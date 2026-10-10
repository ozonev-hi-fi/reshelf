# As-is (from code): Coverage

Status: Draft | Version: 0.1 | Last updated: 2026-10-10

Every function in every owned module, mapped to the `AS-CODE-*` requirement IDs that describe it (or a
note where it is covered only indirectly). Built in the merge pass by extracting every `Source:` line
from the 13 area files and grouping by function name. "Public" means the function appears in that
module's own `Export-ModuleMember` list; everything else is a private helper, included because the real
behavior rules mostly live there (per the Phase 2 scope decision — see `00-roadmap.md`).

## Reshelf.Common.psm1 (27 functions) — files 01, 02

| Function | Public? | IDs |
|---|---|---|
| Resolve-ReshelfDataHome | Yes | AS-CODE-DAT-001–004 |
| ConvertTo-ReshelfNormalizedText | No | AS-CODE-TXT-001–002 |
| ConvertTo-ReshelfHomoglyphNormalizedText | No | AS-CODE-TXT-003–004 |
| Test-ReshelfHasJapaneseScript | No | AS-CODE-TXT-005 |
| Test-ReshelfIsRomanizedText | No | AS-CODE-TXT-006–008 |
| Join-ReshelfBilingualName | No | AS-CODE-TXT-009–011 |
| ConvertTo-ReshelfCueTimestampSeconds | No | AS-CODE-DAT-005–006 |
| Get-ReshelfSha256Hex | No | AS-CODE-DAT-007 |
| Get-ReshelfStableKey | Yes | AS-CODE-DAT-008–009 |
| Remove-ReshelfInvisibleCharacters | No | AS-CODE-TXT-012 |
| ConvertTo-ReshelfTitleCase | No | AS-CODE-TXT-013 |
| ConvertTo-ReshelfLongPath | Yes | AS-CODE-DAT-010–013 |
| Test-ReshelfIsAudioExtension | No | AS-CODE-DAT-014 |
| Test-ReshelfIsLosslessFormat | No | AS-CODE-DAT-015 (see AS-CODE-DEF-002) |
| Get-ReshelfAudioFilesInFolder | No | AS-CODE-DAT-016–018 |
| ConvertFrom-ReshelfTrackFileName | No | AS-CODE-TXT-014–015 (see AS-CODE-DEF-004) |
| ConvertTo-SafeFileName | No | AS-CODE-TXT-016–019 |
| Test-ReshelfLooseCompanionFileName | No | AS-CODE-TXT-020 |
| Get-ReshelfLooseCompanionFileName | No | AS-CODE-TXT-021–022 |
| ConvertTo-ReshelfTruncatedSegment | No | AS-CODE-TXT-023–026 |
| Get-ReshelfRelativePath | No | AS-CODE-DAT-019–020 (see AS-CODE-DEF-001) |
| Get-ReshelfFileSetHash | No | AS-CODE-DAT-021–023 |
| Protect-ReshelfSecret | No | AS-CODE-DAT-024 |
| Unprotect-ReshelfSecret | No | AS-CODE-DAT-025 |
| Set-ReshelfTagLibSharpContext | No | AS-CODE-DAT-026 |
| Get-ReshelfEffectiveDataHome | Yes | AS-CODE-DAT-027 |
| Import-ReshelfTagLibSharp | No | AS-CODE-DAT-028–030 |

## Reshelf.Json.psm1 (3 functions) — file 01

| Function | Public? | IDs |
|---|---|---|
| Resolve-ReshelfSchemaPath | No | AS-CODE-DAT-031–032 |
| Test-ReshelfJson | Yes | AS-CODE-DAT-033–035 |
| Set-ReshelfJsonFile | Yes | AS-CODE-DAT-036–038 |

## Reshelf.Settings.psm1 (12 functions) — files 03, 04

| Function | Public? | IDs |
|---|---|---|
| Test-ReshelfHostIsInteractive | No | AS-CODE-SET-001 |
| New-ReshelfSessionId | No | AS-CODE-SES-001–002 |
| Assert-ReshelfPathWritable | No | AS-CODE-SET-002–003 |
| Get-ReshelfSettings | Yes | AS-CODE-SET-004–006 |
| Initialize-ReshelfSettings | Yes | AS-CODE-SET-007–015 |
| Set-ReshelfDiscogsToken | Yes | AS-CODE-SET-016–018 (see AS-CODE-DEF-005, -006) |
| Set-ReshelfSettings | Yes | AS-CODE-SET-019–024 |
| New-ReshelfSession | No | AS-CODE-SES-003–005 |
| Read-ReshelfSessionFile | No | AS-CODE-SES-006 |
| Get-ReshelfSession | No | AS-CODE-SES-007–008 |
| Resume-ReshelfSession | No | AS-CODE-SES-009 |
| Set-ReshelfSessionStage | No | AS-CODE-SES-010–012 (see AS-CODE-DEF-007) |

