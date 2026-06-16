// GenerateMenuBarIcon.swift
//
// Standalone generator for the menu-bar status icon: a static, monochrome
// pixel-art crab silhouette. Rendered as a black shape on transparency so the
// app can flag it `isTemplate = true` and let macOS tint it for light/dark
// menu bars automatically.
//
// NOT part of the app build graph. Re-run when you want to tweak the art:
//   swift Tools/GenerateMenuBarIcon.swift
//
import AppKit
import Foundation

// 18×18 art grid ('#' = filled pixel). Two eye stalks, a domed shell, a pair of
// claws, and little legs — enough to read as a crab at menu-bar size.
let art = [
    "..................",
    "..................",
    "......#....#......",
    "......#....#......",
    ".....##....##.....",
    "....##########....",
    "...###.####.###...",
    "..##############..",
    "###.##########.###",
    "###.##########.###",
    ".##.##########.##.",
    "....##########....",
    ".....########.....",
    ".....#.#..#.#.....",
    "..................",
    "..................",
    "..................",
    "..................",
]

let cols = 18
let rows = 18
let scale = 2                  // emit @2x (36×36) for crisp pixels on Retina
let W = cols * scale
let H = rows * scale

precondition(art.count == rows, "art must have \(rows) rows")
for (i, row) in art.enumerated() { precondition(row.count == cols, "row \(i) must be \(cols) wide") }

let cs = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.setShouldAntialias(false)
ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))   // black; alpha is what matters for a template

for (r, row) in art.enumerated() {
    for (c, ch) in row.enumerated() where ch == "#" {
        // CoreGraphics origin is bottom-left; art row 0 is the top.
        let x = c * scale
        let y = (rows - 1 - r) * scale
        ctx.fill(CGRect(x: x, y: y, width: scale, height: scale))
    }
}

let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
guard let data = rep.representation(using: .png, properties: [:]) else {
    fatalError("failed to encode PNG")
}

let outDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Sources/KeyboardPet/Resources/Sprites", isDirectory: true)
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
let outURL = outDir.appendingPathComponent("menubar.png")
try! data.write(to: outURL)

print("✅ Wrote menu-bar icon to \(outURL.path)")
