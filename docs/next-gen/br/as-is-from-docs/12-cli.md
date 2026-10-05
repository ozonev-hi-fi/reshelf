# 12 — CLI (as-is, from docs and tests)

Status: Draft | Version: 0.1 | Last updated: 2026-10-05

## Scope

The command-line surface of the legacy app: commands, parameters, defaults, dispatch for `settings` and `session`, errors and exit codes. Also the developer side: how the tests run. Owned inputs: `legacy/tests/Reshelf.Tests.ps1`, `legacy/tests/Invoke-ReshelfTests.ps1`, the Playwright setup files in `legacy/tests/ui/` (`playwright.config.js`, `global-setup.js`, `global-teardown.js`, `helpers.js`, `seed-session.ps1`, `fixtures/`), `legacy/plan/01-repo-and-tooling-scaffolding.md`, `legacy/plan/11-testing-and-verification-strategy.md`, the `legacy/README.md` section "For developers", and every CLI command and parameter that appears anywhere in `legacy/README.md`. What each stage does inside is in the stage area files. This file only names the command.

All paths in the README are relative to the old repo root. Since the Phase 0 move, they are relative to `legacy/` (for example `legacy/scripts/Reshelf.ps1`). See AS-DOC-DEF-111 in [90-suspected-defects.md](90-suspected-defects.md).

## Entry point and dispatch

### AS-DOC-CLI-001 — One entry script with a command word
Status: Draft | Source: legacy/README.md › Pipeline; legacy/tests/Reshelf.Tests.ps1 › Reshelf.ps1 settings/session dispatch › (helper `Invoke-Reshelf`); legacy/plan/01-repo-and-tooling-scaffolding.md › Dev tooling

The user runs every command through one script with PowerShell 7.4 or newer: `pwsh scripts/Reshelf.ps1 <command> [<subcommand>] [-Param value]`. Every script starts with `#Requires -Version 7.4`.

Example: `pwsh scripts/Reshelf.ps1 settings show`. `pwsh scripts/Reshelf.ps1 apply -SessionId 2026-09-25-0007 -WhatIf`.

### AS-DOC-CLI-002 — The command set
Status: Draft | Source: legacy/README.md › Pipeline; legacy/README.md › Step-by-step: organizing a folder; legacy/README.md › Sessions and resuming; legacy/README.md › Reference: lossy/lossless tracking; legacy/plan/01-repo-and-tooling-scaffolding.md › Repo tree

The script knows these commands:

| Command | Subcommands | Parameters |
|---|---|---|
| `settings` | `init`, `show`, `set`, `set-token` | `init`: `-TargetRoot`, `-DefaultSourceRoot`, `-Force`; `set`: `-Key`, `-Value` |
| `recognize` | — | `-SourceRoot`, `-SaveAsDefault` |
| `propose` | — | `-SessionId` |
| `ui` | `start` | `-Port` |
| `apply` | — | `-SessionId`, `-WhatIf`, `-IncludeUnresolved` |
| `session` | `list`, `show`, `resume`, `mark-reviewed` | `<id>` or `-SessionId` |
| `lossy` | `list`, `ignore`, `mark-upgraded` | `list`: `-Status`; others: `<stableKey>` |

Example: `pwsh scripts/Reshelf.ps1 lossy list -Status pending-upgrade`.

### AS-DOC-CLI-003 — A stage command runs "settings init" first when settings.json is missing
Status: Draft | Source: legacy/README.md › One-time setup (note)

Same rule as AS-DOC-SET-033 in [03-settings-and-secrets.md](03-settings-and-secrets.md) (primary, from tests). This entry keeps the README note as its source.

When `settings.json` does not exist, the first `recognize`, `propose`, `apply` or `ui start` command runs `settings init` first. The setup itself: see [03-settings-and-secrets.md](03-settings-and-secrets.md).

Example: a fresh data home, `pwsh scripts/Reshelf.ps1 recognize -SourceRoot D:\Music` → the `settings init` prompts appear first.

