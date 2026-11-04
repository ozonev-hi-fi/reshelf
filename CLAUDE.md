# Reshelf

Project-wide guidance for working on this repo. Local, sensitive, or
not-for-public-history notes live in the gitignored `CLAUDE.local.md`
instead.

Personal music-collection organizer. Two generations live in this repo:

- **Legacy**: the working PowerShell app, in `legacy/` (`legacy/scripts/`, `legacy/ui/`, `legacy/tests/`, `legacy/schemas/`, `legacy/config/`, `legacy/plan/`). **Frozen**: no features, no bug fixes. It serves as executable reference for the rewrite.
- **Next-gen**: the .NET rewrite, specified in `docs/next-gen/`. Goals and rules shared by both generations: `MANIFESTO.md`.

## Next-gen docs

Before you create or change anything under `docs/next-gen/` (requirements, roadmap, ADRs, session briefs), read `docs/next-gen/README.md` and follow its doc rules. When you finish a piece of next-gen work, update the affected docs' status, version, changelog and cross-links before you commit.

To start a planned session, open its brief in `docs/next-gen/sessions/`.

## Talking to the user: no bare codes

This repo uses many short codes: requirement IDs (`AS-*`, `NG-*`, `TB-*`,
`CF-*`), area codes (GEN, REV, DSC, ...) and decision numbers (`D1`, `D2`, ...).
In every message to the user, give each code its meaning in words in the same
sentence. For a decision number, also link to its row in
`docs/next-gen/inbox/raw-notes.md` and give a one-line summary.
