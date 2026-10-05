#Requires -Version 7.4

Import-Module Pester -MinimumVersion 5.0

BeforeAll {
    Import-Module "$PSScriptRoot/../scripts/common/Reshelf.Common.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Reshelf.Json.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Reshelf.Discogs.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Reshelf.LossyTracking.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Reshelf.EditProposal.psm1" -Force
    # Imported directly, after Reshelf.EditProposal.psm1 (which nests it internally to reach
    # Get-ReshelfApplyLogEntry) - same "import it again, last" fix already relied on above for
    # Common/Json/LossyTracking, restoring Add-ReshelfApplyLogEntry to this script's top-level scope
    # so the apply-log fixture helper below can call it directly.
    Import-Module "$PSScriptRoot/../scripts/common/Reshelf.Implementation.psm1" -Force

    $script:SearchFixture = Get-Content -LiteralPath "$PSScriptRoot/fixtures/discogs-responses/search-response.json" -Raw | ConvertFrom-Json
    $script:ReleaseFixture = Get-Content -LiteralPath "$PSScriptRoot/fixtures/discogs-responses/release-response.json" -Raw | ConvertFrom-Json

    # Reshelf.EditProposal.psm1 re-imports Common/Json internally as part of loading, which turns
    # them into nested modules of Reshelf.EditProposal - PowerShell then hides their commands from
    # this script's own top-level scope (order-dependent on what else has imported them). Routing
    # through EditProposal's own module scope, which always has them, avoids that fragility.
    function Get-TestStableKey {
        param(
            [Parameter(Mandatory)]
            [string]$Artist,

            [Parameter(Mandatory)]
            [string]$Album,

            [Nullable[int]]$Year
        )

        return InModuleScope Reshelf.EditProposal -Parameters @{ artistName = $Artist; albumName = $Album; releaseYear = $Year } {
            param($artistName, $albumName, $releaseYear)
            Get-ReshelfStableKey -Artist $artistName -Album $albumName -Year $releaseYear
        }
    }

    function Test-ProposalDocumentJson {
        param(
            [Parameter(Mandatory)]
            [string]$Path
        )

        return InModuleScope Reshelf.EditProposal -Parameters @{ jsonPath = $Path } {
            param($jsonPath)
            Test-ReshelfJson -SchemaName proposal -Path $jsonPath
        }
    }

    function Set-TestJsonFile {
        param(
            [Parameter(Mandatory)]
            [string]$Path,

            [Parameter(Mandatory)]
            [object]$InputObject,

            [Parameter(Mandatory)]
            [string]$SchemaName,

            [int]$Depth = 20
        )

        InModuleScope Reshelf.EditProposal -Parameters @{ p = $Path; o = $InputObject; s = $SchemaName; d = $Depth } {
            param($p, $o, $s, $d)
            Set-ReshelfJsonFile -Path $p -InputObject $o -SchemaName $s -Depth $d | Out-Null
        }
    }

    function Get-TestLossyTrackingEntry {
        param(
            [Parameter(Mandatory)]
            [string]$StableKey,

            [Parameter(Mandatory)]
            [string]$DataHome
        )

        return InModuleScope Reshelf.EditProposal -Parameters @{ k = $StableKey; dh = $DataHome } {
            param($k, $dh)
            Get-ReshelfLossyTrackingEntry -StableKey $k -DataHome $dh
        }
    }

    function Add-TestLossyTrackingEntry {
        param(
            [Parameter(Mandatory)]
            [string]$StableKey,

            [Parameter(Mandatory)]
            [string]$Artist,

            [Parameter(Mandatory)]
            [string]$Album,

            [Parameter(Mandatory)]
            [int]$Year,

            [Parameter(Mandatory)]
            [string]$TargetPath,

            [Parameter(Mandatory)]
            [string]$Format,

            [Parameter(Mandatory)]
            [string]$DataHome
        )

        InModuleScope Reshelf.EditProposal -Parameters @{ k = $StableKey; a = $Artist; al = $Album; y = $Year; tp = $TargetPath; f = $Format; dh = $DataHome } {
            param($k, $a, $al, $y, $tp, $f, $dh)
            Add-ReshelfLossyTrackingEntry -StableKey $k -Artist $a -Album $al -Year $y -TargetPath $tp -Format $f -DataHome $dh | Out-Null
        }
    }

    function New-TestAudioFile {
        param(
            [Parameter(Mandatory)]
            [string]$Path,

            [string]$Content = 'x'
        )

        $dir = Split-Path -Path $Path -Parent
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Set-Content -LiteralPath $Path -Value $Content -NoNewline
        return $Path
    }

    # A real, minimal 2x2 PNG (not 1x1 - Get-ReshelfImageDimensions' own "couldn't decode" sentinel
    # is 1x1, so a genuinely-decodable test fixture must be some other size to stay distinguishable
    # from that failure case).
    function New-TestImageFile {
        param(
            [Parameter(Mandatory)]
            [string]$Path
        )

        $dir = Split-Path -Path $Path -Parent
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $bytes = [Convert]::FromBase64String(
            'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAALSURBVBhXY2BABwAAEgABp3qZbgAAAABJRU5ErkJggg==')
        [System.IO.File]::WriteAllBytes($Path, $bytes)
        return $Path
    }

    # Writes a fake apply-log.json entry directly, standing in for a real 'Reshelf.ps1 apply' run -
    # used to test Resolve-ReshelfTargetComparison's re-run skip check (Reshelf.EditProposal.psm1)
    # without actually running Invoke-ReshelfImplementation.
    function Add-TestApplyLogEntry {
        param(
            [Parameter(Mandatory)] [string]$StableKey,
            [Parameter(Mandatory)] [string]$TargetPath,
            [Parameter(Mandatory)] [string]$SourceFileSetHash,
            [string]$Status = 'applied',
            [string]$DataHome = $script:dataHome
        )

        Add-ReshelfApplyLogEntry -StableKey $StableKey -AppliedAtUtc (Get-Date) -Status $Status -TargetPath $TargetPath `
            -SourceFileSetHash $SourceFileSetHash -ErrorMessage $null -Truncated $false -DataHome $DataHome | Out-Null
    }

    # Same name|size hash Get-ReshelfFileSetHash (Reshelf.Common.psm1) computes - kept private to that
    # module, so re-derived here via InModuleScope rather than exported just for this test file.
    function Get-TestFileSetHash {
        param([Parameter(Mandatory)] [string[]]$FilePaths)

        return InModuleScope Reshelf.EditProposal -Parameters @{ paths = $FilePaths } {
            param($paths)
            Get-ReshelfFileSetHash -FilePaths $paths
        }
    }

    function New-TestTrack {
        param(
            [Parameter(Mandatory)]
            [string]$SourceFilePath,

            [Parameter(Mandatory)]
            [string]$OriginalFileName,

            [string]$DiscFolder,
            [int]$DetectedTrackNumberInDisc = 1,
            [string]$ExistingArtist,
            [string]$ExistingAlbum,
            [string]$ExistingTitle,
            [string]$Format = 'flac',
            [bool]$IsLossless = $true,
            [double]$DurationSeconds = 200.0,
            [AllowNull()] $ExistingCoverArtPath = $null
        )

        [pscustomobject]@{
            sourceFilePath            = $SourceFilePath
            discFolder                = $DiscFolder
            originalFileName          = $OriginalFileName
            detectedTrackNumberInDisc = $DetectedTrackNumberInDisc
            inferredTrackOrder        = $false
            existingTags              = @{ artist = $ExistingArtist; album = $ExistingAlbum; title = $ExistingTitle }
            existingCoverArtPath      = $ExistingCoverArtPath
            format                    = $Format
            isLossless                = $IsLossless
            durationSeconds           = $DurationSeconds
            cueTimestamp              = $null
            isCueVirtualTrack         = $false
        }
    }

    function New-TestRelease {
        param(
            [Parameter(Mandatory)]
            [string]$StableKey,

            [Parameter(Mandatory)]
            [string]$RecognizedTitle,

            [Nullable[int]]$RecognizedYear,

            # Untyped (not [string]) - an unset [string] parameter defaults to '' in PowerShell, not
            # $null, which would fail the schema's pattern/enum check for these two nullable fields
            # on every existing test that doesn't pass them.
            $RecognizedReleaseDate = $null,

            $RecognizedReleaseType = $null,

            [Parameter(Mandatory)]
            [string]$SourceFolderPath,

            [int]$DiscFolderCount = 1,

            [Parameter(Mandatory)]
            [object[]]$Tracks,

            [object[]]$CompanionFiles = @(),

            [bool]$NeedsReview = $false,

            [string[]]$ReviewReasons = @()
        )

        [pscustomobject]@{
            stableKey             = $StableKey
            recognizedTitle       = $RecognizedTitle
            recognizedYear        = $RecognizedYear
            recognizedReleaseDate = $RecognizedReleaseDate
            recognizedReleaseType = $RecognizedReleaseType
            editionFolderName     = $null
            sourceFolderPath      = $SourceFolderPath
            discFolderCount       = $DiscFolderCount
            tracks                = $Tracks
            companionFiles        = $CompanionFiles
            ignoredFiles          = @()
            cueSheets             = @()
            recognitionConfidence = 1.0
            recognitionFlags      = @()
            needsReview           = $NeedsReview
            reviewReasons         = @($ReviewReasons)
        }
    }

    function New-TestRecognitionFile {
        param(
            [Parameter(Mandatory)]
            [string]$Path,

            [Parameter(Mandatory)]
            [string]$SessionId,

            [Parameter(Mandatory)]
            [string]$SourceRoot,

            [Parameter(Mandatory)]
            [object[]]$Artists
        )

        $doc = [pscustomobject]@{
            schemaVersion  = 1
            sessionId      = $SessionId
            sourceRoot     = $SourceRoot
            generatedAtUtc = '2026-09-19T10:00:00.000Z'
            artists        = $Artists
            unrecognized   = @()
        }

        Set-TestJsonFile -Path $Path -InputObject $doc -SchemaName recognition -Depth 20
    }
}

Describe 'Get-ReshelfProposalPadWidth (private)' {
    It 'returns 2 for track counts up to 99' {
        InModuleScope Reshelf.EditProposal {
            Get-ReshelfProposalPadWidth -TotalTrackCount 1 | Should -Be 2
            Get-ReshelfProposalPadWidth -TotalTrackCount 9 | Should -Be 2
            Get-ReshelfProposalPadWidth -TotalTrackCount 99 | Should -Be 2
        }
    }

    It 'grows beyond 2 for larger track counts' {
        InModuleScope Reshelf.EditProposal {
            Get-ReshelfProposalPadWidth -TotalTrackCount 100 | Should -Be 3
            Get-ReshelfProposalPadWidth -TotalTrackCount 999 | Should -Be 3
            Get-ReshelfProposalPadWidth -TotalTrackCount 1000 | Should -Be 4
        }
    }

    It 'uses -MinWidth as a floor, not a fixed value, when settings.trackNumberPadWidth is raised' {
        InModuleScope Reshelf.EditProposal {
            Get-ReshelfProposalPadWidth -TotalTrackCount 1 -MinWidth 3 | Should -Be 3
            Get-ReshelfProposalPadWidth -TotalTrackCount 9 -MinWidth 3 | Should -Be 3
            # A track count that already needs more digits than MinWidth still wins.
            Get-ReshelfProposalPadWidth -TotalTrackCount 1000 -MinWidth 3 | Should -Be 4
        }
    }
}

Describe 'Get-ReshelfStringSimilarity (private)' {
    It 'returns 1.0 for identical strings' {
        InModuleScope Reshelf.EditProposal {
            Get-ReshelfStringSimilarity -A 'radiohead' -B 'radiohead' | Should -Be 1.0
        }
    }

    It 'returns 1.0 when both sides are empty' {
        InModuleScope Reshelf.EditProposal {
            Get-ReshelfStringSimilarity -A '' -B '' | Should -Be 1.0
        }
    }

    It 'returns 0.0 when only one side is empty' {
        InModuleScope Reshelf.EditProposal {
            Get-ReshelfStringSimilarity -A '' -B 'radiohead' | Should -Be 0.0
        }
    }

    It 'scores a near match higher than an unrelated pair' {
        InModuleScope Reshelf.EditProposal {
            $near = Get-ReshelfStringSimilarity -A 'ok computer' -B 'ok computr'
            $unrelated = Get-ReshelfStringSimilarity -A 'ok computer' -B 'kid a'
            $near | Should -BeGreaterThan $unrelated
        }
    }
}

Describe 'Get-ReshelfDiscogsCandidateScore (private)' {
    It 'scores the correct artist/title/year at or above the match threshold' {
        InModuleScope Reshelf.EditProposal -Parameters @{ candidate = $script:SearchFixture.results[0] } {
            param($candidate)
            $score = Get-ReshelfDiscogsCandidateScore -ExpectedArtist 'Radiohead' -ExpectedTitle 'OK Computer' -ExpectedYear 1997 -Candidate $candidate
            $score | Should -BeGreaterOrEqual 0.85
        }
    }

    It 'scores an unrelated artist/title well below the threshold' {
        InModuleScope Reshelf.EditProposal -Parameters @{ candidate = $script:SearchFixture.results[0] } {
            param($candidate)
            $score = Get-ReshelfDiscogsCandidateScore -ExpectedArtist 'Some Totally Different Band' -ExpectedTitle 'Unrelated Album Title' -ExpectedYear $null -Candidate $candidate
            $score | Should -BeLessThan 0.85
        }
    }

    It 'scores a Discogs subtitle Discogs added but the source never has, at the threshold (real Piano Magic "Son De Mar" case, plan/12)' {
        InModuleScope Reshelf.EditProposal {
            $candidate = [pscustomobject]@{
                title = 'Piano Magic - Son De Mar (Music From The Film By Bigas Luna)'
                year  = '2001'
                format = @('CD', 'Mini-Album')
            }
            $score = Get-ReshelfDiscogsCandidateScore -ExpectedArtist 'Piano Magic' -ExpectedTitle 'Son De Mar' -ExpectedYear 2001 -Candidate $candidate
            $score | Should -BeGreaterOrEqual 0.85
        }
    }

    It 'scores a spacing-only title difference at the threshold (real Grails "Red Light"/"Redlight" case, plan/12)' {
        InModuleScope Reshelf.EditProposal {
            $candidate = [pscustomobject]@{ title = 'Grails - Redlight'; year = '2004'; format = @('CD', 'Album') }
            $score = Get-ReshelfDiscogsCandidateScore -ExpectedArtist 'Grails' -ExpectedTitle 'Red Light' -ExpectedYear 2004 -Candidate $candidate
            $score | Should -BeGreaterOrEqual 0.85
        }
    }

    It 'scores an exact-title compilation below the same album, but still at the threshold' {
        InModuleScope Reshelf.EditProposal {
            $album = [pscustomobject]@{ title = 'Some Band - Greatest Hits'; year = '2001'; format = @('CD', 'Album') }
            $compilation = [pscustomobject]@{ title = 'Some Band - Greatest Hits'; year = '2001'; format = @('CD', 'Compilation') }
            $albumScore = Get-ReshelfDiscogsCandidateScore -ExpectedArtist 'Some Band' -ExpectedTitle 'Greatest Hits' -ExpectedYear $null -Candidate $album
            $compilationScore = Get-ReshelfDiscogsCandidateScore -ExpectedArtist 'Some Band' -ExpectedTitle 'Greatest Hits' -ExpectedYear $null -Candidate $compilation
            $compilationScore | Should -BeLessThan $albumScore
            $compilationScore | Should -BeGreaterOrEqual 0.85
        }
    }

    It 'scores a fuzzy-title compilation below the threshold (real Aerosmith "Classic Aerosmith" case)' {
        InModuleScope Reshelf.EditProposal {
            $candidate = [pscustomobject]@{ title = 'Aerosmith - Classic Aerosmith'; year = '2000'; format = @('CD', 'Compilation', 'Remastered') }
            $score = Get-ReshelfDiscogsCandidateScore -ExpectedArtist 'Aerosmith' -ExpectedTitle 'Aerosmith' -ExpectedYear 1973 -Candidate $candidate
            $score | Should -BeLessThan 0.85
        }
    }

    It 'penalizes Box Set and Unofficial Release formats too' {
        InModuleScope Reshelf.EditProposal {
            $plain = [pscustomobject]@{ title = 'Some Band - Some Title'; year = '2001'; format = @('CD', 'Album') }
            $plainScore = Get-ReshelfDiscogsCandidateScore -ExpectedArtist 'Some Band' -ExpectedTitle 'Some Title' -ExpectedYear 2001 -Candidate $plain
            foreach ($formats in @(@('CD', 'Box Set'), @('CD', 'Unofficial Release'))) {
                $candidate = [pscustomobject]@{ title = 'Some Band - Some Title'; year = '2001'; format = $formats }
                $score = Get-ReshelfDiscogsCandidateScore -ExpectedArtist 'Some Band' -ExpectedTitle 'Some Title' -ExpectedYear 2001 -Candidate $candidate
                $score | Should -BeLessThan $plainScore
            }
        }
    }

    It 'scores a Japanese-only artist credit at the threshold when an artist alias is given (real Maximum The Hormone case, session 2026-10-03-0010)' {
        InModuleScope Reshelf.EditProposal {
            $candidate = [pscustomobject]@{ title = 'マキシマム ザ ホルモン* - Greatest The Hits 2011-2011'; year = '2011'; format = @('CD', 'Maxi-Single') }
            $withoutAlias = Get-ReshelfDiscogsCandidateScore -ExpectedArtist 'Maximum The Hormone' -ExpectedTitle 'Greatest The Hits 2011' -ExpectedYear 2011 -Candidate $candidate
            $withAlias = Get-ReshelfDiscogsCandidateScore -ExpectedArtist 'Maximum The Hormone' -ExpectedTitle 'Greatest The Hits 2011' -ExpectedYear 2011 -Candidate $candidate -ArtistAliases @('マキシマム ザ ホルモン')
            $withoutAlias | Should -BeLessThan 0.85
            $withAlias | Should -BeGreaterOrEqual 0.85
        }
    }

    It 'scores a Discogs "X = Y" title at the threshold by comparing against its romanized half (real Maximum The Hormone "Tsume Tsume Tsume''F" case)' {
        InModuleScope Reshelf.EditProposal {
            $candidate = [pscustomobject]@{
                title  = 'マキシマム ザ ホルモン* - Tsume Tsume Tsume / 「F」= 爪爪爪 / 「F」'
                year   = '2008'
                format = @('CD', 'Single')
            }
            $score = Get-ReshelfDiscogsCandidateScore -ExpectedArtist 'Maximum The Hormone' -ExpectedTitle "Tsume Tsume Tsume'F" -ExpectedYear 2008 -Candidate $candidate -ArtistAliases @('マキシマム ザ ホルモン')
            $score | Should -BeGreaterOrEqual 0.85
        }
    }
}

Describe 'Get-ReshelfDiscogsPlayableTracks (private)' {
    It 'flattens an index entry''s sub_tracks into individual playable tracks (real Guapo "Five Suns" case, plan/12)' {
        InModuleScope Reshelf.EditProposal {
            $tracklist = @(
                [pscustomobject]@{
                    position   = ''
                    type_      = 'index'
                    title      = 'Five Suns'
                    sub_tracks = @(
                        [pscustomobject]@{ position = '1'; title = 'Five Suns I' }
                        [pscustomobject]@{ position = '2'; title = 'Five Suns II' }
                        [pscustomobject]@{ position = '3'; title = 'Five Suns III' }
                        [pscustomobject]@{ position = '4'; title = 'Five Suns IV' }
                        [pscustomobject]@{ position = '5'; title = 'Five Suns V' }
                    )
                }
                [pscustomobject]@{ position = '6'; title = '(silence)' }
                [pscustomobject]@{ position = '7'; title = 'Mictlan' }
                [pscustomobject]@{ position = '8'; title = 'Topan' }
            )

            $playable = Get-ReshelfDiscogsPlayableTracks -Tracklist $tracklist
            $playable.Count | Should -Be 8
            $playable[0].title | Should -Be 'Five Suns I'
            $playable[7].title | Should -Be 'Topan'
        }
    }

    It 'skips headings and empty-position entries, and keeps a plain track with its own sub_tracks as one entry' {
        InModuleScope Reshelf.EditProposal {
            $tracklist = @(
                [pscustomobject]@{ position = ''; type_ = 'heading'; title = 'Disc 1' }
                [pscustomobject]@{
                    position   = '1'
                    type_      = 'track'
                    title      = 'A Song'
                    sub_tracks = @([pscustomobject]@{ position = ''; title = 'Part a' }, [pscustomobject]@{ position = ''; title = 'Part b' })
                }
                [pscustomobject]@{ position = '2'; title = 'Another Song' }
            )

            $playable = Get-ReshelfDiscogsPlayableTracks -Tracklist $tracklist
            $playable.Count | Should -Be 2
            $playable[0].title | Should -Be 'A Song'
        }
    }

    It 'gives an index entry''s own sub_tracks its per-track artists when a sub-track has none of its own' {
        InModuleScope Reshelf.EditProposal {
            $tracklist = @(
                [pscustomobject]@{
                    position   = ''
                    type_      = 'index'
                    title      = 'Five Suns'
                    artists    = @([pscustomobject]@{ name = 'Guapo'; join = '' })
                    sub_tracks = @(
                        [pscustomobject]@{ position = '1'; title = 'Five Suns I' }
                        [pscustomobject]@{ position = '2'; title = 'Five Suns II'; artists = @([pscustomobject]@{ name = 'Someone Else'; join = '' }) }
                    )
                }
            )

            $playable = Get-ReshelfDiscogsPlayableTracks -Tracklist $tracklist
            $playable[0].artists[0].name | Should -Be 'Guapo'
            $playable[1].artists[0].name | Should -Be 'Someone Else'
        }
    }
}

Describe 'Get-ReshelfDiscogsArtistCredit (private)' {
    It 'returns a single artist name unchanged' {
        InModuleScope Reshelf.EditProposal {
            Get-ReshelfDiscogsArtistCredit -Artists @([pscustomobject]@{ name = 'The Dubliners'; join = '' }) | Should -Be 'The Dubliners'
        }
    }

    It 'strips a Discogs disambiguation suffix' {
        InModuleScope Reshelf.EditProposal {
            Get-ReshelfDiscogsArtistCredit -Artists @([pscustomobject]@{ name = 'Genesis (2)'; join = '' }) | Should -Be 'Genesis'
        }
    }

    It 'joins two artists with the Discogs join text' {
        InModuleScope Reshelf.EditProposal {
            $artists = @(
                [pscustomobject]@{ name = 'Simon'; join = '&' }
                [pscustomobject]@{ name = 'Garfunkel'; join = '' }
            )
            Get-ReshelfDiscogsArtistCredit -Artists $artists | Should -Be 'Simon & Garfunkel'
        }
    }

    It 'joins with a comma when the join text is a comma' {
        InModuleScope Reshelf.EditProposal {
            $artists = @(
                [pscustomobject]@{ name = 'A'; join = ',' }
                [pscustomobject]@{ name = 'B'; join = '' }
            )
            Get-ReshelfDiscogsArtistCredit -Artists $artists | Should -Be 'A, B'
        }
    }

    It 'drops a featured artist that follows a feat. join, keeping only the main artist(s)' {
        InModuleScope Reshelf.EditProposal {
            $artists = @(
                [pscustomobject]@{ name = 'Jay-Z'; join = 'feat.' }
                [pscustomobject]@{ name = 'Alicia Keys'; join = '' }
            )
            Get-ReshelfDiscogsArtistCredit -Artists $artists | Should -Be 'Jay-Z'
        }
    }

    It 'uses name, not anv (the credited name variation)' {
        InModuleScope Reshelf.EditProposal {
            Get-ReshelfDiscogsArtistCredit -Artists @([pscustomobject]@{ name = 'Prince'; anv = 'The Artist'; join = '' }) | Should -Be 'Prince'
        }
    }

    It 'returns null for an empty or missing artists array' {
        InModuleScope Reshelf.EditProposal {
            Get-ReshelfDiscogsArtistCredit -Artists @() | Should -BeNullOrEmpty
            Get-ReshelfDiscogsArtistCredit -Artists $null | Should -BeNullOrEmpty
        }
    }
}

Describe 'Test-ReshelfIsCompilationArtist (private)' {
    It 'is true when Discogs'' matched release artist is "Various" (id 194)' {
        InModuleScope Reshelf.EditProposal {
            $match = [pscustomobject]@{ Status = 'matched'; Detail = [pscustomobject]@{ artists = @([pscustomobject]@{ name = 'Various'; id = 194 }) } }
            Test-ReshelfIsCompilationArtist -Match $match -ArtistName 'Various' | Should -Be $true
        }
    }

    It 'is false when Discogs matched a normal single artist' {
        InModuleScope Reshelf.EditProposal {
            $match = [pscustomobject]@{ Status = 'matched'; Detail = [pscustomobject]@{ artists = @([pscustomobject]@{ name = 'Metallica'; id = 1 }) } }
            Test-ReshelfIsCompilationArtist -Match $match -ArtistName 'Metallica' | Should -Be $false
        }
    }

    It 'falls back to the recognized folder/artist name ("Various" or "Various Artists") when Discogs did not match' {
        InModuleScope Reshelf.EditProposal {
            $match = [pscustomobject]@{ Status = 'not-found' }
            Test-ReshelfIsCompilationArtist -Match $match -ArtistName 'Various Artists' | Should -Be $true
            Test-ReshelfIsCompilationArtist -Match $match -ArtistName 'Some Band' | Should -Be $false
        }
    }
}

Describe 'Get-ReshelfVariousArtistsEvidence (private)' {
    # Real case (session 2026-10-03-0001): "DIO\1999 - Holy Dio" is a Various-Artists tribute - 18
    # tracks, 18 different tagged artists, none of them "DIO" - that a plain Discogs search on the
    # folder artist never finds.
    It 'looks like Various Artists when every track has a different tagged artist than the folder' {
        InModuleScope Reshelf.EditProposal {
            $tracks = @(
                [pscustomobject]@{ existingTags = @{ artist = 'Blind Guardian' }; originalFileName = "[01] Blind Guardian - Don't Talk To Stranger.mp3" }
                [pscustomobject]@{ existingTags = @{ artist = 'Primal Fear' }; originalFileName = '[02] Primal Fear - Kill The King.mp3' }
                [pscustomobject]@{ existingTags = @{ artist = 'Doro' }; originalFileName = '[03] Doro - Egypt.mp3' }
            )
            $result = Get-ReshelfVariousArtistsEvidence -Tracks $tracks -FolderArtistName 'DIO'
            $result.LooksLikeVarious | Should -Be $true
            $result.DistinctArtistCount | Should -Be 3
            $result.DifferingTrackCount | Should -Be 3
            $result.TrackArtists | Should -Be @('Blind Guardian', 'Primal Fear', 'Doro')
        }
    }

    It 'is false for a normal single-artist release (every track tagged with the folder artist)' {
        InModuleScope Reshelf.EditProposal {
            $tracks = @(
                [pscustomobject]@{ existingTags = @{ artist = 'Radiohead' }; originalFileName = '01 - Airbag.flac' }
                [pscustomobject]@{ existingTags = @{ artist = 'Radiohead' }; originalFileName = '02 - Paranoid Android.flac' }
                [pscustomobject]@{ existingTags = @{ artist = 'Radiohead' }; originalFileName = '03 - Subterranean Homesick Alien.flac' }
            )
            Get-ReshelfVariousArtistsEvidence -Tracks $tracks -FolderArtistName 'Radiohead' | Select-Object -ExpandProperty LooksLikeVarious | Should -Be $false
        }
    }

    It 'is false for a 2-artist split release (not enough distinct artists)' {
        InModuleScope Reshelf.EditProposal {
            $tracks = @(
                [pscustomobject]@{ existingTags = @{ artist = 'Band A' }; originalFileName = '01 - Song One.flac' }
                [pscustomobject]@{ existingTags = @{ artist = 'Band A' }; originalFileName = '02 - Song Two.flac' }
                [pscustomobject]@{ existingTags = @{ artist = 'Band B' }; originalFileName = '03 - Song Three.flac' }
            )
            Get-ReshelfVariousArtistsEvidence -Tracks $tracks -FolderArtistName 'Band A' | Select-Object -ExpandProperty LooksLikeVarious | Should -Be $false
        }
    }

    It 'treats a "feat." guest as the same artist as the main credit' {
        InModuleScope Reshelf.EditProposal {
            $tracks = @(
                [pscustomobject]@{ existingTags = @{ artist = 'Metallica' }; originalFileName = '01 - Enter Sandman.flac' }
                [pscustomobject]@{ existingTags = @{ artist = 'Metallica feat. Justin Bieber' }; originalFileName = '02 - Nothing Else Matters.flac' }
                [pscustomobject]@{ existingTags = @{ artist = 'Metallica' }; originalFileName = '03 - Enter Sandman.flac' }
            )
            Get-ReshelfVariousArtistsEvidence -Tracks $tracks -FolderArtistName 'Metallica' | Select-Object -ExpandProperty LooksLikeVarious | Should -Be $false
        }
    }

    It 'is false when the folder is already "Various"/"Various Artists" (no retry needed)' {
        InModuleScope Reshelf.EditProposal {
            $tracks = @(
                [pscustomobject]@{ existingTags = @{ artist = 'Band A' }; originalFileName = '01 - Song One.flac' }
                [pscustomobject]@{ existingTags = @{ artist = 'Band B' }; originalFileName = '02 - Song Two.flac' }
                [pscustomobject]@{ existingTags = @{ artist = 'Band C' }; originalFileName = '03 - Song Three.flac' }
            )
            Get-ReshelfVariousArtistsEvidence -Tracks $tracks -FolderArtistName 'Various' | Select-Object -ExpandProperty LooksLikeVarious | Should -Be $false
        }
    }

    It 'falls back to a consistent "Artist - Title" file name when no track has an Artist tag' {
        InModuleScope Reshelf.EditProposal {
            $tracks = @(
                [pscustomobject]@{ existingTags = @{ artist = $null }; originalFileName = '[01] Blind Guardian - Title One.mp3' }
                [pscustomobject]@{ existingTags = @{ artist = $null }; originalFileName = '[02] Primal Fear - Title Two.mp3' }
                [pscustomobject]@{ existingTags = @{ artist = $null }; originalFileName = '[03] Doro - Title Three.mp3' }
            )
            $result = Get-ReshelfVariousArtistsEvidence -Tracks $tracks -FolderArtistName 'DIO'
            $result.LooksLikeVarious | Should -Be $true
            $result.TrackArtists | Should -Be @('Blind Guardian', 'Primal Fear', 'Doro')
        }
    }

    It 'ignores file-name artists when not every track has one (inconsistent naming)' {
        InModuleScope Reshelf.EditProposal {
            $tracks = @(
                [pscustomobject]@{ existingTags = @{ artist = $null }; originalFileName = '[01] Blind Guardian - Title One.mp3' }
                [pscustomobject]@{ existingTags = @{ artist = $null }; originalFileName = '02 Title Two.mp3' }
                [pscustomobject]@{ existingTags = @{ artist = $null }; originalFileName = '03 Title Three.mp3' }
            )
            Get-ReshelfVariousArtistsEvidence -Tracks $tracks -FolderArtistName 'DIO' | Select-Object -ExpandProperty LooksLikeVarious | Should -Be $false
        }
    }
}

Describe 'Get-ReshelfDiscogsSearchTitleVariants (private)' {
    # Each case is a real one from plan/12 milestone 3's re-verification against the actual Discogs
    # API - a release_title search containing this "noise" returned zero results even for a release
    # that demonstrably exists; the cleaned variant found it.
    It 'strips a trailing parenthetical sub-title and dash, extracting no year (no digits inside)' {
        InModuleScope Reshelf.EditProposal {
            $result = Get-ReshelfDiscogsSearchTitleVariants -Title 'indigo rose - (progressive form)'
            $result.Titles | Should -Be @('indigo rose - (progressive form)', 'indigo rose')
            $result.YearHint | Should -BeNullOrEmpty
        }
    }

    It 'strips multiple trailing parenthetical groups and extracts a year hint from the first one' {
        InModuleScope Reshelf.EditProposal {
            $result = Get-ReshelfDiscogsSearchTitleVariants -Title 'Violator (1990) (ALFA ALCB-35) (1st Japan 1990)'
            $result.Titles | Should -Be @('Violator (1990) (ALFA ALCB-35) (1st Japan 1990)', 'Violator')
            $result.YearHint | Should -Be 1990
        }
    }

    It 'strips a parenthetical group containing an internal dash' {
        InModuleScope Reshelf.EditProposal {
            $result = Get-ReshelfDiscogsSearchTitleVariants -Title '3218 (Soldier of Fortune Edition - Artwork)'
            $result.Titles | Should -Be @('3218 (Soldier of Fortune Edition - Artwork)', '3218')
        }
    }

    It 'strips a trailing edition word with no parentheses involved' {
        InModuleScope Reshelf.EditProposal {
            $result = Get-ReshelfDiscogsSearchTitleVariants -Title 'Forwards Special Edition'
            $result.Titles | Should -Be @('Forwards Special Edition', 'Forwards')
        }
    }

    It 'returns just one variant when there is nothing to clean' {
        InModuleScope Reshelf.EditProposal {
            $result = Get-ReshelfDiscogsSearchTitleVariants -Title 'OK Computer'
            $result.Titles | Should -Be @('OK Computer')
            $result.YearHint | Should -BeNullOrEmpty
        }
    }
}

Describe 'Get-ReshelfDiscogsFormatPreferenceRank (private)' {
    It 'ranks Album lowest (most preferred), then EP, Single, Promo, then everything else' {
        InModuleScope Reshelf.EditProposal {
            (Get-ReshelfDiscogsFormatPreferenceRank -FormatText 'CD, Album') | Should -Be 0
            (Get-ReshelfDiscogsFormatPreferenceRank -FormatText 'Vinyl, EP') | Should -Be 1
            (Get-ReshelfDiscogsFormatPreferenceRank -FormatText 'Vinyl, 7", 45 RPM, Single') | Should -Be 2
            (Get-ReshelfDiscogsFormatPreferenceRank -FormatText 'CDr, Promo') | Should -Be 3
            (Get-ReshelfDiscogsFormatPreferenceRank -FormatText 'Cassette') | Should -Be 4
        }
    }
}

Describe 'Resolve-ReshelfDiscogsTrackAlignment (private)' {
    It 'aligns every source track to its own Discogs track by title and notes the one Discogs has extra' {
        InModuleScope Reshelf.EditProposal {
            $sourceTracks = @(
                [pscustomobject]@{ existingTags = @{ title = $null }; originalFileName = '01 - Indigo Rose.flac' }
                [pscustomobject]@{ existingTags = @{ title = $null }; originalFileName = '02 - Sun.flac' }
            )
            $discogsTracks = @(
                [pscustomobject]@{ position = '1'; title = 'Cover Your Ears' }
                [pscustomobject]@{ position = '2'; title = 'Indigo Rose' }
                [pscustomobject]@{ position = '3'; title = 'Sun' }
            )

            $result = Resolve-ReshelfDiscogsTrackAlignment -SourceTracks $sourceTracks -DiscogsTracks $discogsTracks

            $result.Aligned | Should -Be $true
            $result.Tracks[0].title | Should -Be 'Indigo Rose'
            $result.Tracks[1].title | Should -Be 'Sun'
            $result.Indices | Should -Be @(2, 3)
            $result.MissingNote | Should -Be 'missing on source: 1 Cover Your Ears'
        }
    }

    It 'does not align when a source track has no good match (score below 0.8)' {
        InModuleScope Reshelf.EditProposal {
            $sourceTracks = @(
                [pscustomobject]@{ existingTags = @{ title = $null }; originalFileName = '01 - Completely Unrelated Name.flac' }
            )
            $discogsTracks = @(
                [pscustomobject]@{ position = '1'; title = 'Airbag' }
                [pscustomobject]@{ position = '2'; title = 'Paranoid Android' }
            )

            $result = Resolve-ReshelfDiscogsTrackAlignment -SourceTracks $sourceTracks -DiscogsTracks $discogsTracks

            $result.Aligned | Should -Be $false
            $result.Tracks.Count | Should -Be 0
        }
    }

    It 'falls back to track-number alignment when titles do not match well enough (real OOIOO "Feather Float" case, plan/12)' {
        InModuleScope Reshelf.EditProposal {
            # The source is missing track 7 ("Asozan") and several remaining file names carry a
            # differently-transliterated title ("(Kanji)") that title-similarity can't match - but
            # every source file's own detected track number still lines up with its true Discogs
            # position, so number-based pairing succeeds where title-based pairing (8/10 would-be
            # matches, 2 below 0.8) does not.
            $sourceTracks = @(
                [pscustomobject]@{ existingTags = @{ title = $null }; originalFileName = '01 Be Sure To Loop.mp3'; discFolder = $null; inferredTrackOrder = $false; detectedTrackNumberInDisc = 1 }
                [pscustomobject]@{ existingTags = @{ title = $null }; originalFileName = '02 Oizumio.mp3'; discFolder = $null; inferredTrackOrder = $false; detectedTrackNumberInDisc = 2 }
                [pscustomobject]@{ existingTags = @{ title = $null }; originalFileName = '03 Ina (Kanji).mp3'; discFolder = $null; inferredTrackOrder = $false; detectedTrackNumberInDisc = 3 }
                [pscustomobject]@{ existingTags = @{ title = $null }; originalFileName = '04 Ah Yeah.mp3'; discFolder = $null; inferredTrackOrder = $false; detectedTrackNumberInDisc = 4 }
                [pscustomobject]@{ existingTags = @{ title = $null }; originalFileName = '05 Switch On.mp3'; discFolder = $null; inferredTrackOrder = $false; detectedTrackNumberInDisc = 5 }
                [pscustomobject]@{ existingTags = @{ title = $null }; originalFileName = "06 Jackson's Club sunspot.mp3"; discFolder = $null; inferredTrackOrder = $false; detectedTrackNumberInDisc = 6 }
                [pscustomobject]@{ existingTags = @{ title = $null }; originalFileName = '08 Baby Bamboo From Nose.mp3'; discFolder = $null; inferredTrackOrder = $false; detectedTrackNumberInDisc = 8 }
                [pscustomobject]@{ existingTags = @{ title = $null }; originalFileName = '09 1000 Frogs And 3 Sun In A House.mp3'; discFolder = $null; inferredTrackOrder = $false; detectedTrackNumberInDisc = 9 }
                [pscustomobject]@{ existingTags = @{ title = $null }; originalFileName = '10 Ring Ring Lee.mp3'; discFolder = $null; inferredTrackOrder = $false; detectedTrackNumberInDisc = 10 }
                [pscustomobject]@{ existingTags = @{ title = $null }; originalFileName = '11 Kanji Ooioo.mp3'; discFolder = $null; inferredTrackOrder = $false; detectedTrackNumberInDisc = 11 }
            )
            $discogsTracks = @(
                [pscustomobject]@{ position = '1'; title = 'Be Sure To Loop' }
                [pscustomobject]@{ position = '2'; title = 'Oizumio' }
                [pscustomobject]@{ position = '3'; title = 'Ina 咲くの唄' }
                [pscustomobject]@{ position = '4'; title = 'Ah Yeah!' }
                [pscustomobject]@{ position = '5'; title = 'Switch On' }
                [pscustomobject]@{ position = '6'; title = 'Jackson''s Club "Sunspot"' }
                [pscustomobject]@{ position = '7'; title = 'Asozan' }
                [pscustomobject]@{ position = '8'; title = 'Baby Bamboo From Nose' }
                [pscustomobject]@{ position = '9'; title = '1000 Frogs And 3 Sun In A House' }
                [pscustomobject]@{ position = '10'; title = 'Ring Ring Lee' }
                [pscustomobject]@{ position = '11'; title = 'ハッピピピ OOIOO' }
            )

            $result = Resolve-ReshelfDiscogsTrackAlignment -SourceTracks $sourceTracks -DiscogsTracks $discogsTracks

            $result.Aligned | Should -Be $true
            $result.Method | Should -Be 'number'
            $result.Tracks.Count | Should -Be 10
            $result.Indices | Should -Be @(1, 2, 3, 4, 5, 6, 8, 9, 10, 11)
            $result.MissingNote | Should -Be 'missing on source: 7 Asozan'
        }
    }

    It 'does not use number alignment across a multi-disc release' {
        InModuleScope Reshelf.EditProposal {
            $sourceTracks = @(
                [pscustomobject]@{ existingTags = @{ title = $null }; originalFileName = '01 - Nothing Alike.flac'; discFolder = 'CD1'; inferredTrackOrder = $false; detectedTrackNumberInDisc = 1 }
            )
            $discogsTracks = @(
                [pscustomobject]@{ position = '1'; title = 'Totally Different Title' }
                [pscustomobject]@{ position = '2'; title = 'Another One' }
            )

            $result = Resolve-ReshelfDiscogsTrackAlignment -SourceTracks $sourceTracks -DiscogsTracks $discogsTracks

            $result.Aligned | Should -Be $false
        }
    }

    It 'does not reuse the same Discogs track for two different source tracks' {
        InModuleScope Reshelf.EditProposal {
            $sourceTracks = @(
                [pscustomobject]@{ existingTags = @{ title = $null }; originalFileName = '01 - Airbag.flac' }
                [pscustomobject]@{ existingTags = @{ title = $null }; originalFileName = '02 - Some Other Song.flac' }
            )
            $discogsTracks = @(
                [pscustomobject]@{ position = '1'; title = 'Airbag' }
            )

            $result = Resolve-ReshelfDiscogsTrackAlignment -SourceTracks $sourceTracks -DiscogsTracks $discogsTracks

            $result.Aligned | Should -Be $false
        }
    }
}

Describe 'Get-ReshelfDiscogsPositionParts (private)' {
    It 'parses disc-track positions' {
        InModuleScope Reshelf.EditProposal {
            $p = Get-ReshelfDiscogsPositionParts -Position '1-3'
            $p.Disc | Should -Be 1; $p.Track | Should -Be 3
            $p = Get-ReshelfDiscogsPositionParts -Position 'CD2-1'
            $p.Disc | Should -Be 2; $p.Track | Should -Be 1
            $p = Get-ReshelfDiscogsPositionParts -Position '2.05'
            $p.Disc | Should -Be 2; $p.Track | Should -Be 5
        }
    }

    It 'parses a plain number as a track with no disc' {
        InModuleScope Reshelf.EditProposal {
            $p = Get-ReshelfDiscogsPositionParts -Position '7'
            $p.Disc | Should -BeNullOrEmpty; $p.Track | Should -Be 7
        }
    }

    It 'returns nothing usable for vinyl sides or empty input' {
        InModuleScope Reshelf.EditProposal {
            foreach ($position in @('A1', 'B2', '', $null)) {
                $p = Get-ReshelfDiscogsPositionParts -Position $position
                $p.Disc | Should -BeNullOrEmpty; $p.Track | Should -BeNullOrEmpty
            }
        }
    }
}

Describe 'New-ReshelfProposedTrackSet (private) - real track positions' {
    BeforeAll {
        $script:TestNames = [pscustomobject]@{ Artist = 'Some Artist'; Album = 'Some Album'; Year = 2002 }

        function New-NumberingTestTrack {
            param(
                [string]$FileName,
                [Nullable[int]]$Number,
                [string]$DiscFolder = $null,
                [bool]$Inferred = $false,
                [string]$ExistingArtist = $null
            )
            [pscustomobject]@{
                originalFileName          = $FileName
                discFolder                = if ($DiscFolder) { $DiscFolder } else { $null }
                detectedTrackNumberInDisc = $Number
                inferredTrackOrder        = $Inferred
                existingTags              = [pscustomobject]@{ artist = $ExistingArtist; album = $null; title = $null }
                format                    = 'mp3'
            }
        }
    }

    It 'keeps a missing first track as a gap in file names and tags when Discogs is aligned' {
        $tracks = @(
            (New-NumberingTestTrack -FileName '02 - dear people.mp3' -Number 2)
            (New-NumberingTestTrack -FileName '03 - hope.mp3' -Number 3)
        )
        $discogs = @(
            [pscustomobject]@{ position = '1'; title = 'Cover Your Ears' }
            [pscustomobject]@{ position = '2'; title = 'Dear People' }
            [pscustomobject]@{ position = '3'; title = 'Hope' }
        )
        InModuleScope Reshelf.EditProposal -Parameters @{ tracks = $tracks; discogs = $discogs; names = $script:TestNames } {
            param($tracks, $discogs, $names)
            $set = New-ReshelfProposedTrackSet -Tracks $tracks -DiscogsTracks $discogs -DiscogsIndices @(2, 3) -Names $names -TrackFileTemplate '{trackNumber} {title}'
            $set.Tracks.proposedFileName | Should -Be @('02 Dear People.mp3', '03 Hope.mp3')
            $set.Tracks.tags.track | Should -Be @(2, 3)
            $set.Tracks.proposedTrackNumber | Should -Be @(2, 3)
            $set.Notes.Count | Should -Be 0
        }
    }

    It 'uses a vinyl-style tracklist index for a single-disc release' {
        $tracks = @(
            (New-NumberingTestTrack -FileName '01 - a.mp3' -Number 1)
            (New-NumberingTestTrack -FileName '03 - c.mp3' -Number 3)
        )
        $discogs = @(
            [pscustomobject]@{ position = 'A1'; title = 'A' }
            [pscustomobject]@{ position = 'A2'; title = 'B' }
            [pscustomobject]@{ position = 'B1'; title = 'C' }
        )
        InModuleScope Reshelf.EditProposal -Parameters @{ tracks = $tracks; discogs = $discogs; names = $script:TestNames } {
            param($tracks, $discogs, $names)
            $set = New-ReshelfProposedTrackSet -Tracks $tracks -DiscogsTracks $discogs -DiscogsIndices @(1, 3) -Names $names -TrackFileTemplate '{trackNumber} {title}'
            $set.Tracks.proposedFileName | Should -Be @('01 A.mp3', '03 C.mp3')
            $set.Tracks.tags.track | Should -Be @(1, 3)
        }
    }

    It 'uses source file numbers when there is no Discogs data, keeping a gap in the middle' {
        $tracks = @(
            (New-NumberingTestTrack -FileName '04 - four.mp3' -Number 4)
            (New-NumberingTestTrack -FileName '06 - six.mp3' -Number 6)
        )
        InModuleScope Reshelf.EditProposal -Parameters @{ tracks = $tracks; names = $script:TestNames } {
            param($tracks, $names)
            $set = New-ReshelfProposedTrackSet -Tracks $tracks -DiscogsTracks @() -Names $names -TrackFileTemplate '{trackNumber} {title}'
            $set.Tracks.proposedFileName | Should -Be @('04 Four.mp3', '06 Six.mp3')
            $set.Tracks.tags.track | Should -Be @(4, 6)
        }
    }

    It 'uses Discogs disc-track positions on a multi-disc release, with the file number from the full tracklist' {
        $tracks = @(
            (New-NumberingTestTrack -FileName '01 - a.mp3' -Number 1 -DiscFolder 'CD 1')
            (New-NumberingTestTrack -FileName '02 - b.mp3' -Number 2 -DiscFolder 'CD 1')
            (New-NumberingTestTrack -FileName '01 - d.mp3' -Number 1 -DiscFolder 'CD 2')
        )
        # Disc 1's last track ("C") is missing from the source - only Discogs knows disc 1 has 3.
        $discogs = @(
            [pscustomobject]@{ position = '1-1'; title = 'A' }
            [pscustomobject]@{ position = '1-2'; title = 'B' }
            [pscustomobject]@{ position = '1-3'; title = 'C' }
            [pscustomobject]@{ position = '2-1'; title = 'D' }
        )
        InModuleScope Reshelf.EditProposal -Parameters @{ tracks = $tracks; discogs = $discogs; names = $script:TestNames } {
            param($tracks, $discogs, $names)
            $set = New-ReshelfProposedTrackSet -Tracks $tracks -DiscogsTracks $discogs -DiscogsIndices @(1, 2, 4) -Names $names -TrackFileTemplate '{trackNumber} {title}'
            $set.Tracks.proposedFileName | Should -Be @('01 A.mp3', '02 B.mp3', '04 D.mp3')
            $set.Tracks.tags.discNumber | Should -Be @(1, 1, 2)
            $set.Tracks.tags.track | Should -Be @(1, 2, 1)
        }
    }

    It 'offsets a later disc by the highest track number of earlier discs without Discogs data' {
        $tracks = @(
            (New-NumberingTestTrack -FileName '01 - a.mp3' -Number 1 -DiscFolder 'CD 1')
            (New-NumberingTestTrack -FileName '03 - c.mp3' -Number 3 -DiscFolder 'CD 1')
            (New-NumberingTestTrack -FileName '02 - e.mp3' -Number 2 -DiscFolder 'CD 2')
        )
        InModuleScope Reshelf.EditProposal -Parameters @{ tracks = $tracks; names = $script:TestNames } {
            param($tracks, $names)
            $set = New-ReshelfProposedTrackSet -Tracks $tracks -DiscogsTracks @() -Names $names -TrackFileTemplate '{trackNumber} {title}'
            $set.Tracks.proposedFileName | Should -Be @('01 A.mp3', '03 C.mp3', '05 E.mp3')
            $set.Tracks.tags.track | Should -Be @(1, 3, 2)
        }
    }

    It 'restarts Track at 1 on a later disc whose source files are numbered continuously' {
        $tracks = @(
            (New-NumberingTestTrack -FileName '01 - a.mp3' -Number 1 -DiscFolder 'CD 1')
            (New-NumberingTestTrack -FileName '02 - b.mp3' -Number 2 -DiscFolder 'CD 1')
            (New-NumberingTestTrack -FileName '03 - c.mp3' -Number 3 -DiscFolder 'CD 2')
            (New-NumberingTestTrack -FileName '04 - d.mp3' -Number 4 -DiscFolder 'CD 2')
        )
        InModuleScope Reshelf.EditProposal -Parameters @{ tracks = $tracks; names = $script:TestNames } {
            param($tracks, $names)
            $set = New-ReshelfProposedTrackSet -Tracks $tracks -DiscogsTracks @() -Names $names -TrackFileTemplate '{trackNumber} {title}'
            $set.Tracks.proposedFileName | Should -Be @('01 A.mp3', '02 B.mp3', '03 C.mp3', '04 D.mp3')
            $set.Tracks.tags.track | Should -Be @(1, 2, 1, 2)
        }
    }

    It 'renumbers a disc sequentially and adds a note when source file numbers repeat' {
        $tracks = @(
            (New-NumberingTestTrack -FileName '01 - a.mp3' -Number 1)
            (New-NumberingTestTrack -FileName '01 - b.mp3' -Number 1)
        )
        InModuleScope Reshelf.EditProposal -Parameters @{ tracks = $tracks; names = $script:TestNames } {
            param($tracks, $names)
            $set = New-ReshelfProposedTrackSet -Tracks $tracks -DiscogsTracks @() -Names $names -TrackFileTemplate '{trackNumber} {title}'
            $set.Tracks.proposedFileName | Should -Be @('01 A.mp3', '02 B.mp3')
            $set.Tracks.tags.track | Should -Be @(1, 2)
            $set.Notes | Should -Be @('track numbers from source file names are not unique on disc 1; renumbered sequentially')
        }
    }

    It 'numbers sequentially, with no note, when the track order was inferred (no numbers in file names)' {
        $tracks = @(
            (New-NumberingTestTrack -FileName 'a.mp3' -Number 1 -Inferred $true)
            (New-NumberingTestTrack -FileName 'b.mp3' -Number 2 -Inferred $true)
        )
        InModuleScope Reshelf.EditProposal -Parameters @{ tracks = $tracks; names = $script:TestNames } {
            param($tracks, $names)
            $set = New-ReshelfProposedTrackSet -Tracks $tracks -DiscogsTracks @() -Names $names -TrackFileTemplate '{trackNumber} {title}'
            $set.Tracks.proposedFileName | Should -Be @('01 A.mp3', '02 B.mp3')
            $set.Notes.Count | Should -Be 0
        }
    }

    Context 'per-track Artist selection (compilations and split releases)' {
        BeforeAll {
            $script:CompilationNames = [pscustomobject]@{ Artist = 'Various'; Album = 'Some Compilation'; Year = 2008; IsCompilation = $true }
        }

        It 'uses the Discogs per-track artist credit when a track has one, even on a non-compilation release (split releases)' {
            $tracks = @(
                (New-NumberingTestTrack -FileName '01 - a.mp3' -Number 1)
            )
            $discogs = @(
                [pscustomobject]@{ position = '1'; title = 'A Song'; artists = @([pscustomobject]@{ name = 'The Dubliners'; join = '' }) }
            )
            InModuleScope Reshelf.EditProposal -Parameters @{ tracks = $tracks; discogs = $discogs; names = $script:TestNames } {
                param($tracks, $discogs, $names)
                $set = New-ReshelfProposedTrackSet -Tracks $tracks -DiscogsTracks $discogs -Names $names -TrackFileTemplate '{trackNumber} {title}'
                $set.Tracks[0].tags.artist | Should -Be 'The Dubliners'
                $set.Tracks[0].tags.albumArtist | Should -Be $names.Artist
                $set.Tracks[0].tags.isCompilation | Should -Be $false
            }
        }

        It 'falls back to the file''s existing Artist tag on a compilation when Discogs has no per-track credit' {
            $tracks = @(
                (New-NumberingTestTrack -FileName '01 - a.mp3' -Number 1 -ExistingArtist 'johnny mcevoy')
            )
            $discogs = @(
                [pscustomobject]@{ position = '1'; title = 'A Song' }
            )
            InModuleScope Reshelf.EditProposal -Parameters @{ tracks = $tracks; discogs = $discogs; names = $script:CompilationNames } {
                param($tracks, $discogs, $names)
                $set = New-ReshelfProposedTrackSet -Tracks $tracks -DiscogsTracks $discogs -Names $names -TrackFileTemplate '{trackNumber} {title}'
                $set.Tracks[0].tags.artist | Should -Be 'Johnny Mcevoy'
                $set.Tracks[0].tags.albumArtist | Should -Be 'Various'
                $set.Tracks[0].tags.isCompilation | Should -Be $true
            }
        }

        It 'falls back to Album Artist and adds a review note on a compilation with neither a Discogs nor a file artist' {
            $tracks = @(
                (New-NumberingTestTrack -FileName '01 - a.mp3' -Number 1)
            )
            InModuleScope Reshelf.EditProposal -Parameters @{ tracks = $tracks; names = $script:CompilationNames } {
                param($tracks, $names)
                $set = New-ReshelfProposedTrackSet -Tracks $tracks -DiscogsTracks @() -Names $names -TrackFileTemplate '{trackNumber} {title}'
                $set.Tracks[0].tags.artist | Should -Be 'Various'
                $set.Notes | Should -Match 'no track artist from Discogs or file tags'
            }
        }

        It 'falls back to the file-name artist on a compilation with no tags at all, and uses the title part as the title (real "Holy Dio" case)' {
            $tracks = @(
                (New-NumberingTestTrack -FileName "[01] Blind Guardian - Don't Talk To Stranger.mp3" -Number 1)
            )
            InModuleScope Reshelf.EditProposal -Parameters @{ tracks = $tracks; names = $script:CompilationNames } {
                param($tracks, $names)
                $set = New-ReshelfProposedTrackSet -Tracks $tracks -DiscogsTracks @() -Names $names -TrackFileTemplate '{trackNumber} {title}' `
                    -FileNameArtists @('Blind Guardian')
                $set.Tracks[0].tags.artist | Should -Be 'Blind Guardian'
                $set.Tracks[0].tags.albumArtist | Should -Be 'Various'
                $set.Tracks[0].proposedTitle | Should -Be "Don't Talk To Stranger"
                $set.Notes | Should -Not -Match 'no track artist from Discogs or file tags'
            }
        }

        It 'keeps today''s behavior on a non-compilation release with no Discogs per-track artist' {
            $tracks = @(
                (New-NumberingTestTrack -FileName '01 - a.mp3' -Number 1 -ExistingArtist 'Some Other Name')
            )
            InModuleScope Reshelf.EditProposal -Parameters @{ tracks = $tracks; names = $script:TestNames } {
                param($tracks, $names)
                $set = New-ReshelfProposedTrackSet -Tracks $tracks -DiscogsTracks @() -Names $names -TrackFileTemplate '{trackNumber} {title}'
                $set.Tracks[0].tags.artist | Should -Be $names.Artist
                $set.Tracks[0].tags.isCompilation | Should -Be $false
            }
        }
    }
}

