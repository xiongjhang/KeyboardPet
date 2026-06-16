import SwiftUI

/// Renders the pet — the pixel-art "Clawd" crab (see `ClawdSpriteView`).
///
/// The crab is authored on a fixed logical canvas (`PetWindowController.petSize`)
/// and scaled as a whole by the user-set `petScale`, so every element (sprite,
/// shadow, bubbles, readout) scales together. `PetWindowController` resizes the
/// floating window to match.
struct PetView: View {
    @EnvironmentObject var controller: PetController
    @ObservedObject private var settings = PetSettings.shared

    var body: some View {
        let scale = CGFloat(settings.petScale)
        let base = PetWindowController.petSize
        ClawdSpriteView()
            .scaleEffect(scale, anchor: .center)
            .frame(width: base.width * scale, height: base.height * scale)
    }
}
