---
name: architecture
description: Codebase comprehension — package map, data flow, complexity hotspots, risk-tier overlay
---

# /architecture

Produce an up-to-date architecture briefing for the deckmate repo.
Two modes: **snapshot** (full) and **delta** (what changed since a given ref).

## Snapshot mode

Report:

1. **Packages and modules** — `DeckMateKit` sub-modules and what each owns.
2. **App targets** — iOS / Mac features present and their state (scaffolded vs implemented).
3. **Data flow** — from server → `DeckMateAPI` → ViewModel → View. Flag
   violations (views calling `URLSession` directly, ViewModels importing
   `SwiftUI`, business logic in `apps/`).
4. **Complexity hotspots** — Swift files over ~250 lines. These should be
   split.
5. **Risk-tier overlay** — which files fall under Critical / High per
   `CLAUDE.md`, and whether recent changes touched any.
6. **Dependency graph** — third-party packages (should be empty in v0.1)
   and local package dependencies.

## Delta mode

```
/architecture delta <git-ref>
```

Report what changed between `<git-ref>` and `HEAD`:

- New / renamed / deleted modules
- New public API surface in `DeckMateKit`
- New app targets / features
- Changes to risk-tier classification
- Any file that crossed the 250-line threshold in either direction

## Tips

- Use the `Grep` tool to find `import SwiftUI` inside `packages/DeckMateKit`
  (violation) and `URLSession` inside `apps/` (violation).
- Use `Glob` to enumerate `.swift` files and sort by line count to find
  hotspots.
- Cross-reference with `../helmlog` route files to check API drift — a
  client route method whose server counterpart was removed is dead code.
