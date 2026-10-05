# 91 — Coverage (as-is, from docs and tests)

Status: Draft | Version: 0.1 | Last updated: 2026-10-05

## How to read this file

The brief's done criterion: every test file (Describe block) and every README section maps to at least one requirement or one suspected defect. This file shows that mapping for all Phase 1 inputs: tests, `legacy/README.md`, `legacy/plan/`, `legacy/schemas/` and `MANIFESTO.md`.

- Requirement IDs (`AS-DOC-<AREA>-NNN`) are in the area files `00`–`13`.
- Defect IDs (`AS-DOC-DEF-NNN`) are in [90-suspected-defects.md](90-suspected-defects.md).
- "A to B" means every ID from A to B.
- The order of the test tables and README rows follows the block list that the lead session built from the sources (every Describe / Context, every `test.describe`, every README heading, every plan and schema file).
- [Gaps](#gaps) lists every block that the six area drafts did not map, and what was done with it.

## Tests

### legacy/tests/Reshelf.Common.Tests.ps1

| Describe / Context | IDs |
|---|---|
| Resolve-ReshelfDataHome | AS-DOC-DAT-003 to AS-DOC-DAT-006; AS-DOC-DEF-111 |
| ConvertTo-ReshelfNormalizedText (private) | AS-DOC-TXT-001 to AS-DOC-TXT-003 |
| ConvertTo-ReshelfHomoglyphNormalizedText | AS-DOC-TXT-004 to AS-DOC-TXT-007 |
| Test-ReshelfHasJapaneseScript | AS-DOC-TXT-008, AS-DOC-TXT-009 |
| Test-ReshelfIsRomanizedText | AS-DOC-TXT-010, AS-DOC-TXT-011 |
| Join-ReshelfBilingualName | AS-DOC-TXT-012 to AS-DOC-TXT-016 |
| Get-ReshelfSha256Hex | AS-DOC-DAT-063 |
| Get-ReshelfStableKey | AS-DOC-DAT-064 to AS-DOC-DAT-066; AS-DOC-DEF-006 |
| ConvertTo-ReshelfLongPath | AS-DOC-DAT-072 to AS-DOC-DAT-075 |
| ConvertTo-ReshelfCueTimestampSeconds | AS-DOC-TXT-040, AS-DOC-TXT-041 |
| ConvertTo-SafeFileName | AS-DOC-TXT-020 to AS-DOC-TXT-029 |
| Test-ReshelfLooseCompanionFileName | AS-DOC-TXT-030, AS-DOC-TXT-031 |
| Get-ReshelfLooseCompanionFileName | AS-DOC-TXT-032 to AS-DOC-TXT-035 |
| ConvertTo-ReshelfTruncatedSegment | AS-DOC-TXT-036 to AS-DOC-TXT-039; AS-DOC-DEF-010, AS-DOC-DEF-012 |
| Get-ReshelfFileSetHash | AS-DOC-DAT-068 to AS-DOC-DAT-071 |
| Protect-ReshelfSecret / Unprotect-ReshelfSecret | AS-DOC-SET-001, AS-DOC-SET-045 to AS-DOC-SET-047 |
| Import-ReshelfTagLibSharp | AS-DOC-DAT-086, AS-DOC-DAT-087 |
| Test-ReshelfIsAudioExtension | AS-DOC-DAT-076, AS-DOC-DAT-077 |
| Test-ReshelfIsLosslessFormat | AS-DOC-DAT-077, AS-DOC-DAT-078 |
| Get-ReshelfAudioFilesInFolder | AS-DOC-DAT-079 to AS-DOC-DAT-081 |
| Get-ReshelfRelativePath | AS-DOC-DAT-082 to AS-DOC-DAT-085 |
| ConvertTo-ReshelfTitleCase | AS-DOC-TXT-018, AS-DOC-TXT-019 |
| Remove-ReshelfInvisibleCharacters | AS-DOC-TXT-017 |
| (file header `#Requires -Version 7.4`) | AS-DOC-DAT-001 |

### legacy/tests/Reshelf.Discogs.Tests.ps1

| Describe / Context | IDs |
|---|---|
| (shared BeforeAll: fixtures, 401/429 exception helpers) | context only; used in AS-DOC-DSC-011 to AS-DOC-DSC-015 |
| Get-DiscogsToken | AS-DOC-DSC-002 to AS-DOC-DSC-006; AS-DOC-DEF-039, AS-DOC-DEF-040, AS-DOC-DEF-111 |
| Get-DiscogsQueryPair | AS-DOC-DSC-009, AS-DOC-DSC-010 |
| Remove-DiscogsExpiredCache | AS-DOC-DSC-023 to AS-DOC-DSC-026 |
| Invoke-DiscogsRequest | AS-DOC-DSC-007, AS-DOC-DSC-010 to AS-DOC-DSC-022; AS-DOC-DEF-042 |

### legacy/tests/Reshelf.EditProposal.Tests.ps1

| Describe / Context | IDs |
|---|---|
| (shared setup: module imports, fixtures, test helpers) | context only |
| Get-ReshelfProposalPadWidth (private) | AS-DOC-MAT-058, AS-DOC-MAT-059; AS-DOC-DEF-051 |
| Get-ReshelfStringSimilarity (private) | AS-DOC-MAT-001 |
| Get-ReshelfDiscogsCandidateScore (private) | AS-DOC-MAT-015, AS-DOC-MAT-017 to AS-DOC-MAT-022; AS-DOC-DEF-049 |
| Get-ReshelfDiscogsPlayableTracks (private) | AS-DOC-MAT-039 to AS-DOC-MAT-041 |
| Get-ReshelfDiscogsArtistCredit (private) | AS-DOC-MAT-049 to AS-DOC-MAT-052 |
| Test-ReshelfIsCompilationArtist (private) | AS-DOC-MAT-053 |
| Get-ReshelfVariousArtistsEvidence (private) | AS-DOC-MAT-054 to AS-DOC-MAT-057; AS-DOC-DEF-053 |
| Get-ReshelfDiscogsSearchTitleVariants (private) | AS-DOC-MAT-002 to AS-DOC-MAT-004 |
| Get-ReshelfDiscogsFormatPreferenceRank (private) | AS-DOC-MAT-029 |
| Resolve-ReshelfDiscogsTrackAlignment (private) | AS-DOC-MAT-044 to AS-DOC-MAT-048; AS-DOC-DEF-045 |
| Get-ReshelfDiscogsPositionParts (private) | AS-DOC-MAT-042, AS-DOC-MAT-043 |
| New-ReshelfProposedTrackSet (private) - real track positions | AS-DOC-PRP-021, AS-DOC-PRP-023 to AS-DOC-PRP-029, AS-DOC-PRP-033; AS-DOC-DEF-068 |
| › Context 'per-track Artist selection (compilations and split releases)' | AS-DOC-PRP-036 to AS-DOC-PRP-040; AS-DOC-DEF-060, AS-DOC-DEF-061, AS-DOC-DEF-067 |
| Test-ReshelfSameLossyRelease (private) | AS-DOC-LSY-029 |
| Resolve-ReshelfDiscogsMatch (private) | AS-DOC-MAT-005 to AS-DOC-MAT-014, AS-DOC-MAT-023 to AS-DOC-MAT-028, AS-DOC-MAT-030, AS-DOC-MAT-036, AS-DOC-DSC-007; AS-DOC-DEF-041, AS-DOC-DEF-043, AS-DOC-DEF-044, AS-DOC-DEF-048, AS-DOC-DEF-049, AS-DOC-DEF-050 |
| Sort-ReshelfDiscogsVersions / Get-ReshelfDiscogsVersionRank (private) | AS-DOC-MAT-031 to AS-DOC-MAT-035; AS-DOC-DEF-046, AS-DOC-DEF-047, AS-DOC-DEF-052 |
| Build-ReshelfTargetIndex and Test-ReshelfTargetReleaseExists | AS-DOC-PRP-061 to AS-DOC-PRP-065, AS-DOC-PRP-075; AS-DOC-DEF-063 |
| New-ReshelfCompanionProposal (private) | AS-DOC-PRP-057 to AS-DOC-PRP-060 |
| Invoke-ReshelfEditProposal (top-level tests: needsReview carry-over, schema-valid proposal.json) | AS-DOC-PRP-003, AS-DOC-PRP-004 |
| › Context 'naming and tagging' | AS-DOC-PRP-003, AS-DOC-PRP-005, AS-DOC-PRP-006, AS-DOC-PRP-008, AS-DOC-PRP-009, AS-DOC-PRP-015 to AS-DOC-PRP-018, AS-DOC-PRP-020 to AS-DOC-PRP-022, AS-DOC-PRP-032 to AS-DOC-PRP-035, AS-DOC-PRP-038, AS-DOC-PRP-041, AS-DOC-PRP-042; AS-DOC-DEF-013, AS-DOC-DEF-059, AS-DOC-DEF-064 |
| › Context 'bilingual (Japanese) release naming (session 2026-10-03-0010)' | AS-DOC-PRP-044 to AS-DOC-PRP-048; AS-DOC-DEF-066 |
| › Context 'cover art' | AS-DOC-PRP-050 to AS-DOC-PRP-053, AS-DOC-PRP-055, AS-DOC-PRP-058, AS-DOC-PRP-059; AS-DOC-DEF-054, AS-DOC-DEF-055 |
| › Context 'target comparison' | AS-DOC-PRP-066 to AS-DOC-PRP-073, AS-DOC-LSY-024, AS-DOC-LSY-025; AS-DOC-DEF-056, AS-DOC-DEF-097 |
| › Context 'lossy tracking' | AS-DOC-LSY-001, AS-DOC-LSY-020, AS-DOC-LSY-022, AS-DOC-LSY-023, AS-DOC-LSY-026 to AS-DOC-LSY-028; AS-DOC-DEF-057, AS-DOC-DEF-098 |
| Update-ReshelfReleaseForDiscogsSelection | AS-DOC-PRP-054, AS-DOC-PRP-076 to AS-DOC-PRP-078; AS-DOC-DEF-065, AS-DOC-DEF-069 |

### legacy/tests/Reshelf.Implementation.Tests.ps1

| Describe / Context | IDs |
|---|---|
| Invoke-ReshelfFfmpegSplit / Invoke-ReshelfFfmpegResize argument quoting | AS-DOC-APL-033 |
| Invoke-ReshelfFfmpegResize error handling | AS-DOC-APL-034 |
| Invoke-ReshelfFfmpegSplit codec selection | AS-DOC-APL-029; AS-DOC-DEF-083 |
| Invoke-ReshelfFfmpegSplit FLAC "invalid block size" retry | AS-DOC-APL-030, AS-DOC-APL-031; AS-DOC-DEF-094 |
| Resolve-ReshelfTruncatedReleaseNames | AS-DOC-APL-056 to AS-DOC-APL-059; AS-DOC-DEF-095 |
| Get-ReshelfApplyLogPath / Get-ReshelfApplyLog / Add-ReshelfApplyLogEntry | AS-DOC-APL-061, AS-DOC-APL-062; AS-DOC-DEF-092 |
| Test-ReshelfReleaseNeedsApply | AS-DOC-APL-009, AS-DOC-APL-011 to AS-DOC-APL-016; AS-DOC-DEF-086, AS-DOC-DEF-089, AS-DOC-DEF-090 |
| ConvertFrom-ReshelfCueTrackRanges | AS-DOC-APL-027, AS-DOC-APL-028 |
| ConvertTo-ReshelfFfmpegSeconds | AS-DOC-APL-026 |
| Resolve-ReshelfCompanionTargetPath | AS-DOC-APL-049 to AS-DOC-APL-051 |
| Invoke-ReshelfReleaseStaging | AS-DOC-APL-017, AS-DOC-APL-049, AS-DOC-APL-052 to AS-DOC-APL-056 |
| Invoke-ReshelfImplementation › -WhatIf; ffmpeg path fallback | AS-DOC-APL-001, AS-DOC-APL-006 |
| Invoke-ReshelfImplementation › final layout / tags / cleanup / log entry | AS-DOC-APL-017, AS-DOC-APL-035, AS-DOC-APL-036, AS-DOC-APL-038, AS-DOC-APL-039, AS-DOC-APL-063; AS-DOC-DEF-106 |
| Invoke-ReshelfImplementation › isCompilation; existing embedded cover; gap-fill; loose cover.jpg | AS-DOC-APL-036 to AS-DOC-APL-038, AS-DOC-APL-040 |
| Invoke-ReshelfImplementation › truncation recorded; truncated path logged on commit failure | AS-DOC-APL-060 |
| Invoke-ReshelfImplementation › .reshelf-staging removal (2 tests) | AS-DOC-APL-020; AS-DOC-DEF-091 |
| Invoke-ReshelfImplementation › second unchanged run skips | AS-DOC-APL-011 |
| Invoke-ReshelfImplementation › tag-write failure continues; missing source file | AS-DOC-APL-007, AS-DOC-APL-024, AS-DOC-APL-045 |
| Invoke-ReshelfImplementation › session stage applied / partially-applied | AS-DOC-APL-064 |
| Invoke-ReshelfImplementation › lossy upgraded; lossy targetPath correction | AS-DOC-APL-022, AS-DOC-APL-065, AS-DOC-APL-066 |
| Invoke-ReshelfImplementation › -IncludeUnresolved (ambiguous, conflict); create-new over an existing folder; rejected | AS-DOC-APL-003 to AS-DOC-APL-005, AS-DOC-APL-018, AS-DOC-APL-019; AS-DOC-DEF-084, AS-DOC-DEF-085 |
| Invoke-ReshelfImplementation › source never deleted | AS-DOC-APL-021 |
| Invoke-ReshelfImplementation › companions (kind-word fallback, proposedFileName, include = false, letter check, same path) | AS-DOC-APL-050 to AS-DOC-APL-055 |
| › Context 'cue-sheet release' | AS-DOC-APL-021, AS-DOC-APL-025, AS-DOC-APL-028; AS-DOC-DEF-087 |

### legacy/tests/Reshelf.Json.Tests.ps1

| Describe / Context | IDs |
|---|---|
| Test-ReshelfJson | AS-DOC-DAT-012 to AS-DOC-DAT-016 |
| Set-ReshelfJsonFile | AS-DOC-DAT-017 to AS-DOC-DAT-019 |

### legacy/tests/Reshelf.LossyTracking.Tests.ps1

| Describe / Context | IDs |
|---|---|
| Get-ReshelfLossyTrackingLedger | AS-DOC-LSY-002 to AS-DOC-LSY-004 |
| Get-ReshelfLossyTrackingEntry | AS-DOC-LSY-006 |
| Add-ReshelfLossyTrackingEntry | AS-DOC-LSY-005, AS-DOC-LSY-007 to AS-DOC-LSY-011 |
| Set-ReshelfLossyTrackingTargetPath | AS-DOC-LSY-005, AS-DOC-LSY-012, AS-DOC-LSY-017 |
| Set-ReshelfLossyTrackingStatus | AS-DOC-LSY-005, AS-DOC-LSY-013 to AS-DOC-LSY-017 |
| Remove-ReshelfLossyTrackingEntry | AS-DOC-LSY-005, AS-DOC-LSY-017, AS-DOC-LSY-018 |
| Set-ReshelfLossyTrackingIgnored | AS-DOC-LSY-005, AS-DOC-LSY-017, AS-DOC-LSY-019 |

### legacy/tests/Reshelf.Pipeline.Tests.ps1

| Describe / Context | IDs |
|---|---|
| Full pipeline: Recognition -> EditProposal -> Implementation (apply tests: skip-all, -WhatIf, real run + re-run, re-propose, target layout golden) | AS-DOC-APL-001, AS-DOC-APL-003, AS-DOC-APL-025, AS-DOC-APL-035, AS-DOC-APL-038, AS-DOC-APL-049, AS-DOC-APL-068, AS-DOC-APL-069, AS-DOC-BND-001; AS-DOC-DEF-085, AS-DOC-DEF-087 |
| Full pipeline: Recognition -> EditProposal -> Implementation (non-apply tests: schema-valid JSON, grouping folder, recognition and proposal golden files) | AS-DOC-REC-003, AS-DOC-REC-004, AS-DOC-REC-009, AS-DOC-REC-036, AS-DOC-PRP-003 (see [Gaps](#gaps), item 4) |
| Full pipeline: lossy release applied first, then its lossless upgrade | AS-DOC-APL-067 |

### legacy/tests/Reshelf.Recognition.Tests.ps1

| Describe / Context | IDs |
|---|---|
| Test-IsReleaseFolder (private) | AS-DOC-REC-011 to AS-DOC-REC-014; AS-DOC-DEF-018, AS-DOC-DEF-029 |
| Test-IsGroupingFolder (private) | AS-DOC-REC-028, AS-DOC-REC-032 to AS-DOC-REC-035 |
| Test-IsAlbumWrapperFolder (private) | AS-DOC-REC-037 to AS-DOC-REC-039 |
| Test-IsCategorySubfolder (private) | AS-DOC-REC-025; AS-DOC-DEF-020 |
| Test-IsBandMemberFolder (private) | AS-DOC-REC-028 to AS-DOC-REC-031; AS-DOC-DEF-027 |
| ConvertFrom-ReshelfTrackFileName (private) | AS-DOC-REC-055 to AS-DOC-REC-059; AS-DOC-DEF-022 |
| Remove-ReshelfArtistNamePrefixFromTitle (private) | AS-DOC-REC-052 to AS-DOC-REC-054 |
| Split-ReshelfReleaseTypeHint (private) | AS-DOC-REC-050, AS-DOC-REC-051 |
| Get-ReshelfTrackOrder (private) | AS-DOC-REC-060, AS-DOC-REC-061; AS-DOC-DEF-035 |
| Test-IsDiscFolder / Get-ReshelfDiscFolders (private) | AS-DOC-REC-062, AS-DOC-REC-063, AS-DOC-REC-065; AS-DOC-DEF-021, AS-DOC-DEF-028 |
| Get-ReshelfDiscNumber (private) | AS-DOC-REC-064; AS-DOC-DEF-021 |
| ConvertFrom-ReshelfCueSheet (private) | AS-DOC-REC-069 to AS-DOC-REC-071 |
| Get-ReshelfCueSheetHeader (private) | AS-DOC-REC-072 |
| Get-ReshelfFlatDiscCuePairs (private) | AS-DOC-REC-079 to AS-DOC-REC-082 |
| Get-ReshelfCompanionFiles (private) | AS-DOC-REC-083 to AS-DOC-REC-088; AS-DOC-DEF-024, AS-DOC-DEF-036 |
| Invoke-ReshelfRecognition › (Describe-level tag mock) | AS-DOC-REC-089 |
| Invoke-ReshelfRecognition › (all tests that check needsReview, reviewReasons or recognitionFlags) | AS-DOC-REC-091 |
| Invoke-ReshelfRecognition › produces a recognition.json that validates against the schema | AS-DOC-REC-002, AS-DOC-REC-003 |
| Invoke-ReshelfRecognition › recognizes a normal single-disc release with correct track order | AS-DOC-REC-016, AS-DOC-REC-060 |
| Invoke-ReshelfRecognition › recognizes a multi-disc release with correct disc folder names and combined track count | AS-DOC-REC-066, AS-DOC-REC-083 |
| Invoke-ReshelfRecognition › records a stray audio file sitting loose in a multi-disc release, flagged for review, instead of dropping it | AS-DOC-REC-067 |
| Invoke-ReshelfRecognition › flags a release for review when a track's audio properties could not be read | AS-DOC-REC-090 |
| Invoke-ReshelfRecognition › routes a playlist file inside a disc subfolder to ignoredFiles instead of dropping it | AS-DOC-REC-086, AS-DOC-REC-087 |
| Invoke-ReshelfRecognition › attributes a category subfolder release to the parent artist | AS-DOC-REC-026 |
| Invoke-ReshelfRecognition › parses a numbered track filename with no dash separator in the fixture tree | AS-DOC-REC-055 |
| Invoke-ReshelfRecognition › strips the dash from a "yyyy - Release Name" source folder in the fixture tree | AS-DOC-REC-044 |
| Invoke-ReshelfRecognition › parses year and title for each supported release folder name form | AS-DOC-REC-044 to AS-DOC-REC-046 |
| Invoke-ReshelfRecognition › parses a full release date and a release-type hint from each real-world folder name form (session 2026-10-03-0010, Maximum The Hormone) | AS-DOC-REC-048 to AS-DOC-REC-050; AS-DOC-DEF-026 |
| Invoke-ReshelfRecognition › creates a new artist bucket for a band-member folder instead of merging into the parent | AS-DOC-REC-029 |
| Invoke-ReshelfRecognition › walks a grouping folder automatically, treating each subfolder as its own artist flagged for review | AS-DOC-REC-036; AS-DOC-DEF-019 |
| Invoke-ReshelfRecognition › flags a release folder with no artist wrapper as unrecognized | AS-DOC-REC-021 |
| Invoke-ReshelfRecognition › promotes a release-without-artist folder into a recognized release when every track agrees on artist/album tags (real-world "edbl" case) | AS-DOC-REC-023 |
| Invoke-ReshelfRecognition › leaves a release-without-artist folder unrecognized when tracks disagree on artist/album tags | AS-DOC-REC-024 |
| Invoke-ReshelfRecognition › splits a flat "Artist - Album" release folder (no artist wrapper) into a review-flagged release | AS-DOC-REC-022; AS-DOC-DEF-032 |
| Invoke-ReshelfRecognition › still flags a flat release folder with no " - " separator as unrecognized (regression) | AS-DOC-REC-021 |
| Invoke-ReshelfRecognition › does not misparse a leading 4-digit non-year number (e.g. a catalog number) as recognizedYear | AS-DOC-REC-022, AS-DOC-REC-047 |
| Invoke-ReshelfRecognition › does not split a release title containing " - " when a real artist context already exists | AS-DOC-REC-045 |
| Invoke-ReshelfRecognition › strips a release folder name that repeats its own artist name (real-world case), without needsReview | AS-DOC-REC-052 |
| Invoke-ReshelfRecognition › parses the year when it sits between a repeated artist-name prefix and the title (real-world Nostromo case) | AS-DOC-REC-053 |
| Invoke-ReshelfRecognition › parses the year when it sits in parentheses after a repeated artist-name prefix (real-world Aerosmith case) | AS-DOC-REC-053 |
| Invoke-ReshelfRecognition › flags an empty artist folder (no audio anywhere) as unrecognized | AS-DOC-REC-017; AS-DOC-DEF-025 |
| Invoke-ReshelfRecognition › builds cue-sheet virtual tracks and routes the playlist file to ignoredFiles | AS-DOC-REC-068, AS-DOC-REC-073, AS-DOC-REC-086, AS-DOC-REC-088 |
| Invoke-ReshelfRecognition › names cue-sheet virtual tracks from an .ape source as flac, since ffmpeg cannot write .ape | AS-DOC-REC-074; AS-DOC-DEF-030 |
| Invoke-ReshelfRecognition › falls back to whole-folder alphabetical order for unnumbered tracks | AS-DOC-REC-061; AS-DOC-DEF-035 |
| Invoke-ReshelfRecognition › records a reserved device folder name (CON) raw, without converting it | AS-DOC-REC-020 |
| Invoke-ReshelfRecognition › flags a near-path-length-limit release without throwing | AS-DOC-REC-092 |
| Invoke-ReshelfRecognition › merges sourcePaths when the same artist name is found under two different parents | AS-DOC-REC-019; AS-DOC-DEF-034 |
| Invoke-ReshelfRecognition › treats a loose audio file mixed with a subfolder of its own audio as a suspected nested release, not unclassified | AS-DOC-REC-015 |
| Invoke-ReshelfRecognition › ignores a loose non-audio file sitting next to release subfolders and still recognizes the releases | AS-DOC-REC-018 |
| Invoke-ReshelfRecognition › still recognizes a single-file + .cue release when an orphaned second .cue for an unused rip format is also present | AS-DOC-REC-076; AS-DOC-DEF-023, AS-DOC-DEF-030 |
| Invoke-ReshelfRecognition › splits a flat multi-disc folder (several flac+cue pairs, no CD subfolders) into one disc per pair, ordered by catalog-number hint in the folder name (real-world Iron Maiden "The X Factor" case) | AS-DOC-REC-079; AS-DOC-DEF-023, AS-DOC-DEF-033 |
| Invoke-ReshelfRecognition › orders flat multi-disc pairs by REM DISCNUMBER, even when it disagrees with the catalog-number hint in the folder name | AS-DOC-REC-080 |
| Invoke-ReshelfRecognition › falls back to the old ordinary-track behavior when 2 audio files share a single cue (not one cue per disc) | AS-DOC-REC-082 |
| Invoke-ReshelfRecognition › walks an artist folder with category subfolders whose releases carry its name as cue PERFORMER into one artist bucket (real-world Iron Maiden\Studio Albums + Compilation Albums case) | AS-DOC-REC-028; AS-DOC-DEF-037 |
| Invoke-ReshelfRecognition › recognizes a "yyyy - Title" album wrapper around a single edition subfolder, title/year from the album folder | AS-DOC-REC-041 |
| Invoke-ReshelfRecognition › splits an album wrapper with two edition subfolders into two reviewed releases with distinct stableKeys | AS-DOC-REC-007, AS-DOC-REC-042 |
| Invoke-ReshelfRecognition › flags a release for review when its album wrapper folder has a loose file, and does not copy that file in | AS-DOC-REC-043 |
| Invoke-ReshelfRecognition › builds cueSheets per disc for a per-disc-cue release nested inside an album wrapper | AS-DOC-REC-077 |
| Invoke-ReshelfRecognition › mixes a cue-image disc with a normal numbered-track disc in the same release | AS-DOC-REC-078 |
| Invoke-ReshelfRecognition › recognizes LP#-numbered disc folders directly under the release folder as one multi-disc release, not two separate editions (real-world 2-LP vinyl rip) | AS-DOC-REC-040 |
| Invoke-ReshelfRecognition › recognizes CD_1/CD_2 (underscore-separated) disc folders directly under the release folder as one multi-disc release, not two separate editions (real-world Rosetta "The Galilean Satellites" case) | AS-DOC-REC-040 |
| Get-ReshelfCueSheetPathForAudio (private) | AS-DOC-REC-075 |

### legacy/tests/Reshelf.Schemas.Tests.ps1

| Describe / Context | IDs |
|---|---|
| Schema examples validate against their schema | AS-DOC-DAT-021, AS-DOC-DAT-037 |
| recognition.json can be extended into a valid proposal.json | AS-DOC-DAT-022, AS-DOC-DAT-055 |

### legacy/tests/Reshelf.Settings.Tests.ps1

| Describe / Context | IDs |
|---|---|
| Initialize-ReshelfSettings | AS-DOC-DAT-007, AS-DOC-SET-017, AS-DOC-SET-018, AS-DOC-SET-020 to AS-DOC-SET-032; AS-DOC-DEF-014, AS-DOC-DEF-015 |
| Set-ReshelfDiscogsToken | AS-DOC-SET-042, AS-DOC-SET-043 |
| Get-ReshelfSettings | AS-DOC-DAT-020, AS-DOC-SET-014, AS-DOC-SET-033, AS-DOC-SET-034; AS-DOC-DEF-015 |
| Set-ReshelfSettings | AS-DOC-SET-029, AS-DOC-SET-030, AS-DOC-SET-035 to AS-DOC-SET-037, AS-DOC-SET-039, AS-DOC-SET-040; AS-DOC-DEF-014, AS-DOC-DEF-015 |
| New-ReshelfSessionId (private) | AS-DOC-SES-002 to AS-DOC-SES-004 |
| New-ReshelfSession | AS-DOC-DAT-010, AS-DOC-SES-005 to AS-DOC-SES-008; AS-DOC-DEF-017 |
| Resume-ReshelfSession | AS-DOC-SES-012 to AS-DOC-SES-017; AS-DOC-DEF-017 |
| Get-ReshelfSession | AS-DOC-DAT-020, AS-DOC-SES-018 to AS-DOC-SES-022 |

### legacy/tests/Reshelf.TagLibSharp.Integration.Tests.ps1

| Describe / Context | IDs |
|---|---|
| Set-ReshelfAudioTags round-trip (real TagLibSharp) -Tag 'Integration' | AS-DOC-APL-039 to AS-DOC-APL-044 |
| › Context '<_>' -ForEach @('flac', 'mp3') | AS-DOC-APL-039 to AS-DOC-APL-043 |
| Get-ReshelfAudioTags on a real file (real TagLibSharp) -Tag 'Integration' | AS-DOC-APL-046 to AS-DOC-APL-048 |
| Full pipeline with real TagLibSharp and ffmpeg -Tag 'Integration' | AS-DOC-APL-023, AS-DOC-APL-036, AS-DOC-APL-039, AS-DOC-APL-070, AS-DOC-ERR-012 |
| (file header comment and BeforeAll: missing DLL or ffmpeg) | AS-DOC-ERR-013 |

### legacy/tests/Reshelf.Tests.ps1

| Describe / Context | IDs |
|---|---|
| Reshelf.ps1 settings/session dispatch | AS-DOC-CLI-001, AS-DOC-CLI-004 to AS-DOC-CLI-006, AS-DOC-CLI-009 to AS-DOC-CLI-013, AS-DOC-CLI-016, AS-DOC-CLI-018 to AS-DOC-CLI-027, AS-DOC-REV-084; AS-DOC-DEF-104, AS-DOC-DEF-105 |

### legacy/tests/Reshelf.UiServer.Tests.ps1

| Describe / Context | IDs |
|---|---|
| Resolve-ReshelfUiRequestPath | AS-DOC-REV-003 to AS-DOC-REV-005 |
| Get-ReshelfUiMimeType | AS-DOC-REV-006 |
| Get-ReshelfUiApiRoute | AS-DOC-REV-007 to AS-DOC-REV-010; AS-DOC-DEF-078, AS-DOC-DEF-079 |
| Get-ReshelfUiSessionsSummary / Get-ReshelfUiCurrentSession | AS-DOC-REV-011, AS-DOC-REV-012 |
| Get-ReshelfUiProposalContent / Save-ReshelfUiProposalContent | AS-DOC-REV-013 to AS-DOC-REV-015; AS-DOC-DEF-072, AS-DOC-DEF-073 |
| Get-ReshelfUiLocalFileBytes | AS-DOC-REV-016, AS-DOC-REV-017; AS-DOC-DEF-077 |
| Save-ReshelfUiManualCoverFile | AS-DOC-REV-018 to AS-DOC-REV-020 |

### legacy/tests/ui/specs/*.spec.js

| File › test.describe | IDs |
|---|---|
| companions.spec.js › companion (other) files | AS-DOC-REV-050 to AS-DOC-REV-057; AS-DOC-DEF-085 |
| covers.spec.js › cover art | AS-DOC-REV-016, AS-DOC-REV-058 to AS-DOC-REV-065; AS-DOC-DEF-071 |
| edit-and-save.spec.js › editing and saving | AS-DOC-REV-032, AS-DOC-REV-033, AS-DOC-REV-039 to AS-DOC-REV-042, AS-DOC-REV-071 to AS-DOC-REV-073; AS-DOC-DEF-074 |
| folder-name-preview.spec.js › live folder name preview | AS-DOC-REV-032 to AS-DOC-REV-037 |
| load-and-sessions.spec.js › loading and switching sessions | AS-DOC-REV-022, AS-DOC-REV-024, AS-DOC-REV-026, AS-DOC-REV-027; AS-DOC-DEF-080 |
| lossy-tracker.spec.js › lossy tracker view | AS-DOC-REV-078 to AS-DOC-REV-083 |
| review-state.spec.js › review state: Discogs match, Approve, Reject | AS-DOC-REV-029, AS-DOC-REV-031, AS-DOC-REV-066, AS-DOC-REV-067, AS-DOC-REV-069; AS-DOC-DEF-069, AS-DOC-DEF-070 |
| server-down.spec.js › server stopped mid-session | AS-DOC-REV-027, AS-DOC-REV-074, AS-DOC-REV-075 |
| track-artist.spec.js › per-track Artist and Compilation flag | AS-DOC-REV-045 to AS-DOC-REV-049 |
| unrecognized.spec.js › unrecognized folders | AS-DOC-REV-076, AS-DOC-REV-077; AS-DOC-DEF-019 |

### Test helpers, runner and UI support files

| File | IDs |
|---|---|
| legacy/tests/Invoke-ReshelfTests.ps1 (script, no Describe) | AS-DOC-CLI-030 to AS-DOC-CLI-034; AS-DOC-DEF-103 |
| legacy/tests/TestHelpers.psm1 › Get-TreeSnapshot | AS-DOC-APL-001 (helper for the "-WhatIf writes nothing" check; see [Gaps](#gaps), item 2) |
| legacy/tests/ui/seed-session.ps1 | AS-DOC-CLI-038, AS-DOC-CLI-039; AS-DOC-DEF-082, AS-DOC-DEF-100 |
| legacy/tests/ui/global-setup.js › globalSetup | AS-DOC-CLI-005, AS-DOC-CLI-007, AS-DOC-CLI-015, AS-DOC-CLI-036; AS-DOC-DEF-111 |
| legacy/tests/ui/global-teardown.js › globalTeardown | AS-DOC-CLI-040 |
| legacy/tests/ui/helpers.js (getState, seedSession, runApply, gotoApp, mockDiscogsSelection) | AS-DOC-CLI-017, AS-DOC-CLI-027, AS-DOC-CLI-038, AS-DOC-CLI-039, AS-DOC-CLI-041, AS-DOC-REV-067; AS-DOC-DEF-069 |
| legacy/tests/ui/playwright.config.js | AS-DOC-CLI-037, AS-DOC-REV-002 |
| legacy/tests/ui/package.json, legacy/tests/ui/package-lock.json | AS-DOC-CLI-035 (see [Gaps](#gaps), item 3) |
| legacy/tests/ui/test-results/.last-run.json | not a source: output of a test run (see [Gaps](#gaps), item 3) |

### Test fixtures

| File | IDs |
|---|---|
| legacy/tests/fixtures/schema-examples/settings-example.json | AS-DOC-DAT-014, AS-DOC-DAT-026; AS-DOC-DEF-002 |
| legacy/tests/fixtures/schema-examples/session-example.json | AS-DOC-DAT-010, AS-DOC-DAT-029, AS-DOC-DAT-032 |
| legacy/tests/fixtures/schema-examples/recognition-example.json | AS-DOC-DAT-033 to AS-DOC-DAT-047; AS-DOC-DEF-003 |
| legacy/tests/fixtures/schema-examples/proposal-example.json | AS-DOC-DAT-047 to AS-DOC-DAT-057 |
| legacy/tests/fixtures/schema-examples/apply-log-example.json | AS-DOC-DAT-059, AS-DOC-DAT-060 |
| legacy/tests/fixtures/schema-examples/lossy-tracking-example.json | AS-DOC-DAT-016, AS-DOC-DAT-019, AS-DOC-DAT-061, AS-DOC-DAT-062 |
| legacy/tests/fixtures/sample-source-tree/** (15 top-level folders) | examples in AS-DOC-REC-008, AS-DOC-REC-011 to AS-DOC-REC-017, AS-DOC-REC-021, AS-DOC-REC-022, AS-DOC-REC-026, AS-DOC-REC-029, AS-DOC-REC-032 to AS-DOC-REC-038, AS-DOC-REC-040 to AS-DOC-REC-045, AS-DOC-REC-047, AS-DOC-REC-052, AS-DOC-REC-055, AS-DOC-REC-061, AS-DOC-REC-065 to AS-DOC-REC-069, AS-DOC-REC-077, AS-DOC-REC-078, AS-DOC-REC-083, AS-DOC-REC-084, AS-DOC-REC-086, AS-DOC-REC-087, AS-DOC-CLI-043; AS-DOC-DEF-029 |
| legacy/tests/fixtures/expected/recognition.json | AS-DOC-REC-004 to AS-DOC-REC-009, AS-DOC-REC-011, AS-DOC-REC-016, AS-DOC-REC-022, AS-DOC-REC-026, AS-DOC-REC-027, AS-DOC-REC-029, AS-DOC-REC-036, AS-DOC-REC-041, AS-DOC-REC-047, AS-DOC-REC-052, AS-DOC-REC-054, AS-DOC-REC-061, AS-DOC-REC-066 to AS-DOC-REC-068, AS-DOC-REC-073, AS-DOC-REC-077, AS-DOC-REC-084, AS-DOC-REC-089, AS-DOC-REC-091, AS-DOC-REC-093; AS-DOC-DEF-018, AS-DOC-DEF-024, AS-DOC-DEF-025, AS-DOC-DEF-031, AS-DOC-DEF-032 |
| legacy/tests/fixtures/expected/proposal.json | AS-DOC-PRP-003 to AS-DOC-PRP-005, AS-DOC-PRP-007, AS-DOC-PRP-010 to AS-DOC-PRP-012, AS-DOC-PRP-014, AS-DOC-PRP-018, AS-DOC-PRP-019, AS-DOC-PRP-029 to AS-DOC-PRP-031, AS-DOC-PRP-043, AS-DOC-PRP-050, AS-DOC-PRP-053, AS-DOC-PRP-055 to AS-DOC-PRP-057, AS-DOC-PRP-075, AS-DOC-LSY-020, AS-DOC-LSY-023; AS-DOC-DEF-007, AS-DOC-DEF-055, AS-DOC-DEF-062 |
| legacy/tests/fixtures/expected/target-layout.txt | AS-DOC-APL-068 |
| legacy/tests/fixtures/discogs-responses/search-response.json | AS-DOC-DSC-011, AS-DOC-MAT-015, AS-DOC-MAT-023 |
| legacy/tests/fixtures/discogs-responses/release-response.json | AS-DOC-MAT-023; AS-DOC-DEF-064 |
| legacy/tests/ui/fixtures/* (large-cover.jpg, small-cover.jpg, loose-companion.jpg, nested-companion.jpg, upload-cover.png, not-an-image.txt) | AS-DOC-CLI-038 (names); AS-DOC-REV-059, AS-DOC-REV-062, AS-DOC-REV-064 (use) |

## legacy/README.md

| Section | IDs |
|---|---|
| (title section) | AS-DOC-GEN-001, AS-DOC-GEN-003 to AS-DOC-GEN-006; AS-DOC-DEF-010, AS-DOC-DEF-013 |
| ## Pipeline | AS-DOC-GEN-003, AS-DOC-REC-001, AS-DOC-CLI-001, AS-DOC-CLI-002; AS-DOC-DEF-088, AS-DOC-DEF-111 |
| ## Requirements | AS-DOC-DAT-001, AS-DOC-DAT-002, AS-DOC-SET-001, AS-DOC-SET-015, AS-DOC-SET-041; AS-DOC-DEF-038, AS-DOC-DEF-111 |
| ## One-time setup | AS-DOC-SET-002, AS-DOC-SET-003, AS-DOC-SET-005, AS-DOC-SET-019, AS-DOC-SET-020, AS-DOC-SET-023, AS-DOC-SET-025, AS-DOC-SET-031, AS-DOC-SET-033, AS-DOC-SET-041, AS-DOC-SET-042, AS-DOC-SET-044, AS-DOC-CLI-003, AS-DOC-CLI-005, AS-DOC-CLI-006, AS-DOC-CLI-008; AS-DOC-DEF-014, AS-DOC-DEF-111 |
| ## Step-by-step: organizing a folder | AS-DOC-CLI-002 (the heading has no own text; see [Gaps](#gaps), item 1) |
| ### 1. Recognize | AS-DOC-REC-002, AS-DOC-REC-009, AS-DOC-REC-010, AS-DOC-REC-017, AS-DOC-REC-021, AS-DOC-CLI-009 to AS-DOC-CLI-011, AS-DOC-CLI-027 |
| ### 2. Propose | AS-DOC-PRP-001, AS-DOC-PRP-002, AS-DOC-CLI-013; AS-DOC-DEF-058 |
| #### How Discogs matching works | AS-DOC-MAT-006, AS-DOC-MAT-007, AS-DOC-MAT-009, AS-DOC-MAT-030, AS-DOC-MAT-031, AS-DOC-MAT-034, AS-DOC-MAT-036 to AS-DOC-MAT-038; AS-DOC-DEF-044, AS-DOC-DEF-052 |
| ### 3. Review in the browser | AS-DOC-REV-015, AS-DOC-REV-019, AS-DOC-REV-022, AS-DOC-REV-028 to AS-DOC-REV-034, AS-DOC-REV-037 to AS-DOC-REV-040, AS-DOC-REV-044, AS-DOC-REV-045, AS-DOC-REV-047, AS-DOC-REV-050, AS-DOC-REV-051, AS-DOC-REV-058, AS-DOC-REV-062, AS-DOC-REV-066 to AS-DOC-REV-070, AS-DOC-REV-072, AS-DOC-CLI-014; AS-DOC-DEF-007, AS-DOC-DEF-061, AS-DOC-DEF-069, AS-DOC-DEF-076, AS-DOC-DEF-081, AS-DOC-DEF-085, AS-DOC-DEF-102 |
| #### Compilations | AS-DOC-PRP-038, AS-DOC-PRP-040, AS-DOC-PRP-041; AS-DOC-DEF-059, AS-DOC-DEF-060 |
| ### 4. Mark reviewed (optional) | AS-DOC-REV-084, AS-DOC-CLI-021, AS-DOC-CLI-022 |
| ### 5. Apply | AS-DOC-APL-001 to AS-DOC-APL-005, AS-DOC-APL-008, AS-DOC-APL-011, AS-DOC-APL-021, AS-DOC-APL-022, AS-DOC-APL-025, AS-DOC-APL-035, AS-DOC-APL-039, AS-DOC-CLI-017, AS-DOC-CLI-027; AS-DOC-DEF-014, AS-DOC-DEF-083, AS-DOC-DEF-084, AS-DOC-DEF-085, AS-DOC-DEF-088, AS-DOC-DEF-093, AS-DOC-DEF-108 |
| ### 6. Check the result | AS-DOC-APL-071, AS-DOC-CLI-023 |
| ## Sessions and resuming | AS-DOC-SES-001, AS-DOC-SES-009, AS-DOC-SES-011, AS-DOC-SES-018, AS-DOC-SES-020, AS-DOC-SES-023, AS-DOC-CLI-002, AS-DOC-CLI-018 to AS-DOC-CLI-020, AS-DOC-CLI-022; AS-DOC-DEF-086 |
| ## Re-runs and duplicates | AS-DOC-PRP-066, AS-DOC-PRP-070 to AS-DOC-PRP-072, AS-DOC-PRP-074, AS-DOC-PRP-075; AS-DOC-DEF-056, AS-DOC-DEF-057 |
| ## Reference: settings | AS-DOC-SET-002 to AS-DOC-SET-016, AS-DOC-SET-035, AS-DOC-SET-038, AS-DOC-SET-040, AS-DOC-DAT-008, AS-DOC-DAT-086, AS-DOC-TXT-050, AS-DOC-TXT-056, AS-DOC-TXT-067, AS-DOC-CLI-006, AS-DOC-CLI-007; AS-DOC-DEF-014, AS-DOC-DEF-015, AS-DOC-DEF-016, AS-DOC-DEF-039 |
| ## Reference: automatic folder recognition | AS-DOC-REC-009, AS-DOC-REC-010, AS-DOC-REC-025, AS-DOC-REC-026, AS-DOC-REC-028 to AS-DOC-REC-030, AS-DOC-REC-032, AS-DOC-REC-036, AS-DOC-REC-037, AS-DOC-REC-041, AS-DOC-REC-042, AS-DOC-REC-079 to AS-DOC-REC-081; AS-DOC-DEF-019, AS-DOC-DEF-020, AS-DOC-DEF-033, AS-DOC-DEF-037 |
| ## Reference: Japanese releases | AS-DOC-PRP-044 to AS-DOC-PRP-047, AS-DOC-PRP-049; AS-DOC-DEF-066 |
| ## Reference: lossy/lossless tracking | AS-DOC-LSY-004, AS-DOC-LSY-019, AS-DOC-LSY-020, AS-DOC-LSY-024, AS-DOC-LSY-030, AS-DOC-LSY-032, AS-DOC-CLI-002, AS-DOC-CLI-023, AS-DOC-CLI-024; AS-DOC-DEF-098, AS-DOC-DEF-099 |
| ## Reference: data folder | AS-DOC-DAT-003, AS-DOC-DAT-004, AS-DOC-DAT-007 to AS-DOC-DAT-011; AS-DOC-DEF-111 |
| ## Troubleshooting / known limitations | AS-DOC-ERR-001, AS-DOC-ERR-008 to AS-DOC-ERR-011, AS-DOC-CLI-008, AS-DOC-CLI-014; AS-DOC-DEF-091, AS-DOC-DEF-107 |
| ## For developers | AS-DOC-CLI-028, AS-DOC-CLI-030 to AS-DOC-CLI-032, AS-DOC-CLI-035; AS-DOC-DEF-111 |

## legacy/plan/

| File › section | IDs |
|---|---|
| 00-overview.md › Steps | status notes only, listed in [00-general.md](00-general.md) › "Not behavior" |
| 00-overview.md › Pipeline | AS-DOC-GEN-003 |
| 00-overview.md › Tech stack | AS-DOC-GEN-004, AS-DOC-GEN-010; AS-DOC-DEF-083 |
| 00-overview.md › Glossary | AS-DOC-GEN-008, AS-DOC-GEN-009 (and the glossary table in [00-general.md](00-general.md)) |
| 00-overview.md › Cross-cutting decisions | AS-DOC-GEN-007 to AS-DOC-GEN-009; AS-DOC-DEF-057 |
| 00-overview.md › Rough ideas | AS-DOC-DEF-001 |
| 01-repo-and-tooling-scaffolding.md › Repo tree | AS-DOC-CLI-002; AS-DOC-DEF-102 |
| 01-repo-and-tooling-scaffolding.md › Data directory | AS-DOC-CLI-004 |
| 01-repo-and-tooling-scaffolding.md › External tools to install manually | AS-DOC-CLI-028 |
| 01-repo-and-tooling-scaffolding.md › Dev tooling; Manual setup | AS-DOC-CLI-001, AS-DOC-CLI-028 |
| 01-repo-and-tooling-scaffolding.md › `.gitignore` | AS-DOC-CLI-029 |
| 01-repo-and-tooling-scaffolding.md › Purpose / scope; Inputs / outputs; Decisions & rationale; Edge cases; Definition of done | AS-DOC-CLI-004, AS-DOC-CLI-028, AS-DOC-CLI-029 (no new rule) |
| 02-discogs-account-and-api-access.md › Purpose / scope; Inputs / outputs | AS-DOC-DSC-001 |
| 02-discogs-account-and-api-access.md › Account and token | AS-DOC-DSC-001, AS-DOC-DSC-002; AS-DOC-DEF-111 |
| 02-discogs-account-and-api-access.md › Token resolution — `Get-DiscogsToken` | AS-DOC-DSC-002 to AS-DOC-DSC-004, AS-DOC-DSC-006; AS-DOC-DEF-039, AS-DOC-DEF-040, AS-DOC-DEF-111 |
| 02-discogs-account-and-api-access.md › API basics | AS-DOC-DSC-007, AS-DOC-DSC-008; AS-DOC-DEF-041, AS-DOC-DEF-043 |
| 02-discogs-account-and-api-access.md › Rate limiting | AS-DOC-DSC-016, AS-DOC-DSC-018 |
| 02-discogs-account-and-api-access.md › Caching | AS-DOC-DSC-019 to AS-DOC-DSC-024; AS-DOC-DEF-019 (an `overrides.json` mention) |
| 02-discogs-account-and-api-access.md › Matching confidence | AS-DOC-MAT-001, AS-DOC-MAT-015, AS-DOC-MAT-023, AS-DOC-MAT-024; AS-DOC-DEF-049, AS-DOC-DEF-050 |
| 02-discogs-account-and-api-access.md › Decisions & rationale | AS-DOC-DSC-001, AS-DOC-MAT-024; AS-DOC-DEF-048 |
| 02-discogs-account-and-api-access.md › Edge cases | AS-DOC-DSC-013, AS-DOC-MAT-025, AS-DOC-MAT-026 |
| 02-discogs-account-and-api-access.md › Manual setup | AS-DOC-DSC-001 |
| 02-discogs-account-and-api-access.md › Definition of done | AS-DOC-DSC-011, AS-DOC-DSC-016, AS-DOC-DSC-020 |
| 03-domain-model-and-json-schemas.md › Purpose / scope | AS-DOC-DEF-005 |
| 03-domain-model-and-json-schemas.md › Inputs / outputs | AS-DOC-DAT-012, AS-DOC-DAT-021 (the schema files) |
| 03-domain-model-and-json-schemas.md › `stableKey` — the linchpin | AS-DOC-DAT-064, AS-DOC-DAT-065, AS-DOC-DAT-067; AS-DOC-DEF-006 |
| 03-domain-model-and-json-schemas.md › `recognition.json` (+ Notes) | AS-DOC-DAT-033, AS-DOC-DAT-039, AS-DOC-DAT-041, AS-DOC-DAT-044 to AS-DOC-DAT-046, AS-DOC-TXT-051 to AS-DOC-TXT-053; AS-DOC-DEF-003, AS-DOC-DEF-008, AS-DOC-DEF-011 |
| 03-domain-model-and-json-schemas.md › `proposal.json` (+ field rules) | AS-DOC-DAT-022, AS-DOC-DAT-048 to AS-DOC-DAT-056, AS-DOC-TXT-049, AS-DOC-TXT-057 to AS-DOC-TXT-072; AS-DOC-DEF-004, AS-DOC-DEF-005, AS-DOC-DEF-006, AS-DOC-DEF-010, AS-DOC-DEF-013 |
| 03-domain-model-and-json-schemas.md › `session.json` | AS-DOC-DAT-029 |
| 03-domain-model-and-json-schemas.md › `settings.json` | AS-DOC-DAT-026; AS-DOC-DEF-002 |
| 03-domain-model-and-json-schemas.md › Lossy-tracking file | AS-DOC-DAT-011 |
| 03-domain-model-and-json-schemas.md › Decisions & rationale | AS-DOC-DAT-012, AS-DOC-DAT-039, AS-DOC-DAT-067 |
| 03-domain-model-and-json-schemas.md › Edge cases | AS-DOC-DAT-036, AS-DOC-DAT-058, AS-DOC-DAT-066, AS-DOC-TXT-050; AS-DOC-DEF-007 |
| 03-domain-model-and-json-schemas.md › Definition of done | AS-DOC-DAT-021, AS-DOC-DAT-022; AS-DOC-DEF-003 |
| 04-settings-module.md › Purpose / scope | AS-DOC-SET-006; AS-DOC-DEF-011, AS-DOC-DEF-014 |
| 04-settings-module.md › Inputs / outputs | AS-DOC-SET-002; AS-DOC-DEF-016 |
| 04-settings-module.md › `Reshelf.Settings.psm1` functions | AS-DOC-SET-019, AS-DOC-SET-033; AS-DOC-DEF-014 |
| 04-settings-module.md › CLI shape | AS-DOC-SET-002, AS-DOC-SET-004 |
| 04-settings-module.md › Naming templates | AS-DOC-TXT-046, AS-DOC-TXT-047, AS-DOC-TXT-050, AS-DOC-TXT-056, AS-DOC-SET-008 |
| 04-settings-module.md › Session persistence | AS-DOC-SES-001, AS-DOC-SES-002, AS-DOC-SES-007, AS-DOC-SES-009 to AS-DOC-SES-011, AS-DOC-SES-023; AS-DOC-DEF-017 |
| 04-settings-module.md › Decisions & rationale | AS-DOC-SET-004, AS-DOC-TXT-050 |
| 04-settings-module.md › Edge cases | AS-DOC-SET-022; AS-DOC-DEF-015 |
| 04-settings-module.md › Manual setup; Definition of done | AS-DOC-SET-004, AS-DOC-SET-032 |
| 05-recognition-module.md › (superseded note) | AS-DOC-REC-010, AS-DOC-REC-036, AS-DOC-REC-037; AS-DOC-DEF-019 |
| 05-recognition-module.md › Purpose / scope | AS-DOC-REC-001 |
| 05-recognition-module.md › Inputs / outputs | AS-DOC-REC-002, AS-DOC-REC-003; AS-DOC-DEF-019 |
| 05-recognition-module.md › Entry point | AS-DOC-REC-002 |
| 05-recognition-module.md › Heuristic functions | AS-DOC-REC-025, AS-DOC-REC-029, AS-DOC-REC-032; AS-DOC-DEF-018, AS-DOC-DEF-020 |
| 05-recognition-module.md › The rule: only genuinely ambiguous cases go to a human | AS-DOC-REC-026, AS-DOC-REC-029; AS-DOC-DEF-019 |
| 05-recognition-module.md › Deterministic cleanups added against real data (plan/12 milestone 3) | AS-DOC-REC-023, AS-DOC-REC-024, AS-DOC-REC-052, AS-DOC-REC-091 |
| 05-recognition-module.md › Track/disc parsing | AS-DOC-REC-055, AS-DOC-REC-061, AS-DOC-REC-062, AS-DOC-REC-066; AS-DOC-DEF-013, AS-DOC-DEF-021, AS-DOC-DEF-022, AS-DOC-DEF-035 |
| 05-recognition-module.md › Single-file + cue detection | AS-DOC-REC-068, AS-DOC-REC-077; AS-DOC-DEF-023 |
| 05-recognition-module.md › Companion file classification | AS-DOC-REC-083, AS-DOC-REC-084, AS-DOC-REC-086; AS-DOC-DEF-024, AS-DOC-DEF-037 |
| 05-recognition-module.md › Reading existing tags | AS-DOC-REC-089; AS-DOC-DEF-038 |
| 05-recognition-module.md › Output | AS-DOC-REC-003 |
| 05-recognition-module.md › Decisions & rationale | AS-DOC-DEF-019 |
| 05-recognition-module.md › Edge cases | AS-DOC-REC-015, AS-DOC-REC-017, AS-DOC-REC-092; AS-DOC-DEF-025 |
| 05-recognition-module.md › Manual setup | AS-DOC-REC-089 |
| 05-recognition-module.md › Definition of done | AS-DOC-DEF-019 (the planted patterns are covered by AS-DOC-REC-011 to AS-DOC-REC-088) |
| 06-edit-proposal-module.md › Purpose / scope; Inputs / outputs; Entry point | AS-DOC-PRP-003 |
| 06-edit-proposal-module.md › Discogs lookup | AS-DOC-MAT-002 to AS-DOC-MAT-006, AS-DOC-MAT-009, AS-DOC-MAT-016, AS-DOC-MAT-023, AS-DOC-MAT-027, AS-DOC-MAT-028, AS-DOC-MAT-031, AS-DOC-MAT-034; AS-DOC-DEF-044, AS-DOC-DEF-047 |
| 06-edit-proposal-module.md › Computing proposed names and tags | AS-DOC-MAT-042, AS-DOC-MAT-050, AS-DOC-MAT-051, AS-DOC-MAT-053, AS-DOC-MAT-058, AS-DOC-MAT-059, AS-DOC-PRP-005, AS-DOC-PRP-006, AS-DOC-PRP-008, AS-DOC-PRP-009, AS-DOC-PRP-012 to AS-DOC-PRP-014, AS-DOC-PRP-017 to AS-DOC-PRP-028, AS-DOC-PRP-032, AS-DOC-PRP-033, AS-DOC-PRP-035 to AS-DOC-PRP-041, AS-DOC-PRP-043; AS-DOC-DEF-013, AS-DOC-DEF-051, AS-DOC-DEF-059, AS-DOC-DEF-060, AS-DOC-DEF-061, AS-DOC-DEF-068 |
| 06-edit-proposal-module.md › Cover art candidates | AS-DOC-PRP-050, AS-DOC-PRP-054, AS-DOC-PRP-056; AS-DOC-DEF-054 |
| 06-edit-proposal-module.md › Target comparison (lossy/lossless + duplicate handling) | AS-DOC-PRP-061, AS-DOC-PRP-066, AS-DOC-PRP-067, AS-DOC-PRP-069 to AS-DOC-PRP-072, AS-DOC-LSY-024 to AS-DOC-LSY-026; AS-DOC-DEF-056, AS-DOC-DEF-057, AS-DOC-DEF-058 |
| 06-edit-proposal-module.md › Decisions & rationale | AS-DOC-MAT-051, AS-DOC-PRP-035, AS-DOC-PRP-037, AS-DOC-PRP-067; AS-DOC-DEF-058 |
| 06-edit-proposal-module.md › Edge cases | AS-DOC-MAT-044 to AS-DOC-MAT-046, AS-DOC-PRP-022, AS-DOC-PRP-034, AS-DOC-PRP-053, AS-DOC-PRP-055; AS-DOC-DEF-045, AS-DOC-DEF-064 |
| 06-edit-proposal-module.md › Manual setup; Definition of done | AS-DOC-PRP-020, AS-DOC-PRP-035, AS-DOC-PRP-067 |
| 07-editing-ui-module.md › Purpose / scope; Inputs / outputs; Structure | AS-DOC-REV-001 |
| 07-editing-ui-module.md › Server-side persistence | AS-DOC-REV-001, AS-DOC-REV-007, AS-DOC-REV-011, AS-DOC-REV-012, AS-DOC-REV-016, AS-DOC-REV-021, AS-DOC-REV-022, AS-DOC-REV-025, AS-DOC-REV-026, AS-DOC-REV-060; AS-DOC-DEF-077, AS-DOC-DEF-080 |
| 07-editing-ui-module.md › Save behavior | AS-DOC-REV-015, AS-DOC-REV-072 |
| 07-editing-ui-module.md › UI shape | AS-DOC-REV-028, AS-DOC-REV-033, AS-DOC-REV-039, AS-DOC-REV-045, AS-DOC-REV-050 to AS-DOC-REV-052, AS-DOC-REV-054, AS-DOC-REV-058, AS-DOC-REV-059, AS-DOC-REV-066, AS-DOC-REV-068, AS-DOC-REV-070; AS-DOC-DEF-076 |
| 07-editing-ui-module.md › Live folder-name preview | AS-DOC-REV-021, AS-DOC-REV-034 to AS-DOC-REV-037, AS-DOC-REV-047; AS-DOC-DEF-073 |
| 07-editing-ui-module.md › Live track file-name preview | AS-DOC-REV-041 to AS-DOC-REV-043; AS-DOC-DEF-074, AS-DOC-DEF-075 |
| 07-editing-ui-module.md › Unrecognized folders | AS-DOC-REV-076, AS-DOC-REV-077; AS-DOC-DEF-019 |
| 07-editing-ui-module.md › Lossy tracker tab | AS-DOC-REV-078, AS-DOC-REV-080 to AS-DOC-REV-083 |
| 07-editing-ui-module.md › Approval gate | AS-DOC-REV-070; AS-DOC-DEF-082, AS-DOC-DEF-085 |
| 07-editing-ui-module.md › Decisions & rationale | AS-DOC-REV-001, AS-DOC-REV-008, AS-DOC-REV-015 |
| 07-editing-ui-module.md › Edge cases | AS-DOC-REV-017, AS-DOC-REV-023, AS-DOC-REV-024, AS-DOC-REV-074, AS-DOC-REV-075 |
| 07-editing-ui-module.md › Manual setup; Definition of done | AS-DOC-REV-001, AS-DOC-REV-022, AS-DOC-REV-072 (no new rule) |
| 08-implementation-module.md › Purpose / scope; Inputs / outputs | AS-DOC-APL-001, AS-DOC-APL-021; AS-DOC-DEF-088 |
| 08-implementation-module.md › Entry point | AS-DOC-APL-001 to AS-DOC-APL-003, AS-DOC-APL-005; AS-DOC-DEF-085, AS-DOC-DEF-108 |
| 08-implementation-module.md › Per-release pipeline | AS-DOC-APL-007, AS-DOC-APL-008, AS-DOC-APL-011, AS-DOC-APL-017 to AS-DOC-APL-019, AS-DOC-APL-032, AS-DOC-APL-035, AS-DOC-APL-039, AS-DOC-APL-040, AS-DOC-APL-049 to AS-DOC-APL-055, AS-DOC-APL-062, AS-DOC-APL-065; AS-DOC-DEF-083, AS-DOC-DEF-084, AS-DOC-DEF-092, AS-DOC-DEF-093, AS-DOC-DEF-096, AS-DOC-DEF-106 |
| 08-implementation-module.md › Why staging-then-commit | AS-DOC-APL-017, AS-DOC-ERR-002 |
| 08-implementation-module.md › Decisions & rationale | AS-DOC-APL-021, AS-DOC-APL-032, AS-DOC-ERR-012; AS-DOC-DEF-096, AS-DOC-DEF-108 |
| 08-implementation-module.md › Edge cases | AS-DOC-APL-045, AS-DOC-ERR-001, AS-DOC-ERR-002; AS-DOC-DEF-109 |
| 08-implementation-module.md › Manual setup; Definition of done | AS-DOC-APL-011, AS-DOC-APL-065, AS-DOC-APL-067 to AS-DOC-APL-069 |
| 09-lossy-lossless-tracking.md › Purpose / scope; Inputs / outputs | AS-DOC-LSY-001 |
| 09-lossy-lossless-tracking.md › Schema | AS-DOC-LSY-004, AS-DOC-LSY-009 |
| 09-lossy-lossless-tracking.md › Lifecycle | AS-DOC-LSY-008, AS-DOC-LSY-020, AS-DOC-LSY-021, AS-DOC-LSY-024, AS-DOC-LSY-026, AS-DOC-LSY-027, AS-DOC-LSY-030, AS-DOC-LSY-031; AS-DOC-DEF-057, AS-DOC-DEF-097, AS-DOC-DEF-098, AS-DOC-DEF-099 |
| 09-lossy-lossless-tracking.md › CLI helpers | AS-DOC-LSY-018, AS-DOC-LSY-032 |
| 09-lossy-lossless-tracking.md › Decisions & rationale | AS-DOC-LSY-001, AS-DOC-LSY-019 |
| 09-lossy-lossless-tracking.md › Edge cases | AS-DOC-LSY-010 |
| 09-lossy-lossless-tracking.md › Manual setup; Definition of done | AS-DOC-LSY-020, AS-DOC-LSY-030, AS-DOC-LSY-032 |
| 10-error-handling-and-edge-cases.md › Purpose / scope | AS-DOC-DEF-110 |
| 10-error-handling-and-edge-cases.md › Re-runs and duplicate detection | AS-DOC-APL-010, AS-DOC-ERR-004 to AS-DOC-ERR-006 |
| 10-error-handling-and-edge-cases.md › Session persistence and resume | AS-DOC-APL-013, AS-DOC-APL-064, AS-DOC-ERR-001 |
| 10-error-handling-and-edge-cases.md › Ambiguous/unrecognizable folders | AS-DOC-ERR-007; AS-DOC-DEF-019 |
| 10-error-handling-and-edge-cases.md › Windows path length | AS-DOC-APL-057, AS-DOC-APL-060, AS-DOC-ERR-003; AS-DOC-DEF-106, AS-DOC-DEF-109 |
| 10-error-handling-and-edge-cases.md › Invalid filename characters | AS-DOC-TXT-020 to AS-DOC-TXT-029 (safe names, in [02-text-and-naming-rules.md](02-text-and-naming-rules.md)) |
| 10-error-handling-and-edge-cases.md › Definition of done | AS-DOC-DEF-109 |
| 11-testing-and-verification-strategy.md › Purpose / scope | no own rule (see the sections below) |
| 11-testing-and-verification-strategy.md › Unit tests (Pester 5) | AS-DOC-CLI-042 |
| 11-testing-and-verification-strategy.md › Fixture source tree | AS-DOC-CLI-043 |
| 11-testing-and-verification-strategy.md › Discogs mocking | AS-DOC-CLI-044 |
| 11-testing-and-verification-strategy.md › Implementation module verification | AS-DOC-CLI-031, AS-DOC-CLI-045; AS-DOC-DEF-103 |
| 11-testing-and-verification-strategy.md › Golden files for the whole fixture tree | AS-DOC-CLI-046 |
| 11-testing-and-verification-strategy.md › UI verification | AS-DOC-CLI-035 to AS-DOC-CLI-038; AS-DOC-DEF-071, AS-DOC-DEF-101 |
| 11-testing-and-verification-strategy.md › Decisions & rationale | AS-DOC-CLI-042, AS-DOC-CLI-045 |
| 11-testing-and-verification-strategy.md › Test runner | AS-DOC-CLI-030 to AS-DOC-CLI-033; AS-DOC-DEF-103 |
| 11-testing-and-verification-strategy.md › Definition of done | AS-DOC-CLI-030, AS-DOC-CLI-035, AS-DOC-CLI-046 (no new rule) |
| 12-build-order-and-milestones.md › Status (milestones 0, 3–8) | AS-DOC-APL-019, AS-DOC-APL-021, AS-DOC-APL-067, AS-DOC-APL-069, AS-DOC-APL-070, AS-DOC-ERR-012; AS-DOC-DEF-019 |
| 12-build-order-and-milestones.md › Milestone 1 — confirmed | AS-DOC-DSC-007, AS-DOC-DSC-016, AS-DOC-DSC-018 |
| 12-build-order-and-milestones.md › Sequence | AS-DOC-APL-020, AS-DOC-APL-067, AS-DOC-APL-071, AS-DOC-ERR-012; AS-DOC-DEF-019 |
| 12-build-order-and-milestones.md › Purpose / scope; Decisions & rationale; Definition of done | scheduling only, no behavior rule; AS-DOC-DEF-019 (the `overrides.json` lines) |
| 13-bandcamp-fallback.md › Status: research needed, not started | AS-DOC-BND-001 |
| 13-bandcamp-fallback.md › Purpose / scope | AS-DOC-BND-001, AS-DOC-BND-002 |
| 13-bandcamp-fallback.md › Research questions | AS-DOC-BND-002 (and the open-questions list in [13-bandcamp-and-errors.md](13-bandcamp-and-errors.md)) |
| 13-bandcamp-fallback.md › Decisions & rationale; Definition of done | AS-DOC-BND-001, AS-DOC-BND-002 (design if built: open-questions section of [13-bandcamp-and-errors.md](13-bandcamp-and-errors.md)) |

## legacy/schemas/

| File | IDs |
|---|---|
| apply-log.schema.json | AS-DOC-DAT-023, AS-DOC-DAT-025, AS-DOC-DAT-059, AS-DOC-DAT-060 |
| lossy-tracking.schema.json | AS-DOC-DAT-023 to AS-DOC-DAT-025, AS-DOC-DAT-061, AS-DOC-DAT-062; AS-DOC-DEF-007 |
| proposal.schema.json | AS-DOC-DAT-024, AS-DOC-DAT-048 to AS-DOC-DAT-057; AS-DOC-DEF-004, AS-DOC-DEF-005, AS-DOC-DEF-007 |
| recognition.schema.json | AS-DOC-DAT-023 to AS-DOC-DAT-025, AS-DOC-DAT-033 to AS-DOC-DAT-047; AS-DOC-DEF-003, AS-DOC-DEF-006, AS-DOC-DEF-008, AS-DOC-DEF-009 |
| session.schema.json | AS-DOC-DAT-023, AS-DOC-DAT-029 to AS-DOC-DAT-032, AS-DOC-SES-009; AS-DOC-DEF-017 |
| settings.schema.json | AS-DOC-DAT-026 to AS-DOC-DAT-028, AS-DOC-SET-006; AS-DOC-DEF-002, AS-DOC-DEF-016 |

## MANIFESTO.md

| Section | IDs |
|---|---|
| §1 Problem | the problem table in [00-general.md](00-general.md) › "Problem the app solves" (no requirement ID; see [Gaps](#gaps), item 5) |
| §2 Core Idea | AS-DOC-GEN-001 |
| §3 Goal | AS-DOC-GEN-002 |
| §4 Target Storage Structure (heading only) | see §4.1–4.5 |
| §4.1 Root | AS-DOC-TXT-042 |
| §4.2 Level 1 — Main Artist | AS-DOC-TXT-043, AS-DOC-TXT-044, AS-DOC-TXT-055 |
| §4.3 Level 2 — Release | AS-DOC-TXT-045, AS-DOC-TXT-046; AS-DOC-DEF-009 |
| §4.4 Level 3 — Media Files (Tracks) | AS-DOC-TXT-047 to AS-DOC-TXT-049, AS-DOC-TXT-051, AS-DOC-TXT-052; AS-DOC-DEF-011, AS-DOC-DEF-013 |
| §4.5 Companion / Extra Materials | AS-DOC-TXT-030, AS-DOC-TXT-053 to AS-DOC-TXT-055; AS-DOC-DEF-008 |
| §5 Metadata Rules | AS-DOC-TXT-048, AS-DOC-TXT-057 to AS-DOC-TXT-069; AS-DOC-DEF-010, AS-DOC-DEF-013 |
| §6 Additional Feature — Lossy/Lossless Tracking | AS-DOC-LSY-001, AS-DOC-LSY-020; AS-DOC-DEF-099 |
| §7 Proposed Process / Module Breakdown | AS-DOC-GEN-003 (the stages = modules 1–5); AS-DOC-APL-007, AS-DOC-APL-021, AS-DOC-APL-025 (module 5); see [Gaps](#gaps), item 6 |
| §8 Tooling Philosophy | AS-DOC-ERR-007, AS-DOC-ERR-012, AS-DOC-ERR-014; AS-DOC-DEF-107, AS-DOC-DEF-108 |
| §9 Open Questions for the Next Planning Session | AS-DOC-DEF-110 (and the open-questions table in [13-bandcamp-and-errors.md](13-bandcamp-and-errors.md)) |

## Gaps

The lead session compared the six coverage drafts with the full block list (166 entries: 115 Describe / Context blocks in the Pester files, 10 `test.describe` blocks, 21 README headings, 14 plan files, 6 schema files). It also compared every row with the `Source:` lines of the area files. Every block now has at least one ID. These items needed action:

| # | Block | What the drafts had | Result |
|---|---|---|---|
| 1 | README › ## Step-by-step: organizing a folder | no row | Resolved. The heading has no text of its own; its content is in the sub-sections 1–6, which are all mapped. AS-DOC-CLI-002 cites it. |
| 2 | legacy/tests/TestHelpers.psm1 › Get-TreeSnapshot | "no own ID, cross-area" | Resolved. The helper makes the before/after file listing for the `-WhatIf` check in the Implementation and Pipeline tests. Mapped to AS-DOC-APL-001 ("Dry run with -WhatIf writes nothing"). No area file cites the helper file itself. |
| 3 | legacy/tests/ui/package.json, package-lock.json, test-results/.last-run.json | no row | Resolved. `package.json` declares `@playwright/test` and the `playwright test` script: AS-DOC-CLI-035 (one-time `npm install`, direct run). `test-results/.last-run.json` is output of a test run, not a source. |
| 4 | Reshelf.Pipeline.Tests.ps1 › Full pipeline: Recognition -> EditProposal -> Implementation, non-apply tests (schema-valid JSON, grouping folder, golden `recognition.json` and `proposal.json`) | "cross-area pointers in 10-apply.md" | Resolved. Mapped to the IDs that state the same rules: AS-DOC-REC-003, AS-DOC-REC-004, AS-DOC-REC-009, AS-DOC-REC-036, AS-DOC-PRP-003. These IDs cite the Recognition / EditProposal tests and the golden files, not the Pipeline test. |
| 5 | MANIFESTO §1 Problem | the problem table in 00-general.md | Accepted as is. §1 describes the problem, not a behavior. The table links each pattern to its area file. |
| 6 | MANIFESTO §7, modules 1–4 (settings, recognition, edit proposal, editing UI) | "cross-area pointers in 10-apply.md" | Resolved by the lead: mapped to AS-DOC-GEN-003 (the four stages). The detailed behavior of each module is in the area files 03, 04, 05, 07, 08, 09 and 11, from higher sources. |

One more finding, not a coverage gap: AS-DOC-ERR-007 (and the example in AS-DOC-ERR-014) describes the `overrides.json` design from plan 10, which the README and the tests contradict. AS-DOC-DEF-019 records it.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-05 | Phase 1 draft. |
