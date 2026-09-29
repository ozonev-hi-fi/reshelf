# Step 6 — Edit Proposal Module

## Purpose / scope

Read `recognition.json`, look up each release on Discogs, and produce
`proposal.json`: a before/after document proposing folder names, file names,
metadata, and cover art per manifesto §4/§5. Matches manifesto §7 module 3.

## Inputs / outputs

- Input: `recognition.json` ([03](03-domain-model-and-json-schemas.md)),
  Discogs API access ([02](02-discogs-account-and-api-access.md)),
  `settings.json` naming templates ([04](04-settings-module.md)).
- Output: `proposal.json`.

## Detailed design

### Entry point

`Invoke-EditProposal.ps1 -SessionId <id>`.

### Discogs lookup

For each recognized release:
1. Build up to two search-title variants from `recognizedTitle`
   (`Get-ReshelfDiscogsSearchTitleVariants`): the raw title, and a "cleaned"
   one with parenthetical groups removed, a trailing `" - ..."` segment
   dropped, and a trailing edition word (Special/Deluxe/Limited/Expanded/
   Anniversary/Remastered) stripped — plus a year hint pulled from a removed
   group, used when `recognizedYear` is unresolved. Added after
   re-verification against the real Discogs API (plan/12 milestone 3) showed
   a `release_title` still carrying this noise returns **zero results** even
   for a release that demonstrably exists (e.g. "Violator (1990) (ALFA
   ALCB-35) (1st Japan 1990)" finds nothing; "Violator" does).
2. `Resolve-ReshelfDiscogsMatch` tries each variant, with its year then
   without it, stopping at the first search that returns anything — at most 4
   cached searches ([02](02-discogs-account-and-api-access.md)), not one
   fixed query. Every candidate is scored against **all** variants and the
   best score kept, regardless of which variant's search actually surfaced
   it.
3. Score candidates; auto-select above threshold, else attach top 5 as
   `ambiguous` (see [02](02-discogs-account-and-api-access.md) for the exact
   scoring mechanism).
4. When more than one candidate clears the threshold (real case: Pivot "O
   Soundtrack My Heart" had 5 same-scoring editions — a 7" single, a promo
   CDr, and 3 different albums), `Select-ReshelfBestDiscogsCandidate` fetches
   up to 5 of their real tracklists and picks the first whose track count
   matches the source; if none match, it prefers an Album-format edition over
   EP/Single/Promo. Only when there's exactly one eligible candidate does it
   skip straight to fetching that one's detail (the original, pre-milestone-3
   behavior).
5. Fetch full detail (`/releases/{id}`) for the selected/auto candidate to get
   canonical tracklist, year, and cover images.

### Computing proposed names and tags

Applies manifesto §5 rules mechanically, using Discogs data as ground truth:

- `proposed.artistFolderName` = Discogs artist name (fallback:
  `recognizedName` if no Discogs match yet — release stays `needsReview`).
- `proposed.releaseFolderName` = `"{year} {album}"` from the naming template,
  using Discogs's year and title.
- **Casing**: Discogs is the encyclopedia and has priority over every
  fallback — its artist/album/track text is used exactly as returned (only
  invisible formatting characters are stripped, see below), so a genuinely
  lowercase name (e.g. "edbl") is kept lowercase when Discogs itself agrees.
  Only the *fallback* path (no Discogs match, or a track title with no
  existing tag) applies `ConvertTo-ReshelfTitleCase` — capitalizes the first
  letter of each whitespace-separated word, leaves existing internal casing
  alone (so "DJ Shadow" stays "DJ Shadow") — added after re-verification
  against real data left names like "aoki takamasa" (the source folder's own
  casing) untouched with no Discogs match to correct it. (Bandcamp will get
  the same priority as Discogs once [13](13-bandcamp-fallback.md) exists.)
- Discogs text can carry invisible formatting characters (a real one: zero-
  width spaces around a dash, `"B​-​Sides"`) that would otherwise
  end up verbatim in file/folder names and tags — `Remove-ReshelfInvisibleCharacters`
  strips them (Unicode category `Cf`) wherever Discogs artist/album/track
  text is read.
