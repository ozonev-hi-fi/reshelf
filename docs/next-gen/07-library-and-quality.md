# 07 — Library, quality comparison, lossy manager

Status: Draft | Version: 0.4 | Last updated: 2026-11-04

## Today vs next-gen

| Topic | Today (legacy) | Next-gen |
|---|---|---|
| Finding a release in the library | Scans `targetRoot/*/*` for folders that match `^\d{4}\s+(.+)$`. It depends on the naming template. | DB index built from tags. Independent of templates and providers. |
| Release key | `stableKey` = SHA-256 of normalized `artist\|album\|year` from **source folder names** | Provider-independent key from tags, with folder names as a fallback |
| Quality | Lossless list by extension (`.flac .wav .ape .alac`). `.m4a` always counts as lossy, even when it holds ALAC (suspected defect). | Detected from codec and stream properties |
| Existing release | `create-new / skip-existing-identical / update-existing / conflict` | Match statuses with user actions (NG-LIB-009) |
| Lossy ledger | `lossy-tracking.json` with **absolute** `targetPath` | Lossy manager screen. Relative paths (NG-PTH-010). |
| Overwrite | Apply deletes the existing library folder, then moves the new one in | The app never deletes in the library. It prepares the new copy in temp (NG-PTH-009). |

## Library index

### NG-LIB-001 — Library index in the DB
Priority: Must | Status: Draft | Source: D44, D32, D54

The app keeps an index of the library in the DB. A "Scan library" action builds it. For each library release the index stores:
- the release key (NG-LIB-002);
- the track count and track durations;
- the audio properties (codec, lossless or lossy, bit depth, sample rate, bitrate);
- the folder location: the root role (target or temp) and the relative path (NG-PTH-010).

The index covers both the target and temp (NG-PTH-010). The library itself is stored as a location (NG-PTH-001), so it is found after a drive-letter change. Apply adds its output to the index at once (NG-PTH-007).

### NG-LIB-002 — Provider-independent release key
Priority: Must | Status: Draft | Source: D44

The release key is built from normalized Album Artist + Album + Year. These values come from the **tags** first and from folder names only as a fallback. The key never depends on provider IDs (NG-PRV-011), and never on the naming templates (NG-CFG-003).

### NG-LIB-003 — Incremental rescan
Priority: Should | Status: Draft | Source: D37 (superseded by D44), D44

Before matching, the app quickly checks the library folders. It rescans only the folders that changed since the last scan (by modified time).

