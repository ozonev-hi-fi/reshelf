# 08 — Proposal: naming and tags (merged)

Status: Draft | Version: 0.3 | Last updated: 2026-10-13

## Scope

This file reconciles [`as-is-from-docs/08-proposal-naming-and-tags.md`](../as-is-from-docs/08-proposal-naming-and-tags.md)
(78 `AS-DOC-PRP-*` requirements, from the Pester tests, the golden
`proposal.json` fixture, the plan and the README) and
[`as-is-from-code/08-proposal-naming-and-tags.md`](../as-is-from-code/08-proposal-naming-and-tags.md)
(104 `AS-CODE-PRP-*` requirements, from `legacy/scripts/common/Reshelf.EditProposal.psm1`,
lines 1332–2928, read cold) into one behavior record for what `propose`
writes into `proposal.json`: naming templates, release and track names, pad
width, per-disc/per-file numbering, track titles, Artist/Album Artist and the
compilation flag, bilingual Japanese naming, cover art candidates and
defaults, companion files, the target index, and target comparison
(create-new/skip/update/conflict, including the lossy/lossless upgrade
summary and the previous-lossy ledger).

**Not merged here — already absorbed into MAT.** `AS-CODE-PRP-002` and
`AS-CODE-PRP-021`–`032` (track-number pad-width formula, title alignment,
number alignment, Disc.Track position parsing) were already merged under
`AS-MAT-*` in [07-proposal-matching.md](07-proposal-matching.md), per that
file's own scope note — phase 1's MAT scope already claimed these as
MAT-owned. They do **not** appear below; `92-coverage.md` maps them to their
`AS-MAT-NNN`. Several items here instead *reuse* an already-merged MAT rule
(the master-year rule, the master-image-fallback rule, the Various/compilation
detection rules, the alignment cascade) — each such item says so and cites
the `AS-MAT-NNN` it reuses, the same pattern `AS-DOC-PRP-041`/`054` already
used before the merge.

**Numbering note.** As with MAT and REC, this file is organized by topic
(run-level behavior, review notes, release names, bilingual names, track
numbers, track titles, Artist/compilation, cover art, companion files,
target index, target comparison, manual re-pick) rather than carrying old
numbers forward, since the code side names many mechanics (run-level
sequencing, the naming-template engine, the lossy ledger, the full
target-action decision table) that the docs/tests view only shows through
example. Every `AS-PRP-NNN` cites every `AS-DOC-PRP-*`/`AS-CODE-PRP-*` id it
reconciles; [92-coverage.md](92-coverage.md) maps every source id to its
`AS-PRP-NNN`.

How Discogs matching, scoring, track alignment and Disc.Track position
parsing work: see [07-proposal-matching.md](07-proposal-matching.md). Text
normalization, title case and safe-name rules: see
[02-text-and-naming.md](02-text-and-naming.md). Settings defaults
(`trackNumberPadWidth`, `coverMaxDimension`, `cacheTtlDays`,
`rateLimitPerMinute`, `namingTemplates.*`): see
[03-settings-and-secrets.md](03-settings-and-secrets.md). Stable keys: see
[01-data-and-storage.md](01-data-and-storage.md). The lossy ledger and its
own lifecycle: see [11-lossy-tracking.md](11-lossy-tracking.md). Apply, cue
splitting and the ffmpeg cover resize: see `10-apply.md` (not yet merged).
The review UI's Discogs picker and cover picker: see `09-review-ui.md` (not
yet merged).

## Run-level behavior

### AS-PRP-001 — A propose run refuses to start unless the recognition input validates against its schema
Status: Draft | Source: AS-CODE-PRP-097

`Invoke-ReshelfEditProposal` validates the recognition document against the
recognition schema before reading anything else, and throws if it fails.
Nothing in the docs/tests view describes this gate; it is a pure code-side
fact.

### AS-PRP-002 — Propose prints a run summary
Status: Draft | Source: AS-DOC-PRP-001

`propose -SessionId <id>` looks up every release, writes the proposal, and
prints a summary: session id, artist count, release count, matched count,
and needs-review count. This print happens at the CLI boundary, outside the
`Reshelf.EditProposal.psm1` lines the code-side view covers — see
[12-cli.md](12-cli.md) (`AS-CLI-012`).

Example: `SessionId : 2026-09-25-0007`, `ArtistCount : 42`, `ReleaseCount :
118`, `MatchedCount : 103`, `NeedsReviewCount : 15`.

### AS-PRP-003 — DataHome and ProposalPath both have computed defaults when not supplied
Status: Draft | Source: AS-CODE-PRP-098

If `DataHome` isn't supplied, it is resolved the normal way (see
[01-data-and-storage.md](01-data-and-storage.md)). If `ProposalPath` isn't
supplied, it defaults to `<DataHome>/sessions/<SessionId>/proposal.json`.

### AS-PRP-004 — Naming, cover and rate-limit parameters fall back to hardcoded defaults matching the settings' own defaults
Status: Draft | Source: AS-DOC-PRP-009 (partial), AS-DOC-PRP-017 (partial), AS-DOC-PRP-018 (partial), AS-DOC-PRP-056 (partial); AS-CODE-PRP-095; AS-CODE-PRP-099

Neither `Invoke-ReshelfEditProposal` nor `Update-ReshelfReleaseForDiscogsSelection`
reads `settings.json` itself. Each has its own hardcoded PowerShell parameter
defaults, which happen to equal the settings' own defaults: release folder
template `{year} {album}`, track file template `{trackNumber} {title}`,
track number pad width 2, cover max dimension 600, cache TTL 30 days, rate
limit 55/minute (see `AS-SET-007`/`008`/`009`/`012`/`013` in
[03-settings-and-secrets.md](03-settings-and-secrets.md)). The caller (the
CLI layer) is responsible for reading the real settings and passing them in;
these are fallbacks for a caller that doesn't.

### AS-PRP-005 — A propose re-run overwrites the proposal and loses review edits
Status: Draft | Source: AS-DOC-PRP-002; AS-CODE-PRP-102

When the user runs `propose` again on the same session, it overwrites
`proposal.json` and all review-UI edits are lost. The document is always
freshly assembled, written to disk, then re-read from disk for the return
value (`AS-PRP-006`) — there is no read-modify-merge with whatever was there
before.

Example: the user edits a track title in the review UI and saves, then runs
`propose -SessionId 2026-09-25-0007` again — the edit is gone.

### AS-PRP-006 — The proposal document is schema-valid, with a hardcoded schema version and a fixed UTC timestamp format
Status: Draft | Source: AS-DOC-PRP-003; AS-CODE-PRP-103

`proposal.json` holds `schemaVersion` (always the literal `1`), `sessionId`,
`sourceRoot`, `generatedAtUtc` (current UTC time, `'yyyy-MM-ddTHH:mm:ss.fffZ'`),
`artists[]` (each with `releases[]`) and `unrecognized[]`. Each release keeps
its recognition fields and adds `discogsMatch`, `proposed`, `coverArt`,
`lossyLossless`, `targetAction` and `humanReview` (`required`, `resolved`,
`rejected`, `notes`). Each track adds `proposedFileName`,
`proposedDiscNumber`, `proposedTrackNumber`, `proposedTitle` and `tags`. The
caller always receives whatever actually round-tripped through JSON
(`AS-PRP-005`), not the in-memory object.

### AS-PRP-007 — The target index and session-collision state are built once per run and shared across every artist and release
Status: Draft | Source: AS-CODE-PRP-100

The target index (`AS-PRP-064`) and the `SessionSeen`/`SessionSeenByPath`
dictionaries (`AS-PRP-069`) are each created once at the top of the run,
before iterating artists, and passed down unchanged to every release — this
is how a cross-artist or cross-release target-path collision is detected
within one run.

### AS-PRP-008 — Every release of an artist has its Discogs match resolved before any of that artist's names are finalized
Status: Draft | Source: AS-CODE-PRP-101

For each artist, every one of that artist's releases is matched first,
before the shared bilingual artist name (`AS-PRP-023`) is computed and
before any one release's names are built — so bilingual evidence from any
sibling release is available before any sibling's own folder/tag name is
decided.

### AS-PRP-009 — Unrecognized source entries pass through unchanged
Status: Draft | Source: AS-CODE-PRP-104

`recognition.unrecognized` is copied into the proposal document's
`unrecognized` field with no transformation.

## Review flags and notes

### AS-PRP-010 — Recognition's own review flag and reasons always carry into the proposal
Status: Draft | Source: AS-DOC-PRP-004; AS-CODE-PRP-082

