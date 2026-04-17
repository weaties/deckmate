# DeckMate

Native Apple clients (Mac, iPhone, iPad, Apple Vision Pro, Apple Watch)
for [HelmLog](../helmlog), the Raspberry-Pi sailing data logger.

## What's in the repo

```
deckmate/
├── DeckMate/                      # Xcode project — all app targets live here
│   ├── DeckMate.xcodeproj
│   ├── DeckMate/                  # main multiplatform target: iOS, iPad, macOS, visionOS
│   │   ├── DeckMateApp.swift      # @main entry point
│   │   ├── ContentView.swift
│   │   └── Assets.xcassets
│   └── DeckMateWatch/             # watchOS target (to be added) — separate process on the watch
├── packages/
│   └── DeckMateKit/               # Shared Swift package: models, API client, auth
├── docs/                          # Architecture, API notes, roadmap, platform design notes
├── .claude/skills/                # Workflow skills for Claude Code
├── CLAUDE.md                      # Claude Code conventions and skill index
└── AGENTS.md                      # Convention reference for any AI coding agent
```

Two Xcode targets cover all five destinations:

- **`DeckMate`** — one SwiftUI multiplatform target that builds for
  iPhone, iPad, Mac, and Apple Vision Pro. Platform-specific behaviour
  is gated with `#if os(iOS) / os(macOS) / os(visionOS)` inside shared
  files.
- **`DeckMateWatch`** — a separate target (watchOS apps must run their
  own process), independent from the phone. See
  `docs/watchos-design.md`.

## v0.1 scope

- **History browser** (iOS / Mac) — list sessions, replay tracks on MapKit, see polars and linked video
- **Live race view** (iOS / Mac) — TWS / TWA / BSP from Signal K; session start/stop; mark drops
- **Immersive replay** (visionOS) — past sessions replayed as a RealityKit scene. See `docs/visionos-design.md`.
- **Wrist control** (watchOS) — start/stop session, drop a mark with one tap. See `docs/watchos-design.md`.

## Getting started

```bash
# 1. Build + test the shared package (fast, no Xcode needed)
cd packages/DeckMateKit && swift build && swift test

# 2. Open the Xcode project
open DeckMate/DeckMate.xcodeproj
```

In Xcode the scheme destination picker lets you run the main target on
any of iPhone, iPad, My Mac, or Apple Vision Pro — all from the same
scheme. The watch target runs as its own scheme.

See `docs/architecture.md` for how the pieces fit together and
`CLAUDE.md` for project conventions.

## Relationship to the server

This client talks to the HelmLog server (sibling repo `../helmlog`) over HTTP
(+ a WebSocket for live data). The server's FastAPI routes under
`src/helmlog/routes/` are the source of truth for the API; see
`docs/api-endpoints.md` for the subset the client consumes and how to keep it
in sync.
