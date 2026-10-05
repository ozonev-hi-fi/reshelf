# 03 — Settings and secrets (as-is, from docs and tests)

Status: Draft | Version: 0.1 | Last updated: 2026-10-05

## Scope

Area **SET**. How the legacy app creates, reads and changes `settings.json`, what each setting means and its default, and how it stores the Discogs token.

Owned inputs: `legacy/tests/Reshelf.Settings.Tests.ps1` (Describes `Initialize-ReshelfSettings`, `Set-ReshelfDiscogsToken`, `Get-ReshelfSettings`, `Set-ReshelfSettings`), `legacy/tests/Reshelf.Common.Tests.ps1` (Describe `Protect-ReshelfSecret / Unprotect-ReshelfSecret`), `legacy/plan/04-settings-module.md`, and the `legacy/README.md` sections "Requirements", "One-time setup" and "Reference: settings". The schema of `settings.json` is in [01-data-home-and-storage.md](01-data-home-and-storage.md) (AS-DOC-DAT-026 to AS-DOC-DAT-028).

Suspected defects and contradictions are listed in [90-suspected-defects.md](90-suspected-defects.md): AS-DOC-DEF-014 to AS-DOC-DEF-016 for this area.

## Platform

### AS-DOC-SET-001 — The stored Discogs token works only for the same Windows user and machine
Status: Draft | Source: legacy/README.md › Requirements; legacy/tests/Reshelf.Common.Tests.ps1 › Protect-ReshelfSecret / Unprotect-ReshelfSecret

The app encrypts the Discogs token with Windows DPAPI (data protection API, encrypts for the current Windows user). The encrypted value can be decrypted only by the same Windows user account on the same machine. So the app needs Windows.

Example: `discogsTokenEncrypted` from `settings.json` copied to another PC → the app cannot decrypt it there.

## Settings file and keys

### AS-DOC-SET-002 — The user views settings with "settings show"
Status: Draft | Source: legacy/README.md › One-time setup (step 6); legacy/README.md › Reference: settings; legacy/plan/04-settings-module.md › CLI shape

`settings.json` lives in the data home (AS-DOC-DAT-007). The command `settings show` displays it.

Example: `pwsh scripts/Reshelf.ps1 settings show`.

### AS-DOC-SET-003 — defaultSourceRoot is the source used when none is given
Status: Draft | Source: legacy/README.md › Reference: settings; legacy/README.md › One-time setup (step 4)

`defaultSourceRoot` (default `""`) is the source folder that `recognize` uses when the user does not pass `-SourceRoot`.

Example: `defaultSourceRoot = D:\source` → `recognize` with no source argument scans `D:\source`.

### AS-DOC-SET-004 — A source given on the command line is used for that run only
Status: Draft | Source: legacy/plan/04-settings-module.md › CLI shape; › Decisions & rationale; › Definition of done

Same rule as AS-DOC-CLI-009 and AS-DOC-CLI-010 in [12-cli.md](12-cli.md) (primary, from tests). This entry keeps its plan source.

`recognize -SourceRoot <path>` uses that path for this run only. It does not change `defaultSourceRoot`, unless the user also passes `-SaveAsDefault`. Reason: most runs are one-off imports from a USB drive or a Downloads folder.

Example: `recognize -SourceRoot D:\test` → this run uses `D:\test`; `defaultSourceRoot` stays as before. With `-SaveAsDefault` → `defaultSourceRoot = D:\test`.

### AS-DOC-SET-005 — targetRoot is where organized music is written
Status: Draft | Source: legacy/README.md › Reference: settings; legacy/README.md › One-time setup (step 4)

`targetRoot` is required. It is the folder where the app writes the organized music. The app checks write access on `settings init` and `settings set` (AS-DOC-SET-031, AS-DOC-SET-040).

Example: `targetRoot = E:\Music`.

### AS-DOC-SET-006 — copyMode is always "copy"
Status: Draft | Source: legacy/README.md › Reference: settings; legacy/plan/04-settings-module.md › Purpose / scope; legacy/schemas/settings.schema.json › copyMode

`copyMode` has one allowed value: `copy`. Source files are always read-only to the app. A `move` mode existed for a short time. It was removed after it destroyed source releases that had no other backup.

Example: `"copyMode": "copy"`. See AS-DOC-SET-030 for what happens with `move`.