When recognition flagged a release for review, the proposal flags it too,
even with a clean Discogs match — `Release.needsReview`/`reviewReasons`
unconditionally set `requiresReview = $true` and append every reason to the
notes, independent of every other check in this function.

Example: `OK Computer` with review reason `artist-name-split-from-folder-name`
and Discogs status `matched` → `humanReview.required = true`, notes contain
`artist-name-split-from-folder-name`.

### AS-PRP-011 — A non-matched Discogs status, and a match error note, each force review independently
Status: Draft | Source: AS-DOC-PRP-005; AS-CODE-PRP-085

When the Discogs match status is `ambiguous` or `not-found`, the release
needs review and the note contains `Discogs match status: <status>`. A
match error note (`AS-MAT-038`) forces review too, on its own — the two
conditions can fire together, each adding its own note.

Example: `Cranberries / Everybody Else Is Doing It` with no Discogs result →
`humanReview.required = true`, notes start with `Discogs match status:
not-found`.

### AS-PRP-012 — Any note from the track set — including a non-unique-numbering note — unconditionally forces review
Status: Draft | Source: resolves `AS-DOC-DEF-068` (see `90-contradictions-resolution.md`)

The track-set building step (`AS-PRP-038`–`049`) returns its own notes
separately from a review flag; the caller is what turns any one of those
notes into `requiresReview = $true` — a fact neither source captured on its
own, found only by re-reading the caller
(`Reshelf.EditProposal.psm1:2578-2581`, and the same pattern again at
`:2766-2770` for the manual re-pick, `AS-PRP-091`).

### AS-PRP-013 — Review notes are one text, joined with "; "; `rejected` always starts false
Status: Draft | Source: AS-DOC-PRP-007; AS-CODE-PRP-089

The review notes are one string, parts joined with `; `. The order in the
golden file is: recognition review reasons, Discogs match status,
unresolved-year note, cover note. `resolved` is `-not requiresReview`, and
`rejected` always starts `false` — rejection is a later, separate user
action, never decided at proposal time.

Example (`Isidor`): `artist-name-split-from-folder-name; Discogs match
status: not-found; UNRESOLVED YEAR: placeholder value used, must be
corrected before applying.; No cover art candidates found from Discogs or
local companion files.`

## Release names

### AS-PRP-014 — Without a Discogs match, names come straight from recognition: Title Cased (or the shared bilingual name), year unmodified
Status: Draft | Source: AS-DOC-PRP-006; AS-CODE-PRP-014; AS-CODE-PRP-015; AS-CODE-PRP-016

When there is no Discogs match (ambiguous or not found), the artist folder
name is the shared bilingual artist name if one was set from another release
of the same artist (`AS-PRP-023`), else the recognized artist name Title
Cased. The proposed album is the recognized title, Title Cased. The proposed
year is the recognized year, exactly as recognition derived it — no bilingual
join is attempted, since there is no Discogs text to pair with.

Example: recognized `Some Totally Different Band` / `Unrelated Album` / 2010,
Discogs status `ambiguous` → `artistFolderName = Some Totally Different
Band`, `album = Unrelated Album`.

### AS-PRP-015 — Discogs text is used exactly as Discogs writes it; casing is never changed
Status: Draft | Source: AS-DOC-PRP-013

The proposal uses Discogs artist, album and track text exactly as Discogs
returns it — it does not change the casing. Only invisible formatting
characters are removed (see [02-text-and-naming.md](02-text-and-naming.md)).

Example: Discogs artist `edbl` → artist folder `edbl` (stays lowercase).

### AS-PRP-016 — Matched-release artist name: the shared bilingual name wins, else Discogs' first artist credit with its disambiguation suffix stripped
Status: Draft | Source: AS-DOC-PRP-008; AS-CODE-PRP-011

For a matched release, the artist used for folder/tag is the precomputed
shared bilingual name (`AS-PRP-023`) when one is set; otherwise it is
Discogs' first artist credit with its trailing `" (N)"` disambiguation
suffix stripped and invisible characters removed.

Example: Discogs artist `Metallica (2)` → artist folder `Metallica`.

### AS-PRP-017 — Names from the fallback (non-Discogs) path are Title Cased
Status: Draft | Source: AS-DOC-PRP-014

Each word starts with a capital letter; existing capitals inside a word
stay. The exact rule: see [02-text-and-naming.md](02-text-and-naming.md).

Example: recognized `3218 (Soldier of Fortune Edition - Artwork)` → album
`3218 (Soldier Of Fortune Edition - Artwork)`.

### AS-PRP-018 — Release folder name is "{year} {album}", built from the template and trimmed
Status: Draft | Source: AS-DOC-PRP-009; AS-CODE-PRP-019

`ReleaseFolderName` is the release folder template, expanded with `{year}`
(cast to `int`) and `{album}` (the sanitized title) substituted, then
trimmed. The default template is `{year} {album}` (`AS-PRP-004`).

Example: template `"{year} {album}"`, year `2005`, sanitized album
`"Angherr Shisspa"` → `"2005 Angherr Shisspa"`. Discogs `OK Computer`, 1997 →
`1997 OK Computer`.

### AS-PRP-019 — The edition folder recognition found is not part of the release folder name
Status: Draft | Source: AS-DOC-PRP-010

When recognition found an edition subfolder, the proposed release folder
name does not contain it.

Example: recognized title `Wrapped Album (Special Edition)`, 1975, edition
folder `1989 Country Label 123` → release folder `1975 Wrapped Album
(Special Edition)`.

### AS-PRP-020 — Year and Album tags always equal the release folder name's parts
Status: Draft | Source: AS-DOC-PRP-012

Every track's year tag is `proposed.year`; every track's album tag is
`proposed.album`. They always equal the `yyyy` and `Name` parts of the
release folder name.

Example: release folder `1993 Everybody Else Is Doing It` → `tags.year =
1993`, `tags.album = Everybody Else Is Doing It`.

### AS-PRP-021 — An unresolved year falls back to the sentinel 1900 and flags the release for review
Status: Draft | Source: AS-DOC-PRP-011; AS-CODE-PRP-017

If the resolved year is falsy (null or `0`, after the matched/unmatched
logic of `AS-PRP-014`/`016`/`022`), the proposal substitutes the hardcoded
sentinel **1900** and sets `UsedSentinelYear = $true`. It goes into the
release folder name, `proposed.year` and every track's year tag. The release
needs review, note `UNRESOLVED YEAR: placeholder value used, must be
corrected before applying.`

Example: `DANCE WITH GHOSTS - Requiem` (no year) → release folder `1900
Requiem`, `tags.year = 1900`. The README warns the user not to keep 1900
(`AS-REV-*`, `09-review-ui.md`, not yet merged); only an empty year blocks
apply, not the value 1900 itself.

### AS-PRP-022 — Matched-release year reuses the matching-area master-year rule
Status: Draft | Source: AS-CODE-PRP-013

This is the same rule as `AS-MAT-045` (primary): the master's year is used
when the match has a master and the master's year is truthy (Discogs
represents "unknown" as `0`, which is falsy); otherwise the picked
pressing's own year is used. No new fact beyond what `AS-MAT-045` already
states — code excerpted here independently, from the naming side of the same
module, confirms it.

Example: a 2019 reissue of a 2005 album → Year 2005.

### AS-PRP-023 — Folder and file names are sanitized; tags keep the original text
Status: Draft | Source: AS-DOC-PRP-015; AS-CODE-PRP-018

The raw artist and title strings are each sanitized into a file-system-safe
name, with any substituted characters tracked. The proposal replaces
characters that a Windows file name cannot hold only in folder names and
file names — tags and `proposedTitle` keep the original text. The character
rules: see [02-text-and-naming.md](02-text-and-naming.md).

Example: artist `AC/DC`, album `Back In Black / Live Edition`, 1980, title
`Rock/Roll: Live` → artist folder `AC_DC`, release folder `1980 Back In
Black _ Live Edition`, file `01 Rock_Roll_ Live.flac`; tags `AC/DC`, `Back
In Black / Live Edition`, `Rock/Roll: Live`.

### AS-PRP-024 — A name fix for a reserved name or a trailing dot is noted
Status: Draft | Source: AS-DOC-PRP-016

When the safe-name step changes a reserved device name or removes a
trailing dot or space, the review notes say so.

Example: artist `CON`, album `Some Album.`, 2010 → artist folder `CON_`,
release folder `2010 Some Album`; notes contain `reserved device name 'CON'
suffixed with '_'` and `trailing dot/space removed`.

