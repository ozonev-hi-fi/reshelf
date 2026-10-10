# Brief — Phase 5: technical specification and ADRs

Status: Draft | Version: 0.2 | Last updated: 2026-10-10

Roadmap phase: 5 | Output: `docs/next-gen/tech-spec/` and `docs/next-gen/adr/NNNN-*.md`, status Agreed

## Scope

This phase is built **only** from `docs/next-gen/br/to-be/` (the Agreed to-be BR produced by phase 4). Do **not** read `br/as-is-from-docs/`, `br/as-is-from-code/` or `br/as-is-merged/` — those are legacy-analysis inputs already folded into the to-be BR and archived by the end of phase 4.

## Goal

Turn the agreed to-be BR into a technical specification of the .NET solution, and decide every technology choice in an ADR.

## Read first

- [../README.md](../README.md): the doc rules.
- The to-be BR (`docs/next-gen/br/to-be/`).
- [../10-platform-and-dependencies.md](../10-platform-and-dependencies.md): the dependency rule NG-PLT-004 and the known ADR candidates.
- The legacy code, for the algorithms (recognition heuristics, Discogs matching, cue splitting).

## Steps

1. Use the **dotnet skills plugin** for analysis and design.
2. Write ADRs, one per decision ([template](../adr/0000-template.md)). At least:
   - UI technology: Blazor vs controllers + static site vs MAUI (NG-APP-008). User preference: controllers over minimal APIs.
   - Tag reading and writing.
   - Cue split, with lossless output.
   - Image resize and inspection.
   - SQLite access and migrations.
   - Bandcamp feasibility spike (NG-PRV-009).
   - Solution structure (projects, shared core for CLI + UI).
3. Write the tech spec:
   - architecture;
   - data model (layers, candidates, snapshots, statuses, reference data);
   - the API between the UI and the core;
   - CLI commands;
   - a test strategy that reuses the legacy fixtures where useful.
4. Make a traceability table: to-be requirement → tech-spec section.
5. Ask the user to review. Set the status to `Agreed` after they agree. Commit.
6. Write the brief for phase 6 (task breakdown).

## Done when

- Every to-be requirement maps to a tech-spec section.
- Every dependency has an accepted ADR.
- The user has agreed.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-04 | Initial brief for phase 4 (technical specification and ADRs). |
| 0.2 | 2026-10-10 | Added a scope note: built only from `br/to-be/`, no direct read of the archived as-is docs. Renumbered from phase 4 to phase 5 (phase 3 split into phases 3/4; task breakdown is now phase 6). |
