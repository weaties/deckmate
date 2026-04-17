---
name: new-kit-module
description: Add a new module to the DeckMateKit Swift package (product + target + tests)
---

# /new-kit-module

Use when a concern is substantial enough to warrant its own SPM module
(for example: a benchmarks visualizer, an audio-playback engine, a
Signal K delta parser). Small additions should just land in the existing
`DeckMateModels` / `DeckMateAPI` / `DeckMateAuth` modules.

## Invocation

```
/new-kit-module <ModuleName>
```

Example: `/new-kit-module DeckMateCharts`.

## Steps

1. Create:
   - `packages/DeckMateKit/Sources/<ModuleName>/<ModuleName>.swift`
   - `packages/DeckMateKit/Tests/<ModuleName>Tests/<ModuleName>Tests.swift`
2. Edit `packages/DeckMateKit/Package.swift`:
   - Add a `.library(name: "<ModuleName>", targets: ["<ModuleName>"])` product.
   - Add a `.target(name: "<ModuleName>", dependencies: […])`.
   - Add a `.testTarget(name: "<ModuleName>Tests", …)`.
3. If the module is a building block for apps, add it to the umbrella
   `DeckMateKit` target's `dependencies` and `@_exported import` it from
   `Sources/DeckMateKit/DeckMateKit.swift`.
4. Run `swift build && swift test` — should still be green.
5. If apps need the new module directly, add it as a package product to
   the iOS and Mac targets in Xcode (Project → Target → Frameworks,
   Libraries, and Embedded Content).

## Naming

- Prefix with `HelmLog` for anything public (`DeckMateCharts`, not
  `Charts`) to avoid collisions with Apple frameworks or other packages.
- If a module is an implementation detail, prefix with `_HelmLog` and
  don't expose it in the umbrella.

## When not to split

- You only have one or two new files.
- The types are closely coupled to an existing module's internals.
- It would create a circular dependency.

Defer the split; add files to the existing module.
