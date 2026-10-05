# Brief — Phase 1: as-is BR from docs and tests

Roadmap phase: 1 | Output: `docs/next-gen/br/as-is-from-docs.md` (one file, or a folder if it gets large)

## Goal

Describe the **current** behavior of the legacy app as business requirements. Use only its documents and its tests.

## Rules

- **Rule D2**: describe behavior only. Do not fix it and do not add next-gen ideas. When something looks wrong or contradictory, write it under "Suspected defects" with its source.
- Do not read the legacy source code (`legacy/scripts`, `legacy/ui`). Phase 2 does that independently. Tests are allowed, because they describe expected behavior.
- Follow the [doc rules](../README.md#doc-rules). Use the ID prefix `AS-DOC-<AREA>-NNN`.

## Inputs

- `MANIFESTO.md`
- `legacy/README.md`
- `legacy/plan/*.md`. Note that some plan files describe superseded designs. The README lists the differences.
- `legacy/schemas/*.json`
- `legacy/tests/**` (Pester and Playwright), and the fixtures in `legacy/tests/fixtures/`

## Steps

1. List the functional areas: settings, recognition, proposal/Discogs, review UI, apply, lossy tracking, sessions, CLI.
2. For each area, write the requirements with acceptance examples. Take the examples from the tests and fixtures where possible, and name the test as the source.
3. Collect the suspected defects and the contradictions between sources.
4. Update the roadmap status. Commit.

## Done when

Every test file (`Describe` block) and every README section maps to at least one requirement or one suspected defect.
