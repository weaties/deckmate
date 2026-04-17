# DeckMate

Native Apple clients (Mac, iPhone, iPad) for [HelmLog](../helmlog), the
Raspberry-Pi sailing data logger.

## What's in the repo

```
deckmate/
├── apps/
│   ├── DeckMateiOS/      # iPhone + iPad universal app target
│   └── DeckMateMac/      # macOS app target
├── packages/
│   └── DeckMateKit/      # Shared Swift package: models, API client, auth
├── docs/                # Architecture, API notes, roadmap
├── .claude/skills/      # Workflow skills for Claude Code
├── CLAUDE.md            # Claude Code conventions and skill index
└── AGENTS.md            # Convention reference for any AI coding agent
```

## v0.1 scope

- **History browser** — list sessions, replay tracks on MapKit, see polars and linked video
- **Live race view** — TWS / TWA / BSP from Signal K; session start/stop; mark drops

## Getting started

```bash
# 1. Build the shared package (works without Xcode)
cd packages/DeckMateKit && swift build && swift test

# 2. Open the workspace in Xcode (create it once — see apps/README.md)
open DeckMate.xcworkspace
```

See `docs/architecture.md` for how the pieces fit together and
`CLAUDE.md` for project conventions.

## Relationship to the server

This client talks to the HelmLog server (sibling repo `../helmlog`) over HTTP
(+ a WebSocket for live data). The server's FastAPI routes under
`src/helmlog/routes/` are the source of truth for the API; see
`docs/api-endpoints.md` for the subset the client consumes and how to keep it
in sync.
