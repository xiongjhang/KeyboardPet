import SwiftUI

/// SwiftUI view that renders the pet with a `Canvas`, animated via `TimelineView`.
struct PetView: View {
    @EnvironmentObject var controller: PetController

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                PetRenderer.draw(
                    state: controller.state,
                    metrics: controller.snapshot,
                    isNight: controller.isNight,
                    permissionGranted: controller.permissionGranted,
                    t: t,
                    stateAge: max(0, t - controller.stateChangedAt),
                    context: &context,
                    size: size
                )
            }
        }
        .frame(width: PetWindowController.petSize.width,
               height: PetWindowController.petSize.height)
        .contentShape(Rectangle())
    }
}

/// Stateless Canvas renderer covering all pet states + the night overlay.
enum PetRenderer {

    static func draw(
        state: PetState,
        metrics: Metrics,
        isNight: Bool,
        permissionGranted: Bool,
        t: TimeInterval,
        stateAge: TimeInterval,
        context ctx: inout GraphicsContext,
        size: CGSize
    ) {
        var center = CGPoint(x: size.width / 2, y: size.height * 0.56)

        // Vertical motion per state.
        switch state {
        case .typing:   center.y += PetTheme.pawBob(t, phase: 0) * 1.5
        case .flow:     center.y += PetTheme.excitedBob(t) * 4
        case .wakeup:   center.y -= PetTheme.wakeupBounce(stateAge)
        case .record:   center.y += PetTheme.excitedBob(t) * 3
        default:        break
        }

        // Idle breathing scale.
        let breathe = (state == .idle) ? PetTheme.breathing(t) : 1.0
        ctx.translateBy(x: center.x, y: center.y)
        ctx.scaleBy(x: breathe, y: breathe)
        ctx.translateBy(x: -center.x, y: -center.y)

        drawShadow(center: center, ctx: &ctx)

        // Behind-the-body effects.
        if state == .flow { drawGlow(center: center, t: t, ctx: &ctx) }
        if state == .record { drawFireworks(size: size, t: t, ctx: &ctx) }

        if state == .sleeping {
            drawSleepingBody(state: state, center: center, ctx: &ctx)
        } else {
            drawArms(state: state, center: center, t: t, ctx: &ctx)
            drawBody(state: state, center: center, ctx: &ctx)
        }

        drawFace(state: state, center: center, t: t, ctx: &ctx)

        // In-front effects / bubbles.
        drawStateEffects(state: state, center: center, t: t, ctx: &ctx)
        if isNight { drawNightcap(center: center, ctx: &ctx) }

        if !permissionGranted {
            drawPermissionHint(size: size, ctx: &ctx)
        }
    }

    // MARK: - Geometry

    private static let bodySize = CGSize(width: 116, height: 100)

    private static func bodyRect(center: CGPoint) -> CGRect {
        CGRect(x: center.x - bodySize.width / 2, y: center.y - bodySize.height / 2,
               width: bodySize.width, height: bodySize.height)
    }

    // MARK: - Body

    private static func drawShadow(center: CGPoint, ctx: inout GraphicsContext) {
        let rect = CGRect(x: center.x - 50, y: center.y + 48, width: 100, height: 18)
        ctx.fill(Path(ellipseIn: rect), with: .color(.black.opacity(0.18)))
    }

    private static func drawBody(state: PetState, center: CGPoint, ctx: inout GraphicsContext) {
        let rect = bodyRect(center: center)
        let path = Path(roundedRect: rect, cornerRadius: 34)
        ctx.fill(path, with: .color(PetTheme.bodyColor(for: state)))
        ctx.stroke(path, with: .color(PetTheme.outlineColor), lineWidth: 3)

        for dx in [-34.0, 34.0] {
            let ear = Path(ellipseIn: CGRect(x: center.x + dx - 11, y: rect.minY - 12, width: 22, height: 22))
            ctx.fill(ear, with: .color(PetTheme.bodyColor(for: state)))
            ctx.stroke(ear, with: .color(PetTheme.outlineColor), lineWidth: 3)
        }
    }

