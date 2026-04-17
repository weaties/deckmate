# Roadmap & TODO

Checked items are complete.

---

## v0.1 — History browser + Live (in progress)

### Foundations
- [x] Repo structure, CLAUDE.md, skills, Swift package skeleton
- [ ] Xcode project + workspace created with `DeckMateiOS`, `DeckMateMac` targets
- [ ] `DeckMateKit` added as a local package dependency to both apps
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
- [ ] First TestFlight build (both iOS and Mac)
- [ ] Crew invited to TestFlight
- [ ] Feedback loop established

---

## v0.2 — Offline-friendly cache

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
