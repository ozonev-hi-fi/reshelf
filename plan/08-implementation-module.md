# Step 8 — Implementation Module

## Purpose / scope

Apply the approved `proposal.json` to real files: copy/move, rename, split
single-file+cue releases, write tags and cover art, update the lossy ledger.
Matches manifesto §7 module 5 — the only step that touches the user's actual
music files.

## Inputs / outputs

- Input: approved `proposal.json` ([03](03-domain-model-and-json-schemas.md)),
  `settings.json` (`copyMode`, always `"copy"` — source files are always read-only to Reshelf; see
  "Decisions & rationale" below).
- Output: files under `targetRoot` in the final structure (manifesto §4),
  updated `lossy-tracking.json` ([09](09-lossy-lossless-tracking.md)),
  `apply-log.json`.

## Detailed design

### Entry point

`Invoke-Implementation.ps1 -SessionId <id> [-WhatIf] [-IncludeUnresolved]`.
Every mutating helper function uses PowerShell's native
`SupportsShouldProcess`, so `-WhatIf` genuinely dry-runs the whole pipeline
with no writes.

By default, releases with `discogsMatch.status == "ambiguous"` and
`humanReview.resolved != true` are skipped (see
[07-editing-ui-module.md](07-editing-ui-module.md)) unless
`-IncludeUnresolved` is passed. A release with `humanReview.rejected == true`
is always skipped, counted separately as `Rejected` in the run summary, and
is never included even with `-IncludeUnresolved` — that flag means "apply
what hasn't been reviewed yet," not "override an explicit rejection".

### Per-release pipeline

1. **Idempotency check** — look up `stableKey` in `apply-log.json`; if
   already applied successfully with the same source file-set hash, skip
   (see [10-error-handling-and-edge-cases.md](10-error-handling-and-edge-cases.md)).
2. **Cue split, if `cueSheet` is present**: parse the `.cue` file's
   `INDEX 01` timestamps and track titles, then run one `ffmpeg -i <source>
   -ss <start> -to <end> -c copy <track file>` call per track (works
   uniformly for lossless formats like flac and lossy ones like mp3 — `-c
   copy` extracts without re-encoding, so no quality loss and no
   lossy-to-lossy re-compression artifacts). Verify the resulting track
   count matches the cue sheet's track count before proceeding. The source
   `.cue` and single audio file are never deleted — source files are always
   read-only to Reshelf (revised from the original plan; see "Decisions &
   rationale" below).
3. **Copy/move into a staging area**: `TargetRoot\.reshelf-staging\<stableKey>\...`,
   never directly into the final target path yet.
4. **Rename** files/folders per `proposal.json`'s `proposed*`/`proposedFileName`
   fields.
5. **Cover resize**: ffmpeg resizes the chosen cover candidate to
   `coverArt.targetMaxDimension` (600×600 max, manifesto §5). If the chosen
   candidate is a remote Discogs URL (the normal, matched case), it's
   downloaded to staging first.
6. **Write tags + embed art**: TagLibSharp, in-process via `Add-Type` — the
   same library [05](05-recognition-module.md) uses to read tags. One
   `TagLib.File.Create(...)` / set properties / `.Save()` call per staged
   track, embedding the resized cover (`TagLib.Picture`) directly into each
   file's tags. No external process, no GUI, nothing to author by hand.
7. **Companion files**: `companionFiles` entries with `include == false`
   (set in the Editing UI, [07](07-editing-ui-module.md)) are skipped
   entirely — never copied, and (like every source file) never deleted from
   the source either. Every other entry is copied to its `placement`: a
   **nested** one keeps its
   subfolder path and file name unchanged; a **loose** one uses its
   `proposedFileName` — computed by [06](06-edit-proposal-module.md) as a
   letter-first name per manifesto §4.5 (never the old digit → `_` prefix,
   which sorted *before* tracks in Explorer and so broke the rule it was
   meant to satisfy), and editable in the UI. Before copying anything for a
   release, every included loose companion's target name is validated —
   starts with a letter, doesn't collide with a track's target file name or
   with another included companion's target path — and the whole release
   fails cleanly (status `failed`, clear message, batch continues) if not; a
   `proposal.json` from before `proposedFileName` existed falls back to
   computing one from the companion's `kind` at apply time.
8. **Atomic-ish final commit**: only after every prior step succeeds for the
   whole release, `Move-Item` the staged folder from
   `.reshelf-staging\<stableKey>` to its real final path under `targetRoot`.
   The source is left untouched — nothing is ever deleted from it.
   If the final path already exists, it is deleted and replaced **only** when
   `targetAction` is `update-existing` or `conflict` (a conflict gets here
   only after a human approved it — plan/10: never *silently* overwritten).
   Any other action fails the release with `target folder '<path>' already
   exists but the proposal says '<action>'; re-run propose`, and the folder
   is not touched. `Move-ReshelfStagedReleaseToTarget` checks this itself,
   right before the delete, instead of trusting step 6. Real case, plan/12
   milestone 7: a key-mismatch bug in [06](06-edit-proposal-module.md) proposed
   `create-new` for a folder that existed, and the old unconditional delete
   would have replaced it with no ledger update.
9. **Update `lossy-tracking.json`** per `lossyLossless.action`
   ([09](09-lossy-lossless-tracking.md)).
10. **Append to `apply-log.json`**: `{ stableKey, appliedAtUtc, status,
    targetPath, sourceFileSetHash }`.

### Why staging-then-commit

If step 5 or 6 fails partway through a release (e.g. a corrupt audio file
throws on `TagLib.File.Create`), nothing has landed at the final target path
yet — the staged folder is either cleaned up or left for inspection, and a
re-run picks the release back up cleanly via the idempotency check. Without
staging, a half-tagged, half-renamed release could end up sitting at its
final path looking "present" to a later run's duplicate check.

## Decisions & rationale

- **TagLibSharp for both reading and writing** (revised from the original
  plan): the original plan used mp3tag for writing specifically, to keep
  step 5's reads and step 8's writes on separate tools. That depended on
  mp3tag's Action-Group mechanism accepting a per-file tag list from an
  external file via a headless CLI switch — a real, documented, scriptable
  feature could not be confirmed to exist (the closest match, `Convert >
  Text File – Tag`, appears to be menu-only). Rather than build on that
  assumption, writing moved to TagLibSharp: it's already a dependency (used
  for reading since [05](05-recognition-module.md)), it writes tags and
  embeds cover art too, and it runs in-process via `Add-Type` — no external
  process, no GUI, no manual Action-Group authoring. The trade-off (reading
  and writing sharing one library instead of two independent ones) is
  discussed in [11](11-testing-and-verification-strategy.md).