- Per track, in disc + in-disc-track order:
  - `proposedDiscNumber` = 1-based disc index (always set, even for
    single-disc).
  - `proposedTrackNumber` (= `tags.track`) = the track's **real** number on
    its disc (no leading zero), restarting at 1 per disc. A track missing
    from the source leaves a gap; the rest are not shifted up.
  - Continuous filename number `NN` = the disc's offset + `proposedTrackNumber`,
    counting across discs, zero-padded to
    `max(trackNumberPadWidth, digits of the highest NN)` ([04](04-settings-module.md)).
  - Where the real number comes from, first match wins
    (`New-ReshelfProposedTrackSet`):
    1. **Discogs data, single-disc source**: the track's index in the
       *full* Discogs tracklist, not only the tracks the source has. Vinyl
       positions (`A1`, `B2`) work too, because the index is used, not the
       position text.
    2. **Discogs data, multi-disc source**: `Track` from the position
       (`1-3`, `CD2-1`, `2.05`, parsed by `Get-ReshelfDiscogsPositionParts`),
       `NN` = the full-tracklist index. Used only when every aligned
       position parses; otherwise step 3.
    3. **Source file numbers** (`detectedTrackNumberInDisc`), per disc, when
       none were inferred and none repeat. The disc offset is the sum of the
       highest Track of each earlier disc. A later disc numbered
       continuously in the source (`CD2\11 - …`, every number above the
       running offset) has the offset subtracted, so Track restarts at 1.
    4. **Counter** (1, 2, 3… per disc). Repeated source numbers on a disc
       also add the note `track numbers from source file names are not
       unique on disc N; renumbered sequentially` and force review.
  - Real case (plan/12 milestone 5): *AOKI Takamasa – Indigo Rose*, source
    missing track 1. Discogs aligned by title, so the proposal is
    `02 Dear People.mp3` (Track 2) … `08 There's Not Much Left.mp3`
    (Track 8). Before this rule it was `01 Dear People.mp3` (Track 1).
  - `proposedTitle` = Discogs track title, with any feat. artist / mix /
    remix / remaster wording preserved in the title text itself.
  - `proposedFileName` = `"{NN} {proposedTitle}.{ext}"`.
  - `tags.albumArtist` = `proposed.artistFolderName` — always the plain
    artist name (e.g. "Various" on a compilation), never including a feat.
    artist even if Discogs credits one on that specific track.
  - `tags.artist` = `tags.albumArtist` by default (manifesto §5). It can
    differ per track, in this order:
    1. Discogs' own per-track credit for that track (`Get-ReshelfDiscogsArtistCredit`),
       when the matched release's tracklist has one — this applies to any
       release, not only a compilation, so a split release also gets its
       tracks' real artists. Multiple artists are joined with Discogs' own
       `join` text (e.g. `"A & B"`); a `feat.`/`ft.`/`featuring` join stops
       the credit there, same feat.-exclusion rule as below.
    2. Else, on a compilation (`Test-ReshelfIsCompilationArtist` — Discogs'
       "Various" artist id 194, or an unmatched recognized artist/folder
       name of "Various"/"Various Artists"), the source file's own existing
       `Artist` tag, title-cased.
    3. Else, on a compilation with neither of the above, `tags.albumArtist`
       ("Various") plus a note that forces human review — silently
       mislabeling a compilation track is worse than asking someone to look.
    4. Otherwise (not a compilation, no Discogs per-track credit),
       `tags.albumArtist`, same as before this feature existed.
    A feat. artist is **never** added to `tags.artist`, whichever of the
    above supplies it — only to the title.
  - `tags.isCompilation` = `proposed.isCompilation` — see
    `Test-ReshelfIsCompilationArtist` above.
  - `tags.title` = `proposedTitle` (this is where any feat. artist text
    lives).
  - `tags.year` = `proposed.year`, `tags.album` = `proposed.album` — always
    equal to the release folder's `yyyy`/`Name` parts.

### Cover art candidates

- Gather all Discogs images for the selected release (primary + secondary),
  plus any existing embedded or loose cover found during Recognition.
