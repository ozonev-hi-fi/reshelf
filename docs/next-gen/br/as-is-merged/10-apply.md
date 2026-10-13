# 10 — Apply (as-is, merged)

Status: Draft | Version: 0.1 | Last updated: 2026-10-13

## Scope

Area **APL**. What the `apply` stage of the legacy app does today: the only
stage that writes music files. Sources: `br/as-is-from-docs/10-apply.md`
(`AS-DOC-APL-001`–`071`, from `legacy/tests/Reshelf.Implementation.Tests.ps1`,
`Reshelf.TagLibSharp.Integration.Tests.ps1`, `Reshelf.Pipeline.Tests.ps1`,
`legacy/plan/08-implementation-module.md`, `MANIFESTO.md` §7 and
`legacy/README.md`) and `br/as-is-from-code/10-apply.md` (`AS-CODE-APL-001`–
`055`, read only from `legacy/scripts/common/Reshelf.Implementation.psm1`).

**ID numbering for this area:** 69 `AS-APL-*` requirements, spanning
`AS-APL-001`–`072` with one 3-number gap. Up to `AS-APL-051`, numbers mirror
`AS-DOC-APL-001`–`055` one for one (three doc numbers, `046`–`048`, are
skipped on purpose — see below — and `AS-APL-050`/`051` each fold two or
four adjacent, tightly related doc items into one, the same way `AS-DSC-002`
folds three sources into one item). From `AS-APL-052` on, the doc-side
numbers no longer line up 1:1 with the merged numbers, because those two
multi-item folds used up fewer `AS-APL` numbers than the `AS-DOC-APL` range
they drew from (`049`–`055`, 7 doc items, became 3 merged items,
`049`–`051`) — every item still cites its exact `AS-DOC-APL-*`/`AS-CODE-APL-*`
source in its own `Source:` line, so nothing is ambiguous, but side-by-side
number comparison beyond `051` only works through that line, not through the
number itself. `AS-DOC-APL-046`–`048` ("Reading tags back") describe
`Get-ReshelfAudioTags`, which phase 1 itself flagged as possibly belonging to
recognition — the REC merge had already covered the exact same reading
behavior as `AS-REC-085`–`089` by the time this area was merged, with no
gap, so no new `AS-APL` item is created for them; `92-coverage.md` points
all three straight at the REC entries. Five facts exist only in the code
view, with no doc-side hook at all (the truncation budget's internal
reservation order, and two apply-log read/lookup nuances) — these get fresh
numbers, `AS-APL-068`–`072`, in a trailing "Mechanics (code-only facts)"
section, same convention as `AS-SET-048`–`050`.

**Contradictions resolved while merging this area:** six phase-1
`AS-DOC-DEF-*` contradictions (`083`–`085`, `088`, `092`, `093`), all
re-verified directly against `Reshelf.Implementation.psm1` and all already
correctly resolved in phase 1's own favor of tests/code over the README/plan
prose. See `90-contradictions-resolution.md`.

**Suspected defects carried forward:** eleven items — eight phase-1
`AS-DOC-DEF-*` suspected defects (`086`, `087`, `089`–`091`, `094`–`096`), the
two `AS-CODE-DEF-APL-*` entries, and one new suspected defect found while
merging (an `apply-log` status value the code accepts but never actually
writes). See `91-suspected-defects-carryforward.md`.

## Run options and release selection

### AS-APL-001 — Dry run with -WhatIf writes nothing but reports a full summary
Status: Draft | Source: AS-DOC-APL-001

With `-WhatIf`, apply changes no file and no folder in the source root, the
data home or the target root. It does not create the target root and does
not write `apply-log.json`. It writes no tags. It still returns the same
summary a real run would return.

Example: one resolved release, `apply -SessionId 2026-09-25-0007 -WhatIf` →
summary `Applied 1, Skipped 0, Failed 0`; the target root does not exist
after the run; `apply-log.json` does not exist.

### AS-APL-002 — The run returns/prints four counters: Applied, Skipped, Rejected, Failed
Status: Draft | Source: AS-DOC-APL-002; AS-CODE-APL-055

| Counter | Meaning |
|---|---|
| Applied | Copied and tagged successfully. |
| Skipped | Not yet reviewed (and `-IncludeUnresolved` was not passed), or already applied in an earlier run with unchanged source files. |
| Rejected | The user ticked Reject in the review UI. |
| Failed | Something went wrong for that release. |

`Invoke-ReshelfImplementation` returns these four as a single object, tallied
across every release according to the gating order in `AS-APL-003`–`005`.

Example (README):
```
SessionId : 2026-09-25-0007
Applied   : 96
Skipped   : 7
Rejected  : 4
Failed    : 0
```

### AS-APL-003 — An unresolved release is skipped by default; the gate is `humanReview.resolved`, not `.required` — resolves AS-DOC-DEF-085
Status: Draft | Source: AS-DOC-APL-003; AS-CODE-APL-048; resolves `AS-DOC-DEF-085` (see `90-contradictions-resolution.md`)

Without `-IncludeUnresolved`, apply skips every release where
`humanReview.resolved` is not `true`. Apply does not stage it and does not
touch its target folder. The release counts as Skipped. The code comments
this as deliberate: `humanReview.required` is the propose-time flag that
decides whether a release needs a human look; `resolved` is the one gate
apply actually checks, so a release can need review for any reason (not only
an ambiguous Discogs match) and still be skipped the same way.

Example: Discogs status `ambiguous`, `humanReview.required = true`,
`resolved = false` → `Skipped 1, Applied 0`; no folder
`Some Band\2010 Some Album` in the target.

Example: `targetAction = conflict`, `resolved = false`, and the target
already has `01 Track.flac` with content `pre-existing-different-content` →
`Skipped 1`; no `.reshelf-staging\a1b2c3d4e5f60708` folder; the target file
still has `pre-existing-different-content`.

### AS-APL-004 — -IncludeUnresolved also applies unresolved releases
Status: Draft | Source: AS-DOC-APL-004; AS-CODE-APL-048

With `-IncludeUnresolved`, apply treats unresolved releases like resolved
ones. An unresolved `conflict` release then replaces the existing target
folder (`AS-APL-018`).

Example: the same `ambiguous` release with `-IncludeUnresolved` →
`Applied 1`; `Some Band\2010 Some Album\01 Track.flac` exists.

### AS-APL-005 — A rejected release is never applied, even with -IncludeUnresolved
Status: Draft | Source: AS-DOC-APL-005; AS-CODE-APL-048