### AS-PRP-025 — Naming template expansion is plain, per-key string substitution
Status: Draft | Source: AS-CODE-PRP-001

A naming template is expanded by replacing each `{key}` literally with the
matching value from a hashtable, one key at a time, using plain string
`.Replace()` — not a regex, not a single pass over the whole template. Any
`{key}` left in the template with no matching hashtable key is left
untouched in the output.

Example: template `"{year} {album}"` with `{ year = 2005; album = "Angherr
Shisspa" }` → `"2005 Angherr Shisspa"`.

### AS-PRP-026 — The returned name object separates raw (tag) text from sanitized (folder) text
Status: Draft | Source: AS-CODE-PRP-020

The result exposes both the sanitized `ArtistFolderName`/`ReleaseFolderName`
(for file-system paths) and the raw, possibly-bilingual `Artist`/`Album`
(for tags, which can hold characters a folder name cannot), plus `Year`,
`IsCompilation`, `UsedSentinelYear`, and the combined `Substitutions` list.

## Bilingual (Japanese) names

### AS-PRP-027 — Japanese-only Discogs text gets the form "{romanized} = {original}"
Status: Draft | Source: AS-DOC-PRP-044

When the Discogs album title or track title is Japanese-only text, the
proposal puts the romanized source text in front: `{romanized} = {original}`
— the Discogs convention.

Example: Discogs album `ロッキンポ殺し`, source title `Rokkinpo Goroshi` →
album `Rokkinpo Goroshi = ロッキンポ殺し`.

### AS-PRP-028 — The romanized half always comes from the source, never from transliteration
Status: Draft | Source: AS-DOC-PRP-045; AS-CODE-PRP-003; AS-CODE-PRP-004; AS-CODE-PRP-005; resolves `AS-DOC-DEF-066` (see `90-contradictions-resolution.md`)

To find a romanized title the source itself already carries, the code first
collects every track's existing `Album` tag value, picks the most frequent
one (ties broken by first-seen order), and uses it — Title Cased — only if
it passes the romanized-text check. If no tag-derived value qualifies, it
falls back to the recognized folder title, Title Cased, again only if that
passes the check. If neither qualifies, the function returns nothing rather
than inventing a romanized value — the caller then falls back to a
Discogs-only (non-bilingual) title. The app never invents or transliterates
this half.

Example: a release whose files' own `Album` tag already reads "Rokkinpo
Goroshi", matched to Discogs-only "ロッキンポ殺し" → romanized half
"Rokkinpo Goroshi" (Title Cased), taken from the tags. Folder artist
`Maximum the Hormone` → `Maximum The Hormone = マキシマム ザ ホルモン` (the
romanized half appears in title case, taken from the folder name, not from
Discogs or from transliteration — see the resolution note for why this
coincidentally equals a Discogs name variation too).

### AS-PRP-029 — A Japanese-only Discogs artist credit, found on any matched release of that artist, gives a bilingual artist folder, Artist and Album Artist — shared by every release of that artist
Status: Draft | Source: AS-DOC-PRP-046; AS-DOC-PRP-047; AS-CODE-PRP-006; AS-CODE-PRP-007; AS-CODE-PRP-008; AS-CODE-PRP-009; AS-CODE-PRP-010

`Various`/`Various Artists` never gets a bilingual name. Otherwise, evidence
that the artist's own Discogs credit is Japanese-only text (not merely a
title that happens to contain Japanese characters) is taken only from a
matched release: the first matched release of the artist whose detail has
an artist credit is used, its trailing disambiguation suffix stripped and
invisible characters removed, kept only if it contains Japanese script. If
no matched release yields qualifying evidence, there is no bilingual name.
With qualifying evidence, the bilingual name requires the source's own name
to itself pass the romanized-text check (`AS-PRP-028`) — otherwise there
would be no romanized half to join — and is then `{TitleCased romanized} =
{raw Japanese Discogs text}`. Once set for one release, every release of
that artist in the session shares the same artist folder, Artist and Album
Artist tags, including a release with no Discogs match of its own (whose
own album stays as recognized).

Example: Discogs artist `マキシマム ザ ホルモン` → artist folder, `artist`
and `albumArtist` = `Maximum The Hormone = マキシマム ザ ホルモン`.
`Maximum the Hormone\1990 Kusoban`, status `not-found` → artist folder
`Maximum The Hormone = マキシマム ザ ホルモン`, album `Kusoban`.

### AS-PRP-030 — A Latin-script Discogs artist gets no Japanese name, even on a partly-Japanese release title
Status: Draft | Source: AS-DOC-PRP-048

Example: Discogs `Iron Maiden` / `Killers (地獄の処刑台)` → artist folder
`Iron Maiden`, `albumArtist = Iron Maiden`.

### AS-PRP-031 — Discogs text already in "X = Y" form, or without Japanese script, stays as is
Status: Draft | Source: AS-DOC-PRP-049

Example: Discogs artist `Iron Maiden` → `Iron Maiden` (no ` = ` part).

### AS-PRP-032 — Matched-release title follows the same bilingual pairing convention as the artist
Status: Draft | Source: AS-DOC-PRP-044 (partial); AS-CODE-PRP-012

The title is the romanized local title (`AS-PRP-028`) joined bilingually
with Discogs' own title (invisible characters removed). If Discogs already
carries both halves of its own "X = Y" convention, that is passed through
unchanged; the source's local romanized text is added only when Discogs'
title is Japanese-only and the source has its own romanized text to
contribute.

Example: Discogs track `ニトロBB戦争`, source title tag `Nitro Bb Sensou` →
title `Nitro Bb Sensou = ニトロBB戦争`.

### AS-PRP-033 — Each track title follows the same bilingual pairing rule, per track
Status: Draft | Source: AS-CODE-PRP-043

When Discogs tracks are used, the romanized half for a given track is the
existing tag title if it is romanized text, else the file-name-derived title
if that is romanized text, else nothing; this is joined bilingually with
the Discogs track's own title (invisible characters stripped), the same
`"X = Y"` convention as the album title (`AS-PRP-032`).

### AS-PRP-034 — A per-track Discogs credit that matches the release artist reuses the release's own (possibly bilingual) artist text
Status: Draft | Source: AS-CODE-PRP-048

The release's artist tag may be a bilingual `"Romanized = Original"` string.
If a per-track Discogs credit (`AS-PRP-052`) normalizes equal to either half
of that string, the full bilingual text is used for the track instead of
the raw Discogs credit — so an ordinary non-compilation release reads
bilingually on every track, not only at the release level.

## Track numbers and file names

### AS-PRP-035 — Track file name is "{NN} {title}.{ext}"
Status: Draft | Source: AS-DOC-PRP-017; AS-CODE-PRP-042

The proposed file name follows the track file template (default
`{trackNumber} {title}`), with the zero-padded file number and the
sanitized title substituted, and the track's own detected format appended
as the extension.

Example: `TrackFileTemplate = "{trackNumber} {title}"`, file number `7`
padded to width 2, title `"Asozan"`, format `mp3` → `"07 Asozan.mp3"`. `01 -
Airbag.flac` → `01 Airbag.flac`.

### AS-PRP-036 — The file number pad width is the larger of the pad setting and the digits needed for the release's highest file number
Status: Draft | Source: AS-DOC-PRP-018; AS-CODE-PRP-041

This is the caller-side half of the matching-area pad-width formula
(`AS-MAT-076`/`077`, primary): the pad width passed to file names uses
`TotalTrackCount` = the release's highest resolved file number
(`AS-PRP-039`), `MinWidth` = the caller's `trackNumberPadWidth` (default 2).

Example: pad width 3, two tracks → `001 Track One.flac`, `002 Track
Two.flac`. Default pad width, two tracks → `01 Track One.flac`, `02 Track
Two.flac`.

### AS-PRP-037 — Disc number is always set, 1-based, from the disc group's own first-seen order — not parsed from the folder name
Status: Draft | Source: AS-DOC-PRP-019; AS-CODE-PRP-051

Every track gets a 1-based disc number, also on a single-disc release. The
`discNumber` tag is the 1-based position of the track's `discFolder` group
in the order those groups were first encountered while scanning tracks — it
is not parsed out of the `discFolder` name itself.

Example: single-disc `01 - I Still Do.flac` → `proposedDiscNumber = 1`,
`tags.discNumber = 1`.

