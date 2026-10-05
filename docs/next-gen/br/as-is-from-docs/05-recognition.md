# 05 — Recognition (as-is, from docs and tests)

Status: Draft | Version: 0.1 | Last updated: 2026-10-05

## Scope

This file describes how the legacy `recognize` step works today. It covers how recognize turns a source folder tree into artists, releases, tracks, companion files and an `unrecognized` list. Owned inputs:

- `legacy/tests/Reshelf.Recognition.Tests.ps1` (all `Describe` blocks);
- `legacy/tests/fixtures/sample-source-tree/**` (folder and file names used as examples);
- `legacy/tests/fixtures/expected/recognition.json` (the golden output, written as "golden file" below);
- `legacy/plan/05-recognition-module.md`;
- `legacy/README.md` sections "Pipeline", "1. Recognize" and "Reference: automatic folder recognition".

Notes for the reader:

- The tests replace the real tag reader with a mock (a fake function). So some values in the examples come from the mock, not from real files: `durationSeconds` = 200, `format` = the lower-case file extension, and `isLossless`. The golden file uses a mock where all tags are empty (`artist`, `album`, `title` = `null`).
- `<SOURCE_ROOT>` in the examples is the scanned source folder.
- Terms used in this file:
  - **recognition flag** — a note in `recognitionFlags`. It does not ask for review.
  - **review reason** — a code in `reviewReasons`. It sets `needsReview` to `true`.
  - **unrecognized entry** — a folder in `unrecognized[]` that recognize could not turn into a release.
- Suspected defects and contradictions found in these inputs are not in this file. They are AS-DOC-DEF-018 to AS-DOC-DEF-038 in [90-suspected-defects.md](90-suspected-defects.md).

## Pipeline and output

### AS-DOC-REC-001 — Recognize is the first pipeline step
Status: Draft | Source: legacy/README.md › Pipeline; legacy/plan/05-recognition-module.md › Purpose / scope

Recognize scans one source folder. It groups the files into artists, releases and tracks, and it writes the result to `recognition.json`. The next step (propose) reads this file.

Example: `source folder → [recognize] → recognition.json → [propose] → proposal.json → [ui start] → [apply]`.

Propose: see [07-proposal-matching.md](07-proposal-matching.md) and [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md). Review in the browser: see [09-review-ui.md](09-review-ui.md). Apply: see [10-apply.md](10-apply.md). The command form `pwsh scripts/Reshelf.ps1 <command>`: see [12-cli.md](12-cli.md).

### AS-DOC-REC-002 — Recognize writes recognition.json into the session folder
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › produces a recognition.json that validates against the schema; legacy/README.md › 1. Recognize

Each recognize run creates a session. It writes `recognition.json` into the folder of that session. The result carries the session ID.

Example: session ID `session-1` → file `<data home>\sessions\session-1\recognition.json`, and the result has `sessionId` = `session-1`.

Session creation and session IDs: see [04-sessions.md](04-sessions.md). The data home folder: see [01-data-home-and-storage.md](01-data-home-and-storage.md). The `-SourceRoot` and `-SaveAsDefault` options and the printed summary (`SessionId`, `ArtistCount`, `ReleaseCount`, `UnrecognizedCount`): see [12-cli.md](12-cli.md).

### AS-DOC-REC-003 — recognition.json is valid against its schema
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › produces a recognition.json that validates against the schema; legacy/plan/05-recognition-module.md › Output

The written `recognition.json` is valid against `legacy/schemas/recognition.schema.json`. The plan says that recognize checks the schema before it writes the file.

Example: recognize over `legacy/tests/fixtures/sample-source-tree` → `Test-Json -SchemaFile recognition.schema.json` returns `true`.

### AS-DOC-REC-004 — Top-level content of recognition.json
Status: Draft | Source: legacy/tests/fixtures/expected/recognition.json

The file holds a schema version, the session ID, the source root, the creation time (UTC), a list of artists and a list of unrecognized entries. Each artist has a name, a list of source paths and a list of releases.

Example (golden file, shortened):

```json
{
  "schemaVersion": 1,
  "sessionId": "<SESSION_ID>",
  "sourceRoot": "<SOURCE_ROOT>",
  "generatedAtUtc": "<GENERATED_AT>",
  "artists": [
    { "recognizedName": "Cranberries",
      "sourcePaths": [ "<SOURCE_ROOT>\\Cranberries" ],
      "releases": [ ... ] }
  ],
  "unrecognized": [ ... ]
}
```

### AS-DOC-REC-005 — Content of a release record
Status: Draft | Source: legacy/tests/fixtures/expected/recognition.json

Each release records: a stable key, the recognized title, year, release date and release type, the edition folder name, the source folder path, the disc count, the tracks, the companion files, the ignored files, the cue sheets, a confidence value, the recognition flags, the review flag and the review reasons.

Example (golden file, `Cranberries\1993 - Everybody Else Is Doing It`):

```json
{ "stableKey": "fc6337eecc96a4aa",
  "recognizedTitle": "Everybody Else Is Doing It", "recognizedYear": 1993,
  "recognizedReleaseDate": null, "recognizedReleaseType": null,
  "editionFolderName": null,
  "sourceFolderPath": "<SOURCE_ROOT>\\Cranberries\\1993 - Everybody Else Is Doing It",
  "discFolderCount": 1, "tracks": [ ... ],
  "companionFiles": [], "ignoredFiles": [], "cueSheets": [],
  "recognitionConfidence": 1.0, "recognitionFlags": [],
  "needsReview": false, "reviewReasons": [] }
```

### AS-DOC-REC-006 — Content of a track record
Status: Draft | Source: legacy/tests/fixtures/expected/recognition.json

Each track records: the source file path, the disc folder, the original file name, the track number inside its disc, whether the order was inferred, the existing tags (artist, album, title), the existing cover path, the format, whether it is lossless, the duration in seconds, the cue timestamp and whether it is a cue virtual track.

Example (golden file, `01 - I Still Do.flac`):

```json
{ "sourceFilePath": "<SOURCE_ROOT>\\Cranberries\\1993 - Everybody Else Is Doing It\\01 - I Still Do.flac",
  "discFolder": null, "originalFileName": "01 - I Still Do.flac",
  "detectedTrackNumberInDisc": 1, "inferredTrackOrder": false,
  "existingTags": { "artist": null, "album": null, "title": null },
  "existingCoverArtPath": null, "format": "flac", "isLossless": true,
  "durationSeconds": 200, "cueTimestamp": null, "isCueVirtualTrack": false }
```

### AS-DOC-REC-007 — Each release has a stable key
Status: Draft | Source: legacy/tests/fixtures/expected/recognition.json; legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › splits an album wrapper with two edition subfolders into two reviewed releases with distinct stableKeys

Each release gets a `stableKey` of 16 hexadecimal characters. Two releases from the same album folder get different keys. The recognition tests do not show how the key is built; the key rules are in [01-data-home-and-storage.md](01-data-home-and-storage.md).

Example: `Cranberries\1993 - Everybody Else Is Doing It` → `fc6337eecc96a4aa`. The editions `1988 Germany Label 1` and `1992 Australia Label 2` of `1980 - Multi Edition Album` → two different keys.

What the key is used for: see [01-data-home-and-storage.md](01-data-home-and-storage.md) (key rules) and [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md) (duplicate and upgrade states).

### AS-DOC-REC-008 — Artists and releases follow the folder walk order
Status: Draft | Source: legacy/tests/fixtures/expected/recognition.json

In the golden file, artists appear in the A–Z order of their folder names, without regard to letter case. An artist from a band-member folder or a grouping folder comes right after the folder that holds it. Releases inside an artist follow the A–Z order of their folder names, with the category subfolders at their own place in that order.

Example (golden file): `Cranberries`, `Dance With Ghosts`, `Godspeed You! Black Emperor`, `Silver Mountain Zion`, `Isidor`, `Live Wire`, `Pink Floyd`, `PULSAR OLYMP`, `Talking Heads`, `David Byrne`, `Unnumbered`, `Wrapper Band`, `ZZ Top`. ZZ Top releases: `XXX`, `Mescalero`, `One Foot In The Blues` (`EPs`), `Live From Texas` (`Lives`), `Pincushion` (`Singles`).

### AS-DOC-REC-009 — An unrecognized entry names the folder, the reason and the children
Status: Draft | Source: legacy/tests/fixtures/expected/recognition.json; legacy/README.md › 1. Recognize; legacy/README.md › Reference: automatic folder recognition

Each unrecognized entry holds the folder path, a reason code and the names of the folder's direct children (files or folders). The known reasons are `release-without-artist-suspected` and `no-audio-files`.

Example (golden file):

```json
[ { "path": "<SOURCE_ROOT>\\1999 Loose Album",
    "reason": "release-without-artist-suspected",
    "children": [ "01 - Track.flac" ] },
  { "path": "<SOURCE_ROOT>\\Empty Artist",
    "reason": "no-audio-files",
    "children": [ "2010 Nothing Here" ] } ]
```

