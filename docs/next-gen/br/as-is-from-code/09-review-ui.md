# Review UI — as-is from code (REV)

Status: Draft | Version: 0.1 | Last updated: 2026-10-10

## Server: static file resolution and MIME types

### AS-CODE-REV-001 — Empty request path serves index.html
Status: Draft | Source: legacy/scripts/common/Reshelf.UiServer.psm1:22 › Resolve-ReshelfUiRequestPath

When the request path (after stripping a leading `/`) is empty, the server serves `index.html` from the UI root instead of failing or listing a directory.

Example: request path `/` → relative path `index.html`.

### AS-CODE-REV-002 — Leading slash is stripped before resolving a static file path
Status: Draft | Source: legacy/scripts/common/Reshelf.UiServer.psm1:22 › Resolve-ReshelfUiRequestPath

The request's absolute URL path has its leading `/` trimmed, then is joined onto the UI root directory to compute the candidate file path.

### AS-CODE-REV-003 — Only existing files are served; missing files return a routing miss
Status: Draft | Source: legacy/scripts/common/Reshelf.UiServer.psm1:42 › Resolve-ReshelfUiRequestPath

If the computed candidate path does not exist as a file (`Test-Path -PathType Leaf`), the function returns `$null` rather than throwing. The caller (Start-ReshelfUiServer.ps1) turns a `$null` result into an HTTP 404 with body `Not found: {path}`.

### AS-CODE-REV-004 — Static file serving is restricted to paths under the UI root (anti path-traversal)
Status: Draft | Source: legacy/scripts/common/Reshelf.UiServer.psm1:46 › Resolve-ReshelfUiRequestPath

After resolving the candidate path, the server checks that the resolved path starts with the resolved UI root plus a directory separator. If not, it returns `$null` (treated as not-found), so a request path like `../../secrets.txt` cannot escape the UI root.

### AS-CODE-REV-005 — Path-root containment check is case-insensitive
Status: Draft | Source: legacy/scripts/common/Reshelf.UiServer.psm1:48 › Resolve-ReshelfUiRequestPath

The "is this path under the UI root" comparison uses `OrdinalIgnoreCase`, so case differences in drive letters/segments do not cause a false rejection on Windows.

### AS-CODE-REV-006 — Fixed extension-to-MIME-type map; everything else is octet-stream
Status: Draft | Source: legacy/scripts/common/Reshelf.UiServer.psm1:10 › Get-ReshelfUiMimeType

Static/ local files are served with a Content-Type from a fixed table: `.html`→text/html, `.js`→text/javascript, `.css`→text/css, `.json`→application/json, `.png`→image/png, `.jpg`/`.jpeg`→image/jpeg, `.svg`→image/svg+xml, `.ico`→image/x-icon. Any other extension (or no extension) gets `application/octet-stream`.

### AS-CODE-REV-007 — MIME-type lookup is case-insensitive on the extension
Status: Draft | Source: legacy/scripts/common/Reshelf.UiServer.psm1:63 › Get-ReshelfUiMimeType

The file extension is lower-cased (`ToLowerInvariant`) before the MIME-type table lookup, so `.JPG` and `.jpg` resolve the same.

## Server: API routing table

### AS-CODE-REV-008 — Session id in every session-scoped route must match a fixed 4-digit-date-plus-sequence pattern
Status: Draft | Source: legacy/scripts/common/Reshelf.UiServer.psm1:71 › Get-ReshelfUiApiRoute

Every route that takes a `{sessionId}` segment validates it against the regex `^\d{4}-\d{2}-\d{2}-\d{4}$` (e.g. `2026-09-25-0003`). A value that doesn't match returns a 400 Bad Request ("Invalid session id '...'" ) instead of attempting any file access, which keeps a crafted id out of the sessions folder.

### AS-CODE-REV-009 — GET /api/current-session is a dedicated route
Status: Draft | Source: legacy/scripts/common/Reshelf.UiServer.psm1:93 › Get-ReshelfUiApiRoute

`GET /api/current-session` maps to the `CurrentSession` action with no parameters.

### AS-CODE-REV-010 — GET /api/sessions is a dedicated route
Status: Draft | Source: legacy/scripts/common/Reshelf.UiServer.psm1:96 › Get-ReshelfUiApiRoute

`GET /api/sessions` maps to the `ListSessions` action.

### AS-CODE-REV-011 — GET and PUT /api/sessions/{id}/proposal share one route pattern
Status: Draft | Source: legacy/scripts/common/Reshelf.UiServer.psm1:100 › Get-ReshelfUiApiRoute

The path `/api/sessions/{sessionId}/proposal` routes to `GetProposal` on GET and `SaveProposal` on PUT (after the session-id format check in REV-008 passes).

### AS-CODE-REV-012 — Unsupported HTTP method on a known API path falls through to static-file handling
Status: Draft | Source: legacy/scripts/common/Reshelf.UiServer.psm1:100 › Get-ReshelfUiApiRoute

