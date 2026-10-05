# 10 — Platform and dependencies

Status: Draft | Version: 0.1 | Last updated: 2026-10-04

## Today vs next-gen

| Topic | Today (legacy) | Next-gen |
|---|---|---|
| Platform | Windows, PowerShell 7.4+ | Windows v1, OS logic behind interfaces |
| Delivery | Clone the repo | Portable zip |
| External tools | The user installs ffmpeg (cue split, cover resize) and copies `TagLibSharp.dll` by hand | Every dependency is chosen by an ADR. The user installs nothing when that is possible. |
| Removable drives | No handling. Absolute paths break when the drive letter changes. | Handled (details → Part B) |

## Requirements

### NG-PLT-001 — Windows-only in v1
Priority: Must | Status: Draft | Source: D6

v1 runs on Windows. Cross-platform support is a non-goal for v1 (NG-VIS-004).

### NG-PLT-002 — OS-specific logic behind interfaces
Priority: Must | Status: Draft | Source: D6

Code that depends on the OS sits behind interfaces, so another OS can be added later. Examples:
- a **path builder** that builds `d:\music\here` on Windows and `/mnt/d/music/here` on Linux;
- secret storage (DPAPI on Windows);
- drive and device detection (→ Part B).

### NG-PLT-003 — Portable zip only
Priority: Must | Status: Draft | Source: D20

The app ships as a portable zip: unpack it and run it. There is no installer in v1, maybe one day.

### NG-PLT-004 — Dependency selection rule
Priority: Must | Status: Draft | Source: D21, D38

Every dependency goes through the same rule, whether it is a NuGet package, a native library or an external tool:
1. **Compare functionality.**
2. If the functionality is equal, **prefer the NuGet package**.
3. If a third-party tool is better, **check its license**: can we ship it inside our zip?
4. If we cannot ship it, the user installs it, and the app checks for it (NG-PLT-006).

The goal is a zip that needs nothing else, but better functionality comes first.

### NG-PLT-005 — An ADR for every dependency
Priority: Must | Status: Draft | Source: D21, D38

Each dependency gets an ADR ([template](adr/0000-template.md)) with pros, cons, the license and bundling check, and the decision. Known candidates for ADRs in the tech spec:
- tag reading and writing (legacy: TagLibSharp);
- cue split (legacy: ffmpeg);
- image resize and inspection (legacy: ffmpeg, System.Drawing);
- SQLite access;
- UI technology (NG-APP-008);
- Bandcamp access (NG-PRV-009).

### NG-PLT-006 — Check for tools that are not bundled
Priority: Must | Status: Draft | Source: D38

If a dependency cannot be shipped in the zip, the app checks that it is installed. If it is missing, the app tells the user how to install it. The features that need it stay unavailable until then.

### NG-PLT-007 — Removable storage robustness
Priority: Must | Status: Draft | Source: RAW

A source or library location can disappear: unplugged, ejected, or the drive letter changed. The app detects this. It shows a clear state and never corrupts its data or half-written output because of it.

Open points → Part B: device identity, drive-letter changes, alternative paths.

## Open points

- Q21 also proposed that a cue split of a lossless source must keep the audio samples bit-exact (re-encoding to FLAC is fine). The user answered about dependencies in general and did not confirm this point. Confirm it in the BR merge.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-04 | Initial version (Docs part A). |
