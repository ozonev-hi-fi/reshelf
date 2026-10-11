# 05 — Recognition (merged)

Status: Draft | Version: 0.1 | Last updated: 2026-10-11

## Scope

This file reconciles [`as-is-from-docs/05-recognition.md`](../as-is-from-docs/05-recognition.md)
(93 `AS-DOC-REC-*` requirements, from the Pester tests, the golden fixture
file and the plan/README text) and
[`as-is-from-code/05-recognition.md`](../as-is-from-code/05-recognition.md)
(110 `AS-CODE-REC-*` requirements, from `legacy/scripts/common/Reshelf.Recognition.psm1`
read cold) into one behavior record for the `recognize` pipeline step.

It also absorbs the two items the text-and-naming merge deferred here
(`AS-CODE-TXT-014`/`015`, `ConvertFrom-ReshelfTrackFileName` — see the scope
note in [02-text-and-naming.md](02-text-and-naming.md)), alongside the
matching `AS-DOC-REC-055`–`059` track-filename rules, in the "Track file
names and track order" section.

**Numbering note.** For every other area merged so far, most `AS-DOC-*`
items carried straight across and kept their number, with `AS-CODE-*`
contributing only a handful of code-only additions appended at the end. REC
is different: `Reshelf.Recognition.psm1` is read here at function-level
granularity, so almost every `AS-DOC-REC-*` behavior rule has a matching,
more precise `AS-CODE-REC-*` counterpart, and the code side also names
whole subsystems (metadata-confirmed artist voting, embedded-cover caching,
the folder-kind resolution engine, release-record construction order) the
docs/tests view never addressed directly. Preserving old numbers here would
scatter closely related facts across the file. Instead this file is
organized by topic, mirroring the docs area file's own section order with
the code-level subsystems folded into the section they belong to; every
`AS-REC-NNN` cites every `AS-DOC-REC-*`/`AS-CODE-REC-*`/`AS-CODE-TXT-*` id it
reconciles, and [92-coverage.md](92-coverage.md) maps every source id to its
`AS-REC-NNN`.

The exact JSON shape of `recognition.json` (required fields, nullability,
enums) is DAT-owned — see `AS-DAT-035`–`047` in
[01-data-and-storage.md](01-data-and-storage.md). This file describes the
*behavior* that computes those field values, not the schema shape itself.

## Pipeline and output

### AS-REC-001 — Recognize is the first pipeline step
Status: Draft | Source: AS-DOC-REC-001

Recognize scans one source folder. It groups the files into artists,
releases and tracks, and writes the result to `recognition.json`. The next
step (propose) reads this file.

Example: `source folder → [recognize] → recognition.json → [propose] → proposal.json → [ui start] → [apply]`.

### AS-REC-002 — Recognize writes recognition.json into the session folder and reads it back
Status: Draft | Source: AS-DOC-REC-002; AS-CODE-REC-110

Each recognize run writes its result to `<data home>/sessions/<session id>/recognition.json`
through the schema-validating JSON writer (schema `recognition`). It then
re-reads that same file from disk and returns the parsed result — the value
callers receive has round-tripped through JSON serialization and schema
validation, not the in-memory document built during the walk.

Example: session ID `session-1` → file `<data home>\sessions\session-1\recognition.json`, result has `sessionId` = `session-1`.

### AS-REC-003 — recognition.json is schema-valid before it is returned
Status: Draft | Source: AS-DOC-REC-003; AS-CODE-REC-110

The written file is valid against `legacy/schemas/recognition.schema.json`
— the writer validates it as part of writing, not as a separate step
recognize runs afterward.

Example: recognize over `legacy/tests/fixtures/sample-source-tree` → `Test-Json -SchemaFile recognition.schema.json` returns `true`.

### AS-REC-004 — Top-level document: fixed schema version, timestamp, artists built from the bucket map
Status: Draft | Source: AS-DOC-REC-004; AS-CODE-REC-106; AS-CODE-REC-107

The document always reports `schemaVersion` 1, and `generatedAtUtc` is the
current UTC time formatted `yyyy-MM-ddTHH:mm:ss.fffZ`. The `artists` array
is built from the artist-bucket map's values (recognized name, de-duplicated
source paths, full release list); `unrecognized` is the flat list of
unrecognized-folder entries collected during the walk.

Example (golden file, shortened):

```json
{
  "schemaVersion": 1,
  "sessionId": "<SESSION_ID>",
  "sourceRoot": "<SOURCE_ROOT>",
  "generatedAtUtc": "<GENERATED_AT>",
  "artists": [ { "recognizedName": "Cranberries", "sourcePaths": [ "<SOURCE_ROOT>\\Cranberries" ], "releases": [ ... ] } ],
  "unrecognized": [ ... ]
}
```

### AS-REC-005 — A release record is built per release by `New-ReshelfReleaseRecord`
Status: Draft | Source: AS-DOC-REC-005

Each release record (stable key, title, year, release date, release type,
edition folder name, source folder path, disc count, tracks, companion
files, ignored files, cue sheets, confidence, flags, review state) is built
by one function, `New-ReshelfReleaseRecord`. "Release record construction"
below describes its order of operations; the exact field list and
nullability are `AS-DAT-035`–`039`.

Example (golden file, `Cranberries\1993 - Everybody Else Is Doing It`): `stableKey` `fc6337eecc96a4aa`, title `Everybody Else Is Doing It`, year 1993, `recognitionConfidence` 1.0, `recognitionFlags` empty, `needsReview` false.

### AS-REC-006 — A track record carries the source file, its position, its existing tags and its audio properties
Status: Draft | Source: AS-DOC-REC-006

Each track records: the source file path, the disc folder (or `null`), the
original file name, the track number inside its disc, whether the order was
inferred, the existing tags (artist, album, title), the existing cover
path, the format, whether it is lossless, the duration in seconds, the cue
timestamp and whether it is a cue virtual track. The exact field list is
`AS-DAT-040`–`044`.

Example (golden file, `01 - I Still Do.flac`): `discFolder` `null`, `detectedTrackNumberInDisc` 1, `inferredTrackOrder` `false`, `format` `flac`, `isLossless` `true`, `durationSeconds` 200, `isCueVirtualTrack` `false`.

### AS-REC-007 — Every release gets a 16-hex-character stable key; a disambiguator keeps multi-edition releases distinct
Status: Draft | Source: AS-DOC-REC-007; AS-CODE-REC-092

Each release gets a `stableKey` derived from artist, album and year (key
rules: `AS-DAT-063`–`066`). When a release is one of several editions of the
same album-wrapper folder (`AS-REC-043`), the album portion of the key is
`"<title> [<edition folder name>]"` instead of just the title, so same-year
editions do not collide on one key.

Example: `Cranberries\1993 - Everybody Else Is Doing It` → `fc6337eecc96a4aa`. The editions `1988 Germany Label 1` and `1992 Australia Label 2` of `1980 - Multi Edition Album` → two different keys.

### AS-REC-008 — Artists and releases appear in folder-walk order
Status: Draft | Source: AS-DOC-REC-008

In the golden file, artists appear in the A–Z order of their folder names
(case-insensitive); an artist found via a band-member or grouping folder
appears right after the folder that holds it, and releases inside an artist
follow the A–Z order of their own folder names. The artist map is keyed by
a case/whitespace-normalized form of the name (`AS-REC-066`); its iteration
order follows the order folders were visited, which in turn follows
whatever order the OS folder listing returns (observed as A–Z on the test
fixtures).

Example (golden file): `Cranberries`, `Dance With Ghosts`, `Godspeed You! Black Emperor`, `Silver Mountain Zion`, `Isidor`, `Live Wire`, `Pink Floyd`, `PULSAR OLYMP`, `Talking Heads`, `David Byrne`, `Unnumbered`, `Wrapper Band`, `ZZ Top`.

### AS-REC-009 — An unrecognized entry names the folder, a reason code and its direct children
Status: Draft | Source: AS-DOC-REC-009; AS-CODE-REC-064

Every unrecognized-folder entry records the folder's path, a reason code
and the names of the files/folders directly inside it (for human triage),
defaulting to an empty list when none are given. The reason codes seen are
`release-without-artist-suspected` and `no-audio-files`.

Example (golden file): `{ "path": "<SOURCE_ROOT>\\1999 Loose Album", "reason": "release-without-artist-suspected", "children": [ "01 - Track.flac" ] }`.

### AS-REC-010 — There is no override file; the user fixes an unrecognized folder on disk and reruns recognize
Status: Draft | Source: AS-DOC-REC-010 (`90` resolves AS-DOC-DEF-019)

When `unrecognized[]` is not empty, the user moves or renames the folder on
disk so it matches a known pattern, then runs recognize again. See
`90-contradictions-resolution.md` for why several plan documents still
describing an `overrides.json` design are stale.

Example: `<SOURCE_ROOT>\1999 Loose Album` is unrecognized. The user moves it to `<SOURCE_ROOT>\Some Artist\1999 Loose Album` and reruns recognize.

### AS-REC-011 — Recognition requires an existing source-root directory
Status: Draft | Source: AS-CODE-REC-108

If the given source root path does not exist or is not a directory,
recognition throws immediately rather than starting the walk.

### AS-REC-012 — The walk starts at the canonical source root, context Root, no artist name
Status: Draft | Source: AS-CODE-REC-109

The source root is resolved to its canonical absolute path, the TagLib
context is initialized (data home, and an optional explicit TagLibSharp
path — see `AS-SET-043`), and the folder walk begins at that root with
context `Root` and no artist name yet known.

## Release folders

### AS-REC-013 — A folder with audio files directly inside is a release folder
Status: Draft | Source: AS-DOC-REC-011; AS-CODE-REC-005

A folder that directly holds at least one audio file (not counting audio in
subfolders) is a release folder. The files do not need track numbers.

Example: `ZZ Top\1999 XXX` (`01 - Poke Chop Sandwich.flac`, `02 Crucifixx A Flatt.flac`) → release. `Unnumbered\2015 No Numbers` (`Alpha Song.flac`, `Beta Song.flac`) → release `No Numbers`.

