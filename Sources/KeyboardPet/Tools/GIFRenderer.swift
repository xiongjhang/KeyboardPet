import AppKit
import SwiftUI

/// Offscreen renderer that exports each pet state's animation as a PNG frame
/// sequence, reusing the exact desktop rendering (`ClawdSpriteContent`) so the
/// resulting GIFs match the on-screen crab pixel-for-pixel — sweat drops, zzz,
/// fireworks, WPM readout and all.
///
/// Invoked via `KeyboardPet --render-gifs <outputDir>`. The frames are then
/// encoded to looping GIFs by `Tools/render_state_gifs.sh`.
enum GIFRenderer {

    /// Render-time resolution multiplier over the 200×200 logical window.
    private static let scale: CGFloat = 2
    /// Frames per second sampled for the exported animation.
    private static let fps: Double = 25

    /// Per-state loop length (seconds), chosen so the looping motion lines up
    /// as cleanly as possible with each state's sprite/effect periods.
    private static let duration: [PetState: Double] = [
        .idle:     2.5,
        .typing:   1.0,
        .flow:     2.0,
        .deleting: 2.0,    // 9 sprite cycles + 4 sweat cycles → seamless
        .thinking: 5.0 / 3, // one 1.2fps sprite cycle
        .sleepy:   20.0 / 9, // one 0.9fps sprite cycle
        .sleeping: 10.0 / 3, // sprite + zzz align
        .wakeup:   2.0,    // the startle bounce damps out over ~2s
        .record:   2.0,
    ]

    /// A plausible live WPM for the states that surface the readout.
    private static let wpm: [PetState: Int] = [
        .typing: 58, .flow: 92, .deleting: 47, .record: 120,
    ]

    /// Entry point (called from `main.swift`). Runs synchronously on the main
    /// thread, so it is safe to hop onto the main actor for the rendering work.
    static func main() {
        MainActor.assumeIsolated { run() }
    }

    @MainActor
    private static func run() {
        // ImageRenderer needs an NSApplication instance to back its drawing.
        _ = NSApplication.shared

        let args = CommandLine.arguments
        guard let flagIdx = args.firstIndex(of: "--render-gifs"),
              flagIdx + 1 < args.count else {
            FileHandle.standardError.write(Data("usage: --render-gifs <outputDir>\n".utf8))
            exit(2)
        }
        let outDir = URL(fileURLWithPath: args[flagIdx + 1], isDirectory: true)

        for state in PetState.allCases {
            render(state: state, into: outDir)
        }
        print("done")
        exit(0)
    }

    @MainActor
    private static func render(state: PetState, into outDir: URL) {
        let dur = duration[state] ?? 2.0
        let frameCount = max(1, Int((dur * fps).rounded()))
        let stateDir = outDir.appendingPathComponent(state.rawValue, isDirectory: true)
        try? FileManager.default.createDirectory(at: stateDir, withIntermediateDirectories: true)

        for i in 0..<frameCount {
            let t = Double(i) / fps
            let content = ClawdSpriteContent(
                state: state,
                t: t,
                age: t,                       // only wakeup uses this (bounce phase)
                isNight: false,
                wpm: wpm[state] ?? 0,
                permissionGranted: true)

            let renderer = ImageRenderer(content: content)
            renderer.scale = scale
            renderer.isOpaque = false

            guard let cg = renderer.cgImage else { continue }
            let rep = NSBitmapImageRep(cgImage: cg)
            guard let data = rep.representation(using: .png, properties: [:]) else { continue }
            let url = stateDir.appendingPathComponent(String(format: "frame_%04d.png", i))
            try? data.write(to: url)
        }
        print("rendered \(state.rawValue): \(frameCount) frames")
    }
}
