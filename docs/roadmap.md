# Roadmap & TODO

Checked items are complete.

---

## v0.1 — History browser + Live (in progress)

### Foundations
- [x] Repo structure, CLAUDE.md, skills, Swift package skeleton
- [x] `DeckMateKit` supports iOS 17 / macOS 14 / visionOS 1 / watchOS 10
- [ ] Xcode project + workspace created with `DeckMateiOS`, `DeckMateMac`,
      `DeckMateVision`, `DeckMateWatch` targets
- [ ] `DeckMateKit` added as a local package dependency to all four apps
- [ ] `swift build` and `swift test` green in CI

### Auth
- [ ] `AuthStore` / `Credential` / `ServerIdentity` wired into a SettingsView
- [ ] `KeychainStore` used to persist the token across launches
- [ ] Biometric gate (`LocalAuthentication`) wrapping the Keychain read
- [ ] Server-side: device-pairing endpoint (see `../helmlog` issue #423)

### History browser
- [ ] `HistoryViewModel` — fetch + cache session list
- [ ] `HistoryView` — iOS: list; Mac: `NavigationSplitView` sidebar
- [ ] `SessionDetailView` — stats, linked audio, linked video
- [ ] `TrackMapView` — MapKit `Map` + `MapPolyline` from `Track.ticks`
- [ ] Polar view — target BSP vs TWS/TWA chart
- [ ] Audio playback + transcript follow-along

### Live
- [ ] `APIClient.liveInstruments()` — `URLSessionWebSocketTask` implementation
- [ ] `LiveViewModel` — current tick, target boatspeed, connection state
- [ ] `LiveView` — big-type current numbers, portrait/landscape adapt
- [ ] Start/stop session controls
- [ ] Drop-mark button (iOS haptic + Mac ⌘M)
- [ ] Replay mode in `DeckMateAPI` — play a recorded JSONL of ticks

### Ship-gate
- [ ] First TestFlight build (iOS + Mac)
- [ ] Crew invited to TestFlight
- [ ] Feedback loop established

---

## v0.2 — Wrist control (watchOS)

- [ ] `SessionController` state machine in `DeckMateKit` (testable without a watch)
  - States: `idle → starting → running → stopping → idle`; errors as surfaced side-state
- [ ] `DeckMateAuth`: `#if !os(watchOS)` guards on `LocalAuthentication`; watchOS uses passcode-scoped Keychain
- [ ] `DeckMateWatch` app scaffold: `SessionView`, `MarksView`, one-tap mark drop with haptic
- [ ] Optimistic UI for mark drop: haptic → local counter bump → fire → reconcile on failure
- [ ] WidgetKit complication: "session running 01:23" with timeline provider
- [ ] Watch-only smoke test: start → drop 3 marks → stop, with airplane mode flipped mid-run
- [ ] TestFlight build for watchOS (independent upload, not companion)

---

## v0.3 — Immersive replay (visionOS)

- [ ] `ReplayViewModel` + `TickCursor` in `DeckMateKit` (playback state machine, time-indexed cursor)
- [ ] WGS84 → scene-space projection in `DeckMateKit` with unit tests (no RealityKit import)
- [ ] `DeckMateVision` app scaffold: 2D `WindowGroup` (session picker + scrubber) + `ImmersiveSpace` stub
- [ ] Track ribbon entity: extruded `MeshResource` coloured by speed-over-ground
- [ ] Wind-arrow entities: one per tick, orientation from TWD, length from TWS
- [ ] Mark entities: sphere anchors, labelled with the mark name
- [ ] Scrubber ↔ immersive scene sync via the shared `ReplayViewModel`
- [ ] `/data-license` review — embargo rendering + no-export affordances on peer sessions
- [ ] TestFlight build for visionOS

---

## v0.4 — Offline-friendly cache

- [ ] SwiftData schema for cached sessions + tracks
- [ ] Stale-while-revalidate in `HistoryViewModel`
- [ ] "Last synced at" indicator per screen

---

## Later — federation viewer

- [ ] Peer session list (view-only)
- [ ] Embargo-aware rendering (UI state, not silent omission)
- [ ] `/data-license` review sign-off before shipping

---

## Later — sign-in polish

- [ ] Sign in with Apple
- [ ] Multi-boat / multi-server switcher
- [ ] Transparent token refresh