    /// Sleeping pose: a flattened, wider body (lying down).
    private static func drawSleepingBody(state: PetState, center: CGPoint, ctx: inout GraphicsContext) {
        let rect = CGRect(x: center.x - 72, y: center.y + 6, width: 144, height: 64)
        let path = Path(roundedRect: rect, cornerRadius: 30)
        ctx.fill(path, with: .color(PetTheme.bodyColor(for: state)))
        ctx.stroke(path, with: .color(PetTheme.outlineColor), lineWidth: 3)
    }

    private static func drawArms(state: PetState, center: CGPoint, t: TimeInterval, ctx: inout GraphicsContext) {
        let rect = bodyRect(center: center)
        let armY = rect.maxY - 14
        let typing = (state == .typing || state == .deleting || state == .flow)
        // Deleting types frantically (faster), flow is excited.
        let speed: TimeInterval = state == .deleting ? t * 1.6 : t

        for (i, dx) in [-rect.width / 2 + 6, rect.width / 2 - 6].enumerated() {
            let bob = typing ? PetTheme.pawBob(speed, phase: i == 0 ? 0 : .pi) * 6 : 0
            let paw = Path(ellipseIn: CGRect(x: center.x + dx - 11, y: armY - bob, width: 22, height: 20))
            ctx.fill(paw, with: .color(PetTheme.bodyColor(for: state)))
            ctx.stroke(paw, with: .color(PetTheme.outlineColor), lineWidth: 3)
        }

        if state == .typing || state == .deleting || state == .flow {
            let ledge = CGRect(x: center.x - 46, y: armY + 16, width: 92, height: 12)
            ctx.fill(Path(roundedRect: ledge, cornerRadius: 4), with: .color(.black.opacity(0.55)))
        }

        // thinking: one paw up to the chin.
        if state == .thinking {
            let paw = Path(ellipseIn: CGRect(x: center.x + 8, y: center.y + 8, width: 20, height: 18))
            ctx.fill(paw, with: .color(PetTheme.bodyColor(for: state)))
            ctx.stroke(paw, with: .color(PetTheme.outlineColor), lineWidth: 3)
        }
    }

    // MARK: - Face

    private static func drawFace(state: PetState, center: CGPoint, t: TimeInterval, ctx: inout GraphicsContext) {
        if state == .sleeping {
            // Closed eyes on the lying body.
            for dx in [-22.0, 22.0] { drawClosedEye(at: CGPoint(x: center.x + dx, y: center.y + 30), ctx: &ctx) }
            return
        }

        let eyeY = center.y - 8
        let eyeDX: CGFloat = 24

        // Eye openness per state.
        let openness: CGFloat
        switch state {
        case .sleepy:   openness = 0.35
        case .thinking: openness = 0.85
        case .flow, .record, .wakeup: openness = 1.0
        default:        openness = PetTheme.blink(t)
        }

        // Cheeks (skip while clearly distressed/sleepy).
        if state != .deleting && state != .sleepy {
            for dx in [-eyeDX - 12, eyeDX + 12] {
                let cheek = Path(ellipseIn: CGRect(x: center.x + dx - 9, y: eyeY + 12, width: 18, height: 12))
                ctx.fill(cheek, with: .color(PetTheme.cheekColor))
            }
        }

        for dx in [-eyeDX, eyeDX] {
            drawEye(at: CGPoint(x: center.x + dx, y: eyeY), openness: openness, state: state, ctx: &ctx)
        }

        drawMouth(state: state, center: CGPoint(x: center.x, y: eyeY + 26), ctx: &ctx)
    }

