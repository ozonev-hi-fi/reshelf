# 90 — Contradictions, resolved (Phase 3)

Status: Draft | Version: 0.12 | Last updated: 2026-10-13

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
broader "is the README's wording now misleading" question is Cross-cutting;
it was closed out under CLI once every area citing it had merged — see the
CLI section below.

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

## MAT

### New: AS-DOC-MAT-001 vs AS-CODE-MAT-001/002 — Is string similarity a token-sort ratio?

`AS-DOC-MAT-001` says plan 02 names "a normalized string similarity such as
token-sort ratio (compare the words after sorting them)" and that the tests
don't fix the exact formula.

Re-read `legacy/scripts/common/Reshelf.EditProposal.psm1:31-89`
(`Get-ReshelfLevenshteinDistance`, `Get-ReshelfStringSimilarity`): the
implementation is classic single-character Levenshtein edit distance,
turned into `1.0 - (distance / max(lengthA, lengthB))`. There is no
tokenization, no sorting of words, nothing resembling a token-sort ratio —
two titles with the same words in a different order would *not* score 1.0.

**Resolved: AS-CODE-MAT-001/002 is factually right.** Plan 02's "token-sort
ratio" is an aspirational/inaccurate naming of the approach, not what the
code implements. Merged as `AS-MAT-001`, corrected.

### Carried from phase 1: `AS-DOC-DEF-043` (search query keys: plan's `q=...&year=...` vs tests' `release_title`/`artist`/`type`)

Re-read `Reshelf.EditProposal.psm1:142-164` (`Get-ReshelfDiscogsSearchQuery`)
and the main search loop (`:1106-1190`): every title-ladder search sets
`type`, `artist`, `release_title`, and `year` only when known — no `q` key
anywhere in this path. A bare `q={name}` is used only by the separate
artist-identity search (`Resolve-ReshelfDiscogsArtistIdentity`,
`:885`), a different endpoint for a different purpose. **Resolved:
tests/code are right — plan 02's `q=...` shape describes neither search.**
Merged as `AS-MAT-007`.

### Carried from phase 1: `AS-DOC-DEF-044` ("at most 4 searches" undersells the full lookup)

Re-read the full `Resolve-ReshelfDiscogsMatch` (`:1035-1301`): plan 06's "at
most 4 cached searches" is correct for one step (the title/year ladder
within master search or release search, `AS-MAT-019`), but the full lookup
is four *steps* (1a master, 1b artist master list, 1c release, 1d catalog
fallback), each of which can run its own further requests (pagination,
version/candidate probing). **Resolved: tests/README are right — plan 06's
own note already flags itself as "not fully reconciled".** No change beyond
stating the full step structure in `AS-MAT-019`–`029`.

### Carried from phase 1: `AS-DOC-DEF-045` (plan: title alignment only; tests: number alignment too)

Re-read `Resolve-ReshelfDiscogsTrackAlignment`
(`Reshelf.EditProposal.psm1:1626-1656`): it is a two-step cascade — title
alignment (`Get-ReshelfDiscogsTitleAlignment`) tried first, number
alignment (`Get-ReshelfDiscogsNumberAlignment`) tried only if that fails,
source titles only if both fail. **Resolved: tests/code are right — plan
06's "falls the whole release back to source titles" describes only the
final fallback, not the full cascade.** Merged as `AS-MAT-059`.
Cross-referenced: `AS-DOC-DEF-064` (Area: PRP, not decided here — a test
that cannot tell which of the two successful methods actually ran).

### Carried from phase 1: `AS-DOC-DEF-049` (threshold wording: "above" vs "at or above")

