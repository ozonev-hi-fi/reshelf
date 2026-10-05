# 09 — Review UI (as-is, from docs and tests)

Status: Draft | Version: 0.1 | Last updated: 2026-10-05

## Scope

The local UI server, its HTTP API, and the review page in the browser. Also the optional "mark reviewed" step. Owned inputs: the Playwright suite `legacy/tests/ui/specs/*.spec.js` and its helpers (`seed-session.ps1`, `global-setup.js`, `helpers.js`, `playwright.config.js`), `legacy/tests/Reshelf.UiServer.Tests.ps1`, `legacy/plan/07-editing-ui-module.md`, and the `legacy/README.md` sections "3. Review in the browser" (without "Compilations") and "4. Mark reviewed (optional)". The `ui start` command itself is in [12-cli.md](12-cli.md).

Test data used in the examples: every UI test seeds one session for artist `Aurora Fields` with four releases (see [12-cli.md](12-cli.md), AS-DOC-CLI-038):

| Seed name | Album (a random suffix follows) | Year | State |
|---|---|---|---|
| rich | `Departure Songs` | 2016 | ambiguous Discogs match, 2 tracks, 3 cover candidates, 3 companions, 2 ignored files |
| minimal | `Quiet Interlude` | 2018 | `needsReview: true` (`no-track-number`), matched, 1 track, 1 cover |
| empty | `Bare Sessions` | 2020 | matched, resolved, no covers, no companions |
| compilation | `Best Of Everywhere` | 2008 | Album Artist `Various`, tracks by `First Act` / `Second Act` |

## UI server

### AS-DOC-REV-001 — The server is local, single-user, without authentication
Status: Draft | Source: legacy/plan/07-editing-ui-module.md › Server-side persistence; legacy/plan/07-editing-ui-module.md › Decisions & rationale

The UI server runs on `localhost` for one user. It has no login and no access control of its own. The server, not the browser, reads and writes files on disk. The browser only talks to the server with `fetch()`, so any modern browser works.

Example: the page loads `proposal.json` through `GET /api/current-session`. The browser never asks for a folder or a file permission.

### AS-DOC-REV-002 — The server handles one request at a time
Status: Draft | Source: legacy/tests/ui/playwright.config.js › (top comment, `workers: 1`)

The server is a single-threaded loop. It handles one request, then the next. Parallel requests wait in a queue.

Example: the Playwright suite runs with `workers: 1` because parallel workers would only queue behind each other.

### AS-DOC-REV-003 — The root path serves index.html
Status: Draft | Source: legacy/tests/Reshelf.UiServer.Tests.ps1 › Resolve-ReshelfUiRequestPath › maps the root request to index.html; … › maps an empty request path to index.html

A request for `/` or for an empty path returns the file `index.html` from the UI folder.

Example: `GET /` → `index.html`. Request path `''` → `index.html`.

### AS-DOC-REV-004 — Other paths serve files from the UI folder
Status: Draft | Source: legacy/tests/Reshelf.UiServer.Tests.ps1 › Resolve-ReshelfUiRequestPath › resolves a top-level file request; … › resolves a nested file request; … › returns null for a missing file

A non-API path maps to a file inside the UI folder, also in subfolders. A path to a file that does not exist returns no file.

Example: `/app.js` → `app.js`. `/nested/thing.css` → `nested\thing.css`. `/does-not-exist.html` → nothing is served.

### AS-DOC-REV-005 — Static files outside the UI folder are refused
Status: Draft | Source: legacy/tests/Reshelf.UiServer.Tests.ps1 › Resolve-ReshelfUiRequestPath › returns null for a path-traversal attempt outside the ui root

A path that leads outside the UI folder (path traversal) returns no file.

Example: the UI folder has a sibling folder with `secret.txt`. `/../<sibling>/secret.txt` → nothing is served.

### AS-DOC-REV-006 — The content type comes from the file extension
Status: Draft | Source: legacy/tests/Reshelf.UiServer.Tests.ps1 › Get-ReshelfUiMimeType › maps <Extension> to <Expected>

The server sets the MIME type by the file extension. An unknown extension gets `application/octet-stream`.

Example:

| File | Content type |
|---|---|
| `index.html` | `text/html` |
| `app.js` | `text/javascript` |
| `styles.css` | `text/css` |
| `data.json` | `application/json` |
| `cover.png` | `image/png` |
| `cover.jpg` | `image/jpeg` |
| `cover.svg` | `image/svg+xml` |
| `unknown.bin` | `application/octet-stream` |

## HTTP API: routing

### AS-DOC-REV-007 — API routes
Status: Draft | Source: legacy/tests/Reshelf.UiServer.Tests.ps1 › Get-ReshelfUiApiRoute › (all `routes …` tests); legacy/plan/07-editing-ui-module.md › Server-side persistence

The server answers these routes under `/api/`. Everything else is a static file request.

| Method | Route | Purpose |
|---|---|---|
| GET | `/api/current-session` | The session to load, with its proposal |
| GET | `/api/sessions` | All sessions, for the "Past sessions" list |
| GET | `/api/sessions/{id}/proposal` | Read one session's `proposal.json` |
| PUT | `/api/sessions/{id}/proposal` | Save one session's `proposal.json` |
| GET | `/api/sessions/{id}/local-file?path=…` | Serve one local cover image |
| POST | `/api/sessions/{id}/manual-cover` | Upload a cover image |
| POST | `/api/sessions/{id}/proposal/releases/{stableKey}/discogs-selection` | Pick a Discogs candidate for one release |
| GET | `/api/naming-templates` | Naming templates for the live preview |
| GET | `/api/lossy` | The lossy-tracking ledger |
| PUT | `/api/lossy/{stableKey}` | Update one ledger entry |
| DELETE | `/api/lossy/{stableKey}` | Remove one ledger entry |

Example: `GET /api/sessions/2026-09-25-0001/proposal` → read proposal of session `2026-09-25-0001`. `PUT /api/lossy/a1b2c3d4e5f60708` → update ledger entry `a1b2c3d4e5f60708`.

### AS-DOC-REV-008 — A session id must have the shape yyyy-MM-dd-NNNN
Status: Draft | Source: legacy/tests/Reshelf.UiServer.Tests.ps1 › Get-ReshelfUiApiRoute › rejects a session id that does not match the real yyyy-mm-dd-nnnn shape; … › rejects an invalid session id on the discogs-selection path; legacy/plan/07-editing-ui-module.md › Decisions & rationale

On every `/api/sessions/{id}/…` route, the server checks the session id against the `yyyy-MM-dd-NNNN` shape before it touches the disk. A wrong id gets a "bad request" answer.

Example: `GET /api/sessions/not-a-real-session-id/proposal` → bad request. `POST /api/sessions/not-a-real-session-id/proposal/releases/a1b2c3d4e5f60708/discogs-selection` → bad request.

### AS-DOC-REV-009 — A stable key in a route must be 16 lowercase hex characters
Status: Draft | Source: legacy/tests/Reshelf.UiServer.Tests.ps1 › Get-ReshelfUiApiRoute › returns $null for a lossy stable key that is not 16 lowercase hex characters; … › returns $null for a discogs-selection stable key that is not 16 lowercase hex characters

