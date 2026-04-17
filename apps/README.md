# Apps

Four app targets live here:

- `DeckMateiOS/` — iPhone + iPad universal SwiftUI app
- `DeckMateMac/` — macOS SwiftUI app
- `DeckMateVision/` — visionOS app (immersive replay)
- `DeckMateWatch/` — watchOS app (session management; independent, not a phone companion)

All four are thin: the business logic lives in `../packages/DeckMateKit`.
Apps import `DeckMateKit` and render SwiftUI / RealityKit views around its
ViewModels.

## Creating the Xcode project (one time)

The `.xcodeproj` / `.xcworkspace` is created via the Xcode GUI rather than
generated from YAML — part of the goal of this repo is to learn how Xcode
project files are actually structured.

### Step 1 — iOS + Mac multiplatform target

1. **File → New → Project… → Multiplatform → App**
   - Product Name: `DeckMate`
   - Interface: SwiftUI
   - Language: Swift
   - Leave "Include Tests" checked
   - Save at the repo root (`/Users/dweatbrook/src/deckmate/`)
2. The wizard creates a multiplatform app target. Rename the iOS run
   destination to `DeckMateiOS` and the macOS run destination to
   `DeckMateMac` if Xcode distinguishes them.
3. **File → Add Package Dependencies… → Add Local…** and point at
   `packages/DeckMateKit`. Add `DeckMateKit` to each app target's frameworks.
4. Move the generated `ContentView.swift` etc. into `apps/DeckMateiOS/App/`
   and `apps/DeckMateMac/App/` respectively. (Xcode lets you drag files in
   the Project Navigator; make sure "Create folder references" is off so
   they stay as groups.)

### Step 2 — visionOS target

1. **File → New → Target… → visionOS → App**
   - Product Name: `DeckMateVision`
   - Interface: SwiftUI
   - Immersive Space Renderer: **RealityKit**
   - Immersive Space: **Mixed**
2. Add `DeckMateKit` to the new target's frameworks.
3. Move the generated Swift files into `apps/DeckMateVision/App/`.
4. In the generated `@main` app struct, keep the default `WindowGroup`
   (the 2D session picker) and the `ImmersiveSpace(id: "Replay")` stub —
   both will be wired to `ReplayViewModel` later.

### Step 3 — watchOS target

1. **File → New → Target… → watchOS → App**
   - Product Name: `DeckMateWatch`
   - Interface: SwiftUI
   - **Un-check** "Include Companion iOS App" — we are building a
     standalone watch app, not an iPhone companion.
2. Add `DeckMateKit` to the new target's frameworks.
3. Move the generated Swift files into `apps/DeckMateWatch/App/`.
4. Entitlements: enable `NSAppTransportSecurity` exceptions for your
   HelmLog server hostname if it's on a private network (Tailscale
   `*.ts.net` etc.), since watchOS is stricter than iOS about ATS.

### Step 4 — workspace

1. Create a `DeckMate.xcworkspace` that references the project and the
   package. (**File → New → Workspace…**, then drag the `.xcodeproj`
   and the `packages/DeckMateKit` folder into it.)
2. Commit `DeckMate.xcworkspace` (not `.xcuserdatad`) and the
   `.xcodeproj`. Our `.gitignore` already excludes user-specific state.

## Code layout inside each app

```
DeckMateiOS/  (same shape for DeckMateMac/)
├── App/                      # @main App entry, Scene setup
├── Features/
│   ├── History/              # HistoryView, HistoryViewModel wiring
│   ├── Live/                 # LiveView, LiveViewModel wiring
│   └── Settings/             # Server URL, auth
├── Resources/
│   ├── Assets.xcassets
│   ├── Info.plist
│   └── DeckMateiOS.entitlements
└── Tests/                    # XCUITest target (critical flows only)

DeckMateVision/
├── App/
├── Features/
│   ├── History/              # 2D window: session picker + scrubber
│   ├── Immersive/            # ImmersiveSpace + RealityKit entity hierarchy
│   └── Settings/
├── Resources/
└── Tests/

DeckMateWatch/
├── App/
├── Features/
│   ├── Session/              # start / stop / running-state view
│   ├── Marks/                # one-tap mark drop + haptic
│   └── Settings/
├── Complications/            # WidgetKit timelines
├── Resources/
└── Tests/
```

Keep code out of the Xcode target wherever possible — prefer adding it to
`DeckMateKit` where it can be `swift test`ed quickly.

## Signing and distribution

- Team: Apple Developer Program (set in Signing & Capabilities).
- Bundle IDs (confirm before first TestFlight submission):
  - `com.helmlog.deckmate.ios`
  - `com.helmlog.deckmate.mac`
  - `com.helmlog.deckmate.vision`
  - `com.helmlog.deckmate.watch`
- Distribution: TestFlight for all four platforms. Use the `/testflight`
  skill for the full archive → upload → release-notes workflow. Note: the
  watchOS binary, because it is standalone (not companion), uploads as its
  own record — it does not piggyback on the iOS build.
