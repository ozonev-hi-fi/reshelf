# 08 — Settings, naming templates, reference data

Status: Draft | Version: 0.5 | Last updated: 2026-11-04

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
Priority: Must | Status: Draft | Source: D31, D40, D57, D76

The output path below the target root comes from **one path template made of levels**. Each level is one name template. The last level is the track file name; the level above it is the release folder. The user can add, remove and reorder levels. Only the target root is fixed (NG-PTH-003).

| Level | Default |
|---|---|
| 1 | `{artist}` |
| 2 (release folder) | `{year} {album}` |
| 3 (track file) | `{trackNumber} {title}` |

The stored template is a list of levels and holds no OS separator. The app joins the levels with the separator of the current OS; the UI shows that separator between the levels.

Example:
```
Stored:   ["{artist}", "{year} {album}", "{trackNumber} {title}"]
Windows:  Kyuss\1994 Welcome to Sky Valley\01 Gardenia.flac
A user's own layout, 4 levels:
          ["{artist}", "{year} - {album}", "CD{disc}", "Track_{discTrack}"]
          → Kyuss\1994 - Welcome to Sky Valley\CD1\Track_01.flac
```

Other templates:

| Template | Default |
|---|---|
| Keep-both release folder (NG-LIB-010) | release-folder level + ` [{quality}]` → `{year} {album} [{quality}]` |
| Replacement release folder (NG-PTH-009) | release-folder level + ` [replacement]` → `{year} {album} [replacement]` |
| Loose companion file rename | starts with a letter (MANIFESTO §4.5); exact default set in the tech spec |

### NG-CFG-004 — Placeholders
Priority: Must | Status: Draft | Source: D40, D77

Templates use placeholders. Placeholders are reference data (NG-CFG-009); how new ones are added is in NG-CFG-014. The minimum set:

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
- no empty level (D76);
- no invalid file-name characters in any level;
- path length within limits;
- no two tracks end up with the same file name.

An invalid template cannot be saved.

### NG-CFG-006 — MANIFESTO naming as defaults; tag rules fixed in v1
Priority: Must | Status: Draft | Source: D40, D80

The naming rules of MANIFESTO §4 become the **default templates**. They are no longer hard-coded. In v1 the tag rules of MANIFESTO §5 are built in and always on:
- Disc is always set;
- Track restarts on each disc;
- Artist = Album Artist (except compilations);
- feat. artists appear only in the title;
- Year and Album are required.

Each rule is a separate unit, so a later version can make them configurable (NG-CFG-015). The embedded-cover size is a setting, not a tag rule (NG-CFG-002).

### NG-CFG-015 — User-configurable tag rules (later)
Priority: Could | Status: Draft | Source: D80 | Depends on: NG-CFG-006, NG-CFG-009

A later version makes the tag rules reference data. The user can turn a built-in rule off, change it, or add their own rule.

Example: a user rule "Album Artist of a compilation = `Various Artists`"; the user turns off "Disc is always set" for single-disc releases.

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
- review reason codes with severity (NG-REV-002);
- template placeholders (NG-CFG-004, NG-CFG-014) and their dictionaries.

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

Example: legacy's hard-coded extension list (`legacy/scripts/common/Reshelf.Common.psm1:3`) does not include `.wv`, so a release folder holding only `Artist - Album.wv` + `Artist - Album.cue` is invisible to recognize today.

### NG-CFG-014 — New placeholders by data, with optional dictionaries
Priority: Should | Status: Draft | Source: D77 | Depends on: NG-CFG-009, NG-LAY-003

Each placeholder row has:

| Property | Values |
|---|---|
| Kind | **Simple**: copied from one file tag (Recognized) and one response field per provider (Proposed). **Computed**: built-in code. |
| Value type | Text, Number, or **Dictionary** |
| Used in | path levels, tags |

- A new **Simple** placeholder needs only a new row, no code change. It also adds an editable field to all three layers (NG-LAY-001), so the user can override it.
- A **Dictionary** placeholder stores the ID of an entry in its dictionary (for example a Genres list), not the text. On Save:
  - a value equal to an entry after normalization (case, spaces) reuses that entry;
  - a similar value asks "Did you mean …?" — the app never merges silently;
  - a new value creates a new entry.
- `{genre}` is **not** part of v1. It is the reference example of this mechanism.

Example:
```
Placeholder   Kind      Value type   File tag   Discogs field
{trackNumber} Computed  Number       —          —            → "01"
{genre}       Simple    Dictionary   GENRE      styles[0]    → ID 17 = "Stoner Rock"
User types "stoner  rock"  → entry 17 reused
User types "Stoner Roc"    → "Did you mean Stoner Rock? [Use it] [Create 'Stoner Roc']"
```

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-04 | Initial version (Docs part A). |
| 0.2 | 2026-10-04 | Docs part B: "Paths" row, replacement release folder template. |
| 0.3 | 2026-10-07 | NG-CFG-013: WavPack (`.wv`) as a built-in audio format (D65). |
| 0.4 | 2026-11-03 | Consistency review: NG-CFG-001 source D13 (picture sections) → D18 (CLI scope, includes settings). |
| 0.5 | 2026-11-04 | Phase 4, area GEN (D76): NG-CFG-003 — one path template made of levels, stored without OS separators; keep-both and replacement folders defined as suffixes of the release-folder level. NG-CFG-005 — no empty level. D77: NG-CFG-004 and NG-CFG-009 — placeholders are reference data; new NG-CFG-014 (new placeholders by data, with optional dictionaries). D80: NG-CFG-006 — tag rules fixed in v1, each a separate unit; new NG-CFG-015 (user-configurable tag rules, Could). D81: NG-CFG-013 example uses neutral names. |