On the lossy routes and the discogs-selection route, a stable key that is not 16 lowercase hex characters does not match any API route. The request goes to static file serving instead (it is not a "bad request").

Example: `PUT /api/lossy/not-a-real-key` → no API route. `POST /api/sessions/2026-09-25-0001/proposal/releases/not-a-real-key/discogs-selection` → no API route.

### AS-DOC-REV-010 — An unknown method or path falls through to static files
Status: Draft | Source: legacy/tests/Reshelf.UiServer.Tests.ps1 › Get-ReshelfUiApiRoute › returns $null for an unsupported verb on a known path; … › returns $null for GET on the manual-cover path; … › returns $null for GET on the lossy stable-key path (no such route); … › returns $null for GET on the discogs-selection path (no such route); … › returns $null for a plain static-file request, so it falls through to file serving; … › falls through to static-file serving for a multi-segment path traversal attempt

A request that matches no method + route pair is not an API call. The server treats it as a static file request. There is no "method not allowed" answer.

Example: `DELETE /api/sessions/2026-09-25-0001/proposal` → static file serving. `GET /api/lossy/a1b2c3d4e5f60708` → static file serving. `GET /api/sessions/../../secret/proposal` → static file serving, where AS-DOC-REV-005 refuses it.

## HTTP API: sessions and proposals

### AS-DOC-REV-011 — The sessions list shows every session and whether it has a proposal
Status: Draft | Source: legacy/tests/Reshelf.UiServer.Tests.ps1 › Get-ReshelfUiSessionsSummary / Get-ReshelfUiCurrentSession › reports hasProposal true only for a session with an on-disk proposal.json; … › returns an empty list when no sessions exist yet; legacy/plan/07-editing-ui-module.md › Server-side persistence

`GET /api/sessions` returns every session with its source root, stage, updated date and a `hasProposal` flag. `hasProposal` is true only when `proposal.json` exists on disk. With no sessions, the list is empty.

Example: session `D:\A` (stage `recognized`) → `hasProposal: false`. Session `D:\B` (stage `proposed`, with `proposal.json`) → `hasProposal: true`.

### AS-DOC-REV-012 — The current session is the newest one that has a proposal
Status: Draft | Source: legacy/tests/Reshelf.UiServer.Tests.ps1 › Get-ReshelfUiSessionsSummary / Get-ReshelfUiCurrentSession › picks the most recently updated session that has a proposal, ignoring a newer one without; … › returns $null when no session has a proposal yet; legacy/plan/07-editing-ui-module.md › Server-side persistence

`GET /api/current-session` picks the session with the newest `updatedAtUtc` among the sessions that have a `proposal.json`. The stage does not matter. The answer includes the proposal content. When no session has a proposal, the answer is `{found: false, message}`.

Example: `D:\Older` (with proposal, updated `2026-01-01T00:00:00.000Z`) and `D:\NewerNoProposal` (no proposal, updated `2026-06-01T00:00:00.000Z`) → the current session is `D:\Older`.

### AS-DOC-REV-013 — Reading a proposal returns the file content as it is on disk
Status: Draft | Source: legacy/tests/Reshelf.UiServer.Tests.ps1 › Get-ReshelfUiProposalContent / Save-ReshelfUiProposalContent › reads back the exact on-disk proposal.json content; … › throws a clear error for a session with no proposal.json

`GET /api/sessions/{id}/proposal` returns the exact content of that session's `proposal.json`. For a session without `proposal.json`, the server answers with an error that says there is "no proposal.json".

Example: the proposal has artist `Some Artist` → the answer has `artists[0].recognizedName = "Some Artist"`. A `recognized` session without a proposal → error `…no proposal.json…`.

### AS-DOC-REV-014 — Saving refuses a body that is not valid JSON
Status: Draft | Source: legacy/tests/Reshelf.UiServer.Tests.ps1 › Get-ReshelfUiProposalContent / Save-ReshelfUiProposalContent › rejects an invalid JSON body without touching the existing file

`PUT /api/sessions/{id}/proposal` with a body that is not valid JSON fails with an error "not valid JSON". The existing `proposal.json` stays unchanged.

Example: body `not json` → error `…not valid JSON…`; `proposal.json` still has `Some Artist`.

### AS-DOC-REV-015 — Saving keeps one backup of the previous proposal
Status: Draft | Source: legacy/tests/Reshelf.UiServer.Tests.ps1 › Get-ReshelfUiProposalContent / Save-ReshelfUiProposalContent › writes a rolling backup of the previous content before saving new content; legacy/plan/07-editing-ui-module.md › Save behavior; legacy/README.md › 3. Review in the browser

Before the server writes the new content, it copies the current `proposal.json` to `proposal.backup.json` in the same session folder. Only one previous version is kept. The server then writes the body as it was sent. It checks only that the body is valid JSON.

Example: `proposal.json` has `Some Artist`. Save body `{"artists":[]}` → `proposal.backup.json` has `Some Artist`; `proposal.json` has 0 artists.

### AS-DOC-REV-016 — The local-file route serves only known cover files
Status: Draft | Source: legacy/tests/Reshelf.UiServer.Tests.ps1 › Get-ReshelfUiLocalFileBytes › serves a path the session proposal already names as a cover candidate; … › serves a file under manual-covers even though it is not yet a named proposal.json candidate; legacy/tests/ui/specs/covers.spec.js › cover art › a local cover candidate is served through /api/.../local-file, a remote-style URL is left untouched

`GET /api/sessions/{id}/local-file?path=<absolute path>` returns the bytes of a local file in two cases: the path is a cover candidate URL in the session's on-disk `proposal.json`, or the file is inside the session's `manual-covers` folder. The content type follows the extension (AS-DOC-REV-006).

Example: candidate `…\<guid>.jpg` in `proposal.json` → bytes `fake-jpeg-bytes`, type `image/jpeg`. `<dataHome>\sessions\<id>\manual-covers\abc123.jpg` (not in `proposal.json`) → bytes `fake-manual-cover-bytes`.

### AS-DOC-REV-017 — The local-file route refuses any other path
Status: Draft | Source: legacy/tests/Reshelf.UiServer.Tests.ps1 › Get-ReshelfUiLocalFileBytes › refuses a path that is not one of the session's known cover candidates; legacy/plan/07-editing-ui-module.md › Edge cases

A path that is not a known cover candidate and not in `manual-covers` is refused with the error "not a known local cover file". The plan says the answer is HTTP 403. The plan also says a candidate path that no longer exists is refused.

Example: `…\not-referenced.jpg` (exists, but not in the proposal) → error `…not a known local cover file…`.

### AS-DOC-REV-018 — A manual cover upload is saved at once in the session's manual-covers folder
Status: Draft | Source: legacy/tests/Reshelf.UiServer.Tests.ps1 › Save-ReshelfUiManualCoverFile › saves a valid upload under manual-covers with its real pixel dimensions

