# 06 — Discogs client (as-is, merged)

Status: Draft | Version: 0.1 | Last updated: 2026-10-11

## Scope

Area **DSC**. How the legacy app talks to the Discogs API: token lookup, the
request (URL, headers, query string), errors and retry, rate limiting, and
the on-disk response cache. Sources: `br/as-is-from-docs/06-discogs-client.md`
(`AS-DOC-DSC-001`–`026`, from `legacy/plan/02-discogs-account-and-api-access.md`
and `legacy/tests/Reshelf.Discogs.Tests.ps1`) and
`br/as-is-from-code/06-discogs-client.md` (`AS-CODE-DSC-001`–`032`, read only
from `legacy/scripts/common/Reshelf.Discogs.psm1`).

**ID numbering for this area:** `AS-DSC-001`–`026` mirror `AS-DOC-DSC-001`–
`026` one for one, elaborated with the matching `AS-CODE-DSC-*` implementation
detail where one exists (every one of the 32 `AS-CODE-DSC-*` facts folds into
one of these 26 — the code view is more granular but adds no entirely new
rule with zero doc-side counterpart). `AS-DOC-SET-044` (the same three-step
token lookup order, described from the README's settings table) is folded
into `AS-DSC-002` rather than kept as a SET item — see the scope note in
`03-settings-and-secrets.md`.

**Contradictions resolved while merging this area:** `AS-DOC-DEF-039` (plan
lists two token sources, tests/README/code have three) and `AS-DOC-DEF-041`
(plan's endpoint list is incomplete) — both already decided in phase 1's
favor of tests/code, re-confirmed against the code here. One new
wording-level contradiction found while merging: the `.env` inline-comment
rule (`AS-DSC-005`) is narrower in the phase-1 text than what the code
actually does. See `90-contradictions-resolution.md`.

**Suspected defects carried forward:** `AS-DOC-DEF-040` (does the "no token"
error name all three sources, including a custom env var name?) and
`AS-DOC-DEF-042` (what does a rate limit of `0` mean?) are now answered by
the code — folded into `AS-DSC-006`/`017` — but still carried forward
unresolved to phase 4 as `CF-DSC-004`/`CF-DSC-003`, per the phase 3 rule that
this phase only establishes facts, not disposition. Two more suspected
defects come from the code-only view with no doc counterpart: an unreachable
third backoff value (`CF-DSC-001`) and a rate-limit signal that can be
silently dropped (`CF-DSC-002`). See `91-suspected-defects-carryforward.md`.

## Account and token

### AS-DSC-001 — The app uses a Discogs Personal Access Token
Status: Draft | Source: AS-DOC-DSC-001

The app authenticates with a Discogs Personal Access Token (PAT). It does not
use an OAuth app registration. The user creates the token by hand, outside
the app, on discogs.com under Settings → Developers → Generate new token.

Example: the user generates a token once and stores it as
`DISCOGS_ACCESS_TOKEN`.

### AS-DSC-002 — Token lookup order: environment variable, then `.env`, then the encrypted settings token
Status: Draft | Source: AS-DOC-DSC-002; AS-DOC-SET-044; AS-CODE-DSC-002; AS-CODE-DSC-003; AS-CODE-DSC-004

The app looks for the token in three places and uses the first one that has
it:

1. a real environment variable;
2. a line in a `.env` file;
3. the DPAPI-encrypted token (`discogsTokenEncrypted`) in `settings.json` in
   the data home.

When the environment variable is set, the app does not read the `.env` file
at all, and never even looks at `settings.json` for the encrypted token (it
still reads `settings.json` once, up front, only to resolve the variable
*name* — AS-DSC-003). The `.env` file defaults to the repo root. How the
encrypted token gets into `settings.json`: see
[03-settings-and-secrets.md](03-settings-and-secrets.md).

Examples:
- Environment variable `token-from-env-var`, no `.env` file → `token-from-env-var`.
- No environment variable, `.env` has `DISCOGS_ACCESS_TOKEN=token-from-file`, `settings.json` has an encrypted `token-from-settings` → `token-from-file`.
- No environment variable, no `.env` file, `settings.json` has an encrypted `token-from-settings` → `token-from-settings`.

### AS-DSC-003 — The variable name comes from `discogsTokenEnvVar`, default `DISCOGS_ACCESS_TOKEN`
Status: Draft | Source: AS-DOC-DSC-003; AS-CODE-DSC-001

The app reads the variable name from the `discogsTokenEnvVar` key in
`settings.json`. It uses the same name for the environment variable and for
the `.env` key. When the key is missing, or there is no `settings.json`, the
name is `DISCOGS_ACCESS_TOKEN`. With a custom name, the app ignores a
`DISCOGS_ACCESS_TOKEN` line in `.env`.

Examples:
- `discogsTokenEnvVar = MY_DISCOGS_TOKEN`, environment variable `MY_DISCOGS_TOKEN=token-from-custom-env-var` → `token-from-custom-env-var`.
- `discogsTokenEnvVar = MY_DISCOGS_TOKEN`, `.env` has `MY_DISCOGS_TOKEN=token-from-custom-file` and `DISCOGS_ACCESS_TOKEN=must-not-be-used` → `token-from-custom-file`.
- `settings.json` has only `targetRoot = D:\Music`, `.env` has `DISCOGS_ACCESS_TOKEN=token-from-default-name` → `token-from-default-name`.

### AS-DSC-004 — `.env` lines: comments, blank lines and the `export` prefix
Status: Draft | Source: AS-DOC-DSC-004; AS-CODE-DSC-003

The app reads the `.env` file line by line. It skips comment lines (starting
with `#`, after trimming) and blank lines. A line matches
`[export ]<name> = <value>`, with optional whitespace around the `=`; the
name is the resolved variable name (AS-DSC-003), matched exactly, not just
any `KEY=VALUE` line.

Examples:
- Lines `# comment`, ``, `DISCOGS_ACCESS_TOKEN=token-from-file` → `token-from-file`.
- Line `export DISCOGS_ACCESS_TOKEN=token-from-export` → `token-from-export`.

### AS-DSC-005 — `.env` values: quotes are taken verbatim; an unquoted value is cut at the first `#`
Status: Draft | Source: AS-DOC-DSC-005; AS-CODE-DSC-003 — wording corrected, see `90-contradictions-resolution.md`

For a quoted value (`"..."` or `'...'`), the app takes everything between the
matching quote characters verbatim, keeping any `#` inside. For an unquoted
value, the app cuts the value at the **first** `#` character found anywhere
in it, then trims trailing whitespace from what's left — it does not require
a space before the `#`. (Phase 1's wording, "removes an inline comment from
` #` to the end of the line, and the space before it", was a precise
description of the one test case the sources had, but overstated the actual
rule — see the correction.)

Examples:
- `DISCOGS_ACCESS_TOKEN=abc123 # personal token` → `abc123`.
- `DISCOGS_ACCESS_TOKEN="abc#123"` → `abc#123`.
- Example (illustration, from re-reading the code, not a test): `DISCOGS_ACCESS_TOKEN=abc#123` (unquoted, no space before `#`) → `abc`, not `abc#123`.

### AS-DSC-006 — No token anywhere is an error that names all three places checked, using the resolved variable name
Status: Draft | Source: AS-DOC-DSC-006; AS-CODE-DSC-005 — answers `AS-DOC-DEF-040`, still carried forward as `CF-DSC-004`

When no source has the token, the app stops with an error before sending any
request. The message names the environment variable actually checked (the
resolved name from AS-DSC-003, so a custom `discogsTokenEnvVar` appears
correctly, not the literal string `DISCOGS_ACCESS_TOKEN`), the `.env` file
path, and the `settings.json` path, and suggests running
`Reshelf.ps1 settings set-token`.

Example: no environment variable, no `.env` file, empty data home → error
naming the checked variable, the `.env` path and the `settings.json` path.

## Request

### AS-DSC-007 — Base URL and endpoints
Status: Draft | Source: AS-DOC-DSC-007; AS-CODE-DSC-024 — resolves `AS-DOC-DEF-041`

All requests go to `https://api.discogs.com`, with the given path appended
as-is; this is generic in the client (it has no notion of which endpoints
exist). The matching module is the actual caller of these endpoints:

| Endpoint | Used for | Source |
|---|---|---|
| `GET /database/search` (`type=release`, `type=master`, `type=artist`) | candidate search | plan, tests |
| `GET /releases/{id}` | full release detail: tracklist, images, year, formats, artists | plan, tests |
| `GET /masters/{id}` | master detail (`main_release`, year, images) | tests |
| `GET /masters/{id}/versions` | the pressings under a master | tests |
| `GET /artists/{id}` | artist profile (`namevariations`) | tests |
| `GET /artists/{id}/releases` | the artist's own catalog | tests |

The plan's own endpoint list only named the first two; the fuller list above,
from the matching tests, is what the merged `AS-DOC-DEF-041` contradiction
resolved in phase 1 and re-confirms here.

Example: a search for `format = CD, Album` goes to
`https://api.discogs.com/database/search?format=CD&format=Album`.

### AS-DSC-008 — Authorization and User-Agent headers
Status: Draft | Source: AS-DOC-DSC-008; AS-CODE-DSC-025

Every request carries `Authorization: Discogs token=<token>`, with the token
from AS-DSC-002, and a fixed `User-Agent: ReshelfPersonalOrganizer/0.1
(+local)` — Discogs rejects generic or missing User-Agent values. No test
checks the headers directly; the code shows both are sent on every call.

### AS-DSC-009 — Query-string keys are sorted
Status: Draft | Source: AS-DOC-DSC-009; AS-CODE-DSC-006

The app builds the query string with the keys in alphabetical order. A
single value goes through unchanged. The same sorted-pairs logic is shared
by cache-key canonicalization (AS-DSC-019) and URL building, so both always
see keys in the same order.

Example: query `{ type = release; q = Radiohead }` → `q=Radiohead&type=release`.

### AS-DSC-010 — An array value repeats its key
Status: Draft | Source: AS-DOC-DSC-010; AS-CODE-DSC-006

For a query value that is an array (any enumerable, not a string), the app
sends the key once for each element, in the array order. It does not join
the elements into one string.

Example: `format = @('CD', 'Album')` → two pairs `format=CD`, `format=Album`;
the URL is `https://api.discogs.com/database/search?format=CD&format=Album`.

### AS-DSC-011 — Every request is a GET; the request returns the parsed JSON body
Status: Draft | Source: AS-DOC-DSC-011; AS-CODE-DSC-023; AS-CODE-DSC-024

Every Discogs HTTP call is a GET, made through `Invoke-RestMethod`, which
already parses the JSON response body into an object before the client sees
it — the caller reads its fields directly, never raw text. Response headers
are captured alongside the body (used for rate limiting, AS-DSC-018). The
query string is appended to the URL only when the query has at least one
entry, with each key and value percent-encoded.

Example: `/database/search` with `q = Radiohead` and the fixture
`search-response.json` → an object whose `results` has 2 items (release
`265498`, CD, UK, and release `895372`, Vinyl, Germany, both
`Radiohead - OK Computer`, 1997).

## Errors and retry

### AS-DSC-012 — HTTP 401 fails at once, without retry
Status: Draft | Source: AS-DOC-DSC-012; AS-CODE-DSC-029

When Discogs answers 401 Unauthorized, the app stops with an error after the
first attempt, naming the path and suggesting `DISCOGS_ACCESS_TOKEN` be
checked. It does not retry and does not consume a retry attempt. What the
user does then: see [13-bandcamp-and-errors.md](13-bandcamp-and-errors.md).

Example: the HTTP call throws 401 → error matching `*401*`; the HTTP call
ran 1 time.

### AS-DSC-013 — A transient failure is retried, up to 3 attempts in total, with a 1s/2s backoff
Status: Draft | Source: AS-DOC-DSC-013; AS-CODE-DSC-026; AS-CODE-DSC-027; AS-CODE-DSC-030; AS-CODE-DSC-031

When a request fails with a non-401, non-429 error (for example a timeout),
the app waits and tries again. It makes at most 3 attempts in total, waiting
1 second before the 2nd attempt and 2 seconds before the 3rd (a third
configured value, 4 seconds, exists in code but is never reached — see
`CF-DSC-001`). Every attempt, including a failed one, counts toward the
rate-limit window (AS-DSC-016). When an attempt succeeds, the app returns
that result. When all 3 attempts fail, the app stops with an error that
names the path, the attempt count and the underlying error message. How the
release continues after the error: see AS-DOC-MAT-026 in
[07-proposal-matching.md](07-proposal-matching.md) (not yet merged).

Examples:
- First call throws `The operation timed out.`, second call succeeds → result with 2 `results`; 2 HTTP calls.
- Every call throws `The operation timed out.` → error matching `*failed after 3 attempts*`; 3 HTTP calls; waits of 1s then 2s.

### AS-DSC-014 — HTTP 429 with `Retry-After` waits the given seconds
Status: Draft | Source: AS-DOC-DSC-014; AS-CODE-DSC-020; AS-CODE-DSC-021; AS-CODE-DSC-022; AS-CODE-DSC-028

When Discogs answers 429 Too Many Requests with a `Retry-After` header, the
app waits that long, then retries, instead of using its own backoff
(AS-DSC-015). The header value is read as an integer number of seconds when
it parses as one (clamped to a minimum of 0); otherwise it is read as an
(assumed-UTC) date/time and converted to "seconds from now, rounded up,
clamped to 0". If the header is absent, or its value matches neither form,
there is no special wait and AS-DSC-015 applies instead.

Example: first call 429 with `Retry-After: 5`, second call succeeds → 1 wait
of 5 seconds; 2 HTTP calls; result with 2 `results`.

### AS-DSC-015 — HTTP 429 without `Retry-After` waits 20 s, then 40 s
Status: Draft | Source: AS-DOC-DSC-015; AS-CODE-DSC-028

When a 429 answer has no usable `Retry-After` value (AS-DSC-014), the app
uses its rate-limit backoff: 20 seconds before the 2nd attempt, 40 seconds
before the 3rd. The limit of 3 attempts from AS-DSC-013 also applies to 429.
A third configured value, 60 seconds, exists in code but is never reached
for the same reason as AS-DSC-013's 4-second value — see `CF-DSC-001`.

Examples:
- First call 429 (no header), second call succeeds → 1 wait of 20 seconds.
- Every call 429 (no header) → 3 HTTP calls, 1 wait of 20 seconds, 1 wait of 40 seconds, then error matching `*failed after 3 attempts*`.

## Rate limiting

### AS-DSC-016 — Self-imposed limit per minute, default 55
Status: Draft | Source: AS-DOC-DSC-016; AS-CODE-DSC-015

The app counts its own requests (successful or failed, AS-DSC-013) in a
sliding window of 60 seconds, dropping timestamps older than that on every
call. When the count reaches the limit, the app waits before it sends the
next request, so it never sends a request Discogs would reject outright. The
default limit is 55 per minute (setting `rateLimitPerMinute`, see
[03-settings-and-secrets.md](03-settings-and-secrets.md)). The plan takes
about 60 per minute as the Discogs limit for authenticated requests.

Example: limit 2. Requests `one` and `two` → no wait. Request `three` → 1
wait.

### AS-DSC-017 — A limit of 0 forces a wait before every request after the first
Status: Draft | Source: AS-DOC-DSC-017; AS-CODE-DSC-016 — answers `AS-DOC-DEF-042`, still carried forward as `CF-DSC-003`

With a rate limit of 0, the request still runs without an error — but the
mechanism now explains what 0 actually means: the wait triggers when the
window is at or over the ceiling **and** at least one timestamp is tracked.
The very first request in a process has no tracked timestamp yet, so it
proceeds immediately; every request after that has at least one timestamp in
the window, and `0 >= 0` is always true, so it always sleeps first (for
"60 seconds minus the age of the oldest tracked timestamp" — effectively up
to 60 seconds, every time). This is a candidate surprising behavior, not
"no limit" as a user might expect from 0 — carried forward undecided as
`CF-DSC-003`.

Example: `RateLimitPerMinute = 0`, query `q = Radiohead` → no error (first
request only, no wait).

### AS-DSC-018 — A low `X-Discogs-Ratelimit-Remaining` header, or a 429, slows the very next request only
Status: Draft | Source: AS-DOC-DSC-018; AS-CODE-DSC-017; AS-CODE-DSC-018; AS-CODE-DSC-019

The app reads the `X-Discogs-Ratelimit-Remaining` header of every successful
response; a value `<= 2` sets a module-level "low remaining" flag (header
parsing is best-effort — any parse failure is logged and ignored, never
fails the request). A 429 response also sets the same flag. The flag forces
a throttle wait on the very next request regardless of the per-minute count,
then is unconditionally cleared — so one low-remaining signal only delays
one subsequent request, not every one after it.

Example: first response has `X-Discogs-Ratelimit-Remaining: 1` → no wait for
the first request; 1 wait before the second request.

## Response cache

### AS-DSC-019 — One cache file per distinct request, named by a SHA-256 hash, in the data home
Status: Draft | Source: AS-DOC-DSC-019; AS-CODE-DSC-007; AS-CODE-DSC-008; AS-CODE-DSC-032

After a successful HTTP call, the app writes the response to
`<data home>\cache\discogs\<hash>.json`. The hash is the lowercase hex
SHA-256 digest of the canonical string `"{Path}?key1=value1&key2=value2…"`,
built from the sorted query pairs (AS-DSC-009), so the same request (same
path, same query, regardless of the order the caller supplied the query in)
always hashes to the same file. The body is serialized as pretty JSON
(`ConvertTo-Json -Depth 20`), UTF-8, before being returned to the caller.
When the caller gives no data home, the app finds it itself (see
[01-data-and-storage.md](01-data-and-storage.md)).

Examples:
- First call `/database/search` with `q = Radiohead` → 1 HTTP call; 1 `*.json` file in `cache\discogs`.
- No data home given, `RESHELF_HOME` points to a test folder → 1 `*.json` file in `$RESHELF_HOME\cache\discogs`.

### AS-DSC-020 — A fresh cache entry answers the request without HTTP — and without even looking up the token
Status: Draft | Source: AS-DOC-DSC-020; AS-CODE-DSC-014

Every lookup checks the cache first, before the Discogs token is resolved at
all. When an identical request has a cache entry younger than the TTL, the
app returns the cached response, parsed from JSON, with no HTTP call and no
token lookup — so a fully cached request needs no token to succeed.

Example: two identical calls `/database/search`, `q = Radiohead` → 1 HTTP
call in total; the second result still has 2 `results`.

### AS-DSC-021 — Cache TTL: 30 days by default, by file age
Status: Draft | Source: AS-DOC-DSC-021; AS-CODE-DSC-009; AS-CODE-DSC-010

A cache entry is fresh while its file is younger than the TTL: `(Now -
file.LastWriteTime).TotalDays < CacheTtlDays`. The default TTL is 30 days
(setting `cacheTtlDays`, see [03-settings-and-secrets.md](03-settings-and-secrets.md);
the same 30-day number is also this module's own hardcoded parameter
default). When the entry is older than the TTL, the app calls Discogs again.

Example: cached with TTL 30, file last written 2 days ago, next identical
call with TTL 1 → a second HTTP call.

### AS-DSC-022 — Expired entries are cleaned once per data home per process
Status: Draft | Source: AS-DOC-DSC-022; AS-CODE-DSC-013

On the first Discogs request for a data home in a process, the app runs the
cache cleanup (AS-DSC-023–026). The app tracks which data homes it has
already pruned, in memory, for the life of the process, and skips the
cleanup on later requests for the same data home.

Examples:
- `leftover-from-a-past-run.json`, last written 31 days ago; first request with TTL 30 → the file is deleted.
- Two requests (`q = one`, `q = two`) for the same data home → the cleanup runs 1 time.

### AS-DSC-023 — Cleanup deletes entries older than the TTL and returns the count
Status: Draft | Source: AS-DOC-DSC-023; AS-CODE-DSC-010

The cleanup physically deletes every cache file older than the TTL — it does
not only skip it. Fresh files stay. The cleanup returns the number of
deleted files.

Examples:
- `fresh.json` just written, TTL 30 → count 0; the file stays.
- `stale.json` last written 31 days ago, TTL 30 → count 1; the file is gone.
- `fresh.json` + `stale.json` (31 days) + corrupt `corrupt.json` → count 2; only `fresh.json` stays.

### AS-DSC-024 — Cleanup deletes a corrupt entry even when it is fresh
Status: Draft | Source: AS-DOC-DSC-024; AS-CODE-DSC-011

A cache file that does not parse as JSON is deleted, whatever its age — a
non-expired file is also read and parsed during cleanup, and a parse failure
(e.g. truncated by a crash mid-write) is treated the same as expiry.

Example: `corrupt.json` with content `{not valid json`, just written, TTL 30
→ count 1; the file is gone.

### AS-DSC-025 — Cleanup with no cache folder, or an empty one, does nothing
Status: Draft | Source: AS-DOC-DSC-025

When `cache\discogs` does not exist yet, or is empty, the cleanup does
nothing and returns 0. A missing folder is not an error.

Example: a new, empty data home, TTL 30 → no error; count 0.

### AS-DSC-026 — A cache file that cannot be deleted gives a warning, not an error
Status: Draft | Source: AS-DOC-DSC-026; AS-CODE-DSC-012

When the cleanup cannot delete an expired or corrupt file (for example,
another process holds a lock on it), it writes a warning and continues —
cache cleanup never fails a real run over one entry it couldn't delete.

Example: `locked.json` last written 31 days ago and opened with no sharing
by another handle, TTL 30 → no error.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-11 | Phase 3: merged 26 `AS-DOC-DSC-*` requirements, 32 `AS-CODE-DSC-*` facts, and `AS-DOC-SET-044` (deferred from SET) into `AS-DSC-001`–`026`. Two phase-1 contradictions (`AS-DOC-DEF-039`, `041`) re-verified against the code and confirmed. One new contradiction found while merging: the `.env` inline-comment rule is a plain "first `#`" cut, not specifically "a space then `#`" as phase 1's wording implied (`AS-DSC-005`). Two phase-1 suspected defects (`AS-DOC-DEF-040`, `042`) now have their mechanism fully explained by the code but are still carried forward undecided (`CF-DSC-004`, `CF-DSC-003`). Two code-only suspected defects carried forward (`CF-DSC-001`, `002`). |
