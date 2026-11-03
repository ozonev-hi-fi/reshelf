# 09 — Storage and environments

Status: Draft | Version: 0.3 | Last updated: 2026-11-03

## Today vs next-gen

| Topic | Today (legacy) | Next-gen |
|---|---|---|
| Storage | JSON files in `.data/` (settings, sessions, recognition, proposal, lossy ledger, apply log), cache and covers on disk | SQLite for structured data, binary files on disk |
| Location | `.data/` in the repo, override with `RESHELF_HOME` | `data/` next to the exe (prod). A configurable folder in dev. |
| Instances | One | Dev, test, prod |
| Discogs token | Env var → `.env` → DPAPI value in `settings.json` | Env var → DPAPI value in the DB |

## Requirements

### NG-STO-001 — SQLite replaces the JSON files
Priority: Must | Status: Draft | Source: RAW, D20

All structured data lives in SQLite: settings, sessions, layers, candidates, snapshots, statuses, library index, lossy tracker and reference data.

### NG-STO-002 — Three instances
Priority: Must | Status: Draft | Source: RAW, D20

| Environment | Instances |
|---|---|
| Development | 2: one for the developer, one for integration and end-to-end tests |
| Published app | 1 |

### NG-STO-003 — Database location
Priority: Must | Status: Draft | Source: RAW, D20

- **Published app**: in a `data` folder next to the executable. This works because the app is portable (NG-PLT-003).
- **Development**: in a configurable folder. The default is a gitignored `data` folder at the repo root.

### NG-STO-004 — Binary files stay on disk
Priority: Must | Status: Draft | Source: D20

Cover images, uploaded pictures and the provider response cache are files under the data folder. The DB stores their paths. The DB stays small and easy to back up.

### NG-STO-005 — Automatic migrations with backup
Priority: Must | Status: Draft | Source: D20

On startup the app applies pending schema migrations automatically. Before each migration it makes a backup copy of the DB file.

### NG-STO-006 — Discogs token storage
Priority: Must | Status: Draft | Source: D20

The Discogs token is stored in the DB, encrypted with DPAPI. An environment variable, if set, overrides it.

### NG-STO-007 — Test isolation
Priority: Must | Status: Draft | Source: D20

- Unit tests do not touch SQLite.
- Integration and end-to-end tests use the test instance and reset it before every run.

### NG-STO-008 — Import of the legacy lossy ledger
Priority: Must | Status: Draft | Source: D8, D55

A one-time import moves the legacy `lossy-tracking.json` into the DB.

The legacy entries hold absolute `targetPath` values. The new ledger stores paths relative to the library (NG-LIB-013). The import converts them like this:
1. The import dialog has an optional "legacy root" field, for example `E:\Music`.
2. For each entry, the import strips the first matching prefix: the current target path, or the legacy root. The comparison ignores case.
3. An entry that matches no prefix is still imported. It gets the mark `Path unresolved`, and the lossy manager shows it (NG-LIB-013).

| Legacy `targetPath` | Current target | Legacy root | Result |
|---|---|---|---|
| `E:\Music\ZZ Top\1999 XXX` | `D:\Music` | `E:\Music` | `ZZ Top\1999 XXX` |
| `e:\music\ZZ Top\1999 XXX` | `E:\Music` | — | `ZZ Top\1999 XXX` |
| `F:\Old\ZZ Top\1999 XXX` | `D:\Music` | `E:\Music` | `Path unresolved` |

### NG-STO-009 — Nothing else is imported
Priority: Must | Status: Draft | Source: D8, D9

Legacy sessions, the apply log and the settings are not imported. The new app starts with fresh data. Because of the freeze (D9), open legacy sessions are not continued.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-04 | Initial version (Docs part A). |
| 0.2 | 2026-10-04 | Docs part B: lossy path conversion rule in NG-STO-008. |
| 0.3 | 2026-11-03 | Consistency review: NG-STO-002 cites D20 ("unit tests use no DB"), which its text follows instead of the raw note. |
