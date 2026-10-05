# 08 — Proposal: naming and tags (as-is, from docs and tests)

Status: Draft | Version: 0.1 | Last updated: 2026-10-05

## Scope

What `propose` writes into `proposal.json` for each release: folder and file names, tag values, track positions, per-track artist and the compilation flag, bilingual Japanese names, cover art choice, companion file names, target comparison, and what happens when the user picks a Discogs version. Owned inputs:

- `legacy/tests/Reshelf.EditProposal.Tests.ps1` — Describe blocks `New-ReshelfProposedTrackSet (private) - real track positions` (with Context `per-track Artist selection`), `Build-ReshelfTargetIndex and Test-ReshelfTargetReleaseExists`, `New-ReshelfCompanionProposal (private)`, `Invoke-ReshelfEditProposal` (Contexts `naming and tagging`, `bilingual (Japanese) release naming`, `cover art`, `target comparison`, and the two top-level tests), `Update-ReshelfReleaseForDiscogsSelection`.
- `legacy/tests/fixtures/expected/proposal.json` (golden file of the pipeline test).
- `legacy/plan/06-edit-proposal-module.md` — naming, tagging, cover art, target comparison, decisions, edge cases.
- `legacy/README.md` — "2. Propose" (not "How Discogs matching works"), "Compilations", "Re-runs and duplicates", "Reference: Japanese releases".

Not here: Discogs search, scoring, master/version choice and track alignment (see [07-proposal-matching.md](07-proposal-matching.md)). Text normalization, title case and safe-name character rules (see [02-text-and-naming-rules.md](02-text-and-naming-rules.md)). The lossy parts of the proposal (see [11-lossy-tracking.md](11-lossy-tracking.md)). Settings defaults (see [03-settings-and-secrets.md](03-settings-and-secrets.md)).

Placeholders and magic values in this file:

| Value | Meaning | Where it shows |
|---|---|---|
| `1900` | Placeholder year when the year is unresolved | AS-DOC-PRP-011 |
| `2` | Default minimum width of the track file number | AS-DOC-PRP-018 |
| `600` | Cover target size (`coverMaxDimension`) | AS-DOC-PRP-056 |
| `Various` | Album Artist and artist folder of a compilation | AS-DOC-PRP-041 |
| `194` | Discogs artist id of "Various" | AS-DOC-PRP-041 |
| `{year} {album}` | Release folder template | AS-DOC-PRP-009 |
| `{trackNumber} {title}` | Track file template | AS-DOC-PRP-017 |
| `existing (embedded)`, `existing (local)` | Cover candidate source labels | AS-DOC-PRP-050 |
| `_` | Replacement for a character that a file name cannot hold; suffix for a reserved device name | AS-DOC-PRP-015, AS-DOC-PRP-016 |
| 16 lowercase hex characters | Stable key format, for example `fc6337eecc96a4aa` | AS-DOC-PRP-075 |

## Propose run

### AS-DOC-PRP-001 — Propose prints a run summary
Status: Draft | Source: legacy/README.md › 2. Propose

`propose -SessionId <id>` looks up every release, writes the proposal, and prints a summary: session id, artist count, release count, matched count, and needs-review count. "Matched" means confidently matched on Discogs. "Needs review" means flagged for a human look.

Example: `SessionId : 2026-09-25-0007`, `ArtistCount : 42`, `ReleaseCount : 118`, `MatchedCount : 103`, `NeedsReviewCount : 15`.

Discogs rate limit and cache: see [06-discogs-client.md](06-discogs-client.md).

### AS-DOC-PRP-002 — A propose re-run overwrites the proposal and loses review edits
Status: Draft | Source: legacy/README.md › 2. Propose

When the user runs `propose` again on the same session, it overwrites `proposal.json`. All edits made in the review UI are lost.

Example: the user edits the title of a track in the UI and saves. Then the user runs `propose -SessionId 2026-09-25-0007` again. The edit is gone.

### AS-DOC-PRP-003 — The proposal document is schema-valid
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › writes a proposal.json that validates against the proposal schema; legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › naming and tagging › sanitizes a reserved-device-name artist and a trailing-dot album title, and records both substitutions in humanReview.notes; legacy/tests/fixtures/expected/proposal.json

Propose writes `proposal.json` into the session folder. The file passes the proposal schema check. It holds `schemaVersion`, `sessionId`, `sourceRoot`, `generatedAtUtc`, `artists[]` (each with `releases[]`) and `unrecognized[]`. Each release keeps its recognition fields and adds `discogsMatch`, `proposed`, `coverArt`, `lossyLossless`, `targetAction` and `humanReview` (`required`, `resolved`, `rejected`, `notes`). Each track adds `proposedFileName`, `proposedDiscNumber`, `proposedTrackNumber`, `proposedTitle` and `tags`.

Example: session `test-session` → `<dataHome>\sessions\test-session\proposal.json`, which passes the schema check. Folder layout: see [01-data-home-and-storage.md](01-data-home-and-storage.md).

## Review flags and notes

### AS-DOC-PRP-004 — Recognition review reasons carry into the proposal review flag
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › carries Recognition's own needsReview/reviewReasons into humanReview.required, even with a clean Discogs match; legacy/tests/fixtures/expected/proposal.json › Godspeed You! Black Emperor

When recognition flagged a release for review, the proposal flags it too, even when the Discogs match is clean. The recognition reasons appear in the review notes.

Example: `OK Computer` with review reason `artist-name-split-from-folder-name` and Discogs status `matched` → `humanReview.required = true`, notes contain `artist-name-split-from-folder-name`.

### AS-DOC-PRP-005 — A release without a confident Discogs match is flagged for review
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › naming and tagging › falls back to recognized names and forces review on an ambiguous Discogs match; legacy/tests/fixtures/expected/proposal.json › Cranberries; legacy/plan/06-edit-proposal-module.md › Computing proposed names and tags

When the Discogs match status is `ambiguous` or `not-found`, the release needs review. The notes contain `Discogs match status: <status>`.

Example: `Cranberries / Everybody Else Is Doing It` with no Discogs result → `humanReview.required = true`, notes start with `Discogs match status: not-found`.

### AS-DOC-PRP-006 — Without a Discogs match, names come from recognition
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › naming and tagging › falls back to recognized names and forces review on an ambiguous Discogs match; legacy/plan/06-edit-proposal-module.md › Computing proposed names and tags

When there is no Discogs match (ambiguous or not found), the proposed artist folder name is the recognized artist name. The proposed album is the recognized title. The proposed year is the recognized year.

