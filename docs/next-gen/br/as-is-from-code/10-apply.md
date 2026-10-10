# As-Is (from code): Apply

Status: Draft | Version: 0.1 | Last updated: 2026-10-10

Area code: APL. Source: `legacy/scripts/common/Reshelf.Implementation.psm1` only. Read directly from
code, independent of `docs/next-gen/br/as-is-from-docs/`.

### AS-CODE-APL-001 — Apply log file location
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:17 › Get-ReshelfApplyLogPath

The apply log is a single JSON file named `apply-log.json`, stored directly under the resolved data
home folder (not under a per-session subfolder).

Example: `DataHome` = `C:\Users\me\.reshelf` → log path = `C:\Users\me\.reshelf\apply-log.json`.

### AS-CODE-APL-002 — Apply log read: missing vs invalid
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:27 › Get-ReshelfApplyLog

If the apply-log file does not exist yet, reading it returns an empty array (not an error). If the
file exists but fails schema validation against the `apply-log` schema, reading it throws.

### AS-CODE-APL-003 — Apply log entry lookup
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:47 › Get-ReshelfApplyLogEntry

Looking up a log entry by `stableKey` returns the first matching row, or nothing if none matches.
The apply log is shared across every session ever applied — a stale entry from an unrelated session
can still be returned if its `stableKey` happens to match.

### AS-CODE-APL-004 — Apply log entry is an upsert, not a touch
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:60 › Add-ReshelfApplyLogEntry

Adding a log entry for a `stableKey` that already has one removes the old row entirely and appends a
brand-new one in its place (a full replace), rather than updating fields on the existing row. A retry
after a failure (`failed` → `applied`) therefore always produces a clean new entry.

### AS-CODE-APL-005 — Apply log entry shape and status values
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:60 › Add-ReshelfApplyLogEntry

A log entry's `status` must be exactly one of: `applied`, `failed`, `skipped`. `appliedAtUtc` is
always stored as UTC in the fixed format `yyyy-MM-ddTHH:mm:ss.fffZ` (millisecond precision, trailing
`Z`), regardless of the local timezone the value was created in.

Example: a `DateTime` of 2026-10-10 14:03:07.512 local time (UTC+2) is stored as
`2026-10-10T12:03:07.512Z`.

### AS-CODE-APL-006 — An "applied" entry is only trusted if it still points somewhere real
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:112 › Test-ReshelfAppliedEntryValid

A log entry only counts as "this release is already done" when all three hold: the entry exists, its
`status` is exactly `applied`, its `targetPath` starts with the current run's `TargetRoot` (compared
case-insensitively, since Windows paths are case-insensitive), and that target folder still physically
exists on disk. If `TargetRoot` was changed since the entry was written (moved to a new drive/folder)
or the folder was deleted/renamed outside Reshelf, the entry is treated as stale and the release needs
a real apply again, even though its recorded status and hash still look fine.

### AS-CODE-APL-007 — Needs-apply decision combines log validity and a live source hash
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:142 › Test-ReshelfReleaseNeedsApply

A release needs applying when its logged "applied" entry is no longer valid (AS-CODE-APL-006), OR the
current hash of its source files differs from the hash recorded at the time it was logged. The hash is
computed over the release's unique set of `sourceFilePath` values across all its tracks.

### AS-CODE-APL-008 — Missing source files don't block re-detecting an already-applied release
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:142 › Test-ReshelfReleaseNeedsApply

If hashing the release's source files throws (a source file has gone missing since the release was
first processed — Reshelf itself never deletes or modifies source files), the function does not
propagate that failure. It falls back to needs-apply = NOT(still-valid-applied-entry) and returns a
null hash, since there is nothing left to hash. Source files going missing between runs is treated as
normal, external, expected behavior, not an error condition.

### AS-CODE-APL-009 — Cue timestamps are converted to plain decimal seconds before reaching ffmpeg
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:181 › ConvertTo-ReshelfFfmpegSeconds

A cue sheet's `MM:SS:FF` timestamp is converted to a plain decimal-seconds string (3 decimal places,
always with a `.` separator via invariant culture, never a locale's `,`) before being passed to
ffmpeg's `-ss`/`-to`. Feeding the raw `MM:SS:FF` string to ffmpeg directly would make ffmpeg
misinterpret it as `HH:MM:SS` instead.

### AS-CODE-APL-010 — Cue track ranges are built per source file, not by track number
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:201 › ConvertFrom-ReshelfCueTrackRanges