This requirement is not confirmed yet. See [Open points](#open-points).

### NG-LIB-004 — First match after recognize
Priority: Must | Status: Draft | Source: D44

After recognize, every source release is matched against the index by its key. Equal track count and track durations within ±3 s confirm the match. This step uses the DB only, so it is fast.

### NG-LIB-005 — Live check after propose
Priority: Must | Status: Draft | Source: D44, D54

After propose, when the final names are known, the app checks the **real files** of the matched library release and of the proposed target path. It confirms they exist, compares the quality (NG-LIB-007) and sets the match status (NG-LIB-009). It checks the proposed path in the target first, then in temp (NG-PTH-010).

## Quality

### NG-LIB-006 — Quality from codec and stream
Priority: Must | Status: Draft | Source: D19, D29

The app detects lossy vs lossless and the audio characteristics (bit depth, sample rate, bitrate) from the codec and the stream properties, not from the file extension.

Example: an `.m4a` file with ALAC is lossless. An `.m4a` file with AAC is lossy.

### NG-LIB-007 — Comparison order
Priority: Must | Status: Draft | Source: D29, D36

Two copies of a release are compared by their real characteristics, in this order. The first difference decides.
1. Lossless beats lossy.
2. Higher bit depth.
3. Higher sample rate.
4. For lossy copies only: higher bitrate.

| Library | Source | Result |
|---|---|---|
| FLAC 24/48 | FLAC 24/96 | Source is better (rule 3) |
| FLAC 24/44.1 | FLAC 16/96 | Library is better (rule 2: bit depth wins over sample rate) |
| MP3 320 | FLAC 16/44.1 | Source is better (rule 1) |

### NG-LIB-008 — Mixed releases
Priority: Must | Status: Draft | Source: D29

A release whose tracks have different qualities is rated by its **lowest-quality** track.

### NG-LIB-009 — Match statuses and actions
Priority: Must | Status: Draft | Source: D19, D30, D57

| Match status | Default action | Other actions |
|---|---|---|
| Identical (same files) | Skip | Keep both |
| Lower quality than library ("undesirable") | Skip | Overwrite, Keep both |
| Higher quality than library (replacement candidate) | Overwrite | Skip, Keep both |
| Same quality, different files | *none, the user must choose* | Skip, Overwrite, Keep both |

In every case the user can take names and metadata from the library copy by selecting the Library candidate (NG-PRV-010).

The app never writes in the target role (NG-PTH-004). "Overwrite" therefore means: the app prepares the new copy in temp, and the user swaps the copies by hand (NG-PTH-009).

### NG-LIB-010 — "Keep both" folder name
Priority: Must | Status: Draft | Source: D31

With "Keep both", the new copy gets a folder name from the configurable keep-both template. The default is `{year} {album} [{quality}]`, for example `1999 XXX [MP3 320]` or `1999 XXX [FLAC 24-96]`. The existing copy keeps its name. The template is part of NG-CFG-003.

## Lossy manager

### NG-LIB-011 — Lossy releases are tracked
Priority: Must | Status: Draft | Source: RAW, MANIFESTO §6, D60

As in legacy, every lossy release that reaches the library is tracked, so it can be upgraded later. Its statuses stay `pending-upgrade`, `upgraded` and `ignored`.

An entry becomes `upgraded` when the better copy is applied (to temp). The app does not wait until the lossy copy is gone from the library.

### NG-LIB-012 — Lossy manager is a separate screen
Priority: Must | Status: Draft | Source: RAW

The lossy manager is a separate screen, reached from the main menu (NG-APP-003). It lists the tracked releases and lets the user filter them, ignore them, and mark them upgraded.

### NG-LIB-013 — Lossy ledger paths
Priority: Must | Status: Draft | Source: RAW, D8, D55

The lossy ledger stores **relative** paths, for example `ZZ Top\1999 XXX`. The app resolves them against the target first, then temp (NG-PTH-010). The lossy manager shows the computed location of each entry (NG-PTH-011).

Legacy absolute paths are converted during the import (NG-STO-008). An entry that could not be converted has the mark `Path unresolved`. The lossy manager shows it, and the user can fix the path or delete the entry.

## Collection copies

### NG-LIB-014 — Manage copies of the library on other devices
Priority: Won't (v1) | Status: Draft | Source: D79 | Depends on: NG-LIB-001, NG-PTH-001, NG-PTH-015

A later version manages **copies** of the main library on other devices, for example a full copy on the SD card of a music player and a partial copy on a phone. A copy is a new root role, separate from source, target and temp. The main library stays read-only (NG-VIS-004); only copies are written. The user can:

| Ability | Example |
|---|---|
| Compare a copy with the main library | "SD card: 12 releases missing, 3 releases older than on the SSD" |
| Sync missing or changed releases to a copy | "Copy the 12 missing releases to the SD card" |
| Use a different quality per copy | SSD holds FLAC 24-96; the phone copy gets MP3 320, converted by the app |
| Choose what a partial copy holds | Phone: only artists marked ★, or one playlist |
| Find stray files on a copy | Releases on the SD card that are no longer in the main library |

A phone copy needs write access over MTP (NG-PTH-014, NG-PTH-015). The details are decided when this feature is planned. v1 must not block it: for example, the library index must not assume that only one library exists.

## Open points

- NG-LIB-003 (incremental rescan): this was part of the Q37 proposal. The user replaced its identity part (provider IDs) with D44, but did not explicitly confirm the incremental rescan itself. Is it wanted? → Phase 4, area PRP (proposal naming and tags), where AS-PRP-007 (the target index is built once per run) lives.
- NG-LIB-011 (lossy releases are tracked) says "every lossy release that reaches the library". The app never puts anything into the library: the user moves results by hand (NG-PTH-006). When does tracking start: at apply to temp, the same moment as `upgraded` (D60)? → Phase 4, area LSY (lossy tracking).
- A lossy-ledger entry stores only a relative path (NG-LIB-013, NG-STO-008), not a release key (NG-LIB-002). If the user renames the folder while moving it, the entry's location stays `Missing` (NG-PTH-011) and never matches again. Should the entry also store or link the release key? → Phase 4, area LSY.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-04 | Initial version (Docs part A). |
| 0.2 | 2026-10-04 | Docs part B: index covers target and temp, Overwrite via temp, `upgraded` at apply, relative lossy paths. Open points resolved. |
| 0.3 | 2026-11-03 | Consistency review: superseded D37 removed from NG-LIB-002 and marked in NG-LIB-003. NG-LIB-003's "confirm in the BR merge" note moved to Open points → phase 4, area PRP. NG-LIB-009 "never writes" stated per role. Two new open points for area LSY: when lossy tracking starts, and renamed lossy folders. |
| 0.4 | 2026-11-04 | Phase 4, area GEN (D79): new section "Collection copies" with NG-LIB-014 (manage copies of the library on other devices, Won't in v1). |
