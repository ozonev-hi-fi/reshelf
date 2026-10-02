#Requires -Version 7.4

Import-Module Pester -MinimumVersion 5.0

BeforeAll {
    Import-Module "$PSScriptRoot/../scripts/common/Reshelf.Common.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Reshelf.Json.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Reshelf.Settings.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Reshelf.LossyTracking.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Reshelf.Implementation.psm1" -Force
    Import-Module "$PSScriptRoot/TestHelpers.psm1" -Force

    # Reshelf.Implementation.psm1 re-imports Common/Json/Settings/LossyTracking internally as part of
    # loading, which turns them into nested modules of Reshelf.Implementation - PowerShell then hides
    # their commands from this script's own top-level scope (order-dependent on what else has
    # imported them, same gotcha noted in Reshelf.EditProposal.Tests.ps1 and
    # Reshelf.LossyTracking.Tests.ps1). Routing through Implementation's own module scope, which
    # always has them, avoids that fragility.
    function New-TestSession {
        param(
            [Parameter(Mandatory)] [string]$SourceRoot,
            [Parameter(Mandatory)] [string]$DataHome
        )
        return InModuleScope Reshelf.Implementation -Parameters @{ sr = $SourceRoot; dh = $DataHome } {
            param($sr, $dh)
            New-ReshelfSession -SourceRoot $sr -DataHome $dh
        }
    }

    function New-TestProposalFile {
        param(
            [Parameter(Mandatory)] [string]$Path,
            [Parameter(Mandatory)] [object]$Document
        )
        InModuleScope Reshelf.Implementation -Parameters @{ p = $Path; o = $Document } {
            param($p, $o)
            Set-ReshelfJsonFile -Path $p -InputObject $o -SchemaName proposal -Depth 20 | Out-Null
        }
    }

    function Get-TestLossyEntry {
        param(
            [Parameter(Mandatory)] [string]$StableKey,
            [Parameter(Mandatory)] [string]$DataHome
        )
        return InModuleScope Reshelf.Implementation -Parameters @{ k = $StableKey; dh = $DataHome } {
            param($k, $dh)
            Get-ReshelfLossyTrackingEntry -StableKey $k -DataHome $dh
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
        InModuleScope Reshelf.Implementation -Parameters @{ k = $StableKey; a = $Artist; al = $Album; y = $Year; tp = $TargetPath; f = $Format; dh = $DataHome } {
            param($k, $a, $al, $y, $tp, $f, $dh)
            Add-ReshelfLossyTrackingEntry -StableKey $k -Artist $a -Album $al -Year $y -TargetPath $tp -Format $f -DataHome $dh | Out-Null
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
            [AllowNull()] [string]$DiscFolder = $null,
            [string]$Artist = 'Some Band',
            [string]$Album = 'Some Album',
            [int]$Year = 2010,
            [bool]$IsCompilation = $false,
            [AllowNull()] $ExistingCoverArtPath = $null
        )

        [pscustomobject]@{
            sourceFilePath            = $SourceFilePath
            discFolder                = $DiscFolder
            originalFileName          = (Split-Path -Leaf $SourceFilePath)
            detectedTrackNumberInDisc = $ProposedTrackNumber
            inferredTrackOrder        = $false
            existingTags              = [pscustomobject]@{ artist = $null; album = $null; title = $null }
            existingCoverArtPath      = $ExistingCoverArtPath
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
                artist        = $Artist
                albumArtist   = $Artist
                album         = $Album
                year          = $Year
                discNumber    = $ProposedDiscNumber
                track         = $ProposedTrackNumber
                title         = $ProposedTitle
                isCompilation = $IsCompilation
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
            [object[]]$CueSheets = @(),
            [string]$DiscogsStatus = 'matched',
            [bool]$HumanReviewResolved = $true,
            [bool]$HumanReviewRequired = $false,
            [bool]$HumanReviewRejected = $false,
            [string]$LossyAction = 'none',
            [bool]$IsLossy = $false,
            [string]$TargetAction = 'create-new',
            [AllowNull()] $CoverCandidateUrl = $null,
            [string]$CoverSourceEdition = 'discogs'
        )

        # @(...) wraps the whole if/else, not just the true branch: an else branch that itself
        # "returns" @() would otherwise collapse to $null once captured from the expression (writing
        # zero objects to the output stream is indistinguishable from writing nothing) - fine for a
        # PowerShell caller, but proposal.schema.json requires coverArt.candidates to be an array.
        $coverCandidates = @(
            if ($CoverCandidateUrl) {
                [pscustomobject]@{ url = $CoverCandidateUrl; sourceEdition = $CoverSourceEdition; width = 600; height = 600 }
            }
        )

        [pscustomobject]@{
            stableKey             = $StableKey
            recognizedTitle       = $Album
            recognizedYear        = $Year
            editionFolderName     = $null
            sourceFolderPath      = $SourceFolderPath
            discFolderCount       = 1
            tracks                = $Tracks
            companionFiles        = $CompanionFiles
            ignoredFiles          = @()
            cueSheets             = @($CueSheets)
            recognitionConfidence = 1.0
            recognitionFlags      = @()
            needsReview           = $false
            reviewReasons         = @()
            discogsMatch          = [pscustomobject]@{ status = $DiscogsStatus; selectedReleaseId = $null; candidates = @() }
            proposed              = [pscustomobject]@{ artistFolderName = $ArtistFolderName; releaseFolderName = $ReleaseFolderName; year = $Year; album = $Album }
            coverArt              = [pscustomobject]@{ candidates = $coverCandidates; chosenCandidateUrl = $CoverCandidateUrl; targetMaxDimension = 600 }
            lossyLossless         = [pscustomobject]@{ isLossy = $IsLossy; action = $LossyAction }
            targetAction          = $TargetAction
            humanReview           = [pscustomobject]@{ required = $HumanReviewRequired; resolved = $HumanReviewResolved; rejected = $HumanReviewRejected; notes = '' }
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

Describe 'Invoke-ReshelfFfmpegSplit / Invoke-ReshelfFfmpegResize argument quoting' {
    It 'wraps a space-containing source/output path as a single quoted argv element for ffmpeg split' {
        $script:capturedArgs = $null
        Mock -ModuleName Reshelf.Implementation Start-Process {
            $script:capturedArgs = $ArgumentList
            [pscustomobject]@{ ExitCode = 0 }
        }

        # Reuses the real fixture path (has a space in both "Pink Floyd" is fine, but the release
        # folder name "1994 Live In Concert (Bootleg)" and the file name both have spaces) - Start-
        # Process joins array elements with a single space and does not quote them, so an unquoted
        # path here would be split into multiple broken argv entries by the child ffmpeg process.
        $sourcePath = Join-Path $PSScriptRoot 'fixtures' 'sample-source-tree' 'Pink Floyd' '1994 Live In Concert (Bootleg)' 'Live In Concert.flac'
        $outputPath = Join-Path $TestDrive 'staged output with spaces.flac'

        Invoke-ReshelfFfmpegSplit -SourceAudioPath $sourcePath -StartTimestamp '00:00:00' -OutputPath $outputPath -FfmpegPath 'ffmpeg.exe'

        $script:capturedArgs | Should -Contain "`"$sourcePath`""
        $script:capturedArgs | Should -Contain "`"$outputPath`""
        # Proves it round-trips as ONE argv element: the raw (unquoted) path must not appear as its
        # own separate element alongside the quoted one.
        $script:capturedArgs | Should -Not -Contain $sourcePath
        $script:capturedArgs | Should -Not -Contain $outputPath
    }

    It 'wraps a space-containing source/output path as a single quoted argv element for ffmpeg resize' {
        $script:capturedArgs = $null
        Mock -ModuleName Reshelf.Implementation Start-Process {
            $script:capturedArgs = $ArgumentList
            [pscustomobject]@{ ExitCode = 0 }
        }

        $sourcePath = Join-Path $TestDrive 'cover art (large).jpg'
        $outputPath = Join-Path $TestDrive 'cover resized.jpg'

        Invoke-ReshelfFfmpegResize -SourceImagePath $sourcePath -MaxDimension 600 -OutputPath $outputPath -FfmpegPath 'ffmpeg.exe'

        $script:capturedArgs | Should -Contain "`"$sourcePath`""
        $script:capturedArgs | Should -Contain "`"$outputPath`""
        $script:capturedArgs | Should -Not -Contain $sourcePath
        $script:capturedArgs | Should -Not -Contain $outputPath
    }
}

Describe 'Invoke-ReshelfFfmpegSplit codec selection' {
    It 'uses -c copy (stream copy) for a source that is neither .ape nor .flac' {
        $script:capturedArgs = $null
        Mock -ModuleName Reshelf.Implementation Start-Process {
            $script:capturedArgs = $ArgumentList
            [pscustomobject]@{ ExitCode = 0 }
        }

        Invoke-ReshelfFfmpegSplit -SourceAudioPath (Join-Path $TestDrive 'source.wav') -StartTimestamp '0.000' `
            -OutputPath (Join-Path $TestDrive 'out.wav') -FfmpegPath 'ffmpeg.exe'

        $script:capturedArgs | Should -Contain '-c'
        $script:capturedArgs | Should -Contain 'copy'
        $script:capturedArgs | Should -Not -Contain '-c:a'
    }

    It 'uses -c:a flac (re-encode) for an .ape source, since ffmpeg cannot write .ape' {
        $script:capturedArgs = $null
        Mock -ModuleName Reshelf.Implementation Start-Process {
            $script:capturedArgs = $ArgumentList
            [pscustomobject]@{ ExitCode = 0 }
        }

        Invoke-ReshelfFfmpegSplit -SourceAudioPath (Join-Path $TestDrive 'source.ape') -StartTimestamp '0.000' `
            -OutputPath (Join-Path $TestDrive 'out.flac') -FfmpegPath 'ffmpeg.exe'

        $script:capturedArgs | Should -Contain '-c:a'
        $script:capturedArgs | Should -Contain 'flac'
        $script:capturedArgs | Should -Not -Contain 'copy'
    }

    It 'uses -c:a flac (re-encode) for a .flac source, since stream-copy does not recompute STREAMINFO duration after trimming' {
        $script:capturedArgs = $null
        Mock -ModuleName Reshelf.Implementation Start-Process {
            $script:capturedArgs = $ArgumentList
            [pscustomobject]@{ ExitCode = 0 }
        }

        Invoke-ReshelfFfmpegSplit -SourceAudioPath (Join-Path $TestDrive 'source.flac') -StartTimestamp '0.000' `
            -OutputPath (Join-Path $TestDrive 'out.flac') -FfmpegPath 'ffmpeg.exe'

        $script:capturedArgs | Should -Contain '-c:a'
        $script:capturedArgs | Should -Contain 'flac'
        $script:capturedArgs | Should -Not -Contain 'copy'
    }
}

Describe 'Invoke-ReshelfFfmpegSplit FLAC "invalid block size" retry' {
    It 'retries once with the start timestamp nudged by 0.05s and succeeds, without throwing' {
        # Confirmed by hand against the two real-world tracks that hit this (AC-DC "Dog Eat Dog" /
        # "Come And Get It"): the failure is at encoder-open time on the FIRST chunk, so only
        # nudging -ss (not -to) changes anything - see the comment on this retry in the module.
        $script:callCount = 0
        $script:capturedStartTimestamps = [System.Collections.Generic.List[string]]::new()
        Mock -ModuleName Reshelf.Implementation Start-Process {
            $script:callCount++
            $startIndex = $ArgumentList.IndexOf('-ss')
            $script:capturedStartTimestamps.Add($ArgumentList[$startIndex + 1])
            Set-Content -LiteralPath $RedirectStandardError -Value '[flac @ 0x0] invalid block size: 4' -NoNewline
            if ($script:callCount -eq 1) { [pscustomobject]@{ ExitCode = -22 } } else { [pscustomobject]@{ ExitCode = 0 } }
        }

        { Invoke-ReshelfFfmpegSplit -SourceAudioPath (Join-Path $TestDrive 'source.flac') -StartTimestamp '322.200' `
                -EndTimestamp '535.070' -OutputPath (Join-Path $TestDrive 'out.flac') -FfmpegPath 'ffmpeg.exe' } | Should -Not -Throw

        $script:callCount | Should -Be 2
        $script:capturedStartTimestamps[0] | Should -Be '322.200'
        $script:capturedStartTimestamps[1] | Should -Be '322.250'
    }

    It 'does not retry and throws immediately when ffmpeg fails for an unrelated reason' {
        Mock -ModuleName Reshelf.Implementation Start-Process {
            Set-Content -LiteralPath $RedirectStandardError -Value 'Invalid argument' -NoNewline
            [pscustomobject]@{ ExitCode = 1 }
        }

        { Invoke-ReshelfFfmpegSplit -SourceAudioPath (Join-Path $TestDrive 'source.flac') -StartTimestamp '0.000' `
                -EndTimestamp '10.000' -OutputPath (Join-Path $TestDrive 'out.flac') -FfmpegPath 'ffmpeg.exe' } | Should -Throw '*exit code 1*'

        Should -Invoke -ModuleName Reshelf.Implementation Start-Process -Times 1 -Exactly
    }

    It 'also retries when there is no end timestamp, since the bug is about the start boundary, not the end' {
        $script:callCount = 0
        Mock -ModuleName Reshelf.Implementation Start-Process {
            $script:callCount++
            Set-Content -LiteralPath $RedirectStandardError -Value '[flac @ 0x0] invalid block size: 4' -NoNewline
            if ($script:callCount -eq 1) { [pscustomobject]@{ ExitCode = -22 } } else { [pscustomobject]@{ ExitCode = 0 } }
        }

        { Invoke-ReshelfFfmpegSplit -SourceAudioPath (Join-Path $TestDrive 'source.flac') -StartTimestamp '600.000' `
                -OutputPath (Join-Path $TestDrive 'out.flac') -FfmpegPath 'ffmpeg.exe' } | Should -Not -Throw

        $script:callCount | Should -Be 2
    }
}

Describe 'Resolve-ReshelfTruncatedReleaseNames' {
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
        $result = Resolve-ReshelfTruncatedReleaseNames -Release $release -TargetRoot 'D:\Music'

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
        $result = Resolve-ReshelfTruncatedReleaseNames -Release $release -TargetRoot $deepRoot -MaxPathLength 250

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
        $result = Resolve-ReshelfTruncatedReleaseNames -Release $release -TargetRoot $deepRoot -MaxPathLength 250

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
        $result = Resolve-ReshelfTruncatedReleaseNames -Release $release -TargetRoot $deepRoot -MaxPathLength 250

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
        $yearResult = Resolve-ReshelfTruncatedReleaseNames -Release $yearRelease -TargetRoot $root -MaxPathLength 250
        $yearResult.ReleaseFolderName.Length | Should -Be 6
        $yearResult.ReleaseFolderName | Should -BeLike '2010 *'

        $catalogRelease = New-TruncationTestRelease -ArtistFolderName $hugeArtist -ReleaseFolderName '3218 Some Catalog Album' -TrackFileNames @($hugeTrack)
        $catalogResult = Resolve-ReshelfTruncatedReleaseNames -Release $catalogRelease -TargetRoot $root -MaxPathLength 250
        $catalogResult.ReleaseFolderName.Length | Should -Be 1
        $catalogResult.ReleaseFolderName | Should -Not -BeLike '3218*'
    }
}

Describe 'Get-ReshelfApplyLogPath / Get-ReshelfApplyLog / Add-ReshelfApplyLogEntry' {
    BeforeEach {
        $script:dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:dataHome -Force | Out-Null
    }

    It 'returns apply-log.json under the given data home' {
        Get-ReshelfApplyLogPath -DataHome $script:dataHome | Should -Be (Join-Path $script:dataHome 'apply-log.json')
    }

    It 'returns an empty array, not an error, when apply-log.json does not exist yet' {
        @(Get-ReshelfApplyLog -DataHome $script:dataHome).Count | Should -Be 0
    }

    It 'appends a new entry and writes a file that validates against the apply-log schema' {
        $log = Add-ReshelfApplyLogEntry -StableKey 'a1b2c3d4e5f60708' -AppliedAtUtc (Get-Date).ToUniversalTime() -Status 'applied' `
            -TargetPath 'C:\target\Some Band\2010 Album' -SourceFileSetHash 'deadbeef' -ErrorMessage $null -Truncated $false -DataHome $script:dataHome

        $log.Count | Should -Be 1
        $logPath = Get-ReshelfApplyLogPath -DataHome $script:dataHome
        Test-Path -LiteralPath $logPath | Should -Be $true
        # Test-ReshelfJson comes from Reshelf.Json.psm1, which Reshelf.Implementation.psm1 re-imports
        # internally as a nested module - that hides this file's own top-level copy of it (same
        # shadowing gotcha the BeforeAll comment above documents for Set-ReshelfJsonFile).
        InModuleScope Reshelf.Implementation -Parameters @{ p = $logPath } {
            param($p)
            Test-ReshelfJson -SchemaName apply-log -Path $p
        } | Should -Be $true

        (Get-ReshelfApplyLog -DataHome $script:dataHome).Count | Should -Be 1
    }

    It 'upserts (replaces, not appends) an existing entry for the same stableKey' {
        Add-ReshelfApplyLogEntry -StableKey 'a1b2c3d4e5f60708' -AppliedAtUtc (Get-Date).ToUniversalTime() -Status 'failed' `
            -TargetPath 'C:\target\Some Band\2010 Album' -SourceFileSetHash 'deadbeef' -ErrorMessage 'boom' -Truncated $false -DataHome $script:dataHome | Out-Null

        $log = Add-ReshelfApplyLogEntry -StableKey 'a1b2c3d4e5f60708' -AppliedAtUtc (Get-Date).ToUniversalTime() -Status 'applied' `
            -TargetPath 'C:\target\Some Band\2010 Album' -SourceFileSetHash 'deadbeef' -ErrorMessage $null -Truncated $false -DataHome $script:dataHome

        $log.Count | Should -Be 1
        $log[0].status | Should -Be 'applied'
        $log[0].errorMessage | Should -BeNullOrEmpty
    }
}

Describe 'Test-ReshelfReleaseNeedsApply' {
    BeforeEach {
        $script:dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:dataHome -Force | Out-Null
        $script:targetRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:targetRoot -Force | Out-Null
    }

    It 'reports NeedsApply true with no prior apply-log entry' {
        $t1 = New-TestAudioFile -Path (Join-Path $TestDrive 'needs-apply-1' '01 Track.flac')
        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName '01 Track.flac'
        $release = New-TestReleaseDoc -StableKey 'aaaaaaaaaaaaaaaa' -ArtistFolderName 'Some Band' -ReleaseFolderName '2010 Some Album' `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $t1) -Tracks @($track)

        $result = Test-ReshelfReleaseNeedsApply -Release $release -TargetRoot $script:targetRoot -DataHome $script:dataHome
        $result.NeedsApply | Should -Be $true
        $result.Hash | Should -Not -BeNullOrEmpty
    }

    It 'reports NeedsApply false when a matching applied entry with the same source-file-set hash already exists under the current TargetRoot' {
        $t1 = New-TestAudioFile -Path (Join-Path $TestDrive 'needs-apply-2' '01 Track.flac')
        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName '01 Track.flac'
        $release = New-TestReleaseDoc -StableKey 'bbbbbbbbbbbbbbbb' -ArtistFolderName 'Some Band' -ReleaseFolderName '2010 Some Album' `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $t1) -Tracks @($track)

        $appliedTargetPath = Join-Path $script:targetRoot 'Some Band\2010 Some Album'
        New-Item -ItemType Directory -Path $appliedTargetPath -Force | Out-Null

        $hash = (Test-ReshelfReleaseNeedsApply -Release $release -TargetRoot $script:targetRoot -DataHome $script:dataHome).Hash
        Add-ReshelfApplyLogEntry -StableKey 'bbbbbbbbbbbbbbbb' -AppliedAtUtc (Get-Date).ToUniversalTime() -Status 'applied' `
            -TargetPath $appliedTargetPath -SourceFileSetHash $hash -ErrorMessage $null -Truncated $false -DataHome $script:dataHome | Out-Null

        (Test-ReshelfReleaseNeedsApply -Release $release -TargetRoot $script:targetRoot -DataHome $script:dataHome).NeedsApply | Should -Be $false
    }

    It 'reports NeedsApply true when the logged entry is applied but the source file set hash has changed' {
        $t1 = New-TestAudioFile -Path (Join-Path $TestDrive 'needs-apply-3' '01 Track.flac')
        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName '01 Track.flac'
        $release = New-TestReleaseDoc -StableKey 'cccccccccccccccc' -ArtistFolderName 'Some Band' -ReleaseFolderName '2010 Some Album' `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $t1) -Tracks @($track)

        $appliedTargetPath = Join-Path $script:targetRoot 'Some Band\2010 Some Album'
        New-Item -ItemType Directory -Path $appliedTargetPath -Force | Out-Null

        Add-ReshelfApplyLogEntry -StableKey 'cccccccccccccccc' -AppliedAtUtc (Get-Date).ToUniversalTime() -Status 'applied' `
            -TargetPath $appliedTargetPath -SourceFileSetHash 'stale-hash-that-cannot-match' -ErrorMessage $null -Truncated $false -DataHome $script:dataHome | Out-Null

        (Test-ReshelfReleaseNeedsApply -Release $release -TargetRoot $script:targetRoot -DataHome $script:dataHome).NeedsApply | Should -Be $true
    }

    It 'reports NeedsApply true when the logged entry exists but its status is failed, even with a matching hash' {
        $t1 = New-TestAudioFile -Path (Join-Path $TestDrive 'needs-apply-4' '01 Track.flac')
        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName '01 Track.flac'
        $release = New-TestReleaseDoc -StableKey 'dddddddddddddddd' -ArtistFolderName 'Some Band' -ReleaseFolderName '2010 Some Album' `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $t1) -Tracks @($track)

        $appliedTargetPath = Join-Path $script:targetRoot 'Some Band\2010 Some Album'
        New-Item -ItemType Directory -Path $appliedTargetPath -Force | Out-Null

        $hash = (Test-ReshelfReleaseNeedsApply -Release $release -TargetRoot $script:targetRoot -DataHome $script:dataHome).Hash
        Add-ReshelfApplyLogEntry -StableKey 'dddddddddddddddd' -AppliedAtUtc (Get-Date).ToUniversalTime() -Status 'failed' `
            -TargetPath $appliedTargetPath -SourceFileSetHash $hash -ErrorMessage 'boom' -Truncated $false -DataHome $script:dataHome | Out-Null

        (Test-ReshelfReleaseNeedsApply -Release $release -TargetRoot $script:targetRoot -DataHome $script:dataHome).NeedsApply | Should -Be $true
    }

    It 'falls back to a null Hash and treats a missing/already-applied entry as not needing re-apply, when every source file is already gone' {
        # Reshelf never deletes source files, but they can still go missing for reasons outside its
        # control (moved/deleted externally, drive offline, ...) - that's not an error on a re-run.
        $missingSourcePath = Join-Path $TestDrive 'needs-apply-5' 'gone.flac'
        $track = New-TestTrack -SourceFilePath $missingSourcePath -ProposedFileName '01 Track.flac'
        $release = New-TestReleaseDoc -StableKey 'eeeeeeeeeeeeeeee' -ArtistFolderName 'Some Band' -ReleaseFolderName '2010 Some Album' `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $missingSourcePath) -Tracks @($track)

        $appliedTargetPath = Join-Path $script:targetRoot 'Some Band\2010 Some Album'
        New-Item -ItemType Directory -Path $appliedTargetPath -Force | Out-Null

        Add-ReshelfApplyLogEntry -StableKey 'eeeeeeeeeeeeeeee' -AppliedAtUtc (Get-Date).ToUniversalTime() -Status 'applied' `
            -TargetPath $appliedTargetPath -SourceFileSetHash 'irrelevant' -ErrorMessage $null -Truncated $false -DataHome $script:dataHome | Out-Null

        $result = Test-ReshelfReleaseNeedsApply -Release $release -TargetRoot $script:targetRoot -DataHome $script:dataHome
        $result.NeedsApply | Should -Be $false
        $result.Hash | Should -BeNullOrEmpty
    }

    It 'reports NeedsApply true (source files gone) when there is no prior applied entry at all' {
        $missingSourcePath = Join-Path $TestDrive 'needs-apply-6' 'gone.flac'
        $track = New-TestTrack -SourceFilePath $missingSourcePath -ProposedFileName '01 Track.flac'
        $release = New-TestReleaseDoc -StableKey 'ffffffffffffffff' -ArtistFolderName 'Some Band' -ReleaseFolderName '2010 Some Album' `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $missingSourcePath) -Tracks @($track)

        $result = Test-ReshelfReleaseNeedsApply -Release $release -TargetRoot $script:targetRoot -DataHome $script:dataHome
        $result.NeedsApply | Should -Be $true
        $result.Hash | Should -BeNullOrEmpty
    }

    It 'reports NeedsApply true when the logged entry is applied with a matching hash but its targetPath is outside the current TargetRoot' {
        $t1 = New-TestAudioFile -Path (Join-Path $TestDrive 'needs-apply-7' '01 Track.flac')
        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName '01 Track.flac'
        $release = New-TestReleaseDoc -StableKey 'a1a1a1a1a1a1a1a1' -ArtistFolderName 'Some Band' -ReleaseFolderName '2010 Some Album' `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $t1) -Tracks @($track)

        # A different, unrelated root - simulates targetRoot having changed (e.g. to a new drive)
        # since this release was last applied. The folder exists, just not under $script:targetRoot.
        $oldTargetRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $appliedTargetPath = Join-Path $oldTargetRoot 'Some Band\2010 Some Album'
        New-Item -ItemType Directory -Path $appliedTargetPath -Force | Out-Null

        $hash = (Test-ReshelfReleaseNeedsApply -Release $release -TargetRoot $script:targetRoot -DataHome $script:dataHome).Hash
        Add-ReshelfApplyLogEntry -StableKey 'a1a1a1a1a1a1a1a1' -AppliedAtUtc (Get-Date).ToUniversalTime() -Status 'applied' `
            -TargetPath $appliedTargetPath -SourceFileSetHash $hash -ErrorMessage $null -Truncated $false -DataHome $script:dataHome | Out-Null

        (Test-ReshelfReleaseNeedsApply -Release $release -TargetRoot $script:targetRoot -DataHome $script:dataHome).NeedsApply | Should -Be $true
    }

    It 'reports NeedsApply true when the logged entry is applied with a matching hash and TargetRoot, but the target folder was deleted' {
        $t1 = New-TestAudioFile -Path (Join-Path $TestDrive 'needs-apply-8' '01 Track.flac')
        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName '01 Track.flac'
        $release = New-TestReleaseDoc -StableKey 'b2b2b2b2b2b2b2b2' -ArtistFolderName 'Some Band' -ReleaseFolderName '2010 Some Album' `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $t1) -Tracks @($track)

        # Never created on disk - simulates the applied release folder having been deleted/renamed
        # outside Reshelf since the log entry was written.
        $appliedTargetPath = Join-Path $script:targetRoot 'Some Band\2010 Some Album'

        $hash = (Test-ReshelfReleaseNeedsApply -Release $release -TargetRoot $script:targetRoot -DataHome $script:dataHome).Hash
        Add-ReshelfApplyLogEntry -StableKey 'b2b2b2b2b2b2b2b2' -AppliedAtUtc (Get-Date).ToUniversalTime() -Status 'applied' `
            -TargetPath $appliedTargetPath -SourceFileSetHash $hash -ErrorMessage $null -Truncated $false -DataHome $script:dataHome | Out-Null

        (Test-ReshelfReleaseNeedsApply -Release $release -TargetRoot $script:targetRoot -DataHome $script:dataHome).NeedsApply | Should -Be $true
    }
}

Describe 'ConvertFrom-ReshelfCueTrackRanges' {
    It 'sorts by cueTimestamp (not proposedTrackNumber) and pairs each track''s own cueTimestamp as Start with the next track''s as End' {
        $t1 = New-TestTrack -SourceFilePath (Join-Path $TestDrive 'cue.flac') -ProposedFileName '02 Second.flac' -ProposedTrackNumber 2 -CueTimestamp '00:03:00' -IsCueVirtualTrack $true
        $t2 = New-TestTrack -SourceFilePath (Join-Path $TestDrive 'cue.flac') -ProposedFileName '01 First.flac' -ProposedTrackNumber 1 -CueTimestamp '00:00:00' -IsCueVirtualTrack $true
        $t3 = New-TestTrack -SourceFilePath (Join-Path $TestDrive 'cue.flac') -ProposedFileName '03 Third.flac' -ProposedTrackNumber 3 -CueTimestamp '00:07:30' -IsCueVirtualTrack $true

        # Deliberately out of order - the function must sort by cueTimestamp itself.
        $ranges = ConvertFrom-ReshelfCueTrackRanges -Tracks @($t1, $t2, $t3)

        $ranges.Count | Should -Be 3
        $ranges[0].Track.proposedTrackNumber | Should -Be 1
        $ranges[0].StartTimestamp | Should -Be '0.000'
        $ranges[0].EndTimestamp | Should -Be '3.000'
        $ranges[1].Track.proposedTrackNumber | Should -Be 2
        $ranges[1].StartTimestamp | Should -Be '3.000'
        $ranges[1].EndTimestamp | Should -Be '7.400'
        $ranges[2].Track.proposedTrackNumber | Should -Be 3
        $ranges[2].StartTimestamp | Should -Be '7.400'
        $ranges[2].EndTimestamp | Should -BeNullOrEmpty
    }

    It 'groups by sourceFilePath instead of sorting the whole list together, for a per-disc-cue release with repeated track numbers' {
        # Real shape of a per-disc-cue release (e.g. AC-DC "Stiff Upper Lip", CD 1/CD 2): each disc
        # has its own source file, and proposedTrackNumber restarts at 1 on every disc - sorting
        # globally by proposedTrackNumber would interleave the two discs' tracks and pair a disc 1
        # track's start with a disc 2 track's start.
        $disc1 = Join-Path $TestDrive 'disc1.flac'
        $disc2 = Join-Path $TestDrive 'disc2.flac'
        $d1t1 = New-TestTrack -SourceFilePath $disc1 -ProposedFileName '01 D1T1.flac' -ProposedTrackNumber 1 -CueTimestamp '00:00:00' -IsCueVirtualTrack $true -DiscFolder 'CD 1'
        # Cue timestamps are MM:SS:FF (minutes:seconds:frames), not HH:MM:SS - '02:00:00' is 2
        # minutes (120s), not 2 seconds.
        $d1t2 = New-TestTrack -SourceFilePath $disc1 -ProposedFileName '02 D1T2.flac' -ProposedTrackNumber 2 -CueTimestamp '02:00:00' -IsCueVirtualTrack $true -DiscFolder 'CD 1'
        $d2t1 = New-TestTrack -SourceFilePath $disc2 -ProposedFileName '01 D2T1.flac' -ProposedTrackNumber 1 -CueTimestamp '00:00:00' -IsCueVirtualTrack $true -DiscFolder 'CD 2'

        $ranges = ConvertFrom-ReshelfCueTrackRanges -Tracks @($d1t1, $d1t2, $d2t1)

        $ranges.Count | Should -Be 3
        $disc1Ranges = @($ranges | Where-Object { $_.Track.sourceFilePath -eq $disc1 } | Sort-Object StartTimestamp)
        $disc2Ranges = @($ranges | Where-Object { $_.Track.sourceFilePath -eq $disc2 } | Sort-Object StartTimestamp)
        $disc1Ranges.Count | Should -Be 2
        $disc2Ranges.Count | Should -Be 1

        $disc1Ranges[0].StartTimestamp | Should -Be '0.000'
        $disc1Ranges[0].EndTimestamp | Should -Be '120.000'
        $disc1Ranges[1].StartTimestamp | Should -Be '120.000'
        $disc1Ranges[1].EndTimestamp | Should -BeNullOrEmpty

        # Disc 2's only track must end at $null (end of ITS OWN file), never at disc 1's first
        # timestamp just because some disc-1 track shares the same proposedTrackNumber.
        $disc2Ranges[0].StartTimestamp | Should -Be '0.000'
        $disc2Ranges[0].EndTimestamp | Should -BeNullOrEmpty
    }

    It 'returns a single range with a null EndTimestamp for a single-track cue release' {
        $t1 = New-TestTrack -SourceFilePath (Join-Path $TestDrive 'cue.flac') -ProposedFileName '01 Only.flac' -ProposedTrackNumber 1 -CueTimestamp '00:00:00' -IsCueVirtualTrack $true

        $ranges = ConvertFrom-ReshelfCueTrackRanges -Tracks @($t1)

        $ranges.Count | Should -Be 1
        $ranges[0].StartTimestamp | Should -Be '0.000'
        $ranges[0].EndTimestamp | Should -BeNullOrEmpty
    }

    It 'returns an empty array, not an error, for an empty track list' {
        @(ConvertFrom-ReshelfCueTrackRanges -Tracks @()).Count | Should -Be 0
    }
}

Describe 'ConvertTo-ReshelfFfmpegSeconds' {
    It 'converts MM:SS:FF cue frames (00-74) into fractional seconds, not HH:MM:SS' {
        # The exact case from the reported bug: frames=73 is invalid as an HH:MM:SS seconds field
        # (ffmpeg errored with "Invalid duration for option to: 09:26:73") but is a perfectly valid
        # cue frame count and must convert cleanly.
        ConvertTo-ReshelfFfmpegSeconds '09:26:73' | Should -Be '566.973'
        ConvertTo-ReshelfFfmpegSeconds '00:00:00' | Should -Be '0.000'
        # frames=45 is < 60, so the old buggy code silently accepted it as HH:MM:SS (3h12m45s)
        # instead of erroring - this is the real-fixture case (Pink Floyd cue) that never surfaced
        # as a visible failure but produced a wrongly-timed split.
        ConvertTo-ReshelfFfmpegSeconds '03:12:45' | Should -Be '192.600'
    }
}

Describe 'Resolve-ReshelfCompanionTargetPath' {
    It 'keeps a nested companion''s relative subfolder path and sanitized file name unchanged' {
        $releaseSource = Join-Path $TestDrive 'nested-companion' 'Some Band' '2010 Album'
        $companionSource = Join-Path $releaseSource 'Scans' 'back cover.jpg'
        $companion = [pscustomobject]@{ sourcePath = $companionSource; kind = 'photo'; placement = 'nested' }

        $result = Resolve-ReshelfCompanionTargetPath -CompanionFile $companion -ReleaseSourceFolderPath $releaseSource -ReleaseFolderPath 'C:\target\Some Band\2010 Album'

        $result | Should -Be (Join-Path 'C:\target\Some Band\2010 Album' 'Scans' 'back cover.jpg')
    }

    It 'uses the loose companion''s proposedFileName when present' {
        $releaseSource = Join-Path $TestDrive 'loose-companion' 'Some Band' '2010 Album'
        $companionSource = Join-Path $releaseSource '01 back.jpg'
        $companion = [pscustomobject]@{ sourcePath = $companionSource; kind = 'cover'; placement = 'loose'; proposedFileName = 'Booklet 01 back.jpg' }

        $result = Resolve-ReshelfCompanionTargetPath -CompanionFile $companion -ReleaseSourceFolderPath $releaseSource -ReleaseFolderPath 'C:\target\Some Band\2010 Album'

        $result | Should -Be (Join-Path 'C:\target\Some Band\2010 Album' 'Booklet 01 back.jpg')
    }

    It 'falls back to computing a letter-first name from kind when proposedFileName is missing (older proposal.json)' {
        $releaseSource = Join-Path $TestDrive 'loose-fallback' 'Some Band' '2010 Album'
        $companionSource = Join-Path $releaseSource '01 back.jpg'
        $companion = [pscustomobject]@{ sourcePath = $companionSource; kind = 'cover'; placement = 'loose' }

        $result = Resolve-ReshelfCompanionTargetPath -CompanionFile $companion -ReleaseSourceFolderPath $releaseSource -ReleaseFolderPath 'C:\target\Some Band\2010 Album'

        (Split-Path -Leaf $result) | Should -Not -BeLike '0*'
        (Split-Path -Leaf $result) | Should -Match '^[A-Za-z]'
    }
}

Describe 'Invoke-ReshelfReleaseStaging' {
    BeforeEach {
        $script:stagingRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N')) 'staging'
        $script:targetRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N')) 'target'

        Mock -ModuleName Reshelf.Implementation Invoke-ReshelfFfmpegSplit { }
        Mock -ModuleName Reshelf.Implementation Invoke-ReshelfFfmpegResize { Set-Content -LiteralPath $OutputPath -Value 'resized' -NoNewline }
        Mock -ModuleName Reshelf.Implementation Invoke-ReshelfCoverDownload { Set-Content -LiteralPath $OutputPath -Value 'downloaded' -NoNewline }
        Mock -ModuleName Reshelf.Implementation Set-ReshelfAudioTags { }
    }

    It 'stages tracks and a nested companion, returning Success with the untruncated final target path' {
        $t1 = New-TestAudioFile -Path (Join-Path $TestDrive 'stage-ok' 'Some Band' '2010 Some Album' '01 Track.flac')
        $nestedCompanion = New-TestAudioFile -Path (Join-Path $TestDrive 'stage-ok' 'Some Band' '2010 Some Album' 'Scans' 'front.jpg')
        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName '01 Track.flac' -ProposedTitle 'Track'
        $companion = [pscustomobject]@{ sourcePath = $nestedCompanion; kind = 'cover'; placement = 'nested' }
        $release = New-TestReleaseDoc -StableKey 'a1b2c3d4e5f60708' -ArtistFolderName 'Some Band' -ReleaseFolderName '2010 Some Album' `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $t1) -Tracks @($track) -CompanionFiles @($companion)

        $result = Invoke-ReshelfReleaseStaging -Release $release -StagingRoot $script:stagingRoot -TargetRoot $script:targetRoot -FfmpegPath 'ffmpeg.exe'

        $result.Success | Should -Be $true
        $result.Truncated | Should -Be $false
        $result.ErrorMessage | Should -BeNullOrEmpty
        $result.TargetPath | Should -Be (Join-Path $script:targetRoot 'Some Band' '2010 Some Album')

        $stagedRelease = Join-Path $script:stagingRoot 'a1b2c3d4e5f60708'
        Test-Path -LiteralPath (Join-Path $stagedRelease '01 Track.flac') | Should -Be $true
        Test-Path -LiteralPath (Join-Path $stagedRelease 'Scans' 'front.jpg') | Should -Be $true
    }

    It 'fails cleanly, without staging any file, when an included loose companion''s target name does not start with a letter' {
        $t1 = New-TestAudioFile -Path (Join-Path $TestDrive 'stage-bad-name' 'Some Band' '2010 Some Album' '01 Track.flac')
        $badCompanion = New-TestAudioFile -Path (Join-Path $TestDrive 'stage-bad-name' 'Some Band' '2010 Some Album' '1 test.jpg')
        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName '01 Track.flac' -ProposedTitle 'Track'
        $companion = [pscustomobject]@{ sourcePath = $badCompanion; kind = 'other'; placement = 'loose'; proposedFileName = '1 test.jpg' }
        $release = New-TestReleaseDoc -StableKey 'b1b2c3d4e5f60708' -ArtistFolderName 'Some Band' -ReleaseFolderName '2010 Some Album' `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $t1) -Tracks @($track) -CompanionFiles @($companion)

        $result = Invoke-ReshelfReleaseStaging -Release $release -StagingRoot $script:stagingRoot -TargetRoot $script:targetRoot -FfmpegPath 'ffmpeg.exe'

        $result.Success | Should -Be $false
        $result.ErrorMessage | Should -BeLike '*must start with a letter*'
        Test-Path -LiteralPath (Join-Path $script:stagingRoot 'b1b2c3d4e5f60708') | Should -Be $false
    }

    It 'fails cleanly when a loose companion''s target name collides with a track''s target file name' {
        # A real proposed track file name always starts with a digit (manifesto SS5 numbering),
        # which would already trip the "must start with a letter" check above before ever reaching
        # this one - so this uses a deliberately unusual letter-first track file name, purely to
        # exercise this specific guard clause in isolation.
        $t1 = New-TestAudioFile -Path (Join-Path $TestDrive 'stage-collide-track' 'Some Band' '2010 Some Album' 'source.flac')
        $collidingCompanion = New-TestAudioFile -Path (Join-Path $TestDrive 'stage-collide-track' 'Some Band' '2010 Some Album' 'dup.jpg')
        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName 'Track One.flac' -ProposedTitle 'Track'
        $companion = [pscustomobject]@{ sourcePath = $collidingCompanion; kind = 'other'; placement = 'loose'; proposedFileName = 'Track One.flac' }
        $release = New-TestReleaseDoc -StableKey 'c1b2c3d4e5f60708' -ArtistFolderName 'Some Band' -ReleaseFolderName '2010 Some Album' `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $t1) -Tracks @($track) -CompanionFiles @($companion)

        $result = Invoke-ReshelfReleaseStaging -Release $release -StagingRoot $script:stagingRoot -TargetRoot $script:targetRoot -FfmpegPath 'ffmpeg.exe'

        $result.Success | Should -Be $false
        $result.ErrorMessage | Should -BeLike '*same as a track file name*'
    }

    It 'fails cleanly when two included companions would both be copied to the same target path' {
        $t1 = New-TestAudioFile -Path (Join-Path $TestDrive 'stage-collide-companion' 'Some Band' '2010 Some Album' '01 Track.flac')
        $companionA = New-TestAudioFile -Path (Join-Path $TestDrive 'stage-collide-companion' 'Some Band' '2010 Some Album' 'a.jpg')
        $companionB = New-TestAudioFile -Path (Join-Path $TestDrive 'stage-collide-companion' 'Some Band' '2010 Some Album' 'b.jpg')
        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName '01 Track.flac' -ProposedTitle 'Track'
        $c1 = [pscustomobject]@{ sourcePath = $companionA; kind = 'other'; placement = 'loose'; proposedFileName = 'Extra Same Name.jpg' }
        $c2 = [pscustomobject]@{ sourcePath = $companionB; kind = 'other'; placement = 'loose'; proposedFileName = 'Extra Same Name.jpg' }
        $release = New-TestReleaseDoc -StableKey 'd1b2c3d4e5f60708' -ArtistFolderName 'Some Band' -ReleaseFolderName '2010 Some Album' `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $t1) -Tracks @($track) -CompanionFiles @($c1, $c2)

        $result = Invoke-ReshelfReleaseStaging -Release $release -StagingRoot $script:stagingRoot -TargetRoot $script:targetRoot -FfmpegPath 'ffmpeg.exe'

        $result.Success | Should -Be $false
        $result.ErrorMessage | Should -BeLike '*would both be copied*'
    }

    It 'skips a companion with include=false entirely - not copied, not counted toward a naming collision' {
        $t1 = New-TestAudioFile -Path (Join-Path $TestDrive 'stage-excluded' 'Some Band' '2010 Some Album' '01 Track.flac')
        $excludedCompanion = New-TestAudioFile -Path (Join-Path $TestDrive 'stage-excluded' 'Some Band' '2010 Some Album' '1 bad name.jpg')
        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName '01 Track.flac' -ProposedTitle 'Track'
        # Invalid loose name, but excluded - must not fail the release nor be copied.
        $companion = [pscustomobject]@{ sourcePath = $excludedCompanion; kind = 'other'; placement = 'loose'; proposedFileName = '1 bad name.jpg'; include = $false }
        $release = New-TestReleaseDoc -StableKey 'e1b2c3d4e5f60708' -ArtistFolderName 'Some Band' -ReleaseFolderName '2010 Some Album' `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $t1) -Tracks @($track) -CompanionFiles @($companion)

        $result = Invoke-ReshelfReleaseStaging -Release $release -StagingRoot $script:stagingRoot -TargetRoot $script:targetRoot -FfmpegPath 'ffmpeg.exe'

        $result.Success | Should -Be $true
        Test-Path -LiteralPath (Join-Path $script:stagingRoot 'e1b2c3d4e5f60708' '1 bad name.jpg') | Should -Be $false
    }
}