### AS-DOC-REC-010 — The user fixes an unrecognized folder on disk
Status: Draft | Source: legacy/README.md › 1. Recognize; legacy/README.md › Reference: automatic folder recognition; legacy/plan/05-recognition-module.md › (superseded note at the top)

There is no override file. When `unrecognized[]` is not empty, the user moves or renames the folder on disk so that it matches a known pattern. Then the user runs recognize again.

Example: `<SOURCE_ROOT>\1999 Loose Album` is unrecognized. The user moves it to `<SOURCE_ROOT>\Some Artist\1999 Loose Album` and runs recognize again.

## Release folders

### AS-DOC-REC-011 — A folder with audio files directly inside is a release folder
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Test-IsReleaseFolder (private) › recognizes a normal release folder with directly-numbered audio files; legacy/tests/fixtures/expected/recognition.json

A folder that directly holds at least one audio file is a release folder. The files do not need track numbers.

Example: `ZZ Top\1999 XXX` (`01 - Poke Chop Sandwich.flac`, `02 Crucifixx A Flatt.flac`) → release. `Unnumbered\2015 No Numbers` (`Alpha Song.flac`, `Beta Song.flac`) → release `No Numbers` in the golden file.

### AS-DOC-REC-012 — A folder whose children are disc folders is a release folder
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Test-IsReleaseFolder (private) › recognizes a multi-disc release folder whose children are all disc subfolders; … › recognizes a multi-disc release folder whose children are LP#-numbered disc subfolders

A folder with no audio directly inside, but with disc folders as children, is a release folder (a multi-disc release). Disc folder names: see AS-DOC-REC-062.

Example: `Wrapper Band\2004 - LP Reissue` (children `LP#1`, `LP#2`) → release. `ZZ Top\2003 Mescalero` (children `CD 1`, `CD 2`) → release.

### AS-DOC-REC-013 — An artist folder is not a release folder
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Test-IsReleaseFolder (private) › does not recognize an artist folder (release-shaped children, no direct audio) as a release

A folder with no audio directly inside, whose children are release folders, is not a release folder.

Example: `ZZ Top` (children `1999 XXX`, `2003 Mescalero`, `EPs`, …) → not a release.

### AS-DOC-REC-014 — A folder without audio files is not a release folder
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Test-IsReleaseFolder (private) › does not recognize an empty folder (no audio files) as a release

A folder that holds no audio files is not a release folder, even when it holds other files.

Example: `Empty Artist\2010 Nothing Here` (only `readme.txt`) → not a release.

### AS-DOC-REC-015 — Loose audio next to a subfolder with audio is a release flagged for review
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › treats a loose audio file mixed with a subfolder of its own audio as a suspected nested release, not unclassified; legacy/plan/05-recognition-module.md › Edge cases

When a folder holds audio files directly and also has a subfolder with its own audio, recognize keeps the folder as a release. It sets `needsReview` and adds the review reason `nested-release-suspected`. The folder does not go to `unrecognized[]`.

Example: `Some Artist\Messy Junk\Bonus Track.flac` plus `Some Artist\Messy Junk\Weird Sub\01 - Track.flac` → release with source folder `…\Messy Junk`, `needsReview` = `true`, `reviewReasons` contains `nested-release-suspected`.

## Artist folders and the source root

### AS-DOC-REC-016 — A top-level folder that holds releases is an artist
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › recognizes a normal single-disc release with correct track order; legacy/tests/fixtures/expected/recognition.json

A folder directly under the source root that holds release folders is an artist. The folder name becomes the artist name. The folder path goes into the artist's source paths.

Example: `<SOURCE_ROOT>\ZZ Top\1999 XXX` → artist `ZZ Top` (`sourcePaths` contains `<SOURCE_ROOT>\ZZ Top`) with release `XXX`, year 1999, 2 tracks, 1 companion file.

### AS-DOC-REC-017 — An artist folder with no audio anywhere below is unrecognized
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › flags an empty artist folder (no audio anywhere) as unrecognized; legacy/plan/05-recognition-module.md › Edge cases; legacy/README.md › 1. Recognize

A top-level folder with no audio file anywhere below it goes to `unrecognized[]` with reason `no-audio-files`. The entry names the top-level folder, not the empty release folder inside it.

Example: `Empty Artist\2010 Nothing Here\readme.txt` → unrecognized entry `path` = `<SOURCE_ROOT>\Empty Artist`, `reason` = `no-audio-files`, `children` = `["2010 Nothing Here"]`.

### AS-DOC-REC-018 — A loose non-audio file in an artist folder does not block recognition
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › ignores a loose non-audio file sitting next to release subfolders and still recognizes the releases

A non-audio file directly in an artist folder, next to release folders, has no effect. The artist and its releases are recognized as usual.

Example: `Some Artist\Discography.txt` plus `Some Artist\2010 Some Album\01 - Track.flac` → artist `Some Artist` with one release `Some Album`. `Some Artist` is not in `unrecognized[]`.

### AS-DOC-REC-019 — The same artist name in two places becomes one artist
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › merges sourcePaths when the same artist name is found under two different parents

When recognize finds two artist folders with the same name under different parent folders, it makes one artist. The artist holds the releases of both folders and both folder paths.

Example: `Genre A\Shared Artist\1999 Album One\01 - Track.flac` and `Genre B\Shared Artist\2001 Album Two\01 - Track.flac` → one artist `Shared Artist` with 2 releases and 2 `sourcePaths`.

### AS-DOC-REC-020 — Reserved device names are recorded as they are
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › records a reserved device folder name (CON) raw, without converting it

Recognize records a Windows reserved device name (such as `CON`) as the artist name without any change.

Example: `CON\2005 Weird\01 - Track.mp3` → artist `CON`.

How names are cleaned later: see [02-text-and-naming-rules.md](02-text-and-naming-rules.md).

### AS-DOC-REC-021 — A release folder directly in the source root is unrecognized
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › flags a release folder with no artist wrapper as unrecognized; … › still flags a flat release folder with no " - " separator as unrecognized (regression); legacy/README.md › 1. Recognize

A release folder directly under the source root, with no `" - "` in its name, goes to `unrecognized[]` with reason `release-without-artist-suspected`. It does not become an artist. AS-DOC-REC-023 has the exception.

Example: `<SOURCE_ROOT>\1999 Loose Album\01 - Track.flac` → unrecognized, `reason` = `release-without-artist-suspected`. No artist named `1999 Loose Album`.

### AS-DOC-REC-022 — A root release folder named "Artist - Album" is split into artist and title
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › splits a flat "Artist - Album" release folder (no artist wrapper) into a review-flagged release; … › does not misparse a leading 4-digit non-year number (e.g. a catalog number) as recognizedYear; legacy/tests/fixtures/expected/recognition.json

A release folder directly under the source root with `" - "` in its name is split at the first `" - "`. The left part becomes the artist, the right part becomes the release title. The release gets `needsReview` and the review reason `artist-name-split-from-folder-name`. In the golden file, the artist's source path is the source root itself.

Example: `<SOURCE_ROOT>\PULSAR OLYMP - 94Shine` (2 tracks) → artist `PULSAR OLYMP`, release `94Shine`, `sourcePaths` = `["<SOURCE_ROOT>"]`. No artist named `PULSAR OLYMP - 94Shine`.

Example: `<SOURCE_ROOT>\Isidor - 3218 (Soldier of Fortune Edition - Artwork)` → artist `Isidor`, release `3218 (Soldier of Fortune Edition - Artwork)`.

### AS-DOC-REC-023 — A root release folder is promoted when all tracks agree on artist and album tags
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › promotes a release-without-artist folder into a recognized release when every track agrees on artist/album tags (real-world "edbl" case); legacy/plan/05-recognition-module.md › Deterministic cleanups added against real data (plan/12 milestone 3)

When a root release folder has no `" - "` in its name, but every track has the same artist tag and the same album tag, recognize makes a release from the tags. The artist tag becomes the artist name and the album tag becomes the release title. The release gets `needsReview` and the review reason `artist-and-album-from-tags`. The folder does not go to `unrecognized[]`.

Example: `<SOURCE_ROOT>\edbl\01 Track One.flac` and `02 Track Two.flac`, both tagged artist `edbl`, album `minibeats, vol.1` → artist `edbl`, release `minibeats, vol.1`, 2 tracks, `reviewReasons` contains `artist-and-album-from-tags`.

### AS-DOC-REC-024 — A root release folder stays unrecognized when track tags disagree
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › leaves a release-without-artist folder unrecognized when tracks disagree on artist/album tags; legacy/plan/05-recognition-module.md › Deterministic cleanups added against real data (plan/12 milestone 3)

When the tracks of a root release folder disagree on the artist or album tag, the folder stays in `unrecognized[]` with reason `release-without-artist-suspected`. The plan says the same happens when tags are missing.

