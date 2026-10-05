# 01 — Data home and storage (as-is, from docs and tests)

Status: Draft | Version: 0.1 | Last updated: 2026-10-05

## Scope

Area **DAT**. Where the legacy app keeps its data, how it reads, writes and validates its JSON documents, the shape of each JSON schema, and the shared file helpers (hashing, stable keys, long paths, audio file detection, relative paths, TagLibSharp loading).

Owned inputs: `legacy/tests/Reshelf.Common.Tests.ps1` (data home, hashing, long path, audio, relative path, TagLibSharp Describes), `legacy/tests/Reshelf.Json.Tests.ps1`, `legacy/tests/Reshelf.Schemas.Tests.ps1`, `legacy/tests/fixtures/schema-examples/*`, `legacy/schemas/*.json`, `legacy/plan/03-domain-model-and-json-schemas.md`, and the `legacy/README.md` sections "Requirements" and "Reference: data folder". `legacy/tests/TestHelpers.psm1` was read as context only.

Suspected defects and contradictions are listed in [90-suspected-defects.md](90-suspected-defects.md): AS-DOC-DEF-002 to AS-DOC-DEF-008 for this area, and AS-DOC-DEF-111 for the default data home after the Phase 0 move.

## Prerequisites

### AS-DOC-DAT-001 — The app needs PowerShell 7.4 or newer
Status: Draft | Source: legacy/README.md › Requirements; legacy/tests/Reshelf.Common.Tests.ps1 › `#Requires -Version 7.4` header

The app runs in PowerShell 7.4 or newer (`pwsh`). Every test file declares this minimum version.

Example: `pwsh scripts/Reshelf.ps1 settings init` runs the setup. Windows PowerShell 5.1 is not supported.

### AS-DOC-DAT-002 — The user supplies TagLibSharp.dll
Status: Draft | Source: legacy/README.md › Requirements

The app does not ship or download TagLibSharp. The user gets `TagLibSharp.dll` from the `TagLibSharp` NuGet package (`lib/netstandard2.0` folder) and copies it to the default location or to the path in the `taglibSharpPath` setting. The app uses it to read tags in `recognize` and to write tags in `apply`.

Example: the user runs `dotnet add package TagLibSharp` in a throwaway project and copies the DLL to `.data\lib\TagLibSharp.dll`.

Other prerequisites: Windows and DPAPI (data protection API) for the token — see [03-settings-and-secrets.md](03-settings-and-secrets.md) (AS-DOC-SET-001); ffmpeg — see AS-DOC-SET-015; a browser for the review UI — see [09-review-ui.md](09-review-ui.md).

## Data home

### AS-DOC-DAT-003 — The RESHELF_HOME environment variable sets the data home
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Resolve-ReshelfDataHome › creates and returns a writable directory; legacy/README.md › Reference: data folder

When the `RESHELF_HOME` environment variable is set, the app uses that folder as its data home. The folder can be anywhere, inside or outside the repo.

Example: `RESHELF_HOME=<TestDrive>\ReshelfHomeTest` → the data home is `<TestDrive>\ReshelfHomeTest`.

### AS-DOC-DAT-004 — Without RESHELF_HOME the data home is the `.data` folder of the app
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Resolve-ReshelfDataHome › defaults to a .data folder inside the repo when RESHELF_HOME is not set; legacy/README.md › Reference: data folder

When `RESHELF_HOME` is not set, the data home is the `.data` folder next to the app's `scripts` and `tests` folders. The README says this folder is git-ignored.

Example: tests in `legacy/tests/` resolve the default to `legacy/tests/../.data`, that is `legacy/.data`.

### AS-DOC-DAT-005 — The app creates the data home and checks that it is writable
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Resolve-ReshelfDataHome › creates and returns a writable directory

When the data home folder does not exist, the app creates it. The returned folder is writable.

Example: `ReshelfHomeTest` does not exist → after resolving, it exists and the app can create `probe.tmp` in it.

### AS-DOC-DAT-006 — A data home path that is a file is an error
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Resolve-ReshelfDataHome › throws when the data home path exists but is a file, not a directory

When the data home path points to an existing file, the app stops with an error. It does not replace the file.

Example: `RESHELF_HOME=<TestDrive>\ReshelfHomeAsFile.tmp`, and that path is a file → error.

## Data folder layout

### AS-DOC-DAT-007 — settings.json is at the data home root
Status: Draft | Source: legacy/README.md › Reference: data folder; legacy/tests/Reshelf.Settings.Tests.ps1 › Initialize-ReshelfSettings › writes valid settings using only supplied params without prompting

The settings file is `<dataHome>\settings.json`. The settings rules are in [03-settings-and-secrets.md](03-settings-and-secrets.md).

Example: data home `D:\data\Reshelf` → `D:\data\Reshelf\settings.json`.

### AS-DOC-DAT-008 — TagLibSharp.dll has a default place under the data home
Status: Draft | Source: legacy/README.md › Reference: data folder; legacy/README.md › Reference: settings (`taglibSharpPath`)

The default location of the TagLibSharp library is `<dataHome>\lib\TagLibSharp.dll`.

Example: data home `.data` → `.data\lib\TagLibSharp.dll`.

### AS-DOC-DAT-009 — Cached Discogs responses live under cache\discogs
Status: Draft | Source: legacy/README.md › Reference: data folder

Cached Discogs API responses are files `<dataHome>\cache\discogs\<hash>.json`. It is a re-run cache, not an archive. The cache expiry and pruning rules: see [06-discogs-client.md](06-discogs-client.md).

Example: `.data\cache\discogs\<hash>.json`.

