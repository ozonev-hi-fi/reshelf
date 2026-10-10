# As-is (from code): Data and storage

Status: Draft | Version: 0.1 | Last updated: 2026-10-10

### AS-CODE-DAT-001 — Data home default location and override
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:13 › Resolve-ReshelfDataHome

If environment variable `RESHELF_HOME` is set, its value is used as the data home path. Otherwise the default is a `.data` folder located two directories above this module's own folder (i.e. the folder that also contains `schemas/`), not the Windows user profile or any other fixed system location.

Example: module at `legacy/scripts/common/Reshelf.Common.psm1` with no `RESHELF_HOME` set → data home resolves to `legacy/.data`.

### AS-CODE-DAT-002 — Data home auto-created if missing
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:13 › Resolve-ReshelfDataHome

If the resolved data home path does not exist yet, it is created as a directory automatically (this is a read/resolve function with a filesystem side effect, not a pure read).

### AS-CODE-DAT-003 — Data home must be a directory
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:13 › Resolve-ReshelfDataHome

If the resolved data home path already exists but is not a directory (e.g. it is a regular file), the function throws: `Reshelf data home '<path>' exists but is not a directory.`

### AS-CODE-DAT-004 — Data home is returned as a resolved absolute path
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:13 › Resolve-ReshelfDataHome

The returned value is always an absolute, canonicalized path (via `Resolve-Path`), never the raw relative/env-var string that was used to locate it.

### AS-CODE-DAT-005 — Cue timestamp format is MM:SS:FF, not HH:MM:SS
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:175 › ConvertTo-ReshelfCueTimestampSeconds

A cue-sheet `INDEX 01` style timestamp with three colon-separated parts is interpreted as minutes, seconds, and CD-audio frames (0-74 at 75 frames/second) — never as hours:minutes:seconds, even though the shape (`NN:NN:NN`) looks identical to a clock time.

### AS-CODE-DAT-006 — Cue timestamp conversion formula and rounding
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:175 › ConvertTo-ReshelfCueTimestampSeconds

The timestamp is converted to total seconds as `minutes*60 + seconds + frames/75.0`, rounded to 3 decimal places.

Example: `"03:25:37"` → 3×60 + 25 + 37/75 = 205.493 seconds.

### AS-CODE-DAT-007 — SHA-256 text hashing is lowercase hex
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:192 › Get-ReshelfSha256Hex

Text is UTF-8 encoded, hashed with SHA-256, and returned as a lowercase hexadecimal string (64 characters), never uppercase and never with separators.

Example: `""` (empty string) → `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b85`.

### AS-CODE-DAT-008 — Stable key canonical string
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:206 › Get-ReshelfStableKey

The key is derived from a canonical string built as `"<normalized artist>|<normalized album>|<year-or-empty>"`, where artist/album are run through the same text normalization used for matching (NFKC, lowercased, letters/digits/spaces only — see AS-CODE-TXT-001/002), and a missing (`null`) year becomes an empty string rather than being omitted or defaulted to a placeholder number.

Example (illustration): Artist `"Pink Floyd"`, Album `"The Wall"`, Year `1979` → canonical string `"pink floyd|the wall|1979"`.

### AS-CODE-DAT-009 — Stable key is truncated to 16 hex characters
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:206 › Get-ReshelfStableKey

The final stable key is only the first 16 characters of the 64-character SHA-256 hex digest of the canonical string, not the full hash.

### AS-CODE-DAT-010 — Long-path prefix: already-prefixed paths pass through
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:261 › ConvertTo-ReshelfLongPath