Example: `<SOURCE_ROOT>\Mixed\01 Track One.flac` (artist `Artist A`) and `02 Track Two.flac` (artist `Artist B`), album `Some Album` for both → unrecognized. No artist named `Artist A`.

## Category subfolders

### AS-DOC-REC-025 — Category subfolder names
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Test-IsCategorySubfolder (private) › recognizes configured category names case-insensitively; … › rejects a name that is not in the category list; legacy/README.md › Reference: automatic folder recognition; legacy/plan/05-recognition-module.md › Heuristic functions

A subfolder of an artist is a category subfolder when its name is in the category list. The README lists `EPs`, `Singles`, `Lives`, `Live`, `Compilations`, `Bootlegs`. The match ignores letter case.

Example: `EPs`, `eps`, `Singles`, `Lives`, `lives` → category. `1999 XXX` → not a category.

Whether the list can be changed in settings: see [03-settings-and-secrets.md](03-settings-and-secrets.md).

### AS-DOC-REC-026 — Releases in a category subfolder belong to the parent artist
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › attributes a category subfolder release to the parent artist; legacy/README.md › Reference: automatic folder recognition; legacy/plan/05-recognition-module.md › The rule: only genuinely ambiguous cases go to a human; legacy/tests/fixtures/expected/recognition.json

Recognize adds the releases inside a category subfolder to the parent artist. The category subfolder does not become an artist. These releases get no review reason for this.

Example: `ZZ Top\EPs\1994 One Foot In The Blues`, `ZZ Top\Lives\2005 Live From Texas`, `ZZ Top\Singles\1996 Pincushion` → all three are releases of `ZZ Top` (5 ZZ Top releases in total). No artist `Lives` or `Singles`. `Live From Texas` has year 2005, `Pincushion` has year 1996, and both have `needsReview` = `false`.

### AS-DOC-REC-027 — The parent artist's source paths include its category folders
Status: Draft | Source: legacy/tests/fixtures/expected/recognition.json

The artist's `sourcePaths` list holds the artist folder and each category subfolder it used.

Example (golden file): `ZZ Top` → `sourcePaths` = `<SOURCE_ROOT>\ZZ Top`, `<SOURCE_ROOT>\ZZ Top\EPs`, `<SOURCE_ROOT>\ZZ Top\Lives`, `<SOURCE_ROOT>\ZZ Top\Singles`.

### AS-DOC-REC-028 — A subfolder whose release metadata names the parent artist is a category folder
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Test-IsGroupingFolder (private) › does not treat an artist folder as a grouping folder when its category subfolders' releases carry its name as cue PERFORMER (real-world Iron Maiden\Studio Albums + Compilation Albums case); … › Test-IsBandMemberFolder (private) › rejects a category-folder-in-disguise whose release metadata matches the parent artist (real-world Iron Maiden\Studio Albums case); … › Invoke-ReshelfRecognition › walks an artist folder with category subfolders whose releases carry its name as cue PERFORMER into one artist bucket (real-world Iron Maiden\Studio Albums + Compilation Albums case); legacy/README.md › Reference: automatic folder recognition

A subfolder name that is not in the category list still counts as a category folder when most of its releases' own metadata agrees with the parent artist name. Recognize checks the cue sheet `PERFORMER` line first, then the artist tag of the audio file. The releases go to the parent artist. They do not get the review reason `grouping-folder-auto-resolved`. Without such metadata, the folder-shape rules decide.

Example: `Iron Maiden\Studio Albums\1980 - Iron Maiden\Iron Maiden.flac` + `Iron Maiden.cue` (`PERFORMER "Iron Maiden"`) and `Iron Maiden\Compilation Albums\1996 - Best Of The Beast\Best Of The Beast.flac` + `.cue` (`PERFORMER "Iron Maiden"`) → one artist `Iron Maiden` with 2 releases. No artist `Studio Albums` or `Compilation Albums`. `Iron Maiden` is not a grouping folder, and `Studio Albums` is not a band-member folder.

## Band-member folders

### AS-DOC-REC-029 — A differently named subfolder with a release inside is a separate artist
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Test-IsBandMemberFolder (private) › recognizes a differently-named subfolder containing a release-shaped child; … › Invoke-ReshelfRecognition › creates a new artist bucket for a band-member folder instead of merging into the parent; legacy/README.md › Reference: automatic folder recognition; legacy/plan/05-recognition-module.md › Heuristic functions; legacy/plan/05-recognition-module.md › The rule: only genuinely ambiguous cases go to a human; legacy/tests/fixtures/expected/recognition.json

A subfolder of an artist folder is a band-member folder when its name differs from the parent artist and it holds release folders. The README adds: it holds only release folders, no loose files. A band-member folder becomes its own artist, named after the folder. Its releases are not added to the parent artist. They get no review reason for this.

Example: `Talking Heads\David Byrne\1994 David Byrne\01 - Angels.flac` → artist `David Byrne` (`sourcePaths` = `<SOURCE_ROOT>\Talking Heads\David Byrne`) with 1 release, `needsReview` = `false`. `Talking Heads` keeps 1 release (`Remain In Light`).

### AS-DOC-REC-030 — A subfolder with the parent artist's name is not a band-member folder
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Test-IsBandMemberFolder (private) › rejects a subfolder whose normalized name matches the parent artist; legacy/README.md › Reference: automatic folder recognition

A subfolder whose normalized name is the same as the parent artist name is not a band-member folder. A release folder inside an artist is not a band-member folder either.

Example (from the test): `Talking Heads\1980 Remain In Light` with parent artist `Talking Heads` → not a band-member folder.

Name normalization: see [02-text-and-naming-rules.md](02-text-and-naming-rules.md).

### AS-DOC-REC-031 — A category subfolder is not a band-member folder
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Test-IsBandMemberFolder (private) › rejects a category-named subfolder

A subfolder with a category name is never a band-member folder, even when it holds release folders.

Example: `ZZ Top\EPs` with parent artist `ZZ Top` → not a band-member folder.

## Grouping folders

### AS-DOC-REC-032 — A folder whose children are different artists is a grouping folder
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Test-IsGroupingFolder (private) › recognizes a grouping folder whose children are all distinct artist-like folders; legacy/README.md › Reference: automatic folder recognition; legacy/plan/05-recognition-module.md › Heuristic functions

A folder is a grouping folder when it has no loose files and its children all look like different artists (each child holds releases, and no child is a release itself).

Example: `Godspeeds and their projects` (children `Godspeed You! Black Emperor`, `Silver Mountain Zion`) → grouping folder.

### AS-DOC-REC-033 — A grouping folder has at least two subfolders
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Test-IsGroupingFolder (private) › requires at least two subfolders

A folder with fewer than two subfolders is never a grouping folder.

Example: `Empty Artist` (one subfolder `2010 Nothing Here`) → not a grouping folder.

### AS-DOC-REC-034 — An artist folder or a multi-disc release is not a grouping folder
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Test-IsGroupingFolder (private) › does not treat a normal artist folder (children are releases) as a grouping folder; … › does not treat a multi-disc release folder as a grouping folder

A folder whose children are releases is an artist folder, not a grouping folder. A folder whose children are disc folders is a release, not a grouping folder.

Example: `ZZ Top` → not a grouping folder. `ZZ Top\2003 Mescalero` (`CD 1`, `CD 2`) → not a grouping folder.

### AS-DOC-REC-035 — An artist folder with album wrapper children is not a grouping folder
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Test-IsGroupingFolder (private) › does not treat an artist folder whose children are all album-wrapper folders as a grouping folder

When the children of a folder are album wrapper folders (AS-DOC-REC-037), the folder is an artist folder, not a grouping folder. Recognize walks into it.

Example: `Wrapper Band` (children `1975 - Wrapped Album (Special Edition)`, `1990 - Loose Files Album`, `2000 - Per Disc Cue Album`, …) → not a grouping folder.

### AS-DOC-REC-036 — Recognize walks a grouping folder and flags every release for review
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › walks a grouping folder automatically, treating each subfolder as its own artist flagged for review; legacy/README.md › Reference: automatic folder recognition; legacy/plan/05-recognition-module.md › (superseded note at the top); legacy/tests/fixtures/expected/recognition.json

Recognize treats each direct subfolder of a grouping folder as its own artist. Every release found this way gets `needsReview` and the review reason `grouping-folder-auto-resolved`. The grouping folder does not go to `unrecognized[]`. The exception is AS-DOC-REC-028.

Example: `Godspeeds and their projects\Godspeed You! Black Emperor\1997 F#A# Infinity` → artist `Godspeed You! Black Emperor`, release `F#A# Infinity`, `reviewReasons` = `["grouping-folder-auto-resolved"]`. `Godspeeds and their projects\Silver Mountain Zion\2000 He Has Left Us Alone` → artist `Silver Mountain Zion`, same reason. No unrecognized entry with reason `grouping-folder-suspected`.