### AS-DOC-CLI-004 — The data home comes from RESHELF_HOME
Status: Draft | Source: legacy/tests/Reshelf.Tests.ps1 › Reshelf.ps1 settings/session dispatch › (BeforeEach); legacy/plan/01-repo-and-tooling-scaffolding.md › Data directory (git-ignored, not committed)

Every command uses the data home from the `RESHELF_HOME` environment variable, or the default `.data\` folder. See [01-data-home-and-storage.md](01-data-home-and-storage.md).

Example: `RESHELF_HOME=C:\Temp\rh` → `settings init` writes `C:\Temp\rh\settings.json`.

## settings

### AS-DOC-CLI-005 — "settings init" creates settings.json; parameters make it non-interactive
Status: Draft | Source: legacy/tests/Reshelf.Tests.ps1 › Reshelf.ps1 settings/session dispatch › settings init produces valid output and a schema-valid settings.json; … › recognize -SourceRoot without -SaveAsDefault leaves defaultSourceRoot unchanged; legacy/tests/ui/global-setup.js › globalSetup; legacy/README.md › One-time setup

`settings init` asks for the setup values. The values can also come as parameters: `-TargetRoot`, `-DefaultSourceRoot`. `-Force` is used for a run with no prompts (the UI test setup uses it). On success the exit code is 0 and `settings.json` exists in the data home. The prompts, defaults and checks: see [03-settings-and-secrets.md](03-settings-and-secrets.md).

Example: `settings init -TargetRoot <temp>\target` → exit 0, `<dataHome>\settings.json` exists. `settings init -TargetRoot <t> -DefaultSourceRoot <s>` → `defaultSourceRoot = <s>`.

### AS-DOC-CLI-006 — "settings show" prints the settings as JSON
Status: Draft | Source: legacy/tests/Reshelf.Tests.ps1 › Reshelf.ps1 settings/session dispatch › settings show prints JSON containing the expected keys; legacy/README.md › One-time setup; legacy/README.md › Reference: settings

`settings show` prints the current settings as JSON.

Example: after `settings init -TargetRoot <temp>\target` → the JSON has `targetRoot = "<temp>\target"`.

### AS-DOC-CLI-007 — "settings set" changes one top-level key
Status: Draft | Source: legacy/README.md › Reference: settings; legacy/tests/ui/global-setup.js › globalSetup

`settings set -Key <key> -Value <value>` changes one simple (not nested) key. Nested keys such as `namingTemplates.releaseFolder` need a hand edit of `settings.json`. Key list and checks: see [03-settings-and-secrets.md](03-settings-and-secrets.md).

Example: `settings set -Key taglibSharpPath -Value <repo>\.data\lib\TagLibSharp.dll`.

### AS-DOC-CLI-008 — "settings set-token" stores the Discogs token
Status: Draft | Source: legacy/README.md › One-time setup; legacy/README.md › Troubleshooting / known limitations

`settings set-token` asks for the Discogs Personal Access Token and stores it. The user runs it again after a Discogs `401 Unauthorized`. Storage and lookup order: see [03-settings-and-secrets.md](03-settings-and-secrets.md).

Example: `pwsh scripts/Reshelf.ps1 settings set-token`.

## recognize

### AS-DOC-CLI-009 — "recognize" uses -SourceRoot, or the default source root
Status: Draft | Source: legacy/tests/Reshelf.Tests.ps1 › Reshelf.ps1 settings/session dispatch › recognize fails with a clear error when there is no -SourceRoot and no defaultSourceRoot; legacy/README.md › 1. Recognize

`recognize -SourceRoot <folder>` scans that folder. Without `-SourceRoot`, it uses `defaultSourceRoot` from the settings. When both are missing, it fails with `No source root given` and a non-zero exit code.

Example: `settings init -TargetRoot <t>` (no default), then `recognize` → non-zero exit, output contains `No source root given`.

### AS-DOC-CLI-010 — "-SaveAsDefault" stores the source root as the default
Status: Draft | Source: legacy/tests/Reshelf.Tests.ps1 › Reshelf.ps1 settings/session dispatch › recognize -SaveAsDefault persists the source root to settings; … › recognize -SourceRoot without -SaveAsDefault leaves defaultSourceRoot unchanged; legacy/README.md › 1. Recognize

With `-SaveAsDefault`, `recognize` also saves `-SourceRoot` as `defaultSourceRoot`. Without it, `defaultSourceRoot` stays unchanged.

Example: `recognize -SourceRoot <temp>\source-empty-2 -SaveAsDefault` → `defaultSourceRoot = <temp>\source-empty-2`. Default `source-original-default`, then `recognize -SourceRoot source-other` → default stays `source-original-default`.

### AS-DOC-CLI-011 — "recognize" creates a session and prints a summary
Status: Draft | Source: legacy/tests/Reshelf.Tests.ps1 › Reshelf.ps1 settings/session dispatch › recognize creates a session and prints a summary for a source with no audio files; legacy/README.md › 1. Recognize

Every `recognize` run creates a new session and prints a summary with `SessionId`, `ArtistCount`, `ReleaseCount` and `UnrecognizedCount`. A source without audio files still succeeds (exit 0). What recognize finds: see [05-recognition.md](05-recognition.md).

Example: source with only `Some Artist Folder\readme.txt` → exit 0, output has `SessionId`, one session exists. README sample: `SessionId : 2026-09-25-0007`, `ArtistCount : 42`, `ReleaseCount : 118`, `UnrecognizedCount : 3`.

### AS-DOC-CLI-012 — A recognize failure names the session it already created
Status: Draft | Source: legacy/tests/Reshelf.Tests.ps1 › Reshelf.ps1 settings/session dispatch › recognize surfaces a clear error (naming the orphaned session) when recognition fails after the session is created

When recognition fails after the session was created, the command fails with a non-zero exit code. The message says `Recognition failed for session <id>`. The session stays in the data home.

Example: source with `Some Artist\2020 Some Album\01 - Track.flac` and no `TagLibSharp.dll` → non-zero exit, output contains `Recognition failed for session`, 1 session exists.

## propose

### AS-DOC-CLI-013 — "propose" needs a session id and prints a summary
Status: Draft | Source: legacy/tests/Reshelf.Tests.ps1 › Reshelf.ps1 settings/session dispatch › propose fails with a clear error when no session id is given; legacy/README.md › 2. Propose

`propose -SessionId <id>` runs the proposal for that session. Without a session id it fails with `requires a session id` and a non-zero exit code. On success it prints `SessionId`, `ArtistCount`, `ReleaseCount`, `MatchedCount` and `NeedsReviewCount`. What propose does: see [07-proposal-matching.md](07-proposal-matching.md) and [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md).

Example: `propose` → non-zero exit, `…requires a session id…`. README sample: `MatchedCount : 103`, `NeedsReviewCount : 15`.

## ui

### AS-DOC-CLI-014 — "ui start" opens the review page on port 4173 by default
Status: Draft | Source: legacy/README.md › 3. Review in the browser; legacy/README.md › Troubleshooting / known limitations

`ui start` starts the local UI server and opens `http://localhost:4173/` in the default browser. `-Port <N>` uses another port, for example when 4173 is already in use. The server and page: see [09-review-ui.md](09-review-ui.md).

