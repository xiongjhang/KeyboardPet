// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "KeyboardPet",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "KeyboardPet",
            path: "Sources/KeyboardPet",
            resources: [
                .copy("Resources/Sprites")
            ]
        )
    ]
)
