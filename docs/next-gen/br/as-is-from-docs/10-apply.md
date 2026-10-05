# 10 — Apply (as-is, from docs and tests)

Status: Draft | Version: 0.1 | Last updated: 2026-10-05

## Scope

What the `apply` stage of the legacy app does today. Apply is the only stage that writes music files. Owned inputs:

- `legacy/tests/Reshelf.Implementation.Tests.ps1` (all Describe blocks)
- `legacy/tests/Reshelf.TagLibSharp.Integration.Tests.ps1` (all Describe blocks)
- `legacy/tests/Reshelf.Pipeline.Tests.ps1` (apply results of both Describe blocks)
- `legacy/plan/08-implementation-module.md`, the apply parts of `legacy/plan/12-build-order-and-milestones.md`
- `MANIFESTO.md` §7 module 5 (Implementation module)
- `legacy/README.md` › "5. Apply" and "6. Check the result"

Error handling that is not specific to apply, and the README troubleshooting list, are in [13-bandcamp-and-errors.md](13-bandcamp-and-errors.md). Contradictions and odd behavior are in [90-suspected-defects.md](90-suspected-defects.md) (AS-DOC-DEF-083 to AS-DOC-DEF-096), not here.

Terms used in this file:

- **stableKey** (deterministic release ID) — the same release gets the same key in every run. Example: `a1b2c3d4e5f60708`.
- **Staging** (temporary work folder) — apply builds a release in `<targetRoot>\.reshelf-staging\<stableKey>\` first and moves it to the final place at the end.
- **Idempotent** (running it twice gives the same result) — a second unchanged apply does no work.
- **Source file-set hash** — a short fingerprint of a release's source audio files.
- **Ledger** — the lossy-tracking file `lossy-tracking.json`.

## Run options and release selection

### AS-DOC-APL-001 — Dry run with -WhatIf writes nothing but reports a full summary
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › -WhatIf produces zero filesystem writes but still returns a full summary; legacy/tests/Reshelf.Pipeline.Tests.ps1 › Full pipeline: Recognition -> EditProposal -> Implementation › -WhatIf with -IncludeUnresolved makes zero filesystem writes; legacy/README.md › 5. Apply; legacy/plan/08-implementation-module.md › Entry point

With `-WhatIf`, apply changes no file and no folder in the source root, the data home or the target root. It does not create the target root and does not write `apply-log.json`. It writes no tags. It still returns the same summary that a real run would return.

Example: one resolved release, `apply -SessionId 2026-09-25-0007 -WhatIf` → summary `Applied 1, Skipped 0, Failed 0`; the target root does not exist after the run; `apply-log.json` does not exist.

Example: the full fixture tree with `-IncludeUnresolved -WhatIf` → `Applied` > 0, and a snapshot of all three roots is the same before and after.

### AS-DOC-APL-002 — The run summary has four counters
Status: Draft | Source: legacy/README.md › 5. Apply; legacy/plan/08-implementation-module.md › Entry point

At the end of a run, apply prints the session ID and four counters:

| Counter | Meaning (README) |
|---|---|
| Applied | Copied and tagged successfully. |
| Skipped | Not yet reviewed (and `-IncludeUnresolved` was not passed), or already applied in an earlier run with unchanged source files. |
| Rejected | The user ticked Reject in the review UI. |
| Failed | Something went wrong for that release. |

Example (README):
```
SessionId : 2026-09-25-0007
Applied   : 96
Skipped   : 7
Rejected  : 4
Failed    : 0
```

### AS-DOC-APL-003 — An unresolved release that needs review is skipped by default
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › skips an ambiguous unresolved release by default and includes it with -IncludeUnresolved; legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › skips a targetAction conflict release with humanReview.resolved = false, leaving the existing target untouched, unless -IncludeUnresolved; legacy/tests/Reshelf.Pipeline.Tests.ps1 › Full pipeline: Recognition -> EditProposal -> Implementation › flags every release for human review since Discogs never matches, and apply skips all of them by default; legacy/README.md › 5. Apply; legacy/plan/08-implementation-module.md › Entry point

Without `-IncludeUnresolved`, apply skips every release where human review is required and not resolved. Apply does not stage it and does not touch its target folder. The release counts as Skipped.

Example: Discogs status `ambiguous`, `humanReview.required = true`, `resolved = false` → `Skipped 1, Applied 0`; no folder `Some Band\2010 Some Album` in the target.

Example: `targetAction = conflict`, `resolved = false`, and the target already has `01 Track.flac` with content `pre-existing-different-content` → `Skipped 1`; no `.reshelf-staging\a1b2c3d4e5f60708` folder; the target file still has `pre-existing-different-content`.

Example: the full fixture tree with Discogs always returning zero results (every release `not-found`, every release needs review) → `Applied 0`, `Skipped` = number of releases, the target root is not created.

### AS-DOC-APL-004 — -IncludeUnresolved also applies unresolved releases
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › skips an ambiguous unresolved release by default and includes it with -IncludeUnresolved; legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › skips a targetAction conflict release with humanReview.resolved = false, leaving the existing target untouched, unless -IncludeUnresolved; legacy/README.md › 5. Apply

With `-IncludeUnresolved`, apply treats unresolved releases like resolved ones. An unresolved `conflict` release then replaces the existing target folder (see AS-DOC-APL-018).

Example: the same `ambiguous` release with `-IncludeUnresolved` → `Applied 1`; `Some Band\2010 Some Album\01 Track.flac` exists.

Example: the same `conflict` release with `-IncludeUnresolved` → `Applied 1`; the target `01 Track.flac` now has content `new-source-content`.

### AS-DOC-APL-005 — A rejected release is never applied
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › never applies a rejected release, even with -IncludeUnresolved; legacy/README.md › 5. Apply; legacy/plan/08-implementation-module.md › Entry point

Apply never applies a release with `humanReview.rejected = true`, also not with `-IncludeUnresolved`. It counts the release as Rejected, not as Skipped. The flag means "apply what nobody reviewed yet", not "ignore a rejection".

Example: a resolved and rejected release, run with `-IncludeUnresolved` → `Rejected 1, Applied 0, Skipped 0`; no target folder `Some Band\2010 Some Album`.

### AS-DOC-APL-006 — Empty ffmpeg path means "ffmpeg" from PATH
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › falls back to plain "ffmpeg" (PATH resolution) when -FfmpegPath is omitted or empty, instead of failing on the empty settings.json default

When the ffmpeg path is empty or not given, apply calls `ffmpeg` and lets Windows find it on PATH. It does not fail because of the empty default value in `settings.json`. The setting itself: see [03-settings-and-secrets.md](03-settings-and-secrets.md).

Example: `ffmpegPath = ""` → the release applies, `Applied 1`.

### AS-DOC-APL-007 — Apply works release by release
Status: Draft | Source: MANIFESTO.md › 7. Proposed Process / Module Breakdown (5. Implementation module); legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › logs status failed and continues to the next release when tag-writing throws, leaving the staging folder behind; legacy/plan/08-implementation-module.md › Per-release pipeline

Apply takes one release, finishes all steps for it, then goes to the next release, until all releases are done. A failure in one release does not stop the run. The next release still runs.

Example: two releases, tag writing fails for `Band One\2010 Album One` → `Applied 1, Failed 1`; `Band Two\2011 Album Two\01 Track.flac` exists in the target.

### AS-DOC-APL-008 — Steps for one release
Status: Draft | Source: legacy/README.md › 5. Apply; legacy/plan/08-implementation-module.md › Per-release pipeline

For each release that apply does not skip, it does these steps:

1. Builds the release in the staging folder `<targetRoot>\.reshelf-staging\<stableKey>\`.
2. Splits a one-file + cue release with ffmpeg, or copies the track files.
3. Downloads or reads the chosen cover and resizes it with ffmpeg to `coverMaxDimension` (600 px by default).
4. Writes the tags (Artist, Album Artist, Album, Year, Disc, Track, Title, Compilation) and embeds the cover with TagLibSharp.
5. Copies the included companion files.
6. Moves the staged folder to `<targetRoot>\<Artist>\<yyyy Album>\`.
7. Updates the lossy ledger and writes the apply-log entry (plan 08 steps 9–10).

Example: release `a1b2c3d4e5f60708` is built in `<targetRoot>\.reshelf-staging\a1b2c3d4e5f60708\` and ends in `<targetRoot>\Some Band\2010 Some Album\`.

## Skip logic for already-applied releases

### AS-DOC-APL-009 — A release with no apply-log entry needs apply
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Test-ReshelfReleaseNeedsApply › reports NeedsApply true with no prior apply-log entry

When `apply-log.json` has no entry for the release's stableKey, apply processes the release. Apply also computes the source file-set hash for it.

Example: stableKey `aaaaaaaaaaaaaaaa`, no log entry, source `01 Track.flac` exists → needs apply, hash is not empty.

### AS-DOC-APL-010 — Source file-set hash (plan only)
Status: Draft | Source: legacy/plan/10-error-handling-and-edge-cases.md › Re-runs and duplicate detection

The source file-set hash is a hash of the sorted list of `file name + size` of every audio file in the release (plan only — tests only show that the hash exists and changes).

Example: not given in the sources.

### AS-DOC-APL-011 — An unchanged applied release is skipped
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Test-ReshelfReleaseNeedsApply › reports NeedsApply false when a matching applied entry with the same source-file-set hash already exists under the current TargetRoot; legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › skips every release on a second, unchanged run and makes no ffmpeg/tag-writing calls; legacy/README.md › 5. Apply; legacy/plan/08-implementation-module.md › Per-release pipeline; legacy/plan/08-implementation-module.md › Definition of done

Apply skips a release when all of these are true: the apply-log entry has status `applied`, the logged hash equals the current source file-set hash, the logged target path is under the current target root, and that folder exists. A skipped release gets no ffmpeg call and no tag write. The release counts as Skipped.

Example: first run `Applied 1`; second run with the same proposal → `Applied 0, Skipped 1, Failed 0`; tags were written only once in total.

### AS-DOC-APL-012 — Changed source files make a release apply again
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Test-ReshelfReleaseNeedsApply › reports NeedsApply true when the logged entry is applied but the source file set hash has changed

When the logged hash differs from the current source file-set hash, apply processes the release again.

Example: logged hash `stale-hash-that-cannot-match`, status `applied`, target folder exists → needs apply.

### AS-DOC-APL-013 — A failed release is retried on the next run
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Test-ReshelfReleaseNeedsApply › reports NeedsApply true when the logged entry exists but its status is failed, even with a matching hash; legacy/plan/10-error-handling-and-edge-cases.md › Session persistence and resume

When the logged status is `failed`, apply processes the release again, even when the hash matches.

Example: entry status `failed`, error `boom`, same hash → needs apply.

### AS-DOC-APL-014 — A new target root makes a release apply again
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Test-ReshelfReleaseNeedsApply › reports NeedsApply true when the logged entry is applied with a matching hash but its targetPath is outside the current TargetRoot

When the logged target path is not under the current target root, apply processes the release again. This covers a target root that moved, for example to a new drive.

Example: logged path `<oldTargetRoot>\Some Band\2010 Some Album` exists, status `applied`, same hash, current target root is a different folder → needs apply.

### AS-DOC-APL-015 — A deleted target folder makes a release apply again
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Test-ReshelfReleaseNeedsApply › reports NeedsApply true when the logged entry is applied with a matching hash and TargetRoot, but the target folder was deleted

When the logged target folder no longer exists, apply processes the release again.

Example: entry `applied`, same hash, path `<targetRoot>\Some Band\2010 Some Album` under the current root, but the folder is not on disk → needs apply.

### AS-DOC-APL-016 — All source files gone: skip only when already applied
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Test-ReshelfReleaseNeedsApply › falls back to a null Hash and treats a missing/already-applied entry as not needing re-apply, when every source file is already gone; legacy/tests/Reshelf.Implementation.Tests.ps1 › Test-ReshelfReleaseNeedsApply › reports NeedsApply true (source files gone) when there is no prior applied entry at all

When every source file of a release is missing, the hash is empty. It is not an error in the check. If the log has an `applied` entry, apply skips the release, whatever the logged hash is. If the log has no entry, apply processes the release (and the copy then fails, see AS-DOC-APL-024).

Example: source `needs-apply-5\gone.flac` missing, entry `applied` with hash `irrelevant`, target folder exists → no apply, hash empty.

Example: source `needs-apply-6\gone.flac` missing, no entry → needs apply, hash empty.

## Staging and final commit

### AS-DOC-APL-017 — The release is built in staging and moved at the end
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfReleaseStaging › stages tracks and a nested companion, returning Success with the untruncated final target path; legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › produces the correct final layout, calls Set-ReshelfAudioTags per track with the expected tags/cover, cleans up working files, and writes a correct apply-log entry; legacy/plan/08-implementation-module.md › Per-release pipeline; legacy/plan/08-implementation-module.md › Why staging-then-commit

Apply puts all files of a release into `<targetRoot>\.reshelf-staging\<stableKey>\` first, with their final names. It writes tags on the staged files. Only when every step for the release succeeds, apply moves the staged folder to `<targetRoot>\<artistFolderName>\<releaseFolderName>\`. So a half-done release never sits at its final path.

Example: tags are written to `<targetRoot>\.reshelf-staging\a1b2c3d4e5f60708\01 Track.flac`; after the run, `<targetRoot>\Some Band\2010 Some Album\01 Track.flac` and `...\Scans\front.jpg` exist.

### AS-DOC-APL-018 — An existing target folder is replaced only for update or approved conflict
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › skips a targetAction conflict release with humanReview.resolved = false, leaving the existing target untouched, unless -IncludeUnresolved; legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › marks the lossy-tracking entry upgraded on a replace-existing release; legacy/plan/08-implementation-module.md › Per-release pipeline (step 8)

When the final folder already exists, apply deletes it and puts the new release in its place only when `targetAction` is `update-existing` or `conflict`. A `conflict` release reaches this point only when it is resolved or `-IncludeUnresolved` is set. The meaning of each `targetAction`: see [07-proposal-matching.md](07-proposal-matching.md).

Example: `update-existing`, the target has `01 Track.mp3` → after apply, the folder has `01 Track.flac` and no `01 Track.mp3`.

Example: `conflict` with `-IncludeUnresolved` → `01 Track.flac` content changes from `pre-existing-different-content` to `new-source-content`.

### AS-DOC-APL-019 — create-new fails when the target folder already exists
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › fails a create-new release whose target folder already exists, leaving that folder untouched (plan/12 milestone 7); legacy/plan/08-implementation-module.md › Per-release pipeline (step 8); legacy/plan/12-build-order-and-milestones.md › Status (milestones 3–7)

When the final folder already exists and `targetAction` is any other value (for example `create-new`), apply does not touch the folder. The release fails. The error says `target folder '<path>' already exists but the proposal says '<action>'; re-run propose`. Apply checks this right before the move, not only from the proposal.

Example: `create-new`, the target already has `Some Band\2010 Some Album\01 Track.mp3` with content `existing-lossy-content` → `Failed 1, Applied 0`; the mp3 keeps its content; no `01 Track.flac`; log status `failed`, message contains `already exists but the proposal says 'create-new'`.

### AS-DOC-APL-020 — The staging root is removed when every release applies
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › removes the empty .reshelf-staging folder once every release in the run has applied successfully; legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › removes the now-empty .reshelf-staging folder after every release applies, but leaves a failed release staged for inspection; legacy/plan/12-build-order-and-milestones.md › Sequence (7. Idempotency and upgrade validation)

When every release in the run applies, apply deletes the empty `<targetRoot>\.reshelf-staging` folder. When a release fails, apply leaves its staging subfolder in place, so the user can look at it. Then `.reshelf-staging` also stays.

Example: one release, success → no `<targetRoot>\.reshelf-staging`.

Example: one release, the final move throws `commit boom` → `Failed 1`; `<targetRoot>\.reshelf-staging\a1b2c3d4e5f60708` exists.

## Source is read-only

### AS-DOC-APL-021 — Apply never deletes or changes a source file
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › never deletes source tracks or companion files - source is always read-only; legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › cue-sheet release › splits once per cue track and never deletes the cue/audio source - source is always read-only; legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › cue-sheet release › leaves the cue/audio source in place when the release fails after splitting; legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › excludes a companion with include = $false from copying, and always leaves its source in place; legacy/README.md › 5. Apply; legacy/plan/08-implementation-module.md › Decisions & rationale; legacy/plan/12-build-order-and-milestones.md › Status (milestones 3–7); MANIFESTO.md › 7. Proposed Process / Module Breakdown (1. Settings module)

Apply only copies. It never deletes or modifies a file under the source root: not the tracks, not the companions, not an excluded companion, and not the `.cue` and audio file of a split release. This is true after success and after failure. `copy` is the only copy mode. (An old `move` mode deleted sources after apply. It was removed after it destroyed source releases with no backup.)

Example: after a successful apply, source `Some Band\2010 Some Album\01 Track.flac` and `...\Scans\front.jpg` still exist.

Example: after a cue release fails at tag writing, `Pink Floyd\1994 Live In Concert (Bootleg)\Live In Concert.cue` and `Live In Concert.flac` still exist.

Example (plan 12): real apply of 27 releases → the source was byte-identical before and after.

## Copying tracks

### AS-DOC-APL-022 — A track is copied under its proposed file name
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › corrects the lossy-tracking targetPath to the committed path on a log-for-upgrade release, but not under -WhatIf; legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › produces the correct final layout, calls Set-ReshelfAudioTags per track with the expected tags/cover, cleans up working files, and writes a correct apply-log entry; legacy/README.md › 5. Apply

A track that is not part of a cue sheet is copied as it is (no conversion). It gets the track's proposed file name. The folders get the proposed artist and release folder names, including names the user edited in the review UI.

Example: source `01 Track.mp3`, proposed release folder `2010 Some Album (Edited)` → `<targetRoot>\Some Band\2010 Some Album (Edited)\01 Track.mp3`.

### AS-DOC-APL-023 — Tags keep the raw text, file names are made safe
Status: Draft | Source: legacy/tests/Reshelf.TagLibSharp.Integration.Tests.ps1 › Full pipeline with real TagLibSharp and ffmpeg › applies the release, writes correct real tags and cover, and sanitizes invalid characters

Folder and file names on disk contain no character that Windows forbids in file names. The tag values keep the original text with those characters. The rules that make names safe: see [02-text-and-naming-rules.md](02-text-and-naming-rules.md).

Example: Discogs title `OK Computer? / Live: Edition`, track `Paranoid Android?` → release folder name and track file names have no invalid characters; the Album tag in each file is `OK Computer? / Live: Edition`.

### AS-DOC-APL-024 — A missing source file fails the release with its real path
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › fails with an error naming the real missing source file, not a confusing later-step message, when a source file was deleted after proposing

When a source file was deleted after `propose`, the copy step fails at once. The release fails. The error message names the missing source file. It does not name a file in the staging folder. Nothing appears in the target.

Example: the source folder `Some Band\2010 Some Album` is deleted after propose → `Failed 1, Applied 0`; no target folder; log message contains the source path of `01 Track.flac` and does not contain `.reshelf-staging`.

## Cue split with ffmpeg

### AS-DOC-APL-025 — One ffmpeg split per cue track
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › cue-sheet release › splits once per cue track and never deletes the cue/audio source - source is always read-only; legacy/tests/Reshelf.Pipeline.Tests.ps1 › Full pipeline: Recognition -> EditProposal -> Implementation › a real -IncludeUnresolved run produces the correct target layout for every planted pattern, and a re-run is a no-op; legacy/README.md › 5. Apply; MANIFESTO.md › 7. Proposed Process / Module Breakdown (5. Implementation module)

For a one-file + cue release, apply calls ffmpeg once per cue track. Each call cuts one time range out of the audio file into one track file with the proposed file name.

Example: fixture `Pink Floyd\1994 Live In Concert (Bootleg)\Live In Concert.cue` (`INDEX 01 00:00:00` and `INDEX 01 03:12:45`) → 2 calls: `0.000` to `192.600`, and `192.600` to the end; target `Pink Floyd\1994 Live In Concert\01 Speak To Me.flac` and `02 Breathe.flac`.

### AS-DOC-APL-026 — Cue times are minutes:seconds:frames
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › ConvertTo-ReshelfFfmpegSeconds › converts MM:SS:FF cue frames (00-74) into fractional seconds, not HH:MM:SS

Apply reads a cue time `MM:SS:FF` as minutes, seconds and frames (75 frames per second, frames 00–74). It passes the time to ffmpeg as seconds with three decimals. It never reads the cue time as hours:minutes:seconds.

Example: `09:26:73` → `566.973`. Example: `03:12:45` → `192.600`. Example: `00:00:00` → `0.000`.

### AS-DOC-APL-027 — Each track ends where the next track starts
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › ConvertFrom-ReshelfCueTrackRanges › sorts by cueTimestamp (not proposedTrackNumber) and pairs each track's own cueTimestamp as Start with the next track's as End; legacy/tests/Reshelf.Implementation.Tests.ps1 › ConvertFrom-ReshelfCueTrackRanges › returns a single range with a null EndTimestamp for a single-track cue release; legacy/tests/Reshelf.Implementation.Tests.ps1 › ConvertFrom-ReshelfCueTrackRanges › returns an empty array, not an error, for an empty track list

Apply sorts the cue tracks of one audio file by their cue time, not by the proposed track number. A track starts at its own cue time and ends at the next track's cue time. The last track has no end time, so it runs to the end of the file. An empty track list gives no ranges and no error.

Example: tracks given in order 2, 1, 3 with cue times `00:03:00`, `00:00:00`, `00:07:30` → track 1: `0.000`–`3.000`; track 2: `3.000`–`7.400`; track 3: `7.400`–(no end).

Example: one track `01 Only.flac` at `00:00:00` → `0.000`–(no end).

### AS-DOC-APL-028 — A per-disc cue release splits each disc from its own file
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › ConvertFrom-ReshelfCueTrackRanges › groups by sourceFilePath instead of sorting the whole list together, for a per-disc-cue release with repeated track numbers; legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › cue-sheet release › splits a per-disc-cue release from each disc's own source file, not one shared source

When each disc has its own audio file and cue sheet, apply builds the time ranges per audio file. Tracks of different discs never mix, even when their track numbers repeat. The last track of each disc runs to the end of its own file.

Example: `CD 1\Disc One.flac` (tracks at `00:00:00` and `02:00:00`) and `CD 2\Disc Two.flac` (track at `00:00:00`) → disc 1: `0.000`–`120.000`, `120.000`–(no end); disc 2: `0.000`–(no end).

Example: 3 split calls → `Some Band\2001 Two Discs\01 Disc One Track One.flac`, `02 Disc One Track Two.flac`, `01 Disc Two Track One.flac`.

### AS-DOC-APL-029 — FLAC and APE sources are re-encoded to FLAC, others are stream-copied
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfFfmpegSplit codec selection › uses -c copy (stream copy) for a source that is neither .ape nor .flac; legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfFfmpegSplit codec selection › uses -c:a flac (re-encode) for an .ape source, since ffmpeg cannot write .ape; legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfFfmpegSplit codec selection › uses -c:a flac (re-encode) for a .flac source, since stream-copy does not recompute STREAMINFO duration after trimming

The ffmpeg split arguments depend on the source format:

| Source | ffmpeg arguments | Reason (test) |
|---|---|---|
| `.flac` | `-c:a flac` (re-encode to FLAC, lossless) | stream copy does not fix the FLAC duration header after a cut |
| `.ape` | `-c:a flac`, output `.flac` | ffmpeg cannot write `.ape` |
| any other, e.g. `.wav` | `-c copy` (stream copy, no re-encode) | — |

Example: `source.wav` → `out.wav` with `-c copy`, no `-c:a`.

Example: `source.ape` → `out.flac` with `-c:a flac`, no `copy`.

### AS-DOC-APL-030 — One retry for the FLAC "invalid block size" error
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfFfmpegSplit FLAC "invalid block size" retry › retries once with the start timestamp nudged by 0.05s and succeeds, without throwing; legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfFfmpegSplit FLAC "invalid block size" retry › also retries when there is no end timestamp, since the bug is about the start boundary, not the end

When the ffmpeg split fails and its error output contains `invalid block size`, apply runs the split once more with the start time moved 0.05 s later. When the retry succeeds, there is no error. This also works when the track has no end time.

Example: start `322.200`, end `535.070`, first call exit code `-22` with `[flac @ 0x0] invalid block size: 4` → second call with start `322.250` succeeds; 2 calls in total. (Real cases: AC-DC "Dog Eat Dog", "Come And Get It".)

Example: start `600.000`, no end → 2 calls, no error.

### AS-DOC-APL-031 — No retry in the other cases
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfFfmpegSplit FLAC "invalid block size" retry › does not retry and throws immediately when ffmpeg fails for an unrelated reason; legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfFfmpegSplit FLAC "invalid block size" retry › does not retry and throws the ordinary message when the start timestamp is not plain seconds; legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfFfmpegSplit FLAC "invalid block size" retry › does not retry and throws the ordinary message when nudging the start would land at or past the end

Apply calls ffmpeg only once and reports the normal error (with the exit code) when:

- the error is not `invalid block size`;
- the start time is not plain seconds;
- the moved start time would be at or after the end time.

Example: error `Invalid argument`, exit code 1 → error message contains `exit code 1`, 1 call.

Example: start `00:00:00`, end `00:01:00`, `invalid block size` → error contains `exit code -22`, 1 call.

Example: start `100.000`, end `100.030`, `invalid block size` → error contains `exit code -22`, 1 call.

### AS-DOC-APL-032 — Split track count is checked (plan only)
Status: Draft | Source: legacy/plan/08-implementation-module.md › Per-release pipeline (step 2); legacy/plan/08-implementation-module.md › Decisions & rationale

After the split, apply checks that the number of track files equals the number of tracks in the cue sheet. If not, the release fails and nothing goes to the target (plan only — no test shows this check).

Example: not given in the sources.

## ffmpeg calls

### AS-DOC-APL-033 — Paths with spaces reach ffmpeg as one argument
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfFfmpegSplit / Invoke-ReshelfFfmpegResize argument quoting › wraps a space-containing source/output path as a single quoted argv element for ffmpeg split; legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfFfmpegSplit / Invoke-ReshelfFfmpegResize argument quoting › wraps a space-containing source/output path as a single quoted argv element for ffmpeg resize

For split and for resize, apply puts each input and output path in double quotes. So a path with spaces stays one argument for ffmpeg.

Example (split): source `...\Pink Floyd\1994 Live In Concert (Bootleg)\Live In Concert.flac` and output `...\staged output with spaces.flac` → both appear in the arguments as `"<path>"`, never without quotes.

Example (resize): `cover art (large).jpg` → `cover resized.jpg`, both quoted.

### AS-DOC-APL-034 — An ffmpeg error message has the exit code and ffmpeg's own text
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfFfmpegResize error handling › includes ffmpeg stderr in the thrown message on failure

When ffmpeg fails, the error message contains the exit code and the text ffmpeg wrote to its error output (stderr).

Example: resize of `cover.jpg` fails with exit code 1 and stderr `Invalid data found when processing input` → message matches `*exit code 1*Invalid data found when processing input*`.

## Cover art

### AS-DOC-APL-035 — The chosen cover is downloaded once and resized once per release
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › produces the correct final layout, calls Set-ReshelfAudioTags per track with the expected tags/cover, cleans up working files, and writes a correct apply-log entry; legacy/tests/Reshelf.Pipeline.Tests.ps1 › Full pipeline: Recognition -> EditProposal -> Implementation › a real -IncludeUnresolved run produces the correct target layout for every planted pattern, and a re-run is a no-op; legacy/README.md › 5. Apply; legacy/plan/08-implementation-module.md › Per-release pipeline (step 5)

When the chosen cover is a web address (the normal Discogs case), apply downloads it once into the staging folder. A local cover file (for example a loose `cover.jpg` in the source) needs no download. Then apply resizes the cover once with ffmpeg to the release's `coverArt.targetMaxDimension` (600 px on the longest side by default, setting `coverMaxDimension`).

Example: chosen cover `https://example.com/cover.jpg` → 1 download, 1 resize.