Describe 'Test-ReshelfSameLossyRelease (private)' {
    It 'matches when the old name is a noisier version of the new one (real "Forwards Special Edition" case)' {
        InModuleScope Reshelf.EditProposal {
            Test-ReshelfSameLossyRelease -OldAlbum 'Forwards Special Edition' -NewAlbum 'Forwards' | Should -Be $true
        }
    }

    It 'matches identical names' {
        InModuleScope Reshelf.EditProposal {
            Test-ReshelfSameLossyRelease -OldAlbum 'Some Album' -NewAlbum 'Some Album' | Should -Be $true
        }
    }

    It 'does not match genuinely unrelated names' {
        InModuleScope Reshelf.EditProposal {
            Test-ReshelfSameLossyRelease -OldAlbum 'Some Album' -NewAlbum 'A Totally Different Album' | Should -Be $false
        }
    }
}

Describe 'Resolve-ReshelfDiscogsMatch (private)' {
    BeforeEach {
        $script:dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    }

    It 'returns matched with fetched detail when the top score is above the threshold' {
        Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
            if ($Path -eq '/database/search') { return $script:SearchFixture }
            return $script:ReleaseFixture
        }

        $result = InModuleScope Reshelf.EditProposal -Parameters @{ dataHome = $script:dataHome } {
            param($dataHome)
            Resolve-ReshelfDiscogsMatch -ArtistName 'Radiohead' -Title 'OK Computer' -Year 1997 -DataHome $dataHome
        }

        $result.Status | Should -Be 'matched'
        $result.SelectedReleaseId | Should -Be 265498
        $result.Detail.title | Should -Be 'OK Computer'
        $result.Candidates.Count | Should -BeGreaterThan 0
    }

    It 'returns ambiguous with candidates but no detail fetch when the top score is below the threshold' {
        Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
            if ($Path -eq '/database/search') { return $script:SearchFixture }
            throw 'detail should not be fetched for an ambiguous match'
        }

        $result = InModuleScope Reshelf.EditProposal -Parameters @{ dataHome = $script:dataHome } {
            param($dataHome)
            Resolve-ReshelfDiscogsMatch -ArtistName 'Some Totally Different Band' -Title 'Unrelated Album' -Year $null -DataHome $dataHome
        }

        $result.Status | Should -Be 'ambiguous'
        $result.SelectedReleaseId | Should -BeNullOrEmpty
        $result.Detail | Should -BeNullOrEmpty
        $result.Candidates.Count | Should -BeGreaterThan 0
    }

    It 'returns not-found when the search yields zero results' {
        Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
            [pscustomobject]@{ results = @() }
        }

        $result = InModuleScope Reshelf.EditProposal -Parameters @{ dataHome = $script:dataHome } {
            param($dataHome)
            Resolve-ReshelfDiscogsMatch -ArtistName 'Radiohead' -Title 'OK Computer' -Year 1997 -DataHome $dataHome
        }

        $result.Status | Should -Be 'not-found'
    }

    It 'skips the artist-master-list fallback for "Various" (its master list runs into the thousands)' {
        $calls = [System.Collections.Generic.List[object]]::new()
        Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
            $calls.Add([pscustomobject]@{ Path = $Path; Query = $Query })
            [pscustomobject]@{ results = @() }
        }

        $result = InModuleScope Reshelf.EditProposal -Parameters @{ dataHome = $script:dataHome } {
            param($dataHome)
            Resolve-ReshelfDiscogsMatch -ArtistName 'Various' -Title 'Holy Dio' -Year 1999 -DataHome $dataHome
        }

        $result.Status | Should -Be 'not-found'
        # Only the per-title-variant/year master searches (at most 4 here, since both the title and
        # its year attempt are tried) - never the paged artist-master-list ('per_page' query key).
        ($calls | Where-Object { $_.Query.ContainsKey('per_page') }).Count | Should -Be 0
    }

    It 'catches a network failure and returns not-found with an error note instead of throwing' {
        Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
            throw 'network is down'
        }

        $result = InModuleScope Reshelf.EditProposal -Parameters @{ dataHome = $script:dataHome } {
            param($dataHome)
            Resolve-ReshelfDiscogsMatch -ArtistName 'Radiohead' -Title 'OK Computer' -Year 1997 -DataHome $dataHome
        }

        $result.Status | Should -Be 'not-found'
        $result.ErrorNote | Should -BeLike '*network is down*'
    }

    It 'falls back to the cleaned title variant when the raw title finds nothing (real "Forwards Special Edition" case)' {
        $eggSearch = [pscustomobject]@{
            results = @([pscustomobject]@{ id = 42; type = 'release'; title = 'The Egg - Forwards'; year = '2004'; format = @('CD', 'Album') })
        }
        $eggDetail = [pscustomobject]@{
            id = 42; title = 'Forwards'; year = 2004; artists = @([pscustomobject]@{ name = 'The Egg' })
            formats = @([pscustomobject]@{ name = 'CD'; descriptions = @('Album') }); images = @(); tracklist = @()
        }

        $calls = [System.Collections.Generic.List[object]]::new()
        Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
            $calls.Add([pscustomobject]@{ Path = $Path; Query = $Query })
            if ($Path -eq '/database/search') {
                if ($Query.release_title -eq 'Forwards') { return $eggSearch }
                return [pscustomobject]@{ results = @() }
            }
            return $eggDetail
        }

        $result = InModuleScope Reshelf.EditProposal -Parameters @{ dataHome = $script:dataHome } {
            param($dataHome)
            Resolve-ReshelfDiscogsMatch -ArtistName 'The Egg' -Title 'Forwards Special Edition' -Year $null -DataHome $dataHome
        }

        $result.Status | Should -Be 'matched'
        $result.SelectedReleaseId | Should -Be 42
        ($calls | Where-Object Path -eq '/database/search').Count | Should -BeGreaterThan 1
    }

    It 'picks the eligible candidate whose real tracklist count matches the source, not just the top score' {
        # Real case (plan/12 milestone 3): Pivot "O Soundtrack My Heart" had 5 same-scoring Discogs
        # candidates (a 7" single, a promo CDr, 3 different album pressings) - the first one by
        # search-result order was a 2-track single, but the source has 11 tracks.
        $search = [pscustomobject]@{
            results = @(
                [pscustomobject]@{ id = 1; type = 'release'; title = 'Pivot - O Soundtrack My Heart'; year = '2008'; format = @('Vinyl', '7"', 'Single') }
                [pscustomobject]@{ id = 2; type = 'release'; title = 'Pivot - O Soundtrack My Heart'; year = '2008'; format = @('CD', 'Album') }
            )
        }
        $singleDetail = [pscustomobject]@{
            id = 1; title = 'O Soundtrack My Heart'; year = 2008; artists = @([pscustomobject]@{ name = 'Pivot' })
            formats = @([pscustomobject]@{ name = 'Vinyl'; descriptions = @('Single') }); images = @()
            tracklist = @([pscustomobject]@{ position = '1'; title = 'A' }, [pscustomobject]@{ position = '2'; title = 'B' })
        }
        $albumDetail = [pscustomobject]@{
            id = 2; title = 'O Soundtrack My Heart'; year = 2008; artists = @([pscustomobject]@{ name = 'Pivot' })
            formats = @([pscustomobject]@{ name = 'CD'; descriptions = @('Album') }); images = @()
            tracklist = @(1..11 | ForEach-Object { [pscustomobject]@{ position = "$_"; title = "Track $_" } })
        }

        Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
            if ($Path -eq '/database/search') { return $search }
            if ($Path -eq '/releases/1') { return $singleDetail }
            if ($Path -eq '/releases/2') { return $albumDetail }
            throw "unexpected path $Path"
        }

        $result = InModuleScope Reshelf.EditProposal -Parameters @{ dataHome = $script:dataHome } {
            param($dataHome)
            Resolve-ReshelfDiscogsMatch -ArtistName 'Pivot' -Title 'O Soundtrack My Heart' -Year 2008 -SourceTrackCount 11 -DataHome $dataHome
        }

        $result.Status | Should -Be 'matched'
        $result.SelectedReleaseId | Should -Be 2
        $result.Detail.tracklist.Count | Should -Be 11
    }

    It 'prefers an Album-format candidate over a Promo one when no eligible candidate matches the source track count' {
        $search = [pscustomobject]@{
            results = @(
                [pscustomobject]@{ id = 1; type = 'release'; title = 'Some Band - Some Album'; year = '2010'; format = @('CDr', 'Promo') }
                [pscustomobject]@{ id = 2; type = 'release'; title = 'Some Band - Some Album'; year = '2010'; format = @('CD', 'Album') }
            )
        }
        $promoDetail = [pscustomobject]@{
            id = 1; title = 'Some Album'; year = 2010; artists = @([pscustomobject]@{ name = 'Some Band' })
            formats = @([pscustomobject]@{ name = 'CDr'; descriptions = @('Promo') }); images = @()
            tracklist = @(1..5 | ForEach-Object { [pscustomobject]@{ position = "$_"; title = "Track $_" } })
        }
        $albumDetail = [pscustomobject]@{
            id = 2; title = 'Some Album'; year = 2010; artists = @([pscustomobject]@{ name = 'Some Band' })
            formats = @([pscustomobject]@{ name = 'CD'; descriptions = @('Album') }); images = @()
            tracklist = @(1..7 | ForEach-Object { [pscustomobject]@{ position = "$_"; title = "Track $_" } })
        }

        Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
            if ($Path -eq '/database/search') { return $search }
            if ($Path -eq '/releases/1') { return $promoDetail }
            if ($Path -eq '/releases/2') { return $albumDetail }
            throw "unexpected path $Path"
        }

        $result = InModuleScope Reshelf.EditProposal -Parameters @{ dataHome = $script:dataHome } {
            param($dataHome)
            # Neither candidate's tracklist (5, 7) matches a source of 9 - falls to format preference.
            Resolve-ReshelfDiscogsMatch -ArtistName 'Some Band' -Title 'Some Album' -Year 2010 -SourceTrackCount 9 -DataHome $dataHome
        }

        $result.Status | Should -Be 'matched'
        $result.SelectedReleaseId | Should -Be 2
    }

    It 'prefers a master''s main release over a same-scoring promo edition, and records the masterId (real Grails "The Burden Of Hope" case, plan/12)' {
        $masterSearch = [pscustomobject]@{
            results = @([pscustomobject]@{ id = 26213; type = 'master'; title = 'Grails - The Burden Of Hope'; year = '2003'; format = @('CD', 'Album') })
        }
        $masterDetail = [pscustomobject]@{ id = 26213; main_release = 384825; year = 2003; images = @() }
        $versionsResult = [pscustomobject]@{
            versions = @(
                [pscustomobject]@{ id = 384825; title = 'The Burden Of Hope'; released = '2003'; format = 'Album'; major_formats = @('CD'); stats = [pscustomobject]@{ community = [pscustomobject]@{ in_collection = 342 } } }
                [pscustomobject]@{ id = 10136207; title = 'The Burden Of Hope'; released = '2003'; format = 'Album, Promo'; major_formats = @('CD'); stats = [pscustomobject]@{ community = [pscustomobject]@{ in_collection = 5 } } }
            )
        }
        $mainDetail = [pscustomobject]@{
            id = 384825; title = 'The Burden Of Hope'; year = 2003; country = 'US'
            artists = @([pscustomobject]@{ name = 'Grails' })
            formats = @([pscustomobject]@{ name = 'CD'; descriptions = @('Album') })
            images = @([pscustomobject]@{ type = 'primary'; uri = 'https://example/main.jpg'; width = 600; height = 600 })
            tracklist = @(1..10 | ForEach-Object { [pscustomobject]@{ position = "$_"; title = "Track $_" } })
        }

        Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
            if ($Path -eq '/database/search' -and $Query.type -eq 'master') { return $masterSearch }
            if ($Path -eq '/masters/26213') { return $masterDetail }
            if ($Path -eq '/masters/26213/versions') { return $versionsResult }
            if ($Path -eq '/releases/384825') { return $mainDetail }
            throw "unexpected path $Path"
        }

        $result = InModuleScope Reshelf.EditProposal -Parameters @{ dataHome = $script:dataHome } {
            param($dataHome)
            Resolve-ReshelfDiscogsMatch -ArtistName 'Grails' -Title 'The Burden Of Hope' -Year 2003 -SourceTrackCount 10 -DataHome $dataHome
        }

        $result.Status | Should -Be 'matched'
        $result.SelectedReleaseId | Should -Be 384825
        $result.MasterId | Should -Be 26213
        $result.Master.main_release | Should -Be 384825
        $result.Detail.tracklist.Count | Should -Be 10
        $result.Candidates.Count | Should -Be 2
    }

    It 'normalizes a Cyrillic look-alike character in the artist name before querying Discogs (real "Inсubus Succubus" case)' {
        # The "c" in the ArtistName below is U+0441 CYRILLIC SMALL LETTER ES, not Latin "c" - looks
        # identical to a human but Discogs' server-side search would return nothing for it.
        $corruptedArtist = [string]::Concat('In', [char]0x0441, 'ubus Succubus')
        $masterSearch = [pscustomobject]@{
            results = @([pscustomobject]@{ id = 298095; type = 'master'; title = 'Incubus Succubus - Wytches'; year = '1994'; format = @('CD', 'Album') })
        }
        $masterDetail = [pscustomobject]@{ id = 298095; main_release = 111; year = 1994; images = @() }
        $versionsResult = [pscustomobject]@{
            versions = @([pscustomobject]@{ id = 111; title = 'Wytches'; released = '1994'; format = 'Album'; major_formats = @('CD'); stats = [pscustomobject]@{ community = [pscustomobject]@{ in_collection = 10 } } })
        }
        $mainDetail = [pscustomobject]@{
            id = 111; title = 'Wytches'; year = 1994; country = 'UK'
            artists = @([pscustomobject]@{ name = 'Incubus Succubus' })
            formats = @([pscustomobject]@{ name = 'CD'; descriptions = @('Album') }); images = @()
            tracklist = @(1..9 | ForEach-Object { [pscustomobject]@{ position = "$_"; title = "Track $_" } })
        }

        $calls = [System.Collections.Generic.List[object]]::new()
        Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
            $calls.Add([pscustomobject]@{ Path = $Path; Query = $Query })
            if ($Path -eq '/database/search' -and $Query.type -eq 'master') { return $masterSearch }
            if ($Path -eq '/masters/298095') { return $masterDetail }
            if ($Path -eq '/masters/298095/versions') { return $versionsResult }
            if ($Path -eq '/releases/111') { return $mainDetail }
            throw "unexpected path $Path"
        }

        $result = InModuleScope Reshelf.EditProposal -Parameters @{ dataHome = $script:dataHome; corruptedArtist = $corruptedArtist } {
            param($dataHome, $corruptedArtist)
            Resolve-ReshelfDiscogsMatch -ArtistName $corruptedArtist -Title 'Wytches' -Year 1994 -SourceTrackCount 9 -DataHome $dataHome
        }

        $result.Status | Should -Be 'matched'
        $result.SelectedReleaseId | Should -Be 111
        $result.HomoglyphNote | Should -Not -BeNullOrEmpty
        ($calls | Where-Object { $_.Path -eq '/database/search' -and $_.Query.type -eq 'master' } | Select-Object -First 1).Query.artist | Should -Be 'Incubus Succubus'
    }

    It 'does not treat a genuinely Cyrillic artist name as homoglyph-corrupted' {
        Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
            [pscustomobject]@{ results = @() }
        }

        $result = InModuleScope Reshelf.EditProposal -Parameters @{ dataHome = $script:dataHome } {
            param($dataHome)
            Resolve-ReshelfDiscogsMatch -ArtistName 'Кино' -Title 'Группа крови' -Year 1988 -DataHome $dataHome
        }

        $result.HomoglyphNote | Should -BeNullOrEmpty
    }

    It 'falls back to the artist master list when a release_title master search finds nothing (real Grails "Red Light"/"Redlight" case, plan/12)' {
        $artistMasterSearch = [pscustomobject]@{
            results = @([pscustomobject]@{ id = 91049; type = 'master'; title = 'Grails - Redlight'; year = '2004'; format = @('CD', 'Album') })
        }
        $masterDetail = [pscustomobject]@{ id = 91049; main_release = 593180; year = 2004; images = @() }
        $versionsResult = [pscustomobject]@{
            versions = @([pscustomobject]@{ id = 593180; title = 'Redlight'; released = '2004'; format = 'Album'; major_formats = @('CD') })
        }
        $mainDetail = [pscustomobject]@{
            id = 593180; title = 'Redlight'; year = 2004; country = 'US'
            artists = @([pscustomobject]@{ name = 'Grails' })
            formats = @([pscustomobject]@{ name = 'CD'; descriptions = @('Album') })
            images = @()
            tracklist = @(1..10 | ForEach-Object { [pscustomobject]@{ position = "$_"; title = "Track $_" } })
        }

        Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
            if ($Path -eq '/database/search') {
                # The master-search ladder always queries with release_title - only the artist-list
                # fallback (step 1b) queries without it.
                if ($Query.ContainsKey('release_title')) { return [pscustomobject]@{ results = @() } }
                return $artistMasterSearch
            }
            if ($Path -eq '/masters/91049') { return $masterDetail }
            if ($Path -eq '/masters/91049/versions') { return $versionsResult }
            if ($Path -eq '/releases/593180') { return $mainDetail }
            throw "unexpected path $Path"
        }

        $result = InModuleScope Reshelf.EditProposal -Parameters @{ dataHome = $script:dataHome } {
            param($dataHome)
            Resolve-ReshelfDiscogsMatch -ArtistName 'Grails' -Title 'Red Light' -Year 2004 -SourceTrackCount 10 -DataHome $dataHome
        }

        $result.Status | Should -Be 'matched'
        $result.SelectedReleaseId | Should -Be 593180
        $result.MasterId | Should -Be 91049
    }

    It 'prefers a CD version over the master''s own Vinyl main release when both match the source track count (real OOIOO "Feather Float" case, plan/12)' {
        $masterSearch = [pscustomobject]@{
            results = @([pscustomobject]@{ id = 8707; type = 'master'; title = 'OOIOO - Feather Float'; year = '1999'; format = @('Vinyl', 'LP') })
        }
        $masterDetail = [pscustomobject]@{ id = 8707; main_release = 1338686; year = 1999; images = @() }
        $versionsResult = [pscustomobject]@{
            versions = @(
                [pscustomobject]@{ id = 1338686; title = 'Feather Float'; released = '1999'; format = 'LP, Limited Edition'; major_formats = @('Vinyl') }
                [pscustomobject]@{ id = 368574; title = 'Feather Float'; released = '2001'; format = 'Album'; major_formats = @('CD') }
            )
        }
        $vinylDetail = [pscustomobject]@{
            id = 1338686; title = 'Feather Float'; year = 1999; country = 'Japan'
            artists = @([pscustomobject]@{ name = 'OOIOO' })
            formats = @([pscustomobject]@{ name = 'Vinyl'; descriptions = @('LP', 'Limited Edition') })
            images = @()
            tracklist = @(1..11 | ForEach-Object { [pscustomobject]@{ position = "$_"; title = "Track $_" } })
        }
        $cdDetail = [pscustomobject]@{
            id = 368574; title = 'Feather Float'; year = 2001; country = 'US'
            artists = @([pscustomobject]@{ name = 'OOIOO' })
            formats = @([pscustomobject]@{ name = 'CD'; descriptions = @('Album') })
            images = @([pscustomobject]@{ type = 'primary'; uri = 'https://example/cd.jpg'; width = 600; height = 600 })
            tracklist = @(1..11 | ForEach-Object { [pscustomobject]@{ position = "$_"; title = "Track $_" } })
        }

        Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
            if ($Path -eq '/database/search' -and $Query.type -eq 'master') { return $masterSearch }
            if ($Path -eq '/masters/8707') { return $masterDetail }
            if ($Path -eq '/masters/8707/versions') { return $versionsResult }
            if ($Path -eq '/releases/1338686') { return $vinylDetail }
            if ($Path -eq '/releases/368574') { return $cdDetail }
            throw "unexpected path $Path"
        }

        $result = InModuleScope Reshelf.EditProposal -Parameters @{ dataHome = $script:dataHome } {
            param($dataHome)
            Resolve-ReshelfDiscogsMatch -ArtistName 'OOIOO' -Title 'Feather Float' -Year 1999 -SourceTrackCount 11 -DataHome $dataHome
        }

        $result.Status | Should -Be 'matched'
        $result.SelectedReleaseId | Should -Be 368574
        $result.MasterId | Should -Be 8707
    }

    It 'promotes a release-search match to its master when the search result itself carries a master_id' {
        $releaseSearch = [pscustomobject]@{
            results = @([pscustomobject]@{ id = 999; type = 'release'; title = 'Some Band - Some Album'; year = '2010'; format = @('CD', 'Album'); master_id = 555 })
        }
        $masterDetail = [pscustomobject]@{ id = 555; main_release = 999; year = 2010; images = @() }
        $versionsResult = [pscustomobject]@{
            versions = @([pscustomobject]@{ id = 999; title = 'Some Album'; released = '2010'; format = 'Album'; major_formats = @('CD') })
        }
        $detail = [pscustomobject]@{
            id = 999; title = 'Some Album'; year = 2010; artists = @([pscustomobject]@{ name = 'Some Band' })
            formats = @([pscustomobject]@{ name = 'CD'; descriptions = @('Album') }); images = @()
            tracklist = @(1..5 | ForEach-Object { [pscustomobject]@{ position = "$_"; title = "Track $_" } })
        }

        Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
            if ($Path -eq '/database/search') {
                if ($Query.type -eq 'master') { return [pscustomobject]@{ results = @() } }
                return $releaseSearch
            }
            if ($Path -eq '/masters/555') { return $masterDetail }
            if ($Path -eq '/masters/555/versions') { return $versionsResult }
            if ($Path -eq '/releases/999') { return $detail }
            throw "unexpected path $Path"
        }

        $result = InModuleScope Reshelf.EditProposal -Parameters @{ dataHome = $script:dataHome } {
            param($dataHome)
            Resolve-ReshelfDiscogsMatch -ArtistName 'Some Band' -Title 'Some Album' -Year 2010 -SourceTrackCount 5 -DataHome $dataHome
        }

        $result.Status | Should -Be 'matched'
        $result.SelectedReleaseId | Should -Be 999
        $result.MasterId | Should -Be 555
    }

    It 'matches by track durations when every title-based search comes up empty (real Maximum The Hormone case, session 2026-10-03-0010: Discogs titles the release only in Japanese)' {
        $artistSearch = [pscustomobject]@{ results = @([pscustomobject]@{ id = 500; type = 'artist'; title = 'マキシマム ザ ホルモン' }) }
        $artistDetail = [pscustomobject]@{ id = 500; name = 'マキシマム ザ ホルモン'; namevariations = @('Maximum The Hormone') }
        $catalogReleases = [pscustomobject]@{
            releases = @([pscustomobject]@{ id = 99; type = 'release'; role = 'Main'; year = 2005; format = @('CD', 'Album'); title = 'ロッキンポ殺し' })
        }
        $releaseDetail = [pscustomobject]@{
            id        = 99; title = 'ロッキンポ殺し'; year = 2005; released = '2005-03-02'
            artists   = @([pscustomobject]@{ name = 'マキシマム ザ ホルモン' })
            tracklist = @(
                [pscustomobject]@{ position = '1'; title = 'ロッキンポ殺し'; duration = '2:05' }
                [pscustomobject]@{ position = '2'; title = 'ニトロBB戦争'; duration = '2:20' }
            )
        }

        Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
            if ($Path -eq '/database/search' -and $Query.type -eq 'artist') { return $artistSearch }
            if ($Path -eq '/artists/500') { return $artistDetail }
            if ($Path -eq '/database/search') { return [pscustomobject]@{ results = @() } }
            if ($Path -eq '/artists/500/releases') { return $catalogReleases }
            if ($Path -eq '/releases/99') { return $releaseDetail }
            throw "unexpected path $Path"
        }

        $result = InModuleScope Reshelf.EditProposal -Parameters @{ dataHome = $script:dataHome } {
            param($dataHome)
            Resolve-ReshelfDiscogsMatch -ArtistName 'Maximum The Hormone' -Title 'Rokkinpo Goroshi' -Year 2005 `
                -SourceTrackCount 2 -SourceDurations @(125.0, 140.0) -DataHome $dataHome
        }

        $result.Status | Should -Be 'matched'
        $result.SelectedReleaseId | Should -Be 99
        $result.Detail.title | Should -Be 'ロッキンポ殺し'
    }

    It 'falls back to ambiguous (not not-found) when the catalog-fallback candidate''s durations do not line up' {
        $artistSearch = [pscustomobject]@{ results = @([pscustomobject]@{ id = 500; type = 'artist'; title = 'マキシマム ザ ホルモン' }) }
        $artistDetail = [pscustomobject]@{ id = 500; name = 'マキシマム ザ ホルモン'; namevariations = @('Maximum The Hormone') }
        $catalogReleases = [pscustomobject]@{
            releases = @([pscustomobject]@{ id = 99; type = 'release'; role = 'Main'; year = 2005; format = @('CD', 'Album'); title = 'ロッキンポ殺し' })
        }
        $releaseDetail = [pscustomobject]@{
            id        = 99; title = 'ロッキンポ殺し'; year = 2005; released = '2005-03-02'
            artists   = @([pscustomobject]@{ name = 'マキシマム ザ ホルモン' })
            tracklist = @(
                [pscustomobject]@{ position = '1'; title = 'ロッキンポ殺し'; duration = '2:05' }
                [pscustomobject]@{ position = '2'; title = 'ニトロBB戦争'; duration = '2:20' }
            )
        }

        Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
            if ($Path -eq '/database/search' -and $Query.type -eq 'artist') { return $artistSearch }
            if ($Path -eq '/artists/500') { return $artistDetail }
            if ($Path -eq '/database/search') { return [pscustomobject]@{ results = @() } }
            if ($Path -eq '/artists/500/releases') { return $catalogReleases }
            if ($Path -eq '/releases/99') { return $releaseDetail }
            throw "unexpected path $Path"
        }

        $result = InModuleScope Reshelf.EditProposal -Parameters @{ dataHome = $script:dataHome } {
            param($dataHome)
            # Durations (50s/60s) are nowhere close to the catalog release's (125s/140s), and no
            # release date was given either - too weak to auto-match.
            Resolve-ReshelfDiscogsMatch -ArtistName 'Maximum The Hormone' -Title 'Rokkinpo Goroshi' -Year 2005 `
                -SourceTrackCount 2 -SourceDurations @(50.0, 60.0) -DataHome $dataHome
        }

        $result.Status | Should -Be 'ambiguous'
        $result.Candidates.Count | Should -BeGreaterThan 0
        $result.Candidates[0].releaseId | Should -Be 99
    }

    It 'needs an exact release date, not just one lucky duration, to auto-match a 1-track single by catalog fallback' {
        $artistSearch = [pscustomobject]@{ results = @([pscustomobject]@{ id = 500; type = 'artist'; title = 'マキシマム ザ ホルモン' }) }
        $artistDetail = [pscustomobject]@{ id = 500; name = 'マキシマム ザ ホルモン'; namevariations = @('Maximum The Hormone') }
        $catalogReleases = [pscustomobject]@{
            releases = @([pscustomobject]@{ id = 77; type = 'release'; role = 'Main'; year = 2005; format = @('CD', 'Single'); title = 'ざわざわ' })
        }
        $releaseDetail = [pscustomobject]@{
            id        = 77; title = 'ざわざわ'; year = 2005; released = '2005-10-19'
            artists   = @([pscustomobject]@{ name = 'マキシマム ザ ホルモン' })
            tracklist = @([pscustomobject]@{ position = '1'; title = 'ざわざわ'; duration = '2:05' })
        }

        Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
            if ($Path -eq '/database/search' -and $Query.type -eq 'artist') { return $artistSearch }
            if ($Path -eq '/artists/500') { return $artistDetail }
            if ($Path -eq '/database/search') { return [pscustomobject]@{ results = @() } }
            if ($Path -eq '/artists/500/releases') { return $catalogReleases }
            if ($Path -eq '/releases/77') { return $releaseDetail }
            throw "unexpected path $Path"
        }

        # One track, its one duration matches exactly (125s), but no release date was given -
        # should still only reach 'ambiguous', not an auto-matched 'matched'.
        $ambiguous = InModuleScope Reshelf.EditProposal -Parameters @{ dataHome = $script:dataHome } {
            param($dataHome)
            Resolve-ReshelfDiscogsMatch -ArtistName 'Maximum The Hormone' -Title 'Zawa' -Year 2005 `
                -SourceTrackCount 1 -SourceDurations @(125.0) -DataHome $dataHome
        }
        $ambiguous.Status | Should -Be 'ambiguous'

        # Same one duration, but this time the exact release date is also given - now it's strong
        # enough to auto-match.
        $matched = InModuleScope Reshelf.EditProposal -Parameters @{ dataHome = $script:dataHome } {
            param($dataHome)
            Resolve-ReshelfDiscogsMatch -ArtistName 'Maximum The Hormone' -Title 'Zawa' -Year 2005 `
                -SourceTrackCount 1 -SourceDurations @(125.0) -ReleaseDate '2005-10-19' -DataHome $dataHome
        }
        $matched.Status | Should -Be 'matched'
        $matched.SelectedReleaseId | Should -Be 77
    }
}