    private static func drawEye(at p: CGPoint, openness: CGFloat, state: PetState, ctx: inout GraphicsContext) {
        let w: CGFloat = 14
        let h = max(2.0, 16 * openness)
        let rect = CGRect(x: p.x - w / 2, y: p.y - h / 2, width: w, height: h)
        if openness < 0.25 {
            drawClosedEye(at: p, ctx: &ctx)
            return
        }
        ctx.fill(Path(ellipseIn: rect), with: .color(PetTheme.outlineColor))
        let glint = Path(ellipseIn: CGRect(x: p.x - 1, y: p.y - 4, width: 4, height: 4))
        ctx.fill(glint, with: .color(.white.opacity(0.9)))
        // Excited states get a sparkle in the eye.
        if state == .flow || state == .record {
            let star = Path(ellipseIn: CGRect(x: p.x - 4, y: p.y, width: 3, height: 3))
            ctx.fill(star, with: .color(.white))
        }
    }

    private static func drawClosedEye(at p: CGPoint, ctx: inout GraphicsContext) {
        var line = Path()
        line.move(to: CGPoint(x: p.x - 7, y: p.y))
        line.addQuadCurve(to: CGPoint(x: p.x + 7, y: p.y), control: CGPoint(x: p.x, y: p.y + 3))
        ctx.stroke(line, with: .color(PetTheme.outlineColor), lineWidth: 3)
    }