`legacy/config/settings.default.json` (not a function, a data file): covered by AS-CODE-SET-014.

## Reshelf.Recognition.psm1 (34 functions) — file 05

| Function | Public? | IDs |
|---|---|---|
| Test-IsDiscFolder | No | AS-CODE-REC-001 |
| Get-ReshelfDiscNumber | No | AS-CODE-REC-002 |
| Get-ReshelfDiscFolders | No | AS-CODE-REC-003–004 |
| Test-IsReleaseFolder | No | AS-CODE-REC-005–007 |
| Test-IsCategorySubfolder | No | AS-CODE-REC-008 |
| Test-IsAlbumWrapperFolder | No | AS-CODE-REC-009–012 |
| Test-IsGroupingFolder | No | AS-CODE-REC-013–016 (see AS-CODE-DEF-012) |
| Test-IsBandMemberFolder | No | AS-CODE-REC-017–021 (see AS-CODE-DEF-012) |
| Get-ReshelfReleaseFolderMetadataArtist | No | AS-CODE-REC-022–023 |
| Test-ReshelfMetadataConfirmsArtist | No | AS-CODE-REC-024 |
| Get-ReshelfTrackOrder | No | AS-CODE-REC-025–026 |
| Get-ReshelfCueSheetPathForAudio | No | AS-CODE-REC-027–030 |
| Test-IsCueSheetRelease | No | AS-CODE-REC-031 |
| Get-ReshelfFlatDiscCuePairs | No | AS-CODE-REC-032–035 |
| ConvertFrom-ReshelfCueSheetText | No | AS-CODE-REC-036–037 |
| ConvertFrom-ReshelfCueSheet | No | AS-CODE-REC-038 |
| Get-ReshelfCueSheetHeader | No | AS-CODE-REC-039–040 |
| New-ReshelfCueVirtualTracks | No | AS-CODE-REC-041–044 |
| Resolve-ReshelfCompanionKind | No | AS-CODE-REC-045–046 |
| Get-ReshelfCompanionFiles | No | AS-CODE-REC-047–050 |
| Save-ReshelfEmbeddedCoverToCache | No | AS-CODE-REC-051–053 (see AS-CODE-DEF-013) |
| Get-ReshelfAudioTags | Yes | AS-CODE-REC-054–056 (see AS-CODE-DEF-014) |
| Resolve-ReshelfArtistAlbumFromTags | No | AS-CODE-REC-057–058 |
| Resolve-ReshelfFolderKind | No | AS-CODE-REC-059–063 |
| New-ReshelfUnrecognizedEntry | No | AS-CODE-REC-064 |
| Add-ReshelfInheritedReviewReasons | No | AS-CODE-REC-065 |
| Merge-ReshelfArtistBucket | No | AS-CODE-REC-066–067 |
| Split-ReshelfLeadingYear | No | AS-CODE-REC-068–071 (see AS-CODE-DEF-008) |
| Split-ReshelfReleaseTypeHint | No | AS-CODE-REC-072–074 |
| Remove-ReshelfArtistNamePrefixFromTitle | No | AS-CODE-REC-075–077 |
| New-ReshelfReleaseRecord | No | AS-CODE-REC-078–094 (see AS-CODE-DEF-009, -010) |
| Invoke-ReshelfFolderWalk | No | AS-CODE-REC-095–105 (see AS-CODE-DEF-010, -011) |
| New-ReshelfRecognitionDocument | No | AS-CODE-REC-106–107 |
| Invoke-ReshelfRecognition | Yes | AS-CODE-REC-108–110 |

## Reshelf.Discogs.psm1 (8 functions) — file 06

