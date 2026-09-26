# Tagger — Personal Music Collection Organizer

Tagger reorganizes a messy pile of music folders into a clean, consistent structure, one release
at a time, using [Discogs](https://www.discogs.com) as the source of truth for names, tags and
cover art.

Target layout:

```
<targetRoot>\
  <Artist>\
    <yyyy Album>\
      01 Track Name.flac
      02 Track Name.flac
      ...
```

Metadata rules the tool enforces:
- `Artist` and `Album Artist` tags are always identical (the artist folder name).
- `Disc` is always set, even for a single-disc release. `Track` restarts at 1 on each disc.
- Featured artists appear only in the track title, never in `Artist`/`Album Artist`.
- The embedded cover is resized to at most 600 px on the longest side.
- Year and Album tags always match the release folder name (`yyyy Album`).

See [MANIFESTO.md](MANIFESTO.md) for the full rationale, and [plan/](plan/) for the design of each
module.

## Pipeline

```
source folder
     |
     v
[recognize]  scans the source, groups files into artists/releases -> recognition.json
     |
     v
[propose]    looks up each release on Discogs, proposes new names/tags/cover -> proposal.json
     |
     v
[ui start]   review/edit the proposal in a browser, save changes
     |
     v
[apply]      copies/moves files into the target folder, writes tags, embeds cover
```

All commands below are run from the repo root with PowerShell 7:

```powershell
pwsh scripts/Tagger.ps1 <command> ...
```

## Requirements

- **Windows** — the Discogs token is encrypted with Windows DPAPI, tied to your Windows user
  account and machine.
- **PowerShell 7.4 or newer** (`pwsh`).
- **ffmpeg** — used by `apply` to split single-file+cue releases and to resize cover images.
  Install it with `winget install Gyan.FFmpeg`, or point the `ffmpegPath` setting at a full path.
  If `ffmpegPath` is empty, the tool looks for `ffmpeg` on PATH.
- **TagLibSharp.dll** — used to read tags during `recognize` and write tags during `apply`. Get it
  from the `TagLibSharp` NuGet package (e.g. `dotnet add package TagLibSharp` in a throwaway
  project, then copy `TagLibSharp.dll` from its `lib/netstandard2.0` folder). Put it at
  `.data\lib\TagLibSharp.dll` (the default location), or point the `taglibSharpPath` setting at it.
- **A Discogs account** to generate a Personal Access Token.
- **Any modern browser** for the review UI (plain `fetch()`, no special browser API needed).

## One-time setup

1. Clone the repo and open a PowerShell 7 terminal in it.
2. Install ffmpeg and place `TagLibSharp.dll` (see Requirements above).
3. Create a Discogs Personal Access Token:
   - Log into [discogs.com](https://www.discogs.com).
   - Go to **Settings → Developers → Generate new token**.
   - Copy the token. You won't need an OAuth app — this is a single-user tool.
4. Run first-time setup:
   ```powershell
   pwsh scripts/Tagger.ps1 settings init
   ```
   It prompts for:
   - **Target root** (where organized music will be written) — required.
   - **Default source root** (optional, press Enter to skip) — a folder `recognize` will use when
     you don't pass `-SourceRoot`.
   - **Copy mode: copy or move** (default: `copy`) — `copy` leaves your source files in place;
     `move` deletes them from the source once a release is applied.
   - **Discogs Personal Access Token** (press Enter to skip, set later) — typed hidden, stored
     encrypted.

   `settings init` checks that the target root is writable before saving anything.
5. If you skipped the token, store it now:
   ```powershell
   pwsh scripts/Tagger.ps1 settings set-token
   ```
   The token lookup order is: the `DISCOGS_ACCESS_TOKEN` environment variable → a `.env` file at
   the repo root (`DISCOGS_ACCESS_TOKEN=...`) → the encrypted value in `settings.json` set by
   `set-token`/`init`.
6. Check everything looks right:
   ```powershell
   pwsh scripts/Tagger.ps1 settings show
   ```

> Note: if `settings.json` doesn't exist yet, the first `recognize`/`propose`/`apply`/`ui start`
> command runs `settings init` for you automatically.

## Step-by-step: organizing a folder

### 1. Recognize

```powershell
pwsh scripts/Tagger.ps1 recognize -SourceRoot "D:\MusicToOrganize\Indie" -SaveAsDefault
```

- `-SourceRoot` — the folder to scan. If omitted, the configured `defaultSourceRoot` is used.
- `-SaveAsDefault` — also saves this path as `defaultSourceRoot` for next time.
- `-OverridesPath <file>` — optional; see [Overrides file](#reference-overrides-file) below.

This creates a new session and writes `recognition.json`. Sample output:

```
SessionId         : 2026-09-25-0007
ArtistCount       : 42
ReleaseCount      : 118
UnrecognizedCount : 3
```

`UnrecognizedCount` lists folders the tool couldn't confidently turn into a release — e.g. a
"grouping" folder holding several sub-artists, or a release folder sitting directly at the source
root with no artist folder around it. If this is non-zero, check `recognition.json`'s
`unrecognized[]` array, and consider writing an [overrides file](#reference-overrides-file) to fix
it, then re-run `recognize`.

### 2. Propose

```powershell
pwsh scripts/Tagger.ps1 propose -SessionId 2026-09-25-0007
```

This looks up every release on Discogs, proposes new folder/file names, tags and cover art, and
writes `proposal.json`. Sample output:

```
SessionId        : 2026-09-25-0007
ArtistCount      : 42
ReleaseCount     : 118
MatchedCount     : 103
NeedsReviewCount : 15
```

- `MatchedCount` — releases confidently matched on Discogs.
- `NeedsReviewCount` — releases flagged for a human look: ambiguous or missing Discogs matches,
  an unresolved year, a tracklist mismatch, and other cases described under
  [Review in the browser](#3-review-in-the-browser).
- Discogs requests are rate-limited (default 55/minute) and cached (`cacheTtlDays`, default 30
  days), so a large run can pause for up to about a minute at a time on the first pass, but a
  re-run of the same source is fast. This is a **re-run cache**, not an archive: it exists for
  retrying after a failed `propose` and for repeated `propose` runs while you tune
  `overrides.json` (see [Reference: overrides file](#reference-overrides-file)), not for looking
  up the same release again months later — a release you've already organized is never queried
  again. An entry older than `cacheTtlDays`, or one that fails to parse, is physically deleted the
  next time `propose` runs (checked once per run), so the cache folder doesn't grow without bound.

> ⚠️ Re-running `propose` on the same session **overwrites** `proposal.json`, discarding any edits
> you made in the review UI. Only re-run it if you haven't reviewed yet, or you're OK losing the
> edits.

### 3. Review in the browser

```powershell
pwsh scripts/Tagger.ps1 ui start
```

Opens `http://localhost:4173/` in your default browser (use `-Port <N>` for a different port). The
page automatically loads the most recently updated session that has a `proposal.json` — there's no
file picker.

What you'll see, top to bottom:

- **Filters** — `Needs review only`, `Ambiguous match only`.
- **Release list** — grouped by artist, each release tagged with a badge:
  - `rejected` — you've ticked Reject.
  - `ambiguous` — Discogs match is ambiguous, not yet resolved.
  - `needsReview` — flagged for review, not yet resolved.
  - `ready` — everything else (including releases nobody flagged — see note below).
- **Before / After table** — read-only, shows the source path and every track's proposed rename.
- **Release fields** — `Artist / Album Artist` (one combined field), `Album`, `Year`, `Release
  Folder Name`. Note: the folder name field does **not** update automatically when you edit Album
  or Year — edit it yourself if needed.
- **Track table** — `Disc`, `Track`, `Title` per track. Editing Title renames the proposed file
  (keeping the `NN ` prefix). Editing Disc/Track numbers does not change the file name prefix.
- **Other files** — companion files (covers, booklets, photos, lyrics). Loose files (directly in
  the release folder) can be renamed and must start with a letter; nested files (in a subfolder)
  can only be included/excluded. Ignored files (playlists, unused `.cue` files) are shown greyed
  out with the reason.
- **Cover gallery** — pick one candidate with a radio button. `Add cover from file…` uploads your
  own JPG/PNG (max 20 MB) and adds it to the gallery.
- **Discogs edition picker** (only shown when the match is ambiguous) — picking an edition here
  only records your choice; it does **not** re-fetch tags/tracklist/cover. Fix the Artist/Album/
  Year/tracks fields yourself, then continue.
- **Notes** — pre-filled with the reasons this release was flagged.
- **Approve** / **Reject** — mutually exclusive checkboxes. Approve marks the release reviewed and
  ready for `apply`. Reject means "never apply this" (e.g. a duplicate pressing you don't want).
- **Save** (top and bottom of the panel) — no auto-save. Saves the whole session's changes to
  `proposal.json` (a `proposal.backup.json` copy of the previous version is kept).

> Releases that `propose` did **not** flag are already marked reviewed — you don't need to tick
> Approve on them. A flagged release is only applied once you tick Approve.

> ⚠️ Never leave **Year** empty, or leave it at the placeholder value **1900**. An empty Year fails
> validation and blocks the *entire* `apply` run, not just that one release; 1900 means the year
> still needs fixing.

### 4. Mark reviewed (optional)

```powershell
pwsh scripts/Tagger.ps1 session mark-reviewed 2026-09-25-0007
```

This only updates the session's stage (for your own bookkeeping and the `session resume` hint).
`apply` does not require it and does not check the stage.

### 5. Apply

Dry-run first to see what would happen, with no files touched:

```powershell
pwsh scripts/Tagger.ps1 apply -SessionId 2026-09-25-0007 -WhatIf
```

Then for real:

```powershell
pwsh scripts/Tagger.ps1 apply -SessionId 2026-09-25-0007
```

- `-IncludeUnresolved` — also applies releases nobody reviewed (rejected releases are still never
  applied).

For each approved release, `apply`:
1. Stages files under `<targetRoot>\.tagger-staging\<stableKey>\`.
2. Splits single-file+cue releases with ffmpeg (no re-encoding), or copies tracks as-is.
3. Downloads/reads the chosen cover, resizes it to `coverMaxDimension` (600 px default) with
   ffmpeg.
4. Writes tags (Artist, Album Artist, Album, Year, Disc, Track, Title) and embeds the cover with
   TagLibSharp.
5. Copies included companion files.
6. Moves the staged folder into `<targetRoot>\<Artist>\<yyyy Album>\`.

> ⚠️ If a folder already exists at that target path, it is **deleted and replaced**.

Source files are always read-only to Tagger: apply never deletes or modifies anything under your
source root, including single-file+cue sources after a successful split. There used to be a
"move" copy mode that deleted source files after applying - it was removed after an incident
destroyed source releases with no other backup, so `copy` is now the only copy mode.

Sample output:

```
SessionId : 2026-09-25-0007
Applied   : 96
Skipped   : 7
Rejected  : 4
Failed    : 0
```

- **Applied** — copied/moved and tagged successfully.
- **Skipped** — not yet reviewed (and `-IncludeUnresolved` wasn't passed), or already applied from
  an earlier run with unchanged source files.
- **Rejected** — you ticked Reject.
- **Failed** — something went wrong; see [Troubleshooting](#troubleshooting--known-limitations).

### 6. Check the result

Look at `<targetRoot>` for the organized folders. If any lossy (e.g. mp3) releases were found,
check the lossy-tracking ledger:

```powershell
pwsh scripts/Tagger.ps1 lossy list
```

See [Lossy/lossless tracking](#reference-lossylossless-tracking) below.

## Sessions and resuming

Each `recognize` run creates a session that moves through stages:

```
recognized -> proposed -> reviewed -> applied (or partially-applied)
```

- `pwsh scripts/Tagger.ps1 session list` — table of all sessions (id, stage, source root, updated
  time).
- `pwsh scripts/Tagger.ps1 session show <id>` — full session details as JSON.
- `pwsh scripts/Tagger.ps1 session resume <id>` — prints the stage and the suggested next command.
- `pwsh scripts/Tagger.ps1 session mark-reviewed <id>` — see [step 4](#4-mark-reviewed-optional).

Re-running `apply` on the same session is safe: releases already applied (with unchanged source
files) are skipped, and previously failed releases are retried.

> Caveat: if you edit a release in the review UI **after** it was already applied, and its source
> files haven't changed, a re-run of `apply` will skip it — your edit won't reach the target
> folder. Apply once per set of edits.

## Re-runs and duplicates

Every release gets a **stableKey** — a deterministic ID from its normalized artist/album/year —
so the same release is always recognized as "the same" across runs, even from a different source
folder. `propose` compares each release's stableKey against what's already in `targetRoot`:

| targetAction | Meaning |
|---|---|
| `create-new` | No release with this stableKey exists in the target yet. |
| `skip-existing-identical` | Same stableKey, and the source files are identical to what's already there. |
| `update-existing` | Same stableKey, source is fully lossless, and the existing target is (partly) lossy — an upgrade. Not flagged for review. |
| `conflict` | Same stableKey but the files differ and it's not a lossy→lossless upgrade. **Flagged for review** — approving it will replace the existing target folder. |

## Reference: settings

`settings.json` lives in the [data folder](#reference-data-folder). View it with `settings show`;
change simple (non-nested) keys with:

```powershell
pwsh scripts/Tagger.ps1 settings set -Key <key> -Value <value>
```

| Key | Default | Meaning |
|---|---|---|
| `defaultSourceRoot` | `""` | Source folder used by `recognize` when `-SourceRoot` is omitted. |
| `targetRoot` | `""` (required) | Where organized music is written. Checked for write access on `set`/`init`. |
| `copyMode` | `copy` | Always `copy` — `move` was removed; source files are always read-only. |
| `namingTemplates.releaseFolder` | `{year} {album}` | Release folder name pattern. Edit `settings.json` by hand — `settings set` can't reach nested keys. |
| `namingTemplates.trackFile` | `{trackNumber} {title}` | Track file name pattern. Same edit-by-hand caveat. |
| `trackNumberPadWidth` | `2` | Minimum digit width for track filename numbers — a floor, not a fixed value: a release with more tracks than this still gets a wider number (`max(trackNumberPadWidth, digits needed)`). |
| `coverMaxDimension` | `600` | Embedded cover size limit, in pixels (longest side). |
| `discogsTokenEnvVar` | `DISCOGS_ACCESS_TOKEN` | Name of the environment variable (and matching `.env` key) checked for the Discogs token — change this if `DISCOGS_ACCESS_TOKEN` collides with something else on your machine. |
| `discogsTokenEncrypted` | `""` | DPAPI-encrypted token, set by `settings init`/`settings set-token`. |
| `rateLimitPerMinute` | `55` | Self-imposed cap on Discogs requests per minute. |
| `cacheTtlDays` | `30` | How long a cached Discogs response is reused before a fresh lookup — and before it's deleted from disk on the next `propose` run. A re-run cache (see [Discogs requests](#2-propose)), not a permanent archive. |
| `dataHome` | `""` | Derived automatically on every load — don't set this by hand. |
| `ffmpegPath` | `""` | Full path to ffmpeg. Empty = use `ffmpeg` from PATH. |
| `taglibSharpPath` | `""` | Full path to `TagLibSharp.dll`. Empty = `<dataHome>\lib\TagLibSharp.dll`. |

## Reference: overrides file

Recognition automatically handles a few common patterns:
- **Category subfolders** (`EPs`, `Singles`, `Lives`, `Live`, `Compilations`, `Bootlegs`) — their
  releases are folded into the parent artist.
- **Band-member folders** (a subfolder with a different name holding only release folders, no
  loose files) — treated as a separate artist named after the folder.

When those heuristics guess wrong, or a folder can't be classified at all (`recognition.json`'s
`unrecognized[]`, e.g. `grouping-folder-suspected` or `release-without-artist-suspected`), write an
overrides file and pass it with `-OverridesPath`:

```powershell
pwsh scripts/Tagger.ps1 recognize -SourceRoot "D:\MusicToOrganize\Indie" -OverridesPath ".\my-overrides.json"
```

Example (all 5 fields on each entry are required):

```json
{
  "schemaVersion": 1,
  "sourceRoot": "D:\\MusicToOrganize\\Indie",
  "entries": [
    {
      "relativePath": "Godspeeds and their projects",
      "kind": "grouping",
      "parentArtistName": null,
      "artistName": null,
      "notes": "Each subfolder is its own artist."
    },
    {
      "relativePath": "Grimes/Albums",
      "kind": "category",
      "parentArtistName": "Grimes",
      "artistName": null,
      "notes": "Releases here belong to Grimes, not to an artist called 'Albums'."
    },
    {
      "relativePath": "Talking Heads/David Byrne",
      "kind": "band-member",
      "parentArtistName": null,
      "artistName": "David Byrne",
      "notes": "Separate main artist nested for historical reasons."
    }
  ]
}
```

- `relativePath` is relative to the source root (either `/` or `\` works, not case-sensitive).
- `kind` is one of:
  - `grouping` — each direct subfolder becomes its own artist.
  - `category` — this folder's contents belong to `parentArtistName` (or the current artist if
    `null`).
  - `band-member` — treat this folder as a separate artist named `artistName` (or the folder name
    if `null`).
  - `artist` — treat the folder itself as a release credited to `artistName` (for a release folder
    sitting directly at the source root, with no artist folder around it).

Overrides are checked before the automatic heuristics, and re-used on every re-run of `recognize`.

## Reference: lossy/lossless tracking

If a release's source files are lossy (e.g. mp3) instead of lossless (e.g. flac), `propose` logs
it in a ledger so it can be found and upgraded later.

- Statuses: `pending-upgrade`, `upgraded`, `ignored`.
- `pwsh scripts/Tagger.ps1 lossy list [-Status pending-upgrade|upgraded|ignored]`
- `pwsh scripts/Tagger.ps1 lossy ignore <stableKey>` — stop tracking this one.
- `pwsh scripts/Tagger.ps1 lossy mark-upgraded <stableKey>` — mark it upgraded manually (e.g. you
  replaced it outside the tool).

If you later import a fully lossless version of a release that's already in the target as lossy,
`propose` detects it automatically (`targetAction: update-existing`) and `apply` replaces the old
folder and marks the ledger entry `upgraded` for you.

## Reference: data folder

All generated/user data lives in `.data\` inside the repo by default (git-ignored). Override the
location with the `TAGGER_HOME` environment variable.

```
<dataHome>\
  settings.json                        your settings
  lib\TagLibSharp.dll                   default TagLibSharp location
  cache\discogs\<hash>.json             cached Discogs API responses (a re-run cache, pruned of
                                         expired/corrupt entries on the next `propose` run)
  overrides\<hash-of-source-root>.json  default overrides file per source root
  sessions\<yyyy-MM-dd-NNNN>\
    session.json                       stage, source root, timestamps
    recognition.json                   output of `recognize`
    proposal.json / proposal.backup.json  output of `propose`, edited by the UI
    manual-covers\                     covers uploaded through the review UI
  lossy-tracking.json                  library-wide lossy-release ledger
  apply-log.json                       library-wide per-release apply history
```

## Troubleshooting / known limitations

- **A release failed to apply** — read its `errorMessage` in `apply-log.json`, and check
  `<targetRoot>\.tagger-staging\<stableKey>\` for what was staged. Fix the problem and run `apply`
  again; it retries failed releases automatically.
- **Port already in use** — pass `-Port <N>` to `ui start`.
- **Discogs 401 Unauthorized** — your token is missing or invalid; re-run `settings set-token`.
- The `unrecognized[]` list from `recognize` is not shown anywhere in the review UI — check
  `recognition.json`/`proposal.json` directly.
- There's no way to paste a Discogs release URL/ID directly in the UI to force a match.
- The UI has no conflict detection between browser tabs/sessions — the last Save wins.

## For developers

Tests use [Pester](https://pester.dev/) 5+ (Windows ships an older built-in version — install a
newer one first). Run them from the repo root:

```powershell
pwsh tests/Invoke-TaggerTests.ps1
```

`-SkipIntegration` excludes the tests that need a real `TagLibSharp.dll` and `ffmpeg`
(`tests/Tagger.TagLibSharp.Integration.Tests.ps1`). Plain `Invoke-Pester ./tests` also works if
you don't need those two conveniences.

The editing UI (step 07) has its own Playwright suite under `tests/ui`, one-time setup:

```powershell
cd tests/ui
npm install
npx playwright install chromium
```

Then run it either directly (`npx playwright test` from `tests/ui`) or as part of the main test
run:

```powershell
pwsh tests/Invoke-TaggerTests.ps1 -IncludeUi
```

See [plan/11-testing-and-verification-strategy.md](plan/11-testing-and-verification-strategy.md)
for what each spec file covers, and [plan/00-overview.md](plan/00-overview.md) for the
module-by-module design.
