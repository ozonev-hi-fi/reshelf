# Step 11 — Testing and Verification Strategy

## Purpose / scope

Define how each module gets tested, given there's no existing test
infrastructure yet. Covers unit tests, fixtures, and manual verification for
the one piece that can't be meaningfully unit-tested (the browser UI).

## Detailed design

### Unit tests (Pester 5)

Focus on pure, deterministic functions — the highest-value, cheapest tests:

- `ConvertTo-SafeFileName` — every case from
  [10-error-handling-and-edge-cases.md](10-error-handling-and-edge-cases.md)
  (invalid chars, trailing dot/space, reserved device names).
- `Test-IsReleaseFolder` / `Test-IsGroupingFolder` / `Test-IsCategorySubfolder` /
  `Test-IsBandMemberFolder` — one test per manifesto §1 pattern.
- Track-number regex parsing — numbered-with-dash, numbered-no-dash,
  no-number-at-all fallback.
- `stableKey` generation — same normalized input always produces the same
  key; different case/whitespace normalizes to the same key.
- Disc/track numbering math — continuous cross-disc filename numbering vs.
  per-disc-restarting `Track` tag, for a 3-disc fixture matching the
  manifesto §5 example table exactly.
- JSON schema round-trips: a `recognition.json` fixture, extended with
  proposal fields, validates against `proposal.schema.json` via `Test-Json`.

### Fixture source tree

`tests/fixtures/sample-source-tree/` — a small synthetic tree using 0-byte
dummy files with correct extensions (no real audio needed for structural
tests), covering every messy pattern named in the manifesto:

- A normal single-disc album.
- A multi-disc album (`CD 1`/`CD 2` subfolders).
- A single-file + `.cue` release.
- A grouping folder ("Godspeeds and their projects" style) with two real
  artist subfolders inside.
- A category subfolder (`EPs`/`Singles`/`Lives`) under a normal artist.
- A band-member folder nested inside a band folder (`David Byrne` inside
  `Talking Heads`).
- Loose companion files (letter-prefixed) and nested companion files.
- Tracks with no track number / no separator.
- A playlist file (`.m3u`) that must be ignored.
- A deeply nested path approaching the Windows path-length limit.
- A filename with invalid characters and a folder named `CON`.

`CON` and a deeply-nested near-path-limit tree aren't checked into the static
fixture tree above — Git for Windows can't index a folder literally named
`CON`, and `core.longpaths` makes a checked-in near-limit path fragile across
clones. Both are instead built at test time, in
`tests/Tagger.Recognition.Tests.ps1`. A filename with invalid characters can't
exist on a real Windows filesystem either; it's covered directly by
`ConvertTo-SafeFileName`'s own unit tests, and end-to-end (through a full
Recognition → EditProposal → Implementation run, not just the sanitizer in
isolation) via a mocked Discogs title in
`tests/Tagger.TagLibSharp.Integration.Tests.ps1`.

### Discogs mocking

`tests/fixtures/discogs-responses/` holds captured JSON for a handful of
real searches/releases. `Invoke-DiscogsRequest` is mocked in Proposal-module
tests (`Mock Invoke-DiscogsRequest { Get-Content $fixturePath | ConvertFrom-Json }`)
so tests never hit the real network or consume rate limit budget.

### Implementation module verification

1. Run with `-WhatIf` first — assert zero filesystem writes occurred
   (compare a before/after snapshot of every file's path, size and last-write
   time under the source root, data home and target root — `Get-TreeSnapshot`
   in `tests/Tagger.Implementation.Tests.ps1` and `tests/Tagger.Pipeline.Tests.ps1`;
   folders are deliberately left out of the snapshot, since a folder's own
   last-write time can tick forward on Windows for reasons unrelated to this
   tool, e.g. background indexing).
2. Run for real against a scratch temp target directory.
3. Verify the resulting layout and tags by re-opening each file fresh with
   **TagLibSharp** and checking the persisted values — this still catches a
   "the write silently didn't save" class of bug, but it's an honest
   trade-off, not the independent-tool check the plan originally described:
   now that both reading (05) and writing (08) go through the same library,
   this can't catch a systematic TagLibSharp bug the way reading back with a
   genuinely different tool would have. Accepted because it removes all
   manual setup for this step (see [08](08-implementation-module.md)).

   Step 3 lives in `tests/Tagger.TagLibSharp.Integration.Tests.ps1`, tagged
   `Integration`. Every other test file mocks `Set-TaggerAudioTags` /
   `Get-TaggerAudioTags`; this file is the only one that loads the real
   `TagLibSharp.dll` and calls a real `ffmpeg` to generate throwaway audio/cover
   media, then reads tags back with a fresh `[TagLib.File]::Create()` call. It
   needs both on the machine running the tests and **fails** (not skips) if
   either is missing — a missing DLL throws the same install hint
   `Import-TaggerTagLibSharp` gives; a missing `ffmpeg` throws directly. A
   silent skip would let this coverage gap reopen unnoticed, so this is an
   intentional hard requirement, not an oversight.

