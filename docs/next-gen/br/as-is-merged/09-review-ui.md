# 09 — Review UI (merged)

Status: Draft | Version: 0.3 | Last updated: 2026-10-13

## Scope

This file reconciles [`as-is-from-docs/09-review-ui.md`](../as-is-from-docs/09-review-ui.md)
(84 `AS-DOC-REV-*` requirements, from the Playwright suite, the UI-server
Pester tests, plan 07 and the README) and
[`as-is-from-code/09-review-ui.md`](../as-is-from-code/09-review-ui.md)
(148 `AS-CODE-REV-*` requirements, from `legacy/scripts/common/Reshelf.UiServer.psm1`,
`legacy/scripts/Start-ReshelfUiServer.ps1`, `legacy/ui/app.js`, `legacy/ui/index.html`
and `legacy/ui/styles.css`, read cold) into one behavior record for the local
UI server and the review page: static file serving, the HTTP API, session
loading, the release list and badges, the before/after table and release
fields, the track table, per-track Artist/Compilation, companion files, the
cover gallery, the Discogs candidate picker, approve/reject/save, the lossy
tracker view, and the page's visibility/CSS states.

**Numbering note.** As with MAT, PRP and REC, this file is organized by
topic (server static files, API routing, each API action group, server
bootstrap, then the client bootstrap/list/detail/track/companion/cover/
lossy-view pieces) rather than carrying old numbers forward, since the code
side is far more granular — nearly twice the item count of the docs/tests
view — and names many mechanics (the routing table's per-path checks, the
JSON serialization quirks, the CSS-only interactions) the docs/tests view
only shows through example or doesn't mention at all. Every `AS-REV-NNN`
cites every `AS-DOC-REV-*`/`AS-CODE-REV-*` id it reconciles;
[92-coverage.md](92-coverage.md) maps every source id to its `AS-REV-NNN`.

How `propose` fills the fields this page edits: see
[08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md). The `ui
start` command itself and apply: see [12-cli.md](12-cli.md) and
[10-apply.md](10-apply.md). The lossy ledger's own lifecycle: see
[11-lossy-tracking.md](11-lossy-tracking.md).

## UI server: static files, MIME types, path safety

### AS-REV-001 — The root path and an empty request path both serve index.html
Status: Draft | Source: AS-DOC-REV-003; AS-CODE-REV-001

A request for `/` or for an empty path, after stripping the leading `/`,
resolves to `index.html` in the UI root — not a directory listing or a
failure.

### AS-REV-002 — Other paths map to a file under the UI folder; a missing file is a routing miss, not an error
Status: Draft | Source: AS-DOC-REV-004; AS-CODE-REV-002; AS-CODE-REV-003

The request path, leading slash trimmed, is joined onto the UI root to
compute the candidate file path, including nested subfolders. If the
candidate does not exist as a file, resolution returns nothing; the caller
turns that into an HTTP 404 with body `Not found: {path}`.

### AS-REV-003 — Path traversal outside the UI folder is refused, case-insensitively
Status: Draft | Source: AS-DOC-REV-005; AS-CODE-REV-004; AS-CODE-REV-005

After resolving the candidate path, the server checks it still starts with
the UI root plus a separator; if not, it is treated as not-found. The
containment check uses ordinal, case-insensitive comparison, so a drive
letter or segment case difference on Windows doesn't cause a false
rejection.

### AS-REV-004 — Content type comes from a fixed, case-insensitive extension table; anything else is octet-stream
Status: Draft | Source: AS-DOC-REV-006; AS-CODE-REV-006; AS-CODE-REV-007

`.html`→text/html, `.js`→text/javascript, `.css`→text/css, `.json`→
application/json, `.png`→image/png, `.jpg`/`.jpeg`→image/jpeg, `.svg`→
image/svg+xml, `.ico`→image/x-icon; any other extension (or none) gets
`application/octet-stream`. The extension is lower-cased before lookup.

## HTTP API: routing

### AS-REV-005 — The API route table
Status: Draft | Source: AS-DOC-REV-007; AS-CODE-REV-009; AS-CODE-REV-010; AS-CODE-REV-011; AS-CODE-REV-014; AS-CODE-REV-015; AS-CODE-REV-016; AS-CODE-REV-017

| Method | Route | Action |
|---|---|---|
| GET | `/api/current-session` | `CurrentSession` |
| GET | `/api/sessions` | `ListSessions` |
| GET | `/api/sessions/{id}/proposal` | `GetProposal` |
| PUT | `/api/sessions/{id}/proposal` | `SaveProposal` |
| GET | `/api/sessions/{id}/local-file?path=…` | `LocalFile` |
| POST | `/api/sessions/{id}/manual-cover?filename=…` | `SaveManualCover` |
| POST | `/api/sessions/{id}/proposal/releases/{stableKey}/discogs-selection` | Discogs re-pick |
| GET | `/api/naming-templates` | `NamingTemplates` |
| GET | `/api/lossy` | `ListLossy` |
| PUT | `/api/lossy/{stableKey}` | `UpdateLossy` |
| DELETE | `/api/lossy/{stableKey}` | `DeleteLossy` |

Everything else is a static file request.

### AS-REV-006 — A session id in any session-scoped route must match yyyy-MM-dd-NNNN; a wrong one is a 400 before any disk access
Status: Draft | Source: AS-DOC-REV-008; AS-CODE-REV-008

The regex `^\d{4}-\d{2}-\d{2}-\d{4}$` is checked first, so a crafted id can't
reach the sessions folder at all.

### AS-REV-007 — A stable key in a route must be 16 lowercase hex characters; a wrong one matches no route at all
Status: Draft | Source: AS-DOC-REV-009; AS-CODE-REV-013; AS-CODE-REV-018

On the discogs-selection and lossy routes, the `{stableKey}` segment must
match `[0-9a-f]{16}`; a value that doesn't simply fails to match the route
pattern and falls through to static-file handling — unlike a bad session id,
which gets an explicit 400 (`AS-REV-006`). Carried forward as a suspected
defect (two kinds of bad input, two different answers): see
`91-suspected-defects-carryforward.md` (`CF-REV-007`).

### AS-REV-008 — An unsupported method on a known path, or any other unmatched request, falls through to static-file handling — there is no 405
Status: Draft | Source: AS-DOC-REV-010; AS-CODE-REV-012; AS-CODE-REV-018 (second half)

