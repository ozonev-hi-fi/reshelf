# 07 — Proposal matching (merged)

Status: Draft | Version: 0.1 | Last updated: 2026-10-13

## Scope

This file reconciles [`as-is-from-docs/07-proposal-matching.md`](../as-is-from-docs/07-proposal-matching.md)
(59 `AS-DOC-MAT-*` requirements, from the Pester tests, fixtures, README and
plan prose) and [`as-is-from-code/07-proposal-matching.md`](../as-is-from-code/07-proposal-matching.md)
(67 `AS-CODE-MAT-*` requirements, from `legacy/scripts/common/Reshelf.EditProposal.psm1`,
lines 1–1330, read cold) into one behavior record for how `propose` finds the
Discogs release for a recognized release folder: string similarity, search
title variants, candidate scoring, the search order (master, artist master
list, plain release, artist catalog fallback), fingerprint matching, match
result, master/version pressing selection, reading a Discogs tracklist,
track alignment, artist credit, compilation detection, and the track-number
pad width.

**Numbering note.** As with REC, almost every `AS-DOC-MAT-*` behavior rule
has a more precise `AS-CODE-MAT-*` counterpart, and the code side also names
whole subsystems the docs/tests view only names as a step: fingerprint
matching (duration/date evidence used with zero title similarity), artist-
identity resolution (confirming a Discogs artist profile before trusting its
aliases), and the catalog-fallback/best-candidate/master-version probing
mechanics. This file is organized by topic rather than carrying old numbers
forward; every `AS-MAT-NNN` cites every `AS-DOC-MAT-*`/`AS-CODE-MAT-*`/
`AS-CODE-PRP-*` id it reconciles, and [92-coverage.md](92-coverage.md) maps
every source id to its `AS-MAT-NNN`.

