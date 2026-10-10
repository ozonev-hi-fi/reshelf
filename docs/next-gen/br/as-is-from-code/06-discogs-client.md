# As-Is BR (from code) — Discogs Client

Status: Draft | Version: 0.1 | Last updated: 2026-10-10

This document describes the as-is behavior of the legacy Discogs HTTP client, read directly from `legacy/scripts/common/Reshelf.Discogs.psm1`. It is written independently from the Phase 1 (docs-based) BR, for later comparison. Area code: **DSC**.

### AS-CODE-DSC-001 — Token lookup: env-var name comes from settings.json
Status: Draft | Source: legacy/scripts/common/Reshelf.Discogs.psm1:12 › Get-DiscogsToken

The environment variable name to check for the Discogs token is read from `settings.json`'s `discogsTokenEnvVar` field. If `settings.json` doesn't exist, or the field is unset, the name defaults to `DISCOGS_ACCESS_TOKEN`.

Example: `settings.json` has no `discogsTokenEnvVar` field → the function checks `DISCOGS_ACCESS_TOKEN`.

### AS-CODE-DSC-002 — Token lookup priority 1: process environment variable
Status: Draft | Source: legacy/scripts/common/Reshelf.Discogs.psm1:12 › Get-DiscogsToken

If the resolved environment variable (AS-CODE-DSC-001) is set in the process environment, its value is returned immediately — this is the highest-priority source and short-circuits the `.env` file and settings.json checks below.

### AS-CODE-DSC-003 — Token lookup priority 2: `.env` file
Status: Draft | Source: legacy/scripts/common/Reshelf.Discogs.psm1:12 › Get-DiscogsToken

When the environment variable isn't set, the function reads a `.env` file (defaulting to the repo root). It skips blank lines and lines starting with `#`, then matches a line of the form `[export ]VARNAME = value`. A quoted value (`"..."` or `'...'`) is taken verbatim between the quotes; an unquoted value has any trailing `# comment` stripped and is trimmed.

Example (illustration): a line `DISCOGS_ACCESS_TOKEN=abc123 # my token` → value `abc123`.

### AS-CODE-DSC-004 — Token lookup priority 3: DPAPI-encrypted token in settings.json
Status: Draft | Source: legacy/scripts/common/Reshelf.Discogs.psm1:12 › Get-DiscogsToken

As a last resort, if `settings.json` has a `discogsTokenEncrypted` field, it is decrypted via `Unprotect-ReshelfSecret` and returned. This is checked last so it never overrides an env var or `.env` file that already works.

### AS-CODE-DSC-005 — Token not found throws a descriptive error
Status: Draft | Source: legacy/scripts/common/Reshelf.Discogs.psm1:12 › Get-DiscogsToken

If none of the three sources yields a token, the function throws an error naming the environment variable checked, the `.env` path, and the `settings.json` path, and suggests running `Reshelf.ps1 settings set-token`.

### AS-CODE-DSC-006 — Query pairs: sorted keys, array values expanded
Status: Draft | Source: legacy/scripts/common/Reshelf.Discogs.psm1:73 › Get-DiscogsQueryPair

Query keys are sorted alphabetically. A value that is an enumerable (not a string) is expanded into one key/value pair per element; any other value becomes a single pair. This ordering is shared by both cache-key canonicalization and URL building, so both always see keys in the same order.

### AS-CODE-DSC-007 — Cache key: SHA-256 hash of a canonical path+query string
Status: Draft | Source: legacy/scripts/common/Reshelf.Discogs.psm1:92 › Get-DiscogsCacheKey

The cache key is the lowercase hex SHA-256 hash of the string `"{Path}?key1=value1&key2=value2..."`, built from the sorted query pairs (AS-CODE-DSC-006). This hash is used as the cache file's base name.

### AS-CODE-DSC-008 — Cache files live under `{DataHome}/cache/discogs/{hash}.json`
Status: Draft | Source: legacy/scripts/common/Reshelf.Discogs.psm1:109 › Remove-DiscogsExpiredCache

Both the cache cleanup and the request cache read/write use the folder `{DataHome}/cache/discogs/`, with one file per cache key named `{hash}.json`.

### AS-CODE-DSC-009 — Cache TTL default: 30 days
Status: Draft | Source: legacy/scripts/common/Reshelf.Discogs.psm1:109 › Remove-DiscogsExpiredCache

The cache time-to-live defaults to 30 days (`CacheTtlDays` parameter, same default used by `Invoke-DiscogsRequest`). This cache exists to avoid re-querying/re-throttling across repeated runs during a review session — not as a long-term archive.

Both this default and the 55-requests/minute rate limit default (AS-CODE-DSC-015) are the hardcoded parameter defaults in this module; [03-settings-and-secrets.md](03-settings-and-secrets.md) (AS-CODE-SET-014) separately documents the same two numbers as configured defaults in `settings.default.json`.

