# 03 — Settings and secrets (as-is, merged)

Status: Draft | Version: 0.1 | Last updated: 2026-10-11

## Scope

Area **SET**. How the legacy app creates, reads and changes `settings.json`,
what each setting means and its default, and how it stores the Discogs
token. Sources: `br/as-is-from-docs/03-settings-and-secrets.md`
(`AS-DOC-SET-001`–`047`, from `legacy/README.md`, `legacy/plan/
04-settings-module.md`, and `legacy/tests/Reshelf.Settings.Tests.ps1`/
`Reshelf.Common.Tests.ps1`) and `br/as-is-from-code/03-settings-and-secrets.md`
(`AS-CODE-SET-001`–`024`, read only from
`legacy/scripts/common/Reshelf.Settings.psm1`).

**ID numbering for this area:** `AS-SET-002`–`043` mirror
`AS-DOC-SET-002`–`043` one for one — each keeps its doc number, elaborated
with the matching `AS-CODE-SET-*` implementation detail where one exists.
`AS-SET-048`–`050` are fresh numbers for `AS-CODE-SET-*` facts (interactive-
host detection, the defaults-template mechanism, the shared write path) that
don't attach to any single doc-side rule.

**Not owned by this area — four doc-side numbers with no `AS-SET` entry:**
- `AS-DOC-SET-001`, `045`, `046`, `047` describe `Protect-ReshelfSecret`/
  `Unprotect-ReshelfSecret` (`legacy/scripts/common/Reshelf.Common.psm1`) — a
  generic, DPAPI-based secret helper, not settings-specific. It is DAT-owned
  code, already merged as `AS-DAT-092` (protect) and `AS-DAT-093`
  (unprotect) in [01-data-and-storage.md](01-data-and-storage.md), which
  already anticipated this cross-link when DAT was merged. No
  `AS-SET-001`/`045`/`046`/`047` is created; the coverage file points these
  four IDs straight at `AS-DAT-092`/`093`.
- `AS-DOC-SET-044` (the three-step token lookup order: env var, then
  `.env`, then the encrypted setting) is the same rule as `AS-DOC-DSC-002`/
  `003` (`br/as-is-from-docs/06-discogs-client.md`) and `AS-CODE-DSC-001`–
  `005` (`br/as-is-from-code/06-discogs-client.md`) — it describes
  `Get-DiscogsToken`, DSC-owned code in `Reshelf.Discogs.psm1`, not anything
  in `Reshelf.Settings.psm1`. No `AS-SET-044` is created; it is left for the
  DSC merge pass, which should cite `AS-DOC-SET-044` alongside the `DSC-*`
  IDs, the way the TXT merge deferred `AS-CODE-TXT-014`/`015` to REC.

**A contradiction found while merging this area, in already-merged DAT
content:** checking `AS-DOC-SET-047` ("an empty secret cannot be encrypted")
against the DAT-merged `AS-DAT-092` turned up a wrong claim in that entry
("an empty-string secret is explicitly allowed as input"). Corrected in
`01-data-and-storage.md`; see `90-contradictions-resolution.md` for the
re-read that resolved it.

## Settings file and keys

### AS-SET-002 — The user views settings with "settings show"
Status: Draft | Source: AS-DOC-SET-002

`settings.json` lives in the data home (`AS-DAT-007`). The command
`settings show` displays it.

Example: `pwsh scripts/Reshelf.ps1 settings show`.

### AS-SET-003 — defaultSourceRoot is the source used when none is given
Status: Draft | Source: AS-DOC-SET-003

`defaultSourceRoot` (default `""`) is the source folder that `recognize`
uses when the user does not pass `-SourceRoot`.

Example: `defaultSourceRoot = D:\source` → `recognize` with no source
argument scans `D:\source`.

### AS-SET-004 — A source given on the command line is used for that run only
Status: Draft | Source: AS-DOC-SET-004

Same rule as `AS-DOC-CLI-009` and `AS-DOC-CLI-010` (area CLI, not yet
merged). This entry keeps its plan source.