### AS-DOC-SET-007 — namingTemplates are changed only by editing the file
Status: Draft | Source: legacy/README.md › Reference: settings

`namingTemplates.releaseFolder` (default `{year} {album}`) and `namingTemplates.trackFile` (default `{trackNumber} {title}`) set the name patterns. `settings set` cannot reach these nested keys. The user edits `settings.json` by hand. The template rules: see AS-DOC-TXT-056 in [02-text-and-naming-rules.md](02-text-and-naming-rules.md).

Example: the user opens `settings.json` and changes `"trackFile"`.

### AS-DOC-SET-008 — trackNumberPadWidth is the minimum width of file numbers
Status: Draft | Source: legacy/README.md › Reference: settings; legacy/plan/04-settings-module.md › Naming templates

`trackNumberPadWidth` (default `2`) is the minimum number of digits in the track file number. It is a floor, not a fixed value (AS-DOC-TXT-050).

Example: default 2 → `01 …`; a 150-track release → `001 …`.

### AS-DOC-SET-009 — coverMaxDimension limits the embedded cover size
Status: Draft | Source: legacy/README.md › Reference: settings

`coverMaxDimension` (default `600`) is the maximum size of the embedded cover in pixels, on the longest side.

Example: default → covers are at most 600 px on the longest side.

### AS-DOC-SET-010 — discogsTokenEnvVar names the token variable
Status: Draft | Source: legacy/README.md › Reference: settings

`discogsTokenEnvVar` (default `DISCOGS_ACCESS_TOKEN`) is the name of the environment variable, and of the matching `.env` key, that the app checks for the Discogs token. The user changes it when the default name collides with something else.

Example: `discogsTokenEnvVar = MY_TOKEN` → the app reads `$env:MY_TOKEN` and `MY_TOKEN=…` in `.env`.

### AS-DOC-SET-011 — discogsTokenEncrypted holds the encrypted token
Status: Draft | Source: legacy/README.md › Reference: settings

`discogsTokenEncrypted` (default `""`) is the DPAPI-encrypted token. `settings init` and `settings set-token` set it. Empty means no stored token.

Example: after `set-token` → a long encrypted string; after a skipped prompt → `""`.

### AS-DOC-SET-012 — rateLimitPerMinute caps Discogs requests
Status: Draft | Source: legacy/README.md › Reference: settings

`rateLimitPerMinute` (default `55`) is a self-imposed maximum number of Discogs requests per minute. How the client applies it: see [06-discogs-client.md](06-discogs-client.md).

Example: default → at most 55 requests per minute.

### AS-DOC-SET-013 — cacheTtlDays sets how long cached Discogs responses live
Status: Draft | Source: legacy/README.md › Reference: settings

`cacheTtlDays` (default `30`) is how long a cached Discogs response is reused before a fresh lookup. After that time, the next `propose` run deletes it from disk. How the cache works: see [06-discogs-client.md](06-discogs-client.md).

Example: a response cached 31 days ago → a fresh request; the old file is deleted on the next `propose`.

### AS-DOC-SET-014 — dataHome is derived on every load
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › Get-ReshelfSettings › overrides a stale on-disk dataHome with the resolved data home the file was actually read from; legacy/README.md › Reference: settings

The user does not set `dataHome`. Each time the app loads the settings, it sets `dataHome` to the folder it actually read `settings.json` from. A different stored value is ignored.

Example: file in `<TestDrive>\<guid>` with `"dataHome": "C:\stale\path"` → loaded `dataHome = <TestDrive>\<guid>`.

### AS-DOC-SET-015 — ffmpegPath empty means ffmpeg from PATH
Status: Draft | Source: legacy/README.md › Requirements; legacy/README.md › Reference: settings

`apply` uses ffmpeg to split single-file + cue releases and to resize cover images. `ffmpegPath` (default `""`) is the full path to ffmpeg. When it is empty, the app uses `ffmpeg` from PATH. The README suggests `winget install Gyan.FFmpeg`.

Example: `ffmpegPath = ""` and ffmpeg on PATH → the app runs `ffmpeg`; `ffmpegPath = C:\tools\ffmpeg.exe` → that file.

### AS-DOC-SET-016 — taglibSharpPath empty means the data home copy
Status: Draft | Source: legacy/README.md › Reference: settings

