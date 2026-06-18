# 跨平台移植方案（方案 A · Tauri）

> 目标：在保留现有 macOS 体验的前提下，将 KeyboardPet 重写为 **Windows + macOS 单一代码库**。
> 技术栈：**Tauri（Rust 后端 + Web 前端）**。
> 当前 Swift 版本作为"行为基准"保留在 `main`，新实现必须 1:1 还原下文列出的核心规则。

---

## 1. 为什么是 Tauri

- 宠物是**像素精灵 + 透明置顶窗口**，Web 前端（HTML/CSS/Canvas）做帧动画最自然，现有 PNG 资产可 100% 复用。
- Tauri 的托盘、透明/置顶/点击穿透窗口、多窗口均为成熟能力。
- Rust 侧用同一套代码处理两个平台的键盘钩子与持久化，仅在最底层按平台分实现。
- 打包体积小（~5–10MB），无 Dock/任务栏占用，符合"轻量后台代理"定位。

---

## 2. 仓库结构（目标）

```
KeyboardPet/                  ← 现有 Swift 工程保留在 main，移植在本分支
├─ src-tauri/                 ← Rust 后端
│  ├─ src/
│  │  ├─ main.rs              ← Tauri 启动、托盘、窗口、命令注册
│  │  ├─ core/                ← 可移植领域逻辑（与平台无关，可单测）
│  │  │  ├─ metrics.rs        ← MetricsEngine 移植
│  │  │  ├─ state_machine.rs  ← PetStateMachine 移植
│  │  │  ├─ experience.rs     ← ExperienceManager 移植
│  │  │  ├─ settings.rs       ← PetSettings（默认值/读写）
│  │  │  └─ stats_store.rs    ← 小时桶持久化（SQLite/JSON）
│  │  └─ platform/            ← 平台相关实现
│  │     ├─ keyboard/
│  │     │  ├─ windows.rs     ← SetWindowsHookEx(WH_KEYBOARD_LL)
│  │     │  └─ macos.rs       ← CGEventTap（行为对齐现有实现）
│  │     ├─ tray.rs           ← 托盘/菜单
│  │     ├─ window.rs         ← 透明置顶/拖拽/位置记忆
│  │     └─ autostart.rs      ← 开机自启
│  └─ tauri.conf.json
├─ src/                       ← Web 前端
│  ├─ pet/                    ← 宠物视图：帧动画、夜间叠加、WPM 浮标
│  ├─ stats/                  ← 统计面板：今日总量、小时热力图、月历热力图
│  ├─ settings/              ← 设置界面
│  └─ assets/clawd/           ← 复用现有 PNG 精灵
└─ docs/cross-platform-plan.md（本文件）
```

> 原则：**core/ 与平台/UI 完全解耦**。键盘输入抽象成 `KeyEvent` 流喂给 core，core 只产出 `Metrics` / `PetState` / XP，平台层与前端只做 I/O 与渲染。

---

## 3. 必须 1:1 还原的核心规则（行为基准）

以下数值与公式取自现有 Swift 实现，移植后用单元测试锁定。

### 3.1 KeyEvent（隐私不变量）
只采集：`key_code: i64`、`is_delete: bool`、`timestamp`。**绝不**采集字符、修饰键、窗口标题、应用名。
- 删除键 keycode 集合：**macOS** `{51, 117}`（Backspace / Forward Delete）；**Windows** 需映射为 `VK_BACK (0x08)`、`VK_DELETE (0x2E)`。

