# As-is (from code): Suspected defects

Status: Draft | Version: 0.1 | Last updated: 2026-10-10

Every suspected defect found while writing the Phase 2 (`AS-CODE-*`) area files, consolidated here
and renumbered sequentially (`AS-CODE-DEF-NNN`, flat, no sub-area) so IDs never collide across files.
Per rule D2, these describe behavior that looks wrong; none of them were fixed. Phase 3 decides what
happens to each one, alongside the phase 1 (`AS-DOC-DEF-*`) list.

Each entry keeps the area it came from and the per-area label the drafting agent originally used
(`DAT-001` etc.), so it can still be traced back to the exact paragraph in its area file.

## Data and storage (DAT)

### AS-CODE-DEF-001 (was AS-CODE-DEF-DAT-001)
`legacy/scripts/common/Reshelf.Common.psm1:525` (`Get-ReshelfRelativePath`) — the "is path under root" check is a plain string prefix match (`$Path.StartsWith($normalizedRoot, ...)`) with no check that a path separator follows the root. A root of `C:\Music` would match a path `C:\MusicArchive\foo.flac` (it textually starts with `C:\Music`), producing a wrong "relative" result (`Archive/foo.flac`) for a path that is not actually inside the root folder.

### AS-CODE-DEF-002 (was AS-CODE-DEF-DAT-002)
`legacy/scripts/common/Reshelf.Common.psm1:310` (`Test-ReshelfIsLosslessFormat`) vs `legacy/scripts/common/Reshelf.Common.psm1:3` (`$script:ReshelfAudioExtensions`) — `.alac` is treated as a lossless format, but `.alac` is absent from the audio-extensions list used by `Test-ReshelfIsAudioExtension` and therefore by `Get-ReshelfAudioFilesInFolder`. A standalone `.alac` file is never discovered as an audio file through the normal folder-scan path, making the "lossless" classification for that extension effectively unreachable in practice.

## Text and naming (TXT)

### AS-CODE-DEF-003 (was AS-CODE-DEF-TXT-001)
`legacy/scripts/common/Reshelf.Common.psm1:137-149` (`Test-ReshelfIsRomanizedText`) — despite its name, this function does not verify the text is actually Latin/romanized. It returns true for any non-Japanese string containing at least one Unicode letter of any script, so pure Cyrillic, Greek, or Arabic text would also be classified as "romanized". This feeds directly into `Join-ReshelfBilingualName`'s decision to join (AS-CODE-TXT-010), so a non-Japanese, non-Latin `Romanized` value could incorrectly be accepted and joined as if it were a valid romanization.

### AS-CODE-DEF-004 (was AS-CODE-DEF-TXT-002)
`legacy/scripts/common/Reshelf.Common.psm1:347` (`ConvertFrom-ReshelfTrackFileName`) — the bracket/paren pattern `^[\[\(](\d{1,3})[\]\)]\s*(?:[-–]\s*)?(.+)$` matches the opening and closing delimiters independently, so a mismatched pair like `"[01).mp3"` or `"(01].mp3"` is still accepted and yields track number `01`.

## Settings and secrets (SET)

### AS-CODE-DEF-005 (was AS-CODE-DEF-SET-001)
`legacy/scripts/common/Reshelf.Settings.psm1:188` (`Set-ReshelfDiscogsToken`) — the prompt text is plain `Discogs Personal Access Token`, with no mention that pressing Enter skips/clears it — but the code right below (line 189) silently accepts an empty entry and stores `""` anyway, identical in effect to a "skip". The prompt wording doesn't match the actual (permissive) behavior.

### AS-CODE-DEF-006 (was AS-CODE-DEF-SET-002)
`legacy/scripts/common/Reshelf.Settings.psm1:186` (`Set-ReshelfDiscogsToken`) combined with `:75` (`Get-ReshelfSettings`) — running `settings set-token` against a data home that has no `settings.json` yet does not fail with a clear "run init first" message — it silently runs the *entire* interactive settings-initialization flow (target root, source root, copy mode, and a first token prompt) before asking for the token a second time. This coupling is easy to trigger by accident and is not obviously intentional.

## Sessions (SES)