Describe 'Sort-ReshelfDiscogsVersions / Get-ReshelfDiscogsVersionRank (private)' {
    It 'prefers the version whose released year matches the folder year, then a CD/File format over Vinyl, then higher community count' {
        InModuleScope Reshelf.EditProposal {
            $versions = @(
                [pscustomobject]@{ id = 1; title = 'X'; released = '2019'; format = 'Album'; major_formats = @('Vinyl'); stats = [pscustomobject]@{ community = [pscustomobject]@{ in_collection = 1 } } }
                [pscustomobject]@{ id = 2; title = 'X'; released = '2005'; format = 'Album'; major_formats = @('CD'); stats = [pscustomobject]@{ community = [pscustomobject]@{ in_collection = 228 } } }
                [pscustomobject]@{ id = 3; title = 'X'; released = '2005'; format = 'Album'; major_formats = @('File'); stats = [pscustomobject]@{ community = [pscustomobject]@{ in_collection = 6 } } }
            )

            $sorted = Sort-ReshelfDiscogsVersions -Versions $versions -FolderYear $null -EditionHints @()
            $sorted[0].id | Should -Be 2
        }
    }

    It 'ranks a Promo/Test Pressing version behind an otherwise-equal one' {
        InModuleScope Reshelf.EditProposal {
            $versions = @(
                [pscustomobject]@{ id = 1; title = 'X'; released = '2010'; format = 'Album, Promo'; major_formats = @('CD') }
                [pscustomobject]@{ id = 2; title = 'X'; released = '2010'; format = 'Album'; major_formats = @('CD') }
            )

            $sorted = Sort-ReshelfDiscogsVersions -Versions $versions -FolderYear $null -EditionHints @()
            $sorted[0].id | Should -Be 2
        }
    }

    It 'ranks Vinyl/Cassette above a rarer format (e.g. 8-Track Cartridge) even when the rarer format matches the folder year' {
        # Real case (AC-DC "T.N.T.", master 8648): an 8-Track Cartridge version has the same
        # released year AND the same track count as the source, but tapes of that format split
        # tracks into "programs" to balance side lengths, so its tracklist ORDER is physically
        # different from the standard release - previously this format fell into the same "else"
        # bucket as CD/File-but-ranked-worse-than-Vinyl/Cassette, which was backwards: it let an
        # 8-Track version outrank an equally-year-matched Vinyl/Cassette version and get picked
        # first by the probe loop in Select-ReshelfDiscogsMasterVersion, silently importing the
        # wrong track order.
        InModuleScope Reshelf.EditProposal {
            $versions = @(
                [pscustomobject]@{ id = 1; title = 'X'; released = '1975'; format = 'Album, Stereo'; major_formats = @('8-Track Cartridge') }
                [pscustomobject]@{ id = 2; title = 'X'; released = '1975'; format = 'LP, Album'; major_formats = @('Vinyl') }
                [pscustomobject]@{ id = 3; title = 'X'; released = '1975'; format = 'Album, Stereo'; major_formats = @('Cassette') }
            )

            $sorted = Sort-ReshelfDiscogsVersions -Versions $versions -FolderYear 1975 -EditionHints @()
            # Vinyl/Cassette (ids 2/3) must both outrank 8-Track Cartridge (id 1), regardless of
            # which of the two ties for first.
            $sorted[-1].id | Should -Be 1
            @($sorted[0].id, $sorted[1].id) | Sort-Object | Should -Be @(2, 3)
        }
    }

    It 'matches an edition hint against Discogs'' own comma-separated format descriptors, not a raw substring of format+title' {
        InModuleScope Reshelf.EditProposal {
            $versions = @(
                [pscustomobject]@{ id = 1; title = 'X'; released = '2010'; format = 'CD, Album, Reissue'; major_formats = @('CD') }
                [pscustomobject]@{ id = 2; title = 'X'; released = '2010'; format = 'CD, Album, Reissue, Deluxe Edition'; major_formats = @('CD') }
            )

            $sorted = Sort-ReshelfDiscogsVersions -Versions $versions -FolderYear $null -EditionHints @('Deluxe Edition')
            $sorted[0].id | Should -Be 2
        }
    }

    It 'does not false-positive an edition hint against an unrelated substring in format/title' {
        InModuleScope Reshelf.EditProposal {
            # "Limited" must not match a version whose format token is "Unlimited Access" (contains
            # "Limited" as a substring but is not the same token) - a real-world style trap for the
            # old blob-substring check.
            $versions = @(
                [pscustomobject]@{ id = 1; title = 'X'; released = '2010'; format = 'CD, Album, Unlimited Access'; major_formats = @('CD') }
                [pscustomobject]@{ id = 2; title = 'X'; released = '2010'; format = 'CD, Album, Limited Edition'; major_formats = @('CD') }
            )

            $rank1 = Get-ReshelfDiscogsVersionRank -Version $versions[0] -FolderYear $null -EditionHints @('Limited')
            $rank2 = Get-ReshelfDiscogsVersionRank -Version $versions[1] -FolderYear $null -EditionHints @('Limited Edition')
            $rank1.EditionMatch | Should -Be $false
            $rank2.EditionMatch | Should -Be $true
        }
    }
}

