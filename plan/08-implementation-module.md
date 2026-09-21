# Step 8 — Implementation Module

## Purpose / scope

Apply the approved `proposal.json` to real files: copy/move, rename, split
single-file+cue releases, write tags and cover art, update the lossy ledger.
Matches manifesto §7 module 5 — the only step that touches the user's actual
music files.

## Inputs / outputs

- Input: approved `proposal.json` ([03](03-domain-model-and-json-schemas.md)),
  `settings.json` (copy vs. move mode).
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
`-IncludeUnresolved` is passed.

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
   count matches the cue sheet's track count before deleting the original
   `.cue` file and single audio file (manifesto §4.4 requires the `.cue`
   deleted afterward — only once splitting is verified successful).
3. **Copy/move into a staging area**: `TargetRoot\.tagger-staging\<stableKey>\...`,
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
7. **Companion files**: copied to their `placement` (nested subfolder, or
   loose with a letter-prefixed filename per manifesto §4.5).
8. **Atomic-ish final commit**: only after every prior step succeeds for the
   whole release, `Move-Item` the staged folder from
   `.tagger-staging\<stableKey>` to its real final path under `targetRoot`.
   If `copyMode == "move"`, source files are deleted only now, after the
   commit succeeds — never before.
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
- **Verify split track count before deleting source**: splitting is
  destructive to the manifesto's stated end state (cue+single-file must not
  survive) — verifying first avoids losing a release to a bad split with no
  way back.
- **Move only after commit succeeds**: protects the user's original files
  when `copyMode == "move"` — a crash mid-pipeline should never leave the
  user with neither a valid source nor a valid target copy.

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
