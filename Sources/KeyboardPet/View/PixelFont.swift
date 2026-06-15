import SwiftUI

/// A tiny bitmap "pixel" font for crisp, retro on-screen readouts.
///
/// Each glyph is a list of equal-length row strings where "1" marks a filled
/// pixel. Glyphs are 5 rows tall; widths vary per character. Rendering fills
/// integer-aligned rectangles so the result stays sharp at any scale (matching
/// the pixel-art crab).
enum PixelFont {

    /// Glyph height, in font pixels (before scaling).
    static let height: CGFloat = 5

    /// Only the characters needed for a "<number> WPM" readout.
    private static let glyphs: [Character: [String]] = [
        "0": ["111", "101", "101", "101", "111"],
        "1": ["010", "110", "010", "010", "111"],
        "2": ["111", "001", "111", "100", "111"],
        "3": ["111", "001", "111", "001", "111"],
        "4": ["101", "101", "111", "001", "001"],
        "5": ["111", "100", "111", "001", "111"],
        "6": ["111", "100", "111", "101", "111"],
        "7": ["111", "001", "010", "010", "010"],
        "8": ["111", "101", "111", "101", "111"],
        "9": ["111", "101", "111", "001", "111"],
        "W": ["10001", "10001", "10101", "11011", "10001"],
        "P": ["11110", "10001", "11110", "10000", "10000"],
        "M": ["10001", "11011", "10101", "10001", "10001"],
        " ": ["00", "00", "00", "00", "00"],
    ]

    /// Total pixel width of `string` at the given pixel scale (incl. inter-glyph gaps).
    static func width(_ string: String, pixel: CGFloat, spacing: CGFloat = 1) -> CGFloat {
        let chars = Array(string)
        var w: CGFloat = 0
        for (i, ch) in chars.enumerated() {
            guard let g = glyphs[ch] else { continue }
            w += CGFloat(g[0].count) * pixel
            if i < chars.count - 1 { w += spacing * pixel }
        }
        return w
    }

    /// Draw `string` with its top-left at `origin`, as filled pixel rects.
    static func draw(_ string: String, at origin: CGPoint, pixel: CGFloat,
                     color: Color, spacing: CGFloat = 1, ctx: inout GraphicsContext) {
        var x = origin.x
        for ch in string {
            guard let g = glyphs[ch] else { continue }
            for (r, row) in g.enumerated() {
                for (c, bit) in row.enumerated() where bit == "1" {
                    let rect = CGRect(x: x + CGFloat(c) * pixel,
                                      y: origin.y + CGFloat(r) * pixel,
                                      width: pixel, height: pixel)
                    ctx.fill(Path(rect), with: .color(color))
                }
            }
            x += CGFloat(g[0].count) * pixel + spacing * pixel
        }
    }

    /// Draw `string` centered horizontally on `centerX`, top edge at `top`.
    static func drawCentered(_ string: String, centerX: CGFloat, top: CGFloat,
                             pixel: CGFloat, color: Color, spacing: CGFloat = 1,
                             ctx: inout GraphicsContext) {
        let w = width(string, pixel: pixel, spacing: spacing)
        draw(string, at: CGPoint(x: centerX - w / 2, y: top), pixel: pixel,
             color: color, spacing: spacing, ctx: &ctx)
    }
}