Describe 'Build-ReshelfTargetIndex and Test-ReshelfTargetReleaseExists' {
    It 'returns an empty index when the target root does not exist' {
        $index = Build-ReshelfTargetIndex -TargetRoot (Join-Path $TestDrive ([guid]::NewGuid().ToString('N')))
        $index.Count | Should -Be 0
    }

    It 'indexes well-formed artist/release folders and finds them by stable key' {
        $targetRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $targetRoot 'ArtistA' '1999 AlbumOne') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $targetRoot 'ArtistB' '2005 AlbumTwo') -Force | Out-Null

        $index = Build-ReshelfTargetIndex -TargetRoot $targetRoot

        $index.Count | Should -Be 2
        $keyA = Get-TestStableKey -Artist 'ArtistA' -Album 'AlbumOne' -Year 1999
        $entry = Test-ReshelfTargetReleaseExists -TargetIndex $index -StableKey $keyA
        $entry | Should -Not -BeNullOrEmpty
        $entry.Path | Should -Be (Join-Path $targetRoot 'ArtistA' '1999 AlbumOne')
    }

    It 'skips a release folder that does not match the "yyyy Name" pattern' {
        $targetRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $targetRoot 'ArtistA' 'Misc') -Force | Out-Null

        $index = Build-ReshelfTargetIndex -TargetRoot $targetRoot
        $index.Count | Should -Be 0
    }

    It 'returns $null from Test-ReshelfTargetReleaseExists when the key is not indexed' {
        $index = Build-ReshelfTargetIndex -TargetRoot (Join-Path $TestDrive ([guid]::NewGuid().ToString('N')))
        Test-ReshelfTargetReleaseExists -TargetIndex $index -StableKey 'doesnotexist0000' | Should -BeNullOrEmpty
    }

    It 'does not throw on a stable-key collision between two folders that normalize the same way' {
        $targetRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $targetRoot 'ZZ Top' '1999 XXX') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $targetRoot 'zz  top' '1999 XXX') -Force | Out-Null

        $index = Build-ReshelfTargetIndex -TargetRoot $targetRoot
        $index.Count | Should -Be 1
    }
}