Cue-virtual tracks are grouped by `sourceFilePath` (one group per physical source audio file, e.g. one
per disc), not sorted globally by `proposedTrackNumber`. Within each group, tracks are ordered by their
own `cueTimestamp`. Each track's split start is its own timestamp; its split end is the next track's
start in the same group, or nothing (meaning "to end of file") for the last track in the group.

### AS-CODE-APL-011 — ffmpeg split: argument quoting and base flags
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:232 › Invoke-ReshelfFfmpegSplit

Every path-bearing ffmpeg argument is wrapped in literal double quotes before being handed to
`Start-Process -ArgumentList`, because that cmdlet joins array elements with a single space and does
not itself quote elements containing spaces — without this, a real path like
`...\1994 Live In Concert (Bootleg)\...` would be split into multiple broken argv entries by ffmpeg.
Base flags are always `-hide_banner -loglevel error -y -i "<source>" -ss <start>`, plus `-to <end>`
when an end timestamp is given.

### AS-CODE-APL-012 — Codec choice on split: copy vs re-encode to FLAC
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:232 › Invoke-ReshelfFfmpegSplit

A `.ape` or `.flac` source is always re-encoded to FLAC (`-c:a flac`) on split. Every other source
format uses a lossless stream copy (`-c copy`, no re-encoding). Reason: ffmpeg has no APE encoder, so
`.ape` can never be stream-copied; and stream-copying a `.flac` would leave its FLAC `STREAMINFO`
`total_samples` field pointing at the original untrimmed file's length instead of the split track's own
length, so it must be re-encoded to get that field recomputed correctly.

### AS-CODE-APL-013 — Known ffmpeg FLAC "invalid block size" failure gets one automatic retry
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:232 › Invoke-ReshelfFfmpegSplit

If ffmpeg's stderr contains `invalid block size` (a known native-FLAC-encoder limitation when the cut
start lands a few samples before a source-file-internal frame boundary), the code retries exactly once
with the start timestamp nudged forward by `0.05` seconds (50 ms). The retry only happens if the start
timestamp can be parsed as a plain decimal number and the nudged start still lands before the end
timestamp (when one is given); otherwise it falls through to the ordinary failure.

Example: a split that fails with "invalid block size: N" at start `125.000` retries once with start
`125.050`.

### AS-CODE-APL-014 — ffmpeg stderr is always captured and surfaced on failure
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:232 › Invoke-ReshelfFfmpegSplit

ffmpeg's stderr is redirected to a temp file for every split attempt (initial and retry). On any
non-zero exit code, the thrown error message includes the exit code, both paths, and the captured
stderr text. The temp file is always removed afterward (success or failure) via a `finally` block.

### AS-CODE-APL-015 — Cover art resize: scale down only, never upscale
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:337 › Invoke-ReshelfFfmpegResize

The ffmpeg scale filter used for cover resizing is
`scale=w='min(N,iw)':h='min(N,ih)':force_original_aspect_ratio=decrease`, where `N` is
`MaxDimension`. A source image already smaller than `N` on both axes is never enlarged.

### AS-CODE-APL-016 — Cover download has no retry or custom timeout
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:373 › Invoke-ReshelfCoverDownload

Downloading a remote cover candidate is a single `Invoke-WebRequest -UseBasicParsing` call with no
retry logic and no explicit timeout override of its own.

### AS-CODE-APL-017 — Audio tag writing: TagLibSharp CorruptFileException fallback
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:396 › Set-ReshelfAudioTags

Opening a file for tag writing first tries `TagLib.File::Create` normally; if that throws
`TagLib.CorruptFileException` (e.g. a nonstandard leading ID3v2 tag on a `.mpc`/Musepack file that
breaks TagLib#'s audio-properties reader), it retries with `ReadStyle.None` (skip parsing audio
properties), which is sufficient since tag writing doesn't need them.

### AS-CODE-APL-018 — Tag fields written on every apply
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:396 › Set-ReshelfAudioTags

Every apply writes: Performers (artist), AlbumArtists (album artist), Album, Year, Disc number, Track
number, and Title. Year/Disc/Track are coerced to `uint32`.

### AS-CODE-APL-019 — Compilation flag is written per format-specific tag, not the base tag
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:396 › Set-ReshelfAudioTags

