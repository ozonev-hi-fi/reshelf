# Brief — Phase 0: move the legacy code and freeze it

Roadmap phase: 0 | Output: `legacy/`, runnable and frozen

## Goal

Move the PowerShell app into `legacy/`. Keep it working as executable reference. Freeze it (D9).

## Read first

- [../README.md](../README.md): the doc rules.
- [../00-roadmap.md](../00-roadmap.md): working rules D2 and D9.
- The repo `README.md`: how the legacy app runs and how its tests run.

## Steps

1. Move these into `legacy/` with `git mv`, so history is kept: `scripts/`, `ui/`, `tests/`, `schemas/`, `config/`, `plan/`, `README.md`, `testResults.xml`.
2. Keep at the root: `MANIFESTO.md`, `CLAUDE.md`, `docs/`, `.gitignore`, `.claude/`.
3. Fix the internal paths, so the legacy app and its tests still run from `legacy/`. Check at least:
   - repo-root detection;
   - the default data home (`.data/`, `RESHELF_HOME`);
   - the `.env` lookup;
   - test paths;
   - Playwright config.

   Decide with the user whether `.data/` stays at the root or moves too.
4. Run `pwsh legacy/tests/Invoke-ReshelfTests.ps1`. The suite must pass, as it did before the move. Also run the UI suite if it is set up.
5. Add a freeze notice to the top of `legacy/README.md`: "Frozen since <date>. No features, no bug fixes. Reference for the next-gen rewrite."
6. Update the paths in `CLAUDE.md`. Update the phase 0 status in `00-roadmap.md`.
7. Commit on `develop`.

## Done when

- The legacy test suite passes from `legacy/`.
- The freeze notice is in place.
- No doc links point to the old paths.
