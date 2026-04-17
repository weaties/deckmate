---
name: pr-checklist
description: Pre-PR verification — tests, lint, format, Xcode build, docs, risk-tier gates
---

# /pr-checklist

Run before opening or rebasing a PR. Adapt depth to the PR's risk tier
(computed as the highest tier of any file the PR touches; see `CLAUDE.md`).

## Always

1. `cd packages/DeckMateKit && swift build && swift test` — all green.
2. `swiftlint` — no new violations.
3. `swift-format lint -r apps packages` — no violations.
4. `xcodebuild -workspace DeckMate.xcworkspace -scheme DeckMateiOS -destination 'platform=iOS Simulator,name=iPhone 15' build test` — green.
   (Mac scheme too if the change touches `apps/DeckMateMac/` or shared views.)
5. PR body includes `Closes #<N>` (or `Fixes #<N>` for bugs).
6. Branch name is `feature/…`, `fix/…`, or `chore/…` — never work on `main`.

## Standard-tier PRs

6. SwiftUI `#Preview` covers loading / loaded / error states for any
   new or changed screen.
7. `docs/roadmap.md` updated if the PR checks off a roadmap item.
8. If the PR adds a user-visible string, check pluralisation and accessibility
   (VoiceOver label, Dynamic Type).

## High-tier PRs (DeckMateAPI, live data, PII caches)

Everything above plus:

9. `APIError` paths exercised — unauthorised, forbidden, not-found, decode failure.
10. Cancellation honoured — long-running streams / requests stop cleanly
    when the observing View disappears.
11. If a new endpoint: `docs/api-endpoints.md` has a row, and a fixture
    lives under `Tests/DeckMateModelsTests/Fixtures/`.
12. Manual smoke test against a real server documented in the PR description.

## Critical-tier PRs (DeckMateAuth, signing, deep-link handlers)

Everything above plus:

13. Keychain reads/writes go through `KeychainStoring` so tests can fake
    them — no direct `SecItem*` calls outside `KeychainStore.swift`.
14. No credential logged by `os.Logger` or any `print`.
15. `AuthError` exhaustively handled at call sites — no `catch {}`.
16. `/data-license` has been run if the change could touch peer data.
17. Manual review by a second pair of eyes before merging.

## Common pre-PR fixes

- Line length / formatting → `swift-format format -i -r apps packages`
- Import order → SwiftLint auto-fix handles most
- `@MainActor` warnings → isolate the top-level View; let `async` methods
  hop onto background actors and return `@MainActor` values

## When to block

Do not merge when:

- Any of the Always checks fails.
- Any risk-tier gate is unchecked for a PR that triggers that tier.
- `/data-license` flags a policy violation that hasn't been addressed.