`IsCompilation` (TCMP/cpil/COMPILATION) is set on each of the ID3v2, Apple (MP4), and Xiph (Vorbis
comment / FLAC) format-specific tag objects individually, fetched without forcing their creation — both
`true` and `false` are written explicitly, so turning compilation off also clears a previously-set flag.
A format with no such concept (e.g. plain `.wav`) is silently skipped for that format's tag type.

### AS-CODE-APL-020 — Cover embedding replaces the whole picture collection
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:396 › Set-ReshelfAudioTags

If a `CoverImagePath` is given and the file exists, the track's `Pictures` collection is replaced
entirely with a single new picture of type `FrontCover`. If no cover path is given (or it doesn't
exist), the file's existing pictures are left untouched.

### AS-CODE-APL-021 — Tag file handle is always disposed
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:396 › Set-ReshelfAudioTags

The opened TagLib file is saved and disposed inside a `try`/`finally` — the handle is released
regardless of whether `Save()` succeeds or throws.

### AS-CODE-APL-022 — Nested companion files preserve their source subfolder structure
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:466 › Resolve-ReshelfCompanionTargetPath

A companion file with `placement = 'nested'` is targeted at the same relative subfolder path (under
the release folder) that it had relative to the release's source folder, with only its file name
sanitized. A companion with no subfolder (relative dir is empty) lands directly in the release folder.

### AS-CODE-APL-023 — Loose companion target name comes from the proposal, with a fallback
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:466 › Resolve-ReshelfCompanionTargetPath

A companion file with `placement = 'loose'` is targeted using its already-computed, sanitized
`proposedFileName` (set by the Edit Proposal step so the name starts with a letter, per manifesto
§4.5 — so alphabetical sorting always puts numbered tracks first). If `proposedFileName` is missing
(a proposal.json written before this field existed), the name is recomputed fresh at apply time
instead.

### AS-CODE-APL-024 — Track file name is split into a never-truncated prefix, body, and extension
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:515 › Split-ReshelfTrackFileName

A proposed track file name is parsed into three parts: a leading digit-based track-number prefix
(matching either `^(\d+\s*[-–]\s*)` — e.g. `"01 - "` — or `^(\d+\s+)` — e.g. `"01 "`), the remaining
title body, and the file extension. If neither pattern matches, the prefix is empty and the whole name
(minus extension) is the body.

Example: `"03 - Track Title.flac"` → prefix `"03 - "`, body `"Track Title"`, extension `".flac"`.

### AS-CODE-APL-025 — Remaining path budget formula
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:548 › Get-ReshelfRemainingPathBudget

The remaining budget for a path segment is `max(MaxLength - Consumed - Reserved, 1)` — it never
returns less than 1, guaranteeing every segment gets at least one character of room even when the
formula would otherwise go to zero or negative.

### AS-CODE-APL-026 — Default max path length for truncation is 250, not Windows' 260
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:569 › Resolve-ReshelfTruncatedReleaseNames

The default `MaxPathLength` for release-name truncation is 250 characters — intentionally below
Windows' ~260-character hard limit — because `\\?\`-prefixed long paths (which lift that hard limit
elsewhere in the app) are not handled consistently by every external tool (Explorer, zip utilities,
cloud-sync clients), so human-facing names are kept short by construction on top of the long-path
workaround.

### AS-CODE-APL-027 — Release folder name preserves a leading year prefix (1900–2100)
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:569 › Resolve-ReshelfTruncatedReleaseNames

If the proposed release folder name starts with a 4-digit number followed by whitespace, and that
number is between 1900 and 2100 inclusive, that `"yyyy "` prefix is treated as never-truncatable and
kept separate from the truncatable body. This bounds check prevents a catalog-number-prefixed title
(e.g. `"3218 (Edition) Album Title"`) from being mistaken for a year.

### AS-CODE-APL-028 — Release folder has a protected floor reserved before the artist budget is computed
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:569 › Resolve-ReshelfTruncatedReleaseNames

The release folder's never-truncated floor is `releasePrefix.Length + 1` (the year prefix, if any,
plus at least one body character). This floor is reserved up front, before the artist folder's budget
is computed, so truncating the artist name can never eat into the room the release folder needs.

### AS-CODE-APL-029 — Per-track floor includes a reserve for a future "~N" disambiguation tag
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:569 › Resolve-ReshelfTruncatedReleaseNames