### AS-PRP-038 — Tracks are grouped into discs by `discFolder`, in first-seen order
Status: Draft | Source: AS-CODE-PRP-033

A single-disc release (every track's `discFolder` is `null`) naturally
collapses into exactly one group, which becomes disc 1.

### AS-PRP-039 — Multi-disc: file numbers run continuously across discs, Track restarts per disc, and a missing track leaves a gap in both
Status: Draft | Source: AS-DOC-PRP-020; AS-DOC-PRP-021; AS-CODE-PRP-035

`trackNumbers` (the Track tag) restart at 1 on every disc; `fileNumbers`
(the proposed file name) keep counting continuously across all discs. Both
follow the release's real track position, so a track missing from the
source leaves a gap in both rather than shifting later tracks down.

Example (`Some Band / 2001 Box Set`, folders `CD 1`, `CD 2`, `CD 3`, two
tracks each): file `01`–`06` continuous; Track restarts `1, 2` on each disc.
Discogs `1 Cover Your Ears`, `2 Dear People`, `3 Hope`; source has `02 -
dear people`, `03 - hope` → `02 Dear People.flac` (Track 2), `03 Hope.flac`
(Track 3) — the others keep their real numbers, they do not move up.

### AS-PRP-040 — A track missing from the source, when the Discogs tracklist has one, is named in the review notes
Status: Draft | Source: AS-DOC-PRP-022

The note text itself ("missing on source: ...") is produced by track
alignment — see `AS-MAT-063` (primary) for how it's built. Here, that note
reaching the caller's notes list is what forces review (`AS-PRP-012`,
`AS-CODE-PRP-086`).

Example: `aoki takamasa / 2002 indigo rose` without track 1 →
`humanReview.required = true`, notes contain `missing on source: 1 Cover
Your Ears`.

### AS-PRP-041 — Discogs indices default to a straight 1:1 mapping when not supplied
Status: Draft | Source: AS-CODE-PRP-034

If Discogs tracks are available and no explicit index mapping is given, it
defaults to `1..Tracks.Count` — the source track order is assumed to
already line up one-to-one with the (possibly pre-aligned) Discogs
tracklist.

### AS-PRP-042 — Single-disc Discogs numbering uses the Discogs index directly for both numbers
Status: Draft | Source: AS-DOC-PRP-023; AS-CODE-PRP-036

On a single-disc source with Discogs data, both the Track tag and the file
number are simply the track's index in the full Discogs tracklist — the
position text is not used, so vinyl positions work too.

Example: Discogs `A1 A`, `A2 B`, `B1 C`; source has the 1st and 3rd → `01
A.mp3` (Track 1), `03 C.mp3` (Track 3).

### AS-PRP-043 — Multi-disc Discogs numbering is trusted only when every involved position parses cleanly; one failure falls the whole release back to file-name numbering
Status: Draft | Source: AS-DOC-PRP-024; AS-CODE-PRP-037

On a multi-disc source, disc and Track come from the Discogs position
(`1-3`, `CD2-1`, `2.05`, parsed per `AS-MAT-057`/`058`) only if every one of
the release's Discogs-aligned positions parses successfully. If even one
fails (e.g. a vinyl side label), the whole release — not just that one
track — falls back to the file-name-based numbering heuristic
(`AS-PRP-044`).

Example: Discogs `1-1 A`, `1-2 B`, `1-3 C`, `2-1 D`; source `CD 1\01 - a`,
`CD 1\02 - b`, `CD 2\01 - d` → `01 A.mp3`, `02 B.mp3`, `04 D.mp3`; discs 1,
1, 2; Tracks 1, 2, 1.

### AS-PRP-044 — Without Discogs numbering: detected file numbers are trusted only when non-inferred and in range; gaps stay
Status: Draft | Source: AS-DOC-PRP-025; AS-CODE-PRP-038

When Discogs numbering isn't used (or couldn't be trusted), each disc's
tracks are numbered from their own detected file-name number only if none
of that disc's tracks had an inferred track order and every detected number
is at least 1; otherwise the disc's tracks are numbered sequentially (1, 2,
3, …) in their current order.

Example: `04 - four.mp3`, `06 - six.mp3` → `04 Four.mp3` (Track 4), `06
Six.mp3` (Track 6) — the gap between 4 and 6 stays.

### AS-PRP-045 — Repeated source numbers on a disc force sequential renumbering, with a note that unconditionally forces review
Status: Draft | Source: AS-DOC-PRP-028; AS-CODE-PRP-039; resolves `AS-DOC-DEF-068` (see `90-contradictions-resolution.md`)

When two files on one disc have the same detected number, the disc is
renumbered 1, 2, 3… in order, and a note is added:
`"track numbers from source file names are not unique on disc <N>;
renumbered sequentially"`. Plan 06 says this also forces review; re-reading
the caller (not just this helper in isolation) confirms it: any note
returned by track-set building — this one included — unconditionally sets
`requiresReview = $true` (`AS-PRP-012`). The phase-1/phase-2 split looked at
different layers of the same call chain, which is why neither source alone
confirmed both halves.

Example: `01 - a.mp3`, `01 - b.mp3` → `01 A.mp3`, `02 B.mp3`; note `track
numbers from source file names are not unique on disc 1; renumbered
sequentially`.

### AS-PRP-046 — Without Discogs numbering, a later disc numbered continuously from the previous disc has its running offset removed
Status: Draft | Source: AS-DOC-PRP-026; AS-DOC-PRP-027; AS-CODE-PRP-040

The file number of a later disc is its Track plus the sum of the highest
Track of each earlier disc. But when every detected number on a later disc
already exceeds that running offset (a rip that numbered its files
continuously, e.g. `CD2\11 - ...`), the offset is subtracted back out so
Track still restarts at 1 — file numbers stay continuous across the release
either way.

Example (offset case): `CD 1\01 - a`, `CD 1\03 - c`, `CD 2\02 - e` → `01
A.mp3`, `03 C.mp3`, `05 E.mp3`; Tracks 1, 3, 2. Example (continuous case):
`CD 1\01`, `CD 1\02`, `CD 2\03`, `CD 2\04` → `01 A.mp3` … `04 D.mp3`; Tracks
1, 2, 1, 2.

### AS-PRP-047 — Inferred track order: numbered sequentially, no note
Status: Draft | Source: AS-DOC-PRP-029

When the file names had no numbers and recognition inferred the order, the
tracks are numbered 1, 2, 3… with no note.

Example: `Alpha Song.flac`, `Beta Song.flac` → `01 Alpha Song.flac`, `02
Beta Song.flac`.

### AS-PRP-048 — A stray track outside the disc folders gets the next disc number
Status: Draft | Source: AS-DOC-PRP-030; carried forward as a suspected defect: see `91-suspected-defects-carryforward.md` (`CF-PRP-003`)

A track that sits outside the disc folders of a multi-disc release gets its
own disc number after the last disc folder (it becomes the next group in
first-seen order, `AS-PRP-038`); its Track is 1, its file number continues
after the last disc.

Example: `2003 Mescalero` with `CD 1` (2 tracks), `CD 2` (3 tracks) and
`Stray Bonus Track.mp3` → `06 Stray Bonus Track.mp3`, disc 3, Track 1 —
creating a third disc that doesn't really exist.

### AS-PRP-049 — Cue sheet tracks are named like separate files
Status: Draft | Source: AS-DOC-PRP-031

Each virtual track of a cue sheet gets its own proposed file name, number
and tags, the same as a separate file; its title comes from the cue track
title. The cue split itself: see `10-apply.md` (not yet merged).

Example: `Live In Concert.flac` with cue titles `Speak To Me`, `Breathe` →
`01 Speak To Me.flac`, `02 Breathe.flac`.

## Track titles

### AS-PRP-050 — Matched: the title is the Discogs track title, feat./mix/remix words stay
Status: Draft | Source: AS-DOC-PRP-032

With a Discogs match, `proposedTitle` and the title tag are the Discogs
track title (joined bilingually per `AS-PRP-033` when applicable). Feat.
artist, mix, remix and remaster words stay in the title.

Example: Discogs `Nothing Else Matters (feat. Justin Bieber)` → title tag
`Nothing Else Matters (feat. Justin Bieber)`.

### AS-PRP-051 — Not matched: the title tag wins, else the file name's title part — except on a tagless compilation track, where the file-name title part wins over a plain title-cased fallback
Status: Draft | Source: AS-DOC-PRP-033; AS-CODE-PRP-044; AS-CODE-PRP-045; AS-CODE-PRP-046