Describe 'New-ReshelfCompanionProposal (private)' {
    It 'adds include = $true and leaves proposedFileName $null for a nested companion' {
        InModuleScope Reshelf.EditProposal {
            $companions = @(
                [pscustomobject]@{ sourcePath = 'C:\src\Scans\front.jpg'; kind = 'cover'; placement = 'nested' }
            )
            $result = New-ReshelfCompanionProposal -CompanionFiles $companions
            $result.Companions.Count | Should -Be 1
            $result.Companions[0].include | Should -Be $true
            $result.Companions[0].proposedFileName | Should -BeNullOrEmpty
            $result.RequiresReview | Should -Be $false
        }
    }

    It 'proposes the same name unchanged for a loose companion that already starts with a letter' {
        InModuleScope Reshelf.EditProposal {
            $companions = @(
                [pscustomobject]@{ sourcePath = 'C:\src\folder.jpg'; kind = 'cover'; placement = 'loose' }
            )
            $result = New-ReshelfCompanionProposal -CompanionFiles $companions
            $result.Companions[0].proposedFileName | Should -Be 'folder.jpg'
            $result.RequiresReview | Should -Be $false
            $result.Notes | Should -BeNullOrEmpty
        }
    }

    It 'renames a digit-starting loose companion with its kind word prefix, flags review, and adds a note' {
        InModuleScope Reshelf.EditProposal {
            $companions = @(
                [pscustomobject]@{ sourcePath = 'C:\src\01 back.jpg'; kind = 'booklet'; placement = 'loose' }
            )
            $result = New-ReshelfCompanionProposal -CompanionFiles $companions
            $result.Companions[0].proposedFileName | Should -Be 'Booklet 01 back.jpg'
            $result.RequiresReview | Should -Be $true
            $result.Notes.Count | Should -Be 1
            $result.Notes[0] | Should -BeLike "*01 back.jpg*renamed*Booklet 01 back.jpg*"
        }
    }

    It 'handles an empty companion list' {
        InModuleScope Reshelf.EditProposal {
            $result = New-ReshelfCompanionProposal -CompanionFiles @()
            $result.Companions.Count | Should -Be 0
            $result.RequiresReview | Should -Be $false
        }
    }
}

