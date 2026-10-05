# 11 — Lossy tracking (as-is, from docs and tests)

Status: Draft | Version: 0.1 | Last updated: 2026-10-05

## Scope

The lossy ledger (a library-wide list of releases kept in a lossy format, such as mp3, so they can be upgraded to lossless later) and the lossy parts of the proposal. Owned inputs:

- `legacy/tests/Reshelf.LossyTracking.Tests.ps1` — all Describe blocks.
- `legacy/tests/Reshelf.EditProposal.Tests.ps1` — Describe `Test-ReshelfSameLossyRelease (private)`, Context `Invoke-ReshelfEditProposal › lossy tracking`, and the lossy tests of Context `target comparison`.
- `legacy/plan/09-lossy-lossless-tracking.md`.
- `legacy/plan/06-edit-proposal-module.md` — the lossy parts of "Target comparison".
- `MANIFESTO.md` §6 (Lossy/Lossless Tracking).
- `legacy/README.md` — "Reference: lossy/lossless tracking".

Not here: the target comparison in general (see [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md)), the apply steps (see [10-apply.md](10-apply.md)), the command syntax (see [12-cli.md](12-cli.md)), the data folder (see [01-data-home-and-storage.md](01-data-home-and-storage.md)).

Magic values in this file:

| Value | Meaning |
|---|---|
| `lossy-tracking.json` | Ledger file name in the data home |
| `pending-upgrade`, `upgraded`, `ignored` | Ledger statuses |
| `none`, `log-for-upgrade`, `replace-existing`, `previously-lossy-different-location`, `previously-lossy-target-missing` | Values of `lossyLossless.action` in the proposal |
| `a1b2c3d4e5f60708` | Stable key used in the tests (16 lowercase hex characters) |

## Ledger file

### AS-DOC-LSY-001 — One library-wide ledger file
Status: Draft | Source: MANIFESTO.md › 6. Additional Feature — Lossy/Lossless Tracking; legacy/plan/09-lossy-lossless-tracking.md › Inputs / outputs; legacy/plan/09-lossy-lossless-tracking.md › Decisions & rationale; legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › lossy tracking › leaves a pre-seeded ignored ledger entry as ignored after a run touches the same release

Releases with lossy source files are logged in a separate tracking file. There is one ledger for the whole library, not one per session. It keeps entries across all runs and sessions. The file is `lossy-tracking.json` in the data home.

Example: `<dataHome>\lossy-tracking.json`.

### AS-DOC-LSY-002 — No ledger file means an empty ledger
Status: Draft | Source: legacy/tests/Reshelf.LossyTracking.Tests.ps1 › Get-ReshelfLossyTrackingLedger › returns an empty array when no ledger file exists

When the ledger file does not exist, reading the ledger gives an empty list. There is no error.

Example: new data home, no `lossy-tracking.json` → 0 entries.

### AS-DOC-LSY-003 — A ledger that breaks the schema gives an error with the file path
Status: Draft | Source: legacy/tests/Reshelf.LossyTracking.Tests.ps1 › Get-ReshelfLossyTrackingLedger › throws a clear error naming the file when the ledger does not match the schema

When the ledger file does not match the lossy-tracking schema, reading it fails. The error message contains the path of the file.

Example: file content `[{"stableKey":"missing-other-fields"}]` → error that names `<dataHome>\lossy-tracking.json`.

### AS-DOC-LSY-004 — A ledger entry holds the release, its location, its format and its status
Status: Draft | Source: legacy/plan/09-lossy-lossless-tracking.md › Schema; legacy/tests/Reshelf.LossyTracking.Tests.ps1 › Get-ReshelfLossyTrackingLedger › returns the parsed entries from an existing valid ledger; legacy/README.md › Reference: lossy/lossless tracking

The ledger is a list of entries. Each entry has: `stableKey`, `artist`, `album`, `year`, `targetPath` (latest known location), `format`, `status`, `firstDetectedUtc`, `lastCheckedUtc`, `upgradedUtc` and `notes`. The status is one of `pending-upgrade`, `upgraded`, `ignored`.

