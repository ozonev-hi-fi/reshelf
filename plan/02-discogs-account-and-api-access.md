# Step 2 — Discogs Account and API Access

## Purpose / scope

Get API access to Discogs, the metadata source of truth (manifesto §5), before
any code that queries it gets written. This is a one-time, out-of-band manual
task plus a small reusable request wrapper.

## Inputs / outputs

- Input: none.
- Output: a Discogs Personal Access Token, and the design for
  `Tagger.Discogs.psm1`'s request/cache/rate-limit wrapper used by
  [06-edit-proposal-module.md](06-edit-proposal-module.md).

## Detailed design

### Account and token

1. Create a Discogs account (or use an existing one) at discogs.com.
2. Go to Settings → Developers → Generate new token.
3. Use a **Personal Access Token**, not a full OAuth app registration —
   OAuth's extra handshake buys nothing for a single-user local tool.
4. Store the token as `DISCOGS_ACCESS_TOKEN`, either:
   - a real environment variable, or
   - a `.env` file at the repo root (git-ignored — never write the token into
     any file inside the repo that isn't git-ignored, or into `TAGGER_HOME`
     plaintext config).

   See **Token resolution** below for how `Tagger.Discogs.psm1` finds it.

### Token resolution — `Get-DiscogsToken`

`Tagger.Discogs.psm1` exposes `Get-DiscogsToken`, checked by
`Invoke-DiscogsRequest` before every call:

1. Check `$env:DISCOGS_ACCESS_TOKEN` (a real environment variable) first.
2. If not set, look for a `.env` file at the repo root, read it line by line,
   and pull the value of a `DISCOGS_ACCESS_TOKEN=...` line (simple
   `KEY=VALUE` parsing — no need for a full dotenv library for one variable).
3. If neither source has it, throw a clear error naming both places checked,
   rather than silently proceeding with no auth and getting a confusing 401
   from Discogs.

This order means a real environment variable (e.g. set once in the user's
shell profile) always wins over `.env`, which is useful if the two ever
disagree, and lets the same code work whether the token came from the shell
or from the file.

**Why `.env` is safe here**: the repo's `.gitignore` excludes `.env`, so it
never reaches git history. On top of that, `.claude/settings.json` in this
repo should carry a `permissions.deny` rule blocking Claude Code's own tools
from reading `.env` directly — so the token stays out of both the git
history and any AI-assisted session's context. `Get-DiscogsToken` itself,
run by the user's own PowerShell process, still needs to read the file to
work — the deny rule restricts Claude Code, not the Tagger scripts
themselves.

### API basics

- Base URL: `https://api.discogs.com`
- Auth header: `Authorization: Discogs token=<value from Get-DiscogsToken>`
- Discogs requires a descriptive `User-Agent` header (generic/missing ones get
  rejected) — e.g. `TaggerPersonalOrganizer/0.1 (+local)`.
- Endpoints used:
  - `GET /database/search?type=release&q=...&artist=...&year=...` — candidate search.
  - `GET /releases/{id}` — full detail: tracklist, images, year, format, credited artists.

### Rate limiting

- Discogs enforces a per-minute limit for authenticated requests (check current
  published limit at build time; treat ~60/min as the working assumption).
- `Invoke-DiscogsRequest` (in `Tagger.Discogs.psm1`) enforces a conservative
  self-imposed ceiling (e.g. 55/min sliding window) and additionally reads back
  the `X-Discogs-Ratelimit-Remaining` response header to back off proactively
  before Discogs itself would reject the request.

### Caching

- On-disk cache: `$TAGGER_HOME\cache\discogs\<hash-of-normalized-query-or-release-id>.json`
- TTL: 30 days by default (release metadata rarely changes) — configurable in
  `settings.json`.
- Every lookup in [06](06-edit-proposal-module.md) checks the cache first. This
  both avoids unnecessary calls and makes re-running Edit Proposal on the same
  source fast and rate-limit-friendly (see [10](10-error-handling-and-edge-cases.md)).

### Matching confidence

- Build a search query from the recognized artist + release title (+ year, if
  known) from `recognition.json`.
- Score each candidate with a simple normalized string-similarity function
  (e.g. token-sort ratio on artist+title).
- Above a confidence threshold (to be tuned during the [Discogs spike](12-build-order-and-milestones.md),
  starting point 0.85): auto-select as `discogsMatch.status = "matched"`.
- Below threshold: attach the top 5 candidates with `status = "ambiguous"` —
  resolved by a human in [07-editing-ui-module.md](07-editing-ui-module.md), never guessed.

## Decisions & rationale

- **Personal Access Token over OAuth**: this is a single-user local tool, not a
  multi-user app distributed to others — OAuth's extra complexity has no payoff
  here.
- **Cache before rate-limit logic matters**: caching turns "re-run against the
  same 500 releases" from 500 API calls into near-zero, which matters more for
  a personal collection than clever backoff tuning.
- **Never auto-select below threshold**: a wrong Discogs match silently
  corrupts every tag/filename downstream (§5's whole point is Discogs as
  ground truth) — worth a manual click to avoid.

## Edge cases

- No candidates found at all → `discogsMatch.status = "not-found"`, routed to
  `needsReview` same as `ambiguous`.
- Discogs returns multiple pressings/editions of the same release (e.g.
  Japanese vs. German) — these show up as separate candidates; the UI's job in
  [07](07-editing-ui-module.md) is letting the user pick the right one, since
  cover art and even tracklist can differ between editions.
- API outage / network error → the request wrapper retries with backoff a
  small fixed number of times, then marks the release `needsReview` with a
  reason rather than failing the whole batch.

## Manual setup

1. Create/use a Discogs account.
2. Generate a Personal Access Token under Settings → Developers.
3. Store it as `DISCOGS_ACCESS_TOKEN`, either as a user environment variable
   or in a git-ignored `.env` file at the repo root (see **Token resolution**
   above).

## Definition of done

- `Invoke-DiscogsRequest -Path "/database/search" -Query @{...}` returns parsed
  JSON using the token from the environment.
- A second identical call within the TTL window hits the on-disk cache, not
  the network (verify by checking `X-Discogs-Ratelimit-Remaining` doesn't
  decrease).
- Exceeding the self-imposed per-minute ceiling causes the wrapper to sleep
  rather than send a request that would get rejected.
