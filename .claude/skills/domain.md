---
name: domain
description: Sailing instrument domain reference — Signal K paths, NMEA 2000 PGNs, and racing concepts as they appear in the client
---

# /domain

Sailing domain reference for anyone working on deckmate. For deep
server-side detail see `../helmlog/.claude/skills/domain.md`; this file
focuses on the concepts that appear in the *client* — the numbers shown
on the live screen and the annotations on the history view.

## Instruments the client renders

| Client label | Signal K path (common) | NMEA 2000 PGN | Unit on screen |
|---|---|---|---|
| **BSP** (boat speed)     | `navigation.speedThroughWater` | 128259 | knots |
| **SOG** (speed over gnd) | `navigation.speedOverGround`    | 129025/129026 | knots |
| **COG** (course over gnd)| `navigation.courseOverGroundTrue` | 129025/129026 | degrees true |
| **HDG** (heading)        | `navigation.headingTrue` / `Magnetic` | 127250 | degrees true |
| **TWS** (true wind speed)| `environment.wind.speedTrue`    | 130306 | knots |
| **TWA** (true wind angle)| `environment.wind.angleTrueWater` | 130306 | degrees ±180 |
| **AWS / AWA**            | `environment.wind.speedApparent` / `angleApparent` | 130306 | knots / degrees |
| **Depth**                | `environment.depth.belowTransducer` | 128267 | metres |
| **Water temp**           | `environment.water.temperature` | 130310 | °C |

## Conventions the UI follows

- **TWA sign:** negative on port tack, positive on starboard. Render the
  absolute value with a small "P" or "S" indicator rather than a minus sign.
- **Headings:** always degrees true. Convert from magnetic if the server
  ever sends magnetic (it doesn't today).
- **Wind colour:** on the live, lift (shift toward the boat) is green,
  header (shift away) is red — computed against the boat's own last
  N-second wind average, not an absolute.
- **Polar target:** show only when `confidence ≥ 0.5`. Below that,
  display `"—"`.

## Racing concepts

- **Session** — a contiguous period of logging. Kinds: `race`, `audio`.
- **Race** — a specifically race-type session with a named course.
- **Mark** — a named point (pin end, windward mark, leeward gate) the
  crew drops at the current GPS. Used for post-session overlays.
- **Leg** — the segment between two marks (auto-derived from mark drops
  and the course).
- **Polar** — a table of target BSP per (TWS, TWA). Built from historical
  sessions; used as a real-time benchmark.
- **Embargo** — a co-op-scoped delay before a session's data is visible
  to peers. See `../helmlog/docs/federation-design.md`.

## Signal K / NMEA 2000 in the client

The client does **not** parse PGNs. The HelmLog server does that and
exposes decoded ticks over `/ws/instruments`. If a PGN is missing from
the server output, the fix lives in `../helmlog/src/helmlog/sk_reader.py`
or `nmea2000.py`, not here.

## Common off-by-ones

- **Degrees vs radians:** Signal K is radians, NMEA 2000 PGN raw is
  integer-scaled, the server exposes degrees to the client. Always degrees
  in `InstrumentTick`.
- **True vs magnetic:** degrees true everywhere unless explicitly labelled
  magnetic.
- **Knots vs m/s:** knots in `InstrumentTick`. Signal K internal is m/s;
  the server converts.