### 3.2 MetricsEngine
- WPM 滑窗 `wpmWindow = 10s`；每 `0.5s` 重算一次（让空闲时间/WPM 自然衰减）。
- WPM 公式：`charsPerMinute = count_in_window * (60 / wpmWindow)`，`wpm = round(charsPerMinute / 5)`（5 字符=1 词，对齐 Monkeytype）。
- 删除率窗口 `deleteWindow = 20s`：`deleteRate = deletes / total`，窗口空时为 0。
- `idleSeconds = now - lastKeyTime`，无按键时为 `∞`。
- 连续编码会话：空闲间隔 `> 60s (sessionGap)` 重置 `sessionStart`；`continuousCodingSeconds` 仅在 `idle <= 60s` 时有效，否则 0。
- Flow 追踪：`wpm >= flowThreshold(60)` 时记 `flowSince`，低于则清空。
- 个人记录：`wpm > peakWPM` 即刷新；**仅当旧记录 > 0** 才触发庆祝回调（避免首次冷启动误报）。
- `todayKeystrokes` 每次按键 +1；日切 `resetDaily()` 归零。

### 3.3 PetStateMachine（优先级解析）
状态优先级（高→低）：`record(9) > wakeup(8) > flow(7) > deleting(6) > typing(5) > thinking(4) > sleepy(3) > sleeping(2) > idle(1)`。

求值顺序（`evaluate`）：
1. `record`：`triggerRecord` 后维持 `recordDuration = 3s`，最高优先。
2. `justTyped = idleSeconds <= activeThreshold(2s) && wpm > 0`。
3. `wakeup`：`wakeupUntil` 内维持；当 `current == sleeping && justTyped` 时进入，维持 `wakeupDuration = 2s`。
4. 活跃分支（justTyped）按序：`flow`（flowEnabled 且 `now - flowSince >= flowSustain(30s)`）→ `deleting`（deletingEnabled 且 `deleteRate > deleteRateThreshold(0.5)`）→ 否则 `typing`。
5. 空闲分支：`idle >= sleepingAfter(300s)` → sleeping；`>= sleepyAfter(120s)` → sleepy；`>= thinkingAfter(30s)` → thinking；否则 idle。

### 3.4 夜间叠加（isNight，独立于主状态）
- `nightEnabled` 默认 true，窗口 `[nightStartHour=0, nightEndHour=5)`。
- `start == end` 或禁用 → 无夜间；`start < end` 取 `hour ∈ [start,end)`；`start > end` 跨午夜（`hour >= start || hour < end`）。
- 夜间使用 `night_<state>_*.png` 帧，缺失则回退日间帧。

### 3.5 ExperienceManager（等级曲线）
- 每次按键 `xpPerKeystroke = 1`。
- `level(xp) = floor(sqrt(max(0,xp)) / 10) + 1`；`xpForLevel(L) = ((L-1)*10)^2`（100→L2, 400→L3, 900→L4…）。
- `levelProgress`、`xpToNextLevel` 按上式派生。
- `reset()` 回到 totalXP=0、level=1。

### 3.6 默认阈值表（PetSettings · 出厂值，用户可调，热生效）
| 键 | 默认 | 含义 |
|---|---|---|
| petScale | 1.0 | 宠物缩放（1.0 = 200pt 基准窗口） |
| thinkingAfter / sleepyAfter / sleepingAfter | 30 / 120 / 300 s | 空闲递进 |
| flowEnabled / flowThreshold / flowSustain | true / 60 WPM / 30 s | 心流 |
| deletingEnabled / deleteRateThreshold | true / 0.5 | 纠结 |
| nightEnabled / nightStartHour / nightEndHour | true / 0 / 5 | 夜间 |
| activeThreshold | 2.0 s | 活跃判定 |
| wpmWindow / deleteWindow | 10 / 20 s | 滑窗 |
| recordDuration / wakeupDuration | 3 / 2 s | 定时状态 |

---

## 4. 平台能力映射（macOS → Windows）