### AS-REC-014 — No direct audio and no subfolders at all means not a release
Status: Draft | Source: AS-DOC-REC-014; AS-CODE-REC-006

A folder with no direct audio files and no subfolders at all is not a
release folder, even when it holds other (non-audio) files.

Example: `Empty Artist\2010 Nothing Here` (only `readme.txt`) → not a release.

### AS-REC-015 — A folder whose children are disc folders is a multi-disc release
Status: Draft | Source: AS-DOC-REC-012; AS-CODE-REC-007

A folder with no direct audio but with subfolders is still a release folder
if at least one of its disc-named subfolders (`AS-REC-018`) directly
contains at least one audio file. A folder with subfolders but no
disc-named ones at all is not a release folder by this rule.

Example: `Wrapper Band\2004 - LP Reissue` (children `LP#1`, `LP#2`) → release. `ZZ Top\2003 Mescalero` (children `CD 1`, `CD 2`) → release.

### AS-REC-016 — A folder whose children are themselves release folders is not a release (it is an artist or a grouping)
Status: Draft | Source: AS-DOC-REC-013 (`90` resolves AS-DOC-DEF-018)

`AS-REC-013`/`014`/`015` are the complete set of ways a folder qualifies as
a release. A folder with no direct audio, whose children are release
folders themselves (not disc-named subfolders), fails all three and so is
never a release — it is handled as an artist folder (`AS-REC-022`) or a
grouping folder (`AS-REC-035`) instead. Plan 05's narrower release
definition ("`yyyy Name`/`Name` directly containing sequentially-numbered
audio") is stale: it misses the disc-subfolder-only and the
unnumbered-files cases that tests and code both support — see
`90-contradictions-resolution.md`.

Example: `ZZ Top` (children `1999 XXX`, `2003 Mescalero`, `EPs`, …) → not a release.

### AS-REC-017 — Loose audio next to a subfolder with its own audio is kept as a release, flagged nested-release-suspected
Status: Draft | Source: AS-DOC-REC-015; AS-CODE-REC-086

When a folder has no disc-named subfolders, holds audio files directly, and
also has at least one subfolder that independently qualifies as its own
release folder, recognize keeps the outer folder as a release (its own
audio becomes its tracks) but sets `needsReview` and adds the review reason
`nested-release-suspected`. The folder does not go to `unrecognized[]`. This
check only runs when the release has no disc-named subfolders — see the
carried-forward gap in `91-suspected-defects-carryforward.md` (`CF-REC-002`)
for the with-disc-folders case.

Example: `Some Artist\Messy Junk\Bonus Track.flac` plus `Some Artist\Messy Junk\Weird Sub\01 - Track.flac` → release with source folder `…\Messy Junk`, `needsReview` = `true`, `reviewReasons` contains `nested-release-suspected`.

## Artist folders and the source root

### AS-REC-018 — Artist folders are found by elimination, not matched by their own shape
Status: Draft | Source: AS-DOC-REC-016; AS-CODE-REC-059–063

A folder is resolved to one of a fixed set of kinds, checked in order:
category (inside an artist-like context, `AS-REC-024`) → release
(`AS-REC-013`–`015`) → album-wrapper (`AS-REC-040`) → band-member (inside an
artist-like context with a known artist name, `AS-REC-031`) → grouping
(`AS-REC-035`). If none of these match and the folder has no audio anywhere
below it, it is `unrecognized` with reason `no-audio-files` (`AS-REC-073`).
Otherwise — no specific shape matched, but audio exists somewhere below —
it is a transparent `pass-through` layer: direct non-audio files sitting in
it (discography notes, cover art, playlists, …) are implicitly ignored
rather than blocking recognition, since a folder with its own direct audio
would already have matched `release` earlier. There is no dedicated
"artist folder" check: a top-level folder becomes an artist because it
falls through every other shape to `pass-through` at the walk's `Root`
context, and a `pass-through` folder found at `Root` has its own leaf name
proposed as the new artist name for everything found inside it (at any
other, non-Root context, a pass-through folder carries forward whatever
artist name was already in effect instead).

Example: `<SOURCE_ROOT>\ZZ Top\1999 XXX` → `ZZ Top` matches no specific shape at Root, has audio below, becomes `pass-through` with `NewArtistName` = `ZZ Top` → artist `ZZ Top` (`sourcePaths` contains `<SOURCE_ROOT>\ZZ Top`) with release `XXX`, year 1999, 2 tracks, 1 companion file.

### AS-REC-019 — An artist folder with no audio anywhere below it is unrecognized
Status: Draft | Source: AS-DOC-REC-017

A top-level folder with no audio file anywhere below it goes to
`unrecognized[]` with reason `no-audio-files`. The walk does not descend
further once a folder is classified unrecognized, so the entry names the
outermost folder that already has zero audio below it — not necessarily
the innermost empty release-shaped folder. This resolves a scenario plan
05 reads as a contradiction; see `90-contradictions-resolution.md`
(`AS-DOC-DEF-025`).

Example: `Empty Artist\2010 Nothing Here\readme.txt` → unrecognized entry `path` = `<SOURCE_ROOT>\Empty Artist`, `reason` = `no-audio-files`, `children` = `["2010 Nothing Here"]`.

### AS-REC-020 — A loose non-audio file in an artist folder does not block recognition
Status: Draft | Source: AS-DOC-REC-018

A non-audio file sitting directly in an artist folder, next to release
subfolders, has no effect — it is ignored as described in `AS-REC-018`'s
`pass-through` case. The artist and its releases are recognized as usual.

Example: `Some Artist\Discography.txt` plus `Some Artist\2010 Some Album\01 - Track.flac` → artist `Some Artist` with one release `Some Album`; `Some Artist` is not in `unrecognized[]`.

### AS-REC-021 — Two artist folders with the same (normalized) name merge into one artist
Status: Draft | Source: AS-DOC-REC-019; AS-CODE-REC-066

When recognize finds two artist folders with the same normalized name under
different parents, it makes one artist, holding the releases and source
paths of both.

Example: `Genre A\Shared Artist\1999 Album One\01 - Track.flac` and `Genre B\Shared Artist\2001 Album Two\01 - Track.flac` → one artist `Shared Artist` with 2 releases and 2 `sourcePaths`.

### AS-REC-022 — Reserved device names are recorded as artist names unchanged
Status: Draft | Source: AS-DOC-REC-020

Recognize records a Windows reserved device name (such as `CON`) as the
artist name without any change — `pass-through`/`Root` just takes the raw
leaf name (`AS-REC-018`). Any cleanup of such names happens later, when
names are turned into safe filenames (`02-text-and-naming.md`).

Example: `CON\2005 Weird\01 - Track.mp3` → artist `CON`.

### AS-REC-023 — A release folder directly in the source root is unrecognized unless it can be split or its tags agree
Status: Draft | Source: AS-DOC-REC-021; AS-CODE-REC-096; AS-CODE-REC-098

When a release folder is found at `Root` (no artist name known yet), recognize
first tries a flat `"Artist - Title"` split on the folder's own name: the
*first* literal `" - "` (space, ASCII hyphen, space — not an en-dash or
em-dash, unlike other heuristics in this module) separates a non-empty
artist half from a non-empty title half. If that does not apply, it falls
back to the tag-agreement check (`AS-REC-025`). If neither works, the
folder is **not** turned into a release — it is recorded as unrecognized
with reason `release-without-artist-suspected`, listing its direct
children. The en-dash/em-dash gap is a carried-forward suspected defect —
see `CF-REC-004`.

Example: `<SOURCE_ROOT>\1999 Loose Album\01 - Track.flac` (no `" - "` in the name, tags disagree or are missing) → unrecognized, `reason` = `release-without-artist-suspected`. No artist named `1999 Loose Album`.

### AS-REC-024 — A root release folder named "Artist - Album" is split and flagged for review
Status: Draft | Source: AS-DOC-REC-022 (carries AS-DOC-DEF-032)

When the name-split applies (`AS-REC-023`), the release is built from the
guessed artist/title and always forced to need review with reason
`artist-name-split-from-folder-name` — a guessed split is never silently
trusted. The resulting artist's `sourcePaths` is the release folder's own
*parent* path, which for a release sitting directly in the source root is
the source root itself — so this artist's one recorded source path is a
folder that also holds every other artist. This is carried forward as a
suspected defect (`CF-REC-005`).

Example: `<SOURCE_ROOT>\PULSAR OLYMP - 94Shine` (2 tracks) → artist `PULSAR OLYMP`, release `94Shine`, `sourcePaths` = `["<SOURCE_ROOT>"]`. No artist named `PULSAR OLYMP - 94Shine`.

Example: `<SOURCE_ROOT>\Isidor - 3218 (Soldier of Fortune Edition - Artwork)` → artist `Isidor`, release `3218 (Soldier of Fortune Edition - Artwork)`.

### AS-REC-025 — A root release folder is promoted when every track agrees on artist and album tags
Status: Draft | Source: AS-DOC-REC-023; AS-CODE-REC-057; AS-CODE-REC-058; AS-CODE-REC-097

When the name-split (`AS-REC-023`) does not apply, recognize reads every
direct audio file's Artist/Album tags (a folder with zero direct audio
files yields no guess at all). If any file is missing either tag, or any
file's normalized Artist or Album differs from the first file's, the whole
result is discarded — even one outlier track blocks the promotion, nothing
ambiguous is auto-guessed. Only when every track agrees is a release built
from the common Artist/Album pair, flagged `needsReview` with reason
`artist-and-album-from-tags`. The folder does not go to `unrecognized[]`.

Example: `<SOURCE_ROOT>\edbl\01 Track One.flac` and `02 Track Two.flac`, both tagged artist `edbl`, album `minibeats, vol.1` → artist `edbl`, release `minibeats, vol.1`, 2 tracks, `reviewReasons` contains `artist-and-album-from-tags`.