Without Discogs tracks, an existing title tag is used (Title Cased) if
present. Otherwise: on a compilation track with no existing Artist tag but
a file-name-derived artist (`AS-PRP-056`) and a distinct parsed title part,
the title is that parsed title part — kept separate from the artist half
rather than leaving the whole "Artist - Title" string as the title. In
every other case, the title is simply the title part parsed from the
original file name, Title Cased.

Example: existing title tag `Rock/Roll: Live` → title `Rock/Roll: Live`.
`04 - four.mp3` with no tags → title `Four`.

### AS-PRP-052 — A Discogs tracklist count mismatch always forces review; alignment is attempted, falling back to source titles only on failure
Status: Draft | Source: AS-DOC-PRP-034; AS-CODE-PRP-086; cross-referenced with `AS-MAT-059` (the alignment cascade itself, primary); carried forward: see `91-suspected-defects-carryforward.md` (`CF-PRP-005`)

Discogs tracks are used as-is only when their count exactly equals the
source track count. Any mismatch forces review unconditionally and attempts
the title-then-number alignment cascade (`AS-MAT-059`–`065`): on success, a
note states the alignment method plus any missing-tracks detail; on
failure, the note states the fallback to source titles and no Discogs-
derived numbering/titles/credits are used at all for this release's tracks.
The app never drops or invents a track either way.

Example: source `01 - Airbag`, `02 - Paranoid Android`; Discogs has 3 tracks
→ `humanReview.required = true`, titles `Airbag`, `Paranoid Android`.

## Artist, Album Artist and compilation flag

### AS-PRP-053 — Album Artist is the artist folder name and never holds a feat. artist; the Artist tag never holds one either
Status: Draft | Source: AS-DOC-PRP-035

The Album Artist tag is `proposed.artistFolderName` on every track — never a
feat. artist, even when Discogs credits one on a track. The Artist tag
never holds a feat. artist either.

Example: track `Nothing Else Matters (feat. Justin Bieber)` → `albumArtist
= Metallica`, `artist = Metallica`.

### AS-PRP-054 — Artist equals Album Artist by default
Status: Draft | Source: AS-DOC-PRP-036; AS-CODE-PRP-050

On a non-compilation release with no Discogs per-track credit, the Artist
tag is always the Album Artist — no filename- or tag-based per-track artist
is ever considered. The file's own existing Artist tag is not used.

Example: release artist `Some Artist`, file Artist tag `Some Other Name` →
`artist = Some Artist`, `isCompilation = false`.

### AS-PRP-055 — A Discogs per-track credit sets the track Artist on any release, not only compilations
Status: Draft | Source: AS-DOC-PRP-037; AS-CODE-PRP-047; resolves `AS-DOC-DEF-061` (see `90-contradictions-resolution.md`)

When the matched Discogs tracklist has an artist credit for a track
(`AS-MAT-066`–`069`), that credit takes priority over every other source for
the track's Artist tag, on any release — including a split release that is
not a compilation. The Album Artist does not change. A credit matching the
release artist reuses the release's own (possibly bilingual) text
(`AS-PRP-034`).

Example: non-compilation `Some Artist`, Discogs track credit `The Dubliners`
→ `artist = The Dubliners`, `albumArtist = Some Artist`, `isCompilation =
false`.

### AS-PRP-056 — Compilation without a Discogs credit: tag artist, then file-name artist, then Album Artist with a review note
Status: Draft | Source: AS-DOC-PRP-038; AS-DOC-PRP-039; AS-DOC-PRP-040; AS-CODE-PRP-049; resolves `AS-DOC-DEF-060` (see `90-contradictions-resolution.md`)

On a compilation, a track with no Discogs credit takes: the track's existing
Artist tag (Title Cased) if present; else the file-name-parsed artist
(Title Cased) if present; else the release's own Album Artist (e.g.
`"Various"`), with a note — `"Track <N>: no track artist from Discogs or
file tags; Artist set to '<Names.Artist>'."` — and the release needs review.
The file-name step exists in the code even though neither the README nor
plan 06 names it as a step.

Example: file Artist tag `johnny mcevoy` → `artist = Johnny Mcevoy`,
`albumArtist = Various`. `[01] Blind Guardian - Don't Talk To Stranger.mp3`,
no tags → `artist = Blind Guardian`, title `Don't Talk To Stranger`, no
note (the file-name step needs no review). `01 - a.mp3` on compilation
`Various / Some Compilation`, no tags, no file-name artist → `artist =
Various`, note contains `no track artist from Discogs or file tags`.
Carried forward: title-casing an all-lowercase tag artist can't restore
real inner capitals — see `91-suspected-defects-carryforward.md`
(`CF-PRP-006`).

### AS-PRP-057 — The track compilation flag equals the release compilation flag
Status: Draft | Source: AS-DOC-PRP-043

Example: `Cranberries` (not a compilation) → `tags.isCompilation = false` on
every track.

### AS-PRP-058 — A "Various" release is a compilation; the release artist folder, Album Artist and every track's compilation flag follow
Status: Draft | Source: AS-DOC-PRP-041

The detection rule itself is the matching-area rule, primary:
`AS-MAT-070`/`071` (Discogs artist id 194/name "Various" when matched; the
folder/recognized name being `Various`/`Various Artists` when not). This
item adds what being a compilation changes here: `proposed.isCompilation =
true`, artist folder and Album Artist `Various`, and the compilation flag
set on every track.

Example: `Various / Our Best Irish Pub Songs`, Discogs artist `Various` (id
194) → `isCompilation = true`, artist folder `Various`, track 1 `artist =
The Dubliners`, `albumArtist = Various`, `tags.isCompilation = true`. How
apply writes the flag (`TCMP` / `cpil` / `COMPILATION`): see `10-apply.md`
(not yet merged).

### AS-PRP-059 — Tracks by many different artists under one normal artist folder are retried and reproposed as a "Various" compilation
Status: Draft | Source: AS-DOC-PRP-042; AS-CODE-PRP-083; AS-CODE-PRP-084; resolves `AS-DOC-DEF-059` (see `90-contradictions-resolution.md`)

The evidence rule ("looks like Various") is the matching-area rule, primary:
`AS-MAT-072`–`075`. When the folder-artist search didn't already match and
the tracks look like Various, a brand-new Discogs search is performed with
artist literally `'Various'` — not a retry of the original search — which
always forces review and adds a note naming the distinct-artist count found.
A Various-Artists fallback release never inherits the original artist's
shared bilingual display name (`AS-PRP-029`) — a `'Various'` compilation
never gets another artist's bilingual folder/tag text. When the folder-
artist search already matched, nothing changes.

Example: `DIO\1999 - Holy Dio` with track artists Blind Guardian, Primal
Fear, Doro → artist folder `Various`, `isCompilation = true`, track Artists
`Blind Guardian`, `Primal Fear`, `Doro`, `albumArtist = Various`, review
required. `Radiohead\1997 OK Computer` matched under `Radiohead` → artist
folder `Radiohead` (no retry).

## Cover art

### AS-PRP-060 — Cover candidates list Discogs images and existing covers, each with a source label
Status: Draft | Source: AS-DOC-PRP-050

`coverArt.candidates` holds all Discogs images of the selected release, plus
any embedded or loose cover found by recognition. Each candidate has a URL
or path, a source label (`sourceEdition`), width and height.

Example: matched `OK Computer` with an embedded cover → 2 candidates, one
labelled `existing (embedded)`. `ZZ Top\1999 XXX\cover.jpg` → candidate
`sourceEdition = existing (local)`, `width = 1`, `height = 1`.

### AS-PRP-061 — A decodable embedded cover is always offered first and is the default choice, even when Discogs also has images
Status: Draft | Source: AS-DOC-PRP-051; AS-CODE-PRP-054; resolves `AS-DOC-DEF-054` (see `90-contradictions-resolution.md`)

The first track carrying an embedded cover contributes an `'existing
(embedded)'` candidate, added before any Discogs-derived candidates and
independent of whether the release matched on Discogs. When it decodes
(`AS-PRP-062`), it is the chosen cover even when Discogs has images — the
Discogs images stay in the list so the user can switch.

Example: embedded `existing-cover.jpg` (a real 2×2 PNG) + Discogs image →
`chosenCandidateUrl = <path of existing-cover.jpg>`.

### AS-PRP-062 — An embedded cover that cannot be decoded is dropped as a candidate, not just left unchosen
Status: Draft | Source: AS-DOC-PRP-052; AS-CODE-PRP-052; AS-CODE-PRP-053; AS-CODE-PRP-055

