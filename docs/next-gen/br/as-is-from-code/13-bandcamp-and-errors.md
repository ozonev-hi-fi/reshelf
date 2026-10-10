# As-Is (from code): Bandcamp and Cross-Cutting Error Handling

Status: Draft | Version: 0.1 | Last updated: 2026-10-10

Area codes: BND (Bandcamp) and ERR (cross-cutting error handling). Unlike the other Phase 2 files, this
one is deliberately cross-cutting: BND is a grep sweep across all of `legacy/scripts/**` and
`legacy/ui/**`; ERR is a sweep across `legacy/scripts/common/*.psm1` and `legacy/scripts/*.ps1` for
patterns that are NOT already documented as a specific rule in `10-apply.md`, `11-lossy-tracking.md`,
or `12-cli.md`. Read directly from code, independent of `docs/next-gen/br/as-is-from-docs/`.

## Bandcamp (BND)

### AS-CODE-BND-001 — Bandcamp exists only as two forward-looking comments, nowhere else
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1453; legacy/scripts/common/Reshelf.Common.psm1:256

A case-insensitive search for `bandcamp` across every file under `legacy/scripts/**` turns up exactly
two matches, both inside `#` comments, not in any string literal, config key, schema field, function
name, or executable logic:

- `Reshelf.EditProposal.psm1:1453` — `"a case change. (Bandcamp will get the same priority once
  plan/13 adds it.)"`
- `Reshelf.Common.psm1:256` — `"Only ever applied to a name with no Discogs (or, later, Bandcamp)
  match..."`

There is no Bandcamp HTTP client, API call, URL, config key, schema field, cache, or UI element
anywhere in `legacy/scripts/**`. This independently confirms, from code alone, that Bandcamp is
plan-only: a documented future intent, not a stub, placeholder, or partial implementation.