If the method is neither GET nor PUT for `/api/sessions/{id}/proposal` (e.g. DELETE), the route function matches the path pattern, confirms the session id, but returns no action object for that method and falls through to the next pattern checks; since none of those match either, `Get-ReshelfUiApiRoute` ultimately returns `$null` and the request is served (or 404'd) as if it were a static file request, not as an API 405/400.

### AS-CODE-REV-013 — POST /api/sessions/{id}/proposal/releases/{stableKey}/discogs-selection requires a 16-hex-character stable key
Status: Draft | Source: legacy/scripts/common/Reshelf.UiServer.psm1:113 › Get-ReshelfUiApiRoute

The release's `stableKey` path segment must match `[0-9a-f]{16}` (16 lowercase hex digits) or the whole path simply doesn't match this route at all (falls through, eventually 404 as a static path).

### AS-CODE-REV-014 — GET /api/sessions/{id}/local-file is a dedicated route
Status: Draft | Source: legacy/scripts/common/Reshelf.UiServer.psm1:122 › Get-ReshelfUiApiRoute

`GET /api/sessions/{sessionId}/local-file` (query string carries `path`) maps to the `LocalFile` action.

### AS-CODE-REV-015 — POST /api/sessions/{id}/manual-cover is a dedicated route
Status: Draft | Source: legacy/scripts/common/Reshelf.UiServer.psm1:130 › Get-ReshelfUiApiRoute

`POST /api/sessions/{sessionId}/manual-cover` (query string carries `filename`) maps to the `SaveManualCover` action.

### AS-CODE-REV-016 — GET /api/naming-templates is a dedicated route
Status: Draft | Source: legacy/scripts/common/Reshelf.UiServer.psm1:138 › Get-ReshelfUiApiRoute

`GET /api/naming-templates` maps to the `NamingTemplates` action with no session scoping.

### AS-CODE-REV-017 — GET /api/lossy is a dedicated route
Status: Draft | Source: legacy/scripts/common/Reshelf.UiServer.psm1:142 › Get-ReshelfUiApiRoute

`GET /api/lossy` maps to `ListLossy`, with no session scoping (the lossy-tracking ledger is global, not per session).

### AS-CODE-REV-018 — PUT and DELETE /api/lossy/{stableKey} require a 16-hex-character key
Status: Draft | Source: legacy/scripts/common/Reshelf.UiServer.psm1:145 › Get-ReshelfUiApiRoute

`/api/lossy/{stableKey}` (stableKey = `[0-9a-f]{16}`) maps to `UpdateLossy` on PUT and `DeleteLossy` on DELETE. Any other method on this exact path falls through to static-file handling, same as REV-012.

## Server: handling each API action (Start-ReshelfUiServer.ps1)

### AS-CODE-REV-019 — CurrentSession: no session with a proposal yet returns found:false, not an error
Status: Draft | Source: legacy/scripts/Start-ReshelfUiServer.ps1:103

When no session has a `proposal.json`, `GET /api/current-session` returns HTTP 200 with `{ found: false, message: "No session has a proposal yet - run recognize and propose first." }` rather than a 4xx/5xx.

### AS-CODE-REV-020 — CurrentSession re-serializes the proposal JSON instead of passing it through raw
Status: Draft | Source: legacy/scripts/Start-ReshelfUiServer.ps1:112

When a current session is found, its `proposal.json` content is parsed (`ConvertFrom-Json`) and embedded in a wrapper object that is then re-serialized (`ConvertTo-Json -Depth 20`) before being sent. This differs from `GetProposal` (REV-021), which sends the same file's bytes untouched — see AS-CODE-DEF-REV-002.

### AS-CODE-REV-021 — GetProposal returns the on-disk proposal.json content byte-for-byte
Status: Draft | Source: legacy/scripts/Start-ReshelfUiServer.ps1:127

`GET /api/sessions/{id}/proposal` reads the file and writes its raw string straight to the response (no parse/re-serialize round trip), preserving exact formatting and number precision. Returns 404 with the underlying error message if the session has no proposal file.

### AS-CODE-REV-022 — SaveProposal only validates that the request body is syntactically valid JSON
Status: Draft | Source: legacy/scripts/common/Reshelf.UiServer.psm1:228 › Save-ReshelfUiProposalContent

Before writing anything, the body is parsed with `ConvertFrom-Json` purely to confirm it is valid JSON; no schema/shape validation is performed. An invalid JSON body throws and is reported as 400, and the existing file is left untouched.

### AS-CODE-REV-023 — SaveProposal keeps exactly one rolling backup copy
Status: Draft | Source: legacy/scripts/common/Reshelf.UiServer.psm1:242 › Save-ReshelfUiProposalContent

Before overwriting `proposal.json`, if it already exists, it is copied to `proposal.backup.json` in the same folder, overwriting any previous backup — only the single most recent prior version is ever kept.

### AS-CODE-REV-024 — SaveProposal writes UTF-8 with no trailing newline
Status: Draft | Source: legacy/scripts/common/Reshelf.UiServer.psm1:247 › Save-ReshelfUiProposalContent

The new content is written via `Set-Content -Encoding utf8 -NoNewline`.

### AS-CODE-REV-025 — SaveProposal response includes a UTC save timestamp
Status: Draft | Source: legacy/scripts/Start-ReshelfUiServer.ps1:140

On success, `PUT /api/sessions/{id}/proposal` returns `{ savedAtUtc: <ISO 8601 UTC timestamp> }` with status 200.

### AS-CODE-REV-026 — SelectDiscogsCandidate requires releaseId in the request body
Status: Draft | Source: legacy/scripts/Start-ReshelfUiServer.ps1:149

If the JSON body has no `releaseId`, the server responds 400 with "Request body must include 'releaseId'." without touching the proposal.

### AS-CODE-REV-027 — SelectDiscogsCandidate returns 404 if the stableKey matches no release in the session
Status: Draft | Source: legacy/scripts/Start-ReshelfUiServer.ps1:165

If no release across all artists in the proposal has the given `stableKey`, the response is 404 ("No release found for stable key '...'").

### AS-CODE-REV-028 — SelectDiscogsCandidate derives a fallback artist name from the first track, favoring album artist over folder name
Status: Draft | Source: legacy/scripts/Start-ReshelfUiServer.ps1:170

The fallback artist name used to search Discogs for the newly selected edition is the first track's `tags.albumArtist` when the release has tracks, otherwise `proposed.artistFolderName`. This is deliberately the album artist, not a track's own artist, so a compilation (e.g. "Various") searches correctly instead of using one track's individual performer.

### AS-CODE-REV-029 — SelectDiscogsCandidate overwrites tracks, proposed names, discogsMatch, coverArt, lossyLossless and targetAction on the matched release
Status: Draft | Source: legacy/scripts/Start-ReshelfUiServer.ps1:182

After calling the shared Discogs-selection logic, the server replaces `target.tracks`, `target.proposed`, `target.discogsMatch`, `target.coverArt`, `target.lossyLossless`, and `target.targetAction` with the recomputed values for that one release; sibling releases in the same session are passed in for context but are not modified.

### AS-CODE-REV-030 — SelectDiscogsCandidate appends any new notes to existing human-review notes, joined by "; "
Status: Draft | Source: legacy/scripts/Start-ReshelfUiServer.ps1:188

If the recompute produces notes, they are joined with `; ` and appended to `target.humanReview.notes` (prefixed with `; ` if notes already existed), rather than replacing them.

### AS-CODE-REV-031 — SelectDiscogsCandidate can force humanReview.required to true but never turns it off
Status: Draft | Source: legacy/scripts/Start-ReshelfUiServer.ps1:192

If the recompute flags `requiresReview`, `target.humanReview.required` is set to `$true`. There is no corresponding path that clears this flag back to `$false` from this handler.

### AS-CODE-REV-032 — SelectDiscogsCandidate saves the proposal to disk immediately and returns the updated release
Status: Draft | Source: legacy/scripts/Start-ReshelfUiServer.ps1:194

The whole proposal (with the one release replaced) is serialized and saved via the same `Save-ReshelfUiProposalContent` path as a manual Save (including the rolling backup, REV-023), before the handler responds 200 with just the updated release object. This happens without the user clicking the page's own Save button.

### AS-CODE-REV-033 — LocalFile requires a 'path' query parameter
Status: Draft | Source: legacy/scripts/Start-ReshelfUiServer.ps1:205

If the query string has no `path` value, the response is 400 ("Missing 'path' query parameter.").

### AS-CODE-REV-034 — LocalFile serves raw bytes with a content type derived from the requested path's extension
Status: Draft | Source: legacy/scripts/Start-ReshelfUiServer.ps1:210

On success, the response body is the file's raw bytes with `ContentType` set from `Get-ReshelfUiMimeType` applied to the requested path's own extension (REV-006/REV-007 apply here too).

### AS-CODE-REV-035 — LocalFile maps every failure to HTTP 403
Status: Draft | Source: legacy/scripts/Start-ReshelfUiServer.ps1:216

Any exception from resolving/reading the local file (not-allowed path, file missing, read error) is reported as HTTP 403 with the exception's message — see AS-CODE-DEF-REV-003 for the not-found-vs-forbidden conflation this causes.

### AS-CODE-REV-036 — SaveManualCover requires a 'filename' query parameter
Status: Draft | Source: legacy/scripts/Start-ReshelfUiServer.ps1:222

If the query string has no `filename` value, the response is 400 ("Missing 'filename' query parameter.").

### AS-CODE-REV-037 — SaveManualCover reads the whole request body as binary before any validation
Status: Draft | Source: legacy/scripts/Start-ReshelfUiServer.ps1:227

The uploaded image's bytes are read as raw binary (`Read-ReshelfUiRequestBodyBytes`, see REV-043/044), not text, to avoid corrupting binary image data the way UTF-8 text decoding would.

### AS-CODE-REV-038 — SaveManualCover response shape
Status: Draft | Source: legacy/scripts/Start-ReshelfUiServer.ps1:229

On success, responds 200 with `{ url, width, height }` for the newly saved file; any failure (empty file, too large, wrong type, unreadable image) is reported as 400 with the thrown message.

### AS-CODE-REV-039 — NamingTemplates exposes exactly three settings fields
Status: Draft | Source: legacy/scripts/Start-ReshelfUiServer.ps1:240

`GET /api/naming-templates` returns `{ releaseFolder, trackFile, trackNumberPadWidth }` read live from `Get-ReshelfSettings` on every request (not cached at server startup).

### AS-CODE-REV-040 — ListLossy returns the entire ledger with no filtering or pagination server-side
Status: Draft | Source: legacy/scripts/Start-ReshelfUiServer.ps1:247

`GET /api/lossy` always returns every entry in the lossy-tracking ledger; status filtering (REV-083) happens only in the browser.

### AS-CODE-REV-041 — UpdateLossy requires a status field in the body
Status: Draft | Source: legacy/scripts/Start-ReshelfUiServer.ps1:254

If the JSON body's `status` is `$null`, the response is 400 ("Request body must include 'status'."). `notes` is optional and only forwarded if present (`$null -ne $body.notes`).

### AS-CODE-REV-042 — UpdateLossy returns 404 if the stable key has no ledger entry after the update call
Status: Draft | Source: legacy/scripts/Start-ReshelfUiServer.ps1:261

After calling `Set-ReshelfLossyTrackingStatus`, the handler looks the entry back up by `stableKey` in the returned ledger; if not found, it responds 404.

### AS-CODE-REV-043 — DeleteLossy maps every failure to HTTP 404
Status: Draft | Source: legacy/scripts/Start-ReshelfUiServer.ps1:272

`DELETE /api/lossy/{stableKey}` responds 200 `{ removed: true }` on success; any exception at all (not just "entry not found") is reported as 404 — see AS-CODE-DEF-REV-004.

## Server: session discovery and disk access helpers

### AS-CODE-REV-044 — Session summary fields
Status: Draft | Source: legacy/scripts/common/Reshelf.UiServer.psm1:160 › Get-ReshelfUiSessionsSummary

Each session in `GET /api/sessions` is reduced to `{ sessionId, sourceRoot, stage, updatedAtUtc, hasProposal }`; `hasProposal` is computed fresh by checking whether the session's `proposalPath` exists as a file right now, not from stored session metadata.

### AS-CODE-REV-045 — Current session is the most recently updated session that actually has a proposal
Status: Draft | Source: legacy/scripts/common/Reshelf.UiServer.psm1:180 › Get-ReshelfUiCurrentSession

Sessions are already sorted descending by `updatedAtUtc` (by the underlying `Get-ReshelfSession`); the "current" session for the review UI is the first one in that order whose `hasProposal` is true — a more recently touched session that has no proposal yet is skipped over, not shown as current.

### AS-CODE-REV-046 — Manual-covers directory path is fixed per session
Status: Draft | Source: legacy/scripts/common/Reshelf.UiServer.psm1:252 › Get-ReshelfUiManualCoversDir

Manually uploaded covers for a session live under `{DataHome}/sessions/{sessionId}/manual-covers`.

### AS-CODE-REV-047 — LocalFile: any file physically under a session's manual-covers folder is always servable
Status: Draft | Source: legacy/scripts/common/Reshelf.UiServer.psm1:280 › Get-ReshelfUiLocalFileBytes

If the resolved requested path is under that session's manual-covers directory, it is served unconditionally — this bypasses the proposal.json allow-list check (REV-048) because a just-uploaded cover candidate only exists in the browser's in-memory proposal until the user clicks Save, so it wouldn't be found in the on-disk proposal.json yet.

### AS-CODE-REV-048 — LocalFile: outside manual-covers, only a path literally named as a non-URL cover candidate in the session's own proposal.json is servable
Status: Draft | Source: legacy/scripts/common/Reshelf.UiServer.psm1:299 › Get-ReshelfUiLocalFileBytes

The server collects every `coverArt.candidates[].url` across all releases in the session's proposal.json whose value does not start with `http://`/`https://` (i.e. a local file path, not a remote Discogs image) into an allow-list, and only serves the requested path if it is exactly in that set. A requested path not in the set throws ("is not a known local cover file for session...") and is reported as 403 (REV-035). This is the server's only access control for this endpoint.

### AS-CODE-REV-049 — LocalFile allow-list comparison is case-insensitive
Status: Draft | Source: legacy/scripts/common/Reshelf.UiServer.psm1:303 › Get-ReshelfUiLocalFileBytes

The allow-list of known cover paths is a `HashSet<string>` using `OrdinalIgnoreCase`, so a path differing only by case still matches.

### AS-CODE-REV-050 — LocalFile throws a distinct "no longer exists" error if the allowed file has since been deleted
Status: Draft | Source: legacy/scripts/common/Reshelf.UiServer.psm1:319 › Get-ReshelfUiLocalFileBytes

Even after passing the allow-list/manual-covers check, the function re-checks the file exists before reading bytes, to guard against a race between the check and the read (e.g. the file was deleted in between).

## Server: manual cover upload

### AS-CODE-REV-051 — Manual cover upload rejects a zero-byte body
Status: Draft | Source: legacy/scripts/common/Reshelf.UiServer.psm1:377 › Save-ReshelfUiManualCoverFile

An empty upload throws "Uploaded file is empty." before any file is written.

### AS-CODE-REV-052 — Manual cover upload size limit is 20 MB
Status: Draft | Source: legacy/scripts/common/Reshelf.UiServer.psm1:333

`$script:ReshelfUiManualCoverMaxBytes = 20MB`. An upload over this size throws "Uploaded file exceeds the 20 MB limit." See AS-CODE-DEF-REV-001 — this same 20 MB value is independently hard-coded a second time in Start-ReshelfUiServer.ps1.

### AS-CODE-REV-053 — Manual cover upload only accepts .jpg, .jpeg, .png (case-insensitive)
Status: Draft | Source: legacy/scripts/common/Reshelf.UiServer.psm1:332

`$script:ReshelfUiManualCoverExtensions = @('.jpg', '.jpeg', '.png')`. Any other extension (matched case-insensitively against the uploaded file name) throws "Unsupported image type '...' - allowed: .jpg, .jpeg, .png."

### AS-CODE-REV-054 — Manual cover upload verifies the session exists without requiring an existing proposal.json
Status: Draft | Source: legacy/scripts/common/Reshelf.UiServer.psm1:390 › Save-ReshelfUiManualCoverFile

`Get-ReshelfSession` is called purely to confirm the session id is real (throwing "Session '...' not found." otherwise); this endpoint never reads or writes proposal.json itself.

### AS-CODE-REV-055 — Manual-covers directory is created on first upload
Status: Draft | Source: legacy/scripts/common/Reshelf.UiServer.psm1:395 › Save-ReshelfUiManualCoverFile

If the session's manual-covers folder doesn't exist yet, it is created before the file is written.

### AS-CODE-REV-056 — Saved manual cover file name is always a new random GUID, never the uploaded file's own name
Status: Draft | Source: legacy/scripts/common/Reshelf.UiServer.psm1:399 › Save-ReshelfUiManualCoverFile

The file is saved as `{new GUID}.{original extension}` — only the extension is carried over from the client-supplied file name, which also avoids any path-injection risk from that name.

### AS-CODE-REV-057 — Manual cover upload reads image dimensions after writing, and deletes the file again if that fails
Status: Draft | Source: legacy/scripts/common/Reshelf.UiServer.psm1:403 › Save-ReshelfUiManualCoverFile

After the bytes are on disk, the server reads width/height via `Get-ReshelfUiImageDimensions`; if that throws (not a readable image), the just-written file is deleted (`-ErrorAction SilentlyContinue`) and the request fails with "Uploaded file is not a readable image: ...".

### AS-CODE-REV-058 — Image dimension reading throws instead of defaulting on failure
Status: Draft | Source: legacy/scripts/common/Reshelf.UiServer.psm1:335 › Get-ReshelfUiImageDimensions

Unlike the similarly named helper in `Reshelf.EditProposal.psm1` (not read for this document), this copy throws on an unreadable image rather than returning a silent 1x1 placeholder, specifically so the caller can delete the bad file (REV-057). It loads the `System.Drawing` assembly on demand if not already loaded.

## Server: HTTP bootstrap, parameters, and request loop

### AS-CODE-REV-059 — Default port is 4173
Status: Draft | Source: legacy/scripts/Start-ReshelfUiServer.ps1:4

`-Port` defaults to `4173` if not specified.

### AS-CODE-REV-060 — Default UI root is the ui/ folder next to the scripts folder
Status: Draft | Source: legacy/scripts/Start-ReshelfUiServer.ps1:5

`-UiRoot` defaults to `{script directory}\..\ui`.

### AS-CODE-REV-061 — -NoBrowser suppresses auto-launching a browser window
Status: Draft | Source: legacy/scripts/Start-ReshelfUiServer.ps1:10

The `-NoBrowser` switch skips the `Start-Process $url` call; it exists so the Playwright test suite, which drives its own browser instance, doesn't also get an unwanted second real browser window on every automated run.

### AS-CODE-REV-062 — Server refuses to start if the UI root doesn't resolve to an existing path
Status: Draft | Source: legacy/scripts/Start-ReshelfUiServer.ps1:24

If `-UiRoot` doesn't resolve, the script throws "UI root '...' does not exist. Nothing to serve." before opening any listener.

### AS-CODE-REV-063 — DataHome is resolved once at startup and fixed for the server's lifetime
Status: Draft | Source: legacy/scripts/Start-ReshelfUiServer.ps1:31

`$dataHome = (Get-ReshelfSettings).dataHome` is read a single time when the script starts; a settings change afterward requires restarting the server to take effect.

### AS-CODE-REV-064 — Server listens on localhost only, on the configured port
Status: Draft | Source: legacy/scripts/Start-ReshelfUiServer.ps1:284

The only `HttpListener` prefix registered is `http://localhost:{Port}/` — not `0.0.0.0` or a specific LAN address, so the UI is reachable only from the same machine.

### AS-CODE-REV-065 — Server opens the OS default browser on startup unless -NoBrowser is given
Status: Draft | Source: legacy/scripts/Start-ReshelfUiServer.ps1:290

`Start-Process $url` launches the default browser pointed at the server's URL right after the listener starts.

### AS-CODE-REV-066 — Request loop polls in 200 ms slices so Ctrl+C can interrupt it even with no incoming traffic
Status: Draft | Source: legacy/scripts/Start-ReshelfUiServer.ps1:301

Instead of a blocking `GetContext()` call, the loop calls `GetContextAsync()` and waits on it in a `while` loop with a 200 ms timeout per iteration, because a plain blocking call can no longer be force-aborted by Ctrl+C on PowerShell 7/.NET (Thread.Abort was removed). This gives the engine a safe point to react to a pending Ctrl+C roughly 5 times per second.

### AS-CODE-REV-067 — A single failed request is caught and answered with HTTP 500, without stopping the server
Status: Draft | Source: legacy/scripts/Start-ReshelfUiServer.ps1:329

Any unhandled exception while handling one request is logged as a PowerShell warning and answered with a plain-text 500 "Internal server error" body; the listener loop keeps running for all other requests/tabs.

### AS-CODE-REV-068 — JSON array/object responses are serialized via -InputObject, not the pipeline, to avoid PowerShell unwrapping small arrays
Status: Draft | Source: legacy/scripts/Start-ReshelfUiServer.ps1:33 › Write-ReshelfUiJsonResponse

`ConvertTo-Json -InputObject $Payload -Depth 20` is used deliberately instead of `$Payload | ConvertTo-Json`, because piping an array unrolls it into separate pipeline items and `ConvertTo-Json` then serializes a bare object/`[]` instead of a real JSON array for a 0- or 1-element collection — this would otherwise break any client code (e.g. `/api/lossy` with 0 or 1 entries) expecting an array back.

### AS-CODE-REV-069 — proposal.json content for GetProposal is written through as-is, bypassing PowerShell's JSON serializer
Status: Draft | Source: legacy/scripts/Start-ReshelfUiServer.ps1:48 › Write-ReshelfUiRawJsonResponse

Raw JSON text (already validated/owned on disk) is written straight to the response body instead of being parsed and re-serialized, to avoid reformatting or precision loss `ConvertFrom-Json`/`ConvertTo-Json` could introduce. CurrentSession does not get this treatment for its embedded `proposal` field (REV-020/DEF-002).

### AS-CODE-REV-070 — JSON request bodies are decoded as text using the request's own content encoding
Status: Draft | Source: legacy/scripts/Start-ReshelfUiServer.ps1:66 › Read-ReshelfUiRequestBody

Text bodies (proposal saves, Discogs selection, lossy updates) are read via a `StreamReader` using `Request.ContentEncoding`.

### AS-CODE-REV-071 — Binary upload bodies are read as raw bytes, never decoded as text
Status: Draft | Source: legacy/scripts/Start-ReshelfUiServer.ps1:72 › Read-ReshelfUiRequestBodyBytes

The manual-cover upload path reads the body directly into a byte array, since UTF-8 text decoding (used for JSON bodies) would corrupt binary image data.

### AS-CODE-REV-072 — Binary upload size is checked twice: declared Content-Length first, then actual bytes received
Status: Draft | Source: legacy/scripts/Start-ReshelfUiServer.ps1:79 › Read-ReshelfUiRequestBodyBytes

The function first rejects early if `Request.ContentLength64` exceeds the max (default 20 MB — see AS-CODE-DEF-REV-001), then separately checks the actual buffered stream length after copying it, since a client's declared Content-Length header is not trusted on its own.

### AS-CODE-REV-073 — Static (non-API) requests are served for any HTTP method, with no method check
Status: Draft | Source: legacy/scripts/Start-ReshelfUiServer.ps1:313

Once a request path doesn't match any API route, the server serves (or 404s) the corresponding static file regardless of HTTP method — there is no restriction to GET only for static content.

## Client: page bootstrap and session loading

### AS-CODE-REV-074 — On load, the page wires controls, starts fetching naming templates, and starts loading the current session, without waiting for the templates fetch
Status: Draft | Source: legacy/ui/app.js:1281

`DOMContentLoaded` calls `wireStaticControls()`, then `loadNamingTemplates()` (not awaited) and `loadCurrentSession()` back-to-back — the two fetches effectively run concurrently rather than the second waiting for the first.

### AS-CODE-REV-075 — There is no periodic polling or auto-refresh anywhere in the client
Status: Draft | Source: legacy/ui/app.js (whole file)

No `setInterval`/`setTimeout`-driven refresh exists. Session, proposal, and lossy-ledger data are (re)fetched only on page load, clicking Retry, switching the session-history dropdown, switching to the Lossy tracker view, or after an action that explicitly re-fetches (Discogs selection, manual cover upload, lossy row edits).

### AS-CODE-REV-076 — There are no keyboard shortcuts anywhere in the client
Status: Draft | Source: legacy/ui/app.js (whole file)

No `keydown`/`keyup`/`keypress` listener is registered anywhere in app.js; every interaction (selecting a release, approving, saving, exporting) requires a mouse/pointer action on a specific element.

### AS-CODE-REV-077 — A found current session shows source root, local date, and stage as the status text
Status: Draft | Source: legacy/ui/app.js:99 › describeSession

The header status reads `Reviewing: {sourceRoot} ({localeDateString}, {stage})`.

### AS-CODE-REV-078 — A second, separate label always shows the raw session id
Status: Draft | Source: legacy/ui/app.js:86 › setSessionIdLabel

`#session-id-label` shows `Session {sessionId}` (or is cleared) — kept deliberately separate from the human-readable status text so a person can reference an exact session id (e.g. to another person), independent of the friendlier status line.

### AS-CODE-REV-079 — Switching away from the current session while there are unsaved changes requires confirmation
Status: Draft | Source: legacy/ui/app.js:43

Changing the session-history `<select>` triggers `window.confirm('You have unsaved changes. Discard them and switch session?')` if `isDirty()`; cancelling reverts the dropdown's value back to the current session id.

### AS-CODE-REV-080 — Selecting a history session with no proposal.json shows a status message instead of any release view
Status: Draft | Source: legacy/ui/app.js:189 › onSelectHistorySession

If the chosen session's `hasProposal` is false, the client sets `state.proposal = null`, shows `"{sourceRoot} has no proposal.json yet."`, and hides both the detail and unrecognized panels, clearing the release list — without making any further network request for that session.

### AS-CODE-REV-081 — The session-history dropdown is hidden entirely unless there are at least two sessions
Status: Draft | Source: legacy/ui/app.js:171 › renderSessionHistory

`#session-history` stays `hidden` whenever `sessions.length <= 1`.

### AS-CODE-REV-082 — Each history dropdown entry is labeled "{sourceRoot} - {localeDate} - {stage}", with a "(no proposal yet)" suffix for sessions without one
Status: Draft | Source: legacy/ui/app.js:178

### AS-CODE-REV-083 — A broken session-history fetch degrades silently (console warning only), not a visible error
Status: Draft | Source: legacy/ui/app.js:155 › refreshSessionHistory

If `/api/sessions` fails after the main session already loaded, the failure is only logged to the console (`"Could not load session history:"`) — the user sees no error state, since the primary session view already succeeded.

## Client: release list, filters, and badges

### AS-CODE-REV-084 — The two review filters combine with OR, not AND
Status: Draft | Source: legacy/ui/app.js:255 › renderList

Checking both "Needs review only" and "Ambiguous match only" shows releases matching *either* status, because a release's computed status is exactly one value at a time — an AND-style combination would always produce zero rows (the comment at this line records this as a fixed-forward design choice, not an open bug).

### AS-CODE-REV-085 — Releases are grouped by artist name as separate sidebar sections
Status: Draft | Source: legacy/ui/app.js:262 › renderList

Each distinct `artistName` (the recognized artist) gets its own `<section>` with an `<h3>` heading, in first-seen order, followed by each release row.

### AS-CODE-REV-086 — Unrecognized folders get their own "Unrecognized (N)" section, only when no status filter is active
Status: Draft | Source: legacy/ui/app.js:305 › renderList

`proposal.unrecognized` entries are listed under an `Unrecognized ({count})` heading, but only when neither "Needs review" nor "Ambiguous" filter checkbox is checked — ticking either filter hides the unrecognized section entirely, since unrecognized items have no review/ambiguous status of their own.

### AS-CODE-REV-087 — Release status is computed with a fixed priority: rejected, then ambiguous-unresolved, then needs-review-unresolved, else ready
Status: Draft | Source: legacy/ui/app.js:234 › getReleaseStatus

`getReleaseStatus` returns, in order: `'rejected'` if `humanReview.rejected`; else `'ambiguous'` if `discogsMatch.status === 'ambiguous'` and not yet `humanReview.resolved`; else `'needsReview'` if (`needsReview` or `humanReview.required`) and not yet resolved; else `'ready'`.

### AS-CODE-REV-088 — Release row label is "{year} {album}", trimmed
Status: Draft | Source: legacy/ui/app.js:287

Example: year `1994`, album `Parklife` → label `1994 Parklife`. A null/missing year collapses to just the album name (leading space trimmed).

### AS-CODE-REV-089 — Unsaved releases get a visual dot marker and an 'unsaved' row class
Status: Draft | Source: legacy/ui/app.js:285 › renderList (behavior); legacy/ui/styles.css:121 (visual)

A release row whose `stableKey` is in `state.dirtyReleaseKeys` gets the CSS class `unsaved`, which draws a small colored bullet (`\25CF`) after its label via `::after` content.

### AS-CODE-REV-090 — Clicking a release row selects it and deselects any unrecognized selection (and vice versa)
Status: Draft | Source: legacy/ui/app.js:337 › selectRelease / legacy/ui/app.js:345 › selectUnrecognized

Selecting a release clears `selectedUnrecognizedIndex` and hides the unrecognized panel; selecting an unrecognized entry clears `selectedReleaseKey` and hides the detail panel. The two selections are mutually exclusive.

### AS-CODE-REV-091 — Only one release row's badge/label is patched after an edit, not the whole sidebar
Status: Draft | Source: legacy/ui/app.js:816 › updateReleaseRowBadge

After an edit marks a release dirty, only that release's own row (if currently rendered) has its badge class/text and label text updated in place; a full `renderList()` rebuild is deliberately avoided per keystroke for performance on sessions with hundreds of releases. If the row isn't currently visible (e.g. hidden by an active filter), nothing is patched until the next full render.

## Client: unrecognized-folder detail

### AS-CODE-REV-092 — Unrecognized detail shows path, reason, and child file names as plain text
Status: Draft | Source: legacy/ui/app.js:353 › renderUnrecognizedDetail

The panel's title is the entry's final path segment; `#unrecognized-path` and `#unrecognized-reason` show the raw `path`/`reason` values; each name in `entry.children` becomes one `<li>`.

## Client: release detail — before/after table and release fields

### AS-CODE-REV-093 — The before/after table switches between a flat list and a disc-grouped layout based on whether the release spans more than one disc
Status: Draft | Source: legacy/ui/app.js:408 › renderBeforeAfterTable

If the release's tracks have more than one distinct `proposedDiscNumber`, the table groups rows by disc (each group's first row gets a row-spanning Disc cell) and the "Before" header spans 2 columns; otherwise it's one row per track with no disc column.