`recognize -SourceRoot <path>` uses that path for this run only. It does not
change `defaultSourceRoot`, unless the user also passes `-SaveAsDefault`.
Reason: most runs are one-off imports from a USB drive or a Downloads
folder.

Example: `recognize -SourceRoot D:\test` → this run uses `D:\test`;
`defaultSourceRoot` stays as before. With `-SaveAsDefault` →
`defaultSourceRoot = D:\test`.

### AS-SET-005 — targetRoot is where organized music is written
Status: Draft | Source: AS-DOC-SET-005

`targetRoot` is required. It is the folder where the app writes the
organized music. It never actually defaults to an empty value in a real
settings file — see `AS-SET-049` for how the template's `""` placeholder is
always overwritten before any save. The app checks write access on
`settings init` and `settings set` (`AS-SET-031`, `AS-SET-040`).

Example: `targetRoot = E:\Music`.

### AS-SET-006 — copyMode is always "copy"
Status: Draft | Source: AS-DOC-SET-006; AS-CODE-SET-010

`copyMode` has one allowed value: `copy`. Source files are always read-only
to the app. A `move` mode existed for a short time. It was removed after it
destroyed source releases that had no other backup. Whatever value is
supplied (at init or at `settings set`) is lower-cased first; any value
other than `copy` throws: `Invalid copy mode '<value>'. Must be 'copy' -
'move' is no longer supported, since Reshelf never deletes source files.` —
this exact message is used for any rejected value, not only `move` (see
`AS-SET-030`, `AS-SET-039`).

Example: `"copyMode": "copy"`.

### AS-SET-007 — namingTemplates are changed only by editing the file
Status: Draft | Source: AS-DOC-SET-007

`namingTemplates.releaseFolder` (default `{year} {album}`) and
`namingTemplates.trackFile` (default `{trackNumber} {title}`) set the name
patterns (confirmed against the template file — `AS-SET-049`). `settings
set` cannot reach these nested keys — the same general rule stated for any
nested key in `AS-SET-038`. The user edits `settings.json` by hand. The
template rules: see `AS-TXT-056`.

Example: the user opens `settings.json` and changes `"trackFile"`.

### AS-SET-008 — trackNumberPadWidth is the minimum width of file numbers
Status: Draft | Source: AS-DOC-SET-008

`trackNumberPadWidth` (default `2`) is the minimum number of digits in the
track file number. It is a floor, not a fixed value (`AS-TXT-050`).

Example: default 2 → `01 …`; a 150-track release → `001 …`.

### AS-SET-009 — coverMaxDimension limits the embedded cover size
Status: Draft | Source: AS-DOC-SET-009

`coverMaxDimension` (default `600`) is the maximum size of the embedded
cover in pixels, on the longest side.

Example: default → covers are at most 600 px on the longest side.

### AS-SET-010 — discogsTokenEnvVar names the token variable
Status: Draft | Source: AS-DOC-SET-010

`discogsTokenEnvVar` (default `DISCOGS_ACCESS_TOKEN`) is the name of the
environment variable, and of the matching `.env` key, that the app checks
for the Discogs token. The user changes it when the default name collides
with something else. How the Discogs client actually uses this name: see
area DSC (`AS-DOC-DSC-003`, not yet merged).

Example: `discogsTokenEnvVar = MY_TOKEN` → the app reads `$env:MY_TOKEN` and
`MY_TOKEN=…` in `.env`.

### AS-SET-011 — discogsTokenEncrypted holds the encrypted token
Status: Draft | Source: AS-DOC-SET-011

`discogsTokenEncrypted` (default `""`) is the DPAPI-encrypted token (the
encryption mechanism itself is DAT-owned — `AS-DAT-092`/`093`). `settings
init` and `settings set-token` set it (`AS-SET-024`, `AS-SET-042`). Empty
means no stored token.

Example: after `set-token` → a long encrypted string; after a skipped
prompt → `""`.

