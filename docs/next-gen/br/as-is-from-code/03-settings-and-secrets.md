# Settings and secrets — as-is from code

Status: Draft | Version: 0.1 | Last updated: 2026-10-10

### AS-CODE-SET-001 — Interactive host detection
Status: Draft | Source: legacy/scripts/common/Reshelf.Settings.psm1:6 › Test-ReshelfHostIsInteractive

The app treats the host as "interactive" when console input is not redirected. It checks `[Console]::IsInputRedirected` and returns the opposite (`true` = interactive). This flag gates every place that would otherwise prompt the user (settings init, token entry).

Example: running with stdin redirected (e.g. from a script or CI pipeline) makes this return `false`, even if a console window is attached.

### AS-CODE-SET-002 — Target path is auto-created if missing, then probed for write access
Status: Draft | Source: legacy/scripts/common/Reshelf.Settings.psm1:36 › Assert-ReshelfPathWritable

Before accepting a target root, the app checks the path exists; if not, it tries to create the directory (recursively). If creation fails, it throws: `Target root '<path>' does not exist and could not be created: <exception message>`.

### AS-CODE-SET-003 — Write access is confirmed by actually writing a probe file
Status: Draft | Source: legacy/scripts/common/Reshelf.Settings.psm1:36 › Assert-ReshelfPathWritable

After the path exists (created or pre-existing), the app writes an empty probe file named `.reshelf-write-probe-<new GUID, no dashes>.tmp` directly in that folder, then deletes it. If writing or deleting fails, it throws: `Target root '<path>' is not writable: <exception message>`. This is the only check used anywhere a path must be "writable" (used for both the target root on init and on every `targetRoot` change via `settings set`).

### AS-CODE-SET-004 — Settings are auto-initialized on first read
Status: Draft | Source: legacy/scripts/common/Reshelf.Settings.psm1:62 › Get-ReshelfSettings

Reading settings never fails just because no settings file exists yet. If `<dataHome>/settings.json` is missing, the app transparently runs the same logic as settings initialization (see AS-CODE-SET-006) and returns the freshly created settings object. If `DataHome` is not supplied by the caller, it is resolved to a default location by a helper outside this file (`Resolve-ReshelfDataHome`), so this document does not state what that default path is.

### AS-CODE-SET-005 — Existing settings file is schema-checked before use
Status: Draft | Source: legacy/scripts/common/Reshelf.Settings.psm1:62 › Get-ReshelfSettings

If `settings.json` exists, it is validated against a JSON schema named `settings` before being parsed for use. If it fails validation, the app throws: `Settings file at '<path>' does not match the settings schema. Fix it manually or re-run 'Reshelf.ps1 settings init -Force'.` — no automatic repair is attempted.

### AS-CODE-SET-006 — `dataHome` on disk is never trusted; it is always overwritten with the current location
Status: Draft | Source: legacy/scripts/common/Reshelf.Settings.psm1:62 › Get-ReshelfSettings

After loading a valid settings file, the in-memory `dataHome` field is always set to the `DataHome` path actually used for this read (the folder the settings.json was found in), replacing whatever value was stored in the file. The code comment states this is deliberate: `dataHome` is a derived value, not a stored user choice, so a copied/moved data folder or a stale value from before the default location changed can never point other functions at the wrong folder.

Example: a `settings.json` copied from `C:\OldData` into `D:\NewData` will report `dataHome = "D:\NewData"` once read, regardless of what is written inside the file.

### AS-CODE-SET-007 — Settings init refuses to overwrite an existing file unless forced
Status: Draft | Source: legacy/scripts/common/Reshelf.Settings.psm1:92 › Initialize-ReshelfSettings

If `<dataHome>/settings.json` already exists and `-Force` is not passed, initialization throws: `Settings file already exists at '<path>'. Use -Force to overwrite.`

### AS-CODE-SET-008 — Target root is mandatory and only promptable on an interactive host
Status: Draft | Source: legacy/scripts/common/Reshelf.Settings.psm1:92 › Initialize-ReshelfSettings