### AS-REC-026 — A root release folder stays unrecognized when track tags disagree or are missing
Status: Draft | Source: AS-DOC-REC-024; AS-CODE-REC-097

When the tracks of a root release folder disagree on artist or album (or
either tag is missing on any track), the folder stays in `unrecognized[]`
with reason `release-without-artist-suspected`.

Example: `<SOURCE_ROOT>\Mixed\01 Track One.flac` (artist `Artist A`) and `02 Track Two.flac` (artist `Artist B`), album `Some Album` for both → unrecognized. No artist named `Artist A`.

## Category subfolders

### AS-REC-027 — The category list is a fixed set of names, matched case-insensitively
Status: Draft | Source: AS-DOC-REC-025; AS-CODE-REC-008 (`90` resolves AS-DOC-DEF-020)

A subfolder of an artist-like folder is a category subfolder when its name
case-insensitively equals one of a fixed list: `EPs`, `Singles`, `Lives`,
`Live`, `Compilations`, `Bootlegs`. The list is literal, hard-coded in
`Reshelf.Recognition.psm1`, not read from settings — no settings key for it
exists in the merged settings area (`03-settings-and-secrets.md`) or its
schema. Plan 05's "configurable" wording and a test name's "configured
category names" phrase describe how the list reads in prose, not an actual
feature; see `90-contradictions-resolution.md`.

Example: `EPs`, `eps`, `Singles`, `Lives`, `lives` → category. `1999 XXX` → not a category.

### AS-REC-028 — Category classification only applies inside an artist-like context
Status: Draft | Source: AS-CODE-REC-059

The category-name check is only tried while the walk is inside something
artist-like (context `ArtistBody`, `CategoryBody` or `BandMemberBody`); it
runs before every other shape check, so a category-named folder is never
mistaken for anything else once inside that context. A folder with a
category name found elsewhere (e.g. directly at the source root) is judged
by the other shape rules instead.

### AS-REC-029 — Releases in a category subfolder belong to the parent artist, with no review reason
Status: Draft | Source: AS-DOC-REC-026; AS-CODE-REC-101

Recognize adds the releases inside a category subfolder to the parent
artist (the walk recurses with context `CategoryBody`, carrying the parent
artist name forward). The category subfolder does not become an artist,
and these releases get no review reason for this.

Example: `ZZ Top\EPs\1994 One Foot In The Blues`, `ZZ Top\Lives\2005 Live From Texas`, `ZZ Top\Singles\1996 Pincushion` → all three are releases of `ZZ Top` (5 ZZ Top releases total). `Live From Texas` has `needsReview` = `false`; same for `Pincushion`.

### AS-REC-030 — The parent artist's source paths include every category folder it used
Status: Draft | Source: AS-DOC-REC-027

The artist's `sourcePaths` list holds the artist folder itself plus every
category subfolder it used (de-duplicated, `AS-REC-067`).

Example (golden file): `ZZ Top` → `sourcePaths` = `<SOURCE_ROOT>\ZZ Top`, `<SOURCE_ROOT>\ZZ Top\EPs`, `<SOURCE_ROOT>\ZZ Top\Lives`, `<SOURCE_ROOT>\ZZ Top\Singles`.

### AS-REC-031 — Release-folder metadata artist: cue PERFORMER first, else the audio file's Artist tag
Status: Draft | Source: AS-CODE-REC-022; AS-CODE-REC-023

To decide what a release folder's own metadata says about its artist, the
first audio file found anywhere below the folder is used. If one or more
`.cue` files sit alongside it and one resolves to it (`AS-REC-050`), and
that cue's header (lines before the first `TRACK`) has a `PERFORMER`, that
value is returned — checked and returned before ever reading audio tags,
because per-track tags on this kind of rip are often empty while a cue's
`PERFORMER` is release-level. Otherwise the first audio file's own Artist
tag is used. If the file cannot be read for tags, no audio file exists
under the folder, or neither signal is present, the result is `null` —
treated the same as "this folder has nothing to say about its artist", not
as a recognition failure.

### AS-REC-032 — Metadata confirms an artist only when strictly more than half the folders with metadata agree
Status: Draft | Source: AS-CODE-REC-024

Given a set of release-folder paths and a target artist name, each
folder's metadata artist (`AS-REC-031`) is compared, case/whitespace
normalized, against the target. If none of the folders produced a metadata
artist at all, the result is "not confirmed". Otherwise it is "confirmed"
only when strictly more than half (> 0.5, not ≥ 0.5) of the folders that
*did* produce a metadata artist match the target.

Example: 1 match out of 2 folders with metadata → 0.5, not strictly greater than 0.5 → not confirmed.

### AS-REC-033 — A subfolder whose releases' metadata confirms the grouping or band-member folder's own artist is folded in as a category instead
Status: Draft | Source: AS-DOC-REC-028; AS-CODE-REC-016; AS-CODE-REC-021

A subfolder name that is not in the fixed category list can still end up
behaving like a category folder (its releases attributed to the parent
artist, no review reason for this) through two independent exceptions,
both driven by `AS-REC-031`/`032`:

- **Grouping exception** (`AS-CODE-REC-016`): a folder that structurally
  qualifies as a grouping folder (`AS-REC-035`/`036`) is *not* treated as
  one if the releases two levels down confirm that the grouping folder's
  own leaf name is the real artist.
- **Band-member exception** (`AS-CODE-REC-021`): a subfolder that
  structurally qualifies as a band-member folder (`AS-REC-038`) is *not*
  treated as one if its releases confirm the *parent* artist name instead
  of naming a distinct performer.

With both exceptions blocking their structural shape, such a subfolder
falls through to `pass-through` (`AS-REC-018`) and its releases end up
attributed to the parent artist exactly as a true category folder's would
— there is no third, literal "category" classification for this case.
Without any such metadata (cue `PERFORMER` or artist tag), the ordinary
folder-shape rules decide instead.

Example: `Iron Maiden\Studio Albums\1980 - Iron Maiden\Iron Maiden.flac` + `Iron Maiden.cue` (`PERFORMER "Iron Maiden"`) and `Iron Maiden\Compilation Albums\1996 - Best Of The Beast\...` (same `PERFORMER`) → one artist `Iron Maiden` with 2 releases. No artist `Studio Albums` or `Compilation Albums`; `Iron Maiden` is not treated as a grouping folder, and `Studio Albums` is not treated as a band-member folder.

## Band-member folders

### AS-REC-034 — A differently-named subfolder holding release folders, with no loose files, becomes its own artist
Status: Draft | Source: AS-DOC-REC-029; AS-CODE-REC-017–020

A subfolder of an artist-like folder is a band-member folder when: its
(normalized) name differs from the parent artist's; it is not a category
name; it has no direct files at all (audio or not — a genuine band-member
wrapper is expected to be a pure container, so any loose file is treated as
messiness for human review rather than auto-classified); and at least one
of its immediate subfolders qualifies as a release folder. A band-member
folder becomes its own artist, named after the folder, walked with context
`BandMemberBody`; its releases are not added to the parent artist, and get
no review reason for this.

Example: `Talking Heads\David Byrne\1994 David Byrne\01 - Angels.flac` → artist `David Byrne` (`sourcePaths` = `<SOURCE_ROOT>\Talking Heads\David Byrne`) with 1 release, `needsReview` = `false`. `Talking Heads` keeps 1 release (`Remain In Light`).

### AS-REC-035 — A subfolder with the parent artist's own (normalized) name is not a band-member folder
Status: Draft | Source: AS-DOC-REC-030; AS-CODE-REC-017

A subfolder whose normalized name equals the parent artist's normalized
name is never a band-member folder. (A plain release folder inside an
artist is not considered either, since it is already classified `release`
before the band-member check ever runs — `AS-REC-018`.)

Example: `Talking Heads\1980 Remain In Light` with parent artist `Talking Heads` → not a band-member folder (it is a release folder).

### AS-REC-036 — A category-named subfolder is never a band-member folder
Status: Draft | Source: AS-DOC-REC-031; AS-CODE-REC-018

A subfolder with a category name is never a band-member folder, even when
it holds release folders.

Example: `ZZ Top\EPs` with parent artist `ZZ Top` → not a band-member folder.

## Grouping folders

### AS-REC-037 — A folder with no loose files, at least two subfolders, none of them release/disc/category/album-wrapper shaped, is a grouping folder
Status: Draft | Source: AS-DOC-REC-032; AS-DOC-REC-033; AS-CODE-REC-013–015

A folder is a grouping folder when: it has no direct files of any kind; it
has at least two immediate subfolders; and none of those subfolders is
itself a release folder, a disc folder (by name), a category subfolder (by
name) or an album-wrapper folder. (The grouping exception, `AS-REC-033`,
can still veto an otherwise-qualifying folder.)

Example: `Godspeeds and their projects` (children `Godspeed You! Black Emperor`, `Silver Mountain Zion`) → grouping folder. `Empty Artist` (one subfolder) → not a grouping folder (fewer than two subfolders).

### AS-REC-038 — An artist folder, a multi-disc release, or an album-wrapper-children folder is not a grouping folder
Status: Draft | Source: AS-DOC-REC-034; AS-DOC-REC-035

These are consequences of `AS-REC-037`'s subfolder-shape check: a folder
whose children are releases is an artist folder, not a grouping folder; a
folder whose children are disc folders is a release, not a grouping
folder; and a folder whose children are album-wrapper folders is an artist
folder recognize walks into, not a grouping folder.

Example: `ZZ Top` → not a grouping folder. `ZZ Top\2003 Mescalero` (`CD 1`, `CD 2`) → not a grouping folder. `Wrapper Band` (children `1975 - Wrapped Album (Special Edition)`, `1990 - Loose Files Album`, …) → not a grouping folder.

### AS-REC-039 — Walking a grouping folder treats every subfolder as its own artist, forced into review
Status: Draft | Source: AS-DOC-REC-036; AS-CODE-REC-103

