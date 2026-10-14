# Step 5 — Recognition Module

> **Superseded (2026-10-02):** the `overrides.json` mechanism described throughout this file was
> removed. A grouping folder is now always auto-walked (each subfolder becomes its own artist,
> every release found this way flagged `needsReview` with reason `grouping-folder-auto-resolved`)
> instead of needing a human-authored override to resolve it. A folder recognition still can't
> classify goes to `unrecognized[]` with no override escape hatch — fix it by moving/renaming the
> folder on disk and re-running `recognize`. A new heuristic, `Test-IsAlbumWrapperFolder`, was also
> added for a `yyyy - Title` folder that wraps one or more edition/pressing subfolders instead of
> holding tracks directly (see README's "Reference: automatic folder recognition").

## Purpose / scope

Walk a source folder tree, recognize main artists / releases / tracks /
companion materials using the visual-cue heuristics from manifesto §2, and
produce `recognition.json`. Matches manifesto §7 module 2.

## Inputs / outputs

- Input: `sourceRoot` (from [04](04-settings-module.md)), an optional
  human-edited `overrides.json` for this source root.
- Output: `recognition.json` (schema in [03](03-domain-model-and-json-schemas.md)),
  validated before being written.

## Detailed design

### Entry point

`Invoke-Recognition.ps1 -SourceRoot <path> -SessionId <id>`, implemented via
`Reshelf.Recognition.psm1`.

### Heuristic functions

- `Test-IsReleaseFolder` — folder looks like `yyyy Name` or `Name`, and
  directly contains audio files with sequential-looking numbering.
- `Test-IsGroupingFolder` — folder contains only subfolders, none of which
  look like releases themselves, and those subfolders each look like distinct
  artist names (e.g. "Godspeeds and their projects" containing "Godspeed You!
  Black Emperor", "Silver Mountain Zion").
- `Test-IsCategorySubfolder` — folder name matches a configurable list
  (`EPs`, `Singles`, `Lives`, `Live`, `Compilations`, `Bootlegs`, ...) and its
  children are releases belonging to the *parent* artist, not to itself.
- `Test-IsBandMemberFolder` — a subfolder inside an artist folder that itself
  contains release-shaped children, but whose name doesn't match the parent
  artist (e.g. `David Byrne` inside `Talking Heads`) — this is actually a
  second, separate main artist nested for historical/organizational reasons.

### The rule: only genuinely ambiguous cases go to a human

Grouping folders, band-member folders, and category subfolders are exactly
the patterns manifesto §1 calls out as real, recurring chaos, but as
implemented (checked 2026-09-26) only grouping folders are actually
ambiguous enough to need a human decision:

- **Category subfolder** (`Test-IsCategorySubfolder`) and **band-member
  folder** (`Test-IsBandMemberFolder`) are resolved automatically, with no
  review flag: a category subfolder's releases are attached to the parent
  artist, and a band-member folder gets its own top-level artist bucket. Both
  patterns are structurally unambiguous once detected — there's no second
  plausible reading of "EPs" under an artist folder, or of a folder that
  itself contains release-shaped children nested one level inside another
  artist. `overrides.json` can still override the *name* used (a
  `parentArtistName` for a category override, an `artistName` for a
  band-member override) if the folder name alone guesses wrong, but no
  override is required to resolve the folder itself.
- **Grouping folder** (`Test-IsGroupingFolder`) is the one pattern that stays
  genuinely ambiguous — "does this folder contain several different artists,
  or is it itself one artist's odd folder name?" isn't answerable from
  structure alone. It goes into `unrecognized[]` with reason
  `grouping-folder-suspected` and `children` listing what's inside, unless a
  human-editable `overrides.json` entry (one per source root, stored next to
  that source root's session data, reusable across re-runs of the same
  source) already resolves it: `{"kind": "grouping"}` tells Recognition
  "treat each child as its own artist". Recognition reads `overrides.json`
  **before** applying heuristics, so a resolved override short-circuits the
  ambiguity on every subsequent run.
- This is the concrete hook for the manifesto's "AI skill" idea (§8): an AI
  skill's job is to help a human populate `overrides.json`'s grouping-folder
  entries faster (e.g. by looking at a folder tree and suggesting entries) —
  not to change Recognition's code or bypass the human-review gate.

### Deterministic cleanups added against real data (plan/12 milestone 3)

Two more folder-name patterns turned out to be resolvable without a human
guess, once seen against the user's real collection — added alongside the
genuinely-ambiguous cases above, not instead of them:

- **A release folder that repeats its own artist folder's name**
  (`Remove-ReshelfArtistNamePrefixFromTitle`), e.g. artist folder "Dance with
  the dead" containing a release folder "DANCE WITH THE DEAD - Blackout".
  Confirmed directly against the real Discogs API: a search whose
  `release_title` still contains the artist name returns zero results even
  for a release that demonstrably exists. The prefix (case-insensitive,
  requiring a `-`/`:`/en-dash/em-dash separator after it) is stripped and
  `recognitionFlags` gets `artist-name-prefix-stripped` — not a review flag,
  since it's a deterministic string match against an artist name Recognition
  already resolved, not a guess.
- **A `release-without-artist-suspected` folder whose tracks agree on their
  own tags** (`Resolve-ReshelfArtistAlbumFromTags`), e.g. "edbl" — tracks
  sitting directly in a folder with no artist wrapper and no `" - "` in the
  folder's own name. Previously always unrecognized, even though the tracks
  themselves already carry the answer. Promoted into a normal release
  (`reviewReasons: ["artist-and-album-from-tags"]`, still `needsReview` —
  unlike the prefix-strip above, this one *is* still flagged, since the
  folder's own name gave no confirmation) only when every track's
  artist/album tags agree; a folder with missing or disagreeing tags still
  goes to `unrecognized[]` as before.

### Track/disc parsing

- Track number + name: ordered regex fallbacks, most specific first:
  1. `^(\d+)\s*[-–]\s*(.+)$` (`"01 - Track Name"`)
  2. `^(\d+)\s+(.+)$` (`"01 Track Name"`, no separator)
  3. no number found → fall back to alphabetical filename order within the
     folder, set `inferredTrackOrder: true` and add flag
     `"no-track-number"` — never blocks recognition, but is visible
     downstream.
- Disc folder detection: `^(CD|Disc|Disk|LP)\s*#?\.?\s*(\d+)$` (case-insensitive).
  Track numbers from files inside disc folders are combined and
  renumbered continuously across discs per manifesto §4.4 when building
  `proposedFileName` in [06](06-edit-proposal-module.md) — Recognition itself
  just records `discFolder` and `detectedTrackNumberInDisc` per track, it
  doesn't compute the final continuous numbering (that's a proposal-step
  concern since it depends on final disc ordering).

### Single-file + cue detection

A release folder containing exactly one audio file and one `.cue` file (or a
per-disc pair inside `CD N` subfolders) is recorded as `cueSheet: {
cueFilePath, audioFilePath }`. Track splitting itself happens in
[08-implementation-module.md](08-implementation-module.md); Recognition only
detects and records the pattern, and does not read the tracks inside it as
separate `tracks[]` entries (there's nothing to enumerate yet — track names
come from the cue sheet content, parsed here into virtual track entries with
`sourceFilePath` pointing at the shared audio file plus a `cueTimestamp` for
later splitting).

### Companion file classification

By extension + filename keywords:

- Images (`.jpg`, `.png`, ...) → `kind: "cover"` unless filename suggests
  otherwise (`booklet`, `back`, `insert` → `kind: "scan"`).
- `.txt`, `.pdf`, `.nfo` with keywords like `lyrics`, `article`, `interview` →
  `kind: "text"`.
- `.m3u`, `.m3u8`, `.pls` → routed to an `ignored` bucket with
  `reason: "playlist-file"` — never copied, per manifesto §4.4 ("No playlist
  files are allowed").
- `placement` recorded as `"loose"` (directly in the release folder) or
  `"nested"` (in a subfolder), matching manifesto §4.5's two allowed
  placements.

### Reading existing tags

**Recommendation (flagged as a deviation from the user's mp3tag decision —
please confirm):** use **TagLibSharp** (a mature, MIT-licensed .NET library,
loaded via `Add-Type` in PowerShell 7) to read existing tags here, rather than
mp3tag. Reason: mp3tag has no clean scriptable "dump all tags as JSON" mode —
its CLI/Action strength is *writing*, which is exactly what it's used for in
[08](08-implementation-module.md). TagLibSharp gives direct, structured
programmatic read access across flac/mp3/alac without shelling out or
parsing GUI-oriented output.

### Output

Validated against `schemas/recognition.schema.json` via `Test-Json` before
being written to disk.

## Decisions & rationale

- **Never auto-resolve ambiguous folder types**: a wrong guess here (e.g.
  treating "Godspeeds and their projects" as one artist) corrupts the target
  structure at the root — Level 1 folders are supposed to be real main
  artists (manifesto §4.2). A human decision, recorded once in
  `overrides.json`, is cheap and permanent; a wrong heuristic is expensive to
  discover and fix later.
- **`overrides.json` per source root, not global**: the same folder name
  ("Live") can mean different things in different parts of a messy
  collection; scoping overrides to the source root avoids one correct
  decision silently misapplying elsewhere.

## Edge cases

- Empty release folder (no audio files) → `unrecognized[]` with
  `reason: "no-audio-files"`.
- Nested releases-within-releases (rare but possible in a messy collection,
  e.g. a "Best Of" folder containing what look like two sub-albums) →
  flagged `needsReview` rather than picking one interpretation.
- See [10-error-handling-and-edge-cases.md](10-error-handling-and-edge-cases.md)
  for path-length and invalid-character handling, which apply to source paths
  too (a source path can already be near the limit).

## Manual setup

None beyond having TagLibSharp available (NuGet package, referenced via
`Add-Type -Path`).

## Definition of done

- Running against [11](11-testing-and-verification-strategy.md)'s fixture
  source tree produces a `recognition.json` that correctly identifies every
  planted pattern (normal album, multi-disc, cue+single-file, grouping
  folder, category subfolder, band-member folder, missing track numbers,
  loose vs. nested companions, a playlist file correctly routed to
  `ignored`).
- An `overrides.json` entry demonstrably changes the outcome for a
  grouping-folder case on a second run.
