import SwiftUI
import AppKit

/// Loads and caches the Clawd crab sprite frames bundled as PNG resources.
///
/// Frames are authored at a low logical resolution (see `Tools/GenerateClawdSprites.swift`)
/// and scaled up with nearest-neighbor interpolation by the view so the pixels stay crisp.
enum ClawdSprites {

    /// Per-state animation frames, in order. Empty array → missing assets.
    private static let cache: [PetState: [NSImage]] = {
        var result: [PetState: [NSImage]] = [:]
        for state in PetState.allCases {
            result[state] = loadFrames(for: state.spriteName)
        }
        return result
    }()

    /// Frames for a state, falling back to `idle` if a state has none.
    static func frames(for state: PetState) -> [NSImage] {
        let f = cache[state] ?? []
        return f.isEmpty ? (cache[.idle] ?? []) : f
    }

    private static func loadFrames(for name: String) -> [NSImage] {
        var frames: [NSImage] = []
        var index = 0
        while let url = Bundle.module.url(
            forResource: "\(name)_\(index)", withExtension: "png", subdirectory: "Sprites/clawd"
        ), let image = NSImage(contentsOf: url) {
            frames.append(image)
            index += 1
        }
        return frames
    }
}

extension PetState {
    /// Sprite file basename for this state (e.g. `idle` → `idle_0.png`).
    var spriteName: String { rawValue }

    /// Animation speed (frames per second) for the crab sprite loop.
    var spriteFPS: Double {
        switch self {
        case .typing:   return 6
        case .deleting: return 9
        case .flow:     return 7
        case .record:   return 6
        case .idle:     return 0.8   // slow → reads as the occasional blink
        case .thinking: return 1.2
        case .sleepy, .sleeping: return 0.6
        case .wakeup:   return 1
        }
    }
}