| 能力 | macOS（现状） | Windows（新增） | 备注 |
|---|---|---|---|
| 全局键盘监听 | `CGEventTap` + 无障碍授权 | `SetWindowsHookEx(WH_KEYBOARD_LL)` | **用 `rdev` 统一封装**（内部即这两套底层钩子）；Windows **免授权**；注意杀软可能误报低级钩子 |
| 托盘/菜单栏 | `NSStatusItem` | 系统托盘 `Shell_NotifyIcon`（Tauri tray） | 同一抽象 |
| 宠物窗口 | `NSWindow`（透明/置顶/拖拽） | `WS_EX_LAYERED \| WS_EX_TRANSPARENT \| WS_EX_TOPMOST` | Tauri：`transparent + alwaysOnTop + decorations:false` |
| 位置记忆 | UserDefaults | settings 存储 | 跨平台统一 |
| 开机自启 | `ServiceManagement` | 注册表 `Run` 键 / 启动文件夹 | 可用 `tauri-plugin-autostart` |
| 持久化 | `SwiftData` + `UserDefaults` | SQLite / JSON @ `%APPDATA%` | 见下 |

**已采用 `rdev`**（P2 落地）：它把 Windows `WH_KEYBOARD_LL` 与 macOS `CGEventTap` 封装为同一 API，省去手写两套 unsafe FFI。隐私上**只读 `KeyPress` 的按键种类来判定是否删除键，绝不读 `event.name`（即产生的字符）**，满足"只采集 keycode + 时间戳"的不变量。`rdev::listen` 无停止句柄，但本应用是常驻托盘代理，进程级常开可接受。macOS 辅助功能授权用 `macos-accessibility-client` 触发系统授权框。

---

## 5. 数据模型与迁移

- 小时桶（来自 `StatsStore`）：`{ key: "yyyy-MM-dd-HH", day: "yyyy-MM-dd", hour: 0..23, count }`，`key` 唯一；写入按 60s 批量。
  - 查询接口需还原：`hourlyCounts(day)`、`dailyCounts(month "yyyy-MM")`、`allHourly()`（导出用）、`eraseAll()`。
- 累计值：`totalXP`、`petLevel`、`peakWPM`、`todayKeystrokes`。
- 设置：第 3.6 节键值。
- **导出格式**对齐现有 `DataExporter`（仅聚合计数的 JSON）；隐私承诺不变（无字符、无网络）。
- 旧 macOS 用户数据迁移：可后置（非必须）；如需，写一次性脚本把 SwiftData/UserDefaults 导出为新格式导入。

---

## 6. 分阶段路线

- **P0 · 骨架**：Tauri 工程初始化；托盘 + 一个透明置顶窗口能显示一张精灵；Win/mac 各自能跑起来。
- **P1 · core 移植**：metrics / state_machine / experience / settings 移植为 Rust，**配齐单元测试**对齐第 3 节规则（可直接把现有 `Tests/` 用例翻过来）。
- **P2 · 键盘钩子**：Windows LL hook + macOS CGEventTap，产出 `KeyEvent` 流接入 core；验证隐私不变量。
- **P3 · 宠物前端**：9 状态帧动画 + 夜间叠加 + 拖拽 + 位置记忆 + WPM 浮标 + 破纪录庆祝。
- **P4 · 统计与设置**：小时/月历热力图、等级/XP 摘要、设置面板（阈值调节、自启、导出/清除）。
- **P5 · 持久化与打包**：SQLite/JSON 落地、批量写入；Windows MSI/NSIS 与 macOS bundle 打包；CI 双平台构建。

> 建议每个阶段在 Windows 与 macOS 都过一遍，避免平台差异累积到最后。

---

## 7. 主要风险

1. **键盘钩子隐私**：必须确认所选方案只拿 keycode，不触达字符内容。
2. **杀软误报**：Windows 低级键盘钩子可能被标记；需在 README 说明并考虑签名。
3. **像素动画清晰度**：前端缩放需 `image-rendering: pixelated`（等价 macOS 的最近邻放大）。
4. **透明点击穿透**：宠物本体可拖拽、空白区点击穿透，两平台行为需一致调校。
5. **行为漂移**：core 的定时器节奏（0.5s 重算）与浮点阈值在 Rust 下需与 Swift 完全一致，靠单测兜底。
</content>
</invoke>