Image dimensions are read with `System.Drawing` on a long-path-safe path.
Any failure (missing file, corrupt data, unsupported format) is caught and
reported as a sentinel `{ Width = 1; Height = 1 }` instead of throwing. When
the embedded cover reports exactly this 1×1 sentinel, it is skipped
entirely, as if there were no embedded cover — preventing a garbage
embedded picture from becoming the default choice and failing the resize at
apply time. Carried forward: this sentinel is indistinguishable from a
genuine 1×1 source image — see `91-suspected-defects-carryforward.md`
(`CF-PRP-001`).

Example: embedded `existing-cover.jpg` with content `not-a-real-image` + one
Discogs image → 1 candidate, no `existing (embedded)`, chosen cover is not
the embedded file.

### AS-PRP-063 — Without Discogs images, every local companion cover file is a candidate — with no decodability check
Status: Draft | Source: AS-DOC-PRP-053; AS-CODE-PRP-058; carried forward as a suspected defect: see `91-suspected-defects-carryforward.md` (`CF-PRP-002`)

If there is no match, or the match has neither pressing images nor master
images, every local companion file of kind `cover` becomes a candidate
labeled `'existing (local)'`, dimensions read the same way as the embedded
check (`AS-PRP-062`) — but, unlike the embedded case, an undecodable local
cover is **not** dropped: it stays a candidate and can still be chosen.

Example: `Some Band\2010 Some Album\cover.jpg` (kind `cover`, content
`not-a-real-image`) → 1 candidate `existing (local)`, `chosenCandidateUrl =
<path of cover.jpg>`, `width = 1`, `height = 1` (the "could not decode"
sentinel, chosen anyway).

### AS-PRP-064 — Matched-pressing images are labeled "<country> <format>", primary vs. alternate
Status: Draft | Source: AS-CODE-PRP-056

When the matched pressing's own images are non-empty, each becomes a
candidate labeled `"<country> <format name>"` (trimmed), or the literal
fallback `'unknown edition'` if that combination is blank. A Discogs image
of type `'primary'` uses the label as-is; any other type gets `"
(alternate)"` appended.

### AS-PRP-065 — With only Discogs images, the primary pressing image is chosen; a pressing with no images falls back to the master's images
Status: Draft | Source: AS-DOC-PRP-054; AS-CODE-PRP-057

When there is no usable existing cover, the Discogs primary image is the
chosen cover. This reuses the matching-area rule, primary: `AS-MAT-046`
("the master's image is a fallback cover candidate"). Here specifically: if
the match is `matched` but the pressing has no images and the match has a
master with its own images, those are used instead, labeled `'master (main
release)'` (primary) or `'master (main release) (alternate)'` — a known
pressing with no photos (e.g. a "NO NUMBER" edition) still gets a
better-than-nothing default.

Example: Discogs release 265498, primary image → `chosenCandidateUrl =
https://i.discogs.com/example/full-265498.jpg`. The user can change it in
the review UI: see `09-review-ui.md` (not yet merged).

### AS-PRP-066 — Default cover choice priority: embedded, then the first non-alternate candidate, then anything
Status: Draft | Source: AS-CODE-PRP-059

The pre-selected `chosenCandidateUrl` is the embedded candidate if present;
otherwise the first candidate whose `sourceEdition` does not end in `"
(alternate)"`; otherwise simply the first candidate in the list. All
discovered candidates remain listed regardless — only the default selection
follows this priority.

### AS-PRP-067 — No cover anywhere: empty list, chosen cover empty, forced review
Status: Draft | Source: AS-DOC-PRP-055; AS-CODE-PRP-087

When neither Discogs nor the source has a cover, the candidate list is
empty and the chosen cover is empty. The release needs review, note `No
cover art candidates found from Discogs or local companion files.`

Example: `Some Band / 2010 Some Album` without images → `candidates = []`,
`chosenCandidateUrl = null`, `humanReview.required = true`.

### AS-PRP-068 — The cover target size is the `coverMaxDimension` setting
Status: Draft | Source: AS-DOC-PRP-056

`coverArt.targetMaxDimension` is the `coverMaxDimension` setting (default
600, `AS-SET-009` in [03-settings-and-secrets.md](03-settings-and-secrets.md)).
Resizing: see `10-apply.md` (not yet merged).

Example: default settings → `targetMaxDimension = 600`.

## Companion files

### AS-PRP-069 — Only "loose" companion files get a proposed rename; a nested companion keeps its path, gets no proposed name, and never causes review
Status: Draft | Source: AS-DOC-PRP-057; AS-CODE-PRP-079

A companion's `proposedFileName` is computed only when its placement is
`loose`; any other placement (e.g. nested in a subfolder) leaves it `null`,
included by default, with no review impact.

Example: `C:\src\Scans\front.jpg` (kind `cover`, nested) → `include = true`,
`proposedFileName = null`, no review.

### AS-PRP-070 — A loose companion that starts with a letter keeps its name
Status: Draft | Source: AS-DOC-PRP-058

Example: `C:\src\folder.jpg` → `proposedFileName = folder.jpg`. `cover.jpg`
→ `include = true`, `proposedFileName = cover.jpg`.

### AS-PRP-071 — A loose companion that starts with a digit gets its kind word prefixed, and always forces review
Status: Draft | Source: AS-DOC-PRP-059; AS-CODE-PRP-081

A loose companion whose name starts with a digit gets the capitalized kind
word and a space in front. `WasPrefixed` always forces
`RequiresReview = true` for the whole companion set, with a note naming the
old and new name.

Example: `01 back.jpg`, kind `booklet` → `Booklet 01 back.jpg`; note
`Companion '01 back.jpg' renamed to 'Booklet 01 back.jpg' (must start with
a letter).`, `humanReview.required = true`.

### AS-PRP-072 — Every companion file defaults to being included
Status: Draft | Source: AS-CODE-PRP-080

`include = $true` unconditionally for every companion — exclusion must be a
later, separate user action.

### AS-PRP-073 — No companion files: empty list, no review
Status: Draft | Source: AS-DOC-PRP-060

Example: `companionFiles = []` → 0 companions, no review flag from
companions.

## Target index

### AS-PRP-074 — The target index keys each well-formed "Artist\yyyy Name" folder by its stable key; anything else is skipped
Status: Draft | Source: AS-DOC-PRP-061; AS-DOC-PRP-062; AS-CODE-PRP-065

The app scans exactly two directory levels: artist folders, then release
folders inside each. A release folder name must match a 4-digit year, a
space, then the album text, or it is skipped entirely — any target folder
not in that exact shape is never indexed and so is invisible to target-
exists/comparison logic. For each match, the stable key is computed from the
folder names on disk; a lookup by stable key returns the folder path.

Example: `ArtistA\1999 AlbumOne` and `ArtistB\2005 AlbumTwo` → 2 entries.
`ArtistA\Misc` → not indexed.

### AS-PRP-075 — A missing target root gives an empty index, not an error
Status: Draft | Source: AS-DOC-PRP-063; AS-CODE-PRP-064

Example: target root that does not exist → 0 entries, no error.

### AS-PRP-076 — An unknown stable key finds nothing
Status: Draft | Source: AS-DOC-PRP-064; AS-CODE-PRP-067

`Test-ReshelfTargetReleaseExists` is a direct dictionary lookup by stable
key, returning nothing when absent.

Example: key `doesnotexist0000` → nothing.

### AS-PRP-077 — A stable-key collision in the target index keeps only the first folder found, silently
Status: Draft | Source: AS-DOC-PRP-065; AS-CODE-PRP-066; carried forward as a suspected defect: see `91-suspected-defects-carryforward.md` (`CF-PRP-004`)

When two target folders normalize to the same stable key, only the first
one encountered is kept in the index — the scan does not fail, and no
warning or review note is produced; the other folder becomes invisible to
target-exists/comparison logic.

Example: `ZZ Top\1999 XXX` and `zz  top\1999 XXX` → 1 entry.

## Lossy "sameness" and the previous-lossy ledger

### AS-PRP-078 — Lossy-release "sameness" is decided by overlapping search-title variants, not exact text match
Status: Draft | Source: AS-CODE-PRP-060

Two album names are the same release if any normalized Discogs search-title
variant (`AS-MAT-002`–`005`) of one name equals any normalized variant of
the other — not requiring an exact string match, to bridge an old lossy
import's messy folder-derived name against a later lossless import's
Discogs-matched name.