Example:
```json
{ "stableKey": "a1b2c3d4e5f60708", "artist": "ZZ Top", "album": "XXX", "year": 1999,
  "targetPath": "E:\\Music\\ZZ Top\\1999 XXX", "format": "mp3", "status": "pending-upgrade",
  "firstDetectedUtc": "2026-09-19T10:00:00.000Z", "lastCheckedUtc": "2026-09-19T10:00:00.000Z",
  "upgradedUtc": null, "notes": "" }
```

### AS-DOC-LSY-005 — Every ledger change writes a schema-valid file
Status: Draft | Source: legacy/tests/Reshelf.LossyTracking.Tests.ps1 › Add-ReshelfLossyTrackingEntry › writes a ledger file that validates against the lossy-tracking schema; legacy/tests/Reshelf.LossyTracking.Tests.ps1 › Set-ReshelfLossyTrackingTargetPath › writes a ledger file that validates against the lossy-tracking schema; legacy/tests/Reshelf.LossyTracking.Tests.ps1 › Set-ReshelfLossyTrackingStatus › writes a ledger file that validates against the lossy-tracking schema; legacy/tests/Reshelf.LossyTracking.Tests.ps1 › Remove-ReshelfLossyTrackingEntry › writes a ledger file that validates against the lossy-tracking schema; legacy/tests/Reshelf.LossyTracking.Tests.ps1 › Set-ReshelfLossyTrackingIgnored › writes a ledger file that validates against the lossy-tracking schema

After add, set target path, set status, remove and ignore, the ledger file passes the lossy-tracking schema check.

Example: add `ZZ Top / XXX`, then add `John 5 / God Told Me To`, then remove the first → the file is still schema-valid.

## Reading one entry

### AS-DOC-LSY-006 — An entry is found by its stable key
Status: Draft | Source: legacy/tests/Reshelf.LossyTracking.Tests.ps1 › Get-ReshelfLossyTrackingEntry › returns $null when no entry matches the stable key; legacy/tests/Reshelf.LossyTracking.Tests.ps1 › Get-ReshelfLossyTrackingEntry › returns the matching entry when present

A lookup by stable key returns the matching entry. When no entry has that key, it returns nothing.

Example: key `a1b2c3d4e5f60708` → entry with `artist = ZZ Top`.
Example: key `doesnotexist00000` → nothing.

## Adding an entry

### AS-DOC-LSY-007 — A new entry starts as pending-upgrade
Status: Draft | Source: legacy/tests/Reshelf.LossyTracking.Tests.ps1 › Add-ReshelfLossyTrackingEntry › creates a new pending-upgrade entry with matching firstDetectedUtc and lastCheckedUtc

Adding an entry for a new stable key creates it with status `pending-upgrade`. `firstDetectedUtc` and `lastCheckedUtc` are both the current time. `upgradedUtc` is empty.

Example: add `ZZ Top / XXX / 1999`, `mp3`, at `2026-09-19T10:00:00Z` → `status = pending-upgrade`, `firstDetectedUtc = lastCheckedUtc`, `upgradedUtc = null`.

### AS-DOC-LSY-008 — A repeat sighting updates lastCheckedUtc and keeps firstDetectedUtc
Status: Draft | Source: legacy/tests/Reshelf.LossyTracking.Tests.ps1 › Add-ReshelfLossyTrackingEntry › updates lastCheckedUtc but keeps firstDetectedUtc on a second call for the same stable key; legacy/plan/09-lossy-lossless-tracking.md › Lifecycle

Adding an entry for a stable key that already exists does not create a second entry. It sets `lastCheckedUtc` to the current time. `firstDetectedUtc` stays.

Example: add at `2026-09-19T10:00:00Z`, add again at `2026-09-20T11:00:00Z` → `firstDetectedUtc = 2026-09-19T10:00:00Z`, `lastCheckedUtc = 2026-09-20T11:00:00Z`.

### AS-DOC-LSY-009 — A repeat sighting replaces the target path and keeps the status
Status: Draft | Source: legacy/tests/Reshelf.LossyTracking.Tests.ps1 › Add-ReshelfLossyTrackingEntry › replaces a stale targetPath on a later sighting but keeps status and firstDetectedUtc; legacy/plan/09-lossy-lossless-tracking.md › Schema

On a repeat sighting, the entry takes the new target path. Status and `firstDetectedUtc` stay.