Example: fixture `ZZ Top\1999 XXX` with only a loose `cover.jpg` as candidate → the resize reads the local file directly.

### AS-DOC-APL-036 — The resized cover is embedded into each track
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › produces the correct final layout, calls Set-ReshelfAudioTags per track with the expected tags/cover, cleans up working files, and writes a correct apply-log entry; legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › gap-fills the found cover into a track that has no embedded cover of its own; legacy/tests/Reshelf.TagLibSharp.Integration.Tests.ps1 › Full pipeline with real TagLibSharp and ffmpeg › applies the release, writes correct real tags and cover, and sanitizes invalid characters

Apply embeds the resized cover into the tags of every track that has no cover of its own. After a real run, each track has exactly one picture of type FrontCover.

Example: the tag write for `01 Track.flac` gets the cover file `<targetRoot>\.reshelf-staging\a1b2c3d4e5f60708\.reshelf-cover-resized.jpg`.

Example: real run of `Radiohead\1997 OK Computer` (3 tracks) → each file has 1 picture, type FrontCover.

### AS-DOC-APL-037 — A track's own embedded cover is kept
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › leaves a track's picture tag untouched when the chosen cover is "existing (embedded)" and that track already has one; legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › gap-fills the found cover into a track that has no embedded cover of its own

