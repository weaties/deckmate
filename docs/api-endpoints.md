# API endpoints consumed by the client

The HelmLog server (`../helmlog`) is the source of truth. This document
summarises the routes the client depends on and how we keep the two in
sync. When adding a new endpoint: run `/api-client` to generate a Swift
wrapper + Codable model from the server route, then add fixture JSON to
`Tests/DeckMateModelsTests/Fixtures/`.

## Auth-adjacent

| Method | Path | Purpose | Server file |
|---|---|---|---|
| `POST` | `/auth/device/pair` (planned) | Exchange a pairing code for a bearer token | `src/helmlog/auth.py` (#423 extension) |
| `POST` | `/auth/logout` | Invalidate the current bearer | `routes/auth.py` |
| `GET`  | `/api/me` | Current user + role | `routes/me.py` |

v0.1 can live with magic-link cookie auth during development. The
client-side `AuthStore` abstraction means we can move to bearer-token
or Sign in with Apple without rewriting callers.

## History browser

| Method | Path | Purpose | Server file |
|---|---|---|---|
| `GET` | `/api/sessions` | List sessions for the logged-in boat | `routes/sessions.py` |
| `GET` | `/api/sessions/{id}` | One session's metadata | `routes/sessions.py` |
| `GET` | `/api/sessions/{id}/track` | Full instrument time series | `routes/sessions.py` |
| `GET` | `/api/sessions/{id}/audio` | Debrief audio clip(s) + transcript | `routes/audio.py` |
| `GET` | `/api/sessions/{id}/videos` | Linked Insta360 / YouTube references | `routes/videos.py` |
| `GET` | `/api/polar` | Current polar baseline for the boat | `routes/polar.py` |
| `GET` | `/api/races` | Race metadata / names / results | `routes/races.py` |

## Live (live race-day)

| Method | Path | Purpose | Server file |
|---|---|---|---|
| `WS`   | `/ws/instruments` | Live Signal K deltas relayed as InstrumentTick | `routes/ws.py` |
| `POST` | `/api/sessions/start` | Start a race/practice session | `routes/sessions.py` |
| `POST` | `/api/sessions/{id}/stop` | End a session | `routes/sessions.py` |
| `POST` | `/api/marks` | Drop a mark at current GPS | `routes/races.py` |

## Federation (deferred past v0.1)

| Method | Path | Purpose | Server file |
|---|---|---|---|
| `GET` | `/peer/sessions` | Co-op peer sessions (view-only!) | `routes/federation.py`, `peer_api.py` |
| `GET` | `/peer/tracks/{id}` | Peer track (respect embargo) | same |

> The client **must not** surface export/share/copy affordances for peer
> data. See `../helmlog/docs/data-licensing.md` and the `/data-license` skill.

## Keeping Codable models in sync

- Field names in `DeckMateModels` must match server JSON keys after
  snake-case conversion. If the server renames a column, add a
  `CodingKeys` mapping in the Swift type rather than renaming the Swift
  property (so SwiftUI / call sites don't churn).
- When a server PR changes an endpoint response shape, capture the new
  response into `Tests/DeckMateModelsTests/Fixtures/` and land the matching
  client PR in the same release window.
- The `/api-client` skill automates the scaffold for a new endpoint.
