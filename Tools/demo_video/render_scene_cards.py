#!/usr/bin/env python3
"""Render the 1080p scene cards (background + captions) for the demo video.

Each card is an SVG rasterized with cairosvg: brand chrome, kicker/title/desc,
and a progress bar. The animated crab (rendered separately by render_pet_frames.py)
is overlaid by build.sh into the empty left half of the pet scenes.

Output: $KP_WORK/bg<idx>.png  +  $KP_WORK/manifest.txt  (idx|petstate|seconds)
"""
import os, html, cairosvg

WORK = os.environ.get("KP_WORK", "/tmp/kp")
W, H = 1920, 1080
FONT = "Hiragino Sans GB, PingFang SC, STHeiti, sans-serif"
BG = "#13151a"; ACCENT = "#7fe1c0"; CORAL = "#d85a30"
TEXT = "#f4f1ea"; MUTED = "#9aa3ad"

# id, pet state (None = text-only card), kicker, title lines, desc lines, kind
scenes = [
    ("intro",   "idle",     "桌面伙伴",      ["KeyboardPet"],       ["一只跟着你真实敲键起舞的", "桌面像素螃蟹"], "intro"),
    ("typing",  "typing",   "实时响应",      ["跟着你的节奏打字"],   ["全局键盘监听，实时切换状态", "只读物理键码 · 绝不记录字符"], "pet"),
    ("flow",    "flow",     "心流",          ["手速拉满，进入心流"], ["持续高 WPM 时进入专注心流状态"], "pet"),
    ("deleting","deleting", "疯狂删除",      ["狂按退格会冒汗"],     ["大量删除时露出无奈表情与汗滴"], "pet"),
    ("thinking","thinking", "短暂停顿",      ["你在思考，它也在想"], ["敲键短暂停顿时进入思考状态"], "pet"),
    ("sleepy",  "sleepy",   "犯困",          ["开始犯困打哈欠"],     ["空闲久了会变得睡眼惺忪"], "pet"),
    ("sleeping","sleeping", "睡着",          ["久不打字就睡着"],     ["长时间空闲会打盹，冒出 zzz"], "pet"),
    ("wakeup",  "wakeup",   "惊醒",          ["你一回来它就惊醒"],   ["恢复打字的瞬间被惊醒"], "pet"),
    ("record",  "record",   "刷新记录",      ["破纪录就放烟花"],     ["刷新 WPM 峰值时触发庆祝动画"], "pet"),
    ("summary", None,       "不只是一只螃蟹", ["还有这些"],          [], "card"),
    ("outro",   "idle",     "开始使用",      ["养一只在你的桌面上"], ["源码开放 · MIT · 一行命令构建", "github.com/xiongjhang/KeyboardPet"], "intro"),
]
N = len(scenes)

def esc(s): return html.escape(s, quote=True)

def lines(ls, x, y, lh, size, weight, color):
    return "\n".join(
        f'<text x="{x}" y="{y+i*lh}" font-family="{FONT}" font-size="{size}" '
        f'font-weight="{weight}" fill="{color}">{esc(t)}</text>' for i, t in enumerate(ls))

def chrome(idx):
    s = [f'<circle cx="126" cy="72" r="13" fill="{CORAL}"/>',
         f'<text x="156" y="84" font-family="{FONT}" font-size="30" font-weight="500" fill="{TEXT}">KeyboardPet</text>',
         f'<text x="{W-100}" y="84" font-family="{FONT}" font-size="26" fill="{MUTED}" text-anchor="end">{idx+1:02d} / {N:02d}</text>']
    seg=90; gap=16; total=N*seg+(N-1)*gap; sx=(W-total)//2; yy=H-70
    for i in range(N):
        s.append(f'<rect x="{sx+i*(seg+gap)}" y="{yy}" width="{seg}" height="5" rx="2" '
                 f'fill="{ACCENT if i<=idx else "#2a2e36"}"/>')
    return "\n".join(s)

def build(idx):
    sid, pet, kicker, title, desc, kind = scenes[idx]
    b = [f'<rect width="{W}" height="{H}" fill="{BG}"/>',
         '<defs><radialGradient id="vg" cx="34%" cy="46%" r="75%">'
         f'<stop offset="0%" stop-color="#1e2530"/><stop offset="72%" stop-color="{BG}"/></radialGradient></defs>',
         f'<rect width="{W}" height="{H}" fill="url(#vg)"/>', chrome(idx)]
    if kind in ("pet", "intro"):
        tx = 1150
        b.append(f'<text x="{tx}" y="452" font-family="{FONT}" font-size="26" font-weight="500" '
                 f'fill="{ACCENT}" letter-spacing="4">{esc(kicker)}</text>')
        ty = 540
        b.append(lines(title, tx, ty, 88, 72, 500, TEXT))
        b.append(lines(desc, tx, ty + len(title)*88 + 14, 50, 32, 400, MUTED))
    else:
        feats = ["九种手绘像素状态，实时跟随你的敲击",
                 "深夜 00:00–05:00 自动进入夜间睡帽模式",
                 "敲键攒经验、升级，刷新 WPM 峰值放烟花",
                 "今日总量 · 每小时 · 月度日历活跃热力图",
                 "Windows 与 macOS 一套体验（Tauri 跨平台）",
                 "100% 本地，绝不联网，随时导出或抹除数据"]
        b.append(f'<text x="{W//2}" y="300" font-family="{FONT}" font-size="60" font-weight="500" '
                 f'fill="{TEXT}" text-anchor="middle">不只是一只螃蟹</text>')
        for i, f in enumerate(feats):
            yy = 430 + i*82
            b.append(f'<circle cx="{W//2-420}" cy="{yy-9}" r="7" fill="{ACCENT}"/>')
            b.append(f'<text x="{W//2-392}" y="{yy}" font-family="{FONT}" font-size="34" fill="{TEXT}">{esc(f)}</text>')
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">' + "\n".join(b) + '</svg>'
    cairosvg.svg2png(bytestring=svg.encode("utf-8"), write_to=os.path.join(WORK, f"bg{idx}.png"),
                     output_width=W, output_height=H)

if __name__ == "__main__":
    os.makedirs(WORK, exist_ok=True)
    durs = {"intro":3.0, "pet":2.6, "card":4.0}
    with open(os.path.join(WORK, "manifest.txt"), "w") as fh:
        for i,(sid,pet,k,t,d,kind) in enumerate(scenes):
            build(i)
            fh.write(f"{i}|{pet or '-'}|{3.4 if sid=='outro' else durs[kind]}\n")
    print(f"generated {N} scene cards @ {W}x{H} ->", WORK)
