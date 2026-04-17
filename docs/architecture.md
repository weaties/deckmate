# Architecture

## The big picture

```
┌─────────────────┐   HTTPS / WS    ┌───────────────────────┐
│  Apps (skin)    │ ──────────────▶ │  HelmLog server       │
│  DeckMateiOS     │                 │  (../helmlog, Pi)     │
│  DeckMateMac     │                 │  FastAPI + SQLite     │
└────────┬────────┘                 └───────────────────────┘
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

### Apps (thin)

`apps/DeckMateiOS` and `apps/DeckMateMac` contain SwiftUI views, asset
catalogs, `Info.plist`, entitlements, and the `@main` App type. They
import `DeckMateKit` and instantiate view-model types from it. No
networking or keychain code lives here.

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
- **Two apps, one brain.** The macOS and iOS apps differ in UI idiom
  (split view vs. tab bar) but consume identical view-model state. Move
  anything shareable into `DeckMateKit`.

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