If `TargetRoot` is not supplied as a parameter: on a non-interactive host, initialization throws immediately: `Target root is required, but this is a non-interactive host. Run: Reshelf.ps1 settings init -TargetRoot <path>`. On an interactive host, it prompts with `Read-Host 'Target root (where organized music will be written)'`. If the value is still empty after that (parameter absent, non-interactive, or prompt answered blank), it throws: `Target root is required.`

### AS-CODE-SET-009 — Default source root is optional and defaults to empty string
Status: Draft | Source: legacy/scripts/common/Reshelf.Settings.psm1:92 › Initialize-ReshelfSettings

If `DefaultSourceRoot` is not supplied, an interactive host is prompted (`Default source root (optional, press Enter to skip)`); a non-interactive host is never prompted. In both cases, if no value is obtained, `DefaultSourceRoot` falls back to `""` (empty string) — this setting has no other default and is never mandatory.

### AS-CODE-SET-010 — Copy mode defaults to `copy` and `copy` is the only legal value
Status: Draft | Source: legacy/scripts/common/Reshelf.Settings.psm1:92 › Initialize-ReshelfSettings

If `CopyMode` is not supplied, it defaults to the literal string `'copy'`. Whatever value is used (supplied or defaulted) is lower-cased, and anything other than `copy` is rejected: `Invalid copy mode '<value>'. Must be 'copy' - 'move' is no longer supported, since Reshelf never deletes source files.` A code comment explains `move` mode existed previously (it deleted source files after applying or after a cue-sheet split) and was removed after an incident destroyed source releases with no backup; source files are now always read-only to Reshelf.

### AS-CODE-SET-011 — Discogs token is never accepted as a plain command-line value during init
Status: Draft | Source: legacy/scripts/common/Reshelf.Settings.psm1:92 › Initialize-ReshelfSettings

There is no parameter for the Discogs token in `Initialize-ReshelfSettings`. On an interactive host only, the app prompts with a masked/secure prompt (`Discogs Personal Access Token (press Enter to skip, set later with: Reshelf.ps1 settings set-token)`, `-AsSecureString`). A non-interactive host is never prompted and the token is left unset for this run. The token can always be supplied afterward via `Set-ReshelfDiscogsToken` (the `settings set-token` command).

### AS-CODE-SET-012 — Discogs token is stored encrypted, or as empty string if skipped
Status: Draft | Source: legacy/scripts/common/Reshelf.Settings.psm1:92 › Initialize-ReshelfSettings

If a token was entered (secure string with length > 0), it is converted with `ConvertFrom-SecureString` (Windows DPAPI-based encryption tied to the current user/machine) before being stored in `discogsTokenEncrypted`. If the prompt was skipped (empty input) or not interactive, `discogsTokenEncrypted` is stored as `""`.

### AS-CODE-SET-013 — Target root writability is checked before any settings file is written
Status: Draft | Source: legacy/scripts/common/Reshelf.Settings.psm1:92 › Initialize-ReshelfSettings

`Assert-ReshelfPathWritable` (AS-CODE-SET-002/003) is run against `TargetRoot` before the settings file is created. If the target root cannot be created or is not writable, initialization fails before `settings.json` is touched.

### AS-CODE-SET-014 — New settings start from `settings.default.json`, with only five fields overridden
Status: Draft | Source: legacy/scripts/common/Reshelf.Settings.psm1:92 › Initialize-ReshelfSettings

Initialization loads `legacy/config/settings.default.json` as the base object, then overrides exactly five fields on it: `defaultSourceRoot`, `targetRoot`, `copyMode`, `dataHome`, `discogsTokenEncrypted`. Every other field keeps the literal value from the defaults file. Per `legacy/config/settings.default.json`, those carried-over defaults are:

