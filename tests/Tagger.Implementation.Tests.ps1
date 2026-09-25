#Requires -Version 7.4

Import-Module Pester -MinimumVersion 5.0

BeforeAll {
    Import-Module "$PSScriptRoot/../scripts/common/Tagger.Common.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Tagger.Json.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Tagger.Settings.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Tagger.LossyTracking.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Tagger.Implementation.psm1" -Force

    # Tagger.Implementation.psm1 re-imports Common/Json/Settings/LossyTracking internally as part of
    # loading, which turns them into nested modules of Tagger.Implementation - PowerShell then hides
    # their commands from this script's own top-level scope (order-dependent on what else has
    # imported them, same gotcha noted in Tagger.EditProposal.Tests.ps1 and
    # Tagger.LossyTracking.Tests.ps1). Routing through Implementation's own module scope, which
    # always has them, avoids that fragility.
    function New-TestSession {
        param(
            [Parameter(Mandatory)] [string]$SourceRoot,
            [Parameter(Mandatory)] [string]$DataHome
        )
        return InModuleScope Tagger.Implementation -Parameters @{ sr = $SourceRoot; dh = $DataHome } {
            param($sr, $dh)
            New-TaggerSession -SourceRoot $sr -DataHome $dh
        }
    }

    # plan/11 "-WhatIf ... compare directory listing before/after": one sorted line per file (path,
    # size, last write time) under every root, plus a marker for whether each root exists, so any
    # created, deleted or rewritten file anywhere - not just in the target - shows up as a diff.
    # Files only, not folders: an intermediate folder's own LastWriteTimeUtc can tick forward on
    # Windows for reasons that have nothing to do with this tool (background indexing, AV scans),
    # so comparing it would make this assertion flaky without catching any write this tool didn't
    # already make through one of its files. Same helper as in Tagger.Pipeline.Tests.ps1 (no shared
    # test-helper module exists yet).
    function Get-TreeSnapshot {
        param([Parameter(Mandatory)] [string[]]$Path)
        $lines = foreach ($root in $Path) {
            if (-not (Test-Path -LiteralPath $root)) { "[$root] missing"; continue }
            "[$root] exists"
            Get-ChildItem -LiteralPath $root -Recurse -Force -File | ForEach-Object {
                "[$root]$($_.FullName.Substring($root.Length))|$($_.Length)|$($_.LastWriteTimeUtc.Ticks)"
            }
        }
        return @($lines | Sort-Object)
    }

    function New-TestProposalFile {
        param(
            [Parameter(Mandatory)] [string]$Path,
            [Parameter(Mandatory)] [object]$Document
        )
        InModuleScope Tagger.Implementation -Parameters @{ p = $Path; o = $Document } {
            param($p, $o)
            Set-TaggerJsonFile -Path $p -InputObject $o -SchemaName proposal -Depth 20 | Out-Null
        }
    }

    function Get-TestLossyEntry {
        param(
            [Parameter(Mandatory)] [string]$StableKey,
            [Parameter(Mandatory)] [string]$DataHome
        )
        return InModuleScope Tagger.Implementation -Parameters @{ k = $StableKey; dh = $DataHome } {
            param($k, $dh)
            Get-TaggerLossyTrackingEntry -StableKey $k -DataHome $dh
        }
    }

    function Add-TestLossyEntry {
        param(
            [Parameter(Mandatory)] [string]$StableKey,
            [Parameter(Mandatory)] [string]$Artist,
            [Parameter(Mandatory)] [string]$Album,
            [Parameter(Mandatory)] [int]$Year,
            [Parameter(Mandatory)] [string]$TargetPath,
            [Parameter(Mandatory)] [string]$Format,
            [Parameter(Mandatory)] [string]$DataHome
        )
        InModuleScope Tagger.Implementation -Parameters @{ k = $StableKey; a = $Artist; al = $Album; y = $Year; tp = $TargetPath; f = $Format; dh = $DataHome } {
            param($k, $a, $al, $y, $tp, $f, $dh)
            Add-TaggerLossyTrackingEntry -StableKey $k -Artist $a -Album $al -Year $y -TargetPath $tp -Format $f -DataHome $dh | Out-Null
        }
    }

    function New-TestAudioFile {
        param(
            [Parameter(Mandatory)] [string]$Path,
            [string]$Content = 'x'
        )
        $dir = Split-Path -Path $Path -Parent
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Set-Content -LiteralPath $Path -Value $Content -NoNewline
        return $Path
    }

    function New-TestTrack {
        param(
            [Parameter(Mandatory)] [string]$SourceFilePath,
            [Parameter(Mandatory)] [string]$ProposedFileName,
            [int]$ProposedTrackNumber = 1,
            [int]$ProposedDiscNumber = 1,
            [string]$ProposedTitle = 'Track',
            [string]$Format = 'flac',
            [bool]$IsLossless = $true,
            [AllowNull()] $CueTimestamp = $null,
            [bool]$IsCueVirtualTrack = $false,
            [string]$Artist = 'Some Band',
            [string]$Album = 'Some Album',
            [int]$Year = 2010
        )

        [pscustomobject]@{
            sourceFilePath            = $SourceFilePath
            discFolder                = $null
            originalFileName          = (Split-Path -Leaf $SourceFilePath)
            detectedTrackNumberInDisc = $ProposedTrackNumber
            inferredTrackOrder        = $false
            existingTags              = [pscustomobject]@{ artist = $null; album = $null; title = $null }
            format                    = $Format
            isLossless                = $IsLossless
            durationSeconds           = 200.0
            cueTimestamp              = $CueTimestamp
            isCueVirtualTrack         = $IsCueVirtualTrack
            proposedFileName          = $ProposedFileName
            proposedDiscNumber        = $ProposedDiscNumber
            proposedTrackNumber       = $ProposedTrackNumber
            proposedTitle             = $ProposedTitle
            tags                      = [pscustomobject]@{
                artist      = $Artist
                albumArtist = $Artist
                album       = $Album
                year        = $Year
                discNumber  = $ProposedDiscNumber
                track       = $ProposedTrackNumber
                title       = $ProposedTitle
            }
        }
    }

    function New-TestReleaseDoc {
        param(
            [Parameter(Mandatory)] [string]$StableKey,
            [Parameter(Mandatory)] [string]$ArtistFolderName,
            [Parameter(Mandatory)] [string]$ReleaseFolderName,
            [Parameter(Mandatory)] [int]$Year,
            [Parameter(Mandatory)] [string]$Album,
            [Parameter(Mandatory)] [string]$SourceFolderPath,
            [Parameter(Mandatory)] [object[]]$Tracks,
            [object[]]$CompanionFiles = @(),
            [object]$CueSheet = $null,
            [string]$DiscogsStatus = 'matched',
            [bool]$HumanReviewResolved = $true,
            [bool]$HumanReviewRequired = $false,
            [string]$LossyAction = 'none',
            [bool]$IsLossy = $false,
            [string]$TargetAction = 'create-new',
            [AllowNull()] $CoverCandidateUrl = $null
        )

        [pscustomobject]@{
            stableKey             = $StableKey
            recognizedTitle       = $Album
            recognizedYear        = $Year
            sourceFolderPath      = $SourceFolderPath
            discFolderCount       = 1
            tracks                = $Tracks
            companionFiles        = $CompanionFiles
            ignoredFiles          = @()
            cueSheet              = $CueSheet
            recognitionConfidence = 1.0
            recognitionFlags      = @()
            needsReview           = $false
            reviewReasons         = @()
            discogsMatch          = [pscustomobject]@{ status = $DiscogsStatus; selectedReleaseId = $null; candidates = @() }
            proposed              = [pscustomobject]@{ artistFolderName = $ArtistFolderName; releaseFolderName = $ReleaseFolderName; year = $Year; album = $Album }
            coverArt              = [pscustomobject]@{ candidates = @(); chosenCandidateUrl = $CoverCandidateUrl; targetMaxDimension = 600 }
            lossyLossless         = [pscustomobject]@{ isLossy = $IsLossy; action = $LossyAction }
            targetAction          = $TargetAction
            humanReview           = [pscustomobject]@{ required = $HumanReviewRequired; resolved = $HumanReviewResolved; notes = '' }
        }
    }

    function New-TestProposalDocument {
        param(
            [Parameter(Mandatory)] [string]$SessionId,
            [Parameter(Mandatory)] [string]$SourceRoot,
            [Parameter(Mandatory)] [object[]]$Releases,
            [string]$ArtistName = 'Some Band'
        )

        return [pscustomobject]@{
            schemaVersion  = 1
            sessionId      = $SessionId
            sourceRoot     = $SourceRoot
            generatedAtUtc = '2026-09-19T10:00:00.000Z'
            artists        = @([pscustomobject]@{ recognizedName = $ArtistName; sourcePaths = @($SourceRoot); releases = $Releases })
            unrecognized   = @()
        }
    }
}

