import SwiftUI

/// Renders the pet — the pixel-art "Clawd" crab (see `ClawdSpriteView`).
struct PetView: View {
    @EnvironmentObject var controller: PetController

    var body: some View {
        ClawdSpriteView()
    }
}
