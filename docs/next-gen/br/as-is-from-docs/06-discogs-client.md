# 06 — Discogs client (as-is, from docs and tests)

Status: Draft | Version: 0.1 | Last updated: 2026-10-05

## Scope

How the legacy app talks to the Discogs API: token lookup, the request (URL, headers, query string), errors and retry, rate limiting, and the on-disk response cache. Owned inputs: `legacy/tests/Reshelf.Discogs.Tests.ps1` (all Describe blocks), `legacy/tests/fixtures/discogs-responses/*`, and `legacy/plan/02-discogs-account-and-api-access.md` (sections up to "Caching", plus "Decisions & rationale", "Edge cases", "Manual setup", "Definition of done"). The "Matching confidence" section of the same plan file is in [07-proposal-matching.md](07-proposal-matching.md).

The tests replace the real HTTP call and the real wait (sleep) with mocks. So the tests show how many calls and waits happen, and how long each wait is. They do not show real network timing.

## Account and token

### AS-DOC-DSC-001 — The app uses a Discogs Personal Access Token
Status: Draft | Source: legacy/plan/02-discogs-account-and-api-access.md › Account and token; legacy/plan/02-discogs-account-and-api-access.md › Decisions & rationale; legacy/plan/02-discogs-account-and-api-access.md › Manual setup

The app authenticates with a Discogs Personal Access Token (PAT). It does not use an OAuth app registration. The user creates the token by hand, outside the app, on discogs.com under Settings → Developers → Generate new token.

Example: the user generates a token once and stores it as `DISCOGS_ACCESS_TOKEN`.

### AS-DOC-DSC-002 — Token lookup order: environment variable, then `.env`, then the encrypted settings token
Status: Draft | Source: legacy/tests/Reshelf.Discogs.Tests.ps1 › Get-DiscogsToken › returns the environment variable when set, without reading .env; › falls back to the .env file when the environment variable is unset; › falls through to the DPAPI-encrypted settings.json token when no env var and no .env file exist; › still prefers the environment variable over an encrypted settings.json token (regression); › still prefers the .env file over an encrypted settings.json token (regression); legacy/plan/02-discogs-account-and-api-access.md › Token resolution — `Get-DiscogsToken`

The app looks for the token in three places and uses the first one that has it:

1. a real environment variable;
2. a line in a `.env` file;
3. the DPAPI-encrypted token (`discogsTokenEncrypted`) in `settings.json` in the data home.

When the environment variable is set, the app does not read the `.env` file at all. The plan puts the `.env` file at the repo root. How the encrypted token gets into `settings.json`: see [03-settings-and-secrets.md](03-settings-and-secrets.md).

Examples:
- Environment variable `token-from-env-var`, no `.env` file → `token-from-env-var`.
- No environment variable, `.env` has `DISCOGS_ACCESS_TOKEN=token-from-file`, `settings.json` has an encrypted `token-from-settings` → `token-from-file`.
- No environment variable, no `.env` file, `settings.json` has an encrypted `token-from-settings` → `token-from-settings`.

### AS-DOC-DSC-003 — The variable name comes from `discogsTokenEnvVar`, default `DISCOGS_ACCESS_TOKEN`
Status: Draft | Source: legacy/tests/Reshelf.Discogs.Tests.ps1 › Get-DiscogsToken › reads a custom env var name from settings.json's discogsTokenEnvVar, not DISCOGS_ACCESS_TOKEN; › uses a custom discogsTokenEnvVar name for the .env file lookup too; › still defaults to DISCOGS_ACCESS_TOKEN when settings.json has no discogsTokenEnvVar key; legacy/plan/02-discogs-account-and-api-access.md › Token resolution — `Get-DiscogsToken`

The app reads the variable name from the `discogsTokenEnvVar` key in `settings.json`. It uses the same name for the environment variable and for the `.env` key. When the key is missing, or there is no `settings.json`, the name is `DISCOGS_ACCESS_TOKEN`. With a custom name, the app ignores a `DISCOGS_ACCESS_TOKEN` line in `.env`.

