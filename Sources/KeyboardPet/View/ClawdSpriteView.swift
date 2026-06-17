import SwiftUI

/// Renders the pixel-art "Clawd" crab from PNG sprite frames, with the same
/// per-state motion and transient effects (zzz / ? / sweat / sparkles …) as the
/// procedural cat skin.
struct ClawdSpriteView: View {
    @EnvironmentObject var controller: PetController

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ClawdSpriteContent(state: controller.state,
                               t: t,
                               age: max(0, t - controller.stateChangedAt),
                               isNight: controller.isNight,
                               wpm: controller.snapshot.wpm,
                               permissionGranted: controller.permissionGranted)
        }
    }
}

/// The pure, time-driven rendering of the crab + its effects for a single
/// instant `t`. Splitting this out of `ClawdSpriteView` lets both the live
/// `TimelineView` and the offscreen GIF renderer (`--render-gifs`) share one
/// source of truth, so exported animations match the desktop pixel-for-pixel.
struct ClawdSpriteContent: View {
    let state: PetState
    /// Absolute time in seconds (reference-date based), as used by the live view.
    let t: TimeInterval
    /// Seconds since the state was entered (drives the wakeup startle bounce).
    let age: TimeInterval
    let isNight: Bool
    let wpm: Int
    let permissionGranted: Bool

    /// On-screen size of the crab sprite (the 64px art is scaled up crisply).
    private let spriteSize: CGFloat = 150

    var body: some View {
        ZStack {
            // Behind-the-body effects.
            Canvas { ctx, size in
                ClawdEffects.drawShadow(size: size, ctx: &ctx)
                if state == .flow { ClawdEffects.drawGlow(size: size, t: t, ctx: &ctx) }
                if state == .record { ClawdEffects.drawFireworks(size: size, t: t, ctx: &ctx) }
            }

            // The nightcap is baked into the night sprite variants, so it
            // shares the crab's pixel grid and moves with the body.
            sprite(for: state, t: t, isNight: isNight)
                .interpolation(.none)
                .resizable()
                .frame(width: spriteSize, height: spriteSize)
                .scaleEffect(state == .idle ? PetTheme.breathing(t) : 1.0)
                .offset(y: bobOffset(state: state, t: t, age: age))

            // In-front ambient bubbles / readout (do not bob with the body).
            Canvas { ctx, size in
                ClawdEffects.draw(state: state,
                                  permissionGranted: permissionGranted,
                                  t: t, ctx: &ctx, size: size)
                // Live pixel-art WPM readout while actively typing.
                if showsWPM(state) {
                    ClawdEffects.drawWPM(wpm, t: t, ctx: &ctx)
                }
            }
        }
        .frame(width: PetWindowController.petSize.width,
               height: PetWindowController.petSize.height)
        .contentShape(Rectangle())
    }

    /// Picks the current animation frame for a state.
    private func sprite(for state: PetState, t: TimeInterval, isNight: Bool) -> Image {
        let frames = ClawdSprites.frames(for: state, isNight: isNight)
        guard !frames.isEmpty else { return Image(systemName: "questionmark") }
        let idx = Int(t * state.spriteFPS) % frames.count
        return Image(nsImage: frames[idx])
    }

    /// Active typing states that should surface the live WPM readout.
    private func showsWPM(_ state: PetState) -> Bool {
        switch state {
        case .typing, .flow, .deleting, .record: return true
        default: return false
        }
    }

    /// Vertical motion per state (positive = downward), mirroring the cat skin.
    private func bobOffset(state: PetState, t: TimeInterval, age: TimeInterval) -> CGFloat {
        switch state {
        case .typing: return PetTheme.pawBob(t, phase: 0) * 1.5
        case .flow:   return PetTheme.excitedBob(t) * 4
        case .record: return PetTheme.excitedBob(t) * 3
        case .wakeup: return -PetTheme.wakeupBounce(age)
        default:      return 0
        }
    }
}

/// Transient particles / bubbles drawn over (or behind) the crab sprite.
enum ClawdEffects {

    /// Approximate on-window anchors for the crab (200×200 window, 150px sprite).
    private static let center = CGPoint(x: 100, y: 104)
    private static let headTop: CGFloat = 58

    static func draw(state: PetState, permissionGranted: Bool,
                     t: TimeInterval, ctx: inout GraphicsContext, size: CGSize) {
        switch state {
        case .deleting:
            for (i, dx) in [-34.0, 34.0].enumerated() {
                let phase = (t * 2 + Double(i) * 0.5).truncatingRemainder(dividingBy: 1)
                let y = headTop + CGFloat(phase) * 30
                let drop = Path(ellipseIn: CGRect(x: center.x + dx, y: y, width: 8, height: 11))
                ctx.fill(drop, with: .color(Color(red: 0.4, green: 0.7, blue: 1.0).opacity(1 - phase)))
            }
        case .thinking:
            bubble("?", at: CGPoint(x: center.x + 56, y: headTop - 4), size: 30,
                   color: PetTheme.outlineColor, ctx: &ctx)
        case .sleeping:
            // "zzz" only once actually asleep; sleepy just shows droopy eyes.
            let base = CGPoint(x: center.x + 44, y: headTop)
            for i in 0..<3 {
                let phase = (t * 0.6 + Double(i) * 0.33).truncatingRemainder(dividingBy: 1)
                let pt = CGPoint(x: base.x + CGFloat(phase) * 26, y: base.y - CGFloat(phase) * 42)
                bubble("z", at: pt, size: 14 + CGFloat(i) * 5,
                       color: PetTheme.outlineColor.opacity(1 - phase), ctx: &ctx)
            }
        case .wakeup:
            bubble("!", at: CGPoint(x: center.x + 48, y: headTop - 10), size: 34, color: .red, ctx: &ctx)
        case .flow:
            drawSparkles(t: t, ctx: &ctx)
        default:
            break
        }

        // Note: the nightcap is baked into the night sprite variants (see
        // `Tools/GenerateClawdSprites.swift`), not drawn here.
        if !permissionGranted { drawPermissionHint(size: size, ctx: &ctx) }
    }

