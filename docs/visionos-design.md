# visionOS — Immersive session replay

Design notes for the visionOS destination. The visionOS app ships as
part of the shared `DeckMate` multiplatform target — it is not a
separate Xcode target — so the files described here live alongside the
iOS/Mac code and are gated by `#if os(visionOS)` where the behaviour
diverges.

## The immersive idea

Replay a past session as a spatial scene: the boat's track becomes a
ribbon hovering in space; wind arrows and mark positions anchor to world
coordinates; the user scrubs time with a 2D window palette. The replay
renders from the same `Track` model as the iOS/Mac map view — the
difference is the renderer, not the data.

## Scene shape

- **Main window** (standard SwiftUI `WindowGroup`) — session list +
  scrubber + play controls. Identical to the iPad layout.
- **ImmersiveSpace** — a RealityKit `Entity` hierarchy driven by a
  `ReplayViewModel` (in `DeckMateKit`) that advances the current time
  index and publishes `(position, heading, TWS, TWA)` tuples. The entity
  tree subscribes and updates transforms / particle systems.

## What lives where

- **`DeckMateKit`** (testable, no RealityKit dependency) — `ReplayViewModel`,
  time-indexed `TickCursor`, coordinate projection (lat/lon → scene-space
  metres), playback state machine.
- **Main app target, visionOS-only files** — the `RealityView`, entity
  wiring, gesture handlers, SwiftUI chrome for the 2D window. Keep it
  presentational. Wrap files that import RealityKit in
  `#if os(visionOS)` so the same target still compiles cleanly on iOS
  and macOS.

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
