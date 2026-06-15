// GenerateClawdSprites.swift
//
// Standalone sprite generator for the "Clawd" pixel-crab skin.
//
// This is NOT part of the app build graph. It draws a chunky pixel-art crab
// with CoreGraphics (antialiasing off → crisp pixels) and writes one PNG per
// animation frame into the app's resource folder. Re-run it whenever you want
// to tweak the art; commit the resulting PNGs.
//
// Usage:
//   swift Tools/GenerateClawdSprites.swift
//
import AppKit
import CoreGraphics
import Foundation

// MARK: - Canvas

/// Logical pixel resolution. The app scales these up with nearest-neighbor so
/// the chunky pixels stay crisp.
let W = 64
let H = 64

func rgb(_ r: Int, _ g: Int, _ b: Int, _ a: Double = 1) -> CGColor {
    CGColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: a)
}

// Palette
let shell      = rgb(0xE8, 0x55, 0x3C)
let shellDark  = rgb(0xB8, 0x3E, 0x2A)
let shellLight = rgb(0xFF, 0x8A, 0x63)
let belly      = rgb(0xFF, 0xD9, 0xA0)
let eyeWhite   = rgb(0xFF, 0xFF, 0xFF)
let pupil      = rgb(0x2A, 0x1A, 0x14)
let legDark    = rgb(0x9A, 0x33, 0x22)
let blush      = rgb(0xFF, 0x9A, 0x9A, 0.6)