## Album wrapper folders

### AS-DOC-REC-037 — A "yyyy - Title" folder that wraps edition subfolders is an album wrapper
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Test-IsAlbumWrapperFolder (private) › recognizes a "yyyy - Title" folder that wraps a single edition subfolder; … › recognizes a "yyyy - Title" folder that wraps more than one edition subfolder; … › recognizes a "yyyy - Title" folder whose single edition subfolder itself has disc subfolders; legacy/README.md › Reference: automatic folder recognition; legacy/plan/05-recognition-module.md › (superseded note at the top)

A folder named `yyyy - Title` that holds no tracks itself, but holds one or more edition (pressing) subfolders, is an album wrapper. Each edition subfolder is a release folder. An edition subfolder may have disc folders.

Example: `Wrapper Band\1975 - Wrapped Album (Special Edition)` (edition `1989 Country Label 123`) → album wrapper. `1980 - Multi Edition Album` (editions `1988 Germany Label 1`, `1992 Australia Label 2`) → album wrapper. `Wrapper Band\2000 - Per Disc Cue Album` (edition `2000 Tour Edition` with `CD 1`, `CD 2`) → album wrapper.

### AS-DOC-REC-038 — A folder with tracks inside or with no leading year is not an album wrapper
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Test-IsAlbumWrapperFolder (private) › rejects a normal release folder with tracks directly inside it; … › rejects a folder whose name has no leading year

A folder that holds tracks directly is a normal release, not an album wrapper. A folder whose name does not start with a year is not an album wrapper.

Example: `ZZ Top\1999 XXX` → not an album wrapper. `ZZ Top` → not an album wrapper.

### AS-DOC-REC-039 — A subfolder that hides audio one level deeper stops the album wrapper match
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Test-IsAlbumWrapperFolder (private) › rejects a "yyyy - Title" folder with a subfolder that hides audio below an unknown extra layer of nesting

When one subfolder of a `yyyy - Title` folder is not a release folder but has audio further down, the folder is not an album wrapper. The tests do not show what recognize does with such a folder after that.

Example: `1965 - Partial Wrapper\1970 Real Edition\01 - Track.flac` plus `1965 - Partial Wrapper\Bonus Nested\Deeper\01 - Track.flac` → not an album wrapper.

### AS-DOC-REC-040 — Disc folders directly under a release make one multi-disc release, not editions
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › recognizes LP#-numbered disc folders directly under the release folder as one multi-disc release, not two separate editions (real-world 2-LP vinyl rip); … › recognizes CD_1/CD_2 (underscore-separated) disc folders directly under the release folder as one multi-disc release, not two separate editions (real-world Rosetta "The Galilean Satellites" case)

When the subfolders of a `yyyy - Title` or `yyyy Title` folder are disc folders, the folder is one multi-disc release. The disc folders are not editions. The release has no edition folder name and no `multiple-editions-in-album-folder` reason.

Example: `Wrapper Band\2004 - LP Reissue\LP#1` (2 cue tracks) and `LP#2` (3 cue tracks) → one release `LP Reissue`, `discFolderCount` = 2, 5 tracks.

Example: `Rosetta\2005 The Galilean Satellites\CD_1` (`CD1-01-rosetta-departe.mp3`, `CD1-02-rosetta-europa.mp3`) and `CD_2` (3 files) → one release `The Galilean Satellites`, `editionFolderName` = `null`, `discFolderCount` = 2, 5 tracks.

### AS-DOC-REC-041 — Title and year come from the album folder; the edition name is recorded
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › recognizes a "yyyy - Title" album wrapper around a single edition subfolder, title/year from the album folder; legacy/README.md › Reference: automatic folder recognition; legacy/tests/fixtures/expected/recognition.json

For a release inside an album wrapper, the title and the year always come from the album wrapper folder. The edition folder name is stored in `editionFolderName`. The release source folder is the edition folder. A wrapper with one edition gets no review reason.

