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
                    permissionGranted: controller.permissionGranted,
                    t: t,
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

/// Stateless Canvas renderer. Kept separate so the drawing logic is easy to
/// extend per state (M3 adds the remaining states + overlays).
enum PetRenderer {

    static func draw(
        state: PetState,
        metrics: Metrics,
        permissionGranted: Bool,
        t: TimeInterval,
        context ctx: inout GraphicsContext,
        size: CGSize
    ) {
        let center = CGPoint(x: size.width / 2, y: size.height * 0.56)

        // Idle breathing scale.
        let breathe = (state == .idle) ? PetTheme.breathing(t) : 1.0
        ctx.translateBy(x: center.x, y: center.y)
        ctx.scaleBy(x: breathe, y: breathe)
        ctx.translateBy(x: -center.x, y: -center.y)

        drawShadow(center: center, ctx: &ctx)
        drawArms(state: state, center: center, t: t, ctx: &ctx)
        drawBody(state: state, center: center, ctx: &ctx)
        drawFace(state: state, center: center, t: t, ctx: &ctx)

        if !permissionGranted {
            drawPermissionHint(size: size, ctx: &ctx)
        }
    }

    // MARK: - Body parts

    private static let bodySize = CGSize(width: 116, height: 100)

    private static func bodyRect(center: CGPoint) -> CGRect {
        CGRect(
            x: center.x - bodySize.width / 2,
            y: center.y - bodySize.height / 2,
            width: bodySize.width,
            height: bodySize.height
        )
    }

    private static func drawShadow(center: CGPoint, ctx: inout GraphicsContext) {
        let rect = CGRect(x: center.x - 50, y: center.y + 48, width: 100, height: 18)
        ctx.fill(Path(ellipseIn: rect), with: .color(.black.opacity(0.18)))
    }

    private static func drawBody(state: PetState, center: CGPoint, ctx: inout GraphicsContext) {
        let rect = bodyRect(center: center)
        let path = Path(roundedRect: rect, cornerRadius: 34)
        ctx.fill(path, with: .color(PetTheme.bodyColor(for: state)))
        ctx.stroke(path, with: .color(PetTheme.outlineColor), lineWidth: 3)

        // Ears / little tufts on top.
        for dx in [-34.0, 34.0] {
            let ear = Path(ellipseIn: CGRect(x: center.x + dx - 11, y: rect.minY - 12,
                                             width: 22, height: 22))
            ctx.fill(ear, with: .color(PetTheme.bodyColor(for: state)))
            ctx.stroke(ear, with: .color(PetTheme.outlineColor), lineWidth: 3)
        }
    }

    private static func drawFace(state: PetState, center: CGPoint, t: TimeInterval, ctx: inout GraphicsContext) {
        let eyeY = center.y - 8
        let eyeDX: CGFloat = 24
        let blink = PetTheme.blink(t)

        // Cheeks.
        for dx in [-eyeDX - 12, eyeDX + 12] {
            let cheek = Path(ellipseIn: CGRect(x: center.x + dx - 9, y: eyeY + 12, width: 18, height: 12))
            ctx.fill(cheek, with: .color(PetTheme.cheekColor))
        }

        // Eyes.
        for dx in [-eyeDX, eyeDX] {
            drawEye(at: CGPoint(x: center.x + dx, y: eyeY), openness: blink, state: state, ctx: &ctx)
        }

        // Mouth.
        drawMouth(state: state, center: CGPoint(x: center.x, y: eyeY + 26), ctx: &ctx)
    }

    private static func drawEye(at p: CGPoint, openness: CGFloat, state: PetState, ctx: inout GraphicsContext) {
        let w: CGFloat = 14
        let h = max(2.0, 16 * openness)
        let rect = CGRect(x: p.x - w / 2, y: p.y - h / 2, width: w, height: h)
        if openness < 0.25 {
            // Closed eye = a small curved line.
            var line = Path()
            line.move(to: CGPoint(x: rect.minX, y: p.y))
            line.addQuadCurve(to: CGPoint(x: rect.maxX, y: p.y),
                              control: CGPoint(x: p.x, y: p.y + 3))
            ctx.stroke(line, with: .color(PetTheme.outlineColor), lineWidth: 3)
        } else {
            ctx.fill(Path(ellipseIn: rect), with: .color(PetTheme.outlineColor))
            // Highlight glint.
            let glint = Path(ellipseIn: CGRect(x: p.x - 1, y: p.y - 4, width: 4, height: 4))
            ctx.fill(glint, with: .color(.white.opacity(0.9)))
        }
    }

    private static func drawMouth(state: PetState, center p: CGPoint, ctx: inout GraphicsContext) {
        var path = Path()
        switch state {
        case .typing:
            // Small open "o".
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 6, y: p.y - 5, width: 12, height: 12)),
                     with: .color(PetTheme.outlineColor))
        default:
            // Gentle smile.
            path.move(to: CGPoint(x: p.x - 11, y: p.y))
            path.addQuadCurve(to: CGPoint(x: p.x + 11, y: p.y),
                              control: CGPoint(x: p.x, y: p.y + 9))
            ctx.stroke(path, with: .color(PetTheme.outlineColor), lineWidth: 3)
        }
    }

    private static func drawArms(state: PetState, center: CGPoint, t: TimeInterval, ctx: inout GraphicsContext) {
        let rect = bodyRect(center: center)
        let armY = rect.maxY - 14
        let typing = (state == .typing)

        for (i, dx) in [-rect.width / 2 + 6, rect.width / 2 - 6].enumerated() {
            let bob = typing ? PetTheme.pawBob(t, phase: i == 0 ? 0 : .pi) * 6 : 0
            let paw = Path(ellipseIn: CGRect(x: center.x + dx - 11, y: armY - bob,
                                             width: 22, height: 20))
            ctx.fill(paw, with: .color(PetTheme.bodyColor(for: state)))
            ctx.stroke(paw, with: .color(PetTheme.outlineColor), lineWidth: 3)
        }

        // A little keyboard ledge while typing.
        if typing {
            let ledge = CGRect(x: center.x - 46, y: armY + 16, width: 92, height: 12)
            let path = Path(roundedRect: ledge, cornerRadius: 4)
            ctx.fill(path, with: .color(.black.opacity(0.55)))
        }
    }

    private static func drawPermissionHint(size: CGSize, ctx: inout GraphicsContext) {
        let text = Text("需要辅助功能权限")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.red)
        ctx.draw(text, at: CGPoint(x: size.width / 2, y: size.height - 12))
    }
}