Examples:
- `discogsTokenEnvVar = MY_DISCOGS_TOKEN`, environment variable `MY_DISCOGS_TOKEN=token-from-custom-env-var` → `token-from-custom-env-var`.
- `discogsTokenEnvVar = MY_DISCOGS_TOKEN`, `.env` has `MY_DISCOGS_TOKEN=token-from-custom-file` and `DISCOGS_ACCESS_TOKEN=must-not-be-used` → `token-from-custom-file`.
- `settings.json` has only `targetRoot = D:\Music`, `.env` has `DISCOGS_ACCESS_TOKEN=token-from-default-name` → `token-from-default-name`.

### AS-DOC-DSC-004 — `.env` lines: comments, blank lines and the `export` prefix
Status: Draft | Source: legacy/tests/Reshelf.Discogs.Tests.ps1 › Get-DiscogsToken › falls back to the .env file when the environment variable is unset; › supports the export KEY=VALUE .env convention; legacy/plan/02-discogs-account-and-api-access.md › Token resolution — `Get-DiscogsToken`

The app reads the `.env` file line by line with simple `KEY=VALUE` parsing. It skips comment lines (starting with `#`) and blank lines. It also accepts a line in the form `export KEY=VALUE`.

Examples:
- Lines `# comment`, ``, `DISCOGS_ACCESS_TOKEN=token-from-file` → `token-from-file`.
- Line `export DISCOGS_ACCESS_TOKEN=token-from-export` → `token-from-export`.

### AS-DOC-DSC-005 — `.env` values: inline comments and quotes
Status: Draft | Source: legacy/tests/Reshelf.Discogs.Tests.ps1 › Get-DiscogsToken › strips an inline comment after an unquoted value; › keeps a hash character inside a quoted value

For an unquoted value, the app removes an inline comment (from ` #` to the end of the line) and the space before it. For a quoted value, the app removes the quotes and keeps every `#` inside them.

Examples:
- `DISCOGS_ACCESS_TOKEN=abc123 # personal token` → `abc123`.
- `DISCOGS_ACCESS_TOKEN="abc#123"` → `abc#123`.

### AS-DOC-DSC-006 — No token anywhere is an error that names the places checked
Status: Draft | Source: legacy/tests/Reshelf.Discogs.Tests.ps1 › Get-DiscogsToken › throws naming both sources when neither is set; legacy/plan/02-discogs-account-and-api-access.md › Token resolution — `Get-DiscogsToken`

When no source has the token, the app stops with an error. It does not send a request without authentication. The error message names the places it checked, including the variable name `DISCOGS_ACCESS_TOKEN`.

Example: no environment variable, no `.env` file, empty data home → error; the message contains `DISCOGS_ACCESS_TOKEN`.

## Request

### AS-DOC-DSC-007 — Base URL and endpoints
Status: Draft | Source: legacy/plan/02-discogs-account-and-api-access.md › API basics; legacy/tests/Reshelf.Discogs.Tests.ps1 › Invoke-DiscogsRequest › sends repeated query-string keys for an array-valued query parameter; legacy/tests/Reshelf.EditProposal.Tests.ps1 › Resolve-ReshelfDiscogsMatch (private)

All requests go to `https://api.discogs.com`. The plan lists two endpoints. The matching tests show more endpoints in use:

| Endpoint | Used for | Source |
|---|---|---|
| `GET /database/search` (`type=release`, `type=master`, `type=artist`) | candidate search | plan, tests |
| `GET /releases/{id}` | full release detail: tracklist, images, year, formats, artists | plan, tests |
| `GET /masters/{id}` | master detail (`main_release`, year, images) | tests |
| `GET /masters/{id}/versions` | the pressings under a master | tests |
| `GET /artists/{id}` | artist profile (`namevariations`) | tests |
| `GET /artists/{id}/releases` | the artist's own catalog | tests |

Example: a search for `format = CD, Album` goes to `https://api.discogs.com/database/search?format=CD&format=Album`.

### AS-DOC-DSC-008 — Authorization and User-Agent headers
Status: Draft | Source: legacy/plan/02-discogs-account-and-api-access.md › API basics

Every request carries `Authorization: Discogs token=<token>`, with the token from AS-DOC-DSC-002. Every request also carries a descriptive `User-Agent` header, because Discogs rejects generic or missing ones. No test checks the headers.

Example: `User-Agent: ReshelfPersonalOrganizer/0.1 (+local)`.

