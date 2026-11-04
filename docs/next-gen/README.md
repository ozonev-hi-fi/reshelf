# Reshelf Next-Gen — Docs

Status: Draft | Version: 0.12 | Last updated: 2026-11-04

This folder holds the **next-gen delta requirements**. These docs describe what changes compared to the legacy PowerShell app. They also hold the roadmap, ADRs (architecture decision records), the briefs for later sessions and the BR documents in `br/`.

The current (as-is) behavior is described by the BR (business requirements) sessions: Phase 1 in [br/as-is-from-docs/](br/as-is-from-docs/README.md), Phase 2 in [br/as-is-from-code/](br/as-is-from-code/README.md), reconciled in Phase 3 [br/as-is-merged/](br/as-is-merged/README.md). Phase 4 applies the next-gen vision to produce the to-be BR in `br/to-be/`. See [00-roadmap.md](00-roadmap.md).

## Index

| File | Prefix | Topic | Status | Version |
|---|---|---|---|---|
| [00-roadmap.md](00-roadmap.md) | — | Phases, sessions, exit criteria | Draft | 0.12 |
| [01-vision-scope.md](01-vision-scope.md) | NG-VIS | Goals, non-goals, principles, glossary | Draft | 0.5 |
| [02-app-shape.md](02-app-shape.md) | NG-APP | CLI + UI, menu, wizard, concurrency | Draft | 0.3 |
| [03-sessions-and-statuses.md](03-sessions-and-statuses.md) | NG-SES | Session lifecycle, invalidation, statuses, approve, apply | Draft | 0.4 |
| [04-data-layers.md](04-data-layers.md) | NG-LAY | Recognized / Proposed / User layers, track identity | Draft | 0.2 |
| [05-providers.md](05-providers.md) | NG-PRV | Discogs, Library, candidates, snapshots | Draft | 0.5 |
| [06-review-page.md](06-review-page.md) | NG-REV | Sorting, filters, tree view, pictures | Draft | 0.2 |
| [07-library-and-quality.md](07-library-and-quality.md) | NG-LIB | Library index, matching, quality, lossy manager | Draft | 0.4 |
| [08-settings-templates-refdata.md](08-settings-templates-refdata.md) | NG-CFG | Settings, naming templates, reference data | Draft | 0.5 |
| [09-storage-and-environments.md](09-storage-and-environments.md) | NG-STO | SQLite, instances, migrations, data import | Draft | 0.3 |
| [10-platform-and-dependencies.md](10-platform-and-dependencies.md) | NG-PLT | Windows v1, OS abstraction, dependency rule | Draft | 0.4 |
| [11-paths-and-devices.md](11-paths-and-devices.md) | NG-PTH | Source / target / temp paths, removable drives | Draft | 0.4 |
| [br/as-is-from-docs/](br/as-is-from-docs/README.md) | AS-DOC | As-is BR from legacy docs and tests (Phase 1) | Draft | 0.2 |
| [br/as-is-from-code/](br/as-is-from-code/README.md) | AS-CODE | As-is BR from legacy code (Phase 2) | Draft | 0.2 |
| [br/as-is-merged/](br/as-is-merged/README.md) | AS | Reconciled as-is BR, facts only (Phase 3) | Agreed | 1.0 |
| [br/to-be/](br/to-be/README.md) | TB | To-be BR: as-is + NG delta (Phase 4) | Draft | 0.3 |
| [adr/](adr/0000-template.md) | — | Architecture decision records | — | — |
| [sessions/](sessions/) | — | Briefs for the planned sessions | — | — |
| [inbox/raw-notes.md](inbox/raw-notes.md) | — | Original notes (verbatim) + decision log D1–D84 | Draft | 0.10 |

## Doc rules

These rules apply to every file in this folder. They also apply to every agent session that works here.

