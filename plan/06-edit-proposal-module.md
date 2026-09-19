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
1. Build a search query from `recognizedName` (artist) + `recognizedTitle`
   (+ `recognizedYear` if known).
2. Check the Discogs cache first ([02](02-discogs-account-and-api-access.md)).
3. Score candidates; auto-select above threshold, else attach top 5 as
   `ambiguous` (see [02](02-discogs-account-and-api-access.md) for the exact
   mechanism).
4. Fetch full detail (`/releases/{id}`) for the selected/auto candidate to get
   canonical tracklist, year, and cover images.

### Computing proposed names and tags

Applies manifesto §5 rules mechanically, using Discogs data as ground truth:

- `proposed.artistFolderName` = Discogs artist name (fallback:
  `recognizedName` if no Discogs match yet — release stays `needsReview`).
- `proposed.releaseFolderName` = `"{year} {album}"` from the naming template,
  using Discogs's year and title.
- Per track, in disc + in-disc-track order:
  - `proposedDiscNumber` = 1-based disc index (always set, even for
    single-disc).
  - `proposedTrackNumber` = 1-based position within its disc (no leading
    zero) — restarts at 1 per disc.
  - Continuous filename number `NN` = running count across all discs in
    order (disc 1 tracks first, then disc 2, ...), zero-padded to the
    release's computed pad width ([04](04-settings-module.md)).
  - `proposedTitle` = Discogs track title, with any feat. artist / mix /
    remix / remaster wording preserved in the title text itself.
  - `proposedFileName` = `"{NN} {proposedTitle}.{ext}"`.
  - `tags.artist` = `tags.albumArtist` = `proposed.artistFolderName` — always
    identical, always the plain artist name, **never** including a feat.
    artist even if Discogs credits one on that specific track. This is a
    hard rule from manifesto §5, applied here regardless of what Discogs's
    per-track credits say.
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

- `Test-TargetReleaseExists -StableKey <key>` checks whether the target
  already has a release with this `stableKey`.
- Not present → `targetAction = "create-new"`.
- Present, and existing target is lossy while the new source is lossless →
  `lossyLossless.action = "replace-existing"`, `targetAction = "update-existing"`.
- Present and effectively identical (same `stableKey`, same source file-set
  hash — see [10](10-error-handling-and-edge-cases.md)) →
  `targetAction = "skip-existing-identical"`, no Discogs re-query needed
  (cache would return instantly anyway, but this avoids even building the
  query).
- Present but different in a way that isn't a lossy→lossless upgrade →
  `targetAction = "conflict"`, `humanReview.required = true`.

## Decisions & rationale

- **Artist/Album Artist never includes feat. credits, even if Discogs's own
  per-track data does**: this is the manifesto's explicit reasoning (§5) —
  players fragment a library across "Artist" and "Artist feat. X" otherwise.
  Discogs is the source of truth for *what the title/tracklist/year are*, not
  for *how the Artist tag must be constructed* — that construction rule is
  the manifesto's own policy layered on top.
- **Skip-existing-identical avoids re-querying Discogs**: keeps repeated runs
  over a growing collection cheap and fast, not just correct.

## Edge cases

- Discogs tracklist track count doesn't match the number of source audio
  files (e.g. a bonus track on Discogs's listing that isn't in the source, or
  vice versa) → `humanReview.required = true` with a note; never silently
  drop or fabricate a track.
- Release matched on Discogs but missing usable cover images → `coverArt.candidates`
  falls back to any existing embedded/loose cover found in `recognition.json`,
  flagged `needsReview` if none exist at all.

## Manual setup

None beyond step 2's Discogs token.

## Definition of done

- Given a `recognition.json` fixture and mocked Discogs responses (see
  [11](11-testing-and-verification-strategy.md)), `Invoke-EditProposal.ps1`
  produces a `proposal.json` that satisfies every manifesto §5 rule for
  multi-disc numbering, Artist=Album Artist, feat.-in-title-only, and
  Year/Album matching the folder name.
- A second run against an unchanged source with an already-populated target
  produces `targetAction = "skip-existing-identical"` for every release.