`POST /api/sessions/{id}/manual-cover` writes the uploaded image into `<dataHome>\sessions\<id>\manual-covers\`. The server decodes the image and answers with the file path (`Url`) and the real pixel `Width` and `Height`. The session does not need a proposal for this.

Example: a 1×1 PNG `front.png` for a `recognized` session → `Width: 1`, `Height: 1`, `Url` under `…\manual-covers\`, and the file exists.

### AS-DOC-REV-019 — A manual cover upload must be a non-empty JPG or PNG of at most 20 MB, for a known session
Status: Draft | Source: legacy/tests/Reshelf.UiServer.Tests.ps1 › Save-ReshelfUiManualCoverFile › rejects an unsupported file extension; … › rejects an empty upload; … › rejects an upload over the size limit; … › rejects an unknown session id; legacy/README.md › 3. Review in the browser

The server refuses an upload in these cases:

| Case | Error text contains |
|---|---|
| Extension is not JPG/PNG | `Unsupported image type` |
| Zero bytes | `empty` |
| More than 20 MB | `20 MB limit` |
| Session does not exist | `not found` |

Example: `front.gif` → `Unsupported image type`. A 21 MB `front.png` → `20 MB limit`. Session `2026-01-01-9999` → `not found`.

### AS-DOC-REV-020 — An upload that is not a readable image is deleted again
Status: Draft | Source: legacy/tests/Reshelf.UiServer.Tests.ps1 › Save-ReshelfUiManualCoverFile › deletes the written file and throws when the uploaded bytes are not a readable image

When the uploaded bytes cannot be decoded as an image, the server deletes the file it wrote and fails with "not a readable image". The `manual-covers` folder stays empty.

Example: `front.png` with the bytes `not actually a png` → error `…not a readable image…`; no file in `manual-covers`.

### AS-DOC-REV-021 — The page loads the naming templates once
Status: Draft | Source: legacy/plan/07-editing-ui-module.md › Server-side persistence; legacy/plan/07-editing-ui-module.md › Live folder-name preview

`GET /api/naming-templates` returns `namingTemplates` and `trackNumberPadWidth` from `settings.json`. The page fetches them once when it loads. It uses them for the live folder-name preview (AS-DOC-REV-034). The template rules: see [03-settings-and-secrets.md](03-settings-and-secrets.md) and [02-text-and-naming-rules.md](02-text-and-naming-rules.md).

Example: default templates `{year} {album}` and `{trackNumber} {title}` → the preview for Album `Indigo Rose`, Year `2002` is `2002 Indigo Rose`.

## Page load and sessions

### AS-DOC-REV-022 — The page loads the current session with no click
Status: Draft | Source: legacy/tests/ui/specs/load-and-sessions.spec.js › loading and switching sessions › auto-loads the most recently updated session with a proposal, no folder picker or session id shown; legacy/README.md › 3. Review in the browser; legacy/plan/07-editing-ui-module.md › Server-side persistence

When the page opens, it loads the current session (AS-DOC-REV-012) at once. There is no file picker and no folder picker. The status text shows the session's source root. It does not show the session id.

Example: open `http://localhost:<port>/` after seeding → `#session-status` contains `<sourceRoot>\load-auto-<suffix>\Aurora Fields`, does not contain the session id, and the list has 4 release rows.

### AS-DOC-REV-023 — No session with a proposal gives a plain message
Status: Draft | Source: legacy/plan/07-editing-ui-module.md › Edge cases

When no session has a `proposal.json` yet (a fresh install, or only `recognize` ran), the page shows a plain status message. It is not an error.

Example: only a `recognized` session exists → the page shows the message from `{found: false, message}`.

### AS-DOC-REV-024 — A reload reads the session again from disk
Status: Draft | Source: legacy/tests/ui/specs/load-and-sessions.spec.js › loading and switching sessions › reload loads the same session again; legacy/plan/07-editing-ui-module.md › Edge cases

A page reload loads the same session again. The page reads `proposal.json` from the server each time it opens, so changes made outside the page show up after a reload.

Example: reload → `#session-status` still contains the same source folder, and the list still has 4 rows.

### AS-DOC-REV-025 — A separate header label shows the session id
Status: Draft | Source: legacy/plan/07-editing-ui-module.md › Server-side persistence

A small label `#session-id-label` in the header shows the raw session id. It is only for information, so the user can name the session. The main status text still does not show the id (AS-DOC-REV-022).

Example: `Session 2026-09-26-0002`.

### AS-DOC-REV-026 — The "Past sessions" dropdown lists sessions by source root, date and stage
Status: Draft | Source: legacy/tests/ui/specs/load-and-sessions.spec.js › loading and switching sessions › with 2+ sessions, the Past sessions dropdown lists both, labeled by source root + date + stage (never the raw session id); legacy/plan/07-editing-ui-module.md › Server-side persistence

When 2 or more sessions exist, the page shows a "Past sessions" dropdown (`#session-history`). Each option label has the source root, the date and the stage. No label has the session id. The list is newest first. The loaded session is the selected option. Picking another option loads that session.

Example: two seeded sessions, both in stage `reviewed` → two options, each with its own source folder and `reviewed`; the selected value is the newer session's id.

### AS-DOC-REV-027 — Switching sessions with unsaved changes asks first
Status: Draft | Source: legacy/tests/ui/specs/load-and-sessions.spec.js › loading and switching sessions › switching sessions with unsaved changes prompts a confirm; cancelling keeps the current session; legacy/tests/ui/specs/server-down.spec.js › server stopped mid-session › Save and a live session switch both show a visible error/retry message, not a silent failure

When the page has unsaved changes and the user picks another session, the browser shows a confirm dialog. Its text says there are unsaved changes. Cancel keeps the current session selected. OK continues the switch.

Example: edit `#field-album` to `Edited Album Name`, pick the older session → dialog text matches `unsaved`; Cancel → the dropdown value is still the current session id.

## Release list, badges and filters

### AS-DOC-REV-028 — The release list is grouped by artist
Status: Draft | Source: legacy/README.md › 3. Review in the browser; legacy/plan/07-editing-ui-module.md › UI shape

The list shows every release of the session, grouped by artist. Each release is one row with one status badge. A click on a row opens that release in the detail panel.

Example: the seeded session → one artist `Aurora Fields` with 4 release rows.

### AS-DOC-REV-029 — The badge shows the release's review status
Status: Draft | Source: legacy/tests/ui/specs/review-state.spec.js › review state: Discogs match, Approve, Reject › an ambiguous release shows the Discogs candidate picker and the "ambiguous" badge; picking a candidate resolves it; … › a release still needing review (not ambiguous, not yet approved) shows the "needsReview" badge; … › Approve and Reject are mutually exclusive, and the row badge reflects the current choice; legacy/README.md › 3. Review in the browser

Each release row has one badge. The first matching rule wins:

| Badge | When |
|---|---|
| `rejected` | Reject is ticked |
| `ambiguous` | The Discogs match is ambiguous and not yet resolved |
| `needsReview` | The release is flagged for review and not yet resolved |
| `ready` | Everything else, also releases that nobody flagged |

Unrecognized folders have their own badge (AS-DOC-REV-076).

Example: rich (ambiguous match and `needsReview: true`) → `ambiguous`. minimal (`needsReview: true`, matched) → `needsReview`. minimal after Approve → `ready`. After Reject → `rejected`.

