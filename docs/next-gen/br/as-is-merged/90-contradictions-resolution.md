# 90 — Contradictions, resolved (Phase 3)

Status: Draft | Version: 0.4 | Last updated: 2026-10-11

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

### Found while merging SET: AS-CODE-DAT-024 vs AS-DOC-SET-047 — Does `Protect-ReshelfSecret` accept an empty string?

`AS-CODE-DAT-024`, already merged as `AS-DAT-092`, said "An empty-string
secret is explicitly allowed as input" (based on the `[AllowEmptyString()]`
parameter attribute on `Protect-ReshelfSecret`). `AS-DOC-SET-047`, sourced
from `legacy/tests/Reshelf.Common.Tests.ps1`, says encrypting an empty text
is an error.

Re-read `legacy/scripts/common/Reshelf.Common.psm1:561-573`
(`Protect-ReshelfSecret`) and the test at
`legacy/tests/Reshelf.Common.Tests.ps1:511-516`: `[AllowEmptyString()]` only
stops PowerShell's *parameter binder* from rejecting an empty argument
before the function runs. The function body still calls
`ConvertTo-SecureString -String $PlainText -AsPlainText -Force`, and that
cmdlet itself throws for an empty plain text — a real `ConvertTo-SecureString`
restriction, not a Reshelf-specific check (the test's own comment says so).
The test proves it: `{ Protect-ReshelfSecret -PlainText '' } | Should -Throw`.

**Resolved: AS-DOC-SET-047 is factually right.** `Protect-ReshelfSecret`
always throws for an empty string; the parameter attribute only affects
whether the *call* is allowed to be made, not whether it succeeds.
`AS-DAT-092`'s text is corrected in `01-data-and-storage.md` (version 0.2)
to remove the wrong claim and state the actual behavior, matching
`AS-DOC-SET-025`'s note that callers must check for an empty/skipped token
themselves before ever calling `Protect-ReshelfSecret`.

## TXT

### New: AS-DOC-TXT-045 vs the `recognizedReleaseType` schema enum — Is "SP" a real release type?

`AS-DOC-DEF-009` flags that MANIFESTO §4.3 lists the release types album
(LP), EP, SP, single and maxi single, while the `recognizedReleaseType` enum
has no `sp` value.

Re-read `legacy/schemas/proposal.schema.json:80` and
`legacy/schemas/recognition.schema.json:74`: both enums are exactly
`["album", "mini-album", "ep", "single", "maxi-single", "lp", null]` — no
`sp`.

**Resolved: both are right, at different levels.** MANIFESTO's listing is a
business-level category (SP is, historically, a Japanese single release),
not a literal enum value. The schema has no separate `sp` value because the
app classifies an SP release under `single`. No change needed beyond a
clarifying note in the merged text — see `AS-TXT-045`.

### Carried from phase 1: `AS-DOC-DEF-010` (tags "must match" names, but names are sanitized/shortened)

Re-checked against the merged TXT content: `AS-TXT-072` already states that
sanitizing touches only `artistFolderName`/`releaseFolderName`/
`proposedFileName`, never `tags.*`; `AS-CODE-TXT-016`–`019` (the
`ConvertTo-SafeFileName` facts) describe sanitation as a name-only operation,
with nothing in the code-only view touching tag values. No new evidence
contradicts phase 1's resolution (plan 03 is right: tags keep the raw text,
only names are made safe and can be shortened). No change to the merged
content; recorded here only for traceability.

### Carried from phase 1: `AS-DOC-DEF-011` (MANIFESTO "cue file must be deleted" vs read-only source)

Re-checked: the TXT code-only view (`Reshelf.Common.psm1`) has no function
that deletes anything — consistent with the already-merged `AS-DAT-044`
(source files are always read-only, copy mode only). Phase 1's resolution
stands: the final structure simply never gets a copy of the `.cue` file;
nothing is deleted. No change to the merged content.