### AS-CODE-DEF-007 (was AS-CODE-DEF-SES-001)
`legacy/scripts/common/Reshelf.Settings.psm1:390-421` (`Set-ReshelfSessionStage`) — no validation that the requested `Stage` is a legal transition from the session's current stage. The workflow implied elsewhere in the same file (`Resume-ReshelfSession`'s stage-to-command mapping at `:374-381`) is clearly sequential (`recognized` → `proposed` → `reviewed` → `applied`/`partially-applied`), but nothing enforces that sequence here — a caller can set any of the 5 values on top of any current stage, including moving "backwards".

## Recognition (REC)

### AS-CODE-DEF-008 (was AS-CODE-DEF-REC-001)
`legacy/scripts/common/Reshelf.Recognition.psm1:966` (`Split-ReshelfLeadingYear`, full-date form) — the day value is only range-checked as 1–31 regardless of the month, so an impossible date like "2024.02.30" would still be accepted as a valid release date.

### AS-CODE-DEF-009 (was AS-CODE-DEF-REC-002)
`legacy/scripts/common/Reshelf.Recognition.psm1:1193` vs `:1198-1269` (`New-ReshelfReleaseRecord`) — the "nested-release-suspected" check (a non-disc subfolder that independently qualifies as its own release folder) is only performed in the no-named-disc-subfolders branch. A multi-disc release (with "CD1"/"CD2"-style subfolders) that also has an unrelated nested release subfolder gets no equivalent flag.

### AS-CODE-DEF-010 (was AS-CODE-DEF-REC-003)
`legacy/scripts/common/Reshelf.Recognition.psm1:1273-1296` and `:1343,1353,1395,1406,1419` (`New-ReshelfReleaseRecord` / `Invoke-ReshelfFolderWalk`) — `recognitionConfidence` is computed once inside `New-ReshelfReleaseRecord`, before the function returns. Callers (`Invoke-ReshelfFolderWalk` and `Add-ReshelfInheritedReviewReasons`) can subsequently force `needsReview=true` and append review reasons (e.g. "artist-name-split-from-folder-name", "artist-and-album-from-tags", "multiple-editions-in-album-folder", "grouping-folder-auto-resolved") without ever recalculating `recognitionConfidence`, so a release can end up with `needsReview=true` while `recognitionConfidence` still reads `1.0` or `0.8` instead of `0.5`.

### AS-CODE-DEF-011 (was AS-CODE-DEF-REC-004)
`legacy/scripts/common/Reshelf.Recognition.psm1:1337` (`Invoke-ReshelfFolderWalk`) and `:1388` (same function, album-wrapper branch) — the no-artist-yet "Artist - Title" folder-name split only matches a literal ASCII `" - "` separator, not an en-dash/em-dash, even though other heuristics in this same module (e.g. `Split-ReshelfLeadingYear`, `Remove-ReshelfArtistNamePrefixFromTitle`) explicitly treat en-dash/em-dash as equivalent separators.

### AS-CODE-DEF-012 (was AS-CODE-DEF-REC-005)
`legacy/scripts/common/Reshelf.Recognition.psm1:179-221` vs `:138-177` (`Test-IsBandMemberFolder` vs `Test-IsGroupingFolder`) — grouping-folder detection requires every subfolder to fail the release/disc/category/album-wrapper checks before granting grouping status, but band-member-folder detection only requires at least one release-folder subfolder to exist, without excluding subfolders that look like disc, category, or album-wrapper folders mixed in alongside it. The two "pure container of releases" heuristics apply different levels of rigor to structurally similar shapes.

### AS-CODE-DEF-013 (was AS-CODE-DEF-REC-006)
`legacy/scripts/common/Reshelf.Recognition.psm1:706-710` (`Save-ReshelfEmbeddedCoverToCache`) — the cache file extension is chosen only from a 2-way switch (png vs. everything-else-as-jpg) on the picture's declared MIME type. A picture whose actual bytes are a different format (e.g. GIF or WEBP) than its declared/assumed type would be cached with a ".jpg" extension that doesn't match its real content.