Example: old album name `"Forwards Special Edition"` vs. new name
`"Forwards"` → considered the same release, because their search-title
variant sets intersect.

### AS-PRP-079 — The previous-lossy ledger lookup trusts a direct stable-key match only if it is still pending
Status: Draft | Source: AS-CODE-PRP-061

The function first looks up the ledger entry for the exact `StableKey`
given; it is used only if that entry's status is `pending-upgrade`.

### AS-PRP-080 — A fallback ledger scan matches by exact year, normalized artist and fuzzy album name, with no further disambiguation among ties
Status: Draft | Source: AS-CODE-PRP-062; carried forward as a suspected defect: see `91-suspected-defects-carryforward.md` (`CF-PRP-007`)

If no direct stable-key match is found (or it isn't pending), every
`pending-upgrade` entry is scanned for one whose year matches exactly,
whose normalized artist equals the input artist, and whose album is the
"same lossy release" (`AS-PRP-078`) — handling a source folder renamed
between the lossy and lossless import, which changes its computed stable
key. The first matching entry wins, with no further disambiguation.

### AS-PRP-081 — Whether the previous-lossy target still exists is always re-checked live, never trusted from the ledger
Status: Draft | Source: AS-CODE-PRP-063

The folder-exists check (folder exists and contains at least one audio
file) is computed fresh on every call, since the ledger record itself
doesn't track whether that folder was later deleted or moved.

## Target comparison

### AS-PRP-082 — The proposed target path is always the fixed two-level "TargetRoot\Artist\Release" layout
Status: Draft | Source: AS-CODE-PRP-088

`proposedTargetPath` is always `Join-Path TargetRoot ArtistFolderName
ReleaseFolderName` — no deeper or shallower structure exists anywhere in
this function.

### AS-PRP-083 — Each release gets exactly one target action
Status: Draft | Source: AS-DOC-PRP-066

Each release gets a `targetAction`: `create-new`, `skip-existing-identical`,
`update-existing` or `conflict`. The comparison runs after the Discogs
lookup and does not depend on the match result.

Example: empty target, `Some Band / 2010 Some Album` → `create-new`.

### AS-PRP-084 — Target comparison identity is a content hash of the release's own source files
Status: Draft | Source: AS-CODE-PRP-068

The release's identity for "is this already applied / already the same"
purposes is a hash computed over the unique set of source file paths across
all of its tracks.

### AS-PRP-085 — A second release with the same stable key in one session is a conflict against the first occurrence
Status: Draft | Source: AS-DOC-PRP-073; AS-CODE-PRP-078

When two releases in one run have the same stable key, the first is
compared with the target as usual; the later one is instead compared with
the first. When the content differs, it is `conflict`. Session-seen state
(by stable key, and separately by proposed path) is updated for every
release; the first claimant of a path always wins, so a later release
proposing the same path compares against whoever claimed it first in the
run, not the most recently processed one.

Example: `Copy One\Some Band\2010 Some Album` and `Copy Two\Some
Band\2010 Some Album` with different content → first `create-new`, second
`conflict`.

### AS-PRP-086 — A valid apply-log entry with the matching source hash gives `skip-existing-identical`, even over renamed/retagged target files
Status: Draft | Source: AS-DOC-PRP-067

First, the app checks the apply log. When it has an `applied` entry for
this stable key, its target path is still under the target root and still
exists, and its recorded source file-set hash equals the current source
hash, the action is `skip-existing-identical`. A second run on an unchanged
source gives `skip-existing-identical` for every release, even though apply
renamed and re-tagged the target files.

Example: source `01 - Track.flac` (`source-content`), target `Some
Band\2010 Some Album\01 Track.flac` (different size), apply-log entry with
the source hash → `skip-existing-identical`. The apply log itself: see
`10-apply.md` (not yet merged).

### AS-PRP-087 — A stale or failed apply-log entry does not cause a skip
Status: Draft | Source: AS-DOC-PRP-068

When the apply-log hash does not match the current source, or the entry
status is `failed`, the app does not skip — it continues with the folder
comparison.

Example: recorded hash `stale-hash-from-a-prior-apply`, target content
differs → `conflict`. Entry status `failed`, target
`partially-written-content` → `conflict`.

### AS-PRP-088 — The existing target folder is found through a fixed priority chain, same-session evidence first
Status: Draft | Source: AS-DOC-PRP-069; AS-CODE-PRP-070

When there is no same-session duplicate (`AS-PRP-085`) and no apply-log skip
(`AS-PRP-086`), the baseline is found in this order, stopping at the first
hit: (a) a same-session duplicate already seen this run under the same
stable key; (b) a different stable key that already claimed this exact
proposed target path earlier in the same run; (c) a valid apply-log entry
for this stable key whose recorded source-file-set hash matches; (d) an
existing on-disk folder, found via — in order — the apply-log entry's own
recorded target path (if still valid), else the literal proposed target
path itself (if it already has audio files), else a lookup in the target
index by stable key. The docs/tests view only names the on-disk half (d) of
this chain, since the session-level checks (a)/(b) need a second release in
the same run to exercise.

Example: source `SOME BAND - SomeAlbum` (no year), proposed `Some
Band\2010 Some Album` exists with `01 Track.mp3`, no apply-log entry → that
folder is found, although its stable key differs.

### AS-PRP-089 — A source release with mixed lossless/lossy tracks is conservatively treated as lossy, with a forced review note
Status: Draft | Source: AS-CODE-PRP-069

The source is lossless only if every track is lossless. If some but not all
tracks are lossless, the release is treated as lossy for the target-action
decision, and a forced review note is always added: `"release has mixed
lossless/lossy source tracks; treated as lossy for target comparison"`.

### AS-PRP-090 — An on-disk baseline is lossless only if every file in it has a lossless extension; zero files never counts as lossless
Status: Draft | Source: AS-CODE-PRP-071

For a baseline found as an existing folder, `IsLossless` starts `true` only
when at least one audio file was found there, and flips to `false` the
moment any file's extension isn't a lossless format.

### AS-PRP-091 — Same file names and sizes as the baseline give `skip-existing-identical`
Status: Draft | Source: AS-DOC-PRP-070

When the found target folder has the same file set as the source (same
names and sizes), the action is `skip-existing-identical` — in practice,
for a target the app didn't create itself.

Example: source `01 Track.flac` and target `Some Band\2010 Some
Album\01 Track.flac`, both `same-content` → `skip-existing-identical`.

### AS-PRP-092 — A lossless source over a lossy baseline at the same path is an upgrade; at a different (older) path, the old copy is left alone and a new one is created instead
Status: Draft | Source: AS-DOC-PRP-071; AS-CODE-PRP-073 (partial); resolves `AS-DOC-DEF-056` (see `90-contradictions-resolution.md`)

When the found target folder is lossy and the source is lossless at the
*same* proposed path, the action is `update-existing`. But when the baseline
was found at a *different*, older path (e.g. via the previous-lossy ledger,
`AS-PRP-079`–`081`), the action is `create-new` instead — the old lossy copy
is left alone under its own name rather than overwritten. Details and the
other lossy cases: see `AS-LSY-017`–`021` in
[11-lossy-tracking.md](11-lossy-tracking.md).

Example: source `01 Track.flac`, target `01 Track.mp3` (same path) →
`update-existing`.

### AS-PRP-093 — A baseline that differs and is not a lossy-to-lossless upgrade is a conflict; the note distinguishes a session collision from a genuine on-disk mismatch
Status: Draft | Source: AS-DOC-PRP-072; AS-CODE-PRP-074

When `targetAction` is `conflict` because of a same-session path collision
(`AS-PRP-085`), the note names the colliding source folder path and its
stable key explicitly. Otherwise the note is the fixed text `'target
conflict: existing target differs from source and is not a lossy-to-
lossless upgrade'`. The release needs review. What approving a conflict
does: see `10-apply.md` (not yet merged).

Example: source `01 Track.flac` (`source-content`), target `01 Track.flac`
(`different-target-content`) → `conflict`, `humanReview.required = true`.

### AS-PRP-094 — The full target-action decision order, authoritative: skip (apply-log), create-new, skip (hash), create-new (renamed-lossy), update-existing, else conflict
Status: Draft | Source: AS-CODE-PRP-073; cross-references `AS-PRP-086`, `AS-PRP-088`, `AS-PRP-091`, `AS-PRP-092`, `AS-PRP-093`

`TargetAction` is decided in this exact order: (1) a matching apply-log
entry → `skip-existing-identical`; (2) no baseline found at all →
`create-new`; (3) baseline hash equals source hash → `skip-existing-
identical`; (4) source lossless, baseline not lossless, baseline at a real,
different path than the proposed one → `create-new`; (5) source lossless,
baseline not lossless, same path → `update-existing`; (6) anything else →
`conflict`.

### AS-PRP-095 — `update-existing` is never itself a reason for review
Status: Draft | Source: AS-DOC-PRP-074

Example: lossless `Some Band / 2010 Some Album` over a lossy target →
`update-existing`, no review reason from the target comparison itself.

### AS-PRP-096 — Every release has a stable key from its normalized artist, album and year
Status: Draft | Source: AS-DOC-PRP-075

Every release has a `stableKey` (16 lowercase hex characters, see `AS-DAT-064`
in [01-data-and-storage.md](01-data-and-storage.md)): a deterministic ID made
from its normalized artist, album and year. The target comparison uses it to
find "the same" release.

Example: `ZZ Top` / `XXX` / 1999 and `zz  top` / `XXX` / 1999 → the same
key. `Cranberries / Everybody Else Is Doing It` → `fc6337eecc96a4aa`.

### AS-PRP-097 — The lossy/lossless summary action has its own priority, independent of `targetAction`; a lossy-sourced release re-upserts its ledger entry on every run
Status: Draft | Source: AS-CODE-PRP-075; AS-CODE-PRP-076; AS-CODE-PRP-077

`lossyLossless.action` is: `'replace-existing'` when `targetAction` is
`update-existing`; else `'log-for-upgrade'` when the source is lossy; else,
if a previous-lossy ledger match was found (`AS-PRP-079`/`080`),
`'previously-lossy-different-location'` (old folder still exists) or
`'previously-lossy-target-missing'` (it doesn't) — the note's wording
differs accordingly, and apply never automatically deletes or touches the
old folder either way, the message is advisory only; else `'none'`.
Independently of this decision, whenever the source is lossy, the ledger
entry is upserted unconditionally on every run — a release pending upgrade
keeps its `lastCheckedUtc` advancing across repeated proposal runs rather
than being written only once. The ledger's own lifecycle: see
[11-lossy-tracking.md](11-lossy-tracking.md).

## Applying a chosen Discogs version (manual re-pick)

### AS-PRP-098 — Picking a Discogs candidate fetches the release (and its master) live, bypassing the cached match pipeline, and recomputes the whole release
Status: Draft | Source: AS-DOC-PRP-076; AS-CODE-PRP-090; carried forward: see `91-suspected-defects-carryforward.md` (`CF-PRP-008`, `CF-PRP-009`)

When the user picks a Discogs candidate for an ambiguous release, the app
fetches that release's full detail directly (bypassing the Discogs match
cache/search pipeline used for the batch run), and its master too if it has
one — so the manual pick still benefits from the same master-year
(`AS-PRP-022`) and master-cover-fallback (`AS-PRP-065`) priority as an
automatic match. It recomputes the artist folder, album, year, track
titles, file names, cover candidates, chosen cover and target action from
it. The match status becomes `matched` and the chosen id is stored; the
candidate list stays unchanged. Unlike the batch path (`AS-PRP-010`,
`AS-PRP-059`), this path never forwards recognition's own review flag/
reasons, and never computes Various-Artists evidence at all — a
compilation release re-picked this way loses the file-name-artist fallback
tier (`AS-PRP-056`) for tracks with no existing Artist tag and no Discogs
per-track credit.

Example: `Amagrama / 2005 Volumen 1` (ambiguous), pick 265498 → `status =
matched`, `selectedReleaseId = 265498`, artist folder `Radiohead`, album
`OK Computer`, year 1997, titles `Airbag`, `Paranoid Android`, `Subterranean
Homesick Alien`, file `01 Airbag.flac`, chosen cover
`https://i.discogs.com/example/full-265498.jpg`, `targetAction =
create-new`. The UI picker: see `09-review-ui.md` (not yet merged).

### AS-PRP-099 — The romanized half is stripped back out of a possibly-already-bilingual current artist tag before resolving bilingual evidence again
Status: Draft | Source: AS-CODE-PRP-091

Because the artist name parameter here comes from the release's current
Album Artist tag — which may already be a bilingual `"Romanized =
Original"` value from an earlier run — the code keeps only the first
(romanized) half before resolving bilingual evidence (`AS-PRP-028`/`029`)
and building the new names.

### AS-PRP-100 — If this one re-picked release has no bilingual evidence of its own, a sibling's already-proposed bilingual name is reused
Status: Draft | Source: AS-CODE-PRP-092

Sibling releases of the same artist are scanned for one whose already-
proposed artist folder name is bilingual, with a romanized half matching
(after normalization) this artist — reusing an artist-level decision so a
single manual re-pick doesn't regress the whole artist back to a
romanized-only name.

### AS-PRP-101 — Cross-release collision/upgrade state for a single re-pick is rebuilt from scratch from the sibling releases, not accumulated incrementally
Status: Draft | Source: AS-CODE-PRP-093

Since only one release is being recomputed, the session-seen state a full
batch run builds incrementally is instead constructed up front from every
sibling's own stored tracks and already-proposed target path — so the
single re-pick still participates correctly in the same cross-release
target-collision and lossy-upgrade detection a full run would apply.

### AS-PRP-102 — Defaults for pad width, cache TTL and rate limit are independently hardcoded here too, same values as the batch run
Status: Draft | Source: AS-CODE-PRP-095

Same values as `AS-PRP-004` (pad width 2, cache TTL 30 days, rate limit
55/minute) — all optional parameters here, whereas the batch run requires
cache TTL and rate limit to be supplied by its own caller.

### AS-PRP-103 — The manual re-pick's return shape is flatter than the full proposal document
Status: Draft | Source: AS-CODE-PRP-096; carried forward: see `91-suspected-defects-carryforward.md` (`CF-PRP-010`)

The result omits fields the full proposed-release document carries (e.g.
`stableKey`, `recognizedTitle`, `sourceFolderPath`, `cueSheets`,
`recognitionConfidence`) and does not nest review state under a
`humanReview` object — `requiresReview` and `notes` are returned as plain
top-level fields instead.

### AS-PRP-104 — After a pick, a sibling with the same stable key and different source content is a conflict
Status: Draft | Source: AS-DOC-PRP-077

After a pick, the target comparison also checks the other releases of the
same proposal. When one of them has the same stable key and different
source content, the action is `conflict` and the release needs review.

Example: `Amagrama\2005 Volumen 1\01 - Track 1.flac` (`release-bytes`) and
sibling `Other Folder\sibling.flac` (`different-bytes`) with the same key →
`conflict`, review required.

### AS-PRP-105 — After a pick, a sibling that already claims the same proposed target path is a conflict, even with a different stable key
Status: Draft | Source: AS-DOC-PRP-078

The note contains `target path collision`.

Example: sibling recognized as `Amagrama / Volumen 1 / 1997`, already
proposed as `Radiohead\1997 OK Computer`; this release picks 265498
(`Radiohead\1997 OK Computer`) → `conflict`, note contains `target path
collision`.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-13 | Phase 3 merge of area PRP: 78 `AS-DOC-PRP-*` + 91 remaining `AS-CODE-PRP-*` (104 minus the 13 already absorbed into `AS-MAT-*` during the MAT merge: `AS-CODE-PRP-002`, `021`–`032`), reconciled into `AS-PRP-001`–`105`. 9 contradictions resolved (`AS-DOC-DEF-054`, `056`–`061`, `066`, `068`), one of them (`068`) requiring a fresh read of the caller beyond what either phase-1 or phase-2 excerpted. 10 suspected defects carried forward (`CF-PRP-001`–`010`, covering all 4 `AS-CODE-DEF-PRP-*` entries and the PRP-area `AS-DOC-DEF-055`, `062`, `063`, `064`, `065`, `067`). Several items reuse an already-merged `AS-MAT-*` rule (master year, master-image fallback, Various/compilation detection, the alignment cascade) rather than restating it. |
| 0.2 | 2026-10-13 | During the LSY merge: the three dangling `(not yet merged)` references to `11-lossy-tracking.md` resolved to real links, one of them repointed from a raw doc-id list to the actual `AS-LSY-017`–`021` range now that those exist. |
| 0.3 | 2026-10-13 | During the CLI merge: the dangling `(not yet merged)` reference to `12-cli.md` resolved to a real link (`AS-CLI-012`). |