### AS-CODE-REV-094 — Disc group label prefers the source's own disc-folder name over a generated "Disc N" label
Status: Draft | Source: legacy/ui/app.js:435

Tracks are grouped (in first-seen order) under `track.discFolder` when the source had a named subfolder (e.g. "Disc 1"), falling back to `Disc {proposedDiscNumber}` otherwise.

### AS-CODE-REV-095 — The folder rename row always appears first in the before/after table
Status: Draft | Source: legacy/ui/app.js:411

Before any track rows, one row shows `release.sourceFolderPath` → `{proposed.artistFolderName}\{proposed.releaseFolderName}`.

### AS-CODE-REV-096 — Album Artist field value prefers the first track's tag over the proposed folder name
Status: Draft | Source: legacy/ui/app.js:466 › renderReleaseFields

`#field-artist` is populated from `release.tracks[0]?.tags.albumArtist`, falling back to `release.proposed.artistFolderName` only if there are no tracks.

### AS-CODE-REV-097 — Editing Album Artist updates every track's albumArtist, and each track's own artist only if it still matched the old value
Status: Draft | Source: legacy/ui/app.js:872 › onEditArtist

For each track, `tags.albumArtist` is always set to the new value; `tags.artist` is updated to match only if it previously equaled the track's own (old) `albumArtist` — a per-track artist that was already customized (e.g. a compilation's individual performer) is left untouched.