### AS-DOC-REV-030 — Releases that propose did not flag are already reviewed
Status: Draft | Source: legacy/README.md › 3. Review in the browser

A release that `propose` did not flag is already marked as reviewed. The user does not need to tick Approve on it. A flagged release is applied only after the user ticks Approve (apply rules: see [10-apply.md](10-apply.md)).

Example: empty (`needsReview: false`, `humanReview.resolved: true`) → badge `ready` without any action.

### AS-DOC-REV-031 — Two filters narrow the list; together they show the union
Status: Draft | Source: legacy/tests/ui/specs/review-state.spec.js › review state: Discogs match, Approve, Reject › the "Needs review" and "Ambiguous" filters narrow the list on their own, and show the union when both are checked; legacy/README.md › 3. Review in the browser

The page has two filter checkboxes: `Needs review only` (`#filter-needs-review`) and `Ambiguous match only` (`#filter-ambiguous`). Each filter keeps only the rows with that badge. When both are ticked, the list shows rows that match either filter.

Example: `Needs review only` → minimal (`needsReview`) visible, rich (`ambiguous`) hidden. Both ticked → both visible. Only `Ambiguous match only` → rich visible, minimal hidden.

## Release fields and folder-name preview

### AS-DOC-REV-032 — The Before / After table shows source and proposed names
Status: Draft | Source: legacy/README.md › 3. Review in the browser; legacy/tests/ui/specs/folder-name-preview.spec.js › live folder name preview › editing Artist/Album/Year updates the Artist Folder/Release Folder fields and the After cell; legacy/tests/ui/specs/edit-and-save.spec.js › editing and saving › a track title edit updates the proposed file name in the Before/After table, preserving the numeric prefix

The Before / After table (`#before-after-table`) is read-only. Row 1 is the release folder: the source path, and the proposed `<Artist Folder>\<Release Folder>`. Each next row is one track: the source file name, and the proposed file name.

Example: row 1 After = `aoki takamasa\2002 Indigo Rose`. Row 2 After = `01 Renamed Opener.flac`.

### AS-DOC-REV-033 — The release fields
Status: Draft | Source: legacy/README.md › 3. Review in the browser; legacy/plan/07-editing-ui-module.md › UI shape; legacy/tests/ui/specs/folder-name-preview.spec.js › live folder name preview › (all tests)

The detail panel has these editable release fields: `Album Artist` (`#field-artist`), a `Compilation (Various Artists)` checkbox (`#field-compilation`), `Album` (`#field-album`), `Year` (`#field-year`), `Artist Folder Name` (`#field-artist-folder`) and `Release Folder Name` (`#field-release-folder`). An edit of `Album` is saved to the release's `proposed.album`.

Example: minimal, `Album` → `Quiet Interlude (Edited)`, Save → `proposed.album = "Quiet Interlude (Edited)"` in `proposal.json`.

### AS-DOC-REV-034 — Editing Album Artist, Album or Year updates the folder names live
Status: Draft | Source: legacy/tests/ui/specs/folder-name-preview.spec.js › live folder name preview › editing Artist/Album/Year updates the Artist Folder/Release Folder fields and the After cell; legacy/plan/07-editing-ui-module.md › Live folder-name preview; legacy/README.md › 3. Review in the browser

When the user edits Album Artist, Album or Year, the page computes Artist Folder Name and Release Folder Name again from the naming templates (AS-DOC-REV-021). It also updates the folder row of the Before / After table. No new `propose` run is needed.

Example: Album Artist `aoki takamasa`, Album `Indigo Rose`, Year `2002` → Artist Folder Name `aoki takamasa`, Release Folder Name `2002 Indigo Rose`, After cell `aoki takamasa\2002 Indigo Rose`.

### AS-DOC-REV-035 — The preview replaces invalid file-system characters
Status: Draft | Source: legacy/tests/ui/specs/folder-name-preview.spec.js › live folder name preview › invalid filesystem characters in Artist/Album are sanitized in the folder name preview; legacy/plan/07-editing-ui-module.md › Live folder-name preview

The preview replaces characters that are invalid in Windows file names, with the same substitution as the naming rules (see [02-text-and-naming-rules.md](02-text-and-naming-rules.md)). The preview does not add the suffix for reserved device names (for example `CON`).

Example: Album Artist `AC/DC` → Artist Folder Name `AC_DC`.

### AS-DOC-REV-036 — A hand edit of a folder name updates the After cell
Status: Draft | Source: legacy/tests/ui/specs/folder-name-preview.spec.js › live folder name preview › editing the Release Folder Name field by hand also updates the After cell; legacy/plan/07-editing-ui-module.md › Live folder-name preview

The user can type a folder name directly. The folder row of the Before / After table then shows the typed name.

Example: Release Folder Name `Custom Folder Name` → After cell contains `Custom Folder Name`.

### AS-DOC-REV-037 — A later Album Artist, Album or Year edit overwrites a hand-typed folder name
Status: Draft | Source: legacy/tests/ui/specs/folder-name-preview.spec.js › live folder name preview › a later Artist/Album/Year edit overwrites a hand-typed folder name; legacy/plan/07-editing-ui-module.md › Live folder-name preview; legacy/README.md › 3. Review in the browser

The page does not remember that a folder name was typed by hand. The next edit of Album Artist, Album or Year computes the folder name again and replaces the typed value.

Example: Release Folder Name `Custom Folder Name`, then Album `Another Album` → Release Folder Name is no longer `Custom Folder Name` and contains `Another Album`.

### AS-DOC-REV-038 — An empty Year blocks the whole apply run; 1900 means "year not fixed"
Status: Draft | Source: legacy/README.md › 3. Review in the browser

Related: AS-DOC-PRP-011 in [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md) (where the placeholder 1900 comes from).

The page lets the user save an empty Year. An empty Year fails validation in `apply` and stops the entire `apply` run, not only that release. The value `1900` is a placeholder: it means the year still needs fixing. Apply validation: see [10-apply.md](10-apply.md).

Example: one release with Year `` → `apply` for the whole session does not run.

## Track table

### AS-DOC-REV-039 — The track table has Disc, Track, Artist and Title per track
Status: Draft | Source: legacy/README.md › 3. Review in the browser; legacy/plan/07-editing-ui-module.md › UI shape; legacy/tests/ui/specs/edit-and-save.spec.js › editing and saving › a Track number edit updates the file-name number (missing track keeps its gap) and survives Save and reload

The track table (`#track-fields-table`) has one row per track with four editable fields: `Disc`, `Track` (number inputs), `Artist` and `Title` (text inputs).

Example: rich → two rows, titles `First Track` and `Second Track`, Disc `1`, Track `1` and `2`.

### AS-DOC-REV-040 — A Title edit renames the proposed file and keeps the number prefix
Status: Draft | Source: legacy/tests/ui/specs/edit-and-save.spec.js › editing and saving › a track title edit updates the proposed file name in the Before/After table, preserving the numeric prefix; legacy/README.md › 3. Review in the browser

When the user edits a track Title, the page changes that track's proposed file name. The `NN ` number prefix stays.