### AS-CODE-DSC-010 — Expired cache entries are deleted on cleanup
Status: Draft | Source: legacy/scripts/common/Reshelf.Discogs.psm1:109 › Remove-DiscogsExpiredCache

A cache file is considered expired, and deleted, when `(Now - file.LastWriteTime).TotalDays >= CacheTtlDays`.

### AS-CODE-DSC-011 — Corrupt cache entries are deleted even if not yet expired
Status: Draft | Source: legacy/scripts/common/Reshelf.Discogs.psm1:109 › Remove-DiscogsExpiredCache

A non-expired cache file is also read and parsed as JSON during cleanup. If parsing throws (e.g. truncated by a crash mid-write), the file is deleted anyway, since a corrupt entry is worse than a missing one.

### AS-CODE-DSC-012 — Cache-delete failures are logged, never fatal
Status: Draft | Source: legacy/scripts/common/Reshelf.Discogs.psm1:109 › Remove-DiscogsExpiredCache

If deleting a stale/corrupt cache file fails (e.g. file locked by another process), a warning is written and the function continues — cache cleanup must never fail a real run over one entry it couldn't delete.

### AS-CODE-DSC-013 — Expired-cache cleanup runs at most once per data home per process
Status: Draft | Source: legacy/scripts/common/Reshelf.Discogs.psm1:236 › Invoke-DiscogsRequest

`Invoke-DiscogsRequest` tracks which data homes have already been pruned in an in-memory set for the lifetime of the process, and only calls `Remove-DiscogsExpiredCache` the first time a given data home is used.

### AS-CODE-DSC-014 — Fresh cache hit skips the network call and the token lookup entirely
Status: Draft | Source: legacy/scripts/common/Reshelf.Discogs.psm1:236 › Invoke-DiscogsRequest

If a cache file exists and its age is less than `CacheTtlDays`, its content is parsed from JSON and returned directly. This happens before the Discogs token is even looked up, so a fully cached request needs no token and makes no HTTP call.

### AS-CODE-DSC-015 — Rate limit default: 55 requests per rolling 60-second window
Status: Draft | Source: legacy/scripts/common/Reshelf.Discogs.psm1:162 › Wait-DiscogsRateLimit

The default rate limit is 55 requests per 60-second sliding window (`RateLimitPerMinute` parameter). Timestamps older than 60 seconds are dropped from the tracked window on every call.

### AS-CODE-DSC-016 — Throttle wait: sleep until the oldest request ages out of the window
Status: Draft | Source: legacy/scripts/common/Reshelf.Discogs.psm1:162 › Wait-DiscogsRateLimit

When the window is at or over the configured ceiling, or the low-remaining signal is set (AS-CODE-DSC-018/019), and there is at least one tracked timestamp, the function sleeps for `60 - (now - oldest timestamp)` seconds before letting the request proceed.

### AS-CODE-DSC-017 — Low-remaining signal is consumed exactly once
Status: Draft | Source: legacy/scripts/common/Reshelf.Discogs.psm1:162 › Wait-DiscogsRateLimit

The module-level "low remaining" flag is read into the current throttle decision and then unconditionally reset to `false` on every call to `Wait-DiscogsRateLimit`, so one 429 or low-remaining response only forces one extra wait on the very next request.

### AS-CODE-DSC-018 — 429 response sets the low-remaining signal
Status: Draft | Source: legacy/scripts/common/Reshelf.Discogs.psm1:236 › Invoke-DiscogsRequest

Receiving an HTTP 429 sets the module-level low-remaining flag, so the next request is throttled even if the per-minute timestamp count hasn't reached the ceiling.

### AS-CODE-DSC-019 — Low `X-Discogs-Ratelimit-Remaining` header also sets the low-remaining signal
Status: Draft | Source: legacy/scripts/common/Reshelf.Discogs.psm1:236 › Invoke-DiscogsRequest

After a successful response, if the `X-Discogs-Ratelimit-Remaining` header is present and its value is `<= 2`, the low-remaining flag is set too. Header parsing is best-effort: any parsing failure is caught and logged as verbose, never fails the request.

### AS-CODE-DSC-020 — Retry-After header: integer value is seconds
Status: Draft | Source: legacy/scripts/common/Reshelf.Discogs.psm1:185 › Get-DiscogsRetryAfterSeconds

If the `Retry-After` header value parses as an integer, it's returned directly, clamped to a minimum of 0.

### AS-CODE-DSC-021 — Retry-After header: date value converted to a wait duration
Status: Draft | Source: legacy/scripts/common/Reshelf.Discogs.psm1:185 › Get-DiscogsRetryAfterSeconds

If the value isn't an integer, it's parsed as an (assumed-UTC) date/time, and the number of seconds until that time (rounded up, clamped to a minimum of 0) is returned instead.

### AS-CODE-DSC-022 — Retry-After returns null when missing or unparseable
Status: Draft | Source: legacy/scripts/common/Reshelf.Discogs.psm1:185 › Get-DiscogsRetryAfterSeconds