Example: recognized `Some Totally Different Band` / `Unrelated Album` / 2010, Discogs status `ambiguous` → `artistFolderName = Some Totally Different Band`, `album = Unrelated Album`.

### AS-DOC-PRP-007 — Review notes are one text, joined with "; "
Status: Draft | Source: legacy/tests/fixtures/expected/proposal.json › Isidor, Dance With Ghosts, ZZ Top / XXX

The review notes are one string. The parts are joined with `; `. The order in the golden file is: recognition review reasons, Discogs match status, unresolved-year note, cover note.

Example (`Isidor`): `artist-name-split-from-folder-name; Discogs match status: not-found; UNRESOLVED YEAR: placeholder value used, must be corrected before applying.; No cover art candidates found from Discogs or local companion files.`

## Release names

### AS-DOC-PRP-008 — Artist folder name comes from Discogs, without the disambiguation suffix
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › naming and tagging › produces correct names and tags for a single-disc matched release; legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › naming and tagging › keeps feat. wording out of Artist/AlbumArtist but in the title, and strips a Discogs disambiguation suffix; legacy/plan/06-edit-proposal-module.md › Computing proposed names and tags

When the release matches on Discogs, the artist folder name is the Discogs artist name. A Discogs number suffix such as ` (2)` is removed.

Example: Discogs artist `Metallica (2)` → artist folder `Metallica`.
Example: Discogs artist `Radiohead` → artist folder `Radiohead`.

### AS-DOC-PRP-009 — Release folder name is "{year} {album}"
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › naming and tagging › produces correct names and tags for a single-disc matched release; legacy/plan/06-edit-proposal-module.md › Computing proposed names and tags

The release folder name follows the release folder template. The default is `{year} {album}`. With a Discogs match, year and album come from Discogs.

Example: Discogs `OK Computer`, 1997 → `1997 OK Computer`.

### AS-DOC-PRP-010 — The edition folder name is not part of the release folder name
Status: Draft | Source: legacy/tests/fixtures/expected/proposal.json › Wrapper Band / Wrapped Album (Special Edition)

When recognition found an edition subfolder, the proposed release folder name does not contain it.

Example: recognized title `Wrapped Album (Special Edition)`, 1975, edition folder `1989 Country Label 123` → release folder `1975 Wrapped Album (Special Edition)`.

### AS-DOC-PRP-011 — An unresolved year becomes the placeholder 1900
Status: Draft | Source: legacy/tests/fixtures/expected/proposal.json › Dance With Ghosts, Isidor, PULSAR OLYMP

When the year is unresolved and Discogs gives none, the proposal uses the year `1900`. It goes into the release folder name, `proposed.year` and every track's year tag. The release needs review. The note is `UNRESOLVED YEAR: placeholder value used, must be corrected before applying.`

Example: `DANCE WITH GHOSTS - Requiem` (no year) → release folder `1900 Requiem`, `tags.year = 1900`.

The README warns the user not to keep 1900 (AS-DOC-REV-038 in [09-review-ui.md](09-review-ui.md)). No test or doc says that apply rejects 1900. Only an empty Year blocks apply.

### AS-DOC-PRP-012 — Year and Album tags match the release folder name
Status: Draft | Source: legacy/plan/06-edit-proposal-module.md › Computing proposed names and tags; legacy/tests/fixtures/expected/proposal.json › Cranberries

Every track's year tag is `proposed.year`. Every track's album tag is `proposed.album`. They are always equal to the `yyyy` and `Name` parts of the release folder name.

Example: release folder `1993 Everybody Else Is Doing It` → `tags.year = 1993`, `tags.album = Everybody Else Is Doing It`.

### AS-DOC-PRP-013 — Discogs text is used as Discogs writes it
Status: Draft | Source: legacy/plan/06-edit-proposal-module.md › Computing proposed names and tags

The proposal uses Discogs artist, album and track text exactly as Discogs returns it. It does not change the casing. Only invisible formatting characters are removed (see [02-text-and-naming-rules.md](02-text-and-naming-rules.md)).

Example: Discogs artist `edbl` → artist folder `edbl` (stays lowercase).

### AS-DOC-PRP-014 — Names from the fallback path are title-cased
Status: Draft | Source: legacy/plan/06-edit-proposal-module.md › Computing proposed names and tags; legacy/tests/fixtures/expected/proposal.json › Isidor, PULSAR OLYMP

When a name does not come from Discogs, the proposal title-cases it. Each word starts with a capital letter. Existing capitals inside a word stay. The exact rule: see [02-text-and-naming-rules.md](02-text-and-naming-rules.md).

Example: recognized `3218 (Soldier of Fortune Edition - Artwork)` → album `3218 (Soldier Of Fortune Edition - Artwork)`.
Example: recognized artist `PULSAR OLYMP` → artist folder `PULSAR OLYMP` (unchanged).

### AS-DOC-PRP-015 — Folder and file names are made safe; tags keep the original text
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › naming and tagging › keeps invalid filesystem characters in tags while sanitizing folder and file names

The proposal replaces characters that a Windows file name cannot hold. It does this only in folder names and file names. The tags and `proposedTitle` keep the original text. The character rules: see [02-text-and-naming-rules.md](02-text-and-naming-rules.md).

Example: artist `AC/DC`, album `Back In Black / Live Edition`, 1980, title `Rock/Roll: Live` → artist folder `AC_DC`, release folder `1980 Back In Black _ Live Edition`, file `01 Rock_Roll_ Live.flac`; tags `AC/DC`, `Back In Black / Live Edition`, `Rock/Roll: Live`.

### AS-DOC-PRP-016 — A name fix for a reserved name or a trailing dot is noted
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › naming and tagging › sanitizes a reserved-device-name artist and a trailing-dot album title, and records both substitutions in humanReview.notes

When the safe-name step changes a reserved device name or removes a trailing dot or space, the review notes say so.

Example: artist `CON`, album `Some Album.`, 2010 → artist folder `CON_`, release folder `2010 Some Album`; notes contain `reserved device name 'CON' suffixed with '_'` and `trailing dot/space removed`.

## Track numbers and file names

### AS-DOC-PRP-017 — Track file name is "{NN} {title}.{ext}"
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › naming and tagging › produces correct names and tags for a single-disc matched release; legacy/plan/06-edit-proposal-module.md › Computing proposed names and tags

The proposed file name follows the track file template. The default is `{trackNumber} {title}`. `NN` is the zero-padded file number. The extension of the source file stays.