`taglibSharpPath` (default `""`) is the full path to `TagLibSharp.dll`. Empty means `<dataHome>\lib\TagLibSharp.dll`. The loading rules: AS-DOC-DAT-086, AS-DOC-DAT-087 in [01-data-home-and-storage.md](01-data-home-and-storage.md).

Example: empty → `.data\lib\TagLibSharp.dll`.

## First-time setup ("settings init")

### AS-DOC-SET-017 — Init writes settings from the given values without prompts
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › Initialize-ReshelfSettings › writes valid settings using only supplied params without prompting

When the host is not interactive and the caller gives the values, init writes `settings.json` with them and does not prompt. The token stays empty.

Example: `TargetRoot = <TestDrive>\target`, `DefaultSourceRoot = D:\source`, `CopyMode = copy` → `settings.json` with these values and `discogsTokenEncrypted = ""`.

### AS-DOC-SET-018 — In an interactive host, init prompts only for missing values
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › Initialize-ReshelfSettings › prompts only for fields left unsupplied, in an interactive host

In an interactive host, init asks only for the values the caller did not give, plus the token.

Example: only `TargetRoot` given → two prompts: "Default source root…" (answer `D:\prompted-source`) and "Discogs Personal Access Token…" (empty). Result: `defaultSourceRoot = D:\prompted-source`, `copyMode = copy`, token `""`.

### AS-DOC-SET-019 — Init asks for the target root when it is missing
Status: Draft | Source: legacy/README.md › One-time setup (step 4); legacy/plan/04-settings-module.md › Reshelf.Settings.psm1 functions

In an interactive host without a given target root, init prompts for it. The target root is required.

Example: `pwsh scripts/Reshelf.ps1 settings init` → prompt "Target root" → user types `E:\Music`.

### AS-DOC-SET-020 — The default source root is optional at init
Status: Draft | Source: legacy/README.md › One-time setup (step 4); legacy/tests/Reshelf.Settings.Tests.ps1 › Initialize-ReshelfSettings › prompts only for fields left unsupplied, in an interactive host

The default source root prompt can be skipped with Enter.

Example: Enter at "Default source root" → `defaultSourceRoot` keeps its default `""` (README table).

### AS-DOC-SET-021 — Init does not ask for the copy mode
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › Initialize-ReshelfSettings › prompts only for fields left unsupplied, in an interactive host; › defaults CopyMode to copy when skipped non-interactively

Init never prompts for the copy mode. It is `copy` unless the caller passes `-CopyMode`.

Example: interactive init with only `TargetRoot` → no copy mode prompt, `copyMode = copy`; non-interactive init with only `TargetRoot` → `copyMode = copy`.

### AS-DOC-SET-022 — Init without a target root in a non-interactive host fails at once
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › Initialize-ReshelfSettings › fails fast with a clear message when TargetRoot is missing in a non-interactive host; legacy/plan/04-settings-module.md › Edge cases

When the host is not interactive and no target root is given, init stops at once with a clear error that mentions "non-interactive". It does not wait for a prompt.

Example: init from a scheduled task with no `-TargetRoot` → error "…non-interactive…".

### AS-DOC-SET-023 — In an interactive host, init always asks for the token, hidden
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › Initialize-ReshelfSettings › writes valid settings using only supplied params without prompting (comment); › encrypts and stores a Discogs token entered at the prompt…; legacy/README.md › One-time setup (step 4)

In an interactive host, init always prompts for the Discogs Personal Access Token, also when all other values are given. There is no parameter to pass the token. The input is hidden.

Example: interactive init with `TargetRoot`, `DefaultSourceRoot`, `CopyMode` given → one prompt "Discogs Personal Access Token…".

### AS-DOC-SET-024 — A token entered at init is stored encrypted
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › Initialize-ReshelfSettings › encrypts and stores a Discogs token entered at the prompt, round-trippable back to the original value

A token typed at the prompt is stored encrypted in `discogsTokenEncrypted`. The stored value is not the plain token. Decrypting it gives the original token.

Example: user types `my-real-token` → `discogsTokenEncrypted` ≠ `my-real-token`; decrypt → `my-real-token`.

### AS-DOC-SET-025 — An empty answer to the token prompt leaves the token empty
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › Initialize-ReshelfSettings › leaves the token empty when skipped (empty response) at the prompt; legacy/README.md › One-time setup (step 4)

When the user presses Enter at the token prompt, `discogsTokenEncrypted` stays `""`. The user can set it later (AS-DOC-SET-042).