func newContext() -> CGContext {
    let cs = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(
        data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
        space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.setShouldAntialias(false)        // crisp, blocky pixels
    ctx.interpolationQuality = .none
    return ctx
}

// Drawing helpers operate in pixel coordinates with y pointing UP.
func rect(_ ctx: CGContext, _ x: Int, _ y: Int, _ w: Int, _ h: Int, _ c: CGColor) {
    ctx.setFillColor(c)
    ctx.fill(CGRect(x: x, y: y, width: w, height: h))
}

func ellipse(_ ctx: CGContext, _ x: Int, _ y: Int, _ w: Int, _ h: Int, _ c: CGColor) {
    ctx.setFillColor(c)
    ctx.fillEllipse(in: CGRect(x: x, y: y, width: w, height: h))
}

/// Cut a transparent wedge (used for the claw pincer notch).
func cutRect(_ ctx: CGContext, _ x: Int, _ y: Int, _ w: Int, _ h: Int) {
    ctx.setBlendMode(.clear)
    ctx.fill(CGRect(x: x, y: y, width: w, height: h))
    ctx.setBlendMode(.normal)
}

// MARK: - Poses

enum Face { case open, blink, sparkle, worried, half, closed, shock, grin }
enum ClawPose { case rest, up, down, chin, frantic }

func drawClaw(_ ctx: CGContext, left: Bool, lift: Int) {
    // Arm + a big pincer. `lift` raises the whole claw.
    let cx = left ? 11 : 51
    let y = 26 + lift
    // arm segment connecting body to claw (reaches into the shell)
    if left {
        rect(ctx, 13, y + 6, 9, 4, shellDark)
    } else {
        rect(ctx, 42, y + 6, 9, 4, shellDark)
    }
    // pincer body
    ellipse(ctx, cx - 4, y, 16, 16, shell)
    ellipse(ctx, cx - 2, y + 9, 12, 6, shellLight) // top highlight
    // outline-ish darker rim at bottom
    ellipse(ctx, cx - 4, y, 16, 5, shellDark)
    // pincer mouth notch (open toward the outside)
    if left {
        cutRect(ctx, cx - 5, y + 9, 7, 4)
    } else {
        cutRect(ctx, cx + 6, y + 9, 7, 4)
    }
}

func drawLegs(_ ctx: CGContext) {
    for i in 0..<3 {
        let oy = 12 + i * 5
        rect(ctx, 14, oy, 6, 3, legDark)   // left legs
        rect(ctx, 44, oy, 6, 3, legDark)   // right legs
    }
}

func drawEye(_ ctx: CGContext, cx: Int, face: Face, look: Int) {
    let stalkY = 40
    let eyeY = 46
    // stalk
    rect(ctx, cx - 1, stalkY, 3, eyeY - stalkY + 2, shellDark)
    switch face {
    case .closed, .blink:
        // happy closed eye: a short flat line
        rect(ctx, cx - 4, eyeY + 4, 9, 2, pupil)
    case .half:
        ellipse(ctx, cx - 4, eyeY, 10, 11, eyeWhite)
        rect(ctx, cx - 5, eyeY + 6, 12, 6, shellDark) // heavy lid
        rect(ctx, cx - 2 + look, eyeY + 2, 3, 3, pupil)
    default:
        // open white eye + pupil
        ellipse(ctx, cx - 4, eyeY, 10, 11, eyeWhite)
        let px = cx - 2 + look
        rect(ctx, px, eyeY + (face == .shock ? 5 : 3), 3, 3, pupil)
        if face == .sparkle || face == .grin {
            rect(ctx, px + 2, eyeY + 7, 1, 1, eyeWhite) // glint
        }
        if face == .shock {
            // wide-open: bigger white, small pupil already placed
            ellipse(ctx, cx - 4, eyeY, 10, 12, eyeWhite)
            rect(ctx, cx - 1, eyeY + 5, 3, 3, pupil)
        }
    }
}

func drawMouth(_ ctx: CGContext, face: Face) {
    let mx = 32
    let my = 36
    switch face {
    case .grin, .sparkle:
        rect(ctx, mx - 5, my - 1, 11, 2, pupil)
        rect(ctx, mx - 4, my - 3, 9, 2, pupil)
    case .worried:
        rect(ctx, mx - 5, my - 1, 4, 2, pupil)
        rect(ctx, mx + 1, my + 1, 4, 2, pupil)
    case .shock:
        ellipse(ctx, mx - 3, my - 4, 7, 7, pupil)
    case .half, .closed:
        rect(ctx, mx - 2, my - 2, 5, 2, pupil)
    default:
        rect(ctx, mx - 4, my - 1, 9, 2, pupil)
    }
}

/// The full crab. `frame` toggles a 1px body bob for liveliness.
func drawCrab(face: Face, claw: ClawPose, frame: Int, sleeping: Bool = false) -> CGImage {
    let ctx = newContext()
    let bob = frame % 2 == 0 ? 0 : 1

    ctx.translateBy(x: 0, y: CGFloat(bob))

    drawLegs(ctx)

    // Shell body (squashed flatter when sleeping)
    if sleeping {
        ellipse(ctx, 12, 14, 40, 22, shell)
        ellipse(ctx, 16, 24, 32, 9, shellLight)
        ellipse(ctx, 12, 14, 40, 6, shellDark)
    } else {
        ellipse(ctx, 14, 16, 36, 28, shell)
        ellipse(ctx, 18, 30, 28, 11, shellLight) // top highlight
        ellipse(ctx, 22, 17, 20, 15, belly)       // belly
        ellipse(ctx, 14, 16, 36, 6, shellDark)     // bottom rim
        // blush
        ellipse(ctx, 19, 24, 6, 4, blush)
        ellipse(ctx, 39, 24, 6, 4, blush)
    }

    // Claws
    let lift: Int
    switch claw {
    case .rest:    lift = 0
    case .up:      lift = 8
    case .down:    lift = -4
    case .chin:    lift = 0
    case .frantic: lift = frame % 2 == 0 ? -3 : 5
    }
    if claw == .chin {
        // left claw rests, right claw up by the face (thinking)
        drawClaw(ctx, left: true, lift: 0)
        drawClaw(ctx, left: false, lift: 12)
    } else if claw == .frantic {
        drawClaw(ctx, left: true, lift: frame % 2 == 0 ? 5 : -3)
        drawClaw(ctx, left: false, lift: frame % 2 == 0 ? -3 : 5)
    } else {
        drawClaw(ctx, left: true, lift: lift)
        drawClaw(ctx, left: false, lift: lift)
    }

    // Face
    if sleeping {
        drawEye(ctx, cx: 26, face: .closed, look: 0)
        drawEye(ctx, cx: 38, face: .closed, look: 0)
        drawMouth(ctx, face: .closed)
    } else {
        let look = (face == .sparkle) ? 0 : 0
        drawEye(ctx, cx: 26, face: face, look: look)
        drawEye(ctx, cx: 38, face: face, look: look)
        drawMouth(ctx, face: face)
    }

    return ctx.makeImage()!
}

// MARK: - Output

func write(_ image: CGImage, to url: URL) {
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else { return }
    try? data.write(to: url)
}

let fm = FileManager.default
let outDir = URL(fileURLWithPath: fm.currentDirectoryPath)
    .appendingPathComponent("Sources/KeyboardPet/Resources/Sprites/clawd", isDirectory: true)
try? fm.createDirectory(at: outDir, withIntermediateDirectories: true)

// state -> [(face, claw, sleeping)] one entry per frame
let frames: [String: [(Face, ClawPose, Bool)]] = [
    "idle":     [(.open, .rest, false), (.blink, .rest, false)],
    "typing":   [(.open, .down, false), (.open, .up, false)],
    "flow":     [(.sparkle, .up, false), (.sparkle, .down, false)],
    "deleting": [(.worried, .frantic, false), (.worried, .frantic, false)],
    "thinking": [(.open, .chin, false), (.blink, .chin, false)],
    "sleepy":   [(.half, .rest, false), (.half, .rest, false)],
    "sleeping": [(.closed, .rest, true), (.closed, .rest, true)],
    "wakeup":   [(.shock, .up, false)],
    "record":   [(.grin, .up, false), (.grin, .down, false)],
]

for (state, list) in frames {
    for (i, spec) in list.enumerated() {
        let img = drawCrab(face: spec.0, claw: spec.1, frame: i, sleeping: spec.2)
        let url = outDir.appendingPathComponent("\(state)_\(i).png")
        write(img, to: url)
    }
}

print("✅ Wrote Clawd sprites to \(outDir.path)")
