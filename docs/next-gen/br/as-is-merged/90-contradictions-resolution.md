# 90 — Contradictions, resolved (Phase 3)

Status: Draft | Version: 0.7 | Last updated: 2026-10-11

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

## SES

### Carried from phase 1: `AS-DOC-DEF-017` (a session is "recognized" from the moment it is created, not when recognition finishes)

Re-read `legacy/scripts/common/Reshelf.Settings.psm1:253-307`
(`New-ReshelfSession`): `stage = 'recognized'` is hardcoded in the record
built right after the session directory is allocated (AS-SES-006/007) —
there is no later step that runs recognition first and only then sets the
stage. Confirms phase 1's resolution: the tests and the area file are right;
plan 04's "once step 5 finishes" is stale.

The design consequence plan 04's wording was dancing around — a session
whose recognition step then fails or is interrupted is stage-indistinguishable
from one that recognized cleanly, since there is no "recognition
running"/"recognition failed" stage — is already captured as `AS-DOC-DEF-104`
(Area: CLI, not yet merged); it is not duplicated here, since it is not a
SES-owned fact to resolve, only a related suspected defect for the CLI merge
pass to carry forward. No change to the merged `AS-SES-*` content beyond
stating the resolved fact plainly in `AS-SES-009`.

## REC

### Carried from phase 1: `AS-DOC-DEF-018` (plan's release-folder definition is narrower than tests/code)

Re-read `legacy/scripts/common/Reshelf.Recognition.psm1:52-81`
(`Test-IsReleaseFolder`): a folder qualifies with direct audio
(`AS-REC-013`), or with no direct audio but at least one disc-named
subfolder holding audio (`AS-REC-015`) — nothing in the code requires
"sequential-looking numbering" or restricts the folder name's own shape.
**Resolved: tests/code are right.** Plan 05's definition ("looks like `yyyy
Name` or `Name`, directly contains audio files with sequential-looking
numbering") is stale — it misses the disc-subfolder-only release
(`Wrapper Band\2004 - LP Reissue`) and the unnumbered-files release
(`Unnumbered\2015 No Numbers`), both of which tests and code agree are
releases. Merged as `AS-REC-013`–`016`, following tests/code.

### Carried from phase 1: `AS-DOC-DEF-019` (several plan documents still describe the removed `overrides.json` design)

Re-read `Reshelf.Recognition.psm1` in full: no function reads, writes or
references an `overrides.json` file anywhere. Grouping folders are walked
automatically (`Invoke-ReshelfFolderWalk`'s `'grouping'` case,
`legacy/scripts/common/Reshelf.Recognition.psm1:1433-1444`), every release
found this way forced into review via `grouping-folder-auto-resolved` —
there is no branch that instead writes an unrecognized entry with reason
`grouping-folder-suspected` pending an override file. **Resolved:
README/tests/code are right — no override file exists anywhere in the
current implementation.** The plan texts (05, 07, 10, 12, 02) describing
`overrides.json` predate the pivot to auto-walking and were never updated;
no change to the merged `AS-REC-*` content beyond stating the current
behavior in `AS-REC-010` and `AS-REC-039`.

### Carried from phase 1: `AS-DOC-DEF-020` (category list: "configurable" or "fixed"?)

Re-read `Reshelf.Recognition.psm1:6` and `:83-94`
(`Test-IsCategorySubfolder`): the category names are a literal array,
`$script:ReshelfCategoryFolderNames = @('EPs', 'Singles', 'Lives', 'Live',
'Compilations', 'Bootlegs')`, matched case-insensitively against a fixed
`[string[]]` default parameter — there is no settings lookup anywhere in
the function. **Resolved: README/code are right — the list is fixed in
code, not configurable.** Plan 05's "a configurable list" and a test name's
"configured category names" describe how the list *reads*, not an actual
settings-driven feature; no corresponding key exists in the merged settings
area (`03-settings-and-secrets.md`) or its schema. Merged as `AS-REC-027`.

### Carried from phase 1: `AS-DOC-DEF-021` (plan's disc-folder pattern is narrower than tests/code)

Re-read `Reshelf.Recognition.psm1:18`: the actual pattern is
`(?i)^(CD|Disc|Disk|LP)[\s_]*#?\.?[\s_]*(\d+)([\s_.-]|$)` — it explicitly
allows `_` and accepts trailing text after the number when a separator
precedes it. Plan 05's `^(CD|Disc|Disk|LP)\s*#?\.?\s*(\d+)$` has neither.
**Resolved: tests/code are right.** Merged as `AS-REC-062`.