When the chosen cover is `existing (embedded)` and a track already has its own embedded cover, apply leaves that track's picture as it is. A track without its own cover gets the chosen cover (gap-fill). The resize step still runs once, because another track can need the gap-fill copy.

Example: chosen cover `<dataHome>\embedded-covers\existing-cover.jpg` (`existing (embedded)`), the track has that cover → 1 resize; the tag write gets no cover path, so the picture stays.

Example: the same chosen cover, the track has no cover → the tag write gets `.reshelf-cover-resized.jpg`.

### AS-DOC-APL-038 — Cover working files do not reach the target
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › produces the correct final layout, calls Set-ReshelfAudioTags per track with the expected tags/cover, cleans up working files, and writes a correct apply-log entry; legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › keeps a loose companion literally named cover.jpg (manifesto section 4.5) alongside a downloaded Discogs cover; legacy/tests/Reshelf.Pipeline.Tests.ps1 › Full pipeline: Recognition -> EditProposal -> Implementation › a real -IncludeUnresolved run produces the correct target layout for every planted pattern, and a re-run is a no-op

The files that apply makes only to embed the cover (`cover-source.download`, `.reshelf-cover-resized.jpg`, a downloaded `cover.jpg`) are not in the final release folder. A loose source companion that is really named `cover.jpg` is a normal companion and is copied.