| Field | Default value | Source |
|---|---|---|
| `namingTemplates.releaseFolder` | `"{year} {album}"` | legacy/config/settings.default.json › namingTemplates.releaseFolder |
| `namingTemplates.trackFile` | `"{trackNumber} {title}"` | legacy/config/settings.default.json › namingTemplates.trackFile |
| `trackNumberPadWidth` | `2` | legacy/config/settings.default.json › trackNumberPadWidth |
| `coverMaxDimension` | `600` | legacy/config/settings.default.json › coverMaxDimension |
| `discogsTokenEnvVar` | `"DISCOGS_ACCESS_TOKEN"` | legacy/config/settings.default.json › discogsTokenEnvVar |
| `rateLimitPerMinute` | `55` | legacy/config/settings.default.json › rateLimitPerMinute |
| `cacheTtlDays` | `30` | legacy/config/settings.default.json › cacheTtlDays |
| `ffmpegPath` | `""` | legacy/config/settings.default.json › ffmpegPath |
| `taglibSharpPath` | `""` | legacy/config/settings.default.json › taglibSharpPath |

The defaults file's own placeholder values for `defaultSourceRoot`, `targetRoot`, `copyMode`, `dataHome`, `discogsTokenEncrypted` (all `""` except `copyMode: "copy"`) are irrelevant at init time because the code always overwrites those five.

`rateLimitPerMinute` (55) and `cacheTtlDays` (30) are the configured defaults; see [06-discogs-client.md](06-discogs-client.md) (AS-CODE-DSC-009, AS-CODE-DSC-015) for how the Discogs client actually enforces them.

### AS-CODE-SET-015 — New settings are schema-validated on write
Status: Draft | Source: legacy/scripts/common/Reshelf.Settings.psm1:92 › Initialize-ReshelfSettings

The assembled settings object is written to `<dataHome>/settings.json` through `Set-ReshelfJsonFile` using the `settings` schema name — the same schema used to validate reads (AS-CODE-SET-005).

### AS-CODE-SET-016 — Setting the Discogs token requires an interactive host, with no exception
Status: Draft | Source: legacy/scripts/common/Reshelf.Settings.psm1:171 › Set-ReshelfDiscogsToken

Unlike settings init, `Set-ReshelfDiscogsToken` has no non-interactive path at all: if the host is not interactive it throws immediately: `'settings set-token' requires an interactive host - a token is never accepted as a plain command-line argument (it would leak into shell history/process list).`

### AS-CODE-SET-017 — Setting the token loads (and can silently create) the full settings file first
Status: Draft | Source: legacy/scripts/common/Reshelf.Settings.psm1:171 › Set-ReshelfDiscogsToken

Before prompting for the new token, the function calls `Get-ReshelfSettings`, which (per AS-CODE-SET-004) auto-initializes a brand-new settings file if none exists yet. So running `settings set-token` on a data home with no settings file does not error — it runs the full settings-initialization prompt sequence (target root, default source root, copy mode, and even an initial token prompt) before then prompting a second time for the token value actually being set.

### AS-CODE-SET-018 — Entering an empty token clears/sets the stored token to an empty string
Status: Draft | Source: legacy/scripts/common/Reshelf.Settings.psm1:171 › Set-ReshelfDiscogsToken

The prompt (`Discogs Personal Access Token`, secure string) is always shown once the interactive-host and settings-load steps pass. If the entered secure string is empty (zero length) or null, `discogsTokenEncrypted` is set to `""`; otherwise it is encrypted with `ConvertFrom-SecureString` as in AS-CODE-SET-012. The updated settings are written back to `settings.json` under the `settings` schema.

### AS-CODE-SET-019 — Generic settings are changed by key/value, restricted to known top-level keys
Status: Draft | Source: legacy/scripts/common/Reshelf.Settings.psm1:197 › Set-ReshelfSettings

`Set-ReshelfSettings` takes a `Key` and a `Value` (both plain strings). It loads current settings (auto-initializing if needed, per AS-CODE-SET-004), then checks `Key` against the existing settings object's property names. If `Key` is not one of them, it throws: `Unknown settings key '<key>'. Valid keys: <comma-and-space-joined, alphabetically sorted list>.`

