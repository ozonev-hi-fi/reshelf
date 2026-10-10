# Proposal naming and tags — as-is from code (PRP)

Status: Draft | Version: 0.1 | Last updated: 2026-10-10

Source file: `legacy/scripts/common/Reshelf.EditProposal.psm1`, lines 1332–2928.

### AS-CODE-PRP-001 — Naming template placeholders are plain string substitution
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1332 › Expand-ReshelfNamingTemplate

A naming template is expanded by replacing each `{key}` literally with the matching value from a hashtable, one key at a time, using plain string `.Replace()` (not a regex, not a single pass over the whole template). Any `{key}` left in the template for which the hashtable has no matching key is left untouched in the output.

Example: Template `"{year} {album}"` with values `{ year = 2005; album = "Angherr Shisspa" }` → `"2005 Angherr Shisspa"`.

### AS-CODE-PRP-002 — File-number pad width is a configurable floor, not a fixed width
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1350 › Get-ReshelfProposalPadWidth

The zero-pad width used for file numbers is `Max(MinWidth, number of digits in the total track count)`. `MinWidth` defaults to 2. A release with more tracks than the configured minimum always gets a wider pad so file names still sort correctly (e.g. track 100 never collides with "10" when padded to only 2 digits).

Example: `TotalTrackCount = 7`, default `MinWidth = 2` → pad width 2 (`"07"`). `TotalTrackCount = 124`, `MinWidth = 2` → pad width 3 (`"007"`... `"124"`).

### AS-CODE-PRP-003 — Local romanized title prefers the source's own tags over its folder name
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1366 › Get-ReshelfLocalRomanizedTitle

To find a romanized album title the source itself already carries (used to pair with a Japanese-only Discogs title), the code first collects every track's existing `Album` tag value, picks the most frequent one (ties broken by first-seen order via `Group-Object` + `Sort-Object -Descending`), and uses it — Title Cased — only if that value passes the romanized-text check.

Example (illustration): Discogs only has "ロッキンポ殺し" for a release whose files' own `Album` tag already reads "Rokkinpo Goroshi" → the local romanized title resolves to "Rokkinpo Goroshi" (Title Cased), taken from the tags rather than from any folder name.

### AS-CODE-PRP-004 — Local romanized title falls back to the recognized folder title
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1366 › Get-ReshelfLocalRomanizedTitle

When no tag-derived `Album` value exists or qualifies as romanized text, the function falls back to `Release.recognizedTitle` (the title recognition derived from the source folder/file names), Title Cased, again only if it passes the romanized-text check.

### AS-CODE-PRP-005 — No local romanized title is reported as null, never guessed
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1366 › Get-ReshelfLocalRomanizedTitle

If neither the tags nor the recognized folder title are romanized text, the function returns `$null` rather than inventing a romanized value. Callers then fall back to a Discogs-only (non-bilingual) title.

### AS-CODE-PRP-006 — Various/Various Artists never gets a bilingual artist name
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1394 › Get-ReshelfBilingualArtistName

If the trimmed artist name is exactly `'Various'` or `'Various Artists'`, the function returns `$null` immediately — a compilation's "Various Artists" credit is never turned into a bilingual "Romanized = Original" form.

### AS-CODE-PRP-007 — Bilingual evidence requires a Japanese-only Discogs credit on a matched release
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1394 › Get-ReshelfBilingualArtistName

Evidence that an artist's own Discogs credit is Japanese-only text (not merely a title that happens to contain Japanese characters) is taken only from matched releases: the first matched release whose detail has at least one artist credit is used, the trailing Discogs disambiguation suffix (e.g. `" (2)"`) is stripped with `-replace '\s+\(\d+\)$', ''`, invisible characters are removed, and the result is kept only if it contains Japanese script.

Example (illustration): Maximum The Hormone's own release credit reads "マキシマム ザ ホルモン" with no romanized half at all → this is the qualifying Discogs name evidence. A Japanese pressing of a non-Japanese act (e.g. Iron Maiden) does not qualify, because that act's own artist credit stays Latin-script even when the release title is partly Japanese.

### AS-CODE-PRP-008 — No Japanese-script Discogs evidence means no bilingual name
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1394 › Get-ReshelfBilingualArtistName

If no matched release yields a Japanese-script artist credit, the function returns `$null`.

### AS-CODE-PRP-009 — Bilingual name also requires a romanized source value to pair with
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1394 › Get-ReshelfBilingualArtistName