Example: `Wrapper Band\1975 - Wrapped Album (Special Edition)\1989 Country Label 123\` (2 tracks) → release `Wrapped Album (Special Edition)`, year 1975, `editionFolderName` = `1989 Country Label 123`, `sourceFolderPath` = `…\1975 - Wrapped Album (Special Edition)\1989 Country Label 123`, `needsReview` = `false`.

### AS-DOC-REC-042 — Several editions in one album wrapper become separate reviewed releases
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › splits an album wrapper with two edition subfolders into two reviewed releases with distinct stableKeys; legacy/README.md › Reference: automatic folder recognition

When an album wrapper holds more than one edition subfolder, each edition becomes its own release. All of them have the same title. Each one gets its own edition folder name, its own stable key, `needsReview` and the review reason `multiple-editions-in-album-folder`.

Example: `Wrapper Band\1980 - Multi Edition Album\1988 Germany Label 1\01 - Track One.flac` and `…\1992 Australia Label 2\01 - Track One.flac` → 2 releases `Multi Edition Album`, 2 different `editionFolderName` values, 2 different `stableKey` values, both with `multiple-editions-in-album-folder`.

### AS-DOC-REC-043 — A loose file in an album wrapper flags the release and stays out
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › flags a release for review when its album wrapper folder has a loose file, and does not copy that file in

When an album wrapper folder holds a loose file next to its edition subfolder, the release gets `needsReview` and the review reason `album-folder-has-loose-files`. The loose file is not in the release's companion files or ignored files.

Example: `Wrapper Band\1990 - Loose Files Album\cover.jpg` plus `…\1991 Some Edition\01 - Track One.flac` → release `Loose Files Album` (edition `1991 Some Edition`), `reviewReasons` contains `album-folder-has-loose-files`. `cover.jpg` is in neither `companionFiles` nor `ignoredFiles`.

## Release folder names

### AS-DOC-REC-044 — Year and title from the release folder name
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › parses year and title for each supported release folder name form; … › strips the dash from a "yyyy - Release Name" source folder in the fixture tree

A release folder name that starts with a 4-digit year gives the year and the title. The year and the title can be separated by a space, by `" - "`, by `" – "` (en dash) or by `-` with no spaces. The separator is not part of the title.

Example:

| Folder | Year | Title |
|---|---|---|
| `1999 XXX` | 1999 | `XXX` |
| `1999 - XXX` | 1999 | `XXX` |
| `1999 – XXX` | 1999 | `XXX` |
| `2006-Fire Without Flame` | 2006 | `Fire Without Flame` |
| `Cranberries\1993 - Everybody Else Is Doing It` | 1993 | `Everybody Else Is Doing It` |

### AS-DOC-REC-045 — A dash inside the title stays when the artist is known
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › parses year and title for each supported release folder name form; … › does not split a release title containing " - " when a real artist context already exists

Inside an artist folder, a `" - "` after the year is part of the title. Recognize does not split it into artist and title. The release gets no review reason for it.

Example: `Live Wire\1990 Live - The Tour` → artist `Live Wire`, release `Live - The Tour`, year 1990, `needsReview` = `false`, no `artist-name-split-from-folder-name`.

### AS-DOC-REC-046 — A year range is not a year
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › parses year and title for each supported release folder name form

A folder name that starts with a year range gets no year. The whole name becomes the title.

Example: `1999-2003 Anthology` → year `null`, title `1999-2003 Anthology`.

### AS-DOC-REC-047 — A leading 4-digit number that is not a year is kept in the title
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › does not misparse a leading 4-digit non-year number (e.g. a catalog number) as recognizedYear; legacy/tests/fixtures/expected/recognition.json

A 4-digit number outside the valid year range is not read as a year. It stays in the title. The docs and tests do not state the year range.

Example: `Isidor - 3218 (Soldier of Fortune Edition - Artwork)` → year `null`, title `3218 (Soldier of Fortune Edition - Artwork)`.

### AS-DOC-REC-048 — A full date "yyyy.MM.dd - Title" gives the release date and the year
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › parses a full release date and a release-type hint from each real-world folder name form (session 2026-10-03-0010, Maximum The Hormone)

A folder name that starts with a valid date `yyyy.MM.dd` followed by `" - "` gives the release date (as `yyyy-MM-dd`), the year and the title. A folder name with only a year has no release date.

Example:

| Folder | Year | Date | Title |
|---|---|---|---|
| `1999.08.29 - (album) A.S.A. Crew` | 1999 | `1999-08-29` | `A.S.A. Crew` |
| `2004.06.23 - (single) Rock Bankurawase` | 2004 | `2004-06-23` | `Rock Bankurawase` |
| `2001 - Hou (EP)` | 2001 | `null` | `Hou` |

### AS-DOC-REC-049 — An invalid date leaves the whole folder name as the title
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › parses a full release date and a release-type hint from each real-world folder name form (session 2026-10-03-0010, Maximum The Hormone)

When the date at the start of a folder name is not a real date, the release gets no date, no year and no release type. The whole folder name becomes the title.

Example: `2006.13.01 - X` (month 13) → year `null`, date `null`, type `null`, title `2006.13.01 - X`.

### AS-DOC-REC-050 — A release type hint in brackets is taken out of the title
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Split-ReshelfReleaseTypeHint (private) › strips a leading "(album)" hint; … › strips a trailing "(EP)" hint regardless of letter case; … › strips a trailing "[EP]" hint written with square brackets; … › normalizes a "mini-album" hint with a space to a hyphenated type; … › Invoke-ReshelfRecognition › parses a full release date and a release-type hint from each real-world folder name form (session 2026-10-03-0010, Maximum The Hormone)

A known release type word in round or square brackets, at the start or at the end of the title, is removed from the title. It is stored in lower case as the release type. `mini album` (with a space) is stored as `mini-album`. The known words in the tests are `album`, `single`, `ep`, `mini-album`.

Example:

| Title or folder | Title | Type |
|---|---|---|
| `(album) A.S.A. Crew` | `A.S.A. Crew` | `album` |
| `Hou (EP)` | `Hou` | `ep` |
| `'Kyo's Poem Book' [EP]` | `'Kyo's Poem Book'` | `ep` |
| `(mini album) Ootori` | `Ootori` | `mini-album` |
| `2001.08.01 - (mini-album) Ootori` | `Ootori` | `mini-album` |
| `2008 - Tsume Tsume Tsume'F (Single)` | `Tsume Tsume Tsume'F` | `single` |

### AS-DOC-REC-051 — Other bracket words stay in the title
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Split-ReshelfReleaseTypeHint (private) › leaves a trailing bracket group untouched when it is not a known release-type word; … › leaves a title with no bracket group untouched

A bracket group that is not a known release type word stays in the title. A title with no bracket group does not change. In both cases the release type is empty.

Example: `Greatest (Deluxe)` → title `Greatest (Deluxe)`, no type. `Rokkinpo Goroshi` → title `Rokkinpo Goroshi`, no type.

### AS-DOC-REC-052 — The artist name at the start of a release folder name is removed
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Remove-ReshelfArtistNamePrefixFromTitle (private) › strips the artist name and a dash separator regardless of letter case; … › strips a colon separator; … › Invoke-ReshelfRecognition › strips a release folder name that repeats its own artist name (real-world case), without needsReview; legacy/plan/05-recognition-module.md › Deterministic cleanups added against real data (plan/12 milestone 3); legacy/tests/fixtures/expected/recognition.json

When a release folder name starts with its own artist name, followed by a separator, recognize removes the artist name and the separator from the title. The match ignores letter case. Separators: `-`, `:`, en dash, em dash (plan). The release gets the recognition flag `artist-name-prefix-stripped`. It does not get `needsReview`.

Example: `Dance With Ghosts\DANCE WITH GHOSTS - Requiem` → title `Requiem`, year `null`, `recognitionFlags` = `["artist-name-prefix-stripped"]`, `needsReview` = `false`.

Example: title `DANCE WITH THE DEAD - Blackout`, artist `Dance with the dead` → `Blackout`. Title `Some Band: Live Album`, artist `Some Band` → `Live Album`.

### AS-DOC-REC-053 — A year between the artist name and the separator becomes the release year
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Remove-ReshelfArtistNamePrefixFromTitle (private) › strips a parenthesized year between the artist name and the separator, and returns it (real Aerosmith case); … › strips a bracketed year between the artist name and the separator; … › Invoke-ReshelfRecognition › parses the year when it sits between a repeated artist-name prefix and the title (real-world Nostromo case); … › parses the year when it sits in parentheses after a repeated artist-name prefix (real-world Aerosmith case)

When a year sits between the artist name prefix and the title, recognize removes it with the prefix and uses it as the release year. The year can be in round brackets, in square brackets, or between two `" - "` separators.

Example: `Aerosmith\Aerosmith (1979) - Night In The Ruts [Austria 466720 2]` → year 1979, title `Night In The Ruts [Austria 466720 2]`, flag `artist-name-prefix-stripped`.

Example: `Nostromo\Nostromo - 1998 - Argue FLAC` → year 1998, title `Argue FLAC`, flag `artist-name-prefix-stripped`.

Example: title `Aerosmith (1973) - Aerosmith [USA CK 32005]` → `Aerosmith [USA CK 32005]`, year 1973. Title `Aerosmith [1977] - Draw the Line` → `Draw the Line`, year 1977.

### AS-DOC-REC-054 — The title stays as it is when the artist name is not a real prefix
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Remove-ReshelfArtistNamePrefixFromTitle (private) › leaves the title untouched when the 4-digit group is outside the year range; … › leaves the title untouched when it does not start with the artist name; … › leaves the title untouched when the artist name is a prefix but not followed by a separator; … › leaves the title untouched when stripping would leave nothing; legacy/tests/fixtures/expected/recognition.json

Recognize does not change the title in these cases: the title does not start with the artist name; the artist name is not followed by a separator; nothing would be left after the separator; the 4-digit group after the artist name is not a valid year.

Example:

| Title | Artist | Result |
|---|---|---|
| `Live - The Tour` | `Live Wire` | `Live - The Tour` |
| `Dance With The Devil` | `Dance` | `Dance With The Devil` |
| `Some Band -` | `Some Band` | `Some Band -` |
| `Some Band (3218) - X` | `Some Band` | `Some Band (3218) - X` (no year) |
| `David Byrne` (folder `1994 David Byrne`) | `David Byrne` | `David Byrne` (golden file) |

## Track file names and track order

### AS-DOC-REC-055 — Track number and title from "NN - Title", "NN – Title" and "NN Title"
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › ConvertFrom-ReshelfTrackFileName (private) › parses a dash-separated numbered filename; … › parses an en-dash-separated numbered filename; … › parses a space-only numbered filename with no separator; … › Invoke-ReshelfRecognition › parses a numbered track filename with no dash separator in the fixture tree; legacy/plan/05-recognition-module.md › Track/disc parsing

A leading number in a track file name is the track number. The rest, without the separator and without the extension, is the title. The separator can be `-`, `–` (en dash) or only a space.

Example: `01 - Poke Chop Sandwich.flac` → 1, `Poke Chop Sandwich`. `02 – Crucifixx A Flatt.flac` → 2, `Crucifixx A Flatt`. `03 Some Track.mp3` → 3, `Some Track`. In the fixture tree, `ZZ Top\1999 XXX\02 Crucifixx A Flatt.flac` → `detectedTrackNumberInDisc` = 2, `inferredTrackOrder` = `false`.

### AS-DOC-REC-056 — A track number in brackets is read
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › ConvertFrom-ReshelfTrackFileName (private) › parses a bracketed numbered filename (real Various-Artists rip case, "[01] Blind Guardian - ..."); … › parses a parenthesized numbered filename

A track number in square or round brackets at the start of the file name is read as the track number.

Example: `[01] Blind Guardian - Don't Talk To Stranger.mp3` → 1, title `Blind Guardian - Don't Talk To Stranger`. `(02) Some Track.flac` → 2, `Some Track`.

### AS-DOC-REC-057 — A year in brackets is not a track number
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › ConvertFrom-ReshelfTrackFileName (private) › does not read a parenthesized year as a track number

A 4-digit year in round brackets at the start of a file name is not a track number.

Example: `(1999) Some Track.flac` → no track number.

### AS-DOC-REC-058 — A file name without a number keeps the whole name as the title
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › ConvertFrom-ReshelfTrackFileName (private) › falls back to the whole filename when no number is present

When a file name has no leading number, the track has no number. The whole name without the extension is the title.

Example: `Alpha Song.flac` → no number, title `Alpha Song`.

### AS-DOC-REC-059 — "Artist - Title" inside a track title is split into two parts
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › ConvertFrom-ReshelfTrackFileName (private) › parses a bracketed numbered filename (real Various-Artists rip case, "[01] Blind Guardian - ..."); … › leaves ArtistPart/TitlePart null when the title has no "Artist - Title" dash

When the title from a file name has the form `Artist - Title`, recognize also keeps an artist part and a title part. When there is no such dash, both parts are empty. The full title stays as it is.

Example: `[01] Blind Guardian - Don't Talk To Stranger.mp3` → artist part `Blind Guardian`, title part `Don't Talk To Stranger`. `03 Some Track.mp3` → no parts.

How compilations use per-track artists: see [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md).

### AS-DOC-REC-060 — Tracks are ordered by their numbers when every file has one
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Get-ReshelfTrackOrder (private) › orders fully-numbered files by their parsed number; … › Invoke-ReshelfRecognition › recognizes a normal single-disc release with correct track order

When every audio file in a folder has a track number, the tracks are ordered by that number. The order is not inferred.

Example: `02 - Second.mp3`, `01 - First.mp3` → order 1, 2, `inferredTrackOrder` = `false` for both. `ZZ Top\1999 XXX` → first track has number 1.

### AS-DOC-REC-061 — When any file has no number, the whole folder uses file name order
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Get-ReshelfTrackOrder (private) › falls back to whole-folder alphabetical order when any file lacks a number; … › Invoke-ReshelfRecognition › falls back to whole-folder alphabetical order for unnumbered tracks; legacy/plan/05-recognition-module.md › Track/disc parsing; legacy/tests/fixtures/expected/recognition.json

When at least one audio file in a folder has no track number, all files in that folder are ordered A–Z by file name. Every track gets `inferredTrackOrder` = `true`. The track number becomes the position in that order. The release gets the recognition flag `no-track-number`. This alone does not set `needsReview`.

Example: `01 - First.mp3`, `Unnumbered.mp3` → order `01 - First.mp3`, `Unnumbered.mp3`, both inferred. `Unnumbered\2015 No Numbers` → `Alpha Song.flac` (1), `Beta Song.flac` (2), flag `no-track-number`, `needsReview` = `false`.

## Disc folders

### AS-DOC-REC-062 — Disc folder names
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Test-IsDiscFolder / Get-ReshelfDiscFolders (private) › recognizes CD/Disc/Disk variants case-insensitively; … › recognizes LP-prefixed disc folders, including a "#" separator; … › recognizes an underscore separator (real-world CD_1/CD_2 rip case); legacy/plan/05-recognition-module.md › Track/disc parsing

A folder is a disc folder when its name is `CD`, `Disc`, `Disk` or `LP`, then a number. Letter case does not matter. Between the word and the number there can be nothing, a space, `.`, `_` or `#`.