Example: Discogs cover, no companion → final folder has no `cover.jpg` and no `cover-source.download`.

Example: Discogs cover plus loose source `cover.jpg` → final folder has `cover.jpg` and no `.reshelf-cover-resized.jpg`.

## Tag writing

### AS-DOC-APL-039 — Apply writes eight tag fields per track
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › produces the correct final layout, calls Set-ReshelfAudioTags per track with the expected tags/cover, cleans up working files, and writes a correct apply-log entry; legacy/tests/Reshelf.TagLibSharp.Integration.Tests.ps1 › Set-ReshelfAudioTags round-trip (real TagLibSharp) › <_> (flac, mp3) › persists every tag field; legacy/tests/Reshelf.TagLibSharp.Integration.Tests.ps1 › Full pipeline with real TagLibSharp and ffmpeg › applies the release, writes correct real tags and cover, and sanitizes invalid characters; legacy/README.md › 5. Apply; legacy/plan/08-implementation-module.md › Per-release pipeline (step 6)

For every track, apply writes Artist, Album Artist, Album, Year, Disc, Track, Title and Compilation with TagLibSharp. The values come from the track's proposed tags. Reading the file back gives the same values. This works for FLAC and MP3. Which values the proposal holds: see [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md).

Example: proposal tags `Some Band`, `Some Band`, `Some Album`, `2010`, disc `1`, track `1`, `Track`, compilation `false` → the same values go to the tag write.