Re-read `Resolve-ReshelfDiscogsMatch:1122` (`$scoredMasters | Where-Object {
$_.score -ge $script:DiscogsMatchThreshold }`) and the equivalent checks for
the artist-master-list and release-search paths: all three use `-ge`
(`>=`), never a strict `>`. **Resolved: the scoring tests ("at the
threshold") are right — a score of exactly 0.85 does count as `matched`;**
the `Resolve-` test's own name ("above the threshold") is loose wording for
the same `>=` check. Merged as `AS-MAT-015`/`016`.

### Carried from phase 1: `AS-DOC-DEF-051` (pad width: plan's "highest NN" vs the unit test's "track count")

Re-read `Get-ReshelfProposalPadWidth` (`Reshelf.EditProposal.psm1:1350-1364`,
MAT-owned) and its real caller, `New-ReshelfProposedTrackSet`
(`:1680-...`, PRP-owned, excluded from MAT's own scope note): the caller
passes `TotalTrackCount` = "the highest resolved `fileNumbers` value" (see
`AS-CODE-PRP-041` in `as-is-from-code/08-proposal-naming-and-tags.md`), not
a plain count of tracks — exactly matching plan 06 and the PRP-side primary
requirement `AS-DOC-PRP-018` ("the larger of the pad setting and the digits
of the *highest file number*"). **Resolved: the plan/PRP view is right.**
`Get-ReshelfProposalPadWidth`'s own parameter name, `TotalTrackCount`, is
just this low-level helper's generic naming — it doesn't care what the
number conceptually represents, only the caller does — which is what misled
the phase-1 reading of its unit test. No behavioral gap: a source with
missing tracks gets a pad width based on the highest number used, not the
count of files present, exactly as plan 06 describes. Merged as
`AS-MAT-076`/`077`. (`AS-CODE-PRP-041` itself stays PRP-owned, to be merged
when area 08 is reached — cited here only as resolution evidence.)

### Carried from phase 1: `AS-DOC-DEF-052` (README version ranking skips the third format group)

Re-read `Get-ReshelfDiscogsVersionRank:584-587`: format rank is 0 for
CD/File, 1 for Vinyl/Cassette, and **2 for everything else** (e.g. 8-Track
Cartridge, Reel-to-Reel, MiniDisc, SACD). **Resolved: tests/code are right —
README step 2's "CD/File over Vinyl/Cassette" omits the third, lowest
group.** Merged as `AS-MAT-052`.

## PRP

### Carried from phase 1: `AS-DOC-DEF-054` (default cover: embedded wins, not the Discogs primary image)

Re-read `New-ReshelfCoverArtProposal` (`Reshelf.EditProposal.psm1:1926-2028`,
`AS-CODE-PRP-054`, `059`): the embedded candidate is added first,
independent of any Discogs match, and the default-choice priority picks it
ahead of anything else whenever it decoded successfully. **Resolved:
tests/code are right — plan 06's "pre-select the Discogs primary image"
describes only the no-embedded-cover case.** Merged as `AS-PRP-061`.

### Carried from phase 1: `AS-DOC-DEF-056` (target actions are not decided by the stable key alone)

Re-read `Resolve-ReshelfTargetComparison` (`:2158-2392`, `AS-CODE-PRP-070`,
`073`): the baseline is found through a 4-branch priority chain (same-
session duplicate, same-session path collision, apply-log entry, on-disk
folder via apply-log path/proposed path/target-index lookup), and a
lossless-over-lossy upgrade found at a *different* path from the proposed
one gives `create-new`, not `update-existing` — a case the README's
stable-key-only table has no row for. **Resolved: tests/code are right —**
the README table is a simplification that only covers the common case.
Merged as `AS-PRP-088`, `092`, `094`.

### Carried from phase 1: `AS-DOC-DEF-057` (the stable key changes when the source folder has a different name)

Re-read `Get-ReshelfStableKey` (already established in the DAT merge as
`AS-DAT-064`–`066`): the key is a hash of the *normalized* artist, album and
year text — not of anything path-related, but also not stable against a
change to that text. A renamed source folder (or a correction recognition
derives differently) changes the recognized artist/album/year text, which
changes the stable key. **Resolved: plan 06, plan 09 and the tests are
right — the README's "always the same across runs, even from a different
source folder" overstates it.** This is exactly why the target-lookup chain
(`AS-PRP-088`) tries several paths instead of relying on the stable key
alone, and why the previous-lossy ledger has its own fuzzy fallback scan
(`AS-PRP-080`). Merged as `AS-PRP-096`. Cross-referenced:
`CF-DAT-001` (in `91-suspected-defects-carryforward.md`) anticipated this
resolution under the label "CF-PRP" — since `AS-DOC-DEF-057` is a
Contradiction, not a Suspected defect, it is resolved here instead of
carried forward; `CF-DAT-001`'s own cross-reference stays correct in
substance (same underlying id), only the destination file differs from what
it guessed. See also `AS-DOC-DEF-006` (Area: DAT, the opposite case: two
real editions colliding on one key).

### Carried from phase 1: `AS-DOC-DEF-058` ("an organized release is never queried again" vs. "Discogs is always queried")

Re-read the already-merged DSC rules `AS-DSC-019`/`020`
([06-discogs-client.md](06-discogs-client.md)): every lookup checks the
on-disk cache first, before the token is even resolved; a fresh cache entry
answers with no HTTP call. **Resolved: plan 06/tests are right — Discogs is
always "queried" in the sense of being checked (cache included); the
README's "never queried again" describes the cache's practical effect in
plain language, not a literal skip.** No `AS-PRP` item needed beyond the
cross-reference — this is fully explained by the already-merged DSC rules.

### Carried from phase 1: `AS-DOC-DEF-059` (compilation detection has a third trigger, and Album Artist is not the folder name)

Re-read `Get-ReshelfVariousArtistsEvidence` and its caller
(`Reshelf.EditProposal.psm1:2434-2653`, `AS-CODE-PRP-083`/`084`, and the
already-merged `AS-MAT-072`–`075`): besides the two Discogs-identity
triggers, a normal artist folder whose tracks show several different
artists is retried under a literal `'Various'` search and reproposed as a
compilation — and the compilation's Album Artist becomes `Various`, not the
original folder name (`DIO`). **Resolved: tests/code are right — the
README's two-trigger list and its "Album Artist stays the folder name"
wording both undersell the real behavior.** Merged as `AS-PRP-059`.

### Carried from phase 1: `AS-DOC-DEF-060` (compilation track artist: the file-name step is missing from the docs)

Re-read `New-ReshelfProposedTrackSet`'s compilation fallback
(`AS-CODE-PRP-049`): the cascade is tag artist → file-name-parsed artist →
Album Artist with a review note — three steps, not the two the README and
plan 06 list. **Resolved: tests/code are right — the file-name step exists
and adds no note/review on its own.** Merged as `AS-PRP-056`.

### Carried from phase 1: `AS-DOC-DEF-061` (the README says a per-track Artist exists only on compilations)

Re-read `AS-CODE-PRP-047`: a Discogs per-track credit, when present, takes
priority over every other source for the Artist tag on *any* release, not
only a compilation — a split release that isn't a compilation still gets
its own per-track credits. **Resolved: tests/code are right.** Merged as
`AS-PRP-055`.

### New, found while merging: where does the romanized half of a bilingual name actually come from? (`AS-DOC-DEF-066`)

`AS-DOC-DEF-066` observed that the README says the romanized half "always
comes from the source itself", yet the result for folder artist `Maximum
the Hormone` (`Maximum The Hormone = …`) equals both the title-cased folder
name *and* a Discogs name variation, leaving it unclear which one it
actually came from. Re-read `Get-ReshelfLocalRomanizedTitle`/
`Get-ReshelfBilingualArtistName` (`AS-CODE-PRP-003`–`010`): the romanized
half is explicitly built from the source — the existing tag value (most
frequent, picked via `Group-Object`), else the recognized folder/file title
— Title Cased, and only ever compared against Discogs evidence to decide
*whether* to go bilingual, never to supply the romanized text itself.
**Resolved: the README is right, and the ambiguity was coincidental** — for
a well-known act, the source's own (title-cased) name and the matching
Discogs name variation read the same, which is why the single example
couldn't distinguish the two candidate explanations. Merged as `AS-PRP-028`.

### Carried from phase 1: `AS-DOC-DEF-068` (repeated source numbers: the plan says "force review", the test checks only the note)

Re-read the caller of `New-ReshelfProposedTrackSet`
(`Reshelf.EditProposal.psm1:2578-2581`, and the manual re-pick's equivalent
at `:2766-2770`): any note returned by track-set building — the "renumbered
sequentially" note included — unconditionally sets
`requiresReview = $true`. Neither phase-1 nor phase-2 read this caller line
directly: phase 1's test only asserted the note; phase 2's code reading
covered `New-ReshelfProposedTrackSet` itself, which returns the note but
never sets a review flag on its own (that's the caller's job). **Resolved:
plan 06 is right — review is forced.** Merged as `AS-PRP-012`, `045`.

## REV

### Carried from phase 1: `AS-DOC-DEF-069` (README "no re-fetch" vs tests that recompute the release)

The README says picking an edition "only records your choice; it does not
re-fetch tags/tracklist/cover". Re-read
`legacy/scripts/Start-ReshelfUiServer.ps1:149-200` (the `SelectDiscogsCandidate`
handler, `AS-CODE-REV-026`–`032`): it calls the shared
`Update-ReshelfReleaseForDiscogsSelection` recompute logic and overwrites
`target.tracks`, `target.proposed`, `target.discogsMatch`, `target.coverArt`,
`target.lossyLossless` and `target.targetAction` on the matched release — a
real live recompute, not a bookkeeping-only pick. `legacy/ui/app.js:1047`
(`AS-CODE-REV-126`) confirms the client side: the POST happens immediately
and `Object.assign(release, updated)` replaces the in-memory release with
whatever the server returns. **Resolved: the tests/helpers/code are right,
the README is stale.** Merged as `AS-REV-016`, `AS-REV-101`.

### Carried from phase 1: `AS-DOC-DEF-073` (plan 07: Save applies the reserved-device-name rule; tests: Save writes the body as sent)

Plan 07 says the live preview skips the reserved-device-name suffix because
"`propose`/Save still apply that for real". Re-read
`Save-ReshelfUiProposalContent` (`legacy/scripts/common/Reshelf.UiServer.psm1:228`,
`AS-CODE-REV-022`): the only check performed before writing is that the body
parses as JSON — there is no folder-name sanitization, reserved-device-name
suffixing, or any other shape validation anywhere in the save path.
**Resolved: the tests are right, plan 07 is wrong.** A hand-typed `CON`
folder name is saved exactly as typed; only a real `propose` run (not Save)
ever applies the reserved-name suffix. Merged as `AS-REV-012`, `AS-REV-071`.

### Carried from phase 1: `AS-DOC-DEF-076` (badge names in plan 07 differ from the tests and README)

Plan 07 lists the badges `needsReview`, `ambiguous match` and `ready`. Re-read
`getReleaseStatus` (`legacy/ui/app.js:234`, `AS-CODE-REV-087`): it returns the
literal strings `'rejected'`, `'ambiguous'`, `'needsReview'` and `'ready'` —
matching the tests and the README exactly, not plan 07's names. **Resolved:
the tests/README/code agree; plan 07 used an earlier, stale naming.** Merged
as `AS-REV-051`.

### Carried from phase 1: `AS-DOC-DEF-077` (plan 07: local-file serves only proposal.json paths; tests: manual covers too)

Plan 07 says a file is served "only if `path` exactly matches one already
listed in that session's own `proposal.json`". Re-read
`Get-ReshelfUiLocalFileBytes` (`legacy/scripts/common/Reshelf.UiServer.psm1:280`,
`AS-CODE-REV-047`/`048`): the function checks two independent conditions —
a path physically under the session's `manual-covers` folder is always
servable, *bypassing* the proposal.json allow-list entirely (since a
just-uploaded cover only lives in the browser's memory until Save); only
*outside* that folder does the proposal.json allow-list apply. **Resolved:
the tests are right, plan 07 described only half the real rule.** Merged as
`AS-REV-019`, `AS-REV-020`.

### Carried from phase 1: `AS-DOC-DEF-080` ("Past sessions" lists all sessions; plan 07 says "the rest")

Plan 07 says the dropdown "lists the rest" (the other sessions). Re-read
`Get-ReshelfUiSessionsSummary`/`renderSessionHistory`
(`legacy/scripts/common/Reshelf.UiServer.psm1:160`, `legacy/ui/app.js:171`,
`AS-CODE-REV-044`, `AS-CODE-REV-081`/`082`): `GET /api/sessions` returns
every session with no exclusion of the current one, and the dropdown renders
all of them, with the loaded session pre-selected among them. Neither the
server nor the client code excludes "the current one" from the list at any
point. **Resolved: the tests are right — the dropdown lists every session,
including the current one, which also happens to be the pre-selected
option; plan 07's "the rest" phrasing was imprecise.** Merged as
`AS-REV-046`.

## APL

### Carried from phase 1: `AS-DOC-DEF-083` (README/plan: cue split "no re-encoding" vs FLAC/APE re-encoding)

Re-read `Invoke-ReshelfFfmpegSplit`
(`legacy/scripts/common/Reshelf.Implementation.psm1:232`, `AS-CODE-APL-012`):
a `.flac` or `.ape` source is always re-encoded with `-c:a flac`; every other
format uses `-c copy`. **Confirms phase 1's resolution: the tests/code are
right** — the README and both plan documents' blanket "no re-encoding"/`-c
copy` claim only holds for non-FLAC/APE sources. Merged as `AS-APL-029`.

### Carried from phase 1: `AS-DOC-DEF-084` (README: an existing target folder is "deleted and replaced" — always?)

Re-read `Move-ReshelfStagedReleaseToTarget`
(`legacy/scripts/common/Reshelf.Implementation.psm1:845`, `AS-CODE-APL-043`):
an existing target folder is removed and replaced only when `TargetAction`
is exactly `update-existing` or `conflict`; any other value throws instead
of touching the folder. **Confirms phase 1's resolution: the tests/code are
right**, the README's unconditional wording overstates it. Merged as
`AS-APL-018`/`019`.

### Carried from phase 1: `AS-DOC-DEF-085` (which releases apply skips by default)

The five sources disagreed on the exact wording of the default-skip rule
(an unresolved ambiguous/conflict release, "releases nobody reviewed", every
release with `humanReview.resolved != true`, only an ambiguous Discogs
match, or "ambiguous-AND-unresolved"). Re-read the release-gating loop in
`Invoke-ReshelfImplementation`
(`legacy/scripts/common/Reshelf.Implementation.psm1:931-950`, `AS-CODE-APL-048`):
the code checks exactly one general gate, `-not $release.humanReview.resolved
-and -not $IncludeUnresolved` — not `.required`, and not conditioned on the
match status being specifically `ambiguous`. A code comment at the site
confirms this is deliberate: `humanReview.required`/`.resolved` is the one
general "does a human need to look at this" gate, set for any flagged
reason, not only an ambiguous Discogs match. **Resolved: the tests/code are
right, with the exact mechanism now settled** — the gate is
`humanReview.resolved`, full stop; `.required` plays no role in the apply-time
check itself (it only feeds propose-time UI badges, see `AS-REV-051`). Merged
as `AS-APL-003`.

### Carried from phase 1: `AS-DOC-DEF-088` (README/plan 08: "copied/moved")

Re-read the `CopyMode` parameter and its `ValidateSet`
(`legacy/scripts/common/Reshelf.Implementation.psm1:899`, `AS-CODE-APL-049`):
only the literal value `'copy'` is accepted, and nothing in the function
branches on it — it exists purely for backward compatibility with older
callers of a removed `move` mode. **Confirms phase 1's resolution: `copy` is
the only real mode**; the README/plan's "copied/moved" phrasing is a leftover
from the removed mode (the same remnant as `AS-DOC-DEF-014`, the `settings
init` prompt). Merged as `AS-APL-021`.

### Carried from phase 1: `AS-DOC-DEF-092` (plan 08's apply-log fields are incomplete)

Re-read `Add-ReshelfApplyLogEntry`
(`legacy/scripts/common/Reshelf.Implementation.psm1:60`, `AS-CODE-APL-005`):
an entry also carries `errorMessage` and `truncated`, beyond plan 08's
`{ stableKey, appliedAtUtc, status, targetPath, sourceFileSetHash }`.
**Confirms phase 1's resolution: the tests/code are right**, plan 08's field
list was never updated after `errorMessage`/`truncated` were added. Merged as
`AS-APL-058`. One further code-only detail found while re-reading the same
function: `status`'s `ValidateSet` also allows a third value, `'skipped'`,
that the code never actually writes — see `91-suspected-defects-carryforward.md`
(`CF-APL-011`).

### Carried from phase 1: `AS-DOC-DEF-093` (step order: split before or after staging)

Plan 08 lists the cue split before staging; the README lists staging before
the split; no test shows the order. Re-read `Invoke-ReshelfReleaseStaging`
(`legacy/scripts/common/Reshelf.Implementation.psm1:677`): there is no
separate split phase at all — the function validates companion names,
creates the staging folder, then walks the release's tracks and, per track,
either runs an ffmpeg split or a plain copy directly into that folder, before
moving on to tag writing and companions. **Resolved: both the plan and the
README oversimplify one combined step into two ordered ones; neither is
wrong about anything observable, since no test exercises the order.** Merged
as `AS-APL-008`, with the actual mechanism spelled out there.

## LSY

None owned by this area. Neither source file for LSY carries an
`AS-DOC-DEF-*`/`AS-CODE-DEF-*` entry of type "Contradiction" — see
`11-lossy-tracking.md`.

## CLI

### Carried from phase 1: `AS-DOC-DEF-101` (plan 11 lists 6 UI spec files; 10 exist)

Plan 11 › UI verification names `load-and-sessions`, `edit-and-save`,
`review-state`, `covers`, `companions` and `server-down`. Re-read
`legacy/tests/ui/specs/`: it holds 10 files — the six named plus
`folder-name-preview.spec.js`, `lossy-tracker.spec.js`,
`track-artist.spec.js` and `unrecognized.spec.js`. **Resolved: the actual
spec folder is right, plan 11 is stale** — these four specs were added after
plan 11 was written and the plan was never updated to list them. Merged as
`AS-CLI-043`, with the full 10-file list.

### Carried from phase 1: `AS-DOC-DEF-102` (plan 01's command list has no "ui"; repo tree out of date)

Plan 01 says `Reshelf.ps1 dispatcher: settings|session|recognize|propose|
apply|lossy` and its repo tree has no `Start-ReshelfUiServer.ps1`, no UI
server module and no `tests/ui/`. Re-read `legacy/scripts/Reshelf.ps1:5`
(`$Command`'s `ValidateSet`): it includes `ui` alongside the six plan 01
names. **Resolved: the README and the code are right, plan 01 predates the
UI server entirely and was never updated.** Merged as `AS-CLI-002`.

### Closing out: `AS-DOC-DEF-111` (Cross-cutting — "repo root" paths after the Phase 0 move to `legacy/`)

Raised while merging DAT (names `AS-DOC-DAT-004` as related) and noted again,
unresolved, while merging SET (`AS-DOC-SET-044`) and DSC (`AS-DOC-DSC-002`):
whether README/plan wording about paths relative to "the repo root" —
including the entry script invocation itself (`pwsh scripts/Reshelf.ps1
<command>`, `AS-DOC-CLI-001`), the test runner (`pwsh
tests/Invoke-ReshelfTests.ps1`, `AS-DOC-CLI-030`) and the UI suite's expected
`TagLibSharp.dll` location (`<repo>/.data/lib/TagLibSharp.dll`,
`AS-DOC-CLI-036`) — still makes sense after the Phase 0 move of the whole app
into `legacy/`.

Every area that has cited a path like this so far (`AS-DAT-004`,
`AS-SET-*`'s own data-home references, `AS-DSC-*`'s `.env` path, and now
every path in `12-cli.md`) already merges it corrected — `legacy/scripts/
Reshelf.ps1`, `legacy/tests/Invoke-ReshelfTests.ps1`, `legacy/.data/lib/
TagLibSharp.dll` — confirmed against the actual post-move file locations, not
just the stale README/plan wording. CLI is the area most directly built
around these entry-point and test-runner paths, and the last of DEF-111's
named areas (DAT, SET, DSC, CLI) to be merged, so this is the natural place
to close the loop. **Resolved: the README and plan wording is stale, written
for the pre-Phase-0 layout; every merged `AS-*` requirement across every
area already states the current, `legacy/`-relative path, so there is no
remaining behavioral ambiguity — only the original legacy docs' own wording
is dated, which is exactly what Phase 0's freeze (`Rule D9`) already expects
of frozen, unmaintained documentation.** No further area needs to carry this
forward; BND/ERR's own `AS-DOC-DEF-108`/`110` (Area: ERR, not Cross-cutting)
are a separate, MANIFESTO-vs-plan question about the tagger/tooling
philosophy, not this path question, and are unaffected by this closure.

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
| 0.8 | 2026-10-13 | Area MAT: six phase-1 contradictions (`AS-DOC-DEF-043`–`045`, `049`, `051`, `052`) re-verified directly against `Reshelf.EditProposal.psm1` (and, for the pad-width one, the not-yet-merged PRP as-is-from-code), all confirmed already correctly resolved. One new contradiction found while merging: plan 02's "token-sort ratio" naming for string similarity vs the actual normalized-Levenshtein-distance formula (`AS-MAT-001`, corrected). |
| 0.9 | 2026-10-13 | Area PRP: eight phase-1 contradictions (`AS-DOC-DEF-054`, `056`–`061`) re-verified directly against `Reshelf.EditProposal.psm1` (lines 1332–2928) and the already-merged DAT/DSC/MAT rules, all confirmed already correctly resolved. One new contradiction found while merging: the ambiguous "where does the romanized half come from" observation (`AS-DOC-DEF-066`) resolved as a coincidence — the README was right, the source's own title-cased name and the matching Discogs name variation just read the same for the example used. `AS-DOC-DEF-068` ("forces review" vs "note only") required reading one level above either phase-1 or phase-2's own excerpts (the caller that turns any track-set note into a forced review) — resolved in the plan's favor. |
| 0.10 | 2026-10-13 | Area REV: five phase-1 contradictions (`AS-DOC-DEF-069`, `073`, `076`, `077`, `080`) re-verified directly against `Reshelf.UiServer.psm1`, `Start-ReshelfUiServer.ps1` and `app.js`, all resolved in favor of the tests/README/code over stale plan-07 prose — including confirming the Discogs re-pick really does a live recompute (`069`), Save never re-applies folder-name safety rules (`073`), the real badge names (`076`), the two independent local-file access checks (`077`), and that the sessions dropdown lists every session including the current one (`080`). |
| 0.11 | 2026-10-13 | Area APL: six phase-1 contradictions (`AS-DOC-DEF-083`–`085`, `088`, `092`, `093`) re-verified directly against `Reshelf.Implementation.psm1`, all confirmed already correctly resolved in favor of the tests/code over the README/plan-08 prose — including settling the exact default-skip gate as `humanReview.resolved` alone (`085`), and finding that the plan's "split before/after staging" ordering question doesn't really apply since the code has no separate split phase at all (`093`). |
| 0.12 | 2026-10-13 | Area LSY: no contradiction owned by this area. Area CLI: two phase-1 contradictions re-verified and resolved in favor of the current tests/README/code over stale plan prose (`AS-DOC-DEF-101`: the real 10 UI spec files vs plan 11's 6; `AS-DOC-DEF-102`: the real `ui` command vs plan 01's missing one). `AS-DOC-DEF-111` (Cross-cutting, left unresolved by DAT/SET/DSC) closed out here, since CLI is the last of its named areas and every merged path across every area already reflects the post-Phase-0 `legacy/`-relative layout. |