Example: first `E:\OldRoot\ZZ Top\1999 XXX`, then `E:\Music\ZZ Top\1999 XXX` → `targetPath = E:\Music\ZZ Top\1999 XXX`, `status = pending-upgrade`.

### AS-DOC-LSY-010 — A repeat sighting does not change an ignored entry back
Status: Draft | Source: legacy/tests/Reshelf.LossyTracking.Tests.ps1 › Add-ReshelfLossyTrackingEntry › leaves a pre-seeded ignored entry as ignored; legacy/plan/09-lossy-lossless-tracking.md › Edge cases

When an entry is `ignored`, a repeat sighting keeps it `ignored`. Only `lastCheckedUtc` changes.

Example: entry `a1b2c3d4e5f60708` set to `ignored`, then added again → `status = ignored`.

### AS-DOC-LSY-011 — A repeat sighting does not change an upgraded entry back
Status: Draft | Source: legacy/tests/Reshelf.LossyTracking.Tests.ps1 › Add-ReshelfLossyTrackingEntry › leaves a pre-seeded upgraded entry as upgraded

When an entry is `upgraded`, a repeat sighting keeps it `upgraded`. `upgradedUtc` stays.

Example: entry `upgraded` with `upgradedUtc = 2026-09-21T00:00:00.000Z`, then added again → `status = upgraded`, `upgradedUtc = 2026-09-21T00:00:00Z`.

## Changing an entry

### AS-DOC-LSY-012 — Setting the target path keeps the status
Status: Draft | Source: legacy/tests/Reshelf.LossyTracking.Tests.ps1 › Set-ReshelfLossyTrackingTargetPath › sets targetPath for an existing entry and leaves status unchanged

The target path of an existing entry can be set. The status does not change.

Example: `E:\Music\ZZ Top\1999 XXX` → set to `E:\Music\ZZ Top\1999 XXX (Edited)`; `status = pending-upgrade`.

### AS-DOC-LSY-013 — The status of an entry can be set
Status: Draft | Source: legacy/tests/Reshelf.LossyTracking.Tests.ps1 › Set-ReshelfLossyTrackingStatus › sets status to ignored

The status of an existing entry can be set to any of the three statuses.

Example: `pending-upgrade` → set `ignored` → `status = ignored`.

### AS-DOC-LSY-014 — Setting "upgraded" stamps the upgrade time
Status: Draft | Source: legacy/tests/Reshelf.LossyTracking.Tests.ps1 › Set-ReshelfLossyTrackingStatus › sets status to upgraded and stamps upgradedUtc

When the status is set to `upgraded`, `upgradedUtc` is set to the current time.

Example: set `upgraded` → `upgradedUtc` is not empty.

### AS-DOC-LSY-015 — Leaving "upgraded" clears the upgrade time
Status: Draft | Source: legacy/tests/Reshelf.LossyTracking.Tests.ps1 › Set-ReshelfLossyTrackingStatus › clears upgradedUtc when moved back off upgraded

When the status changes from `upgraded` to another status, `upgradedUtc` becomes empty.

Example: set `upgraded`, then set `pending-upgrade` → `upgradedUtc = null`.

### AS-DOC-LSY-016 — Notes change only when new notes are given
Status: Draft | Source: legacy/tests/Reshelf.LossyTracking.Tests.ps1 › Set-ReshelfLossyTrackingStatus › updates notes alongside status when -Notes is given; legacy/tests/Reshelf.LossyTracking.Tests.ps1 › Set-ReshelfLossyTrackingStatus › leaves notes untouched when -Notes is not given

A status change can also set the notes. When no notes are given, the old notes stay.

Example: set `ignored` with notes `not chasing this one` → `notes = not chasing this one`.
Example: set `ignored` with `first note`, then set `pending-upgrade` without notes → `notes = first note`.

### AS-DOC-LSY-017 — A change for an unknown stable key warns and changes nothing
Status: Draft | Source: legacy/tests/Reshelf.LossyTracking.Tests.ps1 › Set-ReshelfLossyTrackingTargetPath › warns and returns the ledger unchanged when the stable key does not exist; legacy/tests/Reshelf.LossyTracking.Tests.ps1 › Set-ReshelfLossyTrackingStatus › warns and returns the ledger unchanged when the stable key does not exist; legacy/tests/Reshelf.LossyTracking.Tests.ps1 › Remove-ReshelfLossyTrackingEntry › warns and returns the ledger unchanged when the stable key does not exist; legacy/tests/Reshelf.LossyTracking.Tests.ps1 › Set-ReshelfLossyTrackingIgnored › warns and returns the ledger unchanged when the stable key does not exist