Example: `01 - Airbag.flac` → `01 Airbag.flac`; `03 - Subterranean Homesick Alien.flac` → `03 Subterranean Homesick Alien.flac`.

### AS-DOC-PRP-018 — The file number width is the larger of the pad setting and the needed digits
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › naming and tagging › pads track file numbers to -TrackNumberPadWidth even when the track count itself would only need 2 digits; legacy/plan/06-edit-proposal-module.md › Computing proposed names and tags; legacy/tests/fixtures/expected/proposal.json

The file number is zero-padded to `max(trackNumberPadWidth, digits of the highest file number)`. The default pad width is 2 (see [03-settings-and-secrets.md](03-settings-and-secrets.md)).

Example: pad width 3, two tracks → `001 Track One.flac`, `002 Track Two.flac`.
Example: default pad width, two tracks → `01 Track One.flac`, `02 Track Two.flac`.

### AS-DOC-PRP-019 — Disc number is always set
Status: Draft | Source: legacy/plan/06-edit-proposal-module.md › Computing proposed names and tags; legacy/tests/fixtures/expected/proposal.json › Cranberries

Every track gets a 1-based disc number, also on a single-disc release.

Example: single-disc `01 - I Still Do.flac` → `proposedDiscNumber = 1`, `tags.discNumber = 1`.

### AS-DOC-PRP-020 — Multi-disc: file numbers run across discs, Track restarts per disc
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › naming and tagging › numbers a multi-disc release continuously across discs while tags.track restarts per disc (manifesto section 5 table); legacy/plan/06-edit-proposal-module.md › Computing proposed names and tags

On a multi-disc release, the file number counts across all discs. The Track tag and `proposedTrackNumber` restart at 1 on each disc. The Track tag has no leading zero.

Example (`Some Band / 2001 Box Set`, folders `CD 1`, `CD 2`, `CD 3`, two tracks each):

| File name | Disc | Track | Title |
|---|---|---|---|
| `01 First Track.flac` | 1 | 1 | First Track |
| `02 Second Track.flac` | 1 | 2 | Second Track |
| `03 Third Track.flac` | 2 | 1 | Third Track |
| `04 Fourth Track.flac` | 2 | 2 | Fourth Track |
| `05 Fifth Track.flac` | 3 | 1 | Fifth Track |
| `06 Sixth Track.flac` | 3 | 2 | Sixth Track |

The table comes from MANIFESTO §5 (see [02-text-and-naming-rules.md](02-text-and-naming-rules.md)).

### AS-DOC-PRP-021 — A track missing from the source leaves a gap
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › New-ReshelfProposedTrackSet (private) - real track positions › keeps a missing first track as a gap in file names and tags when Discogs is aligned; legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › naming and tagging › keeps the real track position when the source is missing a track Discogs has (plan/12 milestone 5); legacy/plan/06-edit-proposal-module.md › Computing proposed names and tags

The Track tag is the track's real position on its disc. When the source misses a track, the other tracks keep their real numbers. They do not move up.

Example: Discogs `1 Cover Your Ears`, `2 Dear People`, `3 Hope`; source has `02 - dear people`, `03 - hope` → `02 Dear People.flac` (Track 2), `03 Hope.flac` (Track 3).

### AS-DOC-PRP-022 — A track missing from the source is named in the review notes
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › naming and tagging › keeps the real track position when the source is missing a track Discogs has (plan/12 milestone 5); legacy/plan/06-edit-proposal-module.md › Edge cases

When the Discogs tracklist has a track that the source does not have, the release needs review. The notes name the missing Discogs track.

Example: `aoki takamasa / 2002 indigo rose` without track 1 → `humanReview.required = true`, notes contain `missing on source: 1 Cover Your Ears`.

How source tracks are aligned with Discogs tracks: see [07-proposal-matching.md](07-proposal-matching.md).

### AS-DOC-PRP-023 — Single disc with Discogs: the number is the index in the full Discogs tracklist
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › New-ReshelfProposedTrackSet (private) - real track positions › uses a vinyl-style tracklist index for a single-disc release; legacy/plan/06-edit-proposal-module.md › Computing proposed names and tags

On a single-disc source with Discogs data, the track number is the track's index in the full Discogs tracklist. The position text is not used, so vinyl positions work too.

Example: Discogs `A1 A`, `A2 B`, `B1 C`; source has the 1st and 3rd → `01 A.mp3` (Track 1), `03 C.mp3` (Track 3).

### AS-DOC-PRP-024 — Multi-disc with Discogs: Track from the position, file number from the full tracklist
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › New-ReshelfProposedTrackSet (private) - real track positions › uses Discogs disc-track positions on a multi-disc release, with the file number from the full tracklist; legacy/plan/06-edit-proposal-module.md › Computing proposed names and tags

On a multi-disc source with Discogs data, disc and Track come from the Discogs position (`1-3`, `CD2-1`, `2.05`). The file number is the index in the full Discogs tracklist. This works only when every aligned position can be parsed; else the source file numbers are used (AS-DOC-PRP-025). Position parsing: see [07-proposal-matching.md](07-proposal-matching.md).

Example: Discogs `1-1 A`, `1-2 B`, `1-3 C`, `2-1 D`; source `CD 1\01 - a`, `CD 1\02 - b`, `CD 2\01 - d` → `01 A.mp3`, `02 B.mp3`, `04 D.mp3`; discs 1, 1, 2; Tracks 1, 2, 1.

### AS-DOC-PRP-025 — Without Discogs: source file numbers are used, gaps stay
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › New-ReshelfProposedTrackSet (private) - real track positions › uses source file numbers when there is no Discogs data, keeping a gap in the middle; legacy/plan/06-edit-proposal-module.md › Computing proposed names and tags

Without Discogs data, the track number is the number detected in the source file name. A gap in the source numbers stays.

Example: `04 - four.mp3`, `06 - six.mp3` → `04 Four.mp3` (Track 4), `06 Six.mp3` (Track 6).

### AS-DOC-PRP-026 — Without Discogs: a later disc is offset by the highest Track of earlier discs
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › New-ReshelfProposedTrackSet (private) - real track positions › offsets a later disc by the highest track number of earlier discs without Discogs data; legacy/plan/06-edit-proposal-module.md › Computing proposed names and tags

Without Discogs data, the file number of a later disc is its Track plus the sum of the highest Track of each earlier disc.

Example: `CD 1\01 - a`, `CD 1\03 - c`, `CD 2\02 - e` → `01 A.mp3`, `03 C.mp3`, `05 E.mp3`; Tracks 1, 3, 2.

