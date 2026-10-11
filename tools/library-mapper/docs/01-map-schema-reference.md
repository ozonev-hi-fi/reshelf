# Map schema reference

Full schema: [`../schemas/library-map.schema.json`](../schemas/library-map.schema.json).
Field names deliberately match legacy's `legacy/schemas/recognition.schema.json`
wherever the concept is the same, so the two are easy to compare by eye.

## Envelope

| Field | Meaning |
|---|---|
| `schemaVersion` | Always `1` |
| `label` | The free-text label this map was generated for (e.g. `before`/`after`) |
| `libraryRoot` | Resolved absolute path the scan started from |
| `generatedAtUtc` | When this map was generated |
| `stats` | `artistCount`/`releaseCount`/`trackCount`/`unrecognizedCount`/`errorCount` — read this before loading the full map, to sanity-check it looks complete |
| `artists[]` | The recognized library content |
| `unrecognized[]` | Folders legacy's heuristics couldn't confidently classify (same concept as legacy's own `unrecognized[]`) |
| `errors[]` | `{ path, phase, message }` — `phase` is `walk-isolation` (a whole top-level folder's recognition call threw) or `accessibility` (a path was inaccessible, e.g. a permission error) |

## `artists[]`

Same as legacy: `recognizedName`, `sourcePaths[]`, `releases[]`.

## `releases[]`

Same fields as legacy's `release` def: `stableKey`, `recognizedTitle`,
`recognizedYear`, `recognizedReleaseDate`, `recognizedReleaseType`,
`editionFolderName`, `sourceFolderPath`, `discFolderCount`, `tracks[]`,
`companionFiles[]`, `ignoredFiles[]`, `cueSheets[]`, `recognitionConfidence`,
`recognitionFlags[]`, `needsReview`, `reviewReasons[]`.

`needsReview`/`reviewReasons` matter for matching: a release legacy's own
heuristics were unsure about is exactly the kind of signal worth weighing
before trusting a before/after match (see
[`03-matching-and-verification-procedure.md`](03-matching-and-verification-procedure.md)).

## `tracks[]`

Same as legacy's `track` def, **except**: `existingCoverArtPath` (a
machine-local cache file path, not portable or comparable across two maps) is
replaced with `embeddedCoverSha256` — the SHA-256 hash of the embedded cover's
bytes, read straight off the cache filename (legacy already names cached
covers by their own content hash). `null` means no embedded cover was found on
that track.

## `companionFiles[]` / `ignoredFiles[]` / `cueSheets[]` / `unrecognized[]`

Unchanged from legacy's schema — same fields, same meaning.
