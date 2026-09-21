#Requires -Version 7.4

Import-Module Pester -MinimumVersion 5.0

BeforeAll {
    Import-Module "$PSScriptRoot/../scripts/common/Tagger.Common.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Tagger.Json.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Tagger.Discogs.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Tagger.LossyTracking.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Tagger.EditProposal.psm1" -Force

    $script:SearchFixture = Get-Content -LiteralPath "$PSScriptRoot/fixtures/discogs-responses/search-response.json" -Raw | ConvertFrom-Json
    $script:ReleaseFixture = Get-Content -LiteralPath "$PSScriptRoot/fixtures/discogs-responses/release-response.json" -Raw | ConvertFrom-Json

    # Tagger.EditProposal.psm1 re-imports Common/Json internally as part of loading, which turns
    # them into nested modules of Tagger.EditProposal - PowerShell then hides their commands from
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

        return InModuleScope Tagger.EditProposal -Parameters @{ artistName = $Artist; albumName = $Album; releaseYear = $Year } {
            param($artistName, $albumName, $releaseYear)
            Get-TaggerStableKey -Artist $artistName -Album $albumName -Year $releaseYear
        }
    }

    function Test-ProposalDocumentJson {
        param(
            [Parameter(Mandatory)]
            [string]$Path
        )

        return InModuleScope Tagger.EditProposal -Parameters @{ jsonPath = $Path } {
            param($jsonPath)
            Test-TaggerJson -SchemaName proposal -Path $jsonPath
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

        InModuleScope Tagger.EditProposal -Parameters @{ p = $Path; o = $InputObject; s = $SchemaName; d = $Depth } {
            param($p, $o, $s, $d)
            Set-TaggerJsonFile -Path $p -InputObject $o -SchemaName $s -Depth $d | Out-Null
        }
    }

    function Get-TestLossyTrackingEntry {
        param(
            [Parameter(Mandatory)]
            [string]$StableKey,

            [Parameter(Mandatory)]
            [string]$DataHome
        )

        return InModuleScope Tagger.EditProposal -Parameters @{ k = $StableKey; dh = $DataHome } {
            param($k, $dh)
            Get-TaggerLossyTrackingEntry -StableKey $k -DataHome $dh
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

        InModuleScope Tagger.EditProposal -Parameters @{ k = $StableKey; a = $Artist; al = $Album; y = $Year; tp = $TargetPath; f = $Format; dh = $DataHome } {
            param($k, $a, $al, $y, $tp, $f, $dh)
            Add-TaggerLossyTrackingEntry -StableKey $k -Artist $a -Album $al -Year $y -TargetPath $tp -Format $f -DataHome $dh | Out-Null
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
            [bool]$IsLossless = $true
        )

        [pscustomobject]@{
            sourceFilePath            = $SourceFilePath
            discFolder                = $DiscFolder
            originalFileName          = $OriginalFileName
            detectedTrackNumberInDisc = $DetectedTrackNumberInDisc
            inferredTrackOrder        = $false
            existingTags              = @{ artist = $null; album = $null; title = $ExistingTitle }
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

Describe 'Get-TaggerProposalPadWidth (private)' {
    It 'returns 2 for track counts up to 99' {
        InModuleScope Tagger.EditProposal {
            Get-TaggerProposalPadWidth -TotalTrackCount 1 | Should -Be 2
            Get-TaggerProposalPadWidth -TotalTrackCount 9 | Should -Be 2
            Get-TaggerProposalPadWidth -TotalTrackCount 99 | Should -Be 2
        }
    }

    It 'grows beyond 2 for larger track counts' {
        InModuleScope Tagger.EditProposal {
            Get-TaggerProposalPadWidth -TotalTrackCount 100 | Should -Be 3
            Get-TaggerProposalPadWidth -TotalTrackCount 999 | Should -Be 3
            Get-TaggerProposalPadWidth -TotalTrackCount 1000 | Should -Be 4
        }
    }
}

Describe 'Get-TaggerStringSimilarity (private)' {
    It 'returns 1.0 for identical strings' {
        InModuleScope Tagger.EditProposal {
            Get-TaggerStringSimilarity -A 'radiohead' -B 'radiohead' | Should -Be 1.0
        }
    }

    It 'returns 1.0 when both sides are empty' {
        InModuleScope Tagger.EditProposal {
            Get-TaggerStringSimilarity -A '' -B '' | Should -Be 1.0
        }
    }

    It 'returns 0.0 when only one side is empty' {
        InModuleScope Tagger.EditProposal {
            Get-TaggerStringSimilarity -A '' -B 'radiohead' | Should -Be 0.0
        }
    }

    It 'scores a near match higher than an unrelated pair' {
        InModuleScope Tagger.EditProposal {
            $near = Get-TaggerStringSimilarity -A 'ok computer' -B 'ok computr'
            $unrelated = Get-TaggerStringSimilarity -A 'ok computer' -B 'kid a'
            $near | Should -BeGreaterThan $unrelated
        }
    }
}

Describe 'Get-TaggerDiscogsCandidateScore (private)' {
    It 'scores the correct artist/title/year at or above the match threshold' {
        InModuleScope Tagger.EditProposal -Parameters @{ candidate = $script:SearchFixture.results[0] } {
            param($candidate)
            $score = Get-TaggerDiscogsCandidateScore -ExpectedArtist 'Radiohead' -ExpectedTitle 'OK Computer' -ExpectedYear 1997 -Candidate $candidate
            $score | Should -BeGreaterOrEqual 0.85
        }
    }

    It 'scores an unrelated artist/title well below the threshold' {
        InModuleScope Tagger.EditProposal -Parameters @{ candidate = $script:SearchFixture.results[0] } {
            param($candidate)
            $score = Get-TaggerDiscogsCandidateScore -ExpectedArtist 'Some Totally Different Band' -ExpectedTitle 'Unrelated Album Title' -ExpectedYear $null -Candidate $candidate
            $score | Should -BeLessThan 0.85
        }
    }
}

Describe 'Resolve-TaggerDiscogsMatch (private)' {
    BeforeEach {
        $script:dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    }

    It 'returns matched with fetched detail when the top score is above the threshold' {
        Mock -ModuleName Tagger.EditProposal Invoke-DiscogsRequest {
            if ($Path -eq '/database/search') { return $script:SearchFixture }
            return $script:ReleaseFixture
        }

        $result = InModuleScope Tagger.EditProposal -Parameters @{ dataHome = $script:dataHome } {
            param($dataHome)
            Resolve-TaggerDiscogsMatch -ArtistName 'Radiohead' -Title 'OK Computer' -Year 1997 -DataHome $dataHome
        }

        $result.Status | Should -Be 'matched'
        $result.SelectedReleaseId | Should -Be 265498
        $result.Detail.title | Should -Be 'OK Computer'
        $result.Candidates.Count | Should -BeGreaterThan 0
    }

    It 'returns ambiguous with candidates but no detail fetch when the top score is below the threshold' {
        Mock -ModuleName Tagger.EditProposal Invoke-DiscogsRequest {
            if ($Path -eq '/database/search') { return $script:SearchFixture }
            throw 'detail should not be fetched for an ambiguous match'
        }

        $result = InModuleScope Tagger.EditProposal -Parameters @{ dataHome = $script:dataHome } {
            param($dataHome)
            Resolve-TaggerDiscogsMatch -ArtistName 'Some Totally Different Band' -Title 'Unrelated Album' -Year $null -DataHome $dataHome
        }

        $result.Status | Should -Be 'ambiguous'
        $result.SelectedReleaseId | Should -BeNullOrEmpty
        $result.Detail | Should -BeNullOrEmpty
        $result.Candidates.Count | Should -BeGreaterThan 0
    }

    It 'returns not-found when the search yields zero results' {
        Mock -ModuleName Tagger.EditProposal Invoke-DiscogsRequest {
            [pscustomobject]@{ results = @() }
        }

        $result = InModuleScope Tagger.EditProposal -Parameters @{ dataHome = $script:dataHome } {
            param($dataHome)
            Resolve-TaggerDiscogsMatch -ArtistName 'Radiohead' -Title 'OK Computer' -Year 1997 -DataHome $dataHome
        }

        $result.Status | Should -Be 'not-found'
    }

    It 'catches a network failure and returns not-found with an error note instead of throwing' {
        Mock -ModuleName Tagger.EditProposal Invoke-DiscogsRequest {
            throw 'network is down'
        }

        $result = InModuleScope Tagger.EditProposal -Parameters @{ dataHome = $script:dataHome } {
            param($dataHome)
            Resolve-TaggerDiscogsMatch -ArtistName 'Radiohead' -Title 'OK Computer' -Year 1997 -DataHome $dataHome
        }

        $result.Status | Should -Be 'not-found'
        $result.ErrorNote | Should -BeLike '*network is down*'
    }
}

Describe 'Build-TaggerTargetIndex and Test-TaggerTargetReleaseExists' {
    It 'returns an empty index when the target root does not exist' {
        $index = Build-TaggerTargetIndex -TargetRoot (Join-Path $TestDrive ([guid]::NewGuid().ToString('N')))
        $index.Count | Should -Be 0
    }

    It 'indexes well-formed artist/release folders and finds them by stable key' {
        $targetRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $targetRoot 'ArtistA' '1999 AlbumOne') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $targetRoot 'ArtistB' '2005 AlbumTwo') -Force | Out-Null

        $index = Build-TaggerTargetIndex -TargetRoot $targetRoot

        $index.Count | Should -Be 2
        $keyA = Get-TestStableKey -Artist 'ArtistA' -Album 'AlbumOne' -Year 1999
        $entry = Test-TaggerTargetReleaseExists -TargetIndex $index -StableKey $keyA
        $entry | Should -Not -BeNullOrEmpty
        $entry.Path | Should -Be (Join-Path $targetRoot 'ArtistA' '1999 AlbumOne')
    }

    It 'skips a release folder that does not match the "yyyy Name" pattern' {
        $targetRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $targetRoot 'ArtistA' 'Misc') -Force | Out-Null

        $index = Build-TaggerTargetIndex -TargetRoot $targetRoot
        $index.Count | Should -Be 0
    }

    It 'returns $null from Test-TaggerTargetReleaseExists when the key is not indexed' {
        $index = Build-TaggerTargetIndex -TargetRoot (Join-Path $TestDrive ([guid]::NewGuid().ToString('N')))
        Test-TaggerTargetReleaseExists -TargetIndex $index -StableKey 'doesnotexist0000' | Should -BeNullOrEmpty
    }

    It 'does not throw on a stable-key collision between two folders that normalize the same way' {
        $targetRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $targetRoot 'ZZ Top' '1999 XXX') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $targetRoot 'zz  top' '1999 XXX') -Force | Out-Null

        $index = Build-TaggerTargetIndex -TargetRoot $targetRoot
        $index.Count | Should -Be 1
    }
}