### Carried from phase 1: `AS-DOC-DEF-022` (plan's track-number patterns are fewer than tests/code)

Re-read `Reshelf.Common.psm1:329-347` (`ConvertFrom-ReshelfTrackFileName`,
documented from code as `AS-CODE-TXT-014`/`015`): besides the three dash/
space forms plan 05 lists, the function also accepts a bracketed number
(`[NNN]`/`(NNN)`, capped at 1-3 digits specifically so a 4-digit year in
parentheses is never misread), and always additionally tests the resulting
title for an `"Artist - Title"` shape. **Resolved: tests/code are right —
plan 05's list is incomplete.** Merged as `AS-REC-056`–`059`.

### Carried from phase 1: `AS-DOC-DEF-023` ("exactly one audio file and one .cue" (plan) vs more in tests/code)

Re-read `Reshelf.Recognition.psm1:351-365` (`Test-IsCueSheetRelease`,
still exactly one audio file) and `:321-349`
(`Get-ReshelfCueSheetPathForAudio`, name-matching with one or more cue
files) and `:367-409` (`Get-ReshelfFlatDiscCuePairs`, 2+ audio files each
with its own cue). **Resolved: both plan and tests/code are right, at
different levels — plan's "exactly one audio and one cue" correctly
describes the single-file cue-release shape's audio-file count
(`AS-REC-067`), but is wrong to generalize it to the cue-file count: an
extra, unused cue file for a different rip is tolerated as long as one cue
matches the audio file by name (`AS-REC-075`), and a second, entirely
different shape — flat multi-disc cue pairs, several audio files each with
its own cue, no disc folders at all — exists and plan 05 never mentions it
(`AS-REC-077`).** Merged as `AS-REC-067`, `075`, `077`–`079`.

### Carried from phase 1: `AS-DOC-DEF-024` (companion kind of `back.jpg`: "scan" (plan) vs "booklet" (tests))

Re-read `Reshelf.Recognition.psm1:606-635`
(`Resolve-ReshelfCompanionKind`): an image name is checked for `"photo"`
first, then `"booklet"`/`"back"`/`"insert"` → kind `booklet`; there is no
`"scan"` kind anywhere in the function. **Resolved: tests/code are right —
the kind is `booklet`** (matched via the file name `back`, not the folder
name `scans` — the inputs did not say which one decided it; the code shows
it is the file name). Merged as `AS-REC-081`.

### Carried from phase 1: `AS-DOC-DEF-025` ("empty release folder → no-audio-files" (plan) vs an entry at artist level (test))

Re-read `Reshelf.Recognition.psm1:821-876`
(`Resolve-ReshelfFolderKind`) and `:1299-1456`
(`Invoke-ReshelfFolderWalk`): the walk calls `Resolve-ReshelfFolderKind`
once per folder and, once a folder is classified `unrecognized`, never
descends into it to look for a more specific empty subfolder. **Resolved:
plan and tests/code are consistent, not contradictory, once "which level"
is explained by the walk's top-down short-circuiting** — recognize reports
the *outermost* folder that already has zero audio anywhere below it; for
`Empty Artist\2010 Nothing Here`, the top-level `Empty Artist` folder
itself fails every specific shape (not a release, not an album-wrapper, not
a grouping folder — only one subfolder, `AS-REC-037` needs two) and is
reported directly, without the walk ever separately visiting (or
reporting) `2010 Nothing Here`. Merged as `AS-REC-019`.

### Carried from phase 1: `AS-DOC-DEF-038` (plan 05's "Reading existing tags" is still an open recommendation re: TagLibSharp)

Re-read `legacy/README.md` › Requirements (lists `TagLibSharp.dll` as a
plain dependency) and `Reshelf.Recognition.psm1:725-781`
(`Get-ReshelfAudioTags`, built entirely on `[TagLib.File]::Create`).
**Resolved: README/code are right — TagLibSharp is the tool actually used.**
Plan 05's "a deviation from the user's mp3tag decision — please confirm" is
a stale open question; the decision was made and implemented. No change to
the merged content beyond stating the current behavior in `AS-REC-088`.

## DSC

### Carried from phase 1: `AS-DOC-DEF-039` (plan lists two token sources; tests/README/code have three)