- List all as `coverArt.candidates[]` with source/edition labels.
- Pre-select the Discogs primary image as `chosenCandidateUrl`, but leave it
  changeable in [07-editing-ui-module.md](07-editing-ui-module.md) — this is
  explicitly for the "which pressing/edition" ambiguity manifesto §5 calls
  out (Japanese vs. German cover, quality varies by edition).
- `targetMaxDimension` = `settings.json`'s `coverMaxDimension` (600, per
  manifesto §5).

### Target comparison (lossy/lossless + duplicate handling)

As implemented (checked 2026-09-26): Discogs is always queried first — the
per-request cache (`cacheTtlDays`) is what keeps a re-run cheap, not a
skip-the-query shortcut — and the target comparison below runs afterwards,
independent of the Discogs match:

- `Test-ReshelfTargetReleaseExists -StableKey <key>` checks whether the target
  already has a release with this `stableKey`, by scanning `TargetRoot`'s
  actual folder tree and recomputing each folder's `stableKey` from its
  on-disk name. This can't be relied on alone for a release whose
  `recognizedYear` was unresolved (see [03](03-domain-model-and-json-schemas.md)'s
  edge cases) — the target folder's name always carries the resolved sentinel
  year, which recomputes a *different* `stableKey` than the release's own.
- First, regardless of the above: if `apply-log.json` has a still-valid
  `applied` entry for this `stableKey` (target path still under `TargetRoot`,
  folder still exists — same check [08](08-implementation-module.md)'s own
  skip logic uses) whose recorded `sourceFileSetHash` matches the *current*
  source file-set hash → `targetAction = "skip-existing-identical"`
  immediately. This is the primary "was this exact release already applied
  and unchanged" check — necessary because Implementation renames every
  target file and rewrites its tags, so a target file set's name|size hash
  can never equal the source's again after a real apply.
