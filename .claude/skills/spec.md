---
name: spec
description: Generate a structured spec (decision table, state diagram, or EARS) from a GitHub issue, then TDD from it
---

# /spec

For combinatorial or lifecycle-heavy features, write a structured spec
*before* writing tests. The spec is posted as a comment on the GitHub
issue for human review; TDD proceeds from the spec once approved.

## When to use

- Combinatorial UX — e.g. peer session × role × embargo → affordances.
- Lifecycle state machines — e.g. live-data connection: idle → connecting
  → streaming → degraded → closed.
- Hardware / safety-critical behaviour — e.g. polar confidence gating.
- Anything where "what are the edge cases?" is a real question.

Not needed for simple bug fixes, Low-tier UI tweaks, or pure-linear flows.

## Formats

| Format | Best for | Structure |
|---|---|---|
| **Decision table** | Permissioning, affordance gating | Inputs (columns) → outcome (column). Rows are scenarios. |
| **State diagram** | Long-lived object lifecycle | States + transitions + guards + side effects. ASCII or Mermaid. |
| **EARS requirements** | Condition-triggered behaviour | `WHEN X, THE SYSTEM SHALL Y.` One SHALL per row. |

## Workflow

1. Read the GitHub issue carefully. Capture the *behaviour*, not the *code*.
2. Pick the format that matches the problem shape.
3. Draft the spec as Markdown in a throwaway scratch file, iterate until
   each cell / state / SHALL is unambiguous.
4. Post as a comment on the issue:
   ```bash
   gh issue comment <N> --body "$(cat spec.md)"
   ```
5. Wait for human approval. Revise as needed.
6. Begin `/tdd-swift` — each row / transition / SHALL becomes at least one
   test case.

## Examples

### Decision table — peer session affordances

| Session owner | Role     | Embargoed | Export | Share | Comment | Rendered |
|---|---|---|---|---|---|---|
| self          | crew     | no        | yes    | yes   | yes     | full     |
| self          | crew     | yes       | yes    | yes   | yes     | full     |
| peer          | member   | no        | **no** | **no**| yes     | full     |
| peer          | member   | yes       | no     | no    | no      | **embargo banner** |
| peer          | non-member | —       | no     | no    | no      | 403      |

### State diagram — live data connection

```
 idle ──connect()──▶ connecting ──open──▶ streaming
  ▲                     │                    │
  │                     └─fail──▶ failed     │
  │                               │          │
  └─────────── disconnect() ◀─────┘          │
                                              │
  degraded ◀───heartbeat-miss─── streaming    │
     │              │                         │
     │              └─recover──▶ streaming ◀──┘
     │
     └─timeout──▶ failed
```

### EARS — polar confidence

- WHEN `polar.confidence < 0.5`, THE live SHALL display `"—"` in place of the target BSP.
- WHILE the live connection is `degraded`, THE live SHALL display a yellow "stale" indicator on each numeric tile.
- WHEN the user invokes "Drop mark" AND the GPS fix is older than 2 s, THE system SHALL show a "GPS stale" confirmation prompt before dropping.

## Good spec qualities

- **Unambiguous.** A second reader should write the same tests you would.
- **Minimal.** No implementation sketch, no Swift types — the spec
  survives a rewrite of the implementation.
- **Testable.** Each row / state / SHALL maps to one or more XCTest cases.