### AS-SET-012 — rateLimitPerMinute caps Discogs requests
Status: Draft | Source: AS-DOC-SET-012

`rateLimitPerMinute` (default `55`) is a self-imposed maximum number of
Discogs requests per minute. How the client applies it: see area DSC
(not yet merged).

Example: default → at most 55 requests per minute.

### AS-SET-013 — cacheTtlDays sets how long cached Discogs responses live
Status: Draft | Source: AS-DOC-SET-013

`cacheTtlDays` (default `30`) is how long a cached Discogs response is
reused before a fresh lookup. After that time, the next `propose` run
deletes it from disk. How the cache works: see area DSC (not yet merged).

Example: a response cached 31 days ago → a fresh request; the old file is
deleted on the next `propose`.

### AS-SET-014 — dataHome is derived on every load, never trusted from disk
Status: Draft | Source: AS-DOC-SET-014; AS-CODE-SET-006

The user does not set `dataHome`. Each time the app loads the settings
(`Get-ReshelfSettings`), it overwrites the in-memory `dataHome` field with
the `DataHome` path actually used for this read — the folder the settings
file was found in — discarding whatever value is stored on disk. This is
deliberate (code comment): `dataHome` is a derived value, not a stored user
choice, so a copied/moved data folder, or a stale value from before the
default location changed, can never point other functions at the wrong
folder.

Example: file in `<TestDrive>\<guid>` with `"dataHome": "C:\stale\path"` →
loaded `dataHome = <TestDrive>\<guid>`. A `settings.json` copied from
`C:\OldData` to `D:\NewData` → reports `dataHome = "D:\NewData"` once read,
regardless of the file's own content.

### AS-SET-015 — ffmpegPath empty means ffmpeg from PATH
Status: Draft | Source: AS-DOC-SET-015

`apply` uses ffmpeg to split single-file + cue releases and to resize cover
images. `ffmpegPath` (default `""`) is the full path to ffmpeg. When it is
empty, the app uses `ffmpeg` from PATH. The README suggests
`winget install Gyan.FFmpeg`.

Example: `ffmpegPath = ""` and ffmpeg on PATH → the app runs `ffmpeg`;
`ffmpegPath = C:\tools\ffmpeg.exe` → that file.

### AS-SET-016 — taglibSharpPath empty means the data home copy
Status: Draft | Source: AS-DOC-SET-016

`taglibSharpPath` (default `""`) is the full path to `TagLibSharp.dll`.
Empty means `<dataHome>\lib\TagLibSharp.dll`. The loading rules:
`AS-DAT-086`, `AS-DAT-087`.

Example: empty → `.data\lib\TagLibSharp.dll`.

## First-time setup ("settings init")

### AS-SET-017 — Init writes settings from the given values without prompts
Status: Draft | Source: AS-DOC-SET-017; AS-CODE-SET-008, AS-CODE-SET-009, AS-CODE-SET-011

When the host is not interactive and the caller gives the values, init
writes `settings.json` with them and does not prompt. The token stays
empty.

Example: `TargetRoot = <TestDrive>\target`, `DefaultSourceRoot = D:\source`,
`CopyMode = copy` → `settings.json` with these values and
`discogsTokenEncrypted = ""`.

### AS-SET-018 — In an interactive host, init prompts only for missing values
Status: Draft | Source: AS-DOC-SET-018; AS-CODE-SET-008, AS-CODE-SET-009, AS-CODE-SET-011

In an interactive host, init asks only for the values the caller did not
give: target root (`AS-SET-019`), default source root (`AS-SET-020`), and
always the Discogs token (`AS-SET-023`, which has no parameter at all).
Copy mode is never prompted for (`AS-SET-021`).

Example: only `TargetRoot` given → two prompts: "Default source root…"
(answer `D:\prompted-source`) and "Discogs Personal Access Token…" (empty).
Result: `defaultSourceRoot = D:\prompted-source`, `copyMode = copy`, token
`""`.

### AS-SET-019 — Init asks for the target root when it is missing
Status: Draft | Source: AS-DOC-SET-019; AS-CODE-SET-008