- **Verify split track count before proceeding**: a bad split (wrong track
  count) must fail the release cleanly rather than commit incomplete or
  misaligned tracks to the target.
- **Source files are always read-only, no "move" mode** (revised from the
  original plan): an earlier design deleted the cue-sheet source after a
  verified split, and deleted moved per-track/companion sources in a "move"
  `copyMode` — both were removed entirely after an incident destroyed source
  releases that had no other backup. `copyMode` now only accepts `"copy"`;
  no code path in Reshelf, and no external tool it calls (ffmpeg,
  TagLibSharp), ever deletes or modifies a file under the source root.

## Edge cases

- TagLibSharp fails to open or save a specific file (e.g. corrupt audio) →
  that release is marked `status: "failed"` in `apply-log.json` with an
  error message, staging folder left in place for inspection, pipeline
  continues to the next release rather than aborting the whole batch.
- Target path would exceed Windows path-length limits, or contains invalid
  characters → see [10](10-error-handling-and-edge-cases.md).
- Disk full mid-copy → staging area catches this before any final-path
  commit; the partial staged folder is left for cleanup/retry.

## Manual setup

None — TagLibSharp needs no interactive authoring step, unlike the mp3tag
Action group this step originally planned around.

## Definition of done

- `-WhatIf` run against the fixture source produces a log of intended
  actions with zero actual filesystem writes.
- A real run against a scratch target produces the exact folder/file layout
  and tag values from manifesto §4/§5, verified by reading each file back
  fresh with TagLibSharp after writing (see [11](11-testing-and-verification-strategy.md)
  for the honest limits of that check now that reading and writing share one
  library).
- Re-running unchanged is a no-op (every release skipped via
  `apply-log.json`).
- A simulated lossy→lossless upgrade case correctly replaces the existing
  target release and updates `lossy-tracking.json`.
