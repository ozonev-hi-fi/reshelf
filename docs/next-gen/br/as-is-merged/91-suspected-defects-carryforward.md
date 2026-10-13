# 91 — Suspected defects, carried forward (Phase 3)

Status: Draft | Version: 0.12 | Last updated: 2026-10-13

Every `AS-DOC-DEF-*` and `AS-CODE-DEF-*` entry of type "Suspected defect"
(not "Contradiction" — those are resolved in
[90-contradictions-resolution.md](90-contradictions-resolution.md)),
de-duplicated and cross-referenced where both sets flagged the same issue.

**Disposition (keep / fix / drop) is deferred to phase 4** — see
[../../sessions/br-apply-ng-vision.md](../../sessions/br-apply-ng-vision.md).
Nothing here is decided yet.

Filled in area by area, alongside the area files.

## GEN

### CF-GEN-001 — Links from the review UI to Discogs and Bandcamp pages
Sources: `AS-DOC-DEF-001` (Kind: unimplemented idea). No `AS-CODE` counterpart
(nothing to find in code for a feature that was never implemented).

Plan 00 lists an idea: the review UI links to the Discogs release page (when
the exact pressing is known) or to the master release page, also in the
"ambiguous" section, and in the same way to Bandcamp. No README section, plan
file, test or code says that these links exist.

## DAT

### CF-DAT-001 — Two different editions of the same artist/album/year collide on one stable key
Sources: `AS-DOC-DEF-006`. No `AS-CODE` counterpart (this is a design-level
consequence of the stable-key formula, not a code-level bug).

The stable key uses only artist, album and year (`AS-DAT-064`).
`editionFolderName` is not an input. So two real editions — for example an
original pressing and a same-year reissue — collide on one key, even though
plan 03 says the key identifies "the same real-world release" and separately
describes the user having to manually reject one of two folders that turn
out to be different pressings. See also `CF-PRP` (when that area is merged)
for the related, opposite case: one real release getting two different
stable keys because the source folder was renamed (`AS-DOC-DEF-057`).

