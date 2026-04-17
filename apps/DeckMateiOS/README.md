# DeckMateiOS

iPhone + iPad universal SwiftUI app target.

Placeholder until the Xcode project is created (see `../README.md`). Once
Xcode is set up, the folder layout inside this directory will be:

```
App/           # @main DeckMateiOSApp.swift, ContentView.swift
Features/      # History/, Live/, Settings/ — one subdir per feature
Resources/     # Assets.xcassets, Info.plist, entitlements
Tests/         # XCUITest target for critical flows
```

Keep business logic in `../../packages/DeckMateKit` — this target should
be almost entirely SwiftUI views and wiring.
