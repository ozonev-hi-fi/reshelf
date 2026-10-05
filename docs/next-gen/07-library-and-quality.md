# 07 — Library, quality comparison, lossy manager

Status: Draft | Version: 0.1 | Last updated: 2026-10-04

## Today vs next-gen

| Topic | Today (legacy) | Next-gen |
|---|---|---|
| Finding a release in the library | Scans `targetRoot/*/*` for folders that match `^\d{4}\s+(.+)$`. It depends on the naming template. | DB index built from tags. Independent of templates and providers. |
| Release key | `stableKey` = SHA-256 of normalized `artist\|album\|year` from **source folder names** | Provider-independent key from tags, with folder names as a fallback |
| Quality | Lossless list by extension (`.flac .wav .ape .alac`). `.m4a` always counts as lossy, even when it holds ALAC (suspected defect). | Detected from codec and stream properties |
| Existing release | `create-new / skip-existing-identical / update-existing / conflict` | Match statuses with user actions (NG-LIB-009) |
| Lossy ledger | `lossy-tracking.json` with **absolute** `targetPath` | Lossy manager screen. Paths → Part B. |

## Library index

### NG-LIB-001 — Library index in the DB
Priority: Must | Status: Draft | Source: D44, D32

The app keeps an index of the library in the DB. A "Scan library" action builds it. For each library release the index stores:
- the release key (NG-LIB-002);
- the track count and track durations;
- the audio properties (codec, lossless or lossy, bit depth, sample rate, bitrate);
- the folder location.

Open points: how the library location is stored and found on a removable drive → Part B.

### NG-LIB-002 — Provider-independent release key
Priority: Must | Status: Draft | Source: D44, D37

The release key is built from normalized Album Artist + Album + Year. These values come from the **tags** first and from folder names only as a fallback. The key never depends on provider IDs (NG-PRV-011), and never on the naming templates (NG-CFG-003).

### NG-LIB-003 — Incremental rescan
Priority: Should | Status: Draft | Source: D37, D44

Before matching, the app quickly checks the library folders. It rescans only the folders that changed since the last scan (by modified time).

Note: this was part of the Q37 proposal. The user replaced the identity part (provider IDs) with D44. The incremental rescan itself was not explicitly confirmed. Confirm it in the BR merge.

### NG-LIB-004 — First match after recognize
Priority: Must | Status: Draft | Source: D44

After recognize, every source release is matched against the index by its key. Equal track count and track durations within ±3 s confirm the match. This step uses the DB only, so it is fast.

### NG-LIB-005 — Live check after propose
Priority: Must | Status: Draft | Source: D44

After propose, when the final names are known, the app checks the **real files** of the matched library release and of the proposed target path. It confirms they exist, compares the quality (NG-LIB-007) and sets the match status (NG-LIB-009).

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
Priority: Must | Status: Draft | Source: D19, D30

| Match status | Default action | Other actions |
|---|---|---|
| Identical (same files) | Skip | Keep both |
| Lower quality than library ("undesirable") | Skip | Overwrite, Keep both |
| Higher quality than library (replacement candidate) | Overwrite | Skip, Keep both |
| Same quality, different files | *none, the user must choose* | Skip, Overwrite, Keep both |

In every case the user can take names and metadata from the library copy by selecting the Library candidate (NG-PRV-010).

Open points: how Overwrite runs when the app never writes to the target → Part B.

### NG-LIB-010 — "Keep both" folder name
Priority: Must | Status: Draft | Source: D31

With "Keep both", the new copy gets a folder name from the configurable keep-both template. The default is `{year} {album} [{quality}]`, for example `1999 XXX [MP3 320]` or `1999 XXX [FLAC 24-96]`. The existing copy keeps its name. The template is part of NG-CFG-003.

## Lossy manager

### NG-LIB-011 — Lossy releases are tracked
Priority: Must | Status: Draft | Source: RAW, MANIFESTO §6

As in legacy, every lossy release that reaches the library is tracked, so it can be upgraded later. Its statuses stay `pending-upgrade`, `upgraded` and `ignored`.

### NG-LIB-012 — Lossy manager is a separate screen
Priority: Must | Status: Draft | Source: RAW

The lossy manager is a separate screen, reached from the main menu (NG-APP-003). It lists the tracked releases and lets the user filter them, ignore them, and mark them upgraded.

### NG-LIB-013 — Lossy ledger paths
Priority: Must | Status: Draft | Source: RAW, D8

Open points → Part B. The raw notes say the lossy tracker keeps **relative** paths, resolved against the target first and then the temp folder. Part B also defines how the legacy absolute paths are converted during import (NG-STO-008).

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-04 | Initial version (Docs part A). |