### Golden files for the whole fixture tree

`tests/Tagger.Pipeline.Tests.ps1` also compares the full `recognition.json`,
`proposal.json`, and the target folder layout from a real
`-IncludeUnresolved` apply, against reviewed golden files in
`tests/fixtures/expected/`. The per-pattern assertions already in that file
stay as readable documentation of intent; the golden files are what actually
pin down the exact output for every planted pattern (the Definition of Done
below).

Run-specific values (the three per-test `$TestDrive` roots, the date-based
session id, the `generatedAtUtc` timestamp) are normalized to fixed
placeholders (`<SOURCE_ROOT>`, `<TARGET_ROOT>`, `<DATA_HOME>`,
`<SESSION_ID>`, `<GENERATED_AT>`) before comparing, so the golden files
themselves stay stable across machines and runs.

To regenerate after a deliberate behavior change: run the tests once with
`$env:TAGGER_UPDATE_GOLDEN = '1'`, then review the diff with `git diff`
before committing it — a regenerated golden file is only as correct as the
review it got. Two known non-determinism traps to watch for when
regenerating: a plain `@{ ... }` hashtable literal serializes to JSON with a
process-random key order (fixed once already, in `Tagger.Recognition.psm1`'s
`existingTags`, by using `[pscustomobject]@{ ... }` instead — the same
pattern every other record in this codebase already uses); and comparing
folder timestamps (not just file timestamps) in a tree snapshot is flaky on
Windows for the same background-indexing reason noted above.

### UI verification

No automated browser test suite for v1 — Playwright/similar is explicitly
optional/stretch, not required. Instead, a manual checklist run in Chrome,
tracked in [tests/manual/ui-checklist.md](../tests/manual/ui-checklist.md):

1. Open a session folder via the picker.
2. Edit a proposed release/track name.
3. Change the selected cover-art candidate.
4. Resolve an ambiguous Discogs match by picking a candidate.
5. Approve a release.
6. Save, reload the page, confirm all edits persisted in `proposal.json`.
7. Confirm `proposal.backup.json` holds the pre-save version.
8. Revoke folder permission mid-session (via browser UI) and confirm the app
   shows a retry prompt instead of a silent failure.

## Decisions & rationale

- **Pure-function unit tests over integration tests as the default**: the
  messy-folder heuristics and numbering math are exactly the places a subtle
  bug would silently corrupt a personal music collection — cheap to test in
  isolation, expensive to debug after the fact against real files.
- **Re-verify by reading the file back, not by trusting a save call's success**:
  reading tags back with TagLibSharp after writing them catches a class of
  bug where `.Save()` returns without error but the persisted values are
  wrong. This is weaker than an independent-tool check (both directions now
  share one library, so a systematic TagLibSharp bug could pass both sides) —
  an explicit, accepted trade-off for a zero-manual-setup writer (see
  [08](08-implementation-module.md)).
- **No UI automation for v1**: proportionate effort for a personal tool used
  by one person — a documented manual checklist is enough, and can be
  revisited if the UI grows more complex.

## Test runner

`tests/Invoke-TaggerTests.ps1 [-SkipIntegration] [-Path <paths>]` wraps
`Invoke-Pester` with one convenience: `-SkipIntegration` excludes the
`Integration`-tagged tests in `tests/Tagger.TagLibSharp.Integration.Tests.ps1`
(via `Filter.ExcludeTag`), which need a real `TagLibSharp.dll` and a real
`ffmpeg` on the machine running the tests. Excluding the tag this way also
skips that file's top-level `BeforeAll` entirely — confirmed empirically,
not just assumed — so the "fail if the DLL/ffmpeg is missing" throws never
fire when the tag is excluded.

## Definition of done

- `Invoke-Pester` (or `tests/Invoke-TaggerTests.ps1`) runs green across all
  unit tests.
- The fixture source tree, run through the full pipeline end-to-end
  (`-WhatIf` then real), produces the exact expected `recognition.json` /
  `proposal.json` / target layout for every planted pattern — enforced by
  the golden-file comparison above, not just the schema/structure checks.
- The manual UI checklist has been run at least once and passed.
