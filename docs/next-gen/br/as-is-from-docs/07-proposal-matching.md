# 07 — Proposal matching (as-is, from docs and tests)

Status: Draft | Version: 0.1 | Last updated: 2026-10-05

## Scope

How the legacy app finds the Discogs release for a recognized release folder during `propose`: search title variants, the search order (master, artist master list, release search, artist catalog), candidate scoring, the match result (`matched` / `ambiguous` / `not-found`), version (pressing) selection, reading a Discogs tracklist, track alignment, artist credits, compilation detection, and the track-number pad width. Owned inputs: `legacy/tests/Reshelf.EditProposal.Tests.ps1` Describe blocks from `Get-ReshelfProposalPadWidth` to `Sort-ReshelfDiscogsVersions / Get-ReshelfDiscogsVersionRank` (except `New-ReshelfProposedTrackSet` and `Test-ReshelfSameLossyRelease`), `legacy/tests/fixtures/discogs-responses/*`, `legacy/plan/02-discogs-account-and-api-access.md` › Matching confidence, `legacy/plan/06-edit-proposal-module.md` › Discogs lookup and its track-count edge case, and `legacy/README.md` › How Discogs matching works.

How the app sends requests, retries and caches: see [06-discogs-client.md](06-discogs-client.md). How the matched data becomes names and tags: see [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md).

The tests replace the Discogs requests with mocks. So they show which requests run and what the app picks. They do not show the exact score formula or weights. This file records every number the tests and docs show.

## String similarity

### AS-DOC-MAT-001 — String similarity is a value from 0.0 to 1.0
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Get-ReshelfStringSimilarity (private); legacy/plan/02-discogs-account-and-api-access.md › Matching confidence

The app compares two strings with a similarity value from 0.0 (nothing alike) to 1.0 (identical). Two empty strings count as identical. One empty string against a non-empty one gives 0.0. A near match scores higher than an unrelated pair. The plan names a normalized string similarity such as token-sort ratio (compare the words after sorting them). The tests do not fix the formula. All test inputs are lower case.

Examples:
- `radiohead` vs `radiohead` → 1.0; `` vs `` → 1.0; `` vs `radiohead` → 0.0.
- `ok computer` vs `ok computr` scores higher than `ok computer` vs `kid a`.

## Search title variants

### AS-DOC-MAT-002 — The app searches with up to two title variants: raw and cleaned
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Get-ReshelfDiscogsSearchTitleVariants (private); legacy/plan/06-edit-proposal-module.md › Discogs lookup (step 1)

From the recognized title, the app builds a list of search titles. The first one is the raw title. The second one is a cleaned title, and it exists only when cleaning changes something. The reason (plan): a Discogs title search that still carries this "noise" returns zero results, even for a release that exists.

Examples:
- `Violator (1990) (ALFA ALCB-35) (1st Japan 1990)` → `Violator (1990) (ALFA ALCB-35) (1st Japan 1990)`, `Violator`.
- `OK Computer` → only `OK Computer`.

### AS-DOC-MAT-003 — Cleaning removes parenthetical groups, a trailing ` - ...` part and a trailing edition word
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Get-ReshelfDiscogsSearchTitleVariants (private); legacy/plan/06-edit-proposal-module.md › Discogs lookup (step 1)

The cleaned title has:
- every parenthetical group removed, also one with a dash inside it;
- a trailing `" - ..."` part removed;
- a trailing edition word removed. The plan lists Special, Deluxe, Limited, Expanded, Anniversary, Remastered.

Examples:
- `indigo rose - (progressive form)` → `indigo rose`.
- `3218 (Soldier of Fortune Edition - Artwork)` → `3218`.
- `Forwards Special Edition` → `Forwards`.

### AS-DOC-MAT-004 — A year in a removed group becomes a year hint
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Get-ReshelfDiscogsSearchTitleVariants (private); legacy/plan/06-edit-proposal-module.md › Discogs lookup (step 1)

When a removed parenthetical group holds a year, the app keeps it as a year hint. It takes the year from the first such group. A group without digits gives no hint. The plan says the app uses the hint when the recognized year is unresolved.

Examples:
- `Violator (1990) (ALFA ALCB-35) (1st Japan 1990)` → year hint 1990.
- `indigo rose - (progressive form)` → no year hint.

### AS-DOC-MAT-005 — Look-alike letters are folded before the search, with a visible note
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Resolve-ReshelfDiscogsMatch (private) › normalizes a Cyrillic look-alike character in the artist name before querying Discogs (real "Inсubus Succubus" case); › does not treat a genuinely Cyrillic artist name as homoglyph-corrupted; legacy/plan/06-edit-proposal-module.md › Discogs lookup (step 1a)

Before it searches, the app folds Cyrillic or Greek look-alike letters (homoglyphs: letters that look the same as Latin ones) in mostly-Latin artist and title text to Latin. It sends the folded text to Discogs. When folding changed something, the match result carries a note, so the correction is visible in review. Real non-Latin text stays as it is, and there is no note. The folding rule itself: see [02-text-and-naming-rules.md](02-text-and-naming-rules.md).

