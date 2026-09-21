# Step 1 — Repo and Tooling Scaffolding

## Purpose / scope

Set up the repo structure, external tool dependencies, and dev tooling that every
other step builds on. Nothing else should be written before this step exists,
because later files reference these paths and tools by name.

## Inputs / outputs

- Input: none (first step).
- Output: repo folder structure, a list of externally-installed tools, and the
  `TAGGER_HOME` data-directory convention used everywhere else.

## Detailed design

### Repo tree

```
tagger/
  MANIFESTO.md
  plan/                          (this folder)
  scripts/
    common/
      Tagger.Common.psm1         path/hashing/logging helpers
      Tagger.Settings.psm1       see 04-settings-module.md
      Tagger.Discogs.psm1        see 02-discogs-account-and-api-access.md
      Tagger.Json.psm1           schema validation helpers (Test-Json wrappers)
      Tagger.Recognition.psm1    see 05-recognition-module.md
    01-recognition/
      Invoke-Recognition.ps1
    02-edit-proposal/
      Invoke-EditProposal.ps1
    03-implementation/
      Invoke-Implementation.ps1
    Tagger.ps1                   dispatcher: settings|session|recognize|propose|apply|lossy
  ui/
    index.html
    app.js
    styles.css
  tests/
    fixtures/
      sample-source-tree/
      discogs-responses/
    *.Tests.ps1                  Pester specs
  schemas/
    recognition.schema.json
    proposal.schema.json
    settings.schema.json
    session.schema.json
    lossy-tracking.schema.json
  config/
    settings.default.json
```

### Data directory (outside the repo)

All *user data* — real settings, sessions, generated `recognition.json` /
`proposal.json`, the lossy-tracking ledger, the Discogs cache, and logs — lives
outside the repo:

- Default: `%LOCALAPPDATA%\Tagger`
- Override: `TAGGER_HOME` environment variable
- Resolved by `Resolve-TaggerDataHome` in `Tagger.Settings.psm1` (see [04](04-settings-module.md))

Reason: the repo is source code + plan + schemas + test fixtures only. Real music
folder paths, a Discogs token, and session state are machine-specific and must
never end up in git history.

### External tools to install manually

These are installed once, by hand, on the machine that runs Tagger — not
automated by any script, since this is a personal single-user tool:

| Tool | Purpose | Used by |
|------|---------|---------|
| [ffmpeg](https://ffmpeg.org/) | Resize cover art to 600×600, and split single-file+cue releases into tracks (both lossless and lossy) | [08](08-implementation-module.md) |

Tag reading and writing (including cover art embedding) both go through **TagLibSharp**, a .NET
library loaded in-process via `Add-Type` — not an externally-installed tool, see
[05](05-recognition-module.md) and [08](08-implementation-module.md).

Confirmed during the scaffolding spike (2026-09-19): cuetools/shntool/mp3splt
have no winget package and no reliable Windows install path, so the plan uses
**ffmpeg alone** for cue-sheet splitting instead — one tool instead of three,
already a dependency, and `-c copy` extracts segments losslessly (no
re-encoding) for both flac-family and mp3-family sources. See
[08](08-implementation-module.md) for the exact approach.

Install:
- ffmpeg: `winget install Gyan.FFmpeg`

### Dev tooling

- **PowerShell 7** (`pwsh`) — every script starts with `#Requires -Version 7.4` (bumped from 7.0 in milestone 2, since `Test-Json`'s `-LiteralPath` and full JSON Schema 2020-12 support require 7.4+).
- **Pester** — unit tests (see [11](11-testing-and-verification-strategy.md)). Installed as v6.2.0 (2026-09-19); Windows ships an old built-in v3.4.0 which is left alone — always invoke `Import-Module Pester -MinimumVersion 5.0` or run via a version-pinned `Invoke-Pester` to avoid picking up the built-in one.
- **PSScriptAnalyzer** — linting. Installed as v1.25.0.

### `.gitignore`

Exclude anything machine-specific that could leak a real path or the Discogs
token:

```
config/settings.json
*.local.json
```

(`config/settings.default.json` — a template with placeholder values — is
committed; the real `settings.json` lives under `TAGGER_HOME`, not the repo, so
this entry is a safety net rather than the primary control.)

## Decisions & rationale

- **Data outside the repo**: keeps the git history free of personal file paths
  and secrets, and survives a `git clone`/reinstall cleanly.
- **One `.psm1` per concern**: matches the manifesto's "independently developed
  modules" intent (§7) while staying inside a single PowerShell project instead
  of five separate ones — simpler for a single maintainer.
## Edge cases

None specific to this step — see [10](10-error-handling-and-edge-cases.md) for
cross-cutting concerns.

## Manual setup

1. Install PowerShell 7, ffmpeg.
2. Install Pester 5 and PSScriptAnalyzer (`Install-Module Pester -MinimumVersion 5.0`, `Install-Module PSScriptAnalyzer`).
3. Create the folder tree above.
4. Set `TAGGER_HOME` if the default `%LOCALAPPDATA%\Tagger` location isn't wanted.

## Definition of done

- Folder tree exists and matches the layout above.
- `ffmpeg` resolves on `PATH` or via a documented full path in `settings.json`,
  callable from a fresh `pwsh` shell.
- `Resolve-TaggerDataHome` returns a real, writable directory.
