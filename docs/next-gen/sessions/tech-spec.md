# Brief — Phase 4: technical specification and ADRs

Roadmap phase: 4 | Output: `docs/next-gen/tech-spec/` and `docs/next-gen/adr/NNNN-*.md`, status Agreed

## Goal

Turn the agreed to-be BR into a technical specification of the .NET solution, and decide every technology choice in an ADR.

## Read first

- [../README.md](../README.md): the doc rules.
- The to-be BR (`docs/next-gen/br/to-be.md`).
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
6. Write the brief for phase 5 (task breakdown).

## Done when

- Every to-be requirement maps to a tech-spec section.
- Every dependency has an accepted ADR.
- The user has agreed.
