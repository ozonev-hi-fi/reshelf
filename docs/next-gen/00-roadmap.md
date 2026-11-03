# 00 — Roadmap

Status: Draft | Version: 0.12 | Last updated: 2026-11-03

## Goal

Rewrite Reshelf from PowerShell scripts into a .NET application. The work moves in this order:

1. **Next-gen delta requirements**: the docs in this folder.
2. **To-be BR**: business requirements of the new app, built from the current behavior plus this delta.
3. **Technical specification** with ADRs.
4. **Implementation tasks**, ready for real work.

Each phase runs in its **own Claude session** with a clean context. Each session starts from its brief in [sessions/](sessions/).

## Phases

| Phase | What | Brief | Output | Status |
|---|---|---|---|---|
| A | Docs part A: general next-gen ideas | — (done in the grilling session) | This doc set, commit 1 | Done |
| B | Docs part B: paths twist | [part-b-paths.md](sessions/part-b-paths.md) | [11-paths-and-devices.md](11-paths-and-devices.md) filled in, `→ Part B` markers resolved, commit 2 | Done |
| 0 | Move legacy code to `legacy/` and freeze it | [phase-0-legacy-move.md](sessions/phase-0-legacy-move.md) | `legacy/` runnable and frozen | Done |
| 1 | BR from docs and tests (as-is) | [br-from-docs.md](sessions/br-from-docs.md) | [br/as-is-from-docs/](br/as-is-from-docs/README.md): 744 `AS-DOC-*` requirements, suspected defects, coverage | Done |
| 2 | BR from code (as-is) | [br-from-code.md](sessions/br-from-code.md) | [br/as-is-from-code/](br/as-is-from-code/README.md): 676 `AS-CODE-*` requirements, suspected defects, coverage | Done |
| 3 | Merge the two as-is BRs, resolve contradictions | [br-as-is-merge.md](sessions/br-as-is-merge.md) | `br/as-is-merged/`: reconciled `AS-<AREA>-NNN` requirements; contradictions resolved; suspected defects consolidated but not yet decided | Done |
| 4 | Apply the NG vision to the merged as-is BR | [br-apply-ng-vision.md](sessions/br-apply-ng-vision.md) | `br/to-be/`: to-be BR, validated item by item and Agreed; every suspected defect decided keep/fix/drop; NG delta 01-11 applied; NG open points resolved; coverage checked both directions (`92-coverage.md`); legacy as-is docs archived | In progress |
| 5 | Technical specification + ADRs | [tech-spec.md](sessions/tech-spec.md) | Tech spec (Agreed), ADRs | Not started |
| 6 | Task breakdown | defined at the end of phase 5 | Implementation tasks and milestones | Not started |

### Phase 4 input: real-world library maps

[`tools/library-mapper/`](../../tools/library-mapper/docs/00-overview.md) generates a structured
map of a real music library (tags, companion files, recognition flags) without ever writing to
the scanned storage. Two maps exist locally — `before` (not organized by legacy) and `after`
(organized by legacy) — plus, once the matching/verification procedure has been run over them, a
match report pairing before/after releases. All of it lives under `local/` at the repo root
(gitignored, never committed): `local/maps/before.library-map.json`,
`local/maps/after.library-map.json`, `local/matches/<run-id>/match-report.json`.

Phase 4 must use these, where present, as real-world evidence:
- as test cases for the MAT / area 07 matching logic (`br/as-is-merged/07-proposal-matching.md`,
  and the library index in `08-proposal-naming-and-tags.md`, area PRP) — a real "before" folder messy enough to need manual help, paired with its correct
  "after" release, is exactly the kind of case next-gen's matching should be checked against;
- as corroborating evidence when deciding a suspected defect's disposition (keep/fix/drop) —
  `discogsVerification` in the match report can confirm a wrong match, a typo, or a wrong year that
  was approved without being noticed.

If the maps are missing or stale, regenerate per
[`tools/library-mapper/docs/02-generating-a-map.md`](../../tools/library-mapper/docs/02-generating-a-map.md)
before relying on them. The drive letters a contributor's library lives under (e.g. `D:`, `F:`)
are not fixed — they depend on which USB port a portable drive is connected to, and must be
re-confirmed each time, not assumed from an earlier session.

### Exit criteria