Examples:
- Artist `Inсubus Succubus` (the `с` is U+0441) → the first master search sends `artist = Incubus Succubus`; the result is `matched` (release 111) with a homoglyph note.
- Artist `Кино`, title `Группа крови` → no homoglyph note.

## Search order

### AS-DOC-MAT-006 — Step 1: master search, each title variant with its year, then without
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Resolve-ReshelfDiscogsMatch (private) › skips the artist-master-list fallback for "Various" (its master list runs into the thousands); › prefers a master's main release over a same-scoring promo edition, and records the masterId (real Grails "The Burden Of Hope" case, plan/12); legacy/README.md › How Discogs matching works (step 1); legacy/plan/06-edit-proposal-module.md › Discogs lookup (step 2 and note)

The app first searches Discogs for a master (`type = master`) with `artist` and `release_title`. It tries each title variant (AS-DOC-MAT-002), first with the year, then without it. It stops at the first search that returns anything. This is at most 4 searches.

Example: artist `Various`, title `Holy Dio`, year 1999, all searches empty → at most 4 master searches on this step.

### AS-DOC-MAT-007 — Step 2: the artist's master list
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Resolve-ReshelfDiscogsMatch (private) › falls back to the artist master list when a release_title master search finds nothing (real Grails "Red Light"/"Redlight" case, plan/12); legacy/README.md › How Discogs matching works (step 1)

When every title master search is empty, the app lists every master credited to the artist. This is a paged search (`per_page`) without `release_title`. It finds a release whose Discogs title differs from the folder name.

Example: artist `Grails`, title `Red Light`, year 2004, 10 source tracks; title searches empty; the artist list returns master 91049 `Grails - Redlight` → `matched`, release 593180, master 91049.

### AS-DOC-MAT-008 — No artist master list for "Various"
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Resolve-ReshelfDiscogsMatch (private) › skips the artist-master-list fallback for "Various" (its master list runs into the thousands)

The app skips step 2 when the artist is `Various`. The Discogs master list for "Various" has thousands of entries.

Example: artist `Various`, title `Holy Dio`, year 1999, every search empty → `not-found`; no request with a `per_page` key.

### AS-DOC-MAT-009 — Step 3: plain release search when no master matches
Status: Draft | Source: legacy/README.md › How Discogs matching works; legacy/plan/06-edit-proposal-module.md › Discogs lookup (steps 2–5 and note); legacy/tests/Reshelf.EditProposal.Tests.ps1 › Resolve-ReshelfDiscogsMatch (private) › falls back to the cleaned title variant when the raw title finds nothing (real "Forwards Special Edition" case)

When no master is found (for example promos or obscure one-offs), the app runs a plain release search (`type = release`) with the same title variants.

Example: artist `The Egg`, title `Forwards Special Edition`, no year; only the search with `release_title = Forwards` returns release 42 `The Egg - Forwards` → `matched`, release 42; more than 1 search ran.

### AS-DOC-MAT-010 — A release hit that names a master moves to the master path
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Resolve-ReshelfDiscogsMatch (private) › promotes a release-search match to its master when the search result itself carries a master_id

When a release-search result carries a `master_id`, the app loads that master and its versions and picks the version as in AS-DOC-MAT-030. The result records the master.

Example: master search empty; release search returns release 999 with `master_id = 555`; 5 source tracks → `matched`, release 999, master 555.

### AS-DOC-MAT-011 — Step 4: the artist's own catalog, when every title search is empty
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Resolve-ReshelfDiscogsMatch (private) › matches by track durations when every title-based search comes up empty (real Maximum The Hormone case, session 2026-10-03-0010: Discogs titles the release only in Japanese)

When every title search finds nothing, the app looks for the artist on Discogs (`type = artist`). It accepts an artist profile whose name variations contain the folder artist name. Then it lists the artist's releases (`/artists/{id}/releases`) and checks each one against the source release (AS-DOC-MAT-012 to AS-DOC-MAT-014). This finds releases that Discogs titles only in Japanese. When the catalog check runs and when it is skipped: see the area file that owns `legacy/README.md` › Reference: Japanese releases.

Example: artist search returns artist 500 `マキシマム ザ ホルモン` with name variation `Maximum The Hormone`; catalog has release 99 `ロッキンポ殺し` (role `Main`, 2005, CD Album).

### AS-DOC-MAT-012 — Catalog match needs equal track count and durations that line up
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Resolve-ReshelfDiscogsMatch (private) › matches by track durations when every title-based search comes up empty (real Maximum The Hormone case, session 2026-10-03-0010: Discogs titles the release only in Japanese)

A catalog release is `matched` when its track count equals the source track count and the track durations line up with the source durations. The test shows exact equal durations. The tolerance value is not in the owned tests.