### AS-CODE-REV-098 — Toggling the Compilation checkbox sets isCompilation on the release and on every track's tags
Status: Draft | Source: legacy/ui/app.js:885 › onEditCompilation

### AS-CODE-REV-099 — Editing Album updates the release's proposed album and every track's album tag, and recomputes folder names
Status: Draft | Source: legacy/ui/app.js:893 › onEditAlbum

### AS-CODE-REV-100 — Editing Year accepts only a parsed integer or null, applied to every track's year tag
Status: Draft | Source: legacy/ui/app.js:902 › onEditYear

An empty Year field sets `proposed.year` (and every track's `tags.year`) to `null`; any non-empty value is parsed with `parseInt(value, 10)` (so e.g. "1994abc" becomes `1994`).

### AS-CODE-REV-101 — Artist Folder Name and Release Folder Name fields are recomputed live from Artist/Album/Year, and a direct edit to them is overwritten by the next Artist/Album/Year edit
Status: Draft | Source: legacy/ui/app.js:857 › updateProposedFolderNames / legacy/ui/app.js:912 › onEditArtistFolderName

Editing Artist Folder Name or Release Folder Name directly sets `proposed.artistFolderName`/`releaseFolderName` and marks the release dirty, but any subsequent edit to Artist, Album, or Year recomputes and overwrites both folder-name fields from scratch, discarding the hand-typed value.

### AS-CODE-REV-102 — Client folder-name preview mirrors the server's {year}/{album} naming template fetched at startup
Status: Draft | Source: legacy/ui/app.js:848 › deriveProposedFolderNames

`releaseFolderName` is built by substituting `{year}` and `{album}` (sanitized) into `state.namingTemplates.releaseFolder` (default `'{year} {album}'`) and trimming; `artistFolderName` is just the sanitized artist name. This is a live preview only — a real re-run of `propose` on the legacy CLI is the actual source of truth.

### AS-CODE-REV-103 — Client-side safe-filename sanitizer strips the same character set and reserved device names as the server's
Status: Draft | Source: legacy/ui/app.js:924

`toSafeFileName` replaces control characters and `<>:"/\|?*` with `_`, strips trailing dots/spaces, and appends `_` if the result exactly matches a reserved Windows device name (CON, PRN, AUX, NUL, COM1-9, LPT1-9), case-insensitively. See AS-CODE-DEF-REV-005 regarding a stale comment nearby that describes this function as not doing the reserved-name step.

## Client: track fields and file-name derivation

### AS-CODE-REV-104 — Disc/Track number inputs silently ignore non-integer or sub-1 values instead of writing them through
Status: Draft | Source: legacy/ui/app.js:970 › onEditTrackField

If `parseInt` on the Disc or Track input doesn't produce an integer ≥ 1 (including an empty/incomplete value, which parses to `NaN`), the edit is dropped entirely — no state change, no re-render — rather than storing an invalid number, because the schema requires these as non-nullable integers ≥ 1.

### AS-CODE-REV-105 — A blank per-track Artist field is auto-replaced by Album Artist when the input loses focus
Status: Draft | Source: legacy/ui/app.js:520

On blur, if the track Artist input is empty/whitespace, it is reset to the track's `tags.albumArtist` and that value is saved, because the schema requires a non-empty Artist (minLength 1) and an empty value would otherwise only fail later, during Apply.

### AS-CODE-REV-106 — Editing a track's own Artist does not recompute its file name
Status: Draft | Source: legacy/ui/app.js:990

Artist is not part of the track file-name template, so this edit path skips the folder/file-name recompute (`deriveTrackFileNames`/`renderBeforeAfterTable`) that every other track-field edit triggers.

### AS-CODE-REV-107 — Track file numbering runs continuously across discs using each disc's highest track number as an offset
Status: Draft | Source: legacy/ui/app.js:944 › deriveTrackFileNames

For a multi-disc release, disc 2's first file number continues from disc 1's highest track number (e.g. disc 1 has tracks up to 12 → disc 2 starts its file numbers at 13), mirroring the CLI's own numbering. The UI has no access to Discogs' own per-disc track counts, so if the *last* track of an earlier disc is missing from this session, later discs' file numbers come out one too low and need a manual fix (documented limitation, not silently corrected).

### AS-CODE-REV-108 — Track file number zero-padding grows to fit the largest number, never shrinks below the configured width
Status: Draft | Source: legacy/ui/app.js:958

Pad width = `max(namingTemplates.trackNumberPadWidth, digit count of the largest computed file number)` — e.g. with a configured pad width of 2, file numbers up to 99 stay 2-digit, but number 100+ widens to 3-digit padding for every track in the release.

### AS-CODE-REV-109 — Track file name template substitutes {trackNumber} and {title}, and preserves the current file extension
Status: Draft | Source: legacy/ui/app.js:960

Example: template `'{trackNumber} {title}'`, trackNumber `07`, title `Parklife` → `07 Parklife` plus whatever extension the track's current `proposedFileName` has (or `.{format}` if there's no extension in the current name yet).