### AS-CODE-DEF-014 (was AS-CODE-DEF-REC-007)
`legacy/scripts/common/Reshelf.Recognition.psm1:725-781` (`Get-ReshelfAudioTags`), called from `:539,803,1168,1214,1247` (`New-ReshelfCueVirtualTracks`, `Resolve-ReshelfArtistAlbumFromTags`, `New-ReshelfReleaseRecord`) — only `Get-ReshelfReleaseFolderMetadataArtist` wraps its call to `Get-ReshelfAudioTags` in a try/catch. Every other call site invokes it unguarded, so any exception other than TagLib's "corrupt file" case (already handled inside `Get-ReshelfAudioTags` itself) — e.g. an unsupported format — would propagate up and abort the whole recognition run instead of being recorded as a per-track review flag.

## Discogs client (DSC)

### AS-CODE-DEF-015 (was AS-CODE-DEF-DSC-001)
`legacy/scripts/common/Reshelf.Discogs.psm1:287,290,315-330` — the third element of both backoff arrays (`$backoffSeconds[2]` = 4s, `$rateLimitBackoffSeconds[2]` = 60s) is unreachable: with `$maxAttempts = 3`, the "attempt equals max attempts" check throws before attempt 3 ever reaches the backoff/sleep code, so only indices `0` and `1` of each array are ever used.

### AS-CODE-DEF-016 (was AS-CODE-DEF-DSC-002)
`legacy/scripts/common/Reshelf.Discogs.psm1:162` (`Wait-DiscogsRateLimit`) — the low-remaining signal is reset to `false` unconditionally, even when the throttle condition is true but the tracked timestamp list is empty (so `$shouldThrottle -and $script:DiscogsRequestTimestamps.Count -gt 0` is false and no sleep happens). A 429 or low-remaining signal received just before the timestamp window empties out (e.g. after a long idle gap) is silently discarded with zero delay enforced.

## Proposal matching (MAT)

### AS-CODE-DEF-017 (was AS-CODE-DEF-MAT-001)
`legacy/scripts/common/Reshelf.EditProposal.psm1:263-267` (`Get-ReshelfDiscogsCandidateScore`) — the year-difference check only compares the raw numeric year, so a candidate exactly 1 year off gets `0` adjustment (same as an unknown year) while a 2+ year difference is penalized. A release that is genuinely a different edition/remaster one year off the source's year is treated identically to a perfect year match in scoring, even though the code comment elsewhere (title-cleaning logic) explicitly treats "1 year off" as meaningfully different from "exact".

### AS-CODE-DEF-018 (was AS-CODE-DEF-MAT-002)
`legacy/scripts/common/Reshelf.EditProposal.psm1:1220-1232` (`Resolve-ReshelfDiscogsMatch`, ambiguous-candidate assembly) — building `$masterCandidates` re-fetches each of the top 5 scored masters' detail just to read `main_release`, even when those same masters were already fetched earlier in the same call (e.g. via `Select-ReshelfDiscogsMasterVersion` for a different candidate, or via the artist-master-list path) — relies entirely on the Discogs response cache to avoid a real duplicate network call, with no in-memory reuse.

## Proposal naming and tags (PRP)

### AS-CODE-DEF-019 (was AS-CODE-DEF-PRP-001)
`legacy/scripts/common/Reshelf.EditProposal.psm1:2083-2087` (`Find-ReshelfPreviousLossyEntry`) — the fallback fuzzy ledger scan picks the first `pending-upgrade` entry matching artist+year+fuzzy-album-variant overlap (`Select-Object -First 1`) with no further disambiguation. Two different pending-upgrade albums by the same artist in the same year, whose Discogs search-title variants happen to overlap, could cause the wrong previous-lossy folder to be reported.

### AS-CODE-DEF-020 (was AS-CODE-DEF-PRP-002)
`legacy/scripts/common/Reshelf.EditProposal.psm1:2764` (`Update-ReshelfReleaseForDiscogsSelection`) — calls `New-ReshelfProposedTrackSet` without `-FileNameArtists`, and this function never computes `Get-ReshelfVariousArtistsEvidence` at all (contrast line 2576 in `New-ReshelfProposedRelease`, which passes `-FileNameArtists $vaEvidence.FileNameArtists`). A compilation release that gets its Discogs match manually re-picked loses the filename-parsed-artist fallback tier (AS-CODE-PRP-049) for tracks with no existing Artist tag and no Discogs per-track credit, unlike the same release processed through the normal batch-propose path.