Example: Enter at "Discogs Personal Access Token" → `discogsTokenEncrypted = ""`.

### AS-DOC-SET-026 — In a non-interactive host, init never asks for the token
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › Initialize-ReshelfSettings › leaves the token empty and never prompts for it in a non-interactive host

When the host is not interactive, init does not prompt for the token. The token stays `""`.

Example: non-interactive init with `TargetRoot` → `discogsTokenEncrypted = ""`, no prompt.

### AS-DOC-SET-027 — Init refuses to overwrite existing settings
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › Initialize-ReshelfSettings › throws when settings.json already exists and -Force is not passed

When `settings.json` already exists, init stops with an error that says "already exists".

Example: init twice on the same data home → the second run fails with "…already exists…".

### AS-DOC-SET-028 — Init with -Force overwrites existing settings
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › Initialize-ReshelfSettings › overwrites existing settings.json when -Force is passed

With `-Force`, init replaces the existing `settings.json`.

Example: first init with `target`, then init with `target2 -Force` → `targetRoot = <TestDrive>\target2`.

### AS-DOC-SET-029 — The copy mode value ignores case
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › Initialize-ReshelfSettings › accepts a mixed-case -CopyMode value and normalizes it to lowercase; legacy/tests/Reshelf.Settings.Tests.ps1 › Set-ReshelfSettings › accepts a mixed-case copyMode value and normalizes it to lowercase

The app accepts the copy mode in any case and stores it in lowercase. This applies to init and to `settings set`.

Example: `-CopyMode Copy` → `copyMode = copy`; `settings set -Key copyMode -Value Copy` → `copyMode = copy`.

### AS-DOC-SET-030 — The copy mode "move" is rejected
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › Initialize-ReshelfSettings › rejects -CopyMode move - it was removed for source-file safety; legacy/tests/Reshelf.Settings.Tests.ps1 › Set-ReshelfSettings › rejects copyMode move - it was removed for source-file safety

The value `move` is rejected with an error that says "no longer supported". This applies to init and to `settings set`.

Example: `-CopyMode move` → error "…no longer supported…"; `settings set -Key copyMode -Value move` → the same error.

### AS-DOC-SET-031 — Init checks that the target root is writable before it saves
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › Initialize-ReshelfSettings › throws when TargetRoot is not writable; legacy/README.md › One-time setup (step 4)

Before init saves anything, it checks that the target root is writable. When it is not writable, init stops with an error.

Example: `TargetRoot` points to an existing file → error.

### AS-DOC-SET-032 — Init writes a settings file that matches the schema
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › Initialize-ReshelfSettings › produces a settings.json that validates against the settings schema; legacy/plan/04-settings-module.md › Definition of done

The `settings.json` that init writes is valid against `settings.schema.json`.

Example: init with only `TargetRoot` → valid file with all 13 keys.

### AS-DOC-SET-033 — The first command without settings runs init automatically
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › Get-ReshelfSettings › calls Initialize-ReshelfSettings when settings.json is missing; legacy/README.md › One-time setup (note); legacy/plan/04-settings-module.md › Reshelf.Settings.psm1 functions

When the app needs settings and `settings.json` does not exist, it runs init first. The README names `recognize`, `propose`, `apply` and `ui start` as such commands.

Example: first `recognize` on a fresh machine → the init prompts appear.

## Reading settings

### AS-DOC-SET-034 — The app reads and returns the stored settings
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › Get-ReshelfSettings › returns parsed settings when the file is valid

When `settings.json` exists and is valid, the app returns its values. An invalid file is an error (AS-DOC-DAT-020).

Example: after init with `<TestDrive>\target` → `targetRoot = <TestDrive>\target`.

## Changing settings ("settings set")

### AS-DOC-SET-035 — "settings set" changes and saves one top-level key
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › Set-ReshelfSettings › updates and persists a top-level string key; legacy/README.md › Reference: settings

`settings set -Key <key> -Value <value>` changes one top-level key and saves the file. A later read returns the new value.

Example: `settings set -Key discogsTokenEnvVar -Value MY_TOKEN` → `discogsTokenEnvVar = MY_TOKEN`, also after a new read.

### AS-DOC-SET-036 — "settings set" converts the value to the key's type
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › Set-ReshelfSettings › coerces a string value to the field's real type

The value comes in as text. The app converts it to the type of the key.

