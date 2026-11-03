# To-be BR (Phase 4)

Status: Draft | Version: 0.1 | Last updated: 2026-11-03

This folder holds the **to-be BR**: the business requirements of the new .NET app. It is built from
the merged as-is BR ([../as-is-merged/](../as-is-merged/README.md), 841 `AS-*` requirements, facts
about the legacy app) plus the NG delta docs [01](../../01-vision-scope.md)–[11](../../11-paths-and-devices.md)
(115 `NG-*` requirements). Roadmap phase 4, brief:
[../../sessions/br-apply-ng-vision.md](../../sessions/br-apply-ng-vision.md).

Phase 4 has two parts (D67, phase 4 ends with a validation step):
- **Part 1 — Draft**: one area per session. Decide each suspected defect (keep / fix / drop), apply
  the NG delta, write the area file.
- **Part 2 — Validation**: walk through every `TB-*` requirement one at a time with the user. Only
  this part sets the folder to Agreed.

**Start rule for every Part 1 session:** open the brief, then this file. Continue with the first row
in the [area status table](#area-status-table) whose status is not Done.

## Glossary

### Prefixes

| Prefix | Meaning | Where |
|---|---|---|
| `AS-<AREA>-NNN` | Merged as-is requirement (phase 3): one fact about current legacy behavior | [../as-is-merged/](../as-is-merged/README.md) |
| `AS-DOC-*` | As-is requirement from legacy docs and tests (phase 1) | [../as-is-from-docs/](../as-is-from-docs/README.md) |
| `AS-CODE-*` | As-is requirement from legacy code (phase 2) | [../as-is-from-code/](../as-is-from-code/README.md) |
| `CF-<AREA>-NNN` | Suspected defect carried forward from phase 3, not yet decided | [../as-is-merged/91-suspected-defects-carryforward.md](../as-is-merged/91-suspected-defects-carryforward.md) |
| `NG-<PREFIX>-NNN` | Next-gen delta requirement: what changes compared to legacy | docs [01](../../01-vision-scope.md)–[11](../../11-paths-and-devices.md) |
| `TB-<AREA>-NNN` | To-be requirement: what the new app must do (this folder) | this folder |
| `D<n>` | Decision in the decision log | [../../inbox/raw-notes.md](../../inbox/raw-notes.md) |
| MoSCoW | Priority scale: Must / Should / Could / Won't | [../../README.md](../../README.md#requirement-format) |

### Area codes (as-is and to-be)

| Code | Area name | As-is file |
|---|---|---|
| GEN | General (goals, principles, framing) | [00-general.md](../as-is-merged/00-general.md) |
| DAT | Data and storage | [01-data-and-storage.md](../as-is-merged/01-data-and-storage.md) |
| TXT | Text and naming | [02-text-and-naming.md](../as-is-merged/02-text-and-naming.md) |
| SET | Settings and secrets | [03-settings-and-secrets.md](../as-is-merged/03-settings-and-secrets.md) |
| SES | Sessions | [04-sessions.md](../as-is-merged/04-sessions.md) |
| REC | Recognition | [05-recognition.md](../as-is-merged/05-recognition.md) |
| DSC | Discogs client | [06-discogs-client.md](../as-is-merged/06-discogs-client.md) |
| MAT | Discogs proposal matching | [07-proposal-matching.md](../as-is-merged/07-proposal-matching.md) |
| PRP | Proposal naming and tags | [08-proposal-naming-and-tags.md](../as-is-merged/08-proposal-naming-and-tags.md) |
| REV | Review UI | [09-review-ui.md](../as-is-merged/09-review-ui.md) |
| APL | Apply | [10-apply.md](../as-is-merged/10-apply.md) |
| LSY | Lossy tracking | [11-lossy-tracking.md](../as-is-merged/11-lossy-tracking.md) |
| CLI | Command line | [12-cli.md](../as-is-merged/12-cli.md) |
| BND | Bandcamp | [13-bandcamp-and-errors.md](../as-is-merged/13-bandcamp-and-errors.md) |
| ERR | Errors | [13-bandcamp-and-errors.md](../as-is-merged/13-bandcamp-and-errors.md) |

### Area codes used only in to-be (NG-only files, no legacy counterpart)

| Code | Area name | Main NG source |
|---|---|---|
| APP | App shell (UI pipeline, menu, wizard, CLI + UI at the same time) | [02-app-shape.md](../../02-app-shape.md) |
| LAY | Data layers (Recognized / Proposed / User values) | [04-data-layers.md](../../04-data-layers.md) |
| STO | Storage and instances (SQLite, instances, migrations) | [09-storage-and-environments.md](../../09-storage-and-environments.md) |
| REF | Reference data (formats, companion kinds, reason codes in the DB) | [08-settings-templates-refdata.md](../../08-settings-templates-refdata.md) |
| PLT | Platform (Windows v1, OS abstraction, dependency rule) | [10-platform-and-dependencies.md](../../10-platform-and-dependencies.md) |
| PTH | Paths and devices (source / target / temp, removable drives) | [11-paths-and-devices.md](../../11-paths-and-devices.md) |

### NG delta prefixes

| Prefix | Topic | Doc |
|---|---|---|
| NG-VIS | Vision, goals, principles | [01-vision-scope.md](../../01-vision-scope.md) |
| NG-APP | App shape: CLI + UI, menu, wizard, concurrency | [02-app-shape.md](../../02-app-shape.md) |
| NG-SES | Sessions and statuses | [03-sessions-and-statuses.md](../../03-sessions-and-statuses.md) |
| NG-LAY | Data layers, track identity | [04-data-layers.md](../../04-data-layers.md) |
| NG-PRV | Providers (Discogs, Bandcamp, Library), candidates, snapshots | [05-providers.md](../../05-providers.md) |
| NG-REV | Review page | [06-review-page.md](../../06-review-page.md) |
| NG-LIB | Library index, matching, quality, lossy manager | [07-library-and-quality.md](../../07-library-and-quality.md) |
| NG-CFG | Settings, naming templates, reference data | [08-settings-templates-refdata.md](../../08-settings-templates-refdata.md) |
| NG-STO | SQLite, instances, migrations, data import | [09-storage-and-environments.md](../../09-storage-and-environments.md) |
| NG-PLT | Platform and dependencies | [10-platform-and-dependencies.md](../../10-platform-and-dependencies.md) |
| NG-PTH | Paths and devices | [11-paths-and-devices.md](../../11-paths-and-devices.md) |

## Requirement format

```markdown
### TB-<AREA>-NNN — <title in words>
Priority: <Must|Should|Could|Won't> | Status: Draft | Source: AS-<AREA>-NNN (<short title>), NG-<PREFIX>-NNN (<short title>), D<n> (<short title>)

<behavior text>

Example: <concrete example>
```

- **IDs** are new per area and start at 001. Never renumber or reuse an ID (doc rule 5).
- **`Source:`** always keeps the old `AS-<AREA>-NNN` ID (D67). Every ID in `Source:` gets a short
  title in words, never a bare ID.
- **`Priority`** uses MoSCoW, per [../../README.md](../../README.md#requirement-format). D64 deferred
  real priorities to this phase.
- **Example**: at least one concrete acceptance example per requirement. For MAT, and REC where it
  helps, use a real release pair from `local/maps/before.library-map.json` /
  `after.library-map.json`.
- **Dropped as-is requirement**: write it as an explicit drop in the area file (a short
  `Dropped:` list with the `AS-*` ID, its title and the `D` number). The coverage check in
  `92-coverage.md` needs every `AS-*` ID to end up in a `TB-*` item or in a drop.

## NG → to-be file map

The as-is docs cite no `NG-*` IDs (they hold facts only), so the owner of each NG requirement comes
from a topic scan (D68, NG-only file list and topic scan): which as-is area covers the same
behavior? NG requirements with no legacy counterpart go to the NG-only files `14`–`19`.

This is a **draft owner list**. An area session may move an NG ID to another file; it then updates
this table. The final check is `92-coverage.md`.

| To-be file | Area code | NG requirements applied there |
|---|---|---|
| `00-general.md` | GEN | NG-VIS-001–004 (vision and principles), NG-APP-001 (one core, two front-ends), NG-APP-006 (local, single user) |
| `01-data-and-storage.md` | DAT | NG-CFG-013 (WavPack `.wv` is a built-in audio format) |
| `02-text-and-naming.md` | TXT | NG-CFG-003–006 (naming templates, placeholders, live preview, MANIFESTO naming as defaults), NG-PTH-013 (name-length budget) |
| `03-settings-and-secrets.md` | SET | NG-CFG-001 (settings page), NG-CFG-002 (cover max dimension), NG-CFG-007 (settings never retroactive), NG-CFG-008 (provider-ID tag setting), NG-STO-006 (Discogs token storage) |
| `04-sessions.md` | SES | NG-SES-001–012 and NG-SES-014 (session lifecycle, invalidation, statuses, approval, milestones) |
| `05-recognition.md` | REC | NG-LAY-005 (cue sheets become virtual tracks at recognize) |
| `06-discogs-client.md` | DSC | NG-PRV-001 (provider set), NG-PRV-002 (no-provider mode), NG-PRV-003 (show everything found), NG-PRV-005 (snapshots), NG-PRV-006 (re-sync), NG-PRV-007 (custom provider URL), NG-PRV-008 (search order), NG-PRV-012 (provider response cache) |
| `07-proposal-matching.md` | MAT | NG-PRV-004 (reversible candidate selection) |
| `08-proposal-naming-and-tags.md` | PRP | NG-LIB-001–010 (library index, release key, incremental rescan, library match, quality comparison, "keep both"), NG-PRV-010 (library as a provider), NG-PRV-011 (provider IDs as optional tags) |
| `09-review-ui.md` | REV | NG-REV-001–013 (review page) |
| `10-apply.md` | APL | NG-SES-013 (apply per release), NG-PTH-006–009 (temp → library move, staging, replacing own output, overwrite prepared by the app) |
| `11-lossy-tracking.md` | LSY | NG-LIB-011–013 (lossy tracking, lossy manager, ledger paths), NG-STO-008 (import of the legacy lossy ledger) |
| `12-cli.md` | CLI | NG-APP-005 (CLI scope) |
| `13-bandcamp-and-errors.md` | BND, ERR | NG-PRV-009 (Bandcamp needs research first) |
| `14-app-shell.md` | APP | NG-APP-002 (UI covers the whole pipeline), NG-APP-003 (main menu), NG-APP-004 (session wizard), NG-APP-007 (CLI and UI at the same time), NG-APP-008 (UI technology by ADR) |
| `15-data-layers.md` | LAY | NG-LAY-001–004, NG-LAY-006–009 (three layers, effective value, per-field granularity, track identity, reset, "no override", stale overrides, suggestion next to user value) |
| `16-storage-and-instances.md` | STO | NG-STO-001–005, NG-STO-007, NG-STO-009 (SQLite, instances, DB location, binaries on disk, migrations, test isolation, nothing else imported) |
| `17-reference-data.md` | REF | NG-CFG-009–012 (reference data in the DB, seeding, disable not delete, user rows as draft) |
| `18-platform.md` | PLT | NG-PLT-001–006 (Windows v1, OS interfaces, portable zip, dependency rule, ADR per dependency, check for tools not bundled) |
| `19-paths-and-devices.md` | PTH | NG-PTH-001–005, NG-PTH-010–012 (location model, offline locations, three roots, read-only roles, shared target/temp, relative paths, computed location, location lost mid-operation), NG-PLT-007 (removable storage robustness) |

Total: 115 NG requirements, each with one owner.

Layer-related points that come up in PRP, REV or APL before file `15` exists are marked
"pending LAY" in those files, the same way REV marks the progress/cancel point "pending CLI".

## Open points

Decided inside the owning area. Full reasons: [brief, "Open points"](../../sessions/br-apply-ng-vision.md#open-points--decide-inside-the-owning-area).

| Open point | Owning area |
|---|---|
| NG-LIB-003 (incremental rescan of the library index) | PRP (proposal naming and tags) |
| NG-APP open point (progress and cancel for long operations) | CLI (command line), with a back-reference from REV |
| NG-PLT open point (cue-split bit-exactness) | APL (apply) |

## Area status table

As-is count = `AS-*` requirements in the as-is file. CF count = suspected defects to decide.

| # | File | Area code(s) | Area name | As-is count | CF count | Status | Last done ID |
|---|---|---|---|---|---|---|---|
| 1 | `00-general.md` | GEN | General | 10 | 1 | Not started | — |
| 2 | `01-data-and-storage.md` | DAT | Data and storage | 97 | 5 | Not started | — |
| 3 | `02-text-and-naming.md` | TXT | Text and naming | 74 | 3 | Not started | — |
| 4 | `03-settings-and-secrets.md` | SET | Settings and secrets | 45 | 2 | Not started | — |
| 5 | `04-sessions.md` | SES | Sessions | 25 | 2 | Not started | — |
| 6 | `05-recognition.md` | REC | Recognition | 100 | 18 | Not started | — |
| 7 | `06-discogs-client.md` | DSC | Discogs client | 26 | 4 | Not started | — |
| 8 | `07-proposal-matching.md` | MAT | Discogs proposal matching | 77 | 7 | Not started | — |
| 9 | `08-proposal-naming-and-tags.md` | PRP | Proposal naming and tags | 106 | 10 | Not started | — |
| 10 | `09-review-ui.md` | REV | Review UI | 125 | 15 | Not started | — |
| 11 | `10-apply.md` | APL | Apply | 69 | 11 | Not started | — |
| 12 | `11-lossy-tracking.md` | LSY | Lossy tracking | 22 | 2 | Not started | — |
| 13 | `12-cli.md` | CLI | Command line | 52 | 7 | Not started | — |
| 14 | `13-bandcamp-and-errors.md` | BND, ERR | Bandcamp and errors | 13 | 1 | Not started | — |
| 15 | `14-app-shell.md` | APP | App shell | — | — | Not started | — |
| 16 | `15-data-layers.md` | LAY | Data layers | — | — | Not started | — |
| 17 | `16-storage-and-instances.md` | STO | Storage and instances | — | — | Not started | — |
| 18 | `17-reference-data.md` | REF | Reference data | — | — | Not started | — |
| 19 | `18-platform.md` | PLT | Platform | — | — | Not started | — |
| 20 | `19-paths-and-devices.md` | PTH | Paths and devices | — | — | Not started | — |
| 21 | `92-coverage.md` | — | Coverage check (both directions) | — | — | Not started | — |

Totals: 841 as-is requirements, 88 suspected defects.

`93-validation-log.md` (the Part 2 tracker) is created when Part 2 starts.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-11-03 | Phase 4, Part 1, session 0: folder created. Glossary, requirement format, NG → to-be file map (D68: topic scan, six NG-only files `14`–`19`), open points, area status table. |