A grouping folder is not walked as itself. Instead, every one of its
immediate subfolders starts a fresh walk with context `ArtistBody` and its
own name as the artist, and the reason `grouping-folder-auto-resolved` is
added to the inherited review reasons passed down that branch — every
release eventually found under any grouping folder is forced to need
review (`AS-REC-072`), since there is no name-based confirmation that the
subfolders really are distinct artists. The grouping folder itself does not
go to `unrecognized[]`. The exception is `AS-REC-033`.

Example: `Godspeeds and their projects\Godspeed You! Black Emperor\1997 F#A# Infinity` → artist `Godspeed You! Black Emperor`, release `F#A# Infinity`, `reviewReasons` = `["grouping-folder-auto-resolved"]`.

Carried forward: grouping-folder detection requires *every* subfolder to
fail the release/disc/category/album-wrapper checks, while band-member
detection only requires *one* release-folder subfolder to exist without
excluding the others — the two "pure container" heuristics apply different
rigor to structurally similar shapes (`CF-REC-003`).

## Album wrapper folders

### AS-REC-040 — A "yyyy - Title" folder with no direct audio, wrapping one or more release-shaped edition subfolders, is an album wrapper
Status: Draft | Source: AS-DOC-REC-037; AS-DOC-REC-038; AS-CODE-REC-009–011

A folder can only be an album wrapper if: its own leaf name starts with a
parseable leading year (`AS-REC-052`) — without one, it is never an album
wrapper; it has no direct audio files (a folder with direct audio is
handled by the plain release-folder rule instead); and at least one
immediate subfolder itself qualifies as a release folder. A folder that
holds tracks directly is a normal release, not an album wrapper.

Example: `Wrapper Band\1975 - Wrapped Album (Special Edition)` (edition `1989 Country Label 123`) → album wrapper. `ZZ Top\1999 XXX` → not an album wrapper (tracks directly inside). `ZZ Top` → not an album wrapper (no leading year).

### AS-REC-041 — Every non-release subfolder must have zero audio anywhere below it, or the folder is not an album wrapper
Status: Draft | Source: AS-DOC-REC-039; AS-CODE-REC-012

Every immediate subfolder that is not itself a release folder must contain
zero audio files anywhere underneath it (checked recursively). If any
non-release subfolder hides audio somewhere below, the folder is not
treated as an album wrapper — there is an unknown extra layer of nesting
(e.g. a real band-member folder) that must not be silently swallowed as
"just another edition".

Example: `1965 - Partial Wrapper\1970 Real Edition\01 - Track.flac` plus `1965 - Partial Wrapper\Bonus Nested\Deeper\01 - Track.flac` → not an album wrapper.

### AS-REC-042 — Title and year come from the album wrapper folder; the edition name is recorded separately
Status: Draft | Source: AS-DOC-REC-040; AS-DOC-REC-041

For a release inside an album wrapper, the title and the year always come
from the album wrapper folder's own name, never the edition subfolder's.
When a `yyyy - Title`/`yyyy Title` wrapper's subfolders are disc folders
rather than edition folders, the whole thing is one multi-disc release
instead (`AS-REC-015`), with no edition folder name and no
`multiple-editions-in-album-folder` reason. Otherwise, the edition folder
name is stored in `editionFolderName`, and the release's source folder is
the edition folder. A wrapper with exactly one edition gets no review
reason for this.

Example: `Wrapper Band\1975 - Wrapped Album (Special Edition)\1989 Country Label 123\` (2 tracks) → release `Wrapped Album (Special Edition)`, year 1975, `editionFolderName` = `1989 Country Label 123`, `needsReview` = `false`.

Example: `Wrapper Band\2004 - LP Reissue\LP#1` (2 cue tracks) and `LP#2` (3 cue tracks) → one release `LP Reissue`, `discFolderCount` = 2, `editionFolderName` = `null`.

### AS-REC-043 — Several editions in one album wrapper become separate reviewed releases, each with its own disambiguated stable key
Status: Draft | Source: AS-DOC-REC-042

When an album wrapper holds more than one edition subfolder, each edition
becomes its own release, all sharing the same title/year but each with its
own edition folder name, its own stable key (`AS-REC-007`), `needsReview`
and the review reason `multiple-editions-in-album-folder`.

Example: `Wrapper Band\1980 - Multi Edition Album\1988 Germany Label 1\01 - Track One.flac` and `…\1992 Australia Label 2\01 - Track One.flac` → 2 releases `Multi Edition Album`, 2 different `editionFolderName`/`stableKey` values, both with `multiple-editions-in-album-folder`.

### AS-REC-044 — A loose file directly in an album wrapper flags the release and is excluded from companions/ignored
Status: Draft | Source: AS-DOC-REC-043

When an album wrapper folder holds a loose file next to its edition
subfolder(s), every resulting release gets `needsReview` and the review
reason `album-folder-has-loose-files`. The loose file itself is in neither
the release's `companionFiles` nor `ignoredFiles` — companion scanning only
looks under the edition folder, not the wrapper.

Example: `Wrapper Band\1990 - Loose Files Album\cover.jpg` plus `…\1991 Some Edition\01 - Track One.flac` → release `Loose Files Album` (edition `1991 Some Edition`), `reviewReasons` contains `album-folder-has-loose-files`; `cover.jpg` is in neither list.

### AS-REC-045 — Per-edition artist resolution, when no artist is known yet, splits the ALBUM folder's name — not the edition folder's
Status: Draft | Source: AS-CODE-REC-099; AS-CODE-REC-100

For an album-wrapper folder found with no artist name yet known, each
release-qualifying edition subfolder goes through the same name-split /
tag-agreement / give-up-as-unrecognized cascade as a plain root release
(`AS-REC-023`–`026`), but splitting the *album wrapper's own* folder name,
not the edition subfolder's name. The multiple-editions and
loose-files flags (`AS-REC-043`/`044`) are added on top of whatever that
cascade already produced.

## Release folder names

### AS-REC-046 — Year and title come from the release folder name; the separator is not part of the title
Status: Draft | Source: AS-DOC-REC-044

A release folder name that starts with a 4-digit year gives the year and
the title. The year and title can be separated by a space, by `" - "`, by
`" – "` (en dash) or by `-` with no spaces at all.

Example: `1999 XXX` → 1999, `XXX`. `1999 - XXX` → 1999, `XXX`. `2006-Fire Without Flame` → 2006, `Fire Without Flame`.

### AS-REC-047 — A dash inside the title stays when the artist is already known
Status: Draft | Source: AS-DOC-REC-045

Inside an artist folder (an artist name is already known), a `" - "` after
the year is part of the title; recognize does not split it into artist and
title, and the release gets no review reason for it.

Example: `Live Wire\1990 Live - The Tour` → artist `Live Wire`, release `Live - The Tour`, year 1990, `needsReview` = `false`.

### AS-REC-048 — A year range is not a year; a leading 4-digit non-year number stays in the title
Status: Draft | Source: AS-DOC-REC-046; AS-DOC-REC-047

A folder name starting with what looks like a year range gets no year; the
whole name becomes the title. A leading 4-digit number outside the valid
range (1900–2100, `AS-REC-052`) is likewise never read as a year and stays
in the title.

Example: `1999-2003 Anthology` → year `null`, title `1999-2003 Anthology`. `Isidor - 3218 (Soldier of Fortune Edition - Artwork)` → year `null`, title `3218 (Soldier of Fortune Edition - Artwork)`.

### AS-REC-049 — A full date "yyyy.MM.dd - Title" gives the release date, the year and the title
Status: Draft | Source: AS-DOC-REC-048; AS-CODE-REC-068

A folder name starting with a valid date (`yyyy` then `.`/`-`, a 2-digit
month, the same separator, a 2-digit day) followed by a dash/en-dash or
plain whitespace gives the release date (`yyyy-MM-dd`), the year and the
title. Checked before the plain-year forms, since those never accept a `.`
or a second separator right after the 4 digits.

Example: `1999.08.29 - (album) A.S.A. Crew` → year 1999, date `1999-08-29`, title `(album) A.S.A. Crew`. `2001 - Hou (EP)` → year 2001, date `null`.

### AS-REC-050 — An invalid date (month/day out of range) leaves the whole folder name as the title, with no year
Status: Draft | Source: AS-DOC-REC-049

When the date at the start of a folder name fails the month (1–12) or day
(1–31) check, the full-date form (`AS-REC-049`) does not match, and none of
the other leading-year forms match it either (the extra separator
character stops them), so the release gets no date, no year and no release
type — the whole original folder name becomes the title.

Example: `2006.13.01 - X` (month 13) → year `null`, date `null`, type `null`, title `2006.13.01 - X`. Carried forward: the test's own comment claims this "falls back to the plain `yyyy - Title` form", which would keep year 2006 — it does not; see `CF-REC-006`.

### AS-REC-051 — The three leading-year forms are tried in a fixed priority order, all bounded to 1900–2100
Status: Draft | Source: AS-CODE-REC-068–071

`Split-ReshelfLeadingYear` tries, in order: (1) the full-date form
(`AS-REC-049`); (2) a plain spaced year (`yyyy` then whitespace, optionally
with a dash/en-dash before the space) — the rest is the title, no release
date; (3) a year glued directly to a dash/en-dash with no space (e.g.
`2006-Fire Without Flame`), accepted *unless* the remaining text itself
starts with what looks like a second 4-digit year followed by whitespace
or end-of-string, in which case the whole thing is left unparsed rather
than guessed (this is what keeps `1999-2003 Anthology` from being misread
as year 1999 + title `2003 Anthology`). If none of the three match, the
year and release date are `null` and the title is the original text,
unchanged. In every form, a 4-digit value outside 1900–2100 is never read
as a year — this is also the bound used by `AS-REC-055`/`056`, chosen
because `recognizedYear`'s own schema range is 1900–2100 (`AS-DAT-036`):
without it, a leading catalog number like `3218` would misparse as a year
and fail schema validation.