Example: `pwsh scripts/Reshelf.ps1 ui start` → `http://localhost:4173/`. `ui start -Port 5000` → `http://localhost:5000/`.

### AS-DOC-CLI-015 — The server script can start without a browser
Status: Draft | Source: legacy/tests/ui/global-setup.js › globalSetup

The server script `scripts/Start-ReshelfUiServer.ps1` also runs on its own, with `-Port <N>` and `-NoBrowser`. With `-NoBrowser` it does not open a browser. The UI tests start it this way.

Example: `pwsh -File scripts/Start-ReshelfUiServer.ps1 -Port 53123 -NoBrowser` → `GET http://localhost:53123/` answers OK.

## apply

### AS-DOC-CLI-016 — "apply" needs a session id
Status: Draft | Source: legacy/tests/Reshelf.Tests.ps1 › Reshelf.ps1 settings/session dispatch › apply without a session id exits 1

`apply` without a session id fails with exit code 1.

Example: `pwsh scripts/Reshelf.ps1 apply` → exit 1.

### AS-DOC-CLI-017 — "apply" parameters and summary
Status: Draft | Source: legacy/README.md › 5. Apply; legacy/tests/ui/helpers.js › runApply

`apply -SessionId <id>` applies the session. `-WhatIf` is a dry run with no files touched. `-IncludeUnresolved` also applies releases that nobody reviewed. The command prints `SessionId`, `Applied`, `Skipped`, `Rejected` and `Failed`. What apply does: see [10-apply.md](10-apply.md).

