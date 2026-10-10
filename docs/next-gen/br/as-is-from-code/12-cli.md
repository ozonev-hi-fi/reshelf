# As-Is (from code): CLI

Status: Draft | Version: 0.1 | Last updated: 2026-10-10

Area code: CLI. Source: `legacy/scripts/Reshelf.ps1` only. Read directly from code, independent of
`docs/next-gen/br/as-is-from-docs/`.

### AS-CODE-CLI-001 — Command is a mandatory, closed-set positional argument
Status: Draft | Source: legacy/scripts/Reshelf.ps1:4 › param block (`$Command` ValidateSet)

`Command` is mandatory, bound positionally (position 0), and restricted by `ValidateSet` to exactly:
`settings`, `session`, `recognize`, `propose`, `apply`, `lossy`, `ui`. Any other value is rejected by
PowerShell's own parameter binding before the script body ever runs — there is no custom error message
for an invalid top-level command, and no `default` branch in the dispatch `switch` (none is reachable).

### AS-CODE-CLI-002 — `settings show`
Status: Draft | Source: legacy/scripts/Reshelf.ps1:46 › 'settings' switch

Takes no parameters. Prints the full current settings object as JSON (`ConvertTo-Json -Depth 10`).

### AS-CODE-CLI-003 — `settings init`
Status: Draft | Source: legacy/scripts/Reshelf.ps1:48 › 'settings' switch

Accepts `-TargetRoot`, `-DefaultSourceRoot`, `-CopyMode`, and `-Force` (switch). All four are passed
straight through to the settings initializer. Prints the resulting settings object as JSON.

### AS-CODE-CLI-004 — `settings set`
Status: Draft | Source: legacy/scripts/Reshelf.ps1:52 › 'settings' switch

Accepts `-Key` and `-Value` as plain strings with no local validation in this script — any restriction
on which keys/values are acceptable is enforced downstream, not by the CLI's own parameter block.
Prints the resulting settings object as JSON.

### AS-CODE-CLI-005 — `settings set-token`
Status: Draft | Source: legacy/scripts/Reshelf.ps1:53 › 'settings' switch

Takes no CLI-level parameters (the Discogs token is obtained internally, e.g. interactively or from an
environment variable). Prints the resulting settings object as JSON.

### AS-CODE-CLI-006 — Unknown `settings` subcommand
Status: Draft | Source: legacy/scripts/Reshelf.ps1:54 › 'settings' switch default

An unrecognized `SubCommand` under `settings` throws
`"Unknown 'settings' subcommand '<value>'. Use show, init, set, or set-token."`.

### AS-CODE-CLI-007 — `session list`
Status: Draft | Source: legacy/scripts/Reshelf.ps1:59 › 'session' switch

Takes no parameters. Lists every session's `sessionId`, `stage`, `sourceRoot`, `updatedAtUtc` as a
human-readable table (`Format-Table`) — not machine-parseable JSON output, unlike most other commands.

### AS-CODE-CLI-008 — `session show`
Status: Draft | Source: legacy/scripts/Reshelf.ps1:60 › 'session' switch

Requires `-SessionId` (or the positional session-id slot, position 2); missing it throws
`"'session show' requires a session id."`. Prints the full session object as JSON (`-Depth 10`).

### AS-CODE-CLI-009 — `session resume`
Status: Draft | Source: legacy/scripts/Reshelf.ps1:64 › 'session' switch

Requires a session id, same missing-id error pattern as `session show`. Prints the result as
`Format-List` (not JSON).

### AS-CODE-CLI-010 — `session mark-reviewed`
Status: Draft | Source: legacy/scripts/Reshelf.ps1:68 › 'session' switch

Requires a session id, same missing-id error pattern. Sets that session's stage to the literal string
`reviewed`, then re-fetches and prints the session as `Format-List`.

### AS-CODE-CLI-011 — Unknown `session` subcommand
Status: Draft | Source: legacy/scripts/Reshelf.ps1:74 › 'session' switch default

Throws `"Unknown 'session' subcommand '<value>'. Use list, show, resume, or mark-reviewed."`.

### AS-CODE-CLI-012 — `recognize` source root resolution and defaulting
Status: Draft | Source: legacy/scripts/Reshelf.ps1:77 › 'recognize' case

