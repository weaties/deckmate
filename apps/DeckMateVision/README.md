# DeckMateVision

Apple Vision Pro (visionOS) app target — **immersive session replay**.

Placeholder until the Xcode target is created (see `../README.md`). The
folder layout inside this directory will be:

```
App/           # @main DeckMateVisionApp.swift, scene setup
Features/
  History/     # 2D window: session list, picker, scrubber controls
  Immersive/   # ImmersiveSpace: RealityKit scene for track replay
  Settings/    # Server URL, auth (shared UI with iOS where possible)
Resources/     # Assets.xcassets, Info.plist, entitlements
Tests/         # XCUITest for critical flows only
```

## The immersive idea

Replay a past session as a spatial scene: the boat's track becomes a
ribbon hovering in space; wind arrows and mark positions anchor to world
coordinates; the user scrubs time with a 2D window palette. The replay
renders from the same `Track` model as the iOS/Mac map view — the
difference is the renderer, not the data.

## Scene shape

- **Main window** (standard SwiftUI) — session list + scrubber + play controls.
- **ImmersiveSpace** — a RealityKit `Entity` hierarchy driven by a
  `ReplayViewModel` (in `DeckMateKit`) that advances the current time
  index and publishes `(position, heading, TWS, TWA)` tuples. The entity
  tree subscribes and updates transforms / particle systems.

## What lives where

- **DeckMateKit** (testable) — `ReplayViewModel`, time-indexed `TickCursor`,
  coordinate projection (lat/lon → scene-space metres), playback state machine.
- **This target** — the `RealityView`, entity wiring, gesture handlers,
  SwiftUI chrome for the 2D window. Keep it presentational.

## Things to watch

- **Coordinate choice.** A boat track is hundreds of metres to a few
  kilometres — well inside RealityKit's comfortable precision range if
  you translate the scene origin to the session's bounding-box centroid.
  Don't hand RealityKit raw WGS84 metres.
- **Privacy.** visionOS restricts world-sensing by default. We don't need
  full-space scene understanding for a hovering track; a bounded
  `ImmersiveSpaceStyle.mixed` with a small anchored volume is plenty.
- **Policy.** Per the data licensing policy, peer (co-op) sessions replayed
  in immersive mode must still respect embargoes and have no export /
  share affordance. Run `/data-license` before shipping the feature.
