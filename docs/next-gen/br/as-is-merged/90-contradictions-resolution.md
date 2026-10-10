# 90 — Contradictions, resolved (Phase 3)

Status: Draft | Version: 0.2 | Last updated: 2026-10-10

Every contradiction found while merging `as-is-from-docs/` and
`as-is-from-code/`: the pre-existing `AS-DOC-DEF-*` entries of type
"Contradiction" (found within the docs/tests set itself, phase 1), plus any
new contradiction found here between `AS-DOC-*` and `AS-CODE-*` (phase 1 vs
phase 2, which were written blind to each other). Each entry says which
source is factually right about current behavior, and why. This is a factual
record, not a design decision — see
[91-suspected-defects-carryforward.md](91-suspected-defects-carryforward.md)
for the (undecided) suspected defects, and phase 4 for what the new app
should do about any of this.

Filled in area by area, alongside the area files.

## GEN

None owned by this area. `AS-DOC-GEN-010` points at `AS-DOC-DEF-083`, which
is an APL-area contradiction (ffmpeg re-encoding) — resolved under APL when
that area is merged.

## DAT

### New: AS-DOC-DAT-005 vs AS-CODE-DAT-002 — Does the app check that the data home is writable?

`AS-DOC-DAT-005` (titled "The app creates the data home and checks that it
is writable") says the app both creates the missing folder and checks it is
writable. `AS-CODE-DAT-002`/`AS-CODE-DAT-003` describe `Resolve-ReshelfDataHome`
as creating the folder if missing and checking only that an existing path is
a directory — nothing about writability.

Re-read `legacy/scripts/common/Reshelf.Common.psm1:13-38`
(`Resolve-ReshelfDataHome`): the function creates the directory with
`New-Item -ItemType Directory -Force` when missing, and when the path
already exists it only verifies `Test-Path -PathType Container`. It never
attempts to write a probe file or otherwise test writability. Re-read the
source test, `legacy/tests/Reshelf.Common.Tests.ps1:25-33` ("creates and
returns a writable directory"): the *test itself* creates
`(Join-Path $result 'probe.tmp')` and asserts that doesn't throw — that is
the test's own sanity check on the test environment, not a verification the
production function performs.

**Resolved: AS-CODE-DAT-002/003 is factually right.** The app creates the
data home (or validates it is a directory) but does not itself check
writability; `AS-DOC-DAT-005`'s title overstated what `Resolve-ReshelfDataHome`
does, reading the test's own assertion as if it were app behavior. Merged as
`AS-DAT-005`, corrected.

### Carried from phase 1: `AS-DOC-DEF-002` to `AS-DOC-DEF-005` (plan vs schema/tests, within the docs set)

These four were already contradictions found and resolved inside phase 1
itself (`legacy/plan/03-domain-model-and-json-schemas.md` prose vs the actual
`schemas/*.json` files and their test fixtures), each already resolved in
favor of the schema/tests (source precedence: tests > README > plan). Verified
here by re-reading `legacy/schemas/settings.schema.json` and
`legacy/schemas/proposal.schema.json` directly — in every case the schema
file matches what the `AS-DOC-DAT-*` area file already describes, confirming
phase 1's resolution was correct. No change to the merged `AS-DAT-*` content;
recorded here only so the contradiction is traceable to its resolution.

- `AS-DOC-DEF-002` — Plan 03's `settings.json` example omits
  `discogsTokenEncrypted`, `ffmpegPath`, `taglibSharpPath`. Confirmed: the
  schema requires all 13 keys including these three (`AS-DAT-026`). Plan
  prose is stale; schema is right.
- `AS-DOC-DEF-003` — Plan 03's `recognition.json` example uses an old shape
  (`cueSheet` singular/nullable instead of `cueSheets` array; missing
  several required fields). Confirmed against `recognition.schema.json`'s
  `$defs.release`/`$defs.track` (`AS-DAT-035`, `AS-DAT-040`, `AS-DAT-044`):
  the schema is the array shape. Plan prose is stale; schema is right.
- `AS-DOC-DEF-004` — Plan 03 lists three `lossyLossless.action` values; the
  schema has five. Confirmed in `proposal.schema.json` (`AS-DAT-052`): five
  enum values plus the optional `previousLossy` block. Plan prose is stale;
  schema is right.
- `AS-DOC-DEF-005` — Plan 03 says it gives "the exact shape of every JSON
  document" but omits `discogsMatch.masterId`, `companionFile.include` and
  `companionFile.proposedFileName`. Confirmed present in
  `proposal.schema.json` (`AS-DAT-049`, `AS-DAT-057`). Plan prose is
  incomplete; schema is right.

### Noted, not owned by this area: AS-DOC-DAT-004 and AS-DOC-DEF-111

`AS-DOC-DEF-111` (Area: Cross-cutting) questions whether README/plan
wording about "repo root" paths — including the default data home "inside
the repo" — still makes sense after the Phase 0 move to `legacy/`. The
`AS-DOC-DAT-004`/`AS-CODE-DAT-001` merge in this file (`AS-DAT-004`) already
reflects the post-move reality (`legacy/.data`, two directories above
`Reshelf.Common.psm1`'s folder) — docs and code agree on the actual current
behavior, so there is no DAT-owned contradiction to resolve here. The
broader "is the README's wording now misleading" question is Cross-cutting
and is left for whichever merge pass owns that area.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-10 | Started. Area GEN: no contradiction owned by this area. |
| 0.2 | 2026-10-10 | Area DAT: one new contradiction found and resolved (`AS-DAT-005`, data-home writability — AS-CODE right). Four phase-1 contradictions (`AS-DOC-DEF-002`–`005`) re-verified against the actual schema files and confirmed already correctly resolved. `AS-DOC-DEF-111` noted as Cross-cutting, not DAT-owned. |
