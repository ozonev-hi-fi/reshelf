# Step 3 — Domain Model and JSON Schemas

## Purpose / scope

Define, once, the exact shape of every JSON document that flows between
modules. Every other step file references field names defined here instead of
re-defining them, to avoid drift.

## Inputs / outputs

- Input: manifesto §4 (structure rules) and §5 (metadata rules).
- Output: `schemas/*.schema.json` files, validated at runtime via PowerShell 7's
  `Test-Json -SchemaFile ...`, plus this document as the field-by-field
  reference.

## Detailed design

### `stableKey` — the linchpin

A deterministic id for a release: a hash (e.g. SHA-256, hex-encoded, first 16
chars) of the normalized string `"<artist>|<album>|<year>"` (lowercased,
trimmed, punctuation-stripped). The same real-world release always produces
the same `stableKey`, whether it's recognized today or six months from now
from a different source folder. This is what makes re-runs, duplicate
detection, and resuming a session possible — see
[10-error-handling-and-edge-cases.md](10-error-handling-and-edge-cases.md).

### `recognition.json` (output of step 5)

```jsonc
{
  "schemaVersion": 1,
  "sessionId": "2026-09-19-0001",
  "sourceRoot": "D:\\downloads\\incoming",
  "generatedAtUtc": "2026-09-19T10:00:00Z",
  "artists": [
    {
      "recognizedName": "ZZ Top",
      "sourcePaths": ["D:\\downloads\\incoming\\ZZ Top"],
      "releases": [
        {
          "stableKey": "a1b2c3d4e5f60708",
          "recognizedTitle": "XXX",
          "recognizedYear": 1999,
          "sourceFolderPath": "D:\\downloads\\incoming\\ZZ Top\\1999 XXX",
          "discFolderCount": 1,
          "tracks": [
            {
              "sourceFilePath": "...\\01 Poke Chop Sandwich.flac",
              "discFolder": null,
              "originalFileName": "01 Poke Chop Sandwich.flac",
              "detectedTrackNumberInDisc": 1,
              "inferredTrackOrder": false,
              "existingTags": { "artist": null, "album": null, "title": null },
              "format": "flac",
              "isLossless": true,
              "durationSeconds": 231
            }
          ],
          "companionFiles": [
            { "sourcePath": "...\\cover.jpg", "kind": "cover", "placement": "loose" }
          ],
          "cueSheet": null,
          "recognitionConfidence": 0.95,
          "recognitionFlags": [],
          "needsReview": false,
          "reviewReasons": []
        }
      ]
    }
  ],
  "unrecognized": [
    {
      "path": "D:\\downloads\\incoming\\Godspeeds and their projects",
      "reason": "grouping-folder-suspected",
      "children": ["Godspeed You! Black Emperor", "Silver Mountain Zion"]
    }
  ]
}
```

Notes:
- `discFolder` is `null` for single-disc releases, or `"CD 1"`/`"CD 2"` etc.
  when detected.
- `cueSheet`, when present: `{ "cueFilePath": "...", "audioFilePath": "..." }`.
- `recognitionFlags` carries machine-readable reason codes (e.g.
  `"no-track-number"`, `"no-separator"`) even when `needsReview` is false, so
  the Edit Proposal step can make informed decisions.
- `ignoredFiles[].reason`: `"playlist-file"` (manifesto §4.4: no playlists
  allowed), or `"cue-sheet-not-used"` for a `.cue` file that is *not* the one
  actually used to split a single-file+cue release (see [05](05-recognition-module.md))
  — that used cue sheet stays out of both `companionFiles` and `ignoredFiles`,
  since it's fully represented by `cueSheet` instead.
- `companionFiles[].placement`: `"loose"` (directly in the release folder,
  next to the media files) or `"nested"` (in a subfolder) — see manifesto §4.5.

### `proposal.json` (output of step 6, read/written by step 7)

Extends each release from `recognition.json` with:

```jsonc
{
  "discogsMatch": {
    "status": "matched",           // matched | ambiguous | not-found
    "selectedReleaseId": 123456,
    "candidates": [
      { "releaseId": 123456, "title": "XXX", "year": 1999, "format": "CD, Album", "score": 0.97 }
    ]
  },
  "proposed": {
    "artistFolderName": "ZZ Top",
    "releaseFolderName": "1999 XXX",
    "year": 1999,
    "album": "XXX",
    "isCompilation": false   // optional, defaults to false when absent (older proposal.json)
  },
  "tracks": [
    {
      "proposedFileName": "01 Poke Chop Sandwich.flac",
      "proposedDiscNumber": 1,
      "proposedTrackNumber": 1,
      "proposedTitle": "Poke Chop Sandwich",
      "tags": {
        "artist": "ZZ Top",
        "albumArtist": "ZZ Top",
        "album": "XXX",
        "year": 1999,
        "discNumber": 1,
        "track": 1,
        "title": "Poke Chop Sandwich",
        "isCompilation": false   // optional; same value as proposed.isCompilation on every track
      }
    }
  ],
  "coverArt": {
    "candidates": [
      { "url": "https://...", "sourceEdition": "US CD", "width": 1200, "height": 1200 }
    ],
    "chosenCandidateUrl": "https://...",
    "targetMaxDimension": 600
  },
  "lossyLossless": { "isLossy": false, "action": "none" },   // none | log-for-upgrade | replace-existing
  "targetAction": "create-new",   // create-new | skip-existing-identical | update-existing | conflict
  "humanReview": { "required": false, "resolved": true, "rejected": false, "notes": "" }
}
```

Field rules that directly encode manifesto §5:
- `tags.discNumber` starts at 1, always present.
- `tags.track` restarts at 1 per disc, **no leading zero**.
- `proposedFileName`'s `NN` prefix is zero-padded and continuous across discs
  (differs from `tags.track`).