Example: `apply -SessionId 2026-09-25-0007 -WhatIf`. README sample output: `Applied : 96`, `Skipped : 7`, `Rejected : 4`, `Failed : 0`.

## session

### AS-DOC-CLI-018 — "session list" prints all sessions as a table
Status: Draft | Source: legacy/tests/Reshelf.Tests.ps1 › Reshelf.ps1 settings/session dispatch › session list with zero sessions runs without throwing; legacy/README.md › Sessions and resuming

`session list` prints a table of all sessions: id, stage, source root and updated time. With no sessions it still succeeds (exit 0).

Example: empty data home, `session list` → exit 0.

### AS-DOC-CLI-019 — "session show" prints one session as JSON and needs an id
Status: Draft | Source: legacy/tests/Reshelf.Tests.ps1 › Reshelf.ps1 settings/session dispatch › session show without a session id fails with a clear error instead of listing everything; legacy/README.md › Sessions and resuming

`session show <id>` prints the full session details as JSON. Without an id it fails with `requires a session id` and a non-zero exit code. It does not list all sessions instead.

Example: `session show` → non-zero exit, `…requires a session id…`.

### AS-DOC-CLI-020 — "session resume" prints the stage and the next command
Status: Draft | Source: legacy/tests/Reshelf.Tests.ps1 › Reshelf.ps1 settings/session dispatch › session resume via the CLI reports the right next command for every session stage; … › session resume without a session id fails with a clear error; legacy/README.md › Sessions and resuming

`session resume <id>` prints the session stage and the suggested next command (exit 0). Without an id it fails with `requires a session id`. Stages: see [04-sessions.md](04-sessions.md).

| Stage | Suggested next command contains |
|---|---|
| `recognized` | `propose -SessionId <id>` |
| `proposed` | `ui start` … `mark-reviewed -SessionId <id>` |
| `reviewed` | `apply -SessionId <id>` |
| `applied` | `complete` |
| `partially-applied` | `apply -SessionId <id>` |

Example: stage `reviewed` → output contains `apply -SessionId 2026-10-05-0001`.

### AS-DOC-CLI-021 — "session mark-reviewed" sets the stage to reviewed and needs an id
Status: Draft | Source: legacy/tests/Reshelf.Tests.ps1 › Reshelf.ps1 settings/session dispatch › session mark-reviewed sets stage to reviewed and resume reflects it; … › session mark-reviewed without a session id fails with a clear error; legacy/README.md › 4. Mark reviewed (optional)

`session mark-reviewed <id>` sets the stage to `reviewed` (exit 0). Without an id it fails with `requires a session id`. Meaning of this step: see [09-review-ui.md](09-review-ui.md) (AS-DOC-REV-084).

Example: stage `proposed`, `session mark-reviewed -SessionId <id>` → exit 0, stage `reviewed`.

### AS-DOC-CLI-022 — A session id can be given by position or with -SessionId
Status: Draft | Source: legacy/README.md › Sessions and resuming; legacy/README.md › 4. Mark reviewed (optional); legacy/tests/Reshelf.Tests.ps1 › Reshelf.ps1 settings/session dispatch › session mark-reviewed sets stage to reviewed and resume reflects it