### AS-DOC-DSC-009 — Query-string keys are sorted
Status: Draft | Source: legacy/tests/Reshelf.Discogs.Tests.ps1 › Get-DiscogsQueryPair › sorts keys and passes single values through

The app builds the query string with the keys in alphabetical order. A single value goes through unchanged.

Example: query `{ type = release; q = Radiohead }` → `q=Radiohead&type=release`.

### AS-DOC-DSC-010 — An array value repeats its key
Status: Draft | Source: legacy/tests/Reshelf.Discogs.Tests.ps1 › Get-DiscogsQueryPair › repeats the key for each element of an array value instead of joining them into one string; legacy/tests/Reshelf.Discogs.Tests.ps1 › Invoke-DiscogsRequest › sends repeated query-string keys for an array-valued query parameter

For a query value that is an array, the app sends the key once for each element, in the array order. It does not join the elements into one string.

Example: `format = @('CD', 'Album')` → two pairs `format=CD`, `format=Album`; the URL is `https://api.discogs.com/database/search?format=CD&format=Album`.

### AS-DOC-DSC-011 — The request returns the parsed JSON body
Status: Draft | Source: legacy/tests/Reshelf.Discogs.Tests.ps1 › Invoke-DiscogsRequest › calls the HTTP wrapper on a cache miss and writes a cache file; legacy/plan/02-discogs-account-and-api-access.md › Definition of done; legacy/tests/fixtures/discogs-responses/search-response.json

The request returns the response body as a parsed JSON object, not as raw text. The caller reads its fields directly.

Example: `/database/search` with `q = Radiohead` and the fixture `search-response.json` → an object whose `results` has 2 items (release `265498`, CD, UK, and release `895372`, Vinyl, Germany, both `Radiohead - OK Computer`, 1997).

## Errors and retry

### AS-DOC-DSC-012 — HTTP 401 fails at once, without retry
Status: Draft | Source: legacy/tests/Reshelf.Discogs.Tests.ps1 › Invoke-DiscogsRequest › throws on a 401 without retrying

When Discogs answers 401 Unauthorized, the app stops with an error after the first attempt. It does not retry. The error message contains `401`. What the user does then: see [13-bandcamp-and-errors.md](13-bandcamp-and-errors.md).

Example: the HTTP call throws 401 → error matching `*401*`; the HTTP call ran 1 time.

### AS-DOC-DSC-013 — A transient failure is retried, up to 3 attempts in total
Status: Draft | Source: legacy/tests/Reshelf.Discogs.Tests.ps1 › Invoke-DiscogsRequest › retries a transient failure and returns the result once it succeeds; › throws after exhausting all retry attempts on a persistent transient failure; legacy/plan/02-discogs-account-and-api-access.md › Edge cases

When a request fails with a transient error (for example a timeout), the app waits and tries again. It makes at most 3 attempts in total. When an attempt succeeds, the app returns that result. When all 3 attempts fail, the app stops with an error that says `failed after 3 attempts`. The tests do not show the wait time for this case. How the release continues after the error: see AS-DOC-MAT-026 in [07-proposal-matching.md](07-proposal-matching.md).

Examples:
- First call throws `The operation timed out.`, second call succeeds → result with 2 `results`; 2 HTTP calls.
- Every call throws `The operation timed out.` → error matching `*failed after 3 attempts*`; 3 HTTP calls.

### AS-DOC-DSC-014 — HTTP 429 with `Retry-After` waits the given seconds
Status: Draft | Source: legacy/tests/Reshelf.Discogs.Tests.ps1 › Invoke-DiscogsRequest › retries a 429 and succeeds, honoring the Retry-After header instead of the generic backoff

When Discogs answers 429 Too Many Requests with a `Retry-After` header, the app waits the number of seconds in that header. Then it retries. It does not use its own backoff time in this case.

Example: first call 429 with `Retry-After: 5`, second call succeeds → 1 wait of 5 seconds; 2 HTTP calls; result with 2 `results`.

### AS-DOC-DSC-015 — HTTP 429 without `Retry-After` waits 20 s, then 40 s
Status: Draft | Source: legacy/tests/Reshelf.Discogs.Tests.ps1 › Invoke-DiscogsRequest › retries a 429 using the rate-limit backoff when no Retry-After header is present; › throws after exhausting all retry attempts on a persistent 429, waiting the rate-limit backoff each time