Example: flac and mp3 written with `Radiohead`, `Radiohead`, `OK Computer`, `1997`, disc `1`, track `2`, `Paranoid Android` → read back with the same values.

### AS-DOC-APL-040 — The Compilation flag is written both ways, missing means false
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › passes a track's isCompilation tag through to Set-ReshelfAudioTags unchanged; legacy/tests/Reshelf.TagLibSharp.Integration.Tests.ps1 › Set-ReshelfAudioTags round-trip (real TagLibSharp) › <_> (flac, mp3) › round-trips the Compilation flag both ways; legacy/tests/Reshelf.TagLibSharp.Integration.Tests.ps1 › Set-ReshelfAudioTags round-trip (real TagLibSharp) › <_> (flac, mp3) › defaults the Compilation flag to false when isCompilation is missing from tags; legacy/plan/08-implementation-module.md › Per-release pipeline (step 6)

Apply writes the track's `isCompilation` value as it is. When the value is missing, apply writes `false`. Apply can switch the flag on and off on the same file. The flag goes to the format's own tag: ID3v2 `TCMP`, MP4 `cpil`, or Vorbis/FLAC `COMPILATION` (plan 08).

Example: `Various\2008 A Compilation`, `isCompilation = true` → the tag write gets `true`.

Example: write `true`, then write `false` on the same flac/mp3 → read back `true`, then `false`.

### AS-DOC-APL-041 — Non-ASCII text survives the tag write
Status: Draft | Source: legacy/tests/Reshelf.TagLibSharp.Integration.Tests.ps1 › Set-ReshelfAudioTags round-trip (real TagLibSharp) › <_> (flac, mp3) › round-trips non-ASCII text

Apply writes non-ASCII text (accents, Cyrillic) into tags without loss, for FLAC and MP3.

Example: Artist `Björk`, Album `Океан Ельзи`, Title `Ça plane pour moi` → read back the same.

### AS-DOC-APL-042 — A second tag write replaces the old tags
Status: Draft | Source: legacy/tests/Reshelf.TagLibSharp.Integration.Tests.ps1 › Set-ReshelfAudioTags round-trip (real TagLibSharp) › <_> (flac, mp3) › replaces old tags and old cover on a second write

When apply writes tags to a file that already has tags, the new values replace the old ones.

Example: first `First` / `First Album` / `First Title` / disc 1 / track 1, then `Second` / `Second Album` / `Second Title` / disc 2 / track 5 → read back the second set.

### AS-DOC-APL-043 — One front cover per file, replaced or kept as asked
Status: Draft | Source: legacy/tests/Reshelf.TagLibSharp.Integration.Tests.ps1 › Set-ReshelfAudioTags round-trip (real TagLibSharp) › <_> (flac, mp3) › embeds the cover as one FrontCover jpeg with identical bytes; legacy/tests/Reshelf.TagLibSharp.Integration.Tests.ps1 › Set-ReshelfAudioTags round-trip (real TagLibSharp) › <_> (flac, mp3) › replaces old tags and old cover on a second write; legacy/tests/Reshelf.TagLibSharp.Integration.Tests.ps1 › Set-ReshelfAudioTags round-trip (real TagLibSharp) › <_> (flac, mp3) › leaves the cover alone when no CoverImagePath is given on a later write

When a cover is given, apply embeds it as exactly one picture: type FrontCover, MIME type `image/jpeg`, the same bytes as the file. A later write with a new cover replaces the old picture. A later write without a cover keeps the existing picture.

Example: red 64×64 `cover.jpg` → 1 picture, FrontCover, `image/jpeg`, same bytes.

Example: write with red `cover-a.jpg`, then with blue `cover-b.jpg` → 1 picture with the bytes of `cover-b.jpg`.

Example: write with `cover.jpg` and title `T1`, then without cover and title `T2` → title `T2`, still 1 picture with the bytes of `cover.jpg`.

### AS-DOC-APL-044 — Tags can be written to a .mpc file with a leading ID3v2 tag
Status: Draft | Source: legacy/tests/Reshelf.TagLibSharp.Integration.Tests.ps1 › Set-ReshelfAudioTags round-trip (real TagLibSharp) › writes tags to a .mpc file whose leading ID3v2 tag trips TagLib#'s MusePack properties reader

Some Musepack (`.mpc`) files start with an ID3v2 tag, and the tag library cannot read their audio properties. Apply still writes tags to such a file.

Example: `track.mpc` with old tags `Old Artist` / `Old Album` / `Old Title` → write `Nostromo` / `Eyesore` / `Epitomize` → read back `Nostromo`, `Eyesore`, `Epitomize`. (Real case: the Nostromo "Eyesore" release.)

### AS-DOC-APL-045 — A tag write failure fails only that release
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › logs status failed and continues to the next release when tag-writing throws, leaving the staging folder behind; legacy/plan/08-implementation-module.md › Edge cases

When tag writing fails for a release (for example a corrupt file), the release fails. The log entry has status `failed` and the error text. The staging folder of the release stays. The release does not appear in the target. The other releases continue.

Example: tag write throws `tag write boom` for `bbbbbbbbbbbbbbbb` → its log entry is `failed` with `tag write boom`; `<targetRoot>\.reshelf-staging\bbbbbbbbbbbbbbbb` exists; no `Band One\2010 Album One`; `aaaaaaaaaaaaaaaa` is `applied`.