Set target path, set status, remove and ignore with a stable key that is not in the ledger show a warning. The ledger stays unchanged. There is no error.

Example: ledger with `a1b2c3d4e5f60708` (`pending-upgrade`, `E:\Music\ZZ Top\1999 XXX`); set status `ignored` for `doesnotexist0000` → warning; still 1 entry with `status = pending-upgrade`.

### AS-DOC-LSY-018 — Remove deletes the entry for good
Status: Draft | Source: legacy/tests/Reshelf.LossyTracking.Tests.ps1 › Remove-ReshelfLossyTrackingEntry › permanently removes an existing entry; legacy/tests/Reshelf.LossyTracking.Tests.ps1 › Remove-ReshelfLossyTrackingEntry › leaves other entries untouched; legacy/plan/09-lossy-lossless-tracking.md › CLI helpers

Remove deletes the entry with the given stable key. Other entries stay. It is meant for a mistaken or duplicate entry, or one the user no longer wants tracked.

Example: entries `a1b2c3d4e5f60708` (ZZ Top) and `b2c3d4e5f6070819` (John 5); remove the first → only `b2c3d4e5f6070819` remains.

### AS-DOC-LSY-019 — Ignore keeps the entry and records the decision
Status: Draft | Source: legacy/tests/Reshelf.LossyTracking.Tests.ps1 › Set-ReshelfLossyTrackingIgnored › sets status to ignored for an existing entry; legacy/plan/09-lossy-lossless-tracking.md › Decisions & rationale; legacy/README.md › Reference: lossy/lossless tracking

Ignore sets the status to `ignored`. The entry stays in the ledger. So "I know this one is mp3, I don't care" stays different from "never noticed".

Example: ignore `a1b2c3d4e5f60708` → `status = ignored`, entry still present.

## Lossy parts of the proposal

### AS-DOC-LSY-020 — Propose logs a lossy source release as pending-upgrade
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › lossy tracking › creates a pending-upgrade ledger entry for a lossy source release; MANIFESTO.md › 6. Additional Feature — Lossy/Lossless Tracking; legacy/README.md › Reference: lossy/lossless tracking; legacy/plan/09-lossy-lossless-tracking.md › Lifecycle; legacy/tests/fixtures/expected/proposal.json › ZZ Top / Mescalero

When the source files of a release are lossy, the proposal marks it `isLossy = true` with action `log-for-upgrade`. Propose itself adds a `pending-upgrade` entry to the ledger, before review and apply.

Example: `Some Band\2010 Some Album\01 Track.mp3` → `lossyLossless = { isLossy: true, action: log-for-upgrade }`; ledger entry for its stable key with `status = pending-upgrade`.
Example: `ZZ Top\2003 Mescalero` (mp3) → `isLossy = true`, `action = log-for-upgrade`, `targetAction = create-new`.

### AS-DOC-LSY-021 — Propose stores the proposed target path in the ledger
Status: Draft | Source: legacy/plan/09-lossy-lossless-tracking.md › Lifecycle

When propose adds or refreshes a ledger entry, the entry's target path is the proposed target path of the release. On a repeat sighting, `lastCheckedUtc` and the target path are updated.

Example: lossy `Some Band / 2010 Some Album` → ledger `targetPath = <targetRoot>\Some Band\2010 Some Album`.

### AS-DOC-LSY-022 — Propose does not reset an ignored ledger entry
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › lossy tracking › leaves a pre-seeded ignored ledger entry as ignored after a run touches the same release

When propose sees a lossy release whose ledger entry is `ignored`, the entry stays `ignored`.

Example: `Some Band / Some Album / 2010` entry set to `ignored`, then propose on `01 Track.mp3` → `status = ignored`.

### AS-DOC-LSY-023 — A lossless release with no lossy history has action "none"
Status: Draft | Source: legacy/tests/fixtures/expected/proposal.json › Cranberries; legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › lossy tracking › does not flag previously-lossy when the ledger entry is already ignored

