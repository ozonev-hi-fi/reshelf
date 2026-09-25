#Requires -Version 7.4

Import-Module Pester -MinimumVersion 5.0

# Every other test file mocks Set-TaggerAudioTags / Get-TaggerAudioTags, so no test anywhere opens a
# real audio file with the real TagLibSharp.dll (plan/11's "Implementation module verification" step
# 3). This file closes that gap. It needs a real TagLibSharp.dll and a real ffmpeg on PATH - both are
# hard requirements here (not skipped) since a silent skip would let this coverage gap go unnoticed
# again; BeforeAll throws with the same install hint Import-TaggerTagLibSharp itself gives.

BeforeAll {
    Import-Module "$PSScriptRoot/../scripts/common/Tagger.Common.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Tagger.Json.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Tagger.Settings.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Tagger.Recognition.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Tagger.Discogs.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Tagger.EditProposal.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Tagger.Implementation.psm1" -Force

    # Tagger.Implementation.psm1 re-imports Common internally as part of loading, which turns it into
    # a nested module of Tagger.Implementation - PowerShell then hides Resolve-TaggerDataHome from
    # this script's own top-level scope (same gotcha noted in Tagger.Implementation.Tests.ps1).
    # Routing through Implementation's own module scope, which always has it, avoids that fragility.
    $script:DataHome = InModuleScope Tagger.Implementation { Resolve-TaggerDataHome }
    $script:TagLibSharpPath = Join-Path $script:DataHome 'lib' 'TagLibSharp.dll'
    if (-not (Test-Path -LiteralPath $script:TagLibSharpPath -PathType Leaf)) {
        throw "TagLibSharp.dll not found at '$script:TagLibSharpPath'. Download the TagLibSharp NuGet " +
            "package (e.g. 'dotnet add package TagLibSharp' in a throwaway project), copy " +
            "TagLibSharp.dll from its lib/netstandard2.0 folder to that path, or set " +
            "settings.taglibSharpPath to its location. This test file requires the real DLL, it does " +
            "not mock it."
    }
    Add-Type -Path $script:TagLibSharpPath

    $script:FfmpegPath = (Get-Command ffmpeg -ErrorAction SilentlyContinue).Source
    if (-not $script:FfmpegPath) {
        throw 'ffmpeg not found on PATH. This test file requires real ffmpeg to generate test audio/cover media, it does not mock it.'
    }

    function New-TestAudioFile {
        param(
            [Parameter(Mandatory)] [string]$Path,
            [ValidateSet('flac', 'mp3')] [string]$Format = 'flac'
        )
        # mp3 needs an explicit bitrate: TagLibSharp estimates an mp3's duration from file size /
        # bitrate when no Xing/VBR header is present, and ffmpeg's libmp3lame default (a low, ~VBR
        # setting) makes that estimate wildly wrong (~2x for a 1-second clip) - a fixed 128k bitrate
        # keeps the read-back duration close to the real 1 second.
        $bitrateArgs = if ($Format -eq 'mp3') { @('-b:a', '128k') } else { @() }
        & $script:FfmpegPath -y -hide_banner -loglevel error -f lavfi -i 'anullsrc=r=44100:cl=stereo' -t 1 @bitrateArgs -- $Path
        if ($LASTEXITCODE -ne 0) { throw "ffmpeg failed to create test audio file '$Path' (exit $LASTEXITCODE)." }
    }

    function New-TestCoverImage {
        param(
            [Parameter(Mandatory)] [string]$Path,
            [string]$Color = 'red'
        )
        & $script:FfmpegPath -y -hide_banner -loglevel error -f lavfi -i "color=c=$($Color):s=64x64" -frames:v 1 -- $Path
        if ($LASTEXITCODE -ne 0) { throw "ffmpeg failed to create test cover image '$Path' (exit $LASTEXITCODE)." }
    }

    function Open-TagLibFile {
        param([Parameter(Mandatory)] [string]$Path)
        return [TagLib.File]::Create($Path)
    }

    function Get-TestSafeFileName {
        param([Parameter(Mandatory)] [AllowEmptyString()] [string]$Name)
        return InModuleScope Tagger.Implementation -Parameters @{ n = $Name } {
            param($n)
            ConvertTo-SafeFileName -Name $n
        }
    }
}