Describe 'Invoke-TaggerFfmpegSplit / Invoke-TaggerFfmpegResize argument quoting' {
    It 'wraps a space-containing source/output path as a single quoted argv element for ffmpeg split' {
        $script:capturedArgs = $null
        Mock -ModuleName Tagger.Implementation Start-Process {
            $script:capturedArgs = $ArgumentList
            [pscustomobject]@{ ExitCode = 0 }
        }

        # Reuses the real fixture path (has a space in both "Pink Floyd" is fine, but the release
        # folder name "1994 Live In Concert (Bootleg)" and the file name both have spaces) - Start-
        # Process joins array elements with a single space and does not quote them, so an unquoted
        # path here would be split into multiple broken argv entries by the child ffmpeg process.
        $sourcePath = Join-Path $PSScriptRoot 'fixtures' 'sample-source-tree' 'Pink Floyd' '1994 Live In Concert (Bootleg)' 'Live In Concert.flac'
        $outputPath = Join-Path $TestDrive 'staged output with spaces.flac'

        Invoke-TaggerFfmpegSplit -SourceAudioPath $sourcePath -StartTimestamp '00:00:00' -OutputPath $outputPath -FfmpegPath 'ffmpeg.exe'

        $script:capturedArgs | Should -Contain "`"$sourcePath`""
        $script:capturedArgs | Should -Contain "`"$outputPath`""
        # Proves it round-trips as ONE argv element: the raw (unquoted) path must not appear as its
        # own separate element alongside the quoted one.
        $script:capturedArgs | Should -Not -Contain $sourcePath
        $script:capturedArgs | Should -Not -Contain $outputPath
    }

    It 'wraps a space-containing source/output path as a single quoted argv element for ffmpeg resize' {
        $script:capturedArgs = $null
        Mock -ModuleName Tagger.Implementation Start-Process {
            $script:capturedArgs = $ArgumentList
            [pscustomobject]@{ ExitCode = 0 }
        }

        $sourcePath = Join-Path $TestDrive 'cover art (large).jpg'
        $outputPath = Join-Path $TestDrive 'cover resized.jpg'

        Invoke-TaggerFfmpegResize -SourceImagePath $sourcePath -MaxDimension 600 -OutputPath $outputPath -FfmpegPath 'ffmpeg.exe'

        $script:capturedArgs | Should -Contain "`"$sourcePath`""
        $script:capturedArgs | Should -Contain "`"$outputPath`""
        $script:capturedArgs | Should -Not -Contain $sourcePath
        $script:capturedArgs | Should -Not -Contain $outputPath
    }
}

