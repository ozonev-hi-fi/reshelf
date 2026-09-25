#Requires -Version 7.4

Import-Module Pester -MinimumVersion 5.0

BeforeAll {
    Import-Module "$PSScriptRoot/../scripts/common/Tagger.Common.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Tagger.Json.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Tagger.Settings.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Tagger.Recognition.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Tagger.Discogs.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Tagger.EditProposal.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Tagger.Implementation.psm1" -Force

    $script:FixturesDir = (Resolve-Path "$PSScriptRoot/fixtures/sample-source-tree").Path
}

# End-to-end: chains the real Recognition/EditProposal/Implementation modules over the full
# sample-source-tree fixture, closing the plan/11 gap that only Recognition was ever exercised
# against the whole tree in one run. Discogs is mocked to always return zero search results (every
# release resolves to discogsMatch.status = 'not-found'), which keeps proposed names deterministic
# (falls back to the recognized names - see New-TaggerProposedReleaseNames in Tagger.EditProposal.psm1)
# instead of collapsing every distinct release onto one mocked Discogs release. ffmpeg/TagLibSharp
# calls are mocked the same way Tagger.Implementation.Tests.ps1 already does, since the fixture
# audio files are 0-byte dummies never meant to be opened by a real tag/audio library.
Describe 'Full pipeline: Recognition -> EditProposal -> Implementation' {
    BeforeAll {
        Mock -ModuleName Tagger.Recognition Get-TaggerAudioTags {
            param($Path, $TagLibSharpPath, $DataHome)
            $ext = [System.IO.Path]::GetExtension($Path).TrimStart('.').ToLowerInvariant()
            return @{
                Artist          = $null
                Album           = $null
                Title           = [System.IO.Path]::GetFileNameWithoutExtension($Path)
                Format          = $ext
                IsLossless      = ($ext -in @('flac', 'wav'))
                DurationSeconds = 200
            }
        }

        Mock -ModuleName Tagger.EditProposal Invoke-DiscogsRequest {
            [pscustomobject]@{ results = @() }
        }

        Mock -ModuleName Tagger.Implementation Invoke-TaggerFfmpegSplit {
            Set-Content -LiteralPath $OutputPath -Value 'split' -NoNewline
        }
        Mock -ModuleName Tagger.Implementation Invoke-TaggerFfmpegResize {
            Set-Content -LiteralPath $OutputPath -Value 'resized' -NoNewline
        }
        Mock -ModuleName Tagger.Implementation Invoke-TaggerCoverDownload {
            Set-Content -LiteralPath $OutputPath -Value 'downloaded' -NoNewline
        }
        Mock -ModuleName Tagger.Implementation Set-TaggerAudioTags { }

        function Get-PipelineRelease {
            param(
                [Parameter(Mandatory)] [string]$ArtistName,
                [Parameter(Mandatory)] [string]$RecognizedTitle
            )
            $artist = $script:proposalResult.artists | Where-Object { $_.recognizedName -eq $ArtistName }
            return $artist.releases | Where-Object { $_.recognizedTitle -eq $RecognizedTitle }
        }
    }

    BeforeEach {
        # Implementation mutates its source (cue-split releases always lose their original cue+audio
        # file, regardless of copy/move mode) - it must never run directly against the checked-in
        # fixture tree, only a disposable per-test copy of it.
        $script:dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:targetRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:sourceRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:sourceRoot -Force | Out-Null
        Copy-Item -Path (Join-Path $FixturesDir '*') -Destination $script:sourceRoot -Recurse -Force

        $script:session = New-TaggerSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
        $script:sessionId = $script:session.sessionId

        Invoke-TaggerRecognition -SourceRoot $script:sourceRoot -SessionId $script:sessionId -DataHome $script:dataHome | Out-Null
        $script:recognitionPath = Join-Path $script:dataHome 'sessions' $script:sessionId 'recognition.json'

        $script:proposalResult = Invoke-TaggerEditProposal -SessionId $script:sessionId -RecognitionPath $script:recognitionPath `
            -TargetRoot $script:targetRoot -DataHome $script:dataHome
        $script:proposalPath = Join-Path $script:dataHome 'sessions' $script:sessionId 'proposal.json'
    }

    It 'produces schema-valid recognition.json and proposal.json for the whole fixture tree' {
        Test-Json -LiteralPath $script:recognitionPath -SchemaFile "$PSScriptRoot/../schemas/recognition.schema.json" | Should -Be $true
        Test-Json -LiteralPath $script:proposalPath -SchemaFile "$PSScriptRoot/../schemas/proposal.schema.json" | Should -Be $true
    }

    It 'never proposes a target for a grouping folder or an empty artist folder left in unrecognized[]' {
        ($script:proposalResult.artists.recognizedName) | Should -Not -Contain 'Godspeed You! Black Emperor'
        ($script:proposalResult.artists.recognizedName) | Should -Not -Contain 'Silver Mountain Zion'
        ($script:proposalResult.artists.recognizedName) | Should -Not -Contain 'Empty Artist'
    }

    It 'flags every release for human review since Discogs never matches, and apply skips all of them by default' {
        $releases = @($script:proposalResult.artists.releases)
        ($releases.humanReview.required) | Should -Not -Contain $false

        $result = Invoke-TaggerImplementation -SessionId $script:sessionId -ProposalPath $script:proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome

        $result.Applied | Should -Be 0
        $result.Skipped | Should -Be $releases.Count
        Test-Path -LiteralPath $script:targetRoot | Should -Be $false
    }

    It '-WhatIf with -IncludeUnresolved makes zero filesystem writes' {
        $result = Invoke-TaggerImplementation -SessionId $script:sessionId -ProposalPath $script:proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome -IncludeUnresolved -WhatIf

        $result.Applied | Should -BeGreaterThan 0
        Test-Path -LiteralPath $script:targetRoot | Should -Be $false
        Test-Path -LiteralPath (Join-Path $script:dataHome 'apply-log.json') | Should -Be $false
    }

    It 'a real -IncludeUnresolved run produces the correct target layout for every planted pattern, and a re-run is a no-op' {
        $result = Invoke-TaggerImplementation -SessionId $script:sessionId -ProposalPath $script:proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome -IncludeUnresolved

        $result.Failed | Should -Be 0
        $result.Applied | Should -BeGreaterThan 0

        # Normal single-disc release. Its loose "cover.jpg" companion is also the release's only
        # cover-art candidate, so it gets consumed as the embed-into-tags source and cleaned up as a
        # working file afterwards (Invoke-TaggerReleaseStaging's "Remove cover-art working files"
        # step, Tagger.Implementation.psm1:607-614) rather than surviving as a standalone file -
        # matches the same working-file-cleanup contract already covered for a differently-named
        # cover in Tagger.Implementation.Tests.ps1.
        $xxx = Get-PipelineRelease -ArtistName 'ZZ Top' -RecognizedTitle 'XXX'
        $xxxPath = Join-Path $script:targetRoot $xxx.proposed.artistFolderName $xxx.proposed.releaseFolderName
        Test-Path -LiteralPath $xxxPath | Should -Be $true
        (Get-ChildItem -LiteralPath $xxxPath -Filter '*.flac').Count | Should -Be 2
        Test-Path -LiteralPath (Join-Path $xxxPath 'cover.jpg') | Should -Be $false
        Test-Path -LiteralPath (Join-Path $xxxPath 'cover-source.download') | Should -Be $false

        # Multi-disc release: continuous cross-disc file numbering, no CD1/CD2 subfolders in the
        # target, nested companion file preserved.
        $mescalero = Get-PipelineRelease -ArtistName 'ZZ Top' -RecognizedTitle 'Mescalero'
        $mescaleroPath = Join-Path $script:targetRoot $mescalero.proposed.artistFolderName $mescalero.proposed.releaseFolderName
        Test-Path -LiteralPath $mescaleroPath | Should -Be $true
        (Get-ChildItem -LiteralPath $mescaleroPath -Directory -Filter 'CD *').Count | Should -Be 0
        (Get-ChildItem -LiteralPath $mescaleroPath -Recurse -Filter 'back.jpg').Count | Should -Be 1

        # Category subfolder (EPs) release still lands directly under the artist, not under "EPs".
        $ep = Get-PipelineRelease -ArtistName 'ZZ Top' -RecognizedTitle 'One Foot In The Blues'
        $epPath = Join-Path $script:targetRoot $ep.proposed.artistFolderName $ep.proposed.releaseFolderName
        Test-Path -LiteralPath $epPath | Should -Be $true

        # Band-member-as-artist folder gets its own top-level artist bucket, separate from the band.
        $davidByrne = $script:proposalResult.artists | Where-Object { $_.recognizedName -eq 'David Byrne' }
        $davidByrne | Should -Not -BeNullOrEmpty
        $dbRelease = $davidByrne.releases[0]
        $dbPath = Join-Path $script:targetRoot $dbRelease.proposed.artistFolderName $dbRelease.proposed.releaseFolderName
        Test-Path -LiteralPath $dbPath | Should -Be $true

        # Cue + single-file release: split into per-track files, cue/source deleted from the (copied)
        # source root only - never the checked-in fixture.
        $pinkFloyd = $script:proposalResult.artists | Where-Object { $_.recognizedName -eq 'Pink Floyd' }
        $liveInConcert = $pinkFloyd.releases[0]
        $licPath = Join-Path $script:targetRoot $liveInConcert.proposed.artistFolderName $liveInConcert.proposed.releaseFolderName
        (Get-ChildItem -LiteralPath $licPath -Filter '*.flac').Count | Should -Be 2
        Test-Path -LiteralPath (Join-Path $script:sourceRoot 'Pink Floyd' '1994 Live In Concert (Bootleg)' 'Live In Concert.cue') | Should -Be $false
        Test-Path -LiteralPath (Join-Path $FixturesDir 'Pink Floyd' '1994 Live In Concert (Bootleg)' 'Live In Concert.cue') | Should -Be $true

        # Re-running the whole chain unchanged resolves every applied release to a no-op.
        $rerun = Invoke-TaggerImplementation -SessionId $script:sessionId -ProposalPath $script:proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome -IncludeUnresolved

        $rerun.Applied | Should -Be 0
        $rerun.Skipped | Should -Be $result.Applied
        $rerun.Failed | Should -Be 0
    }
}
