import SwiftUI

/// Renders the pixel-art "Clawd" crab from PNG sprite frames, with the same
/// per-state motion and transient effects (zzz / ? / sweat / sparkles …) as the
/// procedural cat skin.
struct ClawdSpriteView: View {
    @EnvironmentObject var controller: PetController

    /// On-screen size of the crab sprite (the 64px art is scaled up crisply).
    private let spriteSize: CGFloat = 150

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let state = controller.state
            let age = max(0, t - controller.stateChangedAt)

            ZStack {
                // Behind-the-body effects.
                Canvas { ctx, size in
                    ClawdEffects.drawShadow(size: size, ctx: &ctx)
                    if state == .flow { ClawdEffects.drawGlow(size: size, t: t, ctx: &ctx) }
                    if state == .record { ClawdEffects.drawFireworks(size: size, t: t, ctx: &ctx) }
                }

                sprite(for: state, t: t)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: spriteSize, height: spriteSize)
                    .scaleEffect(state == .idle ? PetTheme.breathing(t) : 1.0)
                    .offset(y: bobOffset(state: state, t: t, age: age))

                // In-front effects / bubbles.
                Canvas { ctx, size in
                    ClawdEffects.draw(state: state, isNight: controller.isNight,
                                      permissionGranted: controller.permissionGranted,
                                      t: t, ctx: &ctx, size: size)
                }
            }
            .frame(width: PetWindowController.petSize.width,
                   height: PetWindowController.petSize.height)
            .contentShape(Rectangle())
        }
    }

    /// Picks the current animation frame for a state.
    private func sprite(for state: PetState, t: TimeInterval) -> Image {
        let frames = ClawdSprites.frames(for: state)
        guard !frames.isEmpty else { return Image(systemName: "questionmark") }
        let idx = Int(t * state.spriteFPS) % frames.count
        return Image(nsImage: frames[idx])
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

    static func draw(state: PetState, isNight: Bool, permissionGranted: Bool,
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
        case .sleepy, .sleeping:
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

        if isNight { drawNightcap(ctx: &ctx) }
        if !permissionGranted { drawPermissionHint(size: size, ctx: &ctx) }
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
                let p = CGPoint(x: burst.0.x + cos(a) * radius, y: burst.0.y + sin(a) * radius)
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

    /// A small nightcap perched on the shell while it's late.
    private static func drawNightcap(ctx: inout GraphicsContext) {
        var cap = Path()
        cap.move(to: CGPoint(x: center.x - 30, y: headTop + 4))
        cap.addQuadCurve(to: CGPoint(x: center.x + 26, y: headTop - 2),
                         control: CGPoint(x: center.x - 2, y: headTop - 26))
        cap.addQuadCurve(to: CGPoint(x: center.x + 46, y: headTop - 30),
                         control: CGPoint(x: center.x + 44, y: headTop - 12))
        cap.closeSubpath()
        ctx.fill(cap, with: .color(Color(red: 0.55, green: 0.4, blue: 0.78)))
        ctx.stroke(cap, with: .color(PetTheme.outlineColor), lineWidth: 2.5)
        let pom = Path(ellipseIn: CGRect(x: center.x + 40, y: headTop - 38, width: 14, height: 14))
        ctx.fill(pom, with: .color(.white))
        ctx.stroke(pom, with: .color(PetTheme.outlineColor), lineWidth: 2)
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