Each track's floor is `prefix length + 1 body char + extension length`. The largest such floor across
all tracks in the release is additionally widened by a disambiguation reserve of
`1 + digits(max(1, trackCount))` characters — enough room for a `"~2"`..`"~N"` collision tag (see
AS-CODE-APL-032) up to the track count, so that reserve is sized to the worst case for that release.

### AS-CODE-APL-030 — Artist folder budget reserves room for everything below it
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:569 › Resolve-ReshelfTruncatedReleaseNames

The artist folder's truncation budget is computed from `MaxPathLength` minus what's already consumed
(root + separator) minus a reservation of `1 (separator) + release folder floor + 1 (separator) +
largest track floor` — so truncating the artist name can never starve the release folder or any track
file name of their own guaranteed minimums.

### AS-CODE-APL-031 — Release folder budget is never smaller than its own floor
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:569 › Resolve-ReshelfTruncatedReleaseNames

The release folder's actual truncation length is `max(computed release budget, release floor)` — it
reserves room for `1 (separator) + largest track floor` after it, same mechanism as the artist budget.

### AS-CODE-APL-032 — Track file name collisions get a "~N" disambiguation suffix, never a silent overwrite
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:569 › Resolve-ReshelfTruncatedReleaseNames

When truncating two tracks' names produces the same result (only possible when both tracks share the
same prefix — e.g. neither has a recognizable track-number prefix — and their truncated bodies
coincide), the first attempt uses no suffix; every subsequent collision for that same target name
retries with `"~2"`, `"~3"`, … appended before the extension, tracked via a case-insensitive used-name
set, instead of letting one track's staged file overwrite another's.

### AS-CODE-APL-033 — All companion target paths are validated before any file is touched
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:677 › Invoke-ReshelfReleaseStaging

Before staging writes a single file, every included companion's resolved target path is checked: a
loose companion's target file name must start with a letter (manifesto §4.5) or the release fails; a
loose companion whose target name collides with a track's file name fails the release; and two
companions that would both resolve to the same target path fail the release. Any violation throws
immediately, so a naming problem can never leave a half-written staging folder or silently overwrite
one file with another.

### AS-CODE-APL-034 — Staging path and final target path layout
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:677 › Invoke-ReshelfReleaseStaging

A release stages under `StagingRoot\<stableKey>` and commits to
`TargetRoot\<ArtistFolderName>\<ReleaseFolderName>`, using the already-truncated names from
AS-CODE-APL-026 through AS-CODE-APL-032.

### AS-CODE-APL-035 — Cue vs. normal tracks are branched per track, not per release
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:677 › Invoke-ReshelfReleaseStaging

Whether a track is ffmpeg-split from a cue sheet or plainly copied is decided per track via
`isCueVirtualTrack`, not once for the whole release — a release can mix cue-image discs with
ordinary track-file discs (a per-disc-cue release), and each cue track is split from its own disc's
source file, not one shared file for the whole release.

### AS-CODE-APL-036 — Defensive check that every cue-split output file actually exists
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:677 › Invoke-ReshelfReleaseStaging

After all cue splits for a release run (and only when not running under `-WhatIf`), the code verifies
every expected split output file is actually present on disk, throwing if one is missing. This is a
belt-and-braces check for the rare case ffmpeg exits 0 without producing an output file — the ffmpeg
wrapper itself already throws on a non-zero exit code.

### AS-CODE-APL-037 — Normal track copy forces a terminating error on failure
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:677 › Invoke-ReshelfReleaseStaging

Copying a non-cue track uses `Copy-Item -Force -ErrorAction Stop`. `Copy-Item`'s own default is a
non-terminating error, which would otherwise let staging continue as if the copy succeeded — the
release would then fail two steps later at tag-writing, blaming the missing staged file instead of the
real cause (the source file being gone).

### AS-CODE-APL-038 — Cover art working file uses a dot-prefixed, tool-specific name
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:677 › Invoke-ReshelfReleaseStaging

The resized cover art working file is named `.reshelf-cover-resized.jpg`, deliberately not a plain
`cover.jpg` — a loose companion legitimately named `cover.jpg` (valid under manifesto §4.5) can exist
in the same staging folder, and sharing a name would let the later working-file cleanup
(AS-CODE-APL-041) delete that real companion along with the working file.

### AS-CODE-APL-039 — "Existing (embedded)" cover candidate preserves tracks that already have a cover
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:677 › Invoke-ReshelfReleaseStaging

