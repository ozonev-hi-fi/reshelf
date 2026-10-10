# 01 — Data and storage (as-is, merged)

Status: Draft | Version: 0.1 | Last updated: 2026-10-10

## Scope

Area **DAT**. Where the legacy app keeps its data, how it reads, writes and
validates its JSON documents, the shape of each JSON schema, and the shared
file helpers (hashing, stable keys, long paths, audio file detection,
relative paths, secrets, TagLibSharp loading). Sources:
`br/as-is-from-docs/01-data-home-and-storage.md` (`AS-DOC-DAT-001`–`087`,
read from docs, tests and schemas) and `br/as-is-from-code/01-data-and-storage.md`
(`AS-CODE-DAT-001`–`038`, read only from `legacy/scripts/common/Reshelf.Common.psm1`
and `legacy/scripts/common/Reshelf.Json.psm1`).

The two sets don't line up 1:1. The doc side also covers the shape of every
JSON schema (`schemas/*.schema.json`), which the code side does not — phase 2
read only `.psm1` files, not `.json` schema files, so none of the
`settings.json`/`session.json`/`recognition.json`/`proposal.json`/`apply-log.json`/
`lossy-tracking.json` field-shape rules below have an `AS-CODE-DAT-*`
counterpart; that's expected, not a gap. Conversely, the code side documents
some `Reshelf.Common.psm1` facts (secret encryption, TagLibSharp context
caching, JSON serialization depth) that the doc side doesn't cover at all, or
covers under a different area (secrets: `03-settings-and-secrets.md`).

**ID numbering for this area:** `AS-DAT-001`–`087` mirror `AS-DOC-DAT-001`–`087`
one for one — each keeps its doc number even where an `AS-CODE-DAT-*` item
elaborates or (once, see `AS-DAT-005`) corrects it, because the elaboration is
the same rule, not a second rule. `AS-DAT-088`–`097` are fresh numbers for the
ten `AS-CODE-DAT-*` facts that don't attach to any single doc-side rule.

## Prerequisites

### AS-DAT-001 — The app needs PowerShell 7.4 or newer
Status: Draft | Source: AS-DOC-DAT-001

The app runs in PowerShell 7.4 or newer (`pwsh`). Every script and test file
declares this minimum version (`#Requires -Version 7.4`), confirmed in both
`Reshelf.Common.psm1` and `Reshelf.Json.psm1`.

Example: `pwsh scripts/Reshelf.ps1 settings init` runs the setup. Windows
PowerShell 5.1 is not supported.

### AS-DAT-002 — The user supplies TagLibSharp.dll
Status: Draft | Source: AS-DOC-DAT-002; AS-CODE-DAT-029, AS-CODE-DAT-030

The app does not ship or download TagLibSharp. The user gets
`TagLibSharp.dll` from the `TagLibSharp` NuGet package (`lib/netstandard2.0`
folder) and copies it to the default location or to the path in the
`taglibSharpPath` setting. The exact resolution order and the exact error
text when the DLL is missing are in `AS-DAT-086`/`AS-DAT-087`.

Example: the user runs `dotnet add package TagLibSharp` in a throwaway
project and copies the DLL to `.data\lib\TagLibSharp.dll`.

Other prerequisites: Windows and DPAPI for the token — see `AS-DAT-092`/`093`
below and AS-DOC-SET-001; ffmpeg — see AS-DOC-SET-015; a browser for the
review UI — see `09-review-ui.md`.

## Data home

### AS-DAT-003 — The RESHELF_HOME environment variable sets the data home
Status: Draft | Source: AS-DOC-DAT-003; AS-CODE-DAT-001

When the `RESHELF_HOME` environment variable is set, the app uses that
folder as its data home. The folder can be anywhere, inside or outside the
repo.

Example: `RESHELF_HOME=<TestDrive>\ReshelfHomeTest` → the data home is
`<TestDrive>\ReshelfHomeTest`.

### AS-DAT-004 — Without RESHELF_HOME the data home is the `.data` folder of the app
Status: Draft | Source: AS-DOC-DAT-004; AS-CODE-DAT-001

When `RESHELF_HOME` is not set, the data home is the `.data` folder two
directories above `Reshelf.Common.psm1`'s own folder
(`legacy/scripts/common/`) — that is, next to the app's `scripts` and
`tests` folders.

Example: module at `legacy/scripts/common/Reshelf.Common.psm1` with no
`RESHELF_HOME` set → data home resolves to `legacy/.data`.

### AS-DAT-005 — The app creates the data home if missing, but does not itself check that it is writable
Status: Draft | Source: AS-DOC-DAT-005; AS-CODE-DAT-002 — **conflict resolved, see `90-contradictions-resolution.md`**

When the data home folder does not exist, the app creates it
(`New-Item -ItemType Directory -Force`). It does **not** then probe or
verify that the folder is writable — `Resolve-ReshelfDataHome` only checks
existence and, if the path exists, that it is a directory (`AS-DAT-006`). A
folder that exists but has restrictive permissions is accepted here and only
fails later, when something actually tries to write to it.

Example: `ReshelfHomeTest` does not exist → after resolving, it exists. The
test suite separately confirms the result is writable by creating
`probe.tmp` in it from the test itself — that assertion is not something the
app performs.

### AS-DAT-006 — A data home path that is a file is an error
Status: Draft | Source: AS-DOC-DAT-006; AS-CODE-DAT-003

When the data home path points to an existing file, the app stops with the
error `Reshelf data home '<path>' exists but is not a directory.`. It does
not replace the file.

Example: `RESHELF_HOME=<TestDrive>\ReshelfHomeAsFile.tmp`, and that path is a
file → error.

## Data folder layout

### AS-DAT-007 — settings.json is at the data home root
Status: Draft | Source: AS-DOC-DAT-007

The settings file is `<dataHome>\settings.json`. The settings rules are in
`03-settings-and-secrets.md`.

Example: data home `D:\data\Reshelf` → `D:\data\Reshelf\settings.json`.

### AS-DAT-008 — TagLibSharp.dll has a default place under the data home
Status: Draft | Source: AS-DOC-DAT-008; AS-CODE-DAT-029