Describe 'Invoke-ReshelfEditProposal' {
    BeforeEach {
        $script:dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:sourceRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:targetRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:targetRoot -Force | Out-Null
        $script:recognitionPath = Join-Path $TestDrive "$([guid]::NewGuid().ToString('N')).json"
    }

    Context 'naming and tagging' {
        It 'produces correct names and tags for a single-disc matched release' {
            $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Radiohead' '1997 OK Computer' '01 - Airbag.flac')
            $t2 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Radiohead' '1997 OK Computer' '02 - Paranoid Android.flac')
            $t3 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Radiohead' '1997 OK Computer' '03 - Subterranean Homesick Alien.flac')

            $tracks = @(
                (New-TestTrack -SourceFilePath $t1 -OriginalFileName '01 - Airbag.flac' -DetectedTrackNumberInDisc 1)
                (New-TestTrack -SourceFilePath $t2 -OriginalFileName '02 - Paranoid Android.flac' -DetectedTrackNumberInDisc 2)
                (New-TestTrack -SourceFilePath $t3 -OriginalFileName '03 - Subterranean Homesick Alien.flac' -DetectedTrackNumberInDisc 3)
            )
            $release = New-TestRelease -StableKey (Get-TestStableKey -Artist 'Radiohead' -Album 'OK Computer' -Year 1997) `
                -RecognizedTitle 'OK Computer' -RecognizedYear 1997 -SourceFolderPath (Split-Path $t1) -Tracks $tracks

            New-TestRecognitionFile -Path $script:recognitionPath -SessionId 'test-session' -SourceRoot $script:sourceRoot -Artists @(
                [pscustomobject]@{ recognizedName = 'Radiohead'; sourcePaths = @($script:sourceRoot); releases = @($release) }
            )

            Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
                if ($Path -eq '/database/search') { return $script:SearchFixture }
                return $script:ReleaseFixture
            }

            $result = Invoke-ReshelfEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome

            $releaseResult = $result.artists[0].releases[0]
            $releaseResult.discogsMatch.status | Should -Be 'matched'
            $releaseResult.proposed.artistFolderName | Should -Be 'Radiohead'
            $releaseResult.proposed.releaseFolderName | Should -Be '1997 OK Computer'
            $releaseResult.tracks[0].tags.artist | Should -Be 'Radiohead'
            $releaseResult.tracks[0].tags.albumArtist | Should -Be 'Radiohead'
            $releaseResult.tracks[0].proposedTitle | Should -Be 'Airbag'
            $releaseResult.tracks[0].proposedFileName | Should -Be '01 Airbag.flac'
            $releaseResult.tracks[2].proposedFileName | Should -Be '03 Subterranean Homesick Alien.flac'
            $releaseResult.targetAction | Should -Be 'create-new'
            $releaseResult.humanReview.required | Should -Be $false
        }

        It 'numbers a multi-disc release continuously across discs while tags.track restarts per disc (manifesto section 5 table)' {
            $discs = @('CD 1', 'CD 1', 'CD 2', 'CD 2', 'CD 3', 'CD 3')
            $titles = @('First Track', 'Second Track', 'Third Track', 'Fourth Track', 'Fifth Track', 'Sixth Track')
            $tracks = for ($i = 0; $i -lt $discs.Count; $i++) {
                $fileName = "$([int]($i % 2) + 1) - $($titles[$i]).flac"
                $path = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2001 Box Set' $discs[$i] $fileName)
                New-TestTrack -SourceFilePath $path -OriginalFileName $fileName -DiscFolder $discs[$i] -DetectedTrackNumberInDisc ([int]($i % 2) + 1)
            }

            $release = New-TestRelease -StableKey (Get-TestStableKey -Artist 'Some Band' -Album 'Box Set' -Year 2001) `
                -RecognizedTitle 'Box Set' -RecognizedYear 2001 -SourceFolderPath (Join-Path $script:sourceRoot 'Some Band' '2001 Box Set') `
                -DiscFolderCount 3 -Tracks $tracks

            New-TestRecognitionFile -Path $script:recognitionPath -SessionId 'test-session' -SourceRoot $script:sourceRoot -Artists @(
                [pscustomobject]@{ recognizedName = 'Some Band'; sourcePaths = @($script:sourceRoot); releases = @($release) }
            )

            Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
                [pscustomobject]@{ results = @() }
            }

            $result = Invoke-ReshelfEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
            $releaseTracks = $result.artists[0].releases[0].tracks

            # Copied row by row from MANIFESTO.md section 5: File Name | Disc Number | Track | Title.
            $expected = @(
                @{ FileName = '01 First Track.flac'; Disc = 1; Track = 1; Title = 'First Track' }
                @{ FileName = '02 Second Track.flac'; Disc = 1; Track = 2; Title = 'Second Track' }
                @{ FileName = '03 Third Track.flac'; Disc = 2; Track = 1; Title = 'Third Track' }
                @{ FileName = '04 Fourth Track.flac'; Disc = 2; Track = 2; Title = 'Fourth Track' }
                @{ FileName = '05 Fifth Track.flac'; Disc = 3; Track = 1; Title = 'Fifth Track' }
                @{ FileName = '06 Sixth Track.flac'; Disc = 3; Track = 2; Title = 'Sixth Track' }
            )

            $releaseTracks.Count | Should -Be $expected.Count
            for ($i = 0; $i -lt $expected.Count; $i++) {
                $row = $expected[$i]
                $releaseTracks[$i].proposedFileName | Should -Be $row.FileName
                $releaseTracks[$i].proposedDiscNumber | Should -Be $row.Disc
                $releaseTracks[$i].proposedTrackNumber | Should -Be $row.Track
                $releaseTracks[$i].proposedTitle | Should -Be $row.Title
                $releaseTracks[$i].tags.discNumber | Should -Be $row.Disc
                $releaseTracks[$i].tags.track | Should -Be $row.Track
                $releaseTracks[$i].tags.title | Should -Be $row.Title
            }
        }

        It 'keeps the real track position when the source is missing a track Discogs has (plan/12 milestone 5)' {
            $folder = Join-Path $script:sourceRoot 'aoki takamasa' '2002 indigo rose'
            $t2 = New-TestAudioFile -Path (Join-Path $folder '02 - dear people.flac')
            $t3 = New-TestAudioFile -Path (Join-Path $folder '03 - hope.flac')

            $tracks = @(
                (New-TestTrack -SourceFilePath $t2 -OriginalFileName '02 - dear people.flac' -DetectedTrackNumberInDisc 2)
                (New-TestTrack -SourceFilePath $t3 -OriginalFileName '03 - hope.flac' -DetectedTrackNumberInDisc 3)
            )
            $release = New-TestRelease -StableKey (Get-TestStableKey -Artist 'aoki takamasa' -Album 'indigo rose' -Year 2002) `
                -RecognizedTitle 'indigo rose' -RecognizedYear 2002 -SourceFolderPath $folder -Tracks $tracks

            New-TestRecognitionFile -Path $script:recognitionPath -SessionId 'test-session' -SourceRoot $script:sourceRoot -Artists @(
                [pscustomobject]@{ recognizedName = 'aoki takamasa'; sourcePaths = @($script:sourceRoot); releases = @($release) }
            )

            $script:customSearch = [pscustomobject]@{
                results = @([pscustomobject]@{ id = 777; type = 'release'; title = 'AOKI Takamasa - Indigo Rose'; year = '2002'; format = @('CD', 'Album') })
            }
            $script:customDetail = [pscustomobject]@{
                id        = 777
                title     = 'Indigo Rose'
                year      = 2002
                country   = 'JP'
                artists   = @([pscustomobject]@{ name = 'AOKI Takamasa'; id = 1 })
                formats   = @([pscustomobject]@{ name = 'CD'; qty = '1'; descriptions = @('Album') })
                images    = @()
                tracklist = @(
                    [pscustomobject]@{ position = '1'; title = 'Cover Your Ears'; duration = '' }
                    [pscustomobject]@{ position = '2'; title = 'Dear People'; duration = '' }
                    [pscustomobject]@{ position = '3'; title = 'Hope'; duration = '' }
                )
            }

            Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
                if ($Path -eq '/database/search') { return $script:customSearch }
                return $script:customDetail
            }

            $result = Invoke-ReshelfEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
            $releaseResult = $result.artists[0].releases[0]

            $releaseResult.tracks.proposedFileName | Should -Be @('02 Dear People.flac', '03 Hope.flac')
            $releaseResult.tracks.tags.track | Should -Be @(2, 3)
            $releaseResult.humanReview.required | Should -Be $true
            $releaseResult.humanReview.notes | Should -Match 'missing on source: 1 Cover Your Ears'
        }

        It 'keeps feat. wording out of Artist/AlbumArtist but in the title, and strips a Discogs disambiguation suffix' {
            $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Metallica' '1991 Metallica' '01 - Enter Sandman.flac')
            $t2 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Metallica' '1991 Metallica' '02 - Nothing Else Matters.flac')

            $tracks = @(
                (New-TestTrack -SourceFilePath $t1 -OriginalFileName '01 - Enter Sandman.flac' -DetectedTrackNumberInDisc 1)
                (New-TestTrack -SourceFilePath $t2 -OriginalFileName '02 - Nothing Else Matters.flac' -DetectedTrackNumberInDisc 2)
            )
            $release = New-TestRelease -StableKey (Get-TestStableKey -Artist 'Metallica' -Album 'Metallica' -Year 1991) `
                -RecognizedTitle 'Metallica' -RecognizedYear 1991 -SourceFolderPath (Split-Path $t1) -Tracks $tracks

            New-TestRecognitionFile -Path $script:recognitionPath -SessionId 'test-session' -SourceRoot $script:sourceRoot -Artists @(
                [pscustomobject]@{ recognizedName = 'Metallica'; sourcePaths = @($script:sourceRoot); releases = @($release) }
            )

            $script:customSearch = [pscustomobject]@{
                results = @([pscustomobject]@{ id = 999; type = 'release'; title = 'Metallica - Metallica'; year = '1991'; format = @('CD', 'Album') })
            }
            $script:customDetail = [pscustomobject]@{
                id        = 999
                title     = 'Metallica'
                year      = 1991
                country   = 'US'
                artists   = @([pscustomobject]@{ name = 'Metallica (2)'; id = 1 })
                formats   = @([pscustomobject]@{ name = 'CD'; qty = '1'; descriptions = @('Album') })
                images    = @()
                tracklist = @(
                    [pscustomobject]@{ position = '1'; title = 'Enter Sandman'; duration = '5:32' }
                    [pscustomobject]@{ position = '2'; title = 'Nothing Else Matters (feat. Justin Bieber)'; duration = '6:28' }
                )
            }

            Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
                if ($Path -eq '/database/search') { return $script:customSearch }
                return $script:customDetail
            }

            $result = Invoke-ReshelfEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
            $releaseResult = $result.artists[0].releases[0]

            $releaseResult.proposed.artistFolderName | Should -Be 'Metallica'
            $releaseResult.tracks[1].tags.artist | Should -Be 'Metallica'
            $releaseResult.tracks[1].tags.albumArtist | Should -Be 'Metallica'
            $releaseResult.tracks[1].tags.title | Should -BeLike '*feat*'
            $releaseResult.tracks[1].proposedTitle | Should -BeLike '*feat*'
        }

        It 'gives each track its own Discogs artist credit on a Various-Artists compilation (real "Our Best Irish Pub Songs" case)' {
            $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Various' 'Our Best Irish Pub Songs' '01 - Seven Drunken Nights.mp3')
            $t2 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Various' 'Our Best Irish Pub Songs' '02 - The Pub With No Beer.mp3')

            $tracks = @(
                (New-TestTrack -SourceFilePath $t1 -OriginalFileName '01 - Seven Drunken Nights.mp3' -DetectedTrackNumberInDisc 1 -Format 'mp3' -IsLossless $false -ExistingArtist 'The Dubliners')
                (New-TestTrack -SourceFilePath $t2 -OriginalFileName '02 - The Pub With No Beer.mp3' -DetectedTrackNumberInDisc 2 -Format 'mp3' -IsLossless $false -ExistingArtist 'Dublin City Ramblers')
            )
            $release = New-TestRelease -StableKey (Get-TestStableKey -Artist 'Various' -Album 'Our Best Irish Pub Songs' -Year 2008) `
                -RecognizedTitle 'Our Best Irish Pub Songs' -RecognizedYear 2008 -SourceFolderPath (Split-Path $t1) -Tracks $tracks

            New-TestRecognitionFile -Path $script:recognitionPath -SessionId 'test-session' -SourceRoot $script:sourceRoot -Artists @(
                [pscustomobject]@{ recognizedName = 'Various'; sourcePaths = @($script:sourceRoot); releases = @($release) }
            )

            $script:customSearch = [pscustomobject]@{
                results = @([pscustomobject]@{ id = 555; type = 'release'; title = 'Various - Our Best Irish Pub Songs'; year = '2008'; format = @('CD', 'Album', 'Compilation') })
            }
            $script:customDetail = [pscustomobject]@{
                id        = 555
                title     = 'Our Best Irish Pub Songs'
                year      = 2008
                country   = 'Denmark'
                artists   = @([pscustomobject]@{ name = 'Various'; id = 194 })
                formats   = @([pscustomobject]@{ name = 'CD'; qty = '1'; descriptions = @('Album', 'Compilation') })
                images    = @()
                # Track 1 has its own Discogs per-track credit; track 2 doesn't, so it falls back
                # to the file's own existing Artist tag (Dublin City Ramblers).
                tracklist = @(
                    [pscustomobject]@{ position = '1'; title = 'Seven Drunken Nights'; artists = @([pscustomobject]@{ name = 'The Dubliners'; join = '' }) }
                    [pscustomobject]@{ position = '2'; title = 'The Pub With No Beer' }
                )
            }

            Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
                if ($Path -eq '/database/search') { return $script:customSearch }
                return $script:customDetail
            }

            $result = Invoke-ReshelfEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
            $releaseResult = $result.artists[0].releases[0]

            $releaseResult.proposed.isCompilation | Should -Be $true
            $releaseResult.proposed.artistFolderName | Should -Be 'Various'
            $releaseResult.tracks[0].tags.artist | Should -Be 'The Dubliners'
            $releaseResult.tracks[0].tags.albumArtist | Should -Be 'Various'
            $releaseResult.tracks[0].tags.isCompilation | Should -Be $true
            $releaseResult.tracks[1].tags.artist | Should -Be 'Dublin City Ramblers'
            $releaseResult.tracks[1].tags.albumArtist | Should -Be 'Various'
        }

        It 'retries under "Various" and matches when a Various-Artists release is filed under its tracks'' shared folder (real "DIO/1999 - Holy Dio" case)' {
            $root = Join-Path $script:sourceRoot 'DIO' '1999 - Holy Dio'
            $t1 = New-TestAudioFile -Path (Join-Path $root "[01] Blind Guardian - Don't Talk To Stranger.mp3")
            $t2 = New-TestAudioFile -Path (Join-Path $root '[02] Primal Fear - Kill The King.mp3')
            $t3 = New-TestAudioFile -Path (Join-Path $root '[03] Doro - Egypt (The Chains Are On).mp3')

            $tracks = @(
                (New-TestTrack -SourceFilePath $t1 -OriginalFileName "[01] Blind Guardian - Don't Talk To Stranger.mp3" -DetectedTrackNumberInDisc 1 -Format 'mp3' -IsLossless $false -ExistingArtist 'Blind Guardian')
                (New-TestTrack -SourceFilePath $t2 -OriginalFileName '[02] Primal Fear - Kill The King.mp3' -DetectedTrackNumberInDisc 2 -Format 'mp3' -IsLossless $false -ExistingArtist 'Primal Fear')
                (New-TestTrack -SourceFilePath $t3 -OriginalFileName '[03] Doro - Egypt (The Chains Are On).mp3' -DetectedTrackNumberInDisc 3 -Format 'mp3' -IsLossless $false -ExistingArtist 'Doro')
            )
            $release = New-TestRelease -StableKey (Get-TestStableKey -Artist 'DIO' -Album 'Holy Dio' -Year 1999) `
                -RecognizedTitle 'Holy Dio' -RecognizedYear 1999 -SourceFolderPath $root -Tracks $tracks

            New-TestRecognitionFile -Path $script:recognitionPath -SessionId 'test-session' -SourceRoot $script:sourceRoot -Artists @(
                [pscustomobject]@{ recognizedName = 'DIO'; sourcePaths = @($script:sourceRoot); releases = @($release) }
            )

            $script:variousMaster = [pscustomobject]@{
                results = @([pscustomobject]@{ id = 9001; type = 'master'; title = 'Various - Holy Dio'; year = '1999'; format = @('CD', 'Compilation') })
            }
            $script:variousMasterDetail = [pscustomobject]@{ id = 9001; main_release = 5001; year = 1999 }
            $script:variousVersions = [pscustomobject]@{ versions = @([pscustomobject]@{ id = 5001; major_formats = @('CD'); format = 'CD'; released = '1999' }) }
            $script:variousReleaseDetail = [pscustomobject]@{
                id        = 5001
                title     = 'Holy Dio'
                year      = 1999
                country   = 'US'
                artists   = @([pscustomobject]@{ name = 'Various'; id = 194 })
                formats   = @([pscustomobject]@{ name = 'CD'; qty = '1'; descriptions = @('Compilation') })
                images    = @()
                tracklist = @(
                    [pscustomobject]@{ position = '1'; title = "Don't Talk To Stranger"; artists = @([pscustomobject]@{ name = 'Blind Guardian'; join = '' }) }
                    [pscustomobject]@{ position = '2'; title = 'Kill The King'; artists = @([pscustomobject]@{ name = 'Primal Fear'; join = '' }) }
                    [pscustomobject]@{ position = '3'; title = 'Egypt (The Chains Are On)'; artists = @([pscustomobject]@{ name = 'Doro'; join = '' }) }
                )
            }

            $calls = [System.Collections.Generic.List[object]]::new()
            Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
                $calls.Add([pscustomobject]@{ Path = $Path; Query = $Query })
                if ($Path -eq '/database/search') {
                    if ($Query.artist -eq 'Various' -and $Query.type -eq 'master') { return $script:variousMaster }
                    return [pscustomobject]@{ results = @() }
                }
                if ($Path -eq '/masters/9001') { return $script:variousMasterDetail }
                if ($Path -eq '/masters/9001/versions') { return $script:variousVersions }
                if ($Path -eq '/releases/5001') { return $script:variousReleaseDetail }
                return [pscustomobject]@{ results = @() }
            }

            $result = Invoke-ReshelfEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
            $releaseResult = $result.artists[0].releases[0]

            $releaseResult.discogsMatch.status | Should -Be 'matched'
            $releaseResult.proposed.artistFolderName | Should -Be 'Various'
            $releaseResult.proposed.isCompilation | Should -Be $true
            $releaseResult.tracks[0].tags.artist | Should -Be 'Blind Guardian'
            $releaseResult.tracks[0].tags.albumArtist | Should -Be 'Various'
            $releaseResult.tracks[1].tags.artist | Should -Be 'Primal Fear'
            $releaseResult.tracks[2].tags.artist | Should -Be 'Doro'
            $releaseResult.humanReview.required | Should -Be $true
            $releaseResult.humanReview.notes | Should -Match 'Various Artists compilation'

            ($calls | Where-Object { $_.Path -eq '/database/search' -and $_.Query.artist -eq 'DIO' }).Count | Should -BeGreaterThan 0
            ($calls | Where-Object { $_.Path -eq '/database/search' -and $_.Query.artist -eq 'Various' }).Count | Should -BeGreaterThan 0
        }

        It 'falls back to a proposed "Various" compilation (with tag-based track artists) when the Various retry also finds nothing' {
            $root = Join-Path $script:sourceRoot 'DIO' '1999 - Holy Dio'
            $t1 = New-TestAudioFile -Path (Join-Path $root "[01] Blind Guardian - Don't Talk To Stranger.mp3")
            $t2 = New-TestAudioFile -Path (Join-Path $root '[02] Primal Fear - Kill The King.mp3')
            $t3 = New-TestAudioFile -Path (Join-Path $root '[03] Doro - Egypt (The Chains Are On).mp3')

            $tracks = @(
                (New-TestTrack -SourceFilePath $t1 -OriginalFileName "[01] Blind Guardian - Don't Talk To Stranger.mp3" -DetectedTrackNumberInDisc 1 -Format 'mp3' -IsLossless $false -ExistingArtist 'Blind Guardian')
                (New-TestTrack -SourceFilePath $t2 -OriginalFileName '[02] Primal Fear - Kill The King.mp3' -DetectedTrackNumberInDisc 2 -Format 'mp3' -IsLossless $false -ExistingArtist 'Primal Fear')
                (New-TestTrack -SourceFilePath $t3 -OriginalFileName '[03] Doro - Egypt (The Chains Are On).mp3' -DetectedTrackNumberInDisc 3 -Format 'mp3' -IsLossless $false -ExistingArtist 'Doro')
            )
            $release = New-TestRelease -StableKey (Get-TestStableKey -Artist 'DIO' -Album 'Holy Dio' -Year 1999) `
                -RecognizedTitle 'Holy Dio' -RecognizedYear 1999 -SourceFolderPath $root -Tracks $tracks

            New-TestRecognitionFile -Path $script:recognitionPath -SessionId 'test-session' -SourceRoot $script:sourceRoot -Artists @(
                [pscustomobject]@{ recognizedName = 'DIO'; sourcePaths = @($script:sourceRoot); releases = @($release) }
            )

            Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
                [pscustomobject]@{ results = @() }
            }

            $result = Invoke-ReshelfEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
            $releaseResult = $result.artists[0].releases[0]

            $releaseResult.discogsMatch.status | Should -Be 'not-found'
            $releaseResult.proposed.artistFolderName | Should -Be 'Various'
            $releaseResult.proposed.isCompilation | Should -Be $true
            $releaseResult.tracks[0].tags.artist | Should -Be 'Blind Guardian'
            $releaseResult.tracks[1].tags.artist | Should -Be 'Primal Fear'
            $releaseResult.tracks[2].tags.artist | Should -Be 'Doro'
            $releaseResult.humanReview.required | Should -Be $true
            $releaseResult.humanReview.notes | Should -Match 'Various Artists compilation'
        }

        It 'does not retry under "Various" when the folder-artist search already matched' {
            $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Radiohead' '1997 OK Computer' '01 - Airbag.flac')

            $tracks = @(
                (New-TestTrack -SourceFilePath $t1 -OriginalFileName '01 - Airbag.flac' -DetectedTrackNumberInDisc 1)
            )
            $release = New-TestRelease -StableKey (Get-TestStableKey -Artist 'Radiohead' -Album 'OK Computer' -Year 1997) `
                -RecognizedTitle 'OK Computer' -RecognizedYear 1997 -SourceFolderPath (Split-Path $t1) -Tracks $tracks

            New-TestRecognitionFile -Path $script:recognitionPath -SessionId 'test-session' -SourceRoot $script:sourceRoot -Artists @(
                [pscustomobject]@{ recognizedName = 'Radiohead'; sourcePaths = @($script:sourceRoot); releases = @($release) }
            )

            $calls = [System.Collections.Generic.List[object]]::new()
            Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
                $calls.Add([pscustomobject]@{ Path = $Path; Query = $Query })
                if ($Path -eq '/database/search') { return $script:SearchFixture }
                return $script:ReleaseFixture
            }

            $result = Invoke-ReshelfEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
            $releaseResult = $result.artists[0].releases[0]

            $releaseResult.discogsMatch.status | Should -Be 'matched'
            $releaseResult.proposed.artistFolderName | Should -Be 'Radiohead'
            ($calls | Where-Object { $_.Path -eq '/database/search' -and $_.Query.artist -eq 'Various' }).Count | Should -Be 0
        }

        It 'keeps invalid filesystem characters in tags while sanitizing folder and file names' {
            $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'AC-DC' '1980 Back In Black' '01 - Track.flac')

            $tracks = @(
                (New-TestTrack -SourceFilePath $t1 -OriginalFileName '01 - Track.flac' -DetectedTrackNumberInDisc 1 -ExistingTitle 'Rock/Roll: Live')
            )
            $release = New-TestRelease -StableKey (Get-TestStableKey -Artist 'AC/DC' -Album 'Back In Black / Live Edition' -Year 1980) `
                -RecognizedTitle 'Back In Black / Live Edition' -RecognizedYear 1980 -SourceFolderPath (Split-Path $t1) -Tracks $tracks

            New-TestRecognitionFile -Path $script:recognitionPath -SessionId 'test-session' -SourceRoot $script:sourceRoot -Artists @(
                [pscustomobject]@{ recognizedName = 'AC/DC'; sourcePaths = @($script:sourceRoot); releases = @($release) }
            )

            Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
                [pscustomobject]@{ results = @() }
            }

            $result = Invoke-ReshelfEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
            $releaseResult = $result.artists[0].releases[0]

            # Folder/file names must be filesystem-safe.
            $releaseResult.proposed.artistFolderName | Should -Be 'AC_DC'
            $releaseResult.proposed.releaseFolderName | Should -Be '1980 Back In Black _ Live Edition'
            $releaseResult.tracks[0].proposedFileName | Should -Be '01 Rock_Roll_ Live.flac'

            # Tags (and proposedTitle) must keep the original, unsanitized text.
            $releaseResult.proposed.album | Should -Be 'Back In Black / Live Edition'
            $releaseResult.tracks[0].tags.artist | Should -Be 'AC/DC'
            $releaseResult.tracks[0].tags.albumArtist | Should -Be 'AC/DC'
            $releaseResult.tracks[0].tags.album | Should -Be 'Back In Black / Live Edition'
            $releaseResult.tracks[0].tags.title | Should -Be 'Rock/Roll: Live'
            $releaseResult.tracks[0].proposedTitle | Should -Be 'Rock/Roll: Live'
        }

        It 'forces review and falls back to source titles on a Discogs tracklist count mismatch' {
            $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Radiohead' '1997 OK Computer' '01 - Airbag.flac')
            $t2 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Radiohead' '1997 OK Computer' '02 - Paranoid Android.flac')

            $tracks = @(
                (New-TestTrack -SourceFilePath $t1 -OriginalFileName '01 - Airbag.flac' -DetectedTrackNumberInDisc 1)
                (New-TestTrack -SourceFilePath $t2 -OriginalFileName '02 - Paranoid Android.flac' -DetectedTrackNumberInDisc 2)
            )
            $release = New-TestRelease -StableKey (Get-TestStableKey -Artist 'Radiohead' -Album 'OK Computer' -Year 1997) `
                -RecognizedTitle 'OK Computer' -RecognizedYear 1997 -SourceFolderPath (Split-Path $t1) -Tracks $tracks

            New-TestRecognitionFile -Path $script:recognitionPath -SessionId 'test-session' -SourceRoot $script:sourceRoot -Artists @(
                [pscustomobject]@{ recognizedName = 'Radiohead'; sourcePaths = @($script:sourceRoot); releases = @($release) }
            )

            Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
                if ($Path -eq '/database/search') { return $script:SearchFixture }
                return $script:ReleaseFixture
            }

            $result = Invoke-ReshelfEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
            $releaseResult = $result.artists[0].releases[0]

            $releaseResult.humanReview.required | Should -Be $true
            $releaseResult.tracks[0].proposedTitle | Should -Be 'Airbag'
            $releaseResult.tracks[1].proposedTitle | Should -Be 'Paranoid Android'
        }

        It 'falls back to recognized names and forces review on an ambiguous Discogs match' {
            $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Totally Different Band' '2010 Unrelated Album' '01 - Only Track.flac')
            $tracks = @((New-TestTrack -SourceFilePath $t1 -OriginalFileName '01 - Only Track.flac' -DetectedTrackNumberInDisc 1))
            $release = New-TestRelease -StableKey (Get-TestStableKey -Artist 'Some Totally Different Band' -Album 'Unrelated Album' -Year 2010) `
                -RecognizedTitle 'Unrelated Album' -RecognizedYear 2010 -SourceFolderPath (Split-Path $t1) -Tracks $tracks

            New-TestRecognitionFile -Path $script:recognitionPath -SessionId 'test-session' -SourceRoot $script:sourceRoot -Artists @(
                [pscustomobject]@{ recognizedName = 'Some Totally Different Band'; sourcePaths = @($script:sourceRoot); releases = @($release) }
            )

            Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
                if ($Path -eq '/database/search') { return $script:SearchFixture }
                throw 'detail should not be fetched for an ambiguous match'
            }

            $result = Invoke-ReshelfEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
            $releaseResult = $result.artists[0].releases[0]

            $releaseResult.discogsMatch.status | Should -Be 'ambiguous'
            $releaseResult.proposed.artistFolderName | Should -Be 'Some Totally Different Band'
            $releaseResult.proposed.album | Should -Be 'Unrelated Album'
            $releaseResult.humanReview.required | Should -Be $true
        }

        It 'pads track file numbers to -TrackNumberPadWidth even when the track count itself would only need 2 digits' {
            $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 - Track One.flac')
            $t2 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '02 - Track Two.flac')
            $tracks = @(
                (New-TestTrack -SourceFilePath $t1 -OriginalFileName '01 - Track One.flac' -DetectedTrackNumberInDisc 1)
                (New-TestTrack -SourceFilePath $t2 -OriginalFileName '02 - Track Two.flac' -DetectedTrackNumberInDisc 2)
            )
            $release = New-TestRelease -StableKey (Get-TestStableKey -Artist 'Some Band' -Album 'Some Album' -Year 2010) `
                -RecognizedTitle 'Some Album' -RecognizedYear 2010 -SourceFolderPath (Split-Path $t1) -Tracks $tracks

            New-TestRecognitionFile -Path $script:recognitionPath -SessionId 'test-session' -SourceRoot $script:sourceRoot -Artists @(
                [pscustomobject]@{ recognizedName = 'Some Band'; sourcePaths = @($script:sourceRoot); releases = @($release) }
            )

            Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
                [pscustomobject]@{ results = @() }
            }

            $result = Invoke-ReshelfEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot `
                -DataHome $script:dataHome -TrackNumberPadWidth 3
            $releaseResult = $result.artists[0].releases[0]

            $releaseResult.tracks[0].proposedFileName | Should -Be '001 Track One.flac'
            $releaseResult.tracks[1].proposedFileName | Should -Be '002 Track Two.flac'
        }

        It 'sanitizes a reserved-device-name artist and a trailing-dot album title, and records both substitutions in humanReview.notes' {
            $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'CON' '2010 Some Album.' '01 - Only Track.flac')
            $tracks = @((New-TestTrack -SourceFilePath $t1 -OriginalFileName '01 - Only Track.flac' -DetectedTrackNumberInDisc 1))
            $release = New-TestRelease -StableKey (Get-TestStableKey -Artist 'CON' -Album 'Some Album.' -Year 2010) `
                -RecognizedTitle 'Some Album.' -RecognizedYear 2010 -SourceFolderPath (Split-Path $t1) -Tracks $tracks

            New-TestRecognitionFile -Path $script:recognitionPath -SessionId 'test-session' -SourceRoot $script:sourceRoot -Artists @(
                [pscustomobject]@{ recognizedName = 'CON'; sourcePaths = @($script:sourceRoot); releases = @($release) }
            )

            Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
                [pscustomobject]@{ results = @() }
            }

            $result = Invoke-ReshelfEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
            $releaseResult = $result.artists[0].releases[0]

            $releaseResult.proposed.artistFolderName | Should -Be 'CON_'
            $releaseResult.proposed.releaseFolderName | Should -Be '2010 Some Album'
            $releaseResult.humanReview.notes | Should -BeLike "*reserved device name 'CON' suffixed with '_'*"
            $releaseResult.humanReview.notes | Should -BeLike '*trailing dot/space removed*'

            Test-ProposalDocumentJson -Path (Join-Path $script:dataHome 'sessions' 'test-session' 'proposal.json') | Should -Be $true
        }
    }

    Context 'bilingual (Japanese) release naming (session 2026-10-03-0010)' {
        It 'names the album/track "{romanized} = {original}" and shares the bilingual artist folder across every release of the artist, even one that did not itself match' {
            # Release A: Discogs only has a Japanese-only title for it (real case: "ロッキンポ殺し") -
            # matched by the step-1d catalog fallback (track durations), not by title text at all.
            $folderA = Join-Path $script:sourceRoot 'Maximum the Hormone' '2005 Rokkinpo Goroshi'
            $a1 = New-TestAudioFile -Path (Join-Path $folderA '01 - Rokkinpo Goroshi.flac')
            $a2 = New-TestAudioFile -Path (Join-Path $folderA '02 - Nitro Bb Sensou.flac')
            $tracksA = @(
                (New-TestTrack -SourceFilePath $a1 -OriginalFileName '01 - Rokkinpo Goroshi.flac' -DetectedTrackNumberInDisc 1 -ExistingTitle 'Rokkinpo Goroshi' -DurationSeconds 125.0)
                (New-TestTrack -SourceFilePath $a2 -OriginalFileName '02 - Nitro Bb Sensou.flac' -DetectedTrackNumberInDisc 2 -ExistingTitle 'Nitro Bb Sensou' -DurationSeconds 140.0)
            )
            $releaseA = New-TestRelease -StableKey (Get-TestStableKey -Artist 'Maximum the Hormone' -Album 'Rokkinpo Goroshi' -Year 2005) `
                -RecognizedTitle 'Rokkinpo Goroshi' -RecognizedYear 2005 -SourceFolderPath $folderA -Tracks $tracksA

            # Release B: no Discogs match at all (not even the catalog fallback finds anything near
            # its year) - still must end up under the same bilingual artist folder as release A.
            $folderB = Join-Path $script:sourceRoot 'Maximum the Hormone' '1990 Kusoban'
            $b1 = New-TestAudioFile -Path (Join-Path $folderB '01 - Track One.flac')
            $tracksB = @((New-TestTrack -SourceFilePath $b1 -OriginalFileName '01 - Track One.flac' -DetectedTrackNumberInDisc 1))
            $releaseB = New-TestRelease -StableKey (Get-TestStableKey -Artist 'Maximum the Hormone' -Album 'Kusoban' -Year 1990) `
                -RecognizedTitle 'Kusoban' -RecognizedYear 1990 -SourceFolderPath $folderB -Tracks $tracksB

            New-TestRecognitionFile -Path $script:recognitionPath -SessionId 'test-session' -SourceRoot $script:sourceRoot -Artists @(
                [pscustomobject]@{ recognizedName = 'Maximum the Hormone'; sourcePaths = @($script:sourceRoot); releases = @($releaseA, $releaseB) }
            )

            $artistSearch = [pscustomobject]@{ results = @([pscustomobject]@{ id = 500; type = 'artist'; title = 'マキシマム ザ ホルモン' }) }
            $artistDetail = [pscustomobject]@{ id = 500; name = 'マキシマム ザ ホルモン'; namevariations = @('Maximum The Hormone') }
            # Only release A's year (2005) is within the catalog fallback's +/-1 window of itself;
            # release B's year (1990) filters this same single catalog entry out entirely.
            $catalogReleases = [pscustomobject]@{
                releases = @([pscustomobject]@{ id = 99; type = 'release'; role = 'Main'; year = 2005; format = @('CD', 'Album'); title = 'ロッキンポ殺し' })
            }
            $releaseDetailA = [pscustomobject]@{
                id        = 99; title = 'ロッキンポ殺し'; year = 2005; released = '2005-03-02'
                artists   = @([pscustomobject]@{ name = 'マキシマム ザ ホルモン' })
                tracklist = @(
                    [pscustomobject]@{ position = '1'; title = 'ロッキンポ殺し'; duration = '2:05' }
                    [pscustomobject]@{ position = '2'; title = 'ニトロBB戦争'; duration = '2:20' }
                )
            }

            Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
                if ($Path -eq '/database/search' -and $Query.type -eq 'artist') { return $artistSearch }
                if ($Path -eq '/artists/500') { return $artistDetail }
                if ($Path -eq '/database/search') { return [pscustomobject]@{ results = @() } }
                if ($Path -eq '/artists/500/releases') { return $catalogReleases }
                if ($Path -eq '/releases/99') { return $releaseDetailA }
                throw "unexpected path $Path"
            }

            $result = Invoke-ReshelfEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
            $releases = $result.artists[0].releases

            $releaseAResult = $releases | Where-Object { $_.proposed.album -like 'Rokkinpo Goroshi*' }
            $releaseAResult.discogsMatch.status | Should -Be 'matched'
            $releaseAResult.proposed.artistFolderName | Should -Be 'Maximum The Hormone = マキシマム ザ ホルモン'
            $releaseAResult.proposed.album | Should -Be 'Rokkinpo Goroshi = ロッキンポ殺し'
            $releaseAResult.tracks[0].tags.artist | Should -Be 'Maximum The Hormone = マキシマム ザ ホルモン'
            $releaseAResult.tracks[0].tags.albumArtist | Should -Be 'Maximum The Hormone = マキシマム ザ ホルモン'
            $releaseAResult.tracks[0].proposedTitle | Should -Be 'Rokkinpo Goroshi = ロッキンポ殺し'
            $releaseAResult.tracks[1].proposedTitle | Should -Be 'Nitro Bb Sensou = ニトロBB戦争'

            $releaseBResult = $releases | Where-Object { $_.proposed.album -eq 'Kusoban' }
            $releaseBResult.discogsMatch.status | Should -Be 'not-found'
            $releaseBResult.proposed.artistFolderName | Should -Be 'Maximum The Hormone = マキシマム ザ ホルモン'
        }

        It 'does not add a Japanese name to a non-Japanese act even when a Japanese pressing''s release title is partly Japanese (Iron Maiden guard)' {
            $folder = Join-Path $script:sourceRoot 'Iron Maiden' '1981 Killers'
            $t1 = New-TestAudioFile -Path (Join-Path $folder '01 - The Ides Of March.flac')
            $tracks = @((New-TestTrack -SourceFilePath $t1 -OriginalFileName '01 - The Ides Of March.flac' -DetectedTrackNumberInDisc 1))
            $release = New-TestRelease -StableKey (Get-TestStableKey -Artist 'Iron Maiden' -Album 'Killers' -Year 1981) `
                -RecognizedTitle 'Killers' -RecognizedYear 1981 -SourceFolderPath $folder -Tracks $tracks

            New-TestRecognitionFile -Path $script:recognitionPath -SessionId 'test-session' -SourceRoot $script:sourceRoot -Artists @(
                [pscustomobject]@{ recognizedName = 'Iron Maiden'; sourcePaths = @($script:sourceRoot); releases = @($release) }
            )

            # A Japanese pressing: its OWN title carries a Japanese subtitle, but the artist credit
            # itself ("Iron Maiden") stays Latin script - that's the only evidence this feature trusts.
            $releaseSearch = [pscustomobject]@{
                results = @([pscustomobject]@{ id = 321; type = 'release'; title = 'Iron Maiden - Killers (地獄の処刑台)'; year = '1981'; format = @('CD', 'Album') })
            }
            $detail = [pscustomobject]@{
                id        = 321; title = 'Killers (地獄の処刑台)'; year = 1981
                artists   = @([pscustomobject]@{ name = 'Iron Maiden' })
                tracklist = @([pscustomobject]@{ position = '1'; title = 'The Ides Of March' })
            }

            Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
                if ($Path -eq '/database/search' -and $Query.type -eq 'artist') { return [pscustomobject]@{ results = @() } }
                if ($Path -eq '/database/search' -and $Query.type -eq 'master') { return [pscustomobject]@{ results = @() } }
                if ($Path -eq '/database/search') { return $releaseSearch }
                if ($Path -eq '/releases/321') { return $detail }
                throw "unexpected path $Path"
            }

            $result = Invoke-ReshelfEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
            $releaseResult = $result.artists[0].releases[0]

            $releaseResult.discogsMatch.status | Should -Be 'matched'
            $releaseResult.proposed.artistFolderName | Should -Be 'Iron Maiden'
            $releaseResult.tracks[0].tags.albumArtist | Should -Be 'Iron Maiden'
        }
    }

    Context 'cover art' {
        It 'falls back to a local companion cover when Discogs has no images' {
            $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 - Only Track.flac')
            $coverPath = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' 'cover.jpg') -Content 'not-a-real-image'
            $tracks = @((New-TestTrack -SourceFilePath $t1 -OriginalFileName '01 - Only Track.flac' -DetectedTrackNumberInDisc 1))
            $companions = @([pscustomobject]@{ sourcePath = $coverPath; kind = 'cover'; placement = 'loose' })
            $release = New-TestRelease -StableKey (Get-TestStableKey -Artist 'Some Band' -Album 'Some Album' -Year 2010) `
                -RecognizedTitle 'Some Album' -RecognizedYear 2010 -SourceFolderPath (Split-Path $t1) -Tracks $tracks -CompanionFiles $companions

            New-TestRecognitionFile -Path $script:recognitionPath -SessionId 'test-session' -SourceRoot $script:sourceRoot -Artists @(
                [pscustomobject]@{ recognizedName = 'Some Band'; sourcePaths = @($script:sourceRoot); releases = @($release) }
            )

            Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
                [pscustomobject]@{ results = @() }
            }

            $result = Invoke-ReshelfEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
            $releaseResult = $result.artists[0].releases[0]

            $releaseResult.coverArt.candidates.Count | Should -Be 1
            $releaseResult.coverArt.candidates[0].sourceEdition | Should -Be 'existing (local)'
            $releaseResult.coverArt.chosenCandidateUrl | Should -Be $coverPath

            # New-ReshelfCompanionProposal must be wired into the release doc: the loose 'cover.jpg'
            # already starts with a letter, so it's included as-is with no companion-triggered note.
            # (humanReview.required is already true here for an unrelated reason - no Discogs match.)
            $releaseResult.companionFiles.Count | Should -Be 1
            $releaseResult.companionFiles[0].include | Should -Be $true
            $releaseResult.companionFiles[0].proposedFileName | Should -Be 'cover.jpg'
        }

        It 'defaults to an already-embedded cover even when Discogs also has images' {
            $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Radiohead' '1997 OK Computer' '01 - Airbag.flac')
            $embeddedCoverPath = New-TestImageFile -Path (Join-Path $script:dataHome 'embedded-covers' 'existing-cover.jpg')
            $tracks = @((New-TestTrack -SourceFilePath $t1 -OriginalFileName '01 - Airbag.flac' -DetectedTrackNumberInDisc 1 -ExistingCoverArtPath $embeddedCoverPath))
            $release = New-TestRelease -StableKey (Get-TestStableKey -Artist 'Radiohead' -Album 'OK Computer' -Year 1997) `
                -RecognizedTitle 'OK Computer' -RecognizedYear 1997 -SourceFolderPath (Split-Path $t1) -Tracks $tracks

            New-TestRecognitionFile -Path $script:recognitionPath -SessionId 'test-session' -SourceRoot $script:sourceRoot -Artists @(
                [pscustomobject]@{ recognizedName = 'Radiohead'; sourcePaths = @($script:sourceRoot); releases = @($release) }
            )

            Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
                if ($Path -eq '/database/search') { return $script:SearchFixture }
                return $script:ReleaseFixture
            }

            $result = Invoke-ReshelfEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
            $releaseResult = $result.artists[0].releases[0]

            # Discogs matched and has an image (release-response.json fixture), but the track already
            # carries its own embedded cover - that wins by default so a good existing cover isn't
            # silently replaced. The Discogs image still shows up as a candidate the user can switch to.
            $releaseResult.discogsMatch.status | Should -Be 'matched'
            $releaseResult.coverArt.candidates.sourceEdition | Should -Contain 'existing (embedded)'
            $releaseResult.coverArt.candidates.Count | Should -Be 2
            $releaseResult.coverArt.chosenCandidateUrl | Should -Be $embeddedCoverPath
        }

        It 'falls back to a Discogs image when the embedded cover is not a decodable image' {
            # Real case (session 2026-10-03-0008): a track's embedded picture frame was garbage
            # bytes, not a real JPEG - Get-ReshelfImageDimensions can't decode it and returns its
            # 1x1 "undecodable" sentinel. Defaulting to it anyway (the previous behavior) picked a
            # cover that then failed ffmpeg resize at apply time ("No JPEG data found in image").
            $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Radiohead' '1997 OK Computer' '01 - Airbag.flac')
            $embeddedCoverPath = New-TestAudioFile -Path (Join-Path $script:dataHome 'embedded-covers' 'existing-cover.jpg') -Content 'not-a-real-image'
            $tracks = @((New-TestTrack -SourceFilePath $t1 -OriginalFileName '01 - Airbag.flac' -DetectedTrackNumberInDisc 1 -ExistingCoverArtPath $embeddedCoverPath))
            $release = New-TestRelease -StableKey (Get-TestStableKey -Artist 'Radiohead' -Album 'OK Computer' -Year 1997) `
                -RecognizedTitle 'OK Computer' -RecognizedYear 1997 -SourceFolderPath (Split-Path $t1) -Tracks $tracks

            New-TestRecognitionFile -Path $script:recognitionPath -SessionId 'test-session' -SourceRoot $script:sourceRoot -Artists @(
                [pscustomobject]@{ recognizedName = 'Radiohead'; sourcePaths = @($script:sourceRoot); releases = @($release) }
            )

            Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
                if ($Path -eq '/database/search') { return $script:SearchFixture }
                return $script:ReleaseFixture
            }

            $result = Invoke-ReshelfEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
            $releaseResult = $result.artists[0].releases[0]

            $releaseResult.coverArt.candidates.sourceEdition | Should -Not -Contain 'existing (embedded)'
            $releaseResult.coverArt.candidates.Count | Should -Be 1
            $releaseResult.coverArt.chosenCandidateUrl | Should -Not -Be $embeddedCoverPath
        }

        It 'renames a digit-starting loose companion and forces review, end to end through Invoke-ReshelfEditProposal' {
            $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 - Only Track.flac')
            $photoPath = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 back.jpg')
            $tracks = @((New-TestTrack -SourceFilePath $t1 -OriginalFileName '01 - Only Track.flac' -DetectedTrackNumberInDisc 1))
            $companions = @([pscustomobject]@{ sourcePath = $photoPath; kind = 'photo'; placement = 'loose' })
            $release = New-TestRelease -StableKey (Get-TestStableKey -Artist 'Some Band' -Album 'Some Album' -Year 2010) `
                -RecognizedTitle 'Some Album' -RecognizedYear 2010 -SourceFolderPath (Split-Path $t1) -Tracks $tracks -CompanionFiles $companions

            New-TestRecognitionFile -Path $script:recognitionPath -SessionId 'test-session' -SourceRoot $script:sourceRoot -Artists @(
                [pscustomobject]@{ recognizedName = 'Some Band'; sourcePaths = @($script:sourceRoot); releases = @($release) }
            )

            Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
                [pscustomobject]@{ results = @() }
            }

            $result = Invoke-ReshelfEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
            $releaseResult = $result.artists[0].releases[0]

            $releaseResult.companionFiles[0].proposedFileName | Should -Be 'Photo 01 back.jpg'
            $releaseResult.humanReview.required | Should -Be $true
            $releaseResult.humanReview.notes | Should -BeLike '*renamed*Photo 01 back.jpg*'
        }

        It 'has empty candidates and forces review when no cover art is available anywhere' {
            $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 - Only Track.flac')
            $tracks = @((New-TestTrack -SourceFilePath $t1 -OriginalFileName '01 - Only Track.flac' -DetectedTrackNumberInDisc 1))
            $release = New-TestRelease -StableKey (Get-TestStableKey -Artist 'Some Band' -Album 'Some Album' -Year 2010) `
                -RecognizedTitle 'Some Album' -RecognizedYear 2010 -SourceFolderPath (Split-Path $t1) -Tracks $tracks

            New-TestRecognitionFile -Path $script:recognitionPath -SessionId 'test-session' -SourceRoot $script:sourceRoot -Artists @(
                [pscustomobject]@{ recognizedName = 'Some Band'; sourcePaths = @($script:sourceRoot); releases = @($release) }
            )

            Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
                [pscustomobject]@{ results = @() }
            }

            $result = Invoke-ReshelfEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
            $releaseResult = $result.artists[0].releases[0]

            $releaseResult.coverArt.candidates.Count | Should -Be 0
            $releaseResult.coverArt.chosenCandidateUrl | Should -BeNullOrEmpty
            $releaseResult.humanReview.required | Should -Be $true
        }
    }

    Context 'target comparison' {
        BeforeEach {
            Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
                [pscustomobject]@{ results = @() }
            }
        }

        It 'proposes create-new when the target has no matching release' {
            $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 - Track.flac')
            $tracks = @((New-TestTrack -SourceFilePath $t1 -OriginalFileName '01 - Track.flac' -DetectedTrackNumberInDisc 1))
            $release = New-TestRelease -StableKey (Get-TestStableKey -Artist 'Some Band' -Album 'Some Album' -Year 2010) `
                -RecognizedTitle 'Some Album' -RecognizedYear 2010 -SourceFolderPath (Split-Path $t1) -Tracks $tracks

            New-TestRecognitionFile -Path $script:recognitionPath -SessionId 'test-session' -SourceRoot $script:sourceRoot -Artists @(
                [pscustomobject]@{ recognizedName = 'Some Band'; sourcePaths = @($script:sourceRoot); releases = @($release) }
            )

            $result = Invoke-ReshelfEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
            $result.artists[0].releases[0].targetAction | Should -Be 'create-new'
        }

        It 'proposes skip-existing-identical when the target already has the same file set' {
            $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 Track.flac') -Content 'same-content'
            New-TestAudioFile -Path (Join-Path $script:targetRoot 'Some Band' '2010 Some Album' '01 Track.flac') -Content 'same-content' | Out-Null

            $tracks = @((New-TestTrack -SourceFilePath $t1 -OriginalFileName '01 Track.flac' -DetectedTrackNumberInDisc 1))
            $release = New-TestRelease -StableKey (Get-TestStableKey -Artist 'Some Band' -Album 'Some Album' -Year 2010) `
                -RecognizedTitle 'Some Album' -RecognizedYear 2010 -SourceFolderPath (Split-Path $t1) -Tracks $tracks

            New-TestRecognitionFile -Path $script:recognitionPath -SessionId 'test-session' -SourceRoot $script:sourceRoot -Artists @(
                [pscustomobject]@{ recognizedName = 'Some Band'; sourcePaths = @($script:sourceRoot); releases = @($release) }
            )

            $result = Invoke-ReshelfEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
            $result.artists[0].releases[0].targetAction | Should -Be 'skip-existing-identical'
        }

        It 'proposes skip-existing-identical via a valid apply-log entry, even though the target file was renamed and re-tagged' {
            # Regression test: Implementation (plan/08) renames every target file and rewrites its
            # tags on apply, so its name|size hash can never equal the source's again - without the
            # apply-log fallback below, this would incorrectly fall through to 'conflict'.
            $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 - Track.flac') -Content 'source-content'
            $targetReleasePath = Join-Path $script:targetRoot 'Some Band' '2010 Some Album'
            New-TestAudioFile -Path (Join-Path $targetReleasePath '01 Track.flac') -Content 'source-content-plus-written-tags' | Out-Null

            $tracks = @((New-TestTrack -SourceFilePath $t1 -OriginalFileName '01 - Track.flac' -DetectedTrackNumberInDisc 1))
            $stableKey = Get-TestStableKey -Artist 'Some Band' -Album 'Some Album' -Year 2010
            $release = New-TestRelease -StableKey $stableKey `
                -RecognizedTitle 'Some Album' -RecognizedYear 2010 -SourceFolderPath (Split-Path $t1) -Tracks $tracks

            New-TestRecognitionFile -Path $script:recognitionPath -SessionId 'test-session' -SourceRoot $script:sourceRoot -Artists @(
                [pscustomobject]@{ recognizedName = 'Some Band'; sourcePaths = @($script:sourceRoot); releases = @($release) }
            )

            $sourceHash = Get-TestFileSetHash -FilePaths @($t1)
            Add-TestApplyLogEntry -StableKey $stableKey -TargetPath $targetReleasePath -SourceFileSetHash $sourceHash

            $result = Invoke-ReshelfEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
            $result.artists[0].releases[0].targetAction | Should -Be 'skip-existing-identical'
        }

        It 'proposes conflict, not skip-existing-identical, when the apply-log entry no longer matches the current source' {
            # The source changed after the recorded apply (a different file content/hash) - the
            # stale apply-log entry must not force a skip; the ordinary target-hash comparison
            # below correctly reports conflict instead.
            $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 - Track.flac') -Content 'changed-source-content'
            $targetReleasePath = Join-Path $script:targetRoot 'Some Band' '2010 Some Album'
            New-TestAudioFile -Path (Join-Path $targetReleasePath '01 Track.flac') -Content 'stale-target-content' | Out-Null

            $tracks = @((New-TestTrack -SourceFilePath $t1 -OriginalFileName '01 - Track.flac' -DetectedTrackNumberInDisc 1))
            $stableKey = Get-TestStableKey -Artist 'Some Band' -Album 'Some Album' -Year 2010
            $release = New-TestRelease -StableKey $stableKey `
                -RecognizedTitle 'Some Album' -RecognizedYear 2010 -SourceFolderPath (Split-Path $t1) -Tracks $tracks

            New-TestRecognitionFile -Path $script:recognitionPath -SessionId 'test-session' -SourceRoot $script:sourceRoot -Artists @(
                [pscustomobject]@{ recognizedName = 'Some Band'; sourcePaths = @($script:sourceRoot); releases = @($release) }
            )

            # Recorded hash deliberately doesn't match $t1's current content.
            Add-TestApplyLogEntry -StableKey $stableKey -TargetPath $targetReleasePath -SourceFileSetHash 'stale-hash-from-a-prior-apply'

            $result = Invoke-ReshelfEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
            $result.artists[0].releases[0].targetAction | Should -Be 'conflict'
        }

        It 'proposes conflict, not skip-existing-identical, when the apply-log entry is a failed attempt' {
            $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 - Track.flac') -Content 'source-content'
            $targetReleasePath = Join-Path $script:targetRoot 'Some Band' '2010 Some Album'
            New-TestAudioFile -Path (Join-Path $targetReleasePath '01 Track.flac') -Content 'partially-written-content' | Out-Null

            $tracks = @((New-TestTrack -SourceFilePath $t1 -OriginalFileName '01 - Track.flac' -DetectedTrackNumberInDisc 1))
            $stableKey = Get-TestStableKey -Artist 'Some Band' -Album 'Some Album' -Year 2010
            $release = New-TestRelease -StableKey $stableKey `
                -RecognizedTitle 'Some Album' -RecognizedYear 2010 -SourceFolderPath (Split-Path $t1) -Tracks $tracks

            New-TestRecognitionFile -Path $script:recognitionPath -SessionId 'test-session' -SourceRoot $script:sourceRoot -Artists @(
                [pscustomobject]@{ recognizedName = 'Some Band'; sourcePaths = @($script:sourceRoot); releases = @($release) }
            )

            $sourceHash = Get-TestFileSetHash -FilePaths @($t1)
            Add-TestApplyLogEntry -StableKey $stableKey -TargetPath $targetReleasePath -SourceFileSetHash $sourceHash -Status 'failed'

            $result = Invoke-ReshelfEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
            $result.artists[0].releases[0].targetAction | Should -Be 'conflict'
        }

        It 'proposes update-existing/replace-existing when a lossless source would upgrade a lossy target' {
            $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 Track.flac') -Content 'lossless-content'
            New-TestAudioFile -Path (Join-Path $script:targetRoot 'Some Band' '2010 Some Album' '01 Track.mp3') -Content 'lossy-content' | Out-Null

            $tracks = @((New-TestTrack -SourceFilePath $t1 -OriginalFileName '01 Track.flac' -DetectedTrackNumberInDisc 1 -Format 'flac' -IsLossless $true))
            $release = New-TestRelease -StableKey (Get-TestStableKey -Artist 'Some Band' -Album 'Some Album' -Year 2010) `
                -RecognizedTitle 'Some Album' -RecognizedYear 2010 -SourceFolderPath (Split-Path $t1) -Tracks $tracks

            New-TestRecognitionFile -Path $script:recognitionPath -SessionId 'test-session' -SourceRoot $script:sourceRoot -Artists @(
                [pscustomobject]@{ recognizedName = 'Some Band'; sourcePaths = @($script:sourceRoot); releases = @($release) }
            )

            $result = Invoke-ReshelfEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
            $releaseResult = $result.artists[0].releases[0]

            $releaseResult.targetAction | Should -Be 'update-existing'
            $releaseResult.lossyLossless.action | Should -Be 'replace-existing'
        }

        It 'proposes update-existing/replace-existing via the apply-log when the source stableKey differs from the target folder''s own key (plan/12 milestone 7)' {
            # Real case: source folder "PULSAR OLYMP - 94Shine" gives a stableKey that
            # Build-ReshelfTargetIndex never recomputes from the target folder "Pulsar Olymp\2015 94 Shine".
            $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'SOME BAND - SomeAlbum' '01 Track.flac') -Content 'lossless-content'
            $targetReleasePath = Join-Path $script:targetRoot 'Some Band' '2010 Some Album'
            New-TestAudioFile -Path (Join-Path $targetReleasePath '01 Track.mp3') -Content 'lossy-content' | Out-Null

            $stableKey = Get-TestStableKey -Artist 'SOME BAND' -Album 'SomeAlbum' -Year $null
            $tracks = @((New-TestTrack -SourceFilePath $t1 -OriginalFileName '01 Track.flac' -DetectedTrackNumberInDisc 1 -Format 'flac' -IsLossless $true))
            $release = New-TestRelease -StableKey $stableKey -RecognizedTitle 'Some Album' -RecognizedYear 2010 -SourceFolderPath (Split-Path $t1) -Tracks $tracks
            New-TestRecognitionFile -Path $script:recognitionPath -SessionId 'test-session' -SourceRoot $script:sourceRoot -Artists @(
                [pscustomobject]@{ recognizedName = 'Some Band'; sourcePaths = @($script:sourceRoot); releases = @($release) }
            )
            Add-TestApplyLogEntry -StableKey $stableKey -TargetPath $targetReleasePath -SourceFileSetHash 'hash-of-the-earlier-mp3-source'
            Add-TestLossyTrackingEntry -StableKey $stableKey -Artist 'Some Band' -Album 'Some Album' -Year 2010 `
                -TargetPath $targetReleasePath -Format 'mp3' -DataHome $script:dataHome

            $result = Invoke-ReshelfEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
            $releaseResult = $result.artists[0].releases[0]

            $releaseResult.targetAction | Should -Be 'update-existing'
            $releaseResult.lossyLossless.action | Should -Be 'replace-existing'
        }

        It 'proposes update-existing/replace-existing when a lossy folder sits at the proposed path, even with no apply-log entry and a different stableKey' {
            $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'SOME BAND - SomeAlbum' '01 Track.flac') -Content 'lossless-content'
            New-TestAudioFile -Path (Join-Path $script:targetRoot 'Some Band' '2010 Some Album' '01 Track.mp3') -Content 'lossy-content' | Out-Null

            $tracks = @((New-TestTrack -SourceFilePath $t1 -OriginalFileName '01 Track.flac' -DetectedTrackNumberInDisc 1 -Format 'flac' -IsLossless $true))
            $release = New-TestRelease -StableKey (Get-TestStableKey -Artist 'SOME BAND' -Album 'SomeAlbum' -Year $null) `
                -RecognizedTitle 'Some Album' -RecognizedYear 2010 -SourceFolderPath (Split-Path $t1) -Tracks $tracks
            New-TestRecognitionFile -Path $script:recognitionPath -SessionId 'test-session' -SourceRoot $script:sourceRoot -Artists @(
                [pscustomobject]@{ recognizedName = 'Some Band'; sourcePaths = @($script:sourceRoot); releases = @($release) }
            )

            $result = Invoke-ReshelfEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
            $releaseResult = $result.artists[0].releases[0]

            $releaseResult.targetAction | Should -Be 'update-existing'
            $releaseResult.lossyLossless.action | Should -Be 'replace-existing'
        }

        It 'only warns (previously-lossy-different-location) when the applied lossy folder is under an older name than the proposed path' {
            $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 Track.flac') -Content 'lossless-content'
            $oldPath = Join-Path $script:targetRoot 'Some Band' '2010 Some Album (Old Name)'
            New-TestAudioFile -Path (Join-Path $oldPath '01 Track.mp3') -Content 'lossy-content' | Out-Null

            $stableKey = Get-TestStableKey -Artist 'Some Band' -Album 'Some Album' -Year 2010
            $tracks = @((New-TestTrack -SourceFilePath $t1 -OriginalFileName '01 Track.flac' -DetectedTrackNumberInDisc 1 -Format 'flac' -IsLossless $true))
            $release = New-TestRelease -StableKey $stableKey -RecognizedTitle 'Some Album' -RecognizedYear 2010 -SourceFolderPath (Split-Path $t1) -Tracks $tracks
            New-TestRecognitionFile -Path $script:recognitionPath -SessionId 'test-session' -SourceRoot $script:sourceRoot -Artists @(
                [pscustomobject]@{ recognizedName = 'Some Band'; sourcePaths = @($script:sourceRoot); releases = @($release) }
            )
            Add-TestApplyLogEntry -StableKey $stableKey -TargetPath $oldPath -SourceFileSetHash 'hash-of-the-earlier-mp3-source'

            $result = Invoke-ReshelfEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
            $releaseResult = $result.artists[0].releases[0]

            $releaseResult.targetAction | Should -Be 'create-new'
            $releaseResult.lossyLossless.action | Should -Be 'previously-lossy-different-location'
            $releaseResult.lossyLossless.previousLossy.targetPath | Should -Be $oldPath
            $releaseResult.lossyLossless.previousLossy.format | Should -Be 'mp3'
            $releaseResult.humanReview.required | Should -Be $true
            # The fallback previousLossy (no ledger row) must still satisfy the schema's required fields.
            Test-ProposalDocumentJson -Path (Join-Path $script:dataHome 'sessions' 'test-session' 'proposal.json') | Should -Be $true
        }

        It 'proposes conflict when the target differs from the source and it is not a lossy-to-lossless upgrade' {
            $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 Track.flac') -Content 'source-content'
            New-TestAudioFile -Path (Join-Path $script:targetRoot 'Some Band' '2010 Some Album' '01 Track.flac') -Content 'different-target-content' | Out-Null

            $tracks = @((New-TestTrack -SourceFilePath $t1 -OriginalFileName '01 Track.flac' -DetectedTrackNumberInDisc 1))
            $release = New-TestRelease -StableKey (Get-TestStableKey -Artist 'Some Band' -Album 'Some Album' -Year 2010) `
                -RecognizedTitle 'Some Album' -RecognizedYear 2010 -SourceFolderPath (Split-Path $t1) -Tracks $tracks

            New-TestRecognitionFile -Path $script:recognitionPath -SessionId 'test-session' -SourceRoot $script:sourceRoot -Artists @(
                [pscustomobject]@{ recognizedName = 'Some Band'; sourcePaths = @($script:sourceRoot); releases = @($release) }
            )

            $result = Invoke-ReshelfEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
            $releaseResult = $result.artists[0].releases[0]

            $releaseResult.targetAction | Should -Be 'conflict'
            $releaseResult.humanReview.required | Should -Be $true
        }

        It 'resolves a same-stable-key duplicate within one session against the first occurrence' {
            $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Copy One' 'Some Band' '2010 Some Album' '01 Track.flac') -Content 'copy-one'
            $t2 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Copy Two' 'Some Band' '2010 Some Album' '01 Track.flac') -Content 'copy-two-different'

            $stableKey = Get-TestStableKey -Artist 'Some Band' -Album 'Some Album' -Year 2010
            $release1 = New-TestRelease -StableKey $stableKey -RecognizedTitle 'Some Album' -RecognizedYear 2010 `
                -SourceFolderPath (Split-Path $t1) -Tracks @((New-TestTrack -SourceFilePath $t1 -OriginalFileName '01 Track.flac' -DetectedTrackNumberInDisc 1))
            $release2 = New-TestRelease -StableKey $stableKey -RecognizedTitle 'Some Album' -RecognizedYear 2010 `
                -SourceFolderPath (Split-Path $t2) -Tracks @((New-TestTrack -SourceFilePath $t2 -OriginalFileName '01 Track.flac' -DetectedTrackNumberInDisc 1))

            New-TestRecognitionFile -Path $script:recognitionPath -SessionId 'test-session' -SourceRoot $script:sourceRoot -Artists @(
                [pscustomobject]@{ recognizedName = 'Some Band'; sourcePaths = @($script:sourceRoot); releases = @($release1, $release2) }
            )

            $result = Invoke-ReshelfEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
            $releases = $result.artists[0].releases

            $releases[0].targetAction | Should -Be 'create-new'
            $releases[1].targetAction | Should -Be 'conflict'
        }
    }

    Context 'lossy tracking' {
        BeforeEach {
            Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
                [pscustomobject]@{ results = @() }
            }
        }

        It 'creates a pending-upgrade ledger entry for a lossy source release' {
            $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 Track.mp3')
            $tracks = @((New-TestTrack -SourceFilePath $t1 -OriginalFileName '01 Track.mp3' -DetectedTrackNumberInDisc 1 -Format 'mp3' -IsLossless $false))
            $release = New-TestRelease -StableKey (Get-TestStableKey -Artist 'Some Band' -Album 'Some Album' -Year 2010) `
                -RecognizedTitle 'Some Album' -RecognizedYear 2010 -SourceFolderPath (Split-Path $t1) -Tracks $tracks

            New-TestRecognitionFile -Path $script:recognitionPath -SessionId 'test-session' -SourceRoot $script:sourceRoot -Artists @(
                [pscustomobject]@{ recognizedName = 'Some Band'; sourcePaths = @($script:sourceRoot); releases = @($release) }
            )

            $result = Invoke-ReshelfEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
            $releaseResult = $result.artists[0].releases[0]

            $releaseResult.lossyLossless.isLossy | Should -Be $true
            $releaseResult.lossyLossless.action | Should -Be 'log-for-upgrade'

            $entry = Get-TestLossyTrackingEntry -StableKey $releaseResult.stableKey -DataHome $script:dataHome
            $entry | Should -Not -BeNullOrEmpty
            $entry.status | Should -Be 'pending-upgrade'
        }

        It 'leaves a pre-seeded ignored ledger entry as ignored after a run touches the same release' {
            $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 Track.mp3')
            $stableKey = Get-TestStableKey -Artist 'Some Band' -Album 'Some Album' -Year 2010

            Add-TestLossyTrackingEntry -StableKey $stableKey -Artist 'Some Band' -Album 'Some Album' -Year 2010 `
                -TargetPath (Join-Path $script:targetRoot 'Some Band' '2010 Some Album') -Format 'mp3' -DataHome $script:dataHome
            $ledgerPath = Join-Path $script:dataHome 'lossy-tracking.json'
            $ledger = Get-Content -LiteralPath $ledgerPath -Raw | ConvertFrom-Json
            $ledger[0].status = 'ignored'
            Set-Content -LiteralPath $ledgerPath -Value (ConvertTo-Json -InputObject @($ledger) -Depth 10)

            $tracks = @((New-TestTrack -SourceFilePath $t1 -OriginalFileName '01 Track.mp3' -DetectedTrackNumberInDisc 1 -Format 'mp3' -IsLossless $false))
            $release = New-TestRelease -StableKey $stableKey -RecognizedTitle 'Some Album' -RecognizedYear 2010 -SourceFolderPath (Split-Path $t1) -Tracks $tracks

            New-TestRecognitionFile -Path $script:recognitionPath -SessionId 'test-session' -SourceRoot $script:sourceRoot -Artists @(
                [pscustomobject]@{ recognizedName = 'Some Band'; sourcePaths = @($script:sourceRoot); releases = @($release) }
            )

            Invoke-ReshelfEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome | Out-Null

            $entry = Get-TestLossyTrackingEntry -StableKey $stableKey -DataHome $script:dataHome
            $entry.status | Should -Be 'ignored'
        }

        It 'flags previously-lossy-different-location when a lossless re-import matches a pending-upgrade ledger entry by name, not stableKey, and the old lossy folder still exists' {
            # Real case (plan/12 milestone 3, UI review feedback): "The Egg\2006 Forwards Special
            # Edition" (mp3) was already tracked, then re-imported from a differently-named source
            # folder "The Egg\2006 Forwards" (lossless) - a different stableKey (derived from the
            # recognized folder name), but unmistakably the same release once you compare
            # artist/album/year.
            $oldLossyPath = Join-Path $script:targetRoot 'The Egg' '2006 Forwards Special Edition'
            New-TestAudioFile -Path (Join-Path $oldLossyPath '01 Track.mp3') -Content 'old-lossy' | Out-Null
            $oldStableKey = Get-TestStableKey -Artist 'The Egg' -Album 'Forwards Special Edition' -Year 2006
            Add-TestLossyTrackingEntry -StableKey $oldStableKey -Artist 'The Egg' -Album 'Forwards Special Edition' -Year 2006 `
                -TargetPath $oldLossyPath -Format 'mp3' -DataHome $script:dataHome

            $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'The Egg' '2006 Forwards' '01 Track.flac') -Content 'new-lossless'
            $tracks = @((New-TestTrack -SourceFilePath $t1 -OriginalFileName '01 Track.flac' -DetectedTrackNumberInDisc 1))
            $newStableKey = Get-TestStableKey -Artist 'The Egg' -Album 'Forwards' -Year 2006
            $release = New-TestRelease -StableKey $newStableKey -RecognizedTitle 'Forwards' -RecognizedYear 2006 -SourceFolderPath (Split-Path $t1) -Tracks $tracks

            New-TestRecognitionFile -Path $script:recognitionPath -SessionId 'test-session' -SourceRoot $script:sourceRoot -Artists @(
                [pscustomobject]@{ recognizedName = 'The Egg'; sourcePaths = @($script:sourceRoot); releases = @($release) }
            )

            $result = Invoke-ReshelfEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
            $releaseResult = $result.artists[0].releases[0]

            $releaseResult.targetAction | Should -Be 'create-new'
            $releaseResult.lossyLossless.action | Should -Be 'previously-lossy-different-location'
            $releaseResult.lossyLossless.previousLossy.targetPath | Should -Be $oldLossyPath
            $releaseResult.lossyLossless.previousLossy.targetExists | Should -Be $true
            $releaseResult.humanReview.required | Should -Be $true

            # Apply must never touch the old folder on its own - it's out of scope for this run
            # entirely (a different stableKey, a different proposed target path).
            Test-Path -LiteralPath $oldLossyPath | Should -Be $true
            (Get-TestLossyTrackingEntry -StableKey $oldStableKey -DataHome $script:dataHome).status | Should -Be 'pending-upgrade'
        }

        It 'flags previously-lossy-target-missing when the ledger''s old target folder no longer exists' {
            $oldStableKey = Get-TestStableKey -Artist 'Some Band' -Album 'Some Album (Deluxe Edition)' -Year 2010
            Add-TestLossyTrackingEntry -StableKey $oldStableKey -Artist 'Some Band' -Album 'Some Album (Deluxe Edition)' -Year 2010 `
                -TargetPath (Join-Path $script:targetRoot 'Some Band' 'Deleted Folder') -Format 'mp3' -DataHome $script:dataHome

            $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 Track.flac')
            $tracks = @((New-TestTrack -SourceFilePath $t1 -OriginalFileName '01 Track.flac' -DetectedTrackNumberInDisc 1))
            $release = New-TestRelease -StableKey (Get-TestStableKey -Artist 'Some Band' -Album 'Some Album' -Year 2010) `
                -RecognizedTitle 'Some Album' -RecognizedYear 2010 -SourceFolderPath (Split-Path $t1) -Tracks $tracks

            New-TestRecognitionFile -Path $script:recognitionPath -SessionId 'test-session' -SourceRoot $script:sourceRoot -Artists @(
                [pscustomobject]@{ recognizedName = 'Some Band'; sourcePaths = @($script:sourceRoot); releases = @($release) }
            )

            $result = Invoke-ReshelfEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
            $releaseResult = $result.artists[0].releases[0]

            $releaseResult.lossyLossless.action | Should -Be 'previously-lossy-target-missing'
            $releaseResult.lossyLossless.previousLossy.targetExists | Should -Be $false
            $releaseResult.humanReview.required | Should -Be $true
        }

        It 'does not flag previously-lossy when the ledger entry is already ignored' {
            $oldStableKey = Get-TestStableKey -Artist 'Some Band' -Album 'Some Album (Deluxe Edition)' -Year 2010
            Add-TestLossyTrackingEntry -StableKey $oldStableKey -Artist 'Some Band' -Album 'Some Album (Deluxe Edition)' -Year 2010 `
                -TargetPath (Join-Path $script:targetRoot 'Some Band' 'Old Folder') -Format 'mp3' -DataHome $script:dataHome
            $ledgerPath = Join-Path $script:dataHome 'lossy-tracking.json'
            $ledger = Get-Content -LiteralPath $ledgerPath -Raw | ConvertFrom-Json
            $ledger[0].status = 'ignored'
            Set-Content -LiteralPath $ledgerPath -Value (ConvertTo-Json -InputObject @($ledger) -Depth 10)

            $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 Track.flac')
            $tracks = @((New-TestTrack -SourceFilePath $t1 -OriginalFileName '01 Track.flac' -DetectedTrackNumberInDisc 1))
            $release = New-TestRelease -StableKey (Get-TestStableKey -Artist 'Some Band' -Album 'Some Album' -Year 2010) `
                -RecognizedTitle 'Some Album' -RecognizedYear 2010 -SourceFolderPath (Split-Path $t1) -Tracks $tracks

            New-TestRecognitionFile -Path $script:recognitionPath -SessionId 'test-session' -SourceRoot $script:sourceRoot -Artists @(
                [pscustomobject]@{ recognizedName = 'Some Band'; sourcePaths = @($script:sourceRoot); releases = @($release) }
            )

            $result = Invoke-ReshelfEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
            $releaseResult = $result.artists[0].releases[0]

            $releaseResult.lossyLossless.action | Should -Be 'none'
        }
    }

    It 'carries Recognition''s own needsReview/reviewReasons into humanReview.required, even with a clean Discogs match' {
        $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Radiohead' '1997 OK Computer' '01 - Airbag.flac')
        $tracks = @((New-TestTrack -SourceFilePath $t1 -OriginalFileName '01 - Airbag.flac' -DetectedTrackNumberInDisc 1))
        $release = New-TestRelease -StableKey (Get-TestStableKey -Artist 'Radiohead' -Album 'OK Computer' -Year 1997) `
            -RecognizedTitle 'OK Computer' -RecognizedYear 1997 -SourceFolderPath (Split-Path $t1) -Tracks $tracks `
            -NeedsReview $true -ReviewReasons @('artist-name-split-from-folder-name')

        New-TestRecognitionFile -Path $script:recognitionPath -SessionId 'test-session' -SourceRoot $script:sourceRoot -Artists @(
            [pscustomobject]@{ recognizedName = 'Radiohead'; sourcePaths = @($script:sourceRoot); releases = @($release) }
        )

        Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
            if ($Path -eq '/database/search') { return $script:SearchFixture }
            return $script:ReleaseFixture
        }

        $result = Invoke-ReshelfEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
        $releaseResult = $result.artists[0].releases[0]

        # This fixture's Discogs mock is a clean, matching, threshold-passing result (same as the
        # "produces correct names and tags" test above) - proving the carryover fires independently
        # of EditProposal's own checks, not just when one of them happens to also require review.
        $releaseResult.discogsMatch.status | Should -Be 'matched'
        $releaseResult.humanReview.required | Should -Be $true
        $releaseResult.humanReview.notes | Should -BeLike '*artist-name-split-from-folder-name*'
    }

    It 'writes a proposal.json that validates against the proposal schema' {
        $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 Track.flac')
        $tracks = @((New-TestTrack -SourceFilePath $t1 -OriginalFileName '01 Track.flac' -DetectedTrackNumberInDisc 1))
        $release = New-TestRelease -StableKey (Get-TestStableKey -Artist 'Some Band' -Album 'Some Album' -Year 2010) `
            -RecognizedTitle 'Some Album' -RecognizedYear 2010 -SourceFolderPath (Split-Path $t1) -Tracks $tracks

        New-TestRecognitionFile -Path $script:recognitionPath -SessionId 'test-session' -SourceRoot $script:sourceRoot -Artists @(
            [pscustomobject]@{ recognizedName = 'Some Band'; sourcePaths = @($script:sourceRoot); releases = @($release) }
        )

        Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
            [pscustomobject]@{ results = @() }
        }

        Invoke-ReshelfEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome | Out-Null

        $proposalPath = Join-Path $script:dataHome 'sessions' 'test-session' 'proposal.json'
        Test-ProposalDocumentJson -Path $proposalPath | Should -Be $true
    }
}