Example: artist `Maximum The Hormone`, title `Rokkinpo Goroshi`, 2005, 2 source tracks of 125.0 s and 140.0 s; release 99 has `2:05` and `2:20` → `matched`, release 99, title `ロッキンポ殺し`.

### AS-DOC-MAT-013 — A weak catalog match is `ambiguous`, not `not-found`
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Resolve-ReshelfDiscogsMatch (private) › falls back to ambiguous (not not-found) when the catalog-fallback candidate's durations do not line up

When a catalog release has the right track count but its durations do not line up, and no release date proves it, the app does not auto-match. It returns `ambiguous` with that release as a candidate, so the user can pick it in review.

Example: same catalog, source durations 50.0 s and 60.0 s, no release date → `ambiguous`; the first candidate is release 99.

### AS-DOC-MAT-014 — A 1-track catalog match also needs the exact release date
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Resolve-ReshelfDiscogsMatch (private) › needs an exact release date, not just one lucky duration, to auto-match a 1-track single by catalog fallback

One matching duration is not enough evidence. A 1-track catalog release is `matched` only when the recognized release date equals the Discogs release date. Without that date, it stays `ambiguous`.

Examples:
- Title `Zawa`, 2005, 1 track of 125.0 s, no release date; release 77 `ざわざわ` (1 track, `2:05`, released `2005-10-19`) → `ambiguous`.
- The same, with release date `2005-10-19` → `matched`, release 77.

## Candidate scoring

### AS-DOC-MAT-015 — Each candidate gets a score; the threshold is 0.85
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Get-ReshelfDiscogsCandidateScore (private) › scores the correct artist/title/year at or above the match threshold; › scores an unrelated artist/title well below the threshold; legacy/plan/02-discogs-account-and-api-access.md › Matching confidence; legacy/tests/fixtures/discogs-responses/search-response.json

The app scores each search candidate against the expected artist, title and year. A Discogs search result has a title of the form `Artist - Title`. The match threshold is 0.85. A score at or above 0.85 counts as a confident match. The tests do not show the weight of each part.

Examples:
- `Radiohead` / `OK Computer` / 1997 vs fixture result 265498 `Radiohead - OK Computer`, 1997 → score ≥ 0.85.
- `Some Totally Different Band` / `Unrelated Album Title` / no year vs the same result → score < 0.85.

### AS-DOC-MAT-016 — The best score over all title variants counts
Status: Draft | Source: legacy/plan/06-edit-proposal-module.md › Discogs lookup (step 2)

The app scores every candidate against all title variants. It keeps the best score. It does not matter which variant's search found the candidate. No owned test checks this directly.

Example: for `Forwards Special Edition`, a candidate `The Egg - Forwards` is scored against both `Forwards Special Edition` and `Forwards`; the higher score counts.

### AS-DOC-MAT-017 — An extra Discogs subtitle does not block a match
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Get-ReshelfDiscogsCandidateScore (private) › scores a Discogs subtitle Discogs added but the source never has, at the threshold (real Piano Magic "Son De Mar" case, plan/12)

When the Discogs title has an extra parenthetical subtitle that the source does not have, the score still reaches the threshold.

Example: `Piano Magic` / `Son De Mar` / 2001 vs `Piano Magic - Son De Mar (Music From The Film By Bigas Luna)`, 2001, CD Mini-Album → score ≥ 0.85.

### AS-DOC-MAT-018 — A spacing-only difference does not block a match
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Get-ReshelfDiscogsCandidateScore (private) › scores a spacing-only title difference at the threshold (real Grails "Red Light"/"Redlight" case, plan/12)

When the titles differ only in spaces, the score still reaches the threshold.

Example: `Grails` / `Red Light` / 2004 vs `Grails - Redlight`, 2004, CD Album → score ≥ 0.85.

### AS-DOC-MAT-019 — A Compilation format lowers the score
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Get-ReshelfDiscogsCandidateScore (private) › scores an exact-title compilation below the same album, but still at the threshold; › scores a fuzzy-title compilation below the threshold (real Aerosmith "Classic Aerosmith" case)

A candidate with the format `Compilation` scores lower than the same candidate with the format `Album`. With an exact title, it still reaches the threshold. With a fuzzy title, it falls below.

Examples:
- `Some Band` / `Greatest Hits` / no year: `CD, Compilation` scores lower than `CD, Album`, and still ≥ 0.85.
- `Aerosmith` / `Aerosmith` / 1973 vs `Aerosmith - Classic Aerosmith`, 2000, `CD, Compilation, Remastered` → score < 0.85.

### AS-DOC-MAT-020 — Box Set and Unofficial Release formats lower the score
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Get-ReshelfDiscogsCandidateScore (private) › penalizes Box Set and Unofficial Release formats too

A candidate with the format `Box Set` or `Unofficial Release` scores lower than the same candidate with `CD, Album`.

Example: `Some Band` / `Some Title` / 2001: `CD, Box Set` and `CD, Unofficial Release` each score lower than `CD, Album`.