Describe 'Invoke-TaggerEditProposal' {
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

            Mock -ModuleName Tagger.EditProposal Invoke-DiscogsRequest {
                if ($Path -eq '/database/search') { return $script:SearchFixture }
                return $script:ReleaseFixture
            }

            $result = Invoke-TaggerEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome

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

        It 'numbers a multi-disc release continuously across discs while tags.track restarts per disc' {
            $discs = @('CD 1', 'CD 1', 'CD 2', 'CD 2', 'CD 3', 'CD 3')
            $titles = @('Song A1', 'Song A2', 'Song B1', 'Song B2', 'Song C1', 'Song C2')
            $tracks = for ($i = 0; $i -lt $discs.Count; $i++) {
                $fileName = "$($i + 1) - $($titles[$i]).flac"
                $path = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2001 Box Set' $discs[$i] $fileName)
                New-TestTrack -SourceFilePath $path -OriginalFileName $fileName -DiscFolder $discs[$i] -DetectedTrackNumberInDisc ([int]($i % 2) + 1)
            }

            $release = New-TestRelease -StableKey (Get-TestStableKey -Artist 'Some Band' -Album 'Box Set' -Year 2001) `
                -RecognizedTitle 'Box Set' -RecognizedYear 2001 -SourceFolderPath (Join-Path $script:sourceRoot 'Some Band' '2001 Box Set') `
                -DiscFolderCount 3 -Tracks $tracks

            New-TestRecognitionFile -Path $script:recognitionPath -SessionId 'test-session' -SourceRoot $script:sourceRoot -Artists @(
                [pscustomobject]@{ recognizedName = 'Some Band'; sourcePaths = @($script:sourceRoot); releases = @($release) }
            )

            Mock -ModuleName Tagger.EditProposal Invoke-DiscogsRequest {
                [pscustomobject]@{ results = @() }
            }

            $result = Invoke-TaggerEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
            $releaseTracks = $result.artists[0].releases[0].tracks

            $expectedDiscNumbers = @(1, 1, 2, 2, 3, 3)
            $expectedTrackNumbers = @(1, 2, 1, 2, 1, 2)
            $expectedFileNumbers = @('01', '02', '03', '04', '05', '06')

            for ($i = 0; $i -lt 6; $i++) {
                $releaseTracks[$i].proposedDiscNumber | Should -Be $expectedDiscNumbers[$i]
                $releaseTracks[$i].proposedTrackNumber | Should -Be $expectedTrackNumbers[$i]
                $releaseTracks[$i].tags.discNumber | Should -Be $expectedDiscNumbers[$i]
                $releaseTracks[$i].tags.track | Should -Be $expectedTrackNumbers[$i]
                $releaseTracks[$i].proposedFileName | Should -BeLike "$($expectedFileNumbers[$i]) *"
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

            Mock -ModuleName Tagger.EditProposal Invoke-DiscogsRequest {
                if ($Path -eq '/database/search') { return $script:customSearch }
                return $script:customDetail
            }

            $result = Invoke-TaggerEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
            $releaseResult = $result.artists[0].releases[0]

            $releaseResult.proposed.artistFolderName | Should -Be 'Metallica'
            $releaseResult.tracks[1].tags.artist | Should -Be 'Metallica'
            $releaseResult.tracks[1].tags.albumArtist | Should -Be 'Metallica'
            $releaseResult.tracks[1].tags.title | Should -BeLike '*feat*'
            $releaseResult.tracks[1].proposedTitle | Should -BeLike '*feat*'
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

            Mock -ModuleName Tagger.EditProposal Invoke-DiscogsRequest {
                if ($Path -eq '/database/search') { return $script:SearchFixture }
                return $script:ReleaseFixture
            }

            $result = Invoke-TaggerEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
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

            Mock -ModuleName Tagger.EditProposal Invoke-DiscogsRequest {
                if ($Path -eq '/database/search') { return $script:SearchFixture }
                throw 'detail should not be fetched for an ambiguous match'
            }

            $result = Invoke-TaggerEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
            $releaseResult = $result.artists[0].releases[0]

            $releaseResult.discogsMatch.status | Should -Be 'ambiguous'
            $releaseResult.proposed.artistFolderName | Should -Be 'Some Totally Different Band'
            $releaseResult.proposed.album | Should -Be 'Unrelated Album'
            $releaseResult.humanReview.required | Should -Be $true
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

            Mock -ModuleName Tagger.EditProposal Invoke-DiscogsRequest {
                [pscustomobject]@{ results = @() }
            }

            $result = Invoke-TaggerEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
            $releaseResult = $result.artists[0].releases[0]

            $releaseResult.coverArt.candidates.Count | Should -Be 1
            $releaseResult.coverArt.candidates[0].sourceEdition | Should -Be 'existing (local)'
            $releaseResult.coverArt.chosenCandidateUrl | Should -Be $coverPath
        }

        It 'has empty candidates and forces review when no cover art is available anywhere' {
            $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 - Only Track.flac')
            $tracks = @((New-TestTrack -SourceFilePath $t1 -OriginalFileName '01 - Only Track.flac' -DetectedTrackNumberInDisc 1))
            $release = New-TestRelease -StableKey (Get-TestStableKey -Artist 'Some Band' -Album 'Some Album' -Year 2010) `
                -RecognizedTitle 'Some Album' -RecognizedYear 2010 -SourceFolderPath (Split-Path $t1) -Tracks $tracks

            New-TestRecognitionFile -Path $script:recognitionPath -SessionId 'test-session' -SourceRoot $script:sourceRoot -Artists @(
                [pscustomobject]@{ recognizedName = 'Some Band'; sourcePaths = @($script:sourceRoot); releases = @($release) }
            )

            Mock -ModuleName Tagger.EditProposal Invoke-DiscogsRequest {
                [pscustomobject]@{ results = @() }
            }

            $result = Invoke-TaggerEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
            $releaseResult = $result.artists[0].releases[0]

            $releaseResult.coverArt.candidates.Count | Should -Be 0
            $releaseResult.coverArt.chosenCandidateUrl | Should -BeNullOrEmpty
            $releaseResult.humanReview.required | Should -Be $true
        }
    }

    Context 'target comparison' {
        BeforeEach {
            Mock -ModuleName Tagger.EditProposal Invoke-DiscogsRequest {
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

            $result = Invoke-TaggerEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
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

            $result = Invoke-TaggerEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
            $result.artists[0].releases[0].targetAction | Should -Be 'skip-existing-identical'
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

            $result = Invoke-TaggerEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
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

            $result = Invoke-TaggerEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
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

            $result = Invoke-TaggerEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
            $releases = $result.artists[0].releases

            $releases[0].targetAction | Should -Be 'create-new'
            $releases[1].targetAction | Should -Be 'conflict'
        }
    }

    Context 'lossy tracking' {
        BeforeEach {
            Mock -ModuleName Tagger.EditProposal Invoke-DiscogsRequest {
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

            $result = Invoke-TaggerEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
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

            Invoke-TaggerEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome | Out-Null

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

        Mock -ModuleName Tagger.EditProposal Invoke-DiscogsRequest {
            if ($Path -eq '/database/search') { return $script:SearchFixture }
            return $script:ReleaseFixture
        }

        $result = Invoke-TaggerEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome
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

        Mock -ModuleName Tagger.EditProposal Invoke-DiscogsRequest {
            [pscustomobject]@{ results = @() }
        }

        Invoke-TaggerEditProposal -SessionId 'test-session' -RecognitionPath $script:recognitionPath -TargetRoot $script:targetRoot -DataHome $script:dataHome | Out-Null

        $proposalPath = Join-Path $script:dataHome 'sessions' 'test-session' 'proposal.json'
        Test-ProposalDocumentJson -Path $proposalPath | Should -Be $true
    }
}