| Phase | Done when |
|---|---|
| A | Every decision D1–D48 maps to a requirement or a doc section. Links resolve. Committed. |
| B | The paths model has been grilled with the user and written down. No `→ Part B` marker is left open. Lossy-ledger path conversion is defined. Committed. |
| 0 | Legacy code is in `legacy/`. The Pester suite passes from the new location. A freeze notice is in place. Committed. |
| 1 | Every legacy feature in MANIFESTO, `legacy/README.md`, `legacy/plan/`, `legacy/schemas/` and tests is described as behavior, with acceptance examples. Suspected defects are listed separately. |
| 2 | Every legacy module is described as behavior, written from the code only, without reading the phase 1 output. Suspected defects are listed separately. |
| 3 | Every area's AS-DOC vs AS-CODE comparison is done. Every contradiction (within AS-DOC, or newly found between AS-DOC and AS-CODE) is resolved, with the user where still unclear after checking code/tests. Suspected defects are consolidated and cross-referenced in one carry-forward list, not yet decided. The user confirms `br/as-is-merged/`. |
| 4 | Every suspected defect is decided (keep, fix, or drop). The to-be BR = merged as-is + this delta. Every NG delta requirement (01-11) is applied. Every open point left by the delta docs is resolved. Every to-be requirement has a validation verdict in `93-validation-log.md`, with no gaps left in `92-coverage.md`. The user marks it `Agreed`. Legacy as-is BR docs (`as-is-from-docs/`, `as-is-from-code/`, `as-is-merged/`) are archived or marked superseded once `br/to-be/` is Agreed. |
| 5 | Every to-be requirement maps to a tech-spec section. Every dependency has an ADR. The user marks it `Agreed`. Built only from `br/to-be/` — no direct read of the archived as-is docs. |
| 6 | Every tech-spec section maps to tasks. Each task has acceptance criteria and a test approach. |

## Working rules for all phases

- **Rule D2**: phases 1 and 2 describe the **current** behavior only. They never fix it. A suspected bug is written as "suspected defect". Phase 4 decides what happens to it.
- **Rule D9**: from Phase 0 on, the legacy app is **frozen**, even for bug fixes. Only the new app is used from then on, even in alpha or beta.
- Use the **dotnet skills plugin** for analysis, planning and implementation in phases 5 and 6 and during implementation (RAW).
- Follow the [doc rules](README.md#doc-rules) in every phase.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-04 | Initial roadmap (Docs part A). |
| 0.2 | 2026-10-04 | Phase B done: paths model in doc 11, decisions D49–D63. |
| 0.3 | 2026-10-04 | Phase 0 done: legacy code moved to `legacy/` and frozen. |
| 0.4 | 2026-10-05 | Phase 1 done: as-is BR from docs and tests in `br/as-is-from-docs/`. Format decision D64. |
| 0.5 | 2026-10-10 | Phase 2 done: as-is BR from code in `br/as-is-from-code/`. |
| 0.6 | 2026-10-10 | Phase 3 split into "merge as-is" (factual reconciliation, phase 3) and "apply NG vision" (forward decisions, defect disposition, to-be BR, now phase 4). Tech spec and task breakdown renumbered to phases 5 and 6. |
| 0.7 | 2026-10-10 | Phase 3 status corrected to "In progress": `br/as-is-merged/` has real, committed partial work (areas 00/01 done, 3 trackers in progress). |
| 0.8 | 2026-10-11 | Added "Phase 4 input: real-world library maps" — `tools/library-mapper/` output under `local/` must be used as real-world test cases for MAT/area 07 and for suspected-defect disposition. |
| 0.9 | 2026-10-14 | Phase 3 done: `br/as-is-merged/` Agreed by the user — all 14 areas + contradictions/suspected-defects/coverage complete. |
| 0.10 | 2026-11-03 | Phase 4 prep (D67): added the item-by-item validation step and the coverage check to phase 4's output and exit criteria. |
| 0.11 | 2026-11-03 | Phase 4 started: Part 1 session 0 created `br/to-be/README.md` (D68). Phase 4 status set to "In progress". |
| 0.12 | 2026-11-03 | Consistency review: phase 4 input section points to the real as-is files (`07-proposal-matching.md`, `08-proposal-naming-and-tags.md`) instead of the non-existent `07-library-and-quality.md`. |