When a 429 answer has no `Retry-After` header, the app uses its rate-limit backoff: 20 seconds before the 2nd attempt, 40 seconds before the 3rd attempt. The limit of 3 attempts from AS-DOC-DSC-013 also applies to 429.

Examples:
- First call 429 (no header), second call succeeds → 1 wait of 20 seconds.
- Every call 429 (no header) → 3 HTTP calls, 1 wait of 20 seconds, 1 wait of 40 seconds, then error matching `*failed after 3 attempts*`.

## Rate limiting

### AS-DOC-DSC-016 — Self-imposed limit per minute, default 55
Status: Draft | Source: legacy/tests/Reshelf.Discogs.Tests.ps1 › Invoke-DiscogsRequest › sleeps once the self-imposed per-minute ceiling is reached; legacy/plan/02-discogs-account-and-api-access.md › Rate limiting; legacy/plan/02-discogs-account-and-api-access.md › Definition of done

The app counts its own requests in a sliding window of one minute. When the count reaches the limit, the app waits before it sends the next request. It does not send a request that Discogs would reject. The default limit is 55 per minute (setting `rateLimitPerMinute`, see [03-settings-and-secrets.md](03-settings-and-secrets.md)). The plan takes about 60 per minute as the Discogs limit for authenticated requests.

Example: limit 2. Requests `one` and `two` → no wait. Request `three` → 1 wait.

### AS-DOC-DSC-017 — A limit of 0 does not crash the request
Status: Draft | Source: legacy/tests/Reshelf.Discogs.Tests.ps1 › Invoke-DiscogsRequest › does not crash when RateLimitPerMinute is 0

With a rate limit of 0, the request still runs without an error. The test does not show what 0 means (no limit, or something else).

Example: `RateLimitPerMinute = 0`, query `q = Radiohead` → no error.

### AS-DOC-DSC-018 — A low `X-Discogs-Ratelimit-Remaining` slows down the next request
Status: Draft | Source: legacy/tests/Reshelf.Discogs.Tests.ps1 › Invoke-DiscogsRequest › proactively throttles the next call after a low X-Discogs-Ratelimit-Remaining response; legacy/plan/02-discogs-account-and-api-access.md › Rate limiting

The app reads the `X-Discogs-Ratelimit-Remaining` header of every response. When the value is low, the app waits before the next request. It does this before Discogs itself rejects a request. The test shows that `1` counts as low. It does not show the exact cut-off value or the wait time.

Example: first response has `X-Discogs-Ratelimit-Remaining: 1` → no wait for the first request; 1 wait before the second request.

## Response cache

### AS-DOC-DSC-019 — One cache file per distinct request, in the data home
Status: Draft | Source: legacy/tests/Reshelf.Discogs.Tests.ps1 › Invoke-DiscogsRequest › calls the HTTP wrapper on a cache miss and writes a cache file; › resolves the data home itself when -DataHome is not supplied; legacy/plan/02-discogs-account-and-api-access.md › Caching

After a successful HTTP call, the app writes the response to `<data home>\cache\discogs\<hash>.json`. The hash comes from the normalized query or the release ID. When the caller gives no data home, the app finds it itself (see [01-data-home-and-storage.md](01-data-home-and-storage.md)).

Examples:
- First call `/database/search` with `q = Radiohead` → 1 HTTP call; 1 `*.json` file in `cache\discogs`.
- No data home given, `RESHELF_HOME` points to a test folder → 1 `*.json` file in `$RESHELF_HOME\cache\discogs`.

### AS-DOC-DSC-020 — A fresh cache entry answers the request without HTTP
Status: Draft | Source: legacy/tests/Reshelf.Discogs.Tests.ps1 › Invoke-DiscogsRequest › reads from the cache on a second identical call instead of calling the HTTP wrapper again; legacy/plan/02-discogs-account-and-api-access.md › Caching; legacy/plan/02-discogs-account-and-api-access.md › Definition of done

Every lookup checks the cache first. When an identical request has a cache entry younger than the TTL, the app returns the cached response. It makes no HTTP call.