| Function | Public? | IDs |
|---|---|---|
| Get-DiscogsToken | Yes | AS-CODE-DSC-001–005 |
| Get-DiscogsQueryPair | No | AS-CODE-DSC-006 |
| Get-DiscogsCacheKey | No | AS-CODE-DSC-007 |
| Remove-DiscogsExpiredCache | Yes | AS-CODE-DSC-008–012 |
| Wait-DiscogsRateLimit | No | AS-CODE-DSC-015–017 (see AS-CODE-DEF-016) |
| Get-DiscogsRetryAfterSeconds | No | AS-CODE-DSC-020–022 |
| Invoke-DiscogsHttpRequest | No | AS-CODE-DSC-023 |
| Invoke-DiscogsRequest | Yes | AS-CODE-DSC-013–014, 018–019, 024–032 (see AS-CODE-DEF-015) |

## Reshelf.EditProposal.psm1, lines 1–1330 (23 functions) — file 07

| Function | Public? | IDs |
|---|---|---|
| Get-ReshelfLevenshteinDistance | No | AS-CODE-MAT-001 |
| Get-ReshelfStringSimilarity | No | AS-CODE-MAT-002 |
| Get-ReshelfDiscogsSearchTitleVariants | No | AS-CODE-MAT-003–006 |
| Get-ReshelfDiscogsSearchQuery | No | AS-CODE-MAT-007 |
| Get-ReshelfDiscogsTitleForms | No | AS-CODE-MAT-008 |
| Get-ReshelfDiscogsCandidateScore | No | AS-CODE-MAT-009–015 (see AS-CODE-DEF-017) |
| Get-ReshelfDiscogsPlayableTracks | No | AS-CODE-MAT-017 |
| Get-ReshelfDiscogsDurationSeconds | No | AS-CODE-MAT-018 |
| Get-ReshelfDiscogsFingerprintScore | No | AS-CODE-MAT-019–023 |
| Get-ReshelfDiscogsArtistCredit | No | AS-CODE-MAT-024–025 |
| Test-ReshelfIsCompilationArtist | No | AS-CODE-MAT-026–027 |
| Get-ReshelfVariousArtistsEvidence | No | AS-CODE-MAT-028–030 |
| Get-ReshelfDiscogsFormatPreferenceRank | No | AS-CODE-MAT-031 |
| Get-ReshelfDiscogsVersionRank | No | AS-CODE-MAT-032–035 |
| Sort-ReshelfDiscogsVersions | No | AS-CODE-MAT-036 |
| Select-ReshelfBestDiscogsCandidate | No | AS-CODE-MAT-037–039 |
| Get-ReshelfScoredDiscogsCandidates | No | AS-CODE-MAT-040 |
| Get-ReshelfMasterVersionCandidates | No | AS-CODE-MAT-041 |
| Select-ReshelfDiscogsMasterVersion | No | AS-CODE-MAT-042–045 |
| Resolve-ReshelfDiscogsArtistIdentity | No | AS-CODE-MAT-046–048 |
| Resolve-ReshelfDiscogsCatalogFallback | No | AS-CODE-MAT-050–054 |
| Resolve-ReshelfDiscogsMatch | No | AS-CODE-MAT-016, 049, 055–066 (see AS-CODE-DEF-018) |
| Resolve-ReshelfDiscogsMatchForRelease | No | AS-CODE-MAT-067 |

## Reshelf.EditProposal.psm1, lines 1332–2928 (21 functions) — file 08

| Function | Public? | IDs |
|---|---|---|
| Expand-ReshelfNamingTemplate | No | AS-CODE-PRP-001 |
| Get-ReshelfProposalPadWidth | No | AS-CODE-PRP-002 |
| Get-ReshelfLocalRomanizedTitle | No | AS-CODE-PRP-003–005 |
| Get-ReshelfBilingualArtistName | No | AS-CODE-PRP-006–010 |
| New-ReshelfProposedReleaseNames | No | AS-CODE-PRP-011–020 |
| Get-ReshelfDiscogsTitleAlignment | No | AS-CODE-PRP-021–023 |
| Get-ReshelfDiscogsNumberAlignment | No | AS-CODE-PRP-024–028 |
| Resolve-ReshelfDiscogsTrackAlignment | No | AS-CODE-PRP-029 |
| Get-ReshelfDiscogsPositionParts | No | AS-CODE-PRP-030–032 |
| New-ReshelfProposedTrackSet | No | AS-CODE-PRP-033–051 |
| Get-ReshelfImageDimensions | No | AS-CODE-PRP-052–053 (see AS-CODE-DEF-022) |
| New-ReshelfCoverArtProposal | No | AS-CODE-PRP-054–059 (see AS-CODE-DEF-022) |
| Test-ReshelfSameLossyRelease | No | AS-CODE-PRP-060 |
| Find-ReshelfPreviousLossyEntry | No | AS-CODE-PRP-061–063 (see AS-CODE-DEF-019) |
| Build-ReshelfTargetIndex | Yes | AS-CODE-PRP-064–066 |
| Test-ReshelfTargetReleaseExists | Yes | AS-CODE-PRP-067 |
| Resolve-ReshelfTargetComparison | No | AS-CODE-PRP-068–078 |
| New-ReshelfCompanionProposal | No | AS-CODE-PRP-079–081 |
| New-ReshelfProposedRelease | No | AS-CODE-PRP-082–089 |
| Update-ReshelfReleaseForDiscogsSelection | Yes | AS-CODE-PRP-090–096 (see AS-CODE-DEF-020, -021) |
| Invoke-ReshelfEditProposal | Yes | AS-CODE-PRP-097–104 |

