# DeckMateWatch

Apple Watch (watchOS) app target — **session management from the wrist**.

Placeholder until the Xcode target is created (see `../README.md`). The
folder layout inside this directory will be:

```
App/           # @main DeckMateWatchApp.swift, scene setup
Features/
  Session/     # Start / stop / current-session status
  Marks/       # Drop a race mark with one tap (primary haptic action)
  Settings/    # Server URL, auth pairing
Resources/     # Assets.xcassets, Info.plist, entitlements
Complications/ # WidgetKit complications (e.g. "session running: 01:23")
Tests/         # XCUITest for start → mark → stop flow
```

## Architecture: independent, not companion

v0.1 watch app is **independent** — it talks directly to the HelmLog
server over wifi / cellular, using the same `DeckMateAPI.APIClient` as
every other target. No WatchConnectivity dependency on the iPhone app.

Why:

- A sailor may carry only the watch on deck; the phone is often below.
- Independent watch apps are simpler — no paired-phone state machine,
  no `WCSession` reachability dance, no foreground-only delivery rules.
- The same `DeckMateKit` view-models run here unchanged.

When we later add photo / audio capture (which the watch can't do
solo), *that* feature will optionally use WatchConnectivity to hand off
to the phone — but session management doesn't need it.

## What lives where

- **DeckMateKit** (testable) — `SessionController` with the state
  machine `idle → starting → running → stopping → idle` and
  `dropMark()`; `APIClient` mutations for `POST /sessions/{id}/marks`.
- **This target** — wrist-sized SwiftUI views, Digital Crown scrubbing,
  haptics on mark-drop (use `WKInterfaceDevice.current().play(.click)`
  or `.success`), complication timelines.

## Things to watch

- **No `LocalAuthentication` on watchOS.** Biometric gating of the
  Keychain relies on `LAContext`, which isn't on the watch. Gate the
  token read on device passcode / wrist-detection instead
  (`kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`). `DeckMateAuth`
  will need a `#if os(watchOS)` branch when we add biometrics.
- **Storage is tight.** Don't ship track caches or video on the watch —
  session list metadata only. Heavy cache stays on iPhone / iPad.
- **Mark-drop latency matters.** The flow is "tap → haptic → request
  fires → optimistic UI update". Don't block the tap on the network
  round-trip; enqueue, confirm, and reconcile on failure.
- **Battery.** Don't keep a WebSocket open on the watch during races.
  Poll session state on foreground / complication refresh only.
