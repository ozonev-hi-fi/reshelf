# Step 7 — Editing UI Module

## Purpose / scope

A static-site UI for human review of `proposal.json`: before/after display,
manual correction, cover selection, approval. Matches manifesto §7 module 4.
Persistence approach decided with the user: **File System Access API**.

## Inputs / outputs

- Input: `proposal.json` for a session ([03](03-domain-model-and-json-schemas.md)).
- Output: the same `proposal.json`, edited in place, with
  `humanReview.resolved`/`notes` filled in per release.

## Detailed design

### Structure

Plain `ui/index.html` + `ui/app.js` (ES modules) + `ui/styles.css`. No
framework, no build step — matches the manifesto's "static website, plain
HTML with minimal JS" philosophy (§8).

### File System Access API usage

- One entry action: "Open Session Folder" → `window.showDirectoryPicker()`.
- From the returned directory handle, get a file handle for `proposal.json`,
  read and parse it.
- **Secure-context requirement**: the File System Access API does not work
  from a plain `file://` page in Chromium — it needs `http(s)://` (localhost
  counts). This means a trivial static file server is required:
  `Start-TaggerUiServer.ps1`, a one-liner around `System.Net.HttpListener`
  serving `ui/` on `http://localhost:<port>`. This is *not* the module-4
  backend the manifesto avoids — it serves static files only, with zero
  application logic; all reading/writing of `proposal.json` still happens
  client-side via the File System Access API talking directly to disk.
- Only Chromium-based browsers (Chrome, Edge) support this API — acceptable
  since the user is on Windows.

### Save behavior

- "Save" writes the edited `proposal.json` back via the same file handle.
- Before overwriting, copy the previous content to a rolling
  `proposal.backup.json` (single previous version only — not full
  versioning, just cheap protection against a bad save) since the File
  System Access API has no built-in undo/versioning.

### UI shape

- List view: all releases in the session, grouped by artist, with a status
  badge (`needsReview`, `ambiguous match`, `ready`).
- Filters: "needs review only", "ambiguous Discogs match only".
- Detail view per release:
  - Before/after table: source folder/file names vs. proposed names.
  - Tag preview table (Artist, Album Artist, Year, Album, per-track Disc/Track/Title).
  - Cover-candidate gallery (radio-select among `coverArt.candidates`).
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

## Decisions & rationale

- **Static file server, not a real backend**: needed purely to satisfy the
  browser's secure-context rule for the File System Access API — it has no
  routes, no logic, and could be replaced by any other static host without
  changing `app.js`. This preserves the manifesto's "no server/backend"
  intent in spirit (no application logic runs server-side).
- **One rolling backup, not full versioning**: proportionate to a personal
  tool — protects against "oops, bad save" without building a history
  system nobody asked for.

## Edge cases

- User denies/revokes directory permission mid-session → re-prompt via
  `showDirectoryPicker()` again; the UI must handle a rejected permission
  gracefully (show a retry button, not a silent failure).
- `proposal.json` edited externally between UI loads → UI re-reads on open
  each time; no concurrent-editing story is needed for a single-user tool.
- Browser other than Chrome/Edge → detect `!('showDirectoryPicker' in window)`
  at load and show a clear message instead of a confusing runtime error.

## Manual setup

None beyond having a Chromium-based browser installed.

## Definition of done

- Manual checklist (see [11](11-testing-and-verification-strategy.md)):
  open a session folder, edit a proposed name, change a cover selection,
  approve a release, save, reload, and confirm the changes persisted to
  `proposal.json` on disk and `proposal.backup.json` contains the prior
  version.