### AS-DOC-PRP-027 — Without Discogs: a continuously numbered later disc restarts Track at 1
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › New-ReshelfProposedTrackSet (private) - real track positions › restarts Track at 1 on a later disc whose source files are numbered continuously; legacy/plan/06-edit-proposal-module.md › Computing proposed names and tags

When every source number on a later disc is above the running offset, the source numbers the discs continuously. The offset is subtracted, so Track restarts at 1. The file numbers stay continuous.

Example: `CD 1\01`, `CD 1\02`, `CD 2\03`, `CD 2\04` → `01 A.mp3`, `02 B.mp3`, `03 C.mp3`, `04 D.mp3`; Tracks 1, 2, 1, 2.

### AS-DOC-PRP-028 — Repeated source numbers on a disc: renumber and add a note
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › New-ReshelfProposedTrackSet (private) - real track positions › renumbers a disc sequentially and adds a note when source file numbers repeat; legacy/plan/06-edit-proposal-module.md › Computing proposed names and tags

When two files on one disc have the same source number, the disc is numbered 1, 2, 3… in order. A note is added. The plan says this also forces review.

Example: `01 - a.mp3`, `01 - b.mp3` → `01 A.mp3`, `02 B.mp3`; note `track numbers from source file names are not unique on disc 1; renumbered sequentially`.

### AS-DOC-PRP-029 — Inferred track order: number sequentially, no note
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › New-ReshelfProposedTrackSet (private) - real track positions › numbers sequentially, with no note, when the track order was inferred (no numbers in file names); legacy/tests/fixtures/expected/proposal.json › Unnumbered

When the file names had no numbers and recognition inferred the order, the tracks are numbered 1, 2, 3… with no note.

Example: `Alpha Song.flac`, `Beta Song.flac` → `01 Alpha Song.flac`, `02 Beta Song.flac`.

### AS-DOC-PRP-030 — A stray track outside the disc folders gets the next disc number
Status: Draft | Source: legacy/tests/fixtures/expected/proposal.json › ZZ Top / Mescalero

A track that sits outside the disc folders of a multi-disc release gets its own disc number after the last disc folder. Its Track is 1. Its file number continues after the last disc.

Example: `2003 Mescalero` with `CD 1` (2 tracks), `CD 2` (3 tracks) and `Stray Bonus Track.mp3` → `06 Stray Bonus Track.mp3`, disc 3, Track 1.

### AS-DOC-PRP-031 — Cue sheet tracks are named like separate files
Status: Draft | Source: legacy/tests/fixtures/expected/proposal.json › Pink Floyd / Live In Concert (Bootleg), Wrapper Band / Per Disc Cue Album

Each virtual track of a cue sheet gets its own proposed file name, number and tags, the same as a separate file. Its title comes from the cue track title. The cue split itself: see [10-apply.md](10-apply.md).

Example: `Live In Concert.flac` with cue titles `Speak To Me`, `Breathe` → `01 Speak To Me.flac`, `02 Breathe.flac`.

## Track titles

### AS-DOC-PRP-032 — Matched: the title is the Discogs track title, with feat. and mix words
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › naming and tagging › keeps feat. wording out of Artist/AlbumArtist but in the title, and strips a Discogs disambiguation suffix; legacy/plan/06-edit-proposal-module.md › Computing proposed names and tags

With a Discogs match, `proposedTitle` and the title tag are the Discogs track title. Feat. artist, mix, remix and remaster words stay in the title.

Example: Discogs `Nothing Else Matters (feat. Justin Bieber)` → title tag `Nothing Else Matters (feat. Justin Bieber)`.

### AS-DOC-PRP-033 — Not matched: the title comes from the title tag, else from the file name
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › naming and tagging › keeps invalid filesystem characters in tags while sanitizing folder and file names; legacy/tests/Reshelf.EditProposal.Tests.ps1 › New-ReshelfProposedTrackSet (private) - real track positions › uses source file numbers when there is no Discogs data, keeping a gap in the middle; legacy/plan/06-edit-proposal-module.md › Computing proposed names and tags

Without Discogs data, the title is the existing title tag. When there is no title tag, the title is the title part of the file name, title-cased.

Example: existing title tag `Rock/Roll: Live` → title `Rock/Roll: Live`.
Example: `04 - four.mp3` with no tags → title `Four`.

### AS-DOC-PRP-034 — Discogs track count mismatch: review is required
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › naming and tagging › forces review and falls back to source titles on a Discogs tracklist count mismatch; legacy/plan/06-edit-proposal-module.md › Edge cases

When the Discogs track count differs from the source track count, the release needs review. The app never drops or invents a track. When the tracks cannot be aligned, the source titles are used. Alignment: see [07-proposal-matching.md](07-proposal-matching.md).

Example: source `01 - Airbag`, `02 - Paranoid Android`; Discogs has 3 tracks → `humanReview.required = true`, titles `Airbag`, `Paranoid Android`.

## Artist, Album Artist and compilation flag

### AS-DOC-PRP-035 — Album Artist is the artist folder name and never has a feat. artist
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › naming and tagging › keeps feat. wording out of Artist/AlbumArtist but in the title, and strips a Discogs disambiguation suffix; legacy/plan/06-edit-proposal-module.md › Computing proposed names and tags; legacy/plan/06-edit-proposal-module.md › Decisions & rationale

The Album Artist tag is `proposed.artistFolderName` on every track. It never holds a feat. artist, even when Discogs credits one on a track. The Artist tag never holds a feat. artist either.

Example: track `Nothing Else Matters (feat. Justin Bieber)` → `albumArtist = Metallica`, `artist = Metallica`.

### AS-DOC-PRP-036 — Artist equals Album Artist by default
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › New-ReshelfProposedTrackSet (private) - real track positions › per-track Artist selection (compilations and split releases) › keeps today's behavior on a non-compilation release with no Discogs per-track artist; legacy/plan/06-edit-proposal-module.md › Computing proposed names and tags

On a release that is not a compilation and has no Discogs per-track credit, the Artist tag is the Album Artist. The file's own Artist tag is not used.

Example: release artist `Some Artist`, file Artist tag `Some Other Name` → `artist = Some Artist`, `isCompilation = false`.

### AS-DOC-PRP-037 — A Discogs per-track credit sets the track Artist on any release
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › New-ReshelfProposedTrackSet (private) - real track positions › per-track Artist selection (compilations and split releases) › uses the Discogs per-track artist credit when a track has one, even on a non-compilation release (split releases); legacy/plan/06-edit-proposal-module.md › Computing proposed names and tags

