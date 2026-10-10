# As-Is BR (from code) — Discogs Proposal Matching

Status: Draft | Version: 0.1 | Last updated: 2026-10-10

This document describes the as-is behavior of the legacy Discogs candidate-matching logic, read directly from `legacy/scripts/common/Reshelf.EditProposal.psm1` (lines 1–1330 only; the rest of the file is covered by a separate, independent document). It is written independently from the Phase 1 (docs-based) BR, for later comparison. Area code: **MAT**.

### AS-CODE-MAT-001 — Levenshtein distance is classic single-character edit distance
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:31 › Get-ReshelfLevenshteinDistance

The distance between two strings is computed by dynamic programming, with insertion, deletion, and substitution each costing 1.

Example (illustration): `Get-ReshelfLevenshteinDistance -A "kitten" -B "sitting"` → `3`.

### AS-CODE-MAT-002 — String similarity = 1 minus normalized edit distance
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:70 › Get-ReshelfStringSimilarity

Similarity is `1.0 - (Levenshtein distance / max(lengthA, lengthB))`. Two empty strings are similarity `1.0`; one empty and one non-empty is similarity `0.0`.

### AS-CODE-MAT-003 — Search title variants: raw title, then a cleaned title
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:93 › Get-ReshelfDiscogsSearchTitleVariants

The trimmed, as-is title is always tried first. A second "cleaned" variant — with every parenthetical/bracketed group removed, a trailing dash removed, and a trailing edition word removed — is added only if it differs from the raw title.

Example: `"Violator (1990) (ALFA ALCB-35) (1st Japan 1990)"` → raw variant kept as-is, cleaned variant `"Violator"`.

### AS-CODE-MAT-004 — Year hint extracted from the first bracketed/parenthetical 4-digit year
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:93 › Get-ReshelfDiscogsSearchTitleVariants

The first `(...)`/`[...]` group in the title containing a `19xx` or `20xx` number sets a `YearHint`, used by the caller when no explicit year was supplied.

### AS-CODE-MAT-005 — Edition hints collected from stripped groups and edition words
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:93 › Get-ReshelfDiscogsSearchTitleVariants

Every bracketed/parenthetical group's inner text (except a lone year) and every case-insensitive match of the words "special", "deluxe", "limited", "expanded", "anniversary", "remaster"/"remastered", or "bonus" is collected as an `EditionHint` (deduplicated). These are the same noise the cleaned title strips out, kept instead of discarded so they can be used later to prefer a matching pressing.

### AS-CODE-MAT-006 — Edition-word stripping is trailing-only
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:93 › Get-ReshelfDiscogsSearchTitleVariants

An edition word (optionally followed by "edition") is only stripped from the cleaned title when it appears at the very end of the (already group-stripped) text — not when it appears mid-title.

Example: `"Forwards Special Edition"` → cleaned to `"Forwards"`.

### AS-CODE-MAT-007 — Discogs search query: fixed fields plus optional year
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:142 › Get-ReshelfDiscogsSearchQuery

The query always sets `type=release`, `artist={ArtistName}`, `release_title={Title}`. A `year` field is added only when a year was supplied.

### AS-CODE-MAT-008 — Title comparison forms: normalized, group-stripped, and compact
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:166 › Get-ReshelfDiscogsTitleForms

A title is compared in three normalized forms: as-is normalized text, normalized text with any `(...)`/`[...]` group removed, and a "compact" form with all whitespace removed — deduplicated.

Example: `"Son De Mar (Music From The Film By Bigas Luna)"` vs `"Son De Mar"` → the group-stripped form of the first matches the plain normalized form of the second.

### AS-CODE-MAT-009 — Candidate score: equal 50/50 weight between artist and title
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:188 › Get-ReshelfDiscogsCandidateScore

The base score is `(artistScore * 0.5) + (titleScore * 0.5)`, before the year adjustment and compilation penalty below are applied.

### AS-CODE-MAT-010 — Candidate artist/title text parsed from "Artist - Title"
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:188 › Get-ReshelfDiscogsCandidateScore

