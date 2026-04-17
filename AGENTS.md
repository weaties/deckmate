# AGENTS.md — DeckMate

Conventions for any AI coding agent working on `deckmate/`. Claude Code
users: see `CLAUDE.md` for Claude-specific skills and workflows.

---

## Project Overview

Native Apple clients (Mac, iPhone, iPad) for the HelmLog sailing data logger
server at `../helmlog`. SwiftUI + Swift Package Manager; single Xcode
workspace with `DeckMateiOS` (universal) and `DeckMateMac` app targets and a
shared Swift package `DeckMateKit`.

**Stack:** Swift 5.10+, SwiftUI, Swift Package Manager, XCTest / Swift
Testing, SwiftLint, swift-format, Xcode 15+.

---

## Essential Commands

```bash
# Shared package (fast TDD loop — no simulator needed)
cd packages/DeckMateKit
swift build
swift test

# Lint / format
swiftlint
swift-format lint -r apps packages

# App build + test (from repo root)
xcodebuild -workspace DeckMate.xcworkspace \
           -scheme DeckMateiOS \
           -destination 'platform=iOS Simulator,name=iPhone 15' \
           build test
```

All checks — `swift test`, `swiftlint`, `swift-format lint`, Xcode build+test
— must pass before opening a PR.

---

## Project Structure

```
apps/DeckMateiOS/          # iPhone + iPad app target (thin — views only)
apps/DeckMateMac/          # macOS app target
packages/DeckMateKit/      # shared package (models, API, auth, view models)
docs/                     # architecture, API notes, roadmap
.claude/skills/           # workflow skills
```

Business logic lives in `DeckMateKit`. Apps are the skin.

---

## Coding Conventions

- Swift 5.10+; adopt Swift 6 language mode as it becomes the Xcode default.
- `async`/`await` for concurrency — not `DispatchQueue`, not Combine.
- SwiftUI for all new UI; UIKit/AppKit only as a last resort.
- `Codable` for everything crossing a boundary — no raw `[String: Any]`.
- `os.Logger` for logging; never `print()` in shipping code.
- No force-unwraps in shipping code unless the invariant is documented.
- Files under ~250 lines; split when they grow.
- SwiftLint strict; swift-format formatting; both enforced in CI.

---

## Architecture Rules

- **DeckMateKit is the brain.** ViewModels, API clients, auth logic all live
  there and are testable with `swift test`.
- **Apps are the skin.** SwiftUI views, assets, Info.plist. No `URLSession`
  calls from views.
- **Server is authoritative.** The client reads from the server and caches;
  writes go through the API, not local storage.
- **UTC at the boundary.** Convert to local time zones only at render time.
- **Auth is pluggable.** Anything using credentials goes through `AuthStore`.

---

## Testing Requirements

- TDD: write a failing test before implementing.
- Unit tests in `packages/DeckMateKit/Tests/` — fast, no simulator.
- UI tests (`XCUITest`) only for critical flows.
- SwiftUI previews cover loading / loaded / error states.

---

## Do NOT

- Push directly to `main` — PRs only.
- `print()` anywhere — use `os.Logger`.
- Put business logic in `apps/` that belongs in `DeckMateKit`.
- Call `URLSession` from a SwiftUI view.
- Store credentials in `UserDefaults` — Keychain only.
- Ship a peer / co-op data screen with an "Export" affordance
  (`../helmlog/docs/data-licensing.md`).
- Commit `.mobileprovision`, `AuthKey_*.p8`, `*.p12`, or `.env`.
- Add a third-party dependency without an issue discussion first.

---

## Risk Tiers

| Tier | Modules | Extra |
|---|---|---|
| **Critical** | `DeckMateAuth`, deep-link / URL handlers, any signing code | Security review + data-licensing review |
| **High** | `DeckMateAPI`, live data stream, on-device PII caches | Fixture tests + manual smoke |

---

## Data Licensing

`../helmlog/docs/data-licensing.md` binds the client. Key UI rules: boat
owns its data (export always available), co-op peer data is view-only (no
export), embargoed sessions show embargo state not data, biometric data
requires per-person consent.