Example: `CD 1`, `cd1`, `Disc 2`, `DISK.3`, `LP#1`, `LP#2`, `LP 1`, `lp.1`, `CD_1`, `CD_2` → disc folders. `Bonus Disc` → not a disc folder.

### AS-DOC-REC-063 — A disc folder name can have text after a separator
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Test-IsDiscFolder / Get-ReshelfDiscFolders (private) › recognizes a disc number followed by trailing text after a separator; … › does not match a disc number that runs straight into trailing text with no separator; … › recognizes LP-prefixed disc folders, including a "#" separator

After the disc number, a disc folder name can have more text when a separator comes first. Text that follows the number with no separator makes it not a disc folder.

Example: `CD1. Forwards`, `CD2. Sideways`, `Disc 2 - Bonus` → disc folders. `CD10Something`, `LP10Something` → not disc folders.

### AS-DOC-REC-064 — The disc number comes from the disc folder name
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Get-ReshelfDiscNumber (private) › parses an exact CD-number/Disc-number name with no trailing text; … › parses an LP#-numbered name (real-world 2-LP vinyl rip case); … › parses an underscore-separated name (real-world CD_1/CD_2 rip case); … › parses a disc number followed by trailing text after a separator; … › returns $null for a disc number that runs straight into trailing text with no separator

Recognize reads the disc number from a disc folder name. A name that is not a disc folder name gives no number.

Example: `CD1` → 1, `Disc 2` → 2, `LP#1` → 1, `LP#2` → 2, `CD_1` → 1, `CD_2` → 2, `CD1. Forwards` → 1, `CD2. Sideways` → 2, `CD10Something` → no number.

### AS-DOC-REC-065 — Disc folders are sorted by number
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Test-IsDiscFolder / Get-ReshelfDiscFolders (private) › sorts disc folders numerically, not lexically

Recognize sorts the disc folders of a release by their disc number, not by their names as text.

Example: `ZZ Top\2003 Mescalero` → 2 disc folders, in the order `CD 1`, `CD 2`.

### AS-DOC-REC-066 — In a multi-disc release, each track records its disc folder
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › recognizes a multi-disc release with correct disc folder names and combined track count; legacy/plan/05-recognition-module.md › Track/disc parsing; legacy/tests/fixtures/expected/recognition.json

A multi-disc release counts its discs in `discFolderCount`. Each track records the name of its disc folder in `discFolder`. The track number restarts at 1 in each disc. A release without disc folders has `discFolderCount` = 1 and `discFolder` = `null` on each track. Recognize does not compute a track number across all discs.

Example: `ZZ Top\2003 Mescalero` → `discFolderCount` = 2, `CD 1` has 2 tracks (1, 2), `CD 2` has 3 tracks (1, 2, 3).

Track numbers in the target names: see [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md).

### AS-DOC-REC-067 — A loose audio file in a multi-disc release is kept and flagged
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › records a stray audio file sitting loose in a multi-disc release, flagged for review, instead of dropping it; legacy/tests/fixtures/expected/recognition.json

An audio file directly in a multi-disc release folder, outside the disc folders, stays a track of the release. Its `discFolder` is `null`. The release gets `needsReview` and the review reason `track-outside-disc-folder-suspected`.

Example: `ZZ Top\2003 Mescalero\Stray Bonus Track.mp3` → track with `discFolder` = `null`. In the golden file it has number 1 and `inferredTrackOrder` = `true`, and the release has the flag `no-track-number`.

## Cue sheets

### AS-DOC-REC-068 — One audio file plus a cue sheet becomes cue virtual tracks
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › builds cue-sheet virtual tracks and routes the playlist file to ignoredFiles; legacy/plan/05-recognition-module.md › Single-file + cue detection; legacy/tests/fixtures/expected/recognition.json

When a release folder (or a disc folder) has one audio file and a cue sheet for it, recognize records the pair in `cueSheets` (`cueFilePath`, `audioFilePath`). It makes one virtual track per cue track. Each virtual track points at the shared audio file, has `isCueVirtualTrack` = `true` and stores its start time in `cueTimestamp`. The cue track title goes into `existingTags.title`. Recognize does not split the audio file.

Example: `Pink Floyd\1994 Live In Concert (Bootleg)\Live In Concert.flac` + `Live In Concert.cue` → `cueSheets` has 1 entry. 2 tracks: `Speak To Me` (number 1, `cueTimestamp` `00:00:00`) and `Breathe` (number 2, `03:12:45`). Both have `originalFileName` = `Live In Concert.flac`.

The split itself: see [10-apply.md](10-apply.md).

### AS-DOC-REC-069 — Each cue TRACK gives a title and a start time
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › ConvertFrom-ReshelfCueSheet (private) › parses a well-formed cue sheet into ordered virtual tracks

Recognize reads each `TRACK` entry of a cue sheet in file order. It takes the track `TITLE` and the `INDEX 01` time as the start time.

Example: `Live In Concert.cue` → track 1 `Speak To Me` at `00:00:00`, track 2 `Breathe` at `03:12:45`.

### AS-DOC-REC-070 — A cue sheet with no TRACK entry, or a missing cue file, gives no tracks
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › ConvertFrom-ReshelfCueSheet (private) › returns $null for a cue file with no TRACK entries; … › returns $null for a missing cue file

A cue sheet without any `TRACK` entry gives no virtual tracks. A cue file that does not exist gives no virtual tracks. Neither case is an error.

Example: `malformed.cue` with only `PERFORMER "Nobody"` → no tracks. `does-not-exist.cue` → no tracks.

### AS-DOC-REC-071 — A cue file in Windows-1252 without a BOM is read correctly
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › ConvertFrom-ReshelfCueSheet (private) › correctly decodes accented titles from a Windows-1252-encoded cue file (no BOM)

Recognize reads a cue file that has no BOM (byte order mark, a marker for the text encoding) and is in the Windows-1252 encoding. Accented letters stay correct.

Example: a cue file in Windows-1252 with `TITLE "Für einen Augenblick"` → track title `Für einen Augenblick`, not a title with `?` characters.

### AS-DOC-REC-072 — The cue header gives the disc performer and the disc number
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Get-ReshelfCueSheetHeader (private) › reads the disc-level PERFORMER and REM DISCNUMBER, ignoring a per-track PERFORMER; … › returns $null fields when the cue has no header lines; … › returns $null for a missing cue file

Recognize reads the disc-level `PERFORMER` and `REM DISCNUMBER` lines of a cue sheet (the lines before the first `TRACK`). A `PERFORMER` inside a track is not used. Without header lines, both values are empty. A missing cue file gives no header.

Example:

```
REM DISCNUMBER 2
PERFORMER "Iron Maiden"
TITLE "Best Of The Beast (TOCP-50129)"
  TRACK 01 AUDIO
    PERFORMER "A Different Performer"
```

→ performer `Iron Maiden`, disc number 2.

### AS-DOC-REC-073 — Each cue track gets its own duration
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › builds cue-sheet virtual tracks and routes the playlist file to ignoredFiles; legacy/tests/fixtures/expected/recognition.json

The duration of a cue track is the start of the next track minus its own start. The last track's duration is the whole file's duration minus its own start. Cue times are `mm:ss:ff`, where `ff` is a frame (1/75 second).

