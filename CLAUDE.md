# Reshelf

Personal music-collection organizer. Two generations live in this repo:

- **Legacy**: the working PowerShell app (`scripts/`, `ui/`, `tests/`, `schemas/`, `config/`, `plan/`). After roadmap Phase 0 it lives in `legacy/` and is **frozen**: no features, no bug fixes. It serves as executable reference for the rewrite.
- **Next-gen**: the .NET rewrite, specified in `docs/next-gen/`. Goals and rules shared by both generations: `MANIFESTO.md`.

## Next-gen docs

Before you create or change anything under `docs/next-gen/` (requirements, roadmap, ADRs, session briefs), read `docs/next-gen/README.md` and follow its doc rules. When you finish a piece of next-gen work, update the affected docs' status, version, changelog and cross-links before you commit.

To start a planned session, open its brief in `docs/next-gen/sessions/`.