### AS-CODE-BND-002 — `legacy/ui/**` has zero references to Bandcamp
Status: Draft | Source: legacy/ui/** (directory-wide grep, no matches)

A case-insensitive search for `bandcamp` across every file under `legacy/ui/**` returns zero matches of
any kind — not even a comment. The UI layer has no surface, label, or code path that mentions Bandcamp
at all.

## Cross-cutting error handling (ERR)

### AS-CODE-ERR-001 — Every JSON-backed store validates against its schema before being trusted, with "missing file" handled separately from "invalid file"
Status: Draft | Source: legacy/scripts/common/Reshelf.Implementation.psm1:27,918; legacy/scripts/common/Reshelf.LossyTracking.psm1:16; legacy/scripts/common/Reshelf.Settings.psm1:79,319; legacy/scripts/common/Reshelf.EditProposal.psm1:2878

Every module that owns or reads a JSON-backed document follows the same two-step guard, confirmed
across `Reshelf.Settings.psm1` (settings and session schemas), `Reshelf.EditProposal.psm1` (recognition
schema), `Reshelf.Implementation.psm1` (apply-log and proposal schemas), and
`Reshelf.LossyTracking.psm1` (lossy-tracking schema): a schema-validation check runs before the content
is parsed and used, and on mismatch the code throws a message of the exact shape
`"<Noun> at '<path>' does not match the <schema-name> schema."`. A file that simply doesn't exist yet is
treated differently from one that exists but fails validation: list/ledger/log readers return an empty
array for "file not found", and only throw once a present file fails schema validation.

### AS-CODE-ERR-002 — `Write-Error` is never used anywhere in the app; `throw` and `Write-Warning` divide the work
Status: Draft | Source: legacy/scripts/common/*.psm1; legacy/scripts/*.ps1 (grep: zero `Write-Error` matches; 8 `Write-Warning` matches)

A sweep of every module and script file (`legacy/scripts/common/*.psm1`, `legacy/scripts/*.ps1`) finds
zero uses of `Write-Error` anywhere in the app. Every hard failure is surfaced by `throw` (a terminating
exception), which is then either caught locally and turned into a result object or log entry, or left
to propagate to the caller. `Write-Warning` is the sole mechanism used for "something is off, but not
fatal" conditions, confirmed in: `Reshelf.LossyTracking.psm1`'s five mutator functions warning-and-no-op
when a given `stableKey` has no matching entry; `Reshelf.Implementation.psm1`'s ffmpeg split warning on
a successful FLAC-retry recovery; `Reshelf.Discogs.psm1`'s cache cleanup warning when it can't delete a
stale cache file; and `Start-ReshelfUiServer.ps1` warning per failed HTTP request rather than crashing
its listener loop.

### AS-CODE-ERR-003 — No global `$ErrorActionPreference`; terminating behavior is opted into per cmdlet call with `-ErrorAction Stop`
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:546; legacy/scripts/common/Reshelf.Discogs.psm1:148; legacy/scripts/common/Reshelf.Settings.psm1:45,276; legacy/scripts/common/Reshelf.Implementation.psm1:775,824

`$ErrorActionPreference` is never set anywhere in the app (zero matches across the sweep), so
PowerShell's own per-cmdlet default (mostly non-terminating "Continue") remains in effect everywhere
except where a call site explicitly adds `-ErrorAction Stop`. That opt-in is applied deliberately and
only to cmdlets whose silent-continue default would otherwise hide a real failure behind a later, more
confusing symptom: `Get-Item` (`Reshelf.Common.psm1`), `Remove-Item` (`Reshelf.Discogs.psm1`'s stale
Discogs-cache cleanup), `New-Item` (`Reshelf.Settings.psm1`'s data-folder creation), and `Copy-Item`
(`Reshelf.Implementation.psm1`'s track/companion staging copies, documented as
AS-CODE-APL-037/AS-CODE-APL-040). Note `Reshelf.Implementation.psm1`'s own `New-Item` calls for
directory creation do NOT follow this same opt-in (see `AS-CODE-DEF-APL-001` in `10-apply.md`) — an
inconsistency within that one module, not a sign the app-wide pattern itself is absent elsewhere.

### AS-CODE-ERR-004 — No shared retry/backoff helper; two independent, unrelated retry implementations
Status: Draft | Source: legacy/scripts/common/Reshelf.Discogs.psm1:236 › Invoke-DiscogsRequest; legacy/scripts/common/Reshelf.Implementation.psm1:232 › Invoke-ReshelfFfmpegSplit

There is no shared, reusable retry-with-backoff utility anywhere in the app. The only two places that
retry at all reimplement it independently, for unrelated reasons, with no code shared between them:
`Reshelf.Discogs.psm1`'s `Invoke-DiscogsRequest` runs a generic up-to-3-attempt loop around any Discogs
API call, with a fixed exponential backoff of 1, 2, 4 seconds normally, or a much longer 20, 40, 60
second backoff specifically on an HTTP 429 (rate limit) response — preferring the server's own
`Retry-After` header when present. `Reshelf.Implementation.psm1`'s ffmpeg split instead retries exactly
once, only for one specific ffmpeg stderr message ("invalid block size"), by nudging a timestamp forward
0.05 seconds (documented as AS-CODE-APL-013 in `10-apply.md`). Neither module is aware of or reuses the
other's retry logic.

### AS-CODE-ERR-005 — No general-purpose error/diagnostic log; only apply-log.json persists a failure message, and only for apply
Status: Draft | Source: legacy/scripts/common/*.psm1; legacy/scripts/*.ps1 (sweep for a shared log file)

There is no centralized error or diagnostic log file anywhere in the app. `Write-Warning` and
`Write-Verbose` output goes only to the PowerShell host's own streams and is never persisted to disk.
The sole place any failure text is written to a file is `apply-log.json`'s own `errorMessage` field on a
`failed`-status entry (an apply-specific, per-release record — see `10-apply.md`, AS-CODE-APL-005 and
AS-CODE-APL-051). A failure during `recognize`, `propose`, `settings`, or any `lossy` subcommand leaves
no durable trace beyond whatever the calling terminal happened to display.

## Changelog

| Version | Date | Changes |
|---|---|---|
| 0.1 | 2026-10-10 | Phase 2 draft from code. |