Example: two identical calls `/database/search`, `q = Radiohead` → 1 HTTP call in total; the second result still has 2 `results`.

### AS-DOC-DSC-021 — Cache TTL: 30 days by default, by file age
Status: Draft | Source: legacy/tests/Reshelf.Discogs.Tests.ps1 › Invoke-DiscogsRequest › bypasses a stale cache file and calls the HTTP wrapper again; legacy/plan/02-discogs-account-and-api-access.md › Caching

A cache entry is fresh while its file is younger than the TTL. The age is the time since the file's last write. The default TTL is 30 days (setting `cacheTtlDays`, see [03-settings-and-secrets.md](03-settings-and-secrets.md)). When the entry is older than the TTL, the app calls Discogs again.

Example: cached with TTL 30, file last written 2 days ago, next identical call with TTL 1 → a second HTTP call.

### AS-DOC-DSC-022 — Expired entries are cleaned once per data home per process
Status: Draft | Source: legacy/tests/Reshelf.Discogs.Tests.ps1 › Invoke-DiscogsRequest › physically deletes an expired cache entry from an earlier run on its first call for a data home; › prunes only once per data home per process, not on every call; legacy/plan/02-discogs-account-and-api-access.md › Caching

On the first Discogs request for a data home in a process, the app runs the cache cleanup (AS-DOC-DSC-023 to AS-DOC-DSC-026). Later requests in the same process, for the same data home, do not run it again.

Examples:
- `leftover-from-a-past-run.json`, last written 31 days ago; first request with TTL 30 → the file is deleted.
- Two requests (`q = one`, `q = two`) for the same data home → the cleanup runs 1 time.

### AS-DOC-DSC-023 — Cleanup deletes entries older than the TTL and returns the count
Status: Draft | Source: legacy/tests/Reshelf.Discogs.Tests.ps1 › Remove-DiscogsExpiredCache › leaves a fresh entry alone; › physically deletes an entry older than the TTL, not just ignores it; › deletes only the expired/corrupt entries, leaving fresh ones in place, and returns the correct count; legacy/plan/02-discogs-account-and-api-access.md › Caching

The cleanup physically deletes every cache file older than the TTL. It does not only skip it. Fresh files stay. The cleanup returns the number of deleted files.

Examples:
- `fresh.json` just written, TTL 30 → count 0; the file stays.
- `stale.json` last written 31 days ago, TTL 30 → count 1; the file is gone.
- `fresh.json` + `stale.json` (31 days) + corrupt `corrupt.json` → count 2; only `fresh.json` stays.

### AS-DOC-DSC-024 — Cleanup deletes a corrupt entry even when it is fresh
Status: Draft | Source: legacy/tests/Reshelf.Discogs.Tests.ps1 › Remove-DiscogsExpiredCache › deletes a corrupt entry (fails to parse as JSON) even if it is not yet expired; legacy/plan/02-discogs-account-and-api-access.md › Caching

A cache file that does not parse as JSON is deleted, whatever its age.

Example: `corrupt.json` with content `{not valid json`, just written, TTL 30 → count 1; the file is gone.

### AS-DOC-DSC-025 — Cleanup with no cache folder, or an empty one, does nothing
Status: Draft | Source: legacy/tests/Reshelf.Discogs.Tests.ps1 › Remove-DiscogsExpiredCache › is a no-op, not an error, when the cache folder does not exist yet; › is a no-op when the cache folder exists but is empty

When `cache\discogs` does not exist yet, or is empty, the cleanup does nothing and returns 0. A missing folder is not an error.

Example: a new, empty data home, TTL 30 → no error; count 0.

### AS-DOC-DSC-026 — A cache file that cannot be deleted gives a warning, not an error
Status: Draft | Source: legacy/tests/Reshelf.Discogs.Tests.ps1 › Remove-DiscogsExpiredCache › warns instead of throwing when a stale entry cannot be deleted (e.g. locked by another process)

When the cleanup cannot delete an expired file (for example, another process holds a lock on it), it writes a warning and continues. It does not stop with an error.

Example: `locked.json` last written 31 days ago and opened with no sharing by another handle, TTL 30 → no error.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-05 | Phase 1 draft. |
