# watchOS — Session management from the wrist

Design notes for the Apple Watch app. Unlike iOS / macOS / visionOS,
watchOS **always requires its own Xcode target** — the watch runs a
separate process on a separate device. The target lives inside the same
`DeckMate.xcodeproj` as the main multiplatform target, under the folder
`DeckMate/DeckMateWatch/`.

## Architecture: independent, not companion

v0.1 watch app is **independent** — it talks directly to the HelmLog
server over wifi / cellular, using the same `DeckMateAPI.APIClient` as
the main target. No `WatchConnectivity` dependency on the iPhone app.

Why:

- A sailor may carry only the watch on deck; the phone is often below.
- Independent watch apps are simpler — no paired-phone state machine,
  no `WCSession` reachability dance, no foreground-only delivery rules.
- The same `DeckMateKit` view-models run here unchanged.

When we later add photo / audio capture (which the watch can't do
solo), *that* feature will optionally use `WatchConnectivity` to hand
off to the phone — but session management doesn't need it.

## Target shape

```
DeckMate/DeckMateWatch/
├── DeckMateWatchApp.swift     # @main, scene setup
├── Features/
│   ├── SessionView.swift      # Start / stop / running-state
│   ├── MarksView.swift        # One-tap mark drop with haptic
│   └── SettingsView.swift     # Server URL, auth pairing
├── Complications/             # WidgetKit timelines
└── Assets.xcassets            # Watch-sized icon and complication assets
```

## What lives where

- **`DeckMateKit`** (testable) — `SessionController` with the state
  machine `idle → starting → running → stopping → idle` and `dropMark()`;
  `APIClient` mutations for `POST /sessions/{id}/marks`.
- **This target** — wrist-sized SwiftUI views, Digital Crown scrubbing,
  haptics on mark-drop (`WKInterfaceDevice.current().play(.click)` or
  `.success`), complication timelines.

## Things to watch

- **No `LocalAuthentication` on watchOS.** Biometric gating of the
  Keychain relies on `LAContext`, which isn't on the watch. Gate the
  token read on device passcode / wrist-detection instead
  (`kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`). `DeckMateAuth`
  will need a `#if !os(watchOS)` branch when we add biometrics.
- **Storage is tight.** Don't ship track caches or video on the watch —
  session list metadata only. Heavy cache stays on iPhone / iPad.
- **Mark-drop latency matters.** The flow is "tap → haptic → request
  fires → optimistic UI update". Don't block the tap on the network
  round-trip; enqueue, confirm, and reconcile on failure.
- **Battery.** Don't keep a WebSocket open on the watch during races.
  Poll session state on foreground / complication refresh only.
- **ATS.** watchOS is stricter than iOS about App Transport Security.
  If the HelmLog server is on a private network (Tailscale `*.ts.net`,
  etc.), expect to configure `NSAppTransportSecurity` exceptions in the
  watch target's `Info.plist`.
