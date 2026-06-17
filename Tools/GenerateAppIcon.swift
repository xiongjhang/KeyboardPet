// GenerateAppIcon.swift
//
// Standalone generator for the macOS app icon. Takes the pixel-art crab sprite
// and renders it crisply (nearest-neighbor, no smoothing) onto a rounded-rect
// "squircle" background at every size macOS asks for, writing an `.iconset`
// directory ready for `iconutil`.
//
// NOT part of the app build graph. Driven by Tools/generate_app_icon.sh:
//   swift Tools/GenerateAppIcon.swift <source.png> <out.iconset>
//
import AppKit
import Foundation

let args = CommandLine.arguments
guard args.count == 3 else {
    FileHandle.standardError.write(Data("usage: GenerateAppIcon.swift <source.png> <out.iconset>\n".utf8))
    exit(2)
}
let sourcePath = args[1]
let outDir = URL(fileURLWithPath: args[2], isDirectory: true)

guard let srcImage = NSImage(contentsOfFile: sourcePath),
      let srcCG = srcImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    FileHandle.standardError.write(Data("failed to load \(sourcePath)\n".utf8))
    exit(1)
}

// Warm sand background that complements the crab; subtle vertical gradient.
let bgTop = CGColor(red: 0.99, green: 0.86, blue: 0.62, alpha: 1)
let bgBottom = CGColor(red: 0.96, green: 0.70, blue: 0.40, alpha: 1)

/// Render the icon at a single pixel size.
func renderIcon(size S: Int) -> Data {
    let cs = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(data: nil, width: S, height: S, bitsPerComponent: 8, bytesPerRow: 0,
                        space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let f = CGFloat(S)

    // Squircle background, inset a little like standard macOS icons.
    let inset = f * 0.085
    let rect = CGRect(x: inset, y: inset, width: f - 2 * inset, height: f - 2 * inset)
    let radius = rect.width * 0.225
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    let grad = CGGradient(colorsSpace: cs, colors: [bgTop, bgBottom] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: f), end: CGPoint(x: 0, y: 0), options: [])
    ctx.restoreGState()

    // Crab artwork, nearest-neighbor so the pixels stay crisp.
    ctx.interpolationQuality = .none
    ctx.setShouldAntialias(false)
    let artSize = rect.width * 0.74
    let artRect = CGRect(x: (f - artSize) / 2, y: (f - artSize) / 2, width: artSize, height: artSize)
    ctx.draw(srcCG, in: artRect)

    let out = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: out)
    return rep.representation(using: .png, properties: [:])!
}

try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

// (point size, scale) → filename per Apple's iconset convention.
let variants: [(pt: Int, scale: Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2),
    (256, 1), (256, 2), (512, 1), (512, 2),
]
for v in variants {
    let px = v.pt * v.scale
    let suffix = v.scale == 2 ? "@2x" : ""
    let name = "icon_\(v.pt)x\(v.pt)\(suffix).png"
    let data = renderIcon(size: px)
    try! data.write(to: outDir.appendingPathComponent(name))
}

print("✅ Wrote iconset to \(outDir.path)")