Carried forward: within the full-date form, the day is only range-checked
as 1–31 regardless of the month, so an impossible date like `2024.02.30`
would still be accepted as valid (`CF-REC-001`).

### AS-REC-052 — A release-type hint in brackets, holding nothing but a known type word, is stripped from the title
Status: Draft | Source: AS-DOC-REC-050; AS-DOC-REC-051; AS-CODE-REC-072–074

A bracket group (`()` or `[]`) at the very start or the very end of the
title, containing *only* one of the recognized type words (`mini-album`/
`mini album`, `maxi-single`/`maxi single`, `album`, `single`, `ep`, `lp`;
case-insensitive) and nothing else, is removed; the word becomes the
release type, lower-cased with internal spaces turned to hyphens. The
leading form is tried first; if it doesn't match, the trailing form is
tried. A bracket holding a type word plus other text, or a non-type word,
is left untouched and yields no release type.

Example: `(album) A.S.A. Crew` → title `A.S.A. Crew`, type `album`. `Hou (EP)` → title `Hou`, type `ep`. `(mini album) Ootori` → title `Ootori`, type `mini-album`. `Greatest (Deluxe)` → unchanged, no type. `(What's The Story) Morning Glory?` → unchanged, no type.

### AS-REC-053 — The artist name at the start of a release folder name is removed, together with an optional year
Status: Draft | Source: AS-DOC-REC-052; AS-DOC-REC-053; AS-CODE-REC-075

A title is checked against a pattern anchored at its start: optional
leading whitespace, the artist name (matched exactly, case-insensitive),
optional whitespace, optionally a 4-digit year in parentheses or brackets
(whitespace-tolerant), then one of the separators `-`, `:`, `–` (en dash)
or `—` (em dash), then optional whitespace. If the whole prefix matches and
does not consume the entire title, it is removed; the release gets the
recognition flag `artist-name-prefix-stripped` and *not* `needsReview` —
this cleanup was confirmed against the real Discogs API (searching with the
artist name still embedded in the release title returns nothing; the
stripped title finds real matches), so it is treated as deterministic, not
a guess. A captured year becomes the release year.

Example: `Dance With Ghosts\DANCE WITH GHOSTS - Requiem` → title `Requiem`, flag `artist-name-prefix-stripped`, `needsReview` = `false`. `Aerosmith\Aerosmith (1979) - Night In The Ruts [Austria 466720 2]` → year 1979, title `Night In The Ruts [Austria 466720 2]`.

### AS-REC-054 — A year found only after the artist-prefix strip is recovered by re-running the leading-year split
Status: Draft | Source: AS-CODE-REC-080

If, after the prefix strip (`AS-REC-053`), the release still has no year,
the leading-year split (`AS-REC-051`) runs again on the now-stripped title
— catching a year that sits *after* the artist-name prefix rather than
before it, which the first split (run on the raw, un-stripped name) could
not have seen.

Example: `Nostromo\Nostromo - 1998 - Argue FLAC` with artist name `Nostromo` — the initial split sees no leading year (name starts with `Nostromo`); after the prefix is stripped, `1998 - Argue FLAC` re-splits to year 1998, title `Argue FLAC`.

### AS-REC-055 — The prefix strip is rejected, title unchanged, in several specific cases
Status: Draft | Source: AS-DOC-REC-054; AS-CODE-REC-076; AS-CODE-REC-077

The title stays exactly as it is when: it does not start with the artist
name; the artist name is not followed by one of the separators; stripping
would consume the *entire* title, leaving nothing; or a bracketed 4-digit
number matched as part of the prefix falls outside 1900–2100 (treated as a
catalog number, not a year — the whole prefix-strip is then rejected, not
just the year).

Example: `Live - The Tour` with artist `Live Wire` → unchanged (doesn't start with the artist name). `Some Band -` with artist `Some Band` → unchanged (nothing left after the separator). `Some Band (3218) - X` with artist `Some Band` → unchanged (3218 out of year range cancels the whole strip).

## Track file names and track order

### AS-REC-056 — Track number and title from "NN - Title", "NN – Title" or "NN Title"
Status: Draft | Source: AS-DOC-REC-055; AS-CODE-TXT-014 (first form)

After stripping the extension, a leading number is tried first against
`"N - Title"`/`"N – Title"` (digits, optional whitespace, a hyphen or
en-dash, optional whitespace, then the rest as title) or `"N Title"`
(digits then whitespace, no dash). The number is the track number; the rest
becomes the title.

Example: `01 - Poke Chop Sandwich.flac` → 1, `Poke Chop Sandwich`. `02 – Crucifixx A Flatt.flac` → 2, `Crucifixx A Flatt`. `03 Some Track.mp3` → 3, `Some Track`.

### AS-REC-057 — A bracketed track number (1–3 digits) is read; a bracketed 4-digit year is not
Status: Draft | Source: AS-DOC-REC-056; AS-DOC-REC-057; AS-CODE-TXT-014 (second form)

If the dash/space form (`AS-REC-056`) doesn't match, a number in square or
round brackets at the start of the file name is tried next, capped at 1–3
digits specifically so a 4-digit year in parentheses is never misread as a
track number.

Example: `[01] Blind Guardian - Don't Talk To Stranger.mp3` → 1, title `Blind Guardian - Don't Talk To Stranger`. `(02) Some Track.flac` → 2. `(1999) Some Track.flac` → no track number (4 digits, rejected by the cap).

Carried forward: the bracket/paren pattern matches its opening and closing
delimiters independently, so a mismatched pair like `"[01).mp3"` is still
accepted and yields track number `01` (`CF-TXT-003`, REC-owned; see
[02-text-and-naming.md](02-text-and-naming.md) `CF-TXT-003`).

### AS-REC-058 — A file name with no leading number keeps the whole name (minus extension) as the title
Status: Draft | Source: AS-DOC-REC-058; AS-CODE-TXT-014 (fallback)

When neither of the above forms match, the track has no number, and the
whole trimmed base name (extension removed) is the title.

Example: `Alpha Song.flac` → no number, title `Alpha Song`.

### AS-REC-059 — The title is also tested for an "Artist - Title" shape, as a non-authoritative hint
Status: Draft | Source: AS-DOC-REC-059; AS-CODE-TXT-015

Independently of whether a track number was found, the resulting title is
always also tested against `"<Artist> - <Title>"` (first `" - "`/`" – "`
found, non-greedy), producing candidate artist/title parts. This is only a
candidate, not a decision — a single-artist title can legitimately contain
a dash too (e.g. `"Song - Live"`) — so the caller decides whether to trust
it. With no such dash, both parts are empty and the full title stands.

Example: `[01] Blind Guardian - Don't Talk To Stranger.mp3` → artist part `Blind Guardian`, title part `Don't Talk To Stranger`. `03 Some Track.mp3` → no parts.

How compilations use per-track artists: see [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md).

### AS-REC-060 — Tracks are ordered by number when every file in the folder has one
Status: Draft | Source: AS-DOC-REC-060; AS-CODE-REC-025

When every audio file in a folder parsed a track number (`AS-REC-056`–`058`),
the files are sorted by that number, each keeping its own parsed
number/title; the order is not inferred.

Example: `02 - Second.mp3`, `01 - First.mp3` → order 1, 2, `inferredTrackOrder` = `false` for both.

### AS-REC-061 — If even one file has no number, the whole folder falls back to alphabetical order, renumbered from 1
Status: Draft | Source: AS-DOC-REC-061; AS-CODE-REC-026

When at least one audio file in a folder has no track number, *every* file
in that folder — including ones that did parse a number — is instead
sorted A–Z by file name and renumbered sequentially from 1; every track is
marked `inferredTrackOrder` = `true`, and individually-parsed numbers are
discarded. The release gets the recognition flag `no-track-number`. This
alone does not set `needsReview`.

Example: `01 - First.mp3`, `Unnumbered.mp3` → order `01 - First.mp3` (1), `Unnumbered.mp3` (2), both inferred, flag `no-track-number`.

Carried forward: one unnumbered file in a folder drops the numeric order of
every other file in it (`CF-REC-007`): `2 - B.flac`, `10 - A.flac`,
`Bonus.flac` → alphabetical order `10 - A.flac`, `2 - B.flac`,
`Bonus.flac`, not the numeric order the other two files suggest.

## Disc folders

### AS-REC-062 — Disc-folder name pattern
Status: Draft | Source: AS-DOC-REC-062; AS-DOC-REC-063; AS-CODE-REC-001 (`90` resolves AS-DOC-DEF-021)

A folder name is a disc folder when it starts (case-insensitive) with
`CD`, `Disc`, `Disk` or `LP`, then optional spaces/underscores, an optional
`#`, an optional `.`, optional more spaces/underscores, one or more digits,
and then either a space, underscore, `.`, `-`, or the end of the string.
Plan 05's regex is narrower (no underscore, no trailing text after the
number) — tests and code agree on the fuller pattern; see
`90-contradictions-resolution.md`.

Example: `CD 1`, `cd1`, `Disc 2`, `DISK.3`, `LP#1`, `LP 1`, `CD_1`, `CD1. Forwards`, `Disc 2 - Bonus` → disc folders. `Bonus Disc`, `CD10Something` → not disc folders (no separator before the trailing text).

### AS-REC-063 — The disc number is the digit group the pattern captures
Status: Draft | Source: AS-DOC-REC-064; AS-CODE-REC-002

A disc folder's number is the digit group matched by `AS-REC-062`'s
pattern. A name that does not match the pattern gives no number.

Example: `CD1` → 1, `Disc 2` → 2, `LP#1` → 1, `CD_1` → 1, `CD1. Forwards` → 1, `CD10Something` → no number.

### AS-REC-064 — Disc folders are found one level deep, non-recursively, and sorted by number
Status: Draft | Source: AS-DOC-REC-065; AS-CODE-REC-003; AS-CODE-REC-004