Even with qualifying Japanese-script Discogs evidence, the function returns `$null` if the caller-supplied `ArtistName` (the source folder's own name) does not itself pass the romanized-text check — there would be no romanized half to join.

### AS-CODE-PRP-010 — Bilingual artist name is "Romanized = Original" with the romanized half Title Cased
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1394 › Get-ReshelfBilingualArtistName

When both conditions hold, the result is built by joining the Title-Cased romanized `ArtistName` with the raw Japanese Discogs name, in that order, using the same join convention used for titles (`Join-ReshelfBilingualName`).

Example (illustration): `ArtistName = "maximum the hormone"`, Discogs evidence `"マキシマム ザ ホルモン"` → `"Maximum The Hormone = マキシマム ザ ホルモン"`.

### AS-CODE-PRP-011 — Matched-release artist name: shared bilingual name wins, else Discogs text as-is minus invisible characters
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1427 › New-ReshelfProposedReleaseNames

For a `matched` release, the artist used for folder/tag is the precomputed `ArtistDisplayName` (shared bilingual name, set when any release of this artist carried Japanese-script evidence) when given; otherwise it is Discogs' first artist credit with its trailing `" (N)"` disambiguation suffix stripped and invisible characters removed — with no case change at all, since Discogs' own casing (e.g. lowercase "edbl") is treated as authoritative.

### AS-CODE-PRP-012 — Matched-release title follows the same bilingual "X = Y" convention as the artist
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1427 › New-ReshelfProposedReleaseNames

The title is `Join-ReshelfBilingualName` of the local romanized title (Get-ReshelfLocalRomanizedTitle) and Discogs' own title with invisible characters removed. If Discogs already carries both halves of its own "X = Y" convention, that is passed through unchanged; the source's local romanized text is added only when Discogs' title is Japanese-only and the source has its own romanized text to contribute.

### AS-CODE-PRP-013 — Matched-release year prefers the master's year over the specific pressing's year
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1427 › New-ReshelfProposedReleaseNames

When the match has a master and the master's `year` is truthy (Discogs represents "unknown" as `0`, which is falsy), the master's year is used; otherwise the picked pressing's own `Detail.year` is used. This favors a release's original year (grouping every pressing under one original work) over a later reissue's own year.

Example (illustration): Koenjihyakkei "Angherr Shisspa" — the picked pressing is a 2019 reissue, but its master's year is 2005 → proposed year is 2005.

### AS-CODE-PRP-014 — Unmatched-release artist name: shared bilingual name wins, else Title Case of the source folder name
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1427 › New-ReshelfProposedReleaseNames

When there is no Discogs match for this specific release, `ArtistDisplayName` (if set from another release of the same artist) is still used — so every release of one artist shares the same artist folder/tag name even when only some of its releases matched on Discogs. Otherwise the source `ArtistName` is Title Cased.

Example: source folder artist name `"aoki takamasa"` with no bilingual evidence anywhere → `"Aoki Takamasa"`.

### AS-CODE-PRP-015 — Unmatched-release title is Title Case of the recognized title
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1427 › New-ReshelfProposedReleaseNames

With no Discogs match, the title is simply `Release.recognizedTitle`, Title Cased — no bilingual join is attempted since there is no Discogs text to pair with.

### AS-CODE-PRP-016 — Unmatched-release year is the recognized year, unmodified
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1427 › New-ReshelfProposedReleaseNames

With no Discogs match, the year is `Release.recognizedYear` as-is (whatever recognition derived from the source).

### AS-CODE-PRP-017 — Unresolved year falls back to a hardcoded sentinel value and flags the release
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1427 › New-ReshelfProposedReleaseNames

If the resolved year is falsy (null or `0`) after the matched/unmatched logic above, the code substitutes `$script:UnresolvedYearSentinel` and sets `UsedSentinelYear = $true` on the result. A later comment in this same file (Resolve-ReshelfTargetComparison, around line 2237) confirms this sentinel's literal value is **1900**.

### AS-CODE-PRP-018 — Artist and title are sanitized into file-system-safe names, with substitutions tracked
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1427 › New-ReshelfProposedReleaseNames

The raw artist and title strings are each passed through `ConvertTo-SafeFileName` (context `"artist folder name"` / `"release folder name"`) to produce a `SafeName` plus a list of `Substitutions` (characters that had to be changed to make a valid folder/file name). Both substitution lists are concatenated into the result's `Substitutions` field.

### AS-CODE-PRP-019 — Release folder name is built from the template and trimmed
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1427 › New-ReshelfProposedReleaseNames

`ReleaseFolderName` is `Expand-ReshelfNamingTemplate` applied to `ReleaseFolderTemplate` with `{year}` (cast to `int`) and `{album}` (the sanitized title) substituted, then `.Trim()`-ed.

Example: template `"{year} {album}"`, year `2005`, sanitized album `"Angherr Shisspa"` → `"2005 Angherr Shisspa"`.

### AS-CODE-PRP-020 — The returned name object separates raw (tag) text from sanitized (folder) text
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1427 › New-ReshelfProposedReleaseNames

The result exposes both the sanitized `ArtistFolderName`/`ReleaseFolderName` (for file-system paths) and the raw, possibly-bilingual `Artist`/`Album` (for ID3-style tags, which can hold characters a folder name cannot), plus `Year`, `IsCompilation` (from `Test-ReshelfIsCompilationArtist`), `UsedSentinelYear`, and the combined `Substitutions` list.

### AS-CODE-PRP-021 — Title-based track alignment requires every source track to find its own distinct Discogs track
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1508 › Get-ReshelfDiscogsTitleAlignment

When the Discogs tracklist count doesn't match the source track count, title alignment is tried first: for each source track (tag title, else filename-derived title, normalized) the best-scoring unused Discogs track (via `Get-ReshelfStringSimilarity`) is picked. A track can only be claimed once (`$usedDiscogsIndices`).

### AS-CODE-PRP-022 — A similarity score below 0.8 for any single source track fails the whole alignment
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1508 › Get-ReshelfDiscogsTitleAlignment

The match threshold is a hardcoded **0.8** similarity score. If even one source track's best candidate scores below 0.8 (or no candidate remains), the function gives up entirely and returns `Aligned = $false` — it is all-or-nothing, not a partial/best-effort alignment.

### AS-CODE-PRP-023 — Unclaimed Discogs tracks after a successful alignment are reported as a "missing on source" note
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1508 › Get-ReshelfDiscogsTitleAlignment

On success, every Discogs track never claimed by a source track is listed (as `"<position> <title>"`) and joined into `"missing on source: ..."`, or `$null` if none are left over.

### AS-CODE-PRP-024 — Number-based alignment only applies to single-disc releases
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1563 › Get-ReshelfDiscogsNumberAlignment

Number alignment (the fallback when title alignment fails) requires every source track's `discFolder` to be `$null` (single disc). Any multi-disc release fails this alignment method immediately.

### AS-CODE-PRP-025 — Number-based alignment only trusts numbers that actually came from the file name
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1563 › Get-ReshelfDiscogsNumberAlignment

If any source track has `inferredTrackOrder` set (meaning its track number was guessed, not read from the file name), the whole alignment is rejected — a number this method relies on must be a real, file-name-derived number.

### AS-CODE-PRP-026 — Number-based alignment requires in-range, unique numbers across all source tracks
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1563 › Get-ReshelfDiscogsNumberAlignment

Every `detectedTrackNumberInDisc` must be non-null, between 1 and the Discogs tracklist count inclusive, and unique across the source tracks; otherwise `Aligned = $false`. (An empty `SourceTracks` collection also fails this method.)

### AS-CODE-PRP-027 — Number-paired tracks must still agree on title at least two-thirds of the time
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1563 › Get-ReshelfDiscogsNumberAlignment

Even after numbers line up, the function requires the title-similarity score (threshold 0.8, same as title alignment) to also match for at least **2/3** of the number-paired tracks, or the alignment is rejected — numbers merely falling in range is not trusted on its own.

Example (illustration): OOIOO "Feather Float" is missing track 07 ("Asozan"); several remaining files carry a differently transliterated title that never clears 0.8 on title similarity alone, but their file-derived track numbers still line up 1:1 with Discogs' position numbers, so number alignment succeeds where title alignment did not.

### AS-CODE-PRP-028 — Number-based alignment reports the same "missing on source" note format as title alignment
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1563 › Get-ReshelfDiscogsNumberAlignment

Unclaimed Discogs tracks are listed the same way as in title alignment: `"<position> <title>"` joined into a single `"missing on source: ..."` string.

### AS-CODE-PRP-029 — Track alignment tries title matching first, then number matching, then gives up
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1626 › Resolve-ReshelfDiscogsTrackAlignment

`Resolve-ReshelfDiscogsTrackAlignment` is a strict fallback chain: title alignment is attempted first; only if it fails is number alignment attempted; only if both fail does the release fall back to source-derived titles entirely (`Aligned = $false`, `Method = $null`). The successful method name (`'title'` or `'number'`) is surfaced in the result for the caller's own review note.

### AS-CODE-PRP-030 — Disc.Track positions are parsed from an optional "CD/DVD/Disc" prefix plus two numbers
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1658 › Get-ReshelfDiscogsPositionParts

A Discogs track `position` string is parsed with the regex `^(?:CD|DVD|Disc)?\s*(\d+)\s*[-.]\s*(\d+)$`, producing a disc number and a track number. The disc-type prefix, if present, is discarded — only the two numbers matter.

Example: `"CD2-5"` → Disc 2, Track 5. `"1.12"` → Disc 1, Track 12.

### AS-CODE-PRP-031 — A bare number is parsed as a track-only position with no disc
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1658 › Get-ReshelfDiscogsPositionParts

If the position is just digits (`^(\d+)$`), it is treated as `Track = <number>`, `Disc = $null`.

Example: `"7"` → Disc `$null`, Track 7.

### AS-CODE-PRP-032 — Vinyl/cassette-style side labels and anything unrecognized yield no usable numbers
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1658 › Get-ReshelfDiscogsPositionParts

Any position that doesn't match either pattern above (e.g. `"A1"`, `"B2"`) returns `Disc = $null, Track = $null` — this position carries no numeric information this code can use.

### AS-CODE-PRP-033 — Tracks are grouped into discs by discFolder, in first-seen order
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1680 › New-ReshelfProposedTrackSet

Tracks are grouped by their `discFolder` value, preserving the order each distinct `discFolder` is first encountered. A single-disc release (every track's `discFolder` is `$null`) naturally collapses into exactly one group, which becomes disc 1.

### AS-CODE-PRP-034 — Discogs indices default to a straight 1:1 mapping when not supplied
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1680 › New-ReshelfProposedTrackSet

If Discogs tracks are available and `DiscogsIndices` is empty, it defaults to `1..Tracks.Count` — i.e. source track order is assumed to already line up one-to-one with the (possibly pre-aligned) Discogs tracklist.

### AS-CODE-PRP-035 — Track number and file number are two distinct, independently-tracked numbers
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1680 › New-ReshelfProposedTrackSet

`trackNumbers` (used for the Track tag) restart at 1 on every disc; `fileNumbers` (used in the proposed file name) keep counting continuously across all discs of the release. Both follow the release's real track position, so a track missing from the source leaves a gap in both rather than shifting later tracks down.

### AS-CODE-PRP-036 — Single-disc Discogs numbering uses the Discogs index directly for both numbers
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1680 › New-ReshelfProposedTrackSet

When Discogs tracks are used and there is only one disc group, both `trackNumbers[i]` and `fileNumbers[i]` are simply `DiscogsIndices[i]` — the Discogs track order directly defines the proposed numbering.

### AS-CODE-PRP-037 — Multi-disc Discogs numbering is only trusted when every involved position parses cleanly
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1680 › New-ReshelfProposedTrackSet

For a multi-disc release, Discogs-derived numbering is used only if `Get-ReshelfDiscogsPositionParts` successfully parses a Disc **and** Track number for every one of the release's Discogs-aligned tracks. If even one position fails to parse (e.g. a vinyl side label), the whole release falls back to the file-name-based numbering heuristic below — not just the one unparseable track.

### AS-CODE-PRP-038 — Fallback numbering uses file-name-detected numbers only when they look trustworthy
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1680 › New-ReshelfProposedTrackSet

When Discogs numbering isn't used (or couldn't be trusted), each disc's tracks are numbered from their own `detectedTrackNumberInDisc` only if none of that disc's tracks have `inferredTrackOrder` set and every detected number is `>= 1`; otherwise the disc's tracks are numbered sequentially (1, 2, 3, ...) in their current order.

### AS-CODE-PRP-039 — Non-unique detected numbers within a disc force sequential renumbering, with a note
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1680 › New-ReshelfProposedTrackSet

Even when detected numbers otherwise look usable, if they aren't unique within one disc the code falls back to sequential numbering for that disc and adds the note `"track numbers from source file names are not unique on disc <N>; renumbered sequentially"`.

### AS-CODE-PRP-040 — A later disc numbered continuously from the previous disc has its numbering offset removed
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1680 › New-ReshelfProposedTrackSet

If a disc's file names already number continuously from the prior disc (e.g. "CD2\11 - ..." instead of starting at 1) — detected when every number on that disc exceeds the running offset from earlier discs — that running offset is subtracted back out so the Track tag still restarts at 1 per disc, while `fileNumbers` stay continuous across the whole release regardless.

### AS-CODE-PRP-041 — File-number pad width is derived from the release's highest file number
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1680 › New-ReshelfProposedTrackSet

The pad width passed to file names is `Get-ReshelfProposalPadWidth` with `TotalTrackCount` = the highest resolved `fileNumbers` value and `MinWidth` = the caller's `TrackNumberPadWidth` (default 2).

### AS-CODE-PRP-042 — Proposed file name combines the zero-padded file number, the sanitized title, and the track's own format extension
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1680 › New-ReshelfProposedTrackSet

Each file name is `Expand-ReshelfNamingTemplate` applied to `TrackFileTemplate` with `{trackNumber}` = the zero-padded file number and `{title}` = the sanitized track title, with `.<format>` appended (the track's own detected format, as stored on the track object).

Example: `TrackFileTemplate = "{trackNumber} {title}"`, file number `7` padded to width 2, title `"Asozan"`, format `mp3` → `"07 Asozan.mp3"`.

### AS-CODE-PRP-043 — Track title (Discogs case) follows the same bilingual pairing rule as the album title
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1680 › New-ReshelfProposedTrackSet

When Discogs tracks are used, the romanized half is the existing tag title if it is romanized text, else the file-name-derived title if that is romanized text, else `$null`; this is joined bilingually with the Discogs track's own title (invisible characters stripped), using the same `"X = Y"` convention as the release/album title.

### AS-CODE-PRP-044 — Track title (no Discogs) prefers the existing tag title
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1680 › New-ReshelfProposedTrackSet

Without Discogs tracks, if the track already has an existing `Title` tag, that is used (Title Cased) as the proposed title.

### AS-CODE-PRP-045 — A compilation track numbered "NN Artist - Title" with no tags uses the filename's title half
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1680 › New-ReshelfProposedTrackSet

Without Discogs tracks and without an existing tag title, if the release `IsCompilation`, the track has no existing `Artist` tag, a file-name-derived artist exists for it, and the file name parsed a distinct title part, the proposed title is that parsed `TitlePart` — avoiding the title tag ending up as the whole "Artist - Title" string once the artist half is used separately for the Artist tag.

### AS-CODE-PRP-046 — Otherwise the track title falls back to the plain filename-derived title
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1680 › New-ReshelfProposedTrackSet

If none of the above apply, the proposed title is simply the title part `ConvertFrom-ReshelfTrackFileName` parsed out of the original file name, Title Cased.

### AS-CODE-PRP-047 — Discogs' own per-track artist credit always wins when present, on any release type
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1680 › New-ReshelfProposedTrackSet

If Discogs provides a per-track artist credit (`Get-ReshelfDiscogsArtistCredit`), it takes priority over every other source for the track's Artist tag — this applies to any release with per-track credits, not only compilations, so a split release also keeps each track's real artist.

### AS-CODE-PRP-048 — A Discogs per-track credit matching the release artist reuses the release's own (possibly bilingual) artist text
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1680 › New-ReshelfProposedTrackSet

The release's `Names.Artist` may be a bilingual `"Romanized = Original"` string built from Discogs' raw (un-joined) artist name. If the per-track Discogs credit normalizes equal to either half of that string (split on `" = "`), the full bilingual `Names.Artist` is used for the track instead of the raw Discogs credit text — so an ordinary non-compilation release reads bilingually on every track, not just the release-level tag.

### AS-CODE-PRP-049 — Compilation fallback chain without a Discogs credit: tag artist, then filename artist, then release artist plus a review note
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1680 › New-ReshelfProposedTrackSet

For a compilation (`Names.IsCompilation`) track with no Discogs per-track credit, the Artist tag is: the track's existing `Artist` tag (Title Cased) if present; else the file-name-parsed artist (Title Cased) if present; else the release's own `Names.Artist` (e.g. `"Various"`), with a note added: `"Track <N>: no track artist from Discogs or file tags; Artist set to '<Names.Artist>'."` — forcing human review rather than silently mislabeling a compilation track.

### AS-CODE-PRP-050 — A non-compilation track without a Discogs credit always gets the release (Album) artist
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1680 › New-ReshelfProposedTrackSet

For a non-compilation release with no Discogs per-track credit, the track Artist tag is always `Names.Artist` (same as Album Artist) — no filename or tag-based per-track artist is ever considered.

### AS-CODE-PRP-051 — Disc number tag is the disc's sequential position in first-seen order, not a parsed folder number
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1680 › New-ReshelfProposedTrackSet

The `discNumber` tag written for every track is the 1-based position of its `discFolder` group in the order those groups were first encountered while scanning tracks — it is not parsed out of the `discFolder` name itself.

### AS-CODE-PRP-052 — Image dimensions are read via System.Drawing on a long-path-safe path
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1901 › Get-ReshelfImageDimensions

Dimensions are obtained by loading the file with `[System.Drawing.Image]::FromFile()` against a long-path-converted path (`ConvertTo-ReshelfLongPath`), reading `Width`/`Height`, then disposing the image.

### AS-CODE-PRP-053 — An undecodable image silently reports 1x1 instead of throwing
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1901 › Get-ReshelfImageDimensions

Any exception while loading or reading the image (missing file, corrupt data, unsupported format) is caught and the function returns the sentinel `{ Width = 1; Height = 1 }` rather than propagating the error.

### AS-CODE-PRP-054 — An embedded cover is always offered as a candidate, regardless of any Discogs match
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1926 › New-ReshelfCoverArtProposal

The first track carrying `existingCoverArtPath` contributes an `'existing (embedded)'` candidate, added before any Discogs-derived candidates and independent of whether the release matched on Discogs — so a track that already has a good embedded cover is never silently displaced from consideration by a Discogs image the user never asked to swap in.

### AS-CODE-PRP-055 — An embedded cover measuring exactly 1x1 is treated as corrupt and dropped
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1926 › New-ReshelfCoverArtProposal

If `Get-ReshelfImageDimensions` reports Width=1 and Height=1 for the embedded cover (its sentinel for "found a picture tag but couldn't decode it"), the embedded candidate is skipped entirely, as if no embedded cover existed — this prevents a garbage embedded picture from becoming the default choice and failing resize at apply time.

### AS-CODE-PRP-056 — Matched-release images are labeled "<country> <format>", primary vs. alternate
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1926 › New-ReshelfCoverArtProposal

When the matched pressing's own `Detail.images` is non-empty, each becomes a candidate labeled `"<country> <format name>"` (trimmed), or the literal fallback string `'unknown edition'` if that combination is blank. Discogs images of type `'primary'` use the label as-is; any other type gets `" (alternate)"` appended.

### AS-CODE-PRP-057 — When the picked pressing has no images, the master's images are used instead
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1926 › New-ReshelfCoverArtProposal

If the match is `'matched'` but `Detail.images` is empty and the match has a master with its own `images`, those are used, labeled `'master (main release)'` (primary) or `'master (main release) (alternate)'` — a known pressing with no photos (e.g. a "NO NUMBER" edition) still gets its master's cover as a better-than-nothing default.

### AS-CODE-PRP-058 — With no usable Discogs images at all, local companion cover files are the only source
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1926 › New-ReshelfCoverArtProposal

If there is no match, or the match has neither pressing images nor master images, every local companion file of `kind = 'cover'` becomes a candidate labeled `'existing (local)'`, with dimensions read via `Get-ReshelfImageDimensions`.

### AS-CODE-PRP-059 — Default cover choice: embedded first, then the first non-alternate candidate, then anything
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:1926 › New-ReshelfCoverArtProposal

The pre-selected `chosenCandidateUrl` is the embedded candidate if present; otherwise the first candidate whose `sourceEdition` does **not** end in `" (alternate)"`; otherwise simply the first candidate in the list. All discovered candidates remain listed regardless — only the default selection follows this priority.

### AS-CODE-PRP-060 — Lossy-release "sameness" is decided by overlapping search-title variants, not exact text match
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2029 › Test-ReshelfSameLossyRelease

Two album names are considered the same release if any normalized Discogs search-title variant (`Get-ReshelfDiscogsSearchTitleVariants` — the same noise-tolerant variant generator used for Discogs search queries) of one name equals any normalized variant of the other. An exact string match is deliberately not required, to bridge cases like an old lossy import's messy folder-derived name versus a later lossless import's Discogs-matched name.

Example (illustration): old album name `"Forwards Special Edition"` vs. new album name `"Forwards"` → considered the same release once their respective search-title variant sets are generated and normalized, because they intersect.

### AS-CODE-PRP-061 — Previous-lossy lookup trusts the ledger entry for this exact stableKey only if it's still pending
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2054 › Find-ReshelfPreviousLossyEntry

The function first looks up the lossy-tracking ledger entry for the given `StableKey`; it is only used if `entry.status -eq 'pending-upgrade'`.

### AS-CODE-PRP-062 — Fallback ledger scan matches by exact year, normalized artist, and fuzzy album name
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2054 › Find-ReshelfPreviousLossyEntry

If no direct stableKey match is found (or it isn't pending), every `pending-upgrade` ledger entry is scanned for one whose `year` matches exactly, whose normalized artist equals the normalized input artist, and whose album is the "same lossy release" per AS-CODE-PRP-060 — handling a source folder renamed between the lossy and lossless import, which changes its computed stableKey.

### AS-CODE-PRP-063 — Whether the previous lossy target still exists is always re-checked live, never trusted from the ledger
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2054 › Find-ReshelfPreviousLossyEntry

`TargetExists` is computed fresh on every call (folder exists **and** contains at least one audio file), since the ledger record itself doesn't track whether that folder was later deleted or moved.

### AS-CODE-PRP-064 — A missing target root returns an empty index, not an error
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2103 › Build-ReshelfTargetIndex

If `TargetRoot` doesn't exist as a directory, `Build-ReshelfTargetIndex` returns an empty dictionary rather than throwing.

### AS-CODE-PRP-065 — Only exactly "Artist\YYYY Album" folders are indexed; anything else is invisible
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2103 › Build-ReshelfTargetIndex

The index scans exactly two directory levels (artist folders, then release folders inside each). A release folder name must match `^(\d{4})\s+(.+)$` (a 4-digit year, a space, then the album text) or it is skipped entirely — any target folder not in that exact "YYYY Album" shape is never indexed and so is invisible to target-exists/comparison logic.

### AS-CODE-PRP-066 — StableKey collisions in the target index keep the first folder found; later duplicates are silently dropped
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2103 › Build-ReshelfTargetIndex

The stableKey for each candidate release folder is computed from (artist folder name, parsed album, parsed year) via `Get-ReshelfStableKey`. If two folders compute the same stableKey, only the first one encountered is kept in the index — treated as a pre-existing target-side data inconsistency this index does not try to fix.

### AS-CODE-PRP-067 — Target-release-exists is a direct dictionary lookup by stableKey
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2141 › Test-ReshelfTargetReleaseExists

`Test-ReshelfTargetReleaseExists` does nothing beyond a dictionary lookup of `StableKey` in the given `TargetIndex`, returning `$null` when absent.

### AS-CODE-PRP-068 — Target comparison identity is a content hash of the release's own source files
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2158 › Resolve-ReshelfTargetComparison

The release's identity for "is this already applied / already the same" purposes is `Get-ReshelfFileSetHash` computed over the unique set of `sourceFilePath` values across all of its tracks.

### AS-CODE-PRP-069 — A source release with mixed lossless/lossy tracks is conservatively treated as lossy, with a forced review note
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2158 › Resolve-ReshelfTargetComparison

The source is only considered lossless if **every** track is lossless. If some but not all tracks are lossless, the release is treated as lossy for the target-action decision, and a forced review note is always added: `"release has mixed lossless/lossy source tracks; treated as lossy for target comparison"`.

### AS-CODE-PRP-070 — Existing-target baseline is resolved through a fixed priority chain, cheapest/most-reliable first
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2158 › Resolve-ReshelfTargetComparison

The comparison baseline is found in this order, stopping at the first hit: (a) a same-session duplicate already seen this run under the same stableKey; (b) a different stableKey that already claimed this exact proposed target path earlier in the same run (a cross-stableKey path collision); (c) a valid apply-log entry for this stableKey whose recorded source-file-set hash equals the current source hash (`appliedEntryMatchesSource`); (d) an existing on-disk folder found via, in order: the apply-log entry's own recorded target path (if still valid), else the literal proposed target path itself (if it already has audio files), else a lookup in `TargetIndex` by stableKey.

### AS-CODE-PRP-071 — Existing on-disk baseline is lossless only if every file in it has a lossless extension, and zero files never counts as lossless
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2158 › Resolve-ReshelfTargetComparison

For a baseline found as an existing folder, `IsLossless` starts `true` only when at least one audio file was found there (`targetFiles.Count -gt 0`), and is flipped to `false` the moment any file's extension fails `Test-ReshelfIsLosslessFormat`.

### AS-CODE-PRP-072 — The previous-lossy ledger cross-check only runs when this looks like a brand-new lossless import
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2158 › Resolve-ReshelfTargetComparison

`Find-ReshelfPreviousLossyEntry` is only invoked when the source is fully lossless, no baseline was found at all through the chain above, and the apply-log didn't already mark this exact source as applied (`-not $appliedEntryMatchesSource`) — i.e. only for a target slot with nothing in it yet.

### AS-CODE-PRP-073 — Target action decision order: skip-identical, create-new, skip-identical-by-hash, create-new-for-renamed-lossy, update-existing, or conflict
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2158 › Resolve-ReshelfTargetComparison

`TargetAction` is decided in this exact order: (1) `appliedEntryMatchesSource` → `'skip-existing-identical'`; (2) no baseline found → `'create-new'`; (3) baseline hash equals source hash → `'skip-existing-identical'`; (4) source is lossless, baseline is not lossless, baseline has a real path, and that path differs from the proposed target path → `'create-new'` (the old lossy copy lives under a different/older name and is left alone, not overwritten); (5) source is lossless and baseline is not lossless (same path) → `'update-existing'`; (6) anything else → `'conflict'`.

### AS-CODE-PRP-074 — Conflict notes distinguish a same-session path collision from a genuine on-disk mismatch
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2158 › Resolve-ReshelfTargetComparison

When `targetAction` is `'conflict'` because of a same-session path collision, the note names the colliding source folder path and its stableKey explicitly. Otherwise the generic note is the literal string `'target conflict: existing target differs from source and is not a lossy-to-lossless upgrade'`.

### AS-CODE-PRP-075 — Lossy/lossless summary action has its own priority: replace-existing, log-for-upgrade, previously-lossy-*, or none
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2158 › Resolve-ReshelfTargetComparison

`LossyLossless.action` is decided independently of (but informed by) `TargetAction`: `'update-existing'` forces `action = 'replace-existing'`, `isLossy = $false`; else a lossy source gives `isLossy = $true`, `action = 'log-for-upgrade'`; else, if a previous-lossy ledger match was found, `isLossy = $false` and `action` is `'previously-lossy-different-location'` (old folder still exists) or `'previously-lossy-target-missing'` (it doesn't); else `isLossy = $false`, `action = 'none'`.

### AS-CODE-PRP-076 — Previous-lossy note wording differs depending on whether the old folder still exists
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2158 › Resolve-ReshelfTargetComparison

When the previously-tracked lossy folder still exists, the note reads: `"Previously imported as <format> at '<path>' (first seen <date>) - that folder still exists and will be kept as-is; remove it yourself if you don't want both."` When it no longer exists, the wording changes to a warning that the folder "is not in the target now, so keep this in mind when managing your real collection." Apply never automatically deletes or touches the old folder either way — the message is advisory only.

### AS-CODE-PRP-077 — Every lossy-sourced release re-upserts its ledger entry on every run, not only on first detection
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2158 › Resolve-ReshelfTargetComparison

Whenever the source is lossy, `Add-ReshelfLossyTrackingEntry` is called unconditionally (regardless of `TargetAction`), so a release pending upgrade keeps its `lastCheckedUtc` advancing across repeated proposal runs rather than being written only once.

### AS-CODE-PRP-078 — Session-seen state (by stableKey and by path) is updated for every release, and the first claimant of a path always wins
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2158 › Resolve-ReshelfTargetComparison

`SessionSeen[StableKey]` is always set to this release's hash/losslessness at the end of the function. `SessionSeenByPath` is only set if that normalized path isn't already claimed — so later releases proposing the same target path always compare against whichever release claimed it first in the run, not the most recently processed one.

### AS-CODE-PRP-079 — Only "loose" companion files get a proposed rename; other placements are left as-is
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2393 › New-ReshelfCompanionProposal

A companion file's `proposedFileName` is only computed (via `Get-ReshelfLooseCompanionFileName`) when its `placement` is `'loose'`. Any other placement value leaves `proposedFileName = $null`.

### AS-CODE-PRP-080 — Every companion file defaults to being included
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2393 › New-ReshelfCompanionProposal

Each companion's proposal entry sets `include = $true` unconditionally — nothing is excluded by default; exclusion must be a later, separate user action.

### AS-CODE-PRP-081 — A forced rename prefix (non-letter-starting file name) always forces human review
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2393 › New-ReshelfCompanionProposal

If `Get-ReshelfLooseCompanionFileName` reports `WasPrefixed` (a prefix letter had to be added because the original name didn't start with a letter), `RequiresReview` is set `true` for the whole companion set and a note is added: `"Companion '<original>' renamed to '<new>' (must start with a letter)."`

### AS-CODE-PRP-082 — Recognition-time review flags are always carried through to the final proposal
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2434 › New-ReshelfProposedRelease

If `Release.needsReview` is set (from recognition-stage ambiguity flags such as grouping-folder cases, band-member-as-artist cases, or artist-name-split-from-folder-name), it unconditionally sets `requiresReview = $true` on the proposed release and appends every one of `Release.reviewReasons` to the notes — ensuring these are never dropped just because none of this function's own checks happen to also trigger review.

### AS-CODE-PRP-083 — The Various-Artists fallback search only triggers when the direct match failed and the tracks look like a compilation
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2434 › New-ReshelfProposedRelease

When `match.Status -ne 'matched'` and `Get-ReshelfVariousArtistsEvidence` judges the tracks `LooksLikeVarious`, a brand-new Discogs search is performed with artist name literally `'Various'` (not a retry of the original search). This always forces `requiresReview = $true` and adds a note naming the distinct-artist count found among the tracks.

Example (illustration): a release filed under a shared track folder name that never matches on Discogs, where most tracks clearly have different artists each — the folder's own artist search fails, but a `'Various'` search for the same title/year succeeds, and the release is re-proposed as a Various Artists compilation.

### AS-CODE-PRP-084 — A Various-Artists fallback release never inherits the original artist's bilingual display name
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2434 › New-ReshelfProposedRelease

When the Various-Artists fallback is used, the precomputed `ArtistDisplayName` (built for the original artist's own releases) is discarded (`$null`) before building names — a 'Various' compilation never gets another artist's shared bilingual folder/tag text.

### AS-CODE-PRP-085 — A match error note or any non-'matched' status both force review, each with its own note
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2434 › New-ReshelfProposedRelease

If `match.ErrorNote` is set, it is added to notes and forces review. Independently, if the final `match.Status` isn't `'matched'`, review is forced again with the note `"Discogs match status: <status>"` — both conditions can fire together.

### AS-CODE-PRP-086 — A Discogs tracklist count mismatch always forces review, even when alignment later succeeds
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2434 › New-ReshelfProposedRelease

Discogs tracks are used as-is only when their count exactly equals the source track count. Any mismatch forces `requiresReview = $true` unconditionally and attempts `Resolve-ReshelfDiscogsTrackAlignment`: on success, a note states the alignment method plus any missing-tracks detail; on failure, the note states the fallback to source titles and `discogsTracks` is cleared to empty, meaning no Discogs-derived numbering/titles/credits are used for this release's tracks at all.

### AS-CODE-PRP-087 — No cover art candidates at all forces review with a dedicated note
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2434 › New-ReshelfProposedRelease

If `New-ReshelfCoverArtProposal` returns zero candidates, `requiresReview = $true` and the note `'No cover art candidates found from Discogs or local companion files.'` is added.

### AS-CODE-PRP-088 — Proposed target path is always a fixed two-level "TargetRoot\Artist\Release" layout
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2434 › New-ReshelfProposedRelease

`proposedTargetPath` is always `Join-Path TargetRoot ArtistFolderName ReleaseFolderName` — the target layout has no deeper or shallower structure anywhere in this function.

### AS-CODE-PRP-089 — Human-review notes are flattened into one semicolon-joined string, and "rejected" always starts false
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2434 › New-ReshelfProposedRelease

The final `humanReview` object joins every collected note with `'; '` into a single string, sets `resolved = -not requiresReview`, and always sets `rejected = $false` — rejection is never decided at proposal time; it must be set by a later, separate user action elsewhere in the app.

### AS-CODE-PRP-090 — A manual Discogs re-pick fetches the release (and its master, if any) live, bypassing the cached search/match pipeline
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2647 › Update-ReshelfReleaseForDiscogsSelection

The picked release's full detail is fetched directly via `Invoke-DiscogsRequest -Path "/releases/<id>"`; if it has a `master_id`, the master is also fetched via `/masters/<id>` so the manual pick still benefits from the same master-year and master-cover-fallback priority as an automatic match (AS-CODE-PRP-013, AS-CODE-PRP-057).

### AS-CODE-PRP-091 — The romanized half is stripped back out of a possibly-already-bilingual artist name before resolving bilingual evidence
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2647 › Update-ReshelfReleaseForDiscogsSelection

Because the `ArtistName` parameter here comes from the release's current Album Artist tag — which may already be a bilingual `"Romanized = Original"` value from an earlier run — the code splits on `' = '` and keeps only the first (romanized) half before passing it into `Get-ReshelfBilingualArtistName` and `New-ReshelfProposedReleaseNames`.

### AS-CODE-PRP-092 — If the single re-picked release has no bilingual evidence of its own, a sibling's already-proposed bilingual name is reused
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2647 › Update-ReshelfReleaseForDiscogsSelection

When this one pick alone doesn't yield Japanese-script evidence, `SiblingReleases` is scanned for one whose already-proposed `artistFolderName` is bilingual (contains `' = '`) with a romanized half matching (after normalization) this artist — reusing an artist-level decision so a single manual re-pick doesn't regress the whole artist back to a romanized-only name.

### AS-CODE-PRP-093 — Cross-release collision/upgrade state is rebuilt from scratch from the sibling releases, not accumulated incrementally
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2647 › Update-ReshelfReleaseForDiscogsSelection

Since only one release is being recomputed here, a `SessionSeen`/`SessionSeenByPath` pair equivalent to what a full batch run builds incrementally is instead constructed up front from every `SiblingReleases` entry's own stored tracks and already-proposed target path — so the single re-pick still participates correctly in the same cross-release target-collision and lossy-upgrade detection as a full batch run would.

### AS-CODE-PRP-094 — There is no Various-Artists fallback at all on the manual re-pick path
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2647 › Update-ReshelfReleaseForDiscogsSelection

Unlike `New-ReshelfProposedRelease` (AS-CODE-PRP-083), this function never calls `Get-ReshelfVariousArtistsEvidence` or re-searches as `'Various'` — a manually picked Discogs release is always treated as a direct, final `'matched'` result.

### AS-CODE-PRP-095 — Defaults for pad width, cache TTL, and rate limit are independently hardcoded here, not required from the caller
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2647 › Update-ReshelfReleaseForDiscogsSelection

`TrackNumberPadWidth` defaults to 2, `CacheTtlDays` defaults to 30, `RateLimitPerMinute` defaults to 55 — all optional here, whereas `New-ReshelfProposedRelease` requires `CacheTtlDays`/`RateLimitPerMinute` to be supplied by its own caller (only `TrackNumberPadWidth` is optional there too).

### AS-CODE-PRP-096 — The manual re-pick's return shape is flatter than the full proposed-release document
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2647 › Update-ReshelfReleaseForDiscogsSelection

The result omits fields the full `New-ReshelfProposedRelease` document carries (e.g. `stableKey`, `recognizedTitle`, `sourceFolderPath`, `cueSheets`, `recognitionConfidence`) and does not nest review state under a `humanReview` object — `requiresReview` and `notes` are returned as plain top-level fields instead.

### AS-CODE-PRP-097 — The whole run refuses to start unless the recognition input validates against its schema
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2844 › Invoke-ReshelfEditProposal

`Invoke-ReshelfEditProposal` validates `RecognitionPath` with `Test-ReshelfJson -SchemaName recognition` before reading anything else, and throws `"Recognition document at '<path>' does not match the recognition schema."` if it fails.

### AS-CODE-PRP-098 — DataHome and ProposalPath both have computed defaults when not supplied
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2844 › Invoke-ReshelfEditProposal

If `DataHome` isn't supplied, it is resolved via `Resolve-ReshelfDataHome`. If `ProposalPath` isn't supplied, it defaults to `<DataHome>/sessions/<SessionId>/proposal.json`.

### AS-CODE-PRP-099 — Naming/cover/rate-limit defaults for a whole proposal run are hardcoded parameter defaults
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2844 › Invoke-ReshelfEditProposal

Unless the caller overrides them, this is the full default set for a proposal run: `ReleaseFolderTemplate = '{year} {album}'`, `TrackFileTemplate = '{trackNumber} {title}'`, `TrackNumberPadWidth = 2`, `CoverMaxDimension = 600`, `CacheTtlDays = 30`, `RateLimitPerMinute = 55`.

### AS-CODE-PRP-100 — The target index and session-collision state are built exactly once per run and shared across every artist and release
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2844 › Invoke-ReshelfEditProposal

`Build-ReshelfTargetIndex` and the `SessionSeen`/`SessionSeenByPath` dictionaries are each created once at the top of the function, before iterating artists, and passed down unchanged to every `New-ReshelfProposedRelease` call — this is how cross-artist and cross-release target-path collisions are detected within a single run.

### AS-CODE-PRP-101 — Every release of an artist has its Discogs match resolved in a full pass before any of that artist's names are finalized
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2844 › Invoke-ReshelfEditProposal

For each artist, `Resolve-ReshelfDiscogsMatchForRelease` is called for every one of that artist's releases first, collecting all results into `$matches`, before `Get-ReshelfBilingualArtistName` is computed and before any release's `New-ReshelfProposedRelease` runs — so bilingual-name evidence from any sibling release is available before any one release's folder/tag name is decided.

### AS-CODE-PRP-102 — The returned proposal document is re-read from disk after being written, not returned from memory
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2844 › Invoke-ReshelfEditProposal

The assembled document is written via `Set-ReshelfJsonFile` (schema `proposal`, `Depth 20`), then the function returns `Get-Content -Raw | ConvertFrom-Json` read back from `ProposalPath` — the caller always receives whatever actually round-tripped through JSON, not the original in-memory PowerShell object.

### AS-CODE-PRP-103 — schemaVersion is a hardcoded literal 1, and generatedAtUtc uses a fixed UTC format
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2844 › Invoke-ReshelfEditProposal

The output document always sets `schemaVersion = 1` (a literal, not derived from anything) and `generatedAtUtc` to the current UTC time formatted as `'yyyy-MM-ddTHH:mm:ss.fffZ'`.

### AS-CODE-PRP-104 — Unrecognized source entries pass through to the proposal document unchanged
Status: Draft | Source: legacy/scripts/common/Reshelf.EditProposal.psm1:2844 › Invoke-ReshelfEditProposal

`recognition.unrecognized` is copied directly into the output document's `unrecognized` field with no transformation.

## Suspected defects

- AS-CODE-DEF-PRP-001 — legacy/scripts/common/Reshelf.EditProposal.psm1:2083-2087 (Find-ReshelfPreviousLossyEntry): the fallback fuzzy ledger scan picks the first `pending-upgrade` entry matching artist+year+fuzzy-album-variant overlap (`Select-Object -First 1`) with no further disambiguation. Two different pending-upgrade albums by the same artist in the same year, whose Discogs search-title variants happen to overlap, could cause the wrong previous-lossy folder to be reported.
- AS-CODE-DEF-PRP-002 — legacy/scripts/common/Reshelf.EditProposal.psm1:2764 (Update-ReshelfReleaseForDiscogsSelection): calls `New-ReshelfProposedTrackSet` without `-FileNameArtists`, and this function never computes `Get-ReshelfVariousArtistsEvidence` at all (contrast line 2576 in New-ReshelfProposedRelease, which passes `-FileNameArtists $vaEvidence.FileNameArtists`). A compilation release that gets its Discogs match manually re-picked loses the filename-parsed-artist fallback tier (AS-CODE-PRP-049) for tracks with no existing Artist tag and no Discogs per-track credit, unlike the same release processed through the normal batch-propose path.
- AS-CODE-DEF-PRP-003 — legacy/scripts/common/Reshelf.EditProposal.psm1:2647-2842 (Update-ReshelfReleaseForDiscogsSelection): never reads or forwards `$Release.needsReview` / `$Release.reviewReasons` into its own `requiresReview`/`notes` output, unlike `New-ReshelfProposedRelease` (lines 2496-2499), whose own comment explicitly calls out fixing exactly this "previously silently dropped" gap for the batch path. A release flagged for review at recognition time can have that flag effectively disappear once the user manually re-picks its Discogs match.
- AS-CODE-DEF-PRP-004 — legacy/scripts/common/Reshelf.EditProposal.psm1:1915-1922 and 1955-1962 (Get-ReshelfImageDimensions / New-ReshelfCoverArtProposal): the 1x1 sentinel used to mean "couldn't decode this image" is indistinguishable from a real 1x1-pixel source image. Any embedded cover that is genuinely exactly 1x1 would be silently dropped as if it were corrupt.

## Changelog

| Version | Date | Changes |
|---|---|---|
| 0.1 | 2026-10-10 | Phase 2 draft from code. |