A path that already starts with `\\?\` is returned unchanged — the function is idempotent and never double-prefixes.

### AS-CODE-DAT-011 — Long-path threshold is 240 characters, exclusive
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:261 › ConvertTo-ReshelfLongPath

The default length threshold is 240 characters (overridable via `-Threshold`). A path shorter than the threshold is returned unchanged. A path whose length equals the threshold exactly is treated as needing the prefix (the check is strictly "less than", not "less than or equal") — i.e. a 240-character path already gets the `\\?\` treatment, not just paths of 241+ characters.

### AS-CODE-DAT-012 — Long UNC paths get `\\?\UNC\` prefix
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:261 › ConvertTo-ReshelfLongPath

A path at/over the threshold that starts with `\\` (a UNC path) has its leading `\\` replaced with `\\?\UNC\`.

Example: `\\server\share\...` (240+ chars) → `\\?\UNC\server\share\...`.

### AS-CODE-DAT-013 — Long non-UNC paths get `\\?\` prefix
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:261 › ConvertTo-ReshelfLongPath

A path at/over the threshold that is not a UNC path (e.g. a drive-letter path) is returned with `\\?\` simply prepended.

### AS-CODE-DAT-014 — Recognized audio extensions are a fixed literal list
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:286 › Test-ReshelfIsAudioExtension

An extension is considered audio if it case-insensitively matches one of exactly: `.flac`, `.mp3`, `.m4a`, `.wav`, `.ogg`, `.wma`, `.aac`, `.ape`, `.mpc`. An empty extension (no extension at all) is a valid, non-throwing input that simply returns false.

### AS-CODE-DAT-015 — Lossless formats are a separate, smaller literal list
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:301 › Test-ReshelfIsLosslessFormat

Lossless detection uses its own fixed, case-insensitive list, independent of the audio-extension list above: `.flac`, `.wav`, `.ape`, `.alac`.

### AS-CODE-DAT-016 — Audio file discovery is files-only, optionally recursive
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:314 › Get-ReshelfAudioFilesInFolder

Only files (never directories) are considered. Subfolders are included only when `-Recurse` is passed.

### AS-CODE-DAT-017 — Audio file discovery silently ignores filesystem errors
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:314 › Get-ReshelfAudioFilesInFolder

Enumeration uses `-ErrorAction SilentlyContinue`: an inaccessible folder/file (e.g. a permission error) is silently skipped rather than raising an error, so the function can return a partial or empty result without the caller being told anything went wrong.

### AS-CODE-DAT-018 — Audio file discovery always returns an array
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:314 › Get-ReshelfAudioFilesInFolder

Results are filtered down to files whose extension passes `Test-ReshelfIsAudioExtension`, and the result is always wrapped as an array (`@(...)`) even when there are 0 or exactly 1 matches, so callers never have to special-case PowerShell's single-item unwrapping.

### AS-CODE-DAT-019 — Relative path: root-prefix match is case-insensitive
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:513 › Get-ReshelfRelativePath

The source root's trailing `\` or `/` is trimmed first, then the path is checked to start with that root using a case-insensitive ordinal comparison. If the path does not start with the (trimmed) root, the original, unmodified path is returned — no error is raised for a path outside the root.

### AS-CODE-DAT-020 — Relative path output always uses forward slashes
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:513 › Get-ReshelfRelativePath

When the path is under the root, the root prefix and any leading `\`/`/` are stripped, and every remaining backslash is converted to a forward slash — the result always uses `/` as separator regardless of the input's original separator style.

Example: SourceRoot `C:\Music`, Path `C:\Music\Artist\Album\01 Track.flac` → `Artist/Album/01 Track.flac`.

### AS-CODE-DAT-021 — File-set hash entry format
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:533 › Get-ReshelfFileSetHash

For each input file path, an entry string `"<lowercased file name>|<file length in bytes>"` is built (file content is never read/hashed, only name and size). Entries are then sorted using ordinal (not culture-aware, not locale-sensitive) string comparison before being joined with `\n` and SHA-256 hashed — so the resulting hash does not depend on the order the `FilePaths` array was given in, only on which files (name+size) are present.

### AS-CODE-DAT-022 — File-set hash fails loudly on a missing file
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:533 › Get-ReshelfFileSetHash

Each path is resolved via `Get-Item` with `-ErrorAction Stop`, so a missing file produces an immediate, clear "cannot find path" terminating error rather than continuing with a null/empty entry.

### AS-CODE-DAT-023 — File-set hash accepts an empty file list
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:533 › Get-ReshelfFileSetHash

An empty `FilePaths` array is explicitly allowed (`AllowEmptyCollection`) and produces the SHA-256 hash of an empty string (`e3b0c4...852b85`), not an error.

### AS-CODE-DAT-024 — Secret protection uses Windows DPAPI, machine/user-bound
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:561 › Protect-ReshelfSecret

A plaintext secret is encrypted via the built-in SecureString DPAPI (data protection API) flow (`ConvertTo-SecureString -AsPlainText` then `ConvertFrom-SecureString`), producing ciphertext that can only be decrypted by the same Windows user account on the same machine. An empty-string secret is explicitly allowed as input.

### AS-CODE-DAT-025 — Secret un-protection mirrors protection but does not allow an empty string
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:575 › Unprotect-ReshelfSecret

`Unprotect-ReshelfSecret` reverses the DPAPI encryption (`ConvertTo-SecureString` then `ConvertFrom-SecureString -AsPlainText`) to recover the original plaintext. Unlike `Protect-ReshelfSecret`, its `$EncryptedText` parameter does not have `AllowEmptyString`, so passing an empty string fails PowerShell's mandatory-parameter binding instead of being accepted.

### AS-CODE-DAT-026 — TagLibSharp context is stored, not validated
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:590 › Set-ReshelfTagLibSharpContext

`Set-ReshelfTagLibSharpContext` only stores the given `TagLibSharpPath`/`DataHome` into module-level state for later calls to use; it performs no validation (does not check the path exists, does not check the data home exists) at the time it is called.

### AS-CODE-DAT-027 — Effective data home resolution order
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:602 › Get-ReshelfEffectiveDataHome

The data home used is, in order of preference: (1) an explicit `-DataHome` argument, (2) the data home previously stashed by `Set-ReshelfTagLibSharpContext` for the current run, (3) the default `.data` folder from `Resolve-ReshelfDataHome` (which creates it if missing).

### AS-CODE-DAT-028 — TagLibSharp assembly load is a one-time, process-wide no-op after first load
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:619 › Import-ReshelfTagLibSharp

If the `TagLib.File` type is already loaded in the current session (checked via `'TagLib.File' -as [type]`), the function returns immediately without re-resolving a path or calling `Add-Type` again — `Add-Type` for this DLL only ever runs once per process.

### AS-CODE-DAT-029 — TagLibSharp DLL path resolution order and default relative path
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:619 › Import-ReshelfTagLibSharp

The DLL path used is, in order: (1) an explicit `-TagLibSharpPath` argument, (2) the path previously stashed by `Set-ReshelfTagLibSharpContext`, (3) `<effective data home>/lib/TagLibSharp.dll` — where the effective data home itself follows the same explicit-param → stashed-context → `Resolve-ReshelfDataHome`-default order. The literal relative path `lib/TagLibSharp.dll` is a fixed, hardcoded convention.

### AS-CODE-DAT-030 — Missing TagLibSharp DLL throws a specific instructional error
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:619 › Import-ReshelfTagLibSharp

If no file exists at the resolved path, the function throws: `TagLibSharp.dll not found at '<path>'. Download the TagLibSharp NuGet package (e.g. 'dotnet add package TagLibSharp' in a throwaway project), copy TagLibSharp.dll from its lib/netstandard2.0 folder to that path, or set settings.taglibSharpPath to its location.` — naming a specific NuGet package id, a specific sub-folder (`lib/netstandard2.0`), and a specific settings key (`settings.taglibSharpPath`).

### AS-CODE-DAT-031 — Schema file path convention and extension
Status: Draft | Source: legacy/scripts/common/Reshelf.Json.psm1:5 › Resolve-ReshelfSchemaPath

A schema name is resolved to `<two directories above this module>/schemas/<SchemaName>.schema.json` — the literal suffix `.schema.json` is always appended; callers pass only the bare schema name.

### AS-CODE-DAT-032 — Missing schema file throws
Status: Draft | Source: legacy/scripts/common/Reshelf.Json.psm1:5 › Resolve-ReshelfSchemaPath

If no file exists at the resolved schema path, the function throws: `Schema '<SchemaName>' not found at '<path>'.`

### AS-CODE-DAT-033 — JSON validation supports three input forms, defaulting to file path
Status: Draft | Source: legacy/scripts/common/Reshelf.Json.psm1:20 › Test-ReshelfJson

`Test-ReshelfJson` validates JSON from exactly one of three mutually exclusive sources: a file on disk (`-Path`, the default parameter set when none is named explicitly), an in-memory object (`-InputObject`, serialized to JSON first), or a raw JSON string (`-Json`).

### AS-CODE-DAT-034 — Object validation serializes with Depth 10 by default
Status: Draft | Source: legacy/scripts/common/Reshelf.Json.psm1:20 › Test-ReshelfJson

The `-InputObject` form serializes via `ConvertTo-Json -Depth $Depth` with a default `$Depth` of 10 (overridable). An object graph nested deeper than 10 levels is silently truncated/flattened by `ConvertTo-Json` beyond that depth, which can make schema validation pass or fail based on an incomplete JSON representation of the object rather than its full shape.

### AS-CODE-DAT-035 — Validation itself fully delegates to the built-in `Test-Json` cmdlet
Status: Draft | Source: legacy/scripts/common/Reshelf.Json.psm1:20 › Test-ReshelfJson

No custom validation logic exists beyond resolving the schema file and (for the object form) serializing — the actual JSON Schema check is the standard PowerShell `Test-Json -SchemaFile` cmdlet, returning its boolean result unchanged.

### AS-CODE-DAT-036 — Writing JSON validates against schema before touching disk
Status: Draft | Source: legacy/scripts/common/Reshelf.Json.psm1:51 › Set-ReshelfJsonFile

`Set-ReshelfJsonFile` serializes the object (same `ConvertTo-Json -Depth` default of 10, same truncation caveat as AS-CODE-DAT-034) and validates it against the named schema BEFORE writing anything. On failure it throws: `Document for '<Path>' does not match schema '<SchemaName>'.`, with the first captured validation error's exception message appended as extra detail when one is available (validation errors are captured via `-ErrorVariable`, not left to surface on their own).

### AS-CODE-DAT-037 — Writing JSON auto-creates the parent directory
Status: Draft | Source: legacy/scripts/common/Reshelf.Json.psm1:51 › Set-ReshelfJsonFile

If the target file's parent directory does not exist, it is created recursively (`New-Item -ItemType Directory -Force`) before the file is written — equivalent to `mkdir -p`.

### AS-CODE-DAT-038 — JSON file is written as UTF-8 without BOM and the path is returned
Status: Draft | Source: legacy/scripts/common/Reshelf.Json.psm1:51 › Set-ReshelfJsonFile

The file is written with `Set-Content -Encoding utf8`, which under PowerShell 7+ (this module requires 7.4) means UTF-8 **without** a byte-order mark. The function returns the `Path` it was given on success.

## Suspected defects

### AS-CODE-DEF-DAT-001
`legacy/scripts/common/Reshelf.Common.psm1:525` (`Get-ReshelfRelativePath`) — the "is path under root" check is a plain string prefix match (`$Path.StartsWith($normalizedRoot, ...)`) with no check that a path separator follows the root. A root of `C:\Music` would match a path `C:\MusicArchive\foo.flac` (it textually starts with `C:\Music`), producing a wrong "relative" result (`Archive/foo.flac`) for a path that is not actually inside the root folder.

### AS-CODE-DEF-DAT-002
`legacy/scripts/common/Reshelf.Common.psm1:310` (`Test-ReshelfIsLosslessFormat`) vs `legacy/scripts/common/Reshelf.Common.psm1:3` (`$script:ReshelfAudioExtensions`) — `.alac` is treated as a lossless format, but `.alac` is absent from the audio-extensions list used by `Test-ReshelfIsAudioExtension` and therefore by `Get-ReshelfAudioFilesInFolder`. A standalone `.alac` file is never discovered as an audio file through the normal folder-scan path, making the "lossless" classification for that extension effectively unreachable in practice.

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.1 | 2026-10-10 | Phase 2 draft from code. |