### AS-DOC-MAT-021 — Artist aliases count as the artist
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Get-ReshelfDiscogsCandidateScore (private) › scores a Japanese-only artist credit at the threshold when an artist alias is given (real Maximum The Hormone case, session 2026-10-03-0010)

The caller can give artist aliases. The app compares the candidate artist against the aliases too. So a Discogs credit in another script can match the romanized folder artist. Discogs can add a `*` to a credited name (its marker for a name variation); the test candidate has it.

Example: `Maximum The Hormone` / `Greatest The Hits 2011` / 2011 vs `マキシマム ザ ホルモン* - Greatest The Hits 2011-2011`, CD Maxi-Single → without alias < 0.85; with alias `マキシマム ザ ホルモン` ≥ 0.85.

### AS-DOC-MAT-022 — A Discogs `X = Y` title is compared by its romanized half
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Get-ReshelfDiscogsCandidateScore (private) › scores a Discogs "X = Y" title at the threshold by comparing against its romanized half (real Maximum The Hormone "Tsume Tsume Tsume'F" case)

When a Discogs title has the form `romanized = original`, the app compares the expected title against the romanized half.

Example: `Maximum The Hormone` / `Tsume Tsume Tsume'F` / 2008, alias `マキシマム ザ ホルモン`, vs `マキシマム ザ ホルモン* - Tsume Tsume Tsume / 「F」= 爪爪爪 / 「F」`, 2008, CD Single → score ≥ 0.85.

## Match result

### AS-DOC-MAT-023 — `matched`: best score at or above the threshold, with full detail
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Resolve-ReshelfDiscogsMatch (private) › returns matched with fetched detail when the top score is above the threshold; legacy/plan/02-discogs-account-and-api-access.md › Matching confidence; legacy/plan/06-edit-proposal-module.md › Discogs lookup (steps 3, 5); legacy/tests/fixtures/discogs-responses/release-response.json

When the best candidate reaches the threshold, the status is `matched`. The app selects it automatically. It loads the full detail (`/releases/{id}`): tracklist, year, formats, artists, images. The result has the selected release ID, the detail and the candidate list.

Example: `Radiohead` / `OK Computer` / 1997 with the two fixtures → `matched`; release 265498; detail title `OK Computer` (3 tracks: `Airbag`, `Paranoid Android`, `Subterranean Homesick Alien`); candidates not empty.

### AS-DOC-MAT-024 — `ambiguous`: best score below the threshold, no auto-select
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Resolve-ReshelfDiscogsMatch (private) › returns ambiguous with candidates but no detail fetch when the top score is below the threshold; legacy/plan/02-discogs-account-and-api-access.md › Matching confidence; legacy/plan/02-discogs-account-and-api-access.md › Decisions & rationale

When the best score is below the threshold, the status is `ambiguous`. The app selects nothing and does not load release detail. It attaches the candidates for the user to choose in review (the plan: the top 5). The user resolves it in the review UI: see [09-review-ui.md](09-review-ui.md). The catalog step is an exception: it loads detail to compare durations (AS-DOC-MAT-013).

Example: `Some Totally Different Band` / `Unrelated Album` / no year vs the search fixture → `ambiguous`; no selected release; no detail; candidates not empty.

### AS-DOC-MAT-025 — `not-found`: no search returns anything
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Resolve-ReshelfDiscogsMatch (private) › returns not-found when the search yields zero results; legacy/plan/02-discogs-account-and-api-access.md › Edge cases

When every search returns zero results, the status is `not-found`. The plan routes it to review the same way as `ambiguous` (see [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md)).

Example: every search returns `results = @()` → `not-found`.

### AS-DOC-MAT-026 — A network failure gives `not-found` with an error note
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Resolve-ReshelfDiscogsMatch (private) › catches a network failure and returns not-found with an error note instead of throwing; legacy/plan/02-discogs-account-and-api-access.md › Edge cases

When a Discogs request fails (after the retries in [06-discogs-client.md](06-discogs-client.md)), the match step does not stop the run. It returns `not-found` with an error note that holds the error message. The other releases of the run continue.

Example: every request throws `network is down` → `not-found`; the error note contains `network is down`.

### AS-DOC-MAT-027 — Several candidates over the threshold: the one whose track count matches wins
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Resolve-ReshelfDiscogsMatch (private) › picks the eligible candidate whose real tracklist count matches the source, not just the top score; legacy/plan/06-edit-proposal-module.md › Discogs lookup (step 4)

When more than one candidate reaches the threshold, the app loads the tracklists of up to 5 of them. It picks the first one, in search-result order, whose track count equals the source track count. With exactly one candidate over the threshold, it loads only that one.

Example: Pivot `O Soundtrack My Heart`, 2008, 11 source tracks. Candidate 1 is a 7" Single (2 tracks), candidate 2 is a CD Album (11 tracks) → `matched`, release 2, 11 tracks.