Example: rich, track 1 Title `Renamed Opener` → After `01 Renamed Opener.flac`.

### AS-DOC-REV-041 — A Track number edit renumbers the file name and keeps gaps
Status: Draft | Source: legacy/tests/ui/specs/edit-and-save.spec.js › editing and saving › a Track number edit updates the file-name number (missing track keeps its gap) and survives Save and reload; legacy/plan/07-editing-ui-module.md › Live track file-name preview

When the user edits a Disc or Track number, the page computes the proposed file names of every track in the release again. The file number follows the Track value, so a missing track keeps its gap. Save writes both the file names and the `Track` tags.

Example: rich, Track `2` and `3` (track 1 missing on the source) → `02 First Track.flac`, `03 Second Track.flac`. After Save: `proposedFileName` = `["02 First Track.flac","03 Second Track.flac"]`, `tags.track` = `[2,3]`; the same after reload.

### AS-DOC-REV-042 — On a multi-disc release, file numbers continue after the highest Track of earlier discs
Status: Draft | Source: legacy/tests/ui/specs/edit-and-save.spec.js › editing and saving › on a multi-disc release, a later disc's file numbers start after the highest Track of earlier discs; legacy/plan/07-editing-ui-module.md › Live track file-name preview

The file number is the disc offset plus the Track value. The page has no Discogs track counts per disc, so the size of a disc is its highest Track number. The `Track` tag itself restarts per disc (see [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md)).

Example: track A Disc 1 Track 1, track B Disc 2 Track 1 → `01 First Track.flac`, `02 Second Track.flac`. Then track A Track `3` → `03 First Track.flac`, `04 Second Track.flac`.

### AS-DOC-REV-043 — The file extension stays; older sessions are not renumbered on load
Status: Draft | Source: legacy/plan/07-editing-ui-module.md › Live track file-name preview

The renumbering keeps the file extension of the current proposed name. The page does not renumber a session that was saved before this rule existed. The names change only after the user types a Track value again in that release.

Example: proposed name `01 Track.flac`, Title `Renamed Opener` → `01 Renamed Opener.flac` (the `.flac` stays).

### AS-DOC-REV-044 — An Artist edit does not change the file name
Status: Draft | Source: legacy/README.md › 3. Review in the browser

Editing a track's Artist changes only the `Artist` tag. The proposed file name stays the same.

Example: compilation, track 1 Artist `Renamed Act` → file name stays `01 Track.flac`.

## Per-track Artist and Compilation flag

### AS-DOC-REV-045 — Each track shows its own Artist; the release shows Album Artist and the Compilation flag
Status: Draft | Source: legacy/tests/ui/specs/track-artist.spec.js › per-track Artist and Compilation flag › the track table shows each track's own Artist, and Album Artist/Compilation reflect the release; legacy/README.md › 3. Review in the browser; legacy/plan/07-editing-ui-module.md › UI shape

The track Artist field shows the track's own `Artist` tag. By default it is the Album Artist. On a compilation it can differ per track. How `propose` fills it: see [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md).

Example: compilation → Album Artist `Various`, Compilation ticked, track Artists `First Act` and `Second Act`.

### AS-DOC-REV-046 — Editing one track's Artist changes only that track
Status: Draft | Source: legacy/tests/ui/specs/track-artist.spec.js › per-track Artist and Compilation flag › editing one track's Artist saves only that track, leaving the other and Album Artist unchanged

A track Artist edit changes the `Artist` tag of that track only. Other tracks and the Album Artist stay the same.

Example: compilation, track 1 Artist `Renamed Act`, Save → track 1 `artist = "Renamed Act"`, track 2 `artist = "Second Act"`, both `albumArtist = "Various"`; the same after reload.

### AS-DOC-REV-047 — An Album Artist edit updates a track's Artist only when it equalled the old Album Artist
Status: Draft | Source: legacy/tests/ui/specs/track-artist.spec.js › per-track Artist and Compilation flag › editing Album Artist keeps each track's own custom Artist unchanged; legacy/README.md › 3. Review in the browser; legacy/plan/07-editing-ui-module.md › Live folder-name preview

An Album Artist edit sets the `Album Artist` tag of every track. A track's `Artist` follows the new value only when it was equal to the old Album Artist. A track with its own Artist (from Discogs, or typed by hand) keeps it.

Example: compilation, Album Artist `Various` → `VA`, Save → both tracks `albumArtist = "VA"`, Artists stay `First Act` and `Second Act`.

### AS-DOC-REV-048 — Unticking Compilation clears the flag on the release and on every track
Status: Draft | Source: legacy/tests/ui/specs/track-artist.spec.js › per-track Artist and Compilation flag › unchecking Compilation clears isCompilation on the release and every track

The Compilation checkbox sets one value for the release and for all its tracks.

Example: compilation, untick Compilation, Save → `proposed.isCompilation = false`, `tracks[0].tags.isCompilation = false`, `tracks[1].tags.isCompilation = false`.

### AS-DOC-REV-049 — An empty track Artist falls back to Album Artist when the field loses focus
Status: Draft | Source: legacy/tests/ui/specs/track-artist.spec.js › per-track Artist and Compilation flag › clearing a track's Artist field falls back to Album Artist on blur

When the user clears a track Artist and leaves the field (blur), the field gets the Album Artist value. Typing alone does not do this.

Example: compilation, track 1 Artist `` → focus `Album` → track 1 Artist = `Various`.

## Other files (companions)

### AS-DOC-REV-050 — The Other files table lists companions and ignored files
Status: Draft | Source: legacy/tests/ui/specs/companions.spec.js › companion (other) files › shows one row per companion with Include/Before/Kind, and one row per ignored file, greyed out with its reason; legacy/README.md › 3. Review in the browser; legacy/plan/07-editing-ui-module.md › UI shape

The Other files table (`#companion-table`) has one row per companion file with an `Include` checkbox, the `Before` path (relative to the release folder), the `Kind`, and the target name. Each ignored file (playlist, unused `.cue`) has its own greyed-out, read-only row with the text `Not copied: <reason>`. An ignored file cannot be included.

Example: rich → 3 companion rows (`Scans\inner.jpg` `photo`, `01 back.jpg` `booklet`, `02 extra.jpg` `other`) and 2 ignored rows `Not copied: playlist-file`, `Not copied: cue-sheet-not-used`.

### AS-DOC-REV-051 — A nested companion keeps its path; a loose companion has an editable name
Status: Draft | Source: legacy/tests/ui/specs/companions.spec.js › companion (other) files › a nested companion is name-locked (plain text, same relative path); a loose companion has an editable, pre-filled After field; legacy/README.md › 3. Review in the browser; legacy/plan/07-editing-ui-module.md › UI shape

A nested companion (in a subfolder of the release) shows its target name as plain text, the same relative path. The user can only include or exclude it. A loose companion (directly in the release folder) has a text field with the proposed name from `propose`.

Example: nested `Scans\inner.jpg` → plain text `Scans\inner.jpg`, no input. Loose `01 back.jpg` → input with `Booklet 01 back.jpg`.

