# Step 9 — Lossy/Lossless Tracking

## Purpose / scope

Track releases stored in a lossy format so they can be found and upgraded
later, per manifesto §6. Touched by both [06](06-edit-proposal-module.md)
(detection) and [08](08-implementation-module.md) (recording/updating).

## Inputs / outputs

- Input: `lossyLossless` decisions from `proposal.json`.
- Output: `$RESHELF_HOME\lossy-tracking.json` — a single, library-wide ledger
  (not per-session, since it needs to persist and accumulate across every
  run of the tool over time).

## Detailed design

### Schema

```jsonc
[
  {
    "stableKey": "a1b2c3d4e5f60708",
    "artist": "ZZ Top",
    "album": "XXX",
    "year": 1999,
    "targetPath": "E:\\Music\\ZZ Top\\1999 XXX",  // latest known location, refreshed on every sighting
    "format": "mp3",
    "status": "pending-upgrade",   // pending-upgrade | upgraded | ignored
    "firstDetectedUtc": "2026-09-19T10:00:00Z",
    "lastCheckedUtc": "2026-09-19T10:00:00Z",
    "upgradedUtc": null,
    "notes": ""
  }
]
```

### Lifecycle

- **Step 6** adds a new entry (`status: "pending-upgrade"`) whenever it
  proposes a `create-new` for a release whose source format is lossy, or
  updates `lastCheckedUtc` (and `targetPath`, to the *proposed* path) if the
  entry already exists.
- **Step 6** also detects the upgrade case: an existing target entry is
  `pending-upgrade` and the newly recognized source for the same
  `stableKey` is lossless → sets `lossyLossless.action = "replace-existing"`
  in `proposal.json`.
- **Step 6**, when nothing at all is found by `stableKey` (no target-index
  entry, no valid apply-log entry — the release would otherwise be plain
  `create-new`) and the source is lossless, also checks the ledger by
  *name*: a normalized `artist` + `year` match, with the `album` compared
  via the same noise-stripping `Get-ReshelfDiscogsSearchTitleVariants` uses
  for search (`Test-ReshelfSameLossyRelease`), against every still-pending
  entry. `stableKey` is derived from *this run's* recognized/proposed names,
  so a source folder renamed between imports (real case, plan/12 milestone
  3: an old mp3 import recognized as "Forwards Special Edition", a later
  flac import matching Discogs's own "Forwards") gets a different
  `stableKey` and would otherwise silently miss its own ledger row entirely.
  When found:
  - the old target folder still has lossy audio files in it →
    `lossyLossless.action = "previously-lossy-different-location"`;
  - the old target folder is gone (deleted, or `targetRoot` isn't the real
    collection) → `lossyLossless.action = "previously-lossy-target-missing"`.

  Either way `targetAction` is **not** changed (the release still proceeds
  as `create-new` at its own proposed path) and the old entry's `status`
  stays `pending-upgrade` — deliberately "keep both, only warn": apply never
  touches or deletes anything at a path outside this run's own proposed
  target, so reconciling the two copies (or marking the old one `ignored`/
  `upgraded` by hand) is left to the user, e.g. via the [editing UI](07-editing-ui-module.md)'s
  lossy tracker tab.
- **Step 8**, after successfully applying a `replace-existing` release,
  updates that entry to `status: "upgraded"`, `upgradedUtc = now`. After
  successfully applying any other lossy release (`action: "log-for-upgrade"`),
  it corrects `targetPath` to the path actually committed to
  (`Reshelf.LossyTracking.psm1`'s `Set-ReshelfLossyTrackingTargetPath`) — this
  can differ from what Step 6 proposed, e.g. a release folder name edited in
  the [editing UI](07-editing-ui-module.md) between propose and apply, or
  truncation from [10](10-error-handling-and-edge-cases.md)'s path-length
  handling. `-WhatIf` skips this, like every other write in Step 8.

### CLI helpers

- `Reshelf.ps1 lossy list [-Status pending-upgrade]`
- `Reshelf.ps1 lossy ignore <stableKey>` — sets `status = "ignored"` for a
  release the user has decided not to chase a lossless copy of.
- `Reshelf.ps1 lossy mark-upgraded <stableKey>` — manual override, for cases
  handled outside the normal pipeline.
- `Reshelf.ps1 lossy remove <stableKey>` — permanently deletes the entry
  (`Remove-ReshelfLossyTrackingEntry`), unlike `ignore`, which keeps a record
  of the deliberate decision. For a mistaken/duplicate row, or one the user
  no longer wants tracked at all.
- `Reshelf.ps1 lossy export -Path <file> [-Format csv|json] [-Status ...]` —
  writes the (optionally filtered) ledger out for use outside the tool.

## Decisions & rationale

- **Library-wide, not per-session**: the whole point (manifesto §6) is
  finding lossy releases *later*, potentially many sessions after they were
  first imported — a per-session file would lose that memory the moment the
  session "completes".
- **`ignored` status instead of deleting entries**: keeps a record of a
  deliberate decision ("I know this one's mp3, I don't care") distinguishable
  from "never noticed this one was lossy".

## Edge cases

- The same `stableKey` gets flagged lossy again after being marked `ignored`
  (e.g. re-imported from a different lossy source) → stays `ignored`;
  `lastCheckedUtc` updates but `status` doesn't silently flip back.

## Manual setup

None.

## Definition of done

- A lossy import creates a `pending-upgrade` entry.
- A subsequent lossless import of the same release flips it to `upgraded`
  and the target file is actually replaced.
- `Reshelf.ps1 lossy list` shows the current pending-upgrade backlog.
