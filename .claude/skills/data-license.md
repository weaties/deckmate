---
name: data-license
description: Review client code against the HelmLog data licensing policy (co-op data is view-only, PII deletion rights, embargo)
---

# /data-license

The data licensing policy at `../helmlog/docs/data-licensing.md` binds the
client UI, not just the server. This skill reviews a diff (or a specific
file) against the policy and flags violations.

## Invocation

```
/data-license <path-or-diff-ref>
```

No argument → review all pending changes on the current branch.

## What to check

### 1. Co-op / peer data is view-only

For any screen or ViewModel that renders data where `Session.coOpId` may
be set and the session does **not** belong to the logged-in boat:

- ❌ **Forbidden affordances:** "Export CSV/GPX/JSON", "Share",
  "Copy full track", "Download", "Save to Files", `ShareLink`, protest-
  committee formatting.
- ✅ **Allowed:** visual rendering (map, charts), read-only text, scoped
  comparisons against the user's own boat within the same dashboard.

### 2. Embargoed sessions must show embargo state

When `Session.isEmbargoed(now:)` is true:

- Do not render tracks, polars, or tick data for that session.
- Show a dedicated "Embargoed until <date>" UI element.
- Silent omission is a bug — the user must know the data exists but is
  gated.

### 3. PII categories have deletion rights

Screens that display audio clips, photos, email addresses, biometrics
(HR, breathing), or diarised transcripts must have a visible "Delete"
or "Remove" action for the logged-in boat's own data.

### 4. Boat owns its data

Never hide, paywall, or gate the "Export" action for the logged-in
boat's own sessions. If you find yourself adding a feature flag around
export, something is wrong.

### 5. Biometric data requires per-person consent

If a screen shows biometric data for a crew member other than the
logged-in user (e.g. "Skipper HR during race"), confirm the per-person
consent flow is honoured. Boat-owner consent is **not** transitive for
biometrics.

### 6. No gambling, no protest committee

Do not build features that facilitate betting/wagering on co-op data,
and do not build export formats designed for protest committee
submission of peer data.

## Output

Report findings as:

```
OK:    <path>  — no policy concerns
FLAG:  <path>:<line>  — <which rule>  — <suggested fix>
```

Flag items should block PR merge until resolved.