## Client: companion (non-media) files

### AS-CODE-REV-110 — Only loose companion files have an editable proposed name; nested-folder companions can only be included/excluded
Status: Draft | Source: legacy/ui/app.js:570 › renderCompanionTable

A companion with `placement === 'loose'` gets a text input for its "After" name; any other placement (nested in a subfolder) shows the same relative path as "Before" and "After" with no rename option — only its Include checkbox is editable.

### AS-CODE-REV-111 — A loose companion missing a proposed name is auto-backfilled with its original file name, and this side-effect marks the release dirty
Status: Draft | Source: legacy/ui/app.js:604

If `companion.proposedFileName` is falsy for a loose, included companion (e.g. a session saved before a rename suggestion existed for it), rendering the table itself sets it to the original relative file name and calls `markDirty(release)` — a pure render function has a persistent state side effect here.

### AS-CODE-REV-112 — Companion warnings are re-validated live, in a fixed priority order, without rebuilding the table
Status: Draft | Source: legacy/ui/app.js:658 › refreshCompanionWarnings

For each included loose companion, exactly one of these warnings (first match wins) can show under its name field: "Name is required." (empty name) → "Must start with a letter." → "Same name as a track file." (case-insensitive) → "Same name as another included file." (case-insensitive, checked against names already seen in table order). This mirrors the checks the legacy Implementation module makes before copying files, surfacing a problem before an Apply run would fail on it.

