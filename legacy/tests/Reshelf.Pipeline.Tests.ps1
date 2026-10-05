#Requires -Version 7.4

Import-Module Pester -MinimumVersion 5.0

BeforeAll {
    Import-Module "$PSScriptRoot/../scripts/common/Reshelf.Common.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Reshelf.Json.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Reshelf.Settings.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Reshelf.Recognition.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Reshelf.Discogs.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Reshelf.EditProposal.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Reshelf.Implementation.psm1" -Force
    Import-Module "$PSScriptRoot/TestHelpers.psm1" -Force

    $script:FixturesDir = (Resolve-Path "$PSScriptRoot/fixtures/sample-source-tree").Path
    $script:ExpectedDir = Join-Path $PSScriptRoot 'fixtures' 'expected'

    # Makes a generated JSON document comparable across runs: every run-specific value (the three
    # per-test $TestDrive roots, the date-based session id, the generation timestamp) is replaced by
    # a fixed placeholder. Done on the raw text, not via ConvertFrom-Json, so the golden file keeps
    # the product's exact serialization and no date-looking string gets silently re-formatted.
    function ConvertTo-NormalizedPipelineJson {
        param(
            [Parameter(Mandatory)] [string]$Path,
            [Parameter(Mandatory)] [string]$SourceRoot,
            [Parameter(Mandatory)] [string]$TargetRoot,
            [Parameter(Mandatory)] [string]$DataHome,
            [Parameter(Mandatory)] [string]$SessionId
        )
        $text = (Get-Content -LiteralPath $Path -Raw) -replace "`r`n", "`n"
        $roots = [ordered]@{ '<SOURCE_ROOT>' = $SourceRoot; '<TARGET_ROOT>' = $TargetRoot; '<DATA_HOME>' = $DataHome }
        foreach ($placeholder in $roots.Keys) {
            # JSON escapes each '\' as '\\'.
            $text = $text.Replace($roots[$placeholder].Replace('\', '\\'), $placeholder)
        }
        $text = $text.Replace($SessionId, '<SESSION_ID>')
        $text = $text -replace '("generatedAtUtc"\s*:\s*)"[^"]*"', '$1"<GENERATED_AT>"'
        return $text.TrimEnd("`n")
    }

    # Sorted relative paths of every folder (trailing '/') and file under $Root, '/'-separated.
    function Get-TargetLayout {
        param([Parameter(Mandatory)] [string]$Root)
        $lines = Get-ChildItem -LiteralPath $Root -Recurse -Force | ForEach-Object {
            $relative = $_.FullName.Substring($Root.Length).TrimStart('\').Replace('\', '/')
            if ($_.PSIsContainer) { "$relative/" } else { $relative }
        }
        return (@($lines | Sort-Object -Culture 'en-US') -join "`n")
    }

    # Golden-file compare. $env:RESHELF_UPDATE_GOLDEN = '1' rewrites the file instead (then review
    # the change with 'git diff' before committing it - a regenerated golden file is only as correct
    # as the review it got).
    function Assert-Golden {
        param(
            [Parameter(Mandatory)] [string]$Name,
            [Parameter(Mandatory)] [AllowEmptyString()] [string]$Actual
        )
        $goldenPath = Join-Path $script:ExpectedDir $Name
        if ($env:RESHELF_UPDATE_GOLDEN -eq '1') {
            New-Item -ItemType Directory -Path $script:ExpectedDir -Force | Out-Null
            [System.IO.File]::WriteAllText($goldenPath, "$Actual`n", [System.Text.UTF8Encoding]::new($false))
            return
        }
        if (-not (Test-Path -LiteralPath $goldenPath)) {
            throw "Golden file '$goldenPath' is missing. Run the tests once with `$env:RESHELF_UPDATE_GOLDEN = '1' to create it, then review it."
        }
        $expected = ((Get-Content -LiteralPath $goldenPath -Raw) -replace "`r`n", "`n").TrimEnd("`n")
        $Actual | Should -BeExactly $expected -Because "output must match golden file '$Name' (set RESHELF_UPDATE_GOLDEN=1 to regenerate, then review with git diff)"
    }
}

# End-to-end: chains the real Recognition/EditProposal/Implementation modules over the full
# sample-source-tree fixture, closing the plan/11 gap that only Recognition was ever exercised
# against the whole tree in one run. Discogs is mocked to always return zero search results (every
# release resolves to discogsMatch.status = 'not-found'), which keeps proposed names deterministic
# (falls back to the recognized names - see New-ReshelfProposedReleaseNames in Reshelf.EditProposal.psm1)
# instead of collapsing every distinct release onto one mocked Discogs release. ffmpeg/TagLibSharp
# calls are mocked the same way Reshelf.Implementation.Tests.ps1 already does, since the fixture
# audio files are 0-byte dummies never meant to be opened by a real tag/audio library.
Describe 'Full pipeline: Recognition -> EditProposal -> Implementation' {
    BeforeAll {
        # Title is $null, like a real untagged file: the fixture files are 0-byte dummies with no
        # tags, and a non-null Title here would stop EditProposal from ever using its real
        # filename-parsing fallback (it would propose "01 01 - Track One.flac" from a fake title).
        Mock -ModuleName Reshelf.Recognition Get-ReshelfAudioTags {
            param($Path, $TagLibSharpPath, $DataHome)
            $ext = [System.IO.Path]::GetExtension($Path).TrimStart('.').ToLowerInvariant()
            return @{
                Artist            = $null
                Album             = $null
                Title             = $null
                Format            = $ext
                IsLossless        = ($ext -in @('flac', 'wav'))
                DurationSeconds   = 200
                EmbeddedCoverPath = $null
            }
        }

        Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
            [pscustomobject]@{ results = @() }
        }

        Mock -ModuleName Reshelf.Implementation Invoke-ReshelfFfmpegSplit {
            Set-Content -LiteralPath $OutputPath -Value 'split' -NoNewline
        }
        Mock -ModuleName Reshelf.Implementation Invoke-ReshelfFfmpegResize {
            Set-Content -LiteralPath $OutputPath -Value 'resized' -NoNewline
        }
        Mock -ModuleName Reshelf.Implementation Invoke-ReshelfCoverDownload {
            Set-Content -LiteralPath $OutputPath -Value 'downloaded' -NoNewline
        }
        Mock -ModuleName Reshelf.Implementation Set-ReshelfAudioTags { }

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

        $script:session = New-ReshelfSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
        $script:sessionId = $script:session.sessionId

        Invoke-ReshelfRecognition -SourceRoot $script:sourceRoot -SessionId $script:sessionId -DataHome $script:dataHome | Out-Null
        $script:recognitionPath = Join-Path $script:dataHome 'sessions' $script:sessionId 'recognition.json'

        $script:proposalResult = Invoke-ReshelfEditProposal -SessionId $script:sessionId -RecognitionPath $script:recognitionPath `
            -TargetRoot $script:targetRoot -DataHome $script:dataHome
        $script:proposalPath = Join-Path $script:dataHome 'sessions' $script:sessionId 'proposal.json'
    }

    It 'produces schema-valid recognition.json and proposal.json for the whole fixture tree' {
        Test-Json -LiteralPath $script:recognitionPath -SchemaFile "$PSScriptRoot/../schemas/recognition.schema.json" | Should -Be $true
        Test-Json -LiteralPath $script:proposalPath -SchemaFile "$PSScriptRoot/../schemas/proposal.schema.json" | Should -Be $true
    }

    It 'walks a grouping folder into reviewed artists, but never proposes a target for an empty artist folder left in unrecognized[]' {
        $gybe = $script:proposalResult.artists | Where-Object { $_.recognizedName -eq 'Godspeed You! Black Emperor' }
        $gybe | Should -Not -BeNullOrEmpty
        ($gybe.releases.humanReview.required) | Should -Not -Contain $false
        ($script:proposalResult.artists.recognizedName) | Should -Not -Contain 'Empty Artist'
    }

    It 'flags every release for human review since Discogs never matches, and apply skips all of them by default' {
        $releases = @($script:proposalResult.artists.releases)
        ($releases.humanReview.required) | Should -Not -Contain $false

        $result = Invoke-ReshelfImplementation -SessionId $script:sessionId -ProposalPath $script:proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome

        $result.Applied | Should -Be 0
        $result.Skipped | Should -Be $releases.Count
        Test-Path -LiteralPath $script:targetRoot | Should -Be $false
    }

    It '-WhatIf with -IncludeUnresolved makes zero filesystem writes' {
        $roots = @($script:sourceRoot, $script:dataHome, $script:targetRoot)
        $before = Get-TreeSnapshot -Path $roots

        $result = Invoke-ReshelfImplementation -SessionId $script:sessionId -ProposalPath $script:proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome -IncludeUnresolved -WhatIf

        Get-TreeSnapshot -Path $roots | Should -Be $before
        $result.Applied | Should -BeGreaterThan 0
        Test-Path -LiteralPath $script:targetRoot | Should -Be $false
        Test-Path -LiteralPath (Join-Path $script:dataHome 'apply-log.json') | Should -Be $false
    }

    It 'a real -IncludeUnresolved run produces the correct target layout for every planted pattern, and a re-run is a no-op' {
        $result = Invoke-ReshelfImplementation -SessionId $script:sessionId -ProposalPath $script:proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome -IncludeUnresolved

        $result.Failed | Should -Be 0
        $result.Applied | Should -BeGreaterThan 0

        # Normal single-disc release. Its loose "cover.jpg" companion is also the release's only
        # cover-art candidate: it is both embedded into each track's tags (Invoke-ReshelfFfmpegResize
        # reads it directly, since a local sourcePath - unlike a Discogs URL - needs no separate
        # download step first) and copied to the target as the ordinary loose companion it also is
        # (manifesto section 4.5) - only the tool's own resize working file
        # (".reshelf-cover-resized.jpg") gets cleaned up, matching the same working-file-cleanup
        # contract covered in Reshelf.Implementation.Tests.ps1.
        $xxx = Get-PipelineRelease -ArtistName 'ZZ Top' -RecognizedTitle 'XXX'
        $xxxPath = Join-Path $script:targetRoot $xxx.proposed.artistFolderName $xxx.proposed.releaseFolderName
        Test-Path -LiteralPath $xxxPath | Should -Be $true
        (Get-ChildItem -LiteralPath $xxxPath -Filter '*.flac').Count | Should -Be 2
        Test-Path -LiteralPath (Join-Path $xxxPath 'cover.jpg') | Should -Be $true
        Test-Path -LiteralPath (Join-Path $xxxPath '.reshelf-cover-resized.jpg') | Should -Be $false
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

        # Cue + single-file release: split into per-track files; the cue/source is read-only to
        # Reshelf and must survive in the (copied) source root, same as the checked-in fixture.
        $pinkFloyd = $script:proposalResult.artists | Where-Object { $_.recognizedName -eq 'Pink Floyd' }
        $liveInConcert = $pinkFloyd.releases[0]
        $licPath = Join-Path $script:targetRoot $liveInConcert.proposed.artistFolderName $liveInConcert.proposed.releaseFolderName
        (Get-ChildItem -LiteralPath $licPath -Filter '*.flac').Count | Should -Be 2
        Test-Path -LiteralPath (Join-Path $script:sourceRoot 'Pink Floyd' '1994 Live In Concert (Bootleg)' 'Live In Concert.cue') | Should -Be $true
        Test-Path -LiteralPath (Join-Path $FixturesDir 'Pink Floyd' '1994 Live In Concert (Bootleg)' 'Live In Concert.cue') | Should -Be $true

        # Re-running the whole chain unchanged resolves every applied release to a no-op.
        $rerun = Invoke-ReshelfImplementation -SessionId $script:sessionId -ProposalPath $script:proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome -IncludeUnresolved

        $rerun.Applied | Should -Be 0
        $rerun.Skipped | Should -Be $result.Applied
        $rerun.Failed | Should -Be 0
    }

    It 're-running propose after a real apply resolves every applied release to skip-existing-identical, not conflict' {
        # Regression test for a bug where Get-ReshelfFileSetHash (name|size) never matches again
        # after Implementation has renamed every file and rewritten its tags - Resolve-ReshelfTargetComparison
        # (Reshelf.EditProposal.psm1) must instead trust a valid apply-log.json entry, exactly like
        # Test-ReshelfReleaseNeedsApply (Reshelf.Implementation.psm1) already does for apply itself.
        $applyResult = Invoke-ReshelfImplementation -SessionId $script:sessionId -ProposalPath $script:proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome -IncludeUnresolved
        $applyResult.Failed | Should -Be 0
        $applyResult.Applied | Should -BeGreaterThan 0

        # A real second session (not just a synthetic session id), matching what a real re-run of
        # 'Reshelf.ps1 recognize' would produce - Invoke-ReshelfImplementation's own Set-ReshelfSessionStage
        # call needs a real session.json to update. Recognition itself isn't re-run: the source is
        # unchanged, and this test is specifically about propose's target comparison, not recognition.
        $rerunSession = New-ReshelfSession -SourceRoot $script:sourceRoot -DataHome $script:dataHome
        $rerunSessionId = $rerunSession.sessionId
        $rerunProposal = Invoke-ReshelfEditProposal -SessionId $rerunSessionId -RecognitionPath $script:recognitionPath `
            -TargetRoot $script:targetRoot -DataHome $script:dataHome
        $rerunReleases = @($rerunProposal.artists.releases)

        $appliedStableKeys = @(Get-ReshelfApplyLog -DataHome $script:dataHome | Where-Object { $_.status -eq 'applied' } | Select-Object -ExpandProperty stableKey)
        $appliedStableKeys.Count | Should -Be $applyResult.Applied

        foreach ($stableKey in $appliedStableKeys) {
            $release = $rerunReleases | Where-Object { $_.stableKey -eq $stableKey }
            $release.targetAction | Should -Be 'skip-existing-identical' -Because "release '$stableKey' was already applied unchanged and must not be re-proposed as a conflict"
        }

        $rerunApply = Invoke-ReshelfImplementation -SessionId $rerunSessionId -ProposalPath (Join-Path $script:dataHome 'sessions' $rerunSessionId 'proposal.json') `
            -TargetRoot $script:targetRoot -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome -IncludeUnresolved
        $rerunApply.Applied | Should -Be 0
        $rerunApply.Failed | Should -Be 0
    }

    # plan/11 Definition of Done: the exact expected recognition.json / proposal.json / target
    # layout for every planted pattern, checked against reviewed golden files in fixtures/expected/.
    # The per-pattern Its above stay as readable intent; these make the whole output exact.
    It 'recognition.json matches the golden file' {
        $actual = ConvertTo-NormalizedPipelineJson -Path $script:recognitionPath -SourceRoot $script:sourceRoot `
            -TargetRoot $script:targetRoot -DataHome $script:dataHome -SessionId $script:sessionId
        Assert-Golden -Name 'recognition.json' -Actual $actual
    }

    It 'proposal.json matches the golden file' {
        $actual = ConvertTo-NormalizedPipelineJson -Path $script:proposalPath -SourceRoot $script:sourceRoot `
            -TargetRoot $script:targetRoot -DataHome $script:dataHome -SessionId $script:sessionId
        Assert-Golden -Name 'proposal.json' -Actual $actual
    }

    It 'target layout after a real -IncludeUnresolved run matches the golden file' {
        $result = Invoke-ReshelfImplementation -SessionId $script:sessionId -ProposalPath $script:proposalPath -TargetRoot $script:targetRoot `
            -CopyMode copy -FfmpegPath 'ffmpeg.exe' -DataHome $script:dataHome -IncludeUnresolved
        $result.Failed | Should -Be 0

        Assert-Golden -Name 'target-layout.txt' -Actual (Get-TargetLayout -Root $script:targetRoot)
    }
}

# Real case (plan/12 milestone 7): the source folder "PULSAR OLYMP - 94Shine" gives a stableKey
# that differs from the key of the Discogs-corrected target folder "Pulsar Olymp\2015 94 Shine", so
# the lossless re-import never found the lossy folder it should replace.
Describe 'Full pipeline: lossy release applied first, then its lossless upgrade' {
    BeforeAll {
        Mock -ModuleName Reshelf.Recognition Get-ReshelfAudioTags {
            param($Path, $TagLibSharpPath, $DataHome)
            $ext = [System.IO.Path]::GetExtension($Path).TrimStart('.').ToLowerInvariant()
            return @{ Artist = $null; Album = $null; Title = $null; Format = $ext; IsLossless = ($ext -eq 'flac')
                DurationSeconds = 200; EmbeddedCoverPath = $null }
        }
        Mock -ModuleName Reshelf.EditProposal Invoke-DiscogsRequest {
            if ($Path -eq '/database/search') {
                return [pscustomobject]@{ results = @([pscustomobject]@{ id = 4242; type = 'release'; title = 'Some Band - Some Album'; year = '2010'; format = @('CD', 'Album') }) }
            }
            return [pscustomobject]@{
                id = 4242; title = 'Some Album'; year = 2010; country = 'DE'
                artists   = @([pscustomobject]@{ name = 'Some Band'; id = 1 })
                formats   = @([pscustomobject]@{ name = 'CD'; qty = '1'; descriptions = @('Album') })
                images    = @()
                tracklist = @([pscustomobject]@{ position = '1'; title = 'Track One'; duration = '' })
            }
        }
        Mock -ModuleName Reshelf.Implementation Invoke-ReshelfFfmpegResize { Set-Content -LiteralPath $OutputPath -Value 'resized' -NoNewline }
        Mock -ModuleName Reshelf.Implementation Invoke-ReshelfCoverDownload { Set-Content -LiteralPath $OutputPath -Value 'downloaded' -NoNewline }
        Mock -ModuleName Reshelf.Implementation Set-ReshelfAudioTags { }

        function Invoke-PipelineRun {
            param([Parameter(Mandatory)] [string]$SourceRoot)
            $session = New-ReshelfSession -SourceRoot $SourceRoot -DataHome $script:dataHome
            Invoke-ReshelfRecognition -SourceRoot $SourceRoot -SessionId $session.sessionId -DataHome $script:dataHome | Out-Null
            $proposal = Invoke-ReshelfEditProposal -SessionId $session.sessionId -TargetRoot $script:targetRoot -DataHome $script:dataHome `
                -RecognitionPath (Join-Path $script:dataHome 'sessions' $session.sessionId 'recognition.json')
            $apply = Invoke-ReshelfImplementation -SessionId $session.sessionId -TargetRoot $script:targetRoot -CopyMode copy -FfmpegPath 'ffmpeg.exe' `
                -DataHome $script:dataHome -IncludeUnresolved -ProposalPath (Join-Path $script:dataHome 'sessions' $session.sessionId 'proposal.json')
            return [pscustomobject]@{ Release = $proposal.artists[0].releases[0]; Apply = $apply }
        }
    }

    BeforeEach {
        $script:dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:targetRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:lossyRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:losslessRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        foreach ($root in @($script:lossyRoot, $script:losslessRoot)) {
            New-Item -ItemType Directory -Path (Join-Path $root 'SOME BAND - SomeAlbum') -Force | Out-Null
        }
        Set-Content -LiteralPath (Join-Path $script:lossyRoot 'SOME BAND - SomeAlbum' '01 - Track One.mp3') -Value 'lossy' -NoNewline
        Set-Content -LiteralPath (Join-Path $script:losslessRoot 'SOME BAND - SomeAlbum' '01 - Track One.flac') -Value 'lossless' -NoNewline
    }

    It 'replaces the lossy target folder with the lossless release and marks the ledger entry upgraded' {
        $lossy = Invoke-PipelineRun -SourceRoot $script:lossyRoot
        $lossy.Release.lossyLossless.action | Should -Be 'log-for-upgrade'
        $lossy.Apply.Applied | Should -Be 1
        $targetPath = Join-Path $script:targetRoot 'Some Band' '2010 Some Album'
        Test-Path -LiteralPath (Join-Path $targetPath '01 Track One.mp3') | Should -Be $true
        $stableKey = $lossy.Release.stableKey
        (InModuleScope Reshelf.EditProposal -Parameters @{ k = $stableKey; d = $script:dataHome } { param($k, $d) Get-ReshelfLossyTrackingEntry -StableKey $k -DataHome $d }).status |
            Should -Be 'pending-upgrade'

        $lossless = Invoke-PipelineRun -SourceRoot $script:losslessRoot

        $lossless.Release.stableKey | Should -Be $stableKey
        $lossless.Release.targetAction | Should -Be 'update-existing'
        $lossless.Release.lossyLossless.action | Should -Be 'replace-existing'
        $lossless.Apply.Applied | Should -Be 1
        $lossless.Apply.Failed | Should -Be 0
        @(Get-ChildItem -LiteralPath $targetPath -File).Name | Should -Be @('01 Track One.flac')
        (InModuleScope Reshelf.EditProposal -Parameters @{ k = $stableKey; d = $script:dataHome } { param($k, $d) Get-ReshelfLossyTrackingEntry -StableKey $k -DataHome $d }).status |
            Should -Be 'upgraded'
    }
}
