# Generating a library map

## Prerequisites

- PowerShell 7.4+.
- A `TagLibSharp.dll`, same as legacy needs. If you already have one set up for
  legacy (`legacy/config/settings.json`'s `taglibSharpPath`), you can reuse
  that path, or let this tool cache its own copy under
  `local/.data/<label>/lib/TagLibSharp.dll` by placing a copy there before
  running.
- (Optional, for the matching/verification step later, not for this step) a
  Discogs personal access token in the same environment variable legacy uses
  (`DISCOGS_ACCESS_TOKEN` by default — see `discogsTokenEnvVar` in
  `config/settings.default.json`).

## One-time setup

Create `tools/library-mapper/config/settings.local.json` (gitignored already
by the repo's `*.local.json` rule) with your real paths:

```json
{
  "beforeRoot": "D:\\Path\\To\\Your\\Not-Organized\\Copy",
  "afterRoot": "D:\\Path\\To\\Your\\Organized\\Library",
  "taglibSharpPath": "C:\\Path\\To\\TagLibSharp.dll"
}
```

All fields are optional — you can always pass `-LibraryRoot` and
`-TagLibSharpPath` directly on the command line instead.

## Running it

```powershell
cd tools/library-mapper/scripts
./New-ReshelfLibraryMap.ps1 -Label before
./New-ReshelfLibraryMap.ps1 -Label after
```

This writes:

- `local/maps/before.library-map.json`, `local/maps/after.library-map.json`
  (or whatever path `-OutputPath` points at)
- `local/.data/<label>/` — session artifacts and the embedded-cover cache for
  that run, isolated from legacy's own `.data/` so this tool can never touch
  legacy's real cache

Pass `-Force` to overwrite an existing output file. Re-run per label any time
your library changes — each run re-walks the whole label from scratch (there's
no incremental/resumable scan).

If `-LibraryRoot` mixes real music folders with unrelated ones — e.g. a phone
storage root, with its default Android folders (`DCIM`, `Download`, `Android`,
`Movies`, `Notifications`, `Ringtones`, `Pictures`, `Podcasts`, ...) sitting
next to your actual collection — pass `-ExcludeTopLevelName` with the
top-level folder names to skip. They're never walked, never recognized, and
never even listed for the accessibility check, so they don't cost scan time
or show up as noise in the map:

```powershell
./New-ReshelfLibraryMap.ps1 -LibraryRoot 'F:\' -Label before `
    -ExcludeTopLevelName 'DCIM','Download','Android','Movies','Notifications','Ringtones'
```

Prefer moving your real collection into its own subfolder first (so
`-LibraryRoot` only ever contains music) when that's practical — simpler than
maintaining an exclude list across re-runs.

## What it does, in short

For each top-level folder directly under `-LibraryRoot` (normally one per
artist), it calls legacy's own `Invoke-ReshelfRecognition` — the same
heuristics, tag reading, and companion-file classification legacy itself uses
— and merges the results into one combined map. One bad/corrupt file only
takes down the one top-level folder it's in for that run; the rest of the
library still gets mapped. A file sitting loose directly under `-LibraryRoot`,
not inside any folder, is not captured — only works on a library organized
into top-level folders (artists, or similar).

See [`01-map-schema-reference.md`](01-map-schema-reference.md) for what ends
up in the output, and [`03-matching-and-verification-procedure.md`](03-matching-and-verification-procedure.md)
for what to do with two generated maps.