In an interactive host without a given target root, init prompts with
`Read-Host 'Target root (where organized music will be written)'`. The
target root is required: if the prompt answer is still empty, init throws
`Target root is required.`

Example: `pwsh scripts/Reshelf.ps1 settings init` → prompt "Target root" →
user types `E:\Music`.

### AS-SET-020 — The default source root is optional at init
Status: Draft | Source: AS-DOC-SET-020; AS-CODE-SET-009

The default source root prompt (`Default source root (optional, press
Enter to skip)`) can be skipped with Enter; a non-interactive host is never
prompted for it either way. In both cases, with no value obtained,
`defaultSourceRoot` falls back to `""` — it has no other default and is
never mandatory.

Example: Enter at "Default source root" → `defaultSourceRoot` keeps its
default `""`.

### AS-SET-021 — Init does not ask for the copy mode
Status: Draft | Source: AS-DOC-SET-021; AS-CODE-SET-010

Init never prompts for the copy mode (the code comment: there is no real
choice to make, since `move` was removed). It is `copy` unless the caller
passes `-CopyMode`.

Example: interactive init with only `TargetRoot` → no copy mode prompt,
`copyMode = copy`; non-interactive init with only `TargetRoot` →
`copyMode = copy`.

### AS-SET-022 — Init without a target root in a non-interactive host fails at once
Status: Draft | Source: AS-DOC-SET-022; AS-CODE-SET-008

When the host is not interactive and no target root is given, init throws
immediately: `Target root is required, but this is a non-interactive host.
Run: Reshelf.ps1 settings init -TargetRoot <path>`. It does not wait for a
prompt.

Example: init from a scheduled task with no `-TargetRoot` → error
"…non-interactive…".

### AS-SET-023 — In an interactive host, init always asks for the token, hidden
Status: Draft | Source: AS-DOC-SET-023; AS-CODE-SET-011

In an interactive host, init always prompts for the Discogs Personal Access
Token (`Discogs Personal Access Token (press Enter to skip, set later with:
Reshelf.ps1 settings set-token)`), also when all other values are given.
There is no parameter to pass the token — passing it on the command line
would leak into shell history/the process list. The input is a secure
string (`-AsSecureString`), hidden at the console.

Example: interactive init with `TargetRoot`, `DefaultSourceRoot`,
`CopyMode` given → one prompt "Discogs Personal Access Token…".

### AS-SET-024 — A token entered at init is stored encrypted
Status: Draft | Source: AS-DOC-SET-024; AS-CODE-SET-012

A token typed at the prompt (length > 0) is converted with
`ConvertFrom-SecureString` (DPAPI, `AS-DAT-092`) before being stored in
`discogsTokenEncrypted`. The stored value is not the plain token.
Decrypting it (`AS-DAT-093`) gives the original token.

Example: user types `my-real-token` → `discogsTokenEncrypted` ≠
`my-real-token`; decrypt → `my-real-token`.

### AS-SET-025 — An empty answer to the token prompt leaves the token empty
Status: Draft | Source: AS-DOC-SET-025; AS-CODE-SET-012

When the user presses Enter at the token prompt (zero-length or null secure
string), `discogsTokenEncrypted` stays `""` — the app checks for this
before ever calling the DPAPI encryption helper, since that helper itself
throws for an empty plain text (`AS-DAT-092`, as corrected). The user can
set it later (`AS-SET-042`).

Example: Enter at "Discogs Personal Access Token" →
`discogsTokenEncrypted = ""`.

### AS-SET-026 — In a non-interactive host, init never asks for the token
Status: Draft | Source: AS-DOC-SET-026; AS-CODE-SET-011

When the host is not interactive, init does not prompt for the token. The
token stays `""`.

Example: non-interactive init with `TargetRoot` →
`discogsTokenEncrypted = ""`, no prompt.

### AS-SET-027 — Init refuses to overwrite existing settings
Status: Draft | Source: AS-DOC-SET-027; AS-CODE-SET-007