The `session` subcommands take the id as the first free value or as `-SessionId <id>`.

Example: `session mark-reviewed 2026-09-25-0007` (README) and `session mark-reviewed -SessionId <id>` (test) both work.

## lossy

### AS-DOC-CLI-023 — "lossy list" prints the ledger, optionally filtered by status
Status: Draft | Source: legacy/tests/Reshelf.Tests.ps1 › Reshelf.ps1 settings/session dispatch › lossy list with an empty ledger runs without throwing; … › lossy list -Status filters to matching entries only; legacy/README.md › Reference: lossy/lossless tracking

`lossy list` prints the lossy-tracking ledger. With an empty ledger it still succeeds (exit 0). `-Status pending-upgrade|upgraded|ignored` prints only entries with that status. The ledger rules: see [11-lossy-tracking.md](11-lossy-tracking.md).

Example: `a1b2c3d4e5f60708` (`upgraded`) and `b2c3d4e5f6070819` (`pending-upgrade`), `lossy list -Status pending-upgrade` → output has `b2c3d4e5f6070819`, not `a1b2c3d4e5f60708`.

### AS-DOC-CLI-024 — "lossy ignore" and "lossy mark-upgraded" set the status of one entry
Status: Draft | Source: legacy/tests/Reshelf.Tests.ps1 › Reshelf.ps1 settings/session dispatch › lossy ignore then mark-upgraded flip an entry status via the CLI; legacy/README.md › Reference: lossy/lossless tracking

`lossy ignore <stableKey>` sets the entry to `ignored`. `lossy mark-upgraded <stableKey>` sets it to `upgraded`. An `ignored` entry can be set to `upgraded`.

Example: `lossy ignore a1b2c3d4e5f60708` → `ignored`; then `lossy mark-upgraded a1b2c3d4e5f60708` → `upgraded`.

### AS-DOC-CLI-025 — "lossy ignore" and "lossy mark-upgraded" need a stable key
Status: Draft | Source: legacy/tests/Reshelf.Tests.ps1 › Reshelf.ps1 settings/session dispatch › lossy ignore without a stable key fails with a clear error; … › lossy mark-upgraded without a stable key fails with a clear error

Without a stable key, both commands fail with `requires a stable key` and a non-zero exit code.

Example: `lossy ignore` → non-zero exit, `…requires a stable key…`.

## Output and exit behavior

### AS-DOC-CLI-026 — Errors give a non-zero exit code and a readable message
Status: Draft | Source: legacy/tests/Reshelf.Tests.ps1 › Reshelf.ps1 settings/session dispatch › (all "fails with a clear error" tests); … › apply without a session id exits 1

A missing required value stops the command. The output says what is missing, and the exit code is not 0. A successful command exits with 0.

Example: `propose` → `requires a session id`; `lossy ignore` → `requires a stable key`; `apply` → exit 1; `session list` → exit 0.

### AS-DOC-CLI-027 — Summaries print as "Name : Value" lines
Status: Draft | Source: legacy/tests/Reshelf.Tests.ps1 › Reshelf.ps1 settings/session dispatch › session resume via the CLI reports the right next command for every session stage (comment); legacy/tests/ui/helpers.js › runApply (comment); legacy/README.md › 1. Recognize; legacy/README.md › 5. Apply

Command summaries print in PowerShell list format, one `Name : Value` per line. A long value wraps at the console width. The output can contain ANSI color codes, also when it is redirected; `NO_COLOR=1` turns them off.

Example: `Applied   : 96`. The `NextCommand` value of `session resume` can wrap across two lines.

## Developer: tools and repo

### AS-DOC-CLI-028 — Developer tools
Status: Draft | Source: legacy/plan/01-repo-and-tooling-scaffolding.md › Dev tooling; legacy/plan/01-repo-and-tooling-scaffolding.md › Manual setup; legacy/README.md › For developers