Apply never applies a release with `humanReview.rejected = true`. It counts
the release as Rejected, not Skipped. This gate is checked first, before the
`resolved` gate (`AS-APL-003`), and is never overridden by
`-IncludeUnresolved`: rejection is a deliberate, permanent human decision
("never apply this"), unlike an ordinary unresolved release ("not yet looked
at").

Example: a resolved and rejected release, run with `-IncludeUnresolved` →
`Rejected 1, Applied 0, Skipped 0`; no target folder
`Some Band\2010 Some Album`.

### AS-APL-006 — Empty ffmpeg path means "ffmpeg" from PATH
Status: Draft | Source: AS-DOC-APL-006; AS-CODE-APL-045

When the ffmpeg path is empty or not given, apply calls `ffmpeg` and lets
Windows find it on PATH, rather than failing on the empty default value in
`settings.json`.

Example: `ffmpegPath = ""` → the release applies, `Applied 1`.

### AS-APL-007 — Apply works release by release; one release's failure doesn't stop the run; the proposal is schema-validated once up front
Status: Draft | Source: AS-DOC-APL-007; AS-CODE-APL-046; AS-CODE-APL-052

Before an apply run reads anything from the proposal file, it validates it
against the `proposal` schema and throws if it fails. Apply then takes one
release, finishes all steps for it, and goes to the next, until all releases
are done. A failure in one release — anywhere in staging, the commit move, or
the lossy-ledger update — is caught and does not stop the run.

Example: two releases, tag writing fails for `Band One\2010 Album One` →
`Applied 1, Failed 1`; `Band Two\2011 Album Two\01 Track.flac` exists in the
target.

### AS-APL-008 — Steps for one release — resolves AS-DOC-DEF-093
Status: Draft | Source: AS-DOC-APL-008; AS-CODE-APL-034; AS-CODE-APL-047; resolves `AS-DOC-DEF-093` (see `90-contradictions-resolution.md`)

For each release that apply does not skip, it does these steps:

1. Builds the release in the staging folder
   `<targetRoot>\.reshelf-staging\<stableKey>\` — a dot-prefixed folder
   inside the target root itself.
2. Splits a one-file + cue release with ffmpeg, or copies the track files —
   decided per track, interleaved with staging the track, not as a separate
   phase strictly before or after it (see the resolution note below).
3. Downloads or reads the chosen cover and resizes it with ffmpeg to
   `coverMaxDimension` (600 px by default).
4. Writes the tags (Artist, Album Artist, Album, Year, Disc, Track, Title,
   Compilation) and embeds the cover with TagLibSharp.
5. Copies the included companion files.
6. Moves the staged folder to `<targetRoot>\<Artist>\<yyyy Album>\`.
7. Updates the lossy ledger and writes the apply-log entry.

Example: release `a1b2c3d4e5f60708` is built in
`<targetRoot>\.reshelf-staging\a1b2c3d4e5f60708\` and ends in
`<targetRoot>\Some Band\2010 Some Album\`.

**Resolution (step order):** plan 08 lists the cue split before staging; the
README lists staging before the split. Re-reading
`Invoke-ReshelfReleaseStaging`: there is no separate "split phase" at all —
the function computes the truncated layout and validates companion names,
creates the staging folder, then walks the release's tracks and, per track,
either runs an ffmpeg split or a plain copy straight into that staging
folder, before moving on to tag writing and companion copying. Both the plan
and the README oversimplify one combined step into two ordered ones. Neither
is contradicted on anything observable; no test exercises order, so this
doesn't change any test-backed fact. No `AS-CODE-DEF` was raised for it.

## Skip logic for already-applied releases

### AS-APL-009 — A release with no apply-log entry needs apply
Status: Draft | Source: AS-DOC-APL-009; AS-CODE-APL-007

When `apply-log.json` has no entry for the release's `stableKey`, apply
processes the release. Apply also computes the source file-set hash for it.

Example: `stableKey` `aaaaaaaaaaaaaaaa`, no log entry, source
`01 Track.flac` exists → needs apply, hash is not empty.

### AS-APL-010 — The source file-set hash is a case-insensitive fingerprint of name+size, over every unique source file path
Status: Draft | Source: AS-DOC-APL-010; AS-CODE-APL-007

The hash is SHA-256 over the sorted (ordinal), newline-joined list of
`lower-cased file name|size` for every unique `sourceFilePath` across the
release's tracks. Two releases with identical file names and sizes hash the
same even if one file's name differs only in case.

### AS-APL-011 — An unchanged applied release is skipped
Status: Draft | Source: AS-DOC-APL-011; AS-CODE-APL-006; AS-CODE-APL-007

Apply skips a release when all of these are true: the apply-log entry has
status `applied`, the logged hash equals the current source file-set hash,
the logged target path starts with the current target root
(case-insensitive), and that target folder still physically exists. A
skipped release gets no ffmpeg call and no tag write. The release counts as
Skipped.

Example: first run `Applied 1`; second run with the same proposal →
`Applied 0, Skipped 1, Failed 0`; tags were written only once in total.

### AS-APL-012 — Changed source files make a release apply again
Status: Draft | Source: AS-DOC-APL-012; AS-CODE-APL-007

When the logged hash differs from the current source file-set hash, apply
processes the release again.

Example: logged hash `stale-hash-that-cannot-match`, status `applied`,
target folder exists → needs apply.

### AS-APL-013 — A failed release is retried on the next run
Status: Draft | Source: AS-DOC-APL-013; AS-CODE-APL-006

When the logged status is anything other than exactly `applied` (in
practice, `failed`), apply processes the release again, even when the hash
matches.

Example: entry status `failed`, error `boom`, same hash → needs apply.

### AS-APL-014 — A new target root makes a release apply again
Status: Draft | Source: AS-DOC-APL-014; AS-CODE-APL-006

When the logged target path is not under the current target root, apply
processes the release again — covering a target root that moved, for example
to a new drive.

Example: logged path `<oldTargetRoot>\Some Band\2010 Some Album` exists,
status `applied`, same hash, current target root is different → needs apply.

### AS-APL-015 — A deleted target folder makes a release apply again
Status: Draft | Source: AS-DOC-APL-015; AS-CODE-APL-006

When the logged target folder no longer exists on disk, apply processes the
release again, whatever its recorded status and hash say.

Example: entry `applied`, same hash, path under the current root, but the
folder is not on disk → needs apply.

### AS-APL-016 — All source files gone: skip only when already applied — carries CF-APL-001/002
Status: Draft | Source: AS-DOC-APL-016; AS-CODE-APL-008; carried forward: see `91-suspected-defects-carryforward.md` (`CF-APL-001`, citing `AS-DOC-DEF-089`; `CF-APL-002`, citing `AS-DOC-DEF-090`)

When every source file of a release is missing, hashing throws; the code
does not propagate that failure — it falls back to
`needsApply = NOT(still-valid-applied-entry)` with a `null` hash, treating
missing source files between runs as normal/external, not an error. If the
log has an `applied` entry that is still valid (`AS-APL-011`'s checks,
including the target folder still existing on disk), apply skips the
release regardless of the unobtainable hash. If the log has no entry, or the
entry isn't valid, apply processes the release (and the copy then fails, see
`AS-APL-024`).

Example: source `needs-apply-5\gone.flac` missing, entry `applied` with hash
`irrelevant`, target folder exists → no apply, hash empty.

Example: source `needs-apply-6\gone.flac` missing, no entry → needs apply,
hash empty.

## Staging and final commit

### AS-APL-017 — The release is built in staging and moved at the end; directory creation doesn't force a terminating error — carries CF-APL-009
Status: Draft | Source: AS-DOC-APL-017; AS-CODE-APL-034; carried forward: see `91-suspected-defects-carryforward.md` (`CF-APL-009`, citing `AS-CODE-DEF-APL-001`)

Apply puts all files of a release into
`<targetRoot>\.reshelf-staging\<stableKey>\` first, with their final names,
and writes tags there. Only when every step for the release succeeds does
apply move the staged folder to
`<targetRoot>\<artistFolderName>\<releaseFolderName>\`. A half-done release
never sits at its final path.

Example: tags are written to
`<targetRoot>\.reshelf-staging\a1b2c3d4e5f60708\01 Track.flac`; after the
run, `<targetRoot>\Some Band\2010 Some Album\01 Track.flac` and
`...\Scans\front.jpg` exist.

Carried forward: the `New-Item -ItemType Directory` calls that create the
staging folder, a companion's parent directory, and the final target's
parent directory don't pass `-ErrorAction Stop`, unlike every `Copy-Item`
call in this module (`AS-APL-022`/`049`) and the equivalent `New-Item` calls
in `Reshelf.Settings.psm1`. If directory creation fails (permission denied,
disk full), the default non-terminating error lets execution continue as if
the folder existed, surfacing a less clear failure later (e.g. a
`Copy-Item` "path not found") instead of failing fast with a direct message.

### AS-APL-018 — An existing target folder is replaced only for update-existing or conflict — resolves AS-DOC-DEF-084
Status: Draft | Source: AS-DOC-APL-018; AS-CODE-APL-043; AS-CODE-APL-044; resolves `AS-DOC-DEF-084` (see `90-contradictions-resolution.md`)

When the final folder already exists, apply deletes it (full recursive
delete) and moves the staged folder into place only when `targetAction` is
`update-existing` or `conflict`. A `conflict` release reaches this point
only when resolved or `-IncludeUnresolved` is set. This check runs here,
immediately before the delete — not earlier, from the proposal alone — so a
stale or wrong `targetAction` fails the release instead of destroying
whatever is already in the target. The meaning of each `targetAction`: see
[07-proposal-matching.md](07-proposal-matching.md).

Example: `update-existing`, the target has `01 Track.mp3` → after apply, the
folder has `01 Track.flac` and no `01 Track.mp3`.

Example: `conflict` with `-IncludeUnresolved` → `01 Track.flac` content
changes from `pre-existing-different-content` to `new-source-content`.

### AS-APL-019 — create-new fails when the target folder already exists
Status: Draft | Source: AS-DOC-APL-019; AS-CODE-APL-043

When the final folder already exists and `targetAction` is any value other
than `update-existing`/`conflict` (for example `create-new`), apply does not
touch the folder. The release fails with
`target folder '<path>' already exists but the proposal says '<action>';
re-run propose`.

Example: `create-new`, the target already has
`Some Band\2010 Some Album\01 Track.mp3` with content
`existing-lossy-content` → `Failed 1, Applied 0`; the mp3 keeps its content;
no `01 Track.flac`; log status `failed`, message contains `already exists
but the proposal says 'create-new'`.

### AS-APL-020 — The staging root is removed only when completely empty — carries CF-APL-004
Status: Draft | Source: AS-DOC-APL-020; AS-CODE-APL-053; carried forward: see `91-suspected-defects-carryforward.md` (`CF-APL-004`, citing `AS-DOC-DEF-091`)

At the end of a run, apply deletes `<targetRoot>\.reshelf-staging` only if
it is now completely empty. A failed release's own staging subfolder is
deliberately left in place for inspection — it already made the wrapper
non-empty, so `.reshelf-staging` also stays. Only a successfully-applied
release ever moves itself out of staging during the run.

Example: one release, success → no `<targetRoot>\.reshelf-staging`.

Example: one release, the final move throws `commit boom` → `Failed 1`;
`<targetRoot>\.reshelf-staging\a1b2c3d4e5f60708` exists.

A failed release leaves `.reshelf-staging\<stableKey>\` in place, and the
README says the next apply retries it. Carried forward: no test or doc says
what happens to the files already in that folder on the retry — the
staging folder is (re)created with `-Force`, which does not clear existing
contents, so a stale file from the earlier failed attempt (e.g. a companion
dropped from the proposal since, or an old cue split now obsolete) could
still be present when the folder is later moved to the target as a whole.

## Source is read-only

### AS-APL-021 — Apply never deletes or changes a source file; "copy" is the only mode — resolves AS-DOC-DEF-088; carries CF-APL-003
Status: Draft | Source: AS-DOC-APL-021; AS-CODE-APL-049; resolves `AS-DOC-DEF-088` (see `90-contradictions-resolution.md`); carried forward: see `91-suspected-defects-carryforward.md` (`CF-APL-003`, citing `AS-DOC-DEF-087`)

Apply only copies. It never deletes or modifies a file under the source
root: not the tracks, not the companions, not an excluded companion, and not
the `.cue`/audio file of a split release — true after success and after
failure. The `CopyMode` parameter's `ValidateSet` allows only the literal
value `'copy'`; nothing in the function branches on it, and it exists only
for backward compatibility with older callers (an earlier `move` mode,
which deleted sources after apply, was removed after it destroyed source
releases with no backup — this is the same remnant noted in
`AS-DOC-DEF-014`, the `settings init` prompt).

Example: after a successful apply, source `Some Band\2010 Some Album\01
Track.flac` and `...\Scans\front.jpg` still exist.

Example: after a cue release fails at tag writing,
`Pink Floyd\1994 Live In Concert (Bootleg)\Live In Concert.cue` and
`Live In Concert.flac` still exist.

Example (plan 12): real apply of 27 releases → the source was byte-identical
before and after.

## Copying tracks

### AS-APL-022 — A track is copied under its proposed file name, into the proposed folder names
Status: Draft | Source: AS-DOC-APL-022; AS-CODE-APL-037

A track that is not part of a cue sheet is copied as-is (no conversion), to
its proposed file name, under the proposed artist/release folder names —
including names the user edited in the review UI. `Copy-Item -Force
-ErrorAction Stop` is used, so a non-terminating copy failure (`Copy-Item`'s
own default) can't silently continue as if the copy had succeeded.

Example: source `01 Track.mp3`, proposed release folder
`2010 Some Album (Edited)` →
`<targetRoot>\Some Band\2010 Some Album (Edited)\01 Track.mp3`.

### AS-APL-023 — Tags keep the raw text, file names are made safe
Status: Draft | Source: AS-DOC-APL-023

Folder and file names on disk contain no character Windows forbids in file
names. The tag values keep the original text with those characters. The
rules that make names safe: see
[02-text-and-naming.md](02-text-and-naming.md).

Example: Discogs title `OK Computer? / Live: Edition`, track
`Paranoid Android?` → release folder name and track file names have no
invalid characters; the Album tag in each file is
`OK Computer? / Live: Edition`.

### AS-APL-024 — A missing source file fails the release with its real path, not a staging-folder path
Status: Draft | Source: AS-DOC-APL-024; AS-CODE-APL-037

When a source file was deleted after `propose`, the copy step fails at once
(the forced terminating error from `AS-APL-022`). The release fails. The
error message names the missing source file, not a file in the staging
folder. Nothing appears in the target.

Example: the source folder `Some Band\2010 Some Album` is deleted after
propose → `Failed 1, Applied 0`; no target folder; log message contains the
source path of `01 Track.flac` and does not contain `.reshelf-staging`.

## Cue split with ffmpeg

### AS-APL-025 — One ffmpeg split per cue track, per source file, with a defensive existence check afterward
Status: Draft | Source: AS-DOC-APL-025; AS-CODE-APL-010; AS-CODE-APL-036

For a one-file + cue release, apply calls ffmpeg once per cue track, cutting
one time range out of the audio file into one track file. Cue-virtual
tracks are grouped by `sourceFilePath` (one group per disc), not sorted
globally by `proposedTrackNumber`; within each group, tracks are ordered by
their own cue timestamp. After all splits for a release run (skipped under
`-WhatIf`), the code verifies every expected output file actually exists on
disk and throws if one is missing — a belt-and-braces check for the rare
case ffmpeg exits 0 without producing a file, since the ffmpeg wrapper
itself already throws on a non-zero exit code.

Example: fixture `Pink Floyd\1994 Live In Concert (Bootleg)\Live In
Concert.cue` (`INDEX 01 00:00:00` and `INDEX 01 03:12:45`) → 2 calls:
`0.000` to `192.600`, and `192.600` to the end; target
`Pink Floyd\1994 Live In Concert\01 Speak To Me.flac` and
`02 Breathe.flac`.

### AS-APL-026 — Cue times are minutes:seconds:frames, converted to plain decimal seconds
Status: Draft | Source: AS-DOC-APL-026; AS-CODE-APL-009

Apply reads a cue time `MM:SS:FF` as minutes, seconds and frames (75 frames
per second, 00–74), and converts it to a plain decimal-seconds string (3
decimal places, invariant-culture `.`, never a locale's `,`) before passing
it to ffmpeg's `-ss`/`-to` — feeding the raw `MM:SS:FF` string directly
would make ffmpeg misread it as `HH:MM:SS`.

Example: `09:26:73` → `566.973`. Example: `03:12:45` → `192.600`. Example:
`00:00:00` → `0.000`.

### AS-APL-027 — Each track ends where the next track in its group starts
Status: Draft | Source: AS-DOC-APL-027; AS-CODE-APL-010

Apply sorts the cue tracks of one audio file by their own cue time, not by
proposed track number. A track starts at its own cue time and ends at the
next track's cue time; the last track in the group has no end time, so it
runs to the end of the file. An empty track list gives no ranges and no
error.

Example: tracks given in order 2, 1, 3 with cue times `00:03:00`,
`00:00:00`, `00:07:30` → track 1: `0.000`–`3.000`; track 2: `3.000`–`7.400`;
track 3: `7.400`–(no end).

### AS-APL-028 — A per-disc cue release splits each disc from its own file, tracks never mixing across discs
Status: Draft | Source: AS-DOC-APL-028; AS-CODE-APL-010; AS-CODE-APL-035

When each disc has its own audio file and cue sheet, apply builds time
ranges per audio file (grouped by `sourceFilePath`), so tracks of different
discs never mix even when their numbers repeat; the last track of each disc
runs to the end of its own file. Whether a track is cue-split or plainly
copied is decided per track via `isCueVirtualTrack`, not once for the whole
release, so a release can mix cue-image discs with ordinary track-file
discs.

Example: `CD 1\Disc One.flac` (tracks at `00:00:00` and `02:00:00`) and
`CD 2\Disc Two.flac` (track at `00:00:00`) → disc 1: `0.000`–`120.000`,
`120.000`–(no end); disc 2: `0.000`–(no end).

Example: 3 split calls → `Some Band\2001 Two Discs\01 Disc One Track
One.flac`, `02 Disc One Track Two.flac`, `01 Disc Two Track One.flac`.

### AS-APL-029 — FLAC and APE sources are re-encoded to FLAC, others are stream-copied — resolves AS-DOC-DEF-083
Status: Draft | Source: AS-DOC-APL-029; AS-CODE-APL-012; resolves `AS-DOC-DEF-083` (see `90-contradictions-resolution.md`)

| Source | ffmpeg arguments | Reason |
|---|---|---|
| `.flac` | `-c:a flac` (re-encode) | stream copy does not recompute FLAC `STREAMINFO` duration after a cut |
| `.ape` | `-c:a flac`, output `.flac` | ffmpeg has no APE encoder, so `.ape` can never be stream-copied |
| any other, e.g. `.wav` | `-c copy` (stream copy) | — |

The README and both plan documents say splitting uses `-c copy` ("no
re-encoding") for every format; the tests and code show `.flac`/`.ape`
re-encode. The area follows the tests/code.

Example: `source.wav` → `out.wav` with `-c copy`, no `-c:a`.

Example: `source.ape` → `out.flac` with `-c:a flac`, no `copy`.

### AS-APL-030 — One retry for the FLAC "invalid block size" error, nudging the start 50 ms later — carries CF-APL-005
Status: Draft | Source: AS-DOC-APL-030; AS-CODE-APL-013; carried forward: see `91-suspected-defects-carryforward.md` (`CF-APL-005`, citing `AS-DOC-DEF-094`)

When the ffmpeg split fails and its stderr contains `invalid block size` (a
known native-FLAC-encoder limitation when the cut start lands a few samples
before a source-internal frame boundary), apply retries once with the start
time moved `0.05` s later — only if the start time parses as a plain decimal
and the nudged start still lands before the end time. The previous track's
own end time is not moved to match, so the 50 ms the retry skips forward
belongs to no track at all; the test treats this as intended, not corrected.

Example: start `322.200`, end `535.070`, first call exit code `-22` with
`[flac @ 0x0] invalid block size: 4` → second call with start `322.250`
succeeds; 2 calls in total. (Real cases: AC-DC "Dog Eat Dog", "Come And Get
It".)

### AS-APL-031 — No retry in the other cases
Status: Draft | Source: AS-DOC-APL-031; AS-CODE-APL-013

Apply calls ffmpeg only once and reports the normal error (with exit code
and stderr) when: the error is not `invalid block size`; the start time is
not plain seconds; or the moved start time would be at or after the end
time.

Example: error `Invalid argument`, exit code 1 → error message contains
`exit code 1`, 1 call.

### AS-APL-032 — A defensive per-file check stands in for an explicit split track-count assertion — carries CF-APL-006
Status: Draft | Source: AS-DOC-APL-032; cross-referenced with `AS-APL-025` (`AS-CODE-APL-036`); carried forward: see `91-suspected-defects-carryforward.md` (`CF-APL-006`, citing `AS-DOC-DEF-096`)

Plan 08 describes an explicit check that the number of produced track files
equals the number of tracks in the cue sheet, failing the release on a
mismatch. The actual code doesn't assert an integer count match; it checks
that every output file the split step was supposed to produce (one per cue
track range, by construction) is physically present, throwing if one is
missing (`AS-APL-025`). In practice the two amount to the same outcome, but
no test exercises either phrasing of the check directly.

## ffmpeg calls

### AS-APL-033 — Paths with spaces reach ffmpeg as one argument
Status: Draft | Source: AS-DOC-APL-033; AS-CODE-APL-011

For split and for resize, apply wraps each input/output path in literal
double quotes before handing the argument list to `Start-Process`, which
joins array elements with a single space and does not itself quote
elements containing spaces.

Example (split): source `...\Pink Floyd\1994 Live In Concert
(Bootleg)\Live In Concert.flac` and output `...\staged output with
spaces.flac` → both appear in the arguments as `"<path>"`.

### AS-APL-034 — An ffmpeg error message has the exit code and ffmpeg's own stderr text
Status: Draft | Source: AS-DOC-APL-034; AS-CODE-APL-014

ffmpeg's stderr is redirected to a temp file for every split attempt
(initial and retry) and always removed afterward via `finally`. On a
non-zero exit code, the thrown message includes the exit code, both paths,
and the captured stderr text.

Example: resize of `cover.jpg` fails with exit code 1 and stderr
`Invalid data found when processing input` → message matches `*exit code
1*Invalid data found when processing input*`.

## Cover art

### AS-APL-035 — The chosen cover is downloaded (if remote) once and resized once per release, never upscaled
Status: Draft | Source: AS-DOC-APL-035; AS-CODE-APL-015; AS-CODE-APL-016

When the chosen cover is a web address (the normal Discogs case), apply
downloads it once into staging with a single `Invoke-WebRequest
-UseBasicParsing` call — no retry, no custom timeout. A local cover file
needs no download. Apply then resizes the cover once with ffmpeg's
`scale=w='min(N,iw)':h='min(N,ih)':force_original_aspect_ratio=decrease`
filter to `coverArt.targetMaxDimension` (600 px by default,
`coverMaxDimension`) — a source already smaller than `N` on both axes is
never enlarged.

Example: chosen cover `https://example.com/cover.jpg` → 1 download, 1
resize.

Example: fixture `ZZ Top\1999 XXX` with only a loose `cover.jpg` as
candidate → the resize reads the local file directly.

### AS-APL-036 — The resized cover is embedded into each track that doesn't already have one
Status: Draft | Source: AS-DOC-APL-036; AS-CODE-APL-020; AS-CODE-APL-039

Apply embeds the resized cover into the tags of every track that has no
cover of its own. After a real run, each track has exactly one picture of
type FrontCover.

Example: the tag write for `01 Track.flac` gets the cover file
`<targetRoot>\.reshelf-staging\a1b2c3d4e5f60708\.reshelf-cover-resized.jpg`.

Example: real run of `Radiohead\1997 OK Computer` (3 tracks) → each file has
1 picture, type FrontCover.

### AS-APL-037 — A track's own embedded cover is kept when the chosen candidate is "existing (embedded)"
Status: Draft | Source: AS-DOC-APL-037; AS-CODE-APL-039

When the chosen cover is `existing (embedded)` and a track already has its
own embedded cover, apply leaves that track's picture untouched. A track
without its own cover still gets the chosen cover (gap-fill), so a release
never ends up with some tracks illustrated and others blank. The resize
step still runs once, since another track can need the gap-fill copy.

Example: chosen cover `<dataHome>\embedded-covers\existing-cover.jpg`
(`existing (embedded)`), the track has that cover → 1 resize; the tag write
gets no cover path, so the picture stays.

Example: the same chosen cover, the track has no cover → the tag write gets
`.reshelf-cover-resized.jpg`.

### AS-APL-038 — Cover working files never reach the target; the working-file name is deliberately not "cover.jpg"
Status: Draft | Source: AS-DOC-APL-038; AS-CODE-APL-038; AS-CODE-APL-041

The files apply makes only to embed the cover (`cover-source.download`,
`.reshelf-cover-resized.jpg`) are deleted (best-effort) before the release
is considered staged, and never reach the final release folder. The resized
working file is deliberately named `.reshelf-cover-resized.jpg`, not plain
`cover.jpg` — a loose source companion legitimately named `cover.jpg`
(valid under manifesto §4.5) can exist in the same staging folder, and
sharing a name would let this cleanup delete that real companion along with
the working file. A loose companion really named `cover.jpg` is a normal
companion and is copied.

Example: Discogs cover, no companion → final folder has no `cover.jpg` and
no `cover-source.download`.

Example: Discogs cover plus loose source `cover.jpg` → final folder has
`cover.jpg` and no `.reshelf-cover-resized.jpg`.

## Tag writing

### AS-APL-039 — Apply writes Artist, Album Artist, Album, Year, Disc, Track, Title and Compilation per track
Status: Draft | Source: AS-DOC-APL-039; AS-CODE-APL-018

For every track, apply writes these eight fields with TagLibSharp, from the
track's proposed tags (Year/Disc/Track coerced to `uint32`). Reading the
file back gives the same values. This works for FLAC and MP3. Which values
the proposal holds: see
[08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md).

Example: proposal tags `Some Band`, `Some Band`, `Some Album`, `2010`, disc
`1`, track `1`, `Track`, compilation `false` → the same values go to the
tag write.

### AS-APL-040 — The Compilation flag is written per format-specific tag, both ways; missing means false
Status: Draft | Source: AS-DOC-APL-040; AS-CODE-APL-019

`IsCompilation` is set explicitly (both `true` and `false`) on each of the
ID3v2 (`TCMP`), Apple/MP4 (`cpil`) and Xiph/Vorbis-comment (`COMPILATION`,
FLAC) tag objects individually — writing `false` also clears a previously-set
flag, not just skips setting it. A format with no such concept (e.g. plain
`.wav`) is silently skipped for that tag type. When the proposal's value is
missing, apply writes `false`.

Example: `Various\2008 A Compilation`, `isCompilation = true` → the tag
write gets `true`.

Example: write `true`, then write `false` on the same flac/mp3 → read back
`true`, then `false`.

How the flag gets onto the proposal in the first place (detection and the
release/track-level effect): see `AS-MAT-070`/`071` (detection) and
`AS-PRP-058` (effect on `proposed`/`tags`) in
[07-proposal-matching.md](07-proposal-matching.md) and
[08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md).

### AS-APL-041 — Non-ASCII text survives the tag write
Status: Draft | Source: AS-DOC-APL-041

Apply writes non-ASCII text (accents, Cyrillic) into tags without loss, for
FLAC and MP3.

Example: Artist `Björk`, Album `Океан Ельзи`, Title `Ça plane pour moi` →
read back the same.

### AS-APL-042 — A second tag write replaces the old tags
Status: Draft | Source: AS-DOC-APL-042; AS-CODE-APL-020

When apply writes tags to a file that already has tags, the new values
replace the old ones.

Example: first `First` / `First Album` / `First Title` / disc 1 / track 1,
then `Second` / `Second Album` / `Second Title` / disc 2 / track 5 → read
back the second set.

### AS-APL-043 — One front cover per file; the whole picture collection is replaced, or left alone if no cover is given
Status: Draft | Source: AS-DOC-APL-043; AS-CODE-APL-020

When a `CoverImagePath` is given and exists, the track's entire `Pictures`
collection is replaced with a single new picture: type FrontCover, MIME
`image/jpeg`, the same bytes as the file. A later write with no cover path
leaves the existing picture(s) untouched.

Example: red 64×64 `cover.jpg` → 1 picture, FrontCover, `image/jpeg`, same
bytes.

Example: write with `cover.jpg` and title `T1`, then without cover and
title `T2` → title `T2`, still 1 picture with the bytes of `cover.jpg`.

### AS-APL-044 — Tags can be written to a .mpc file with a leading ID3v2 tag
Status: Draft | Source: AS-DOC-APL-044; AS-CODE-APL-017

Opening a file for tag writing tries `TagLib.File::Create` normally first;
if that throws `TagLib.CorruptFileException` (a nonstandard leading ID3v2
tag on a `.mpc`/Musepack file breaking TagLib#'s audio-properties reader),
it retries with `ReadStyle.None` (skip audio-property parsing), sufficient
since tag writing doesn't need them.

Example: `track.mpc` with old tags `Old Artist` / `Old Album` / `Old Title`
→ write `Nostromo` / `Eyesore` / `Epitomize` → read back `Nostromo`,
`Eyesore`, `Epitomize`. (Real case: the Nostromo "Eyesore" release.)

### AS-APL-045 — A tag write failure fails only that release, cleanly logged, staging left in place
Status: Draft | Source: AS-DOC-APL-045; AS-CODE-APL-021; AS-CODE-APL-052

When tag writing fails (for example a corrupt file), the release fails.
The opened TagLib file handle is always saved and disposed inside
`try`/`finally`, released whether `Save()` succeeds or throws. The log
entry has status `failed` and the error text; the release's staging folder
stays for inspection; the release does not appear in the target. Other
releases continue.

Example: tag write throws `tag write boom` for `bbbbbbbbbbbbbbbb` → its log
entry is `failed` with `tag write boom`;
`<targetRoot>\.reshelf-staging\bbbbbbbbbbbbbbbb` exists; no
`Band One\2010 Album One`; `aaaaaaaaaaaaaaaa` is `applied`.

## Reading tags back

`AS-DOC-APL-046`–`048` ("Reading a file gives tags, format, lossless flag
and duration", "An embedded cover is saved to the data home cache", "A .mpc
file with a leading ID3v2 tag gives a tag-only read") describe
`Get-ReshelfAudioTags`, the same function recognize uses to read existing
tags. The REC merge already covered this exact behavior as `AS-REC-085`–
`089` (embedded-cover caching, the corrupt-file tag-only fallback,
format/lossless/duration) before this area was merged, with nothing left
over — no new `AS-APL` item is created for these three; `92-coverage.md`
points all three straight at the `AS-REC-*` entries.

## Companion files

### AS-APL-049 — A nested companion keeps its subfolder and name; companions are copied last
Status: Draft | Source: AS-DOC-APL-049; AS-CODE-APL-022; AS-CODE-APL-040

A companion with placement `nested` goes to the same relative subfolder path
inside the release folder, with the same (sanitized) file name; one with no
subfolder lands directly in the release folder. Companions are copied after
tags are written to every track, with any missing parent directory (e.g. a
nested subfolder) created first, using the same forced terminating copy as
tracks (`AS-APL-022`).

Example: source `...\2010 Album\Scans\back cover.jpg` →
`C:\target\Some Band\2010 Album\Scans\back cover.jpg`.

Example: fixture `ZZ Top\2003 Mescalero` → `scans\back.jpg` once in the
target release.

### AS-APL-050 — A loose companion gets its proposed file name, falling back to a kind-prefixed name
Status: Draft | Source: AS-DOC-APL-050; AS-DOC-APL-051; AS-CODE-APL-023

A companion with placement `loose` goes directly into the release folder
under its proposed, already-sanitized file name (set by Edit Proposal, so
the name starts with a letter per manifesto §4.5, keeping numbered tracks
first alphabetically). When an older `proposal.json` has no proposed name
for a loose companion, apply computes one at apply time instead, starting
with a letter from the companion's kind — never a digit, never the old `_`
prefix. How the name is normally proposed: see
[08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md).

Example: source `01 back.jpg`, proposed `Booklet 01 back.jpg` →
`C:\target\Some Band\2010 Album\Booklet 01 back.jpg`.

Example: loose `01-photo.jpg`, kind `photo`, no proposed name →
`Photo 01-photo.jpg`.

### AS-APL-051 — Every included companion's target path is validated before any file is touched
Status: Draft | Source: AS-DOC-APL-052; AS-DOC-APL-053; AS-DOC-APL-054; AS-DOC-APL-055; AS-CODE-APL-033

Before staging copies a single file: an excluded companion (`include =
false`) is skipped fully — not copied, not checked, its source stays; an
included loose companion's target name must start with a letter, or the
release fails before staging anything; an included loose companion whose
target name equals a track's file name fails the release; and two included
companions resolving to the same target path fail the release. Any
violation throws immediately, so a naming problem can never leave a
half-written staging folder or let one file silently overwrite another.

Example: excluded `1 bad name.jpg` (invalid name) → the release succeeds;
no `1 bad name.jpg` in staging.

Example: proposed `1 test.jpg` (digit-first) → failure, message contains
`must start with a letter`; no staging folder `b1b2c3d4e5f60708`.

Example: track `Track One.flac`, companion `dup.jpg` proposed as
`Track One.flac` → failure, message contains `same as a track file name`.

Example: `a.jpg` and `b.jpg` both proposed as `Extra Same Name.jpg` →
failure, message contains `would both be copied`.

## Long paths: name truncation

### AS-APL-052 — Names stay as they are when the full path is ≤ 250 characters
Status: Draft | Source: AS-DOC-APL-056; AS-CODE-APL-026

Apply checks the full target path of every file of a release against a
limit of 250 characters — intentionally below Windows' ~260-character hard
limit, because `\\?\`-prefixed long paths (which lift that limit elsewhere
in the app) aren't handled consistently by every external tool (Explorer,
zip utilities, cloud-sync clients). When all paths fit, apply keeps the
names and marks the release as not truncated.

Example: target root `D:\Music`, `Some Band` / `2010 Some Album` /
`01 Track.flac` → not truncated, names unchanged.

### AS-APL-053 — Long names are shortened; year prefix, track-number prefix and extension are kept; a nested companion's own path is not — carries CF-APL-010
Status: Draft | Source: AS-DOC-APL-057; AS-CODE-APL-024; AS-CODE-APL-025; cross-referenced with `AS-APL-070`–`072`; carried forward: see `91-suspected-defects-carryforward.md` (`CF-APL-010`, citing `AS-CODE-DEF-APL-002`)

When a full path would exceed 250 characters, apply shortens the readable
part of the artist folder, release folder and track file names until every
path fits, via a per-segment remaining-budget formula that never goes below
1 character. A track file name is first split into a never-truncated
leading number prefix (`^(\d+\s*[-–]\s*)` or `^(\d+\s+)`), a body, and the
extension; truncation only ever shortens the body. The release folder's
`yyyy ` prefix (`AS-APL-054`) is kept the same way.

Example: deep target root, long artist/release/track names → truncated;
release starts with `2010 `, track starts with `01 ` and ends with `.flac`;
full path ≤ 250.

Example: track `01 - Extremely … Long Track Title.flac` → the result starts
with `01 - `.

Carried forward: this budgeting and truncation covers the artist folder,
release folder and track file names (`AS-APL-053`/`054`/`070`–`072`), but a
nested companion file's relative subfolder path and file name are never
truncated or budgeted at all — only sanitized for illegal characters
(`AS-APL-049`). A release with a deeply nested companion structure can still
produce a final path well past the 250-character limit, despite the stated
goal of keeping human-facing names short by construction.

### AS-APL-054 — Only a real year (1900–2100) is a protected release-folder prefix — carries CF-APL-007
Status: Draft | Source: AS-DOC-APL-058; AS-CODE-APL-027; carried forward: see `91-suspected-defects-carryforward.md` (`CF-APL-007`, citing `AS-DOC-DEF-095`)

A leading 4-digit number followed by whitespace is treated as a
never-truncatable year prefix only when the number is between 1900 and 2100
inclusive — this bounds check stops a catalog-number-prefixed title (e.g.
`3218 (Edition) Album Title`) from being mistaken for a year. Outside that
range, the whole name is truncatable, which can shrink a release folder
name to as little as 1 character under a tight budget.

Example: artist of 1000 `A`, track `01 ` + 1000 `B`, root `C:\M`, limit 250:
release `2010 Some Album` → 6 characters, starts with `2010 `.

Example: same setup, release `3218 Some Catalog Album` → 1 character, does
not start with `3218`.

### AS-APL-055 — Truncated track names that would collide get a disambiguation suffix, never a silent overwrite
Status: Draft | Source: AS-DOC-APL-059; AS-CODE-APL-032

When truncating two tracks' names would produce the same result (only
possible when both lack a recognizable number prefix and their truncated
bodies coincide), the first occurrence uses no suffix; every later collision
for the same target name retries with `~2`, `~3`, … appended before the
extension, tracked via a case-insensitive used-name set. Both paths still
fit the limit.

Example: `Hidden Extremely … Alpha.flac` and `Hidden Extremely …
Beta.flac` (no number prefix) → two different names, both paths ≤ 250.

### AS-APL-056 — Truncation is recorded in the apply log, even on failure after staging
Status: Draft | Source: AS-DOC-APL-060; AS-CODE-APL-005; AS-CODE-APL-052

When apply shortens names, the apply-log entry has `truncated = true` and
the shortened target path — also true when the release fails after
staging, since the logged `TargetPath`/`Truncated` prefer the staging
result's own values (reflecting what was actually staged) over the raw,
untruncated path. Truncation is visible, not silent.

Example: the long release under a deep root → `Applied 1`; entry `applied`,
`truncated = true`, target path ≤ 250 characters and exists; its `.flac`
file starts with `01 `.

Example: same release, the final move throws `commit boom` → `Failed 1`;
entry `failed`, `truncated = true`, target path ≤ 250 and not the raw long
path.

## Apply log

### AS-APL-057 — The apply log lives in the data home, one file for every session ever applied
Status: Draft | Source: AS-DOC-APL-061; AS-CODE-APL-001

The apply log is the file `apply-log.json` directly under the data home —
not session-specific, not a per-session subfolder. When the file doesn't
exist, reading it returns an empty array, not an error — see `AS-APL-068`
for the invalid-file case. Looking up an entry by `stableKey` returns the
first match across every session ever applied; a stale entry from an
unrelated session can still be returned if its `stableKey` happens to match
(`AS-APL-069`). Data home location: see
[01-data-and-storage.md](01-data-and-storage.md).

Example: data home `<dataHome>` → `<dataHome>\apply-log.json`.

Example: new data home, no file → 0 entries.

### AS-APL-058 — One log entry per release, upserted (fully replaced) on each run — resolves AS-DOC-DEF-092
Status: Draft | Source: AS-DOC-APL-062; AS-CODE-APL-004; AS-CODE-APL-005; resolves `AS-DOC-DEF-092` (see `90-contradictions-resolution.md`)

An entry has: `stableKey`, `appliedAtUtc` (always UTC, fixed format
`yyyy-MM-ddTHH:mm:ss.fffZ` regardless of local timezone), `status`, target
path, source file-set hash, error message and truncated flag. The file
matches the `apply-log` schema. Adding an entry for a `stableKey` that
already has one removes the old row entirely and appends a brand-new one —
a full replace, not a field update — so a retry after failure (`failed` →
`applied`) always produces a clean new entry. Plan 08 lists only
`{ stableKey, appliedAtUtc, status, targetPath, sourceFileSetHash }`; the
tests and code also write and read `errorMessage` and `truncated` — the area
follows the tests/code.

Example: first entry `a1b2c3d4e5f60708`, `applied`,
`C:\target\Some Band\2010 Album`, hash `deadbeef` → 1 entry, schema-valid.

Example: `failed` with `boom`, then `applied` for the same key → 1 entry,
status `applied`, no error message.

`status` must be exactly one of `applied`, `failed`, `skipped` — but a new
finding while merging this area shows `skipped` is dead: see `AS-APL-069`.

### AS-APL-059 — A successful apply writes a full log entry; every attempted release gets one, success or failure
Status: Draft | Source: AS-DOC-APL-063; AS-CODE-APL-051

After a release applies, its log entry has status `applied`, the final
release folder as target path, no error message, `truncated = false` (when
no shortening happened) and a non-empty hash. Both the success and failure
branches always write an entry with the current timestamp; if the source
hash couldn't be computed (`AS-APL-016`), the literal sentinel
`'unavailable-source-missing'` is stored instead of a real hash.

Example: `a1b2c3d4e5f60708` → `applied`,
`<targetRoot>\Some Band\2010 Some Album`, no error, `truncated = false`,
hash present.

## Session stage after apply

### AS-APL-060 — Apply sets the session stage to "applied" or "partially-applied" from the results
Status: Draft | Source: AS-DOC-APL-064; AS-CODE-APL-054

At the end of a run, apply sets the session stage to `partially-applied`
when at least one release failed, otherwise `applied`. A skipped release
does not count as a failure. Stage meanings: see
[04-sessions.md](04-sessions.md).

Example: all releases succeed → `applied`. Example: one release fails at
tag writing → `partially-applied`. Example: the only release is unresolved
and skipped → `Skipped 1, Failed 0`, stage `applied`.

## Lossy tracking updates from apply

Ledger format and the `lossy` commands: see
[11-lossy-tracking.md](11-lossy-tracking.md).

### AS-APL-061 — A lossless replacement marks the ledger entry upgraded
Status: Draft | Source: AS-DOC-APL-065; AS-CODE-APL-050; AS-DOC-LSY-030 (same rule, plan/README sources)

When a release with lossy action `replace-existing` applies successfully,
apply sets its ledger entry to status `upgraded` and records the upgrade
time. The old lossy files are gone from the target folder.

Example: ledger has `Some Band` / `Some Album` / 2010, `mp3`, target has
`01 Track.mp3`; lossless source `01 Track.flac`, `update-existing` +
`replace-existing` → `Applied 1`; folder has `01 Track.flac`, no
`01 Track.mp3`; ledger `upgraded` with an upgrade time.

### AS-APL-062 — A logged lossy release gets the real committed path in the ledger, not the proposed one
Status: Draft | Source: AS-DOC-APL-066; AS-CODE-APL-050; AS-DOC-LSY-031 (same rule, plan source)

When a release with lossy action `log-for-upgrade` applies, apply writes
the real final folder path into its ledger entry, since the proposal step
logged the *proposed* path, which can differ from the final one (a
UI-edited folder name, or path-length truncation). The status stays
`pending-upgrade`. With `-WhatIf`, the ledger does not change.

Example: ledger path `<targetRoot>\Some Band\2010 Some Album`, the user
renamed the release folder to `2010 Some Album (Edited)` → after `-WhatIf`
the ledger path is unchanged; after a real run it is
`<targetRoot>\Some Band\2010 Some Album (Edited)`, status `pending-upgrade`.

## End-to-end results

### AS-APL-063 — Lossy first, lossless later: the target ends with only the lossless files
Status: Draft | Source: AS-DOC-APL-067

When the full pipeline runs first on a lossy copy of a release and later on
a lossless copy, the second apply replaces the lossy target folder.
Afterwards the folder holds only the lossless files, and the ledger entry is
`upgraded`. How propose finds the existing folder: see
[07-proposal-matching.md](07-proposal-matching.md).

Example: source `SOME BAND - SomeAlbum\01 - Track One.mp3`, Discogs
`Some Band` / `Some Album` / 2010 → `Applied 1`, target
`Some Band\2010 Some Album\01 Track One.mp3`, ledger `pending-upgrade`.

Example: then source `SOME BAND - SomeAlbum\01 - Track One.flac` → same
stableKey, `update-existing` + `replace-existing`; `Applied 1, Failed 0`;
the folder has only `01 Track One.flac`; ledger `upgraded`. (Real case, plan
12: Pulsar Olymp – 94 Shine, mp3 then FLAC.)

### AS-APL-064 — Full fixture run gives the expected target layout
Status: Draft | Source: AS-DOC-APL-068

Recognize → propose → apply with `-IncludeUnresolved` over the full fixture
tree gives `Failed 0`. The target matches the reviewed golden file
`legacy/tests/fixtures/expected/target-layout.txt`. The target has no
`.reshelf-staging` folder.

Example: `ZZ Top\1999 XXX\` → `01 Poke Chop Sandwich.flac`,
`02 Crucifixx A Flatt.flac`, `cover.jpg`.

Example: multi-disc `ZZ Top\2003 Mescalero\` → `01 Track One.mp3` …
`06 Stray Bonus Track.mp3`, `scans\back.jpg`, no `CD *` subfolder.

### AS-APL-065 — A re-run after apply does nothing — carries CF-APL-008
Status: Draft | Source: AS-DOC-APL-069; carried forward: see `91-suspected-defects-carryforward.md` (`CF-APL-008`, citing `AS-DOC-DEF-086`)

Running apply again on the same unchanged proposal applies nothing. A new
session with a new proposal for the same unchanged source also applies
nothing and fails nothing — the skip is keyed on the source file-set hash
(`AS-APL-011`), not on the proposal's content, so an edit made in the
review UI after a release was already applied, with unchanged source files,
never reaches the target on a later apply run. The README calls this a
caveat.

Example: first run `Applied` = N → re-run `Applied 0`, `Skipped` = N,
`Failed 0`.

Example: new session, re-propose, apply with `-IncludeUnresolved` →
`Applied 0, Failed 0`.

### AS-APL-066 — With real ffmpeg and TagLibSharp, the files hold the proposed tags
Status: Draft | Source: AS-DOC-APL-070

With the real tag library and real ffmpeg, a full run writes the release to
`<targetRoot>\<artistFolderName>\<releaseFolderName>\`. Each track file has
Artist, Album Artist, Album, Year, Disc, Track and Title equal to the
proposal's tags, and one FrontCover picture.

Example: source `Radiohead\1997 OK Computer\01 - Airbag.flac`,
`02 - Paranoid Android.flac`, `03 - Subterranean Homesick Alien.flac` →
`Applied 1, Failed 0`; every file matches its proposed tags.

## Checking the result

### AS-APL-067 — The user checks the target and the lossy ledger after apply
Status: Draft | Source: AS-DOC-APL-071

After apply, the user looks at `<targetRoot>` for the organized folders.
When lossy releases were found, the user lists the ledger with
`lossy list`. For failed releases, the user reads `errorMessage` in
`apply-log.json`.

Example: `pwsh scripts/Reshelf.ps1 lossy list`.

## Mechanics (code-only facts)

### AS-APL-068 — Apply-log read: missing file vs schema-invalid file
Status: Draft | Source: AS-CODE-APL-002

If the apply-log file doesn't exist yet, reading it returns an empty array
(`AS-APL-057`). If the file exists but fails `apply-log` schema validation,
reading it throws instead of returning an empty/partial result.

### AS-APL-069 — Apply log entries are shared across every session, with no session scoping — carries CF-APL-011
Status: Draft | Source: AS-CODE-APL-003; cross-referenced with `AS-APL-058`

Looking up a log entry by `stableKey` has no awareness of which session
produced it — a stale entry from an unrelated, long-finished session is
returned the same as a fresh one if its `stableKey` happens to match. Since
`status` accepts `applied`/`failed`/`skipped` (`AS-APL-058`) but the code
never actually writes `'skipped'` — only `'applied'` and `'failed'` are ever
passed to `Add-ReshelfApplyLogEntry` — a skipped release leaves no log entry
at all, consistent with `AS-APL-009` (no entry ⇒ needs apply next time) but
meaning the third `ValidateSet` value is presently unreachable. New finding,
no original phase-1/phase-2 source id; carried forward: see
`91-suspected-defects-carryforward.md` (`CF-APL-011`).

### AS-APL-070 — The release folder has a protected floor, reserved before the artist budget is computed
Status: Draft | Source: AS-CODE-APL-028; AS-CODE-APL-030; cross-referenced with `AS-APL-053`

The release folder's never-truncated floor is `releasePrefix.Length + 1`
(the year prefix, if any, plus at least one body character), reserved up
front. The artist folder's own truncation budget is computed only after
that: `MaxPathLength` minus what's consumed so far, minus `1 (separator) +
release floor + 1 (separator) + largest track floor` — so truncating the
artist name can never starve the release folder or any track file name of
its guaranteed minimum.

### AS-APL-071 — A track's floor reserves room for a future "~N" disambiguation tag, sized to the release's own track count
Status: Draft | Source: AS-CODE-APL-029

Each track's floor is `prefix length + 1 body char + extension length`,
then the largest such floor across the release is widened by
`1 + digits(max(1, trackCount))` characters — enough room for the worst-case
`~2`..`~N` collision suffix (`AS-APL-055`) that release could ever need.

### AS-APL-072 — The release folder's actual budget is never smaller than its own floor
Status: Draft | Source: AS-CODE-APL-031

The release folder's truncation length is `max(computed budget, release
floor)`, reserving `1 (separator) + largest track floor` after it — the
same floor-first mechanism as the artist budget (`AS-APL-070`).

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-13 | Area APL merged: 69 `AS-APL-*` requirements, `AS-APL-001`–`072` with a gap at `046`–`048` (68 `AS-DOC-APL-*` items folded in, 3 of them — `046`–`048` — redirected instead to the already-merged `AS-REC-085`–`089`; 5 fresh `AS-APL-068`–`072` for code-only budget/log mechanics). 6 phase-1 contradictions re-verified against `Reshelf.Implementation.psm1` and confirmed already correctly resolved (`AS-DOC-DEF-083`–`085`, `088`, `092`, `093`). 11 suspected defects carried forward (`CF-APL-001`–`011`, covering 8 phase-1 `AS-DOC-DEF-*` items — `086`, `087`, `089`–`091`, `094`–`096` — the 2 `AS-CODE-DEF-APL-*` entries, and 1 new finding — the `apply-log` `'skipped'` status value is defined but never written). |
| 0.2 | 2026-10-13 | During the LSY merge: `AS-APL-061`/`062` Source lines extended to also cite `AS-DOC-LSY-030`/`031` (the same two facts, restated from LSY's own plan/README sources with nothing new); the dangling `(not yet merged)` note under "Lossy tracking updates from apply" resolved to a real link now that `11-lossy-tracking.md` exists. |
