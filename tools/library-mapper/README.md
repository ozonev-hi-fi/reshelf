# library-mapper

A tool for comparing two states of a music library — a "before" state (not
organized by the Reshelf app) and an "after" state (organized by it) — to:

1. Build real-world test cases for how the next-gen app should recognize
   releases in messy folders (feeds `docs/next-gen`'s not-yet-merged matching
   area, MAT / area 07).
2. Catch mistakes still sitting in the "after" state that were approved
   without being noticed (wrong Discogs match, typos, wrong year).

**Nothing about your actual music collection is ever committed.** Only the
mechanism (schemas, script, docs) lives here, tracked in git. Everything it
generates — maps, match reports — is written under `local/` at the repo root,
which is gitignored.

Start at [`docs/00-overview.md`](docs/00-overview.md).

## Layout

- `schemas/` — JSON Schema for the generated map (`library-map.schema.json`)
  and for a matching session's output (`match-report.schema.json`).
- `config/` — `settings.default.json` (tracked, no real paths) and, locally,
  a `settings.local.json` you create yourself (gitignored by the repo's
  existing `*.local.json` rule) with your real library paths.
- `scripts/` — `New-ReshelfLibraryMap.ps1`, the extraction script. Reuses
  `legacy/`'s existing recognition pipeline read-only; never modifies it.
- `docs/` — how to generate a map, the map schema reference, and the
  procedure a Claude session follows to do the actual before/after matching
  and Discogs re-verification (deliberately **not** a script — see
  [`docs/00-overview.md`](docs/00-overview.md) for why).