Describe 'Update-ReshelfReleaseForDiscogsSelection' {
    BeforeEach {
        $script:dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:sourceRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:targetRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:targetRoot -Force | Out-Null
    }

    # Simulates the real bug: a release that came back 'ambiguous' from Resolve-ReshelfDiscogsMatch
    # (so its tracks still carry Recognition's own placeholder/source titles) then has the user pick
    # one of the candidates the UI showed - this is the recompute that must follow that pick.
    It 'recomputes track titles, album/artist names, cover art, and target action from the chosen candidate' {
        $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Amagrama' '2005 Volumen 1' '01 - Track 1.flac')
        $t2 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Amagrama' '2005 Volumen 1' '02 - Track 2.flac')
        $t3 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Amagrama' '2005 Volumen 1' '03 - Track 3.flac')

        $tracks = @(
            (New-TestTrack -SourceFilePath $t1 -OriginalFileName '01 - Track 1.flac' -DetectedTrackNumberInDisc 1)
            (New-TestTrack -SourceFilePath $t2 -OriginalFileName '02 - Track 2.flac' -DetectedTrackNumberInDisc 2)
            (New-TestTrack -SourceFilePath $t3 -OriginalFileName '03 - Track 3.flac' -DetectedTrackNumberInDisc 3)
        )
        $release = New-TestRelease -StableKey (Get-TestStableKey -Artist 'Amagrama' -Album 'Volumen 1' -Year 2005) `
            -RecognizedTitle 'Volumen 1' -RecognizedYear 2005 -SourceFolderPath (Split-Path $t1) -Tracks $tracks `
            -NeedsReview $true -ReviewReasons @('Discogs match status: ambiguous')
        $candidates = @(
            [pscustomobject]@{ releaseId = 265498; title = 'Radiohead - OK Computer'; year = 1997; format = 'CD, Album'; score = 0.7868 }
        )
        $release | Add-Member -NotePropertyName discogsMatch -NotePropertyValue ([pscustomobject]@{
                status            = 'ambiguous'
                selectedReleaseId = $null
                candidates        = $candidates
            })

        Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
            $script:ReleaseFixture
        }

        $updated = Update-ReshelfReleaseForDiscogsSelection -Release $release -SelectedReleaseId 265498 -SiblingReleases @() `
            -ArtistName 'Amagrama' -TargetRoot $script:targetRoot -ReleaseFolderTemplate '{year} {album}' `
            -TrackFileTemplate '{trackNumber} {title}' -CoverMaxDimension 600 -DataHome $script:dataHome

        $updated.discogsMatch.status | Should -Be 'matched'
        $updated.discogsMatch.selectedReleaseId | Should -Be 265498
        # The candidate list itself (what the UI's radio picker renders) must survive unchanged.
        $updated.discogsMatch.candidates | Should -Be $candidates

        $updated.proposed.artistFolderName | Should -Be 'Radiohead'
        $updated.proposed.album | Should -Be 'OK Computer'
        $updated.proposed.year | Should -Be 1997

        $updated.tracks[0].proposedTitle | Should -Be 'Airbag'
        $updated.tracks[1].proposedTitle | Should -Be 'Paranoid Android'
        $updated.tracks[2].proposedTitle | Should -Be 'Subterranean Homesick Alien'
        $updated.tracks[0].proposedFileName | Should -Be '01 Airbag.flac'

        $updated.coverArt.candidates.Count | Should -Be 1
        $updated.coverArt.chosenCandidateUrl | Should -Be 'https://i.discogs.com/example/full-265498.jpg'

        # Target root is empty, so this is a brand new folder - proves Build-ReshelfTargetIndex and
        # Resolve-ReshelfTargetComparison actually ran against the *new* (Discogs-derived) path.
        $updated.targetAction | Should -Be 'create-new'
    }

    It 'flags a target conflict when a sibling release in the same proposal shares this stable key with different source content (plan/10)' {
        $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Amagrama' '2005 Volumen 1' '01 - Track 1.flac') -Content 'release-bytes'
        $tracks = @((New-TestTrack -SourceFilePath $t1 -OriginalFileName '01 - Track 1.flac' -DetectedTrackNumberInDisc 1))
        $stableKey = Get-TestStableKey -Artist 'Amagrama' -Album 'Volumen 1' -Year 2005
        $release = New-TestRelease -StableKey $stableKey -RecognizedTitle 'Volumen 1' -RecognizedYear 2005 `
            -SourceFolderPath (Split-Path $t1) -Tracks $tracks
        $release | Add-Member -NotePropertyName discogsMatch -NotePropertyValue ([pscustomobject]@{
                status = 'ambiguous'; selectedReleaseId = $null
                candidates = @([pscustomobject]@{ releaseId = 265498; title = 'Radiohead - OK Computer'; year = 1997; format = 'CD, Album'; score = 0.7868 })
            })

        # Same stable key (plan/10's "same release, two sources, one session" case), but different
        # bytes - a real duplicate should be flagged as a conflict, not silently overwritten.
        $siblingSourceFile = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Other Folder' 'sibling.flac') -Content 'different-bytes'
        $siblingTracks = @((New-TestTrack -SourceFilePath $siblingSourceFile -OriginalFileName 'sibling.flac' -DetectedTrackNumberInDisc 1))
        $sibling = New-TestRelease -StableKey $stableKey -RecognizedTitle 'Volumen 1' -RecognizedYear 2005 `
            -SourceFolderPath (Split-Path $siblingSourceFile) -Tracks $siblingTracks

        Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
            $script:ReleaseFixture
        }

        $updated = Update-ReshelfReleaseForDiscogsSelection -Release $release -SelectedReleaseId 265498 -SiblingReleases @($sibling) `
            -ArtistName 'Amagrama' -TargetRoot $script:targetRoot -ReleaseFolderTemplate '{year} {album}' `
            -TrackFileTemplate '{trackNumber} {title}' -CoverMaxDimension 600 -DataHome $script:dataHome

        $updated.targetAction | Should -Be 'conflict'
        $updated.requiresReview | Should -Be $true
    }

    It 'flags a target conflict when a sibling release with a DIFFERENT stable key already claimed the same proposed target path (real case: two source folders for one album that Discogs corrects to one folder)' {
        $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Amagrama' '2005 Volumen 1' '01 - Track 1.flac') -Content 'release-bytes'
        $tracks = @((New-TestTrack -SourceFilePath $t1 -OriginalFileName '01 - Track 1.flac' -DetectedTrackNumberInDisc 1))
        $release = New-TestRelease -StableKey (Get-TestStableKey -Artist 'Amagrama' -Album 'Volumen 1' -Year 2005) `
            -RecognizedTitle 'Volumen 1' -RecognizedYear 2005 -SourceFolderPath (Split-Path $t1) -Tracks $tracks
        $release | Add-Member -NotePropertyName discogsMatch -NotePropertyValue ([pscustomobject]@{
                status = 'ambiguous'; selectedReleaseId = $null
                candidates = @([pscustomobject]@{ releaseId = 265498; title = 'Radiohead - OK Computer'; year = 1997; format = 'CD, Album'; score = 0.7868 })
            })

        # Sibling's own source folder was recognized under a different year (1997 vs 2005), so its
        # stableKey (derived from recognized Artist|Album|Year, not the Discogs-corrected one) is
        # different from $release's - yet it already resolved, earlier in this same session, to the
        # exact same corrected 'Radiohead\1997 OK Computer' folder this release is about to claim.
        $siblingSourceFile = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Other Folder' 'sibling.flac') -Content 'different-bytes'
        $siblingTracks = @((New-TestTrack -SourceFilePath $siblingSourceFile -OriginalFileName 'sibling.flac' -DetectedTrackNumberInDisc 1))
        $sibling = New-TestRelease -StableKey (Get-TestStableKey -Artist 'Amagrama' -Album 'Volumen 1' -Year 1997) `
            -RecognizedTitle 'Volumen 1' -RecognizedYear 1997 -SourceFolderPath (Split-Path $siblingSourceFile) -Tracks $siblingTracks
        $sibling | Add-Member -NotePropertyName proposed -NotePropertyValue ([pscustomobject]@{
                artistFolderName = 'Radiohead'; releaseFolderName = '1997 OK Computer'; year = 1997; album = 'OK Computer'; isCompilation = $false
            })

        Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
            $script:ReleaseFixture
        }

        $updated = Update-ReshelfReleaseForDiscogsSelection -Release $release -SelectedReleaseId 265498 -SiblingReleases @($sibling) `
            -ArtistName 'Amagrama' -TargetRoot $script:targetRoot -ReleaseFolderTemplate '{year} {album}' `
            -TrackFileTemplate '{trackNumber} {title}' -CoverMaxDimension 600 -DataHome $script:dataHome

        $updated.targetAction | Should -Be 'conflict'
        $updated.requiresReview | Should -Be $true
        $updated.notes -join '; ' | Should -BeLike '*target path collision*'
    }
}