When `settings.json` already exists and `-Force` is not passed, init
throws: `Settings file already exists at '<path>'. Use -Force to
overwrite.`

Example: init twice on the same data home → the second run fails with
"…already exists…".

### AS-SET-028 — Init with -Force overwrites existing settings
Status: Draft | Source: AS-DOC-SET-028

With `-Force`, init replaces the existing `settings.json`.

Example: first init with `target`, then init with `target2 -Force` →
`targetRoot = <TestDrive>\target2`.

### AS-SET-029 — The copy mode value ignores case
Status: Draft | Source: AS-DOC-SET-029; AS-CODE-SET-010

The app lower-cases the copy mode before validating it, in both init and
`settings set`.

Example: `-CopyMode Copy` → `copyMode = copy`; `settings set -Key copyMode
-Value Copy` → `copyMode = copy`.

### AS-SET-030 — The copy mode "move" is rejected
Status: Draft | Source: AS-DOC-SET-030; AS-CODE-SET-010

The value `move` is rejected with the same message as any other invalid
value (`AS-SET-006`): `Invalid copy mode 'move'. Must be 'copy' - 'move' is
no longer supported, since Reshelf never deletes source files.` This
applies to init and to `settings set`.

Example: `-CopyMode move` → error "…no longer supported…"; `settings set
-Key copyMode -Value move` → the same error.

### AS-SET-031 — Init checks that the target root is writable before it saves
Status: Draft | Source: AS-DOC-SET-031; AS-CODE-SET-002, AS-CODE-SET-003, AS-CODE-SET-013

Before init saves anything, it checks that the target root is writable
(`Assert-ReshelfPathWritable`): if the path doesn't exist, it tries to
create it (recursively) first — failure here throws `Target root '<path>'
does not exist and could not be created: <exception message>`. Once the
path exists, the app writes an empty probe file named
`.reshelf-write-probe-<guid>.tmp` directly in that folder and deletes it; if
writing or deleting fails, it throws `Target root '<path>' is not writable:
<exception message>`. This is the only writability check in the app, used
both here and on every `targetRoot` change via `settings set` (`AS-SET-040`).

Example: `TargetRoot` points to an existing file → "…is not writable…";
`TargetRoot` doesn't exist and can't be created (e.g. a read-only parent) →
"…does not exist and could not be created…".

### AS-SET-032 — Init writes a settings file that matches the schema
Status: Draft | Source: AS-DOC-SET-032; AS-CODE-SET-015

The `settings.json` that init writes is schema-validated on write, through
the same save path used everywhere else (`AS-SET-050`).

Example: init with only `TargetRoot` → valid file with all 13 keys.

### AS-SET-033 — Reading settings runs init automatically when none exist yet
Status: Draft | Source: AS-DOC-SET-033; AS-CODE-SET-004

Reading settings never fails just because `settings.json` doesn't exist
yet: whenever anything calls `Get-ReshelfSettings` and finds no file at
`<dataHome>/settings.json`, it transparently runs
`Initialize-ReshelfSettings` and returns the freshly created settings. This
isn't limited to a first explicit CLI command — `Get-ReshelfSettings` is
also called internally by `settings set` and `settings set-token`, so
either of those can trigger the full init prompt sequence too (see
`AS-SET-042` and `CF-SET-002` in
`91-suspected-defects-carryforward.md`).

Example: first `recognize` on a fresh machine → the init prompts appear.

## Reading settings

### AS-SET-034 — Existing settings are schema-checked, then returned as-is
Status: Draft | Source: AS-DOC-SET-034; AS-CODE-SET-005

If `settings.json` exists, it is validated against the `settings` schema
before being parsed. An invalid file throws: `Settings file at '<path>'
does not match the settings schema. Fix it manually or re-run
'Reshelf.ps1 settings init -Force'.` — no automatic repair is attempted. A
valid file's values are returned as read (except `dataHome`, always
overwritten — `AS-SET-014`).

Example: after init with `<TestDrive>\target` → `targetRoot = <TestDrive>\target`.