`recognize` has no subcommands. `-SourceRoot` is optional; if omitted, it falls back to the current
settings' `defaultSourceRoot`. If neither is available, it throws a message that names both options:
pass `-SourceRoot`, or run `Reshelf.ps1 settings set -Key defaultSourceRoot -Value <path>` first.

### AS-CODE-CLI-013 — `-SaveAsDefault` only applies with an explicit `-SourceRoot`
Status: Draft | Source: legacy/scripts/Reshelf.ps1:84 › 'recognize' case

The `-SaveAsDefault` switch only has an effect when combined with an explicit `-SourceRoot` on the same
invocation — it persists that value as the new `defaultSourceRoot` setting before recognition runs.
Passing `-SaveAsDefault` alone (relying on the existing default) does nothing.

### AS-CODE-CLI-014 — `recognize` always creates a brand-new session
Status: Draft | Source: legacy/scripts/Reshelf.ps1:88 › 'recognize' case

Every `recognize` invocation creates a new session; there is no "resume and re-recognize into the same
session" path. If recognition fails, the thrown error explicitly tells the user to re-run
`recognize -SourceRoot <path>` — which creates yet another new session rather than reusing the one that
just failed (which is left behind with no `recognition.json`).

### AS-CODE-CLI-015 — `recognize` success output
Status: Draft | Source: legacy/scripts/Reshelf.ps1:96 › 'recognize' case

Prints `SessionId`, `ArtistCount`, `ReleaseCount`, `UnrecognizedCount` as a `Format-List` summary —
counts only, not the full recognition data.

### AS-CODE-CLI-016 — `propose` requires a session id
Status: Draft | Source: legacy/scripts/Reshelf.ps1:103 › 'propose' case

Throws `"'propose' requires a session id. Usage: Reshelf.ps1 propose -SessionId <id>"` if not given.

### AS-CODE-CLI-017 — `propose` takes all its real inputs from current settings, not its own parameters
Status: Draft | Source: legacy/scripts/Reshelf.ps1:108 › 'propose' case

Beyond `-SessionId`, `propose` has no parameters of its own for target root, naming templates, track
number pad width, cover max dimension, cache TTL, or rate limit — all of these are read live from the
current settings at the moment `propose` runs. Re-running `propose` on the same session after changing
settings applies the new settings against that session's existing (unchanged) `recognition.json`.

### AS-CODE-CLI-018 — `propose` wraps failures with session context
Status: Draft | Source: legacy/scripts/Reshelf.ps1:119 › 'propose' case

A failure during proposal generation is caught and rethrown as
`"Edit proposal failed for session '<id>': <original message>"`.

### AS-CODE-CLI-019 — `propose` success: records stage and prints a summary
Status: Draft | Source: legacy/scripts/Reshelf.ps1:123 › 'propose' case

On success, the session's stage is set to `proposed` with the `proposal.json` path recorded, then a
`Format-List` summary is printed: `SessionId`, `ArtistCount`, `ReleaseCount`, `MatchedCount` (releases
with `discogsMatch.status -eq 'matched'`), `NeedsReviewCount` (releases with `humanReview.required`).

### AS-CODE-CLI-020 — `apply` requires a session id
Status: Draft | Source: legacy/scripts/Reshelf.ps1:135 › 'apply' case

Throws `"'apply' requires a session id. Usage: Reshelf.ps1 apply -SessionId <id>"` if not given.

### AS-CODE-CLI-021 — `apply` parameters: settings plus two switches
Status: Draft | Source: legacy/scripts/Reshelf.ps1:144 › 'apply' case

`apply`'s only own parameters are `-IncludeUnresolved` and `-WhatIf` (both switches); target root, copy
mode, ffmpeg path, TagLib# path, and data home are all taken from current settings, same pattern as
`propose` (AS-CODE-CLI-017).

### AS-CODE-CLI-022 — `apply` is the only command that actually wires up `-WhatIf`
Status: Draft | Source: legacy/scripts/Reshelf.ps1:144 › 'apply' case

Although `-WhatIf` is declared as a script-level parameter (available to every command), only the
`apply` branch forwards it into a function that supports `ShouldProcess`
(`Invoke-ReshelfImplementation`). Passing `-WhatIf` to any other command has no effect.

### AS-CODE-CLI-023 — `apply` has no try/catch of its own
Status: Draft | Source: legacy/scripts/Reshelf.ps1:144 › 'apply' case