### AS-CODE-REV-113 — A loose companion name must start with a Unicode letter, not just an ASCII one
Status: Draft | Source: legacy/ui/app.js:566 › startsWithLetter

The check uses the regex `/^\p{L}/u`, so a name starting with e.g. an accented or non-Latin letter passes.

### AS-CODE-REV-114 — Excluded/ignored companions are shown read-only with their exclusion reason, and never get a name field or warnings
Status: Draft | Source: legacy/ui/app.js:636

Each entry in `release.ignoredFiles` is shown as a dimmed (`companion-row-ignored`) row reading `Not copied: {reason}` in the After column, with no Include checkbox and no name input.

### AS-CODE-REV-115 — The companion table is hidden entirely (replaced by "No other files") when there are no companion or ignored files
Status: Draft | Source: legacy/ui/app.js:579

## Client: cover art and Discogs candidate selection

### AS-CODE-REV-116 — Cover and Discogs candidate pickers share one radio-list implementation, and re-fire selection even on re-clicking the already-selected option
Status: Draft | Source: legacy/ui/app.js:704 › renderRadioList

Both lists listen for the native `click` event (not `change`), specifically so clicking an option that's already checked still re-runs the selection handler — needed e.g. to let a user re-trigger logic for a stale `selectedReleaseId` saved before some later recompute existed.

### AS-CODE-REV-117 — A cover candidate's image source routes through the local-file API unless it's already an http(s) URL
Status: Draft | Source: legacy/ui/app.js:731 › resolveCoverImageSrc