If there are no response headers, the `Retry-After` header is absent, or its value matches neither the integer nor the date form, the function returns `null`.

### AS-CODE-DSC-023 — HTTP requests are GET-only, with response headers captured
Status: Draft | Source: legacy/scripts/common/Reshelf.Discogs.psm1:218 › Invoke-DiscogsHttpRequest

Every Discogs HTTP call is a GET via `Invoke-RestMethod`; the response headers are captured alongside the body and returned together.

### AS-CODE-DSC-024 — Request URL: fixed host, raw path, URL-encoded query string
Status: Draft | Source: legacy/scripts/common/Reshelf.Discogs.psm1:236 › Invoke-DiscogsRequest

The request URL is `https://api.discogs.com` + the given path, with a query string appended only when the query has at least one entry. Each key and value is percent-encoded with `System.Uri.EscapeDataString`.

### AS-CODE-DSC-025 — Fixed request headers
Status: Draft | Source: legacy/scripts/common/Reshelf.Discogs.psm1:236 › Invoke-DiscogsRequest

Every request sends `Authorization: Discogs token={token}` and a fixed `User-Agent: ReshelfPersonalOrganizer/0.1 (+local)`.

### AS-CODE-DSC-026 — Retry policy: 3 attempts maximum
Status: Draft | Source: legacy/scripts/common/Reshelf.Discogs.psm1:236 › Invoke-DiscogsRequest

A request is tried up to 3 times (`$maxAttempts = 3`) before giving up.

### AS-CODE-DSC-027 — Non-429 failure backoff: 1s, 2s, 4s
Status: Draft | Source: legacy/scripts/common/Reshelf.Discogs.psm1:236 › Invoke-DiscogsRequest

A failure that isn't a 401 or a 429 waits `1`, then `2`, then `4` seconds before the next attempt (`$backoffSeconds = @(1, 2, 4)`), indexed by attempt number.

### AS-CODE-DSC-028 — 429 failure backoff: Retry-After, else 20s/40s/60s
Status: Draft | Source: legacy/scripts/common/Reshelf.Discogs.psm1:236 › Invoke-DiscogsRequest

On a 429, the wait is the parsed `Retry-After` value (AS-CODE-DSC-020/021) if present; otherwise a dedicated, much longer schedule of `20`, `40`, `60` seconds is used (`$rateLimitBackoffSeconds = @(20, 40, 60)`), since a 429 means the per-minute window is exhausted, not a transient blip.

### AS-CODE-DSC-029 — 401 Unauthorized aborts immediately, no retry
Status: Draft | Source: legacy/scripts/common/Reshelf.Discogs.psm1:236 › Invoke-DiscogsRequest

A 401 response throws immediately, naming the path and suggesting the `DISCOGS_ACCESS_TOKEN` be checked, without consuming any further retry attempts.

### AS-CODE-DSC-030 — Exhausted retries throw with attempt count and last error
Status: Draft | Source: legacy/scripts/common/Reshelf.Discogs.psm1:236 › Invoke-DiscogsRequest

If the final attempt also fails, the function throws, naming the path, the number of attempts made, and the underlying exception message.

### AS-CODE-DSC-031 — Every attempt is counted toward the rate-limit window
Status: Draft | Source: legacy/scripts/common/Reshelf.Discogs.psm1:236 › Invoke-DiscogsRequest

A timestamp is recorded for both a successful and a failed HTTP attempt, so even failed attempts count against the 55-per-minute budget (AS-CODE-DSC-015).

### AS-CODE-DSC-032 — Successful response is written to the cache file
Status: Draft | Source: legacy/scripts/common/Reshelf.Discogs.psm1:236 › Invoke-DiscogsRequest

On success, the cache directory is created if missing, and the response body is serialized as pretty JSON (`ConvertTo-Json -Depth 20`, UTF-8) and written to the cache file, before being returned to the caller.

## Suspected defects

### AS-CODE-DEF-DSC-001
`legacy/scripts/common/Reshelf.Discogs.psm1:287,290,315-330` — the third element of both backoff arrays (`$backoffSeconds[2]` = 4s, `$rateLimitBackoffSeconds[2]` = 60s) is unreachable: with `$maxAttempts = 3`, the "attempt equals max attempts" check throws before attempt 3 ever reaches the backoff/sleep code, so only indices `0` and `1` of each array are ever used.

### AS-CODE-DEF-DSC-002
`legacy/scripts/common/Reshelf.Discogs.psm1:162` (`Wait-DiscogsRateLimit`) — the low-remaining signal is reset to `false` unconditionally, even when the throttle condition is true but the tracked timestamp list is empty (so `$shouldThrottle -and $script:DiscogsRequestTimestamps.Count -gt 0` is false and no sleep happens). A 429 or low-remaining signal received just before the timestamp window empties out (e.g. after a long idle gap) is silently discarded with zero delay enforced.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-10 | Phase 2 draft from code. |