## Changing settings ("settings set")

### AS-SET-035 — "settings set" changes and saves one top-level key
Status: Draft | Source: AS-DOC-SET-035; AS-CODE-SET-019

`settings set -Key <key> -Value <value>` loads the current settings
(auto-initializing if needed, `AS-SET-033`), changes one top-level key and
saves the file (`AS-SET-050`). A later read returns the new value.

Example: `settings set -Key discogsTokenEnvVar -Value MY_TOKEN` →
`discogsTokenEnvVar = MY_TOKEN`, also after a new read.

### AS-SET-036 — "settings set" converts the value to the key's type
Status: Draft | Source: AS-DOC-SET-036; AS-CODE-SET-021

The value comes in as text. The app converts it based on the *current*
value's runtime type: to an integer for a numeric key
(`trackNumberPadWidth`, `coverMaxDimension`, `rateLimitPerMinute`,
`cacheTtlDays`), or left as plain text otherwise. The code also has a
boolean-conversion branch, but no current settings field is boolean, so
that branch is never exercised in practice.

Example: `settings set -Key cacheTtlDays -Value 45` → `cacheTtlDays = 45`
as an integer, not `"45"`.

### AS-SET-037 — "settings set" rejects an unknown key
Status: Draft | Source: AS-DOC-SET-037; AS-CODE-SET-019

An unknown key gives an error that says "Unknown settings key '<key>'.
Valid keys: <comma-and-space-joined, alphabetically sorted list>."

Example: `settings set -Key notAKey -Value x` → error "Unknown settings
key…".

### AS-SET-038 — "settings set" cannot change nested keys
Status: Draft | Source: AS-DOC-SET-038; AS-CODE-SET-020

`settings set` works only for simple (non-nested) keys: if the current
value of a key is itself an object (e.g. `namingTemplates`), it throws
`Setting key '<key>' is a nested object and cannot be set directly. Edit
settings.json manually for now.` (See `AS-SET-007` for the specific
`namingTemplates` case this rules out.)

Example: changing `namingTemplates.trackFile` needs a hand edit of
`settings.json`.

### AS-SET-039 — "settings set" rejects an invalid copy mode
Status: Draft | Source: AS-DOC-SET-039; AS-CODE-SET-022

A copy mode value that is not `copy` gives the same full message as init
(`AS-SET-006`, `AS-SET-030`): `Invalid copy mode '<value>'. Must be 'copy' -
'move' is no longer supported, since Reshelf never deletes source files.` —
the "move" wording appears even for an unrelated value like `shred`; the
test only checks for the "Invalid copy mode" prefix.

Example: `settings set -Key copyMode -Value shred` → error "Invalid copy
mode 'shred'. Must be 'copy' - 'move' is no longer supported…".

### AS-SET-040 — Changing targetRoot checks write access again and creates the folder
Status: Draft | Source: AS-DOC-SET-040; AS-CODE-SET-023

When the user changes `targetRoot`, the app re-runs the same writability
check as init (`AS-SET-031`), which creates a missing folder. No equivalent
existence/writability check exists for any other path-like field
(`defaultSourceRoot`, `ffmpegPath`, `taglibSharpPath`, `dataHome`) changed
through `settings set`.

Example: `settings set -Key targetRoot -Value <TestDrive>\newTarget` →
`targetRoot = <TestDrive>\newTarget`, and the folder exists.

## Discogs token

### AS-SET-041 — The user creates a Discogs Personal Access Token by hand
Status: Draft | Source: AS-DOC-SET-041

The app needs a Discogs account and a Personal Access Token. The user logs
into discogs.com, opens **Settings → Developers → Generate new token** and
copies the token. No OAuth app is needed, because the app has one user.

Example: the user copies the token and pastes it at the init or
`set-token` prompt.

### AS-SET-042 — "settings set-token" replaces only the token — but can silently run full init first
Status: Draft | Source: AS-DOC-SET-042; AS-CODE-SET-017, AS-CODE-SET-018

