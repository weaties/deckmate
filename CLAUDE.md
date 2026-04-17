# CLAUDE.md — DeckMate

## Project Overview

Native Apple clients — **Mac, iPhone, iPad** — for [HelmLog](../helmlog), a
Raspberry-Pi sailing data logger. The server (`../helmlog`) captures Signal K
/ NMEA 2000 instrument data, stores it in SQLite, and exposes a FastAPI API;
this repo is the client that talks to it.

v0.1 is two complementary surfaces in one app:

1. **History browser** — list sessions, replay tracks on MapKit, show polars
   and linked video, scrub debrief audio and transcripts.
2. **Live race view** — live TWS / TWA / BSP / SOG / COG from the boat's
   Signal K WebSocket (via a HelmLog relay endpoint); start/stop sessions;
   drop race marks with one tap.

This project is also deliberately a **learning exercise** for the author to
get familiar with native Apple development (Swift, SwiftUI, Xcode, Swift
Package Manager, TestFlight). Skeletons in this repo are instructive on
purpose — they compile and run, but leave concrete behaviour for the author
to fill in as they learn the stack.

---

## Stack & Tooling

| Concern | Tool |
|---|---|
| Language | **Swift 5.10+** (Swift 6 language mode once Xcode ships default) |
| UI framework | **SwiftUI** (UIKit / AppKit only where SwiftUI can't reach) |
| Concurrency | `async`/`await`, `Task`, `AsyncStream` — **no** Combine unless unavoidable |
| Package manager | **Swift Package Manager** (`packages/DeckMateKit/Package.swift`) |
| App build system | **Xcode** project at repo root (workspace references the SPM package) |
| Dependency injection | Constructor injection; `@Environment` for SwiftUI composition |
| Local persistence | `SwiftData` (preferred) or file-backed `Codable` JSON for small caches |
| Maps | **MapKit** (`Map`, `MapPolyline`) — tracks rendered as `MKPolyline` overlays |
| Keychain | `Security.framework` via a thin `KeychainStore` wrapper (in `DeckMateAuth`) |
| Biometrics | `LocalAuthentication` (Face ID / Touch ID) — for unlocking stored credentials |
| HTTP | `URLSession` with `async`/`await` — no Alamofire |
| WebSocket | `URLSessionWebSocketTask` — used for the live Signal K relay |
| JSON | `Codable` with custom `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase` |
| Logging | **`os.Logger`** (subsystem `com.helmlog.deckmate`) — never `print()` in shipping code |
| Testing | **`XCTest`** + **Swift Testing** (`@Test`) for new suites; `XCUITest` for critical UI flows |
| Linting | **SwiftLint** (strict), invoked as an Xcode build phase |
| Formatting | **swift-format** (Apple's) — enforced via pre-commit hook |
| Distribution | **TestFlight** (Apple Developer Team account) |
| Bundle ID prefix | `com.helmlog.*` (confirm before first TestFlight submission) |

---

## Project Structure

```
deckmate/
├── CLAUDE.md                  # this file
├── AGENTS.md                  # convention reference for any AI agent
├── README.md
├── .gitignore
│
├── apps/                      # app targets (thin; business logic lives in DeckMateKit)
│   ├── DeckMateiOS/            # iPhone + iPad universal SwiftUI app
│   │   ├── App/               # @main App, SceneDelegate-equivalent
│   │   ├── Features/          # feature-organised screens (History/, Live/, Settings/)
│   │   ├── Resources/         # Assets.xcassets, Info.plist, entitlements
│   │   └── README.md
│   └── DeckMateMac/            # macOS app (shares Features/ via Swift package where possible)
│       ├── App/
│       ├── Features/
│       ├── Resources/
│       └── README.md
│
├── packages/
│   └── DeckMateKit/            # the shared Swift package — most of the code lives here
│       ├── Package.swift
│       ├── Sources/
│       │   ├── DeckMateKit/        # umbrella module — re-exports Models/API/Auth
│       │   ├── DeckMateModels/     # Codable domain models (Session, Track, Polar, …)
│       │   ├── DeckMateAPI/        # URLSession-based API client + error types
│       │   └── DeckMateAuth/       # AuthStore protocol, Keychain, biometric unlock
│       └── Tests/
│           ├── DeckMateModelsTests/
│           ├── DeckMateAPITests/
│           └── DeckMateAuthTests/
│
├── docs/
│   ├── architecture.md        # how apps/, DeckMateKit, and the server fit together
│   ├── api-endpoints.md       # the server routes the client consumes
│   └── roadmap.md
│
└── .claude/
    └── skills/
        ├── tdd-swift.md
        ├── new-screen.md
        ├── new-kit-module.md
        ├── api-client.md
        ├── architecture.md
        ├── domain.md
        ├── data-license.md
        ├── pr-checklist.md
        ├── spec.md
        └── testflight.md
```

> **Xcode project:** the `.xcodeproj` / `.xcworkspace` is created once via Xcode
> GUI (see `apps/README.md`). We intentionally don't generate it from YAML —
> part of the goal is to learn how Xcode project files are actually structured.

---

## Common Commands

```bash
# Swift package (works without Xcode — great for CI and quick TDD loops)
cd packages/DeckMateKit
swift build                    # compile package
swift test                     # run all XCTest / Swift Testing suites
swift test --filter DeckMateModelsTests  # target one module

# Xcode
open DeckMate.xcworkspace # open the project
xcodebuild -workspace DeckMate.xcworkspace \
           -scheme DeckMateiOS -destination 'platform=iOS Simulator,name=iPhone 15' \
           build test          # headless build + test

# Lint / format
swiftlint                      # check
swiftlint --fix                # auto-fix safe rules
swift-format format -i -r apps packages    # format in place
swift-format lint  -r apps packages        # format check (CI)
```

---

## Development Workflow

### One-time Mac setup

```bash
# Xcode (App Store — needs to match the iOS SDK you're targeting)
# Then Xcode command-line tools
xcode-select --install

# Linters / formatters
brew install swiftlint swift-format

# Open the package to prime SourceKit indexing
open -a Xcode packages/DeckMateKit/Package.swift
```

### Daily dev loop — TDD

Follow TDD (see `/tdd-swift`): write a failing test first, then implement.
For pure model/API/auth logic, iterate inside `packages/DeckMateKit` with
`swift test` — it's fast and doesn't need a simulator. For UI work, use
Xcode's preview + `XCUITest` for critical flows only.

```bash
swift test                   # package tests green
swiftlint                    # lint clean
swift-format lint -r apps packages   # format clean
xcodebuild ... build test    # full app build + tests (before PR)
```

### Issue → PR workflow

Mirror the helmlog conventions:

1. Mark the issue in progress and branch off `main`:
   ```bash
   gh issue edit <N> --add-label "in-progress"
   gh issue comment <N> --body "In progress on \`<branch>\` (Claude Code on <host>)"
   git checkout -b feature/my-feature main
   ```
2. Develop with TDD until `swift test`, `swiftlint`, `swift-format lint`, and the
   Xcode build + test all pass.
3. Push and open a PR with `Closes #N` in the body so the issue auto-closes:
   ```bash
   git push -u origin feature/my-feature
   gh pr create --title "..." --body "$(cat <<'EOF'
   ## Summary
   ...

   Closes #<issue>

   Generated with [Claude Code](https://claude.ai/code)
   EOF
   )"
   ```
4. After merge, remove `in-progress` if it wasn't cleared automatically.

**All changes to `main` come through merged PRs.** Never push directly to `main`.

### Environment & configuration

Client configuration is small: the server base URL, a bearer token (or a
reference to a keychain-stored credential), and a Tailscale hint. Store
these in a user-visible Settings screen backed by `UserDefaults` for
non-secret preferences and Keychain for credentials.

Never commit signing assets, `.env`, `.mobileprovision`, or `AuthKey_*.p8`.

---

## Coding Conventions

- **Swift 5.10+**, Swift 6 language mode once it ships in the default Xcode.
  Use `@MainActor`, `Sendable`, actor isolation where it helps.
- **`async`/`await` everywhere** — new async code should never reach for
  `DispatchQueue` or `Combine` pipelines. Use `AsyncStream` for push data.
- **Explicit types at module boundaries.** `let x: Int` in public API even when
  inference works, for readability. Private locals can elide the type.
- **SwiftUI first.** Use UIKit/AppKit only when the SwiftUI equivalent is
  missing or obviously worse (e.g., complex AVKit video integration).
- **`os.Logger`** for all logging; one subsystem per module
  (`com.helmlog.deckmate.api`, `…auth`, `…ui`). Never `print()` outside tests.
- **`Codable` structs**, not dictionaries, for anything crossing a boundary.
  Use `@CodingKeys` and/or snake-case key decoding strategy.
- **No force-unwraps in shipping code** except when the invariant is
  documented one line above (rare — prefer a `guard` with a logged failure).
- **Files stay small.** If a SwiftUI view or a manager type grows past
  ~250 lines, split it. Big files are a smell, not a goal.
- **Hardware-flavoured code is isolated** (mirroring helmlog): any module
  that touches the Keychain, biometrics, the network, or the WebSocket relay
  is testable with a protocol and a fake.

---

## Architecture Principles

- **DeckMateKit is the brain; apps are the skin.** Every feature is a pair:
  a ViewModel-like type in the package (testable without a simulator) and a
  SwiftUI `View` in the app that renders it. Apps should contain almost no
  business logic.
- **One source of truth per screen.** ViewModels expose `@Published` (or
  `@Observable` with Swift 5.9+) state; views are projections. Views never
  reach into `URLSession` directly.
- **Server data is read, never mutated locally.** The server (`../helmlog`) is
  authoritative. The client may cache data (SwiftData), but any mutation —
  starting a session, dropping a mark — goes through the API.
- **Timestamps are UTC at the boundary.** The server returns UTC; convert to
  the user's `TimeZone` only at display time, never on the way in.
- **The live data stream is pull-modelled as `AsyncStream<InstrumentTick>`.**
  `DeckMateAPI.liveInstruments()` hides whether it's a WebSocket, long-poll, or
  SSE — and whether we're hitting Signal K directly or via a HelmLog relay.
  Screens consume the stream; they don't know the transport.
- **Auth is pluggable.** `AuthStore` is a protocol in `DeckMateAuth`. The v0.1
  implementation is a simple bearer token stored in the Keychain, optionally
  gated by biometrics. `SignInWithAppleAuthStore`, `MagicLinkAuthStore`, and
  `DevicePairingAuthStore` all slot in behind the same protocol.

---

## Relationship to the HelmLog Server

The server is the source of truth. Before adding a client feature, check:

- `../helmlog/src/helmlog/routes/*.py` — the FastAPI router files define the
  API surface. Match field names exactly in Codable models. Run
  `/api-client` to generate a Swift client from a route.
- `../helmlog/src/helmlog/auth.py` — the user/role model, device bearer
  tokens (#423), and invitation flow. Client auth extends this.
- `../helmlog/src/helmlog/storage.py` — SQLite schema (v50+). JSON fields
  returned by the API usually reflect column names.
- `../helmlog/docs/data-licensing.md` — the policy that binds both sides.
  Co-op / peer data is view-only; the client must enforce this in UI (no
  "Export" button on peer data).
- `../helmlog/docs/federation-design.md` — peer API, embargo windows.

When the server API changes in a PR on that repo, an equivalent client PR
should land in the same release window.

---

## Data Licensing Policy (binding)

The data licensing policy at `../helmlog/docs/data-licensing.md` applies
equally to the client. Key UI constraints:

- **Boat owns its data** — never hide, gate, or strip the "Export" action
  for the logged-in boat's own sessions.
- **PII categories** — audio, photos, emails, biometrics, diarised
  transcripts have deletion and anonymisation rights. The client must
  surface a "Delete" action anywhere it displays them.
- **Co-op data is view-only** — peer sessions must not have any "Export",
  "Share", or "Copy full track" affordance. Display only.
- **Temporal sharing / embargo** — before rendering a peer session, check
  `embargo_until` and show a clear "embargoed until T" state instead of
  the data. Never silently show partial data.
- **Gambling prohibition** — no feature may facilitate betting or wagering
  use of co-op data.
- **Protest firewall** — do not build export formats for co-op data
  designed for protest-committee submission.
- **Biometric data** — requires per-person consent separate from instrument
  data. Coaches need separate authorisation; "boat owner agreed" does not
  transitively authorise.

Run `/data-license` before shipping any screen that shows peer or
co-op data.

---

## Dos and Don'ts

**Do:**

- **All changes to `main` come through merged PRs.** Never push directly.
- Include `Closes #N` in PR bodies so issues auto-close.
- Apply the `in-progress` label when starting work on an issue.
- Follow TDD — `swift test` loop inside `DeckMateKit` first; UI after.
- Run `swiftlint`, `swift-format lint`, and the Xcode build+test before opening a PR.
- Keep `apps/*` thin — move logic into `DeckMateKit` unless it is inherently
  view-shaped (animation, layout, gesture).
- Log with `os.Logger`, one subsystem per module.
- Use `Codable` for every type that crosses an API or persistence boundary.
- Store secrets in the Keychain via `DeckMateAuth.KeychainStore` — never in
  `UserDefaults` or plist.
- Check `../helmlog/src/helmlog/routes/` when you suspect API drift.

**Don't:**

- Don't push to `main`. Ever.
- Don't use `print()` for operational output; use `os.Logger`.
- Don't pull in a third-party dependency without proposing it in an issue
  first — we are trying to stay close to Apple frameworks on purpose.
- Don't put business logic in `apps/` that should live in `DeckMateKit`.
- Don't call `URLSession` from a SwiftUI view; go through an `APIClient`.
- Don't render peer (co-op) data with export affordances — violates policy.
- Don't force-unwrap (`!`) in shipping code without a documented invariant.
- Don't commit `.mobileprovision`, `AuthKey_*.p8`, or any `.env`.
- Don't ship `@MainActor` drift — if you declare an actor type, keep UI
  interactions hopping onto `@MainActor` at the view boundary.

---

## Testing Strategy

### Unit tests — `packages/DeckMateKit/Tests/`

Run with `swift test` in ~1-2 s. No simulator required. Use this loop for
almost everything — model decoding, API client error handling, auth store
behaviour, ViewModel state machines.

- **DeckMateModelsTests** — `Codable` round-trips from recorded JSON fixtures
  (copy real responses from `../helmlog` into `Tests/.../Fixtures/`).
- **DeckMateAPITests** — use a `URLProtocol` stub to inject canned responses;
  test every error path (bad status, decode failure, timeout, cancellation).
- **DeckMateAuthTests** — fake `KeychainStore` and `BiometricEvaluator`
  protocols; no actual Keychain touching in tests.

### App / UI tests — `apps/*/Tests/`

Reserve **XCUITest** for critical user flows only — logging in, replaying a
track, dropping a mark under bad network conditions. They are slow and
flaky; don't use them as a regression net for pure logic.

Use **SwiftUI previews** aggressively. Every non-trivial view ships with at
least one preview covering the loading, loaded, and error states.

### Hardware / live-data tests

For the live feature, add a **replay mode** in `DeckMateAPI` that reads a
JSONL of instrument ticks from a file and replays them on an `AsyncStream`.
This lets you develop the live UI at your desk without a boat.

---

## Risk Tiers

| Tier | Modules | Blast radius | Verification |
|---|---|---|---|
| **Critical** | `DeckMateAuth` (Keychain, biometrics, token exchange), URL handling of deep links, any code that signs or validates requests | Credential compromise, account takeover | TDD + fake-keychain tests + manual security review + `/data-license` where peer data is involved |
| **High** | `DeckMateAPI` (error handling, cancellation, retry), live data stream code, on-device caches of PII (audio, transcripts) | Silent data loss, showing stale / wrong numbers during racing, PII retention bugs | TDD + fixture-based tests + manual on-water smoke |
| **Standard** | SwiftUI screens, MapKit overlays, charts, SettingsView, History filters | Wrong-looking UI, confusing UX | TDD (ViewModel) + preview + `/pr-checklist` |
| **Low** | Assets, strings, README, scripts, CI config | Visual / non-functional | Smoke check |

A PR's tier is the **highest** tier of any file it touches. New modules
default to **Standard** until explicitly classified.

---

## Structured Specs

For combinatorial UX (permission gating, live-vs-offline state transitions,
embargo-aware peer rendering), write a structured spec first using the
`/spec` skill. Same three formats as helmlog:

| Format | When | Example |
|---|---|---|
| **Decision table** | Permissioning / affordance logic | Peer session × role × embargo → which UI affordances appear |
| **State diagram** | Lifecycle of a long-lived object | Live-data connection: idle → connecting → streaming → degraded → closed |
| **EARS requirements** | Conditions with clear triggers | WHEN polar confidence < 0.5 THE DECKMATE SHALL display "—" instead of a target |

Specs are posted as GitHub issue comments for review before code is written.

---

## Skills (on-demand workflows)

| Skill | Purpose |
|---|---|
| `/tdd-swift` | Red-green-refactor cycle for Swift using XCTest / Swift Testing |
| `/new-screen` | Scaffold a SwiftUI screen: View, ViewModel, preview, and test |
| `/new-kit-module` | Add a new module to `DeckMateKit` (Package.swift product + target + tests) |
| `/api-client` | Generate a Swift client + Codable models from a HelmLog FastAPI route |
| `/architecture` | Codebase comprehension — package map, data flow, complexity hotspots |
| `/domain` | Sailing instrument domain reference — same knowledge base as `/domain` in helmlog |
| `/data-license` | Review changes against the HelmLog data licensing policy |
| `/pr-checklist` | Pre-PR verification: tests, lint, format, Xcode build, docs, risk-tier gates |
| `/spec` | Structured spec (decision table, state diagram, EARS) for complex features |
| `/testflight` | TestFlight distribution workflow — archive, upload, release notes, crew access |

---

## Learning-mode notes (for Claude)

The author is explicitly using this repo to learn native Apple development.
When introducing a Swift / SwiftUI / Xcode concept for the first time:

- Call it out briefly (e.g., "This uses `@Observable` — the Swift 5.9+
  replacement for `ObservableObject` that lets SwiftUI observe any property
  without `@Published`.").
- Relate it to the Python-server equivalent when one exists (FastAPI
  dependency injection ≈ SwiftUI `@Environment`; Pydantic ≈ `Codable`;
  `asyncio.TaskGroup` ≈ `Swift Concurrency TaskGroup`).
- Prefer one-line explanations to paragraphs — enough to unblock, not a
  tutorial dump.
- Don't hide Xcode internals behind an over-clever script. When something
  must touch the Xcode project, explain the file format, the scheme, or the
  build phase being edited.