### AS-CODE-DEF-021 (was AS-CODE-DEF-PRP-003)
`legacy/scripts/common/Reshelf.EditProposal.psm1:2647-2842` (`Update-ReshelfReleaseForDiscogsSelection`) — never reads or forwards `$Release.needsReview` / `$Release.reviewReasons` into its own `requiresReview`/`notes` output, unlike `New-ReshelfProposedRelease` (lines 2496-2499), whose own comment explicitly calls out fixing exactly this "previously silently dropped" gap for the batch path. A release flagged for review at recognition time can have that flag effectively disappear once the user manually re-picks its Discogs match.

### AS-CODE-DEF-022 (was AS-CODE-DEF-PRP-004)
`legacy/scripts/common/Reshelf.EditProposal.psm1:1915-1922` and `:1955-1962` (`Get-ReshelfImageDimensions` / `New-ReshelfCoverArtProposal`) — the 1x1 sentinel used to mean "couldn't decode this image" is indistinguishable from a real 1x1-pixel source image. Any embedded cover that is genuinely exactly 1x1 would be silently dropped as if it were corrupt.

## Review UI (REV)

### AS-CODE-DEF-023 (was AS-CODE-DEF-REV-001) — Manual-cover upload size limit (20 MB) is hard-coded independently in two places
`legacy/scripts/common/Reshelf.UiServer.psm1:333` (`$script:ReshelfUiManualCoverMaxBytes = 20MB`) and `legacy/scripts/Start-ReshelfUiServer.ps1:77` (`[long]$MaxBytes = 20MB` default parameter on `Read-ReshelfUiRequestBodyBytes`). Since the HTTP-layer call site never overrides that default, the module-level check in `Save-ReshelfUiManualCoverFile` (REV-052) can never actually trigger via the real upload path — the request body is already rejected at the earlier, independently-maintained limit first. If either literal is changed without the other, the two checks silently diverge.

### AS-CODE-DEF-024 (was AS-CODE-DEF-REV-002) — GET /api/current-session and GET /api/sessions/{id}/proposal expose the same proposal.json differently
`legacy/scripts/Start-ReshelfUiServer.ps1:112` (CurrentSession: parses then re-serializes the proposal with `ConvertFrom-Json`/`ConvertTo-Json -Depth 20`) versus `:130` (GetProposal: writes the raw file content through unchanged). The same underlying file can come back with different formatting (and potentially different number precision/property order) depending on which endpoint the client happens to call.

### AS-CODE-DEF-025 (was AS-CODE-DEF-REV-003) — LocalFile handler reports every failure as HTTP 403, including "file no longer exists"
`legacy/scripts/Start-ReshelfUiServer.ps1:216`. A genuinely missing file (`Get-ReshelfUiLocalFileBytes` throwing "File '...' no longer exists.") is reported as 403 Forbidden rather than 404 Not Found, conflating an access-control failure with a simple not-found condition.

### AS-CODE-DEF-026 (was AS-CODE-DEF-REV-004) — DeleteLossy handler reports every failure as HTTP 404, including non-"not found" errors
`legacy/scripts/Start-ReshelfUiServer.ps1:272`. Any exception from `Remove-ReshelfLossyTrackingEntry` (e.g. a file lock or disk I/O error, not just "no such entry") is reported to the client as 404 Not Found.

### AS-CODE-DEF-027 (was AS-CODE-DEF-REV-005) — Stale comment claims the client's safe-filename sanitizer skips reserved-device-name handling, but the code does include it
`legacy/ui/app.js:846-847` (comment on `deriveProposedFolderNames`) says `toSafeFileName` "doesn't reproduce the reserved-device-name suffixing, which 'propose' still applies for real on Save," but the actual `toSafeFileName` implementation at `legacy/ui/app.js:933-936` does append `_` for a name matching a reserved Windows device name (CON, PRN, AUX, NUL, COM1-9, LPT1-9). The comment appears to predate that addition and is now misleading about actual behavior.

### AS-CODE-DEF-028 (was AS-CODE-DEF-REV-006) — Release notes textarea has no null-safety fallback, unlike the equivalent lossy-notes field elsewhere in the same file
`legacy/ui/app.js:391` (`notesField.value = release.humanReview.notes;`) assigns the field directly with no `?? ''` fallback, while the lossy-tracker edit path a few hundred lines later (`legacy/ui/app.js:1204`, `notes: entry.notes ?? ''`) treats a null notes value defensively. If `humanReview.notes` is ever `null` (e.g. a release that was never reviewed), the textarea would display the literal text "null" instead of being empty.

