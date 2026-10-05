# Step 4 — Settings Module

## Purpose / scope

Resolve source/target roots, naming templates, copy mode, and
session state — the configuration every other module reads before doing
anything. Matches manifesto §7 module 1. `copyMode` only ever accepts
`"copy"` — a "move" mode existed briefly and was removed after it destroyed
source releases with no other backup; source files are always read-only to
Reshelf.

## Inputs / outputs

- Input: `config/settings.default.json` (template), user input on first run.
- Output: real `settings.json` under `RESHELF_HOME`; `session.json` per run
  (schemas in [03](03-domain-model-and-json-schemas.md)).

## Detailed design

### `Reshelf.Settings.psm1` functions

`Resolve-ReshelfDataHome` is defined in `Reshelf.Common.psm1` (step 1), not here —
`Reshelf.Settings.psm1` imports it rather than redefining it.

- `Get-ReshelfSettings` — reads `settings.json` from the data home; if missing,
  triggers `Initialize-ReshelfSettings`.
- `Initialize-ReshelfSettings` — interactive first-run wizard: prompts for
  target root (required), default source root (optional), copy-vs-move
  (default `copy`).
- `Set-ReshelfSettings -Key ... -Value ...` — updates and persists one setting.

### CLI shape (`Reshelf.ps1`)

- `Reshelf.ps1 settings show`
- `Reshelf.ps1 settings init`
- `Reshelf.ps1 settings set -Key targetRoot -Value E:\Music`
- `Reshelf.ps1 recognize [-SourceRoot <path>] [-SaveAsDefault]` — matches the
  manifesto's `/run c:\downloads\folder` example (§3): `-SourceRoot` overrides
  `defaultSourceRoot` for this run only, unless `-SaveAsDefault` is passed.

### Naming templates

`namingTemplates.releaseFolder` / `.trackFile` are format strings with
placeholders (`{year}`, `{album}`, `{artist}`, `{trackNumber}`, `{title}`).
Defaults match manifesto §4 exactly (`"{year} {album}"`, `"{trackNumber} {title}"`)
but are configurable in case the target format ever needs to change without
code edits.

`trackNumberPadWidth`: a configurable *floor*, not a fixed value — the actual
per-release width is `max(settings.trackNumberPadWidth, digits needed for the
release's total track count across all discs)`. The setting defaults to 2, so
a 150-track box set still gets 3-digit numbers and everything else still gets
the manifesto's standard 2 digits unless the setting is raised.

### Session persistence

- `New-ReshelfSession -SourceRoot <path>` — creates `session.json` with a
  generated `sessionId` (e.g. `yyyy-MM-dd-NNNN`), `stage = "recognized"` once
  step 5 finishes.
- `Resume-ReshelfSession -SessionId <id>` — loads `session.json`, prints the
  current `stage` and the next command to run (see
  [10](10-error-handling-and-edge-cases.md) for the full resume flow).
- `Set-ReshelfSessionStage -SessionId <id> -Stage <stage>` — sets any stage
  (`recognized`/`proposed`/`reviewed`/`applied`/`partially-applied`); every
  module that finishes a step calls this itself. A separate
  `Complete-ReshelfSession` (fixed to `stage = "applied"`) existed briefly but
  was removed as dead code — nothing called it and `Set-ReshelfSessionStage`
  already covers the same case.
- CLI: `Reshelf.ps1 session list|resume|show|mark-reviewed`.

## Decisions & rationale

- **Per-release pad width instead of a fixed 2**: the manifesto's own examples
  always use 2-digit numbers, but a hardcoded width would silently break on
  any release with 100+ tracks (misordered filenames) — computing it avoids a
  latent bug for a rare but real case.
- **`-SourceRoot` doesn't persist unless asked**: matches the manifesto's
  stated usage pattern directly (§3) — most runs are one-off imports from a
  USB drive or Downloads folder, not the default source.

## Edge cases

- First run with no `settings.json` and no interactive terminal (e.g. run from
  a scheduled task) → `Initialize-ReshelfSettings` fails fast with a clear
  error instead of hanging on a prompt.
- `targetRoot` not writable → fail fast at settings load time, not partway
  through Implementation.

## Manual setup

None beyond step 1's scaffolding.

## Definition of done

- `Reshelf.ps1 settings init` produces a valid `settings.json` matching
  `schemas/settings.schema.json`.
- `Reshelf.ps1 recognize -SourceRoot D:\test` uses `D:\test` for that run
  without changing `defaultSourceRoot`.
- `Reshelf.ps1 session resume <id>` correctly reports the next step for a
  session at each possible `stage` value.