**Absorbed from PRP's as-is-from-code (not yet merged).** `AS-CODE-PRP-002`
and `AS-CODE-PRP-021`–`032` (track-number pad width, title alignment, number
alignment, Disc.Track position parsing) are read from
[`as-is-from-code/08-proposal-naming-and-tags.md`](../as-is-from-code/08-proposal-naming-and-tags.md),
whose own line range (1332–2928) is a mechanical split of the one shared
module file, not a semantic one. Phase 1's own MAT scope note already claims
these Describe blocks as MAT-owned ("`Get-ReshelfProposalPadWidth` to
... `Get-ReshelfDiscogsVersionRank`, except `New-ReshelfProposedTrackSet` and
`Test-ReshelfSameLossyRelease`"), so they are merged here, under `AS-MAT-*`,
rather than waiting for PRP's own merge pass. `AS-CODE-PRP-041`
(`New-ReshelfProposedTrackSet`'s own pad-width call) stays PRP-owned per that
same exclusion — it is cited only as resolution evidence below, never merged
as an `AS-MAT` source. **When PRP (area 08) is merged, `AS-CODE-PRP-002` and
`AS-CODE-PRP-021`–`032` must not be re-merged there — cite this file
instead.**

How the app sends requests, retries and caches: see
[06-discogs-client.md](06-discogs-client.md). How the matched data becomes
names and tags: see `08-proposal-naming-and-tags.md` (not yet merged).

## String similarity

### AS-MAT-001 — String similarity is normalized Levenshtein edit distance, not a token-sort ratio
Status: Draft | Source: AS-DOC-MAT-001; AS-CODE-MAT-001; AS-CODE-MAT-002

Two strings are compared with classic single-character Levenshtein edit
distance (insertion, deletion, substitution, each costing 1), then turned
into a 0.0–1.0 similarity: `1.0 - (distance / max(lengthA, lengthB))`. Two
empty strings are similarity 1.0; one empty and one non-empty is 0.0. Plan
02 names "a normalized string similarity such as token-sort ratio (compare
the words after sorting them)" as the intended approach — see
`90-contradictions-resolution.md` for why the actual implementation is
plain normalized Levenshtein distance instead, with no word-order handling
at all.

Example: `kitten` vs `sitting` → distance 3. `radiohead` vs `radiohead` →
1.0; `` vs `` → 1.0; `` vs `radiohead` → 0.0.

## Search title variants and query

### AS-MAT-002 — Search title variants: the raw title always, a cleaned title only if it differs
Status: Draft | Source: AS-DOC-MAT-002; AS-CODE-MAT-003

The trimmed raw title is always tried first. A second, "cleaned" variant is
added only when cleaning actually changes something — a Discogs title
search still carrying folder "noise" (a sub-title, a catalog number, an
edition word) can return zero results even for a release that exists.

Example: `Violator (1990) (ALFA ALCB-35) (1st Japan 1990)` → raw kept as-is,
cleaned `Violator`. `OK Computer` → only `OK Computer`.

### AS-MAT-003 — Cleaning removes every bracket/paren group, a trailing dash part, and a trailing-only edition word
Status: Draft | Source: AS-DOC-MAT-003; AS-CODE-MAT-003; AS-CODE-MAT-006

Cleaning strips: every `(...)`/`[...]` group (including one with a dash
inside it); a trailing `" - "`/en-dash/em-dash sequence; and one of the
words special/deluxe/limited/expanded/anniversary/remaster(ed)/bonus
(case-insensitive), optionally followed by "edition" — but only when it
sits at the very end of the already group-stripped text, not mid-title.

Example: `indigo rose - (progressive form)` → `indigo rose`. `3218 (Soldier
of Fortune Edition - Artwork)` → `3218`. `Forwards Special Edition` →
`Forwards`.

### AS-MAT-004 — A year inside a removed group becomes a year hint
Status: Draft | Source: AS-DOC-MAT-004; AS-CODE-MAT-004

The first removed `(...)`/`[...]` group containing a `19xx`/`20xx` number
sets a year hint, used when the caller supplied no explicit year. A group
without digits gives no hint.

Example: `Violator (1990) (ALFA ALCB-35) (1st Japan 1990)` → year hint
1990. `indigo rose - (progressive form)` → no hint.

### AS-MAT-005 — The same stripped groups and edition words become edition hints, kept for version ranking
Status: Draft | Source: AS-CODE-MAT-005

Every removed group's inner text (except a lone year) and every matched
edition word is collected as a deduplicated edition hint — the same noise
this function strips out of the search title, kept instead of discarded so
a later pressing choice can prefer a version whose own title/format carries
the same wording (`AS-MAT-053`).

### AS-MAT-006 — Look-alike (homoglyph) letters are folded before any search; a note appears only when something changed
Status: Draft | Source: AS-DOC-MAT-005; AS-CODE-MAT-055

Before any Discogs call, the artist name and title are run through
homoglyph normalization (Cyrillic/Greek letters that look like Latin ones,
folded to Latin). A human-readable note is attached to the match result
only when normalization actually changed something; real non-Latin text is
left as-is with no note. The folding rule itself: see
[02-text-and-naming.md](02-text-and-naming.md).

Example: artist `Inсubus Succubus` (Cyrillic `с`, U+0441) → searched as
`Incubus Succubus`, result carries a homoglyph note. Artist `Кино`, title
`Группа крови` → no note.

### AS-MAT-007 — The Discogs search query: fixed fields plus optional year — not the `q=...&year=...` shape the plan shows
Status: Draft | Source: AS-CODE-MAT-007; resolves `AS-DOC-DEF-043` (see `90-contradictions-resolution.md`)

A title-ladder search query always sets `type` (`release` or `master`),
`artist={name}` and `release_title={title}`; a `year` field is added only
when a year is known/hinted. The artist-master-list fallback and catalog
listing instead use `per_page`/`page` pagination with no `release_title`
(`AS-MAT-020`, `AS-MAT-025`); only the separate artist-identity search
(`AS-MAT-018`) uses a bare `q={name}` parameter.

## Candidate scoring

### AS-MAT-008 — A title is compared in three normalized forms: raw, group-stripped, and compact (no spaces)
Status: Draft | Source: AS-CODE-MAT-008

Matching only the plain normalized text missed a real Discogs subtitle case
and a spacing-only difference — three forms are compared instead: as-is
normalized, with any `(...)`/`[...]` group stripped, and "compact" (all
whitespace removed).

Example: `Son De Mar (Music From The Film By Bigas Luna)` vs `Son De Mar` —
the group-stripped form of the first matches the plain form of the second.

### AS-MAT-009 — Candidate score: 50% artist similarity + 50% title similarity, before adjustments; parsed from Discogs' own "Artist - Title" shape
Status: Draft | Source: AS-DOC-MAT-015 (partial); AS-CODE-MAT-009; AS-CODE-MAT-010

The candidate's raw `title` field is split on the first `" - "` into a
candidate artist and candidate title. A trailing `*` (Discogs' marker for a
disambiguated, reused artist name) is stripped from the artist part, which
is then split on `=` (Discogs' "{Romanized} = {Native script}" credit
style, inconsistently spaced) into separate name parts; the title is split
on `=` the same way. The base score is `(artistScore * 0.5) + (titleScore *
0.5)`, before the year adjustment and compilation penalty below.

### AS-MAT-010 — Artist score: best similarity across every expected name and every known alias
Status: Draft | Source: AS-DOC-MAT-021; AS-CODE-MAT-011

The artist score is the maximum similarity found between any of {the
expected artist name, its known Discogs aliases} and any of the candidate's
artist-name parts. Aliases let a Discogs credit in another script (a
Japanese act's own name) match the romanized folder artist.

Example: `Maximum The Hormone` / `Greatest The Hits 2011` vs `マキシマム ザ
ホルモン* - Greatest The Hits 2011-2011` → without alias scores below
threshold; with alias `マキシマム ザ ホルモン` reaches it.

### AS-MAT-011 — Title score: best similarity across every title form and every "=" part
Status: Draft | Source: AS-DOC-MAT-022; AS-CODE-MAT-012

The title score is the maximum similarity found between any title form
(`AS-MAT-008`) of the expected title and any title form of any candidate
title part (split on `=` the same way as the artist).

Example: `Maximum The Hormone` / `Tsume Tsume Tsume'F` vs `マキシマム ザ
ホルモン* - Tsume Tsume Tsume / 「F」= 爪爪爪 / 「F」` → compared against the
romanized half, reaches the threshold.

### AS-MAT-012 — Year adjustment: exact match +0.05, more than 1 year apart −0.05, otherwise none
Status: Draft | Source: AS-CODE-MAT-013

When both an expected and a candidate year are known: equal years add
0.05; a gap of more than 1 year subtracts 0.05; a gap of exactly 1 year, or
either year unknown, applies no adjustment at all.

### AS-MAT-013 — Compilation, Box Set or Unofficial Release format: −0.10 penalty
Status: Draft | Source: AS-DOC-MAT-019; AS-DOC-MAT-020; AS-CODE-MAT-014

A candidate whose format text contains "compilation", "box set" or
"unofficial release" (case-insensitive) has 0.10 subtracted from its score
— small enough that an exact-title match of this kind still passes the
threshold, large enough that a fuzzy one does not win silently.

Examples: `Some Band` / `Greatest Hits`, `CD, Compilation` scores lower
than `CD, Album` but still passes with an exact title. `Aerosmith` /
`Aerosmith` / 1973 vs `Aerosmith - Classic Aerosmith`, 2000, `CD,
Compilation, Remastered` → falls below threshold. `CD, Box Set` and `CD,
Unofficial Release` are penalized the same way.

### AS-MAT-014 — The final score is clamped to [0, 1]
Status: Draft | Source: AS-CODE-MAT-015

After weighting, year adjustment and the compilation penalty, the score
never goes below 0.0 or above 1.0.

### AS-MAT-015 — The auto-match threshold is 0.85; a score exactly at it counts ("at or above", not "above")
Status: Draft | Source: AS-DOC-MAT-015 (partial); AS-CODE-MAT-016; resolves `AS-DOC-DEF-049` (see `90-contradictions-resolution.md`)

`>= 0.85` is treated as eligible for an automatic match at every stage
(master search, artist-master-list fallback, release search). This is a
module constant, not an exposed setting.

Example: `Radiohead` / `OK Computer` / 1997 vs `Radiohead - OK Computer`,
1997 → scores at or above 0.85. `Some Totally Different Band` /
`Unrelated Album Title` / no year vs the same result → well below 0.85.

### AS-MAT-016 — The best score across every title variant counts, regardless of which search found the candidate
Status: Draft | Source: AS-DOC-MAT-016; AS-CODE-MAT-040

Each raw search result is scored against every title variant (`AS-MAT-002`),
and the maximum resulting score is kept — a candidate can score well
against the raw title even when only the cleaned variant's search actually
returned it.

Example: for `Forwards Special Edition`, a candidate `The Egg - Forwards`
is scored against both `Forwards Special Edition` and `Forwards`; the
higher score counts.

### AS-MAT-017 — An extra Discogs subtitle or a spacing-only title difference does not block a match
Status: Draft | Source: AS-DOC-MAT-017; AS-DOC-MAT-018

Example: `Piano Magic` / `Son De Mar` / 2001 vs `Piano Magic - Son De Mar
(Music From The Film By Bigas Luna)`, 2001 → reaches threshold. `Grails` /
`Red Light` / 2004 vs `Grails - Redlight`, 2004 → reaches threshold.

## Search order: artist identity and steps 1a–1d

### AS-MAT-018 — Artist identity is resolved once per artist, skipped for "Various", confirmed only by fetching each candidate's own profile
Status: Draft | Source: AS-DOC-MAT-011 (partial); AS-CODE-MAT-046; AS-CODE-MAT-047; AS-CODE-MAT-048

Before any title-based search is scored, the app looks up the folder
artist on Discogs (`type=artist`, `q={name}`) — skipped entirely when the
artist name is exactly `Various`/`Various Artists`. Only the top 5 search
hits are considered; each candidate's own artist profile is fetched and
confirmed only by an exact normalized match against its `name` (trailing
`" (N)"` stripped) or any of its `namevariations` — the raw search result's
own `title` text is never trusted directly, since it may show a different
name (e.g. a Japanese act's native-script name) than the one that found
it. Any exception during this lookup is caught, logged verbose-only, and
treated as "unknown identity" (`null`) rather than failing the match. A
confirmed identity's name + namevariations become artist aliases
(`AS-MAT-010`) used by every scoring step below.

Example: artist search for `Maximum The Hormone` returns artist 500
`マキシマム ザ ホルモン`, confirmed by a name variation; aliases feed every
later score.

### AS-MAT-019 — Step 1a: master search, each title variant with its year then without, stopping at the first non-empty result — at most 4 searches
Status: Draft | Source: AS-DOC-MAT-006; AS-CODE-MAT-056; AS-CODE-MAT-057

A `type=master` search is tried first, before a plain release search,
specifically because Discogs groups every pressing of a work under one
master — this lets version ranking (`AS-MAT-050`) disambiguate between
several same-scoring release editions that a plain release search alone
has no way to prefer between.

Example: artist `Various`, title `Holy Dio`, year 1999, all searches empty
→ at most 4 master searches on this step.

### AS-MAT-020 — Step 1b: the artist's master list, tried only when step 1a found nothing eligible, skipped for "Various"
Status: Draft | Source: AS-DOC-MAT-007; AS-DOC-MAT-008; AS-CODE-MAT-058

When step 1a found no eligible master, up to 3 pages (300) of masters
credited to the artist are listed (paged, no `release_title`) and scored
locally — this catches a title Discogs itself spells differently than the
folder does. Skipped entirely for `Various`/`Various Artists`, whose
master list runs into the thousands and would waste rate-limited calls on
a release this step was never going to find.

Example: artist `Grails`, title `Red Light`, title searches empty; the
artist list returns master 91049 `Grails - Redlight` → eligible. Artist
`Various`, title `Holy Dio` → step skipped, no request with a `per_page`
key for this step.

### AS-MAT-021 — An eligible master (from 1a or 1b) is the highest scorer; its pressing is resolved through master-version selection
Status: Draft | Source: AS-DOC-MAT-010 (partial); AS-CODE-MAT-059

When step 1a or 1b found at least one eligible master, the highest-scoring
one is chosen and `Select-ReshelfDiscogsMasterVersion` (`AS-MAT-043`–`048`)
resolves which specific pressing to use.

Example: Grails `The Burden Of Hope`, master 26213 → resolved to release
384825 via master-version selection.

### AS-MAT-022 — Step 1c: plain release search, tried only when no master — eligible or not — was found at all
Status: Draft | Source: AS-DOC-MAT-009; AS-CODE-MAT-060

When neither step 1a nor 1b found any master result at all, a `type=release`
search (the original, pre-master-search behavior) is tried with the same
title variants.

Example: artist `The Egg`, title `Forwards Special Edition`, no year; only
`release_title=Forwards` returns release 42 `The Egg - Forwards` →
eligible.

### AS-MAT-023 — An eligible release with a master_id resolves through master-version selection; one without resolves through best-candidate track-count probing
Status: Draft | Source: AS-DOC-MAT-010; AS-CODE-MAT-061; AS-CODE-MAT-062

When the best eligible plain-release result carries a `master_id`, the
match is resolved through master-version selection for that master rather
than using the raw release id directly. Otherwise the final pick goes
through best-candidate selection (`AS-MAT-040`–`042`) across all eligible
releases.

Example: master search empty; release search returns release 999 with
`master_id=555` → resolved via master 555, not release 999 directly.

### AS-MAT-024 — Step 1d (catalog fallback): reached only when master and release search both found nothing eligible, and only attempted when the artist identity resolved and a year is known
Status: Draft | Source: AS-DOC-MAT-011 (partial); AS-CODE-MAT-049; AS-CODE-MAT-063

The catalog/fingerprint fallback is the last resort — it exists for a
release Discogs titles only in a script (e.g. Japanese) the folder's own
title never scores close to. It is reached only once every title-based
search (1a/1b/1c) came up with nothing eligible, and is only attempted when
the artist identity was resolved (`AS-MAT-018`) and an effective year
(explicit or hinted, `AS-MAT-004`) is known.

Example: artist `マキシマム ザ ホルモン`/`Maximum The Hormone`, every title
search empty → catalog fallback runs; finds release 99 `ロッキンポ殺し`.

### AS-MAT-025 — Catalog fallback lists up to 3 pages of the artist's catalog, keeping "Main"-role entries within ±1 year of the folder year
Status: Draft | Source: AS-CODE-MAT-050

Up to 3 pages of 100 releases each (300 total) from `/artists/{id}/releases`
are fetched, keeping only entries with `role=Main` and a `year` within 1
year of the folder's year.

### AS-MAT-026 — Catalog fallback ranks candidates by year closeness then release-type match — a tie-breaker only
Status: Draft | Source: AS-CODE-MAT-051

Candidates are sorted by absolute distance from the folder's year first,
then by whether the folder's release-type hint (e.g. "single") appears in
the candidate's own format text. This ranking only decides check order; the
real decision is the per-release fingerprint check (`AS-MAT-030`–`034`).

### AS-MAT-027 — Catalog fallback checks up to 8 ranked candidates against the fingerprint, stopping at the first Strong one
Status: Draft | Source: AS-DOC-MAT-012; AS-CODE-MAT-052

Up to 8 ranked candidates have their detail fetched and run through the
fingerprint check, stopping at the first one that fingerprints Strong
(`AS-MAT-033`). A Strong hit is returned with status `matched`.

Example: artist `Maximum The Hormone`, title `Rokkinpo Goroshi`, 2005, 2
source tracks of 125.0 s and 140.0 s; release 99 has `2:05` and `2:20` →
Strong, matched, release 99, title `ロッキンポ殺し`.

### AS-MAT-028 — A Strong master-type catalog hit still resolves its pressing through master-version selection
Status: Draft | Source: AS-CODE-MAT-053

When the strong fingerprint hit is a master (not a release), master-version
selection (`AS-MAT-043`–`048`) is still run to pick the right specific
pressing, rather than returning the master itself.

### AS-MAT-029 — No Strong catalog hit yields up to 5 ambiguous candidates, ranked by the fingerprint's own non-gating score
Status: Draft | Source: AS-CODE-MAT-054

If none of the checked catalog candidates fingerprints Strong, up to 5 are
returned as ambiguous candidates, ranked by the non-gating fingerprint
score (`AS-MAT-034`) descending.

## Fingerprint matching

### AS-MAT-030 — Fingerprint matching requires an exact track-count match before anything else is checked
Status: Draft | Source: AS-CODE-MAT-019

The fingerprint check (used only in the catalog fallback, when title-based
search has already failed) first requires the release's playable-track
count to exactly equal the source's track count; nothing else is checked
otherwise.

### AS-MAT-031 — Fingerprint duration tolerance: ±3 seconds
Status: Draft | Source: AS-CODE-MAT-020

Two track durations are considered matching when their absolute difference
is at most 3 seconds.

### AS-MAT-032 — "Durations strong": at least 2 tracks compared, covering at least 2/3 of all playable tracks, every one within tolerance
Status: Draft | Source: AS-CODE-MAT-021

Durations are strong evidence only when track counts already match, at
least 2 tracks were compared, the compared tracks are at least 2/3 of all
playable tracks, and every compared track is within the 3-second tolerance
(100% of those compared).

### AS-MAT-033 — Fingerprint "Strong": track count matches AND (durations strong OR an exact release-date match) — the only way to auto-match with zero title similarity
Status: Draft | Source: AS-DOC-MAT-012; AS-DOC-MAT-013; AS-DOC-MAT-014; AS-CODE-MAT-022

A release/master fingerprints Strong — confident enough for an auto-match
with no title match at all — when the track count matches, and either the
durations are strong (`AS-MAT-032`) or the release's own `released` date
text equals the source's known release date exactly. This single formula
explains both doc-side observations: a catalog release with the right
track count but non-lining-up durations and no release date is never
Strong (so it returns `ambiguous`, not an auto-match); and a 1-track
release can never satisfy "durations strong" on its own (`AS-MAT-032`
needs at least 2 compared tracks), so it is Strong only through the exact
release-date branch — one lucky matching duration is deliberately not
enough evidence by itself.

Examples: 2 tracks, durations line up → Strong, matched. Same catalog
entry, durations 50.0 s/60.0 s, no release date → not Strong, `ambiguous`.
1 track, duration matches, no release date → not Strong, `ambiguous`. Same,
with the release date also matching → Strong, matched.

### AS-MAT-034 — Fingerprint's own non-gating score (0.4 / up to 0.5 / 0.1) only ranks ambiguous candidates, never gates Strong
Status: Draft | Source: AS-CODE-MAT-023

A separate score adds 0.4 for a track-count match, up to 0.5 weighted by
the fraction of compared tracks that match durations, and 0.1 for an exact
date match. It is used only to order the ambiguous candidate list
(`AS-MAT-029`) when nothing reached Strong, never to decide Strong itself.

## Match result

### AS-MAT-035 — `matched`: an eligible/Strong candidate is auto-selected, full release detail loaded
Status: Draft | Source: AS-DOC-MAT-023

When the best candidate reaches the threshold (or the catalog fingerprint
reaches Strong), the status is `matched`, the app selects it automatically,
and loads full detail (`/releases/{id}`: tracklist, year, formats, artists,
images).

Example: `Radiohead` / `OK Computer` / 1997 → `matched`, release 265498,
detail title `OK Computer` (3 tracks).

### AS-MAT-036 — `ambiguous`: nothing eligible/Strong anywhere; up to 5 deduplicated candidates from all three sources, no auto-select, no detail fetch
Status: Draft | Source: AS-DOC-MAT-024; AS-CODE-MAT-064

When nothing is eligible or Strong anywhere, the status is `ambiguous`. The
app selects nothing and loads no release detail (the catalog fingerprint
check is the one exception that loads detail to compare durations,
`AS-MAT-030`–`033`). The candidate list combines, deduplicated by release
id and ranked by score descending, capped at 5: the top 5 scored masters'
own main releases, the top 5 scored plain releases, and any catalog-
fallback candidates. The user resolves it in the review UI: see
[09-review-ui.md](09-review-ui.md).

Example: `Some Totally Different Band` / `Unrelated Album` / no year →
`ambiguous`; no selected release, no detail, candidates not empty.

### AS-MAT-037 — `not-found`: the combined candidate list is empty
Status: Draft | Source: AS-DOC-MAT-025; AS-CODE-MAT-065

When the combined ambiguous-candidate list (`AS-MAT-036`) ends up empty,
the status is `not-found` instead. The plan routes it to review the same
way as `ambiguous`.

Example: every search returns `results = @()` → `not-found`.

### AS-MAT-038 — Any exception anywhere in matching is caught and reported as `not-found` with an error note; a homoglyph note found earlier is preserved
Status: Draft | Source: AS-DOC-MAT-026; AS-CODE-MAT-066

The whole matching process is wrapped in a try/catch. Any exception — a
network failure after the retries in [06-discogs-client.md](06-discogs-client.md),
or anything else — produces `not-found` with an `ErrorNote` holding the
exception message, while the homoglyph note (`AS-MAT-006`), if any, is
still attached. The run continues with the other releases.

Example: every request throws `network is down` → `not-found`; the error
note contains `network is down`.

### AS-MAT-039 — The per-release wrapper feeds recognized fields straight through, with no logic of its own
Status: Draft | Source: AS-CODE-MAT-067

`Resolve-ReshelfDiscogsMatchForRelease` is a thin wrapper over the matching
function above, mapping the release's recognized title/year/track
count/release type/release date/per-track durations — nothing more.

## Best-candidate and master/version selection

### AS-MAT-040 — Several eligible plain-release candidates: up to 5 are probed by real tracklist count; the first exact match wins
Status: Draft | Source: AS-DOC-MAT-027; AS-CODE-MAT-037; AS-CODE-MAT-038

When the caller's source track count is unknown (`<= 0`) or there is
exactly one eligible candidate, the top-scored one is trusted outright with
a single detail fetch. Otherwise, up to 5 eligible candidates (the same
width as the UI's candidate list) are fetched and checked for an exact
playable-track-count match, stopping at the first one found; each fetch is
cached.

Example: Pivot `O Soundtrack My Heart`, 11 source tracks. Candidate 1 is a
7" Single (2 tracks), candidate 2 is a CD Album (11 tracks) → `matched`,
release 2.

### AS-MAT-041 — No probed candidate matches the track count: the best format-preference rank among only the probed ones wins; still status `matched`
Status: Draft | Source: AS-DOC-MAT-028; AS-CODE-MAT-039

If none of the probed candidates has the source's exact track count, the
one with the best format-preference rank (`AS-MAT-042`) *among only the
candidates actually probed* is chosen — not the top-scored one by default.
The status stays `matched`, with no review flag for this. Carried forward
as a suspected defect: see `91-suspected-defects-carryforward.md`
(`CF-MAT-005`).

Example: `Some Band` / `Some Album`, 9 source tracks. Candidate 1 `CDr,
Promo` (5 tracks), candidate 2 `CD, Album` (7 tracks) → `matched`, release
2.

### AS-MAT-042 — Format preference ranking: Album, EP, Single, Promo, then everything else
Status: Draft | Source: AS-DOC-MAT-029; AS-CODE-MAT-031

Used only as a tie-breaker (never as a score).

| Format text contains | Rank |
|---|---|
| Album | 0 |
| EP | 1 |
| Single | 2 |
| Promo | 3 |
| none of these | 4 |

Examples: `CD, Album` → 0; `Vinyl, EP` → 1; `Vinyl, 7", 45 RPM, Single` →
2; `CDr, Promo` → 3; `Cassette` → 4.

### AS-MAT-043 — On the master path, the main release is tried first; trusted outright when the source track count is unknown, or when there are no edition hints and its own count agrees
Status: Draft | Source: AS-DOC-MAT-030; AS-CODE-MAT-042

When a master matches, the app loads the master and its versions. The
master's own `main_release` is accepted outright when the source track
count is unknown, or when there are no edition hints (`AS-MAT-005`) and the
main release's own playable-track count equals the source's — the common
case, saving a full probe.

Example: Grails `The Burden Of Hope`, master 26213, main release 384825
(CD Album, 10 tracks matching 10 source tracks) → accepted outright.

### AS-MAT-044 — The master-version candidate list reuses the master's own score and is capped at 5
Status: Draft | Source: AS-DOC-MAT-030 (partial); AS-CODE-MAT-041

Every version of a matched master reuses the master's own match score
(versions are not individually rescored); the candidate list is capped at
5 entries, each titled `"{ArtistName} - {version title}"`.

Example: Grails `The Burden Of Hope` → 2 candidates (main release plus one
`Album, Promo` version).

### AS-MAT-045 — The master's year is the release year, not the picked pressing's own year
Status: Draft | Source: AS-DOC-MAT-037

When the match has a master, the release's Year tag and folder name use
the master's year (the original year), never the picked pressing's own
year. How the year goes into names and tags: see
`08-proposal-naming-and-tags.md` (not yet merged).

Example: a 2019 reissue of a 2005 album → Year 2005.

### AS-MAT-046 — The master's image is a fallback cover candidate
Status: Draft | Source: AS-DOC-MAT-038

When the picked pressing has no cover image on Discogs, the master's own
image is added as a cover candidate. The cover candidate list: see
`08-proposal-naming-and-tags.md` (not yet merged).

Example: picked pressing `images = @()`, master has an image → the master
image is a cover candidate.

### AS-MAT-047 — Otherwise, up to 8 sorted versions are probed for an exact track-count match — wider than the plain-release probe
Status: Draft | Source: AS-CODE-MAT-043

Up to 8 versions (sorted by version rank, `AS-MAT-050`) are fetched and
checked for an exact playable-track-count match, stopping at the first
match — wider than the plain release search's 5, since a master can have
many more pressings.

### AS-MAT-048 — No probed version matches: fall back to the main release if one exists, else the best-ranked version overall
Status: Draft | Source: AS-CODE-MAT-044

If no probed version has the source's exact track count, the main release
is used if one exists; otherwise the first version in the sorted list
(`AS-MAT-050`) is used.

### AS-MAT-049 — A Vinyl/Cassette pick is replaced by a same-track-count CD/File version, probed among up to 3 sorted candidates
Status: Draft | Source: AS-DOC-MAT-036; AS-CODE-MAT-045

Once a Vinyl or Cassette pressing is chosen, up to 3 CD/File versions
(sorted the same way) are probed for the same playable-track count as the
chosen pressing; the first match replaces the choice, since a digital
source rip is closer to a CD/File pressing than to the vinyl/cassette
edition version ranking picked.

Example: OOIOO `Feather Float`, master's main release is a vinyl edition
(11 tracks, 1999); a CD Album version (11 tracks, 2001) replaces it →
`matched`, release 368574.

## Version ranking

### AS-MAT-050 — Version sort order: year match, edition-hint match, not-unwanted, format rank, popularity
Status: Draft | Source: AS-DOC-MAT-031; AS-CODE-MAT-032; AS-CODE-MAT-035; AS-CODE-MAT-036

Versions of a master are sorted, highest priority first: (1) the released
year equals the folder year; (2) an edition hint matches the version
(`AS-MAT-053`); (3) not a Promo/Test Pressing/Unofficial/Acetate
(`AS-MAT-051`); (4) format rank, CD/File best (`AS-MAT-052`); (5) higher
Discogs "in collection" count (0 if missing/unparseable), descending. Each
field only breaks ties left by the ones before it. Carried forward: the
version-rank test itself never exercises rule 1 (year match) in isolation
— see `91-suspected-defects-carryforward.md` (`CF-MAT-003`).

Example: no folder year, no hints; versions 1 (2019, Vinyl, 1 in
collection), 2 (2005, CD, 228), 3 (2005, File, 6) → version 2 first.

### AS-MAT-051 — A Promo, Test Pressing, Unofficial or Acetate version ranks behind an otherwise-equal one
Status: Draft | Source: AS-DOC-MAT-032; AS-CODE-MAT-034

The docs/tests view names only Promo and Test Pressing; the code's check is
wider, also catching "unofficial" and "acetate" in the format text.

Example: version 1 `Album, Promo` (CD, 2010) and version 2 `Album` (CD,
2010) → version 2 first.

### AS-MAT-052 — Format rank has three groups: CD/File first, then Vinyl/Cassette, then every rarer format last
Status: Draft | Source: AS-DOC-MAT-033; AS-CODE-MAT-033; resolves `AS-DOC-DEF-052` (see `90-contradictions-resolution.md`)

CD or File ranks best (the closest match for a digital rip); Vinyl or
Cassette ranks next; every other format (e.g. 8-Track Cartridge,
Reel-to-Reel, MiniDisc, SACD — more likely to have a nonstandard tracklist)
ranks last.

Example: folder year 1975; version 1 `8-Track Cartridge`, version 2
`Vinyl`, version 3 `Cassette`, all 1975 → version 1 is last; 2 and 3 are
first and second.

### AS-MAT-053 — An edition hint matches a version's own comma-split format token by exact equality first; only then is the pressing title checked for a raw substring
Status: Draft | Source: AS-DOC-MAT-034; AS-DOC-MAT-035; AS-CODE-MAT-032

The version's `format` text is split on commas into normalized tokens; an
edition hint (`AS-MAT-005`) matches when it equals one of those tokens
exactly (not merely because the token contains the hint text as a
substring). Only when no token matches at all does a weaker fallback check
whether the pressing title contains the hint as a raw substring. Carried
forward: the one test exercising "no false positive" uses a different hint
per version (`Limited` vs `Limited Edition`), so it never directly checks a
near-miss hint against an otherwise-matching token — see
`91-suspected-defects-carryforward.md` (`CF-MAT-004`).

Example: hint `Deluxe Edition`; version 1 `CD, Album, Reissue`, version 2
`CD, Album, Reissue, Deluxe Edition` → version 2's token matches exactly,
first. Hint `Limited` vs token `Unlimited Access` → no match (not exactly
equal). Hint `Limited Edition` vs token `Limited Edition` → exact match.

## Reading a Discogs tracklist

### AS-MAT-054 — An "index" entry's sub-tracks become separate playable tracks; headings and position-less entries are skipped
Status: Draft | Source: AS-DOC-MAT-039; AS-DOC-MAT-040; AS-CODE-MAT-017

The app builds the list of playable tracks from the Discogs tracklist. An
entry of type `heading`, or with an empty/missing position, is excluded. An
entry of type `index` that has `sub_tracks` is expanded into its
sub-tracks instead of being counted itself; a plain track (type `track`)
that has its own sub-tracks stays one playable track.

Example: Guapo: index `Five Suns` with sub-tracks `Five Suns I` … `Five
Suns V`, then `(silence)`, `Mictlan`, `Topan` → 8 playable tracks.

### AS-MAT-055 — A sub-track without its own artists inherits the index entry's artists
Status: Draft | Source: AS-DOC-MAT-041; AS-CODE-MAT-017

A sub-track with no `artists` of its own gets the artists of its index
entry; a sub-track with its own artists keeps them.

Example: index `Five Suns` with artist `Guapo`; sub-track `Five Suns I` (no
artists) → `Guapo`; sub-track `Five Suns II` (artist `Someone Else`) →
`Someone Else`.

### AS-MAT-056 — Duration text is parsed only as "m:ss" or "h:mm:ss"
Status: Draft | Source: AS-CODE-MAT-018

A duration string is parsed as 2 or 3 colon-separated integer parts.
Anything blank, with a different part count, or non-numeric returns
`null`.

## Disc.Track position parsing

### AS-MAT-057 — A position gives disc and track numbers from "D-T", "CDD-T" or "D.TT"
Status: Draft | Source: AS-DOC-MAT-042; AS-CODE-PRP-030

A Discogs track `position` is parsed with an optional `CD`/`DVD`/`Disc`
prefix (discarded), then two numbers separated by `-` or `.`.

Examples: `1-3` → disc 1, track 3. `CD2-1` → disc 2, track 1. `2.05` →
disc 2, track 5.

### AS-MAT-058 — A plain number is a track only, with no disc; a vinyl side or an empty/missing position gives neither
Status: Draft | Source: AS-DOC-MAT-043; AS-CODE-PRP-031; AS-CODE-PRP-032

Examples: `7` → no disc, track 7. `A1`, `B2`, ``, `null` → no disc, no
track.

## Track alignment

### AS-MAT-059 — Alignment is a strict two-step cascade: title first, then number; neither succeeding falls back to source titles entirely
Status: Draft | Source: AS-DOC-MAT-045 (partial); AS-CODE-PRP-029; resolves `AS-DOC-DEF-045` (see `90-contradictions-resolution.md`)

When the Discogs track count differs from the source, title alignment
(`AS-MAT-060`–`061`) is attempted first; only if it fails is number
alignment (`AS-MAT-064`–`065`) attempted; only if both fail does the
release fall back to source-derived titles entirely (`Aligned = false`,
`Method = null`). The successful method name (`title` or `number`) is
surfaced for the caller's own review note. Plan 06's "falls the whole
release back to source titles" undersold this — there is a second method,
not just a single fallback. Cross-referenced: `AS-DOC-DEF-064` (Area: PRP,
not decided here — a track-count-mismatch test that cannot tell which of
the two methods actually ran).

### AS-MAT-060 — Title alignment pairs every source track with its own best-scoring, not-yet-claimed Discogs track (similarity ≥ 0.8)
Status: Draft | Source: AS-DOC-MAT-044; AS-CODE-PRP-021; AS-CODE-PRP-022

For each source track, the best-scoring Discogs track not already claimed
by an earlier source track is picked (`Get-ReshelfStringSimilarity`, over
normalized titles). A pair needs a similarity of at least 0.8 — a
hardcoded threshold, all-or-nothing, not a partial/best-effort alignment.

Example: source `01 - Indigo Rose.flac`, `02 - Sun.flac`; Discogs `1 Cover
Your Ears`, `2 Indigo Rose`, `3 Sun` → aligned; titles `Indigo Rose`,
`Sun`; indices 2, 3.

### AS-MAT-061 — The source title for alignment: the existing title tag, else the file name's title part
Status: Draft | Source: AS-DOC-MAT-044 (partial); AS-CODE-PRP-021 (partial)

The source title used for comparison comes from the existing title tag,
or, when that is blank, from the file name without its number prefix and
extension (`AS-MAT-057`/`058` of [05-recognition.md](05-recognition.md)'s
track-filename parsing).

### AS-MAT-062 — A source track without a good-enough match stops title alignment entirely; one Discogs track can only be claimed once
Status: Draft | Source: AS-DOC-MAT-045; AS-DOC-MAT-046; AS-CODE-PRP-022

If even one source track's best remaining candidate scores below 0.8 (or
no unclaimed candidate remains), title alignment gives up entirely and
returns no tracks — the pairing is strictly one-to-one.

Example: source `01 - Completely Unrelated Name.flac`; Discogs `1 Airbag`,
`2 Paranoid Android` → not aligned. Source `01 - Airbag.flac`, `02 - Some
Other Song.flac`; Discogs only `1 Airbag` → not aligned (one Discogs track
cannot serve two source tracks).

### AS-MAT-063 — On a successful alignment (either method), every unclaimed Discogs track is reported as "missing on source: position title"
Status: Draft | Source: AS-CODE-PRP-023; AS-CODE-PRP-028

Example: source `01 - Indigo Rose.flac`, `02 - Sun.flac`; Discogs also has
`1 Cover Your Ears` → note `missing on source: 1 Cover Your Ears`.

### AS-MAT-064 — Number alignment only applies to a single-disc source with no inferred track order
Status: Draft | Source: AS-DOC-MAT-048; AS-CODE-PRP-024; AS-CODE-PRP-025

Number alignment (the fallback when title alignment fails) requires every
source track's `discFolder` to be `null` (single disc) and no source
track's order to be inferred (`AS-REC-061`) — a number this method trusts
must be a real, file-name-derived number, not a guess.

Example: source `01 - Nothing Alike.flac` in disc folder `CD1` → number
alignment not attempted (multi-disc).

### AS-MAT-065 — Number alignment requires in-range, unique detected numbers, AND title agreement on at least 2/3 of the number-paired tracks
Status: Draft | Source: AS-DOC-MAT-047; AS-CODE-PRP-026; AS-CODE-PRP-027

Every source track's detected number must be non-null, between 1 and the
Discogs tracklist count inclusive, and unique across the source tracks.
This is necessary but not sufficient: even after numbers line up, at least
2/3 of the number-paired tracks must also clear the 0.8 title-similarity
threshold (`AS-MAT-060`), or the alignment is rejected — numbers merely
falling in range is not trusted on its own. The docs/tests view shows the
numeric pairing itself but not this additional title-agreement
requirement.

Example: OOIOO, 10 source files numbered 1–6 and 8–11 (some titles written
differently, e.g. `03 Ina (Kanji).mp3` vs `Ina 咲くの唄`); Discogs has 11
tracks, number alignment succeeds (enough of the 10 pairs still clear 0.8)
→ method `number`; note `missing on source: 7 Asozan`.

## Artist credit

### AS-MAT-066 — A Discogs artist credit uses the "name" field, never "anv", with the "(N)" disambiguation suffix stripped
Status: Draft | Source: AS-DOC-MAT-049; AS-CODE-MAT-024

Examples: `The Dubliners` → `The Dubliners`. `Genesis (2)` → `Genesis`.
Name `Prince`, anv `The Artist` → `Prince`.

### AS-MAT-067 — Several artists are joined with each artist's own Discogs join text; a comma join gets a space only after it
Status: Draft | Source: AS-DOC-MAT-050; AS-CODE-MAT-024

A word join (e.g. `&`) gets a space on both sides; a comma join gets a
space only after it; a blank/missing join defaults to `", "`.

Examples: `Simon` (join `&`) + `Garfunkel` → `Simon & Garfunkel`. `A` (join
`,`) + `B` → `A, B`.

### AS-MAT-068 — A feat./ft./featuring join ends the credit; the featured artist never appears in it
Status: Draft | Source: AS-DOC-MAT-051; AS-CODE-MAT-025

Once a `join` value matches "feat.", "ft." or "featuring" (case-
insensitive), the credit stops there.

Example: `Jay-Z` (join `feat.`) + `Alicia Keys` → `Jay-Z`.

### AS-MAT-069 — No artists (empty or missing) gives no credit
Status: Draft | Source: AS-DOC-MAT-052; AS-CODE-MAT-024

Example: `@()` → `null`; `$null` → `null`.

## Compilations and Various Artists

### AS-MAT-070 — Matched release: compilation only when the first credited artist is Discogs id 194 or name exactly "Various" — never from the format word alone
Status: Draft | Source: AS-DOC-MAT-053 (partial); AS-CODE-MAT-026

The format word "Compilation" is never used by itself, since a
single-artist "Greatest Hits" can also carry it.

Examples: matched, artist `Various` id 194 → compilation. Matched, artist
`Metallica` id 1 → not a compilation.

### AS-MAT-071 — Unmatched release: compilation only when the folder's own artist name is exactly "Various" or "Various Artists"
Status: Draft | Source: AS-DOC-MAT-053 (partial); AS-CODE-MAT-027

Examples: not-found, name `Various Artists` → compilation. Not-found, name
`Some Band` → not a compilation.

### AS-MAT-072 — "Looks like Various": at least 3 tracks, at least 3 distinct track artists, more than half differing from the folder artist, and the folder artist itself not already "Various"
Status: Draft | Source: AS-DOC-MAT-054; AS-CODE-MAT-030

This evidence lets the app catch a Various-Artists tribute a search on the
folder artist would never find. Carried forward: `AS-DOC-DEF-053`
questioned whether the exact minimum was defined by the docs/tests view —
the code now fully explains the rule (≥3 tracks, ≥3 distinct, >50%
differing); no behavioral gap was found, carried forward unchanged per the
phase 3/phase 4 split — see `91-suspected-defects-carryforward.md`
(`CF-MAT-007`).

Examples: folder `DIO`; tracks `Blind Guardian`, `Primal Fear`, `Doro` →
looks like Various. Folder `Radiohead`; every track `Radiohead` → no.
Folder `Band A`; tracks `Band A`, `Band A`, `Band B` → no (2 distinct, not
enough).

### AS-MAT-073 — A featured guest counts as the main artist for this check
Status: Draft | Source: AS-DOC-MAT-055; AS-CODE-MAT-029

The `feat.`/`ft.`/`featuring` part of a track artist is cut before
comparing — a featured guest doesn't make a track count as a different
performer.

Example: folder `Metallica`; tracks `Metallica`, `Metallica feat. Justin
Bieber`, `Metallica` → no (not Various).

### AS-MAT-074 — A folder already named "Various"/"Various Artists" gives no evidence — no retry needed
Status: Draft | Source: AS-DOC-MAT-056; AS-CODE-MAT-030

Example: folder `Various`; tracks `Band A`, `Band B`, `Band C` → no.

### AS-MAT-075 — Per-track artist evidence: the existing tag first; only when every track lacks a tag does a consistent "Artist - Title" file name supply it
Status: Draft | Source: AS-DOC-MAT-057; AS-CODE-MAT-028

The file-name fallback is used only when *every* track in the release has
that `[NN] Artist - Title` shape — a single-artist title can have a dash
too, so a partial/inconsistent set of file names is not trusted.

Examples: folder `DIO`, no tags; `[01] Blind Guardian - Title One.mp3`,
`[02] Primal Fear - Title Two.mp3`, `[03] Doro - Title Three.mp3` → looks
like Various. Same folder, one file `02 Title Two.mp3` with no artist part
→ no (inconsistent naming).

## Track-number pad width

### AS-MAT-076 — The file-number pad width is max(configured minimum, digits needed) — at least 2 digits, growing with the number padded
Status: Draft | Source: AS-DOC-MAT-058; AS-CODE-PRP-002

Examples: 1, 9, 99 → pad width 2. 100, 999 → 3. 1000 → 4.

### AS-MAT-077 — `trackNumberPadWidth` (default 2) is a floor, not a fixed width
Status: Draft | Source: AS-DOC-MAT-059; AS-CODE-PRP-002; resolves `AS-DOC-DEF-051` (see `90-contradictions-resolution.md`)

The minimum width comes from the setting `trackNumberPadWidth` (default 2,
see [03-settings-and-secrets.md](03-settings-and-secrets.md)); a number
that needs more digits still wins. This low-level function's own parameter
is generically named `TotalTrackCount`, which `AS-DOC-DEF-051` read as
implying a plain count of tracks — see the resolution note for why the
real caller always passes the release's *highest resolved file number*
instead, matching plan 06.

Example: minimum width 3: 1 → 3; 9 → 3; 1000 → 4.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-13 | Phase 3 merge of area MAT: 59 `AS-DOC-MAT-*`, 67 `AS-CODE-MAT-*`, plus 13 `AS-CODE-PRP-*` items absorbed from PRP's not-yet-merged as-is-from-code (pad width, track/number alignment, position parsing — all explicitly MAT-owned per phase 1's own scope note), reconciled into `AS-MAT-001`–`077`. 6 contradictions resolved (`AS-DOC-DEF-043`–`045`, `049`, `051`, `052`, plus a new one found while merging: the plan's "token-sort ratio" naming for string similarity vs the actual normalized-Levenshtein formula). 7 suspected defects carried forward (`CF-MAT-001`–`007`, covering both `AS-CODE-DEF-MAT-*` entries and the MAT-area `AS-DOC-DEF-046`–`048`/`050`/`053`), plus a cross-reference to `AS-DOC-DEF-064` (PRP-owned, not decided here). |
