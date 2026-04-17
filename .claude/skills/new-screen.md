---
name: new-screen
description: Scaffold a SwiftUI screen — View, ViewModel in DeckMateKit, preview, and unit test
---

# /new-screen

Create a new feature screen with the full shape this repo expects:

- **ViewModel** in `packages/DeckMateKit/Sources/DeckMateKit/ViewModels/` (or a
  dedicated module if the feature is big) — `@Observable`, pure Swift,
  testable with `swift test`.
- **SwiftUI `View`** in `DeckMate/DeckMate/Features/<Feature>/` (or
  `DeckMate/DeckMateWatch/Features/<Feature>/` for wrist-only screens).
  Use `#if os(macOS)` / `os(visionOS)` inside the file when the UX
  differs meaningfully by destination.
- **`#Preview`** covering `loading`, `loaded`, and `error` states.
- **Unit test** on the ViewModel — no simulator needed.

## Invocation

```
/new-screen <FeatureName>
```

Example: `/new-screen History`.

## Checklist

1. Add `FeatureNameViewModel.swift` with an `@Observable final class`
   exposing:
   - a `State` enum or struct (`idle / loading / loaded(T) / failed(APIError)`)
   - one or more `intent` methods (`func load() async`)
   - dependencies injected in `init` (typically `APIClient`).
2. Add `FeatureNameView.swift` in the iOS app, observing the ViewModel
   via `@State private var vm = FeatureNameViewModel(…)` and switching on
   `vm.state`.
3. Add a `#Preview` that constructs the ViewModel with a fake `APIClient`
   and seeds each state in turn.
4. Add a Mac variant if the idiom needs to differ (split view, menu bar,
   keyboard shortcuts). Share the ViewModel.
5. Add `FeatureNameViewModelTests.swift` under
   `packages/DeckMateKit/Tests/DeckMateKitTests/` exercising each transition.
6. Wire the screen into navigation (`ContentView`, `TabView`, or
   `NavigationSplitView`).
7. Run `swift test && swiftlint && swift-format lint -r apps packages`.

## Conventions

- One ViewModel per screen; don't share ViewModels across unrelated views.
- ViewModels never import `SwiftUI`. Keep them platform-agnostic so the
  Mac app can reuse them.
- Error states are rendered as typed `APIError` cases, not generic strings.
- Loading states must be *visible* — don't leave the screen blank while
  awaiting a first fetch.
