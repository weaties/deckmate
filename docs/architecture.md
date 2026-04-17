# Architecture

## The big picture

```
┌──────────────────────────────────────────────┐   HTTPS / WS   ┌───────────────────────┐
│  Apps (skin)                                 │ ─────────────▶ │  HelmLog server       │
│  DeckMateiOS      DeckMateVision (visionOS)   │                │  (../helmlog, Pi)     │
│  DeckMateMac      DeckMateWatch   (watchOS)   │                │  FastAPI + SQLite     │
└──────────────────────┬───────────────────────┘                └───────────────────────┘
                       │ imports
                       ▼
┌─────────────────────────────────────────┐
│  packages/DeckMateKit (the brain)        │
│                                          │
│  ┌──────────────┐  ┌───────────────┐   │
│  │ DeckMateModels│  │ DeckMateAuth   │   │
│  └──────┬───────┘  └──────┬────────┘   │
│         │                 │             │
│         ▼                 ▼             │
│        ┌──────────────────┐              │
│        │  DeckMateAPI       │              │
│        │  (URLSession +    │              │
│        │   WebSocket)      │              │
│        └──────────────────┘              │
└─────────────────────────────────────────┘
```

All four apps talk to the server directly. The watch is **independent**,
not a companion — it does not rely on WatchConnectivity or on the iPhone
app being reachable.

### Apps (thin)

Four app targets, all calling into `DeckMateKit` for behaviour and using
it for state:

- **DeckMateiOS** — iPhone + iPad, primary everyday surface (history + live).
- **DeckMateMac** — desktop debriefs; bigger windows, split view.
- **DeckMateVision** — Apple Vision Pro. 2D window for session picker +
  scrubber, plus an `ImmersiveSpace` that renders the session as a
  RealityKit scene (track ribbon, wind arrows, marks in world space).
- **DeckMateWatch** — Apple Watch, standalone. Start / stop sessions and
  drop race marks from the wrist; no map, no live numbers (screen too
  small, battery too precious).

Each target contains SwiftUI views, asset catalogs, `Info.plist`,
entitlements, and the `@main` App type. They import `DeckMateKit` and
instantiate view-model types from it. No networking or keychain code
lives here.

### DeckMateKit (thick)

Shared Swift package, split into focused modules:

- **DeckMateModels** — `Codable` domain types (`Session`, `Track`,
  `InstrumentTick`, `Polar`, …) plus the shared `DeckMateJSON` decoder /
  encoder tuned for the server's snake-case + ISO-8601 output. Fixture
  JSON in `Tests/.../Fixtures/` comes from real server responses.
- **DeckMateAuth** — the `AuthStore` protocol and current implementations.
  v0.1 ships `BearerTokenAuthStore` and a `KeychainStore` helper. Later,
  biometric gating (`LocalAuthentication`), Sign in with Apple, and
  device-pairing flows slot in behind the same protocol.
- **DeckMateAPI** — `URLSession`-based `APIClient` with typed `APIError`,
  and an `AsyncThrowingStream<InstrumentTick, Error>` for the live live
  feed. Transport is overridable so tests can inject a `URLProtocol` stub.
- **DeckMateKit** — umbrella that re-exports the three above for apps.

### Server (authoritative)

The client reads from and posts to the HelmLog server (sibling repo
`../helmlog`). That server is the source of truth for sessions, tracks,
polars, users, and auth. See `api-endpoints.md` for the specific routes
we consume.

## Why this shape

- **Fast TDD loop.** Everything in `DeckMateKit` builds and tests in a
  couple of seconds via `swift test`. We only open Xcode for UI work.
- **Pluggable auth.** Auth mechanisms will change (magic link → Sign in
  with Apple → biometric-gated bearer token). The `AuthStore` protocol
  means views never care which one is active.
- **Four apps, one brain.** iOS / macOS / visionOS / watchOS targets
  differ wildly in UI idiom (tab bar, split view, `ImmersiveSpace`, wrist
  list) but consume identical view-model state. Move anything shareable
  into `DeckMateKit`. When a platform can't support an API, the kit
  `#if os(...)`-guards the platform-specific bits instead of forcing the
  app to know.

## SwiftUI layering

Each feature screen comes in three pieces:

1. **Model type** (in `DeckMateKit`) — plain `struct` or `actor` with state
   and pure methods. Tests are XCTest.
2. **SwiftUI `View`** (in `apps/…/Features/…`) — observes the model type
   via `@State` + `@Observable`, renders state, fires intents.
3. **Preview** — `#Preview` with seeded fixture data covering loading,
   loaded, and error states.

## Live-data flow (live)

```
    HelmLog server (../helmlog)
    ────────────────────────────
      /ws/instruments  (WebSocket relaying Signal K deltas)
                 │
                 ▼
    DeckMateAPI.liveInstruments()
      → AsyncThrowingStream<InstrumentTick, Error>
                 │
                 ▼
    LiveViewModel (@Observable)
      .latestTick, .connectionState, .lastError
                 │
                 ▼
    LiveView (SwiftUI)
```

The transport is an implementation detail. When we swap the WebSocket for
a different protocol, only `DeckMateAPI.liveInstruments()` changes.

## On-device persistence (cache)

Non-secret cache (last known session list, last polar, last settled
position) uses **SwiftData** or a `Codable` JSON blob under
`FileManager.default.urls(for: .cachesDirectory, …)`. Secrets (bearer
tokens) live only in the Keychain via `DeckMateAuth.KeychainStore`.

The cache is a hint, not a source of truth — every screen refreshes from
the server when it appears, and shows the cached data in the meantime.

## Immersive replay (visionOS)

The visionOS target runs two scenes side-by-side:

- A **2D `WindowGroup`** with the session picker, time scrubber, and
  play / pause controls — normal SwiftUI, no different from iPad.
- An **`ImmersiveSpace`** (`.mixed` style) hosting a RealityKit `Entity`
  tree: the track as an extruded polyline anchored to a bounded volume,
  wind arrows attached to each tick sample, and marks as sphere anchors.

The window's `ReplayViewModel` (in `DeckMateKit`) owns playback state and
publishes a `TickCursor` that both the 2D chrome and the RealityKit
entities observe. The visionOS target itself contains only the
`RealityView`, entity construction, and gesture handlers.

**Coordinate system:** the kit projects WGS84 (lat, lon) to scene-space
metres with the session's bounding-box centroid as the origin, so
RealityKit never sees numbers with planetary magnitudes. This is pure
Swift maths — fully unit-testable, no RealityKit dependency.

## Session management (watchOS)

The watch target is intentionally narrow: start a session, stop a
session, drop a race mark. It uses:

- `SessionController` (in `DeckMateKit`) — a state machine
  `idle → starting → running → stopping → idle` wrapping the same
  `APIClient` mutations as the iOS live view.
- **Optimistic UI.** Mark-drop plays a haptic, updates the counter
  instantly, and fires the request. On failure, a retry row appears at
  the top of the list — the mark is not silently lost.
- **Polling, not WebSockets.** Foreground and complication refreshes
  poll the session's status. Keeping a socket open during a race would
  eat the battery.
- **No `LocalAuthentication`.** `DeckMateAuth`'s biometric gate is
  `#if !os(watchOS)`; on watch we rely on device-passcode-scoped
  Keychain access and wrist-detection.
