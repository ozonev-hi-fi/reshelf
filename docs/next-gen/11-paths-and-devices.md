# 11 — Paths and devices

Status: Draft | Version: 0.4 | Last updated: 2026-11-04

This doc defines where the app reads music, where it writes results, and how it finds these folders when a drive letter changes or a drive disappears.

## Today vs next-gen

| Topic | Today (legacy) | Next-gen |
|---|---|---|
| Source | `-SourceRoot` per run, or `defaultSourceRoot` in settings | Same idea. The source is stored as a location (NG-PTH-001). |
| Library | One absolute `targetRoot` | One target, stored as a location (NG-PTH-001, NG-PTH-003) |
| Apply output | Written **into `targetRoot`** through `<targetRoot>\.reshelf-staging` | Written **into temp only** (NG-PTH-004, NG-PTH-007) |
| Existing library folder | Deleted on `update-existing` / `conflict`, then replaced | Never deleted. The app prepares the new copy, the user swaps (NG-PTH-009). |
| Drive letter change | Absolute paths break. Apply-log entries become invalid. | The app finds the drive by its volume serial number (NG-PTH-001) |
| Lossy ledger | Absolute `targetPath` | Relative path, resolved against target, then temp (NG-PTH-010) |

## Locations

### NG-PTH-001 — Location model
Priority: Must | Status: Draft | Source: D50, D51, D63

The app stores every root folder (source, target, temp) as a **location**:
- the **volume serial number** (an ID written to the drive when it is formatted);
- the **path inside the volume**, without the drive letter.

At run time the app finds the mounted volume with that serial number and builds the full path from its current drive letter. Detection sits behind the OS interface (NG-PLT-002).

A UNC path (a network path like `\\server\share\Music`) is stored as a plain path, without a serial number.

Example: the user picks `E:\Music`. The app stores serial `1A2B-3C4D` + `\Music`. Next day the SSD is mounted as `D:`. The app finds serial `1A2B-3C4D` on `D:` and uses `D:\Music`.

A session stores its source as a location + a relative path. So the overlap message (NG-SES-002) and reopening an old session still work after a letter change.

### NG-PTH-002 — Offline locations and Re-locate
Priority: Must | Status: Draft | Source: D50, D56, D63

When no mounted volume has the stored serial number (or a UNC path cannot be reached), the location is **Offline**.
- The UI shows the location and the items under it as `Offline`, not as missing or deleted.
- A "Re-locate" action lets the user pick the folder again with a folder picker. The app stores the new serial number and path.
- If two mounted volumes have the same serial number (for example a cloned drive), the app does not guess. It asks the user to choose one.

## Roots and roles

### NG-PTH-003 — Three roots
Priority: Must | Status: Draft | Source: D49, D53, D61

| Root | Count | Setting | Rule |
|---|---|---|---|
| **Source** | One per session | Optional default source folder | The UI "New session" page has an editable path field with a "Browse…" button, filled with the default. The CLI option `--source` overrides the default. |
| **Target** (library) | Exactly one in v1 | Required | The organized collection |
| **Temp** | Exactly one in v1 | Required | The place where apply writes its results. "Use the library as temp" is an explicit option. An empty field never means "write into the library". |

Several libraries (for example "Main" and "Car SD card") are a **Won't** for v1.

### NG-PTH-004 — Read-only roles
Priority: Must | Status: Draft | Source: D52, RAW, MANIFESTO §7

The app uses each root by its **role**:
- **Source role**: read only. The app never changes or deletes a source file (kept from legacy).
- **Target role**: read only. The app reads the library to scan it, match it and compare quality. It never writes, renames, moves or deletes anything in it.
- **Temp role**: the only place where apply writes.

### NG-PTH-005 — Target and temp may share a value
Priority: Must | Status: Draft | Source: D52, D53

- Target and temp may point to the **same folder**. The roles stay separate: in the temp role apply writes there, and in the target role the app still only reads.
- Temp may sit **inside** the target, for example `E:\Music\_incoming`. The library scan skips the temp folder, so its content is not counted twice.

### NG-PTH-006 — Moving results from temp to the library
Priority: Must (manual move) / Could ("Move to library") | Status: Draft | Source: D52