The developer needs PowerShell 7.4+, Pester 5 or newer, and PSScriptAnalyzer for linting. Windows ships an old Pester 3.4.0. Every test file loads Pester with `Import-Module Pester -MinimumVersion 5.0`, so it never picks up the old one. ffmpeg is an external tool installed by hand (`winget install Gyan.FFmpeg`); its use: see [10-apply.md](10-apply.md).

Example: `Install-Module Pester -MinimumVersion 5.0`, `Install-Module PSScriptAnalyzer`.

### AS-DOC-CLI-029 — Machine-specific files stay out of git
Status: Draft | Source: legacy/plan/01-repo-and-tooling-scaffolding.md › `.gitignore`

The repo ignores machine-specific files: `config/settings.json`, `*.local.json`, `.env` and `.data/`. Only the template `config/settings.default.json` is committed.

Example: a `.env` file with `DISCOGS_ACCESS_TOKEN=…` is never committed.

## Developer: running the tests

### AS-DOC-CLI-030 — The test runner runs all Pester tests
Status: Draft | Source: legacy/tests/Invoke-ReshelfTests.ps1 › (script); legacy/README.md › For developers; legacy/plan/11-testing-and-verification-strategy.md › Test runner

`pwsh tests/Invoke-ReshelfTests.ps1` runs every Pester test in the `tests` folder with detailed output. `-Path <paths>` runs only the given files or folders. Plain `Invoke-Pester ./tests` also works, without the runner's extra switches.

Example: `pwsh tests/Invoke-ReshelfTests.ps1 -Path tests/Reshelf.UiServer.Tests.ps1`.

### AS-DOC-CLI-031 — "-SkipIntegration" leaves out the tests that need TagLibSharp and ffmpeg
Status: Draft | Source: legacy/tests/Invoke-ReshelfTests.ps1 › (script, `.PARAMETER SkipIntegration`); legacy/README.md › For developers; legacy/plan/11-testing-and-verification-strategy.md › Implementation module verification; legacy/plan/11-testing-and-verification-strategy.md › Test runner

`-SkipIntegration` excludes the tests tagged `Integration` (`tests/Reshelf.TagLibSharp.Integration.Tests.ps1`). Without the switch, these tests run and fail (they do not skip) when the real `TagLibSharp.dll` or `ffmpeg` is missing.

Example: `pwsh tests/Invoke-ReshelfTests.ps1 -SkipIntegration` on a machine without ffmpeg → no integration failure.

### AS-DOC-CLI-032 — "-IncludeUi" runs the Playwright suite after the Pester tests pass
Status: Draft | Source: legacy/tests/Invoke-ReshelfTests.ps1 › (script, `.PARAMETER IncludeUi`); legacy/README.md › For developers; legacy/plan/11-testing-and-verification-strategy.md › Test runner

`-IncludeUi` also runs `npx playwright test` in `tests/ui`, but only after all Pester tests pass. When a Pester test fails, the runner prints a warning, skips the UI suite and exits with 1. `-Path` and `-SkipIntegration` do not affect the UI suite; it always runs in full.

Example: one Pester failure + `-IncludeUi` → warning `Pester tests failed - skipping the Playwright UI suite.`, exit 1.

### AS-DOC-CLI-033 — "-IncludeUi" without installed node modules skips the UI suite with success
Status: Draft | Source: legacy/tests/Invoke-ReshelfTests.ps1 › (script); legacy/plan/11-testing-and-verification-strategy.md › Test runner

When `tests/ui/node_modules` does not exist, the runner prints a warning, skips the UI suite and exits with 0.

Example: fresh clone, `pwsh tests/Invoke-ReshelfTests.ps1 -IncludeUi`, all Pester tests pass → warning `tests/ui/node_modules not found - run 'npm install' …`, exit 0.

### AS-DOC-CLI-034 — The runner's exit code
Status: Draft | Source: legacy/tests/Invoke-ReshelfTests.ps1 › (script)