### AS-CODE-DEF-029 (was AS-CODE-DEF-REV-007) — An unsupported HTTP method on a recognized API path is served as a generic static-file 404 instead of a clear API error
`legacy/scripts/common/Reshelf.UiServer.psm1:100-153` (`Get-ReshelfUiApiRoute`) — for both `/api/sessions/{id}/proposal` (GET/PUT only) and `/api/lossy/{stableKey}` (PUT/DELETE only), any other method matches the path's regex, passes the session-id/stable-key validation, but then falls through every method-specific `if` with no action returned — the function returns `$null` for that method, and the request ends up handled as if it were a static-file lookup, returning `404 Not found: /api/sessions/...` instead of a 405 Method Not Allowed or a clearer 400.

## Apply (APL)

### AS-CODE-DEF-030 (was AS-CODE-DEF-APL-001)
`legacy/scripts/common/Reshelf.Implementation.psm1:731, 822, 862` — the `New-Item -ItemType Directory` calls that create the staging folder, a companion's parent directory, and the final target's parent directory do not pass `-ErrorAction Stop`, unlike every `Copy-Item` call in the same function (AS-CODE-APL-037/040) and unlike the equivalent `New-Item` calls in `Reshelf.Settings.psm1`. If directory creation fails (permission denied, disk full), `New-Item`'s default non-terminating error lets execution continue as if the folder existed, surfacing a less clear failure later (e.g. a `Copy-Item` "path not found") instead of failing fast with a direct message.

### AS-CODE-DEF-031 (was AS-CODE-DEF-APL-002)
`legacy/scripts/common/Reshelf.Implementation.psm1:466-503` (`Resolve-ReshelfCompanionTargetPath`) and `:569-673` (`Resolve-ReshelfTruncatedReleaseNames`) — the path-length truncation logic budgets and truncates the artist folder, release folder, and track file names (AS-CODE-APL-026 through AS-CODE-APL-032), but a nested companion file's relative subfolder path and file name are never truncated or budgeted at all — they are copied through verbatim (only sanitized for illegal characters). A release with a deeply nested companion file structure can therefore still produce a final path well past `MaxPathLength` (250), despite the function's stated goal of keeping human-facing names short by construction.

## Lossy tracking (LSY)

No suspected defects found in `Reshelf.LossyTracking.psm1`.

## CLI (CLI)

### AS-CODE-DEF-032 (was AS-CODE-DEF-CLI-001)
`legacy/scripts/Reshelf.ps1:144-154` (`'apply'` case) — this is the only long-running command (`recognize`, `propose`, `apply`) without its own `try`/`catch` that adds user-facing context before rethrowing. An `apply`-time failure surfaces as a raw, unwrapped PowerShell error instead of the `"<Step> failed for session '<id>': <message>"` style the other two give, which is inconsistent given the otherwise-parallel structure of these three cases.

### AS-CODE-DEF-033 (was AS-CODE-DEF-CLI-002)
`legacy/scripts/Reshelf.ps1:193-206` (`'ignore'`, `'mark-upgraded'`, `'remove'` under `'lossy'`) — these subcommands read a lossy-ledger stable key out of the `-SessionId` parameter (immediately aliased to `$stableKey`), rather than a dedicated `-StableKey` parameter. A scripted caller passing `-SessionId` to a `lossy` subcommand, reasonably expecting it to mean a session (as it does for every `session` subcommand), would be silently operating on a ledger stable key instead.

### AS-CODE-DEF-034 (was AS-CODE-DEF-CLI-003)
`legacy/scripts/Reshelf.ps1:27-29` (`$Format` default `'csv'`) — the default is declared once, at script scope, for a parameter name that currently only `lossy export` reads. This is harmless today, but any future command parameter also named `-Format` would silently inherit this default rather than one of its own.

## Bandcamp (BND) and cross-cutting error handling (ERR)

No suspected defects — these two sections describe absence/confirmation facts (Bandcamp is plan-only; error-handling patterns are consistent app-wide, see [13-bandcamp-and-errors.md](13-bandcamp-and-errors.md)), not behavior that looks wrong.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-10 | Phase 2 merge: consolidated 34 suspected defects from the 13 area files, renumbered flat. |