Describe 'Invoke-ReshelfImplementation' {
    BeforeEach {
        $script:dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:sourceRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:targetRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:dataHome -Force | Out-Null

        Mock -ModuleName Reshelf.Implementation Invoke-ReshelfFfmpegSplit { }
        Mock -ModuleName Reshelf.Implementation Invoke-ReshelfFfmpegResize { Set-Content -LiteralPath $OutputPath -Value 'resized' -NoNewline }
        Mock -ModuleName Reshelf.Implementation Invoke-ReshelfCoverDownload { Set-Content -LiteralPath $OutputPath -Value 'downloaded' -NoNewline }
        Mock -ModuleName Reshelf.Implementation Set-ReshelfAudioTags { }
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

        $result = Invoke-ReshelfImplementation -SessionId 'whatif-session' -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome -WhatIf

        Get-TreeSnapshot -Path $roots | Should -Be $before
        $result.Applied | Should -Be 1
        $result.Skipped | Should -Be 0
        $result.Failed | Should -Be 0

        Test-Path -LiteralPath $script:targetRoot | Should -Be $false
        Test-Path -LiteralPath (Join-Path $script:dataHome 'apply-log.json') | Should -Be $false
        Should -Invoke -ModuleName Reshelf.Implementation Set-ReshelfAudioTags -Times 0
    }

    It 'falls back to plain "ffmpeg" (PATH resolution) when -FfmpegPath is omitted or empty, instead of failing on the empty settings.json default' {
        # settings.default.json's ffmpegPath is "" by design (plan/01's Definition of Done: ffmpeg
        # resolves via PATH or a documented full path) - scripts/Reshelf.ps1's apply command passes
        # that straight through, so this must not throw a parameter-binding error for an empty string.
        $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 Track.flac')
        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName '01 Track.flac' -ProposedTitle 'Track'
        $release = New-TestReleaseDoc -StableKey 'a1b2c3d4e5f60708' -ArtistFolderName 'Some Band' -ReleaseFolderName '2010 Some Album' `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $t1) -Tracks @($track)

        $session = New-TestSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
        $proposalPath = Join-Path $script:dataHome 'sessions' $session.sessionId 'proposal.json'
        New-TestProposalFile -Path $proposalPath -Document (New-TestProposalDocument -SessionId $session.sessionId -SourceRoot $script:sourceRoot -Releases @($release))

        $result = Invoke-ReshelfImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath '' -DataHome $script:dataHome
        $result.Applied | Should -Be 1
    }

    It 'produces the correct final layout, calls Set-ReshelfAudioTags per track with the expected tags/cover, cleans up working files, and writes a correct apply-log entry' {
        $script:audioTagsCalls = [System.Collections.Generic.List[object]]::new()
        Mock -ModuleName Reshelf.Implementation Set-ReshelfAudioTags {
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

        $result = Invoke-ReshelfImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome

        $result.Applied | Should -Be 1

        $finalReleasePath = Join-Path $script:targetRoot 'Some Band' '2010 Some Album'
        Test-Path -LiteralPath (Join-Path $finalReleasePath '01 Track.flac') | Should -Be $true
        Test-Path -LiteralPath (Join-Path $finalReleasePath 'Scans' 'front.jpg') | Should -Be $true

        # Working files that only exist to get embedded into tags must not survive into the final folder.
        Test-Path -LiteralPath (Join-Path $finalReleasePath 'cover.jpg') | Should -Be $false
        Test-Path -LiteralPath (Join-Path $finalReleasePath 'cover-source.download') | Should -Be $false

        Should -Invoke -ModuleName Reshelf.Implementation Invoke-ReshelfCoverDownload -Times 1
        Should -Invoke -ModuleName Reshelf.Implementation Invoke-ReshelfFfmpegResize -Times 1
        $script:audioTagsCalls.Count | Should -Be 1
        $expectedFilePath = Join-Path $script:targetRoot '.reshelf-staging' 'a1b2c3d4e5f60708' '01 Track.flac'
        $expectedCoverPath = Join-Path $script:targetRoot '.reshelf-staging' 'a1b2c3d4e5f60708' '.reshelf-cover-resized.jpg'
        $script:audioTagsCalls[0].Path | Should -Be $expectedFilePath
        $script:audioTagsCalls[0].CoverImagePath | Should -Be $expectedCoverPath
        $script:audioTagsCalls[0].Tags.artist | Should -Be 'Some Band'
        $script:audioTagsCalls[0].Tags.albumArtist | Should -Be 'Some Band'
        $script:audioTagsCalls[0].Tags.album | Should -Be 'Some Album'
        $script:audioTagsCalls[0].Tags.year | Should -Be 2010
        $script:audioTagsCalls[0].Tags.discNumber | Should -Be 1
        $script:audioTagsCalls[0].Tags.track | Should -Be 1
        $script:audioTagsCalls[0].Tags.title | Should -Be 'Track'
        $script:audioTagsCalls[0].Tags.isCompilation | Should -Be $false

        $entry = Get-ReshelfApplyLogEntry -StableKey 'a1b2c3d4e5f60708' -DataHome $script:dataHome
        $entry.status | Should -Be 'applied'
        $entry.targetPath | Should -Be $finalReleasePath
        $entry.errorMessage | Should -BeNullOrEmpty
        $entry.truncated | Should -Be $false
        $entry.sourceFileSetHash | Should -Not -BeNullOrEmpty
    }

    It 'passes a track''s isCompilation tag through to Set-ReshelfAudioTags unchanged' {
        $script:audioTagsCalls = [System.Collections.Generic.List[object]]::new()
        Mock -ModuleName Reshelf.Implementation Set-ReshelfAudioTags {
            $script:audioTagsCalls.Add([pscustomobject]@{ Path = $Path; Tags = $Tags; CoverImagePath = $CoverImagePath })
        }

        $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Various' '2008 A Compilation' '01 Track.flac')
        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName '01 Track.flac' -ProposedTitle 'Track' -Artist 'Various' -Album 'A Compilation' -IsCompilation $true
        $release = New-TestReleaseDoc -StableKey 'a1b2c3d4e5f60709' -ArtistFolderName 'Various' -ReleaseFolderName '2008 A Compilation' `
            -Year 2008 -Album 'A Compilation' -SourceFolderPath (Split-Path $t1) -Tracks @($track)

        $session = New-TestSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
        $proposalPath = Join-Path $script:dataHome 'sessions' $session.sessionId 'proposal.json'
        New-TestProposalFile -Path $proposalPath -Document (New-TestProposalDocument -SessionId $session.sessionId -SourceRoot $script:sourceRoot -Releases @($release))

        $result = Invoke-ReshelfImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath '' -DataHome $script:dataHome

        $result.Applied | Should -Be 1
        $script:audioTagsCalls[0].Tags.isCompilation | Should -Be $true
    }

    It 'leaves a track''s picture tag untouched when the chosen cover is "existing (embedded)" and that track already has one' {
        $script:audioTagsCalls = [System.Collections.Generic.List[object]]::new()
        Mock -ModuleName Reshelf.Implementation Set-ReshelfAudioTags {
            $script:audioTagsCalls.Add([pscustomobject]@{ Path = $Path; CoverImagePath = $CoverImagePath })
        }

        $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 Track.flac')
        $embeddedCoverPath = Join-Path $script:dataHome 'embedded-covers' 'existing-cover.jpg'
        New-Item -ItemType Directory -Path (Split-Path $embeddedCoverPath) -Force | Out-Null
        Set-Content -LiteralPath $embeddedCoverPath -Value 'existing-cover-bytes' -NoNewline

        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName '01 Track.flac' -ProposedTitle 'Track' -ExistingCoverArtPath $embeddedCoverPath
        $release = New-TestReleaseDoc -StableKey 'a1b2c3d4e5f60708' -ArtistFolderName 'Some Band' -ReleaseFolderName '2010 Some Album' `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $t1) -Tracks @($track) `
            -CoverCandidateUrl $embeddedCoverPath -CoverSourceEdition 'existing (embedded)'

        $session = New-TestSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
        $proposalPath = Join-Path $script:dataHome 'sessions' $session.sessionId 'proposal.json'
        New-TestProposalFile -Path $proposalPath -Document (New-TestProposalDocument -SessionId $session.sessionId -SourceRoot $script:sourceRoot -Releases @($release))

        $result = Invoke-ReshelfImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome

        $result.Applied | Should -Be 1
        # The resize step still runs (a gap-fill copy might be needed by another track in the
        # release), but this specific track already had its own cover, so it gets $null - Set-
        # ReshelfAudioTags then leaves that file's Tag.Pictures completely untouched.
        Should -Invoke -ModuleName Reshelf.Implementation Invoke-ReshelfFfmpegResize -Times 1
        $script:audioTagsCalls.Count | Should -Be 1
        $script:audioTagsCalls[0].CoverImagePath | Should -BeNullOrEmpty
    }

    It 'gap-fills the found cover into a track that has no embedded cover of its own' {
        $script:audioTagsCalls = [System.Collections.Generic.List[object]]::new()
        Mock -ModuleName Reshelf.Implementation Set-ReshelfAudioTags {
            $script:audioTagsCalls.Add([pscustomobject]@{ Path = $Path; CoverImagePath = $CoverImagePath })
        }

        $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 Track.flac')
        $embeddedCoverPath = Join-Path $script:dataHome 'embedded-covers' 'existing-cover.jpg'
        New-Item -ItemType Directory -Path (Split-Path $embeddedCoverPath) -Force | Out-Null
        Set-Content -LiteralPath $embeddedCoverPath -Value 'existing-cover-bytes' -NoNewline

        # This track has no ExistingCoverArtPath of its own - unlike the previous test.
        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName '01 Track.flac' -ProposedTitle 'Track'
        $release = New-TestReleaseDoc -StableKey 'a1b2c3d4e5f60708' -ArtistFolderName 'Some Band' -ReleaseFolderName '2010 Some Album' `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $t1) -Tracks @($track) `
            -CoverCandidateUrl $embeddedCoverPath -CoverSourceEdition 'existing (embedded)'

        $session = New-TestSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
        $proposalPath = Join-Path $script:dataHome 'sessions' $session.sessionId 'proposal.json'
        New-TestProposalFile -Path $proposalPath -Document (New-TestProposalDocument -SessionId $session.sessionId -SourceRoot $script:sourceRoot -Releases @($release))

        $result = Invoke-ReshelfImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome

        $result.Applied | Should -Be 1
        $script:audioTagsCalls.Count | Should -Be 1
        $expectedCoverPath = Join-Path $script:targetRoot '.reshelf-staging' 'a1b2c3d4e5f60708' '.reshelf-cover-resized.jpg'
        $script:audioTagsCalls[0].CoverImagePath | Should -Be $expectedCoverPath
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

        $result = Invoke-ReshelfImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome

        $result.Applied | Should -Be 1

        # The Discogs cover is embedded and cleaned up as a working file; the source's own loose
        # "cover.jpg" companion is a real target-layout file (manifesto section 4.5) and must survive.
        $finalReleasePath = Join-Path $script:targetRoot 'Some Band' '2010 Some Album'
        Test-Path -LiteralPath (Join-Path $finalReleasePath 'cover.jpg') | Should -Be $true
        Test-Path -LiteralPath (Join-Path $finalReleasePath '.reshelf-cover-resized.jpg') | Should -Be $false
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

        $result = Invoke-ReshelfImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $deepTargetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome

        $result.Applied | Should -Be 1

        $entry = Get-ReshelfApplyLogEntry -StableKey 'a1b2c3d4e5f60708' -DataHome $script:dataHome
        $entry.status | Should -Be 'applied'
        $entry.truncated | Should -Be $true
        $entry.targetPath.Length | Should -BeLessOrEqual 250
        Test-Path -LiteralPath $entry.targetPath | Should -Be $true

        $stagedFile = Get-ChildItem -LiteralPath $entry.targetPath -Filter '*.flac'
        $stagedFile.Name | Should -BeLike '01 *'
        $stagedFile.Name | Should -BeLike '*.flac'
    }

    It 'logs the truncated staged path, not the raw untruncated one, when the commit step fails after staging succeeded' {
        Mock -ModuleName Reshelf.Implementation Move-ReshelfStagedReleaseToTarget { throw 'commit boom' }

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

        $result = Invoke-ReshelfImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $deepTargetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome

        $result.Failed | Should -Be 1

        $entry = Get-ReshelfApplyLogEntry -StableKey 'a1b2c3d4e5f60708' -DataHome $script:dataHome
        $entry.status | Should -Be 'failed'
        $rawUntruncatedPath = Join-Path $deepTargetRoot $longArtist $longAlbum
        $entry.targetPath | Should -Not -Be $rawUntruncatedPath
        $entry.targetPath.Length | Should -BeLessOrEqual 250
        $entry.truncated | Should -Be $true
    }

    It 'removes the now-empty .reshelf-staging folder after every release applies, but leaves a failed release staged for inspection' {
        Mock -ModuleName Reshelf.Implementation Move-ReshelfStagedReleaseToTarget { throw 'commit boom' }

        $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 Track.flac')
        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName '01 Track.flac'
        $release = New-TestReleaseDoc -StableKey 'a1b2c3d4e5f60708' -ArtistFolderName 'Some Band' -ReleaseFolderName '2010 Some Album' `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $t1) -Tracks @($track)

        $session = New-TestSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
        $proposalPath = Join-Path $script:dataHome 'sessions' $session.sessionId 'proposal.json'
        New-TestProposalFile -Path $proposalPath -Document (New-TestProposalDocument -SessionId $session.sessionId -SourceRoot $script:sourceRoot -Releases @($release))

        $result = Invoke-ReshelfImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome

        $result.Failed | Should -Be 1
        # plan/08 "Edge cases": a failed release's staging folder is left in place for inspection -
        # so .reshelf-staging itself must still exist, and this one release's subfolder inside it too.
        $stagingRoot = Join-Path $script:targetRoot '.reshelf-staging'
        Test-Path -LiteralPath $stagingRoot | Should -Be $true
        Test-Path -LiteralPath (Join-Path $stagingRoot 'a1b2c3d4e5f60708') | Should -Be $true
    }

    It 'removes the empty .reshelf-staging folder once every release in the run has applied successfully' {
        $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 Track.flac')
        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName '01 Track.flac'
        $release = New-TestReleaseDoc -StableKey 'a1b2c3d4e5f60708' -ArtistFolderName 'Some Band' -ReleaseFolderName '2010 Some Album' `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $t1) -Tracks @($track)

        $session = New-TestSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
        $proposalPath = Join-Path $script:dataHome 'sessions' $session.sessionId 'proposal.json'
        New-TestProposalFile -Path $proposalPath -Document (New-TestProposalDocument -SessionId $session.sessionId -SourceRoot $script:sourceRoot -Releases @($release))

        $result = Invoke-ReshelfImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome

        $result.Applied | Should -Be 1
        Test-Path -LiteralPath (Join-Path $script:targetRoot '.reshelf-staging') | Should -Be $false
    }

    It 'skips every release on a second, unchanged run and makes no ffmpeg/tag-writing calls' {
        $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 Track.flac')
        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName '01 Track.flac'
        $release = New-TestReleaseDoc -StableKey 'a1b2c3d4e5f60708' -ArtistFolderName 'Some Band' -ReleaseFolderName '2010 Some Album' `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $t1) -Tracks @($track)

        $session = New-TestSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
        $proposalPath = Join-Path $script:dataHome 'sessions' $session.sessionId 'proposal.json'
        New-TestProposalFile -Path $proposalPath -Document (New-TestProposalDocument -SessionId $session.sessionId -SourceRoot $script:sourceRoot -Releases @($release))

        $firstResult = Invoke-ReshelfImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome
        $firstResult.Applied | Should -Be 1

        $secondResult = Invoke-ReshelfImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome

        $secondResult.Applied | Should -Be 0
        $secondResult.Skipped | Should -Be 1
        $secondResult.Failed | Should -Be 0

        Should -Invoke -ModuleName Reshelf.Implementation Set-ReshelfAudioTags -Times 1
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

        Mock -ModuleName Reshelf.Implementation Set-ReshelfAudioTags {
            if ($Path -like "*$failingKey*") { throw 'tag write boom' }
        }

        $session = New-TestSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
        $proposalPath = Join-Path $script:dataHome 'sessions' $session.sessionId 'proposal.json'
        New-TestProposalFile -Path $proposalPath -Document (New-TestProposalDocument -SessionId $session.sessionId -SourceRoot $script:sourceRoot -Releases @($releaseFail, $releaseOk))

        $result = Invoke-ReshelfImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome

        $result.Applied | Should -Be 1
        $result.Failed | Should -Be 1

        $failedEntry = Get-ReshelfApplyLogEntry -StableKey $failingKey -DataHome $script:dataHome
        $failedEntry.status | Should -Be 'failed'
        $failedEntry.errorMessage | Should -BeLike '*tag write boom*'

        Test-Path -LiteralPath (Join-Path $script:targetRoot '.reshelf-staging' $failingKey) | Should -Be $true
        Test-Path -LiteralPath (Join-Path $script:targetRoot 'Band One' '2010 Album One') | Should -Be $false
        Test-Path -LiteralPath (Join-Path $script:targetRoot 'Band Two' '2011 Album Two' '01 Track.flac') | Should -Be $true

        $okEntry = Get-ReshelfApplyLogEntry -StableKey $okKey -DataHome $script:dataHome
        $okEntry.status | Should -Be 'applied'
    }

    It 'fails with an error naming the real missing source file, not a confusing later-step message, when a source file was deleted after proposing' {
        # Found against a real collection: the user deleted a source folder after 'propose' had
        # already recorded it. Copy-Item's default (non-terminating) error let execution continue
        # as if the copy succeeded, so the release used to fail two steps later at tag-writing with
        # a message blaming the missing *staged* file - accurate, but not the real cause.
        $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 Track.flac')
        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName '01 Track.flac'
        $release = New-TestReleaseDoc -StableKey 'a1b2c3d4e5f60708' -ArtistFolderName 'Some Band' -ReleaseFolderName '2010 Some Album' `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $t1) -Tracks @($track)

        $session = New-TestSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
        $proposalPath = Join-Path $script:dataHome 'sessions' $session.sessionId 'proposal.json'
        New-TestProposalFile -Path $proposalPath -Document (New-TestProposalDocument -SessionId $session.sessionId -SourceRoot $script:sourceRoot -Releases @($release))

        Remove-Item -LiteralPath (Split-Path $t1) -Recurse -Force

        $result = Invoke-ReshelfImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome

        $result.Failed | Should -Be 1
        $result.Applied | Should -Be 0
        Test-Path -LiteralPath (Join-Path $script:targetRoot 'Some Band' '2010 Some Album') | Should -Be $false

        $entry = Get-ReshelfApplyLogEntry -StableKey 'a1b2c3d4e5f60708' -DataHome $script:dataHome
        $entry.status | Should -Be 'failed'
        $entry.errorMessage | Should -BeLike "*$([System.Management.Automation.WildcardPattern]::Escape($t1))*"
        $entry.errorMessage | Should -Not -BeLike '*.reshelf-staging*'
    }

    It 'sets the session stage to applied when everything succeeds, partially-applied when something fails, and applied (not partially-applied) when releases are only skipped' {
        # All-succeed case.
        $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Band One' '2010 Album One' '01 Track.flac')
        $releaseOk = New-TestReleaseDoc -StableKey 'aaaaaaaaaaaaaaaa' -ArtistFolderName 'Band One' -ReleaseFolderName '2010 Album One' `
            -Year 2010 -Album 'Album One' -SourceFolderPath (Split-Path $t1) -Tracks @((New-TestTrack -SourceFilePath $t1 -ProposedFileName '01 Track.flac'))

        $okSession = New-TestSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
        $okProposalPath = Join-Path $script:dataHome 'sessions' $okSession.sessionId 'proposal.json'
        New-TestProposalFile -Path $okProposalPath -Document (New-TestProposalDocument -SessionId $okSession.sessionId -SourceRoot $script:sourceRoot -Releases @($releaseOk))

        Invoke-ReshelfImplementation -SessionId $okSession.sessionId -ProposalPath $okProposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome | Out-Null

        (Get-ReshelfSession -SessionId $okSession.sessionId -DataHome $script:dataHome).stage | Should -Be 'applied'

        # One failure among others.
        $t2 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Band Two' '2011 Album Two' '01 Track.flac')
        $failingKey = 'bbbbbbbbbbbbbbbb'
        $releaseFail = New-TestReleaseDoc -StableKey $failingKey -ArtistFolderName 'Band Two' -ReleaseFolderName '2011 Album Two' `
            -Year 2011 -Album 'Album Two' -SourceFolderPath (Split-Path $t2) -Tracks @((New-TestTrack -SourceFilePath $t2 -ProposedFileName '01 Track.flac'))
        Mock -ModuleName Reshelf.Implementation Set-ReshelfAudioTags { throw 'tag write boom' }

        $failSession = New-TestSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
        $failProposalPath = Join-Path $script:dataHome 'sessions' $failSession.sessionId 'proposal.json'
        New-TestProposalFile -Path $failProposalPath -Document (New-TestProposalDocument -SessionId $failSession.sessionId -SourceRoot $script:sourceRoot -Releases @($releaseFail))

        Invoke-ReshelfImplementation -SessionId $failSession.sessionId -ProposalPath $failProposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome | Out-Null

        (Get-ReshelfSession -SessionId $failSession.sessionId -DataHome $script:dataHome).stage | Should -Be 'partially-applied'

        # Skipped-only (an unresolved release, not included) must stay 'applied', not 'partially-applied' -
        # a skip is "nothing to do yet", not a failure (plan/10).
        Mock -ModuleName Reshelf.Implementation Set-ReshelfAudioTags { }
        $t3 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Band Three' '2012 Album Three' '01 Track.flac')
        $releaseUnresolved = New-TestReleaseDoc -StableKey 'cccccccccccccccc' -ArtistFolderName 'Band Three' -ReleaseFolderName '2012 Album Three' `
            -Year 2012 -Album 'Album Three' -SourceFolderPath (Split-Path $t3) -Tracks @((New-TestTrack -SourceFilePath $t3 -ProposedFileName '01 Track.flac')) `
            -DiscogsStatus 'ambiguous' -HumanReviewResolved $false -HumanReviewRequired $true

        $skipSession = New-TestSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
        $skipProposalPath = Join-Path $script:dataHome 'sessions' $skipSession.sessionId 'proposal.json'
        New-TestProposalFile -Path $skipProposalPath -Document (New-TestProposalDocument -SessionId $skipSession.sessionId -SourceRoot $script:sourceRoot -Releases @($releaseUnresolved))

        $skipResult = Invoke-ReshelfImplementation -SessionId $skipSession.sessionId -ProposalPath $skipProposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome
        $skipResult.Skipped | Should -Be 1
        $skipResult.Failed | Should -Be 0

        (Get-ReshelfSession -SessionId $skipSession.sessionId -DataHome $script:dataHome).stage | Should -Be 'applied'
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

        $result = Invoke-ReshelfImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome

        $result.Applied | Should -Be 1

        $finalReleasePath = Join-Path $script:targetRoot 'Some Band' '2010 Some Album'
        Test-Path -LiteralPath (Join-Path $finalReleasePath '01 Track.flac') | Should -Be $true
        Test-Path -LiteralPath (Join-Path $finalReleasePath '01 Track.mp3') | Should -Be $false

        $ledgerEntry = Get-TestLossyEntry -StableKey 'a1b2c3d4e5f60708' -DataHome $script:dataHome
        $ledgerEntry.status | Should -Be 'upgraded'
        $ledgerEntry.upgradedUtc | Should -Not -BeNullOrEmpty
    }

    It 'corrects the lossy-tracking targetPath to the committed path on a log-for-upgrade release, but not under -WhatIf' {
        # Step 6 logged the proposed path; a folder name edited in the UI afterwards must not leave the
        # ledger pointing at a folder that was never created.
        $staleTargetPath = Join-Path $script:targetRoot 'Some Band' '2010 Some Album'
        Add-TestLossyEntry -StableKey 'a1b2c3d4e5f60708' -Artist 'Some Band' -Album 'Some Album' -Year 2010 `
            -TargetPath $staleTargetPath -Format 'mp3' -DataHome $script:dataHome

        $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 Track.mp3')
        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName '01 Track.mp3' -Format 'mp3' -IsLossless $false
        $release = New-TestReleaseDoc -StableKey 'a1b2c3d4e5f60708' -ArtistFolderName 'Some Band' -ReleaseFolderName '2010 Some Album (Edited)' `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $t1) -Tracks @($track) -IsLossy $true -LossyAction 'log-for-upgrade'

        $session = New-TestSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
        $proposalPath = Join-Path $script:dataHome 'sessions' $session.sessionId 'proposal.json'
        New-TestProposalFile -Path $proposalPath -Document (New-TestProposalDocument -SessionId $session.sessionId -SourceRoot $script:sourceRoot -Releases @($release))

        Invoke-ReshelfImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome -WhatIf | Out-Null
        (Get-TestLossyEntry -StableKey 'a1b2c3d4e5f60708' -DataHome $script:dataHome).targetPath | Should -Be $staleTargetPath

        $result = Invoke-ReshelfImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome
        $result.Applied | Should -Be 1

        $committedPath = Join-Path $script:targetRoot 'Some Band' '2010 Some Album (Edited)'
        Test-Path -LiteralPath (Join-Path $committedPath '01 Track.mp3') | Should -Be $true
        $ledgerEntry = Get-TestLossyEntry -StableKey 'a1b2c3d4e5f60708' -DataHome $script:dataHome
        $ledgerEntry.targetPath | Should -Be $committedPath
        $ledgerEntry.status | Should -Be 'pending-upgrade'
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

        $defaultResult = Invoke-ReshelfImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome
        $defaultResult.Skipped | Should -Be 1
        $defaultResult.Applied | Should -Be 0
        Test-Path -LiteralPath (Join-Path $script:targetRoot 'Some Band' '2010 Some Album') | Should -Be $false

        $includedResult = Invoke-ReshelfImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome -IncludeUnresolved
        $includedResult.Applied | Should -Be 1
        Test-Path -LiteralPath (Join-Path $script:targetRoot 'Some Band' '2010 Some Album' '01 Track.flac') | Should -Be $true
    }

    It 'skips a targetAction conflict release with humanReview.resolved = false, leaving the existing target untouched, unless -IncludeUnresolved' {
        $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 Track.flac') -Content 'new-source-content'
        # Pre-existing, DIFFERENT content already at the final target path - proves it survives
        # untouched when the conflict release is correctly skipped (this is exactly the scenario
        # Move-ReshelfStagedReleaseToTarget's unconditional overwrite would otherwise silently destroy).
        $existingTargetFile = New-TestAudioFile -Path (Join-Path $script:targetRoot 'Some Band' '2010 Some Album' '01 Track.flac') -Content 'pre-existing-different-content'

        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName '01 Track.flac'
        $release = New-TestReleaseDoc -StableKey 'a1b2c3d4e5f60708' -ArtistFolderName 'Some Band' -ReleaseFolderName '2010 Some Album' `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $t1) -Tracks @($track) `
            -TargetAction 'conflict' -HumanReviewResolved $false -HumanReviewRequired $true

        $session = New-TestSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
        $proposalPath = Join-Path $script:dataHome 'sessions' $session.sessionId 'proposal.json'
        New-TestProposalFile -Path $proposalPath -Document (New-TestProposalDocument -SessionId $session.sessionId -SourceRoot $script:sourceRoot -Releases @($release))

        $defaultResult = Invoke-ReshelfImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome
        $defaultResult.Skipped | Should -Be 1
        $defaultResult.Applied | Should -Be 0
        Test-Path -LiteralPath (Join-Path $script:targetRoot '.reshelf-staging' 'a1b2c3d4e5f60708') | Should -Be $false
        (Get-Content -LiteralPath $existingTargetFile -Raw) | Should -Be 'pre-existing-different-content'

        $includedResult = Invoke-ReshelfImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome -IncludeUnresolved
        $includedResult.Applied | Should -Be 1
        (Get-Content -LiteralPath $existingTargetFile -Raw) | Should -Be 'new-source-content'
    }

    It 'fails a create-new release whose target folder already exists, leaving that folder untouched (plan/12 milestone 7)' {
        $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 Track.flac') -Content 'new-source-content'
        $existingTargetFile = New-TestAudioFile -Path (Join-Path $script:targetRoot 'Some Band' '2010 Some Album' '01 Track.mp3') -Content 'existing-lossy-content'

        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName '01 Track.flac'
        $release = New-TestReleaseDoc -StableKey 'a1b2c3d4e5f60708' -ArtistFolderName 'Some Band' -ReleaseFolderName '2010 Some Album' `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $t1) -Tracks @($track) `
            -TargetAction 'create-new' -HumanReviewResolved $true

        $session = New-TestSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
        $proposalPath = Join-Path $script:dataHome 'sessions' $session.sessionId 'proposal.json'
        New-TestProposalFile -Path $proposalPath -Document (New-TestProposalDocument -SessionId $session.sessionId -SourceRoot $script:sourceRoot -Releases @($release))

        $result = Invoke-ReshelfImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome

        $result.Failed | Should -Be 1
        $result.Applied | Should -Be 0
        (Get-Content -LiteralPath $existingTargetFile -Raw) | Should -Be 'existing-lossy-content'
        Test-Path -LiteralPath (Join-Path $script:targetRoot 'Some Band' '2010 Some Album' '01 Track.flac') | Should -Be $false
        $logEntry = InModuleScope Reshelf.Implementation -Parameters @{ dataHome = $script:dataHome } {
            param($dataHome)
            Get-ReshelfApplyLogEntry -StableKey 'a1b2c3d4e5f60708' -DataHome $dataHome
        }
        $logEntry.status | Should -Be 'failed'
        $logEntry.errorMessage | Should -Match "already exists but the proposal says 'create-new'"
    }

    It 'never applies a rejected release, even with -IncludeUnresolved' {
        # A rejection is a deliberate, permanent "never apply this" decision (e.g. one of two
        # different physical pressings of the same album) - unlike a merely unresolved release,
        # -IncludeUnresolved must not override it.
        $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 Track.flac')
        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName '01 Track.flac'
        $release = New-TestReleaseDoc -StableKey 'a1b2c3d4e5f60708' -ArtistFolderName 'Some Band' -ReleaseFolderName '2010 Some Album' `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $t1) -Tracks @($track) `
            -HumanReviewResolved $true -HumanReviewRejected $true

        $session = New-TestSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
        $proposalPath = Join-Path $script:dataHome 'sessions' $session.sessionId 'proposal.json'
        New-TestProposalFile -Path $proposalPath -Document (New-TestProposalDocument -SessionId $session.sessionId -SourceRoot $script:sourceRoot -Releases @($release))

        $result = Invoke-ReshelfImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome -IncludeUnresolved
        $result.Rejected | Should -Be 1
        $result.Applied | Should -Be 0
        $result.Skipped | Should -Be 0
        Test-Path -LiteralPath (Join-Path $script:targetRoot 'Some Band' '2010 Some Album') | Should -Be $false
    }

    It 'never deletes source tracks or companion files - source is always read-only' {
        $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 Track.flac')
        $nestedCompanion = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' 'Scans' 'front.jpg')

        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName '01 Track.flac'
        $companion = [pscustomobject]@{ sourcePath = $nestedCompanion; kind = 'cover'; placement = 'nested' }
        $release = New-TestReleaseDoc -StableKey 'a1b2c3d4e5f60708' -ArtistFolderName 'Some Band' -ReleaseFolderName '2010 Some Album' `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $t1) -Tracks @($track) -CompanionFiles @($companion)

        $session = New-TestSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
        $proposalPath = Join-Path $script:dataHome 'sessions' $session.sessionId 'proposal.json'
        New-TestProposalFile -Path $proposalPath -Document (New-TestProposalDocument -SessionId $session.sessionId -SourceRoot $script:sourceRoot -Releases @($release))

        $result = Invoke-ReshelfImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome

        $result.Applied | Should -Be 1

        $finalReleasePath = Join-Path $script:targetRoot 'Some Band' '2010 Some Album'
        Test-Path -LiteralPath (Join-Path $finalReleasePath '01 Track.flac') | Should -Be $true
        Test-Path -LiteralPath (Join-Path $finalReleasePath 'Scans' 'front.jpg') | Should -Be $true

        # A former "move mode" used to delete these after a successful commit - removed entirely
        # after an incident destroyed source releases with no other backup. Source must survive.
        Test-Path -LiteralPath $t1 | Should -Be $true
        Test-Path -LiteralPath $nestedCompanion | Should -Be $true
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
                    -Year 1994 -Album 'Live In Concert' -SourceFolderPath $script:cueReleaseDir -Tracks @($track1, $track2) -CueSheets @($cueSheet)
            }

            function New-TestPerDiscCueRelease {
                param([string]$StableKey = 'c2c2c2c2c2c2c2c2')

                # Two discs, each its own cue image sharing no source file with the other - the real
                # shape Reshelf.Recognition.psm1 now produces for a per-disc-cue release (e.g. AC-DC
                # "Stiff Upper Lip", CD 1/CD 2 each with their own .flac + .cue).
                $disc1Audio = Join-Path $script:cueReleaseDir 'CD 1' 'Disc One.flac'
                $disc2Audio = Join-Path $script:cueReleaseDir 'CD 2' 'Disc Two.flac'
                New-TestAudioFile -Path $disc1Audio | Out-Null
                New-TestAudioFile -Path $disc2Audio | Out-Null

                $cueSheet1 = [pscustomobject]@{ cueFilePath = Join-Path $script:cueReleaseDir 'CD 1' 'Disc One.cue'; audioFilePath = $disc1Audio }
                $cueSheet2 = [pscustomobject]@{ cueFilePath = Join-Path $script:cueReleaseDir 'CD 2' 'Disc Two.cue'; audioFilePath = $disc2Audio }

                # Deliberately the SAME proposedTrackNumber (1) on both discs' first track - the real
                # numbering restarts per disc, and the split must still use each track's own
                # cueTimestamp/sourceFilePath rather than a release-wide sort by proposedTrackNumber.
                $track1 = New-TestTrack -SourceFilePath $disc1Audio -ProposedFileName '01 Disc One Track One.flac' `
                    -ProposedTrackNumber 1 -ProposedDiscNumber 1 -ProposedTitle 'Disc One Track One' -CueTimestamp '00:00:00' -IsCueVirtualTrack $true -DiscFolder 'CD 1' -Artist 'Some Band' -Album 'Two Discs' -Year 2001
                $track2 = New-TestTrack -SourceFilePath $disc1Audio -ProposedFileName '02 Disc One Track Two.flac' `
                    -ProposedTrackNumber 2 -ProposedDiscNumber 1 -ProposedTitle 'Disc One Track Two' -CueTimestamp '00:02:00' -IsCueVirtualTrack $true -DiscFolder 'CD 1' -Artist 'Some Band' -Album 'Two Discs' -Year 2001
                $track3 = New-TestTrack -SourceFilePath $disc2Audio -ProposedFileName '01 Disc Two Track One.flac' `
                    -ProposedTrackNumber 1 -ProposedDiscNumber 2 -ProposedTitle 'Disc Two Track One' -CueTimestamp '00:00:00' -IsCueVirtualTrack $true -DiscFolder 'CD 2' -Artist 'Some Band' -Album 'Two Discs' -Year 2001

                return New-TestReleaseDoc -StableKey $StableKey -ArtistFolderName 'Some Band' -ReleaseFolderName '2001 Two Discs' `
                    -Year 2001 -Album 'Two Discs' -SourceFolderPath $script:cueReleaseDir -Tracks @($track1, $track2, $track3) -CueSheets @($cueSheet1, $cueSheet2)
            }
        }

        BeforeEach {
            $script:cueFixtureDir = "$PSScriptRoot/fixtures/sample-source-tree/Pink Floyd/1994 Live In Concert (Bootleg)"
            $script:cueReleaseDir = Join-Path $script:sourceRoot 'Pink Floyd' '1994 Live In Concert (Bootleg)'
            New-Item -ItemType Directory -Path $script:cueReleaseDir -Force | Out-Null
            Copy-Item -LiteralPath (Join-Path $script:cueFixtureDir 'Live In Concert.cue') -Destination (Join-Path $script:cueReleaseDir 'Live In Concert.cue')
            New-TestAudioFile -Path (Join-Path $script:cueReleaseDir 'Live In Concert.flac') | Out-Null

            $script:splitCalls = [System.Collections.Generic.List[object]]::new()
            Mock -ModuleName Reshelf.Implementation Invoke-ReshelfFfmpegSplit {
                $script:splitCalls.Add([pscustomobject]@{ Start = $StartTimestamp; End = $EndTimestamp; Output = $OutputPath })
                Set-Content -LiteralPath $OutputPath -Value 'split' -NoNewline
            }
        }

        It 'splits once per cue track and never deletes the cue/audio source - source is always read-only' {
            $release = New-TestCueRelease
            $session = New-TestSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
            $proposalPath = Join-Path $script:dataHome 'sessions' $session.sessionId 'proposal.json'
            New-TestProposalFile -Path $proposalPath -Document (New-TestProposalDocument -SessionId $session.sessionId -SourceRoot $script:sourceRoot -Releases @($release))

            $result = Invoke-ReshelfImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
                -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome

            $result.Applied | Should -Be 1
            $script:splitCalls.Count | Should -Be 2
            $script:splitCalls[0].Start | Should -Be '0.000'
            $script:splitCalls[0].End | Should -Be '192.600'
            $script:splitCalls[1].Start | Should -Be '192.600'
            $script:splitCalls[1].End | Should -BeNullOrEmpty

            # A former design deleted the single-file+cue source as "superseded by the split" -
            # removed entirely after an incident destroyed source releases with no other backup.
            Test-Path -LiteralPath (Join-Path $script:cueReleaseDir 'Live In Concert.cue') | Should -Be $true
            Test-Path -LiteralPath (Join-Path $script:cueReleaseDir 'Live In Concert.flac') | Should -Be $true

            $finalReleasePath = Join-Path $script:targetRoot 'Pink Floyd' '1994 Live In Concert'
            Test-Path -LiteralPath (Join-Path $finalReleasePath '01 Speak To Me.flac') | Should -Be $true
            Test-Path -LiteralPath (Join-Path $finalReleasePath '02 Breathe.flac') | Should -Be $true
        }

        It 'leaves the cue/audio source in place when the release fails after splitting' {
            Mock -ModuleName Reshelf.Implementation Set-ReshelfAudioTags { throw 'tag write boom' }

            $release = New-TestCueRelease
            $session = New-TestSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
            $proposalPath = Join-Path $script:dataHome 'sessions' $session.sessionId 'proposal.json'
            New-TestProposalFile -Path $proposalPath -Document (New-TestProposalDocument -SessionId $session.sessionId -SourceRoot $script:sourceRoot -Releases @($release))

            $result = Invoke-ReshelfImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
                -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome

            $result.Failed | Should -Be 1
            Test-Path -LiteralPath (Join-Path $script:cueReleaseDir 'Live In Concert.cue') | Should -Be $true
            Test-Path -LiteralPath (Join-Path $script:cueReleaseDir 'Live In Concert.flac') | Should -Be $true
        }

        It 'splits a per-disc-cue release from each disc''s own source file, not one shared source' {
            $release = New-TestPerDiscCueRelease
            $session = New-TestSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
            $proposalPath = Join-Path $script:dataHome 'sessions' $session.sessionId 'proposal.json'
            New-TestProposalFile -Path $proposalPath -Document (New-TestProposalDocument -SessionId $session.sessionId -SourceRoot $script:sourceRoot -Releases @($release))

            $result = Invoke-ReshelfImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
                -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome

            $result.Applied | Should -Be 1
            $script:splitCalls.Count | Should -Be 3

            $disc1Call = $script:splitCalls | Where-Object { $_.Output -like '*Disc One Track One*' }
            $disc2Call = $script:splitCalls | Where-Object { $_.Output -like '*Disc Two Track One*' }
            $disc1Call | Should -Not -BeNullOrEmpty
            $disc2Call | Should -Not -BeNullOrEmpty

            $finalReleasePath = Join-Path $script:targetRoot 'Some Band' '2001 Two Discs'
            Test-Path -LiteralPath (Join-Path $finalReleasePath '01 Disc One Track One.flac') | Should -Be $true
            Test-Path -LiteralPath (Join-Path $finalReleasePath '02 Disc One Track Two.flac') | Should -Be $true
            Test-Path -LiteralPath (Join-Path $finalReleasePath '01 Disc Two Track One.flac') | Should -Be $true
        }
    }

    It 'falls back to a kind-word-prefixed name for a loose companion from a pre-existing proposal with no proposedFileName, and preserves a nested companion subfolder' {
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

        $result = Invoke-ReshelfImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome

        $result.Applied | Should -Be 1

        $finalReleasePath = Join-Path $script:targetRoot 'Some Band' '2010 Some Album'
        # No proposedFileName was supplied (simulating a proposal.json written before that field
        # existed), so Resolve-ReshelfCompanionTargetPath falls back to computing a letter-first name
        # from the companion's kind ('photo' -> 'Photo ...') - never the old '_' digit prefix, which
        # would sort *before* tracks in Explorer and so broke manifesto SS4.5.
        Test-Path -LiteralPath (Join-Path $finalReleasePath 'Photo 01-photo.jpg') | Should -Be $true
        Test-Path -LiteralPath (Join-Path $finalReleasePath 'Scans' 'front.jpg') | Should -Be $true
    }

    It 'uses proposedFileName for a loose companion when the proposal supplies one' {
        $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 Track.flac')
        $looseCompanion = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01-photo.jpg')

        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName '01 Track.flac'
        $companions = @(
            [pscustomobject]@{ sourcePath = $looseCompanion; kind = 'photo'; placement = 'loose'; include = $true; proposedFileName = 'Backstage Photo.jpg' }
        )
        $release = New-TestReleaseDoc -StableKey 'a1b2c3d4e5f60708' -ArtistFolderName 'Some Band' -ReleaseFolderName '2010 Some Album' `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $t1) -Tracks @($track) -CompanionFiles $companions

        $session = New-TestSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
        $proposalPath = Join-Path $script:dataHome 'sessions' $session.sessionId 'proposal.json'
        New-TestProposalFile -Path $proposalPath -Document (New-TestProposalDocument -SessionId $session.sessionId -SourceRoot $script:sourceRoot -Releases @($release))

        $result = Invoke-ReshelfImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome

        $result.Applied | Should -Be 1
        $finalReleasePath = Join-Path $script:targetRoot 'Some Band' '2010 Some Album'
        Test-Path -LiteralPath (Join-Path $finalReleasePath 'Backstage Photo.jpg') | Should -Be $true
    }

    It 'excludes a companion with include = $false from copying, and always leaves its source in place' {
        $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 Track.flac')
        $excludedCompanion = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' 'Booklet skip.jpg')

        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName '01 Track.flac'
        $companions = @(
            [pscustomobject]@{ sourcePath = $excludedCompanion; kind = 'booklet'; placement = 'loose'; include = $false; proposedFileName = 'Booklet skip.jpg' }
        )
        $release = New-TestReleaseDoc -StableKey 'a1b2c3d4e5f60708' -ArtistFolderName 'Some Band' -ReleaseFolderName '2010 Some Album' `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $t1) -Tracks @($track) -CompanionFiles $companions

        $session = New-TestSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
        $proposalPath = Join-Path $script:dataHome 'sessions' $session.sessionId 'proposal.json'
        New-TestProposalFile -Path $proposalPath -Document (New-TestProposalDocument -SessionId $session.sessionId -SourceRoot $script:sourceRoot -Releases @($release))

        $result = Invoke-ReshelfImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome

        $result.Applied | Should -Be 1
        $finalReleasePath = Join-Path $script:targetRoot 'Some Band' '2010 Some Album'
        Test-Path -LiteralPath (Join-Path $finalReleasePath 'Booklet skip.jpg') | Should -Be $false
        # An excluded companion is never copied - and, like every source file, its own source is
        # never deleted either.
        Test-Path -LiteralPath $excludedCompanion | Should -Be $true
    }

    It 'fails the release with a clear message when an included loose companion name does not start with a letter' {
        $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 Track.flac')
        $badCompanion = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' 'photo.jpg')

        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName '01 Track.flac'
        $companions = @(
            [pscustomobject]@{ sourcePath = $badCompanion; kind = 'photo'; placement = 'loose'; include = $true; proposedFileName = '01 photo.jpg' }
        )
        $release = New-TestReleaseDoc -StableKey 'a1b2c3d4e5f60708' -ArtistFolderName 'Some Band' -ReleaseFolderName '2010 Some Album' `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $t1) -Tracks @($track) -CompanionFiles $companions

        $session = New-TestSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
        $proposalPath = Join-Path $script:dataHome 'sessions' $session.sessionId 'proposal.json'
        New-TestProposalFile -Path $proposalPath -Document (New-TestProposalDocument -SessionId $session.sessionId -SourceRoot $script:sourceRoot -Releases @($release))

        $result = Invoke-ReshelfImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome

        $result.Failed | Should -Be 1
        $result.Applied | Should -Be 0
    }

    It 'fails the release when two included companions would resolve to the same target path' {
        $t1 = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' '01 Track.flac')
        $companionA = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' 'a.jpg')
        $companionB = New-TestAudioFile -Path (Join-Path $script:sourceRoot 'Some Band' '2010 Some Album' 'b.jpg')

        $track = New-TestTrack -SourceFilePath $t1 -ProposedFileName '01 Track.flac'
        $companions = @(
            [pscustomobject]@{ sourcePath = $companionA; kind = 'other'; placement = 'loose'; include = $true; proposedFileName = 'Extra Same.jpg' }
            [pscustomobject]@{ sourcePath = $companionB; kind = 'other'; placement = 'loose'; include = $true; proposedFileName = 'Extra Same.jpg' }
        )
        $release = New-TestReleaseDoc -StableKey 'a1b2c3d4e5f60708' -ArtistFolderName 'Some Band' -ReleaseFolderName '2010 Some Album' `
            -Year 2010 -Album 'Some Album' -SourceFolderPath (Split-Path $t1) -Tracks @($track) -CompanionFiles $companions

        $session = New-TestSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
        $proposalPath = Join-Path $script:dataHome 'sessions' $session.sessionId 'proposal.json'
        New-TestProposalFile -Path $proposalPath -Document (New-TestProposalDocument -SessionId $session.sessionId -SourceRoot $script:sourceRoot -Releases @($release))

        $result = Invoke-ReshelfImplementation -SessionId $session.sessionId -ProposalPath $proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome

        $result.Failed | Should -Be 1
        $result.Applied | Should -Be 0
    }
}