## Reshelf.UiServer.psm1 (11 functions) + Start-ReshelfUiServer.ps1 + legacy/ui/* — file 09

| Function | Public? | IDs |
|---|---|---|
| Resolve-ReshelfUiRequestPath | Yes | AS-CODE-REV-001–005 |
| Get-ReshelfUiMimeType | Yes | AS-CODE-REV-006–007 |
| Get-ReshelfUiApiRoute | Yes | AS-CODE-REV-008–018 (see AS-CODE-DEF-029) |
| Get-ReshelfUiSessionsSummary | Yes | AS-CODE-REV-044 |
| Get-ReshelfUiCurrentSession | Yes | AS-CODE-REV-045 |
| Get-ReshelfUiProposalContent | No | covered indirectly via AS-CODE-REV-021 (route-level; the drafting agent documented its "no proposal.json yet" throw under the `GetProposal`/`CurrentSession` route entries rather than citing this helper by name — behavior is captured, function name is not) |
| Save-ReshelfUiProposalContent | Yes | AS-CODE-REV-022–024 |
| Get-ReshelfUiManualCoversDir | No | AS-CODE-REV-046 |
| Get-ReshelfUiLocalFileBytes | No | AS-CODE-REV-047–050 |
| Get-ReshelfUiImageDimensions | No | AS-CODE-REV-058 |
| Save-ReshelfUiManualCoverFile | No | AS-CODE-REV-051, 054–057 (see AS-CODE-DEF-023) |

`Start-ReshelfUiServer.ps1` local functions/routes: `Write-ReshelfUiJsonResponse` (AS-CODE-REV-068), `Write-ReshelfUiRawJsonResponse` (AS-CODE-REV-069), `Read-ReshelfUiRequestBody` (AS-CODE-REV-070), `Read-ReshelfUiRequestBodyBytes` (AS-CODE-REV-071–072), plus every dispatched API action (AS-CODE-REV-019–021, 025–043) and startup parameters (AS-CODE-REV-073–076). See AS-CODE-DEF-023, -024, -025, -026.

`legacy/ui/app.js`, `index.html`, `styles.css`: ~40 client-side behaviors covered under AS-CODE-REV-077–148 (session history, release editing, cover gallery, Discogs picker, lossy tracker, CSV/JSON export, CSS-driven states). See AS-CODE-DEF-027, -028.

## Reshelf.Implementation.psm1 (19 functions) — file 10