Re-read `legacy/scripts/common/Reshelf.Discogs.psm1:12-70` (`Get-DiscogsToken`):
the function checks the environment variable, then `.env`, then
`settings.json`'s `discogsTokenEncrypted` — three sources, matching the
tests and the README's settings table, not plan 02's two. **Confirms phase
1's resolution: tests/README/code are right.** Merged as `AS-DSC-002`.

### Carried from phase 1: `AS-DOC-DEF-041` (the plan endpoint list is incomplete)

Re-confirmed: the Discogs client itself (`Invoke-DiscogsRequest`) is generic
over the path, so the endpoint catalog lives at the matching module's call
sites, not in this module. The fuller list the matching tests exercise
(`/database/search` with `type=master`/`type=artist`, `/masters/{id}`,
`/masters/{id}/versions`, `/artists/{id}`, `/artists/{id}/releases`) was
already folded into `AS-DOC-DSC-007` in phase 1. **Confirms phase 1's
resolution: tests are right, plan 02's list is incomplete.** No change
beyond restating it in `AS-DSC-007`.

### New, found while merging: the `.env` inline-comment rule is narrower in the phase-1 text than in the code

`AS-DOC-DSC-005` describes the unquoted-value rule as "removes an inline
comment (from ` #` to the end of the line) and the space before it" — a
precise description of the one test case available (`abc123 # personal
token`), but not of the actual mechanism.

Re-read `Reshelf.Discogs.psm1:50-56`: for an unquoted value, the code finds
the **first** `#` anywhere in the raw value (`$rawValue.IndexOf('#')`, no
check for a preceding space), substrings up to it, and trims trailing
whitespace. `AS-CODE-DSC-003`'s "any trailing `# comment` stripped" already
described this correctly, in looser words.

**Resolved: AS-CODE-DSC-003 is factually more precise.** The rule is "cut at
the first `#`, then trim", not "cut at a space-then-`#` sequence". The
difference is observable for an unquoted value containing a `#` with no
preceding space (e.g. `abc#123`), which the phase-1 wording would predict
stays whole but the code actually still cuts. No test exercises this exact
input either way. Merged with corrected wording in `AS-DSC-005`.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-10 | Started. Area GEN: no contradiction owned by this area. |
| 0.2 | 2026-10-10 | Area DAT: one new contradiction found and resolved (`AS-DAT-005`, data-home writability — AS-CODE right). Four phase-1 contradictions (`AS-DOC-DEF-002`–`005`) re-verified against the actual schema files and confirmed already correctly resolved. `AS-DOC-DEF-111` noted as Cross-cutting, not DAT-owned. |
| 0.3 | 2026-10-11 | Area TXT: one new contradiction found and resolved (`AS-DOC-DEF-009`, MANIFESTO "SP" vs the `recognizedReleaseType` enum — both right, at different levels). Three phase-1 contradictions (`AS-DOC-DEF-010`, `011`, `013`) re-verified against the code-only view and schema/DAT cross-references, confirmed already correctly resolved. |
| 0.4 | 2026-10-11 | Area SET: three phase-1 contradictions (`AS-DOC-DEF-014`–`016`) re-verified against the code and confirmed already correctly resolved. One new contradiction found in already-merged DAT content (`AS-CODE-DAT-024` vs `AS-DOC-SET-047` — `Protect-ReshelfSecret` does not actually accept an empty string) and corrected retroactively in `01-data-and-storage.md`. |
| 0.5 | 2026-10-11 | Area SES: one phase-1 contradiction (`AS-DOC-DEF-017`) re-verified against the code and confirmed already correctly resolved; its related design consequence left cross-referenced to the not-yet-merged CLI area (`AS-DOC-DEF-104`). |
| 0.6 | 2026-10-11 | Area REC: nine phase-1 contradictions (`AS-DOC-DEF-018`–`025`, `038`) re-verified directly against `Reshelf.Recognition.psm1`, all confirmed already correctly resolved (tests/code right in every case except `AS-DOC-DEF-023` and `AS-DOC-DEF-025`, where plan and tests/code turned out both right at different levels once the mechanism was traced). |
| 0.7 | 2026-10-11 | Area DSC: two phase-1 contradictions (`AS-DOC-DEF-039`, `041`) re-verified against `Reshelf.Discogs.psm1` and confirmed already correctly resolved. One new contradiction found while merging: the `.env` inline-comment rule is a plain "cut at the first `#`" in the code, narrower/different from phase 1's "space then `#`" wording (`AS-DSC-005`, corrected). |