Disc folders are found by scanning only the immediate subfolders of a
release folder (not recursively) and keeping those matching `AS-REC-062`;
a folder that cannot be listed (e.g. inaccessible) is treated as having no
subfolders rather than erroring. The results are sorted ascending by their
extracted disc number, not as text.

Example: `ZZ Top\2003 Mescalero` → 2 disc folders, in the order `CD 1`, `CD 2`.

### AS-REC-065 — A multi-disc release counts and labels its discs; a single-disc release has disc count 1 and a null disc label
Status: Draft | Source: AS-DOC-REC-066

A multi-disc release's `discFolderCount` is the number of disc folders;
each track records its disc folder's name in `discFolder`, and the track
number restarts at 1 in each disc — recognize does not compute a number
across all discs. A release without disc folders has `discFolderCount` = 1
and `discFolder` = `null` on every track.

Example: `ZZ Top\2003 Mescalero` → `discFolderCount` = 2, `CD 1` has 2 tracks (1, 2), `CD 2` has 3 tracks (1, 2, 3).

### AS-REC-066 — A loose audio file in a multi-disc release is kept as a track, flagged track-outside-disc-folder-suspected
Status: Draft | Source: AS-DOC-REC-067; AS-CODE-REC-088

An audio file sitting directly in a multi-disc release folder, outside
every disc folder, would otherwise vanish (excluded from both the per-disc
track lists and companion scanning) — instead it is still collected as its
own track, with `discFolder` = `null`, and the release gets `needsReview`
with reason `track-outside-disc-folder-suspected`.

Example: `ZZ Top\2003 Mescalero\Stray Bonus Track.mp3` → track with `discFolder` = `null`, number 1, `inferredTrackOrder` = `true` (golden file), release flagged `no-track-number` and `track-outside-disc-folder-suspected`.

Carried forward: this check exists for the with-disc-folders branch, but
the with-disc-folders branch never checks whether a *non-disc* subfolder
independently qualifies as its own nested release — unlike the no-disc
branch's `nested-release-suspected` check (`AS-REC-017`); see `CF-REC-002`.

## Cue sheets

### AS-REC-067 — One audio file plus its cue sheet becomes cue virtual tracks; the audio file is never split at this stage
Status: Draft | Source: AS-DOC-REC-068; AS-CODE-REC-031

A folder (release or disc folder) with exactly one audio file that
resolves to a cue sheet (`AS-REC-069`) is a single-file cue-sheet release.
Recognize records the pair in `cueSheets` and makes one virtual track per
cue `TRACK` entry; each virtual track points at the shared audio file, has
`isCueVirtualTrack` = `true`, and stores its start time in `cueTimestamp`.
The audio file itself is not split here — that happens at apply time (see
[10-apply.md](10-apply.md)).

Example: `Pink Floyd\1994 Live In Concert (Bootleg)\Live In Concert.flac` + `Live In Concert.cue` → `cueSheets` has 1 entry; 2 tracks `Speak To Me` (00:00:00) and `Breathe` (03:12:45), both `originalFileName` = `Live In Concert.flac`.

### AS-REC-068 — Each cue TRACK gives a title (default "Track N") and a start time from INDEX 01
Status: Draft | Source: AS-DOC-REC-069; AS-CODE-REC-038

Cue text is split into lines (CRLF/CR/LF) and scanned in order, each line
trimmed. A `TRACK <n> AUDIO` line opens a pending track and clears any
pending title; while pending, a `TITLE "<text>"` line sets its title; a
following `INDEX 01 <hh:mm:ss>` line commits the track (number, title —
defaulting to `"Track <n>"` if no `TITLE` was seen — and that timestamp)
and clears the pending state. Any other `INDEX` line (e.g. the `INDEX 00`
pregap) is ignored.

Example: `Live In Concert.cue` → track 1 `Speak To Me` at `00:00:00`, track 2 `Breathe` at `03:12:45`.

### AS-REC-069 — A cue sheet with no TRACK entry, a missing file, or an unreadable file gives no tracks, not an error
Status: Draft | Source: AS-DOC-REC-070; AS-CODE-REC-038

If reading or decoding the cue file throws, or zero tracks were found, the
result is `null` (unparseable) rather than an error. The committed tracks,
when present, are returned sorted by track number.

Example: `malformed.cue` with only `PERFORMER "Nobody"` → no tracks. `does-not-exist.cue` → no tracks.

### AS-REC-070 — Cue text decoding: trusted UTF-8 BOM, else strict UTF-8 with a Windows-1252 fallback
Status: Draft | Source: AS-DOC-REC-071; AS-CODE-REC-036; AS-CODE-REC-037

If the cue file's bytes start with a UTF-8 BOM (`EF BB BF`), the rest is
decoded as UTF-8, BOM dropped, trusted without further checks. Otherwise
the bytes are first decoded as *strict* UTF-8 (any invalid sequence
throws); if that throws, they are decoded as Windows-1252 instead — the
common case for cue sheets ripped on Windows with accented letters.
Plain-ASCII cue sheets decode identically either way.

Example: a BOM-less Windows-1252 cue file with `TITLE "Für einen Augenblick"` → track title `Für einen Augenblick`, not garbled.

### AS-REC-071 — The cue header gives the disc performer and disc number; a per-track PERFORMER is ignored for this
Status: Draft | Source: AS-DOC-REC-072; AS-CODE-REC-039; AS-CODE-REC-040

Header scanning stops at the first `TRACK <n>` line — a `PERFORMER`/`REM
DISCNUMBER` appearing after that line describes just that one track (which
can differ on a compilation), not the whole disc, and is never read as
header data. Within the header area, a non-blank `PERFORMER "<text>"` sets
the header performer (trimmed; if several appear, the last one wins); a
`REM DISCNUMBER <digits>` (optionally quoted) sets the disc number. Either
can be `null` if its line never appears; a missing cue file gives no
header at all.

Example:
```
REM DISCNUMBER 2
PERFORMER "Iron Maiden"
TITLE "Best Of The Beast (TOCP-50129)"
  TRACK 01 AUDIO
    PERFORMER "A Different Performer"
```
→ performer `Iron Maiden`, disc number 2 (the per-track `PERFORMER` is ignored).

### AS-REC-072 — Each cue track's duration is the gap to the next track's start (or to the file's own end, for the last track)
Status: Draft | Source: AS-DOC-REC-073; AS-CODE-REC-044

A cue track's duration is the time between its own `INDEX 01` timestamp and
the *next* track's; the last track's duration is the whole audio file's
duration minus its own start. Cue times are `mm:ss:ff` (`ff` = 1/75
second); the computed duration is rounded to 3 decimal places. Each
track's title comes from the cue (or its default); artist/album come from
the whole file's own tags, not the cue.

Example: `Live In Concert.flac` (mock duration 200 s), tracks at `00:00:00` and `03:12:45` → `Speak To Me` 192.6 s, `Breathe` 7.4 s.

Carried forward: if the whole-file duration is shorter than the last
track's own start, this subtraction can go negative; no guard, flag or
review reason exists for it (`CF-REC-008`).

### AS-REC-073 — An .ape source's cue virtual tracks are reported as .flac, still lossless
Status: Draft | Source: AS-DOC-REC-074; AS-CODE-REC-042

When the source audio file's format is `.ape`, every virtual track's
`format` is `flac` instead, and `isLossless` stays `true` — the splitting
tool has no `.ape` encoder/muxer and always re-encodes an `.ape` split to
`.flac`, losslessly. For every other format, the virtual tracks' format
matches the source unchanged.

Example: `APE Cue Band\1993 APE Bootleg\Show.ape` + `Show.cue` (tracks `Intro`, `Main Set`) → 2 tracks, both `format` = `flac`, `isLossless` = `true`.

### AS-REC-074 — Unreadable audio properties, or an unparseable cue, still produce a result — flagged for review
Status: Draft | Source: AS-DOC-REC-090 (cue context); AS-CODE-REC-041; AS-CODE-REC-043

Before splitting, the source audio file's own tags/properties are read; if
they cannot be read, the whole cue-track result is flagged `needsReview`
with reason `audio-properties-unreadable`. If the cue sheet itself cannot
be parsed at all (`AS-REC-069`), recognize falls back to exactly one
virtual track covering the whole file: number 1, inferred order, cue
timestamp `00:00:00`, title/artist/album from the file's own tags, flagged
`needsReview` with reason `unparseable-cue-sheet`.

### AS-REC-075 — Picking the cue sheet for an audio file: unconditional if there's one cue, else name-matching
Status: Draft | Source: AS-DOC-REC-075; AS-DOC-REC-076; AS-CODE-REC-027–030