Describe 'Resolve-TaggerTruncatedReleaseNames' {
    BeforeAll {
        function New-TruncationTestRelease {
            param(
                [string]$ArtistFolderName = 'Some Band',
                [string]$ReleaseFolderName = '2010 Some Album',
                [string[]]$TrackFileNames = @('01 Track.flac')
            )
            $tracks = foreach ($fileName in $TrackFileNames) {
                New-TestTrack -SourceFilePath (Join-Path $TestDrive $fileName) -ProposedFileName $fileName
            }
            return New-TestReleaseDoc -StableKey 'a1b2c3d4e5f60708' -ArtistFolderName $ArtistFolderName -ReleaseFolderName $ReleaseFolderName `
                -Year 2010 -Album 'Some Album' -SourceFolderPath $TestDrive -Tracks @($tracks)
        }
    }

    It 'leaves normal short names unchanged' {
        $release = New-TruncationTestRelease
        $result = Resolve-TaggerTruncatedReleaseNames -Release $release -TargetRoot 'D:\Music'

        $result.Truncated | Should -Be $false
        $result.ArtistFolderName | Should -Be 'Some Band'
        $result.ReleaseFolderName | Should -Be '2010 Some Album'
        $result.TrackFileNames['01 Track.flac'] | Should -Be '01 Track.flac'
    }

    It 'truncates long names while keeping every resulting path within budget, and preserves prefixes/extensions' {
        $longArtist = 'The ' + ('Extremely ' * 10) + 'Long Band Name'
        $longAlbum = '2010 ' + ('Extremely ' * 10) + 'Long Album Title'
        $longTrack = '01 ' + ('Extremely ' * 10) + 'Long Track Title.flac'
        $deepRoot = Join-Path $TestDrive (('deeply' + ('\nested' * 15)))

        $release = New-TruncationTestRelease -ArtistFolderName $longArtist -ReleaseFolderName $longAlbum -TrackFileNames @($longTrack)
        $result = Resolve-TaggerTruncatedReleaseNames -Release $release -TargetRoot $deepRoot -MaxPathLength 250

        $result.Truncated | Should -Be $true
        $result.ReleaseFolderName | Should -BeLike '2010 *'
        $result.TrackFileNames[$longTrack] | Should -BeLike '01 *'
        $result.TrackFileNames[$longTrack] | Should -BeLike '*.flac'

        $finalTrackPath = Join-Path $deepRoot $result.ArtistFolderName $result.ReleaseFolderName $result.TrackFileNames[$longTrack]
        $finalTrackPath.Length | Should -BeLessOrEqual 250
    }

    It 'disambiguates two track names that would otherwise collide after truncation, and keeps the disambiguated name within budget' {
        # A leading track number is preserved verbatim and is unique per track (continuous
        # numbering), so it alone would prevent a collision - these deliberately have no
        # recognizable numeric prefix (both start with "Hidden"), so their long, near-identical
        # bodies genuinely truncate down to the same string.
        $sharedText = 'Extremely ' * 20
        $trackA = "Hidden ${sharedText}Alpha.flac"
        $trackB = "Hidden ${sharedText}Beta.flac"
        $deepRoot = Join-Path $TestDrive (('deeply' + ('\nested' * 15)))

        $release = New-TruncationTestRelease -TrackFileNames @($trackA, $trackB)
        $result = Resolve-TaggerTruncatedReleaseNames -Release $release -TargetRoot $deepRoot -MaxPathLength 250

        $result.Truncated | Should -Be $true
        $result.TrackFileNames[$trackA] | Should -Not -Be $result.TrackFileNames[$trackB]

        $pathA = Join-Path $deepRoot $result.ArtistFolderName $result.ReleaseFolderName $result.TrackFileNames[$trackA]
        $pathB = Join-Path $deepRoot $result.ArtistFolderName $result.ReleaseFolderName $result.TrackFileNames[$trackB]
        $pathA.Length | Should -BeLessOrEqual 250
        $pathB.Length | Should -BeLessOrEqual 250
    }

    It 'preserves a dash-separated track-number prefix, not just the default space-separated form' {
        $longDashTrack = '01 - ' + ('Extremely ' * 10) + 'Long Track Title.flac'
        $deepRoot = Join-Path $TestDrive (('deeply' + ('\nested' * 15)))

        $release = New-TruncationTestRelease -TrackFileNames @($longDashTrack)
        $result = Resolve-TaggerTruncatedReleaseNames -Release $release -TargetRoot $deepRoot -MaxPathLength 250

        $result.Truncated | Should -Be $true
        $result.TrackFileNames[$longDashTrack] | Should -BeLike '01 - *'
    }

    It 'does not treat a non-year 4-digit catalog-number prefix as an immune-from-truncation year prefix' {
        # Both release names are squeezed under the same very tight budget (a huge artist name and
        # a huge track name eat almost the whole MaxPathLength). A real year keeps its "yyyy "
        # prefix protected (floor = 5 + 1 = 6); a catalog number that merely looks like one must
        # not get that same protection (floor = 0 + 1 = 1) - Recognition.psm1 already guards the
        # same pattern with a 1900-2100 bounds check for this exact reason (e.g. "3218 (Edition)").
        $hugeArtist = 'A' * 1000
        $hugeTrack = '01 ' + ('B' * 1000) + '.flac'
        $root = 'C:\M'

        $yearRelease = New-TruncationTestRelease -ArtistFolderName $hugeArtist -ReleaseFolderName '2010 Some Album' -TrackFileNames @($hugeTrack)
        $yearResult = Resolve-TaggerTruncatedReleaseNames -Release $yearRelease -TargetRoot $root -MaxPathLength 250
        $yearResult.ReleaseFolderName.Length | Should -Be 6
        $yearResult.ReleaseFolderName | Should -BeLike '2010 *'

        $catalogRelease = New-TruncationTestRelease -ArtistFolderName $hugeArtist -ReleaseFolderName '3218 Some Catalog Album' -TrackFileNames @($hugeTrack)
        $catalogResult = Resolve-TaggerTruncatedReleaseNames -Release $catalogRelease -TargetRoot $root -MaxPathLength 250
        $catalogResult.ReleaseFolderName.Length | Should -Be 1
        $catalogResult.ReleaseFolderName | Should -Not -BeLike '3218*'
    }
}

Describe 'Invoke-TaggerImplementation' {
    BeforeEach {
        $script:dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:sourceRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:targetRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:dataHome -Force | Out-Null

        Mock -ModuleName Tagger.Implementation Invoke-TaggerFfmpegSplit { }
        Mock -ModuleName Tagger.Implementation Invoke-TaggerFfmpegResize { Set-Content -LiteralPath $OutputPath -Value 'resized' -NoNewline }
        Mock -ModuleName Tagger.Implementation Invoke-TaggerCoverDownload { Set-Content -LiteralPath $OutputPath -Value 'downloaded' -NoNewline }
        Mock -ModuleName Tagger.Implementation Set-TaggerAudioTags { }
    }

    It '-WhatIf produces zero filesystem writes but still returns a full summary' {
        $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 Track.flac')
        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName '01 Track.flac' -ProposedTitle 'Track'
        $release = New-TestReleaseDoc -StableKey 'a1b2c3d4e5f60708' -ArtistFolderName 'Some Band' -ReleaseFolderName '2010 Some Album' `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $t1) -Tracks @($track)

        $proposalPath = Join-Path $script:dataHome 'proposal.json'
        New-TestProposalFile -Path $proposalPath -Document (New-TestProposalDocument -SessionId 'whatif-session' -SourceRoot $script:sourceRoot -Releases @($release))

        $roots = @($script:sourceRoot, $script:dataHome, $script:targetRoot)
        $before = Get-TreeSnapshot -Path $roots

        $result = Invoke-TaggerImplementation -SessionId 'whatif-session' -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome -WhatIf

        Get-TreeSnapshot -Path $roots | Should -Be $before
        $result.Applied | Should -Be 1
        $result.Skipped | Should -Be 0
        $result.Failed | Should -Be 0

        Test-Path -LiteralPath $script:targetRoot | Should -Be $false
        Test-Path -LiteralPath (Join-Path $script:dataHome 'apply-log.json') | Should -Be $false
        Should -Invoke -ModuleName Tagger.Implementation Set-TaggerAudioTags -Times 0
    }

    It 'produces the correct final layout, calls Set-TaggerAudioTags per track with the expected tags/cover, cleans up working files, and writes a correct apply-log entry' {
        $script:audioTagsCalls = [System.Collections.Generic.List[object]]::new()
        Mock -ModuleName Tagger.Implementation Set-TaggerAudioTags {
            $script:audioTagsCalls.Add([pscustomobject]@{ Path = $Path; Tags = $Tags; CoverImagePath = $CoverImagePath })
        }

        $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 Track.flac')
        $nestedCompanion = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' 'Scans' 'front.jpg')

        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName '01 Track.flac' -ProposedTitle 'Track'
        $companion = [pscustomobject]@{ sourcePath = $nestedCompanion; kind = 'cover'; placement = 'nested' }
        $release = New-TestReleaseDoc -StableKey 'a1b2c3d4e5f60708' -ArtistFolderName 'Some Band' -ReleaseFolderName '2010 Some Album' `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $t1) -Tracks @($track) -CompanionFiles @($companion) `
            -CoverCandidateUrl 'https://example.com/cover.jpg'

        $session = New-TestSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
        $proposalPath = Join-Path $script:dataHome 'sessions' $session.sessionId 'proposal.json'
        New-TestProposalFile -Path $proposalPath -Document (New-TestProposalDocument -SessionId $session.sessionId -SourceRoot $script:sourceRoot -Releases @($release))

        $result = Invoke-TaggerImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome

        $result.Applied | Should -Be 1

        $finalReleasePath = Join-Path $script:targetRoot 'Some Band' '2010 Some Album'
        Test-Path -LiteralPath (Join-Path $finalReleasePath '01 Track.flac') | Should -Be $true
        Test-Path -LiteralPath (Join-Path $finalReleasePath 'Scans' 'front.jpg') | Should -Be $true

        # Working files that only exist to get embedded into tags must not survive into the final folder.
        Test-Path -LiteralPath (Join-Path $finalReleasePath 'cover.jpg') | Should -Be $false
        Test-Path -LiteralPath (Join-Path $finalReleasePath 'cover-source.download') | Should -Be $false

        Should -Invoke -ModuleName Tagger.Implementation Invoke-TaggerCoverDownload -Times 1
        Should -Invoke -ModuleName Tagger.Implementation Invoke-TaggerFfmpegResize -Times 1
        $script:audioTagsCalls.Count | Should -Be 1
        $expectedFilePath = Join-Path $script:targetRoot '.tagger-staging' 'a1b2c3d4e5f60708' '01 Track.flac'
        $expectedCoverPath = Join-Path $script:targetRoot '.tagger-staging' 'a1b2c3d4e5f60708' '.tagger-cover-resized.jpg'
        $script:audioTagsCalls[0].Path | Should -Be $expectedFilePath
        $script:audioTagsCalls[0].CoverImagePath | Should -Be $expectedCoverPath
        $script:audioTagsCalls[0].Tags.artist | Should -Be 'Some Band'
        $script:audioTagsCalls[0].Tags.albumArtist | Should -Be 'Some Band'
        $script:audioTagsCalls[0].Tags.album | Should -Be 'Some Album'
        $script:audioTagsCalls[0].Tags.year | Should -Be 2010
        $script:audioTagsCalls[0].Tags.discNumber | Should -Be 1
        $script:audioTagsCalls[0].Tags.track | Should -Be 1
        $script:audioTagsCalls[0].Tags.title | Should -Be 'Track'

        $entry = Get-TaggerApplyLogEntry -StableKey 'a1b2c3d4e5f60708' -DataHome $script:dataHome
        $entry.status | Should -Be 'applied'
        $entry.targetPath | Should -Be $finalReleasePath
        $entry.errorMessage | Should -BeNullOrEmpty
        $entry.truncated | Should -Be $false
        $entry.sourceFileSetHash | Should -Not -BeNullOrEmpty
    }

    It 'keeps a loose companion literally named cover.jpg (manifesto section 4.5) alongside a downloaded Discogs cover' {
        $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 Track.flac')
        $looseCover = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' 'cover.jpg')

        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName '01 Track.flac' -ProposedTitle 'Track'
        $companion = [pscustomobject]@{ sourcePath = $looseCover; kind = 'cover'; placement = 'loose' }
        $release = New-TestReleaseDoc -StableKey 'a1b2c3d4e5f60708' -ArtistFolderName 'Some Band' -ReleaseFolderName '2010 Some Album' `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $t1) -Tracks @($track) -CompanionFiles @($companion) `
            -CoverCandidateUrl 'https://example.com/cover.jpg'

        $session = New-TestSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
        $proposalPath = Join-Path $script:dataHome 'sessions' $session.sessionId 'proposal.json'
        New-TestProposalFile -Path $proposalPath -Document (New-TestProposalDocument -SessionId $session.sessionId -SourceRoot $script:sourceRoot -Releases @($release))

        $result = Invoke-TaggerImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome

        $result.Applied | Should -Be 1

        # The Discogs cover is embedded and cleaned up as a working file; the source's own loose
        # "cover.jpg" companion is a real target-layout file (manifesto section 4.5) and must survive.
        $finalReleasePath = Join-Path $script:targetRoot 'Some Band' '2010 Some Album'
        Test-Path -LiteralPath (Join-Path $finalReleasePath 'cover.jpg') | Should -Be $true
        Test-Path -LiteralPath (Join-Path $finalReleasePath '.tagger-cover-resized.jpg') | Should -Be $false
    }

    It 'truncates human-readable names and records it, when the fully-assembled target path would exceed the limit' {
        $deepTargetRoot = Join-Path $script:targetRoot (('deeply' + ('\nested' * 15)))
        $longArtist = 'The ' + ('Extremely ' * 10) + 'Long Band Name'
        $longAlbum = '2010 ' + ('Extremely ' * 10) + 'Long Album Title'
        $longTrackFileName = '01 ' + ('Extremely ' * 10) + 'Long Track Title.flac'

        $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' 'source.flac')
        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName $longTrackFileName -ProposedTitle 'Track'
        $release = New-TestReleaseDoc -StableKey 'a1b2c3d4e5f60708' -ArtistFolderName $longArtist -ReleaseFolderName $longAlbum `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $t1) -Tracks @($track)

        $session = New-TestSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
        $proposalPath = Join-Path $script:dataHome 'sessions' $session.sessionId 'proposal.json'
        New-TestProposalFile -Path $proposalPath -Document (New-TestProposalDocument -SessionId $session.sessionId -SourceRoot $script:sourceRoot -Releases @($release))

        $result = Invoke-TaggerImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $deepTargetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome

        $result.Applied | Should -Be 1

        $entry = Get-TaggerApplyLogEntry -StableKey 'a1b2c3d4e5f60708' -DataHome $script:dataHome
        $entry.status | Should -Be 'applied'
        $entry.truncated | Should -Be $true
        $entry.targetPath.Length | Should -BeLessOrEqual 250
        Test-Path -LiteralPath $entry.targetPath | Should -Be $true

        $stagedFile = Get-ChildItem -LiteralPath $entry.targetPath -Filter '*.flac'
        $stagedFile.Name | Should -BeLike '01 *'
        $stagedFile.Name | Should -BeLike '*.flac'
    }

    It 'logs the truncated staged path, not the raw untruncated one, when the commit step fails after staging succeeded' {
        Mock -ModuleName Tagger.Implementation Move-TaggerStagedReleaseToTarget { throw 'commit boom' }

        $deepTargetRoot = Join-Path $script:targetRoot (('deeply' + ('\nested' * 15)))
        $longArtist = 'The ' + ('Extremely ' * 10) + 'Long Band Name'
        $longAlbum = '2010 ' + ('Extremely ' * 10) + 'Long Album Title'
        $longTrackFileName = '01 ' + ('Extremely ' * 10) + 'Long Track Title.flac'

        $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' 'source.flac')
        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName $longTrackFileName -ProposedTitle 'Track'
        $release = New-TestReleaseDoc -StableKey 'a1b2c3d4e5f60708' -ArtistFolderName $longArtist -ReleaseFolderName $longAlbum `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $t1) -Tracks @($track)

        $session = New-TestSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
        $proposalPath = Join-Path $script:dataHome 'sessions' $session.sessionId 'proposal.json'
        New-TestProposalFile -Path $proposalPath -Document (New-TestProposalDocument -SessionId $session.sessionId -SourceRoot $script:sourceRoot -Releases @($release))

        $result = Invoke-TaggerImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $deepTargetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome

        $result.Failed | Should -Be 1

        $entry = Get-TaggerApplyLogEntry -StableKey 'a1b2c3d4e5f60708' -DataHome $script:dataHome
        $entry.status | Should -Be 'failed'
        $rawUntruncatedPath = Join-Path $deepTargetRoot $longArtist $longAlbum
        $entry.targetPath | Should -Not -Be $rawUntruncatedPath
        $entry.targetPath.Length | Should -BeLessOrEqual 250
        $entry.truncated | Should -Be $true
    }

    It 'removes the now-empty .tagger-staging folder after every release applies, but leaves a failed release staged for inspection' {
        Mock -ModuleName Tagger.Implementation Move-TaggerStagedReleaseToTarget { throw 'commit boom' }

        $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 Track.flac')
        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName '01 Track.flac'
        $release = New-TestReleaseDoc -StableKey 'a1b2c3d4e5f60708' -ArtistFolderName 'Some Band' -ReleaseFolderName '2010 Some Album' `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $t1) -Tracks @($track)

        $session = New-TestSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
        $proposalPath = Join-Path $script:dataHome 'sessions' $session.sessionId 'proposal.json'
        New-TestProposalFile -Path $proposalPath -Document (New-TestProposalDocument -SessionId $session.sessionId -SourceRoot $script:sourceRoot -Releases @($release))

        $result = Invoke-TaggerImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome

        $result.Failed | Should -Be 1
        # plan/08 "Edge cases": a failed release's staging folder is left in place for inspection -
        # so .tagger-staging itself must still exist, and this one release's subfolder inside it too.
        $stagingRoot = Join-Path $script:targetRoot '.tagger-staging'
        Test-Path -LiteralPath $stagingRoot | Should -Be $true
        Test-Path -LiteralPath (Join-Path $stagingRoot 'a1b2c3d4e5f60708') | Should -Be $true
    }

    It 'removes the empty .tagger-staging folder once every release in the run has applied successfully' {
        $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 Track.flac')
        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName '01 Track.flac'
        $release = New-TestReleaseDoc -StableKey 'a1b2c3d4e5f60708' -ArtistFolderName 'Some Band' -ReleaseFolderName '2010 Some Album' `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $t1) -Tracks @($track)

        $session = New-TestSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
        $proposalPath = Join-Path $script:dataHome 'sessions' $session.sessionId 'proposal.json'
        New-TestProposalFile -Path $proposalPath -Document (New-TestProposalDocument -SessionId $session.sessionId -SourceRoot $script:sourceRoot -Releases @($release))

        $result = Invoke-TaggerImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome

        $result.Applied | Should -Be 1
        Test-Path -LiteralPath (Join-Path $script:targetRoot '.tagger-staging') | Should -Be $false
    }

    It 'skips every release on a second, unchanged run and makes no ffmpeg/tag-writing calls' {
        $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 Track.flac')
        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName '01 Track.flac'
        $release = New-TestReleaseDoc -StableKey 'a1b2c3d4e5f60708' -ArtistFolderName 'Some Band' -ReleaseFolderName '2010 Some Album' `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $t1) -Tracks @($track)

        $session = New-TestSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
        $proposalPath = Join-Path $script:dataHome 'sessions' $session.sessionId 'proposal.json'
        New-TestProposalFile -Path $proposalPath -Document (New-TestProposalDocument -SessionId $session.sessionId -SourceRoot $script:sourceRoot -Releases @($release))

        $firstResult = Invoke-TaggerImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome
        $firstResult.Applied | Should -Be 1

        $secondResult = Invoke-TaggerImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome

        $secondResult.Applied | Should -Be 0
        $secondResult.Skipped | Should -Be 1
        $secondResult.Failed | Should -Be 0

        Should -Invoke -ModuleName Tagger.Implementation Set-TaggerAudioTags -Times 1
    }

    It 'logs status failed and continues to the next release when tag-writing throws, leaving the staging folder behind' {
        $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Band One' '2010 Album One' '01 Track.flac')
        $t2 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Band Two' '2011 Album Two' '01 Track.flac')

        $failingKey = 'bbbbbbbbbbbbbbbb'
        $okKey = 'aaaaaaaaaaaaaaaa'

        $releaseFail = New-TestReleaseDoc -StableKey $failingKey -ArtistFolderName 'Band One' -ReleaseFolderName '2010 Album One' `
            -Year 2010 -Album 'Album One' -SourceFolderPath (Split-Path $t1) -Tracks @((New-TestTrack -SourceFilePath $t1 -ProposedFileName '01 Track.flac'))
        $releaseOk = New-TestReleaseDoc -StableKey $okKey -ArtistFolderName 'Band Two' -ReleaseFolderName '2011 Album Two' `
            -Year 2011 -Album 'Album Two' -SourceFolderPath (Split-Path $t2) -Tracks @((New-TestTrack -SourceFilePath $t2 -ProposedFileName '01 Track.flac'))

        Mock -ModuleName Tagger.Implementation Set-TaggerAudioTags {
            if ($Path -like "*$failingKey*") { throw 'tag write boom' }
        }

        $session = New-TestSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
        $proposalPath = Join-Path $script:dataHome 'sessions' $session.sessionId 'proposal.json'
        New-TestProposalFile -Path $proposalPath -Document (New-TestProposalDocument -SessionId $session.sessionId -SourceRoot $script:sourceRoot -Releases @($releaseFail, $releaseOk))

        $result = Invoke-TaggerImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome

        $result.Applied | Should -Be 1
        $result.Failed | Should -Be 1

        $failedEntry = Get-TaggerApplyLogEntry -StableKey $failingKey -DataHome $script:dataHome
        $failedEntry.status | Should -Be 'failed'
        $failedEntry.errorMessage | Should -BeLike '*tag write boom*'

        Test-Path -LiteralPath (Join-Path $script:targetRoot '.tagger-staging' $failingKey) | Should -Be $true
        Test-Path -LiteralPath (Join-Path $script:targetRoot 'Band One' '2010 Album One') | Should -Be $false
        Test-Path -LiteralPath (Join-Path $script:targetRoot 'Band Two' '2011 Album Two' '01 Track.flac') | Should -Be $true

        $okEntry = Get-TaggerApplyLogEntry -StableKey $okKey -DataHome $script:dataHome
        $okEntry.status | Should -Be 'applied'
    }

    It 'marks the lossy-tracking entry upgraded on a replace-existing release' {
        $existingLossyFile = New-TestAudioFile -Path (Join-Path $script:targetRoot 'Some Band' '2010 Some Album' '01 Track.mp3') -Content 'old-lossy'
        Add-TestLossyEntry -StableKey 'a1b2c3d4e5f60708' -Artist 'Some Band' -Album 'Some Album' -Year 2010 `
            -TargetPath (Split-Path $existingLossyFile) -Format 'mp3' -DataHome $script:dataHome

        $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 Track.flac') -Content 'new-lossless'
        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName '01 Track.flac'
        $release = New-TestReleaseDoc -StableKey 'a1b2c3d4e5f60708' -ArtistFolderName 'Some Band' -ReleaseFolderName '2010 Some Album' `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $t1) -Tracks @($track) -LossyAction 'replace-existing' -TargetAction 'update-existing'

        $session = New-TestSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
        $proposalPath = Join-Path $script:dataHome 'sessions' $session.sessionId 'proposal.json'
        New-TestProposalFile -Path $proposalPath -Document (New-TestProposalDocument -SessionId $session.sessionId -SourceRoot $script:sourceRoot -Releases @($release))

        $result = Invoke-TaggerImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome

        $result.Applied | Should -Be 1

        $finalReleasePath = Join-Path $script:targetRoot 'Some Band' '2010 Some Album'
        Test-Path -LiteralPath (Join-Path $finalReleasePath '01 Track.flac') | Should -Be $true
        Test-Path -LiteralPath (Join-Path $finalReleasePath '01 Track.mp3') | Should -Be $false

        $ledgerEntry = Get-TestLossyEntry -StableKey 'a1b2c3d4e5f60708' -DataHome $script:dataHome
        $ledgerEntry.status | Should -Be 'upgraded'
        $ledgerEntry.upgradedUtc | Should -Not -BeNullOrEmpty
    }

    It 'skips an ambiguous unresolved release by default and includes it with -IncludeUnresolved' {
        $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 Track.flac')
        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName '01 Track.flac'
        $release = New-TestReleaseDoc -StableKey 'a1b2c3d4e5f60708' -ArtistFolderName 'Some Band' -ReleaseFolderName '2010 Some Album' `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $t1) -Tracks @($track) `
            -DiscogsStatus 'ambiguous' -HumanReviewResolved $false -HumanReviewRequired $true

        $session = New-TestSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
        $proposalPath = Join-Path $script:dataHome 'sessions' $session.sessionId 'proposal.json'
        New-TestProposalFile -Path $proposalPath -Document (New-TestProposalDocument -SessionId $session.sessionId -SourceRoot $script:sourceRoot -Releases @($release))

        $defaultResult = Invoke-TaggerImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome
        $defaultResult.Skipped | Should -Be 1
        $defaultResult.Applied | Should -Be 0
        Test-Path -LiteralPath (Join-Path $script:targetRoot 'Some Band' '2010 Some Album') | Should -Be $false

        $includedResult = Invoke-TaggerImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome -IncludeUnresolved
        $includedResult.Applied | Should -Be 1
        Test-Path -LiteralPath (Join-Path $script:targetRoot 'Some Band' '2010 Some Album' '01 Track.flac') | Should -Be $true
    }

    It 'skips a targetAction conflict release with humanReview.resolved = false, leaving the existing target untouched, unless -IncludeUnresolved' {
        $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 Track.flac') -Content 'new-source-content'
        # Pre-existing, DIFFERENT content already at the final target path - proves it survives
        # untouched when the conflict release is correctly skipped (this is exactly the scenario
        # Move-TaggerStagedReleaseToTarget's unconditional overwrite would otherwise silently destroy).
        $existingTargetFile = New-TestAudioFile -Path (Join-Path $script:targetRoot 'Some Band' '2010 Some Album' '01 Track.flac') -Content 'pre-existing-different-content'

        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName '01 Track.flac'
        $release = New-TestReleaseDoc -StableKey 'a1b2c3d4e5f60708' -ArtistFolderName 'Some Band' -ReleaseFolderName '2010 Some Album' `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $t1) -Tracks @($track) `
            -TargetAction 'conflict' -HumanReviewResolved $false -HumanReviewRequired $true

        $session = New-TestSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
        $proposalPath = Join-Path $script:dataHome 'sessions' $session.sessionId 'proposal.json'
        New-TestProposalFile -Path $proposalPath -Document (New-TestProposalDocument -SessionId $session.sessionId -SourceRoot $script:sourceRoot -Releases @($release))

        $defaultResult = Invoke-TaggerImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome
        $defaultResult.Skipped | Should -Be 1
        $defaultResult.Applied | Should -Be 0
        Test-Path -LiteralPath (Join-Path $script:targetRoot '.tagger-staging' 'a1b2c3d4e5f60708') | Should -Be $false
        (Get-Content -LiteralPath $existingTargetFile -Raw) | Should -Be 'pre-existing-different-content'

        $includedResult = Invoke-TaggerImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome -IncludeUnresolved
        $includedResult.Applied | Should -Be 1
        (Get-Content -LiteralPath $existingTargetFile -Raw) | Should -Be 'new-source-content'
    }

    It 'also deletes companion source files (not just tracks) in move mode' {
        $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 Track.flac')
        $nestedCompanion = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' 'Scans' 'front.jpg')

        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName '01 Track.flac'
        $companion = [pscustomobject]@{ sourcePath = $nestedCompanion; kind = 'cover'; placement = 'nested' }
        $release = New-TestReleaseDoc -StableKey 'a1b2c3d4e5f60708' -ArtistFolderName 'Some Band' -ReleaseFolderName '2010 Some Album' `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $t1) -Tracks @($track) -CompanionFiles @($companion)

        $session = New-TestSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
        $proposalPath = Join-Path $script:dataHome 'sessions' $session.sessionId 'proposal.json'
        New-TestProposalFile -Path $proposalPath -Document (New-TestProposalDocument -SessionId $session.sessionId -SourceRoot $script:sourceRoot -Releases @($release))

        $result = Invoke-TaggerImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode move -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome

        $result.Applied | Should -Be 1

        $finalReleasePath = Join-Path $script:targetRoot 'Some Band' '2010 Some Album'
        Test-Path -LiteralPath (Join-Path $finalReleasePath '01 Track.flac') | Should -Be $true
        Test-Path -LiteralPath (Join-Path $finalReleasePath 'Scans' 'front.jpg') | Should -Be $true

        Test-Path -LiteralPath $t1 | Should -Be $false
        Test-Path -LiteralPath $nestedCompanion | Should -Be $false
    }

    Context 'cue-sheet release' {
        BeforeAll {
            function New-TestCueRelease {
                param([string]$StableKey = 'c1c1c1c1c1c1c1c1')

                $cueSheet = [pscustomobject]@{
                    cueFilePath   = Join-Path $script:cueReleaseDir 'Live In Concert.cue'
                    audioFilePath = Join-Path $script:cueReleaseDir 'Live In Concert.flac'
                }
                $track1 = New-TestTrack -SourceFilePath $cueSheet.audioFilePath -ProposedFileName '01 Speak To Me.flac' `
                    -ProposedTrackNumber 1 -ProposedTitle 'Speak To Me' -CueTimestamp '00:00:00' -IsCueVirtualTrack $true -Artist 'Pink Floyd' -Album 'Live In Concert' -Year 1994
                $track2 = New-TestTrack -SourceFilePath $cueSheet.audioFilePath -ProposedFileName '02 Breathe.flac' `
                    -ProposedTrackNumber 2 -ProposedTitle 'Breathe' -CueTimestamp '03:12:45' -IsCueVirtualTrack $true -Artist 'Pink Floyd' -Album 'Live In Concert' -Year 1994

                return New-TestReleaseDoc -StableKey $StableKey -ArtistFolderName 'Pink Floyd' -ReleaseFolderName '1994 Live In Concert' `
                    -Year 1994 -Album 'Live In Concert' -SourceFolderPath $script:cueReleaseDir -Tracks @($track1, $track2) -CueSheet $cueSheet
            }
        }

        BeforeEach {
            $script:cueFixtureDir = "$PSScriptRoot/fixtures/sample-source-tree/Pink Floyd/1994 Live In Concert (Bootleg)"
            $script:cueReleaseDir = Join-Path $script:sourceRoot 'Pink Floyd' '1994 Live In Concert (Bootleg)'
            New-Item -ItemType Directory -Path $script:cueReleaseDir -Force | Out-Null
            Copy-Item -LiteralPath (Join-Path $script:cueFixtureDir 'Live In Concert.cue') -Destination (Join-Path $script:cueReleaseDir 'Live In Concert.cue')
            New-TestAudioFile -Path (Join-Path $script:cueReleaseDir 'Live In Concert.flac') | Out-Null

            $script:splitCalls = [System.Collections.Generic.List[object]]::new()
            Mock -ModuleName Tagger.Implementation Invoke-TaggerFfmpegSplit {
                $script:splitCalls.Add([pscustomobject]@{ Start = $StartTimestamp; End = $EndTimestamp; Output = $OutputPath })
                Set-Content -LiteralPath $OutputPath -Value 'split' -NoNewline
            }
        }

        It 'splits once per cue track and deletes the cue/audio source only after a successful run' {
            $release = New-TestCueRelease
            $session = New-TestSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
            $proposalPath = Join-Path $script:dataHome 'sessions' $session.sessionId 'proposal.json'
            New-TestProposalFile -Path $proposalPath -Document (New-TestProposalDocument -SessionId $session.sessionId -SourceRoot $script:sourceRoot -Releases @($release))

            $result = Invoke-TaggerImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
                -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome

            $result.Applied | Should -Be 1
            $script:splitCalls.Count | Should -Be 2
            $script:splitCalls[0].Start | Should -Be '00:00:00'
            $script:splitCalls[0].End | Should -Be '03:12:45'
            $script:splitCalls[1].Start | Should -Be '03:12:45'
            $script:splitCalls[1].End | Should -BeNullOrEmpty

            Test-Path -LiteralPath (Join-Path $script:cueReleaseDir 'Live In Concert.cue') | Should -Be $false
            Test-Path -LiteralPath (Join-Path $script:cueReleaseDir 'Live In Concert.flac') | Should -Be $false

            $finalReleasePath = Join-Path $script:targetRoot 'Pink Floyd' '1994 Live In Concert'
            Test-Path -LiteralPath (Join-Path $finalReleasePath '01 Speak To Me.flac') | Should -Be $true
            Test-Path -LiteralPath (Join-Path $finalReleasePath '02 Breathe.flac') | Should -Be $true
        }

        It 'leaves the cue/audio source in place when the release fails after splitting' {
            Mock -ModuleName Tagger.Implementation Set-TaggerAudioTags { throw 'tag write boom' }

            $release = New-TestCueRelease
            $session = New-TestSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
            $proposalPath = Join-Path $script:dataHome 'sessions' $session.sessionId 'proposal.json'
            New-TestProposalFile -Path $proposalPath -Document (New-TestProposalDocument -SessionId $session.sessionId -SourceRoot $script:sourceRoot -Releases @($release))

            $result = Invoke-TaggerImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
                -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome

            $result.Failed | Should -Be 1
            Test-Path -LiteralPath (Join-Path $script:cueReleaseDir 'Live In Concert.cue') | Should -Be $true
            Test-Path -LiteralPath (Join-Path $script:cueReleaseDir 'Live In Concert.flac') | Should -Be $true
        }
    }

    It 'places a loose companion with a digit-prefixed name and preserves a nested companion subfolder' {
        $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 Track.flac')
        $looseCompanion = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01-photo.jpg')
        $nestedCompanion = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' 'Scans' 'front.jpg')

        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName '01 Track.flac'
        $companions = @(
            [pscustomobject]@{ sourcePath = $looseCompanion; kind = 'photo'; placement = 'loose' }
            [pscustomobject]@{ sourcePath = $nestedCompanion; kind = 'cover'; placement = 'nested' }
        )
        $release = New-TestReleaseDoc -StableKey 'a1b2c3d4e5f60708' -ArtistFolderName 'Some Band' -ReleaseFolderName '2010 Some Album' `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $t1) -Tracks @($track) -CompanionFiles $companions

        $session = New-TestSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
        $proposalPath = Join-Path $script:dataHome 'sessions' $session.sessionId 'proposal.json'
        New-TestProposalFile -Path $proposalPath -Document (New-TestProposalDocument -SessionId $session.sessionId -SourceRoot $script:sourceRoot -Releases @($release))

        $result = Invoke-TaggerImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome

        $result.Applied | Should -Be 1

        $finalReleasePath = Join-Path $script:targetRoot 'Some Band' '2010 Some Album'
        Test-Path -LiteralPath (Join-Path $finalReleasePath '_01-photo.jpg') | Should -Be $true
        Test-Path -LiteralPath (Join-Path $finalReleasePath 'Scans' 'front.jpg') | Should -Be $true
    }
}