Unlike `recognize` (AS-CODE-CLI-014's catch) and `propose` (AS-CODE-CLI-018), the `apply` case does not
wrap `Invoke-ReshelfImplementation` in a local `try`/`catch` — an exception there propagates with its
original, unwrapped message.

### AS-CODE-CLI-024 — `apply` always prints a result summary
Status: Draft | Source: legacy/scripts/Reshelf.ps1:148 › 'apply' case

Prints `SessionId`, `Applied`, `Skipped`, `Rejected`, `Failed` as a `Format-List`, regardless of whether
any release failed.

### AS-CODE-CLI-025 — `apply` prints per-release failure detail, scoped to the session
Status: Draft | Source: legacy/scripts/Reshelf.ps1:156 › 'apply' case

When `Failed > 0`, the session's own `proposal.json` is re-read to get its own set of `stableKey`
values, and the apply log is filtered down to only `failed` entries whose `stableKey` is in that set —
because the apply log is shared across every session ever applied, and an unrelated stable key could
otherwise still be sitting there as `failed` from a previous, unrelated run. Each matching entry's
`StableKey`, `TargetPath`, `ErrorMessage` is printed via `Format-List`, preceded by a yellow
`"Failed releases:"` heading written with `Write-Host` (not pipeline output).

### AS-CODE-CLI-026 — `ui start`
Status: Draft | Source: legacy/scripts/Reshelf.ps1:177 › 'ui' switch

If `-Port` is given (a non-zero value), it is forwarded to `Start-ReshelfUiServer.ps1`; otherwise that
script is invoked with no `-Port` argument at all, letting its own internal default apply.

### AS-CODE-CLI-027 — Unknown `ui` subcommand
Status: Draft | Source: legacy/scripts/Reshelf.ps1:183 › 'ui' switch default

Throws `"Unknown 'ui' subcommand '<value>'. Use start."`.

### AS-CODE-CLI-028 — `lossy list`
Status: Draft | Source: legacy/scripts/Reshelf.ps1:188 › 'lossy' switch

An optional `-Status` filters the ledger (ValidateSet: `pending-upgrade`, `upgraded`, `ignored`) before
display. Shows a `Format-Table` with columns `stableKey, artist, album, year, format, status,
targetPath` — notably fewer columns than `lossy export`'s CSV form (AS-CODE-CLI-032).

### AS-CODE-CLI-029 — `lossy ignore` / `lossy mark-upgraded` / `lossy remove` reuse the session-id slot as a stable key
Status: Draft | Source: legacy/scripts/Reshelf.ps1:193,198,203 › 'lossy' switch

These three subcommands have no dedicated `-StableKey` parameter: they read the stable key from the
same positional/`-SessionId` slot used by the `session` command, immediately aliased to a local
`$stableKey` variable. Each throws its own `"'lossy <subcommand>' requires a stable key."` if that slot
is empty.

### AS-CODE-CLI-030 — `lossy export` requires a path, supports CSV or JSON
Status: Draft | Source: legacy/scripts/Reshelf.ps1:208 › 'lossy' switch

Requires `-Path` (the output file); throws `"'lossy export' requires -Path <file> (the output file
path)."` if missing. Accepts the same optional `-Status` filter as `lossy list`. `-Format` defaults to
`csv` (the script's own parameter default) and accepts only `csv` or `json` (`ValidateSet`).

### AS-CODE-CLI-031 — `lossy export` JSON output
Status: Draft | Source: legacy/scripts/Reshelf.ps1:214 › 'lossy' switch

With `-Format json`, the (optionally filtered) ledger is serialized with `ConvertTo-Json -Depth 10` and
written via `Set-Content -Encoding utf8`.

### AS-CODE-CLI-032 — `lossy export` CSV output: a wider fixed column set
Status: Draft | Source: legacy/scripts/Reshelf.ps1:217 › 'lossy' switch

With `-Format csv` (the default), the ledger is projected to a fixed column set — `stableKey, artist,
album, year, format, status, targetPath, firstDetectedUtc, lastCheckedUtc, upgradedUtc, notes` — and
written with `Export-Csv -NoTypeInformation -Encoding utf8`. This is a superset of the columns shown by
`lossy list` (AS-CODE-CLI-028).

### AS-CODE-CLI-033 — `lossy export` confirmation message
Status: Draft | Source: legacy/scripts/Reshelf.ps1:221 › 'lossy' switch

Prints a plain string `"Exported <N> entries to <Path>"`, where `N` is the count of the filtered ledger
actually written (not the unfiltered ledger's total count).

### AS-CODE-CLI-034 — Unknown `lossy` subcommand
Status: Draft | Source: legacy/scripts/Reshelf.ps1:223 › 'lossy' switch default

Throws `"Unknown 'lossy' subcommand '<value>'. Use list, ignore, mark-upgraded, remove, or export."`.

### AS-CODE-CLI-035 — No top-level try/catch around command dispatch
Status: Draft | Source: legacy/scripts/Reshelf.ps1:44 › top-level `switch ($Command)`

The entire `switch ($Command) { ... }` dispatch block has no enclosing `try`/`catch` of its own. Any
uncaught `throw` — whether from this script's own subcommand validation, or from deep inside a called
module — propagates all the way up through PowerShell's default engine behavior.

### AS-CODE-CLI-036 — Exit codes are never set explicitly
Status: Draft | Source: legacy/scripts/Reshelf.ps1 (whole file)

No command path calls `exit`, sets `$LASTEXITCODE`, or calls `$host.SetShouldExit` anywhere in this
script. The process's exit code is left entirely to PowerShell's own default behavior: 0 when the
script runs to completion, non-zero when a terminating error (any uncaught `throw`, from this script or
a module it calls) ends execution early.

### AS-CODE-CLI-037 — `-Format` is a script-wide parameter but only `lossy export` reads it
Status: Draft | Source: legacy/scripts/Reshelf.ps1:27 › param block (`$Format` default `csv`)

`-Format` is declared at the script's top-level parameter block (so it is syntactically acceptable with
any command) with a default of `csv`, but only the `lossy export` subcommand ever reads its value.
Passing `-Format` to any other command is silently accepted and ignored.

### AS-CODE-CLI-038 — `-Status` filter is shared between `lossy list` and `lossy export` only
Status: Draft | Source: legacy/scripts/Reshelf.ps1:22 › param block (`$Status` ValidateSet)

`-Status` (`ValidateSet`: `pending-upgrade`, `upgraded`, `ignored`) is used only to filter the ledger in
`lossy list` and `lossy export`. It is never combined with the stable-key-via-`-SessionId` subcommands
(`ignore`, `mark-upgraded`, `remove`), which operate on exactly one entry identified by key, not a
filtered set.

### AS-CODE-CLI-039 — `settings init`'s `-CopyMode` has no local restriction
Status: Draft | Source: legacy/scripts/Reshelf.ps1:18 › param block (`$CopyMode`, no ValidateSet)

`-CopyMode`, accepted by `settings init`, is a free string in this script's own parameter block (no
`ValidateSet`) — unlike `Invoke-ReshelfImplementation`'s own `CopyMode` parameter, which is restricted
to the single value `'copy'` (AS-CODE-APL-049). Any restriction on acceptable `CopyMode` values for
`settings init` is therefore enforced downstream (in the settings module), not by this CLI script.

## Suspected defects

- `AS-CODE-DEF-CLI-001` — legacy/scripts/Reshelf.ps1:144-154 (`'apply'` case): this is the only
  long-running command (`recognize`, `propose`, `apply`) without its own `try`/`catch` that adds
  user-facing context before rethrowing. An `apply`-time failure surfaces as a raw, unwrapped
  PowerShell error instead of the `"<Step> failed for session '<id>': <message>"` style the other two
  give, which is inconsistent given the otherwise-parallel structure of these three cases.
- `AS-CODE-DEF-CLI-002` — legacy/scripts/Reshelf.ps1:193-206 (`'ignore'`, `'mark-upgraded'`, `'remove'`
  under `'lossy'`): these subcommands read a lossy-ledger stable key out of the `-SessionId` parameter
  (immediately aliased to `$stableKey`), rather than a dedicated `-StableKey` parameter. A scripted
  caller passing `-SessionId` to a `lossy` subcommand, reasonably expecting it to mean a session (as it
  does for every `session` subcommand), would be silently operating on a ledger stable key instead.
- `AS-CODE-DEF-CLI-003` — legacy/scripts/Reshelf.ps1:27-29 (`$Format` default `'csv'`): the default is
  declared once, at script scope, for a parameter name that currently only `lossy export` reads. This is
  harmless today, but any future command parameter also named `-Format` would silently inherit this
  default rather than one of its own.

## Changelog

| Version | Date | Changes |
|---|---|---|
| 0.1 | 2026-10-10 | Phase 2 draft from code. |