### AS-DOC-MAT-028 — No track count matches: the format preference decides
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Resolve-ReshelfDiscogsMatch (private) › prefers an Album-format candidate over a Promo one when no eligible candidate matches the source track count; legacy/plan/06-edit-proposal-module.md › Discogs lookup (step 4)

When none of the loaded tracklists has the source track count, the app picks the candidate with the best format rank (AS-DOC-MAT-029). The status is still `matched`.

Example: `Some Band` / `Some Album` / 2010, 9 source tracks. Candidate 1 `CDr, Promo` (5 tracks), candidate 2 `CD, Album` (7 tracks) → `matched`, release 2.

### AS-DOC-MAT-029 — Format preference: Album, EP, Single, Promo, then the rest
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Get-ReshelfDiscogsFormatPreferenceRank (private)

The app ranks a candidate's format text. A lower rank is preferred.

| Format text contains | Rank |
|---|---|
| Album | 0 |
| EP | 1 |
| Single | 2 |
| Promo | 3 |
| none of these | 4 |

Examples: `CD, Album` → 0; `Vinyl, EP` → 1; `Vinyl, 7", 45 RPM, Single` → 2; `CDr, Promo` → 3; `Cassette` → 4.

## Master and version selection

### AS-DOC-MAT-030 — On the master path, the main release is tried first
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Resolve-ReshelfDiscogsMatch (private) › prefers a master's main release over a same-scoring promo edition, and records the masterId (real Grails "The Burden Of Hope" case, plan/12); legacy/README.md › How Discogs matching works (step 2)

When a master matches, the app loads the master and its versions (pressings). It tries the master's main release first. When the main release's track count equals the source, the app picks it. Otherwise it tries the other versions in rank order (AS-DOC-MAT-031) and picks the first one with the source track count. The result records the master ID and the master data. The candidates are the master's versions.

Example: Grails `The Burden Of Hope`, 2003, 10 source tracks; master 26213, main release 384825 (CD Album, 10 tracks); other version 10136207 (`Album, Promo`) → `matched`, release 384825, master 26213, 2 candidates.

### AS-DOC-MAT-031 — Version rank order: year, edition, format group, not promo, collection count
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Sort-ReshelfDiscogsVersions / Get-ReshelfDiscogsVersionRank (private) › prefers the version whose released year matches the folder year, then a CD/File format over Vinyl, then higher community count; legacy/README.md › How Discogs matching works (step 2); legacy/plan/06-edit-proposal-module.md › Discogs lookup (note)

The app sorts the versions by these rules, in this order:

1. the released year equals the folder year;
2. an edition hint from the folder title matches the version (AS-DOC-MAT-034);
3. format group: CD or File first, then Vinyl or Cassette, then every other format (AS-DOC-MAT-033);
4. not a Promo or Test Pressing (AS-DOC-MAT-032);
5. higher Discogs "in collection" count.

Example: no folder year, no hints; versions 1 (2019, Vinyl, 1 in collection), 2 (2005, CD, 228), 3 (2005, File, 6) → version 2 first.

### AS-DOC-MAT-032 — A Promo or Test Pressing ranks behind an equal version
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Sort-ReshelfDiscogsVersions / Get-ReshelfDiscogsVersionRank (private) › ranks a Promo/Test Pressing version behind an otherwise-equal one

Between two otherwise equal versions, the one marked Promo or Test Pressing comes second.

Example: version 1 `Album, Promo` (CD, 2010) and version 2 `Album` (CD, 2010) → version 2 first.

### AS-DOC-MAT-033 — Rare formats rank behind Vinyl and Cassette
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Sort-ReshelfDiscogsVersions / Get-ReshelfDiscogsVersionRank (private) › ranks Vinyl/Cassette above a rarer format (e.g. 8-Track Cartridge) even when the rarer format matches the folder year

A version in a format other than CD, File, Vinyl or Cassette ranks last in the format group. The reason (test comment): an 8-Track Cartridge splits tracks into "programs", so its track order differs from the standard release.

Example: folder year 1975; version 1 `8-Track Cartridge`, version 2 `Vinyl`, version 3 `Cassette`, all 1975 → version 1 is last; versions 2 and 3 are first and second.

### AS-DOC-MAT-034 — An edition hint matches a format descriptor token first, then the pressing title
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Sort-ReshelfDiscogsVersions / Get-ReshelfDiscogsVersionRank (private) › matches an edition hint against Discogs' own comma-separated format descriptors, not a raw substring of format+title; legacy/plan/06-edit-proposal-module.md › Discogs lookup (note); legacy/README.md › How Discogs matching works (step 2)

The app takes edition hints (for example `Deluxe Edition`, `Special Edition`) from the folder title. It splits the version's format text at commas and compares the hint with each token. Only when no token matches does it check whether the pressing title contains the hint.

Example: hint `Deluxe Edition`; version 1 `CD, Album, Reissue`, version 2 `CD, Album, Reissue, Deluxe Edition` → version 2 first.

