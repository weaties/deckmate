# Apps

Two app targets live here:

- `DeckMateiOS/` — iPhone + iPad universal SwiftUI app
- `DeckMateMac/` — macOS SwiftUI app

Both are thin: the business logic lives in `../packages/DeckMateKit`. Apps
import `DeckMateKit` and render SwiftUI views around its ViewModels.

## Creating the Xcode project (one time)

The `.xcodeproj` / `.xcworkspace` is created via the Xcode GUI rather than
generated from YAML — part of the goal of this repo is to learn how Xcode
project files are actually structured. Once:

1. **File → New → Project… → Multiplatform → App**
   - Product Name: `DeckMate`
   - Interface: SwiftUI
   - Language: Swift
   - Leave "Include Tests" checked
   - Save at the repo root (`/Users/dweatbrook/src/deckmate/`)
2. The wizard creates a multiplatform app target. Rename the iOS run
   destination to `DeckMateiOS` and the macOS run destination to
   `DeckMateMac` if Xcode distinguishes them.
3. **File → Add Package Dependency… → Add Local…** and point at
   `packages/DeckMateKit`. Add `DeckMateKit` to each app target's frameworks.
4. Move the generated `ContentView.swift` etc. into `apps/DeckMateiOS/App/`
   and `apps/DeckMateMac/App/` respectively. (Xcode lets you drag files in
   the Project Navigator; make sure "Create folder references" is off so
   they stay as groups.)
5. Create a `DeckMate.xcworkspace` that references both the project
   and the package. (**File → New → Workspace…**, then drag the project
   and the package into it.)
6. Commit `DeckMate.xcworkspace` (not `.xcuserdatad`) and the
   `.xcodeproj`. Our `.gitignore` already excludes user-specific state.

## Code layout inside each app

```
DeckMateiOS/ (same shape for DeckMateMac/)
├── App/                    # @main App entry, Scene setup
├── Features/
│   ├── History/            # HistoryView, HistoryViewModel wiring
│   ├── Live/               # LiveView, LiveViewModel wiring
│   └── Settings/           # Server URL, auth
├── Resources/
│   ├── Assets.xcassets
│   ├── Info.plist
│   └── DeckMateiOS.entitlements
└── Tests/                  # XCUITest target (critical flows only)
```

Keep code out of the Xcode target wherever possible — prefer adding it to
`DeckMateKit` where it can be `swift test`ed quickly.

## Signing and distribution

- Team: Apple Developer Program (set in Signing & Capabilities).
- Bundle IDs: `com.helmlog.deckmate.ios` and `com.helmlog.deckmate.mac` (confirm before
  first TestFlight submission).
- Distribution: TestFlight. Use the `/testflight` skill for the full
  archive → upload → release-notes workflow.