When the chosen cover candidate's `sourceEdition` is `'existing (embedded)'`, a track that already had
its own embedded cover (`HasExistingCover`) is left untouched rather than having the new cover
re-embedded into it. A track with no existing cover still gets the resized cover, so a release never
ends up with some tracks illustrated and others blank.

### AS-CODE-APL-040 — Companion files are copied last, directories created on demand
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:677 › Invoke-ReshelfReleaseStaging

Included companion files are copied after tags are written to all tracks. Any missing parent directory
for a companion's target path (e.g. a nested subfolder) is created first. The copy itself uses
`Copy-Item -Force -ErrorAction Stop`, same forcing rationale as AS-CODE-APL-037.

### AS-CODE-APL-041 — Cover-art working files never survive into the committed release folder
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:677 › Invoke-ReshelfReleaseStaging

If a cover was generated for the release, both the resized working file (`.reshelf-cover-resized.jpg`)
and the raw download (`cover-source.download`, only present if the cover source was a URL) are deleted
(best-effort, errors ignored) before the release is considered staged. A real source companion file is
never touched by this cleanup.

### AS-CODE-APL-042 — A staging failure is captured as a result, not an uncaught exception
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:677 › Invoke-ReshelfReleaseStaging

Any exception during staging (companion validation, ffmpeg split, copy, tag writing, …) is caught
internally and turned into `{ Success = $false; TargetPath; Truncated; ErrorMessage }` rather than
propagating — one release's failure is contained to that release's result object, not the whole batch.

### AS-CODE-APL-043 — Moving staged release to target re-validates the target-folder overwrite decision
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:845 › Move-ReshelfStagedReleaseToTarget

If the final target folder already exists, it is only removed and replaced when `TargetAction` is
exactly `update-existing` or `conflict` (a human-approved overwrite); any other value throws
`"target folder '<path>' already exists but the proposal says '<action>'; re-run propose"`. This check
runs here, immediately before the delete, rather than trusting the earlier proposal step — so a wrong
`targetAction` recorded upstream (e.g. `create-new` for a folder that turns out to already exist) fails
the release instead of destroying whatever is already in the target.

### AS-CODE-APL-044 — Replacing an existing target folder is a full recursive delete, then a move
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:845 › Move-ReshelfStagedReleaseToTarget

When an overwrite is authorized (AS-CODE-APL-043), the existing target folder is removed with
`Remove-Item -Recurse -Force`, then the staged folder is moved into place with `Move-Item -Force`. Any
missing parent directory for the final path is created first.

### AS-CODE-APL-045 — Empty ffmpeg path setting means "resolve via PATH"
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:885 › Invoke-ReshelfImplementation

If `FfmpegPath` is not given (the documented default empty settings value), it is defaulted to the
literal string `'ffmpeg'`, letting `Start-Process` resolve it via the system `PATH` the same way any
other CLI invocation of ffmpeg would.

### AS-CODE-APL-046 — Proposal document is schema-validated before use
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:885 › Invoke-ReshelfImplementation

Before an apply run reads anything from the proposal file, it validates it against the `proposal`
schema and throws `"Proposal document at '<path>' does not match the proposal schema."` if it fails.

### AS-CODE-APL-047 — Staging root is a hidden-style, target-root-local folder
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:885 › Invoke-ReshelfImplementation

Every apply run stages releases under `TargetRoot\.reshelf-staging`, a dot-prefixed folder inside the
same target root the releases are ultimately committed into.

### AS-CODE-APL-048 — Release gating order: rejected, then unresolved, then already-applied
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:885 › Invoke-ReshelfImplementation

For each release in the proposal, three gates are checked in this order: (1) `humanReview.rejected` —
always skipped and counted as "rejected", and this is never overridden by `-IncludeUnresolved`, because
rejection is a deliberate, permanent human decision, not merely "not yet reviewed"; (2)
`humanReview.resolved = false` — skipped unless `-IncludeUnresolved` is passed; (3) the needs-apply
check (AS-CODE-APL-007) — skipped if the release is already validly applied and its source hash is
unchanged.

### AS-CODE-APL-049 — CopyMode only ever accepts "copy"; apply never deletes or moves source files
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:885 › Invoke-ReshelfImplementation

The `CopyMode` parameter's `ValidateSet` allows only the literal value `'copy'`. Source files (tracks,
cue sheets, companions) are never deleted or modified by apply regardless of what `CopyMode` says —
the parameter exists only for backward compatibility with older callers; nothing in this function
branches on its value. A prior design that supported a "move" mode (deleting moved sources) was removed
after an incident destroyed source releases that had no other backup.

