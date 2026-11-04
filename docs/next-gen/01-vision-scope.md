# 01 — Vision and scope

Status: Draft | Version: 0.5 | Last updated: 2026-11-04

## Vision

Reshelf next-gen is a .NET rewrite of the PowerShell app. The purpose stays the same as in [MANIFESTO.md](../../MANIFESTO.md): turn messy music folders into a clean library, one release at a time. The new app adds:
- a full local UI that controls the whole pipeline;
- SQLite storage instead of JSON files;
- full transparency about what providers found;
- separate data layers for recognized, proposed and user-edited data;
- a library-aware quality comparison.

## Requirements

### NG-VIS-001 — .NET application replaces the PowerShell scripts
Priority: Must | Status: Draft | Source: RAW

The next-gen app is a .NET application. It replaces the PowerShell scripts completely. It has the same pipeline: recognize → propose → review → apply.

### NG-VIS-002 — CLI and full UI
Priority: Must | Status: Draft | Source: RAW, D18

The app has a CLI for power users and a full UI. With the UI you can do everything without the CLI. Details: [02-app-shape.md](02-app-shape.md).

### NG-VIS-003 — Legacy code is the reference, not the truth
Priority: Must | Status: Draft | Source: RAW, D2

The legacy code is the main source for current behavior. It can still contain logic errors and bugs. A behavior that looks wrong is recorded as a "suspected defect". It is not copied blindly and not fixed silently.

### NG-VIS-004 — Core principles
Priority: Must | Status: Draft | Source: RAW, D11, D12, D27, D44, D52

| Principle | Meaning |
|---|---|
| Source is read-only | Nothing in the app ever changes or deletes a source file. This is kept from legacy (MANIFESTO §7). |
| Library is read-only | In the target role, the app never writes, moves or deletes anything in the library. Apply writes only in the temp role, and the user moves the results (NG-PTH-004). Temp may share the library folder (NG-PTH-005). |
| The user's version wins | User edits have the top priority over proposed and recognized data (NG-LAY-002). |
| No silent matching | Everything a provider found is visible and can be changed (NG-PRV-003). |
| Works without providers | The app works only on folder names, structure and existing tags when no provider is set up or when a provider finds nothing (NG-PRV-002). |
| No retroactive changes | Settings changes never touch releases that were already applied (NG-CFG-007). |

## Non-goals (v1)

| Non-goal | Note |
|---|---|
| Cross-platform (Linux, macOS) | Windows-only in v1. OS-specific code sits behind interfaces, so a port is possible later (NG-PLT-002). |
| Installer | Portable zip only. An installer may come "some day" (NG-PLT-003). |
| Multi-user, remote access, login | One user on one machine (NG-APP-006). |
| New features in the legacy app | The legacy app is frozen (roadmap rule D9). |

## Glossary

| Term | Meaning |
|---|---|
| **Main artist** | A band or performer. The first folder level under the target in the default layout. |
| **Release** | One album, EP, single, etc. The main unit of work. |
| **Companion material** | Non-track files of a release: cover scans, booklets, lyrics, photos. |
| **Lossy / lossless** | Compressed with loss (MP3, AAC, ...) / exact (FLAC, ALAC, WavPack, ...). Decided from the codec, not the extension (NG-LIB-006). |
| **Session** | One run of the pipeline over one source folder. Created by `recognize`. |
| **Stage** | A pipeline step: Recognize, Propose, Review, Apply. |
| **Source** | A folder with unorganized music. Read-only to the app. |
| **Target / library** | The organized music collection. Read-only to the app (NG-PTH-004). See [11-paths-and-devices.md](11-paths-and-devices.md). |
| **Temp** | The folder where apply writes its results. The user checks them there and moves them to the library. May be the same folder as the target (NG-PTH-005). |
| **Location** | How the app stores a root folder: volume serial number + path inside the volume, so a drive-letter change does not break it (NG-PTH-001). |
| **Provider** | An external or internal metadata source: Discogs, Library. |
| **Candidate** | One possible match found by a provider for a release. |
| **Snapshot** | The stored data that one candidate gave, kept so you can switch back without a new request. |
| **Layer** | One of three data versions: Recognized, Proposed, User. |
| **Override** | A User-layer value that replaces the Proposed or Recognized value. |
| **Stale override** | An override whose underlying Proposed value changed after the user edited it. |
| **Source item** | One audio unit in the source: a file, or one track of a cue sheet. |
| **Virtual track** | A track defined by a cue sheet (start/end time) before the physical split. |
| **Reason code** | A coded review flag with a severity (Blocking / Warning / Info). |
| **Reference data** | Lists the app works with, stored in the DB. The full list is in NG-CFG-009. |
| **Built-in row** | A reference-data row that the app ships and owns. |
| **Delta requirements** | What changes compared to the legacy app (these docs). |
| **As-is / to-be** | Current behavior / target behavior. |
| **BR** | Business requirements: what the app must do, without technical detail. |
| **ADR** | Architecture decision record: a short doc about one decision and its reasons. |
| **MoSCoW** | Priority scale: Must, Should, Could, Won't. |
| **Upsert** | Insert a row if it is missing, update it if it exists. |
| **DPAPI** | Windows Data Protection API: encrypts data for the current Windows user. |

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-04 | Initial version (Docs part A). |
| 0.2 | 2026-10-04 | Docs part B: "Library is read-only" principle; glossary entries Target, Temp, Location. |
| 0.3 | 2026-11-03 | D69 (no Bandcamp): Bandcamp removed from the glossary entry Provider. |
| 0.4 | 2026-11-03 | Consistency review: NG-VIS-004 "Library is read-only" stated per role (target role), matching NG-PTH-004/005. Glossary "Reference data" links to NG-CFG-009 instead of copying an incomplete list. |
| 0.5 | 2026-11-04 | Bandcamp cleanup: glossary entry Provider lists only the real providers. Phase 4 area GEN: glossary terms Main artist, Companion material, Lossy / lossless moved here from the legacy glossary. |