Without `-IncludeUi`, the exit code is 1 when any Pester test failed, else 0. With `-IncludeUi` and a UI run, the exit code is the Playwright exit code.

Example: all Pester pass, one Playwright test fails → the Playwright exit code (not 0).

### AS-DOC-CLI-035 — One-time setup and direct run of the UI suite
Status: Draft | Source: legacy/README.md › For developers; legacy/plan/11-testing-and-verification-strategy.md › UI verification

The UI suite needs a one-time `npm install` and `npx playwright install chromium` in `tests/ui`. It then runs with `npx playwright test` in that folder, or through the runner with `-IncludeUi`. It uses `@playwright/test` 1.48 or newer.

Example: `cd tests/ui; npm install; npx playwright install chromium; npx playwright test`.

### AS-DOC-CLI-036 — The UI suite drives the real server against a temporary data home
Status: Draft | Source: legacy/tests/ui/global-setup.js › globalSetup; legacy/plan/11-testing-and-verification-strategy.md › UI verification

Before the specs run, the setup creates a temporary folder with `data`, `target` and `source`, sets `RESHELF_HOME` to `data`, and runs `settings init -TargetRoot <target> -Force` and `settings set -Key taglibSharpPath`. It picks a free port, starts the real server with `-NoBrowser`, and waits up to 15 seconds for `GET /` to answer. It stores port, URL and paths in `tests/ui/.tmp/state.json`. Nothing is mocked except the Discogs selection call (AS-DOC-CLI-039).

Example: no `TagLibSharp.dll` at `<repo>/.data/lib/TagLibSharp.dll` → setup fails with `TagLibSharp.dll not found at '…'`. Server not up in 15 s → `Reshelf UI server never became ready at http://localhost:<port>/`.

### AS-DOC-CLI-037 — The UI suite runs one test at a time; the server-down spec runs last
Status: Draft | Source: legacy/tests/ui/playwright.config.js › (config); legacy/plan/11-testing-and-verification-strategy.md › UI verification

The suite uses 1 worker, no retries, a 30-second timeout per test, Desktop Chrome, a trace kept on failure and a screenshot on failure. It has two projects: `main` (all specs except `server-down.spec.js`) and `server-down`, which runs after `main` because it stops the shared server.

Example: `npx playwright test` → `main` runs 9 spec files, then `server-down` runs `server-down.spec.js`.

### AS-DOC-CLI-038 — Each UI test seeds its own fresh session
Status: Draft | Source: legacy/tests/ui/seed-session.ps1 › (script); legacy/tests/ui/helpers.js › seedSession; legacy/plan/11-testing-and-verification-strategy.md › UI verification

Each test calls the seed script with a label. The script makes a new source folder `<source>\<label>-<8 hex>\Aurora Fields\`, real 1-second FLAC files (made with ffmpeg) and image files from `tests/ui/fixtures/`. It writes a schema-valid `proposal.json` with four releases (`rich`, `minimal`, `empty`, `compilation`) and new stable keys, and sets the session stage to `reviewed`. It prints the session id, proposal path, source folder and each release's stable key, album and year as JSON.

Fixture files: `large-cover.jpg`, `small-cover.jpg`, `loose-companion.jpg`, `nested-companion.jpg`, `upload-cover.png`, `not-an-image.txt`.

Example: `seedSession('edit-save')` → `{sessionId, proposalPath, sourceFolderPath, rich:{stableKey, album:"Departure Songs <suffix>", year:2016}, minimal:{…, year:2018}, empty:{…, year:2020}, compilation:{…, year:2008}}`.

### AS-DOC-CLI-039 — The UI suite never calls Discogs
Status: Draft | Source: legacy/tests/ui/helpers.js › mockDiscogsSelection; legacy/tests/ui/seed-session.ps1 › (NOTE on the "remote" cover candidate)

The UI suite has no network access to Discogs. The test intercepts the `discogs-selection` call in the browser and answers it with `discogsMatch.status = "matched"` only. The one remote cover URL points to `https://example.invalid/cover-remote.jpg`, which never loads.

