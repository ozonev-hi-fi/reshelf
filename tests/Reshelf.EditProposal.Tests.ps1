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
            [string]$ExistingTitle,
            [string]$Format = 'flac',
            [bool]$IsLossless = $true,
            [AllowNull()] $ExistingCoverArtPath = $null
        )

        [pscustomobject]@{
            sourceFilePath            = $SourceFilePath
            discFolder                = $DiscFolder
            originalFileName          = $OriginalFileName
            detectedTrackNumberInDisc = $DetectedTrackNumberInDisc
            inferredTrackOrder        = $false
            existingTags              = @{ artist = $null; album = $null; title = $ExistingTitle }
            existingCoverArtPath      = $ExistingCoverArtPath
            format                    = $Format
            isLossless                = $IsLossless
            durationSeconds           = 200.0
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
            sourceFolderPath      = $SourceFolderPath
            discFolderCount       = $DiscFolderCount
            tracks                = $Tracks
            companionFiles        = $CompanionFiles
            ignoredFiles          = @()
            cueSheet              = $null
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

            # Discogs matched and has an image (release-response.json fixture), but the track already
            # carries its own embedded cover - that wins by default so a good existing cover isn't
            # silently replaced. The Discogs image still shows up as a candidate the user can switch to.
            $releaseResult.discogsMatch.status | Should -Be 'matched'
            $releaseResult.coverArt.candidates.sourceEdition | Should -Contain 'existing (embedded)'
            $releaseResult.coverArt.candidates.Count | Should -Be 2
            $releaseResult.coverArt.chosenCandidateUrl | Should -Be $embeddedCoverPath
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