### CF-DAT-002 — The placeholder year 1900 is indistinguishable from a real year 1900
Sources: `AS-DOC-DEF-007`. No `AS-CODE` counterpart (the placeholder is
written by the propose step, outside this area's code source).

For an unknown year, propose writes the placeholder `1900` (the schema
minimum, see `AS-DAT-058`). `tags.year` and the lossy-tracking `year` cannot
be `null`, so a real recording from 1900 and an unresolved year look
identical in the folder name and the tags. Plan 03 notes that target
matching cannot rely on the folder name in this case.

### CF-DAT-003 — Companion file placement is schema-free text, not limited to loose/nested
Sources: `AS-DOC-DEF-008`. No `AS-CODE` counterpart (schema constraints
aren't part of the code-only source set).

Plan 03 and MANIFESTO §4.5 describe only two placements, `loose` and
`nested`, but `recognition.schema.json`'s `companionFile.placement` accepts
any non-empty string (`AS-DAT-045`). Validation would not catch a typo or a
third value.

### CF-DAT-004 — Relative-path root check is a plain string prefix match, not a folder-boundary match
Sources: `AS-CODE-DEF-001` (`AS-CODE-DEF-DAT-001` in the original per-area
numbering). No `AS-DOC` counterpart (the docs-and-tests view had no test
covering this edge case).

`Get-ReshelfRelativePath`'s "is this path under the root" check
(`AS-DAT-083`) is `$Path.StartsWith($normalizedRoot, ...)` with no check
that a path separator follows the root. A root of `C:\Music` textually
matches `C:\MusicArchive\foo.flac` too, producing a wrong "relative" result
(`Archive/foo.flac`) for a path that is not actually inside the root folder.

### CF-DAT-005 — `.alac` is classified lossless but is never found as an audio file
Sources: `AS-CODE-DEF-002` (`AS-CODE-DEF-DAT-002` in the original per-area
numbering). No `AS-DOC` counterpart (the docs-and-tests view had no test
exercising a standalone `.alac` file).

`Test-ReshelfIsLosslessFormat` treats `.alac` as lossless (`AS-DAT-078`), but
`.alac` is absent from the audio-extension list (`AS-DAT-076`) used by
`Test-ReshelfIsAudioExtension` and therefore by `Get-ReshelfAudioFilesInFolder`.
A standalone `.alac` file is never discovered as an audio file through the
normal folder-scan path, making the "lossless" classification for that
extension effectively unreachable in practice.

## TXT

### CF-TXT-001 — "Is romanized" accepts any non-Japanese letter, not just Latin/romanized text
Sources: `AS-CODE-DEF-003` (`AS-CODE-DEF-TXT-001` in the original per-area
numbering). No `AS-DOC` counterpart (the docs-and-tests view only noted that
"tests do not cover other scripts, for example Cyrillic" — AS-TXT-010 —
without flagging it as a defect).

`Test-ReshelfIsRomanizedText` (AS-TXT-010) does not verify the text is
actually Latin/romanized. It returns true for any non-Japanese string
containing at least one Unicode letter of any script, so pure Cyrillic,
Greek or Arabic text also counts as "romanized". This feeds directly into
`Join-ReshelfBilingualName`'s decision to join (AS-TXT-015): a non-Japanese,
non-Latin `Romanized` value could be accepted and joined as if it were a
valid romanization.

### CF-TXT-002 — A truncated segment can end up longer than the limit
Sources: `AS-DOC-DEF-012`; confirmed by `AS-CODE-TXT-024`.

When the limit is smaller than prefix + suffix, the truncation helper
(AS-TXT-038) still keeps one body character. The result is then longer than
the limit: limit 5 → `01 S.flac` (9 characters). Truncation exists to stay
within a path length limit, so exceeding it defeats the purpose.

### CF-TXT-003 — A mismatched bracket/parenthesis pair is still read as a track number
Sources: `AS-CODE-DEF-004` (`AS-CODE-DEF-TXT-002` in the original per-area
numbering). No `AS-DOC` counterpart (the docs-and-tests view had no test
covering a mismatched pair). Concerns `ConvertFrom-ReshelfTrackFileName`,
which is REC-owned content deferred to that area's merge (see the scope note
in [02-text-and-naming.md](02-text-and-naming.md)) — carried forward here
under TXT because that is where the code-phase agent filed it; cross-reference
`AS-DOC-REC-056` when REC is merged.

The bracket/paren pattern `^[\[\(](\d{1,3})[\]\)]\s*(?:[-–]\s*)?(.+)$` matches
the opening and closing delimiters independently, so a mismatched pair like
`"[01).mp3"` or `"(01].mp3"` is still accepted and yields track number `01`.

## SET

### CF-SET-001 — The `set-token` prompt doesn't say that Enter skips/clears it
Sources: `AS-CODE-DEF-005` (`AS-CODE-DEF-SET-001` in the original per-area
numbering). No `AS-DOC` counterpart (the docs-and-tests view only states the
permissive behavior itself — `AS-SET-042` — without flagging the wording
mismatch as a defect).

`Set-ReshelfDiscogsToken`'s prompt text is plain `Discogs Personal Access
Token`, with no mention that pressing Enter skips/clears it — but the code
right below silently accepts an empty entry and stores `""` anyway,
identical in effect to a "skip". The prompt wording doesn't match the
actual (permissive) behavior. Compare `Initialize-ReshelfSettings`'s token
prompt, whose wording does say "(press Enter to skip, set later with:
Reshelf.ps1 settings set-token)" — `set-token`'s own prompt doesn't carry
the same hint for itself.

### CF-SET-002 — `set-token` on a data home with no settings file silently runs full init first
Sources: `AS-CODE-DEF-006` (`AS-CODE-DEF-SET-002` in the original per-area
numbering). No `AS-DOC` counterpart (the docs-and-tests view describes
`set-token` only against an existing settings file).

Running `settings set-token` against a data home that has no `settings.json`
yet does not fail with a clear "run init first" message — it silently runs
the *entire* interactive settings-initialization flow (target root, source
root, copy mode, and a first token prompt, `AS-SET-042`) before asking for
the token a second time. This coupling is easy to trigger by accident and is
not obviously intentional.

## SES

### CF-SES-001 — No validation that a stage change is a legal transition from the current stage
Sources: `AS-CODE-DEF-007` (`AS-CODE-DEF-SES-001` in the original per-area
numbering). No `AS-DOC` counterpart (the docs-and-tests view only states the
five allowed values, `AS-SES-009`, without flagging the missing order check
as a defect).

`Set-ReshelfSessionStage` only checks that the requested `Stage` is one of
the five known literal values (`AS-SES-009`). It does not look at the
session's current stage at all, so any of the five can be set on top of any
current stage — including moving an `applied` session back to `recognized`.
The workflow implied by `Resume-ReshelfSession`'s stage-to-command mapping
(`AS-SES-012`–`016`) is clearly sequential; nothing enforces that sequence on
write.

### CF-SES-002 — Listing fails entirely on one malformed session.json, instead of skipping it like a missing one
Sources: found while merging this area, re-reading `Get-ReshelfSession`'s
listing branch (`legacy/scripts/common/Reshelf.Settings.psm1:325-356`). No
`AS-DOC` or `AS-CODE` source names this combination directly —
`AS-CODE-SES-006`/`007` each describe one half of it in isolation; untested
by the Pester suite (its schema-validation test, behind `AS-SES-022`, only
exercises lookup by id).

When listing all sessions, a subfolder with no `session.json` is silently
skipped (`AS-SES-025`), but a subfolder whose `session.json` exists and
fails schema validation is not — reading it throws, and that exception
propagates out of the whole listing call. So `session list` (and anything
else that calls the no-id form, e.g. the UI's session list) fails completely
because of one bad session, with no indication in the error of which session
caused it.

## REC

### CF-REC-001 — A full release date's day is only checked 1–31, regardless of the month
Sources: `AS-CODE-DEF-REC-001`. No `AS-DOC` counterpart (the docs-and-tests
view had no test exercising an impossible day-of-month).

`Split-ReshelfLeadingYear`'s full-date form (`AS-REC-051`) bounds-checks
year 1900–2100, month 1–12 and day 1–31 independently — the day is never
checked against what the specific month actually allows. An impossible
date such as `2024.02.30` would still be accepted as a valid release date.

### CF-REC-002 — The with-disc-folders branch never checks for a nested, non-disc release subfolder
Sources: `AS-CODE-DEF-REC-002`. No `AS-DOC` counterpart (the docs-and-tests
view had no test combining named disc subfolders with an extra, unrelated
nested release).

The no-disc-folders branch flags `nested-release-suspected` when it built
tracks directly and a subfolder also independently qualifies as its own
release (`AS-REC-017`). The with-disc-folders branch (`AS-REC-092`) has no
equivalent check: a multi-disc release (`CD1`/`CD2`-style subfolders) that
also happens to have an unrelated nested release subfolder gets no flag at
all.

### CF-REC-003 — Grouping-folder detection is stricter than band-member-folder detection for a structurally similar shape
Sources: `AS-CODE-DEF-REC-005`. No `AS-DOC` counterpart (the docs-and-tests
view described each heuristic's own tests without comparing their rigor).

Grouping-folder detection (`AS-REC-037`) requires *every* subfolder to fail
the release/disc/category/album-wrapper checks. Band-member-folder
detection (`AS-REC-034`) only requires *at least one* subfolder to qualify
as a release folder, without excluding subfolders that look like disc,
category or album-wrapper folders mixed in alongside it. The two "pure
container of releases" heuristics apply different levels of rigor to
structurally similar shapes.

### CF-REC-004 — The no-artist-yet "Artist - Title" folder-name split only recognizes the ASCII hyphen
Sources: `AS-CODE-DEF-REC-004`. No `AS-DOC` counterpart (the docs-and-tests
view's examples for this split all happen to use a plain hyphen).

The pattern used when no artist name is known yet (`AS-REC-023`) matches
only a literal `" - "` (space, ASCII hyphen, space) — not an en-dash or
em-dash — unlike other heuristics in the same module (the leading-year
split, the artist-name-prefix strip) that explicitly treat en-dash/em-dash
as equivalent separators.

### CF-REC-005 — After a root "Artist - Album" split, the artist's one source path is the whole source root
Sources: `AS-DOC-DEF-032`. No `AS-CODE` counterpart (the code-only view
documents `Merge-ReshelfArtistBucket`'s "keyed by the release folder's own
parent path" rule — `AS-CODE-REC-095` — without separately flagging this
consequence for the root-level split case).

For `PULSAR OLYMP - 94Shine` and `Isidor - 3218 (…)` sitting directly in
the source root, the golden file gives the artist `sourcePaths` =
`["<SOURCE_ROOT>"]` — that same folder holds every other artist too, not
only this one.

### CF-REC-006 — A test's own comment disagrees with its own assertion for an invalid full date
Sources: `AS-DOC-DEF-026`. No `AS-CODE` counterpart (the code-only view
documents the actual bounds-check behavior — `AS-CODE-REC-068` — without
remarking on the test's comment wording).

The test comment for `"2006.13.01 - X"` (month 13) says the name "falls
back to the plain `yyyy - Title` form" — which would keep year 2006 — but
the test's own assertion is year `null`, title `2006.13.01 - X` (the whole
name, unparsed). The comment and the assertion do not agree; re-reading
`Split-ReshelfLeadingYear` confirms the assertion (full behavior: `AS-REC-050`)
is what the code actually does.

### CF-REC-007 — One unnumbered file drops the numeric order of every other file in the same folder
Sources: `AS-DOC-DEF-035`. Confirmed by `AS-CODE-REC-026`.

When one file in a folder has no track number, *all* files are sorted A–Z
by name and renumbered from 1 — the individually-parsed numbers of the
other files are discarded, not used as a tiebreak or a partial order.

Example (illustration): `2 - B.flac`, `10 - A.flac`, `Bonus.flac` → order `10 - A.flac`, `2 - B.flac`, `Bonus.flac`.

### CF-REC-008 — A cue track's computed duration can go negative
Sources: `AS-DOC-DEF-030`. No `AS-CODE` counterpart (the code-only view
documents the duration formula — `AS-CODE-REC-044` — without flagging the
unguarded subtraction).

A cue track's duration is "the next track's start minus its own start",
and the last track's is "the whole file's duration minus its own start"
(`AS-REC-072`). If the whole-file duration (from the audio properties
reader) is shorter than the last track's own start, this subtraction goes
negative. No guard, flag or review reason exists for this — e.g. after a
wrong duration from the tag reader or a malformed cue sheet.

### CF-REC-009 — `discFolder` holds a non-folder label for flat multi-disc cue pairs
Sources: `AS-DOC-DEF-033`. No `AS-CODE` counterpart (the code-only view
documents the sort heuristic — `AS-CODE-REC-035` — without flagging the
field-name mismatch).

Flat multi-disc cue pairs (`AS-REC-077`) have no disc *folder* at all, yet
each of their tracks' `discFolder` field holds a label built from the
audio file's own base name (containing the catalog-number hint). The field
name implies a folder; the value here is not one, and its exact shape
(beyond "contains the catalog number") is not documented anywhere.

### CF-REC-010 — Embedded-cover cache extension is chosen from declared MIME type only, not the actual bytes
Sources: `AS-CODE-DEF-REC-006`. No `AS-DOC` counterpart (the docs-and-tests
view does not exercise embedded-cover caching at all).

`Save-ReshelfEmbeddedCoverToCache`'s extension choice (`AS-REC-086`) is a
2-way switch on the picture's *declared* MIME type (`.png` for
`image/png`, `.jpg` for everything else). A picture whose actual bytes are
a different format than its declared/assumed type (e.g. a mislabeled GIF
or WEBP) would be cached with a `.jpg` extension that does not match its
real content.

### CF-REC-011 — Only one of several tag-reading call sites guards against an unreadable file
Sources: `AS-CODE-DEF-REC-007`. No `AS-DOC` counterpart (the docs-and-tests
view's mock tag reader never throws, so this path is untested either way).

Only `Get-ReshelfReleaseFolderMetadataArtist` (`AS-REC-031`) wraps its call
to `Get-ReshelfAudioTags` in a try/catch. Every other call site (cue
virtual tracks, tag-agreement, release-record track building) invokes it
unguarded, so any exception other than TagLib's own "corrupt file" case
(already handled inside `Get-ReshelfAudioTags` itself, `AS-REC-088`) — e.g.
an unsupported format — would propagate up and abort the *whole*
recognition run, instead of being recorded as a per-track review flag.

### CF-REC-012 — Recognition confidence can go stale once later review reasons are added
Sources: `AS-DOC-DEF-031`; `AS-CODE-DEF-REC-003`.

`recognitionConfidence` (`AS-REC-093`) is computed once, inside
`New-ReshelfReleaseRecord`, before it returns. Callers
(`Invoke-ReshelfFolderWalk`, and the inherited-review-reasons step) can
subsequently force `needsReview` = `true` and append review reasons
(`artist-name-split-from-folder-name`, `artist-and-album-from-tags`,
`multiple-editions-in-album-folder`, `grouping-folder-auto-resolved`)
without ever recalculating the confidence — so a release can end up
`needsReview` = `true` while `recognitionConfidence` still reads 1.0 or 0.8
instead of 0.5. This is the same gap the docs-and-tests view spotted from
the golden file's own numbers (a release needing review with a *higher*
confidence than one that does not); the code-only view explains the
mechanism.

### CF-REC-013 — It is not checked whether a zero-release "filler" artist bucket leaks into the output
Sources: `AS-DOC-DEF-034`. No `AS-CODE` counterpart (the code-only view
documents bucket merging in general — `AS-CODE-REC-066`/`067` — without
exercising this specific filler-folder scenario).

In the artist-merge test, two plain filler ("genre") folders each wrap one
differently-named artist subfolder; each inner folder is recognized as a
band-member folder of its genre folder, i.e. the genre folders are walked
as parent artists in their own right. The test does not check whether a
zero-release artist bucket for the genre folder's own name (`Genre A`/
`Genre B`) ends up in the output `artists[]`.

### CF-REC-014 — The band-member "same normalized name" test doesn't actually test that rule
Sources: `AS-DOC-DEF-027`. Kind: test quality.

The test "rejects a subfolder whose normalized name matches the parent
artist" uses `Talking Heads\1980 Remain In Light` with parent
`Talking Heads` — the names do not match. The test really checks that a
*release* folder is not a band-member folder (it is excluded earlier, by
already being classified `release`); the "same normalized name"
rule (`AS-REC-035`) itself has no real test.

### CF-REC-015 — The "sorts disc folders numerically" test doesn't prove a numeric sort
Sources: `AS-DOC-DEF-028`. Kind: test quality.

The test uses only `CD 1` and `CD 2` (`AS-REC-064`) — a plain text sort
gives the same order. A case that would distinguish numeric from lexical
sorting (e.g. `CD 2` vs `CD 10`) is missing.

### CF-REC-016 — The "all disc subfolders" release-folder test doesn't isolate the rule it names
Sources: `AS-DOC-DEF-029`. Kind: test quality.

The test uses `ZZ Top\2003 Mescalero`, which also has a `scans` folder and
a loose `Stray Bonus Track.mp3`. The loose audio file alone already makes
the folder a release (`AS-REC-013`), so this test does not actually
exercise the disc-folder rule (`AS-REC-015`) on its own; only the separate
LP#-numbered fixture (`2004 - LP Reissue`) does.

### CF-REC-017 — A companion-file test checks far less than its name promises
Sources: `AS-DOC-DEF-036`. Kind: test quality.

The test "classifies loose and nested companions, routing playlists to
ignored" uses only `ZZ Top\1999 XXX` and checks one loose `cover.jpg`. It
checks no nested companion (`AS-REC-084`) and no playlist (`AS-REC-082`) in
that same test.

### CF-REC-018 — Three documented recognition rules have no test at all
Sources: `AS-DOC-DEF-037`. Kind: test quality.

(a) Plan 05 names a companion kind `text` for `.txt`/`.pdf`/`.nfo` files
with words like `lyrics`/`article`/`interview` in the name — no test
covers it, and the actual code (`AS-REC-081`) only ever produces `lyrics`
or `other` for these extensions, never a `text` kind. (b) The README says
the metadata-confirmed category check (`AS-REC-033`) uses the cue
`PERFORMER` first, "then the audio file's artist tag", and needs "most"
releases to agree — the tests cover only the cue-`PERFORMER`, all-agree
case. (c) The README says a band-member folder holds "only release
folders, no loose files" — no test covers a band-member folder that *does*
have loose files (the code-only view confirms the rule directly from
source, `AS-CODE-REC-019`, but the legacy Pester suite still has no case
for it).

Also cross-referenced here: `CF-TXT-003` above (a mismatched bracket/paren
pair in `ConvertFrom-ReshelfTrackFileName` is still accepted as a track
number) concerns this area's `AS-REC-057`, but stays filed under TXT — see
the scope note in [02-text-and-naming.md](02-text-and-naming.md).

## DSC

### CF-DSC-001 — The third element of both retry-backoff arrays is unreachable
Sources: `AS-CODE-DEF-DSC-001`. No `AS-DOC` counterpart (the docs-and-tests
view only shows the backoff waits that actually happen, not the unused
array element).

With `$maxAttempts = 3`, the "attempt equals max attempts" check throws
before a 3rd attempt ever reaches the backoff/sleep code, so only indices
`0` and `1` of `$backoffSeconds = @(1, 2, 4)` and
`$rateLimitBackoffSeconds = @(20, 40, 60)` are ever used (`AS-DSC-013`,
`AS-DSC-015`). The `4` and `60` values are dead configuration.

### CF-DSC-002 — The low-remaining throttle signal can be silently dropped
Sources: `AS-CODE-DEF-DSC-002`. No `AS-DOC` counterpart (the docs-and-tests
view did not exercise the timestamp-window-empty edge case).

`Wait-DiscogsRateLimit` (`AS-DSC-018`) resets the low-remaining flag to
`false` unconditionally on every call, even when the throttle condition
itself was false because the tracked timestamp list was empty (the throttle
needs both "at/over ceiling" and "at least one tracked timestamp"). A 429 or
low-remaining signal received just before the timestamp window empties out
(e.g. after a long idle gap) is discarded with zero delay enforced, instead
of carrying over to the next request.

### CF-DSC-003 — A rate limit of 0 is not "no limit" — it throttles every request after the first
Sources: `AS-DOC-DEF-042`; mechanism explained by `AS-CODE-DSC-016`.

The docs-and-tests view only showed that `RateLimitPerMinute = 0` doesn't
crash, without saying what 0 means. Re-reading the code (`AS-DSC-017`)
answers that: with a ceiling of 0, every request after the very first one in
a process sleeps first (potentially up to 60 seconds), because the throttle
condition `count >= ceiling` is true as soon as one timestamp is tracked. A
user setting 0 expecting "unlimited" would get close to the opposite.

### CF-DSC-004 — Does the "no token" error name all three sources, including a custom env var name?
Sources: `AS-DOC-DEF-040`; mechanism explained by `AS-CODE-DSC-005`.

The docs-and-tests view only asserted the error message contains
`DISCOGS_ACCESS_TOKEN`, leaving open whether it also names the encrypted
settings source or a custom `discogsTokenEnvVar` name. Re-reading the code
(`AS-DSC-006`) answers that: the thrown message names the actually-resolved
variable name (so a custom name appears correctly, not the literal
`DISCOGS_ACCESS_TOKEN`), the `.env` path, and the `settings.json` path, and
suggests `Reshelf.ps1 settings set-token`. No gap was found in what the
message names — carried forward only because phase 3 does not itself decide
to close out a phase-1 suspected defect.

## MAT

### CF-MAT-001 — A candidate exactly 1 year off scores the same as one with an unknown year
Sources: `AS-CODE-DEF-MAT-001`. No `AS-DOC` counterpart (the docs-and-tests
view did not exercise a 1-year-off candidate specifically).

`Get-ReshelfDiscogsCandidateScore`'s year adjustment (`AS-MAT-012`) only
compares the raw numeric year: an exact match adds `+0.05`, a gap of more
than 1 year subtracts `-0.05`, but a gap of exactly 1 year gets no
adjustment at all — identical to an unknown year. A release that is
genuinely a different edition/remaster one year off the source's year is
scored the same as a perfect year match, even though the title-cleaning
logic elsewhere in the same module treats "1 year off" as meaningfully
different from "exact".

### CF-MAT-002 — Ambiguous-candidate assembly may re-fetch a master already fetched earlier in the same call
Sources: `AS-CODE-DEF-MAT-002`. No `AS-DOC` counterpart (the docs-and-tests
view mocks all requests, so a real duplicate fetch is invisible to it).

Building the `ambiguous` candidate list's master entries (`AS-MAT-036`)
re-fetches each of the top 5 scored masters' detail just to read
`main_release`, even when those same masters may already have been fetched
earlier in the same call (e.g. via master-version selection for a
different candidate, or via the artist-master-list path). This relies
entirely on the Discogs response cache to avoid a real duplicate network
call, with no in-memory reuse within the one matching run.

### CF-MAT-003 — The version-rank test claims a year preference but passes no folder year
Sources: `AS-DOC-DEF-046`. Kind: test quality.

The test "prefers the version whose released year matches the folder year,
then a CD/File format over Vinyl, then higher community count" calls the
sort with `-FolderYear $null`, so it cannot actually exercise rule 1 (year
match, `AS-MAT-050`) — the winner follows from format group and collection
count alone. No test checks the year rule on its own.

### CF-MAT-004 — The edition-hint "no false positive" test uses a different hint for each version
Sources: `AS-DOC-DEF-047`. Kind: test quality.

The test ranks version 1 with hint `Limited` and version 2 with hint
`Limited Edition`, so it never directly checks a near-miss hint (e.g.
`Limited`) against an otherwise-matching-looking token on the *same*
version. The underlying mechanism is now fully known from code (exact
normalized-token equality, `AS-MAT-053`) — no behavioral gap was found —
but this specific test still doesn't exercise its own named scenario.

### CF-MAT-005 — Auto-`matched` even when no probed candidate has the source track count, with no review flag
Sources: `AS-DOC-DEF-048`. No `AS-CODE` counterpart (the code-only view
documents the format-preference fallback mechanism, `AS-CODE-MAT-039`,
without flagging the lack of a review signal).

When several candidates pass the threshold and none of the probed ones has
the source track count, the app still returns `matched` by format
preference alone (`AS-MAT-041`): example, source 9 tracks, candidates with
5 and 7 tracks → `matched`, release 2. Plan 02 says unclear matches are
"never guessed", but no review flag is raised for this case.

### CF-MAT-006 — "Top 5 candidates" for `ambiguous` has no test checking the cap directly
Sources: `AS-DOC-DEF-050`. Kind: test quality.

Plan 02 says an `ambiguous` result carries the top 5 candidates. The one
Pester test for this only checks "more than 0" (2 candidates, from the
master path). The code confirms the cap of 5 independently on every
candidate-producing path (`AS-MAT-029`, `AS-MAT-036`, `AS-MAT-044`), but no
test exercises a release with more than 5 real candidates to prove the
truncation itself.

### CF-MAT-007 — Various Artists evidence: the docs/tests view left the exact minimum undefined
Sources: `AS-DOC-DEF-053`; mechanism now explained by `AS-CODE-MAT-030`.

The docs-and-tests view only showed 3 distinct artists → yes and 2 → no,
without stating the general rule. Re-reading the code (`AS-MAT-072`)
answers that: at least 3 tracks, at least 3 distinct normalized track
artists, and more than half the tracks differing from the folder artist.
No gap was found in the actual behavior — carried forward only because
phase 3 does not itself decide to close out a phase-1 suspected defect.

## PRP

### CF-PRP-001 — The 1×1 "undecodable" sentinel is indistinguishable from a genuine 1×1 embedded cover
Sources: `AS-CODE-DEF-PRP-004`. No `AS-DOC` counterpart (the docs/tests view
only shows the undecodable case, never a genuine 1×1 image).

`Get-ReshelfImageDimensions` reports `{ Width = 1; Height = 1 }` both when an
image genuinely is 1×1 and when it couldn't be decoded at all. Any embedded
cover that really is exactly 1×1 would be silently dropped as if it were
corrupt (`AS-PRP-062`).

### CF-PRP-002 — An undecodable local companion cover is not checked and still becomes the chosen cover, unlike an undecodable embedded cover
Sources: `AS-DOC-DEF-055`. No `AS-CODE` counterpart found in the excerpt for
a decodability gate on local companion covers (`AS-CODE-PRP-058` reads
dimensions the same way as the embedded check, `AS-CODE-PRP-052`/`053`, but
nothing in this function drops a local candidate the way `AS-CODE-PRP-055`
drops an embedded one).

An undecodable embedded cover is removed from the candidates (`AS-PRP-062`).
But a loose `cover.jpg` with content that isn't a real image stays a
candidate and is chosen — the golden file shows it as `width 1, height 1`,
the "could not decode" value (`AS-PRP-063`). A test comment notes such a
cover fails the ffmpeg resize at apply time.

### CF-PRP-003 — A stray track outside a release's disc folders is given a phantom extra disc number
Sources: `AS-DOC-DEF-062`. No `AS-CODE` counterpart (the code's own disc-
grouping rule, `AS-CODE-PRP-033`, mechanically explains *why* this happens —
a stray track becomes its own new `discFolder` group — but was not flagged
there as a defect).

In the golden file, `ZZ Top\2003 Mescalero` has `discFolderCount = 2`. The
stray `Stray Bonus Track.mp3` (outside the disc folders) gets disc 3, Track
1 and file number `06` — a third disc that doesn't really exist
(`AS-PRP-048`). Recognition flags the release
(`track-outside-disc-folder-suspected`), but the proposed disc number may
still be wrong.

### CF-PRP-004 — A stable-key collision in the target index silently drops one folder, with no warning
Sources: `AS-DOC-DEF-063`; confirmed by `AS-CODE-PRP-066` (same mechanism:
first folder encountered wins, later duplicates silently dropped).

`ZZ Top\1999 XXX` and `zz  top\1999 XXX` give one index entry
(`AS-PRP-077`). The docs/tests view only checks "no error" and count 1; the
code confirms the mechanism but neither source shows which folder is kept,
and no warning or review note is produced either way. The other folder is
invisible to the comparison.

### CF-PRP-005 — The track-count-mismatch review test cannot tell which alignment method actually ran
Sources: `AS-DOC-DEF-064`. Cross-referenced from `AS-MAT-059`'s own
resolution of the sibling contradiction `AS-DOC-DEF-045` (Area: MAT).

The test name says it "falls back to source titles", but title alignment
would actually succeed for the fixture used (the source titles already
equal the first two Discogs titles), so the Discogs titles are used instead,
plus a "missing on source" note (`AS-PRP-040`, `052`). The asserted titles
are the same either way, so the test cannot distinguish the two successful
paths.

### CF-PRP-006 — Title-casing an all-lowercase tag cannot restore a real name's inner capitals
Sources: `AS-DOC-DEF-067`.

The file Artist tag `johnny mcevoy` becomes `Johnny Mcevoy` (`AS-PRP-056`).
The real name is "Johnny McEvoy" — title case on an all-lowercase tag cannot
restore inner capitals, and the proposal writes the wrong name with no
review note.

### CF-PRP-007 — The fuzzy previous-lossy ledger fallback scan picks the first matching entry with no further disambiguation
Sources: `AS-CODE-DEF-PRP-001`.

The fallback scan (`AS-PRP-080`) picks the first `pending-upgrade` entry
matching artist + year + fuzzy-album-variant overlap, with no further
disambiguation. Two different pending-upgrade albums by the same artist in
the same year, whose search-title variants happen to overlap, could cause
the wrong previous-lossy folder to be reported.

### CF-PRP-008 — A compilation's manual Discogs re-pick loses the file-name-artist fallback tier that the batch path has
Sources: `AS-CODE-DEF-PRP-002`.

`Update-ReshelfReleaseForDiscogsSelection` never computes Various-Artists
evidence at all (`AS-PRP-098`), unlike the batch path
(`New-ReshelfProposedRelease`, which passes file-name-parsed artists into
track-set building). A compilation release that gets its Discogs match
manually re-picked loses the file-name-artist fallback tier (`AS-PRP-056`)
for tracks with no existing Artist tag and no Discogs per-track credit,
unlike the same release processed through the normal batch-propose path.

### CF-PRP-009 — A manual Discogs re-pick never forwards recognition's own review flag/reasons, unlike the batch path
Sources: `AS-CODE-DEF-PRP-003`. Related: `AS-PRP-010` (the batch path's own
code comment explicitly calls out fixing exactly this "previously silently
dropped" gap).

`Update-ReshelfReleaseForDiscogsSelection` never reads or forwards
`Release.needsReview`/`reviewReasons` into its own `requiresReview`/`notes`
output (`AS-PRP-098`). A release flagged for review at recognition time can
have that flag effectively disappear once the user manually re-picks its
Discogs match.

### CF-PRP-010 — The manual re-pick's review output lands in different, flatter fields than the full proposal's `humanReview`
Sources: `AS-DOC-DEF-065`. Related code evidence: `AS-CODE-PRP-096`
(confirms the flatter return shape — `requiresReview`/`notes` as plain
top-level fields, not nested under `humanReview`, and several other fields
omitted entirely, `AS-PRP-103`).

The selection-recompute tests read the review flag as `requiresReview` and
the note as `notes` on the returned release. The full proposal document
keeps them in `humanReview.required` and `humanReview.notes` instead. The
tests don't show that a conflict flag and a `target path collision` note
(`AS-PRP-104`/`105`) actually reach `humanReview` once this result is
folded back into the stored proposal.

## REV

### CF-REV-001 — Every local-file failure, including a genuinely missing file, is reported as HTTP 403
Sources: `AS-CODE-DEF-REV-003`; related: `AS-DOC-REV-017`.

`Get-ReshelfUiLocalFileBytes` throwing "File '...' no longer exists."
(`AS-REV-021`) is reported the same way as an access-control refusal
(`AS-REV-022`) — a genuinely missing allowed file is conflated with
"forbidden".

### CF-REV-002 — GET /api/current-session and GET /api/sessions/{id}/proposal expose the same proposal.json differently
Sources: `AS-CODE-DEF-REV-002`.

`CurrentSession` parses then re-serializes the proposal
(`ConvertFrom-Json`/`ConvertTo-Json -Depth 20`); `GetProposal` writes the
raw file content through unchanged (`AS-REV-011`). The same file can come
back with different formatting, and potentially different number precision
or property order, depending on which endpoint is called.

### CF-REV-003 — Save accepts any valid JSON, also a proposal that breaks the schema
Sources: `AS-DOC-DEF-072`.

The save test writes `{"artists":[]}` (no `schemaVersion`, no `sessionId`)
and it succeeds (`AS-REV-012`). A bad request body can damage
`proposal.json`, and only one backup is kept (`AS-REV-013`).

### CF-REV-004 — Manual-cover upload size limit (20 MB) is hard-coded independently in two places
Sources: `AS-CODE-DEF-REV-001`.

`Reshelf.UiServer.psm1:333` (`$script:ReshelfUiManualCoverMaxBytes = 20MB`,
`AS-REV-024`) and `Start-ReshelfUiServer.ps1:77` (`AS-REV-040`'s default
`$MaxBytes`) independently hold the same literal. Since the HTTP-layer call
site never overrides that default, the module-level check can never
actually trigger via the real upload path — the earlier, independently
maintained limit always rejects first. If either literal changes without
the other, the two checks silently diverge.

### CF-REV-005 — DeleteLossy handler reports every failure as HTTP 404, including non-"not found" errors
Sources: `AS-CODE-DEF-REV-004`.

Any exception from removing a ledger entry (`AS-REV-031`) — a file lock or
disk I/O error, not just "no such entry" — is reported to the client as 404
Not Found.

### CF-REV-006 — "Needs review only" hides an ambiguous release that also needs review
Sources: `AS-DOC-DEF-070`.

The filter works on the computed badge, not on the raw `needsReview` flag
(`AS-REV-054`). A release with `needsReview: true` but badge `ambiguous` is
hidden by "Needs review only", even though its label suggests it would show.

### CF-REV-007 — A bad session id gives "bad request"; a bad stable key gives "no route" — the same kind of input error, two different answers
Sources: `AS-DOC-DEF-078`.

A wrong session id in a route is an explicit 400 (`AS-REV-006`); a wrong
stable key on the lossy or discogs-selection route matches no route at all
and falls through to static file serving (`AS-REV-007`).

### CF-REV-008 — A wrong HTTP method on a known API path is served as a generic static-file 404, not a clear API error
Sources: `AS-DOC-DEF-079`; `AS-CODE-DEF-REV-007` (same mechanism, read
independently from the code: the routing function returns no action for an
unmatched method and falls through to static-file handling, `AS-REV-008`).

`DELETE /api/sessions/{id}/proposal`, `GET` on the manual-cover path, and
similar requests get no "method not allowed"/400 answer — the client sees a
plain 404 as if the path didn't exist.

### CF-REV-009 — Stale code comment claims the client's safe-filename sanitizer skips reserved-device-name handling, but it doesn't
Sources: `AS-CODE-DEF-REV-005`.

The comment on `deriveProposedFolderNames` (`app.js:846-847`) predates
`toSafeFileName`'s actual reserved-name suffixing step (`AS-REV-066`) and is
now misleading about current behavior — a documentation-only issue, not a
behavioral one.

### CF-REV-010 — An empty Year in one release blocks the whole apply run, with no warning shown on the review page
Sources: `AS-DOC-DEF-081`; related: `AS-DOC-DEF-082` (`CF-REV-015`, a
related seed-data inconsistency in the same review-state area).

The README documents the apply-time block (`AS-REV-070`); no source shows
the review page itself warning the user before they get there.

### CF-REV-011 — Live track numbering comes out too low when the last track of an earlier disc is missing
Sources: `AS-DOC-DEF-074`; confirmed by `AS-CODE-REV-107` (`AS-REV-075`),
which documents the same limitation directly in a code comment.

The page has no access to Discogs' own per-disc track counts, so it uses
each disc's highest *detected* Track number as that disc's size — if the
real last track of an earlier disc is absent from the source, every later
disc's file numbers are off by one, needing a manual fix.

### CF-REV-012 — Older sessions are not renumbered on load
Sources: `AS-DOC-DEF-075`.

A session saved before the live-numbering rule existed keeps its old file
names (`AS-REV-077`) until the user types a Track value again in that
release — until then, the page shows names that don't reflect the current
rule.

### CF-REV-013 — Unsaved manual cover uploads leave files on disk
Sources: `AS-DOC-DEF-071`.

The upload writes the file at once (`AS-REV-096`). Reloading without Save
removes the candidate from the gallery, but the file stays in
`manual-covers\` with nothing in any source describing later cleanup.

### CF-REV-014 — Release notes textarea has no null-safety fallback, unlike the equivalent lossy-notes field
Sources: `AS-CODE-DEF-REV-006`.

`notesField.value = release.humanReview.notes` (`AS-REV-102`) has no `?? ''`
guard, while the lossy-tracker edit path a few hundred lines later in the
same file does guard its own notes value. If `humanReview.notes` is ever
`null` (e.g. a release never reviewed), the textarea would show the literal
text "null" instead of being empty.

### CF-REV-015 — Seed test data: a release has needsReview = true but humanReview.required = false
Sources: `AS-DOC-DEF-082` (Kind: test quality).

Plan 07 says `humanReview.required` is set whenever a release is flagged
(`AS-REV-051`'s badge logic reads `needsReview`/`humanReview.required`
together). The UI test seed has `needsReview: true`,
`reviewReasons: ["no-track-number"]` and `humanReview.required: false` for
the same release — the badge follows `needsReview`, so the inconsistency
doesn't affect the observed UI behavior here, but neither source makes
clear which field a real `propose` run would actually set in this exact
combination.

## APL

### CF-APL-001 — A test name claims a "missing" log entry means no re-apply; it actually only covers an existing applied entry
Sources: `AS-DOC-DEF-089` (Kind: test quality).

One test is named "treats a missing/already-applied entry as not needing
re-apply, when every source file is already gone". The next test shows that
with no entry at all (sources gone) the release DOES need apply. The first
test covers only an existing `applied` entry; the "missing" part of the test
name is wrong.

### CF-APL-002 — All sources gone + a valid applied entry: skip is confirmed, but only because the target folder check still passes
Sources: `AS-DOC-DEF-090`.

When all source files are gone and an `applied` log entry exists, apply
skips the release even though the logged hash (now unobtainable) can't be
compared. Re-reading `Test-ReshelfAppliedEntryValid`/`Test-ReshelfReleaseNeedsApply`
(`AS-APL-006`/`016`) answers part of the open question: the target folder's
continued existence on disk *is* part of what makes the logged entry "still
valid", so the skip is conditioned on the target folder, not blind to it.
What's still not covered by any test: the outcome when the target folder was
also deleted in this same all-sources-gone scenario.

### CF-APL-003 — Old test comment claims cue-split releases "lose" their source; contradicted by the same file
Sources: `AS-DOC-DEF-087` (Kind: test quality).

A `BeforeEach` comment in the pipeline test says "Implementation mutates its
source (cue-split releases always lose their original cue+audio file,
regardless of copy/move mode)". The same test file, 100 lines later, and the
dedicated Implementation tests both assert the `.cue` and audio source files
stay — consistent with `AS-APL-021`, confirmed directly in code
(`CopyMode` only ever accepts `'copy'`). The comment is stale.

### CF-APL-004 — A retry over an old failed staging folder could pick up stale leftover files
Sources: `AS-DOC-DEF-091`.

A failed release leaves `.reshelf-staging\<stableKey>\` in place, and the
README says the next apply retries it. Re-reading `Invoke-ReshelfReleaseStaging`:
the staging folder is (re)created with `New-Item -Force`, which does not
clear any existing contents first. A file left over from the earlier failed
attempt — a companion since dropped from the proposal, or an obsolete cue
split — could still be sitting in that folder, and would be moved into the
target along with the new content when the whole folder is committed
(`AS-APL-017`/`020`). No test exercises a retry over a non-empty stale
staging folder either way.

### CF-APL-005 — The FLAC "invalid block size" retry effectively drops 50 ms of audio between two tracks
Sources: `AS-DOC-DEF-094`.

The retry moves a track's start `0.05` s later (e.g. `322.200` → `322.250`)
without moving the previous track's end to match, so that 50 ms belongs to
no track. The test (`AS-APL-030`) treats this as intended behavior, not a
bug to fix.

### CF-APL-006 — No test exercises the split-output-count check against the cue sheet
Sources: `AS-DOC-DEF-096` (Kind: test quality).

Plan 08 describes an explicit split-track-count-vs-cue-sheet check. The
actual code (`AS-APL-025`/`032`, `AS-CODE-APL-036`) checks that every
expected output file is physically present, not an integer count
comparison — the same outcome in practice, but neither phrasing of the
check has test coverage of its own.

### CF-APL-007 — Truncation can shrink a release folder name to 1 character
Sources: `AS-DOC-DEF-095`.

With a very tight path-length budget, `3218 Some Catalog Album` becomes a
1-character folder name, while `2010 Some Album` becomes 6 characters
(`2010 ` + 1), because only a real year (1900–2100) protects the prefix
(`AS-APL-054`). The test asserts this directly. A 1-character folder name is
not useful for the user to browse.

### CF-APL-008 — An edit made after apply does not reach the target on a later re-apply
Sources: `AS-DOC-DEF-086`.

When the user edits a release in the review UI after it was already applied,
and its source files didn't change, a later `apply` run skips it
(`AS-APL-011`/`065`) — the skip check is keyed on the source file-set hash,
not on the proposal's content, so the edit never reaches the target. The
README calls this a caveat, not a bug.

### CF-APL-009 — Directory creation during staging doesn't force a terminating error
Sources: `AS-CODE-DEF-APL-001`. No `AS-DOC-DEF` counterpart.

The `New-Item -ItemType Directory` calls that create the staging folder, a
companion's parent directory, and the final target's parent directory don't
pass `-ErrorAction Stop`, unlike every `Copy-Item` call in the same module
(`AS-APL-022`/`049`) and the equivalent `New-Item` calls in
`Reshelf.Settings.psm1`. If directory creation fails (permission denied,
disk full), the default non-terminating error lets execution continue as if
the folder existed, surfacing a less clear failure later (e.g. a
`Copy-Item` "path not found") instead of failing fast with a direct message.

### CF-APL-010 — A nested companion's own path is never truncated or budgeted against the 250-character limit
Sources: `AS-CODE-DEF-APL-002`. No `AS-DOC-DEF` counterpart.

The path-length truncation logic (`AS-APL-053`, `AS-CODE-APL-026`–`032`)
budgets and truncates the artist folder, release folder and track file
names, but a nested companion file's relative subfolder path and file name
are copied through verbatim — only sanitized for illegal characters, never
truncated or budgeted. A release with a deeply nested companion structure
can still produce a final path well past `MaxPathLength` (250), despite the
function's stated goal of keeping human-facing names short by construction.

### CF-APL-011 — The apply-log `status` field allows a third value, `'skipped'`, that the code never actually writes
Sources: none — found directly while merging, no original phase-1/phase-2 id.

`Add-ReshelfApplyLogEntry`'s `status` parameter (`AS-APL-058`) has a
`ValidateSet` of `applied`, `failed`, `skipped`, but every call site in
`Invoke-ReshelfImplementation` only ever passes `'applied'` or `'failed'`. A
skipped release gets no log entry at all (consistent with `AS-APL-009`: no
entry still means "needs apply" next time), so the third accepted value is
presently unreachable in practice.

## LSY

### CF-LSY-001 — Ignoring a previously-upgraded entry leaves a stale upgradedUtc behind
Sources: none — found directly while merging, no original phase-1/phase-2 id.

`Set-ReshelfLossyTrackingIgnored` (the function behind `lossy ignore`,
`AS-LSY-014`) only ever touches `status`, never `upgradedUtc` — unlike the
generic status setter (`Set-ReshelfLossyTrackingStatus`, `AS-LSY-010`), which
always clears `upgradedUtc` on any move away from `upgraded`. An entry that
was `upgraded` and is then ignored through the dedicated `lossy ignore` path
keeps its old `upgradedUtc` timestamp even though `status` no longer says
`upgraded` — a combination the generic setter's own rule would never
produce. No test exercises ignoring an already-`upgraded` entry.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-10 | Started. Area GEN: 1 item carried forward (`CF-GEN-001`). |
| 0.2 | 2026-10-10 | Area DAT: 5 items carried forward (`CF-DAT-001`–`005`); no duplicates found between the `AS-DOC-DEF-*` and `AS-CODE-DEF-*` sets for this area. |
| 0.3 | 2026-10-11 | Area TXT: 3 items carried forward (`CF-TXT-001`–`003`); no duplicates found between the `AS-DOC-DEF-*` and `AS-CODE-DEF-*` sets for this area. `CF-TXT-003` concerns a REC-owned function, cross-referenced for that area's merge. |
| 0.4 | 2026-10-11 | Area SET: 2 items carried forward (`CF-SET-001`–`002`); both `AS-CODE-DEF-*` only, no `AS-DOC-DEF-*` suspected defects exist for this area (only the 3 contradictions resolved in `90-contradictions-resolution.md`). |
| 0.5 | 2026-10-11 | Area SES: 2 items carried forward (`CF-SES-001`–`002`). `CF-SES-001` is `AS-CODE-DEF-*` only (no `AS-DOC-DEF-*` suspected defect for this area — only the one contradiction resolved in `90-contradictions-resolution.md`). `CF-SES-002` is a new suspected defect found directly while merging, with no original phase-1/phase-2 source id. |
| 0.6 | 2026-10-11 | Area REC: 18 items carried forward (`CF-REC-001`–`018`), covering all 7 `AS-CODE-DEF-REC-*` entries and all 12 REC-area `AS-DOC-DEF-*` suspected defects (`AS-DOC-DEF-026`–`037`). `CF-REC-012` merges `AS-DOC-DEF-031` and `AS-CODE-DEF-REC-003` — the docs-and-tests view spotted the same recognition-confidence inconsistency from the golden file's numbers that the code-only view explains by mechanism. `CF-TXT-003` (filed under TXT) is cross-referenced as concerning this area's `AS-REC-057`. |
| 0.7 | 2026-10-11 | Area DSC: 4 items carried forward (`CF-DSC-001`–`004`). Two are `AS-CODE-DEF-DSC-*` only (`001`, `002`). Two are phase-1 `AS-DOC-DEF-*` items (`040`, `042`) whose mechanism is now fully explained by the code — `CF-DSC-003` (rate limit 0) looks like a real surprising-behavior candidate, `CF-DSC-004` (error message naming) found no actual gap — but both stay undecided here per the phase 3/phase 4 split. |
| 0.8 | 2026-10-13 | Area MAT: 7 items carried forward (`CF-MAT-001`–`007`). Two are `AS-CODE-DEF-MAT-*` only (`001`, `002`). Five are phase-1 `AS-DOC-DEF-*` items (`046`–`048`, `050`, `053`) — three Kind: test quality (`046`, `047`, `050`), one a genuine behavior gap with no review flag (`048`), and one (`053`) whose mechanism is now fully explained by the code with no gap found, same pattern as `CF-DSC-004`. |
| 0.9 | 2026-10-13 | Area PRP: 10 items carried forward (`CF-PRP-001`–`010`). Four are `AS-CODE-DEF-PRP-*` only (`001`, confirmed by code only; `002`, `003`, `004`); the other six are phase-1 `AS-DOC-DEF-*` items (`055`, `062`–`065`, `067`). `CF-PRP-004` is confirmed, not contradicted, by its matching code read (`AS-CODE-PRP-066`); `CF-PRP-010` cross-references `AS-CODE-PRP-096` as reinforcing code-side detail for the same shape-mismatch issue. |
| 0.10 | 2026-10-13 | Area REV: 15 items carried forward (`CF-REV-001`–`015`), covering all 7 `AS-CODE-DEF-REV-*` entries (one of them, `007`, merged into `CF-REV-008` alongside the matching `AS-DOC-DEF-079` as the same fact from two sources) and all 9 REV-area `AS-DOC-DEF-*` suspected defects (`070`–`072`, `074`, `075`, `078`, `079`, `081`, `082`). `CF-REV-011` is confirmed, not contradicted, by its matching code comment (`AS-CODE-REV-107`). |
| 0.11 | 2026-10-13 | Area APL: 11 items carried forward (`CF-APL-001`–`011`), covering both `AS-CODE-DEF-APL-*` entries and all 8 APL-area `AS-DOC-DEF-*` suspected defects (`086`, `087`, `089`–`091`, `094`–`096`). `CF-APL-002` is partly answered, not contradicted, by re-reading `AS-APL-006`/`016` (the target-folder check does apply in that scenario). `CF-APL-011` is a new suspected defect found directly while merging, with no original source id — the apply-log `status` field accepts a `'skipped'` value the code never writes. |
| 0.12 | 2026-10-13 | Area LSY: 1 item carried forward (`CF-LSY-001`), a new finding with no original phase-1/phase-2 id — the dedicated ignore mutator leaves a stale `upgradedUtc` on an entry ignored after being upgraded, unlike the generic status setter. Neither LSY source file carried any pre-existing suspected defect. |