### AS-DOC-REV-052 — A loose companion without a proposed name gets its original name and marks the release unsaved
Status: Draft | Source: legacy/tests/ui/specs/companions.spec.js › companion (other) files › a loose companion with no proposedFileName yet is backfilled with its original name (not left empty) and marks the release dirty; legacy/plan/07-editing-ui-module.md › UI shape

When a loose companion has no `proposedFileName` (an older `proposal.json`), the page fills the field with the original file name. This change marks the release as unsaved, so the next Save stores it.

Example: `02 extra.jpg` with `proposedFileName: null` → field `02 extra.jpg`, warning `Must start with a letter.` (not `Name is required.`), release row has the unsaved mark.

### AS-DOC-REV-053 — Editing a loose companion name marks the release unsaved
Status: Draft | Source: legacy/tests/ui/specs/companions.spec.js › companion (other) files › editing a loose companion name keeps focus while typing and marks the release dirty

The user can type a new loose companion name. The field keeps focus while the user types. The release gets the unsaved mark.

Example: `Booklet 01 back.jpg` → `Booklet Back Cover.jpg` → the field shows the full new name; the row is unsaved.

### AS-DOC-REV-054 — Inline warnings on a loose companion name do not block Save
Status: Draft | Source: legacy/tests/ui/specs/companions.spec.js › companion (other) files › clearing a loose name, or one starting with a digit/symbol, shows an inline warning that does not block saving; … › a loose name matching another included companion's name shows a collision warning; legacy/plan/07-editing-ui-module.md › UI shape

The page shows an inline warning under a loose companion name with a problem. Save stays enabled. The same checks run in `apply` (see [10-apply.md](10-apply.md)).

| Problem | Warning text |
|---|---|
| Empty name | `Name is required.` |
| Does not start with a letter | `Must start with a letter.` |
| Same name as another included companion | `Same name as another included file.` |
| Same name as a track file | `Same name as a track file.` |

The track-name warning cannot appear through normal edits: a track name always starts with its number, and a companion name that starts with a number already gets `Must start with a letter.`

Example: `` → `Name is required.`. `1 test.jpg` → `Must start with a letter.`. Two loose names `Same Extra.jpg` → second row `Same name as another included file.`. `#save-btn` stays enabled.

### AS-DOC-REV-055 — An excluded companion shows no warning
Status: Draft | Source: legacy/tests/ui/specs/companions.spec.js › companion (other) files › unchecking Include suppresses the warning even with a bad name; re-checking brings it back

When the user unticks `Include`, the warning of that row is hidden. When the user ticks it again, the warning comes back.

Example: name `1 bad name.jpg` → `Must start with a letter.`; untick Include → no warning; tick → `Must start with a letter.`.

### AS-DOC-REV-056 — A release with no other files shows "No other files"
Status: Draft | Source: legacy/tests/ui/specs/companions.spec.js › companion (other) files › a release with no companion or ignored files shows "No other files" instead of the table

When a release has no companion files and no ignored files, the table is hidden. The page shows the text `No other files` (`#companion-empty`).

Example: minimal → `No other files`.

### AS-DOC-REV-057 — Saved companion choices are what apply copies
Status: Draft | Source: legacy/tests/ui/specs/companions.spec.js › companion (other) files › end-to-end: renaming a loose companion and excluding a nested one, then Save + apply, produces the expected target layout

The Include and name choices that the user saves in the page are the ones `apply` uses. How `apply` copies companions: see [10-apply.md](10-apply.md).

Example: rich, untick nested `Scans\inner.jpg`, rename `01 back.jpg` → `Renamed Back Cover.jpg`, rename `02 extra.jpg` → `Extra Booklet Page.jpg`, pick a Discogs candidate, Approve, Save, then `apply -IncludeUnresolved` → `Applied: 4`, `Failed: 0`; target `Aurora Fields\2016 Departure Songs …\` has `Renamed Back Cover.jpg`, `Extra Booklet Page.jpg`, `01 Track.flac`, `02 Track.flac`, and no `Scans\inner.jpg`.

## Cover gallery

### AS-DOC-REV-058 — The user picks one cover candidate with a radio button
Status: Draft | Source: legacy/tests/ui/specs/covers.spec.js › cover art › selecting a different cover candidate marks the release dirty and updates the chosen candidate; legacy/README.md › 3. Review in the browser; legacy/plan/07-editing-ui-module.md › UI shape

The gallery shows every cover candidate of the release with a radio button. The candidate in `coverArt.chosenCandidateUrl` is selected when the release opens. Picking another candidate selects it, unselects the old one, and marks the release unsaved.

Example: rich → candidate 1 (`front-large.jpg`) selected; pick candidate 2 → candidate 2 selected, candidate 1 not, row unsaved.

### AS-DOC-REV-059 — Each candidate shows its size and its embedded size
Status: Draft | Source: legacy/tests/ui/specs/covers.spec.js › cover art › shows original size and embedded size for an oversized cover, "(embedded as is)" for one already under the limit; legacy/plan/07-editing-ui-module.md › UI shape

Each candidate shows its pixel size. When a side is larger than `coverArt.targetMaxDimension`, it also shows the size after the downscale, with the aspect ratio kept. Otherwise it shows `(embedded as is)`.

Example: `3120x3200` at target 600 → `3120x3200 → 585x600 embedded`. `500x500` → `500x500 (embedded as is)`.

### AS-DOC-REV-060 — Local candidates load through the local-file route; web URLs load directly
Status: Draft | Source: legacy/tests/ui/specs/covers.spec.js › cover art › a local cover candidate is served through /api/.../local-file, a remote-style URL is left untouched; legacy/plan/07-editing-ui-module.md › Server-side persistence

A candidate with a local path is shown through `/api/sessions/{id}/local-file?path=<path>` (AS-DOC-REV-016). A candidate with an `http(s)` URL is used as the image source as it is.

Example: `front-large.jpg` → `src` contains `/api/sessions/<id>/local-file?path=`, and the image loads. `https://example.invalid/cover-remote.jpg` → `src` is `https://example.invalid/cover-remote.jpg`.

### AS-DOC-REV-061 — A thumbnail click opens a full-size preview without changing the choice
Status: Draft | Source: legacy/tests/ui/specs/covers.spec.js › cover art › clicking a thumbnail opens a lightbox with the full-size image, without changing the selected candidate; Close/outside-click/Escape all close it

A click on a thumbnail opens a lightbox (`#cover-modal`) with the full-size image. The selected candidate does not change. The `Close` button, a click outside the image, or the Escape key closes it.

Example: candidate 1 selected, click thumbnail 2 → lightbox open, candidate 1 still selected; `#cover-modal-close` → closed.

### AS-DOC-REV-062 — "Add cover from file…" adds an uploaded image as a new, selected candidate
Status: Draft | Source: legacy/tests/ui/specs/covers.spec.js › cover art › uploading a valid image adds it as a new, auto-selected candidate; an unsaved upload is gone after reload but its file stays on disk; … › adding a manual cover to a release that already has candidates appends it, keeping the existing ones selectable; legacy/README.md › 3. Review in the browser

The `Add cover from file…` control uploads a JPG or PNG at once (AS-DOC-REV-018). The status shows `Uploaded`. The page adds the image at the end of the gallery and selects it. The other candidates stay and can still be picked.

