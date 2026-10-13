# 12 — CLI (as-is, merged)

Status: Draft | Version: 0.1 | Last updated: 2026-10-13

## Scope

Area **CLI**. The command-line surface of the legacy app — `legacy/scripts/
Reshelf.ps1`'s commands, subcommands, parameters, defaults, dispatch and
error/exit behavior — plus the developer side: how the test suites run. What
each stage *does* once dispatched is owned by that stage's own area file;
this file only names the command, its parameters, and the dispatcher's own
mechanics. Sources: `br/as-is-from-docs/12-cli.md` (`AS-DOC-CLI-001`–`046`,
from `legacy/tests/Reshelf.Tests.ps1`, `legacy/tests/Invoke-ReshelfTests.ps1`,
the Playwright setup files in `legacy/tests/ui/`, `legacy/plan/01-repo-and-
tooling-scaffolding.md`, `legacy/plan/11-testing-and-verification-strategy.md`
and `legacy/README.md`) and `br/as-is-from-code/12-cli.md` (`AS-CODE-CLI-001`–
`039`, read only from `legacy/scripts/Reshelf.ps1`).

**ID numbering for this area:** 52 `AS-CLI-*` requirements, `AS-CLI-001`–
`052`. Mostly follows the doc side's own section order (entry/dispatch,
settings, recognize, propose, ui, apply, session, lossy, output/exit,
developer tooling, test strategy), the same approach as DSC/APL, with fresh
items inserted for facts only the code-only view has (several — the code
reads the actual parameter block and dispatch `switch`, which turns out to
carry real detail no doc or test names: `propose`/`apply` reading every real
input live from current settings rather than their own parameters, `apply`
being the only command that actually wires up `-WhatIf`, its per-release
failure detail printing, and the `lossy export`/`lossy remove` subcommands,
which the doc-side command table omits entirely even though `AS-LSY-022`
already names them from the ledger's own side).

Four doc items are not new `AS-CLI` items: `AS-DOC-CLI-003` (first-command
auto-init) restates `AS-SET-033` exactly — the behavior lives in
`Get-ReshelfSettings`/`Initialize-ReshelfSettings`, not in `Reshelf.ps1`
itself, which is why `AS-CODE-CLI` (reading only `Reshelf.ps1`) has no
counterpart for it. `AS-DOC-CLI-004` (data home from `RESHELF_HOME`) restates
`AS-DAT-003`/`AS-DAT-004` exactly. Neither gets a new `AS-CLI` id; see
`92-coverage.md`. `AS-DOC-CLI-014`/`015` (the `ui start` default port and
`-NoBrowser`) are facts about `Start-ReshelfUiServer.ps1` itself — already
merged, from the code-only view, as `AS-REV-032`/`033` — so those two items'
`Source:` lines have been extended to cite the doc ids too (see that file's
changelog); `AS-CLI-015` here only states the dispatch-level fact (`ui
start`'s `-Port` forwarding) and cross-references `AS-REV-032`/`033` for the
actual default and the browser-suppression behavior, the same "CLI owns the
command line, the stage area owns what happens inside" split used throughout
this merge pass.

**Contradictions resolved while merging this area:** two pre-existing
`AS-DOC-DEF-*` contradictions (`AS-DOC-DEF-101`, `102`), both resolved in
favor of the current tests/README/code over stale plan prose. This area also
closes out `AS-DOC-DEF-111` (Area: Cross-cutting), left unresolved by every
area that has cited it so far (DAT, SET, DSC) — see
`90-contradictions-resolution.md`.

**Suspected defects carried forward:** four pre-existing `AS-DOC-DEF-*`
entries (`100`, `103`, `104`, `105`) and all three `AS-CODE-DEF-CLI-*`
entries, seven in total. See `91-suspected-defects-carryforward.md`
(`CF-CLI-001`–`007`).

## Entry point and dispatch

### AS-CLI-001 — One entry script, with a mandatory command word from a closed set
Status: Draft | Source: AS-DOC-CLI-001; AS-CODE-CLI-001

The user runs every command through one script with PowerShell 7.4 or newer:
`pwsh legacy/scripts/Reshelf.ps1 <command> [<subcommand>] [-Param value]`
(paths are relative to the repo root; since the Phase 0 move to `legacy/`,
the entry script itself lives at `legacy/scripts/Reshelf.ps1` — this closes
`AS-DOC-DEF-111` for every path this area cites; see
`90-contradictions-resolution.md`). Every script starts with `#Requires
-Version 7.4`. `Command` is mandatory, bound positionally (position 0), and
restricted by `ValidateSet` to exactly `settings`, `session`, `recognize`,
`propose`, `apply`, `lossy`, `ui`. Any other value is rejected by
PowerShell's own parameter binding before the script body ever runs — there
is no custom error message for an invalid top-level command, and no
`default` branch in the dispatch `switch` (none is reachable).

Example: `pwsh legacy/scripts/Reshelf.ps1 settings show`. `pwsh legacy/
scripts/Reshelf.ps1 apply -SessionId 2026-09-25-0007 -WhatIf`.

### AS-CLI-002 — The command and subcommand set
Status: Draft | Source: AS-DOC-CLI-002; AS-CODE-CLI-001 (carries `AS-DOC-DEF-102`, resolved); cross-referenced with AS-CLI-026, AS-CLI-028, AS-CLI-029

The script knows these commands:

| Command | Subcommands | Parameters |
|---|---|---|
| `settings` | `init`, `show`, `set`, `set-token` | `init`: `-TargetRoot`, `-DefaultSourceRoot`, `-CopyMode`, `-Force`; `set`: `-Key`, `-Value` |
| `recognize` | — | `-SourceRoot`, `-SaveAsDefault` |
| `propose` | — | `-SessionId` |
| `ui` | `start` | `-Port` |
| `apply` | — | `-SessionId`, `-WhatIf`, `-IncludeUnresolved` |
| `session` | `list`, `show`, `resume`, `mark-reviewed` | `<id>` or `-SessionId` |
| `lossy` | `list`, `ignore`, `mark-upgraded`, `remove`, `export` | `list`/`export`: `-Status`; `ignore`/`mark-upgraded`/`remove`: `<stableKey>`; `export`: `-Path`, `-Format` |

`AS-DOC-DEF-102` asked whether the README's `ui start` command is real, since
plan 01's own command list and repo tree have no `ui` command and no UI
server module at all. **Resolved: the README and the code are right, plan 01
is stale** — `ValidateSet('settings', 'session', 'recognize', 'propose',
'apply', 'lossy', 'ui')` in the actual script includes `ui`
(`AS-CODE-CLI-001`), and plan 01 predates the UI server entirely. The table
above also corrects the doc-side command table, which named only `list`,
`ignore` and `mark-upgraded` under `lossy` — `remove` and `export` are real
subcommands the doc-side table simply never listed (`AS-CODE-CLI-029`–`034`;
`AS-LSY-022` already named both from the ledger's own side).

Example: `pwsh legacy/scripts/Reshelf.ps1 lossy export -Path out.csv
-Status pending-upgrade`.

### AS-CLI-003 — Each command group rejects its own unrecognized subcommand with a named-group error
Status: Draft | Source: AS-CODE-CLI-006; AS-CODE-CLI-011; AS-CODE-CLI-027; AS-CODE-CLI-034

Unlike the top-level `Command` (`AS-CLI-001`, rejected by `ValidateSet`
before the switch runs), each command group's `SubCommand` is a free string
checked inside that group's own `switch`, with a `default` branch that throws
a message naming the group and listing its valid subcommands:
`"Unknown 'settings' subcommand '<value>'. Use show, init, set, or
set-token."`, `"Unknown 'session' subcommand '<value>'. Use list, show,
resume, or mark-reviewed."`, `"Unknown 'ui' subcommand '<value>'. Use
start."`, `"Unknown 'lossy' subcommand '<value>'. Use list, ignore,
mark-upgraded, remove, or export."`.

Example: `pwsh legacy/scripts/Reshelf.ps1 settings frobnicate` → `Unknown
'settings' subcommand 'frobnicate'. Use show, init, set, or set-token.`

## settings

### AS-CLI-004 — "settings init" creates settings.json; parameters make it non-interactive
Status: Draft | Source: AS-DOC-CLI-005; AS-CODE-CLI-003; cross-referenced with AS-SET-006, AS-SET-021, AS-SET-029, AS-SET-030 (copy mode), AS-CODE-CLI-039

`settings init` accepts `-TargetRoot`, `-DefaultSourceRoot`, `-CopyMode` and
`-Force` (switch), all four passed straight through to
`Initialize-ReshelfSettings`. `-Force` is used for a run with no prompts (the
UI test setup uses it). On success the exit code is 0 and `settings.json`
exists in the data home, printed as JSON (`ConvertTo-Json -Depth 10`). The
script's own `-CopyMode` parameter has no `ValidateSet` of its own — any
restriction on acceptable values (only `copy` is accepted; `move` throws
naming it "no longer supported") is enforced downstream, by
`Initialize-ReshelfSettings` itself (`AS-SET-006`/`021`/`029`/`030`), not by
this CLI script. The prompts, defaults and checks: see
[03-settings-and-secrets.md](03-settings-and-secrets.md).

Example: `settings init -TargetRoot <temp>\target` → exit 0, `<dataHome>\
settings.json` exists. `settings init -TargetRoot <t> -DefaultSourceRoot <s>`
→ `defaultSourceRoot = <s>`.

### AS-CLI-005 — "settings show" prints the settings as JSON
Status: Draft | Source: AS-DOC-CLI-006; AS-CODE-CLI-002

`settings show` takes no parameters and prints the current settings object as
JSON (`ConvertTo-Json -Depth 10`).

Example: after `settings init -TargetRoot <temp>\target` → the JSON has
`targetRoot = "<temp>\target"`.

### AS-CLI-006 — "settings set" changes one top-level key
Status: Draft | Source: AS-DOC-CLI-007; AS-CODE-CLI-004

`settings set -Key <key> -Value <value>` accepts both as plain strings with
no local validation in this script — any restriction on which keys/values
are acceptable is enforced downstream. Nested keys such as
`namingTemplates.releaseFolder` need a hand edit of `settings.json`. Prints
the resulting settings object as JSON. Key list and checks: see
[03-settings-and-secrets.md](03-settings-and-secrets.md).

Example: `settings set -Key taglibSharpPath -Value <repo>\.data\lib\
TagLibSharp.dll`.

### AS-CLI-007 — "settings set-token" stores the Discogs token
Status: Draft | Source: AS-DOC-CLI-008; AS-CODE-CLI-005

`settings set-token` takes no CLI-level parameters — the token is obtained
internally (interactively, or from an environment variable) — and prints the
resulting settings object as JSON. The user runs it again after a Discogs
`401 Unauthorized`. Storage and lookup order: see
[03-settings-and-secrets.md](03-settings-and-secrets.md).

Example: `pwsh legacy/scripts/Reshelf.ps1 settings set-token`.

## recognize

### AS-CLI-008 — "recognize" uses -SourceRoot, or the default source root
Status: Draft | Source: AS-DOC-CLI-009; AS-CODE-CLI-012

`-SourceRoot` is optional; if omitted, `recognize` falls back to the current
settings' `defaultSourceRoot`. When neither is available, it throws `"No
source root given and no defaultSourceRoot configured. Pass -SourceRoot, or
run 'Reshelf.ps1 settings set -Key defaultSourceRoot -Value <path>'."` — a
non-zero exit code, naming both ways to fix it.

Example: `settings init -TargetRoot <t>` (no default), then `recognize` →
non-zero exit, output contains `No source root given`.

### AS-CLI-009 — "-SaveAsDefault" only has an effect together with an explicit -SourceRoot
Status: Draft | Source: AS-DOC-CLI-010; AS-CODE-CLI-013

With `-SaveAsDefault` and an explicit `-SourceRoot` on the same invocation,
`recognize` saves that value as `defaultSourceRoot` before recognition runs.
`-SaveAsDefault` alone, relying on the existing default, does nothing.
Without `-SaveAsDefault`, `defaultSourceRoot` stays unchanged.

Example: `recognize -SourceRoot <temp>\source-empty-2 -SaveAsDefault` →
`defaultSourceRoot = <temp>\source-empty-2`. Default
`source-original-default`, then `recognize -SourceRoot source-other` →
default stays `source-original-default`.

### AS-CLI-010 — "recognize" always creates a brand-new session and prints a counts-only summary
Status: Draft | Source: AS-DOC-CLI-011; AS-CODE-CLI-014; AS-CODE-CLI-015

Every `recognize` invocation creates a new session — there is no "resume and
re-recognize into the same session" path. On success it prints `SessionId`,
`ArtistCount`, `ReleaseCount` and `UnrecognizedCount` as a `Format-List`
summary (counts only, not the full recognition data). A source without audio
files still succeeds (exit 0). What recognize finds: see
[05-recognition.md](05-recognition.md).

Example: source with only `Some Artist Folder\readme.txt` → exit 0, output
has `SessionId`, one session exists. README sample: `SessionId :
2026-09-25-0007`, `ArtistCount : 42`, `ReleaseCount : 118`,
`UnrecognizedCount : 3`.

### AS-CLI-011 — A recognize failure names the session it already created, and its own fix suggestion creates yet another — carries CF-CLI-003
Status: Draft | Source: AS-DOC-CLI-012; AS-CODE-CLI-014; carried forward: see `91-suspected-defects-carryforward.md` (`CF-CLI-003`, citing `AS-DOC-DEF-104`)

When recognition fails after the session was created, the command fails with
a non-zero exit code and the full message `"Recognition failed for session
'<id>': <original message> The session was created but has no
recognition.json - fix the issue and run 'Reshelf.ps1 recognize -SourceRoot
<path>' again (this starts a new session)."` The session stays in the data
home, named in the error, with no `recognition.json`.

Example: source with `Some Artist\2020 Some Album\01 - Track.flac` and no
`TagLibSharp.dll` → non-zero exit, output contains `Recognition failed for
session`, 1 session exists.

Carried forward: the message's own "this starts a new session" is an honest
description of a real design gap — re-running the suggested fix creates
another session rather than resuming the failed one, which is left behind
forever at stage `recognized` with no `recognition.json` (`AS-SES-007`). See
`CF-CLI-003`.

## propose

### AS-CLI-012 — "propose" needs a session id and prints a summary; records the proposed stage
Status: Draft | Source: AS-DOC-CLI-013; AS-CODE-CLI-016; AS-CODE-CLI-019

`propose -SessionId <id>` runs the proposal for that session. Without a
session id it throws `"'propose' requires a session id. Usage: Reshelf.ps1
propose -SessionId <id>"` — a non-zero exit code. On success, the session's
stage is set to `proposed` with the `proposal.json` path recorded, then a
`Format-List` summary is printed: `SessionId`, `ArtistCount`, `ReleaseCount`,
`MatchedCount` (releases with `discogsMatch.status -eq 'matched'`) and
`NeedsReviewCount` (releases with `humanReview.required`). What propose does:
see [07-proposal-matching.md](07-proposal-matching.md) and
[08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md).

Example: `propose` → non-zero exit, `…requires a session id…`. README
sample: `MatchedCount : 103`, `NeedsReviewCount : 15`.

### AS-CLI-013 — "propose" takes all its real inputs from current settings, not its own parameters
Status: Draft | Source: AS-CODE-CLI-017

Beyond `-SessionId`, `propose` has no parameters of its own for target root,
naming templates, track number pad width, cover max dimension, cache TTL or
rate limit — all of these are read live from the current settings at the
moment `propose` runs. Re-running `propose` on the same session after
changing settings applies the new settings against that session's existing
(unchanged) `recognition.json`.

Example: change `trackNumberPadWidth` between two `propose` runs on the same
session → the second run's naming reflects the new value.

### AS-CLI-014 — "propose" wraps a failure with session context
Status: Draft | Source: AS-CODE-CLI-018

A failure during proposal generation is caught and rethrown as `"Edit
proposal failed for session '<id>': <original message>"`.

Example: a Discogs client error during propose → `Edit proposal failed for
session '2026-09-25-0007': <original message>`.

## ui

### AS-CLI-015 — "ui start" forwards -Port when given; otherwise the server's own default applies
Status: Draft | Source: AS-DOC-CLI-014; AS-DOC-CLI-015; AS-CODE-CLI-026; cross-referenced with AS-REV-032 (default port, UI root), AS-REV-033 (-NoBrowser)

`ui start` resolves `Start-ReshelfUiServer.ps1` next to `Reshelf.ps1` and
invokes it. If `-Port` is given (non-zero), it is forwarded; otherwise the
script runs with no `-Port` argument at all, letting that script's own
internal default apply. The default port (4173), the UI root resolution, and
`-NoBrowser` are the server script's own behavior, merged under area REV as
`AS-REV-032`/`033` (read from the code, since neither was specific to the
`Reshelf.ps1` dispatcher). The server script can also run standalone, outside
`Reshelf.ps1 ui start` — the UI test suite starts it this way.

Example: `pwsh legacy/scripts/Reshelf.ps1 ui start` → `http://localhost:
4173/`. `ui start -Port 5000` → `http://localhost:5000/`. `pwsh -File
legacy/scripts/Start-ReshelfUiServer.ps1 -Port 53123 -NoBrowser` → `GET
http://localhost:53123/` answers OK.

## apply

### AS-CLI-016 — "apply" needs a session id
Status: Draft | Source: AS-DOC-CLI-016; AS-CODE-CLI-020

`apply` without a session id throws `"'apply' requires a session id. Usage:
Reshelf.ps1 apply -SessionId <id>"` — exit code 1.

Example: `pwsh legacy/scripts/Reshelf.ps1 apply` → exit 1.

### AS-CLI-017 — "apply" parameters and summary
Status: Draft | Source: AS-DOC-CLI-017; AS-CODE-CLI-021; AS-CODE-CLI-024

`apply -SessionId <id>` applies the session. Its only own parameters are
`-IncludeUnresolved` and `-WhatIf` (both switches); target root, copy mode,
ffmpeg path, TagLib# path and data home are all taken from current settings,
the same live-settings pattern as `propose` (`AS-CLI-013`).
`-WhatIf` is a dry run with no files touched; `-IncludeUnresolved` also
applies releases that nobody reviewed. The command always prints `SessionId`,
`Applied`, `Skipped`, `Rejected` and `Failed` as a `Format-List`, regardless
of whether any release failed. What apply does: see
[10-apply.md](10-apply.md).

Example: `apply -SessionId 2026-09-25-0007 -WhatIf`. README sample output:
`Applied : 96`, `Skipped : 7`, `Rejected : 4`, `Failed : 0`.

### AS-CLI-018 — "apply" is the only command that actually wires up -WhatIf
Status: Draft | Source: AS-CODE-CLI-022

`-WhatIf` is declared at the script's top-level parameter block, so it is
syntactically acceptable with any command, but only the `apply` branch
forwards it into a function that supports `ShouldProcess`
(`Invoke-ReshelfImplementation`). Passing `-WhatIf` to any other command is
silently accepted and has no effect.

Example: `recognize -WhatIf` → runs for real; recognition is not a
`ShouldProcess` operation, and nothing in that branch reads `$WhatIf`.

### AS-CLI-019 — "apply" has no try/catch of its own, unlike recognize and propose — carries CF-CLI-004
Status: Draft | Source: AS-CODE-CLI-023; carried forward: see `91-suspected-defects-carryforward.md` (`CF-CLI-004`, citing `AS-CODE-DEF-CLI-001`)

Unlike `recognize` (`AS-CLI-011`'s catch) and `propose` (`AS-CLI-014`'s
catch), the `apply` case does not wrap `Invoke-ReshelfImplementation` in a
local `try`/`catch` — an exception there propagates with its original,
unwrapped message, not the `"<Step> failed for session '<id>': <message>"`
style the other two give.

Example: a mid-apply ffmpeg failure → a raw, unwrapped PowerShell error,
with no "Apply failed for session '<id>'" framing.

### AS-CLI-020 — "apply" prints per-release failure detail, scoped to the session
Status: Draft | Source: AS-CODE-CLI-025

When `Failed > 0`, the session's own `proposal.json` is re-read to get its
own set of `stableKey` values, and the apply log is filtered down to only
`failed` entries whose `stableKey` is in that set — because the apply log is
shared across every session ever applied, and an unrelated stable key could
otherwise still be sitting there as `failed` from a previous, unrelated run.
Each matching entry's `StableKey`, `TargetPath`, `ErrorMessage` is printed
via `Format-List`, preceded by a yellow `"Failed releases:"` heading written
with `Write-Host` (not pipeline output).

Example: 2 releases fail during `apply` → `Failed : 2`, then `Failed
releases:` in yellow, then two `Format-List` blocks with `StableKey`,
`TargetPath`, `ErrorMessage`.

## session

### AS-CLI-021 — "session list" prints all sessions as a human-readable table
Status: Draft | Source: AS-DOC-CLI-018; AS-CODE-CLI-007

`session list` takes no parameters and lists every session's `sessionId`,
`stage`, `sourceRoot`, `updatedAtUtc` as a `Format-Table` — not
machine-parseable JSON, unlike most other commands. With no sessions it
still succeeds (exit 0).

Example: empty data home, `session list` → exit 0.

### AS-CLI-022 — "session show" prints one session as JSON and needs an id
Status: Draft | Source: AS-DOC-CLI-019; AS-CODE-CLI-008

`session show <id>` requires `-SessionId` (or the positional session-id
slot); missing it throws `"'session show' requires a session id."` — a
non-zero exit code. On success it prints the full session object as JSON
(`-Depth 10`). It does not list all sessions instead.

Example: `session show` → non-zero exit, `…requires a session id…`.

### AS-CLI-023 — "session resume" needs an id and prints the result as a list, not JSON
Status: Draft | Source: AS-DOC-CLI-020; AS-CODE-CLI-009; cross-referenced with AS-SES-011–016 (the actual stage-to-command mapping)

`session resume <id>` requires a session id, same missing-id error pattern as
`session show` (`"'session resume' requires a session id."`). On success it
prints `Resume-ReshelfSession`'s result as `Format-List` (exit 0) — the
stage and the suggested next command. The actual stage-to-command mapping is
owned by area SES, not repeated here: see [04-sessions.md](04-sessions.md)
(`AS-SES-011`–`016`).

Example: stage `reviewed` → output contains `apply -SessionId
2026-10-05-0001`.

### AS-CLI-024 — "session mark-reviewed" sets the stage to reviewed and needs an id
Status: Draft | Source: AS-DOC-CLI-021; AS-CODE-CLI-010

`session mark-reviewed <id>` requires a session id, same missing-id error
pattern (`"'session mark-reviewed' requires a session id."`). On success it
sets that session's stage to the literal string `reviewed`, then re-fetches
and prints the session as `Format-List` (exit 0). Meaning of this step: see
[09-review-ui.md](09-review-ui.md) (`AS-REV-084`).

Example: stage `proposed`, `session mark-reviewed -SessionId <id>` → exit 0,
stage `reviewed`.

### AS-CLI-025 — A session id can be given by position or with -SessionId
Status: Draft | Source: AS-DOC-CLI-022

Every `session` subcommand, and `propose`/`apply`, take the session id as the
first free value (position 2) or as `-SessionId <id>` — the same bound
parameter either way.

Example: `session mark-reviewed 2026-09-25-0007` (README) and `session
mark-reviewed -SessionId <id>` (test) both work.

## lossy

### AS-CLI-026 — "lossy list" prints the ledger, optionally filtered by status
Status: Draft | Source: AS-DOC-CLI-023; AS-CODE-CLI-028

`lossy list` prints the lossy-tracking ledger as a `Format-Table` with
columns `stableKey, artist, album, year, format, status, targetPath` —
notably fewer columns than `lossy export`'s CSV form (`AS-CLI-029`). With an
empty ledger it still succeeds (exit 0). `-Status pending-upgrade|upgraded|
ignored` (`ValidateSet`) prints only entries with that status. The ledger
rules: see [11-lossy-tracking.md](11-lossy-tracking.md).

Example: `a1b2c3d4e5f60708` (`upgraded`) and `b2c3d4e5f6070819`
(`pending-upgrade`), `lossy list -Status pending-upgrade` → output has
`b2c3d4e5f6070819`, not `a1b2c3d4e5f60708`.

### AS-CLI-027 — "lossy ignore" and "lossy mark-upgraded" set the status of one entry, read from the session-id slot — carries CF-CLI-005
Status: Draft | Source: AS-DOC-CLI-024; AS-DOC-CLI-025; AS-CODE-CLI-029; carried forward: see `91-suspected-defects-carryforward.md` (`CF-CLI-005`, citing `AS-CODE-DEF-CLI-002`)

`lossy ignore <stableKey>` sets the entry to `ignored`; `lossy mark-upgraded
<stableKey>` sets it to `upgraded` — an `ignored` entry can be set to
`upgraded`. Neither has a dedicated `-StableKey` parameter: both read the
stable key from the same positional/`-SessionId` slot used by the `session`
command, immediately aliased to a local `$stableKey` variable. Each throws
its own `"'lossy <subcommand>' requires a stable key."` if that slot is
empty — a non-zero exit code.

Example: `lossy ignore a1b2c3d4e5f60708` → `ignored`; then `lossy
mark-upgraded a1b2c3d4e5f60708` → `upgraded`. `lossy ignore` (no key) →
non-zero exit, `…requires a stable key…`.

Carried forward: a scripted caller passing `-SessionId` to a `lossy`
subcommand, reasonably expecting it to mean a session (as it does for every
`session` subcommand and for `propose`/`apply`), would silently be operating
on a ledger stable key instead. See `CF-CLI-005`.

### AS-CLI-028 — "lossy remove" permanently deletes an entry, same stable-key-slot pattern as ignore/mark-upgraded
Status: Draft | Source: AS-CODE-CLI-029; cross-referenced with AS-LSY-013

`lossy remove <stableKey>` deletes the row with that key, same
positional/`-SessionId`-slot reuse as `AS-CLI-027`, same missing-key error
pattern (`"'lossy remove' requires a stable key."`). The underlying delete
semantics (distinct from `ignore`, which keeps the row): see
[11-lossy-tracking.md](11-lossy-tracking.md) (`AS-LSY-013`). Neither the
doc-side command table nor its `lossy` section (`AS-DOC-CLI-023`–`025`)
named this subcommand at all, even though `AS-LSY-022` already described the
user being able to remove an entry.

Example: `pwsh legacy/scripts/Reshelf.ps1 lossy remove a1b2c3d4e5f60708`.

### AS-CLI-029 — "lossy export" requires a path, supports CSV (default, wider columns) or JSON
Status: Draft | Source: AS-CODE-CLI-030; AS-CODE-CLI-031; AS-CODE-CLI-032; AS-CODE-CLI-033; cross-referenced with AS-LSY-022

`lossy export` requires `-Path` (the output file); missing it throws
`"'lossy export' requires -Path <file> (the output file path)."` It accepts
the same optional `-Status` filter as `lossy list`. `-Format` defaults to
`csv` and accepts only `csv` or `json` (`ValidateSet`). With `-Format json`,
the (optionally filtered) ledger is serialized with `ConvertTo-Json -Depth
10` and written via `Set-Content -Encoding utf8`. With `-Format csv` (the
default), the ledger is projected to a fixed, wider column set —
`stableKey, artist, album, year, format, status, targetPath,
firstDetectedUtc, lastCheckedUtc, upgradedUtc, notes` — a superset of `lossy
list`'s columns (`AS-CLI-026`) — and written with `Export-Csv
-NoTypeInformation -Encoding utf8`. On success it prints `"Exported <N>
entries to <Path>"`, where `N` is the count of the filtered ledger actually
written, not the unfiltered ledger's total count. Like `AS-CLI-028`, this
subcommand is real but entirely absent from the doc-side command table and
`lossy` section, even though `AS-LSY-022` already named the export feature
from the ledger's own side.

Example: `lossy export -Path out.json -Format json -Status upgraded` →
`out.json` has only `upgraded` entries. `lossy export -Path out.csv` (no
`-Format`, default `csv`) with 7 matching entries → `Exported 7 entries to
out.csv`.

### AS-CLI-030 — The -Status filter is shared only between "lossy list" and "lossy export"
Status: Draft | Source: AS-CODE-CLI-038

`-Status` (`ValidateSet`: `pending-upgrade`, `upgraded`, `ignored`) is used
only to filter the ledger in `lossy list` and `lossy export`. It is never
combined with the stable-key-via-`-SessionId` subcommands (`ignore`,
`mark-upgraded`, `remove`), which operate on exactly one entry identified by
key, not a filtered set.

Example: `lossy ignore -Status upgraded a1b2c3d4e5f60708` → `-Status` is
accepted syntactically (it's a script-wide parameter) but has no effect on
`ignore`.

## Output and exit behavior

### AS-CLI-031 — Errors give a non-zero exit code; the process never sets one explicitly — carries CF-CLI-006
Status: Draft | Source: AS-DOC-CLI-026; AS-CODE-CLI-035; AS-CODE-CLI-036; carried forward: see `91-suspected-defects-carryforward.md` (`CF-CLI-006`, citing `AS-DOC-DEF-105`)

A missing required value stops the command with a readable message and a
non-zero exit code; a successful command exits with 0. Mechanically: the
entire top-level `switch ($Command) { ... }` dispatch has no enclosing
`try`/`catch` of its own, and no command path calls `exit`, sets
`$LASTEXITCODE`, or calls `$host.SetShouldExit` anywhere in this script — the
process's exit code is left entirely to PowerShell's own default engine
behavior: 0 when the script runs to completion, non-zero when any uncaught
`throw` (from this script's own validation or from deep inside a called
module) ends execution early.

Example: `propose` → `…requires a session id…`, non-zero exit; `lossy
ignore` → `…requires a stable key…`, non-zero exit; `apply` → exit 1;
`session list` → exit 0.

Carried forward: the test suite itself checks this two different ways —
`apply` without a session id is tested for exit code exactly 1 with no
message assertion, while `propose` and every `session` subcommand without an
id are tested for "non-zero" plus the literal text `requires a session id`.
This is a test-methodology inconsistency, not a behavior difference (both
paths are an uncaught `throw`, per this item) — the docs never actually
confirm whether `apply` prints the same `requires a session id` text. See
`CF-CLI-006`.

### AS-CLI-032 — Summaries print as "Name : Value" lines
Status: Draft | Source: AS-DOC-CLI-027

Command summaries print in PowerShell list format (`Format-List`), one
`Name : Value` per line. A long value wraps at the console width. The output
can contain ANSI color codes, also when it is redirected; `NO_COLOR=1` turns
them off.

Example: `Applied   : 96`. The `NextCommand` value of `session resume` can
wrap across two lines.

### AS-CLI-033 — "-Format" is a script-wide parameter but only "lossy export" reads it — carries CF-CLI-007
Status: Draft | Source: AS-CODE-CLI-037; carried forward: see `91-suspected-defects-carryforward.md` (`CF-CLI-007`, citing `AS-CODE-DEF-CLI-003`)

`-Format` is declared at the script's top-level parameter block (so it is
syntactically acceptable with any command) with a default of `csv`, but only
`lossy export` ever reads its value. Passing `-Format` to any other command
is silently accepted and ignored.

Example: `session list -Format json` → `-Format` is accepted but has no
effect; the output is still `session list`'s own `Format-Table`.

Carried forward: harmless today, since only `lossy export` reads `-Format`,
but a future command parameter also named `-Format` would silently inherit
this script-wide default rather than one of its own. See `CF-CLI-007`.

## Developer: tools and repo

### AS-CLI-034 — Developer tools
Status: Draft | Source: AS-DOC-CLI-028

The developer needs PowerShell 7.4+, Pester 5 or newer, and PSScriptAnalyzer
for linting. Windows ships an old Pester 3.4.0; every test file loads Pester
with `Import-Module Pester -MinimumVersion 5.0`, so it never picks up the old
one. ffmpeg is an external tool installed by hand (`winget install
Gyan.FFmpeg`); its use: see [10-apply.md](10-apply.md).

Example: `Install-Module Pester -MinimumVersion 5.0`, `Install-Module
PSScriptAnalyzer`.

### AS-CLI-035 — Machine-specific files stay out of git
Status: Draft | Source: AS-DOC-CLI-029

The repo ignores machine-specific files: `config/settings.json`,
`*.local.json`, `.env` and `.data/`. Only the template
`config/settings.default.json` is committed.

Example: a `.env` file with `DISCOGS_ACCESS_TOKEN=…` is never committed.

## Developer: running the tests

### AS-CLI-036 — The test runner runs all Pester tests
Status: Draft | Source: AS-DOC-CLI-030

`pwsh legacy/tests/Invoke-ReshelfTests.ps1` runs every Pester test in the
`tests` folder with detailed output. `-Path <paths>` runs only the given
files or folders. Plain `Invoke-Pester ./tests` also works, without the
runner's extra switches.

Example: `pwsh legacy/tests/Invoke-ReshelfTests.ps1 -Path
tests/Reshelf.UiServer.Tests.ps1`.

### AS-CLI-037 — "-SkipIntegration" leaves out the tests that need TagLibSharp and ffmpeg
Status: Draft | Source: AS-DOC-CLI-031

`-SkipIntegration` excludes the tests tagged `Integration`
(`tests/Reshelf.TagLibSharp.Integration.Tests.ps1`). Without the switch,
these tests run and fail (they do not skip) when the real `TagLibSharp.dll`
or `ffmpeg` is missing.

Example: `pwsh legacy/tests/Invoke-ReshelfTests.ps1 -SkipIntegration` on a
machine without ffmpeg → no integration failure.

### AS-CLI-038 — "-IncludeUi" runs the Playwright suite after the Pester tests pass
Status: Draft | Source: AS-DOC-CLI-032

`-IncludeUi` also runs `npx playwright test` in `tests/ui`, but only after
all Pester tests pass. When a Pester test fails, the runner prints a
warning, skips the UI suite and exits with 1. `-Path` and `-SkipIntegration`
do not affect the UI suite; it always runs in full.

Example: one Pester failure + `-IncludeUi` → warning `Pester tests failed -
skipping the Playwright UI suite.`, exit 1.

### AS-CLI-039 — "-IncludeUi" without installed node modules skips the UI suite with success — carries CF-CLI-002
Status: Draft | Source: AS-DOC-CLI-033; carried forward: see `91-suspected-defects-carryforward.md` (`CF-CLI-002`, citing `AS-DOC-DEF-103`)

When `tests/ui/node_modules` does not exist, the runner prints a warning,
skips the UI suite and exits with 0.

Example: fresh clone, `pwsh legacy/tests/Invoke-ReshelfTests.ps1
-IncludeUi`, all Pester tests pass → warning `tests/ui/node_modules not
found - run 'npm install' …`, exit 0.

Carried forward: plan 11 says a silent skip of the integration tests "would
let this coverage gap reopen unnoticed", and makes `-SkipIntegration`-covered
tests fail instead of skip for exactly that reason. A missing `node_modules`
folder gets the opposite treatment — a warning and a success exit — so the
same coverage gap plan 11 worried about for one suite is explicitly allowed
for the other. See `CF-CLI-002`.

### AS-CLI-040 — The runner's exit code
Status: Draft | Source: AS-DOC-CLI-034

Without `-IncludeUi`, the exit code is 1 when any Pester test failed, else
0. With `-IncludeUi` and a UI run, the exit code is the Playwright exit
code.

Example: all Pester pass, one Playwright test fails → the Playwright exit
code (not 0).

### AS-CLI-041 — One-time setup and direct run of the UI suite
Status: Draft | Source: AS-DOC-CLI-035

The UI suite needs a one-time `npm install` and `npx playwright install
chromium` in `tests/ui`. It then runs with `npx playwright test` in that
folder, or through the runner with `-IncludeUi`. It uses `@playwright/test`
1.48 or newer.

Example: `cd legacy/tests/ui; npm install; npx playwright install chromium;
npx playwright test`.

### AS-CLI-042 — The UI suite drives the real server against a temporary data home
Status: Draft | Source: AS-DOC-CLI-036

Before the specs run, the setup creates a temporary folder with `data`,
`target` and `source`, sets `RESHELF_HOME` to `data`, and runs `settings
init -TargetRoot <target> -Force` and `settings set -Key taglibSharpPath`. It
picks a free port, starts the real server with `-NoBrowser`, and waits up to
15 seconds for `GET /` to answer. It stores port, URL and paths in
`tests/ui/.tmp/state.json`. Nothing is mocked except the Discogs selection
call (`AS-CLI-046`).

Example: no `TagLibSharp.dll` at `legacy/.data/lib/TagLibSharp.dll` → setup
fails with `TagLibSharp.dll not found at '…'`. Server not up in 15 s →
`Reshelf UI server never became ready at http://localhost:<port>/`.

### AS-CLI-043 — The UI suite runs one test at a time; the server-down spec runs last
Status: Draft | Source: AS-DOC-CLI-037 (carries `AS-DOC-DEF-101`, resolved)

The suite uses 1 worker, no retries, a 30-second timeout per test, Desktop
Chrome, a trace kept on failure and a screenshot on failure. It has two
projects: `main` (every spec except `server-down.spec.js`) and `server-down`,
which runs after `main` because it stops the shared server. There are 10
spec files in total: `load-and-sessions`, `edit-and-save`, `review-state`,
`covers`, `companions`, `folder-name-preview`, `lossy-tracker`,
`track-artist`, `unrecognized` and `server-down`.

`AS-DOC-DEF-101` asked whether plan 11's list of 6 spec files (`load-and-
sessions`, `edit-and-save`, `review-state`, `covers`, `companions`,
`server-down`) was complete. **Resolved: the actual spec folder is right,
plan 11 is stale** — `legacy/tests/ui/specs/` has 10 files; `folder-name-
preview.spec.js`, `lossy-tracker.spec.js`, `track-artist.spec.js` and
`unrecognized.spec.js` were added after plan 11 was written and it was never
updated.

Example: `npx playwright test` → `main` runs 9 spec files, then
`server-down` runs `server-down.spec.js`.

### AS-CLI-044 — Each UI test seeds its own fresh session — carries CF-CLI-001
Status: Draft | Source: AS-DOC-CLI-038; carried forward: see `91-suspected-defects-carryforward.md` (`CF-CLI-001`, citing `AS-DOC-DEF-100`)

Each test calls the seed script with a label. The script makes a new source
folder `<source>\<label>-<8 hex>\Aurora Fields\`, real 1-second FLAC files
(made with ffmpeg) and image files from `tests/ui/fixtures/`. It writes a
schema-valid `proposal.json` with four releases (`rich`, `minimal`, `empty`,
`compilation`) and new stable keys, and sets the session stage to
`reviewed`. It prints the session id, proposal path, source folder and each
release's stable key, album and year as JSON.

Fixture files: `large-cover.jpg`, `small-cover.jpg`, `loose-companion.jpg`,
`nested-companion.jpg`, `upload-cover.png`, `not-an-image.txt`.

Example: `seedSession('edit-save')` → `{sessionId, proposalPath,
sourceFolderPath, rich:{stableKey, album:"Departure Songs <suffix>",
year:2016}, minimal:{…, year:2018}, empty:{…, year:2020}, compilation:{…,
year:2008}}`.

Carried forward: the script's own `.DESCRIPTION` says "a schema-valid
proposal.json for two releases" and shows a sample output with only `rich`
and `minimal` — stale, since the script seeds and prints all four. See
`CF-CLI-001`.

### AS-CLI-045 — The UI suite never calls Discogs
Status: Draft | Source: AS-DOC-CLI-039

The UI suite has no network access to Discogs. The test intercepts the
`discogs-selection` call in the browser and answers it with
`discogsMatch.status = "matched"` only. The one remote cover URL points to
`https://example.invalid/cover-remote.jpg`, which never loads.

Example: pick candidate `releaseId 1001` → the test answers
`{discogsMatch:{status:"matched", selectedReleaseId:1001, candidates:[]}}`.

### AS-CLI-046 — The UI suite stops the server and deletes its temporary data at the end
Status: Draft | Source: AS-DOC-CLI-040

After all specs, the teardown stops the server process tree (`taskkill /T
/F`). A server that is already stopped is not an error. It then deletes the
temporary folder and `tests/ui/.tmp`.

Example: after `server-down.spec.js` stopped the server, the teardown still
finishes without error.

### AS-CLI-047 — The UI suite can run "apply" for real
Status: Draft | Source: AS-DOC-CLI-041

A UI test can run `scripts/Reshelf.ps1 apply -SessionId <id>
-IncludeUnresolved` against the temporary target root, with `NO_COLOR=1`. It
reads `Applied`, `Skipped`, `Rejected` and `Failed` from the output.

Example: the companions end-to-end test → `{Applied: 4}`.

## Developer: test strategy

### AS-CLI-048 — Unit tests focus on pure functions
Status: Draft | Source: AS-DOC-CLI-042

Pester unit tests are the default. They cover the deterministic rules: safe
file names, folder-type detection, track-number parsing, `stableKey`,
disc/track numbering, and JSON schema round trips.

Example: a 3-disc fixture checks continuous file numbers against per-disc
`Track` tags.

### AS-CLI-049 — A synthetic source tree holds the messy patterns
Status: Draft | Source: AS-DOC-CLI-043

`tests/fixtures/sample-source-tree/` uses 0-byte files with real extensions.
It has one example of each messy pattern. A folder named `CON` and a
near-path-limit tree are not in git; the tests build them at run time.

Example: `Godspeeds and their projects\Godspeed You! Black Emperor\…`,
`Talking Heads\David Byrne\…`, `ZZ Top\EPs\…`.

### AS-CLI-050 — Tests never call the real Discogs API
Status: Draft | Source: AS-DOC-CLI-044

Proposal tests replace the Discogs request with captured JSON from
`tests/fixtures/discogs-responses/`. Tests never use the network or the rate
limit.

Example: `Mock Invoke-DiscogsRequest { Get-Content $fixturePath |
ConvertFrom-Json }`.

### AS-CLI-051 — Apply is checked with a dry run snapshot and a tag read-back
Status: Draft | Source: AS-DOC-CLI-045

A `-WhatIf` run must leave every file under source root, data home and
target root unchanged (path, size, last-write time; folders are not
compared). A real run then goes to a temporary target. The integration test
reads the tags back with TagLibSharp from a fresh file object.

Example: snapshot before and after `apply -WhatIf` → equal.

### AS-CLI-052 — Golden files pin the full pipeline output
Status: Draft | Source: AS-DOC-CLI-046

The pipeline test compares `recognition.json`, `proposal.json` and the
target layout of an `-IncludeUnresolved` apply with reviewed files in
`tests/fixtures/expected/`. Run-specific values are replaced first by
`<SOURCE_ROOT>`, `<TARGET_ROOT>`, `<DATA_HOME>`, `<SESSION_ID>`,
`<GENERATED_AT>`. With `RESHELF_UPDATE_GOLDEN=1` the test writes new golden
files; the developer reviews them with `git diff`.

Example: `$env:RESHELF_UPDATE_GOLDEN = '1'; pwsh
legacy/tests/Invoke-ReshelfTests.ps1`.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-13 | Area CLI merged: 52 `AS-CLI-*` requirements (`AS-CLI-001`–`052`) reconciling 46 `AS-DOC-CLI-*` + 39 `AS-CODE-CLI-*`. Two contradictions resolved (`AS-DOC-DEF-101`: plan 11's 6-file UI spec list vs the real 10 files — files right, plan stale; `AS-DOC-DEF-102`: plan 01's missing `ui` command vs the README/code — README/code right, plan stale). `AS-DOC-DEF-111` (Cross-cutting, deferred by DAT/SET/DSC) closed out here — every `AS-DOC-CLI-*` path citation corrected to `legacy/`-relative, consistent with the already-merged `AS-DAT-004`. Seven suspected defects carried forward (`CF-CLI-001`–`007`): four `AS-DOC-DEF-*` (`100`, `103`, `104`, `105`) and all three `AS-CODE-DEF-CLI-*`. Two doc items redirected with no new id to already-merged items (`AS-DOC-CLI-003`→`AS-SET-033`, `AS-DOC-CLI-004`→`AS-DAT-003`/`004`); two more (`AS-DOC-CLI-014`/`015`) folded into already-merged `AS-REV-032`/`033`'s own `Source:` lines while still getting a thin dispatch-level `AS-CLI-015` here. `AS-CODE-CLI-029`–`034` (`lossy remove`/`lossy export`) surfaced two subcommands the doc-side command table omitted entirely, even though `AS-LSY-022` had already named them from the ledger's own side. |