Example: `settings set -Key cacheTtlDays -Value 45` → `cacheTtlDays = 45` as an integer, not `"45"`.

### AS-DOC-SET-037 — "settings set" rejects an unknown key
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › Set-ReshelfSettings › throws for an unknown key

An unknown key gives an error that says "Unknown settings key".

Example: `settings set -Key notAKey -Value x` → error "Unknown settings key…".

### AS-DOC-SET-038 — "settings set" cannot change nested keys
Status: Draft | Source: legacy/README.md › Reference: settings

`settings set` works only for simple (non-nested) keys. The keys inside `namingTemplates` cannot be set with it.

Example: changing `namingTemplates.trackFile` needs a hand edit of `settings.json`.

### AS-DOC-SET-039 — "settings set" rejects an invalid copy mode
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › Set-ReshelfSettings › throws for an invalid copyMode

A copy mode value that is not known gives an error that says "Invalid copy mode". (For `move`, see AS-DOC-SET-030.)

Example: `settings set -Key copyMode -Value shred` → error "Invalid copy mode…".

### AS-DOC-SET-040 — Changing targetRoot checks write access again and creates the folder
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › Set-ReshelfSettings › re-validates writability when changing targetRoot; legacy/README.md › Reference: settings

When the user changes `targetRoot`, the app checks write access again. A missing folder is created.

Example: `settings set -Key targetRoot -Value <TestDrive>\newTarget` → `targetRoot = <TestDrive>\newTarget`, and the folder exists.

## Discogs token

### AS-DOC-SET-041 — The user creates a Discogs Personal Access Token by hand
Status: Draft | Source: legacy/README.md › One-time setup (step 3); legacy/README.md › Requirements

The app needs a Discogs account and a Personal Access Token. The user logs into discogs.com, opens **Settings → Developers → Generate new token** and copies the token. No OAuth app is needed, because the app has one user.

Example: the user copies the token and pastes it at the init or `set-token` prompt.

### AS-DOC-SET-042 — "settings set-token" replaces only the token
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › Set-ReshelfDiscogsToken › updates an existing settings.json token and leaves every other field untouched; legacy/README.md › One-time setup (step 5)

`settings set-token` prompts for the token in an interactive host and stores it encrypted. All other settings stay the same.

Example: user types `updated-token` → decrypt(`discogsTokenEncrypted`) = `updated-token`; `targetRoot`, `defaultSourceRoot`, `copyMode` unchanged.

### AS-DOC-SET-043 — "settings set-token" fails in a non-interactive host
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › Set-ReshelfDiscogsToken › throws and never prompts when the host is not interactive

When the host is not interactive, `set-token` stops with an error that mentions "interactive". It does not prompt.

Example: `set-token` from a scheduled task → error "…interactive…".

### AS-DOC-SET-044 — The token comes from the environment, then .env, then settings
Status: Draft | Source: legacy/README.md › One-time setup (step 5)

The app looks for the Discogs token in this order:
1. the environment variable named by `discogsTokenEnvVar` (default `DISCOGS_ACCESS_TOKEN`);
2. a `.env` file at the repo root with the line `DISCOGS_ACCESS_TOKEN=...`;
3. the encrypted value in `settings.json`.

Example: `$env:DISCOGS_ACCESS_TOKEN` set and `discogsTokenEncrypted` also set → the app uses the environment variable.

### AS-DOC-SET-045 — An encrypted secret does not show the plain text
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Protect-ReshelfSecret / Unprotect-ReshelfSecret › round-trips plain text through DPAPI encryption; › produces an encrypted string that does not contain the original plain text

The encrypted text is different from the plain text and does not contain it.

Example: `super-secret-value` → an encrypted string without `super-secret-value` in it.

### AS-DOC-SET-046 — Decrypting gives back the original secret
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Protect-ReshelfSecret / Unprotect-ReshelfSecret › round-trips plain text through DPAPI encryption

Decrypting an encrypted secret (same user, same machine) gives the exact original text.

Example: encrypt `my-discogs-token`, then decrypt → `my-discogs-token`.

### AS-DOC-SET-047 — An empty secret cannot be encrypted
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Protect-ReshelfSecret / Unprotect-ReshelfSecret › throws for an empty string …

Encrypting an empty text is an error. So a skipped token is not encrypted; the app checks for empty first and stores `""` (AS-DOC-SET-025).

Example: encrypt `''` → error.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-05 | Phase 1 draft. |