### AS-DOC-MAT-035 — An edition hint does not match part of another token
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Sort-ReshelfDiscogsVersions / Get-ReshelfDiscogsVersionRank (private) › does not false-positive an edition hint against an unrelated substring in format/title

A hint does not match a format token only because the token contains the hint text.

Examples:
- Hint `Limited` vs `CD, Album, Unlimited Access` → no edition match.
- Hint `Limited Edition` vs `CD, Album, Limited Edition` → edition match.

### AS-DOC-MAT-036 — A Vinyl or Cassette pick is replaced by a CD or File version with the same track count
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Resolve-ReshelfDiscogsMatch (private) › prefers a CD version over the master's own Vinyl main release when both match the source track count (real OOIOO "Feather Float" case, plan/12); legacy/README.md › How Discogs matching works (step 3)

When the picked version is Vinyl or Cassette, and a CD or File version has the same track count, the app picks the CD or File version. Source rips are digital files, so a CD or File pressing is closer.

Example: OOIOO `Feather Float`, 1999, 11 source tracks; master 8707, main release 1338686 (Vinyl LP, 1999, 11 tracks); version 368574 (CD Album, 2001, 11 tracks) → `matched`, release 368574, master 8707.

### AS-DOC-MAT-037 — The master's year is the release year
Status: Draft | Source: legacy/README.md › How Discogs matching works (step 4)

When the match has a master, the release's Year tag and folder name use the master's year (the original year). They do not use the picked pressing's own year. No owned test checks this. How the year goes into names and tags: see [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md).

Example: a 2019 reissue of a 2005 album → Year 2005.

### AS-DOC-MAT-038 — The master's image is a fallback cover candidate
Status: Draft | Source: legacy/README.md › How Discogs matching works (step 5)

When the picked pressing has no cover image on Discogs, the app adds the master's own image as a cover candidate. The gallery is not empty then. No owned test checks this. The cover candidate list: see [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md).

Example: picked pressing `images = @()`, master has an image → the master image is a cover candidate.

## Reading a Discogs tracklist

### AS-DOC-MAT-039 — An index entry's sub-tracks become separate playable tracks
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Get-ReshelfDiscogsPlayableTracks (private) › flattens an index entry's sub_tracks into individual playable tracks (real Guapo "Five Suns" case, plan/12)

The app builds the list of playable tracks from the Discogs tracklist. An entry of type `index` is replaced by its sub-tracks, one playable track each.

Example: Guapo: index `Five Suns` with sub-tracks `Five Suns I` … `Five Suns V`, then `(silence)`, `Mictlan`, `Topan` → 8 playable tracks; first `Five Suns I`, last `Topan`.

### AS-DOC-MAT-040 — Headings and entries without a position are not tracks
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Get-ReshelfDiscogsPlayableTracks (private) › skips headings and empty-position entries, and keeps a plain track with its own sub_tracks as one entry

The app skips `heading` entries and entries with an empty position. A plain track (type `track`) that has its own sub-tracks stays one playable track.

Example: heading `Disc 1`, track `1` `A Song` with sub-tracks `Part a`, `Part b`, track `2` `Another Song` → 2 playable tracks; first `A Song`.

### AS-DOC-MAT-041 — Sub-tracks inherit the index entry's artists
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Get-ReshelfDiscogsPlayableTracks (private) › gives an index entry's own sub_tracks its per-track artists when a sub-track has none of its own

A sub-track without its own artists gets the artists of its index entry. A sub-track with its own artists keeps them.

Example: index `Five Suns` with artist `Guapo`; sub-track `Five Suns I` (no artists) → `Guapo`; sub-track `Five Suns II` (artist `Someone Else`) → `Someone Else`.

### AS-DOC-MAT-042 — A position gives disc and track numbers
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Get-ReshelfDiscogsPositionParts (private) › parses disc-track positions; legacy/plan/06-edit-proposal-module.md › Computing proposed names and tags

The app reads a disc number and a track number from a Discogs position in the forms `D-T`, `CDD-T` and `D.TT`. How the numbers are used: see [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md).

Examples: `1-3` → disc 1, track 3; `CD2-1` → disc 2, track 1; `2.05` → disc 2, track 5.

### AS-DOC-MAT-043 — A plain number is a track only; vinyl sides give nothing
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Get-ReshelfDiscogsPositionParts (private) › parses a plain number as a track with no disc; › returns nothing usable for vinyl sides or empty input

A plain number gives a track number and no disc number. A vinyl side position, an empty position and no position give neither.

Examples: `7` → no disc, track 7; `A1`, `B2`, ``, null → no disc, no track.

## Track alignment

### AS-DOC-MAT-044 — Title alignment pairs each source track with one Discogs track (similarity ≥ 0.8)
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Resolve-ReshelfDiscogsTrackAlignment (private) › aligns every source track to its own Discogs track by title and notes the one Discogs has extra; legacy/plan/06-edit-proposal-module.md › Edge cases