The default location of the TagLibSharp library is
`<dataHome>\lib\TagLibSharp.dll` — a fixed, hardcoded relative path.

Example: data home `.data` → `.data\lib\TagLibSharp.dll`.

### AS-DAT-009 — Cached Discogs responses live under cache\discogs
Status: Draft | Source: AS-DOC-DAT-009

Cached Discogs API responses are files `<dataHome>\cache\discogs\<hash>.json`.
It is a re-run cache, not an archive. The cache expiry and pruning rules:
see `06-discogs-client.md`.

Example: `.data\cache\discogs\<hash>.json`.

### AS-DAT-010 — Each session has its own folder under sessions
Status: Draft | Source: AS-DOC-DAT-010

Each session has a folder `<dataHome>\sessions\<sessionId>\`. It holds:
- `session.json` — stage, source root, timestamps;
- `recognition.json` — output of `recognize`;
- `proposal.json` and `proposal.backup.json` — output of `propose`, edited
  by the UI;
- `manual-covers\` — covers uploaded through the review UI.

Example: `.data\sessions\2026-09-19-0001\session.json`, and
`recognitionPath` = `D:\data\Reshelf\sessions\2026-09-19-0001\recognition.json`
in `session-example.json`.

### AS-DAT-011 — The lossy ledger and the apply log are library-wide files
Status: Draft | Source: AS-DOC-DAT-011

`lossy-tracking.json` and `apply-log.json` are at the data home root. They
are not per session. They cover the whole library.

Example: `.data\lossy-tracking.json`, `.data\apply-log.json`.

## JSON documents and validation

### AS-DAT-012 — Each JSON document type has one schema file
Status: Draft | Source: AS-DOC-DAT-012; AS-CODE-DAT-031

Each document type has one JSON Schema (draft 2020-12) file in `schemas/`.
The app finds the schema by a short name (`settings`, `session`,
`recognition`, `proposal`, `lossy-tracking`, `apply-log`), resolved to
`<two directories above Reshelf.Json.psm1>/schemas/<name>.schema.json`.

Example: schema name `settings` → `schemas/settings.schema.json`.

### AS-DAT-013 — An unknown schema name is an error
Status: Draft | Source: AS-DOC-DAT-013; AS-CODE-DAT-032

When the schema name does not match a schema file, validation stops with the
error `Schema '<SchemaName>' not found at '<path>'.`. It does not return
`false`.

Example: schema name `does-not-exist` with JSON `{}` → error.

### AS-DAT-014 — Validation accepts a file, an object or raw JSON text
Status: Draft | Source: AS-DOC-DAT-014; AS-CODE-DAT-033

The app can validate a document in three mutually exclusive forms: a file
path (`-Path`, the default), an in-memory object (`-InputObject`, serialized
to JSON first), or a raw JSON string (`-Json`). All three give the same
result.

Example: `settings-example.json` as a path, as a parsed object, and as raw
text → valid in all three cases.

### AS-DAT-015 — An invalid document gives "false", not an error
Status: Draft | Source: AS-DOC-DAT-015; AS-CODE-DAT-035

When a document breaks its schema, validation returns `false`. No custom
validation logic exists beyond resolving the schema file and (for the object
form) serializing — the check itself fully delegates to the built-in
`Test-Json -SchemaFile` cmdlet.

Example: `settings-example.json` without `targetRoot` → `false`.

### AS-DAT-016 — Arrays stay arrays during validation
Status: Draft | Source: AS-DOC-DAT-016

An array with one element is validated as an array, not as a single object.
An empty array is valid for an array schema.

Example: the first entry of `lossy-tracking-example.json` wrapped in an
array → valid against `lossy-tracking`; `[]` → valid against
`lossy-tracking`.

### AS-DAT-017 — The app writes a JSON file only when it is valid
Status: Draft | Source: AS-DOC-DAT-017; AS-CODE-DAT-036

Before it writes a JSON document, the app validates it against its schema.
A valid document is written and the app returns the file path. An invalid
document throws `Document for '<Path>' does not match schema '<SchemaName>'.`
(with the first captured validation error's message appended when
available), and no file is created.

Example: settings without `targetRoot`, target `invalid-settings.json` →
error, `invalid-settings.json` does not exist.

### AS-DAT-018 — Writing a JSON file creates missing parent folders
Status: Draft | Source: AS-DOC-DAT-018; AS-CODE-DAT-037

When the parent folders of the target file do not exist, the app creates
them recursively before writing.

Example: target `nested/dir/settings.json` in an empty folder → the file
exists after the write.

### AS-DAT-019 — A one-element array is written as a JSON array
Status: Draft | Source: AS-DOC-DAT-019

When the document is an array with one element, the file content starts
with `[`. The app does not write a bare object.

Example: `lossy-tracking.json` with one entry → the file text starts with
`[`.

### AS-DAT-020 — The app validates settings.json and session.json when it reads them
Status: Draft | Source: AS-DOC-DAT-020

When the app reads `settings.json` or `session.json` and the file breaks its
schema, it stops with a clear error. The message contains "does not match".
(This read path is in `Reshelf.Settings.psm1`, outside this area's code
source; see `03-settings-and-secrets.md` / `04-sessions.md`.)

Example: `settings.json` = `{"copyMode":"copy"}` → error "…does not
match…"; `session.json` = `{"stage":"recognized"}` → error "…does not
match…".

### AS-DAT-021 — Each schema has a valid example document
Status: Draft | Source: AS-DOC-DAT-021

For each of the six schemas there is an example document in
`tests/fixtures/schema-examples/`. Each example is valid against its schema.

Example: `recognition-example.json` → `recognition.schema.json`;
`apply-log-example.json` → `apply-log.schema.json`.

### AS-DAT-022 — A proposal document is a recognition document plus proposal fields
Status: Draft | Source: AS-DOC-DAT-022

`proposal.json` has the same structure as `recognition.json`. It adds
proposal-only fields to each release and each track. When you add these
fields to a valid recognition document, it becomes a valid proposal
document.

Example: `recognition-example.json` + track fields `proposedFileName =
'01 Poke Chop Sandwich.flac'`, `tags` and release fields `discogsMatch`,
`proposed`, `coverArt`, `lossyLossless`, `targetAction = 'create-new'`,
`humanReview` → valid against `proposal.schema.json`.

## Shared value formats

### AS-DAT-023 — All stored timestamps are UTC in ISO 8601 form
Status: Draft | Source: AS-DOC-DAT-023

Every timestamp field has the form `yyyy-MM-ddTHH:mm:ssZ`, with optional
fractional seconds. The `Z` (UTC) suffix is required.

Example: `"createdAtUtc": "2026-09-19T10:00:00Z"`;
`"2026-09-19T10:00:00.123Z"` is also valid; `"2026-09-19T10:00:00+02:00"` is
not.

### AS-DAT-024 — Years are integers from 1900 to 2100
Status: Draft | Source: AS-DOC-DAT-024

Every year field is an integer from 1900 to 2100. Some year fields also
allow `null`.

Example: `"recognizedYear": 1999` is valid; `1899` and `"1999"` (string) are
not.

### AS-DAT-025 — A stable key is 16 lowercase hex characters in every document
Status: Draft | Source: AS-DOC-DAT-025

Every `stableKey` field matches `^[0-9a-f]{16}$`. How that string is
produced: `AS-DAT-064`.

Example: `"stableKey": "a1b2c3d4e5f60708"`.

## Schema: settings.json

### AS-DAT-026 — settings.json has exactly 13 required keys
Status: Draft | Source: AS-DOC-DAT-026

`settings.json` is one object. All 13 keys are required and no other key is
allowed: `defaultSourceRoot`, `targetRoot`, `copyMode`, `namingTemplates`,
`trackNumberPadWidth`, `coverMaxDimension`, `discogsTokenEnvVar`,
`discogsTokenEncrypted`, `rateLimitPerMinute`, `cacheTtlDays`, `dataHome`,
`ffmpegPath`, `taglibSharpPath`. The meaning of each key is in
`03-settings-and-secrets.md`.

Example: `settings-example.json` has all 13 keys → valid. The same file
without `targetRoot` → invalid.

### AS-DAT-027 — settings.json value limits
Status: Draft | Source: AS-DOC-DAT-027

| Key | Limit |
|---|---|
| `targetRoot` | string, at least 1 character |
| `copyMode` | only `"copy"` |
| `trackNumberPadWidth` | integer ≥ 2 |
| `coverMaxDimension` | integer ≥ 1 |
| `discogsTokenEnvVar` | string, at least 1 character |
| `rateLimitPerMinute` | integer ≥ 1 |
| `cacheTtlDays` | integer ≥ 0 |
| `defaultSourceRoot`, `discogsTokenEncrypted`, `dataHome`, `ffmpegPath`, `taglibSharpPath` | any string, empty allowed |

Example: `"copyMode": "move"` → invalid; `"cacheTtlDays": 0` → valid;
`"trackNumberPadWidth": 1` → invalid.

### AS-DAT-028 — namingTemplates has exactly two templates
Status: Draft | Source: AS-DOC-DAT-028

`namingTemplates` is an object with exactly two required, non-empty
strings: `releaseFolder` and `trackFile`. No other key is allowed.

Example: `{ "releaseFolder": "{year} {album}", "trackFile": "{trackNumber}
{title}" }`.

## Schema: session.json

### AS-DAT-029 — session.json has seven required fields
Status: Draft | Source: AS-DOC-DAT-029

`session.json` is one object with exactly these required fields:
`sessionId`, `sourceRoot`, `createdAtUtc`, `updatedAtUtc`, `stage`,
`recognitionPath`, `proposalPath`. No other field is allowed.

Example: `session-example.json` (`sessionId` `2026-09-19-0001`,
`sourceRoot` `D:\downloads\incoming`, `stage` `recognized`).

### AS-DAT-030 — The session id has the form yyyy-MM-dd-NNNN
Status: Draft | Source: AS-DOC-DAT-030

`sessionId` matches `^\d{4}-\d{2}-\d{2}-\d{4}$`. How the app creates the id:
see `04-sessions.md`.

Example: `2026-09-19-0001` is valid; `2026-09-19-1` is not.

### AS-DAT-031 — The session stage is one of five values
Status: Draft | Source: AS-DOC-DAT-031

`stage` is one of: `recognized`, `proposed`, `reviewed`, `applied`,
`partially-applied`. The stage flow: see `04-sessions.md`.

Example: `"stage": "partially-applied"` is valid; `"stage": "approved"` is
not.

### AS-DAT-032 — proposalPath can be null; recognitionPath cannot be empty
Status: Draft | Source: AS-DOC-DAT-032

`recognitionPath` is a non-empty string. `proposalPath` is a string or
`null`. `sourceRoot` is a non-empty string.

Example: `session-example.json` has `"proposalPath": null` and
`"recognitionPath": "D:\\data\\Reshelf\\sessions\\2026-09-19-0001\\recognition.json"`.

## Schema: recognition.json

### AS-DAT-033 — recognition.json top level
Status: Draft | Source: AS-DOC-DAT-033

`recognition.json` is one object with exactly these required fields:
`schemaVersion` (always `1`), `sessionId`, `sourceRoot`, `generatedAtUtc`,
`artists` (array), `unrecognized` (array).

Example: `"schemaVersion": 1, "sessionId": "2026-09-19-0001", "sourceRoot":
"D:\\downloads\\incoming"`. `"schemaVersion": 2` → invalid.

### AS-DAT-034 — A recognized artist has a name, source paths and releases
Status: Draft | Source: AS-DOC-DAT-034

Each artist has `recognizedName` (non-empty), `sourcePaths` (at least one
non-empty path) and `releases` (array, may be empty).

Example: `"recognizedName": "ZZ Top", "sourcePaths":
["D:\\downloads\\incoming\\ZZ Top"]`.

### AS-DAT-035 — A recognized release has fourteen required fields
Status: Draft | Source: AS-DOC-DAT-035

Each release has: `stableKey`, `recognizedTitle` (non-empty),
`recognizedYear`, `editionFolderName`, `sourceFolderPath`,
`discFolderCount` (integer ≥ 1), `tracks` (at least one), `companionFiles`,
`ignoredFiles`, `cueSheets`, `recognitionConfidence` (number 0–1),
`recognitionFlags`, `needsReview` (boolean), `reviewReasons`.

Example: release `XXX`, `"recognizedYear": 1999`, `"discFolderCount": 1`,
`"recognitionConfidence": 0.95`, one track.

### AS-DAT-036 — The recognized year can be unknown
Status: Draft | Source: AS-DOC-DAT-036

`recognizedYear` is an integer 1900–2100 or `null`. `null` means that
recognition found no year.

Example: folder `XXX` with no year → `"recognizedYear": null`.

### AS-DAT-037 — Release date and release type are optional and nullable
Status: Draft | Source: AS-DOC-DAT-037

A release may have `recognizedReleaseDate` (`yyyy-MM-dd` or `null`) and
`recognizedReleaseType` (`album`, `mini-album`, `ep`, `single`,
`maxi-single`, `lp`, or `null`). The fields may also be absent.

Example: `"recognizedReleaseDate": "1999-08-29", "recognizedReleaseType":
"album"` → valid; both `null` → valid; both absent → valid.

### AS-DAT-038 — The edition folder name is null or non-empty
Status: Draft | Source: AS-DOC-DAT-038

`editionFolderName` is required. It is `null` or a non-empty string. How
recognition fills it: see `05-recognition.md`.

Example: `recognition-example.json` has `"editionFolderName": null`.

### AS-DAT-039 — Recognition flags are separate from the review decision
Status: Draft | Source: AS-DOC-DAT-039

`recognitionFlags` holds machine-readable reason codes, also when
`needsReview` is `false`. Only ambiguous cases set `needsReview = true`;
then `reviewReasons` explains why. Which codes exist: see
`05-recognition.md`.

Example: a release whose track numbers were inferred →
`"recognitionFlags": ["no-track-number"]`, `"needsReview": false`.

### AS-DAT-040 — A recognized track has twelve required fields
Status: Draft | Source: AS-DOC-DAT-040

Each track has: `sourceFilePath`, `discFolder`, `originalFileName`,
`detectedTrackNumberInDisc` (integer ≥ 1), `inferredTrackOrder` (boolean),
`existingTags`, `existingCoverArtPath` (string or `null`), `format`
(non-empty), `isLossless` (boolean), `durationSeconds` (number ≥ 0),
`cueTimestamp`, `isCueVirtualTrack` (boolean).

Example: `"originalFileName": "01 Poke Chop Sandwich.flac", "format":
"flac", "isLossless": true, "durationSeconds": 231`.

### AS-DAT-041 — The disc folder is null for a single-disc release
Status: Draft | Source: AS-DOC-DAT-041

`discFolder` is `null` for a single-disc release. For a multi-disc release
it holds the disc subfolder name.

Example: single disc → `"discFolder": null`; 2-CD release → `"CD 1"`,
`"CD 2"`.

### AS-DAT-042 — Existing tags hold artist, album and title, each nullable
Status: Draft | Source: AS-DOC-DAT-042

`existingTags` has exactly three required keys: `artist`, `album`, `title`.
Each is a string or `null`.

Example: a file without tags → `{ "artist": null, "album": null, "title":
null }`.

### AS-DAT-043 — A cue timestamp has the form MM:SS:FF and converts at 75 frames/second
Status: Draft | Source: AS-DOC-DAT-043; AS-CODE-DAT-005, AS-CODE-DAT-006

`cueTimestamp` is `null` or a string `NN:NN:NN` — minutes, seconds, CD-audio
frames (0–74 at 75 frames/second), never hours:minutes:seconds even though
the shape looks like a clock time. The app converts it to total seconds as
`minutes*60 + seconds + frames/75.0`, rounded to 3 decimal places.

Example: a plain file track → `"cueTimestamp": null`; a cue virtual track →
`"cueTimestamp": "09:26:73"`; `"03:25:37"` → 3×60 + 25 + 37/75 = 205.493
seconds.

### AS-DAT-044 — A used cue sheet is a pair of cue file and audio file
Status: Draft | Source: AS-DOC-DAT-044

`cueSheets` is an array. Each item has `cueFilePath` and `audioFilePath`,
both non-empty. A cue sheet that the app uses to split a single-file release
is listed only here. It is not in `companionFiles` and not in
`ignoredFiles`.

Example: `{ "cueFilePath": "…\\album.cue", "audioFilePath":
"…\\album.flac" }`; a release without cue → `"cueSheets": []`.

### AS-DAT-045 — A companion file has a kind and a placement
Status: Draft | Source: AS-DOC-DAT-045

Each companion file has `sourcePath`, `kind` and `placement`. `kind` is one
of `cover`, `booklet`, `photo`, `lyrics`, `other`. Plan 03 says `placement`
is `loose` (directly in the release folder) or `nested` (in a subfolder).
The schema accepts any non-empty string for `placement` — see the carried-
forward suspected defect `CF-DAT-003`.

Example: `{ "sourcePath": "D:\\downloads\\incoming\\ZZ Top\\1999
XXX\\cover.jpg", "kind": "cover", "placement": "loose" }`.

### AS-DAT-046 — An ignored file has a reason
Status: Draft | Source: AS-DOC-DAT-046

Each ignored file has `sourcePath` and `reason`, both non-empty. Plan 03
names the reasons `playlist-file` (no playlists in the target) and
`cue-sheet-not-used` (a `.cue` file that is not the one used to split the
release).

Example: `{ "sourcePath": "…\\playlist.m3u", "reason": "playlist-file" }`.

### AS-DAT-047 — An unrecognized folder has a path, a reason and its children
Status: Draft | Source: AS-DOC-DAT-047

Each `unrecognized` entry has `path`, `reason` (both non-empty) and
`children` (array of names). Which reasons exist: see `05-recognition.md`.

Example: `{ "path": "D:\\downloads\\incoming\\Empty Folder", "reason":
"no-audio-files", "children": [] }`; `{ "path": "…\\Godspeeds and their
projects", "reason": "grouping-folder-suspected", "children":
["Godspeed You! Black Emperor", "Silver Mountain Zion"] }`.

## Schema: proposal.json

### AS-DAT-048 — A proposed release adds six required fields
Status: Draft | Source: AS-DOC-DAT-048

In `proposal.json` each release has all recognition fields plus six
required fields: `discogsMatch`, `proposed`, `coverArt`, `lossyLossless`,
`targetAction`, `humanReview`.

Example: `proposal-example.json`, release `XXX`.

### AS-DAT-049 — The Discogs match has a status, a selected release and candidates
Status: Draft | Source: AS-DOC-DAT-049

`discogsMatch` has `status` (`matched`, `ambiguous` or `not-found`),
`selectedReleaseId` (integer or `null`) and `candidates`. It may also have
`masterId` (integer or `null`). Each candidate has `releaseId`, `title`
(non-empty), `year` (1900–2100 or `null`), `format` (non-empty) and `score`
(0–1). How matching works: see `07-proposal-matching.md`.

Example: `{ "status": "matched", "selectedReleaseId": 123456, "candidates":
[ { "releaseId": 123456, "title": "XXX", "year": 1999, "format": "CD,
Album", "score": 0.97 } ] }`.

### AS-DAT-050 — The proposed block holds the target folder names, year and album
Status: Draft | Source: AS-DOC-DAT-050

`proposed` has `artistFolderName`, `releaseFolderName`, `album` (all
non-empty) and `year` (1900–2100 or `null`). `isCompilation` (boolean) is
optional; when it is absent (older `proposal.json`), it counts as `false`.

Example: `{ "artistFolderName": "ZZ Top", "releaseFolderName": "1999 XXX",
"year": 1999, "album": "XXX" }`.

### AS-DAT-051 — Cover art holds candidates, the chosen URL and a size limit
Status: Draft | Source: AS-DOC-DAT-051

`coverArt` has `candidates`, `chosenCandidateUrl` (string or `null`) and
`targetMaxDimension` (integer ≥ 1). Each candidate has `url` (non-empty),
`sourceEdition` (string), `width` and `height` (integers ≥ 1).

Example: `{ "candidates": [ { "url": "https://example.com/cover.jpg",
"sourceEdition": "US CD", "width": 1200, "height": 1200 } ],
"chosenCandidateUrl": "https://example.com/cover.jpg",
"targetMaxDimension": 600 }`.

### AS-DAT-052 — The lossy/lossless block has a flag and one of five actions
Status: Draft | Source: AS-DOC-DAT-052

`lossyLossless` has `isLossy` (boolean) and `action`. `action` is one of
`none`, `log-for-upgrade`, `replace-existing`,
`previously-lossy-different-location`, `previously-lossy-target-missing`.
It may have `previousLossy` with `targetPath`, `format`, `firstDetectedUtc`
and `targetExists` (all required inside it). The meaning of the actions: see
`11-lossy-tracking.md`.

Example: `{ "isLossy": false, "action": "none" }`.

### AS-DAT-053 — The target action is one of four values
Status: Draft | Source: AS-DOC-DAT-053

`targetAction` is one of `create-new`, `skip-existing-identical`,
`update-existing`, `conflict`. How propose chooses it: see
`07-proposal-matching.md`.

Example: `"targetAction": "create-new"`.

### AS-DAT-054 — Human review has four required fields
Status: Draft | Source: AS-DOC-DAT-054

`humanReview` has `required`, `resolved`, `rejected` (booleans) and `notes`
(string). `resolved: false` means "not reviewed yet". `rejected: true` means
a deliberate, permanent "never apply this". Only the review UI sets
`rejected`. How apply treats it: see `10-apply.md`.

Example: `{ "required": false, "resolved": true, "rejected": false,
"notes": "" }`. Two folders turn out to be two different pressings of the
same album; the one the user does not keep gets `rejected: true`.

### AS-DAT-055 — A proposed track adds file name, numbers, title and tags
Status: Draft | Source: AS-DOC-DAT-055

In `proposal.json` each track has all recognition fields plus
`proposedFileName` (non-empty), `proposedDiscNumber` (integer ≥ 1),
`proposedTrackNumber` (integer ≥ 1), `proposedTitle` (non-empty) and `tags`.

Example: `"proposedFileName": "01 Poke Chop Sandwich.flac",
"proposedDiscNumber": 1, "proposedTrackNumber": 1, "proposedTitle": "Poke
Chop Sandwich"`.

### AS-DAT-056 — Track tags are all required and never empty
Status: Draft | Source: AS-DOC-DAT-056

`tags` has seven required fields: `artist`, `albumArtist`, `album`, `title`
(non-empty strings), `year` (integer 1900–2100, not `null`), `discNumber`
and `track` (integers ≥ 1). `isCompilation` (boolean) is optional. Plan 03
says it has the same value as `proposed.isCompilation` on every track. The
tag rules: see `02-text-and-naming.md`.

Example: `{ "artist": "ZZ Top", "albumArtist": "ZZ Top", "album": "XXX",
"year": 1999, "discNumber": 1, "track": 1, "title": "Poke Chop Sandwich" }`.

### AS-DAT-057 — A proposed companion file can be excluded and renamed
Status: Draft | Source: AS-DOC-DAT-057

In `proposal.json` a companion file may also have `include` (boolean) and
`proposedFileName` (non-empty string or `null`).

Example: `{ "sourcePath": "…\\cover.jpg", "kind": "cover", "placement":
"loose", "include": true, "proposedFileName": "cover.jpg" }`.

### AS-DAT-058 — An unknown year gets the placeholder year 1900 in the proposal
Status: Draft | Source: AS-DOC-DAT-058

Same rule as AS-DOC-PRP-011 in `08-proposal-naming-and-tags.md` (primary,
from the golden file). When a release has no year (`recognizedYear: null`),
propose does not block. It uses the fixed placeholder year `1900` (the
schema minimum) in the folder name, sets `humanReview.required = true` with
the note `UNRESOLVED YEAR: placeholder value used, must be corrected before
applying`, and still gives the release a `targetAction` (usually
`create-new`). See the carried-forward suspected defect `CF-DAT-002`.

Example: `ZZ Top/XXX` without a year → release folder `1900 XXX`, review
required.

## Schema: apply-log.json

### AS-DAT-059 — apply-log.json is an array of per-release apply results
Status: Draft | Source: AS-DOC-DAT-059

`apply-log.json` is an array. Each entry has exactly seven required fields:
`stableKey`, `appliedAtUtc`, `status`, `targetPath` (non-empty),
`sourceFileSetHash` (non-empty), `errorMessage` (string or `null`),
`truncated` (boolean). How apply uses it: see `10-apply.md`.

Example: `{ "stableKey": "a1b2c3d4e5f60708", "appliedAtUtc":
"2026-09-19T10:00:00Z", "status": "applied", "targetPath":
"E:\\Music\\ZZ Top\\1999 XXX", "sourceFileSetHash": "9f3a…0708",
"errorMessage": null, "truncated": false }`.

### AS-DAT-060 — An apply-log status is applied, failed or skipped
Status: Draft | Source: AS-DOC-DAT-060

`status` is one of `applied`, `failed`, `skipped`.

Example: `"status": "failed"` with `"errorMessage": "…"`; `"status":
"applied"` with `"errorMessage": null`.

## Schema: lossy-tracking.json

### AS-DAT-061 — lossy-tracking.json is an array of lossy releases
Status: Draft | Source: AS-DOC-DAT-061

`lossy-tracking.json` is an array. Each entry has exactly eleven required
fields: `stableKey`, `artist`, `album` (non-empty), `year` (integer
1900–2100, not `null`), `targetPath`, `format` (non-empty), `status`,
`firstDetectedUtc`, `lastCheckedUtc`, `upgradedUtc` (timestamp or `null`),
`notes` (string). How the ledger is used: see `11-lossy-tracking.md`.

Example: `{ "stableKey": "a1b2c3d4e5f60708", "artist": "ZZ Top", "album":
"XXX", "year": 1999, "targetPath": "E:\\Music\\ZZ Top\\1999 XXX", "format":
"mp3", "status": "pending-upgrade", "upgradedUtc": null, "notes": "" }`.

### AS-DAT-062 — A lossy entry status is pending-upgrade, upgraded or ignored
Status: Draft | Source: AS-DOC-DAT-062

`status` is one of `pending-upgrade`, `upgraded`, `ignored`.

Example: `"status": "pending-upgrade"`.

## Hashes and stable keys

### AS-DAT-063 — A text hash is a 64-character lowercase SHA-256 hex string
Status: Draft | Source: AS-DOC-DAT-063; AS-CODE-DAT-007

The app UTF-8 encodes a text, hashes it with SHA-256, and writes the result
as 64 lowercase hex characters, never uppercase and never with separators.
The same text always gives the same hash; different texts give different
hashes.

Example: `""` (empty string) →
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b85`;
`D:\downloads\incoming` twice → the same hash; `a` and `b` → different
hashes.

### AS-DAT-064 — A stable key is the first 16 hex characters of a SHA-256 hash of artist, album and year
Status: Draft | Source: AS-DOC-DAT-064; AS-CODE-DAT-008, AS-CODE-DAT-009

The stable key is built from the canonical string
`<normalized artist>|<normalized album>|<year-or-empty>`, SHA-256 hashed,
and truncated to the first 16 lowercase hex characters (not the full
64-character digest). The same input always gives the same key.

Example: artist `ZZ Top`, album `XXX`, year `1999` → a key like
`a1b2c3d4e5f60708`, the same on every run.

### AS-DAT-065 — The stable key's normalization is the same one used for text matching
Status: Draft | Source: AS-DOC-DAT-065; AS-CODE-DAT-008

Before hashing, the artist and album text go through NFKC Unicode
normalization, are lowercased, and have everything except letters, digits
and spaces stripped, then runs of whitespace are collapsed to one space and
the ends trimmed. This is the same normalization function used elsewhere
for text matching (`ConvertTo-ReshelfNormalizedText`; see
`02-text-and-naming.md`). Plan 03's looser description ("lowercases, trims,
collapses spaces, strips punctuation") describes the same outcome.

Example: (`ZZ Top`, `XXX`, 1999) and (`  zz   top `, ` xxx `, 1999) → the
same key.

### AS-DAT-066 — The year is part of the stable key, as an empty string when unknown
Status: Draft | Source: AS-DOC-DAT-066; AS-CODE-DAT-008

Different years give different keys. A missing year (`null`) becomes an
empty string in the canonical text (not a default/placeholder number), so
the key still has three `|`-separated parts. The key always uses the real
recognized year, never the placeholder year `1900` (`AS-DAT-058`).

Example: (`ZZ Top`, `XXX`, 1999) and (`ZZ Top`, `XXX`, 2000) → different
keys; (`ZZ Top`, `XXX`, `null`) → a key, no error.

### AS-DAT-067 — The same release gets the same key from any source folder
Status: Draft | Source: AS-DOC-DAT-067

The key depends only on the content (artist, album, year), not on the
folder or a random id. So a release recognized today and again six months
later from another source folder gets the same key. Re-runs, duplicate
detection and resume use this. The re-run rules: see
`07-proposal-matching.md`.

Example: `D:\downloads\incoming\ZZ Top\1999 XXX` and
`F:\usb\ZZ Top - XXX (1999)` both recognized as (`ZZ Top`, `XXX`, 1999) →
the same key.

### AS-DAT-068 — The file-set hash does not depend on the order of the files
Status: Draft | Source: AS-DOC-DAT-068; AS-CODE-DAT-021

The app computes one hash for a set of files: for each file it builds the
entry `"<lowercased file name>|<file length in bytes>"` (file content is
never read), sorts the entries with ordinal string comparison, joins them
with `\n`, and SHA-256 hashes the result. The same set gives the same hash,
in any order, because sorting happens before hashing.

Example: (`a.flac`, `b.flac`) and (`b.flac`, `a.flac`) → the same hash.

### AS-DAT-069 — The file-set hash ignores the case of file names
Status: Draft | Source: AS-DOC-DAT-069; AS-CODE-DAT-021

The same file written in upper case or lower case gives the same hash,
because the file name is lowercased before building its entry.

Example: `<dir>\a.flac` and `<DIR>\A.FLAC` → the same hash.

### AS-DAT-070 — The file-set hash changes when a file size changes
Status: Draft | Source: AS-DOC-DAT-070; AS-CODE-DAT-021

When the size of a file in the set changes, the hash changes, because the
file length in bytes is part of each entry. A content change that keeps the
same size is not covered by these inputs (content is never read or hashed,
only name and size).

Example: `a.flac` with content `aaaa`, then `aaaaaaaa` → different hashes.

### AS-DAT-071 — An empty file set has a fixed hash
Status: Draft | Source: AS-DOC-DAT-071; AS-CODE-DAT-023

An empty list of files is explicitly allowed and gives the SHA-256 hash of
an empty string (`e3b0c4…852b85`), always the same one, not an error.

Example: `@()` twice → the same hash.

## Long paths

### AS-DAT-072 — A short path stays as it is
Status: Draft | Source: AS-DOC-DAT-072; AS-CODE-DAT-011

A path shorter than the length threshold is not changed. The threshold is
240 characters by default (overridable via `-Threshold`).

Example: `D:\music\ZZ Top\1999 XXX` → `D:\music\ZZ Top\1999 XXX`.

### AS-DAT-073 — A path at or over 240 characters gets the `\\?\` long-path prefix
Status: Draft | Source: AS-DOC-DAT-073; AS-CODE-DAT-011, AS-CODE-DAT-013

The length check is strictly "less than the threshold" — a path exactly 240
characters long already gets the prefix, not only paths of 241+ characters.
A non-UNC path at or over the threshold gets `\\?\` simply prepended.

Example: `D:\` + 250 × `a` (253 characters) → `\\?\D:\aaaa…`.

### AS-DAT-074 — A near-limit network path gets the `\\?\UNC\` prefix
Status: Draft | Source: AS-DOC-DAT-074; AS-CODE-DAT-012

A UNC (network share) path at or over the threshold has its leading `\\`
replaced with `\\?\UNC\`.

Example: `\\server\share\` + 250 × `a` → `\\?\UNC\server\share\aaaa…`.

### AS-DAT-075 — A path that already has the prefix is not changed
Status: Draft | Source: AS-DOC-DAT-075; AS-CODE-DAT-010

A path that already starts with `\\?\` is returned unchanged — the
conversion is idempotent and never double-prefixes.

Example: `\\?\D:\` + 250 × `a` → the same text.

## Audio files

### AS-DAT-076 — Audio files are detected against a fixed, literal extension list
Status: Draft | Source: AS-DOC-DAT-076; AS-CODE-DAT-014

The app decides by file extension, case-insensitively, against exactly this
list: `.flac`, `.mp3`, `.m4a`, `.wav`, `.ogg`, `.wma`, `.aac`, `.ape`,
`.mpc`.

Example: `.FLAC` → audio; `.mpc` → audio; `.txt` → not audio.

### AS-DAT-077 — A file without an extension is not audio, and not an error
Status: Draft | Source: AS-DOC-DAT-077; AS-CODE-DAT-014

An empty extension is a valid, non-throwing input that gives "not audio"
and "not lossless".

Example: file `README` (extension `''`) → not audio, not lossless.

### AS-DAT-078 — Lossless formats are a separate, smaller literal list
Status: Draft | Source: AS-DOC-DAT-078; AS-CODE-DAT-015

Lossless detection uses its own fixed, case-insensitive list, independent
of the audio-extension list: `.flac`, `.wav`, `.ape`, `.alac`. See the
carried-forward suspected defect `CF-DAT-005` — `.alac` is lossless here but
absent from the audio-extension list in `AS-DAT-076`, so a standalone
`.alac` file is never found by the normal folder scan.

Example: `.flac` → lossless; `.mpc` (Musepack) → lossy.

### AS-DAT-079 — Listing audio files in a folder is files-only and skips non-audio by default
Status: Draft | Source: AS-DOC-DAT-079; AS-CODE-DAT-016, AS-CODE-DAT-018

By default the app lists only the audio files directly in the folder — only
files, never directories, and it does not recurse into subfolders. The
result is always wrapped as an array, even for 0 or exactly 1 matches, so
callers never hit PowerShell's single-item unwrapping.

Example: folder with `01 Track.flac`, `02 Track.mp3`, `readme.txt`,
`playlist.m3u`, `CD 1\01 Nested.flac` → `01 Track.flac`, `02 Track.mp3`.

### AS-DAT-080 — Listing audio files can include subfolders
Status: Draft | Source: AS-DOC-DAT-080; AS-CODE-DAT-016

On request (`-Recurse`), the app also lists the audio files in all
subfolders.

Example: `CD 1\01 Track.flac`, `CD 2\01 Track.flac` with the recursive
option → 2 files.

### AS-DAT-081 — A folder without audio files gives an empty list
Status: Draft | Source: AS-DOC-DAT-081; AS-CODE-DAT-018

A folder with no audio files gives an empty list, not an error. See also
`AS-DAT-089` — enumeration errors are swallowed the same way.

Example: folder with only `notes.txt` → 0 files.

## Relative paths

### AS-DAT-082 — A relative path uses forward slashes
Status: Draft | Source: AS-DOC-DAT-082; AS-CODE-DAT-020

The app writes a path below the source root as a relative path with `/`
separators, at any depth — every backslash in the remainder is converted
to a forward slash.

Example: root `C:\Music\Source`, path
`C:\Music\Source\Some Band\2010 Album\Scans\front.jpg` →
`Some Band/2010 Album/Scans/front.jpg`.

### AS-DAT-083 — The root match ignores case and a trailing separator, but not a partial folder-name match
Status: Draft | Source: AS-DOC-DAT-083; AS-CODE-DAT-019

The app trims a trailing `\` or `/` from the root, then checks whether the
path starts with that root using a case-insensitive ordinal comparison —
see the carried-forward suspected defect `CF-DAT-004`: this is a plain
string-prefix check with no check that a path separator follows the root,
so a root of `C:\Music` also matches `C:\MusicArchive\foo.flac`.

Example: root `c:\music\source`, path `C:\Music\Source\Some Band\front.jpg`
→ `Some Band/front.jpg`; root `C:\Music\Source\`, path
`C:\Music\Source\Album\file.jpg` → `Album/file.jpg`.

### AS-DAT-084 — A path outside the root stays as it is
Status: Draft | Source: AS-DOC-DAT-084; AS-CODE-DAT-019

When the path does not start with the root, the app returns it unchanged
(with its original backslashes). No error is raised for a path outside the
root.

Example: root `C:\Music\Source`, path `D:\Elsewhere\file.jpg` →
`D:\Elsewhere\file.jpg`.

### AS-DAT-085 — The root itself gives an empty relative path
Status: Draft | Source: AS-DOC-DAT-085

When the path is the root itself, the relative path is an empty string.

Example: root `C:\Music\Source`, path `C:\Music\Source` → `''`.

## TagLibSharp loading

### AS-DAT-086 — Without a configured path, TagLibSharp is loaded from the effective data home
Status: Draft | Source: AS-DOC-DAT-086; AS-CODE-DAT-029

When `taglibSharpPath` is empty, the app loads
`<effective data home>\lib\TagLibSharp.dll`; when it is set, the app uses
that full path. The effective data home itself follows the same order as
`AS-DAT-090`.

Example: data home `<TestDrive>\<guid>`, file
`<TestDrive>\<guid>\lib\TagLibSharp.dll` exists → the app loads that file.

### AS-DAT-087 — A missing TagLibSharp.dll gives a clear, instructional error
Status: Draft | Source: AS-DOC-DAT-087; AS-CODE-DAT-030

When the DLL is not at the resolved path, the app throws:
`TagLibSharp.dll not found at '<path>'. Download the TagLibSharp NuGet
package (e.g. 'dotnet add package TagLibSharp' in a throwaway project),
copy TagLibSharp.dll from its lib/netstandard2.0 folder to that path, or
set settings.taglibSharpPath to its location.`

Example: data home without `lib\TagLibSharp.dll` → error "TagLibSharp.dll
not found … `<dataHome>\lib\TagLibSharp.dll`".

## Additional facts found only in the code

These ten rules came from `Reshelf.Common.psm1`/`Reshelf.Json.psm1` with no
single matching doc-side rule to attach to, so they get fresh IDs.

### AS-DAT-088 — Data home is returned as a resolved absolute path
Status: Draft | Source: AS-CODE-DAT-004

`Resolve-ReshelfDataHome`'s return value is always an absolute,
canonicalized path (via `Resolve-Path`), never the raw relative path or
environment-variable string that was used to locate it.

### AS-DAT-089 — Audio file discovery silently ignores filesystem errors
Status: Draft | Source: AS-CODE-DAT-017

Folder enumeration for audio files uses `-ErrorAction SilentlyContinue`: an
inaccessible folder or file (for example a permission error) is silently
skipped rather than raising an error, so the function can return a partial
or empty result without telling the caller anything went wrong.

### AS-DAT-090 — Effective data home resolution order
Status: Draft | Source: AS-CODE-DAT-027

The data home a function actually uses, in order of preference: (1) an
explicit `-DataHome` argument, (2) the data home previously stashed for the
current run by `Set-ReshelfTagLibSharpContext`, (3) the default `.data`
folder from `AS-DAT-004` (created if missing).

### AS-DAT-091 — TagLibSharp assembly load is a one-time, process-wide no-op after first load
Status: Draft | Source: AS-CODE-DAT-028

If the `TagLib.File` type is already loaded in the current session, loading
TagLibSharp returns immediately without re-resolving a path or loading the
assembly again — the assembly load for this DLL only ever runs once per
process.

### AS-DAT-092 — Secret protection uses Windows DPAPI, machine/user-bound
Status: Draft | Source: AS-CODE-DAT-024

A plaintext secret is encrypted via the built-in SecureString DPAPI flow,
producing ciphertext that only the same Windows user account on the same
machine can decrypt. An empty-string secret is explicitly allowed as input.
This is the mechanism behind the Discogs token storage described in
`03-settings-and-secrets.md` (AS-DOC-SET-001); it lives in
`Reshelf.Common.psm1`, shared rather than settings-specific.

### AS-DAT-093 — Secret un-protection does not allow an empty string
Status: Draft | Source: AS-CODE-DAT-025

Reversing the DPAPI encryption recovers the original plaintext, but unlike
protection (`AS-DAT-092`), the encrypted-text parameter has no
"allow empty string" attribute, so passing an empty string fails parameter
binding instead of being accepted.

### AS-DAT-094 — TagLibSharp context is stored, not validated
Status: Draft | Source: AS-CODE-DAT-026

Stashing a `TagLibSharpPath`/`DataHome` for later calls to reuse performs no
validation at the time it is called — it does not check that the path or
the data home actually exists.

### AS-DAT-095 — Object-form JSON validation serializes with a default depth of 10
Status: Draft | Source: AS-CODE-DAT-034

Validating or writing an in-memory object (rather than a file or a raw
string) serializes it via `ConvertTo-Json -Depth $Depth`, defaulting to 10
(overridable). An object graph nested deeper than 10 levels is silently
truncated by that serialization before validation ever runs, which can make
a validation result depend on the depth setting rather than the object's
full shape.

### AS-DAT-096 — The file-set hash fails loudly on a missing file
Status: Draft | Source: AS-CODE-DAT-022

Each path is resolved with a terminating error if missing, so a missing
file produces an immediate, clear "cannot find path" error rather than
continuing with a null or empty entry.

### AS-DAT-097 — The JSON file is written as UTF-8 without a byte-order mark
Status: Draft | Source: AS-CODE-DAT-038

Writing a JSON document uses UTF-8 encoding without a BOM (byte-order
mark), and the function that writes it returns the path it was given on
success.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-10 | Phase 3: merged `AS-DOC-DAT-001`–`087` and `AS-CODE-DAT-001`–`038` into `AS-DAT-001`–`097`. One conflict resolved (`AS-DAT-005`, data-home writability). Five suspected defects carried forward, see `91-suspected-defects-carryforward.md`. |