    /// A pixel-art HUD showing the live WPM above the crab's head while typing.
    /// The colour warms up with speed and turns "hot" past the flow threshold.
    static func drawWPM(_ wpm: Int, t: TimeInterval, ctx: inout GraphicsContext) {
        let numStr = "\(wpm)"
        let numPixel: CGFloat = 4
        let unitPixel: CGFloat = 2
        let numTop: CGFloat = 12

        let numW = PixelFont.width(numStr, pixel: numPixel)
        let unitStr = "WPM"
        let unitW = PixelFont.width(unitStr, pixel: unitPixel)
        let unitTop = numTop + PixelFont.height * numPixel + 5

        let color = wpmColor(wpm)

        // Backing HUD panel so the readout stays legible over any wallpaper.
        let contentW = max(numW, unitW)
        let panel = CGRect(x: center.x - contentW / 2 - 8,
                           y: numTop - 6,
                           width: contentW + 16,
                           height: (unitTop + PixelFont.height * unitPixel + 6) - (numTop - 6))
        ctx.fill(Path(roundedRect: panel, cornerRadius: 5), with: .color(.black.opacity(0.32)))

        // Number, with a 1px dark drop-shadow for contrast.
        PixelFont.drawCentered(numStr, centerX: center.x + 1, top: numTop + 1,
                               pixel: numPixel, color: .black.opacity(0.5), ctx: &ctx)
        PixelFont.drawCentered(numStr, centerX: center.x, top: numTop,
                               pixel: numPixel, color: color, ctx: &ctx)
        // Unit label.
        PixelFont.drawCentered(unitStr, centerX: center.x, top: unitTop,
                               pixel: unitPixel, color: color.opacity(0.85), ctx: &ctx)
    }

    /// Speed → colour ramp: calm green → warm yellow → hot orange for fast typing.
    private static func wpmColor(_ wpm: Int) -> Color {
        switch wpm {
        case ..<40:   return Color(red: 0.55, green: 0.85, blue: 0.70)  // calm green
        case 40..<80: return Color(red: 1.0,  green: 0.82, blue: 0.30)  // warm yellow
        default:      return Color(red: 1.0,  green: 0.45, blue: 0.30)  // hot orange (flow)
        }
    }

    static func drawShadow(size: CGSize, ctx: inout GraphicsContext) {
        let rect = CGRect(x: size.width / 2 - 46, y: size.height * 0.82, width: 92, height: 16)
        ctx.fill(Path(ellipseIn: rect), with: .color(.black.opacity(0.18)))
    }

    static func drawGlow(size: CGSize, t: TimeInterval, ctx: inout GraphicsContext) {
        let r: CGFloat = 84
        let glow = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
        ctx.fill(glow, with: .color(Color.orange.opacity(Double(PetTheme.glow(t)) * 0.45)))
    }

    static func drawFireworks(size: CGSize, t: TimeInterval, ctx: inout GraphicsContext) {
        let bursts: [(CGPoint, Color)] = [
            (CGPoint(x: size.width * 0.28, y: size.height * 0.22), .pink),
            (CGPoint(x: size.width * 0.72, y: size.height * 0.18), .yellow),
            (CGPoint(x: size.width * 0.5, y: size.height * 0.32), .cyan),
        ]
        for (i, burst) in bursts.enumerated() {
            let phase = (t * 0.9 + Double(i) * 0.4).truncatingRemainder(dividingBy: 1)
            let radius = CGFloat(phase) * 32
            let alpha = 1 - phase
            for a in stride(from: 0.0, to: .pi * 2, by: .pi / 5) {
                let p = CGPoint(x: burst.0.x + CGFloat(cos(a)) * radius,
                                y: burst.0.y + CGFloat(sin(a)) * radius)
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 2.5, y: p.y - 2.5, width: 5, height: 5)),
                         with: .color(burst.1.opacity(alpha)))
            }
        }
    }

    private static func drawSparkles(t: TimeInterval, ctx: inout GraphicsContext) {
        let positions: [(CGFloat, CGFloat)] = [(-62, -34), (60, -26), (-52, 32), (56, 38)]
        for (i, pos) in positions.enumerated() {
            let twinkle = abs(sin(t * 3 + Double(i)))
            bubble("✦", at: CGPoint(x: center.x + pos.0, y: center.y + pos.1),
                   size: 12 + CGFloat(twinkle) * 8,
                   color: .yellow.opacity(0.6 + twinkle * 0.4), ctx: &ctx)
        }
    }

    private static func bubble(_ s: String, at p: CGPoint, size: CGFloat, color: Color,
                               ctx: inout GraphicsContext) {
        let text = Text(s).font(.system(size: size, weight: .heavy, design: .rounded)).foregroundStyle(color)
        ctx.draw(text, at: p)
    }

    private static func drawPermissionHint(size: CGSize, ctx: inout GraphicsContext) {
        let text = Text("需要辅助功能权限")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.red)
        ctx.draw(text, at: CGPoint(x: size.width / 2, y: size.height - 12))
    }
}