Describe 'Set-TaggerAudioTags round-trip (real TagLibSharp)' -Tag 'Integration' {
    BeforeEach {
        $script:workDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:workDir -Force | Out-Null
    }

    Context '<_>' -ForEach @('flac', 'mp3') {
        BeforeEach {
            $script:audioPath = Join-Path $script:workDir "track.$_"
            New-TestAudioFile -Path $script:audioPath -Format $_
        }

        It 'persists every tag field' {
            $tags = [pscustomobject]@{
                artist      = 'Radiohead'
                albumArtist = 'Radiohead'
                album       = 'OK Computer'
                year        = 1997
                discNumber  = 1
                track       = 2
                title       = 'Paranoid Android'
            }
            Set-TaggerAudioTags -Path $script:audioPath -Tags $tags -TagLibSharpPath $script:TagLibSharpPath

            $file = Open-TagLibFile -Path $script:audioPath
            try {
                $file.Tag.FirstPerformer | Should -Be 'Radiohead'
                $file.Tag.FirstAlbumArtist | Should -Be 'Radiohead'
                $file.Tag.Album | Should -Be 'OK Computer'
                $file.Tag.Year | Should -Be 1997
                $file.Tag.Disc | Should -Be 1
                $file.Tag.Track | Should -Be 2
                $file.Tag.Title | Should -Be 'Paranoid Android'
            }
            finally {
                $file.Dispose()
            }
        }

        It 'embeds the cover as one FrontCover jpeg with identical bytes' {
            $coverPath = Join-Path $script:workDir 'cover.jpg'
            New-TestCoverImage -Path $coverPath -Color 'red'
            $expectedBytes = [System.IO.File]::ReadAllBytes($coverPath)

            $tags = [pscustomobject]@{
                artist = 'Artist'; albumArtist = 'Artist'; album = 'Album'; year = 2000
                discNumber = 1; track = 1; title = 'Title'
            }
            Set-TaggerAudioTags -Path $script:audioPath -Tags $tags -CoverImagePath $coverPath -TagLibSharpPath $script:TagLibSharpPath

            $file = Open-TagLibFile -Path $script:audioPath
            try {
                $file.Tag.Pictures.Count | Should -Be 1
                $file.Tag.Pictures[0].Type | Should -Be ([TagLib.PictureType]::FrontCover)
                $file.Tag.Pictures[0].MimeType | Should -Be 'image/jpeg'
                [byte[]]$actualBytes = $file.Tag.Pictures[0].Data.Data
                [System.Convert]::ToBase64String($actualBytes) | Should -Be ([System.Convert]::ToBase64String($expectedBytes))
            }
            finally {
                $file.Dispose()
            }
        }

        It 'round-trips non-ASCII text' {
            $tags = [pscustomobject]@{
                artist      = 'Björk'
                albumArtist = 'Björk'
                album       = 'Океан Ельзи'
                year        = 2001
                discNumber  = 1
                track       = 1
                title       = 'Ça plane pour moi'
            }
            Set-TaggerAudioTags -Path $script:audioPath -Tags $tags -TagLibSharpPath $script:TagLibSharpPath

            $file = Open-TagLibFile -Path $script:audioPath
            try {
                $file.Tag.FirstPerformer | Should -Be 'Björk'
                $file.Tag.Album | Should -Be 'Океан Ельзи'
                $file.Tag.Title | Should -Be 'Ça plane pour moi'
            }
            finally {
                $file.Dispose()
            }
        }

        It 'replaces old tags and old cover on a second write' {
            $coverA = Join-Path $script:workDir 'cover-a.jpg'
            $coverB = Join-Path $script:workDir 'cover-b.jpg'
            New-TestCoverImage -Path $coverA -Color 'red'
            New-TestCoverImage -Path $coverB -Color 'blue'
            $expectedBytesB = [System.IO.File]::ReadAllBytes($coverB)

            $tagsA = [pscustomobject]@{ artist = 'First'; albumArtist = 'First'; album = 'First Album'; year = 1990; discNumber = 1; track = 1; title = 'First Title' }
            $tagsB = [pscustomobject]@{ artist = 'Second'; albumArtist = 'Second'; album = 'Second Album'; year = 2020; discNumber = 2; track = 5; title = 'Second Title' }

            Set-TaggerAudioTags -Path $script:audioPath -Tags $tagsA -CoverImagePath $coverA -TagLibSharpPath $script:TagLibSharpPath
            Set-TaggerAudioTags -Path $script:audioPath -Tags $tagsB -CoverImagePath $coverB -TagLibSharpPath $script:TagLibSharpPath

            $file = Open-TagLibFile -Path $script:audioPath
            try {
                $file.Tag.FirstPerformer | Should -Be 'Second'
                $file.Tag.Album | Should -Be 'Second Album'
                $file.Tag.Title | Should -Be 'Second Title'
                $file.Tag.Disc | Should -Be 2
                $file.Tag.Track | Should -Be 5
                $file.Tag.Pictures.Count | Should -Be 1
                [byte[]]$actualBytes = $file.Tag.Pictures[0].Data.Data
                [System.Convert]::ToBase64String($actualBytes) | Should -Be ([System.Convert]::ToBase64String($expectedBytesB))
            }
            finally {
                $file.Dispose()
            }
        }

        It 'leaves the cover alone when no CoverImagePath is given on a later write' {
            $coverPath = Join-Path $script:workDir 'cover.jpg'
            New-TestCoverImage -Path $coverPath -Color 'red'
            $expectedBytes = [System.IO.File]::ReadAllBytes($coverPath)

            $tagsWithCover = [pscustomobject]@{ artist = 'A'; albumArtist = 'A'; album = 'Alb'; year = 2000; discNumber = 1; track = 1; title = 'T1' }
            $tagsNoCover = [pscustomobject]@{ artist = 'A'; albumArtist = 'A'; album = 'Alb'; year = 2000; discNumber = 1; track = 2; title = 'T2' }

            Set-TaggerAudioTags -Path $script:audioPath -Tags $tagsWithCover -CoverImagePath $coverPath -TagLibSharpPath $script:TagLibSharpPath
            Set-TaggerAudioTags -Path $script:audioPath -Tags $tagsNoCover -TagLibSharpPath $script:TagLibSharpPath

            $file = Open-TagLibFile -Path $script:audioPath
            try {
                $file.Tag.Title | Should -Be 'T2'
                $file.Tag.Pictures.Count | Should -Be 1
                [byte[]]$actualBytes = $file.Tag.Pictures[0].Data.Data
                [System.Convert]::ToBase64String($actualBytes) | Should -Be ([System.Convert]::ToBase64String($expectedBytes))
            }
            finally {
                $file.Dispose()
            }
        }
    }
}