## Reading tags back

These rules come from tests in this area's inputs. The recognize stage uses the same reading. The lead may move them to [05-recognition.md](05-recognition.md).

### AS-DOC-APL-046 — Reading a file gives tags, format, lossless flag and duration
Status: Draft | Source: legacy/tests/Reshelf.TagLibSharp.Integration.Tests.ps1 › Get-ReshelfAudioTags on a real file (real TagLibSharp) › reads back artist/album/title, format, lossless flag and duration for a flac file; legacy/tests/Reshelf.TagLibSharp.Integration.Tests.ps1 › Get-ReshelfAudioTags on a real file (real TagLibSharp) › reads back format and lossless flag for an mp3 file

Reading a real audio file gives the artist, album and title tags, the format (from the file type), whether the format is lossless, and the duration in seconds.

Example: 1-second `track.flac` tagged `Artist` / `Album` / `Title` → `Artist`, `Album`, `Title`, format `flac`, lossless `true`, duration between 0.9 and 1.2.

Example: 1-second `track.mp3` (128k) → format `mp3`, lossless `false`, duration between 0.9 and 1.2.

### AS-DOC-APL-047 — An embedded cover is saved to the data home cache
Status: Draft | Source: legacy/tests/Reshelf.TagLibSharp.Integration.Tests.ps1 › Get-ReshelfAudioTags on a real file (real TagLibSharp) › extracts an already-embedded cover to a cache file under DataHome and returns EmbeddedCoverPath; legacy/tests/Reshelf.TagLibSharp.Integration.Tests.ps1 › Get-ReshelfAudioTags on a real file (real TagLibSharp) › returns a null EmbeddedCoverPath when the file has no embedded picture