When the matched Discogs tracklist has an artist credit for a track, that credit is the track's Artist tag. This applies to every release, also to a split release that is not a compilation. The Album Artist does not change. How the credit text is built from several artists and `join` text: see [07-proposal-matching.md](07-proposal-matching.md).

Example: non-compilation `Some Artist`, Discogs track credit `The Dubliners` → `artist = The Dubliners`, `albumArtist = Some Artist`, `isCompilation = false`.

### AS-DOC-PRP-038 — Compilation without a Discogs credit: the file's Artist tag, title-cased
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › New-ReshelfProposedTrackSet (private) - real track positions › per-track Artist selection (compilations and split releases) › falls back to the file's existing Artist tag on a compilation when Discogs has no per-track credit; legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › naming and tagging › gives each track its own Discogs artist credit on a Various-Artists compilation (real "Our Best Irish Pub Songs" case); legacy/README.md › Compilations

On a compilation, a track without a Discogs credit takes the file's existing Artist tag, title-cased.

Example: file Artist tag `johnny mcevoy` → `artist = Johnny Mcevoy`, `albumArtist = Various`.
Example: `Our Best Irish Pub Songs`, track 2 with no Discogs credit and file tag `Dublin City Ramblers` → `artist = Dublin City Ramblers`.

### AS-DOC-PRP-039 — Compilation without any tag: the artist part of the file name
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › New-ReshelfProposedTrackSet (private) - real track positions › per-track Artist selection (compilations and split releases) › falls back to the file-name artist on a compilation with no tags at all, and uses the title part as the title (real "Holy Dio" case)

On a compilation, a track with no Discogs credit and no Artist tag takes the artist part of its file name. The rest of the file name is the title. No "no track artist" note is added.

Example: `[01] Blind Guardian - Don't Talk To Stranger.mp3`, no tags → `artist = Blind Guardian`, `albumArtist = Various`, title `Don't Talk To Stranger`.

### AS-DOC-PRP-040 — Compilation with no track artist at all: Album Artist plus a review note
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › New-ReshelfProposedTrackSet (private) - real track positions › per-track Artist selection (compilations and split releases) › falls back to Album Artist and adds a review note on a compilation with neither a Discogs nor a file artist; legacy/plan/06-edit-proposal-module.md › Computing proposed names and tags; legacy/README.md › Compilations

On a compilation, a track with no Discogs credit, no Artist tag and no file-name artist gets the Album Artist as Artist. A note is added and the release needs review.

Example: `01 - a.mp3` on compilation `Various / Some Compilation` → `artist = Various`; note contains `no track artist from Discogs or file tags`.

### AS-DOC-PRP-041 — A "Various" release is a compilation
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › naming and tagging › gives each track its own Discogs artist credit on a Various-Artists compilation (real "Our Best Irish Pub Songs" case); legacy/README.md › Compilations; legacy/plan/06-edit-proposal-module.md › Computing proposed names and tags

The detection part is the same rule as AS-DOC-MAT-053 in [07-proposal-matching.md](07-proposal-matching.md) (primary). This entry adds what a compilation changes.

A release is a compilation when its Discogs artist is "Various" (Discogs artist id 194), or when its unmatched recognized artist or folder name is `Various` or `Various Artists`. A compilation has `proposed.isCompilation = true`, artist folder and Album Artist `Various`, and the compilation flag on every track.

Example: `Various / Our Best Irish Pub Songs`, Discogs artist `Various` (id 194) → `isCompilation = true`, artist folder `Various`, track 1 `artist = The Dubliners`, `albumArtist = Various`, `tags.isCompilation = true`.

How apply writes the flag (`TCMP` / `cpil` / `COMPILATION`): see [10-apply.md](10-apply.md).

### AS-DOC-PRP-042 — Tracks by many artists under one artist folder become a "Various" compilation
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › naming and tagging › retries under "Various" and matches when a Various-Artists release is filed under its tracks' shared folder (real "DIO/1999 - Holy Dio" case); legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › naming and tagging › falls back to a proposed "Various" compilation (with tag-based track artists) when the Various retry also finds nothing; legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › naming and tagging › does not retry under "Various" when the folder-artist search already matched

When a release sits under a normal artist folder, but its tracks show many different artists, the proposal treats it as a Various Artists compilation. This happens with or without a Discogs match. The release needs review with a note that contains `Various Artists compilation`. When the folder-artist search already matched, nothing changes. The search retry under "Various" and the evidence rule: see [07-proposal-matching.md](07-proposal-matching.md).

Example: `DIO\1999 - Holy Dio` with track artists Blind Guardian, Primal Fear, Doro → artist folder `Various`, `isCompilation = true`, track Artists `Blind Guardian`, `Primal Fear`, `Doro`, `albumArtist = Various`, review required. Discogs status is `matched` when the retry finds it, else `not-found`.
Example: `Radiohead\1997 OK Computer` matched under `Radiohead` → artist folder `Radiohead`.

### AS-DOC-PRP-043 — The track compilation flag equals the release compilation flag
Status: Draft | Source: legacy/plan/06-edit-proposal-module.md › Computing proposed names and tags; legacy/tests/fixtures/expected/proposal.json

Every track's compilation tag is `proposed.isCompilation`.

Example: `Cranberries` (not a compilation) → `tags.isCompilation = false` on every track.

## Bilingual (Japanese) names

### AS-DOC-PRP-044 — Japanese-only Discogs text gets the form "{romanized} = {original}"
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › bilingual (Japanese) release naming (session 2026-10-03-0010) › names the album/track "{romanized} = {original}" and shares the bilingual artist folder across every release of the artist, even one that did not itself match; legacy/README.md › Reference: Japanese releases

When the Discogs album title or track title is Japanese-only text, the proposal puts the romanized source text in front: `{romanized} = {original}`. This is the Discogs convention.

Example: Discogs album `ロッキンポ殺し`, source title `Rokkinpo Goroshi` → album `Rokkinpo Goroshi = ロッキンポ殺し`.
Example: Discogs track `ニトロBB戦争`, source title tag `Nitro Bb Sensou` → title `Nitro Bb Sensou = ニトロBB戦争`.

### AS-DOC-PRP-045 — The romanized half comes from the source, never from transliteration
Status: Draft | Source: legacy/README.md › Reference: Japanese releases; legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › bilingual (Japanese) release naming (session 2026-10-03-0010) › names the album/track "{romanized} = {original}" and shares the bilingual artist folder across every release of the artist, even one that did not itself match

The romanized half comes from the source: an existing tag, the recognized folder or file title, or the folder's artist name. The app never invents or transliterates it.

