# Step 7 — Editing UI Module

## Purpose / scope

A static-site UI for human review of `proposal.json`: before/after display,
manual correction, cover selection, approval. Matches manifesto §7 module 4.
Persistence approach: the local `Start-TaggerUiServer.ps1` server reads and
writes `proposal.json` on the browser's behalf (see "Server-side persistence"
below) — superseding an earlier File System Access API design that needed a
folder pick on every first visit, per user feedback that "session" should be
an invisible implementation detail, not something to browse for.

## Inputs / outputs

- Input: `proposal.json` for a session ([03](03-domain-model-and-json-schemas.md)).
- Output: the same `proposal.json`, edited in place, with
  `humanReview.resolved`/`notes` filled in per release.

## Detailed design

### Structure

Plain `ui/index.html` + `ui/app.js` (ES modules) + `ui/styles.css`. No
framework, no build step — matches the manifesto's "static website, plain
HTML with minimal JS" philosophy (§8).

### Server-side persistence

- `Start-TaggerUiServer.ps1` already runs as a local PowerShell process with
  full, unrestricted disk access — unlike the browser, which needs a
  permission grant (and, before this design, a manual folder pick) for every
  file it touches. The server now reads and writes `proposal.json` itself and
  hands the browser plain JSON over `fetch()`, so the page needs **zero
  clicks**, including the very first visit — no folder picker, no permission
  prompt, no concept of "session" the user ever has to know about.