The candidate's raw `title` field is split on the first `" - "` into a candidate artist and candidate title. A trailing `*` (Discogs' marker for a disambiguated, reused artist name) is stripped from the artist part, and the artist part is further split on `=` (Discogs' "{Romanized} = {Native script}" credit style) into separate name parts.

### AS-CODE-MAT-011 — Artist score: best similarity across every expected name and every alias
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:188 › Get-ReshelfDiscogsCandidateScore

The artist score is the maximum string similarity (normalized text) found between any of {the expected artist name, its known Discogs aliases} and any of the candidate's artist-name parts (from AS-CODE-MAT-010).

### AS-CODE-MAT-012 — Title score: best similarity across every form and every "=" part
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:188 › Get-ReshelfDiscogsCandidateScore

The candidate title is split on `=` the same way the artist is. The title score is the maximum string similarity found between any title form (AS-CODE-MAT-008) of the expected title and any title form of any candidate title part.

### AS-CODE-MAT-013 — Year adjustment: ±0.05
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:188 › Get-ReshelfDiscogsCandidateScore

When both an expected and a candidate year are known: an exact year match adds `+0.05`; a difference of more than 1 year subtracts `-0.05`; a 1-year (or exact) difference, or either year being unknown, applies no adjustment.

### AS-CODE-MAT-014 — Compilation penalty: -0.10
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:188 › Get-ReshelfDiscogsCandidateScore

A candidate whose format text contains "compilation", "box set", or "unofficial release" (case-insensitive) has `0.10` subtracted from its score (`$script:DiscogsCompilationPenalty`). This is small enough that an exact-title compilation still passes the match threshold, but large enough to stop a fuzzy compilation title match from winning silently.

Example: real case cited in code comments — "Classic Aerosmith" scored against the title "Aerosmith" (1973 album) no longer wins silently once the compilation penalty is applied.

### AS-CODE-MAT-015 — Final candidate score is clamped to [0, 1]
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:188 › Get-ReshelfDiscogsCandidateScore

After the artist/title weighting, year adjustment, and compilation penalty, the score is clamped so it never goes below `0.0` or above `1.0`.

### AS-CODE-MAT-016 — Auto-match threshold: 0.85
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1035 › Resolve-ReshelfDiscogsMatch

A candidate must score `>= 0.85` (`$script:DiscogsMatchThreshold`) to be treated as eligible for an automatic match, at every stage (master search, artist-master-list fallback, release search). This value is a module constant, not an exposed setting.

### AS-CODE-MAT-017 — Playable tracks exclude headings and expand "index" groupings
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:278 › Get-ReshelfDiscogsPlayableTracks

A Discogs tracklist entry with type "heading", or with no position, is excluded. An entry with type "index" that has `sub_tracks` is expanded into its sub-tracks instead of being counted itself; a sub-track with no `artists` of its own inherits the index entry's `artists`.

Example: a tracklist with one "index" entry covering 5 movements plus 3 plain tracks after it yields 8 playable tracks, not 3.

### AS-CODE-MAT-018 — Duration text parsed only as "m:ss" or "h:mm:ss"
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:320 › Get-ReshelfDiscogsDurationSeconds

A duration string is parsed as 2 or 3 colon-separated integer parts (`m:ss` or `h:mm:ss`). Anything blank, with a different part count, or non-numeric returns `null`.

### AS-CODE-MAT-019 — Fingerprint match requires an exact track-count match first
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:343 › Get-ReshelfDiscogsFingerprintScore

The fingerprint check (used only when title-based search has already failed) first requires the release's playable-track count to exactly equal the source's track count; nothing else is checked otherwise.

### AS-CODE-MAT-020 — Fingerprint duration tolerance: ±3 seconds
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:343 › Get-ReshelfDiscogsFingerprintScore

Two track durations are considered matching when their absolute difference is `<= 3` seconds.

### AS-CODE-MAT-021 — Fingerprint "durations strong": at least 2/3 of tracks compared, 100% matching
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:343 › Get-ReshelfDiscogsFingerprintScore

Durations are considered strong evidence only when track counts match, at least 2 tracks were compared, the compared tracks are at least 2/3 of all playable tracks, and every compared track is within the 3-second tolerance (100% of those compared).

### AS-CODE-MAT-022 — Fingerprint "Strong" = track count match AND (durations strong OR exact release date)
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:343 › Get-ReshelfDiscogsFingerprintScore

A release/master fingerprints as `Strong` (confident enough for an auto-match with no title match) when the track count matches, and either the durations are strong (AS-CODE-MAT-021) or the release's own `released` date text equals the source's known release date exactly.

### AS-CODE-MAT-023 — Fingerprint non-gating score: 0.4 / up to 0.5 / 0.1
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:343 › Get-ReshelfDiscogsFingerprintScore

A separate score (not used to gate the Strong verdict, only to rank ambiguous candidates) adds `0.4` for a track-count match, up to `0.5` weighted by the fraction of compared tracks that match durations, and `0.1` for an exact date match.

### AS-CODE-MAT-024 — Artist-credit text: "name" field, disambiguation stripped, Discogs join tokens
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:402 › Get-ReshelfDiscogsArtistCredit

The Artist tag text is built from the Discogs `artists[]` array's `name` field (never `anv`), with a trailing `" (N)"` Discogs disambiguation suffix stripped. Multiple artists are joined using each artist's own `join` value, defaulting to `", "` when `join` is empty.

Example: `[{name:'A', join:'&'}, {name:'B (2)'}]` → `"A & B"`.

### AS-CODE-MAT-025 — Artist credit truncates at a "feat./ft./featuring" join
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:402 › Get-ReshelfDiscogsArtistCredit

Once a `join` value matches "feat.", "ft.", or "featuring" (case-insensitive), the credit stops — a featured artist is never added to the Artist tag text.

### AS-CODE-MAT-026 — Compilation-artist, matched case: Discogs artist id 194 or name "Various"
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:436 › Test-ReshelfIsCompilationArtist

For a matched release, it's treated as a Various-Artists compilation only when the release's first credited artist has Discogs id `194` or name exactly `"Various"`. The format word "Compilation" alone is never used, since a single-artist "Greatest Hits" can also carry it.

### AS-CODE-MAT-027 — Compilation-artist, unmatched case: folder artist name is "Various"/"Various Artists"
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:436 › Test-ReshelfIsCompilationArtist

When there's no match to check, the release is treated as a compilation only when the folder's own artist name is exactly `"Various"` or `"Various Artists"`.

### AS-CODE-MAT-028 — Various-artists evidence: tag artist, then filename artist part
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:458 › Get-ReshelfVariousArtistsEvidence

Per-track artist evidence uses the existing Artist tag first; if that's blank, it falls back to the "Artist" part of an "Artist - Title" style filename — but only when every single track in the release has that filename shape.

Example: real case cited in code comments — `DIO\1999 - Holy Dio`, a tribute album where 18 tracks are by 18 different bands, is caught this way even though a Discogs search under "DIO" finds nothing.

### AS-CODE-MAT-029 — Various-artists comparison strips a "feat." suffix first
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:458 › Get-ReshelfVariousArtistsEvidence

Before comparing a track artist to the folder artist, any "feat./ft./featuring ..." suffix is cut — a featured guest doesn't make a track count as a different performer.

### AS-CODE-MAT-030 — "Looks like Various" thresholds: 3+ tracks, 3+ distinct artists, >50% differing
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:458 › Get-ReshelfVariousArtistsEvidence

The release "looks like Various" when: there are at least 3 tracks, at least 3 distinct normalized track artists, more than half the tracks have an artist differing from the folder's own artist name, and the folder artist itself isn't already "Various"/"Various Artists".

### AS-CODE-MAT-031 — Format preference ranking: Album < EP < Single < Promo < other
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:514 › Get-ReshelfDiscogsFormatPreferenceRank

Used only as a tie-breaker (never as a score): Album = rank 0, EP = rank 1, Single = rank 2, Promo = rank 3, anything else = rank 4. Lower ranks are preferred as the "main" release.

### AS-CODE-MAT-032 — Version ranking: year match and edition-hint match
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:534 › Get-ReshelfDiscogsVersionRank

A version's year is parsed from its `released` text and compared to the folder's year for an exact match. An edition hint matches when it equals one of the version's own comma-split, normalized `format` tokens; if no token matches, a weaker fallback checks whether the hint text appears as a raw substring of the version's title.

### AS-CODE-MAT-033 — Version format rank: CD/File < Vinyl/Cassette < other
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:534 › Get-ReshelfDiscogsVersionRank

Format rank is 0 for CD or File (best match for a digital rip), 1 for Vinyl or Cassette, and 2 for anything else (e.g. 8-Track Cartridge, Reel-to-Reel, MiniDisc, SACD — formats more likely to have a nonstandard tracklist).

### AS-CODE-MAT-034 — Version "unwanted" rank: promo/test pressing/unofficial/acetate deprioritized
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:534 › Get-ReshelfDiscogsVersionRank

A version whose format text matches (case-insensitive) "promo", "test pressing", "unofficial", or "acetate" gets unwanted rank 1 (deprioritized); everything else gets rank 0.

### AS-CODE-MAT-035 — Version ranking carries the community "in_collection" count
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:534 › Get-ReshelfDiscogsVersionRank

The version's `stats.community.in_collection` count (0 if missing/unparseable) is carried through as the lowest-priority tie-breaker, used in descending order.

### AS-CODE-MAT-036 — Version sort order: year, edition, wantedness, format, popularity
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:605 › Sort-ReshelfDiscogsVersions

Versions of a master are sorted, highest priority first: year match, then edition-hint match, then not-unwanted, then format rank (AS-CODE-MAT-033), then `in_collection` count descending.

### AS-CODE-MAT-037 — Best-candidate selection trusts the top score when track count is unknown or there's one candidate
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:632 › Select-ReshelfBestDiscogsCandidate

When the caller doesn't know (or care about) the source track count (`<= 0`), or when there is exactly one eligible candidate, the top-scored candidate is trusted outright with a single release-detail fetch — the pre-existing behavior before track-count probing was added.

### AS-CODE-MAT-038 — Best-candidate selection probes up to 5 candidates for an exact track-count match
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:632 › Select-ReshelfBestDiscogsCandidate

Otherwise, up to 5 eligible candidates (the same width as the UI's candidate list) are fetched and checked for an exact playable-track-count match, stopping at the first one found. Each fetch is cached (via `Invoke-DiscogsRequest`).

### AS-CODE-MAT-039 — No exact match among probed candidates falls back to format preference
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:632 › Select-ReshelfBestDiscogsCandidate

If none of the probed candidates has the source's exact track count, the one with the best format-preference rank (AS-CODE-MAT-031) among only the candidates actually probed is chosen — not the top-scored one by default.

Example: real case cited in code comments — Pivot "O Soundtrack My Heart" had 5 same-scoring candidates (a 7" single, a promo CDr, and 3 albums); format preference picks an album.

### AS-CODE-MAT-040 — Scored-candidate list: best score across all title variants
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:677 › Get-ReshelfScoredDiscogsCandidates

Each raw search result is scored against every title variant (AS-CODE-MAT-003), and the maximum resulting score is kept — a candidate can score well against the raw title even when only the cleaned variant's search actually returned it.

### AS-CODE-MAT-041 — Master-version candidates: shared master score, capped at 5
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:723 › Get-ReshelfMasterVersionCandidates

Every version of a matched master reuses the master's own match score (versions are not individually rescored), and the candidate list is capped at 5 entries (`Limit` parameter), with each titled `"{ArtistName} - {version title}"`.

### AS-CODE-MAT-042 — Master-version selection trusts main_release when track count is unknown or agrees with no edition hints
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:763 › Select-ReshelfDiscogsMasterVersion

The master's `main_release` is accepted outright when the source track count is unknown (`<= 0`), or when there are no edition hints and the main release's own playable-track count equals the source's.

### AS-CODE-MAT-043 — Otherwise, up to 8 sorted versions are probed for an exact track-count match
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:763 › Select-ReshelfDiscogsMasterVersion

Up to 8 versions (sorted by `Sort-ReshelfDiscogsVersions`, AS-CODE-MAT-036) are fetched and checked for an exact playable-track-count match, stopping at the first match. This is a wider probe than the plain release search's 5, since a master can have many more pressings.

### AS-CODE-MAT-044 — No exact match among probed versions falls back to main release, then best-ranked version
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:763 › Select-ReshelfDiscogsMasterVersion

If no probed version has the source's exact track count, the main release is used if one exists; otherwise the best-ranked version overall (first in the sorted list) is used.

### AS-CODE-MAT-045 — Digital-rip preference: swap a Vinyl/Cassette pick for a matching CD/File pressing
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:763 › Select-ReshelfDiscogsMasterVersion

Once a Vinyl or Cassette pressing is the chosen release, up to 3 CD/File versions (sorted the same way) are probed for the same playable-track count as the chosen pressing; the first one that matches replaces the choice, since a digital source rip is closer to a CD/File pressing than to the vinyl/cassette edition that version ranking picked.

Example: real case cited in code comments — OOIOO "Feather Float" master's `main_release` is a vinyl edition; a matching CD/File pressing is preferred instead.

### AS-CODE-MAT-046 — Artist-identity resolution is skipped for "Various"/"Various Artists"
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:864 › Resolve-ReshelfDiscogsArtistIdentity

If the folder artist name is exactly `"Various"` or `"Various Artists"`, artist-identity resolution returns `null` without any Discogs call.

### AS-CODE-MAT-047 — Artist identity confirmed only by fetching the top 5 hits' own profiles
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:864 › Resolve-ReshelfDiscogsArtistIdentity

Only the top 5 artist-search hits are considered. Each candidate's own artist profile is fetched and its identity is confirmed only by an exact normalized-text match against its `name` (with trailing `" (N)"` stripped) or any of its `namevariations` — the raw search result's `title` text is never trusted directly, since it may show a different name (e.g. a Japanese act's native-script name) than the one that found it.

### AS-CODE-MAT-048 — Artist-identity resolution fails safe (returns null) on any error
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:864 › Resolve-ReshelfDiscogsArtistIdentity

Any exception during artist-identity lookup is caught, logged as verbose only, and the function returns `null` ("unknown identity") rather than propagating.

### AS-CODE-MAT-049 — Catalog fallback requires: nothing eligible found AND identity resolved AND a known year
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1035 › Resolve-ReshelfDiscogsMatch

The catalog-number/track-fingerprint fallback (step 1d) is only attempted when every title-based search (master, artist-master-list, release) found nothing eligible, the artist identity was resolved, and an effective year is known.

### AS-CODE-MAT-050 — Catalog fallback lists up to 3 pages of the artist's catalog, filtered to "Main" role within ±1 year
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:916 › Resolve-ReshelfDiscogsCatalogFallback

Up to 3 pages of 100 releases each (300 total) from `/artists/{id}/releases` are fetched, keeping only entries with `role = "Main"` and a `year` within 1 year of the folder's year.

### AS-CODE-MAT-051 — Catalog fallback ranks by year closeness, then release-type match
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:916 › Resolve-ReshelfDiscogsCatalogFallback

Candidates are sorted by absolute distance from the folder's year first, then by whether the folder's release-type hint (e.g. "single") appears in the candidate's own format text. This ranking is only a tie-breaker; the real decision is the per-release fingerprint check below.

### AS-CODE-MAT-052 — Catalog fallback checks up to 8 ranked candidates against the fingerprint
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:916 › Resolve-ReshelfDiscogsCatalogFallback

Up to 8 ranked candidates have their release/master detail fetched and run through the fingerprint check (AS-CODE-MAT-019 to -022), stopping at the first one that fingerprints `Strong`.

### AS-CODE-MAT-053 — A Strong "master"-type catalog hit still resolves through master-version selection
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:916 › Resolve-ReshelfDiscogsCatalogFallback

When the strong fingerprint hit is a master (not a release), `Select-ReshelfDiscogsMasterVersion` is still run to pick the right specific pressing, rather than returning the master itself.

### AS-CODE-MAT-054 — No Strong catalog hit yields up to 5 ambiguous candidates by fingerprint score
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:916 › Resolve-ReshelfDiscogsCatalogFallback

If none of the checked catalog candidates fingerprints as Strong, up to 5 are returned as ambiguous candidates, ranked by the non-gating fingerprint score (AS-CODE-MAT-023) descending.

### AS-CODE-MAT-055 — Homoglyph normalization runs before any Discogs search
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1035 › Resolve-ReshelfDiscogsMatch

The artist name and title are run through homoglyph (look-alike character) normalization before any search. A human-readable note is attached to the result only when something actually changed.

Example: real case cited in code comments — `"Inсubus Succubus"` with a Cyrillic `с` (U+0441) in place of Latin `c` is normalized before searching, since the Cyrillic look-alike made Discogs' search return nothing.

### AS-CODE-MAT-056 — Search ladder: up to 4 attempts (2 title variants × with/without year)
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1035 › Resolve-ReshelfDiscogsMatch

Both the master search and the release search try each title variant with, then without, the known/hinted year, stopping at the first combination that returns any result — not every combination up front.

### AS-CODE-MAT-057 — Step 1a: master search runs before plain release search
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1035 › Resolve-ReshelfDiscogsMatch

A `type=master` search is tried first, specifically because Discogs groups every pressing of a work under one master — this lets version ranking (AS-CODE-MAT-036) disambiguate between several same-scoring release editions that a plain release search alone has no way to prefer between.

### AS-CODE-MAT-058 — Step 1b: artist master-list fallback, skipped for "Various"
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1035 › Resolve-ReshelfDiscogsMatch

If step 1a found no eligible master, up to 3 pages (300) of masters credited to the artist are listed and scored locally — this catches a title Discogs itself spells differently than the folder does. This step is skipped entirely when the artist is "Various"/"Various Artists", since that artist's master list runs into the thousands and would waste rate-limited calls on a release it was never going to find this way.

### AS-CODE-MAT-059 — Eligible master selection picks the highest score, then resolves its pressing
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1035 › Resolve-ReshelfDiscogsMatch

When step 1a or 1b found at least one eligible master, the highest-scoring one is chosen, and `Select-ReshelfDiscogsMasterVersion` resolves which specific pressing to use.

### AS-CODE-MAT-060 — Step 1c: plain release search only runs when no master was found at all
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1035 › Resolve-ReshelfDiscogsMatch

A `type=release` search (the original, pre-master-search behavior) is only attempted when neither step 1a nor 1b found any master result, eligible or not.

### AS-CODE-MAT-061 — An eligible release with a master_id still resolves through master-version selection
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1035 › Resolve-ReshelfDiscogsMatch

If the best eligible plain-release result carries a `master_id`, the match is resolved through `Select-ReshelfDiscogsMasterVersion` for that master rather than using the raw release id directly.

### AS-CODE-MAT-062 — An eligible release with no master_id resolves through best-candidate track-count probing
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1035 › Resolve-ReshelfDiscogsMatch

If the best eligible release has no `master_id`, the final pick goes through `Select-ReshelfBestDiscogsCandidate` (AS-CODE-MAT-037 to -039) across all eligible releases instead.

### AS-CODE-MAT-063 — Step 1d (catalog fallback) only runs when master and release search both failed
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1035 › Resolve-ReshelfDiscogsMatch

The catalog fallback (AS-CODE-MAT-049 to -054) is reached only when neither the master search nor the release search found anything eligible. A `Strong` fingerprint result there is returned with status `matched`.

### AS-CODE-MAT-064 — "Ambiguous" status combines up to 5 deduplicated candidates from all three sources
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1035 › Resolve-ReshelfDiscogsMatch

When nothing is eligible/strong anywhere, the result status is `ambiguous`, and the candidate list combines (deduplicated by release id, ranked by score descending, capped at 5): the top 5 scored masters' own main releases, the top 5 scored plain releases, and any catalog-fallback candidates.

### AS-CODE-MAT-065 — Empty combined candidate list yields status "not-found"
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1035 › Resolve-ReshelfDiscogsMatch

If the combined ambiguous-candidate list (AS-CODE-MAT-064) ends up empty, the result status is `not-found` instead.

### AS-CODE-MAT-066 — Any exception during matching is caught and reported as "not-found"
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1035 › Resolve-ReshelfDiscogsMatch

The whole matching process is wrapped in a try/catch; any exception produces a `not-found` result with an `ErrorNote` containing the exception message, while the homoglyph note (AS-CODE-MAT-055), if any, is still preserved.

### AS-CODE-MAT-067 — Per-release wrapper feeds recognized fields straight through
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1303 › Resolve-ReshelfDiscogsMatchForRelease

`Resolve-ReshelfDiscogsMatchForRelease` is a thin wrapper that calls `Resolve-ReshelfDiscogsMatch` with the release's `recognizedTitle`, `recognizedYear`, track count, `recognizedReleaseType`, `recognizedReleaseDate`, and each track's `durationSeconds` — with no logic of its own beyond that mapping.

## Suspected defects

### AS-CODE-DEF-MAT-001
`legacy/scripts/common/Reshelf.EditProposal.psm1:263-267` (`Get-ReshelfDiscogsCandidateScore`) — the year-difference check only compares the raw numeric year, so a candidate exactly 1 year off gets `0` adjustment (same as an unknown year) while a 2+ year difference is penalized. A release that is genuinely a different edition/remaster one year off the source's year is treated identically to a perfect year match in scoring, even though the code comment elsewhere (title-cleaning logic) explicitly treats "1 year off" as meaningfully different from "exact".

### AS-CODE-DEF-MAT-002
`legacy/scripts/common/Reshelf.EditProposal.psm1:1220-1232` (`Resolve-ReshelfDiscogsMatch`, ambiguous-candidate assembly) — building `$masterCandidates` re-fetches each of the top 5 scored masters' detail just to read `main_release`, even when those same masters were already fetched earlier in the same call (e.g. via `Select-ReshelfDiscogsMasterVersion` for a different candidate, or via the artist-master-list path) — relies entirely on the Discogs response cache to avoid a real duplicate network call, with no in-memory reuse.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-10 | Phase 2 draft from code. |