    private static func drawMouth(state: PetState, center p: CGPoint, ctx: inout GraphicsContext) {
        var path = Path()
        switch state {
        case .typing:
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 6, y: p.y - 5, width: 12, height: 12)),
                     with: .color(PetTheme.outlineColor))
        case .deleting:
            // Wavy worried mouth.
            path.move(to: CGPoint(x: p.x - 12, y: p.y))
            path.addCurve(to: CGPoint(x: p.x + 12, y: p.y),
                          control1: CGPoint(x: p.x - 4, y: p.y + 8),
                          control2: CGPoint(x: p.x + 4, y: p.y - 8))
            ctx.stroke(path, with: .color(PetTheme.outlineColor), lineWidth: 3)
        case .flow, .record:
            // Big open grin.
            ctx.fill(Path(roundedRect: CGRect(x: p.x - 10, y: p.y - 4, width: 20, height: 14), cornerRadius: 7),
                     with: .color(PetTheme.outlineColor))
        case .sleepy, .sleeping:
            // Small yawn / o.
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 5, y: p.y - 3, width: 10, height: 12)),
                     with: .color(PetTheme.outlineColor))
        case .wakeup:
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 8, y: p.y - 6, width: 16, height: 16)),
                     with: .color(PetTheme.outlineColor))
        default:
            path.move(to: CGPoint(x: p.x - 11, y: p.y))
            path.addQuadCurve(to: CGPoint(x: p.x + 11, y: p.y), control: CGPoint(x: p.x, y: p.y + 9))
            ctx.stroke(path, with: .color(PetTheme.outlineColor), lineWidth: 3)
        }
    }

    // MARK: - Effects & bubbles

    private static func drawStateEffects(state: PetState, center: CGPoint, t: TimeInterval, ctx: inout GraphicsContext) {
        let rect = bodyRect(center: center)
        switch state {
        case .deleting:
            // Sweat drops flicking off the head.
            for (i, dx) in [-46.0, 46.0].enumerated() {
                let phase = (t * 2 + Double(i) * 0.5).truncatingRemainder(dividingBy: 1)
                let y = rect.minY - 6 + CGFloat(phase) * 26
                let drop = Path(ellipseIn: CGRect(x: center.x + dx, y: y, width: 7, height: 10))
                ctx.fill(drop, with: .color(Color(red: 0.4, green: 0.7, blue: 1.0).opacity(1 - phase)))
            }
        case .thinking:
            drawBubbleText("?", at: CGPoint(x: center.x + 52, y: rect.minY - 6),
                           size: 30, color: PetTheme.outlineColor, ctx: &ctx)
        case .sleepy, .sleeping:
            // Rising zzZ bubbles.
            let base = CGPoint(x: rect.maxX - 6, y: rect.minY - 4)
            for i in 0..<3 {
                let phase = (t * 0.6 + Double(i) * 0.33).truncatingRemainder(dividingBy: 1)
                let pt = CGPoint(x: base.x + CGFloat(phase) * 24, y: base.y - CGFloat(phase) * 40)
                drawBubbleText("z", at: pt, size: 14 + CGFloat(i) * 5,
                               color: PetTheme.outlineColor.opacity(1 - phase), ctx: &ctx)
            }
        case .wakeup:
            drawBubbleText("!", at: CGPoint(x: center.x + 46, y: rect.minY - 10),
                           size: 34, color: .red, ctx: &ctx)
        case .flow:
            drawSparkles(center: center, t: t, ctx: &ctx)
        default:
            break
        }
    }

    private static func drawGlow(center: CGPoint, t: TimeInterval, ctx: inout GraphicsContext) {
        let r: CGFloat = 90
        let glow = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
        ctx.fill(glow, with: .color(Color.orange.opacity(Double(PetTheme.glow(t)) * 0.5)))
    }

    private static func drawSparkles(center: CGPoint, t: TimeInterval, ctx: inout GraphicsContext) {
        let positions: [(CGFloat, CGFloat)] = [(-64, -40), (60, -30), (-50, 30), (58, 36)]
        for (i, pos) in positions.enumerated() {
            let twinkle = abs(sin(t * 3 + Double(i)))
            drawBubbleText("✦", at: CGPoint(x: center.x + pos.0, y: center.y + pos.1),
                           size: 12 + CGFloat(twinkle) * 8,
                           color: .yellow.opacity(0.6 + twinkle * 0.4), ctx: &ctx)
        }
    }

    private static func drawFireworks(size: CGSize, t: TimeInterval, ctx: inout GraphicsContext) {
        let bursts: [(CGPoint, Color)] = [
            (CGPoint(x: size.width * 0.3, y: size.height * 0.25), .pink),
            (CGPoint(x: size.width * 0.7, y: size.height * 0.2), .yellow),
            (CGPoint(x: size.width * 0.5, y: size.height * 0.35), .cyan),
        ]
        for (i, burst) in bursts.enumerated() {
            let phase = (t * 0.9 + Double(i) * 0.4).truncatingRemainder(dividingBy: 1)
            let radius = CGFloat(phase) * 34
            let alpha = 1 - phase
            for a in stride(from: 0.0, to: .pi * 2, by: .pi / 5) {
                let p = CGPoint(x: burst.0.x + cos(a) * radius, y: burst.0.y + sin(a) * radius)
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 2.5, y: p.y - 2.5, width: 5, height: 5)),
                         with: .color(burst.1.opacity(alpha)))
            }
        }
    }

    /// A nightcap drawn on top while it's late at night (the `night` overlay).
    private static func drawNightcap(center: CGPoint, ctx: inout GraphicsContext) {
        let rect = bodyRect(center: center)
        var cap = Path()
        cap.move(to: CGPoint(x: center.x - 36, y: rect.minY + 2))
        cap.addQuadCurve(to: CGPoint(x: center.x + 30, y: rect.minY - 6),
                         control: CGPoint(x: center.x - 4, y: rect.minY - 30))
        cap.addQuadCurve(to: CGPoint(x: center.x + 52, y: rect.minY - 34),
                         control: CGPoint(x: center.x + 50, y: rect.minY - 14))
        cap.closeSubpath()
        ctx.fill(cap, with: .color(Color(red: 0.55, green: 0.4, blue: 0.78)))
        ctx.stroke(cap, with: .color(PetTheme.outlineColor), lineWidth: 2.5)
        // Pom-pom.
        let pom = Path(ellipseIn: CGRect(x: center.x + 46, y: rect.minY - 42, width: 14, height: 14))
        ctx.fill(pom, with: .color(.white))
        ctx.stroke(pom, with: .color(PetTheme.outlineColor), lineWidth: 2)
    }

    private static func drawBubbleText(_ s: String, at p: CGPoint, size: CGFloat, color: Color, ctx: inout GraphicsContext) {
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