Describe 'Get-TaggerAudioTags on a real file (real TagLibSharp)' -Tag 'Integration' {
    BeforeEach {
        $script:workDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:workDir -Force | Out-Null
    }

    It 'reads back artist/album/title, format, lossless flag and duration for a flac file' {
        $path = Join-Path $script:workDir 'track.flac'
        New-TestAudioFile -Path $path -Format flac
        $tags = [pscustomobject]@{ artist = 'Artist'; albumArtist = 'Artist'; album = 'Album'; year = 2010; discNumber = 1; track = 1; title = 'Title' }
        Set-TaggerAudioTags -Path $path -Tags $tags -TagLibSharpPath $script:TagLibSharpPath

        $result = Get-TaggerAudioTags -Path $path -TagLibSharpPath $script:TagLibSharpPath

        $result.Artist | Should -Be 'Artist'
        $result.Album | Should -Be 'Album'
        $result.Title | Should -Be 'Title'
        $result.Format | Should -Be 'flac'
        $result.IsLossless | Should -Be $true
        $result.DurationSeconds | Should -BeGreaterThan 0.9
        $result.DurationSeconds | Should -BeLessThan 1.2
    }

    It 'reads back format and lossless flag for an mp3 file' {
        $path = Join-Path $script:workDir 'track.mp3'
        New-TestAudioFile -Path $path -Format mp3
        $tags = [pscustomobject]@{ artist = 'Artist'; albumArtist = 'Artist'; album = 'Album'; year = 2010; discNumber = 1; track = 1; title = 'Title' }
        Set-TaggerAudioTags -Path $path -Tags $tags -TagLibSharpPath $script:TagLibSharpPath

        $result = Get-TaggerAudioTags -Path $path -TagLibSharpPath $script:TagLibSharpPath

        $result.Format | Should -Be 'mp3'
        $result.IsLossless | Should -Be $false
        $result.DurationSeconds | Should -BeGreaterThan 0.9
        $result.DurationSeconds | Should -BeLessThan 1.2
    }
}