Zero `.cue` files → no match. Exactly one `.cue` file → that one,
unconditionally, whatever its name. With more than one, two name-matching
rules are tried in order: first, a cue named exactly `<audio file name with
extension>.cue` (e.g. `Album.flac.cue` for `Album.flac`); if that does not
yield exactly one match, a cue whose base name (no extension) equals the
audio file's base name (e.g. `Album.cue`). If neither rule yields exactly
one match, the result is no match. A release with one audio file and an
extra, unrelated cue file (for a format that isn't present) is still a cue
release, as long as one cue matches by name.

Example: audio `Album.flac`, cues `Album.flac.cue` + `Album.wav.cue` → `Album.flac.cue` (exact-name rule wins even though a basename match also exists for the same audio file, since the rules are tried in priority order, not merged). Audio `Album.flac`, cues `Other.flac.cue` + `Other.wav.cue` → no match.

### AS-REC-076 — Each disc folder can have its own cue sheet
Status: Draft | Source: AS-DOC-REC-077; AS-DOC-REC-078

When each disc folder of a release holds one audio file and its own cue
sheet, each disc gets its own `cueSheets` entry and its own virtual
tracks, and no cue file is marked unused. One release can also mix a
cue-image disc with a normal numbered-track disc; each disc is handled by
its own form independently.

Example: `Wrapper Band\2000 - Per Disc Cue Album\2000 Tour Edition\CD 1\Disc One.flac` + `.cue`, and `CD 2\Disc Two.flac` + `.cue` → 2 `cueSheets`, `discFolderCount` = 2, 3 virtual tracks total, no `cue-sheet-not-used`.

## Flat multi-disc cue pairs

### AS-REC-077 — Two or more audio files, each with its own distinct cue, become one disc per pair
Status: Draft | Source: AS-DOC-REC-079; AS-CODE-REC-032; AS-CODE-REC-033

When a release folder has no disc-named subfolders, holds at least 2 direct
audio files, and *every* one resolves to its own cue sheet with no two
sharing the same cue, each audio/cue pair becomes its own virtual disc
(labeled by the audio file's own base name). The release is flagged
`needsReview` with reason `flat-multi-disc-cue-pairs`, no cue file is
marked unused, and the reported disc count is the pair count. If any
audio file fails to resolve a cue, or two share one, the whole operation
yields no pairs — not a partial result — and the folder falls through to
whichever other rule applies (ordinary tracks, or a single cue release).

Example: `Iron Maiden\1995 - The X Factor (TOCP-8588)\` with `...(TOCP-8588).flac`+`.cue` (2 tracks) and `...(BCD-0033).flac`+`.cue` (1 track) → `discFolderCount` = 2, 2 `cueSheets`.

### AS-REC-078 — Pairs are ordered by cue DISCNUMBER when every cue has one; otherwise by a catalog-number-in-folder-name heuristic
Status: Draft | Source: AS-DOC-REC-080; AS-DOC-REC-081; AS-CODE-REC-034; AS-CODE-REC-035

If every pair's cue header carries a `REM DISCNUMBER`, the pairs are
sorted by that number — this wins even when it disagrees with any
catalog-number hint in the folder name. Otherwise, for each pair, the text
inside the *last* trailing parenthesized group of the audio file's base
name is extracted; if that text appears (case-insensitive, substring)
inside the release folder's own name, the pair sorts first. Ties (in
either rule) are broken by audio file name.

Example: folder `1995 - The X Factor (TOCP-8588)`, `(TOCP-8588).cue` has `REM DISCNUMBER 2`, `(BCD-0033).cue` has `REM DISCNUMBER 1` → disc 1 is `BCD-0033`, disc 2 is `TOCP-8588` (DISCNUMBER wins over the folder-name hint). Without any DISCNUMBER: disc 1 is the pair whose catalog fragment (`TOCP-8588`) appears in the folder name.

Carried forward: `discFolder` holds this catalog-number label for a flat
pair even though there is no actual disc *folder* — the field name implies
a folder, but the value here is not one, and its exact shape is not
documented (`CF-REC-009`).

### AS-REC-079 — Without one cue per audio file, the files are ordinary tracks and the shared cue is ignored
Status: Draft | Source: AS-DOC-REC-082

Flat pairing needs at least two audio files, each resolving to its *own*
distinct cue. When several audio files instead share one cue file (or
there are fewer than 2 audio files), recognize treats the audio files as
normal tracks and the cue file goes to `ignoredFiles` with reason
`cue-sheet-not-used`. One audio file with one cue is the ordinary
single-file cue release (`AS-REC-067`), not a flat pair.

Example: `Some Artist\2003 Some Album\01 - Track One.flac`, `02 - Track Two.flac`, `Album.cue` → `discFolderCount` = 1, 0 `cueSheets`, 2 normal tracks, `Album.cue` ignored with `cue-sheet-not-used`.

## Companion and ignored files

### AS-REC-080 — All non-audio files under the release are scanned recursively; audio files are never companions
Status: Draft | Source: AS-DOC-REC-083; AS-DOC-REC-087; AS-CODE-REC-047

Every file anywhere under the release folder (recursive, any depth,
including inside disc subfolders) is scanned, except files recognized as
audio — those are tracks, handled elsewhere, regardless of which
subfolder they sit in.

Example: `ZZ Top\2003 Mescalero\CD 1\01 - Track One.mp3` → not a companion (it's a track). `ZZ Top\2003 Mescalero\CD 1\setlist.m3u` → still checked (and ignored, see `AS-REC-082`).

### AS-REC-081 — A companion file's kind: image keywords first, then text-like keywords, else cover/other
Status: Draft | Source: AS-DOC-REC-084; AS-DOC-REC-085; AS-CODE-REC-045; AS-CODE-REC-046 (`90` resolves AS-DOC-DEF-024)

For an image extension (`.jpg`, `.jpeg`, `.png`, `.bmp`, `.gif`, `.tiff`,
`.webp`), the lower-cased file name is checked first for `"photo"` (kind
`photo`), then for `"booklet"`, `"back"` or `"insert"` (kind `booklet`,
checked after `photo`); otherwise the kind defaults to `cover`. For `.txt`,
`.pdf` or `.nfo`, the name is checked for `"lyrics"` (kind `lyrics`),
otherwise `other`. Any other extension — including no extension at all —
is always `other`; recognize does not fail on an extensionless file.
Plan 05's distinct `"scan"` kind, and its separate `"text"` kind, do not
exist in the implementation — see `90-contradictions-resolution.md`.

Example: `ZZ Top\1999 XXX\cover.jpg` → `{ "kind": "cover", "placement": "loose" }`. `ZZ Top\2003 Mescalero\scans\back.jpg` → `{ "kind": "booklet", "placement": "nested" }` (matched via `"back"`, not the folder name `scans`). `Some Release\Extensionless` → kind `other`.

### AS-REC-082 — Playlist files are always ignored, never a companion
Status: Draft | Source: AS-DOC-REC-086; AS-CODE-REC-049

Files with extension `.m3u`, `.m3u8` or `.pls` go to `ignoredFiles` with
reason `playlist-file`.

Example: `Pink Floyd\1994 Live In Concert (Bootleg)\playlist.m3u` → `{ "reason": "playlist-file" }`. `ZZ Top\2003 Mescalero\CD 1\setlist.m3u` → ignored the same way, inside a disc subfolder.

### AS-REC-083 — A used cue sheet is silent; any other cue file is ignored
Status: Draft | Source: AS-DOC-REC-088; AS-CODE-REC-048; AS-CODE-REC-090

A `.cue` file whose full path is among the cue sheets actually used for
track-splitting anywhere in the release (flat pairs, single cue, or
per-disc cues) is skipped silently — neither a companion nor an ignored
file. Every other `.cue` file goes to `ignoredFiles` with reason
`cue-sheet-not-used` — never silently dropped.

Example: `Pink Floyd\1994 Live In Concert (Bootleg)` with `Live In Concert.cue` in use → `ignoredFiles` holds only `playlist.m3u`. If that same cue were not used, it would be ignored with `cue-sheet-not-used`.

### AS-REC-084 — Placement is "loose" at the release root, "nested" anywhere else
Status: Draft | Source: AS-DOC-REC-083; AS-CODE-REC-050

Any remaining file (not audio, not `.cue`, not a playlist extension) is
recorded as a companion with its kind (`AS-REC-081`) and a placement:
`loose` when it sits directly in the release folder itself, `nested` when
it sits in any subfolder — including a disc folder.

Example: `ZZ Top\1999 XXX\cover.jpg` → `loose`. `ZZ Top\2003 Mescalero\scans\back.jpg` → `nested`.

## Embedded cover caching

### AS-REC-085 — Empty embedded picture data yields no cache file
Status: Draft | Source: AS-CODE-REC-051

If the embedded picture has no bytes (null or zero-length), no file is
written and `null` is returned for the cover path.

### AS-REC-086 — The cache file name is the picture's SHA-256 hash; the extension comes from its declared MIME type
Status: Draft | Source: AS-CODE-REC-052

The cache file name is the lower-case hex SHA-256 hash of the picture's
bytes, so identical cover images from different tracks map to the same
cache file. The extension is `.png` for MIME type `image/png`, and `.jpg`
for `image/jpeg` or anything else (the default).

Carried forward: the extension comes only from this 2-way switch on the
*declared* MIME type, not the actual bytes — a picture whose real format
(e.g. GIF, WEBP) differs from its declared type would be cached with a
mismatched `.jpg` extension (`CF-REC-010`).

### AS-REC-087 — An existing cache file is reused, never overwritten
Status: Draft | Source: AS-CODE-REC-053

The cache file lives under `<data home>/embedded-covers/`. If a file with
the computed hash+extension name already exists there, it is reused as-is;
otherwise it is written.

## Track properties and existing tags

### AS-REC-088 — Recognize reads existing tags, embedded cover and audio properties per file; a corrupt-properties file falls back to tag-only
Status: Draft | Source: AS-DOC-REC-089; AS-CODE-REC-054; AS-CODE-REC-055; AS-CODE-REC-056

For each audio file, recognize reads the Artist/Album/Title tags (each
`null` if blank), the embedded cover (`FrontCover` preferred, else the
first picture; cached per `AS-REC-085`–`087`; `null` if none), the format
(file extension, lower-cased, no dot), whether it is lossless, and the
duration. The plan/README name TagLibSharp as the tool for this (see
`03-settings-and-secrets.md` for `taglibSharpPath`). Opening the file is
tried normally first; if that specifically throws a "corrupt file"
exception, it is reopened in a tag-only mode that skips audio-property
parsing, and the result is flagged `PropertiesUnavailable` — this recovers
tag data from a file whose format-specific property parser chokes (e.g. an
ID3v2 tag prepended to a `.mpc` file) instead of failing the whole file.
Any other exception from the first open is not caught and propagates.

Example (golden file, mock tags all empty): `ZZ Top\2003 Mescalero\CD 1\01 - Track One.mp3` → `format` = `mp3`, `isLossless` = `false`, `durationSeconds` = 200, `existingTags` all `null`.

### AS-REC-089 — Unreadable audio properties give duration 0 and flag the release for review
Status: Draft | Source: AS-DOC-REC-090

When a track's audio properties could not be read, its `durationSeconds`
is 0, and the release gets `needsReview` with reason
`audio-properties-unreadable`.

Example: `ZZ Top\1999 XXX\01 - Poke Chop Sandwich.flac` with unreadable properties → `durationSeconds` = 0, release `XXX` has `audio-properties-unreadable`.

Carried forward: only the release-folder metadata-artist lookup
(`AS-REC-031`) wraps its tag read in a try/catch for this; every other call
site (cue virtual tracks, tag-agreement, release-record building) invokes
tag reading unguarded, so any *other* exception (e.g. an unsupported
format) would abort the whole recognition run instead of being recorded as
a per-track review flag (`CF-REC-011`).

## Release record construction

### AS-REC-090 — Construction order: leaf name, leading-year split, artist-prefix strip, re-split, release-type split, path-length flag
Status: Draft | Source: AS-CODE-REC-078; AS-CODE-REC-079; AS-CODE-REC-080; AS-CODE-REC-081; AS-CODE-REC-082; AS-DOC-REC-092

Building a release record runs these steps in order on the working leaf
name (an explicit override when given — used for a root-split or an
album-wrapper's edition — otherwise the on-disk folder name): the leading-
year split (`AS-REC-051`); the artist-name-prefix strip (`AS-REC-053`),
adopting a year it captured if none was found yet; a second leading-year
split on the now-stripped title if still no year (`AS-REC-054`); the
release-type hint split (`AS-REC-052`) on whatever title remains. If the
source path needed long-path handling to resolve (its long-path form
differs from the plain path string), the recognition flag
`path-near-length-limit` is added — no error is raised.

Example: `<source root>\Long Artist aaaa…a\1990 Long Path Album\01 - track.mp3`, folder path ~250 characters → no error, release flagged `path-near-length-limit`.

### AS-REC-091 — No disc folders: flat multi-disc cue pairs take priority, then a single-file cue release, then plain tracks
Status: Draft | Source: AS-CODE-REC-083; AS-CODE-REC-084; AS-CODE-REC-085

When the release folder has no disc-named subfolders, recognize tries, in
order: flat multi-disc cue pairs (`AS-REC-077`), if at least 2 are found;
otherwise a single-file cue-sheet release (`AS-REC-067`); otherwise plain
track ordering (`AS-REC-060`/`061`), where every inferred-order track adds
`no-track-number` and every unreadable-properties track adds
`audio-properties-unreadable` (`AS-REC-089`).

### AS-REC-092 — With disc folders: each disc is independently a cue release or a plain track list; loose audio outside every disc is still kept
Status: Draft | Source: AS-CODE-REC-087; AS-CODE-REC-088

When the release folder has disc-named subfolders, each one (in disc-number
order) is checked on its own for being a single-file cue-sheet release
(`AS-REC-067`); if not, its audio files get plain track ordering, with the
same flagging as `AS-REC-091`. Every track is labeled with its disc
folder's name. Any audio file sitting outside every disc subfolder is still
collected as its own track (`AS-REC-066`).

Carried forward: unlike the no-disc-folders branch, this branch
(`AS-CODE-REC-089`) never checks whether a non-disc subfolder independently
qualifies as its own nested release (`CF-REC-002`, cross-referenced from
`AS-REC-017`/`066`).

### AS-REC-093 — Recognition confidence: 1.0, dropping to 0.8 for a flag, 0.5 for a review reason — computed once, before the record returns
Status: Draft | Source: AS-DOC-REC-093; AS-CODE-REC-091

Confidence starts at 1.0. It drops to 0.8 if any recognition flag was
raised while building the record (inferred track order, a stripped artist
prefix, a near-path-length-limit path). It drops further to 0.5 — not
combined, the higher drop simply overrides the lower one — if the release
needs review for any reason raised during record construction. This is
computed once, before `New-ReshelfReleaseRecord` returns.

Example (golden file): `Cranberries\1993 - ...` (no flags/reasons) → 1.0. `Dance With Ghosts\DANCE WITH GHOSTS - Requiem` (flag `artist-name-prefix-stripped`) → 0.8. `ZZ Top\2003 Mescalero` (flag `no-track-number`, reason `track-outside-disc-folder-suspected`) → 0.5.

Carried forward: review reasons and flags added *after* this point — by
`Invoke-ReshelfFolderWalk` (`artist-name-split-from-folder-name`,
`artist-and-album-from-tags`, `multiple-editions-in-album-folder`) or by
inherited review reasons (`grouping-folder-auto-resolved`, `AS-REC-095`) —
never trigger a recalculation, so a release can end up with `needsReview` =
`true` while `recognitionConfidence` still reads 1.0 or 0.8 instead of 0.5
(`CF-REC-012`). The golden-file examples above with `grouping-folder-auto-resolved` and `artist-name-split-from-folder-name` showing confidence 1.0 despite `needsReview` = `true` are instances of exactly this gap.

### AS-REC-094 — Reported disc count defaults to 1; flags and review reasons are de-duplicated
Status: Draft | Source: AS-CODE-REC-093; AS-CODE-REC-094

The reported disc count is the flat-pair count when that path was used
(`AS-REC-077`), otherwise the number of disc-named subfolders, floored at
1 — a release with no disc subfolders is always reported as having 1 disc.
Both `recognitionFlags` and `reviewReasons` are de-duplicated before being
stored on the record.

## Folder-walk dispatch and inherited review reasons

### AS-REC-095 — Inherited review reasons (e.g. from a grouping folder) force needsReview and are merged in, de-duplicated
Status: Draft | Source: AS-CODE-REC-065

A release built under an ancestor folder that was already auto-classified
(currently only a grouping folder, `AS-REC-039`) is given that ancestor's
review reasons after it is built: its `needsReview` is forced to `true`
and the reasons are appended to its list, de-duplicated. A release with no
inherited reasons is returned unchanged.

### AS-REC-096 — Artist bucketing: normalized key, first-seen display name, de-duplicated source paths, un-deduplicated releases
Status: Draft | Source: AS-CODE-REC-066; AS-CODE-REC-067

Releases are grouped into artist buckets keyed by a case/whitespace-
normalized form of the artist name. A bucket's displayed `recognizedName`
is set once, from the first release that creates the bucket, and is never
updated by a later release matching the same key under a different
spelling. Each bucket keeps a de-duplicated list of distinct source
folder-parent paths (a path already present is not added again) and a flat
list of every release merged into it (releases are always appended, never
deduplicated).

Carried forward: in the artist-merge scenario where two plain filler
("genre") folders each wrap one differently-named artist subfolder, those
filler folders are themselves walked as parent artists — it is not checked
whether a zero-release artist bucket for the filler folder's own name ends
up in the output (`CF-REC-013`).

### AS-REC-097 — A release with an artist already known is built directly and merged into that artist's bucket
Status: Draft | Source: AS-CODE-REC-095

When a child folder is classified `release` and an artist name is already
known from the walk context, the release record is built under that artist
(`AS-REC-013`–`017`), any inherited review reasons are applied
(`AS-REC-095`), and it is merged into that artist's bucket (`AS-REC-096`),
keyed by the release folder's own *parent* path as the source path.

### AS-REC-098 — Category/band-member/grouping/pass-through each recurse with their own context and artist-name rule
Status: Draft | Source: AS-CODE-REC-101; AS-CODE-REC-102; AS-CODE-REC-104

A `category` folder recurses with context `CategoryBody`, using the parent
artist name carried by the classification (or the one already in effect).
A `band-member` folder recurses with context `BandMemberBody` and its
artist name *reset* to the band-member folder's own name — a new, distinct
artist from its parent. A `pass-through` folder recurses with the same
context, except `Root` is promoted to `ArtistBody` (once past the first
real folder under the scan root, everything is inside an artist's body);
its artist name is the classification's proposed new name if one was set
(only happens at Root, `AS-REC-018`), otherwise whatever was already in
effect.

### AS-REC-099 — Unrecognized folders are recorded with the classification's own reason and their own direct children
Status: Draft | Source: AS-CODE-REC-064; AS-CODE-REC-105

An `unrecognized` folder is recorded in the unrecognized list with the
reason `Resolve-ReshelfFolderKind` returned and the names of its own
direct children, for human triage (`AS-REC-009`).

## Flags, review reasons and confidence

### AS-REC-100 — A review reason sets needsReview; a recognition flag alone does not
Status: Draft | Source: AS-DOC-REC-091

A release has `needsReview` = `true` exactly when it has at least one
review reason. A recognition flag by itself never sets `needsReview`.

Review reasons seen in the inputs: `nested-release-suspected`,
`artist-name-split-from-folder-name`, `artist-and-album-from-tags`,
`grouping-folder-auto-resolved`, `multiple-editions-in-album-folder`,
`album-folder-has-loose-files`, `track-outside-disc-folder-suspected`,
`flat-multi-disc-cue-pairs`, `audio-properties-unreadable`,
`unparseable-cue-sheet`.

Recognition flags seen in the inputs: `artist-name-prefix-stripped`,
`no-track-number`, `path-near-length-limit`.

Example: `Dance With Ghosts\DANCE WITH GHOSTS - Requiem` → flag `artist-name-prefix-stripped`, `needsReview` = `false`. `Godspeeds and their projects\Silver Mountain Zion\2000 He Has Left Us Alone` → reason `grouping-folder-auto-resolved`, `needsReview` = `true`.

How the review page shows these: see [09-review-ui.md](09-review-ui.md).

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-11 | Phase 3 merge of area REC: 93 `AS-DOC-REC-*`, 110 `AS-CODE-REC-*`, plus the two `AS-CODE-TXT-*` items the TXT merge deferred here, reconciled into `AS-REC-001`–`100`. 9 contradictions resolved (`AS-DOC-DEF-018`–`025`, `038`). 18 suspected defects carried forward (`CF-REC-001`–`018`, covering all of `AS-CODE-DEF-REC-001`–`007` and the REC-area `AS-DOC-DEF-026`–`037`), plus a cross-reference to `CF-TXT-003` (the mismatched bracket/paren pair in `ConvertFrom-ReshelfTrackFileName`, already filed under TXT). |