Example: minimal (1 candidate), upload `upload-cover.png` → 2 candidates, the new one selected, its `src` uses the local-file route. rich (3 candidates) → 4 candidates; candidate 1 can be picked again.

### AS-DOC-REV-063 — An unsaved upload leaves the gallery on reload, but its file stays on disk
Status: Draft | Source: legacy/tests/ui/specs/covers.spec.js › cover art › uploading a valid image adds it as a new, auto-selected candidate; an unsaved upload is gone after reload but its file stays on disk

The new candidate lives only in the page until Save. The uploaded file is already on disk. When the user reloads without Save, the candidate is gone from the gallery, and the file stays in `manual-covers`.

Example: minimal, upload, reload without Save → 1 candidate; the file under `manual-covers\` still exists.

### AS-DOC-REV-064 — A failed upload shows an error and adds nothing
Status: Draft | Source: legacy/tests/ui/specs/covers.spec.js › cover art › uploading a non-image file shows an inline error and adds nothing to the gallery

When the server refuses an upload (AS-DOC-REV-019, AS-DOC-REV-020), the status `#manual-cover-status` shows `Upload failed`. The gallery stays the same.

Example: minimal, upload `not-an-image.txt` → `Upload failed`; still 1 candidate.

### AS-DOC-REV-065 — The upload control is there also when the gallery is empty
Status: Draft | Source: legacy/tests/ui/specs/covers.spec.js › cover art › a release with no cover candidates at all still shows the "Add cover from file…" control

A release with no cover candidates still shows the `Add cover from file…` button (`#manual-cover-btn`).

Example: empty → 0 candidates, button visible.

## Review state

### AS-DOC-REV-066 — The Discogs edition picker appears only for an ambiguous match
Status: Draft | Source: legacy/tests/ui/specs/review-state.spec.js › review state: Discogs match, Approve, Reject › an ambiguous release shows the Discogs candidate picker and the "ambiguous" badge; picking a candidate resolves it; legacy/README.md › 3. Review in the browser; legacy/plan/07-editing-ui-module.md › UI shape

When the release's Discogs match status is `ambiguous`, the detail panel shows the Discogs edition picker (`#discogs-candidates`). It has one radio option per Discogs candidate with its title. For any other status the picker is hidden.

Example: rich → 2 options: `Departure Songs … (Original Press)` and `Departure Songs … (Reissue)`.

### AS-DOC-REV-067 — Picking a Discogs candidate updates the release from the server
Status: Draft | Source: legacy/tests/ui/specs/review-state.spec.js › review state: Discogs match, Approve, Reject › an ambiguous release shows the Discogs candidate picker and the "ambiguous" badge; picking a candidate resolves it; legacy/tests/ui/helpers.js › mockDiscogsSelection (comment); legacy/README.md › 3. Review in the browser

Picking a candidate sends `POST /api/sessions/{id}/proposal/releases/{stableKey}/discogs-selection` with the `releaseId`. The server answers with release fields. The page merges these fields into the release and keeps every field that the answer does not have. The status `#discogs-candidate-status` shows `Updated.`. When the merged status is no longer ambiguous, the picker hides. The README says the pick only records the choice and does not fetch tags, tracklist or cover again (see AS-DOC-DEF-069 in [90-suspected-defects.md](90-suspected-defects.md)).

Example: pick `Reissue` (`releaseId: 1002`) → answer `discogsMatch.status = "matched"`, `Updated.`, picker hidden.

### AS-DOC-REV-068 — The Notes field is pre-filled with the review reasons
Status: Draft | Source: legacy/README.md › 3. Review in the browser; legacy/plan/07-editing-ui-module.md › UI shape

The detail panel has a free-text `Notes` field (`humanReview.notes`). It is pre-filled with the reasons why the release was flagged.

Example: rich (`reviewReasons: ["ambiguous-discogs-match"]`) → Notes show this reason.

### AS-DOC-REV-069 — Approve and Reject exclude each other
Status: Draft | Source: legacy/tests/ui/specs/review-state.spec.js › review state: Discogs match, Approve, Reject › Approve and Reject are mutually exclusive, and the row badge reflects the current choice; legacy/README.md › 3. Review in the browser

`Approve` (`#approve-checkbox`) and `Reject` (`#reject-checkbox`) are checkboxes. Ticking one unticks the other. The row badge changes at once.

Example: minimal, Approve → Approve on, Reject off, badge `ready`. Reject → Reject on, Approve off, badge `rejected`. Approve again → badge `ready`.

### AS-DOC-REV-070 — Approve resolves a release; Reject resolves it and excludes it from apply
Status: Draft | Source: legacy/plan/07-editing-ui-module.md › Approval gate; legacy/plan/07-editing-ui-module.md › UI shape; legacy/README.md › 3. Review in the browser

Approve sets `humanReview.resolved = true`: the release is reviewed and ready for `apply`. Reject sets `humanReview.rejected = true` and also `resolved = true`. Reject means "never apply this", for example a duplicate pressing. Apply rules: see [10-apply.md](10-apply.md).

Example: rich, Reject, Save → `humanReview.rejected = true`, `humanReview.resolved = true`.

## Unsaved changes and Save

### AS-DOC-REV-071 — An edit marks the release as unsaved and counts the changes
Status: Draft | Source: legacy/tests/ui/specs/edit-and-save.spec.js › editing and saving › editing a field marks the release dirty (dot + unsaved counts), Save clears both, and the edit persists on reload

An edit marks the release row as unsaved (a dot, CSS class `unsaved`). Two counters, at the top and at the bottom of the panel, show the number of unsaved changes. With no changes they are empty.

Example: minimal, Album `Quiet Interlude (Edited)` → row unsaved; `#unsaved-count` and `#unsaved-count-top` = `1 unsaved change`.

### AS-DOC-REV-072 — Save writes the whole session; there is no auto-save
Status: Draft | Source: legacy/tests/ui/specs/edit-and-save.spec.js › editing and saving › editing a field marks the release dirty (dot + unsaved counts), Save clears both, and the edit persists on reload; legacy/README.md › 3. Review in the browser; legacy/plan/07-editing-ui-module.md › Save behavior

The page never saves by itself. `Save` (top and bottom of the panel) sends the whole session's proposal with `PUT /api/sessions/{id}/proposal` (AS-DOC-REV-015). After success, `#save-status` shows `Saved`, the unsaved marks and counters are cleared, and the edit is still there after a reload.

Example: minimal, Album edit, Save → `Saved`; `proposal.json` has `Quiet Interlude (Edited)`; `proposal.backup.json` has `Quiet Interlude <suffix>`; after reload the field shows `Quiet Interlude (Edited)`.

### AS-DOC-REV-073 — Leaving the page with unsaved changes asks first
Status: Draft | Source: legacy/tests/ui/specs/edit-and-save.spec.js › editing and saving › making an edit then trying to leave the page triggers the browser's own unsaved-changes prompt

When the page has unsaved changes and the user navigates away, the browser shows its own "leave page?" prompt. Without changes, there is no prompt.

Example: rich, Album `Unsaved Edit`, go to `/?other=1` → the browser dialog appears.

