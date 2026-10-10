# Reshelf Next-Gen — Docs

Status: Draft | Version: 0.4 | Last updated: 2026-10-07

This folder holds the **next-gen delta requirements**. These docs describe what changes compared to the legacy PowerShell app. They also hold the roadmap, ADRs (architecture decision records), the briefs for later sessions and the BR documents in `br/`.

The current (as-is) behavior is described by the BR (business requirements) sessions: Phase 1 in [br/as-is-from-docs/](br/as-is-from-docs/README.md), Phase 2 later in `br/as-is-from-code/`. See [00-roadmap.md](00-roadmap.md).

## Index

| File | Prefix | Topic | Status | Version |
|---|---|---|---|---|
| [00-roadmap.md](00-roadmap.md) | — | Phases, sessions, exit criteria | Draft | 0.4 |
| [01-vision-scope.md](01-vision-scope.md) | NG-VIS | Goals, non-goals, principles, glossary | Draft | 0.2 |
| [02-app-shape.md](02-app-shape.md) | NG-APP | CLI + UI, menu, wizard, concurrency | Draft | 0.1 |
| [03-sessions-and-statuses.md](03-sessions-and-statuses.md) | NG-SES | Session lifecycle, invalidation, statuses, approve, apply | Draft | 0.2 |
| [04-data-layers.md](04-data-layers.md) | NG-LAY | Recognized / Proposed / User layers, track identity | Draft | 0.1 |
| [05-providers.md](05-providers.md) | NG-PRV | Discogs, Bandcamp, Library, candidates, snapshots | Draft | 0.2 |
| [06-review-page.md](06-review-page.md) | NG-REV | Sorting, filters, tree view, pictures | Draft | 0.1 |
| [07-library-and-quality.md](07-library-and-quality.md) | NG-LIB | Library index, matching, quality, lossy manager | Draft | 0.2 |
| [08-settings-templates-refdata.md](08-settings-templates-refdata.md) | NG-CFG | Settings, naming templates, reference data | Draft | 0.3 |
| [09-storage-and-environments.md](09-storage-and-environments.md) | NG-STO | SQLite, instances, migrations, data import | Draft | 0.2 |
| [10-platform-and-dependencies.md](10-platform-and-dependencies.md) | NG-PLT | Windows v1, OS abstraction, dependency rule | Draft | 0.2 |
| [11-paths-and-devices.md](11-paths-and-devices.md) | NG-PTH | Source / target / temp paths, removable drives | Draft | 0.2 |
| [br/as-is-from-docs/](br/as-is-from-docs/README.md) | AS-DOC | As-is BR from legacy docs and tests (Phase 1) | Draft | 0.1 |
| [adr/](adr/0000-template.md) | — | Architecture decision records | — | — |
| [sessions/](sessions/) | — | Briefs for the planned sessions | — | — |
| [inbox/raw-notes.md](inbox/raw-notes.md) | — | Original notes (verbatim) + decision log D1–D64 | Draft | 0.3 |

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
6. **Every requirement has a source.** `Source:` points to a decision in [inbox/raw-notes.md](inbox/raw-notes.md) (`D1`–`D64`, and later decisions with the next free number) or to a raw-notes section (`RAW`). Exception (D64): as-is requirements (`AS-DOC-*`, `AS-CODE-*`) point to the legacy file and test, function or section, and have no `Priority`. See [br/as-is-from-docs/README.md](br/as-is-from-docs/README.md#requirement-format).
7. **New decisions.** A new decision gets a new `D` entry in the decision log. It either updates a requirement doc or creates an ADR in [adr/](adr/0000-template.md).
8. **Single source of truth.** Each rule lives in one doc. Other docs link to it by requirement ID. They do not copy it.
9. **Open points.** Write an unresolved item as an `Open points` bullet in the doc where it belongs. Write it as a question, not as a guess. A point that waits for a later phase or another doc names it, for example `→ tech spec`.

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