Example: `Live In Concert.flac` with a whole-file duration of 200 s (mock) → `Speak To Me` 192.6 s (`03:12:45` = 192.6 s), `Breathe` 7.4 s.

Example (golden file): `2000 - Per Disc Cue Album\2000 Tour Edition\CD 1\Disc One.flac` (200 s), tracks at `00:00:00` and `02:00:00` → 120 s and 80 s.

### AS-DOC-REC-074 — Cue tracks from an .ape file are recorded as flac
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › names cue-sheet virtual tracks from an .ape source as flac, since ffmpeg cannot write .ape

When the audio file of a cue sheet is an `.ape` file, every virtual track has `format` = `flac` and `isLossless` = `true`. The test comment gives the reason: apply cannot write `.ape`, so it writes `.flac`.

Example: `APE Cue Band\1993 APE Bootleg\Show.ape` + `Show.cue` (tracks `Intro`, `Main Set`) → 2 tracks, both `format` = `flac`, `isLossless` = `true`.

The re-encoding during the split: see [10-apply.md](10-apply.md).

### AS-DOC-REC-075 — How recognize picks the cue sheet for an audio file
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Get-ReshelfCueSheetPathForAudio (private) › returns $null when there are no cue files; … › returns the only cue file regardless of its name when exactly one exists; … › picks the cue file matching audioname.ext.cue out of several; … › picks the cue file matching the audio file's base name out of several; … › returns $null when several cue files exist and none names the audio file; … › prefers the audioname.ext.cue match over a basename.cue match naming the same audio file

Recognize picks the cue sheet for an audio file in a folder by these rules:

1. No cue file → no cue sheet.
2. Exactly one cue file → that one, whatever its name.
3. Several cue files → the one named `<audio file name with extension>.cue`. If there is none, the one named `<audio base name>.cue`. When both exist, the first one wins.
4. Several cue files and none matches the audio file name → no cue sheet.

Example: audio `Album.flac`:

| Cue files | Result |
|---|---|
| none | none |
| `tracklist.cue` | `tracklist.cue` |
| `Album.flac.cue`, `Album.wav.cue` | `Album.flac.cue` |
| `Album.cue`, `Album.wav.cue` | `Album.cue` |
| `Other.flac.cue`, `Other.wav.cue` | none |

Example: audio `Album.ape`, cue files `Album.ape.cue` and `Album.cue` → `Album.ape.cue`.

### AS-DOC-REC-076 — An extra cue file for another format does not stop cue detection
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › still recognizes a single-file + .cue release when an orphaned second .cue for an unused rip format is also present

A release with one audio file and two cue files is still a cue release, when one cue file matches the audio file name (AS-DOC-REC-075).

Example: `Some Artist\2003 Some Album\Some Album.flac` + `Some Album.flac.cue` (2 tracks) + `Some Album.wav.cue` (no `.wav` file exists) → `cueSheets` has 1 entry with `cueFilePath` = `…\Some Album.flac.cue`. 2 tracks, the second has `existingTags.title` = `Second Track`.

### AS-DOC-REC-077 — Each disc folder can have its own cue sheet
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › builds cueSheets per disc for a per-disc-cue release nested inside an album wrapper; legacy/plan/05-recognition-module.md › Single-file + cue detection; legacy/tests/fixtures/expected/recognition.json

When each disc folder of a release holds one audio file and its cue sheet, each disc gets its own `cueSheets` entry and its own virtual tracks. No cue file is ignored as unused. The release gets no review reason for this.

Example: `Wrapper Band\2000 - Per Disc Cue Album\2000 Tour Edition\CD 1\Disc One.flac` + `Disc One.cue`, and `CD 2\Disc Two.flac` + `Disc Two.cue` → 2 `cueSheets`, `discFolderCount` = 2, 3 virtual tracks (2 in `CD 1`, 1 in `CD 2`), no `cue-sheet-not-used`, no `per-disc-cue-not-yet-supported`.

Example (golden file): `Wrapper Band\2004 - LP Reissue\LP#1\Side One.cue` and `LP#2\Side Two.cue` → 2 `cueSheets`.

### AS-DOC-REC-078 — One release can mix a cue disc and a normal disc
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › mixes a cue-image disc with a normal numbered-track disc in the same release

In a multi-disc release, one disc can be an audio file with a cue sheet and another disc can be normal track files. Each disc is handled by its own form.

Example: `Wrapper Band\2001 - Mixed Disc Album\2001 Tour Edition\CD 1\Disc One.flac` + `Disc One.cue` → 2 virtual tracks. `CD 2\01 - Track One.flac`, `02 - Track Two.flac` → 2 normal tracks. The release has 1 `cueSheets` entry.

## Flat multi-disc cue pairs

### AS-DOC-REC-079 — Several audio files with one cue each, without disc folders, become one disc per pair
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Get-ReshelfFlatDiscCuePairs (private) › pairs each audio file with its own distinct cue, ordering by the catalog-number hint in the folder name (real-world Iron Maiden "The X Factor" case); … › Invoke-ReshelfRecognition › splits a flat multi-disc folder (several flac+cue pairs, no CD subfolders) into one disc per pair, ordered by catalog-number hint in the folder name (real-world Iron Maiden "The X Factor" case); legacy/README.md › Reference: automatic folder recognition

When a release folder directly holds two or more audio files and each one has its own cue sheet, each audio + cue pair becomes one disc. Each disc is split like any other cue release. The release gets `needsReview` and the review reason `flat-multi-disc-cue-pairs`, so the user can check the disc order. No cue file is ignored as unused. Each track's `discFolder` holds a disc label that contains the pair's catalog number.

