# 91 — Suspected defects, carried forward (Phase 3)

Status: Draft | Version: 0.5 | Last updated: 2026-10-11

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

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-10 | Started. Area GEN: 1 item carried forward (`CF-GEN-001`). |
| 0.2 | 2026-10-10 | Area DAT: 5 items carried forward (`CF-DAT-001`–`005`); no duplicates found between the `AS-DOC-DEF-*` and `AS-CODE-DEF-*` sets for this area. |
| 0.3 | 2026-10-11 | Area TXT: 3 items carried forward (`CF-TXT-001`–`003`); no duplicates found between the `AS-DOC-DEF-*` and `AS-CODE-DEF-*` sets for this area. `CF-TXT-003` concerns a REC-owned function, cross-referenced for that area's merge. |
| 0.4 | 2026-10-11 | Area SET: 2 items carried forward (`CF-SET-001`–`002`); both `AS-CODE-DEF-*` only, no `AS-DOC-DEF-*` suspected defects exist for this area (only the 3 contradictions resolved in `90-contradictions-resolution.md`). |
| 0.5 | 2026-10-11 | Area SES: 2 items carried forward (`CF-SES-001`–`002`). `CF-SES-001` is `AS-CODE-DEF-*` only (no `AS-DOC-DEF-*` suspected defect for this area — only the one contradiction resolved in `90-contradictions-resolution.md`). `CF-SES-002` is a new suspected defect found directly while merging, with no original phase-1/phase-2 source id. |
| 0.6 | 2026-10-11 | Area REC: 18 items carried forward (`CF-REC-001`–`018`), covering all 7 `AS-CODE-DEF-REC-*` entries and all 12 REC-area `AS-DOC-DEF-*` suspected defects (`AS-DOC-DEF-026`–`037`). `CF-REC-012` merges `AS-DOC-DEF-031` and `AS-CODE-DEF-REC-003` — the docs-and-tests view spotted the same recognition-confidence inconsistency from the golden file's numbers that the code-only view explains by mechanism. `CF-TXT-003` (filed under TXT) is cross-referenced as concerning this area's `AS-REC-057`. |