### Carried from phase 1: `AS-DOC-DEF-013` (wording-only: "renumbered continuously across discs")

Re-checked: this was already fully resolved within phase 1 itself — all
sources agree on both numbers (the zero-padded file number keeps counting
across discs; the `Track` tag restarts at 1 per disc), and only one plan
file's wording was ambiguous. The TXT code-only view adds nothing new (file
numbering across discs is computed by propose/matching, outside
`Reshelf.Common.psm1`). No change to the merged content.

## SET

### Carried from phase 1: `AS-DOC-DEF-014` (README "settings init" still offers "copy or move")

Re-read `legacy/scripts/common/Reshelf.Settings.psm1:92-142`
(`Initialize-ReshelfSettings`) and `:197-251` (`Set-ReshelfSettings`):
neither function ever prompts for the copy mode, and both reject any value
other than `copy` with a message naming `move` as "no longer supported".
Confirms phase 1's resolution: the README's "Copy mode: copy or move" line
(One-time setup) is a stale remnant contradicting the rest of the same
README, the plan, and the tests. No change to the merged `AS-SET-*` content.

### Carried from phase 1: `AS-DOC-DEF-015` (when is target-root write access checked?)

Re-read `Get-ReshelfSettings` (`Reshelf.Settings.psm1:62-90`): it never calls
`Assert-ReshelfPathWritable`. The check only runs in
`Initialize-ReshelfSettings` and in `Set-ReshelfSettings` when `Key -eq
'targetRoot'`. Confirms phase 1's resolution: the README and tests ("on
set/init") are right; plan 04's "at settings load time" is wrong. No change
to the merged content (`AS-SET-031`, `AS-SET-040`).

### Carried from phase 1: `AS-DOC-DEF-016` (documented default of targetRoot vs the schema)

Re-read `legacy/config/settings.default.json` (`"targetRoot": ""`) and
`legacy/schemas/settings.schema.json` (`targetRoot` has `minLength: 1`) and
`Initialize-ReshelfSettings`: `targetRoot` is one of the five fields always
overwritten before a settings file is ever saved (`AS-SET-049`), and the
function throws before saving if it would still be empty (`AS-SET-019`,
`AS-SET-022`). **Resolved: both are right, at different levels.** The
template's `""` is a placeholder that is never actually persisted; the
schema's `minLength: 1` is the real invariant for any settings file that
exists on disk, and it always holds. The README's "default" column is
imprecise (there is no real usable default for a required field) but not a
behavioral defect. No change to the merged content beyond this note.

### Found while merging SET: AS-CODE-DAT-024 vs AS-DOC-SET-047

See the entry under **DAT** above — discovered while merging this area, but
the correction applies to the already-merged `AS-DAT-092`.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-10 | Started. Area GEN: no contradiction owned by this area. |
| 0.2 | 2026-10-10 | Area DAT: one new contradiction found and resolved (`AS-DAT-005`, data-home writability — AS-CODE right). Four phase-1 contradictions (`AS-DOC-DEF-002`–`005`) re-verified against the actual schema files and confirmed already correctly resolved. `AS-DOC-DEF-111` noted as Cross-cutting, not DAT-owned. |
| 0.3 | 2026-10-11 | Area TXT: one new contradiction found and resolved (`AS-DOC-DEF-009`, MANIFESTO "SP" vs the `recognizedReleaseType` enum — both right, at different levels). Three phase-1 contradictions (`AS-DOC-DEF-010`, `011`, `013`) re-verified against the code-only view and schema/DAT cross-references, confirmed already correctly resolved. |
| 0.4 | 2026-10-11 | Area SET: three phase-1 contradictions (`AS-DOC-DEF-014`–`016`) re-verified against the code and confirmed already correctly resolved. One new contradiction found in already-merged DAT content (`AS-CODE-DAT-024` vs `AS-DOC-SET-047` — `Protect-ReshelfSecret` does not actually accept an empty string) and corrected retroactively in `01-data-and-storage.md`. |