A lossless release with no lossy target and no matching pending ledger entry gets `lossyLossless = { isLossy: false, action: none }`.

Example: `Cranberries / 1993 Everybody Else Is Doing It` (flac) → `isLossy = false`, `action = none`.

### AS-DOC-LSY-024 — A lossless source over a found lossy target is replace-existing
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › target comparison › proposes update-existing/replace-existing when a lossless source would upgrade a lossy target; legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › target comparison › proposes update-existing/replace-existing via the apply-log when the source stableKey differs from the target folder's own key (plan/12 milestone 7); legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › target comparison › proposes update-existing/replace-existing when a lossy folder sits at the proposed path, even with no apply-log entry and a different stableKey; legacy/README.md › Reference: lossy/lossless tracking; legacy/plan/06-edit-proposal-module.md › Target comparison (lossy/lossless + duplicate handling)

When the existing target folder is found (see [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md), AS-DOC-PRP-069) at the proposed path, it holds lossy files, and the source is lossless, the proposal is an upgrade: `targetAction = update-existing`, `lossyLossless.action = replace-existing`. A ledger entry is not needed for this.

Example: source `Some Band\2010 Some Album\01 Track.flac`, target `Some Band\2010 Some Album\01 Track.mp3`, no ledger entry → `update-existing` / `replace-existing`.
Example: source `SOME BAND - SomeAlbum\01 Track.flac` (different stable key), lossy folder at the proposed path `Some Band\2010 Some Album` → `update-existing` / `replace-existing`.

### AS-DOC-LSY-025 — A lossy folder at another path than the proposed one: keep both, only warn
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › target comparison › only warns (previously-lossy-different-location) when the applied lossy folder is under an older name than the proposed path; legacy/plan/06-edit-proposal-module.md › Target comparison (lossy/lossless + duplicate handling)

When the lossy folder found for this stable key is at a different path than the proposed one, apply would only write the proposed path and leave the old folder. So the proposal is `targetAction = create-new` with `lossyLossless.action = previously-lossy-different-location`. The release needs review. `previousLossy` describes the old folder. Without a ledger entry, its format comes from the extension of the first audio file, and `firstDetectedUtc` from the folder creation time.

Example: apply-log entry for `Some Band / Some Album / 2010` points to `Some Band\2010 Some Album (Old Name)` with `01 Track.mp3`; source is flac → `create-new`, `previously-lossy-different-location`, `previousLossy.targetPath = <targetRoot>\Some Band\2010 Some Album (Old Name)`, `previousLossy.format = mp3`, review required.

### AS-DOC-LSY-026 — A pending ledger entry found by name gives previously-lossy-different-location
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › lossy tracking › flags previously-lossy-different-location when a lossless re-import matches a pending-upgrade ledger entry by name, not stableKey, and the old lossy folder still exists; legacy/plan/09-lossy-lossless-tracking.md › Lifecycle; legacy/plan/06-edit-proposal-module.md › Target comparison (lossy/lossless + duplicate handling)

When nothing is found by stable key (plain `create-new`) and the source is lossless, the app also searches the ledger by name. It compares every `pending-upgrade` entry by normalized artist and year, and by album with the same-release check (AS-DOC-LSY-029). When an entry matches and its old folder still holds lossy files, `lossyLossless.action = previously-lossy-different-location` with `previousLossy.targetExists = true`. The release needs review. `targetAction` stays `create-new`. The old entry stays `pending-upgrade`. Nothing touches the old folder.

Example: ledger `The Egg / Forwards Special Edition / 2006` at `The Egg\2006 Forwards Special Edition` (mp3); new source `The Egg\2006 Forwards` (flac) → `create-new`, `previously-lossy-different-location`, `previousLossy.targetPath = <targetRoot>\The Egg\2006 Forwards Special Edition`, `targetExists = true`; old folder still exists; old entry `pending-upgrade`.

### AS-DOC-LSY-027 — A ledger match whose old folder is gone gives previously-lossy-target-missing
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › lossy tracking › flags previously-lossy-target-missing when the ledger's old target folder no longer exists; legacy/plan/09-lossy-lossless-tracking.md › Lifecycle