### AS-CODE-SET-020 — Nested object settings cannot be changed through this command
Status: Draft | Source: legacy/scripts/common/Reshelf.Settings.psm1:197 › Set-ReshelfSettings

If the current value of `Key` is itself an object (e.g. `namingTemplates`), the function refuses to set it: `Setting key '<key>' is a nested object and cannot be set directly. Edit settings.json manually for now.`

### AS-CODE-SET-021 — The incoming string value is coerced to match the existing field's type
Status: Draft | Source: legacy/scripts/common/Reshelf.Settings.psm1:197 › Set-ReshelfSettings

Before storing, the string `Value` is converted based on the *current* value's runtime type: to `[int]` if the current value is `int`/`long` (e.g. `trackNumberPadWidth`, `coverMaxDimension`, `rateLimitPerMinute`, `cacheTtlDays`), to `[bool]` via `[System.Convert]::ToBoolean(...)` if the current value is boolean, otherwise left as a plain string (e.g. `targetRoot`, `defaultSourceRoot`, `copyMode`, `discogsTokenEnvVar`, `discogsTokenEncrypted`, `dataHome`, `ffmpegPath`, `taglibSharpPath`).

Example: `settings set trackNumberPadWidth 3` stores the integer `3` because the existing `trackNumberPadWidth` default (`2`) is numeric.

### AS-CODE-SET-022 — Changing `copyMode` is still restricted to `copy`
Status: Draft | Source: legacy/scripts/common/Reshelf.Settings.psm1:197 › Set-ReshelfSettings

Setting `copyMode` applies the same lower-case-and-validate rule as init (AS-CODE-SET-010): any value other than `copy` throws `Invalid copy mode '<value>'. Must be 'copy' - 'move' is no longer supported, since Reshelf never deletes source files.`

### AS-CODE-SET-023 — Changing `targetRoot` re-runs the writability check
Status: Draft | Source: legacy/scripts/common/Reshelf.Settings.psm1:197 › Set-ReshelfSettings

Setting `targetRoot` to a new value runs `Assert-ReshelfPathWritable` (AS-CODE-SET-002/003) against the new path before the setting is saved. No equivalent existence/writability check exists for any other path-like field (`defaultSourceRoot`, `ffmpegPath`, `taglibSharpPath`, `dataHome`) when changed through this command.

### AS-CODE-SET-024 — Every settings write goes through the same schema-validated save path
Status: Draft | Source: legacy/scripts/common/Reshelf.Settings.psm1:197 › Set-ReshelfSettings

After validation/coercion, the updated field is applied in-memory and the whole settings object is written to `<dataHome>/settings.json` via `Set-ReshelfJsonFile -SchemaName settings`, identical to the init and token-set paths.

## Suspected defects

- AS-CODE-DEF-SET-001 — legacy/scripts/common/Reshelf.Settings.psm1:188: `Set-ReshelfDiscogsToken`'s prompt text is plain `Discogs Personal Access Token`, with no mention that pressing Enter skips/clears it — but the code right below (line 189) silently accepts an empty entry and stores `""` anyway, identical in effect to a "skip". The prompt wording doesn't match the actual (permissive) behavior.
- AS-CODE-DEF-SET-002 — legacy/scripts/common/Reshelf.Settings.psm1:186 (`Set-ReshelfDiscogsToken`) combined with :75 (`Get-ReshelfSettings`): running `settings set-token` against a data home that has no `settings.json` yet does not fail with a clear "run init first" message — it silently runs the *entire* interactive settings-initialization flow (target root, source root, copy mode, and a first token prompt) before asking for the token a second time. This coupling is easy to trigger by accident and is not obviously intentional.

## Changelog

| Version | Date | Notes |
|---|---|---|
| 0.1 | 2026-10-10 | Phase 2 draft from code. |
