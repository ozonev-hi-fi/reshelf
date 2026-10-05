# 11 — Paths and devices

Status: Draft (stub, to be filled in Docs part B) | Version: 0.1 | Last updated: 2026-10-04

This doc is a placeholder. **Docs part B** fills it. See the brief [sessions/part-b-paths.md](sessions/part-b-paths.md).

## Input

- The "Paths twist" section of [inbox/raw-notes.md](inbox/raw-notes.md#paths-twist). It covers source, target, temp, alternative paths for the same library, device identity, read-only rules and relative lossy paths.
- The decision log D1–D48 in the same file.

## Open points collected in Docs part A (marked `→ Part B`)

| From | Open point |
|---|---|
| NG-SES-002 | How a source folder is identified when its drive letter changes (for the overlap message) |
| NG-SES-010 | Where applied output lives (temp vs target), and how "outdated, apply again" works there |
| NG-SES-013 | Apply writes only to temp (raw notes). Confirm it and define it. |
| NG-SES-014 | Whether a release state "moved from temp to target" is needed |
| NG-LIB-001 | How the library location is stored and found on a removable drive |
| NG-LIB-009 | How "Overwrite" runs when the app never writes to the target |
| NG-LIB-013 | Relative lossy paths, resolved against target first, then temp |
| NG-STO-008 | Converting legacy absolute `targetPath` values when the lossy ledger is imported |
| NG-PLT-002 | Device detection behind an OS interface |
| NG-PLT-007 | Device identity, drive-letter changes, alternative paths |

## Requirements

None yet. Use the prefix `NG-PTH-NNN`.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-04 | Stub created in Docs part A. |
