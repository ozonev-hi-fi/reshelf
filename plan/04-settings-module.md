# Step 4 — Settings Module

## Purpose / scope

Resolve source/target roots, naming templates, copy-vs-move mode, and
session state — the configuration every other module reads before doing
anything. Matches manifesto §7 module 1.

## Inputs / outputs

- Input: `config/settings.default.json` (template), user input on first run.
- Output: real `settings.json` under `TAGGER_HOME`; `session.json` per run
  (schemas in [03](03-domain-model-and-json-schemas.md)).

## Detailed design

### `Tagger.Settings.psm1` functions

`Resolve-TaggerDataHome` is defined in `Tagger.Common.psm1` (step 1), not here —
`Tagger.Settings.psm1` imports it rather than redefining it.

- `Get-TaggerSettings` — reads `settings.json` from the data home; if missing,
  triggers `Initialize-TaggerSettings`.
- `Initialize-TaggerSettings` — interactive first-run wizard: prompts for
  target root (required), default source root (optional), copy-vs-move
  (default `copy`).
- `Set-TaggerSettings -Key ... -Value ...` — updates and persists one setting.

### CLI shape (`Tagger.ps1`)

- `Tagger.ps1 settings show`
- `Tagger.ps1 settings init`
- `Tagger.ps1 settings set -Key targetRoot -Value E:\Music`
- `Tagger.ps1 recognize [-SourceRoot <path>] [-SaveAsDefault]` — matches the
  manifesto's `/run c:\downloads\folder` example (§3): `-SourceRoot` overrides
  `defaultSourceRoot` for this run only, unless `-SaveAsDefault` is passed.

### Naming templates

`namingTemplates.releaseFolder` / `.trackFile` are format strings with
placeholders (`{year}`, `{album}`, `{artist}`, `{trackNumber}`, `{title}`).
Defaults match manifesto §4 exactly (`"{year} {album}"`, `"{trackNumber} {title}"`)
but are configurable in case the target format ever needs to change without
code edits.

`trackNumberPadWidth`: computed per-release, not fixed — `max(2, digits needed
for the release's total track count across all discs)`. A 150-track box set
gets 3-digit numbers; everything else gets the manifesto's standard 2 digits.

### Session persistence

- `New-TaggerSession -SourceRoot <path>` — creates `session.json` with a
  generated `sessionId` (e.g. `yyyy-MM-dd-NNNN`), `stage = "recognized"` once
  step 5 finishes.
- `Resume-TaggerSession -SessionId <id>` — loads `session.json`, prints the
  current `stage` and the next command to run (see
  [10](10-error-handling-and-edge-cases.md) for the full resume flow).
- `Complete-TaggerSession -SessionId <id>` — sets `stage = "applied"`.
- CLI: `Tagger.ps1 session list|resume|show`.

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
  a scheduled task) → `Initialize-TaggerSettings` fails fast with a clear
  error instead of hanging on a prompt.
- `targetRoot` not writable → fail fast at settings load time, not partway
  through Implementation.

## Manual setup

None beyond step 1's scaffolding.

## Definition of done

- `Tagger.ps1 settings init` produces a valid `settings.json` matching
  `schemas/settings.schema.json`.
- `Tagger.ps1 recognize -SourceRoot D:\test` uses `D:\test` for that run
  without changing `defaultSourceRoot`.
- `Tagger.ps1 session resume <id>` correctly reports the next step for a
  session at each possible `stage` value.