When a file has an embedded picture, reading it saves the picture bytes to a file under `<dataHome>\embedded-covers\` and returns that path. When the file has no picture, the path is empty.

Example: `track.flac` with a green cover → a file under `<dataHome>\embedded-covers\` with the same bytes.

Example: `track-no-cover.flac` → no path.

### AS-DOC-APL-048 — A .mpc file with a leading ID3v2 tag gives a tag-only read
Status: Draft | Source: legacy/tests/Reshelf.TagLibSharp.Integration.Tests.ps1 › Get-ReshelfAudioTags on a real file (real TagLibSharp) › falls back to a tag-only read for a .mpc file whose leading ID3v2 tag trips TagLib#'s MusePack properties reader

When the audio properties of a `.mpc` file cannot be read because of a leading ID3v2 tag, reading still returns the tags. It marks the properties as unavailable, with duration 0 and lossless `false`.

Example: `track.mpc` with `Nostromo` / `Eyesore` / `Epitomize` → the same three values, format `mpc`, lossless `false`, properties unavailable `true`, duration `0`.

## Companion files

### AS-DOC-APL-049 — A nested companion keeps its subfolder and name
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Resolve-ReshelfCompanionTargetPath › keeps a nested companion's relative subfolder path and sanitized file name unchanged; legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfReleaseStaging › stages tracks and a nested companion, returning Success with the untruncated final target path; legacy/tests/Reshelf.Pipeline.Tests.ps1 › Full pipeline: Recognition -> EditProposal -> Implementation › a real -IncludeUnresolved run produces the correct target layout for every planted pattern, and a re-run is a no-op; legacy/plan/08-implementation-module.md › Per-release pipeline (step 7)

A companion with placement `nested` goes to the same subfolder path inside the release folder, with the same file name.

Example: source `...\2010 Album\Scans\back cover.jpg` → `C:\target\Some Band\2010 Album\Scans\back cover.jpg`.

Example: fixture `ZZ Top\2003 Mescalero` → `scans\back.jpg` once in the target release.

### AS-DOC-APL-050 — A loose companion gets its proposed file name
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Resolve-ReshelfCompanionTargetPath › uses the loose companion's proposedFileName when present; legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › uses proposedFileName for a loose companion when the proposal supplies one; legacy/plan/08-implementation-module.md › Per-release pipeline (step 7)

A companion with placement `loose` goes directly into the release folder under its proposed file name. How the name is proposed: see [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md).

Example: source `01 back.jpg`, proposed `Booklet 01 back.jpg` → `C:\target\Some Band\2010 Album\Booklet 01 back.jpg`.

Example: source `01-photo.jpg`, proposed `Backstage Photo.jpg` → `...\2010 Some Album\Backstage Photo.jpg`.

### AS-DOC-APL-051 — Without a proposed name, the loose name starts with the kind word
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Resolve-ReshelfCompanionTargetPath › falls back to computing a letter-first name from kind when proposedFileName is missing (older proposal.json); legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › falls back to a kind-word-prefixed name for a loose companion from a pre-existing proposal with no proposedFileName, and preserves a nested companion subfolder; legacy/plan/08-implementation-module.md › Per-release pipeline (step 7)

When an older `proposal.json` has no proposed file name for a loose companion, apply builds a name at apply time. The name starts with a letter, from the companion's kind. It never starts with a digit and never with the old `_` prefix.

Example: loose `01-photo.jpg`, kind `photo` → `Photo 01-photo.jpg`.

Example: loose `01 back.jpg`, kind `cover` → a name that starts with a letter, not with `0`.

### AS-DOC-APL-052 — An excluded companion is not copied and not checked
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfReleaseStaging › skips a companion with include=false entirely - not copied, not counted toward a naming collision; legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › excludes a companion with include = $false from copying, and always leaves its source in place; legacy/plan/08-implementation-module.md › Per-release pipeline (step 7)

A companion with `include = false` is skipped fully. Apply does not copy it and does not check its name. Its source file stays.

Example: excluded `1 bad name.jpg` (invalid name) → the release succeeds; no `1 bad name.jpg` in staging.

Example: excluded `Booklet skip.jpg` → not in the target; the source file still exists.

### AS-DOC-APL-053 — A loose companion name must start with a letter
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfReleaseStaging › fails cleanly, without staging any file, when an included loose companion's target name does not start with a letter; legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › fails the release with a clear message when an included loose companion name does not start with a letter; legacy/plan/08-implementation-module.md › Per-release pipeline (step 7)

Before apply copies any file of a release, it checks every included loose companion name. When a name does not start with a letter, the release fails with a clear message. No file of the release is staged. The run continues.

Example: proposed `1 test.jpg` → failure, message contains `must start with a letter`; no staging folder `b1b2c3d4e5f60708`.

Example: proposed `01 photo.jpg` → `Failed 1, Applied 0`.

### AS-DOC-APL-054 — A loose companion name must not equal a track file name
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfReleaseStaging › fails cleanly when a loose companion's target name collides with a track's target file name; legacy/plan/08-implementation-module.md › Per-release pipeline (step 7)

When an included loose companion would get the same name as a track file, the release fails.

Example: track `Track One.flac`, companion `dup.jpg` proposed as `Track One.flac` → failure, message contains `same as a track file name`.

### AS-DOC-APL-055 — Two companions must not go to the same target path
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfReleaseStaging › fails cleanly when two included companions would both be copied to the same target path; legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › fails the release when two included companions would resolve to the same target path; legacy/plan/08-implementation-module.md › Per-release pipeline (step 7)

When two included companions would end at the same target path, the release fails.

Example: `a.jpg` and `b.jpg` both proposed as `Extra Same Name.jpg` → failure, message contains `would both be copied`.

Example: `a.jpg` and `b.jpg` both proposed as `Extra Same.jpg` → `Failed 1, Applied 0`.

## Long paths: name truncation

### AS-DOC-APL-056 — Names stay as they are when the path is short enough
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Resolve-ReshelfTruncatedReleaseNames › leaves normal short names unchanged; legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfReleaseStaging › stages tracks and a nested companion, returning Success with the untruncated final target path

Apply checks the full target path of every file of a release against a limit of 250 characters. When all paths fit, apply keeps the names and marks the release as not truncated.

Example: target root `D:\Music`, `Some Band` / `2010 Some Album` / `01 Track.flac` → not truncated, names unchanged.

### AS-DOC-APL-057 — Long names are shortened, prefixes and extensions are kept
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Resolve-ReshelfTruncatedReleaseNames › truncates long names while keeping every resulting path within budget, and preserves prefixes/extensions; legacy/tests/Reshelf.Implementation.Tests.ps1 › Resolve-ReshelfTruncatedReleaseNames › preserves a dash-separated track-number prefix, not just the default space-separated form; legacy/plan/10-error-handling-and-edge-cases.md › Windows path length

When a full path would be longer than 250 characters, apply shortens the readable part of the artist folder, release folder and track file names until every path fits. It keeps the `yyyy ` year prefix of the release folder, the track number prefix (`NN ` or `NN - `) and the file extension.

Example: deep target root, artist `The Extremely … Long Band Name`, release `2010 Extremely … Long Album Title`, track `01 Extremely … Long Track Title.flac` → truncated; release starts with `2010 `, track starts with `01 ` and ends with `.flac`; full path ≤ 250.

Example: track `01 - Extremely … Long Track Title.flac` → the result starts with `01 - `.

### AS-DOC-APL-058 — Only a real year is a protected prefix
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Resolve-ReshelfTruncatedReleaseNames › does not treat a non-year 4-digit catalog-number prefix as an immune-from-truncation year prefix

The year prefix is protected only when the 4 digits are a real year. A 4-digit catalog number at the start of a release folder name is not protected.

Example: artist of 1000 `A`, track `01 ` + 1000 `B`, root `C:\M`, limit 250: release `2010 Some Album` → 6 characters, starts with `2010 `.

Example: same setup, release `3218 Some Catalog Album` → 1 character, does not start with `3218`.

### AS-DOC-APL-059 — Truncated track names stay different
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Resolve-ReshelfTruncatedReleaseNames › disambiguates two track names that would otherwise collide after truncation, and keeps the disambiguated name within budget

When two track names would become equal after shortening, apply makes them different. Both paths still fit the limit.

Example: `Hidden Extremely … Alpha.flac` and `Hidden Extremely … Beta.flac` (no number prefix) → two different names, both paths ≤ 250.

### AS-DOC-APL-060 — Truncation is recorded in the apply log
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › truncates human-readable names and records it, when the fully-assembled target path would exceed the limit; legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › logs the truncated staged path, not the raw untruncated one, when the commit step fails after staging succeeded; legacy/plan/10-error-handling-and-edge-cases.md › Windows path length

When apply shortens names, the apply-log entry has `truncated = true` and the shortened target path. This is true also when the release fails after staging. So the truncation is visible, not silent.

Example: the long release under a deep root → `Applied 1`; entry `applied`, `truncated = true`, target path ≤ 250 characters and exists; its `.flac` file starts with `01 `.

Example: same release, the final move throws `commit boom` → `Failed 1`; entry `failed`, `truncated = true`, target path ≤ 250 and not the raw long path.

## Apply log

### AS-DOC-APL-061 — The apply log lives in the data home
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Get-ReshelfApplyLogPath / Get-ReshelfApplyLog / Add-ReshelfApplyLogEntry › returns apply-log.json under the given data home; legacy/tests/Reshelf.Implementation.Tests.ps1 › Get-ReshelfApplyLogPath / Get-ReshelfApplyLog / Add-ReshelfApplyLogEntry › returns an empty array, not an error, when apply-log.json does not exist yet

The apply log is the file `apply-log.json` in the data home. It is not session-specific. When the file does not exist yet, the log is empty. That is not an error. Data home location: see [01-data-home-and-storage.md](01-data-home-and-storage.md).

Example: data home `<dataHome>` → `<dataHome>\apply-log.json`.

Example: new data home, no file → 0 entries.

### AS-DOC-APL-062 — One log entry per release, replaced on each run
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Get-ReshelfApplyLogPath / Get-ReshelfApplyLog / Add-ReshelfApplyLogEntry › appends a new entry and writes a file that validates against the apply-log schema; legacy/tests/Reshelf.Implementation.Tests.ps1 › Get-ReshelfApplyLogPath / Get-ReshelfApplyLog / Add-ReshelfApplyLogEntry › upserts (replaces, not appends) an existing entry for the same stableKey; legacy/plan/08-implementation-module.md › Per-release pipeline (step 10)

An entry has: stableKey, apply time (UTC), status (`applied` or `failed`), target path, source file-set hash, error message and truncated flag. The file matches the `apply-log` schema. The log has at most one entry per stableKey: a new result replaces the old entry (upsert — insert or update).

Example: first entry `a1b2c3d4e5f60708`, `applied`, `C:\target\Some Band\2010 Album`, hash `deadbeef` → 1 entry, the file is schema-valid.

Example: `failed` with `boom`, then `applied` for the same key → 1 entry, status `applied`, no error message.

### AS-DOC-APL-063 — A successful apply writes a full log entry
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › produces the correct final layout, calls Set-ReshelfAudioTags per track with the expected tags/cover, cleans up working files, and writes a correct apply-log entry

After a release applies, its log entry has status `applied`, the final release folder as target path, no error message, `truncated = false` (when no shortening happened) and a non-empty hash.

Example: `a1b2c3d4e5f60708` → `applied`, `<targetRoot>\Some Band\2010 Some Album`, no error, `truncated = false`, hash present.

## Session stage after apply

### AS-DOC-APL-064 — Apply sets the session stage from the results
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › sets the session stage to applied when everything succeeds, partially-applied when something fails, and applied (not partially-applied) when releases are only skipped; legacy/plan/10-error-handling-and-edge-cases.md › Session persistence and resume

At the end of a run, apply sets the session stage to `partially-applied` when at least one release failed. Otherwise it sets `applied`. A skipped release does not count as a failure. Stage meanings: see [04-sessions.md](04-sessions.md).

Example: all releases succeed → `applied`. Example: one release fails at tag writing → `partially-applied`. Example: the only release is unresolved and skipped → `Skipped 1, Failed 0`, stage `applied`.

## Lossy tracking updates from apply

Ledger format and the `lossy` commands: see [11-lossy-tracking.md](11-lossy-tracking.md).

### AS-DOC-APL-065 — A lossless replacement marks the ledger entry upgraded
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › marks the lossy-tracking entry upgraded on a replace-existing release; legacy/plan/08-implementation-module.md › Per-release pipeline (step 9); legacy/plan/08-implementation-module.md › Definition of done

When a release with lossy action `replace-existing` applies, apply sets its ledger entry to status `upgraded` and records the upgrade time. The old lossy files are gone from the target folder.

Example: ledger has `Some Band` / `Some Album` / 2010, `mp3`, target has `01 Track.mp3`; lossless source `01 Track.flac`, `update-existing` + `replace-existing` → `Applied 1`; folder has `01 Track.flac`, no `01 Track.mp3`; ledger `upgraded` with an upgrade time.

### AS-DOC-APL-066 — A logged lossy release gets the real committed path in the ledger
Status: Draft | Source: legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › corrects the lossy-tracking targetPath to the committed path on a log-for-upgrade release, but not under -WhatIf

When a release with lossy action `log-for-upgrade` applies, apply writes the real final folder path into its ledger entry. The status stays `pending-upgrade`. With `-WhatIf`, the ledger does not change.

Example: ledger path `<targetRoot>\Some Band\2010 Some Album`, the user renamed the release folder to `2010 Some Album (Edited)` → after `-WhatIf` the ledger path is unchanged; after a real run it is `<targetRoot>\Some Band\2010 Some Album (Edited)`, status `pending-upgrade`.

### AS-DOC-APL-067 — Lossy first, lossless later: the target ends with only the lossless files
Status: Draft | Source: legacy/tests/Reshelf.Pipeline.Tests.ps1 › Full pipeline: lossy release applied first, then its lossless upgrade › replaces the lossy target folder with the lossless release and marks the ledger entry upgraded; legacy/plan/12-build-order-and-milestones.md › Status (milestones 3–7); legacy/plan/12-build-order-and-milestones.md › Sequence (7. Idempotency and upgrade validation); legacy/plan/08-implementation-module.md › Definition of done

When the full pipeline runs first on a lossy copy of a release and later on a lossless copy, the second apply replaces the lossy target folder. Afterwards the folder holds only the lossless files, and the ledger entry is `upgraded`. How propose finds the existing folder: see [07-proposal-matching.md](07-proposal-matching.md).

Example: source `SOME BAND - SomeAlbum\01 - Track One.mp3`, Discogs `Some Band` / `Some Album` / 2010 → `Applied 1`, target `Some Band\2010 Some Album\01 Track One.mp3`, ledger `pending-upgrade`.

Example: then source `SOME BAND - SomeAlbum\01 - Track One.flac` → same stableKey, `update-existing` + `replace-existing`; `Applied 1, Failed 0`; the folder has only `01 Track One.flac`; ledger `upgraded`. (Real case, plan 12: Pulsar Olymp – 94 Shine, mp3 then FLAC.)

## End-to-end results

### AS-DOC-APL-068 — Full fixture run gives the expected target layout
Status: Draft | Source: legacy/tests/Reshelf.Pipeline.Tests.ps1 › Full pipeline: Recognition -> EditProposal -> Implementation › a real -IncludeUnresolved run produces the correct target layout for every planted pattern, and a re-run is a no-op; legacy/tests/Reshelf.Pipeline.Tests.ps1 › Full pipeline: Recognition -> EditProposal -> Implementation › target layout after a real -IncludeUnresolved run matches the golden file; legacy/plan/08-implementation-module.md › Definition of done

Recognize → propose → apply with `-IncludeUnresolved` over the full fixture tree gives `Failed 0`. The target matches the reviewed golden file `legacy/tests/fixtures/expected/target-layout.txt`. The target has no `.reshelf-staging` folder. How the names are built: see [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md).

Example: `ZZ Top\1999 XXX\` → `01 Poke Chop Sandwich.flac`, `02 Crucifixx A Flatt.flac`, `cover.jpg`.

Example: multi-disc `ZZ Top\2003 Mescalero\` → `01 Track One.mp3` … `06 Stray Bonus Track.mp3`, `scans\back.jpg`, no `CD *` subfolder. An EP from an `EPs` category folder lands at `ZZ Top\1994 One Foot In The Blues\`.

Example: cue release `Pink Floyd\1994 Live In Concert (Bootleg)\` → `01 Speak To Me.flac`, `02 Breathe.flac`; the source `.cue` still exists.

### AS-DOC-APL-069 — A re-run after apply does nothing
Status: Draft | Source: legacy/tests/Reshelf.Pipeline.Tests.ps1 › Full pipeline: Recognition -> EditProposal -> Implementation › a real -IncludeUnresolved run produces the correct target layout for every planted pattern, and a re-run is a no-op; legacy/tests/Reshelf.Pipeline.Tests.ps1 › Full pipeline: Recognition -> EditProposal -> Implementation › re-running propose after a real apply resolves every applied release to skip-existing-identical, not conflict; legacy/plan/12-build-order-and-milestones.md › Status (milestones 3–7); legacy/plan/08-implementation-module.md › Definition of done

Running apply again on the same unchanged proposal applies nothing. A new session with a new proposal for the same unchanged source also applies nothing and fails nothing. Why propose gives `skip-existing-identical`: see [07-proposal-matching.md](07-proposal-matching.md).

Example: first run `Applied` = N → re-run `Applied 0`, `Skipped` = N, `Failed 0`.

Example: new session, re-propose, apply with `-IncludeUnresolved` → `Applied 0, Failed 0`.

### AS-DOC-APL-070 — With real ffmpeg and TagLibSharp, the files hold the proposed tags
Status: Draft | Source: legacy/tests/Reshelf.TagLibSharp.Integration.Tests.ps1 › Full pipeline with real TagLibSharp and ffmpeg › applies the release, writes correct real tags and cover, and sanitizes invalid characters; legacy/plan/12-build-order-and-milestones.md › Status (milestone 0)

With the real tag library and real ffmpeg, a full run writes the release to `<targetRoot>\<artistFolderName>\<releaseFolderName>\`. Each track file has Artist, Album Artist, Album, Year, Disc, Track and Title equal to the proposal's tags, and one FrontCover picture.

Example: source `Radiohead\1997 OK Computer\01 - Airbag.flac`, `02 - Paranoid Android.flac`, `03 - Subterranean Homesick Alien.flac` → `Applied 1, Failed 0`; every file read back with the real library matches its proposed tags.

## Checking the result

### AS-DOC-APL-071 — The user checks the target and the lossy ledger after apply
Status: Draft | Source: legacy/README.md › 6. Check the result; legacy/plan/12-build-order-and-milestones.md › Sequence (6. Implementation, dry-run then real)

After apply, the user looks at `<targetRoot>` for the organized folders. When lossy releases were found, the user lists the ledger with `lossy list`. For failed releases, the user reads `errorMessage` in `apply-log.json`. The `lossy list` command: see [11-lossy-tracking.md](11-lossy-tracking.md).

Example: `pwsh scripts/Reshelf.ps1 lossy list`.

## Rules from owned inputs that belong to other areas

- Session stage table, `session resume`, and the meaning of `partially-applied` (plan 10 › Session persistence and resume): see [04-sessions.md](04-sessions.md).
- How `targetAction` and `lossyLossless.action` are chosen (plan 10 › Re-runs and duplicate detection; Pipeline › lossy then lossless, the propose half): see [07-proposal-matching.md](07-proposal-matching.md).
- Recognition output and golden `recognition.json`, grouping folder and empty artist folder (Pipeline › schema-valid …, walks a grouping folder …, recognition.json matches the golden file): see [05-recognition.md](05-recognition.md).
- Golden `proposal.json`, human review flag for `not-found` releases (Pipeline › proposal.json matches the golden file; flags every release …): see [07-proposal-matching.md](07-proposal-matching.md).
- Safe file names (plan 10 › Invalid filename characters): see [02-text-and-naming-rules.md](02-text-and-naming-rules.md).
- Discogs headers, rate limit 60 vs. 55, cache (plan 12 › Milestone 1): see [06-discogs-client.md](06-discogs-client.md).
- MANIFESTO §7 modules 1–4 (settings, recognition, edit proposal, editing UI): see [03-settings-and-secrets.md](03-settings-and-secrets.md), [04-sessions.md](04-sessions.md), [05-recognition.md](05-recognition.md), [07-proposal-matching.md](07-proposal-matching.md), [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md), [09-review-ui.md](09-review-ui.md), [11-lossy-tracking.md](11-lossy-tracking.md).

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-05 | Phase 1 draft. |
