// swift-tools-version: 5.10
// DeckMateKit — shared library for the DeckMate native Apple clients.
//
// Split into three focused products so apps can depend only on what they
// need and tests can live next to each concern:
//
//   DeckMateModels  — Codable domain models that mirror the HelmLog server API
//   DeckMateAPI     — URLSession-based client; owns error types and transport
//   DeckMateAuth    — AuthStore protocol, Keychain, biometric unlock
//   DeckMateKit     — umbrella that re-exports the three above
//
// Everything here is pure Swift (no UIKit/AppKit/SwiftUI) so it can be
// built and tested with `swift test` on a Mac without launching Xcode.

import PackageDescription

let package = Package(
    name: "DeckMateKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1),
        .watchOS(.v10),
    ],
    products: [
        .library(name: "DeckMateKit", targets: ["DeckMateKit"]),
        .library(name: "DeckMateModels", targets: ["DeckMateModels"]),
        .library(name: "DeckMateAPI", targets: ["DeckMateAPI"]),
        .library(name: "DeckMateAuth", targets: ["DeckMateAuth"]),
    ],
    dependencies: [
        // Intentionally empty — we stay on Apple frameworks in v0.1.
        // If we ever add one, propose it in an issue first (see CLAUDE.md).
    ],
    targets: [
        .target(
            name: "DeckMateModels",
            path: "Sources/DeckMateModels"
        ),
        .target(
            name: "DeckMateAuth",
            path: "Sources/DeckMateAuth"
        ),
        .target(
            name: "DeckMateAPI",
            dependencies: ["DeckMateModels", "DeckMateAuth"],
            path: "Sources/DeckMateAPI"
        ),
        .target(
            name: "DeckMateKit",
            dependencies: ["DeckMateModels", "DeckMateAPI", "DeckMateAuth"],
            path: "Sources/DeckMateKit"
        ),

        .testTarget(
            name: "DeckMateModelsTests",
            dependencies: ["DeckMateModels"],
            path: "Tests/DeckMateModelsTests"
        ),
        .testTarget(
            name: "DeckMateAPITests",
            dependencies: ["DeckMateAPI"],
            path: "Tests/DeckMateAPITests"
        ),
        .testTarget(
            name: "DeckMateAuthTests",
            dependencies: ["DeckMateAuth"],
            path: "Tests/DeckMateAuthTests"
        ),
        .testTarget(
            name: "DeckMateKitTests",
            dependencies: ["DeckMateKit"],
            path: "Tests/DeckMateKitTests"
        ),
    ]
)
