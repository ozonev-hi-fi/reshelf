# 08 — Settings, naming templates, reference data

Status: Draft | Version: 0.4 | Last updated: 2026-11-03

## Today vs next-gen

| Topic | Today (legacy) | Next-gen |
|---|---|---|
| Settings | `settings.json`, edited through the CLI (`settings set` reaches only simple keys) | Settings UI page + CLI, stored in the DB |
| Cover size | `coverMaxDimension` setting (600) | Same setting, edited in the UI. Never retroactive. |
| Templates | `releaseFolder` `{year} {album}`, `trackFile` `{trackNumber} {title}`. The artist folder is hard-coded. | Every output name comes from a template, with preview and validation |
| Paths | `defaultSourceRoot` and one absolute `targetRoot` | Default source, target and temp, stored as locations. Defined in NG-PTH-003. |
| Formats and lists | Hard-coded in the PowerShell modules (for example the audio extensions in `Reshelf.Common.psm1:3`) | Reference data in the DB, seeded on startup, editable |

## Settings

### NG-CFG-001 — Settings page
Priority: Must | Status: Draft | Source: RAW, D18

All settings can be viewed and changed on a Settings page in the UI. The CLI can also change them (NG-APP-005).

### NG-CFG-002 — Cover max dimension
Priority: Must | Status: Draft | Source: D13

The maximum size of the embedded cover (longest side, default 600 px) is a setting. Apply resizes covers to this value.

### NG-CFG-007 — Settings are never retroactive
Priority: Must | Status: Draft | Source: D27, D13

- Releases that are **not yet applied** always use the current settings. The review page shows the effective value.
- **Applied** releases are never changed again because a setting changed.

Example: you change the cover size from 600 to 800. Releases you apply after the change get 800 px covers. The library is not touched.

## Naming templates

### NG-CFG-003 — Every output name is a template
Priority: Must | Status: Draft | Source: D31, D40, D57

These names come from configurable templates:

| Template | Default |
|---|---|
| Artist folder | `{artist}` |
| Release folder | `{year} {album}` |
| Track file | `{trackNumber} {title}` |
| Keep-both release folder (NG-LIB-010) | `{year} {album} [{quality}]` |
| Replacement release folder (NG-PTH-009) | `{year} {album} [replacement]` |
| Loose companion file rename | starts with a letter (MANIFESTO §4.5); exact default set in the tech spec |

### NG-CFG-004 — Placeholders
Priority: Must | Status: Draft | Source: D40

Templates use placeholders. The minimum set:

| Placeholder | Meaning |
|---|---|
| `{artist}` | Album Artist |
| `{album}` | Album |
| `{year}` | Year |
| `{disc}` | Disc number |
| `{discTrack}` | Track number on its disc |
| `{trackNumber}` | Track number counted across all discs (MANIFESTO §4.4), padded |
| `{title}` | Track title |
| `{quality}` | Quality label, for example `FLAC 24-96`, `MP3 320` |
| `{edition}` | Edition or pressing text, when known |

The full list is defined in the tech spec.

### NG-CFG-005 — Live preview and validation
Priority: Must | Status: Draft | Source: D40

The template editor shows a live preview on a sample release. It validates the result:
- no invalid file-name characters;
- path length within limits;
- no two tracks end up with the same file name.

An invalid template cannot be saved.

### NG-CFG-006 — MANIFESTO naming as defaults; tag rules stay fixed
Priority: Must | Status: Draft | Source: D40

The naming rules of MANIFESTO §4 become the **default templates**. They are no longer hard-coded. The tag rules of MANIFESTO §5 stay fixed:
- Disc is always set;
- Track restarts on each disc;
- Artist = Album Artist (except compilations);
- feat. artists appear only in the title;
- Year and Album are required.

### NG-CFG-008 — Provider-ID tag setting
Priority: Should | Status: Draft | Source: D45

A setting "Write provider IDs to tags" (default: on) controls NG-PRV-011.

## Reference data

### NG-CFG-009 — Reference data lives in the DB
Priority: Must | Status: Draft | Source: RAW, D19

These lists are DB rows, not code:
- audio formats (extension, codec family);
- companion-file kinds (cover, booklet, photo, lyrics, ...);
- ignored extensions (playlists, ...);
- category folder names (`EPs`, `Singles`, `Lives`, ...);
- review reason codes with severity (NG-REV-002).

Lossy vs lossless is decided from the codec (NG-LIB-006), not from this list.

### NG-CFG-010 — Built-in rows are seeded on startup, with confirmation
Priority: Must | Status: Draft | Source: RAW, D19, D33

The app ships built-in rows with stable keys. On every startup it compares them with the DB. When a new app version brings changes (for example a new format `.opus`), the app shows "these reference-data changes will be applied" and waits for the user's confirmation. After confirmation it **upserts** the rows.

### NG-CFG-011 — Built-in rows can be disabled, not deleted
Priority: Must | Status: Draft | Source: D19

The user can disable a built-in row. The user cannot delete it.

### NG-CFG-012 — User rows, edited as a draft
Priority: Must | Status: Draft | Source: D19, D33

On the Reference data page the user can add their own rows, for example the category folder `Studio Albums`. Edits are a draft until the user presses Save. Cancel drops the draft. App updates never change user rows.

### NG-CFG-013 — WavPack (.wv) is a built-in audio format
Priority: Should | Status: Draft | Source: D65

The built-in audio-formats reference data (NG-CFG-009) includes WavPack (`.wv`), in addition to the legacy set. A single `.wv` file with a matching `.cue` sheet is recognized as a release, the same as `.flac` + cue or `.ape` + cue (NG-LAY-005).

Example: legacy's hard-coded extension list (`legacy/scripts/common/Reshelf.Common.psm1:3`) does not include `.wv`, so a release folder holding only `35007 - Liquid.wv` + `.cue` is invisible to recognize today.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-04 | Initial version (Docs part A). |
| 0.2 | 2026-10-04 | Docs part B: "Paths" row, replacement release folder template. |
| 0.3 | 2026-10-07 | NG-CFG-013: WavPack (`.wv`) as a built-in audio format (D65). |
| 0.4 | 2026-11-03 | Consistency review: NG-CFG-001 source D13 (picture sections) → D18 (CLI scope, includes settings). |