`settings set-token` loads the current settings first via
`Get-ReshelfSettings` — which, per `AS-SET-033`, auto-initializes a
brand-new settings file if none exists yet. So running `set-token` against
a data home with no settings file does not error; it silently runs the
entire interactive init prompt sequence (target root, default source root,
copy mode, and a first token prompt) before then prompting a second time
for the token actually being set. See `CF-SET-002` in
`91-suspected-defects-carryforward.md`.

Once settings are loaded, it always prompts once more for the token
(`Discogs Personal Access Token`, secure string — see `CF-SET-001` about
this prompt's wording). An empty/zero-length answer sets
`discogsTokenEncrypted` to `""`; otherwise it is encrypted the same way as
init (`AS-SET-024`). Every other field stays the same.

Example: user types `updated-token` →
decrypt(`discogsTokenEncrypted`) = `updated-token`; `targetRoot`,
`defaultSourceRoot`, `copyMode` unchanged.

### AS-SET-043 — "settings set-token" fails in a non-interactive host, with no exception
Status: Draft | Source: AS-DOC-SET-043; AS-CODE-SET-016

Unlike init, `set-token` has no non-interactive path at all: on a
non-interactive host it throws immediately: `'settings set-token' requires
an interactive host - a token is never accepted as a plain command-line
argument (it would leak into shell history/process list).` It does not
prompt.

Example: `set-token` from a scheduled task → error "…interactive…".

## Mechanics (code-only facts)

### AS-SET-048 — "Interactive" means console input is not redirected
Status: Draft | Source: AS-CODE-SET-001

The app treats the host as interactive when `[Console]::IsInputRedirected`
is false. This single check gates every prompt in this area (init's three
prompts, `set-token`'s prompt) and the non-interactive fail-fast paths
(`AS-SET-019`, `AS-SET-022`, `AS-SET-023`, `AS-SET-043`).

Example: running with stdin redirected (e.g. from a script or CI pipeline)
makes this return `false`, even if a console window is attached.

### AS-SET-049 — New settings start from a template file, with exactly five fields overridden
Status: Draft | Source: AS-CODE-SET-014

`settings init` loads `legacy/config/settings.default.json` as the base
object, then overrides exactly five fields on it: `defaultSourceRoot`,
`targetRoot`, `copyMode`, `dataHome`, `discogsTokenEncrypted`. Every other
field — `namingTemplates.*`, `trackNumberPadWidth`, `coverMaxDimension`,
`discogsTokenEnvVar`, `rateLimitPerMinute`, `cacheTtlDays`, `ffmpegPath`,
`taglibSharpPath` — keeps the literal value from the template file
(confirming the per-field defaults in `AS-SET-007`–`010`, `012`, `013`,
`015`, `016`). The template's own placeholder values for the five
overridden fields (`""` for everything except `copyMode: "copy"`) are
irrelevant at init time, because the code always replaces them.

### AS-SET-050 — Every settings write is schema-validated through the same save path
Status: Draft | Source: AS-CODE-SET-015, AS-CODE-SET-024

Init, `set-token` and `settings set` all write the assembled settings
object to `<dataHome>/settings.json` through the same helper,
`Set-ReshelfJsonFile -SchemaName settings` — the same schema name used to
validate a read (`AS-SET-034`). There is only one save path for settings in
the whole app.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-11 | Phase 3: merged 42 `AS-DOC-SET-*` requirements (`001`, `044`–`047` not owned by this area — see scope note) and 24 `AS-CODE-SET-*` facts into `AS-SET-002`–`043`, `048`–`050`. Three phase-1 contradictions (`AS-DOC-DEF-014`–`016`) re-verified against the code and confirmed. One new contradiction found and resolved in already-merged DAT content (`AS-CODE-DAT-024` vs `AS-DOC-SET-047` — `Protect-ReshelfSecret` does not actually accept an empty string; `AS-DAT-092` corrected). Two suspected defects carried forward (`AS-CODE-DEF-005`/`006` → `CF-SET-001`/`002`). |