When the Discogs track count differs from the source, the app tries to pair every source track with its own Discogs track by title similarity. A pair needs a similarity of at least 0.8. The source title comes from the existing title tag, or from the file name without the number prefix and the extension. On success, the result has the aligned Discogs tracks, their 1-based positions in the Discogs list, and a note that names the Discogs tracks the source does not have, as `missing on source: <position> <title>`.

Example: source `01 - Indigo Rose.flac`, `02 - Sun.flac`; Discogs `1 Cover Your Ears`, `2 Indigo Rose`, `3 Sun` → aligned; titles `Indigo Rose`, `Sun`; indices 2, 3; note `missing on source: 1 Cover Your Ears`.

### AS-DOC-MAT-045 — A source track without a good match stops the alignment
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Resolve-ReshelfDiscogsTrackAlignment (private) › does not align when a source track has no good match (score below 0.8); legacy/plan/06-edit-proposal-module.md › Edge cases

When one source track has no Discogs track with similarity ≥ 0.8 (and number alignment does not apply), the alignment fails and returns no tracks. The plan says the whole release then uses the source titles and goes to review (see [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md)).

Example: source `01 - Completely Unrelated Name.flac`; Discogs `1 Airbag`, `2 Paranoid Android` → not aligned; 0 tracks.

### AS-DOC-MAT-046 — One Discogs track serves at most one source track
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Resolve-ReshelfDiscogsTrackAlignment (private) › does not reuse the same Discogs track for two different source tracks; legacy/plan/06-edit-proposal-module.md › Edge cases

The pairing is one-to-one. The app does not use one Discogs track for two source tracks.

Example: source `01 - Airbag.flac`, `02 - Some Other Song.flac`; Discogs only `1 Airbag` → not aligned.

### AS-DOC-MAT-047 — Number alignment when titles do not match well enough
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Resolve-ReshelfDiscogsTrackAlignment (private) › falls back to track-number alignment when titles do not match well enough (real OOIOO "Feather Float" case, plan/12)

When title alignment fails, the app pairs each source track with the Discogs track at the source track's detected number. The result says the method is `number`. In the test, every source track has a detected number and no inferred order.

Example: OOIOO, 10 source files numbered 1–6 and 8–11 (some titles written differently, e.g. `03 Ina (Kanji).mp3` vs `Ina 咲くの唄`); Discogs has 11 tracks → aligned, method `number`; 10 tracks; indices 1, 2, 3, 4, 5, 6, 8, 9, 10, 11; note `missing on source: 7 Asozan`.

### AS-DOC-MAT-048 — No number alignment on a multi-disc source
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Resolve-ReshelfDiscogsTrackAlignment (private) › does not use number alignment across a multi-disc release

The app does not use number alignment when the source tracks are in disc folders.

Example: source `01 - Nothing Alike.flac` in disc folder `CD1`, number 1; Discogs `1 Totally Different Title`, `2 Another One` → not aligned.

## Artist credit

### AS-DOC-MAT-049 — A Discogs artist credit uses the name without the disambiguation suffix
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Get-ReshelfDiscogsArtistCredit (private) › returns a single artist name unchanged; › strips a Discogs disambiguation suffix; › uses name, not anv (the credited name variation)

The app builds an artist credit from a Discogs `artists` list. It uses each artist's `name`, not `anv` (the credited name variation). It removes the Discogs disambiguation suffix ` (N)`. Where the credit is used: see [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md).

Examples: `The Dubliners` → `The Dubliners`; `Genesis (2)` → `Genesis`; name `Prince`, anv `The Artist` → `Prince`.

### AS-DOC-MAT-050 — Several artists are joined with the Discogs join text
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Get-ReshelfDiscogsArtistCredit (private) › joins two artists with the Discogs join text; › joins with a comma when the join text is a comma; legacy/plan/06-edit-proposal-module.md › Computing proposed names and tags

The app joins several artists with each artist's Discogs `join` text. A word join gets a space on both sides. A comma join gets a space only after it.

Examples: `Simon` (join `&`) + `Garfunkel` → `Simon & Garfunkel`; `A` (join `,`) + `B` → `A, B`.

### AS-DOC-MAT-051 — A feat. join ends the credit
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Get-ReshelfDiscogsArtistCredit (private) › drops a featured artist that follows a feat. join, keeping only the main artist(s); legacy/plan/06-edit-proposal-module.md › Computing proposed names and tags; legacy/plan/06-edit-proposal-module.md › Decisions & rationale

When an artist's join text is a featuring join, the credit stops there. The featured artist is not in the credit. The test shows `feat.`. The plan also names `ft.` and `featuring`.

Example: `Jay-Z` (join `feat.`) + `Alicia Keys` → `Jay-Z`.

### AS-DOC-MAT-052 — No artists means no credit
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Get-ReshelfDiscogsArtistCredit (private) › returns null for an empty or missing artists array