- Otherwise, falling back to the target-folder hash comparison. The existing
  folder is found in this order, first match wins:
  1. the valid apply-log entry's `targetPath` for this `stableKey` (same
     source release, strongest link);
  2. the proposed target path itself, if it exists and has audio files;
  3. `Build-ReshelfTargetIndex` by `stableKey`.

  Steps 1–2 were added in plan/12 milestone 7. The index keys a folder by its
  *target* name, but `stableKey` comes from the *source* folder's names, and
  these differ whenever Discogs corrects them (real case: source
  `PULSAR OLYMP - 94Shine` vs. target `Pulsar Olymp\2015 94 Shine`). The
  existing lossy folder was invisible, so the FLAC re-import was proposed as
  `create-new` into that same folder instead of an upgrade.
  - Not present → `targetAction = "create-new"`.
  - Present, and existing target is lossy while the new source is lossless →
    `lossyLossless.action = "replace-existing"`, `targetAction = "update-existing"`.
    Exception: when the lossy folder is at a **different** path than this
    run's proposed one (e.g. its names were edited in the UI before its own
    apply), apply would replace only the proposed path and leave the old
    folder behind. That case is `create-new` +
    `"previously-lossy-different-location"` instead ("keep both, only warn",
    below). With no ledger row, `previousLossy.format` comes from the first
    audio file's extension and `firstDetectedUtc` from the folder's creation
    time.
  - Present and effectively identical by file-set hash (same `stableKey`, same
    source file-set hash — see [10](10-error-handling-and-edge-cases.md)) →
    `targetAction = "skip-existing-identical"`. In practice this path only
    fires for a target Reshelf didn't create itself (e.g. a manually
    pre-populated target folder) — a real `apply`'s own target is caught by
    the apply-log check above instead.
  - Present but different in a way that isn't a lossy→lossless upgrade →
    `targetAction = "conflict"`, `humanReview.required = true`.
  - **Nothing at all found by `stableKey`** (the `create-new` case above) and
    the source is lossless: `Find-ReshelfPreviousLossyEntry` also checks the
    lossy-tracking ledger by *name* — a normalized artist+year match, with
    the album compared via `Test-ReshelfSameLossyRelease` (the same
    noise-stripping `Get-ReshelfDiscogsSearchTitleVariants` uses for search)
    — against every still-`pending-upgrade` row. Added because `stableKey` is
    derived from *this run's* recognized/proposed names: a source folder
    renamed between imports (real case, plan/12 milestone 3: an old mp3
    import recognized as "Forwards Special Edition", a later flac import
    matching Discogs's own "Forwards") gets a different `stableKey` and would
    otherwise silently miss its own ledger row entirely, creating a second,
    unrelated one instead. When found: `lossyLossless.action` becomes
    `"previously-lossy-different-location"` (the old target folder still has
    lossy files in it) or `"previously-lossy-target-missing"` (it's gone —
    deleted, or `targetRoot` isn't the real collection). Either way
    `targetAction` is **not** changed and the old ledger row's `status` stays
    `pending-upgrade` — "keep both, only warn": apply never touches or
    deletes anything outside this run's own proposed target path, so
    reconciling the two copies is left to the user (e.g. via
    [07](07-editing-ui-module.md)'s lossy tracker tab).

## Decisions & rationale

- **Artist/Album Artist never includes feat. credits, even if Discogs's own
  per-track data does**: this is the manifesto's explicit reasoning (§5) —
  players fragment a library across "Artist" and "Artist feat. X" otherwise.
  Discogs is the source of truth for *what the title/tracklist/year are*, not
  for *how the Artist tag must be constructed* — that construction rule is
  the manifesto's own policy layered on top. The one exception this rule
  still enforces even on a compilation: a `feat.`/`ft.`/`featuring` join in
  Discogs' per-track `artists[]` ends the credit there, same as everywhere
  else.
- **A per-track `tags.artist` (compilations, split releases) is still built
  from Discogs' own per-track data, not invented locally**: the manifesto's
  "Artist == Album Artist" rule was written before compilations existed as a
  case; extending it to allow a per-track exception, sourced from Discogs
  (or the file's own tag as a fallback), keeps "Discogs is the source of
  truth for tracklist data" intact rather than special-casing it away.
- **Discogs is always queried, but the cache makes a re-run cheap anyway**:
  originally planned as an explicit skip-the-query shortcut for an identical
  release; as implemented, `cacheTtlDays` already answers a repeated identical
  query from disk without a live HTTP call, so a separate shortcut wasn't
  needed to keep repeated runs fast.
- **The re-run skip check goes through `apply-log.json`, not the target
  folder's own file names**: Implementation always renames and re-tags a
  target release's files, so comparing name|size hashes against the target
  folder can never again match the source after one real apply — the
  apply-log's own recorded source hash is the only reliable "was this exact
  thing already applied, unchanged" signal.

## Edge cases

- Discogs tracklist track count doesn't match the number of source audio
  files (e.g. a bonus track on Discogs's listing that isn't in the source, or
  vice versa) → `humanReview.required = true` with a note; never silently
  drop or fabricate a track. Before falling all the way back to source
  titles, `Resolve-ReshelfDiscogsTrackAlignment` tries matching every source
  track to its own Discogs track by title similarity (>= 0.8, one-to-one) —
  real case: a Discogs tracklist with one extra track the source never
  ripped, where every track the source *does* have still has a clean 1:1
  title match. On success, the aligned Discogs titles are used and the note
  names which Discogs track(s) the source is missing; any track without a
  good match falls the whole release back to source titles, unchanged from
  before this existed.
- Release matched on Discogs but missing usable cover images → `coverArt.candidates`
  falls back to any existing embedded/loose cover found in `recognition.json`,
  flagged `needsReview` if none exist at all.

## Manual setup

None beyond step 2's Discogs token.

## Definition of done

- Given a `recognition.json` fixture and mocked Discogs responses (see
  [11](11-testing-and-verification-strategy.md)), `Invoke-EditProposal.ps1`
  produces a `proposal.json` that satisfies every manifesto §5 rule for
  multi-disc numbering, Artist=Album Artist (except a per-track artist on a
  compilation/split release), feat.-in-title-only, and Year/Album matching
  the folder name.
- A second run against an unchanged source with an already-populated target
  produces `targetAction = "skip-existing-identical"` for every release.