Example: pick candidate `releaseId 1001` → the test answers `{discogsMatch:{status:"matched", selectedReleaseId:1001, candidates:[]}}`.

### AS-DOC-CLI-040 — The UI suite stops the server and deletes its temporary data at the end
Status: Draft | Source: legacy/tests/ui/global-teardown.js › globalTeardown

After all specs, the teardown stops the server process tree (`taskkill /T /F`). A server that is already stopped is not an error. It then deletes the temporary folder and `tests/ui/.tmp`.

Example: after `server-down.spec.js` stopped the server, the teardown still finishes without error.

### AS-DOC-CLI-041 — The UI suite can run "apply" for real
Status: Draft | Source: legacy/tests/ui/helpers.js › runApply

A UI test can run `scripts/Reshelf.ps1 apply -SessionId <id> -IncludeUnresolved` against the temporary target root, with `NO_COLOR=1`. It reads `Applied`, `Skipped`, `Rejected` and `Failed` from the output.

Example: the companions end-to-end test → `{Applied: 4}`.

## Developer: test strategy

### AS-DOC-CLI-042 — Unit tests focus on pure functions
Status: Draft | Source: legacy/plan/11-testing-and-verification-strategy.md › Unit tests (Pester 5); legacy/plan/11-testing-and-verification-strategy.md › Decisions & rationale

Pester unit tests are the default. They cover the deterministic rules: safe file names, folder-type detection, track-number parsing, `stableKey`, disc/track numbering, and JSON schema round trips.

Example: a 3-disc fixture checks continuous file numbers against per-disc `Track` tags.

### AS-DOC-CLI-043 — A synthetic source tree holds the messy patterns
Status: Draft | Source: legacy/plan/11-testing-and-verification-strategy.md › Fixture source tree

`tests/fixtures/sample-source-tree/` uses 0-byte files with real extensions. It has one example of each messy pattern. A folder named `CON` and a near-path-limit tree are not in git; the tests build them at run time.

Example: `Godspeeds and their projects\Godspeed You! Black Emperor\…`, `Talking Heads\David Byrne\…`, `ZZ Top\EPs\…`.

### AS-DOC-CLI-044 — Tests never call the real Discogs API
Status: Draft | Source: legacy/plan/11-testing-and-verification-strategy.md › Discogs mocking

Proposal tests replace the Discogs request with captured JSON from `tests/fixtures/discogs-responses/`. Tests never use the network or the rate limit.

Example: `Mock Invoke-DiscogsRequest { Get-Content $fixturePath | ConvertFrom-Json }`.

### AS-DOC-CLI-045 — Apply is checked with a dry run snapshot and a tag read-back
Status: Draft | Source: legacy/plan/11-testing-and-verification-strategy.md › Implementation module verification

A `-WhatIf` run must leave every file under source root, data home and target root unchanged (path, size, last-write time; folders are not compared). A real run then goes to a temporary target. The integration test reads the tags back with TagLibSharp from a fresh file object.

Example: snapshot before and after `apply -WhatIf` → equal.

### AS-DOC-CLI-046 — Golden files pin the full pipeline output
Status: Draft | Source: legacy/plan/11-testing-and-verification-strategy.md › Golden files for the whole fixture tree

The pipeline test compares `recognition.json`, `proposal.json` and the target layout of an `-IncludeUnresolved` apply with reviewed files in `tests/fixtures/expected/`. Run-specific values are replaced first by `<SOURCE_ROOT>`, `<TARGET_ROOT>`, `<DATA_HOME>`, `<SESSION_ID>`, `<GENERATED_AT>`. With `RESHELF_UPDATE_GOLDEN=1` the test writes new golden files; the developer reviews them with `git diff`.

Example: `$env:RESHELF_UPDATE_GOLDEN = '1'; pwsh tests/Invoke-ReshelfTests.ps1`.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-05 | Phase 1 draft. |