1. **Header.** Every doc starts with `Status: <Draft | Agreed | Withdrawn> | Version: <x.y> | Last updated: <yyyy-MM-dd>`.
2. **Changelog.** Every doc ends with a changelog table (`Version | Date | Change`).
3. **Keep docs current after every piece of work.** Before you commit, do all of these:
   - update the header of each changed doc;
   - add a changelog row;
   - update the [Index](#index) row (status and version);
   - fix the cross-links that point to moved or renamed items.
4. **Versions.** A minor bump (`0.1 → 0.2`) is for edits. A major bump (`0.x → 1.0`) is for the user's agreement (`Agreed`).
5. **Stable requirement IDs.** The ID format is `NG-<PREFIX>-NNN`. Never renumber or reuse an ID. A dropped requirement keeps its ID and gets `Status: Withdrawn` with a reason.
6. **Every requirement has a source.** `Source:` points to a decision in [inbox/raw-notes.md](inbox/raw-notes.md) (`D1`, `D2`, … with the next free number for new ones), to a raw-notes section (`RAW`), or to a section of the repo's [MANIFESTO.md](../../MANIFESTO.md) (`MANIFESTO §n`, D70). A link to another requirement is not a source: put it in `Depends on:`. Exception (D64): as-is requirements (`AS-DOC-*`, `AS-CODE-*`) point to the legacy file and test, function or section, and have no `Priority`. See [br/as-is-from-docs/README.md](br/as-is-from-docs/README.md#requirement-format). Exception (D82): to-be requirements (`TB-*`) list their origin `AS-*`, `NG-*` and `D<n>` IDs in `Source:`; `Depends on:` is for other `TB-*` requirements. See [br/to-be/README.md](br/to-be/README.md#requirement-format).
7. **New decisions.** A new decision gets a new `D` entry in the decision log. It either updates a requirement doc or creates an ADR in [adr/](adr/0000-template.md).
8. **Single source of truth.** Each rule lives in one doc. Other docs link to it by requirement ID. They do not copy it.
9. **Open points.** Write an unresolved item as an `Open points` bullet in the doc where it belongs. Write it as a question, not as a guess. A point that waits for a later phase or another doc names it, for example `→ tech spec`.
10. **Examples.** Use well-known public releases (for example `Kyuss / 1994 Welcome to Sky Valley`) or invented names (`Artist A`, `Album B`). Never use folder names, drive paths, session IDs or groupings from a contributor's own collection (D81).

## Requirement format

```markdown
### NG-SES-008 — Re-run recognize keeps user edits for existing items
Priority: Must | Status: Draft | Source: D25 | Depends on: NG-LAY-004

When recognize runs again in a session, the User-layer edits stay attached to every source item that still exists.

Example: you renamed the title of `03 Hidden.flac`. After re-recognize, the file still exists, so the title edit stays.
```

- **Priority** uses MoSCoW: **Must** (v1 is not usable without it), **Should** (important, can slip), **Could** (nice to have), **Won't** (not in this version).
- The initial priorities were set by the agent in Docs part A. They are `Draft` until the user reviews them.

## Glossary

The shared terms are defined in [01-vision-scope.md](01-vision-scope.md#glossary).

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-04 | Docs part A: initial doc set. |
| 0.2 | 2026-10-04 | Docs part B: doc 11 filled in (NG-PTH), decisions D49–D63, open points resolved. Doc rule 9 no longer names Part B. |
| 0.3 | 2026-10-05 | Phase 1: index row for `br/as-is-from-docs/`; doc rule 6 names the D64 exception for as-is requirements. |
| 0.4 | 2026-10-07 | Index row for doc 08 bumped to 0.3 (NG-CFG-013, WavPack `.wv` support, D65). |
| 0.5 | 2026-10-10 | Index row for `br/as-is-from-code/` (Phase 2 done). |
| 0.6 | 2026-10-10 | Index rows fixed: 00-roadmap.md (0.7), br/as-is-from-docs/ (0.2), br/as-is-from-code/ (0.2), inbox/raw-notes.md (0.5, D1–D66); added missing index row for br/as-is-merged/. |
| 0.7 | 2026-10-11 | Index row for 00-roadmap.md bumped to 0.8 (Phase 4 input: real-world library maps from `tools/library-mapper/`). |
| 0.8 | 2026-10-14 | Index row for 02-app-shape.md fixed to 0.2 (matched the file's own header, stale since 2026-10-10). |
| 0.9 | 2026-11-03 | Phase 4 prep (D67): index rows fixed — 00-roadmap.md (0.10), br/as-is-merged/ (Agreed 0.15), inbox/raw-notes.md (0.6, D1–D67); line 7 now mentions phase 3 and the coming br/to-be/. |
| 0.10 | 2026-11-03 | Phase 4 session 0 (D68): index row for `br/to-be/` (Draft 0.1); 00-roadmap.md (0.11), inbox/raw-notes.md (0.8, D1–D69). D69 (no Bandcamp): 01-vision-scope.md (0.3), 05-providers.md (0.3, topic without Bandcamp), 10-platform-and-dependencies.md (0.3). |
| 0.11 | 2026-11-03 | Consistency review (D70): doc rule 6 allows `MANIFESTO §n` as a source; a requirement link goes in `Depends on:`. Index rows updated for 00 (0.12), 01 (0.4), 02 (0.3), 03 (0.3), 05 (0.4), 06 (0.2), 07 (0.3), 08 (0.4), 09 (0.3), 10 (0.4), 11 (0.3), inbox/raw-notes.md (0.9, D1–D70), br/to-be/ (0.2). br/as-is-merged/ set to 1.0 (doc rule 4: Agreed = major version). |
| 0.12 | 2026-11-04 | Bandcamp cleanup (D69 is the only live mention) and phase 4 area GEN decisions D71–D84, doc rule 6 exception for to-be `Source:` (D82), doc rule 10 (examples): index rows for 01 (0.5), 03 (0.4), 04 (0.2), 05 (0.5), 07 (0.4), 08 (0.5), 11 (0.4), inbox/raw-notes.md (0.10, D1–D84), br/to-be/ (0.3). |