An empty or missing `artists` list gives no credit (null).

Example: `@()` → null; `$null` → null.

## Compilations and Various Artists

### AS-DOC-MAT-053 — A release is a compilation when Discogs credits "Various" (id 194)
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Test-ReshelfIsCompilationArtist (private); legacy/plan/06-edit-proposal-module.md › Computing proposed names and tags

When the match is `matched`, the release is a compilation if the Discogs release artist is "Various" (Discogs artist id 194). When there is no Discogs match, the release is a compilation if the recognized artist or folder name is `Various` or `Various Artists`. What a compilation changes: see [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md).

Examples:
- `matched`, artist `Various` id 194 → compilation.
- `matched`, artist `Metallica` id 1 → not a compilation.
- `not-found`, name `Various Artists` → compilation; `not-found`, name `Some Band` → not a compilation.

### AS-DOC-MAT-054 — A folder looks like Various Artists when its tracks have many different artists
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Get-ReshelfVariousArtistsEvidence (private) › looks like Various Artists when every track has a different tagged artist than the folder; › is false for a normal single-artist release (every track tagged with the folder artist); › is false for a 2-artist split release (not enough distinct artists)

The app checks the source tracks' artists against the folder artist. The release "looks like Various Artists" when every track has an artist different from the folder artist and there are enough distinct artists. 3 tracks with 3 different artists is enough. 2 distinct artists is not enough. The result also gives the distinct artist count, the count of tracks that differ, and the list of track artists. The test comment says the app uses this for a Various-Artists tribute that a search on the folder artist never finds. What the app does with the evidence: see [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md).

Examples:
- Folder `DIO`; tracks tagged `Blind Guardian`, `Primal Fear`, `Doro` → looks like Various; 3 distinct; 3 differing; artists `Blind Guardian`, `Primal Fear`, `Doro`.
- Folder `Radiohead`; every track tagged `Radiohead` → no.
- Folder `Band A`; tracks `Band A`, `Band A`, `Band B` → no.

### AS-DOC-MAT-055 — A featured guest counts as the main artist
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Get-ReshelfVariousArtistsEvidence (private) › treats a "feat." guest as the same artist as the main credit

For this check, the app ignores the `feat.` part of a track artist.

Example: folder `Metallica`; tracks `Metallica`, `Metallica feat. Justin Bieber`, `Metallica` → no.

### AS-DOC-MAT-056 — A folder that is already "Various" gives no evidence
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Get-ReshelfVariousArtistsEvidence (private) › is false when the folder is already "Various"/"Various Artists" (no retry needed)

When the folder artist is already `Various` or `Various Artists`, the result is "no". A retry as Various is not needed.

Example: folder `Various`; tracks `Band A`, `Band B`, `Band C` → no.

### AS-DOC-MAT-057 — Without artist tags, a consistent `Artist - Title` file name gives the artist
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Get-ReshelfVariousArtistsEvidence (private) › falls back to a consistent "Artist - Title" file name when no track has an Artist tag; › ignores file-name artists when not every track has one (inconsistent naming)

When no track has an artist tag, the app reads the artist from the file name in the form `[NN] Artist - Title`. It does this only when every track's file name has this form.

Examples:
- Folder `DIO`; no tags; `[01] Blind Guardian - Title One.mp3`, `[02] Primal Fear - Title Two.mp3`, `[03] Doro - Title Three.mp3` → looks like Various; artists `Blind Guardian`, `Primal Fear`, `Doro`.
- Folder `DIO`; no tags; `[01] Blind Guardian - Title One.mp3`, `02 Title Two.mp3`, `03 Title Three.mp3` → no.

## Track-number pad width

### AS-DOC-MAT-058 — The file number has at least 2 digits and grows with the track count
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Get-ReshelfProposalPadWidth (private) › returns 2 for track counts up to 99; › grows beyond 2 for larger track counts; legacy/plan/06-edit-proposal-module.md › Computing proposed names and tags

The pad width of the track number in a file name is the number of digits of the track count, but at least 2. How the number is built: see [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md).

Examples: 1, 9, 99 tracks → 2; 100, 999 → 3; 1000 → 4.

### AS-DOC-MAT-059 — `trackNumberPadWidth` is a floor, not a fixed width
Status: Draft | Source: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Get-ReshelfProposalPadWidth (private) › uses -MinWidth as a floor, not a fixed value, when settings.trackNumberPadWidth is raised; legacy/plan/06-edit-proposal-module.md › Computing proposed names and tags

Same rule as AS-DOC-PRP-018 in [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md) (primary). This entry keeps its unit-test source.

The minimum width comes from the setting `trackNumberPadWidth` (default 2, see [03-settings-and-secrets.md](03-settings-and-secrets.md)). A track count that needs more digits still wins.

Examples: minimum 3: 1 track → 3; 9 → 3; 1000 → 4.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-05 | Phase 1 draft. |