### AS-DOC-DAT-010 — Each session has its own folder under sessions
Status: Draft | Source: legacy/README.md › Reference: data folder; legacy/tests/Reshelf.Settings.Tests.ps1 › New-ReshelfSession › creates the session folder and a session.json with stage recognized

Each session has a folder `<dataHome>\sessions\<sessionId>\`. It holds:
- `session.json` — stage, source root, timestamps;
- `recognition.json` — output of `recognize`;
- `proposal.json` and `proposal.backup.json` — output of `propose`, edited by the UI;
- `manual-covers\` — covers uploaded through the review UI.

Example: `.data\sessions\2026-09-19-0001\session.json`, and `recognitionPath` = `D:\data\Reshelf\sessions\2026-09-19-0001\recognition.json` in `session-example.json`.

### AS-DOC-DAT-011 — The lossy ledger and the apply log are library-wide files
Status: Draft | Source: legacy/README.md › Reference: data folder; legacy/plan/03-domain-model-and-json-schemas.md › Lossy-tracking file

`lossy-tracking.json` and `apply-log.json` are at the data home root. They are not per session. They cover the whole library.

Example: `.data\lossy-tracking.json`, `.data\apply-log.json`.

## JSON documents and validation

### AS-DOC-DAT-012 — Each JSON document type has one schema file
Status: Draft | Source: legacy/plan/03-domain-model-and-json-schemas.md › Decisions & rationale; legacy/tests/Reshelf.Json.Tests.ps1 › Test-ReshelfJson

Each document type has one JSON Schema (draft 2020-12) file in `schemas/`. The app finds the schema by a short name: `settings`, `session`, `recognition`, `proposal`, `lossy-tracking`, `apply-log`.

Example: schema name `settings` → `schemas/settings.schema.json`.

### AS-DOC-DAT-013 — An unknown schema name is an error
Status: Draft | Source: legacy/tests/Reshelf.Json.Tests.ps1 › Test-ReshelfJson › throws when the schema name does not resolve to a file

When the schema name does not match a schema file, validation stops with an error. It does not return `false`.

Example: schema name `does-not-exist` with JSON `{}` → error.

### AS-DOC-DAT-014 — Validation accepts a file, an object or raw JSON text
Status: Draft | Source: legacy/tests/Reshelf.Json.Tests.ps1 › Test-ReshelfJson

The app can validate a document in three forms: a file path, an in-memory object, or a raw JSON string. All three give the same result.

Example: `settings-example.json` as a path, as a parsed object, and as raw text → valid in all three cases.

### AS-DOC-DAT-015 — An invalid document gives "false", not an error
Status: Draft | Source: legacy/tests/Reshelf.Json.Tests.ps1 › Test-ReshelfJson › returns false for a document missing a required field

When a document breaks its schema, validation returns `false`.

Example: `settings-example.json` without `targetRoot` → `false`.

### AS-DOC-DAT-016 — Arrays stay arrays during validation
Status: Draft | Source: legacy/tests/Reshelf.Json.Tests.ps1 › Test-ReshelfJson › validates a single-element array via -InputObject without collapsing it to an object; › validates an empty array via -InputObject

An array with one element is validated as an array, not as a single object. An empty array is valid for an array schema.

Example: the first entry of `lossy-tracking-example.json` wrapped in an array → valid against `lossy-tracking`; `[]` → valid against `lossy-tracking`.

### AS-DOC-DAT-017 — The app writes a JSON file only when it is valid
Status: Draft | Source: legacy/tests/Reshelf.Json.Tests.ps1 › Set-ReshelfJsonFile › writes the file and returns its path when the document is valid; › throws and does not create the file when the document is invalid

Before it writes a JSON document, the app validates it against its schema. A valid document is written and the app returns the file path. An invalid document causes an error, and no file is created.

Example: settings without `targetRoot`, target `invalid-settings.json` → error, `invalid-settings.json` does not exist.

### AS-DOC-DAT-018 — Writing a JSON file creates missing parent folders
Status: Draft | Source: legacy/tests/Reshelf.Json.Tests.ps1 › Set-ReshelfJsonFile › creates a missing parent directory

When the parent folders of the target file do not exist, the app creates them.

Example: target `nested/dir/settings.json` in an empty folder → the file exists after the write.

### AS-DOC-DAT-019 — A one-element array is written as a JSON array
Status: Draft | Source: legacy/tests/Reshelf.Json.Tests.ps1 › Set-ReshelfJsonFile › writes a single-element array as a JSON array, not a bare object

When the document is an array with one element, the file content starts with `[`. The app does not write a bare object.

Example: `lossy-tracking.json` with one entry → the file text starts with `[`.

### AS-DOC-DAT-020 — The app validates settings.json and session.json when it reads them
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › Get-ReshelfSettings › throws a clear error when the on-disk file fails schema validation; legacy/tests/Reshelf.Settings.Tests.ps1 › Get-ReshelfSession › throws a clear error when session.json fails schema validation

When the app reads `settings.json` or `session.json` and the file breaks its schema, it stops with a clear error. The message contains "does not match".

Example: `settings.json` = `{"copyMode":"copy"}` → error "…does not match…"; `session.json` = `{"stage":"recognized"}` → error "…does not match…".

### AS-DOC-DAT-021 — Each schema has a valid example document
Status: Draft | Source: legacy/tests/Reshelf.Schemas.Tests.ps1 › Schema examples validate against their schema; legacy/plan/03-domain-model-and-json-schemas.md › Definition of done

For each of the six schemas there is an example document in `tests/fixtures/schema-examples/`. Each example is valid against its schema.

Example: `recognition-example.json` → `recognition.schema.json`; `apply-log-example.json` → `apply-log.schema.json`.

### AS-DOC-DAT-022 — A proposal document is a recognition document plus proposal fields
Status: Draft | Source: legacy/tests/Reshelf.Schemas.Tests.ps1 › recognition.json can be extended into a valid proposal.json; legacy/plan/03-domain-model-and-json-schemas.md › proposal.json

`proposal.json` has the same structure as `recognition.json`. It adds proposal-only fields to each release and each track. When you add these fields to a valid recognition document, it becomes a valid proposal document.

Example: `recognition-example.json` + track fields `proposedFileName = '01 Poke Chop Sandwich.flac'`, `tags` and release fields `discogsMatch`, `proposed`, `coverArt`, `lossyLossless`, `targetAction = 'create-new'`, `humanReview` → valid against `proposal.schema.json`.

## Shared value formats

### AS-DOC-DAT-023 — All stored timestamps are UTC in ISO 8601 form
Status: Draft | Source: legacy/schemas/session.schema.json; legacy/schemas/recognition.schema.json; legacy/schemas/apply-log.schema.json; legacy/schemas/lossy-tracking.schema.json

Every timestamp field has the form `yyyy-MM-ddTHH:mm:ssZ`, with optional fractional seconds. The `Z` (UTC) suffix is required.

Example: `"createdAtUtc": "2026-09-19T10:00:00Z"`; `"2026-09-19T10:00:00.123Z"` is also valid; `"2026-09-19T10:00:00+02:00"` is not.

### AS-DOC-DAT-024 — Years are integers from 1900 to 2100
Status: Draft | Source: legacy/schemas/recognition.schema.json › recognizedYear; legacy/schemas/proposal.schema.json › tags.year; legacy/schemas/lossy-tracking.schema.json › year

Every year field is an integer from 1900 to 2100. Some year fields also allow `null` (see the schema requirements below).

Example: `"recognizedYear": 1999` is valid; `1899` and `"1999"` (string) are not.

### AS-DOC-DAT-025 — A stable key is 16 lowercase hex characters in every document
Status: Draft | Source: legacy/schemas/recognition.schema.json › stableKey; legacy/schemas/apply-log.schema.json › stableKey; legacy/schemas/lossy-tracking.schema.json › stableKey

Every `stableKey` field matches `^[0-9a-f]{16}$`.

Example: `"stableKey": "a1b2c3d4e5f60708"`.

## Schema: settings.json

### AS-DOC-DAT-026 — settings.json has exactly 13 required keys
Status: Draft | Source: legacy/schemas/settings.schema.json; legacy/tests/fixtures/schema-examples/settings-example.json

`settings.json` is one object. All 13 keys are required and no other key is allowed: `defaultSourceRoot`, `targetRoot`, `copyMode`, `namingTemplates`, `trackNumberPadWidth`, `coverMaxDimension`, `discogsTokenEnvVar`, `discogsTokenEncrypted`, `rateLimitPerMinute`, `cacheTtlDays`, `dataHome`, `ffmpegPath`, `taglibSharpPath`. The meaning of each key is in [03-settings-and-secrets.md](03-settings-and-secrets.md).

Example: `settings-example.json` has all 13 keys → valid. The same file without `targetRoot` → invalid.

### AS-DOC-DAT-027 — settings.json value limits
Status: Draft | Source: legacy/schemas/settings.schema.json

The schema limits the values:

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

Example: `"copyMode": "move"` → invalid; `"cacheTtlDays": 0` → valid; `"trackNumberPadWidth": 1` → invalid.

### AS-DOC-DAT-028 — namingTemplates has exactly two templates
Status: Draft | Source: legacy/schemas/settings.schema.json › namingTemplates

`namingTemplates` is an object with exactly two required, non-empty strings: `releaseFolder` and `trackFile`. No other key is allowed.

Example: `{ "releaseFolder": "{year} {album}", "trackFile": "{trackNumber} {title}" }`.

## Schema: session.json

### AS-DOC-DAT-029 — session.json has seven required fields
Status: Draft | Source: legacy/schemas/session.schema.json; legacy/tests/fixtures/schema-examples/session-example.json

`session.json` is one object with exactly these required fields: `sessionId`, `sourceRoot`, `createdAtUtc`, `updatedAtUtc`, `stage`, `recognitionPath`, `proposalPath`. No other field is allowed.

Example: `session-example.json` (`sessionId` `2026-09-19-0001`, `sourceRoot` `D:\downloads\incoming`, `stage` `recognized`).

### AS-DOC-DAT-030 — The session id has the form yyyy-MM-dd-NNNN
Status: Draft | Source: legacy/schemas/session.schema.json › sessionId

`sessionId` matches `^\d{4}-\d{2}-\d{2}-\d{4}$`. How the app creates the id: see [04-sessions.md](04-sessions.md).

Example: `2026-09-19-0001` is valid; `2026-09-19-1` is not.

### AS-DOC-DAT-031 — The session stage is one of five values
Status: Draft | Source: legacy/schemas/session.schema.json › stage

`stage` is one of: `recognized`, `proposed`, `reviewed`, `applied`, `partially-applied`. The stage flow: see [04-sessions.md](04-sessions.md).

Example: `"stage": "partially-applied"` is valid; `"stage": "approved"` is not.

### AS-DOC-DAT-032 — proposalPath can be null; recognitionPath cannot be empty
Status: Draft | Source: legacy/schemas/session.schema.json; legacy/tests/fixtures/schema-examples/session-example.json

`recognitionPath` is a non-empty string. `proposalPath` is a string or `null`. `sourceRoot` is a non-empty string.

Example: `session-example.json` has `"proposalPath": null` and `"recognitionPath": "D:\\data\\Reshelf\\sessions\\2026-09-19-0001\\recognition.json"`.

## Schema: recognition.json

### AS-DOC-DAT-033 — recognition.json top level
Status: Draft | Source: legacy/schemas/recognition.schema.json; legacy/tests/fixtures/schema-examples/recognition-example.json; legacy/plan/03-domain-model-and-json-schemas.md › recognition.json

`recognition.json` is one object with exactly these required fields: `schemaVersion` (always `1`), `sessionId`, `sourceRoot`, `generatedAtUtc`, `artists` (array), `unrecognized` (array).

Example: `"schemaVersion": 1, "sessionId": "2026-09-19-0001", "sourceRoot": "D:\\downloads\\incoming"`. `"schemaVersion": 2` → invalid.

### AS-DOC-DAT-034 — A recognized artist has a name, source paths and releases
Status: Draft | Source: legacy/schemas/recognition.schema.json › $defs.artist

Each artist has `recognizedName` (non-empty), `sourcePaths` (at least one non-empty path) and `releases` (array, may be empty).

Example: `"recognizedName": "ZZ Top", "sourcePaths": ["D:\\downloads\\incoming\\ZZ Top"]`.

### AS-DOC-DAT-035 — A recognized release has fourteen required fields
Status: Draft | Source: legacy/schemas/recognition.schema.json › $defs.release

Each release has: `stableKey`, `recognizedTitle` (non-empty), `recognizedYear`, `editionFolderName`, `sourceFolderPath`, `discFolderCount` (integer ≥ 1), `tracks` (at least one), `companionFiles`, `ignoredFiles`, `cueSheets`, `recognitionConfidence` (number 0–1), `recognitionFlags`, `needsReview` (boolean), `reviewReasons`.

Example: release `XXX`, `"recognizedYear": 1999`, `"discFolderCount": 1`, `"recognitionConfidence": 0.95`, one track.

### AS-DOC-DAT-036 — The recognized year can be unknown
Status: Draft | Source: legacy/schemas/recognition.schema.json › recognizedYear; legacy/plan/03-domain-model-and-json-schemas.md › Edge cases

`recognizedYear` is an integer 1900–2100 or `null`. `null` means that recognition found no year.

Example: folder `XXX` with no year → `"recognizedYear": null`.

### AS-DOC-DAT-037 — Release date and release type are optional and nullable
Status: Draft | Source: legacy/tests/Reshelf.Schemas.Tests.ps1 › Schema examples validate against their schema › recognition-example.json validates with recognizedReleaseDate/recognizedReleaseType added…; legacy/schemas/recognition.schema.json

A release may have `recognizedReleaseDate` (`yyyy-MM-dd` or `null`) and `recognizedReleaseType` (`album`, `mini-album`, `ep`, `single`, `maxi-single`, `lp`, or `null`). The fields may also be absent.

Example: `"recognizedReleaseDate": "1999-08-29", "recognizedReleaseType": "album"` → valid; both `null` → valid; both absent → valid.

### AS-DOC-DAT-038 — The edition folder name is null or non-empty
Status: Draft | Source: legacy/schemas/recognition.schema.json › editionFolderName; legacy/tests/fixtures/schema-examples/recognition-example.json

`editionFolderName` is required. It is `null` or a non-empty string. How recognition fills it: see [05-recognition.md](05-recognition.md).

Example: `recognition-example.json` has `"editionFolderName": null`.

### AS-DOC-DAT-039 — Recognition flags are separate from the review decision
Status: Draft | Source: legacy/plan/03-domain-model-and-json-schemas.md › recognition.json (Notes); legacy/plan/03-domain-model-and-json-schemas.md › Decisions & rationale

`recognitionFlags` holds machine-readable reason codes, also when `needsReview` is `false`. Only ambiguous cases set `needsReview = true`; then `reviewReasons` explains why. Which codes exist: see [05-recognition.md](05-recognition.md).

Example: a release whose track numbers were inferred → `"recognitionFlags": ["no-track-number"]`, `"needsReview": false`.

### AS-DOC-DAT-040 — A recognized track has twelve required fields
Status: Draft | Source: legacy/schemas/recognition.schema.json › $defs.track; legacy/tests/fixtures/schema-examples/recognition-example.json

Each track has: `sourceFilePath`, `discFolder`, `originalFileName`, `detectedTrackNumberInDisc` (integer ≥ 1), `inferredTrackOrder` (boolean), `existingTags`, `existingCoverArtPath` (string or `null`), `format` (non-empty), `isLossless` (boolean), `durationSeconds` (number ≥ 0), `cueTimestamp`, `isCueVirtualTrack` (boolean).

Example: `"originalFileName": "01 Poke Chop Sandwich.flac", "format": "flac", "isLossless": true, "durationSeconds": 231`.

### AS-DOC-DAT-041 — The disc folder is null for a single-disc release
Status: Draft | Source: legacy/plan/03-domain-model-and-json-schemas.md › recognition.json (Notes); legacy/schemas/recognition.schema.json › discFolder

`discFolder` is `null` for a single-disc release. For a multi-disc release it holds the disc subfolder name.

Example: single disc → `"discFolder": null`; 2-CD release → `"CD 1"`, `"CD 2"`.

### AS-DOC-DAT-042 — Existing tags hold artist, album and title, each nullable
Status: Draft | Source: legacy/schemas/recognition.schema.json › existingTags

`existingTags` has exactly three required keys: `artist`, `album`, `title`. Each is a string or `null`.

Example: a file without tags → `{ "artist": null, "album": null, "title": null }`.

### AS-DOC-DAT-043 — A cue timestamp has the form MM:SS:FF
Status: Draft | Source: legacy/schemas/recognition.schema.json › cueTimestamp

`cueTimestamp` is `null` or a string `NN:NN:NN` (minutes, seconds, CD frames). How the app converts it to seconds: see AS-DOC-TXT-040 in [02-text-and-naming-rules.md](02-text-and-naming-rules.md).

Example: a plain file track → `"cueTimestamp": null`; a cue virtual track → `"cueTimestamp": "09:26:73"`.

### AS-DOC-DAT-044 — A used cue sheet is a pair of cue file and audio file
Status: Draft | Source: legacy/schemas/recognition.schema.json › cueSheets; legacy/plan/03-domain-model-and-json-schemas.md › recognition.json (Notes)

`cueSheets` is an array. Each item has `cueFilePath` and `audioFilePath`, both non-empty. A cue sheet that the app uses to split a single-file release is listed only here. It is not in `companionFiles` and not in `ignoredFiles`.

Example: `{ "cueFilePath": "…\\album.cue", "audioFilePath": "…\\album.flac" }`; a release without cue → `"cueSheets": []`.

### AS-DOC-DAT-045 — A companion file has a kind and a placement
Status: Draft | Source: legacy/schemas/recognition.schema.json › $defs.companionFile; legacy/plan/03-domain-model-and-json-schemas.md › recognition.json (Notes)

Each companion file has `sourcePath`, `kind` and `placement`. `kind` is one of `cover`, `booklet`, `photo`, `lyrics`, `other`. Plan 03 says `placement` is `loose` (directly in the release folder) or `nested` (in a subfolder). The schema accepts any non-empty string for `placement`.

Example: `{ "sourcePath": "D:\\downloads\\incoming\\ZZ Top\\1999 XXX\\cover.jpg", "kind": "cover", "placement": "loose" }`.

### AS-DOC-DAT-046 — An ignored file has a reason
Status: Draft | Source: legacy/schemas/recognition.schema.json › $defs.ignoredFile; legacy/plan/03-domain-model-and-json-schemas.md › recognition.json (Notes)

Each ignored file has `sourcePath` and `reason`, both non-empty. Plan 03 names the reasons `playlist-file` (no playlists in the target) and `cue-sheet-not-used` (a `.cue` file that is not the one used to split the release).

Example: `{ "sourcePath": "…\\playlist.m3u", "reason": "playlist-file" }`.

### AS-DOC-DAT-047 — An unrecognized folder has a path, a reason and its children
Status: Draft | Source: legacy/schemas/recognition.schema.json › $defs.unrecognizedEntry; legacy/tests/fixtures/schema-examples/recognition-example.json; legacy/tests/fixtures/schema-examples/proposal-example.json

Each `unrecognized` entry has `path`, `reason` (both non-empty) and `children` (array of names). Which reasons exist: see [05-recognition.md](05-recognition.md).

Example: `{ "path": "D:\\downloads\\incoming\\Empty Folder", "reason": "no-audio-files", "children": [] }`; `{ "path": "…\\Godspeeds and their projects", "reason": "grouping-folder-suspected", "children": ["Godspeed You! Black Emperor", "Silver Mountain Zion"] }`.

## Schema: proposal.json

### AS-DOC-DAT-048 — A proposed release adds six required fields
Status: Draft | Source: legacy/schemas/proposal.schema.json › $defs.release; legacy/plan/03-domain-model-and-json-schemas.md › proposal.json

In `proposal.json` each release has all recognition fields plus six required fields: `discogsMatch`, `proposed`, `coverArt`, `lossyLossless`, `targetAction`, `humanReview`.

Example: `proposal-example.json`, release `XXX`.

### AS-DOC-DAT-049 — The Discogs match has a status, a selected release and candidates
Status: Draft | Source: legacy/schemas/proposal.schema.json › discogsMatch; legacy/tests/fixtures/schema-examples/proposal-example.json

`discogsMatch` has `status` (`matched`, `ambiguous` or `not-found`), `selectedReleaseId` (integer or `null`) and `candidates`. It may also have `masterId` (integer or `null`). Each candidate has `releaseId`, `title` (non-empty), `year` (1900–2100 or `null`), `format` (non-empty) and `score` (0–1). How matching works: see [07-proposal-matching.md](07-proposal-matching.md).

Example: `{ "status": "matched", "selectedReleaseId": 123456, "candidates": [ { "releaseId": 123456, "title": "XXX", "year": 1999, "format": "CD, Album", "score": 0.97 } ] }`.

### AS-DOC-DAT-050 — The proposed block holds the target folder names, year and album
Status: Draft | Source: legacy/schemas/proposal.schema.json › proposed; legacy/plan/03-domain-model-and-json-schemas.md › proposal.json

`proposed` has `artistFolderName`, `releaseFolderName`, `album` (all non-empty) and `year` (1900–2100 or `null`). `isCompilation` (boolean) is optional; when it is absent (older `proposal.json`), it counts as `false`.

Example: `{ "artistFolderName": "ZZ Top", "releaseFolderName": "1999 XXX", "year": 1999, "album": "XXX" }`.

### AS-DOC-DAT-051 — Cover art holds candidates, the chosen URL and a size limit
Status: Draft | Source: legacy/schemas/proposal.schema.json › coverArt; legacy/tests/fixtures/schema-examples/proposal-example.json

`coverArt` has `candidates`, `chosenCandidateUrl` (string or `null`) and `targetMaxDimension` (integer ≥ 1). Each candidate has `url` (non-empty), `sourceEdition` (string), `width` and `height` (integers ≥ 1).

Example: `{ "candidates": [ { "url": "https://example.com/cover.jpg", "sourceEdition": "US CD", "width": 1200, "height": 1200 } ], "chosenCandidateUrl": "https://example.com/cover.jpg", "targetMaxDimension": 600 }`.

### AS-DOC-DAT-052 — The lossy/lossless block has a flag and one of five actions
Status: Draft | Source: legacy/schemas/proposal.schema.json › lossyLossless

`lossyLossless` has `isLossy` (boolean) and `action`. `action` is one of `none`, `log-for-upgrade`, `replace-existing`, `previously-lossy-different-location`, `previously-lossy-target-missing`. It may have `previousLossy` with `targetPath`, `format`, `firstDetectedUtc` and `targetExists` (all required inside it). The meaning of the actions: see [11-lossy-tracking.md](11-lossy-tracking.md).

Example: `{ "isLossy": false, "action": "none" }`.

### AS-DOC-DAT-053 — The target action is one of four values
Status: Draft | Source: legacy/schemas/proposal.schema.json › targetAction; legacy/plan/03-domain-model-and-json-schemas.md › proposal.json

`targetAction` is one of `create-new`, `skip-existing-identical`, `update-existing`, `conflict`. How propose chooses it: see [07-proposal-matching.md](07-proposal-matching.md).

Example: `"targetAction": "create-new"`.

### AS-DOC-DAT-054 — Human review has four required fields
Status: Draft | Source: legacy/schemas/proposal.schema.json › humanReview; legacy/plan/03-domain-model-and-json-schemas.md › proposal.json (field rules)

`humanReview` has `required`, `resolved`, `rejected` (booleans) and `notes` (string). `resolved: false` means "not reviewed yet". `rejected: true` means a deliberate, permanent "never apply this". Only the review UI sets `rejected`. How apply treats it: see [10-apply.md](10-apply.md).

Example: `{ "required": false, "resolved": true, "rejected": false, "notes": "" }`. Two folders turn out to be two different pressings of the same album; the one the user does not keep gets `rejected: true`.

### AS-DOC-DAT-055 — A proposed track adds file name, numbers, title and tags
Status: Draft | Source: legacy/schemas/proposal.schema.json › $defs.track; legacy/tests/Reshelf.Schemas.Tests.ps1 › recognition.json can be extended into a valid proposal.json

In `proposal.json` each track has all recognition fields plus `proposedFileName` (non-empty), `proposedDiscNumber` (integer ≥ 1), `proposedTrackNumber` (integer ≥ 1), `proposedTitle` (non-empty) and `tags`.

Example: `"proposedFileName": "01 Poke Chop Sandwich.flac", "proposedDiscNumber": 1, "proposedTrackNumber": 1, "proposedTitle": "Poke Chop Sandwich"`.

### AS-DOC-DAT-056 — Track tags are all required and never empty
Status: Draft | Source: legacy/schemas/proposal.schema.json › tags

`tags` has seven required fields: `artist`, `albumArtist`, `album`, `title` (non-empty strings), `year` (integer 1900–2100, not `null`), `discNumber` and `track` (integers ≥ 1). `isCompilation` (boolean) is optional. Plan 03 says it has the same value as `proposed.isCompilation` on every track. The tag rules: see AS-DOC-TXT-057 to AS-DOC-TXT-072 in [02-text-and-naming-rules.md](02-text-and-naming-rules.md).

Example: `{ "artist": "ZZ Top", "albumArtist": "ZZ Top", "album": "XXX", "year": 1999, "discNumber": 1, "track": 1, "title": "Poke Chop Sandwich" }`.

### AS-DOC-DAT-057 — A proposed companion file can be excluded and renamed
Status: Draft | Source: legacy/schemas/proposal.schema.json › $defs.companionFile; legacy/tests/fixtures/schema-examples/proposal-example.json

In `proposal.json` a companion file may also have `include` (boolean) and `proposedFileName` (non-empty string or `null`).

Example: `{ "sourcePath": "…\\cover.jpg", "kind": "cover", "placement": "loose", "include": true, "proposedFileName": "cover.jpg" }`.

### AS-DOC-DAT-058 — An unknown year gets the placeholder year 1900 in the proposal
Status: Draft | Source: legacy/plan/03-domain-model-and-json-schemas.md › Edge cases

Same rule as AS-DOC-PRP-011 in [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md) (primary, from the golden file). This entry keeps its plan source.

When a release has no year (`recognizedYear: null`), propose does not block. It uses the fixed placeholder year `1900` (the schema minimum) in the folder name. It sets `humanReview.required = true` with the note `UNRESOLVED YEAR: placeholder value used, must be corrected before applying`. The release still gets a `targetAction` (usually `create-new`). The proposal rules: see [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md).

Example: `ZZ Top/XXX` without a year → release folder `1900 XXX`, review required.

## Schema: apply-log.json

### AS-DOC-DAT-059 — apply-log.json is an array of per-release apply results
Status: Draft | Source: legacy/schemas/apply-log.schema.json; legacy/tests/fixtures/schema-examples/apply-log-example.json

`apply-log.json` is an array. Each entry has exactly seven required fields: `stableKey`, `appliedAtUtc`, `status`, `targetPath` (non-empty), `sourceFileSetHash` (non-empty), `errorMessage` (string or `null`), `truncated` (boolean). How apply uses it: see [10-apply.md](10-apply.md).

Example: `{ "stableKey": "a1b2c3d4e5f60708", "appliedAtUtc": "2026-09-19T10:00:00Z", "status": "applied", "targetPath": "E:\\Music\\ZZ Top\\1999 XXX", "sourceFileSetHash": "9f3a…0708", "errorMessage": null, "truncated": false }`.

### AS-DOC-DAT-060 — An apply-log status is applied, failed or skipped
Status: Draft | Source: legacy/schemas/apply-log.schema.json › status

`status` is one of `applied`, `failed`, `skipped`.

Example: `"status": "failed"` with `"errorMessage": "…"`; `"status": "applied"` with `"errorMessage": null`.

## Schema: lossy-tracking.json

### AS-DOC-DAT-061 — lossy-tracking.json is an array of lossy releases
Status: Draft | Source: legacy/schemas/lossy-tracking.schema.json; legacy/tests/fixtures/schema-examples/lossy-tracking-example.json

`lossy-tracking.json` is an array. Each entry has exactly eleven required fields: `stableKey`, `artist`, `album` (non-empty), `year` (integer 1900–2100, not `null`), `targetPath`, `format` (non-empty), `status`, `firstDetectedUtc`, `lastCheckedUtc`, `upgradedUtc` (timestamp or `null`), `notes` (string). How the ledger is used: see [11-lossy-tracking.md](11-lossy-tracking.md).

Example: `{ "stableKey": "a1b2c3d4e5f60708", "artist": "ZZ Top", "album": "XXX", "year": 1999, "targetPath": "E:\\Music\\ZZ Top\\1999 XXX", "format": "mp3", "status": "pending-upgrade", "upgradedUtc": null, "notes": "" }`.

### AS-DOC-DAT-062 — A lossy entry status is pending-upgrade, upgraded or ignored
Status: Draft | Source: legacy/schemas/lossy-tracking.schema.json › status

`status` is one of `pending-upgrade`, `upgraded`, `ignored`.

Example: `"status": "pending-upgrade"`.

## Hashes and stable keys

### AS-DOC-DAT-063 — A text hash is a 64-character lowercase SHA-256 hex string
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Get-ReshelfSha256Hex

The app hashes a text with SHA-256 and writes the result as 64 lowercase hex characters. The same text always gives the same hash. Different texts give different hashes.

Example: `D:\downloads\incoming` twice → the same hash; `a` and `b` → different hashes.

### AS-DOC-DAT-064 — A stable key identifies a release by artist, album and year
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Get-ReshelfStableKey; legacy/plan/03-domain-model-and-json-schemas.md › stableKey — the linchpin

The stable key is 16 lowercase hex characters. Plan 03 says it is the first 16 characters of the SHA-256 hash of the normalized text `<artist>|<album>|<year>`. The same input always gives the same key.

Example: artist `ZZ Top`, album `XXX`, year `1999` → a key like `a1b2c3d4e5f60708`, the same on every run.

### AS-DOC-DAT-065 — The stable key ignores case and extra spaces
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Get-ReshelfStableKey › normalizes case and whitespace before hashing; legacy/plan/03-domain-model-and-json-schemas.md › stableKey — the linchpin

Before hashing, the app lowercases, trims and collapses spaces. Plan 03 says it also strips punctuation.

Example: (`ZZ Top`, `XXX`, 1999) and (`  zz   top `, ` xxx `, 1999) → the same key.

### AS-DOC-DAT-066 — The year is part of the stable key and can be null
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Get-ReshelfStableKey › produces different keys for different years; › accepts a null year; legacy/plan/03-domain-model-and-json-schemas.md › Edge cases

Different years give different keys. A missing year (`null`) is allowed. The key always uses the real recognized year, never the placeholder year `1900` (AS-DOC-DAT-058).

Example: (`ZZ Top`, `XXX`, 1999) and (`ZZ Top`, `XXX`, 2000) → different keys; (`ZZ Top`, `XXX`, `null`) → a key, no error.

### AS-DOC-DAT-067 — The same release gets the same key from any source folder
Status: Draft | Source: legacy/plan/03-domain-model-and-json-schemas.md › stableKey — the linchpin; › Decisions & rationale

The key depends only on the content (artist, album, year), not on the folder or a random id. So a release recognized today and again six months later from another source folder gets the same key. Re-runs, duplicate detection and resume use this. The re-run rules: see [07-proposal-matching.md](07-proposal-matching.md).

Example: `D:\downloads\incoming\ZZ Top\1999 XXX` and `F:\usb\ZZ Top - XXX (1999)` both recognized as (`ZZ Top`, `XXX`, 1999) → the same key.

### AS-DOC-DAT-068 — The file-set hash does not depend on the order of the files
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Get-ReshelfFileSetHash › is deterministic for the same file set; › is independent of input order

The app computes one hash for a set of files. The same set gives the same hash, in any order.

Example: (`a.flac`, `b.flac`) and (`b.flac`, `a.flac`) → the same hash.

### AS-DOC-DAT-069 — The file-set hash ignores the case of file names
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Get-ReshelfFileSetHash › is case-insensitive on file name

The same file written in upper case or lower case gives the same hash.

Example: `<dir>\a.flac` and `<DIR>\A.FLAC` → the same hash.

### AS-DOC-DAT-070 — The file-set hash changes when a file size changes
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Get-ReshelfFileSetHash › produces a different hash when file size changes

When the size of a file in the set changes, the hash changes. The tests do not show whether a content change with the same size changes the hash.

Example: `a.flac` with content `aaaa`, then `aaaaaaaa` → different hashes.

### AS-DOC-DAT-071 — An empty file set has a fixed hash
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Get-ReshelfFileSetHash › is deterministic for an empty file list

An empty list of files gives a hash, and it is always the same one.

Example: `@()` twice → the same hash.

## Long paths

### AS-DOC-DAT-072 — A short path stays as it is
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › ConvertTo-ReshelfLongPath › leaves a short path unchanged

A path that is not near the Windows path length limit is not changed. The tests do not state the exact limit.

Example: `D:\music\ZZ Top\1999 XXX` → `D:\music\ZZ Top\1999 XXX`.

### AS-DOC-DAT-073 — A near-limit local path gets the `\\?\` prefix
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › ConvertTo-ReshelfLongPath › prefixes a near-limit local path with \\?\

A local path near the length limit gets the `\\?\` long-path prefix.

Example: `D:\` + 250 × `a` (253 characters) → `\\?\D:\aaaa…`.

### AS-DOC-DAT-074 — A near-limit network path gets the `\\?\UNC\` prefix
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › ConvertTo-ReshelfLongPath › prefixes a near-limit UNC path with \\?\UNC\

A UNC (network share) path near the limit gets the `\\?\UNC\` prefix. The leading `\\` is dropped.

Example: `\\server\share\` + 250 × `a` → `\\?\UNC\server\share\aaaa…`.

### AS-DOC-DAT-075 — A path that already has the prefix is not changed
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › ConvertTo-ReshelfLongPath › does not double-prefix an already-long-form path

A path that already starts with `\\?\` does not get a second prefix.

Example: `\\?\D:\` + 250 × `a` → the same text.

## Audio files

### AS-DOC-DAT-076 — Audio files are detected by extension, in any case
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Test-ReshelfIsAudioExtension

The app decides by the file extension if a file is audio. The check ignores case. Musepack (`.mpc`) counts as audio. The full list of extensions is not in these inputs; see [05-recognition.md](05-recognition.md).

Example: `.FLAC` → audio; `.mpc` → audio; `.txt` → not audio.

### AS-DOC-DAT-077 — A file without an extension is not audio, and not an error
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Test-ReshelfIsAudioExtension › returns false, not a binding error, for an empty extension; legacy/tests/Reshelf.Common.Tests.ps1 › Test-ReshelfIsLosslessFormat › returns false, not a binding error, for an empty extension

An empty extension gives "not audio" and "not lossless". It does not cause an error.

Example: file `README` (extension `''`) → not audio, not lossless.

### AS-DOC-DAT-078 — Lossless formats are detected by extension
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Test-ReshelfIsLosslessFormat

The app decides by the extension if an audio format is lossless.

Example: `.flac` → lossless; `.mpc` (Musepack) → lossy.

### AS-DOC-DAT-079 — Listing audio files in a folder skips non-audio files and subfolders
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Get-ReshelfAudioFilesInFolder › returns only audio files, ignoring extensions like .txt/.m3u/.cue, without recursing by default

By default the app lists only the audio files directly in the folder. It skips text, playlist and cue files. It does not look into subfolders.

Example: folder with `01 Track.flac`, `02 Track.mp3`, `readme.txt`, `playlist.m3u`, `CD 1\01 Nested.flac` → `01 Track.flac`, `02 Track.mp3`.

### AS-DOC-DAT-080 — Listing audio files can include subfolders
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Get-ReshelfAudioFilesInFolder › recurses into subfolders when -Recurse is passed

On request, the app also lists the audio files in all subfolders.

Example: `CD 1\01 Track.flac`, `CD 2\01 Track.flac` with the recursive option → 2 files.

### AS-DOC-DAT-081 — A folder without audio files gives an empty list
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Get-ReshelfAudioFilesInFolder › returns an empty array, not an error, for a folder with no audio files

A folder with no audio files gives an empty list, not an error.

Example: folder with only `notes.txt` → 0 files.

## Relative paths

### AS-DOC-DAT-082 — A relative path uses forward slashes
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Get-ReshelfRelativePath › returns the path under the source root with forward slashes, regardless of backslash depth

The app writes a path below the source root as a relative path with `/` separators, at any depth.

Example: root `C:\Music\Source`, path `C:\Music\Source\Some Band\2010 Album\Scans\front.jpg` → `Some Band/2010 Album/Scans/front.jpg`.

### AS-DOC-DAT-083 — The root match ignores case and a trailing separator
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Get-ReshelfRelativePath › matches the root case-insensitively; › tolerates a trailing separator on the root

The app matches the root without regard to case. A trailing `\` on the root does not matter.

Example: root `c:\music\source`, path `C:\Music\Source\Some Band\front.jpg` → `Some Band/front.jpg`; root `C:\Music\Source\`, path `C:\Music\Source\Album\file.jpg` → `Album/file.jpg`.

### AS-DOC-DAT-084 — A path outside the root stays as it is
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Get-ReshelfRelativePath › returns the path unchanged when it does not start with the given root

When the path does not start with the root, the app returns it unchanged (with its backslashes).

Example: root `C:\Music\Source`, path `D:\Elsewhere\file.jpg` → `D:\Elsewhere\file.jpg`.

### AS-DOC-DAT-085 — The root itself gives an empty relative path
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Get-ReshelfRelativePath › returns an empty string for a path identical to the root

When the path is the root itself, the relative path is an empty string.

Example: root `C:\Music\Source`, path `C:\Music\Source` → `''`.

## TagLibSharp loading

### AS-DOC-DAT-086 — Without a configured path, TagLibSharp is loaded from the data home
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Import-ReshelfTagLibSharp › falls back to the script-scoped DataHome … for auto-discovery; legacy/README.md › Reference: settings (`taglibSharpPath`)

When `taglibSharpPath` is empty, the app loads `<dataHome>\lib\TagLibSharp.dll`. When it is set, the app uses that full path.

Example: data home `<TestDrive>\<guid>`, file `<TestDrive>\<guid>\lib\TagLibSharp.dll` exists → the app loads that file.

### AS-DOC-DAT-087 — A missing TagLibSharp.dll gives a clear error with the path
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Import-ReshelfTagLibSharp › throws a clear error naming the resolved path when the DLL is missing there

When the DLL is not at the resolved path, the app stops with an error. The message contains `TagLibSharp.dll not found` and the path it checked.

Example: data home without `lib\TagLibSharp.dll` → error "TagLibSharp.dll not found … <dataHome>\lib\TagLibSharp.dll".

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-05 | Phase 1 draft. |