Example: track title tag `Rokkinpo Goroshi` → `Rokkinpo Goroshi = ロッキンポ殺し`.
Example: folder artist `Maximum the Hormone` → `Maximum The Hormone = マキシマム ザ ホルモン` (the romanized half appears in title case).

### AS-DOC-PRP-046 — A Japanese-only Discogs artist gives a bilingual artist folder, Artist and Album Artist
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › bilingual (Japanese) release naming (session 2026-10-03-0010) › names the album/track "{romanized} = {original}" and shares the bilingual artist folder across every release of the artist, even one that did not itself match; legacy/README.md › Reference: Japanese releases

When the Discogs artist credit is Japanese-only text, the artist folder, the Artist tag and the Album Artist tag use the bilingual form.

Example: Discogs artist `マキシマム ザ ホルモン` → artist folder, `artist` and `albumArtist` = `Maximum The Hormone = マキシマム ザ ホルモン`.

### AS-DOC-PRP-047 — All releases of one artist share the bilingual artist folder
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › bilingual (Japanese) release naming (session 2026-10-03-0010) › names the album/track "{romanized} = {original}" and shares the bilingual artist folder across every release of the artist, even one that did not itself match; legacy/README.md › Reference: Japanese releases

When one release of an artist gets a bilingual artist name, every release of that artist in the session uses the same artist folder. This includes a release with no Discogs match. That release's album stays as recognized.

Example: `Maximum the Hormone\1990 Kusoban`, status `not-found` → artist folder `Maximum The Hormone = マキシマム ザ ホルモン`, album `Kusoban`.

### AS-DOC-PRP-048 — A Latin-script Discogs artist gets no Japanese name
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › bilingual (Japanese) release naming (session 2026-10-03-0010) › does not add a Japanese name to a non-Japanese act even when a Japanese pressing's release title is partly Japanese (Iron Maiden guard)

When the Discogs artist credit is in Latin script, the artist folder and Album Artist get no Japanese part. This holds even when the release title is partly Japanese.

Example: Discogs `Iron Maiden` / `Killers (地獄の処刑台)` → artist folder `Iron Maiden`, `albumArtist = Iron Maiden`.

### AS-DOC-PRP-049 — Discogs text already in "X = Y" form, or without Japanese script, stays as is
Status: Draft | Source: legacy/README.md › Reference: Japanese releases

When Discogs already writes a name as `X = Y`, or the Discogs text has no Japanese script, the proposal uses the Discogs text unchanged.

Example: Discogs artist `Iron Maiden` → `Iron Maiden` (no ` = ` part).

Release date and release-type hints in folder names: see [05-recognition.md](05-recognition.md). The artist-catalog fallback search for Japanese releases: see [07-proposal-matching.md](07-proposal-matching.md).

## Cover art

### AS-DOC-PRP-050 — Cover candidates list Discogs images and existing covers with a source label
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › cover art › defaults to an already-embedded cover even when Discogs also has images; legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › cover art › falls back to a local companion cover when Discogs has no images; legacy/plan/06-edit-proposal-module.md › Cover art candidates; legacy/tests/fixtures/expected/proposal.json › ZZ Top / XXX

`coverArt.candidates` holds all Discogs images of the selected release, plus any embedded or loose cover found by recognition. Each candidate has a URL or path, a source label (`sourceEdition`), width and height.

Example: matched `OK Computer` with an embedded cover → 2 candidates, one labelled `existing (embedded)`.
Example: `ZZ Top\1999 XXX\cover.jpg` → candidate `sourceEdition = existing (local)`, `width = 1`, `height = 1`.

### AS-DOC-PRP-051 — A decodable embedded cover is the default choice
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › cover art › defaults to an already-embedded cover even when Discogs also has images

When a track already has an embedded cover that is a real image, it is the chosen cover, even when Discogs has images. The Discogs images stay in the list, so the user can switch.

Example: embedded `existing-cover.jpg` (a real 2×2 PNG) + Discogs image → `chosenCandidateUrl = <path of existing-cover.jpg>`.

### AS-DOC-PRP-052 — An embedded cover that cannot be decoded is not a candidate
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › cover art › falls back to a Discogs image when the embedded cover is not a decodable image

When the embedded cover is not a real image, it is left out of the candidates. A Discogs image is chosen.

Example: embedded `existing-cover.jpg` with content `not-a-real-image` + one Discogs image → 1 candidate, no `existing (embedded)`, chosen cover is not the embedded file.

### AS-DOC-PRP-053 — Without Discogs images, a local companion cover is chosen
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › cover art › falls back to a local companion cover when Discogs has no images; legacy/plan/06-edit-proposal-module.md › Edge cases; legacy/tests/fixtures/expected/proposal.json › ZZ Top / XXX

When Discogs gives no image, a loose cover companion from the source is the candidate and the chosen cover. No cover note is added.

Example: `Some Band\2010 Some Album\cover.jpg` (kind `cover`, content `not-a-real-image`) → 1 candidate `existing (local)`, `chosenCandidateUrl = <path of cover.jpg>`.

### AS-DOC-PRP-054 — With only Discogs images, the Discogs primary image is chosen
Status: Draft | Source: legacy/plan/06-edit-proposal-module.md › Cover art candidates; legacy/tests/Reshelf.EditProposal.Tests.ps1 › Update-ReshelfReleaseForDiscogsSelection › recomputes track titles, album/artist names, cover art, and target action from the chosen candidate

When there is no usable existing cover, the Discogs primary image is the chosen cover. The user can change it in the review UI (see [09-review-ui.md](09-review-ui.md)).

Example: Discogs release 265498, primary image → `chosenCandidateUrl = https://i.discogs.com/example/full-265498.jpg`.

### AS-DOC-PRP-055 — No cover anywhere: empty list and review
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › cover art › has empty candidates and forces review when no cover art is available anywhere; legacy/tests/fixtures/expected/proposal.json › Cranberries

When neither Discogs nor the source has a cover, the candidate list is empty and the chosen cover is empty. The release needs review. The note is `No cover art candidates found from Discogs or local companion files.`

Example: `Some Band / 2010 Some Album` without images → `candidates = []`, `chosenCandidateUrl = null`, `humanReview.required = true`.

### AS-DOC-PRP-056 — The cover target size is the coverMaxDimension setting
Status: Draft | Source: legacy/plan/06-edit-proposal-module.md › Cover art candidates; legacy/tests/fixtures/expected/proposal.json