- `tags.albumArtist` always equals the *raw* artist name (typically "Various"
  on a compilation); `proposed.artistFolderName` is the same text with
  filesystem-invalid characters replaced by `_` (via `ConvertTo-SafeFileName`)
  — they match character-for-character except where sanitization applied.
- `tags.artist` equals `tags.albumArtist` by default. On a compilation
  (`proposed.isCompilation`/`tags.isCompilation` true — Discogs' own "Various"
  artist, or a recognized "Various"/"Various Artists" folder/artist name with
  no Discogs match), `tags.artist` can instead be Discogs' own per-track
  credit, or the source file's existing Artist tag when Discogs has none for
  that track — see [06](06-edit-proposal-module.md). This also covers a
  split release with per-track Discogs credits, whether or not it's a
  Various-Artists compilation.
- feat. artists appear only in `proposedTitle` / `proposedFileName`, never in
  `tags.artist` / `tags.albumArtist`.
- `tags.album` is the *raw* album/release title; `proposed.releaseFolderName`
  (`"yyyy The Album Name"`) uses the sanitized form of the same title, with
  `tags.year` supplying the `yyyy` prefix. Sanitization never touches
  `tags.*` or `proposedTitle` — only the filesystem-facing name fields
  (`artistFolderName`, `releaseFolderName`, `proposedFileName`).
- `humanReview.rejected` is a human's deliberate, permanent "never apply
  this" decision — distinct from `resolved: false`, which just means "not
  reviewed yet." Set only via the editing UI (step 07); [08](08-implementation-module.md)
  always skips a rejected release, even with `-IncludeUnresolved`, since that
  flag means "apply what hasn't been looked at yet," not "override an
  explicit no." A real example: two folders turn out to be different
  physical pressings of the same album (e.g. two different Discogs release
  ids) that only diverged this late because pressing/rip tags in the folder
  names broke automatic matching — the one not being kept gets rejected here.

### `session.json`

```jsonc
{
  "sessionId": "2026-09-19-0001",
  "sourceRoot": "D:\\downloads\\incoming",
  "createdAtUtc": "2026-09-19T10:00:00Z",
  "updatedAtUtc": "2026-09-19T10:05:00Z",
  "stage": "recognized",   // recognized | proposed | reviewed | applied | partially-applied
  "recognitionPath": "...\\recognition.json",
  "proposalPath": "...\\proposal.json"
}
```

### `settings.json`

```jsonc
{
  "defaultSourceRoot": "",
  "targetRoot": "E:\\Music",
  "copyMode": "copy",               // "copy" only - source files are always read-only
  "namingTemplates": {
    "releaseFolder": "{year} {album}",
    "trackFile": "{trackNumber} {title}"
  },
  "trackNumberPadWidth": 2,
  "coverMaxDimension": 600,
  "discogsTokenEnvVar": "DISCOGS_ACCESS_TOKEN",
  "rateLimitPerMinute": 55,
  "cacheTtlDays": 30,
  "dataHome": ""
}
```

### Lossy-tracking file

See [09-lossy-lossless-tracking.md](09-lossy-lossless-tracking.md) for the full
schema — it's a standalone, library-wide ledger rather than per-session.

## Decisions & rationale

- **`stableKey` as a content-derived hash, not a random GUID**: a GUID would
  make the exact same real-world release look like a new one every time it's
  re-recognized from a different source folder. A deterministic hash of
  `artist|album|year` lets every module independently agree "this is the same
  release" without a shared database.
- **One schema file per document, validated with `Test-Json`**: catches shape
  drift immediately during development rather than failing deep inside a later
  module with a confusing error.
- **`recognitionFlags` separate from `needsReview`**: keeps low-signal
  information (e.g. "no track number found, had to infer order") available for
  later steps and debugging, without forcing every such case into manual
  review — only genuinely ambiguous cases (§5 in
  [05](05-recognition-module.md)) set `needsReview = true`.

## Edge cases

- Track counts over 99 → `trackNumberPadWidth` computed per-release as
  `max(settings.trackNumberPadWidth, digits needed for total track count
  across discs)` — the setting is the *floor*, not a fixed value; it defaults
  to 2, which reproduces the original hardcoded behavior (see
  [04](04-settings-module.md)).
- A release with no year known yet (recognized but not matched to Discogs) →
  `recognizedYear: null` permitted in `recognition.json`. As implemented
  (checked 2026-09-26), `proposal.json` does **not** block on this the way
  originally planned: `New-ReshelfProposedReleaseNames`
  (`Reshelf.EditProposal.psm1`) substitutes a fixed sentinel year (`1900`,
  `schema:UnresolvedYearSentinel`, the schema's own minimum) for the folder
  name and forces `humanReview.required = true` with a
  `"UNRESOLVED YEAR: placeholder value used, must be corrected before
  applying"` note, so the release still gets a `targetAction` (typically
  `create-new`) and can be applied with `-IncludeUnresolved`. `stableKey`
  itself is still computed from the real `recognizedYear` (`null` if
  unresolved), never from the sentinel — this is why the re-run/target-match
  logic (steps [06](06-edit-proposal-module.md)/[10](10-error-handling-and-edge-cases.md))
  can't rely on recomputing a stableKey from the *target folder's* name (which
  always has the sentinel year baked in) for this case; it must look the
  release up by its own stableKey instead (e.g. via `apply-log.json`).

## Definition of done

- Each schema file in `schemas/` validates the example documents above via
  `Test-Json`.
- A round-trip test (see [11](11-testing-and-verification-strategy.md)) can
  read a `recognition.json`, add proposal fields, and validate the result
  against `proposal.schema.json`.