Example: a candidate url of `https://discogs.../img.jpg` loads directly; a candidate url of `D:\Music\...\Front.jpg` (a local companion file, which a browser can't load directly) becomes `/api/sessions/{currentSessionId}/local-file?path=D%3A%5CMusic%5C...%5CFront.jpg`.

### AS-CODE-REV-118 — Each cover candidate shows its original size and, if it would be shrunk on embed, the resulting embedded size
Status: Draft | Source: legacy/ui/app.js:744 › computeEmbeddedCoverSize / legacy/ui/app.js:753 › renderCoverGallery

The scale-down-only, aspect-preserving computation mirrors the server's embed-time resize filter. Example: a 1500x1500 candidate with `coverArt.targetMaxDimension` of 1000 shows `"1500x1500 → 1000x1000 embedded"`; a candidate already at or under the max shows `"{w}x{h} (embedded as is)"`. The max-dimension value is also shown as a tooltip on the size text.

### AS-CODE-REV-119 — Clicking a cover thumbnail opens it full-size in a native dialog, closable via an X button or clicking the backdrop
Status: Draft | Source: legacy/ui/app.js:736 › openCoverModal

### AS-CODE-REV-120 — The Discogs ambiguous-candidate picker only appears when the release's match status is 'ambiguous'
Status: Draft | Source: legacy/ui/app.js:787 › renderDiscogsCandidates

Each candidate is listed as `"{title} ({year}, {format}) - score {score}"`.

### AS-CODE-REV-121 — Manual cover upload input accepts only PNG/JPEG via the file picker, and is a hidden input triggered by a styled label button
Status: Draft | Source: legacy/ui/index.html:104

`#manual-cover-input` is `type="file" accept="image/png,image/jpeg" hidden`; the visible control is a `<label for="manual-cover-input">` styled as a button, reading "Add cover from file…".

### AS-CODE-REV-122 — Manual cover upload sends the file's bytes to the server immediately, before the user clicks Save
Status: Draft | Source: legacy/ui/app.js:1012 › onManualCoverFileChosen / legacy/ui/app.js:1022 › uploadManualCover

Choosing a file immediately POSTs its bytes to `/api/sessions/{id}/manual-cover`, with the input's Content-Type set from `file.type` or `application/octet-stream` as a fallback. Only the resulting candidate reference added to `coverArt.candidates` follows the normal deferred-until-Save path (via `markDirty`) — the file itself is already durably on disk by the time Save is clicked, since the legacy app's Apply step reads cover art from a disk path, not from proposal.json's in-memory shape.

### AS-CODE-REV-123 — A successfully uploaded manual cover is added as a new candidate labeled "manual upload" and auto-selected
Status: Draft | Source: legacy/ui/app.js:1032

### AS-CODE-REV-124 — Manual cover upload status text cycles through "Uploading...", a success message prompting Save, or a failure message
Status: Draft | Source: legacy/ui/app.js:1023

Success text: `"Uploaded - click Save to keep this selection."`; failure text: `"Upload failed: {message}"`.

### AS-CODE-REV-125 — Choosing the same file again later is allowed, because the file input is cleared right after reading it
Status: Draft | Source: legacy/ui/app.js:1014

`e.target.value = ''` runs immediately after grabbing `e.target.files[0]`, so a browser's "value unchanged" suppression of the `change` event doesn't block re-selecting the identical file name next time.

### AS-CODE-REV-126 — Selecting a Discogs candidate immediately calls the server and replaces the whole in-memory release with the server's recomputed result
Status: Draft | Source: legacy/ui/app.js:1047 › onSelectDiscogsCandidate

This POST happens immediately on click (not deferred to Save) and `Object.assign(release, updated)` overwrites every field the server returned (tracks, proposed names, coverArt, etc.) on the client's in-memory release object, then both the detail panel and sidebar are re-rendered. Status text shows "Loading tracklist for this edition...", then "Updated." or "Failed to load edition: {message}".

## Client: notes, approve/reject, and save

### AS-CODE-REV-127 — Approve and Reject checkboxes are mutually exclusive
Status: Draft | Source: legacy/ui/app.js:1071 › onToggleApprove / legacy/ui/app.js:1082 › onToggleReject

Checking Approve sets `humanReview.resolved = true` and, if Reject was checked, clears it (`rejected = false`) both in state and in the Reject checkbox's own UI. Checking Reject sets `humanReview.rejected = true` and also forces `humanReview.resolved = true` (reject is itself a completed review decision), clearing the Approve checkbox.

### AS-CODE-REV-128 — The Save button (top or bottom) always submits the entire proposal document, not just the dirty release(s)
Status: Draft | Source: legacy/ui/app.js:1093 › saveProposal

`PUT /api/sessions/{id}/proposal` is called with `JSON.stringify(state.proposal, null, 2)` — the whole in-memory proposal — every time Save is clicked, regardless of how many releases are actually marked dirty.

### AS-CODE-REV-129 — A successful save clears every dirty marker at once and re-renders the list; a failed save leaves dirty state untouched
Status: Draft | Source: legacy/ui/app.js:1093 › saveProposal

On success: `state.dirtyReleaseKeys.clear()`, indicator and list re-rendered, status text `"Saved at {localeTimeString}"`. On failure: status text `"Save failed: {message}"`, and no dirty state is cleared, so the unsaved-count badges stay as they were.

### AS-CODE-REV-130 — The unsaved-change count is shown in two places and always kept in sync
Status: Draft | Source: legacy/ui/app.js:836 › updateSaveIndicator

Text is `"{n} unsaved change"` (singular for n=1) or `"{n} unsaved changes"`, mirrored into both `#unsaved-count-top` and `#unsaved-count`; empty string when there are no dirty releases.

### AS-CODE-REV-131 — Closing or navigating away from the page is intercepted only when there are unsaved changes
Status: Draft | Source: legacy/ui/app.js:1110

A `beforeunload` listener calls `e.preventDefault()` and sets `e.returnValue = ''` (triggering the browser's native "leave site?" prompt) only if `isDirty()`.

## Client: lossy tracker view

### AS-CODE-REV-132 — Switching to the Lossy tracker tab always re-fetches the ledger from the server
Status: Draft | Source: legacy/ui/app.js:110 › switchView

`switchView('lossy')` unconditionally calls `loadLossyLedger()`, even if the ledger was already loaded earlier in the session.

### AS-CODE-REV-133 — The view switch for the Releases pane uses an inline style, not the hidden attribute, due to a CSS specificity conflict
Status: Draft | Source: legacy/ui/app.js:110

`#main-layout` has its own `display: flex` rule by ID selector in styles.css (needed for its two-pane layout), which would otherwise outrank the `[hidden]` attribute's default `display: none` — so switching views sets `#main-layout.style.display` directly (`'flex'`/`'none'`) instead of toggling `hidden` on it, while `#lossy-view` (no such conflicting rule) is toggled with the plain `hidden` attribute.

### AS-CODE-REV-134 — The status filter dropdown filters the already-loaded ledger client-side only
Status: Draft | Source: legacy/ui/app.js:1131 › getFilteredLossyEntries

Options are "All" (empty value), `pending-upgrade`, `upgraded`, `ignored`; changing the dropdown re-renders the existing in-memory entries, with no new network request.

### AS-CODE-REV-135 — Status and Notes edits in the lossy table save immediately, with no separate Save button
Status: Draft | Source: legacy/ui/app.js:1202 › onLossyRowChange

Changing the Status `<select>` (on `change`) or the Notes input (on `change`, i.e. on blur/Enter, not every keystroke) immediately PUTs `{ status, notes, ...changedField }` to `/api/lossy/{stableKey}`, merging the one changed field over the entry's current status/notes. On success the row is updated from the server's response and status text shows `"Saved at {time}"`; on failure, `"Save failed: {message}"`.

### AS-CODE-REV-136 — Deleting a lossy entry requires a confirmation naming the artist and album, and warns it cannot be undone
Status: Draft | Source: legacy/ui/app.js:1219 › onLossyRowDelete

Prompt text: `Permanently remove the lossy-tracking entry for "{artist} - {album}"? This cannot be undone.` Declining leaves the entry untouched; confirming calls `DELETE /api/lossy/{stableKey}` and removes it from the in-memory list on success.

### AS-CODE-REV-137 — CSV export columns are a fixed, specific list and order
Status: Draft | Source: legacy/ui/app.js:1261 › exportLossyLedger

Columns: `stableKey, artist, album, year, format, status, targetPath, firstDetectedUtc, lastCheckedUtc, upgradedUtc, notes` — note `upgradedUtc` is exported even though it is not a visible table column.

### AS-CODE-REV-138 — CSV values are quoted only when they contain a comma, quote, or newline; embedded quotes are doubled
Status: Draft | Source: legacy/ui/app.js:1246 › toCsvValue

Example: a notes value of `Cracked, re-ripped "v2"` becomes `"Cracked, re-ripped ""v2"""` in the CSV.

### AS-CODE-REV-139 — Both CSV and JSON export respect the currently active status filter, not the full ledger
Status: Draft | Source: legacy/ui/app.js:1252 › exportLossyLedger

`getFilteredLossyEntries()` (the same filtered set the table is showing) is what gets exported, not `state.lossy.entries` unfiltered.

### AS-CODE-REV-140 — Export file names embed an ISO timestamp with colons and dots replaced by hyphens
Status: Draft | Source: legacy/ui/app.js:1254

Example: `lossy-tracking-2026-10-10T14-05-32-123Z.csv` (illustration). Download is triggered via a synthetic `<a download>` click against a `Blob` object URL, which is revoked immediately after.

### AS-CODE-REV-141 — Naming templates are fetched once; a failure keeps hardcoded client defaults silently
Status: Draft | Source: legacy/ui/app.js:1269 › loadNamingTemplates

Default values if the fetch fails: `releaseFolder: '{year} {album}'`, `trackFile: '{trackNumber} {title}'`, `trackNumberPadWidth: 2`. Failure is only logged to the console; the folder-name live-preview feature (REV-102) simply may be out of sync with a non-default server template rather than the page showing any error.

## Client/markup: panel visibility states

### AS-CODE-REV-142 — Six page regions are hidden by default in the HTML and only shown by script in response to state
Status: Draft | Source: legacy/ui/index.html:12

`#retry-btn` (shown on a load error), `#session-history` (shown once ≥2 sessions exist), `#unrecognized-panel` (shown when an unrecognized entry is selected), `#detail-panel` (shown when a release is selected), `#discogs-candidates` (shown when the selected release's match is ambiguous), and `#lossy-view` (shown when the Lossy tracker tab is active) all carry the `hidden` attribute in the markup and are only unhidden by app.js.

## CSS: layout and visually-driven behavior

### AS-CODE-REV-143 — There are no responsive/mobile layout rules anywhere in styles.css
Status: Draft | Source: legacy/ui/styles.css (whole file)

The stylesheet contains no `@media` queries at all; the two-pane desktop layout (fixed 320px sidebar + flexible detail pane, `#main-layout { height: calc(100vh - 100px) }`) is the only layout, with no narrower-viewport behavior.

### AS-CODE-REV-144 — The release sidebar and detail pane scroll independently
Status: Draft | Source: legacy/ui/styles.css:63

`#main-layout` is a fixed-height flex row; `#release-list` (320px wide) and `#detail-panel`/`#unrecognized-panel` each have their own `overflow-y: auto`, so scrolling the release list does not scroll the detail pane and vice versa.

### AS-CODE-REV-145 — The selected cover candidate is highlighted purely in CSS via :has(), with no JS class toggle
Status: Draft | Source: legacy/ui/styles.css:244

`.cover-candidate:has(input:checked) img { border-color: #1a73e8; }` draws a blue border around whichever cover thumbnail's radio input is checked, driven entirely by the browser's native `:has()` relational selector rather than a class app.js adds/removes.

### AS-CODE-REV-146 — The full-size cover modal is capped to 90% of the viewport in both dimensions and dims the page behind it natively
Status: Draft | Source: legacy/ui/styles.css:285

`#cover-modal img { max-width: 90vw; max-height: 90vh; }` with `#cover-modal::backdrop { background: rgba(0,0,0,0.7); }` — both are native `<dialog>` element behaviors (`showModal()`), not custom-built overlay code.

### AS-CODE-REV-147 — A companion row with an active warning is visually distinguished by a light red row background
Status: Draft | Source: legacy/ui/styles.css:199

`.companion-row-warning td { background: #fff3f3; }` applies whenever `refreshCompanionWarnings` (REV-112) finds a problem with that row.

### AS-CODE-REV-148 — Status badges are colored per status, and the "unrecognized" badge reuses a neutral gray not shared with any release status
Status: Draft | Source: legacy/ui/styles.css:105

`badge-ready` green (#2e7d32), `badge-needsReview` amber (#f9a825), `badge-ambiguous` red (#c62828), `badge-rejected` gray (#757575), `badge-unrecognized` darker gray (#616161) — five visually distinct states total across releases and unrecognized entries.

## Suspected defects

### AS-CODE-DEF-REV-001 — Manual-cover upload size limit (20 MB) is hard-coded independently in two places
legacy/scripts/common/Reshelf.UiServer.psm1:333 (`$script:ReshelfUiManualCoverMaxBytes = 20MB`) and legacy/scripts/Start-ReshelfUiServer.ps1:77 (`[long]$MaxBytes = 20MB` default parameter on `Read-ReshelfUiRequestBodyBytes`). Since the HTTP-layer call site never overrides that default, the module-level check in `Save-ReshelfUiManualCoverFile` (REV-052) can never actually trigger via the real upload path — the request body is already rejected at the earlier, independently-maintained limit first. If either literal is changed without the other, the two checks silently diverge.

### AS-CODE-DEF-REV-002 — GET /api/current-session and GET /api/sessions/{id}/proposal expose the same proposal.json differently
legacy/scripts/Start-ReshelfUiServer.ps1:112 (CurrentSession: parses then re-serializes the proposal with `ConvertFrom-Json`/`ConvertTo-Json -Depth 20`) versus legacy/scripts/Start-ReshelfUiServer.ps1:130 (GetProposal: writes the raw file content through unchanged). The same underlying file can come back with different formatting (and potentially different number precision/property order) depending on which endpoint the client happens to call.

### AS-CODE-DEF-REV-003 — LocalFile handler reports every failure as HTTP 403, including "file no longer exists"
legacy/scripts/Start-ReshelfUiServer.ps1:216. A genuinely missing file (`Get-ReshelfUiLocalFileBytes` throwing "File '...' no longer exists.") is reported as 403 Forbidden rather than 404 Not Found, conflating an access-control failure with a simple not-found condition.

### AS-CODE-DEF-REV-004 — DeleteLossy handler reports every failure as HTTP 404, including non-"not found" errors
legacy/scripts/Start-ReshelfUiServer.ps1:272. Any exception from `Remove-ReshelfLossyTrackingEntry` (e.g. a file lock or disk I/O error, not just "no such entry") is reported to the client as 404 Not Found.

### AS-CODE-DEF-REV-005 — Stale comment claims the client's safe-filename sanitizer skips reserved-device-name handling, but the code does include it
legacy/ui/app.js:846-847 (comment on `deriveProposedFolderNames`) says `toSafeFileName` "doesn't reproduce the reserved-device-name suffixing, which 'propose' still applies for real on Save," but the actual `toSafeFileName` implementation at legacy/ui/app.js:933-936 does append `_` for a name matching a reserved Windows device name (CON, PRN, AUX, NUL, COM1-9, LPT1-9). The comment appears to predate that addition and is now misleading about actual behavior.

### AS-CODE-DEF-REV-006 — Release notes textarea has no null-safety fallback, unlike the equivalent lossy-notes field elsewhere in the same file
legacy/ui/app.js:391 (`notesField.value = release.humanReview.notes;`) assigns the field directly with no `?? ''` fallback, while the lossy-tracker edit path a few hundred lines later (legacy/ui/app.js:1204, `notes: entry.notes ?? ''`) treats a null notes value defensively. If `humanReview.notes` is ever `null` (e.g. a release that was never reviewed), the textarea would display the literal text "null" instead of being empty.

### AS-CODE-DEF-REV-007 — An unsupported HTTP method on a recognized API path is served as a generic static-file 404 instead of a clear API error
legacy/scripts/common/Reshelf.UiServer.psm1:100-153 (`Get-ReshelfUiApiRoute`): for both `/api/sessions/{id}/proposal` (GET/PUT only) and `/api/lossy/{stableKey}` (PUT/DELETE only), any other method matches the path's regex, passes the session-id/stable-key validation, but then falls through every method-specific `if` with no action returned — the function returns `$null` for that method, and the request ends up handled as if it were a static-file lookup, returning `404 Not found: /api/sessions/...` instead of a 405 Method Not Allowed or a clearer 400.

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 0.1 | 2026-10-10 | Phase 2 draft from code. |