`DELETE /api/sessions/{id}/proposal`, `GET` on the manual-cover or
discogs-selection paths, and similar mismatches all return no action from
the routing function; the request is then served (or 404'd) exactly as a
static file request would be. Carried forward: see
`91-suspected-defects-carryforward.md` (`CF-REV-008`), cross-referenced with
`AS-CODE-DEF-REV-007` (a plain 404 instead of a clearer 405/400).

## HTTP API: sessions and proposal

### AS-REV-009 — The sessions list reduces each session to id/root/stage/updated/hasProposal, computed live
Status: Draft | Source: AS-DOC-REV-011; AS-CODE-REV-044

`hasProposal` is true only when that session's `proposal.json` exists on
disk right now — not from any stored flag. With no sessions, the list is
empty.

### AS-REV-010 — The current session is the most recently updated session that has a proposal; none found gives found:false, not an error
Status: Draft | Source: AS-DOC-REV-012; AS-DOC-REV-023; AS-CODE-REV-019; AS-CODE-REV-045

Sessions are already sorted newest-first by `updatedAtUtc`; the current
session is the first one in that order whose `hasProposal` is true — a
more-recently-touched session without a proposal is skipped, not shown as
current. When none qualifies, `GET /api/current-session` answers HTTP 200
with `{ found: false, message: "No session has a proposal yet - run
recognize and propose first." }`, not a 4xx/5xx.

### AS-REV-011 — CurrentSession re-serializes the embedded proposal; GetProposal returns the on-disk bytes untouched
Status: Draft | Source: AS-DOC-REV-013; AS-CODE-REV-020; AS-CODE-REV-021; AS-CODE-REV-069

`GET /api/sessions/{id}/proposal` writes the raw file content straight to
the response, preserving exact formatting and number precision; it answers
404 with the underlying error if the session has no proposal file.
`GET /api/current-session`, instead, parses the same file's content
(`ConvertFrom-Json`) and re-serializes it (`ConvertTo-Json -Depth 20`)
inside a wrapper object before sending it — the same file can come back
differently formatted depending on which endpoint is called. Carried
forward: see `91-suspected-defects-carryforward.md` (`CF-REV-002`, citing
`AS-CODE-DEF-REV-002`).

### AS-REV-012 — Save only checks the body is syntactically valid JSON; an invalid body leaves the file untouched
Status: Draft | Source: AS-DOC-REV-014; AS-CODE-REV-022

No schema or shape validation runs — `ConvertFrom-Json` is called purely to
confirm the body parses. Carried forward: see
`91-suspected-defects-carryforward.md` (`CF-REV-003`, citing
`AS-DOC-DEF-072`: a structurally-broken `proposal.json` can be saved this
way).

### AS-REV-013 — Save keeps exactly one rolling backup, writes UTF-8 with no trailing newline, and returns a UTC save timestamp
Status: Draft | Source: AS-DOC-REV-015; AS-CODE-REV-023; AS-CODE-REV-024; AS-CODE-REV-025

Before overwriting `proposal.json`, if it exists it is copied to
`proposal.backup.json` in the same folder, replacing any earlier backup —
only the single most recent prior version is ever kept. The new content is
written with `Set-Content -Encoding utf8 -NoNewline`. On success, `PUT
/api/sessions/{id}/proposal` returns `{ savedAtUtc: <ISO 8601 UTC> }` with
status 200.

## HTTP API: Discogs re-pick

### AS-REV-014 — A re-pick requires releaseId in the body and a stableKey matching a real release, else 400/404
Status: Draft | Source: AS-CODE-REV-026; AS-CODE-REV-027

A missing `releaseId` is a 400 ("Request body must include 'releaseId'.")
without touching the proposal; a `stableKey` matching no release across any
artist in the session's proposal is a 404.

### AS-REV-015 — The re-pick's fallback search artist is the album artist, never one track's own artist
Status: Draft | Source: AS-CODE-REV-028

The name used to search Discogs for the newly selected edition is the first
track's `tags.albumArtist` when the release has tracks, otherwise
`proposed.artistFolderName` — deliberately the album artist, not a track's
own performer, so a compilation (e.g. "Various") searches correctly.

### AS-REV-016 — A re-pick really re-fetches and recomputes the release from Discogs, not just records the choice — resolves AS-DOC-DEF-069
Status: Draft | Source: AS-DOC-REV-067 (partial); AS-CODE-REV-029; AS-CODE-REV-030; AS-CODE-REV-031; AS-CODE-REV-032; resolves `AS-DOC-DEF-069` (see `90-contradictions-resolution.md`)

The server calls the shared Discogs-selection recompute logic and replaces
`target.tracks`, `target.proposed`, `target.discogsMatch`, `target.coverArt`,
`target.lossyLossless` and `target.targetAction` on the one matched release;
sibling releases are passed in for context only. New notes from the
recompute are appended to `humanReview.notes`, joined by `"; "`, rather than
replacing them; a forced `requiresReview` sets `humanReview.required = true`
but nothing in this handler ever clears it back to `false`.

### AS-REV-017 — A re-pick saves the whole proposal to disk at once, before the user ever clicks Save, and returns only the one updated release
Status: Draft | Source: AS-CODE-REV-032

The save goes through the same path (and rolling backup, `AS-REV-013`) as a
manual Save; the handler then responds 200 with just the updated release
object.

## HTTP API: local-file and manual-cover

### AS-REV-018 — The local-file route requires a path query parameter
Status: Draft | Source: AS-CODE-REV-033

A missing `path` value is a 400 ("Missing 'path' query parameter.").

### AS-REV-019 — Any file physically under a session's manual-covers folder is always servable, bypassing the proposal.json allow-list
Status: Draft | Source: AS-DOC-REV-016 (partial); AS-CODE-REV-046; AS-CODE-REV-047

Manual covers live under `{DataHome}/sessions/{sessionId}/manual-covers`. A
just-uploaded cover candidate only exists in the browser's in-memory
proposal until Save, so it wouldn't yet be found in the on-disk
`proposal.json` — this path exists specifically so it's still servable.

### AS-REV-020 — Outside manual-covers, only a local path already listed as a cover candidate in the session's own on-disk proposal.json is servable
Status: Draft | Source: AS-DOC-REV-016 (partial); AS-DOC-REV-017; AS-CODE-REV-048; AS-CODE-REV-049

Every `coverArt.candidates[].url` across the session's releases whose value
doesn't start with `http://`/`https://` is collected into a case-insensitive
allow-list (`HashSet<string>`, `OrdinalIgnoreCase`); this is the route's
only access control. A requested path outside the set throws "...is not a
known local cover file..." (`AS-REV-022`).

### AS-REV-021 — The allow-list check is re-verified live against the file system, to guard a delete-after-check race
Status: Draft | Source: AS-CODE-REV-050

Even after passing the allow-list or manual-covers check, the function
re-checks the file still exists before reading bytes, and throws a distinct
"no longer exists" error if it was deleted in between.

### AS-REV-022 — Every local-file failure, including a genuinely missing file, is reported as HTTP 403
Status: Draft | Source: AS-DOC-REV-017 (partial); AS-CODE-REV-034; AS-CODE-REV-035

On success the response body is the file's raw bytes, with content type
from the requested path's own extension (`AS-REV-004`). Any exception —
not-allowed path, missing file, read error — is reported as 403. Carried
forward: see `91-suspected-defects-carryforward.md` (`CF-REV-001`, citing
`AS-CODE-DEF-REV-003`: a missing file is conflated with an access-control
failure).

### AS-REV-023 — A manual-cover upload requires a filename query parameter, and reads the body as raw bytes, never as text
Status: Draft | Source: AS-CODE-REV-036; AS-CODE-REV-037

A missing `filename` is a 400. Reading as binary (not via the request's text
encoding) avoids corrupting the uploaded image data.

### AS-REV-024 — A manual-cover upload must be non-empty, JPG/PNG only, at most 20 MB, for a known session
Status: Draft | Source: AS-DOC-REV-019; AS-CODE-REV-051; AS-CODE-REV-052; AS-CODE-REV-053; AS-CODE-REV-054

| Case | Error text contains |
|---|---|
| Zero bytes | `empty` |
| Extension not `.jpg`/`.jpeg`/`.png` (case-insensitive) | `Unsupported image type` |
| Over 20 MB | `20 MB limit` |
| Session does not exist | `not found` |

`Get-ReshelfSession` is called purely to confirm the session id is real —
this endpoint never reads or writes `proposal.json`. Carried forward: see
`91-suspected-defects-carryforward.md` (`CF-REV-004`, citing
`AS-CODE-DEF-REV-001`: the 20 MB limit is hardcoded independently a second
time at the HTTP body-read layer, `AS-REV-041`, which always fires first in
practice).

### AS-REV-025 — A successful upload is saved at once under the session's manual-covers folder (created on first use), named by a new GUID, never the client's own file name
Status: Draft | Source: AS-DOC-REV-018; AS-CODE-REV-055; AS-CODE-REV-056

Only the original extension carries over from the client-supplied name,
which also avoids any path-injection risk from that name.

### AS-REV-026 — The server decodes the saved upload to get real pixel dimensions; a non-image upload is deleted again and the request fails
Status: Draft | Source: AS-DOC-REV-020; AS-CODE-REV-057; AS-CODE-REV-058

If decoding throws, the just-written file is deleted
(`-ErrorAction SilentlyContinue`) and the request fails with "Uploaded file
is not a readable image: ...". This image-dimension helper throws on
failure rather than returning a silent 1×1 placeholder — unlike the
similarly named helper on the naming/tags side (see `AS-PRP-062`) —
specifically so the caller here can delete the bad file.

### AS-REV-027 — On success, the manual-cover endpoint returns url, width and height
Status: Draft | Source: AS-DOC-REV-018 (partial); AS-CODE-REV-038

Any failure (empty, too large, wrong type, unreadable) is reported as 400
with the thrown message.

## HTTP API: naming templates and lossy ledger

### AS-REV-028 — Naming templates are read live from settings on every request, not cached at startup
Status: Draft | Source: AS-DOC-REV-021; AS-CODE-REV-039

`GET /api/naming-templates` returns `{ releaseFolder, trackFile,
trackNumberPadWidth }` from `Get-ReshelfSettings`, re-read fresh each call.

### AS-REV-029 — The lossy-ledger list has no server-side filtering or paging
Status: Draft | Source: AS-CODE-REV-040

`GET /api/lossy` always returns the entire ledger; status filtering
(`AS-REV-114`) is a browser-only concern.

### AS-REV-030 — Updating a ledger entry requires a status field; a stable key with no entry afterward is a 404
Status: Draft | Source: AS-CODE-REV-041; AS-CODE-REV-042

A `$null` `status` is a 400 ("Request body must include 'status'.");
`notes` is optional and forwarded only when present. After the update call,
the handler looks the entry back up by `stableKey`; not found there is a
404.

### AS-REV-031 — Deleting a ledger entry maps every failure to 404, not only "not found"
Status: Draft | Source: AS-CODE-REV-043

Success is 200 `{ removed: true }`. Carried forward: see
`91-suspected-defects-carryforward.md` (`CF-REV-005`, citing
`AS-CODE-DEF-REV-004`).

## Server: HTTP bootstrap and request loop

### AS-REV-032 — Default port 4173, default UI root the ui/ folder next to scripts; startup fails if the UI root doesn't resolve
Status: Draft | Source: AS-CODE-REV-059; AS-CODE-REV-060; AS-CODE-REV-062; AS-DOC-CLI-014 (deferred here from CLI — see `12-cli.md`)

A non-resolving `-UiRoot` throws "UI root '...' does not exist. Nothing to
serve." before any listener opens.

### AS-REV-033 — -NoBrowser suppresses the auto-launched browser; otherwise the OS default browser opens on startup
Status: Draft | Source: AS-CODE-REV-061; AS-CODE-REV-065; AS-DOC-CLI-015 (deferred here from CLI — see `12-cli.md`)

`-NoBrowser` exists so the Playwright suite, which drives its own browser
instance, doesn't also get an unwanted real browser window on every
automated run.

### AS-REV-034 — DataHome is read once at startup and fixed for the server's life
Status: Draft | Source: AS-CODE-REV-063

A settings change afterward needs a server restart to take effect.

### AS-REV-035 — The listener binds localhost only, on the configured port
Status: Draft | Source: AS-DOC-REV-001; AS-CODE-REV-064

The server is local and single-user with no login or access control of its
own; the only registered `HttpListener` prefix is `http://localhost:{Port}/`
— not `0.0.0.0` or a LAN address — so it's reachable only from the same
machine. The browser only talks to it with `fetch()`; it never asks for
folder/file permission itself.

### AS-REV-036 — The request loop handles one request at a time, polling with a 200 ms timeout so Ctrl+C can still interrupt it
Status: Draft | Source: AS-DOC-REV-002; AS-CODE-REV-066

Instead of a blocking `GetContext()` call, the loop awaits
`GetContextAsync()` inside a `while` loop with a 200 ms timeout per
iteration — a plain blocking call can no longer be force-aborted by Ctrl+C
on PowerShell 7/.NET (`Thread.Abort` was removed) — giving the loop a safe
point to react roughly 5 times a second. Parallel requests queue behind each
other; the Playwright suite runs with `workers: 1` for this reason.

### AS-REV-037 — A single failed request is caught and answered with HTTP 500, without stopping the server; static requests accept any HTTP method
Status: Draft | Source: AS-CODE-REV-067; AS-CODE-REV-073

Any unhandled exception while handling one request is logged as a warning
and answered with a plain-text 500 body; the listener keeps running for
every other request. Once a path doesn't match any API route, the static
file response is served (or 404'd) regardless of method — there is no
GET-only restriction.

### AS-REV-038 — JSON array/object responses are built with -InputObject, not the pipeline, so a 0- or 1-element array isn't unwrapped
Status: Draft | Source: AS-CODE-REV-068

Piping an array to `ConvertTo-Json` unrolls it into separate pipeline items
and would serialize a bare object/`[]` instead of a real JSON array for a 0-
or 1-entry collection (e.g. `/api/lossy`); `-InputObject` avoids that.

### AS-REV-039 — Text request bodies decode with the request's own content encoding; binary upload bodies are read as raw bytes
Status: Draft | Source: AS-CODE-REV-070; AS-CODE-REV-071

Proposal saves, Discogs selections and lossy updates use a `StreamReader`
against `Request.ContentEncoding`; the manual-cover upload path reads
straight into a byte array, since UTF-8 text decoding would corrupt binary
image data.

### AS-REV-040 — A binary upload's size is checked twice: the declared Content-Length first, then the actual bytes received
Status: Draft | Source: AS-CODE-REV-072

The function rejects early if `Request.ContentLength64` exceeds the max
(default 20 MB, `AS-REV-024`), then separately re-checks the actual buffered
stream length after copying it — a client's declared header isn't trusted
alone.

## Client: page bootstrap and session loading

### AS-REV-041 — On load, the page wires controls and starts the templates fetch and the current-session fetch without waiting on each other
Status: Draft | Source: AS-CODE-REV-074

`loadNamingTemplates()` is not awaited before `loadCurrentSession()` starts
— the two effectively run concurrently.

### AS-REV-042 — The page loads the current session with no click, no file/folder picker
Status: Draft | Source: AS-DOC-REV-022; AS-CODE-REV-077

Status text reads `Reviewing: {sourceRoot} ({localeDateString}, {stage})` —
it shows the source root and stage, never the session id.

### AS-REV-043 — With no session having a proposal yet, the page shows a plain status message, not an error
Status: Draft | Source: AS-DOC-REV-023; cross-referenced with `AS-REV-010`

A fresh install, or a session where only `recognize` has run, shows the
`{found: false, message}` text as a plain status.

### AS-REV-044 — A reload re-fetches the current session from disk; there is no other polling, auto-refresh, or keyboard shortcut anywhere
Status: Draft | Source: AS-DOC-REV-024; AS-CODE-REV-075; AS-CODE-REV-076

Session, proposal and lossy-ledger data are (re)fetched only on page load,
Retry, switching the session-history dropdown, switching to the Lossy
tracker view, or right after an action that explicitly re-fetches (Discogs
selection, manual cover upload, lossy row edits) — never on a timer. No
`keydown`/`keyup`/`keypress` listener exists anywhere; every interaction
needs a mouse/pointer action.

### AS-REV-045 — A separate header label always shows the raw session id, kept apart from the friendlier status text
Status: Draft | Source: AS-DOC-REV-025; AS-CODE-REV-078

`#session-id-label` shows `Session {sessionId}` (or is cleared) — so a
person can reference an exact session id to someone else, independent of
the status line (`AS-REV-042`).

### AS-REV-046 — The "Past sessions" dropdown is hidden unless at least two sessions exist; each option is labeled by source root, date and stage, never the raw id
Status: Draft | Source: AS-DOC-REV-026; AS-CODE-REV-081; AS-CODE-REV-082; resolves `AS-DOC-DEF-080` (see `90-contradictions-resolution.md`)

The list is newest first; the loaded session is the selected option. A
session with no proposal yet gets a `"(no proposal yet)"` suffix on its
label.

### AS-REV-047 — Switching sessions with unsaved changes asks for confirmation; cancelling reverts the dropdown
Status: Draft | Source: AS-DOC-REV-027; AS-CODE-REV-079

`window.confirm('You have unsaved changes. Discard them and switch
session?')` fires only if `isDirty()`; cancelling restores the dropdown's
value to the current session id.

### AS-REV-048 — Picking a history session with no proposal shows a status message and clears the list, with no further request for that session
Status: Draft | Source: AS-CODE-REV-080

`state.proposal` is set to `null`, the message
`"{sourceRoot} has no proposal.json yet."` is shown, and both the detail and
unrecognized panels hide.

### AS-REV-049 — A broken session-history refresh, after the main session already loaded, degrades silently to a console warning
Status: Draft | Source: AS-CODE-REV-083

The user sees no error state, since the primary session view already
succeeded — only `"Could not load session history:"` is logged.

## Client: release list, filters and badges

### AS-REV-050 — The release list is grouped by artist, each a separate sidebar section in first-seen order
Status: Draft | Source: AS-DOC-REV-028; AS-CODE-REV-085

A click on a row opens that release in the detail panel.

### AS-REV-051 — Release badge priority: rejected, then ambiguous-unresolved, then needsReview-unresolved, else ready — resolves AS-DOC-DEF-076
Status: Draft | Source: AS-DOC-REV-029; AS-DOC-REV-030; AS-CODE-REV-087; resolves `AS-DOC-DEF-076` (see `90-contradictions-resolution.md`)

First match wins: `'rejected'` if `humanReview.rejected`; else `'ambiguous'`
if the Discogs status is `ambiguous` and not yet `humanReview.resolved`;
else `'needsReview'` if (`needsReview` or `humanReview.required`) and not
yet resolved; else `'ready'`. A release `propose` didn't flag is already
`'ready'` without any user action. Unrecognized folders have their own badge
(`AS-REV-060`).

### AS-REV-052 — Release row label is "{year} {album}", trimmed
Status: Draft | Source: AS-CODE-REV-088

A missing year collapses to just the album name.

### AS-REV-053 — The two review filters combine with OR, because a release has exactly one status at a time
Status: Draft | Source: AS-DOC-REV-031; AS-CODE-REV-084

An AND-style combination would always show zero rows — the code comments
this as a deliberate design choice, not a bug.

### AS-REV-054 — "Needs review only" filters on the computed badge, not the raw needsReview flag, so an ambiguous-and-flagged release is hidden by it
Status: Draft | Source: no direct id (see `91-suspected-defects-carryforward.md`, `CF-REV-006`, citing `AS-DOC-DEF-070`)

Carried forward as a suspected defect: a release with `needsReview: true`
but badge `ambiguous` is hidden by "Needs review only" even though its
label suggests it would show.

### AS-REV-055 — Unrecognized folders get their own "Unrecognized (N)" section, only when neither status filter is active
Status: Draft | Source: AS-CODE-REV-086

Ticking either filter hides the unrecognized section entirely, since those
entries have no review/ambiguous status of their own.

### AS-REV-056 — An unsaved release row gets a dot marker and an "unsaved" class
Status: Draft | Source: AS-DOC-REV-071 (partial); AS-CODE-REV-089

Any row whose `stableKey` is in `state.dirtyReleaseKeys` gets the class,
which draws a small colored bullet after the label.

### AS-REV-057 — Selecting a release and selecting an unrecognized entry are mutually exclusive
Status: Draft | Source: AS-CODE-REV-090

Picking one clears the other's selection and hides its panel.

### AS-REV-058 — After an edit, only that one release row's badge/label is patched in place, not the whole sidebar
Status: Draft | Source: AS-CODE-REV-091

A full `renderList()` rebuild per keystroke is deliberately avoided for
performance on sessions with hundreds of releases; a row hidden by an active
filter isn't patched until the next full render.

## Client: unrecognized-folder detail

### AS-REV-059 — Unrecognized folders appear in the list with the badge "unrecognized"
Status: Draft | Source: AS-DOC-REV-076

Each entry of the proposal's `unrecognized[]` is one row, named by the
folder name.

### AS-REV-060 — Selecting an unrecognized folder shows its path, reason and child files as plain text
Status: Draft | Source: AS-DOC-REV-077; AS-CODE-REV-092

The panel title is the entry's final path segment; each child file name
becomes one list item.

## Client: before/after table and release fields

### AS-REV-061 — The before/after table is read-only; row 1 is the folder rename, each next row one track
Status: Draft | Source: AS-DOC-REV-032; AS-CODE-REV-095

Row 1 shows `release.sourceFolderPath` → `{artistFolderName}\{releaseFolderName}`,
always first, before any track row.

### AS-REV-062 — A multi-disc release groups the before/after table by disc, preferring the source's own disc-folder name over a generated "Disc N" label
Status: Draft | Source: AS-CODE-REV-093; AS-CODE-REV-094

Tracks are grouped (in first-seen order) under `track.discFolder` when the
source had a named subfolder, falling back to `Disc {proposedDiscNumber}`
otherwise; a single-disc release has no disc column.

### AS-REV-063 — The release fields: Album Artist, Compilation, Album, Year, Artist Folder Name, Release Folder Name; the Album Artist field prefers the first track's own tag over the proposed folder name
Status: Draft | Source: AS-DOC-REV-033; AS-CODE-REV-096

`#field-artist` is populated from `tracks[0]?.tags.albumArtist`, falling
back to `proposed.artistFolderName` only when there are no tracks. An edit
of Album is saved to `proposed.album`.

### AS-REV-064 — Editing Album Artist, Album or Year recomputes both folder names live and updates the folder row; no new propose run is needed
Status: Draft | Source: AS-DOC-REV-034; AS-CODE-REV-099; AS-CODE-REV-101 (partial); AS-CODE-REV-102

The client preview mirrors the server's `{year}`/`{album}` naming template,
fetched once at startup (`AS-REV-028`), substituting and trimming the same
way; it's a live preview only, not a guarantee the CLI's real `propose`
output matches exactly.

### AS-REV-065 — Editing Album Artist sets every track's Album Artist tag; a track's own Artist follows only if it still equalled the old Album Artist
Status: Draft | Source: AS-DOC-REV-047; AS-CODE-REV-097

A per-track Artist already customized (e.g. a compilation's individual
performer) is left untouched.

### AS-REV-066 — The live preview sanitizes the same character set and reserved device names as the server
Status: Draft | Source: AS-DOC-REV-035; AS-CODE-REV-103

`toSafeFileName` replaces control characters and `<>:"/\|?*` with `_`,
strips trailing dots/spaces, and appends `_` for a name exactly matching a
reserved Windows device name (CON, PRN, AUX, NUL, COM1-9, LPT1-9),
case-insensitively. A nearby code comment incorrectly claims this function
skips the reserved-name step; see `91-suspected-defects-carryforward.md`
(`CF-REV-009`, citing `AS-CODE-DEF-REV-005`) for the stale-comment note.

### AS-REV-067 — A hand-typed folder name updates the After cell, but is silently overwritten by the next Artist/Album/Year edit
Status: Draft | Source: AS-DOC-REV-036; AS-DOC-REV-037; AS-CODE-REV-101

The page does not remember a folder name was typed by hand; any subsequent
edit to Artist, Album or Year recomputes and replaces both folder-name
fields from scratch.

### AS-REV-068 — Editing Year accepts only a parsed integer or null; a non-numeric tail is silently dropped, not rejected
Status: Draft | Source: AS-CODE-REV-100

An empty Year sets `proposed.year` (and every track's `tags.year`) to
`null`; a non-empty value is parsed with `parseInt(value, 10)`, so e.g.
"1994abc" becomes `1994`.

### AS-REV-069 — Toggling Compilation sets isCompilation on the release and on every track's tags at once
Status: Draft | Source: AS-DOC-REV-048; AS-CODE-REV-098

### AS-REV-070 — The page lets the user save an empty Year; only apply blocks the run, with no warning shown on the page
Status: Draft | Source: AS-DOC-REV-038; carried forward: see `91-suspected-defects-carryforward.md` (`CF-REV-010`, citing `AS-DOC-DEF-081`)

An empty Year fails validation in `apply` and stops the entire run, not only
that release (see `10-apply.md`, not yet merged). The value `1900` is a
placeholder meaning "year not fixed" (`AS-PRP-021`); it alone doesn't block
apply.

### AS-REV-071 — Save does not apply the reserved-device-name suffix to a hand-typed folder name; the body is written exactly as sent — resolves AS-DOC-DEF-073
Status: Draft | Source: resolves `AS-DOC-DEF-073` (see `90-contradictions-resolution.md`), cross-referenced with `AS-REV-012` (`AS-CODE-REV-022`)

Save's only check is JSON validity (`AS-REV-012`); nothing in the save path
re-applies folder-name safety rules to whatever the client sent.

## Client: track table and file-name derivation

### AS-REV-072 — The track table has Disc, Track (numbers), Artist and Title per track
Status: Draft | Source: AS-DOC-REV-039

### AS-REV-073 — A Title edit renames the proposed file but keeps the "NN " number prefix and current extension
Status: Draft | Source: AS-DOC-REV-040; AS-CODE-REV-109

The template substitutes `{trackNumber}` and `{title}`, preserving whatever
extension the current proposed name has (or `.{format}` if none yet).

### AS-REV-074 — A Disc or Track edit recomputes every track's proposed file name in the release; the file number follows Track, so a missing track keeps its gap
Status: Draft | Source: AS-DOC-REV-041; AS-CODE-REV-107 (partial)

Save writes both the file names and the Track tags; the result survives
reload.

### AS-REV-075 — On a multi-disc release, file numbers continue after the highest Track of earlier discs — a documented limitation, not silently corrected, when that disc's last track is missing on the source
Status: Draft | Source: AS-DOC-REV-042; AS-CODE-REV-107; carried forward: see `91-suspected-defects-carryforward.md` (`CF-REV-011`, citing `AS-DOC-DEF-074`)

The page has no access to Discogs' own per-disc track counts, so it uses
each disc's highest Track number as that disc's size; if the true last
track of an earlier disc is absent, later discs' file numbers come out one
too low and need a manual fix.

### AS-REV-076 — File-number pad width grows to fit the largest computed number, never shrinks below the configured width
Status: Draft | Source: AS-CODE-REV-108

E.g. a configured pad width of 2 stays 2-digit up to 99, then widens to
3-digit for every track once a number reaches 100+.

### AS-REV-077 — A session saved before the numbering rule keeps its old file names until the user types a Track value again in that release
Status: Draft | Source: AS-DOC-REV-043; carried forward: see `91-suspected-defects-carryforward.md` (`CF-REV-012`, citing `AS-DOC-DEF-075`)

Until then, the page shows names that don't follow the current rule.

### AS-REV-078 — Disc/Track inputs silently ignore a non-integer or sub-1 value instead of writing it through
Status: Draft | Source: AS-CODE-REV-104

Includes an empty/incomplete value, which `parseInt`s to `NaN` — the edit is
dropped entirely (no state change, no re-render), since the schema requires
these as non-nullable integers ≥ 1.

### AS-REV-079 — An Artist edit changes only the tag; the file-name recompute is skipped entirely for this field
Status: Draft | Source: AS-DOC-REV-044; AS-CODE-REV-106

Artist isn't part of the track file-name template, so editing it doesn't
trigger `deriveTrackFileNames`/`renderBeforeAfterTable` the way every other
track-field edit does.

## Client: per-track Artist and Compilation flag

### AS-REV-080 — Each track shows its own Artist; the release shows Album Artist and the Compilation flag; on a compilation a track's Artist can differ
Status: Draft | Source: AS-DOC-REV-045

How `propose` fills a track's Artist: see `AS-PRP-053`–`059`.

### AS-REV-081 — Editing one track's Artist changes only that track, never the Album Artist or other tracks
Status: Draft | Source: AS-DOC-REV-046

### AS-REV-082 — An empty track Artist is replaced by Album Artist when the field loses focus, not while typing
Status: Draft | Source: AS-DOC-REV-049; AS-CODE-REV-105

The schema requires a non-empty Artist (minLength 1); this blur-fallback
avoids the value only failing later, during Apply.

## Client: companion (other) files

### AS-REV-083 — The Other-files table lists one row per companion (Include, Before, Kind, target name) and one greyed-out row per ignored file naming its reason
Status: Draft | Source: AS-DOC-REV-050; AS-CODE-REV-114

An ignored file (playlist, unused `.cue`) can't be included and shows
`Not copied: <reason>`.

### AS-REV-084 — Only a loose companion has an editable target name; a nested companion shows its relative path as plain text, include/exclude only
Status: Draft | Source: AS-DOC-REV-051; AS-CODE-REV-110

### AS-REV-085 — A loose companion missing a proposed name is auto-backfilled with its original name as a side effect of rendering the table, and this backfill itself marks the release unsaved
Status: Draft | Source: AS-DOC-REV-052; AS-CODE-REV-111

A pure render function has a persistent state side effect here, for an
older `proposal.json` saved before a rename suggestion existed for that
companion.

### AS-REV-086 — Editing a loose companion name keeps focus while typing and marks the release unsaved
Status: Draft | Source: AS-DOC-REV-053

### AS-REV-087 — Inline warnings on a loose companion name, first match wins: empty, then doesn't start with a (Unicode) letter, then matches a track file name, then matches another included companion — none block Save
Status: Draft | Source: AS-DOC-REV-054; AS-CODE-REV-112; AS-CODE-REV-113

| Problem | Warning text |
|---|---|
| Empty name | `Name is required.` |
| Does not start with a letter | `Must start with a letter.` |
| Same name as a track file | `Same name as a track file.` |
| Same name as another included companion | `Same name as another included file.` |

The start-with-letter check uses `/^\p{L}/u`, so an accented or non-Latin
letter passes. The track-name warning can't appear through normal edits: a
track name always starts with its number, and a companion name starting
with a digit already gets `Must start with a letter.` first — the two
sources describe the same priority, the docs view via this note rather than
an explicit order.

### AS-REV-088 — Unticking Include hides that row's warning; ticking it again brings the same warning back
Status: Draft | Source: AS-DOC-REV-055

### AS-REV-089 — A release with no companion and no ignored files shows "No other files" instead of the table
Status: Draft | Source: AS-DOC-REV-056; AS-CODE-REV-115

### AS-REV-090 — What the user saves (Include and name choices) is exactly what apply copies
Status: Draft | Source: AS-DOC-REV-057

How apply copies companions: see `10-apply.md` (not yet merged).

## Client: cover gallery

### AS-REV-091 — Every cover candidate is listed with a radio button; the chosenCandidateUrl candidate starts selected; picking another selects it, unselects the old one, and marks the release unsaved
Status: Draft | Source: AS-DOC-REV-058; AS-CODE-REV-116

Both the cover gallery and the Discogs candidate picker (`AS-REV-101`) share
one radio-list implementation, which listens for the native `click` event
(not `change`) so re-clicking an already-selected option still re-runs the
selection handler.

### AS-REV-092 — Each candidate shows its pixel size, and, if it would shrink to fit targetMaxDimension, the resulting embedded size; otherwise "(embedded as is)"
Status: Draft | Source: AS-DOC-REV-059; AS-CODE-REV-118

The scale-down-only, aspect-preserving computation mirrors the server's
embed-time resize; the max-dimension value also shows as a tooltip.

### AS-REV-093 — A local candidate's image loads through the local-file route; an http(s) candidate loads directly
Status: Draft | Source: AS-DOC-REV-060; AS-CODE-REV-117

### AS-REV-094 — A thumbnail click opens a full-size native-dialog lightbox without changing the selection; closable by its own Close control, an outside click, or Escape
Status: Draft | Source: AS-DOC-REV-061; AS-CODE-REV-119

The lightbox is a native `<dialog>` opened with `showModal()` — Escape-to-close
is native browser behavior, not custom code.

### AS-REV-095 — "Add cover from file…" uploads a JPG/PNG at once; on success it's appended as a new, auto-selected candidate, the others staying pickable
Status: Draft | Source: AS-DOC-REV-062; AS-CODE-REV-121; AS-CODE-REV-123

The hidden `#manual-cover-input` (`accept="image/png,image/jpeg"`) is
triggered by a styled `<label>` button reading "Add cover from file…"; the
new candidate is labeled "manual upload".

### AS-REV-096 — The uploaded file reaches disk immediately on choosing it, before Save; only the gallery's candidate reference follows the normal unsaved-until-Save path
Status: Draft | Source: AS-DOC-REV-063; AS-CODE-REV-122; carried forward: see `91-suspected-defects-carryforward.md` (`CF-REV-013`, citing `AS-DOC-DEF-071`)

Reloading without Save removes the candidate from the gallery, but the
already-uploaded file stays in `manual-covers` with nothing shown to remove
it later — since Apply reads cover art from a disk path, the file needs to
be durable before Save is even clicked.

### AS-REV-097 — A failed upload shows "Upload failed: {message}" and adds nothing to the gallery
Status: Draft | Source: AS-DOC-REV-064; AS-CODE-REV-124

Success text is `"Uploaded - click Save to keep this selection."`.

### AS-REV-098 — The upload control is shown even when the gallery has no candidates at all
Status: Draft | Source: AS-DOC-REV-065

### AS-REV-099 — Choosing the same file again later is always possible: the file input is cleared immediately after reading it
Status: Draft | Source: AS-CODE-REV-125

`e.target.value = ''` runs right after grabbing the file, so the browser's
"value unchanged" suppression of `change` doesn't block re-picking the same
file name.

## Client: Discogs candidate picker, approve/reject and save

### AS-REV-100 — The Discogs edition picker appears only while the match status is ambiguous, one radio option per candidate with title/year/format/score
Status: Draft | Source: AS-DOC-REV-066; AS-CODE-REV-120

Example label: `"{title} ({year}, {format}) - score {score}"`.

### AS-REV-101 — Picking a candidate posts the selection at once and replaces the whole in-memory release with the server's recomputed result — resolves AS-DOC-DEF-069
Status: Draft | Source: AS-DOC-REV-067; AS-CODE-REV-126; resolves `AS-DOC-DEF-069` (see `90-contradictions-resolution.md` and `AS-REV-016`)

`Object.assign(release, updated)` overwrites every field the server
returned; both the detail panel and sidebar re-render. Status text cycles
through "Loading tracklist for this edition...", then "Updated." or
"Failed to load edition: {message}"; the picker hides once the merged
status is no longer ambiguous.

### AS-REV-102 — The Notes field is pre-filled with the review reasons
Status: Draft | Source: AS-DOC-REV-068

The field assigns `release.humanReview.notes` with no null-safety fallback,
unlike the equivalent lossy-notes field elsewhere in the same file; carried
forward: see `91-suspected-defects-carryforward.md` (`CF-REV-014`, citing
`AS-CODE-DEF-REV-006`).

### AS-REV-103 — Approve and Reject are mutually exclusive checkboxes; the row badge updates at once
Status: Draft | Source: AS-DOC-REV-069; AS-CODE-REV-127

Checking Approve sets `humanReview.resolved = true` and clears Reject (both
in state and in the checkbox UI); checking Reject sets
`humanReview.rejected = true` and also forces `resolved = true`, clearing
Approve.

### AS-REV-104 — Approve marks the release reviewed and ready for apply; Reject marks it reviewed and excluded from apply
Status: Draft | Source: AS-DOC-REV-070

Reject means "never apply this" (e.g. a duplicate pressing). Apply rules:
see `10-apply.md` (not yet merged).

## Client: unsaved changes and Save

### AS-REV-105 — An edit marks the release row unsaved and is counted in two synced counters, top and bottom of the panel
Status: Draft | Source: AS-DOC-REV-071; AS-CODE-REV-130

Text is `"{n} unsaved change"` (singular for 1) or `"{n} unsaved changes"`;
empty with no dirty releases.

### AS-REV-106 — Save always sends the entire in-memory proposal, regardless of how many releases are dirty; there is no auto-save
Status: Draft | Source: AS-DOC-REV-072; AS-CODE-REV-128

`PUT /api/sessions/{id}/proposal` is called with the whole
`JSON.stringify(state.proposal, null, 2)` every time Save is clicked.

### AS-REV-107 — A successful save clears every dirty marker and re-renders the list; a failed save leaves dirty state untouched
Status: Draft | Source: AS-CODE-REV-129

Success: `"Saved at {localeTimeString}"`. Failure:
`"Save failed: {message}"`, with unsaved-count badges staying as they were.

### AS-REV-108 — Leaving the page with unsaved changes triggers the browser's own prompt; without changes there is none
Status: Draft | Source: AS-DOC-REV-073; AS-CODE-REV-131

A `beforeunload` listener calls `e.preventDefault()` and sets
`e.returnValue = ''` only if `isDirty()`.

## Server stopped

### AS-REV-109 — A failed Save shows "Save failed", not a silent failure
Status: Draft | Source: AS-DOC-REV-074

### AS-REV-110 — A failed session load shows an error and a Retry button; the unsaved-changes confirm still comes first
Status: Draft | Source: AS-DOC-REV-075

`#retry-btn` appears; switching sessions while the current one has unsaved
changes still asks for confirmation (`AS-REV-047`) before the error path
runs.

## Lossy tracker view

### AS-REV-111 — A header button switches between the release view and the lossy tracker; switching to Lossy always re-fetches the ledger
Status: Draft | Source: AS-DOC-REV-078; AS-CODE-REV-132

The release view (`#main-layout`) shows on load; `#view-btn-lossy` shows
`#lossy-view` and hides it; `#view-btn-releases` switches back. The lossy
ledger's own rules: see [11-lossy-tracking.md](11-lossy-tracking.md).

### AS-REV-112 — The release-view toggle uses an inline style, not the hidden attribute, because of a CSS specificity conflict
Status: Draft | Source: AS-CODE-REV-133

`#main-layout` has its own by-ID `display: flex` rule (needed for its
two-pane layout), which would outrank `[hidden]`'s default `display: none`
— so the toggle sets `style.display` directly for this one element, while
`#lossy-view` (no such conflict) uses the plain `hidden` attribute.

### AS-REV-113 — The status filter narrows the already-loaded ledger client-side only, with no new request
Status: Draft | Source: AS-DOC-REV-079; AS-CODE-REV-134

Options: "All" (empty value), `pending-upgrade`, `upgraded`, `ignored`.

### AS-REV-114 — A status or Notes change in a row saves at once (status on change, notes on blur) with no separate Save step
Status: Draft | Source: AS-DOC-REV-080; AS-DOC-REV-081; AS-CODE-REV-135

`PUT /api/lossy/{stableKey}` merges the one changed field over the entry's
current status/notes; success shows `"Saved at {time}"`, failure
`"Save failed: {message}"`.

### AS-REV-115 — Delete asks for confirmation naming the artist and album, warns it can't be undone, then removes the row from disk and from the in-memory list
Status: Draft | Source: AS-DOC-REV-082; AS-CODE-REV-136

Prompt: `Permanently remove the lossy-tracking entry for "{artist} -
{album}"? This cannot be undone.`

### AS-REV-116 — Export CSV and Export JSON build a file in the browser from the rows currently shown (after the filter), with no extra request
Status: Draft | Source: AS-DOC-REV-083; AS-CODE-REV-137; AS-CODE-REV-139

CSV columns: `stableKey, artist, album, year, format, status, targetPath,
firstDetectedUtc, lastCheckedUtc, upgradedUtc, notes` (`upgradedUtc` is
exported even though it isn't a visible table column). Before the table has
loaded, the CSV has only the header.

### AS-REV-117 — CSV values are quoted only when they contain a comma, quote or newline, with embedded quotes doubled; the export file name embeds a sortable, colon-free UTC timestamp
Status: Draft | Source: AS-CODE-REV-138; AS-CODE-REV-140

Example: notes `Cracked, re-ripped "v2"` → `"Cracked, re-ripped
""v2"""`. Download is a synthetic `<a download>` click against a `Blob`
object URL, revoked right after.

### AS-REV-118 — Naming templates are fetched once; a failed fetch keeps hardcoded client defaults silently
Status: Draft | Source: AS-CODE-REV-141

Defaults: `releaseFolder: '{year} {album}'`, `trackFile: '{trackNumber}
{title}'`, `trackNumberPadWidth: 2`. Failure is only logged to the console —
the folder-name live preview (`AS-REV-064`) may simply drift out of sync
with a non-default server template.

## Markup and CSS

### AS-REV-119 — Six page regions start hidden in the markup and are only unhidden by script, in response to state
Status: Draft | Source: AS-CODE-REV-142

`#retry-btn`, `#session-history`, `#unrecognized-panel`, `#detail-panel`,
`#discogs-candidates` and `#lossy-view` all carry `hidden` in the markup.

### AS-REV-120 — There are no responsive/mobile rules anywhere in the stylesheet; the two-pane layout is fixed-desktop only
Status: Draft | Source: AS-CODE-REV-143

No `@media` queries exist; `#main-layout { height: calc(100vh - 100px) }`
with a fixed 320px sidebar is the only layout.

### AS-REV-121 — The release sidebar and the detail/unrecognized pane each scroll independently
Status: Draft | Source: AS-CODE-REV-144

Each has its own `overflow-y: auto` inside the fixed-height flex row.

### AS-REV-122 — The selected cover candidate's highlight is pure CSS via :has(), with no JS class toggle; the full-size modal caps to 90% of the viewport and dims the page via the native dialog backdrop
Status: Draft | Source: AS-CODE-REV-145; AS-CODE-REV-146

`.cover-candidate:has(input:checked) img { border-color: #1a73e8; }`;
`#cover-modal img { max-width: 90vw; max-height: 90vh; }` with
`#cover-modal::backdrop { background: rgba(0,0,0,0.7); }` — both native
`<dialog>`/`:has()` behaviors, not custom-built.

### AS-REV-123 — A companion row with an active warning gets a light red background
Status: Draft | Source: AS-CODE-REV-147

`.companion-row-warning td { background: #fff3f3; }`.

### AS-REV-124 — Status badges are colored per status; the "unrecognized" badge reuses a neutral gray not shared with any release status
Status: Draft | Source: AS-CODE-REV-148

`badge-ready` green, `badge-needsReview` amber, `badge-ambiguous` red,
`badge-rejected` gray, `badge-unrecognized` a darker gray — five visually
distinct states across releases and unrecognized entries.

## Mark reviewed (optional)

### AS-REV-125 — "session mark-reviewed" only changes the session's own stage bookkeeping
Status: Draft | Source: AS-DOC-REV-084

It does not touch any release; apply does not need it and does not check
it. The command syntax: see [12-cli.md](12-cli.md) (`AS-CLI-024`). Stages:
see [04-sessions.md](04-sessions.md).

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-13 | Phase 3 merge of area REV: 84 `AS-DOC-REV-*` + 148 `AS-CODE-REV-*`, reconciled into `AS-REV-001`–`125`. 5 contradictions resolved (`AS-DOC-DEF-069`, `073`, `076`, `077`, `080`), all in favor of the tests/code over stale plan-07 prose, each independently confirmed from the server/client code. 15 suspected defects carried forward (`CF-REV-001`–`015`), covering all 7 `AS-CODE-DEF-REV-*` entries and the 9 REV-area `AS-DOC-DEF-*` suspected defects (`070`–`072`, `074`, `075`, `078`, `079`, `081`, `082`). |
| 0.2 | 2026-10-13 | During the LSY merge: two dangling `(not yet merged)` references to `11-lossy-tracking.md` resolved to real links; the same edit also resolved an already-stale `10-apply.md` `(not yet merged)` note in passing. |
| 0.3 | 2026-10-13 | During the CLI merge: `AS-REV-032`/`033`'s `Source:` lines extended to cite `AS-DOC-CLI-014`/`015` (the `ui start` default port and `-NoBrowser`, restated from the CLI doc side with no new content) — see `12-cli.md`. Two dangling `(not yet merged)` references to `12-cli.md` resolved to real links. |
