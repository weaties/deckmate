---
name: tdd-swift
description: Test-driven development loop for Swift using XCTest / Swift Testing inside DeckMateKit
---

# /tdd-swift

Follow strict red-green-refactor inside `packages/DeckMateKit`. Keep cycles
short — a single failing assertion, then the minimum to turn it green,
then the refactor.

## Loop

1. **Red.** Write one failing test in the matching `Tests/…/` module.
   - Prefer `XCTest` for parity with the existing suite. Use Swift
     Testing (`@Test`, `#expect`) for brand-new suites where it reads
     noticeably better, and be consistent within a file.
   - Name: `test<Behavior>` (XCTest) or a descriptive function name
     (Swift Testing).
   - Run `swift test --filter <TargetName>/<FileName>` to get a fast loop.
2. **Green.** Add just enough code in `Sources/…/` to make the test pass.
   No extra features, no speculative abstractions.
3. **Refactor.** Clean up — rename, extract, remove duplication. Tests
   stay green. Run the full `swift test` once before moving on.
4. **Commit.** Small, focused commits. Each commit should leave the tree
   green with `swift test && swiftlint && swift-format lint -r packages`.

## When to pop out of the package loop

- **UI behaviour** that can only be validated visually → move to Xcode,
  write a SwiftUI `#Preview`, iterate there. Only a truly critical flow
  justifies an `XCUITest`.
- **Auth flows that touch real Keychain or biometrics** → write an
  integration test under an Xcode scheme, not in the SPM suite (SPM
  tests don't have a host app bundle).

## Common pitfalls

- **`async` tests:** declare them as `func testFoo() async throws`. Don't
  use `DispatchGroup` / semaphores — use `await` directly.
- **Date comparisons:** inject a `now:` parameter (like `Session.isEmbargoed(now:)`)
  rather than calling `Date.now` inside the unit under test.
- **Fixture drift:** when the server adds a field, drop the new JSON
  response into `Tests/DeckMateModelsTests/Fixtures/` and let the Codable
  test fail until the model is updated.

## Output format for PRs

Each TDD change should produce:
- one or more new/changed test files
- the minimum production change
- no new public API unless the test required it