Example: `Iron Maiden\1995 - The X Factor (TOCP-8588)\` with `Iron Maiden - The X Factor (TOCP-8588).flac` + `.cue` (2 tracks) and `Iron Maiden - The X Factor (BCD-0033).flac` + `.cue` (1 track) → `discFolderCount` = 2, 2 `cueSheets`, disc 1 label contains `TOCP-8588` (2 tracks), disc 2 label contains `BCD-0033` (1 track).

### AS-DOC-REC-080 — Flat cue pairs are ordered by REM DISCNUMBER when every cue has one
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Get-ReshelfFlatDiscCuePairs (private) › orders by REM DISCNUMBER when every cue has one, even if it disagrees with the folder-name hint; … › Invoke-ReshelfRecognition › orders flat multi-disc pairs by REM DISCNUMBER, even when it disagrees with the catalog-number hint in the folder name; legacy/README.md › Reference: automatic folder recognition

When every cue sheet of the pairs has a `REM DISCNUMBER` line, the discs follow these numbers. This rule wins over the catalog number in the folder name.

Example: folder `1995 - The X Factor (TOCP-8588)`, `…(TOCP-8588).cue` has `REM DISCNUMBER 2`, `…(BCD-0033).cue` has `REM DISCNUMBER 1` → disc 1 is `BCD-0033`, disc 2 is `TOCP-8588`.

### AS-DOC-REC-081 — Otherwise the pair named in the folder goes first
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Get-ReshelfFlatDiscCuePairs (private) › pairs each audio file with its own distinct cue, ordering by the catalog-number hint in the folder name (real-world Iron Maiden "The X Factor" case); legacy/README.md › Reference: automatic folder recognition

When not every cue has `REM DISCNUMBER`, the pair whose catalog number appears in the release folder name goes first. The catalog number is the last text in round brackets in the file name. The other pairs follow in file name order.

Example: folder `1995 - The X Factor (TOCP-8588)`, cue files with only `PERFORMER "Iron Maiden"` → disc 1 `Iron Maiden - The X Factor (TOCP-8588).flac`, disc 2 `Iron Maiden - The X Factor (BCD-0033).flac`.

### AS-DOC-REC-082 — Without one cue per audio file, the files are normal tracks
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Get-ReshelfFlatDiscCuePairs (private) › returns an empty list when 2 audio files share a single cue (not one cue per disc); … › returns an empty list when fewer than 2 audio files are present; … › Invoke-ReshelfRecognition › falls back to the old ordinary-track behavior when 2 audio files share a single cue (not one cue per disc)

Flat cue pairs need at least two audio files and a separate cue for each one. When several audio files share one cue file, recognize treats the audio files as normal tracks. The cue file goes to `ignoredFiles` with reason `cue-sheet-not-used`. One audio file with one cue is not a flat pair; it is a normal cue release (AS-DOC-REC-068).

Example: `Some Artist\2003 Some Album\01 - Track One.flac`, `02 - Track Two.flac`, `Album.cue` → `discFolderCount` = 1, 0 `cueSheets`, 2 normal tracks, `Album.cue` ignored with `cue-sheet-not-used`.

Example: `Track A.flac` + `Track A.cue` → no flat pairs.

## Companion and ignored files

### AS-DOC-REC-083 — A companion file is loose or nested
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Get-ReshelfCompanionFiles (private) › classifies loose and nested companions, routing playlists to ignored; … › classifies a nested companion file under a non-disc subfolder; … › Invoke-ReshelfRecognition › recognizes a multi-disc release with correct disc folder names and combined track count; legacy/plan/05-recognition-module.md › Companion file classification

A non-audio file of a release is a companion file. Its placement is `loose` when it sits directly in the release folder and `nested` when it sits in a subfolder that is not a disc folder.

Example: `ZZ Top\1999 XXX\cover.jpg` → placement `loose`. `ZZ Top\2003 Mescalero\scans\back.jpg` → placement `nested`.

### AS-DOC-REC-084 — The kind of a companion file
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Get-ReshelfCompanionFiles (private) › classifies loose and nested companions, routing playlists to ignored; … › classifies a nested companion file under a non-disc subfolder; legacy/plan/05-recognition-module.md › Companion file classification; legacy/tests/fixtures/expected/recognition.json

Each companion file gets a kind from its extension and its name. In the tests: an image gets kind `cover`; an image named `back` in a `scans` subfolder gets kind `booklet`. The plan also names a `text` kind for `.txt`, `.pdf` and `.nfo` files with words like `lyrics`, `article` or `interview` in the name. No test covers the `text` kind.

Example: `ZZ Top\1999 XXX\cover.jpg` → `{ "kind": "cover", "placement": "loose" }`. `ZZ Top\2003 Mescalero\scans\back.jpg` → `{ "kind": "booklet", "placement": "nested" }`. Golden file: `…\1989 Country Label 123\scans\back.jpg` → `booklet`, `nested`.

What apply does with companion files: see [10-apply.md](10-apply.md).

### AS-DOC-REC-085 — A file with no extension is a companion of kind "other"
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Get-ReshelfCompanionFiles (private) › classifies a file with no extension at all as a companion of kind other, instead of throwing

A file without an extension in a release folder is a companion file of kind `other`. Recognize does not fail on it.

Example: `Some Release\Extensionless` (0 bytes) → one companion, kind `other`, placement `loose`.

### AS-DOC-REC-086 — Playlist files are ignored
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Get-ReshelfCompanionFiles (private) › routes a playlist file to ignored with reason playlist-file; … › Invoke-ReshelfRecognition › builds cue-sheet virtual tracks and routes the playlist file to ignoredFiles; … › routes a playlist file inside a disc subfolder to ignoredFiles instead of dropping it; legacy/plan/05-recognition-module.md › Companion file classification

A playlist file goes to `ignoredFiles` with reason `playlist-file`. It is not a companion file. The plan names `.m3u`, `.m3u8` and `.pls`, and says playlist files are never copied.

Example: `Pink Floyd\1994 Live In Concert (Bootleg)\playlist.m3u` → `{ "reason": "playlist-file" }` (the only ignored file of that release). `ZZ Top\2003 Mescalero\CD 1\setlist.m3u` → ignored, `playlist-file`.

### AS-DOC-REC-087 — Audio files in disc folders are tracks; other files there are still checked
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Get-ReshelfCompanionFiles (private) › excludes audio files under disc subfolders (those are tracks, not companions), but still catches a non-audio file there

Audio files inside disc folders are tracks, never companion files. Non-audio files inside disc folders are still classified as companion files or ignored files.

Example: `ZZ Top\2003 Mescalero\CD 1\01 - Track One.mp3` → not a companion. `ZZ Top\2003 Mescalero\CD 1\setlist.m3u` → in the ignored files.

### AS-DOC-REC-088 — A cue file in use is left out; an unused cue file is ignored
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Get-ReshelfCompanionFiles (private) › routes a playlist file to ignored with reason playlist-file; … › routes an unused .cue file to ignored with reason cue-sheet-not-used when no CueSheetPaths is given; … › Invoke-ReshelfRecognition › builds cue-sheet virtual tracks and routes the playlist file to ignoredFiles

A cue file that recognize uses for virtual tracks is neither a companion file nor an ignored file. A cue file that recognize does not use goes to `ignoredFiles` with reason `cue-sheet-not-used`.

Example: `Pink Floyd\1994 Live In Concert (Bootleg)` with `Live In Concert.cue` in use → `ignoredFiles` holds only `playlist.m3u`. When the same cue is not in use → `Live In Concert.cue` ignored with `cue-sheet-not-used`.

## Track properties and existing tags

### AS-DOC-REC-089 — Recognize reads existing tags and audio properties from each file
Status: Draft | Source: legacy/plan/05-recognition-module.md › Reading existing tags; legacy/plan/05-recognition-module.md › Manual setup; legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition (Describe-level mock); legacy/tests/fixtures/expected/recognition.json

For each audio file, recognize reads the existing artist, album and title tags, the embedded cover, the format, whether it is lossless, and the duration. The plan uses the TagLibSharp library for this. A virtual cue track takes its title from the cue sheet (AS-DOC-REC-068).

Example (golden file, tags empty in the mock): `ZZ Top\2003 Mescalero\CD 1\01 - Track One.mp3` → `format` = `mp3`, `isLossless` = `false`, `durationSeconds` = 200, `existingTags` all `null`.

Where TagLibSharp is set up (`taglibSharpPath`): see [03-settings-and-secrets.md](03-settings-and-secrets.md). The lossless/lossy decision: see [11-lossy-tracking.md](11-lossy-tracking.md).

### AS-DOC-REC-090 — A file whose audio properties cannot be read flags the release
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › flags a release for review when a track's audio properties could not be read

When the audio properties of a track cannot be read, the track gets duration 0. The release gets `needsReview` and the review reason `audio-properties-unreadable`.

Example: `ZZ Top\1999 XXX\01 - Poke Chop Sandwich.flac` with unreadable properties → `durationSeconds` = 0, release `XXX` has `audio-properties-unreadable`.

## Flags, review reasons and confidence

### AS-DOC-REC-091 — Review reasons set needsReview; recognition flags do not
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition (all It blocks that check needsReview, reviewReasons or recognitionFlags); legacy/plan/05-recognition-module.md › Deterministic cleanups added against real data (plan/12 milestone 3); legacy/tests/fixtures/expected/recognition.json

A release has `needsReview` = `true` when it has at least one review reason. A recognition flag alone does not set `needsReview`.

Review reasons seen in the inputs: `nested-release-suspected`, `artist-name-split-from-folder-name`, `artist-and-album-from-tags`, `grouping-folder-auto-resolved`, `multiple-editions-in-album-folder`, `album-folder-has-loose-files`, `track-outside-disc-folder-suspected`, `flat-multi-disc-cue-pairs`, `audio-properties-unreadable`.

Recognition flags seen in the inputs: `artist-name-prefix-stripped`, `no-track-number`, `path-near-length-limit`.

Example: `Dance With Ghosts\DANCE WITH GHOSTS - Requiem` → flag `artist-name-prefix-stripped`, `needsReview` = `false`. `Godspeeds and their projects\Silver Mountain Zion\2000 He Has Left Us Alone` → reason `grouping-folder-auto-resolved`, `needsReview` = `true`.

How the review page shows them: see [09-review-ui.md](09-review-ui.md).

### AS-DOC-REC-092 — A path near the length limit is flagged, not an error
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › flags a near-path-length-limit release without throwing; legacy/plan/05-recognition-module.md › Edge cases

When a release path is close to the Windows path length limit, recognize does not fail. The release gets the recognition flag `path-near-length-limit`.

Example: `<source root>\Long Artist aaaa…a\1990 Long Path Album\01 - track.mp3`, with the folder path about 250 characters long → no error, release has the flag `path-near-length-limit`.

General path length and invalid character rules: see [13-bandcamp-and-errors.md](13-bandcamp-and-errors.md).

### AS-DOC-REC-093 — Each release has a recognition confidence value
Status: Draft | Source: legacy/tests/fixtures/expected/recognition.json

Each release has a `recognitionConfidence` value between 0 and 1. The docs and tests do not describe the rule. The golden file shows these values:

| Release | Flags / reasons | Confidence |
|---|---|---|
| `Cranberries\1993 - Everybody Else Is Doing It` | none | 1.0 |
| `Godspeeds and their projects\Godspeed You! Black Emperor\1997 F#A# Infinity` | reason `grouping-folder-auto-resolved` | 1.0 |
| `Isidor - 3218 (…)` | reason `artist-name-split-from-folder-name` | 1.0 |
| `Dance With Ghosts\DANCE WITH GHOSTS - Requiem` | flag `artist-name-prefix-stripped` | 0.8 |
| `Unnumbered\2015 No Numbers` | flag `no-track-number` | 0.8 |
| `ZZ Top\2003 Mescalero` | flag `no-track-number`, reason `track-outside-disc-folder-suspected` | 0.5 |

How propose or review use this value: see [07-proposal-matching.md](07-proposal-matching.md).

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-05 | Phase 1 draft. |