- **Must**: the user checks the result in temp and moves it to the target by hand (for example in Explorer). The app notices the move later (NG-PTH-011).
- **Could**: a separate, explicit "Move to library" action, per release and with a confirmation. It is the only action that would ever write into the target. It is not part of v1 unless the tech spec adds it.

## Apply output

### NG-PTH-007 — Staging in temp, then one move
Priority: Must | Status: Draft | Source: D56

Apply builds each release in a staging folder (a temporary build folder) in the temp root, for example `<temp>\.reshelf-staging`. When the release is complete, the app moves it to its final name with **one move**. The staging folder is on the same volume, so the move is atomic (it either happens fully or not at all).
- A half-written release never sits under its final name.
- After a failure or a crash, the app cleans the staging leftovers on the next start.
- The library scan skips the staging folder.
- After a successful apply, the app adds the output to the library index (NG-LIB-001) at once. A rescan is not needed to see it.

### NG-PTH-008 — Replacing the app's own output in temp
Priority: Must | Status: Draft | Source: D58 | Depends on: NG-SES-010

The app may replace a folder in temp only when **both** are true:
1. The app wrote that folder itself (the DB has a record of it).
2. Nobody changed it since: the file list, the file sizes and the modified times are the same as recorded.

Otherwise the folder is **foreign**. The app does not touch it and writes the new output with the replacement suffix (NG-PTH-009).

Example: you applied `ZZ Top\1999 XXX` to temp. Then you fixed a title, and the release became "outdated, apply again". The folder in temp is unchanged, so the re-apply replaces it. If you had deleted a booklet from that folder, the re-apply would write `1999 XXX [replacement]` next to it instead.

### NG-PTH-009 — Overwrite: the app prepares, the user swaps
Priority: Must | Status: Draft | Source: D57 | Depends on: NG-LIB-009

When the user chooses **Overwrite** for a library match, the app never deletes the library copy. Instead:
1. Apply writes the new copy to temp.
2. The release shows the note **"Replace pending"**: "Delete or move `<library>\ZZ Top\1999 XXX`, then move the new copy in."
3. If the final name is already taken in temp (always the case when temp == target), the new copy gets the **replacement suffix**. It comes from the replacement template (NG-CFG-003), default `{year} {album} [replacement]`.

| Setup | Library copy | New copy |
|---|---|---|
| temp ≠ target | `E:\Music\ZZ Top\1999 XXX` | `T:\Temp\ZZ Top\1999 XXX` |
| temp == target | `E:\Music\ZZ Top\1999 XXX` | `E:\Music\ZZ Top\1999 XXX [replacement]` |

In both setups the user does the swap by hand. "Keep both" (NG-LIB-010) needs no special rule: its folder name never clashes, so it goes to temp like any other release.

### NG-PTH-010 — Relative paths, resolved against target, then temp
Priority: Must | Status: Draft | Source: RAW, D54, D76

The library index (NG-LIB-001) and the lossy ledger (NG-LIB-013) store **relative** paths, for example `ZZ Top\1999 XXX`. A stored relative path is a list of levels (`["ZZ Top", "1999 XXX"]`) with no OS separator; the app joins it with the separator of the current OS (D76).
- To find the real folder, the app tries `<target>\<relative path>` first, then `<temp>\<relative path>`.
- The library index covers **both** roots. Each entry remembers the root role where it was found. If both roots have the same release, the target entry wins.

Example: you applied `ZZ Top\1999 XXX` to temp and did not move it yet. A new session finds the same release in a source. Matching sees the temp copy, so the app does not propose a duplicate.

### NG-PTH-011 — Computed release location
Priority: Must | Status: Draft | Source: D59 | Depends on: NG-SES-014

There is no extra release status after `Applied`. The **Done** milestone does not change. Instead, an applied release shows a **Location** that the app computes each time it shows it:

| Location | Meaning |
|---|---|
| `Library` | Found under the target |
| `Temp` | Found under temp, not yet moved |
| `Missing` | Found in neither root |
| `Offline` | The root that should hold it is offline (NG-PTH-002) |

The app looks up the relative path (NG-PTH-010). If the user renamed the folder while moving it, the location is `Missing` until the next library scan finds the release again by its release key (NG-LIB-002).

## Robustness

### NG-PTH-012 — A location disappears during an operation
Priority: Must | Status: Draft | Source: D56 | Depends on: NG-PLT-007