When the name search finds a pending entry but its old target folder no longer exists, `lossyLossless.action = previously-lossy-target-missing` with `previousLossy.targetExists = false`. The release needs review. The folder may be deleted, or the target root is not the real collection.

Example: ledger `Some Band / Some Album (Deluxe Edition) / 2010` at `Some Band\Deleted Folder` (missing); source `Some Band\2010 Some Album` (flac) → `previously-lossy-target-missing`, `targetExists = false`, review required.

### AS-DOC-LSY-028 — Ignored ledger entries are not used by the name search
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › lossy tracking › does not flag previously-lossy when the ledger entry is already ignored

The name search only uses `pending-upgrade` entries. An `ignored` entry gives no warning.

Example: ledger `Some Band / Some Album (Deluxe Edition) / 2010` set to `ignored`; source `Some Band\2010 Some Album` (flac) → `lossyLossless.action = none`.

### AS-DOC-LSY-029 — Same-release check: a noisier album name matches the clean one
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Test-ReshelfSameLossyRelease (private) › matches when the old name is a noisier version of the new one (real "Forwards Special Edition" case); legacy/tests/Reshelf.EditProposal.Tests.ps1 › Test-ReshelfSameLossyRelease (private) › matches identical names; legacy/tests/Reshelf.EditProposal.Tests.ps1 › Test-ReshelfSameLossyRelease (private) › does not match genuinely unrelated names

Two album names are the same release when they are equal, or when the old one is the new one plus noise (edition words, parenthetical groups). Unrelated names do not match. The noise removal is the same as for the Discogs search title (see [07-proposal-matching.md](07-proposal-matching.md)).

Example: `Forwards Special Edition` vs `Forwards` → same.
Example: `Some Album` vs `Some Album` → same.
Example: `Some Album` vs `A Totally Different Album` → not the same.

## After apply

### AS-DOC-LSY-030 — A successful upgrade marks the ledger entry upgraded
Status: Draft | Source: legacy/plan/09-lossy-lossless-tracking.md › Lifecycle; legacy/plan/09-lossy-lossless-tracking.md › Definition of done; legacy/README.md › Reference: lossy/lossless tracking

Same rule as AS-DOC-APL-065 in [10-apply.md](10-apply.md) (primary, from tests). This entry keeps its plan and README sources.

After apply replaces a lossy release (`replace-existing`), the ledger entry becomes `upgraded` and `upgradedUtc` is set to now. Apply replaces the old folder. The apply steps: see [10-apply.md](10-apply.md).

Example: lossless re-import of `ZZ Top / 1999 XXX` over the mp3 target, applied → entry `status = upgraded`, `upgradedUtc = <apply time>`.

### AS-DOC-LSY-031 — After apply, a logged lossy release gets its real target path
Status: Draft | Source: legacy/plan/09-lossy-lossless-tracking.md › Lifecycle

Same rule as AS-DOC-APL-066 in [10-apply.md](10-apply.md) (primary, from tests). This entry keeps its plan source.

After apply writes a `log-for-upgrade` release, the ledger entry's target path is set to the path apply really used. It can differ from the proposed path (a folder name edited in the UI, or a shortened path). A `-WhatIf` apply does not change the ledger.

Example: proposed `E:\Music\ZZ Top\1999 XXX`, user edits the folder to `1999 XXX (Edited)`, apply → `targetPath = E:\Music\ZZ Top\1999 XXX (Edited)`.

## User actions on the ledger

### AS-DOC-LSY-032 — The user can list, ignore, mark upgraded, remove and export entries
Status: Draft | Source: legacy/plan/09-lossy-lossless-tracking.md › CLI helpers; legacy/plan/09-lossy-lossless-tracking.md › Definition of done; legacy/README.md › Reference: lossy/lossless tracking

The user can list the ledger, filtered by status. The user can ignore an entry, mark it upgraded by hand (for example after a replacement outside the tool), remove it, and export it to a CSV or JSON file, filtered by status. The list of `pending-upgrade` entries is the upgrade backlog. Command syntax: see [12-cli.md](12-cli.md).

Example: `lossy list -Status pending-upgrade` shows the backlog; `lossy ignore a1b2c3d4e5f60708` → `status = ignored`.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-05 | Phase 1 draft. |