`coverArt.targetMaxDimension` is the `coverMaxDimension` setting. The default is 600 (see [03-settings-and-secrets.md](03-settings-and-secrets.md)). Resizing: see [10-apply.md](10-apply.md).

Example: default settings → `targetMaxDimension = 600`.

## Companion files

### AS-DOC-PRP-057 — A nested companion is included and keeps its path
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › New-ReshelfCompanionProposal (private) › adds include = $true and leaves proposedFileName $null for a nested companion; legacy/tests/fixtures/expected/proposal.json › ZZ Top / Mescalero

A companion file in a subfolder of the release is included by default. It gets no proposed file name. It does not cause review.

Example: `C:\src\Scans\front.jpg` (kind `cover`, nested) → `include = true`, `proposedFileName = null`, no review.

### AS-DOC-PRP-058 — A loose companion that starts with a letter keeps its name
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › New-ReshelfCompanionProposal (private) › proposes the same name unchanged for a loose companion that already starts with a letter; legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › cover art › falls back to a local companion cover when Discogs has no images

A companion file directly in the release folder whose name starts with a letter keeps its name. It is included. No note, no review.

Example: `C:\src\folder.jpg` → `proposedFileName = folder.jpg`.
Example: `cover.jpg` → `include = true`, `proposedFileName = cover.jpg`.

### AS-DOC-PRP-059 — A loose companion that starts with a digit gets its kind word in front
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › New-ReshelfCompanionProposal (private) › renames a digit-starting loose companion with its kind word prefix, flags review, and adds a note; legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › cover art › renames a digit-starting loose companion and forces review, end to end through Invoke-ReshelfEditProposal

A loose companion whose name starts with a digit gets the capitalized kind word and a space in front. The release needs review. A note names the old and the new name.

Example: `01 back.jpg`, kind `booklet` → `Booklet 01 back.jpg`; note like `… 01 back.jpg … renamed … Booklet 01 back.jpg`.
Example: `01 back.jpg`, kind `photo` → `Photo 01 back.jpg`, `humanReview.required = true`.

### AS-DOC-PRP-060 — No companion files: empty list, no review
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › New-ReshelfCompanionProposal (private) › handles an empty companion list

When the release has no companion files, the companion list is empty. It does not cause review.

Example: `companionFiles = []` → 0 companions, no review flag from companions.

## Target index

### AS-DOC-PRP-061 — The target index keys each "Artist\yyyy Name" folder by its stable key
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Build-ReshelfTargetIndex and Test-ReshelfTargetReleaseExists › indexes well-formed artist/release folders and finds them by stable key; legacy/plan/06-edit-proposal-module.md › Target comparison (lossy/lossless + duplicate handling)

The app scans the target root. For each `<artist>\<yyyy Name>` folder, it computes the stable key from the folder names on disk. A lookup by stable key returns the folder path.

Example: `ArtistA\1999 AlbumOne` and `ArtistB\2005 AlbumTwo` → 2 entries; key of `ArtistA` / `AlbumOne` / 1999 finds `<targetRoot>\ArtistA\1999 AlbumOne`.

### AS-DOC-PRP-062 — The target index skips folders that do not match "yyyy Name"
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Build-ReshelfTargetIndex and Test-ReshelfTargetReleaseExists › skips a release folder that does not match the "yyyy Name" pattern

A release folder whose name does not start with a 4-digit year and a space is not indexed.

Example: `ArtistA\Misc` → index is empty.

### AS-DOC-PRP-063 — A missing target root gives an empty index
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Build-ReshelfTargetIndex and Test-ReshelfTargetReleaseExists › returns an empty index when the target root does not exist

When the target root does not exist, the index is empty. There is no error.

Example: target root `<TestDrive>\<new guid>` (not created) → 0 entries.

### AS-DOC-PRP-064 — An unknown stable key finds nothing
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Build-ReshelfTargetIndex and Test-ReshelfTargetReleaseExists › returns $null from Test-ReshelfTargetReleaseExists when the key is not indexed

A lookup with a key that is not in the index returns nothing.

Example: key `doesnotexist0000` → nothing.

### AS-DOC-PRP-065 — Two folders with the same stable key give one index entry, without error
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Build-ReshelfTargetIndex and Test-ReshelfTargetReleaseExists › does not throw on a stable-key collision between two folders that normalize the same way

When two target folders normalize to the same stable key, the index keeps one entry. The scan does not fail.

Example: `ZZ Top\1999 XXX` and `zz  top\1999 XXX` → 1 entry.

## Target comparison

### AS-DOC-PRP-066 — Each release gets one target action
Status: Draft | Source: legacy/README.md › Re-runs and duplicates; legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › target comparison › proposes create-new when the target has no matching release

Each release gets a `targetAction`: `create-new`, `skip-existing-identical`, `update-existing` or `conflict`. When no existing target folder is found, the action is `create-new`. The comparison runs after the Discogs lookup and does not depend on the match result.

Example: empty target, `Some Band / 2010 Some Album` → `create-new`.

### AS-DOC-PRP-067 — A valid apply-log entry with the same source hash gives skip-existing-identical
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › target comparison › proposes skip-existing-identical via a valid apply-log entry, even though the target file was renamed and re-tagged; legacy/plan/06-edit-proposal-module.md › Target comparison (lossy/lossless + duplicate handling); legacy/plan/06-edit-proposal-module.md › Definition of done

First, the app checks the apply log. When it has an `applied` entry for this stable key, its target path is still under the target root and still exists, and its recorded source file-set hash equals the current source hash, the action is `skip-existing-identical`. This works even though apply renamed and re-tagged the target files. A second run on an unchanged source gives `skip-existing-identical` for every release.

Example: source `01 - Track.flac` (`source-content`), target `Some Band\2010 Some Album\01 Track.flac` (different size), apply-log entry with the source hash → `skip-existing-identical`.

The apply log itself: see [10-apply.md](10-apply.md).

### AS-DOC-PRP-068 — A stale or failed apply-log entry does not cause a skip
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › target comparison › proposes conflict, not skip-existing-identical, when the apply-log entry no longer matches the current source; legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › target comparison › proposes conflict, not skip-existing-identical, when the apply-log entry is a failed attempt

When the apply-log hash does not match the current source, or the entry status is `failed`, the app does not skip. It continues with the folder comparison.

Example: recorded hash `stale-hash-from-a-prior-apply`, target content differs → `conflict`.
Example: entry status `failed`, target `partially-written-content` → `conflict`.