| Operation | When a location disappears |
|---|---|
| Recognize / re-recognize | The run stops. The session keeps its state from before the run. No release becomes `Source missing` because a drive is offline. |
| Scan library | The scan stops. The old index stays. Entries are not removed: offline ≠ deleted. |
| Apply | Per release. The release that was running gets `Error` with a reason. Staging leftovers are cleaned (NG-PTH-007). Releases already applied stay applied. |
| Lossy manager, review page | Items under an offline root show `Offline`, not `Missing`. |

### NG-PTH-013 — Name-length budget
Priority: Must | Status: Draft | Source: D62

Legacy shortens long folder and file names so the full path fits. Next-gen counts the budget from the **longer** of the temp and target roots. Then the release fits in temp and still fits after the move to the target.

Example: temp `T:\t`, target `E:\Music\Collection`. The budget is counted from `E:\Music\Collection`.

### NG-PTH-014 — Phones over USB (MTP) are not a direct source in v1
Priority: Must | Status: Draft | Source: D78

A phone connected by USB is an MTP device (Media Transfer Protocol): it has no drive letter and no volume serial number, and normal file APIs cannot open its files. So it cannot be a root location (NG-PTH-001). When the user tries to pick a folder on such a device as a source, the app explains: "Phones connected by USB are not supported directly. Copy the folder to a disk first." A memory card in a card reader is a normal drive and works.

Example: the user picks `This PC\Pixel 7\Internal shared storage\Music`. The app shows the message and does not create a session.

### NG-PTH-015 — Copy from a device into managed temporary storage (after v1)
Priority: Should | Status: Draft | Source: D78 | Depends on: NG-PTH-014, NG-PLT-002

A later version can copy a folder from an MTP device into app-managed temporary storage and recognize the copy. The device stays read-only. The user sees what was copied, where, and how much space it uses, and can delete it. When the session is finished (NG-SES-014), the app suggests deleting the copy. The session remembers the original device and folder, e.g. "copied from Pixel 7, `Internal shared storage\Music\New`".

Device access is Windows-specific and sits behind the OS interface (NG-PLT-002).

## Resolved open points

The open points that Docs part A collected for this doc are now resolved:

| From | Resolved by |
|---|---|
| NG-SES-002 | NG-PTH-001 |
| NG-SES-010 | NG-PTH-008 |
| NG-SES-013 | NG-PTH-004, NG-PTH-007 |
| NG-SES-014 | NG-PTH-011 |
| NG-LIB-001 | NG-PTH-001, NG-PTH-010 |
| NG-LIB-009 | NG-PTH-009 |
| NG-LIB-013 | NG-PTH-010 |
| NG-STO-008 | NG-STO-008 (conversion rule, D55) |
| NG-PLT-002 | NG-PTH-001 |
| NG-PLT-007 | NG-PTH-002, NG-PTH-012 |

## Open points

- Target and temp are the **same folder** (NG-PTH-005). Three rules then clash:
  - "The library scan skips the temp folder" would skip the whole library. Does the skip apply only when temp is a subfolder of target?
  - "If both roots have the same release, the target entry wins" (NG-PTH-010), so an applied release would never show Location `Temp` (NG-PTH-011). Should the location come from the app's own apply record instead?
  - Apply again replaces the app's own output (NG-PTH-008), but that folder is also a target entry, and the target role never writes (NG-PTH-004). Is the replace allowed because the item belongs to the temp role?

  → Phase 4, area PTH (paths and devices).
- NG-PTH-008 writes a foreign-folder clash under the replacement name, `{year} {album} [replacement]`. What happens when that name is **also** taken by a folder that is not the app's own? → Phase 4, area APL (apply).

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-04 | Stub created in Docs part A. |
| 0.2 | 2026-10-04 | Docs part B: paths model grilled with the user (D49–D63). Requirements NG-PTH-001…013 added. Open points resolved. |
| 0.3 | 2026-11-03 | Consistency review: NG-PTH-002 cites D63 (UNC paths). New open points: target and temp as the same folder → phase 4 area PTH; clash on the replacement name → phase 4 area APL. |
| 0.4 | 2026-11-04 | Phase 4, area GEN (D76): NG-PTH-010 — stored relative paths are lists of levels with no OS separator. D78: new NG-PTH-014 (phones over USB/MTP not a direct source in v1, with a message) and NG-PTH-015 (copy from a device into managed temporary storage, after v1). |
