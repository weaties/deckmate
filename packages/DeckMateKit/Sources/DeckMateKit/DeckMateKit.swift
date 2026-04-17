// DeckMateKit — umbrella module.
//
// Re-exports the three focused modules so apps can write a single
// `import DeckMateKit` and get models + API + auth in scope.
//
// If you're browsing the package, start in DeckMateModels (types), then
// DeckMateAPI (how we call the server), then DeckMateAuth (credentials).

@_exported import DeckMateAPI
@_exported import DeckMateAuth
@_exported import DeckMateModels

/// Version of the client library. Bump when publishing a TestFlight build
/// that changes the API contract or on-device schema.
public enum DeckMateKitVersion {
    public static let current: String = "0.1.0-dev"
}