| Function | Public? | IDs |
|---|---|---|
| Get-ReshelfApplyLogPath | Yes | AS-CODE-APL-001 |
| Get-ReshelfApplyLog | Yes | AS-CODE-APL-002 |
| Get-ReshelfApplyLogEntry | Yes | AS-CODE-APL-003 |
| Add-ReshelfApplyLogEntry | Yes | AS-CODE-APL-004–005 |
| Test-ReshelfAppliedEntryValid | No | AS-CODE-APL-006 |
| Test-ReshelfReleaseNeedsApply | No | AS-CODE-APL-007–008 |
| ConvertTo-ReshelfFfmpegSeconds | No | AS-CODE-APL-009 |
| ConvertFrom-ReshelfCueTrackRanges | No | AS-CODE-APL-010 |
| Invoke-ReshelfFfmpegSplit | No | AS-CODE-APL-011–014 |
| Invoke-ReshelfFfmpegResize | No | AS-CODE-APL-015 |
| Invoke-ReshelfCoverDownload | No | AS-CODE-APL-016 |
| Set-ReshelfAudioTags | No | AS-CODE-APL-017–021 |
| Resolve-ReshelfCompanionTargetPath | No | AS-CODE-APL-022–023 (see AS-CODE-DEF-031) |
| Split-ReshelfTrackFileName | No | AS-CODE-APL-024 |
| Get-ReshelfRemainingPathBudget | No | AS-CODE-APL-025 |
| Resolve-ReshelfTruncatedReleaseNames | No | AS-CODE-APL-026–032 (see AS-CODE-DEF-031) |
| Invoke-ReshelfReleaseStaging | No | AS-CODE-APL-033–042 (see AS-CODE-DEF-030) |
| Move-ReshelfStagedReleaseToTarget | No | AS-CODE-APL-043–044 (see AS-CODE-DEF-030) |
| Invoke-ReshelfImplementation | Yes | AS-CODE-APL-045–055 |

## Reshelf.LossyTracking.psm1 (9 functions) — file 11

| Function | Public? | IDs |
|---|---|---|
| Get-ReshelfLossyTrackingLedgerPath | No | AS-CODE-LSY-001 |
| Get-ReshelfLossyTrackingLedger | Yes | AS-CODE-LSY-002 |
| Get-ReshelfLossyTrackingEntry | Yes | AS-CODE-LSY-003 |
| Add-ReshelfLossyTrackingEntry | Yes | AS-CODE-LSY-004–005, 013 |
| Set-ReshelfLossyTrackingUpgraded | Yes | AS-CODE-LSY-007 |
| Set-ReshelfLossyTrackingTargetPath | Yes | AS-CODE-LSY-008 |
| Set-ReshelfLossyTrackingIgnored | Yes | AS-CODE-LSY-009 |
| Set-ReshelfLossyTrackingStatus | Yes | AS-CODE-LSY-006, 010–011 |
| Remove-ReshelfLossyTrackingEntry | Yes | AS-CODE-LSY-012 |

Cross-cutting: AS-CODE-LSY-014 ("stable key not found" never throws) spans all five mutators above.

## Reshelf.ps1 (CLI dispatcher, no functions of its own) — file 12

Every `Command`/`SubCommand` combination, parameter, and the param block itself map to
AS-CODE-CLI-001–039. See AS-CODE-DEF-032, -033, -034.

## Cross-cutting (BND, ERR) — file 13

Not function-scoped by design: AS-CODE-BND-001–002 confirm (by grep) that Bandcamp has no real
implementation anywhere in `legacy/scripts/**` or `legacy/ui/**`. AS-CODE-ERR-001–005 describe
app-wide error-handling patterns (schema-validate-before-trust, `throw`/`Write-Warning` split, no
global `$ErrorActionPreference`, no shared retry helper, no central error log) that cut across every
module above rather than belonging to one of them.

## Totals

| File | Area(s) | IDs | Suspected defects |
|---|---|---|---|
| 01-data-and-storage.md | DAT | 38 | 2 |
| 02-text-and-naming.md | TXT | 26 | 2 |
| 03-settings-and-secrets.md | SET | 24 | 2 |
| 04-sessions.md | SES | 12 | 1 |
| 05-recognition.md | REC | 110 | 7 |
| 06-discogs-client.md | DSC | 32 | 2 |
| 07-proposal-matching.md | MAT | 67 | 2 |
| 08-proposal-naming-and-tags.md | PRP | 104 | 4 |
| 09-review-ui.md | REV | 148 | 7 |
| 10-apply.md | APL | 55 | 2 |
| 11-lossy-tracking.md | LSY | 14 | 0 |
| 12-cli.md | CLI | 39 | 3 |
| 13-bandcamp-and-errors.md | BND, ERR | 7 | 0 |

Total: **676** requirement IDs, **34** suspected defects (consolidated in [90-suspected-defects.md](90-suspected-defects.md)).

Every function found in the 9 owned PowerShell modules (140 functions total) maps to at least one
requirement ID, with one noted exception (`Get-ReshelfUiProposalContent`, covered indirectly — see the
Reshelf.UiServer.psm1 table above).

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-10 | Phase 2 merge: coverage built from the 13 area files' Source lines. |