### AS-CODE-APL-050 — Lossy-tracking ledger is updated based on the release's lossy/lossless action
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:885 › Invoke-ReshelfImplementation

On a successful commit: if `lossyLossless.action` is `'replace-existing'`, the ledger entry for that
release's `stableKey` is marked `upgraded` (AS-CODE-LSY-007). If it is `'log-for-upgrade'`, the
ledger's `targetPath` is corrected to the actually-committed path (AS-CODE-LSY-008) — the proposal step
logged the *proposed* path, which can differ from the final one due to a UI-edited folder name or
path-length truncation.

### AS-CODE-APL-051 — Every attempted release gets an apply-log entry, success or failure
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:885 › Invoke-ReshelfImplementation

Both the success and failure branches record an apply-log entry (AS-CODE-APL-004/005) with the current
timestamp. If the source hash could not be computed (AS-CODE-APL-008), the literal sentinel string
`'unavailable-source-missing'` is stored as `sourceFileSetHash` instead of a real hash.

### AS-CODE-APL-052 — A failure outside staging itself is still caught and logged
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:885 › Invoke-ReshelfImplementation

An outer `try`/`catch` wraps staging, the commit move, and the lossy-ledger update together — this
catches anything thrown outside `Invoke-ReshelfReleaseStaging` itself (the commit move, or the ledger
update call), so one release's unexpected failure never stops the whole batch. The logged
`TargetPath`/`Truncated` prefer the staging result's own values (reflecting what was actually
staged/committed) when staging got that far, falling back to the raw, untruncated target path only if
staging never ran at all.

### AS-CODE-APL-053 — Empty staging-root wrapper folder is cleaned up, failed releases' folders are not
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:885 › Invoke-ReshelfImplementation

At the end of a run, the `.reshelf-staging` wrapper folder itself is removed only if it is completely
empty. A failed release's own staging subfolder is deliberately left in place (it already made the
wrapper non-empty), left behind for manual inspection — only a successfully-applied release ever moves
itself out of staging during the run.

### AS-CODE-APL-054 — Session stage after apply: "applied" vs "partially-applied"
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:885 › Invoke-ReshelfImplementation

At the end of an apply run, the session's stage is set to `applied` if no release failed, or
`partially-applied` if at least one did.

### AS-CODE-APL-055 — Apply run returns four counts: Applied, Skipped, Failed, Rejected
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:885 › Invoke-ReshelfImplementation

`Invoke-ReshelfImplementation` returns an object with `Applied`, `Skipped`, `Failed`, and `Rejected`
counts, tallied across every release in the proposal according to the gating order in
AS-CODE-APL-048 and the staging outcome.

## Suspected defects

- `AS-CODE-DEF-APL-001` — legacy/scripts/common/Reshelf.Implementation.psm1:731, 822, 862: the
  `New-Item -ItemType Directory` calls that create the staging folder, a companion's parent directory,
  and the final target's parent directory do not pass `-ErrorAction Stop`, unlike every `Copy-Item`
  call in the same function (AS-CODE-APL-037/040) and unlike the equivalent `New-Item` calls in
  `Reshelf.Settings.psm1`. If directory creation fails (permission denied, disk full), `New-Item`'s
  default non-terminating error lets execution continue as if the folder existed, surfacing a less
  clear failure later (e.g. a `Copy-Item` "path not found") instead of failing fast with a direct
  message.
- `AS-CODE-DEF-APL-002` — legacy/scripts/common/Reshelf.Implementation.psm1:466-503
  (`Resolve-ReshelfCompanionTargetPath`) and :569-673 (`Resolve-ReshelfTruncatedReleaseNames`): the
  path-length truncation logic budgets and truncates the artist folder, release folder, and track file
  names (AS-CODE-APL-026 through AS-CODE-APL-032), but a nested companion file's relative subfolder
  path and file name are never truncated or budgeted at all — they are copied through verbatim (only
  sanitized for illegal characters). A release with a deeply nested companion file structure can
  therefore still produce a final path well past `MaxPathLength` (250), despite the function's stated
  goal of keeping human-facing names short by construction.

## Changelog

| Version | Date | Changes |
|---|---|---|
| 0.1 | 2026-10-10 | Phase 2 draft from code. |
