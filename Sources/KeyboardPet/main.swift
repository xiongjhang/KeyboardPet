import Foundation

// Normal launch runs the SwiftUI app. Passing `--render-gifs <outDir>` instead
// renders each pet state's animation offscreen (reusing the exact desktop view)
// into a PNG frame sequence, then exits — used to refresh the README state GIFs.
if CommandLine.arguments.contains("--render-gifs") {
    GIFRenderer.main()
} else {
    KeyboardPetApp.main()
}