- API surface (all under `/api/`, everything else still served as a static
  file from `ui/`, unchanged):
  - `GET /api/current-session` — the session with the newest `updatedAtUtc`
    that already has a `proposal.json` (whatever its stage — matches "pick up
    where I left off"), plus that proposal's full content. `{found: false,
    message}` when no session has one yet.
  - `GET /api/sessions` — every session (source root, stage, updated date,
    whether it has a proposal), for the "Past sessions" list below.
  - `GET`/`PUT /api/sessions/{id}/proposal` — read or save one session's
    `proposal.json` directly, by its real `sessionId`.
  - `GET /api/sessions/{id}/local-file?path=...` — serves a local (non-Discogs)
    cover image; only if `path` exactly matches one already listed in that
    session's own `proposal.json`, since this listener has no other access
    control. Fixes what was otherwise a standing gap: a local companion-file
    cover candidate is an absolute Windows path, which `<img src>` can never
    load directly from a browser.
- A small **"Past sessions"** dropdown (shown only when 2+ sessions exist)
  lists the rest, labeled by source root + date + stage — never by the raw
  session id — for the "rewind to an older run" case.
- This is a real change from the original "no backend" framing (see Decisions
  below): the server now has a few application-specific routes, not just
  static file serving. It stays localhost-only, single-user, with no auth —
  the same trust boundary `Start-TaggerUiServer.ps1` already had.
- Since the browser no longer touches the filesystem directly, the File
  System Access API (and its Chromium-only requirement) is gone entirely —
  the page works in any modern browser with `fetch()`.

### Save behavior

- "Save" `PUT`s the edited `proposal.json` to `/api/sessions/{id}/proposal`.
- Before overwriting, the server copies the previous content to a rolling
  `proposal.backup.json` (single previous version only — not full
  versioning, just cheap protection against a bad save).

### UI shape

- List view: all releases in the session, grouped by artist, with a status
  badge (`needsReview`, `ambiguous match`, `ready`).
- Filters: "needs review only", "ambiguous Discogs match only".
- Detail view per release:
  - Before/after table: source folder/file names vs. proposed names.
  - Tag preview table (Artist, Album Artist, Year, Album, per-track Disc/Track/Title).
  - **Other files** table (`companionFiles` + `ignoredFiles`, manifesto §4.5 /
    §7.2 "we need to see them in Editing module"): one row per companion, with
    an Include checkbox and its Before/Kind. A **loose** companion (directly
    in the release folder) also gets an editable target-name field
    (`proposedFileName`), pre-filled by [06](06-edit-proposal-module.md) with
    a letter-first name; a **nested** companion (in a subfolder) is
    name-locked — it can only be included/excluded, since its subfolder isn't
    renamed here. Files in `ignoredFiles` (an unused `.cue`, a playlist) are
    listed read-only, greyed out, with their reason — they were never going to
    be copied and can't be included. An inline warning (not a save block)
    flags a loose name that's empty, doesn't start with a letter, or collides
    with a track name/another included file — the same checks
    [08](08-implementation-module.md) makes before copying, surfaced here
    before an apply run would otherwise fail on them.
  - Cover-candidate gallery (radio-select among `coverArt.candidates`). Each candidate shows its
    source pixel size and the size it will be embedded at (`coverArt.targetMaxDimension`), so an
    oversized local cover is clearly marked as one that will be downscaled.
  - `discogsMatch.candidates` shown when `status = "ambiguous"`, letting the
    user pick the correct edition/pressing.
  - Free-text `humanReview.notes` field and an "Approve" checkbox
    (`humanReview.resolved = true`).

### Approval gate

`humanReview.required`/`.resolved` is the one general "does a human need to
look at this before applying" signal - set whenever
[06-edit-proposal-module.md](06-edit-proposal-module.md)'s
`New-TaggerProposedRelease` flags a release for any reason (an ambiguous
Discogs match, an unresolved year, a tracklist mismatch, missing cover art, a
target conflict, or a carried-over Recognition ambiguity such as a
grouping-folder or artist-name-split guess) - not just an ambiguous Discogs
match specifically. By default,
[08-implementation-module.md](08-implementation-module.md) skips every
release where `humanReview.resolved != true`, for whatever reason it was set,
unless Implementation is explicitly run with `-IncludeUnresolved`. This keeps
a "run implementation now" action from silently applying an unreviewed guess
or overwriting a target-conflict release that still needs a human decision.

A separate **"Reject"** control sets `humanReview.rejected = true` (and
implies `resolved = true` — rejecting is itself a completed review decision).
Unlike a plain unresolved release, a rejected one is **never** applied, not
even with `-IncludeUnresolved` — the two states answer different questions
("haven't looked at it yet" vs. "looked at it and said no"). See
[03](03-domain-model-and-json-schemas.md) for the case this exists for: two
folders that turn out to be different physical pressings of the same album,
where the user only wants one kept.

## Decisions & rationale

- **Local server reads/writes `proposal.json`, not the browser** (superseding
  an earlier File System Access API design): the original design needed one
  folder-permission click per browser profile, and there was no way to remove
  that click entirely — Chrome will never let a page touch a local file
  without at least one user gesture, ever, for any site. Since "session"
  needed to be fully invisible (no picking, no ids shown), the only way to
  get to zero clicks was to stop having the browser touch the filesystem at
  all. This does cross the original "no real backend" line — the server now
  has a few application-specific routes — but it stays localhost-only,
  single-user, with no data ever leaving the machine, so the spirit of "no
  application server exposed to anyone" still holds.
- **One rolling backup, not full versioning**: proportionate to a personal
  tool — protects against "oops, bad save" without building a history
  system nobody asked for.
- **Session id validated against its real shape before touching disk**:
  `/api/sessions/{id}/...` checks `id` against the `yyyy-mm-dd-nnnn` pattern
  `New-TaggerSessionId` actually produces before it's ever handed to a
  filesystem call, so a crafted id in a URL can't reach outside the sessions
  folder.

## Edge cases

- No session has a `proposal.json` yet (fresh install, or only `recognize`
  has been run) → plain status message, not an error.
- `proposal.json` edited externally between UI loads → UI re-reads on open
  each time; no concurrent-editing story is needed for a single-user tool.
- Server stopped mid-session (e.g. the `pwsh` window closed) → `fetch()`
  fails; the UI shows a retry message instead of a silently stuck page.
- A local cover candidate's path no longer exists, or isn't one the current
  proposal actually names → the local-file request is refused (403), not a
  broken image with no explanation logged.

## Manual setup

None — any modern browser works, no special API support required.

## Definition of done

- The Playwright suite in `tests/ui` (see
  [11](11-testing-and-verification-strategy.md)) runs green: a session
  loads with no click needed, a proposed name/cover/companion edit is
  reflected immediately, Save persists it to `proposal.json` on disk with
  `proposal.backup.json` holding the prior version, and reloading shows the
  saved edit.