# End-to-end with real ffmpeg and real TagLibSharp, closing the same "only Recognition was ever
# exercised against real media" gap Tagger.Pipeline.Tests.ps1 closed for the rest of the pipeline
# with mocked media. Discogs is still mocked (the plan never intended live network calls in tests),
# but its fixture is edited in memory to include filesystem-invalid characters, so this also covers
# the "invalid characters through the full pipeline" case plan/11 only ever unit-tested directly on
# ConvertTo-SafeFileName.
Describe 'Full pipeline with real TagLibSharp and ffmpeg' -Tag 'Integration' {
    BeforeAll {
        $script:searchFixture = Get-Content "$PSScriptRoot/fixtures/discogs-responses/search-response.json" -Raw | ConvertFrom-Json
        $script:releaseFixture = Get-Content "$PSScriptRoot/fixtures/discogs-responses/release-response.json" -Raw | ConvertFrom-Json
        $script:releaseFixture.title = 'OK Computer? / Live: Edition'
        $script:releaseFixture.tracklist[1].title = 'Paranoid Android?'

        Mock -ModuleName Tagger.EditProposal Invoke-DiscogsRequest {
            param($Path)
            if ($Path -eq '/database/search') { return $script:searchFixture }
            return $script:releaseFixture
        }

        Mock -ModuleName Tagger.Implementation Invoke-TaggerCoverDownload {
            param($OutputPath)
            # $OutputPath is 'cover-source.download' (the real Invoke-TaggerCoverDownload just saves
            # raw bytes via Invoke-WebRequest, extension-agnostic) - ffmpeg itself needs a recognized
            # extension to pick a muxer, so generate to a real .jpg first and copy the bytes over.
            $tempJpg = "$OutputPath.jpg"
            New-TestCoverImage -Path $tempJpg -Color 'green'
            Copy-Item -LiteralPath $tempJpg -Destination $OutputPath -Force
            Remove-Item -LiteralPath $tempJpg -Force
        }
    }

    BeforeEach {
        $script:dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:targetRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:sourceRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $releaseSourcePath = Join-Path $script:sourceRoot 'Radiohead' '1997 OK Computer'
        New-Item -ItemType Directory -Path $releaseSourcePath -Force | Out-Null
        New-TestAudioFile -Path (Join-Path $releaseSourcePath '01 - Airbag.flac') -Format flac
        New-TestAudioFile -Path (Join-Path $releaseSourcePath '02 - Paranoid Android.flac') -Format flac
        New-TestAudioFile -Path (Join-Path $releaseSourcePath '03 - Subterranean Homesick Alien.flac') -Format flac

        $session = New-TaggerSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
        $script:sessionId = $session.sessionId

        Invoke-TaggerRecognition -SourceRoot $script:sourceRoot -SessionId $script:sessionId -DataHome $script:dataHome -TagLibSharpPath $script:TagLibSharpPath | Out-Null
        $recognitionPath = Join-Path $script:dataHome 'sessions' $script:sessionId 'recognition.json'

        $script:proposalResult = Invoke-TaggerEditProposal -SessionId $script:sessionId -RecognitionPath $recognitionPath `
            -TargetRoot $script:targetRoot -DataHome $script:dataHome
        $script:proposalPath = Join-Path $script:dataHome 'sessions' $script:sessionId 'proposal.json'
    }

    It 'applies the release, writes correct real tags and cover, and sanitizes invalid characters' {
        $result = Invoke-TaggerImplementation -SessionId $script:sessionId -ProposalPath $script:proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath $script:FfmpegPath -TagLibSharpPath $script:TagLibSharpPath -DataHome $script:dataHome -IncludeUnresolved

        $result.Failed | Should -Be 0
        $result.Applied | Should -Be 1

        $release = $script:proposalResult.artists[0].releases[0]
        $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()

        # The release/track *names* (not the full path, which legitimately contains a drive-letter
        # colon and backslash separators) must be sanitized, matching what ConvertTo-SafeFileName
        # would produce.
        $release.proposed.releaseFolderName.IndexOfAny($invalidChars) | Should -Be -1
        $release.proposed.album | Should -Be (Get-TestSafeFileName -Name 'OK Computer? / Live: Edition').SafeName

        $releasePath = Join-Path $script:targetRoot $release.proposed.artistFolderName $release.proposed.releaseFolderName
        Test-Path -LiteralPath $releasePath | Should -Be $true

        foreach ($track in $release.tracks) {
            $track.proposedFileName.IndexOfAny($invalidChars) | Should -Be -1
            $trackPath = Join-Path $releasePath $track.proposedFileName
            Test-Path -LiteralPath $trackPath | Should -Be $true

            $file = Open-TagLibFile -Path $trackPath
            try {
                $file.Tag.FirstPerformer | Should -Be $track.tags.artist
                $file.Tag.FirstAlbumArtist | Should -Be $track.tags.albumArtist
                $file.Tag.Album | Should -Be $track.tags.album
                $file.Tag.Year | Should -Be $track.tags.year
                $file.Tag.Disc | Should -Be $track.tags.discNumber
                $file.Tag.Track | Should -Be $track.tags.track
                $file.Tag.Title | Should -Be $track.tags.title
                $file.Tag.Pictures.Count | Should -Be 1
                $file.Tag.Pictures[0].Type | Should -Be ([TagLib.PictureType]::FrontCover)
            }
            finally {
                $file.Dispose()
            }
        }

        # The proposed tag/name values are themselves already sanitized (New-TaggerProposedReleaseNames
        # and New-TaggerProposedTrackSet in Tagger.EditProposal.psm1 run every Discogs-sourced string
        # through ConvertTo-SafeFileName before it ever reaches proposal.json) - tags and file/folder
        # names share one safe value, there is no separate "raw tag vs sanitized name" pair to compare.
        $release.proposed.album | Should -Not -Match '[?/:]'
    }
}
