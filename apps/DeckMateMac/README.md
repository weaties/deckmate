# DeckMateMac

Native macOS SwiftUI app target.

Placeholder until the Xcode project is created (see `../README.md`). Once
Xcode is set up, the folder layout inside this directory will be:

```
App/           # @main DeckMateMacApp.swift, MainWindowView.swift
Features/      # shared feature views where possible; Mac-specific where not
Resources/     # Assets.xcassets, Info.plist, entitlements
Tests/         # XCUITest target for critical flows
```

Mac-specific affordances to expect:

- A multi-column `NavigationSplitView` (sidebar / sessions list / detail).
- Menu bar commands for Start / Stop session, Drop mark.
- Keyboard shortcuts for the live view (e.g. ⌘M to drop mark).
- `Window { }`-scoped scenes rather than `WindowGroup { }` where the UX
  is inherently single-window.
