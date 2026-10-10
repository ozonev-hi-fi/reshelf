# Brief — Phase 4: apply the NG vision to the merged as-is BR

Status: Draft | Version: 0.1 | Last updated: 2026-10-10

Roadmap phase: 4 | Output: `docs/next-gen/br/to-be/`, status Agreed

## Goal

Apply the NG vision (delta docs 01-11, decisions D1-D65+) onto the reconciled as-is BR (`br/as-is-merged/`, phase 3's output) to produce the to-be BR. Decide every suspected defect's disposition. Resolve the NG delta docs' open points.

This is where forward design decisions get made. Phase 3 ([br-as-is-merge.md](br-as-is-merge.md)) only established facts about the legacy app's current behavior; it did not decide anything about the new app.

## Read first

- [../README.md](../README.md): the doc rules.
- `docs/next-gen/br/as-is-merged/` (phase 3 output): the reconciled `AS-<AREA>-NNN` requirements and the suspected-defect carry-forward list.
- The delta docs [01](../01-vision-scope.md)–[11](../11-paths-and-devices.md).
- The decision log in [../inbox/raw-notes.md](../inbox/raw-notes.md).

## Steps

1. For each area, take the reconciled `AS-<AREA>-NNN` requirements and find which NG delta requirements (01-11) touch it.
2. For each suspected defect in `br/as-is-merged/91-suspected-defects-carryforward.md`, decide with the user: keep, fix, or drop. Use the `grilling` skill and ask in rounds.
3. Apply the delta. Each relevant NG requirement replaces or extends the matching as-is requirement. Every to-be requirement links to its sources (`AS-<AREA>` / original `AS-DOC` / `AS-CODE` / NG IDs).
4. Resolve the open points the delta docs left for the merge:
   - NG-LIB-003 (incremental rescan) in [07-library-and-quality.md](../07-library-and-quality.md);
   - the NG-APP open point (long-operation progress/cancel) in [02-app-shape.md](../02-app-shape.md);
   - the NG-PLT open point (cue-split bit-exactness) in [10-platform-and-dependencies.md](../10-platform-and-dependencies.md).
5. Ask the user to review the to-be BR. Mark it Agreed only after they agree.
6. Once Agreed, archive `br/as-is-from-docs/`, `br/as-is-from-code/` and `br/as-is-merged/`: move them under a new `br/archive/` folder, or add a clear "Superseded by br/to-be/. Kept for reference only." notice to the top of each folder's README. This leaves the tech-spec phase (5) with exactly one requirements source to read.
7. Update the roadmap status and the changelogs. Commit.

## Done when

- No undecided suspected defect is left.
- Every NG requirement (01-11) appears in the to-be BR.
- Every named open point is resolved.
- The user has marked `br/to-be/` Agreed.
- The legacy as-is docs are archived or marked superseded.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-10 | New brief for phase 4, split out of the former phase 3 brief (`br-merge.md`, now `br-as-is-merge.md`, scoped to reconciliation only). Covers the forward design decisions: defect disposition, NG delta application, open-point resolution, to-be BR, archiving the legacy as-is docs. |