## Server stopped

### AS-DOC-REV-074 — A failed Save shows "Save failed"
Status: Draft | Source: legacy/tests/ui/specs/server-down.spec.js › server stopped mid-session › Save and a live session switch both show a visible error/retry message, not a silent failure; legacy/plan/07-editing-ui-module.md › Edge cases

When the server does not answer, Save does not fail silently. `#save-status` shows `Save failed`.

Example: edit Album, stop the server process, Save → `Save failed`.

### AS-DOC-REV-075 — A failed load shows "Error" and a Retry button
Status: Draft | Source: legacy/tests/ui/specs/server-down.spec.js › server stopped mid-session › Save and a live session switch both show a visible error/retry message, not a silent failure; legacy/plan/07-editing-ui-module.md › Edge cases

When loading a session fails (for example the server stopped), the session status shows an error and the page shows a Retry button (`#retry-btn`). The unsaved-changes confirm still comes first (AS-DOC-REV-027).

Example: server stopped, pick another session, accept the confirm → `#session-status` contains `Error`; `#retry-btn` visible.

## Unrecognized folders

### AS-DOC-REV-076 — Unrecognized folders appear in the release list with the badge "unrecognized"
Status: Draft | Source: legacy/tests/ui/specs/unrecognized.spec.js › unrecognized folders › a release-without-artist folder shows up in the sidebar with its path, reason and children; … › a no-audio-files entry shows up in the sidebar the same way; legacy/plan/07-editing-ui-module.md › Unrecognized folders

Each entry of the proposal's `unrecognized[]` list is a row in the list, with the folder name and the badge `unrecognized`. What makes a folder unrecognized: see [05-recognition.md](05-recognition.md).

Example: entry `<source>\edbl` (reason `release-without-artist-suspected`) → row with text `edbl`, badge `unrecognized`. Entry `<source>\Empty Folder` (`no-audio-files`) → row `Empty Folder`.

### AS-DOC-REV-077 — Selecting an unrecognized folder shows its path, reason and files
Status: Draft | Source: legacy/tests/ui/specs/unrecognized.spec.js › unrecognized folders › a release-without-artist folder shows up in the sidebar with its path, reason and children; … › a no-audio-files entry shows up in the sidebar the same way; legacy/plan/07-editing-ui-module.md › Unrecognized folders

A click on an unrecognized row shows the unrecognized panel (`#unrecognized-panel`) instead of the release detail panel. It shows the full path, the reason code, and one list item per child file.

Example: `edbl` → path `<source>\edbl`, reason `release-without-artist-suspected`, 2 items (`edbl - minibeats, vol.1 - 01 Track.flac`, `… 02 Track.flac`). `Empty Folder` → reason `no-audio-files`, 0 items.

## Lossy tracker view

### AS-DOC-REV-078 — A header button switches between the release view and the lossy tracker
Status: Draft | Source: legacy/tests/ui/specs/lossy-tracker.spec.js › lossy tracker view › switching to the Lossy tracker tab shows the ledger; switching back shows releases again; legacy/plan/07-editing-ui-module.md › Lossy tracker tab

The page has two views. The release view (`#main-layout`) is shown on load. The `Lossy tracker` button (`#view-btn-lossy`) shows the lossy view (`#lossy-view`) and hides the release view. The releases button (`#view-btn-releases`) switches back. The ledger rules: see [11-lossy-tracking.md](11-lossy-tracking.md).

Example: ledger with `ZZ Top` / `XXX` → lossy view has 1 row with `ZZ Top` and `XXX`.

### AS-DOC-REV-079 — A status filter narrows the lossy table
Status: Draft | Source: legacy/tests/ui/specs/lossy-tracker.spec.js › lossy tracker view › the status filter narrows the table to matching rows only

The status filter (`#lossy-filter-status`) shows only the rows with the selected status.

Example: `Band Pending` (`pending-upgrade`) and `Band Ignored` (`ignored`) → 2 rows; filter `ignored` → 1 row `Band Ignored`.

### AS-DOC-REV-080 — A status change in a row is saved at once
Status: Draft | Source: legacy/tests/ui/specs/lossy-tracker.spec.js › lossy tracker view › changing a row's status persists to disk; legacy/plan/07-editing-ui-module.md › Lossy tracker tab

Each row has a status dropdown. A change is saved to `lossy-tracking.json` at once with `PUT /api/lossy/{stableKey}`. There is no separate Save step. `#lossy-status` shows `Saved`.

Example: `pending-upgrade` → `ignored` → `Saved`; on disk `status = "ignored"`.

### AS-DOC-REV-081 — A notes change in a row is saved when the field loses focus
Status: Draft | Source: legacy/tests/ui/specs/lossy-tracker.spec.js › lossy tracker view › editing a row's notes persists to disk; legacy/plan/07-editing-ui-module.md › Lossy tracker tab

Each row has a notes text field. The new text is saved when the user leaves the field.

Example: notes `Not chasing this one`, blur → `Saved`; on disk `notes = "Not chasing this one"`.

### AS-DOC-REV-082 — Delete removes a ledger row after a confirm
Status: Draft | Source: legacy/tests/ui/specs/lossy-tracker.spec.js › lossy tracker view › deleting a row asks for confirmation and removes it from disk; legacy/plan/07-editing-ui-module.md › Lossy tracker tab

Each row has a Delete button. It asks for confirmation. The text says the row is removed permanently. After OK, `DELETE /api/lossy/{stableKey}` removes the entry from `lossy-tracking.json`. With no rows left, the page shows the empty state (`#lossy-empty`).

Example: one entry, Delete, OK → empty state; the ledger file has 0 entries.

### AS-DOC-REV-083 — Export CSV and Export JSON download the rows that are shown
Status: Draft | Source: legacy/tests/ui/specs/lossy-tracker.spec.js › lossy tracker view › Export CSV downloads a file containing the visible rows; legacy/plan/07-editing-ui-module.md › Lossy tracker tab

`Export CSV` (`#lossy-export-csv-btn`) and `Export JSON` build a file in the browser from the rows the table shows now (after the filter). There is no extra request. The browser downloads the file. Before the table has loaded, the CSV has only the header.

Example: one `ZZ Top` row → the CSV contains the header `stableKey` and `ZZ Top`.

## Mark reviewed (optional)

### AS-DOC-REV-084 — "mark-reviewed" only changes the session stage
Status: Draft | Source: legacy/README.md › 4. Mark reviewed (optional); legacy/tests/Reshelf.Tests.ps1 › Reshelf.ps1 settings/session dispatch › session mark-reviewed sets stage to reviewed and resume reflects it

`session mark-reviewed <id>` sets the session stage to `reviewed`. This is for the user's own bookkeeping and for the `session resume` hint. It does not change any release. `apply` does not need it and does not check the stage. The command syntax: see [12-cli.md](12-cli.md). Stages: see [04-sessions.md](04-sessions.md).

Example: `pwsh scripts/Reshelf.ps1 session mark-reviewed 2026-09-25-0007` → stage `reviewed`; `session resume` then suggests `apply -SessionId 2026-09-25-0007`.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-05 | Phase 1 draft. |