### AS-DOC-PRP-069 — The existing target folder is found in a fixed order
Status: Draft | Source: legacy/plan/06-edit-proposal-module.md › Target comparison (lossy/lossless + duplicate handling); legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › target comparison › proposes update-existing/replace-existing via the apply-log when the source stableKey differs from the target folder's own key (plan/12 milestone 7); legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › target comparison › proposes update-existing/replace-existing when a lossy folder sits at the proposed path, even with no apply-log entry and a different stableKey

When there is no skip, the app looks for the existing target folder. First match wins:
1. the target path of a valid apply-log entry for this stable key;
2. the proposed target path, when it exists and has audio files;
3. the target index, by stable key.

Example: source `SOME BAND - SomeAlbum` (no year), proposed `Some Band\2010 Some Album` exists with `01 Track.mp3`, no apply-log entry → that folder is found, although its stable key differs.

### AS-DOC-PRP-070 — Same file names and sizes give skip-existing-identical
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › target comparison › proposes skip-existing-identical when the target already has the same file set; legacy/plan/06-edit-proposal-module.md › Target comparison (lossy/lossless + duplicate handling); legacy/README.md › Re-runs and duplicates

When the found target folder has the same file set as the source (same file names and sizes), the action is `skip-existing-identical`. In practice this happens for a target that the app did not create itself.

Example: source `01 Track.flac` and target `Some Band\2010 Some Album\01 Track.flac`, both `same-content` → `skip-existing-identical`.

### AS-DOC-PRP-071 — A lossless source over a lossy target is an upgrade
Status: Draft | Source: legacy/README.md › Re-runs and duplicates; legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › target comparison › proposes update-existing/replace-existing when a lossless source would upgrade a lossy target

When the found target folder is lossy and the source is lossless, the action is `update-existing`. Details and the other lossy cases: see [11-lossy-tracking.md](11-lossy-tracking.md) (AS-DOC-LSY-024 to AS-DOC-LSY-028).

Example: source `01 Track.flac`, target `01 Track.mp3` → `update-existing`.

### AS-DOC-PRP-072 — A different target that is not an upgrade is a conflict
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › target comparison › proposes conflict when the target differs from the source and it is not a lossy-to-lossless upgrade; legacy/README.md › Re-runs and duplicates; legacy/plan/06-edit-proposal-module.md › Target comparison (lossy/lossless + duplicate handling)

When the found target folder differs from the source and it is not a lossy-to-lossless upgrade, the action is `conflict`. The release needs review. What approving a conflict does: see [10-apply.md](10-apply.md).

Example: source `01 Track.flac` (`source-content`), target `01 Track.flac` (`different-target-content`) → `conflict`, `humanReview.required = true`.

### AS-DOC-PRP-073 — A second release with the same stable key in one session is a conflict
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › target comparison › resolves a same-stable-key duplicate within one session against the first occurrence

When two releases in one session have the same stable key, the first one is compared with the target as usual. The later one is compared with the first one. When the content differs, it is a `conflict`.

Example: `Copy One\Some Band\2010 Some Album` and `Copy Two\Some Band\2010 Some Album` with different content → first `create-new`, second `conflict`.

### AS-DOC-PRP-074 — An upgrade is not flagged for review
Status: Draft | Source: legacy/README.md › Re-runs and duplicates

A release with `update-existing` is not flagged for review because of its target action.

Example: lossless `Some Band / 2010 Some Album` over a lossy target → `update-existing`, no review reason from the target comparison.

### AS-DOC-PRP-075 — Every release has a stable key from its normalized artist, album and year
Status: Draft | Source: legacy/README.md › Re-runs and duplicates; legacy/tests/Reshelf.EditProposal.Tests.ps1 › Build-ReshelfTargetIndex and Test-ReshelfTargetReleaseExists › does not throw on a stable-key collision between two folders that normalize the same way; legacy/tests/fixtures/expected/proposal.json

Every release has a `stableKey`: a deterministic ID made from its normalized artist, album and year. The same names always give the same key. The key is 16 lowercase hex characters. The target comparison uses it to find "the same" release. How the key is built: see [01-data-home-and-storage.md](01-data-home-and-storage.md).

Example: `ZZ Top` / `XXX` / 1999 and `zz  top` / `XXX` / 1999 → the same key.
Example: `Cranberries / Everybody Else Is Doing It` → `fc6337eecc96a4aa`.

## Applying a chosen Discogs version

### AS-DOC-PRP-076 — Picking a Discogs candidate recomputes the release
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Update-ReshelfReleaseForDiscogsSelection › recomputes track titles, album/artist names, cover art, and target action from the chosen candidate

When the user picks a Discogs candidate for an ambiguous release, the app fetches that release. It recomputes the artist folder, album, year, track titles, file names, cover candidates, chosen cover and target action from it. The match status becomes `matched` and the chosen id is stored. The candidate list stays unchanged.

Example: `Amagrama / 2005 Volumen 1` (ambiguous), pick 265498 → `status = matched`, `selectedReleaseId = 265498`, artist folder `Radiohead`, album `OK Computer`, year 1997, titles `Airbag`, `Paranoid Android`, `Subterranean Homesick Alien`, file `01 Airbag.flac`, chosen cover `https://i.discogs.com/example/full-265498.jpg`, `targetAction = create-new`.

The UI picker: see [09-review-ui.md](09-review-ui.md).

### AS-DOC-PRP-077 — After a pick, a sibling with the same stable key and other content is a conflict
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Update-ReshelfReleaseForDiscogsSelection › flags a target conflict when a sibling release in the same proposal shares this stable key with different source content (plan/10)

After a pick, the target comparison also checks the other releases of the same proposal. When one of them has the same stable key and different source content, the action is `conflict` and the release needs review.

Example: `Amagrama\2005 Volumen 1\01 - Track 1.flac` (`release-bytes`) and sibling `Other Folder\sibling.flac` (`different-bytes`) with the same key → `conflict`, review required.

### AS-DOC-PRP-078 — After a pick, a sibling that already claims the same target path is a conflict
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Update-ReshelfReleaseForDiscogsSelection › flags a target conflict when a sibling release with a DIFFERENT stable key already claimed the same proposed target path (real case: two source folders for one album that Discogs corrects to one folder)

After a pick, when another release of the same proposal already has the same proposed target path, the action is `conflict`, even with a different stable key. The release needs review. The note contains `target path collision`.

Example: sibling recognized as `Amagrama / Volumen 1 / 1997`, already proposed as `Radiohead\1997 OK Computer`; this release picks 265498 (`Radiohead\1997 OK Computer`) → `conflict`, note contains `target path collision`.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-05 | Phase 1 draft. |
