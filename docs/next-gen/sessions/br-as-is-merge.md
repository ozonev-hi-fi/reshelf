# Brief — Phase 3: merge the two as-is BRs, resolve contradictions

Status: Draft | Version: 0.2 | Last updated: 2026-10-10

Roadmap phase: 3 | Output: `docs/next-gen/br/as-is-merged/`, status Agreed (as a reconciled as-is record)

## Goal

Produce one reconciled as-is BR (`br/as-is-merged/`) by comparing `br/as-is-from-docs/` (phase 1) and `br/as-is-from-code/` (phase 2) area by area, resolving every contradiction, and consolidating suspected defects into one carry-forward list for phase 4 — without deciding their disposition and without touching the NG delta docs.

This phase only establishes facts about the legacy app's current behavior. It does not decide what the new app should do. That is phase 4 ([br-apply-ng-vision.md](br-apply-ng-vision.md)).

## Read first

- [../README.md](../README.md): the doc rules.
- The phase 1 and phase 2 outputs in `docs/next-gen/br/`: [br/as-is-from-docs/](../br/as-is-from-docs/README.md) and [br/as-is-from-code/](../br/as-is-from-code/README.md).

## Steps

1. Compare the two as-is BRs area by area. Build a table per area: agree / only in docs / only in code / conflict.
2. For each conflict, re-read the code, tests and docs needed to understand it. If it is still unclear after that check, ask the user. Use the `grilling` skill and ask in rounds.
3. Also pull in the existing `AS-DOC-DEF-*` contradiction entries (not suspected defects) and resolve those the same way.
4. Consolidate all `AS-DOC-DEF-*` and `AS-CODE-DEF-*` suspected-defect entries (not contradictions) into one de-duplicated, cross-referenced carry-forward list, explicitly marked "disposition deferred to phase 4". Do not decide keep, fix or drop here.
5. Write the reconciled area files with a new ID scheme `AS-<AREA>-NNN` (no `Priority` field — this is still a fact, not a decision). Each requirement's `Source:` line cites every `AS-DOC-*`/`AS-CODE-*` ID it reconciles.
6. Build a coverage file mapping every `AS-DOC-*`/`AS-CODE-*` ID to its `AS-<AREA>-NNN`.
7. Ask the user to review the merged folder. They mark `br/as-is-merged/README.md` Agreed.
8. Update the roadmap status and the changelogs. Commit.

## Done when

- No open contradiction is left.
- Every suspected defect is in the carry-forward list (none silently dropped).
- Every `AS-DOC-*`/`AS-CODE-*` ID is traceable in the coverage file.
- The user has marked `br/as-is-merged/README.md` Agreed.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-04 | Initial brief for phase 3 ("merge into the to-be BR"). |
| 0.2 | 2026-10-10 | Renamed from `br-merge.md`. Scoped to factual reconciliation only (phase 3). Forward design decisions — applying the NG delta, deciding suspected defects, resolving NG open points, marking a to-be BR Agreed — moved to the new phase 4 brief [br-apply-ng-vision.md](br-apply-ng-vision.md). |
