#Requires -Version 7.4

Import-Module Pester -MinimumVersion 5.0

BeforeAll {
    Import-Module "$PSScriptRoot/../scripts/common/Reshelf.Common.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Reshelf.Json.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Reshelf.Recognition.psm1" -Force

    $script:FixturesDir = (Resolve-Path "$PSScriptRoot/fixtures/sample-source-tree").Path
    $script:OverridesDir = (Resolve-Path "$PSScriptRoot/fixtures/overrides").Path
}

Describe 'Test-IsReleaseFolder (private)' {
    It 'recognizes a normal release folder with directly-numbered audio files' {
        InModuleScope Reshelf.Recognition -Parameters @{ fixturesDir = $script:FixturesDir } {
            param($fixturesDir)
            Test-IsReleaseFolder -Path (Join-Path $fixturesDir 'ZZ Top\1999 XXX') | Should -Be $true
        }
    }

    It 'recognizes a multi-disc release folder whose children are all disc subfolders' {
        InModuleScope Reshelf.Recognition -Parameters @{ fixturesDir = $script:FixturesDir } {
            param($fixturesDir)
            Test-IsReleaseFolder -Path (Join-Path $fixturesDir 'ZZ Top\2003 Mescalero') | Should -Be $true
        }
    }

    It 'does not recognize an artist folder (release-shaped children, no direct audio) as a release' {
        InModuleScope Reshelf.Recognition -Parameters @{ fixturesDir = $script:FixturesDir } {
            param($fixturesDir)
            Test-IsReleaseFolder -Path (Join-Path $fixturesDir 'ZZ Top') | Should -Be $false
        }
    }

    It 'does not recognize an empty folder (no audio files) as a release' {
        InModuleScope Reshelf.Recognition -Parameters @{ fixturesDir = $script:FixturesDir } {
            param($fixturesDir)
            Test-IsReleaseFolder -Path (Join-Path $fixturesDir 'Empty Artist\2010 Nothing Here') | Should -Be $false
        }
    }
}

Describe 'Test-IsGroupingFolder (private)' {
    It 'recognizes a grouping folder whose children are all distinct artist-like folders' {
        InModuleScope Reshelf.Recognition -Parameters @{ fixturesDir = $script:FixturesDir } {
            param($fixturesDir)
            Test-IsGroupingFolder -Path (Join-Path $fixturesDir 'Godspeeds and their projects') | Should -Be $true
        }
    }

    It 'does not treat a normal artist folder (children are releases) as a grouping folder' {
        InModuleScope Reshelf.Recognition -Parameters @{ fixturesDir = $script:FixturesDir } {
            param($fixturesDir)
            Test-IsGroupingFolder -Path (Join-Path $fixturesDir 'ZZ Top') | Should -Be $false
        }
    }

    It 'does not treat a multi-disc release folder as a grouping folder' {
        InModuleScope Reshelf.Recognition -Parameters @{ fixturesDir = $script:FixturesDir } {
            param($fixturesDir)
            Test-IsGroupingFolder -Path (Join-Path $fixturesDir 'ZZ Top\2003 Mescalero') | Should -Be $false
        }
    }

    It 'requires at least two subfolders' {
        InModuleScope Reshelf.Recognition -Parameters @{ fixturesDir = $script:FixturesDir } {
            param($fixturesDir)
            Test-IsGroupingFolder -Path (Join-Path $fixturesDir 'Empty Artist') | Should -Be $false
        }
    }
}

Describe 'Test-IsCategorySubfolder (private)' {
    It 'recognizes configured category names case-insensitively' {
        InModuleScope Reshelf.Recognition {
            Test-IsCategorySubfolder -Name 'EPs' | Should -Be $true
            Test-IsCategorySubfolder -Name 'eps' | Should -Be $true
            Test-IsCategorySubfolder -Name 'Singles' | Should -Be $true
            Test-IsCategorySubfolder -Name 'Lives' | Should -Be $true
            Test-IsCategorySubfolder -Name 'lives' | Should -Be $true
        }
    }

    It 'rejects a name that is not in the category list' {
        InModuleScope Reshelf.Recognition {
            Test-IsCategorySubfolder -Name '1999 XXX' | Should -Be $false
        }
    }
}

Describe 'Test-IsBandMemberFolder (private)' {
    It 'recognizes a differently-named subfolder containing a release-shaped child' {
        InModuleScope Reshelf.Recognition -Parameters @{ fixturesDir = $script:FixturesDir } {
            param($fixturesDir)
            Test-IsBandMemberFolder -Path (Join-Path $fixturesDir 'Talking Heads\David Byrne') -ParentArtistName 'Talking Heads' | Should -Be $true
        }
    }

    It 'rejects a subfolder whose normalized name matches the parent artist' {
        InModuleScope Reshelf.Recognition -Parameters @{ fixturesDir = $script:FixturesDir } {
            param($fixturesDir)
            Test-IsBandMemberFolder -Path (Join-Path $fixturesDir 'Talking Heads\1980 Remain In Light') -ParentArtistName 'Talking Heads' | Should -Be $false
        }
    }

    It 'rejects a category-named subfolder' {
        InModuleScope Reshelf.Recognition -Parameters @{ fixturesDir = $script:FixturesDir } {
            param($fixturesDir)
            Test-IsBandMemberFolder -Path (Join-Path $fixturesDir 'ZZ Top\EPs') -ParentArtistName 'ZZ Top' | Should -Be $false
        }
    }
}

Describe 'ConvertFrom-ReshelfTrackFileName (private)' {
    It 'parses a dash-separated numbered filename' {
        InModuleScope Reshelf.Recognition {
            $result = ConvertFrom-ReshelfTrackFileName -FileName '01 - Poke Chop Sandwich.flac'
            $result.Number | Should -Be 1
            $result.Title | Should -Be 'Poke Chop Sandwich'
            $result.HasNumber | Should -Be $true
        }
    }

    It 'parses an en-dash-separated numbered filename' {
        InModuleScope Reshelf.Recognition {
            $result = ConvertFrom-ReshelfTrackFileName -FileName ('02 ' + [char]0x2013 + ' Crucifixx A Flatt.flac')
            $result.Number | Should -Be 2
            $result.Title | Should -Be 'Crucifixx A Flatt'
        }
    }

    It 'parses a space-only numbered filename with no separator' {
        InModuleScope Reshelf.Recognition {
            $result = ConvertFrom-ReshelfTrackFileName -FileName '03 Some Track.mp3'
            $result.Number | Should -Be 3
            $result.Title | Should -Be 'Some Track'
            $result.HasNumber | Should -Be $true
        }
    }

    It 'falls back to the whole filename when no number is present' {
        InModuleScope Reshelf.Recognition {
            $result = ConvertFrom-ReshelfTrackFileName -FileName 'Alpha Song.flac'
            $result.Number | Should -Be $null
            $result.Title | Should -Be 'Alpha Song'
            $result.HasNumber | Should -Be $false
        }
    }
}

Describe 'Get-ReshelfTrackOrder (private)' {
    It 'orders fully-numbered files by their parsed number' {
        InModuleScope Reshelf.Recognition {
            $files = @(
                [pscustomobject]@{ Name = '02 - Second.mp3' }
                [pscustomobject]@{ Name = '01 - First.mp3' }
            )
            $ordered = Get-ReshelfTrackOrder -AudioFiles $files
            $ordered[0].Number | Should -Be 1
            $ordered[1].Number | Should -Be 2
            $ordered | ForEach-Object { $_.InferredOrder | Should -Be $false }
        }
    }

    It 'falls back to whole-folder alphabetical order when any file lacks a number' {
        InModuleScope Reshelf.Recognition {
            $files = @(
                [pscustomobject]@{ Name = '01 - First.mp3' }
                [pscustomobject]@{ Name = 'Unnumbered.mp3' }
            )
            $ordered = Get-ReshelfTrackOrder -AudioFiles $files
            ($ordered | ForEach-Object { $_.InferredOrder }) | Should -Not -Contain $false
            $ordered[0].File.Name | Should -Be '01 - First.mp3'
            $ordered[1].File.Name | Should -Be 'Unnumbered.mp3'
        }
    }
}

Describe 'Test-IsDiscFolder / Get-ReshelfDiscFolders (private)' {
    It 'recognizes CD/Disc/Disk variants case-insensitively' {
        InModuleScope Reshelf.Recognition {
            Test-IsDiscFolder -Name 'CD 1' | Should -Be $true
            Test-IsDiscFolder -Name 'cd1' | Should -Be $true
            Test-IsDiscFolder -Name 'Disc 2' | Should -Be $true
            Test-IsDiscFolder -Name 'DISK.3' | Should -Be $true
            Test-IsDiscFolder -Name 'Bonus Disc' | Should -Be $false
        }
    }

    It 'recognizes a disc number followed by trailing text after a separator' {
        InModuleScope Reshelf.Recognition {
            Test-IsDiscFolder -Name 'CD1. Forwards' | Should -Be $true
            Test-IsDiscFolder -Name 'CD2. Sideways' | Should -Be $true
            Test-IsDiscFolder -Name 'Disc 2 - Bonus' | Should -Be $true
        }
    }

    It 'does not match a disc number that runs straight into trailing text with no separator' {
        InModuleScope Reshelf.Recognition {
            Test-IsDiscFolder -Name 'CD10Something' | Should -Be $false
        }
    }

    It 'sorts disc folders numerically, not lexically' {
        InModuleScope Reshelf.Recognition -Parameters @{ fixturesDir = $script:FixturesDir } {
            param($fixturesDir)
            $discs = Get-ReshelfDiscFolders -Path (Join-Path $fixturesDir 'ZZ Top\2003 Mescalero')
            $discs.Count | Should -Be 2
            $discs[0].Name | Should -Be 'CD 1'
            $discs[1].Name | Should -Be 'CD 2'
        }
    }
}

Describe 'Get-ReshelfDiscNumber (private)' {
    It 'parses an exact CD-number/Disc-number name with no trailing text' {
        InModuleScope Reshelf.Recognition {
            Get-ReshelfDiscNumber -Name 'CD1' | Should -Be 1
            Get-ReshelfDiscNumber -Name 'Disc 2' | Should -Be 2
        }
    }

    It 'parses a disc number followed by trailing text after a separator' {
        InModuleScope Reshelf.Recognition {
            Get-ReshelfDiscNumber -Name 'CD1. Forwards' | Should -Be 1
            Get-ReshelfDiscNumber -Name 'CD2. Sideways' | Should -Be 2
        }
    }

    It 'returns $null for a disc number that runs straight into trailing text with no separator' {
        InModuleScope Reshelf.Recognition {
            Get-ReshelfDiscNumber -Name 'CD10Something' | Should -BeNullOrEmpty
        }
    }
}

Describe 'ConvertFrom-ReshelfCueSheet (private)' {
    It 'parses a well-formed cue sheet into ordered virtual tracks' {
        InModuleScope Reshelf.Recognition -Parameters @{ fixturesDir = $script:FixturesDir } {
            param($fixturesDir)
            $cuePath = Join-Path $fixturesDir 'Pink Floyd\1994 Live In Concert (Bootleg)\Live In Concert.cue'
            $tracks = ConvertFrom-ReshelfCueSheet -CueFilePath $cuePath
            $tracks.Count | Should -Be 2
            $tracks[0].Title | Should -Be 'Speak To Me'
            $tracks[0].Timestamp | Should -Be '00:00:00'
            $tracks[1].Title | Should -Be 'Breathe'
            $tracks[1].Timestamp | Should -Be '03:12:45'
        }
    }

    It 'returns $null for a cue file with no TRACK entries' {
        InModuleScope Reshelf.Recognition {
            $path = Join-Path $TestDrive 'malformed.cue'
            Set-Content -LiteralPath $path -Value 'PERFORMER "Nobody"'
            ConvertFrom-ReshelfCueSheet -CueFilePath $path | Should -Be $null
        }
    }

    It 'correctly decodes accented titles from a Windows-1252-encoded cue file (no BOM)' {
        # Real-world case: German cue sheets ripped on Windows are often Windows-1252, not UTF-8.
        # Reading them as UTF-8 (the default) turns bytes like u-umlaut into lossy U+FFFD replacement
        # characters instead of recovering the real title. Built from explicit char codes rather than
        # a literal accented character in this source file, to avoid this very same class of mixup.
        InModuleScope Reshelf.Recognition {
            $uUmlaut = [char]0xFC
            $expectedTitle = "F${uUmlaut}r einen Augenblick"
            $cueText = "TRACK 01 AUDIO`r`n    TITLE `"$expectedTitle`"`r`n    INDEX 01 00:00:00`r`n"

            $path = Join-Path $TestDrive 'german.cue'
            $bytes = [System.Text.Encoding]::GetEncoding(1252).GetBytes($cueText)
            [System.IO.File]::WriteAllBytes($path, $bytes)

            $tracks = ConvertFrom-ReshelfCueSheet -CueFilePath $path
            $tracks.Count | Should -Be 1
            $tracks[0].Title | Should -Be $expectedTitle
        }
    }

    It 'returns $null for a missing cue file' {
        InModuleScope Reshelf.Recognition {
            ConvertFrom-ReshelfCueSheet -CueFilePath (Join-Path $TestDrive 'does-not-exist.cue') | Should -Be $null
        }
    }
}

Describe 'Get-ReshelfCompanionFiles (private)' {
    It 'classifies loose and nested companions, routing playlists to ignored' {
        InModuleScope Reshelf.Recognition -Parameters @{ fixturesDir = $script:FixturesDir } {
            param($fixturesDir)
            $result = Get-ReshelfCompanionFiles -Path (Join-Path $fixturesDir 'ZZ Top\1999 XXX')
            $result.Companions.Count | Should -Be 1
            $result.Companions[0].kind | Should -Be 'cover'
            $result.Companions[0].placement | Should -Be 'loose'
        }
    }

    It 'classifies a nested companion file under a non-disc subfolder' {
        InModuleScope Reshelf.Recognition -Parameters @{ fixturesDir = $script:FixturesDir } {
            param($fixturesDir)
            $result = Get-ReshelfCompanionFiles -Path (Join-Path $fixturesDir 'ZZ Top\2003 Mescalero')
            $result.Companions.Count | Should -Be 1
            $result.Companions[0].placement | Should -Be 'nested'
            $result.Companions[0].kind | Should -Be 'booklet'
        }
    }

    It 'routes a playlist file to ignored with reason playlist-file' {
        InModuleScope Reshelf.Recognition -Parameters @{ fixturesDir = $script:FixturesDir } {
            param($fixturesDir)
            $releaseDir = Join-Path $fixturesDir 'Pink Floyd\1994 Live In Concert (Bootleg)'
            # This fixture is a single-file + .cue release - passing the real cue sheet path (as
            # Invoke-ReshelfRecognition itself does) keeps the used cue file excluded here, so only
            # the playlist shows up as ignored.
            $result = Get-ReshelfCompanionFiles -Path $releaseDir -CueSheetPath (Join-Path $releaseDir 'Live In Concert.cue')
            $result.Ignored.Count | Should -Be 1
            $result.Ignored[0].reason | Should -Be 'playlist-file'
        }
    }

    It 'routes an unused .cue file to ignored with reason cue-sheet-not-used when no CueSheetPath is given' {
        InModuleScope Reshelf.Recognition -Parameters @{ fixturesDir = $script:FixturesDir } {
            param($fixturesDir)
            $releaseDir = Join-Path $fixturesDir 'Pink Floyd\1994 Live In Concert (Bootleg)'
            $result = Get-ReshelfCompanionFiles -Path $releaseDir
            $cueEntry = $result.Ignored | Where-Object { $_.sourcePath -like '*Live In Concert.cue' }
            $cueEntry | Should -Not -BeNullOrEmpty
            $cueEntry.reason | Should -Be 'cue-sheet-not-used'
        }
    }

    It 'excludes audio files under disc subfolders (those are tracks, not companions), but still catches a non-audio file there' {
        InModuleScope Reshelf.Recognition -Parameters @{ fixturesDir = $script:FixturesDir } {
            param($fixturesDir)
            $result = Get-ReshelfCompanionFiles -Path (Join-Path $fixturesDir 'ZZ Top\2003 Mescalero')
            $result.Companions | Where-Object { $_.sourcePath -like '*CD 1*' -or $_.sourcePath -like '*CD 2*' } | Should -BeNullOrEmpty
            $playlistInDisc = $result.Ignored | Where-Object { $_.sourcePath -like '*CD 1*setlist.m3u' }
            $playlistInDisc | Should -Not -BeNullOrEmpty
        }
    }

    It 'classifies a file with no extension at all as a companion of kind other, instead of throwing' {
        # Found against a real collection sample: a 0-byte loose file with no extension
        # (e.g. an aborted download) sitting next to real tracks. Test-ReshelfIsAudioExtension /
        # Resolve-ReshelfCompanionKind used to reject '' outright as a Mandatory string parameter.
        InModuleScope Reshelf.Recognition {
            $releaseDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N')) 'Some Release'
            New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null
            New-Item -ItemType File -Path (Join-Path $releaseDir 'Extensionless') -Force | Out-Null

            { $result = Get-ReshelfCompanionFiles -Path $releaseDir } | Should -Not -Throw

            $result = Get-ReshelfCompanionFiles -Path $releaseDir
            $result.Companions.Count | Should -Be 1
            $result.Companions[0].kind | Should -Be 'other'
            $result.Companions[0].placement | Should -Be 'loose'
        }
    }
}

Describe 'Get-ReshelfOverrides / Resolve-ReshelfFolderOverride (private)' {
    It 'returns an empty entries list when no overrides file exists' {
        InModuleScope Reshelf.Recognition {
            $dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
            $result = Get-ReshelfOverrides -SourceRoot 'D:\does-not-matter' -DataHome $dataHome
            $result.entries.Count | Should -Be 0
        }
    }

    It 'throws a clear error for a malformed overrides file' {
        InModuleScope Reshelf.Recognition {
            $path = Join-Path $TestDrive 'malformed-overrides.json'
            Set-Content -LiteralPath $path -Value '{"entries":"not-an-array"}'
            { Get-ReshelfOverrides -SourceRoot 'D:\x' -OverridesPath $path } | Should -Throw '*does not match*'
        }
    }

    It 'reads each of the 4 override kinds from a real overrides file' {
        InModuleScope Reshelf.Recognition -Parameters @{ overridesDir = $script:OverridesDir } {
            param($overridesDir)
            $overrides = Get-ReshelfOverrides -SourceRoot 'D:\downloads\incoming' -OverridesPath (Join-Path $overridesDir '..\schema-examples\overrides-example.json')
            $overrides.entries.Count | Should -Be 4
            ($overrides.entries.kind | Sort-Object -Unique) | Should -Be @('artist', 'band-member', 'category', 'grouping')
        }
    }

    It 'matches a relative path case-insensitively regardless of slash direction' {
        InModuleScope Reshelf.Recognition {
            $overrides = [pscustomobject]@{
                entries = @([pscustomobject]@{ relativePath = 'Talking Heads/EPs'; kind = 'category' })
            }
            $match = Resolve-ReshelfFolderOverride -Overrides $overrides -RelativePath 'talking heads\EPS'
            $match | Should -Not -BeNullOrEmpty
        }
    }

    It 'returns $null when no entry matches the relative path' {
        InModuleScope Reshelf.Recognition {
            $overrides = [pscustomobject]@{ entries = @() }
            Resolve-ReshelfFolderOverride -Overrides $overrides -RelativePath 'anything' | Should -BeNullOrEmpty
        }
    }
}

Describe 'Invoke-ReshelfRecognition' {
    BeforeAll {
        Mock -ModuleName Reshelf.Recognition Get-ReshelfAudioTags {
            param($Path, $TagLibSharpPath, $DataHome)
            $ext = [System.IO.Path]::GetExtension($Path).TrimStart('.').ToLowerInvariant()
            return @{
                Artist            = $null
                Album             = $null
                Title             = [System.IO.Path]::GetFileNameWithoutExtension($Path)
                Format            = $ext
                IsLossless        = ($ext -in @('flac', 'wav', 'ape'))
                DurationSeconds   = 200
                EmbeddedCoverPath = $null
            }
        }
    }

    BeforeEach {
        $script:dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    }

    It 'produces a recognition.json that validates against the schema' {
        $result = Invoke-ReshelfRecognition -SourceRoot $FixturesDir -SessionId 'session-1' -DataHome $dataHome

        $outputPath = Join-Path $dataHome 'sessions' 'session-1' 'recognition.json'
        $outputPath | Should -Exist
        Test-Json -LiteralPath $outputPath -SchemaFile "$PSScriptRoot/../schemas/recognition.schema.json" | Should -Be $true
        $result.sessionId | Should -Be 'session-1'
    }

    It 'recognizes a normal single-disc release with correct track order' {
        $result = Invoke-ReshelfRecognition -SourceRoot $FixturesDir -SessionId 'session-2' -DataHome $dataHome

        $zzTop = $result.artists | Where-Object { $_.recognizedName -eq 'ZZ Top' }
        $zzTop | Should -Not -BeNullOrEmpty
        $release = $zzTop.releases | Where-Object { $_.recognizedTitle -eq 'XXX' }
        $release.recognizedYear | Should -Be 1999
        $release.tracks.Count | Should -Be 2
        $release.tracks[0].detectedTrackNumberInDisc | Should -Be 1
        $release.companionFiles.Count | Should -Be 1
    }

    It 'recognizes a multi-disc release with correct disc folder names and combined track count' {
        $result = Invoke-ReshelfRecognition -SourceRoot $FixturesDir -SessionId 'session-3' -DataHome $dataHome

        $zzTop = $result.artists | Where-Object { $_.recognizedName -eq 'ZZ Top' }
        $release = $zzTop.releases | Where-Object { $_.recognizedTitle -eq 'Mescalero' }
        $release.discFolderCount | Should -Be 2
        ($release.tracks | Where-Object { $_.discFolder -eq 'CD 1' }).Count | Should -Be 2
        ($release.tracks | Where-Object { $_.discFolder -eq 'CD 2' }).Count | Should -Be 3
        $release.companionFiles[0].placement | Should -Be 'nested'
    }

    It 'records a stray audio file sitting loose in a multi-disc release, flagged for review, instead of dropping it' {
        $result = Invoke-ReshelfRecognition -SourceRoot $FixturesDir -SessionId 'session-3b' -DataHome $dataHome

        $zzTop = $result.artists | Where-Object { $_.recognizedName -eq 'ZZ Top' }
        $release = $zzTop.releases | Where-Object { $_.recognizedTitle -eq 'Mescalero' }
        $strayTrack = $release.tracks | Where-Object { $_.originalFileName -eq 'Stray Bonus Track.mp3' }
        $strayTrack | Should -Not -BeNullOrEmpty
        $strayTrack.discFolder | Should -Be $null
        $release.needsReview | Should -Be $true
        $release.reviewReasons | Should -Contain 'track-outside-disc-folder-suspected'
    }

    It 'routes a playlist file inside a disc subfolder to ignoredFiles instead of dropping it' {
        $result = Invoke-ReshelfRecognition -SourceRoot $FixturesDir -SessionId 'session-3c' -DataHome $dataHome

        $zzTop = $result.artists | Where-Object { $_.recognizedName -eq 'ZZ Top' }
        $release = $zzTop.releases | Where-Object { $_.recognizedTitle -eq 'Mescalero' }
        $ignoredInDisc = $release.ignoredFiles | Where-Object { $_.sourcePath -like '*CD 1*setlist.m3u' }
        $ignoredInDisc | Should -Not -BeNullOrEmpty
        $ignoredInDisc.reason | Should -Be 'playlist-file'
    }

    It 'attributes a category subfolder release to the parent artist' {
        $result = Invoke-ReshelfRecognition -SourceRoot $FixturesDir -SessionId 'session-4' -DataHome $dataHome

        $zzTop = $result.artists | Where-Object { $_.recognizedName -eq 'ZZ Top' }
        $zzTop.releases.Count | Should -Be 5
        ($zzTop.releases.recognizedTitle) | Should -Contain 'One Foot In The Blues'

        # "Lives" is a second category name, planted separately from "EPs".
        $live = $zzTop.releases | Where-Object { $_.recognizedTitle -eq 'Live From Texas' }
        $live | Should -Not -BeNullOrEmpty
        $live.recognizedYear | Should -Be 2005
        ($result.artists.recognizedName) | Should -Not -Contain 'Lives'

        # "Singles" is a third category name, planted separately from "EPs"/"Lives".
        $single = $zzTop.releases | Where-Object { $_.recognizedTitle -eq 'Pincushion' }
        $single | Should -Not -BeNullOrEmpty
        $single.recognizedYear | Should -Be 1996
        ($result.artists.recognizedName) | Should -Not -Contain 'Singles'
    }

    It 'parses a numbered track filename with no dash separator in the fixture tree' {
        $result = Invoke-ReshelfRecognition -SourceRoot $FixturesDir -SessionId 'session-2b' -DataHome $dataHome

        $zzTop = $result.artists | Where-Object { $_.recognizedName -eq 'ZZ Top' }
        $release = $zzTop.releases | Where-Object { $_.recognizedTitle -eq 'XXX' }
        $noDash = $release.tracks | Where-Object { $_.originalFileName -eq '02 Crucifixx A Flatt.flac' }
        $noDash.detectedTrackNumberInDisc | Should -Be 2
        $noDash.inferredTrackOrder | Should -Be $false
    }

    It 'strips the dash from a "yyyy - Release Name" source folder in the fixture tree' {
        $result = Invoke-ReshelfRecognition -SourceRoot $FixturesDir -SessionId 'session-2c' -DataHome $dataHome

        $cranberries = $result.artists | Where-Object { $_.recognizedName -eq 'Cranberries' }
        $cranberries.releases.Count | Should -Be 1
        $cranberries.releases[0].recognizedYear | Should -Be 1993
        $cranberries.releases[0].recognizedTitle | Should -Be 'Everybody Else Is Doing It'
    }

    It 'parses year and title for each supported release folder name form' {
        # Each case is an artist folder with one release folder; en dash written as [char]0x2013 to
        # keep this file ASCII.
        $cases = @(
            @{ Folder = '1999 XXX'; Year = 1999; Title = 'XXX' }
            @{ Folder = '1999 - XXX'; Year = 1999; Title = 'XXX' }
            @{ Folder = "1999 $([char]0x2013) XXX"; Year = 1999; Title = 'XXX' }
            @{ Folder = '1990 Live - The Tour'; Year = 1990; Title = 'Live - The Tour' }
            @{ Folder = '1999-2003 Anthology'; Year = $null; Title = '1999-2003 Anthology' }
        )

        foreach ($case in $cases) {
            $sourceRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
            New-Item -ItemType File -Path (Join-Path $sourceRoot 'Some Artist' $case.Folder '01 - Track.flac') -Force | Out-Null

            $result = Invoke-ReshelfRecognition -SourceRoot $sourceRoot -SessionId 'session-2d' -DataHome $dataHome

            $release = ($result.artists | Where-Object { $_.recognizedName -eq 'Some Artist' }).releases[0]
            $release.recognizedYear | Should -Be $case.Year -Because "folder '$($case.Folder)'"
            $release.recognizedTitle | Should -Be $case.Title -Because "folder '$($case.Folder)'"
        }
    }

    It 'creates a new artist bucket for a band-member folder instead of merging into the parent' {
        $result = Invoke-ReshelfRecognition -SourceRoot $FixturesDir -SessionId 'session-5' -DataHome $dataHome

        $talkingHeads = $result.artists | Where-Object { $_.recognizedName -eq 'Talking Heads' }
        $davidByrne = $result.artists | Where-Object { $_.recognizedName -eq 'David Byrne' }
        $talkingHeads.releases.Count | Should -Be 1
        $davidByrne | Should -Not -BeNullOrEmpty
        $davidByrne.releases.Count | Should -Be 1
    }

    It 'flags a grouping folder as unrecognized by default, without descending into it' {
        $result = Invoke-ReshelfRecognition -SourceRoot $FixturesDir -SessionId 'session-6' -DataHome $dataHome

        $entry = $result.unrecognized | Where-Object { $_.reason -eq 'grouping-folder-suspected' }
        $entry | Should -Not -BeNullOrEmpty
        ($result.artists.recognizedName) | Should -Not -Contain 'Godspeed You! Black Emperor'
    }

    It 'resolves a grouping folder into separate artists when an override is supplied' {
        $overridesPath = Join-Path $OverridesDir 'grouping-override.json'
        $result = Invoke-ReshelfRecognition -SourceRoot $FixturesDir -SessionId 'session-7' -DataHome $dataHome -OverridesPath $overridesPath

        ($result.unrecognized.reason) | Should -Not -Contain 'grouping-folder-suspected'
        ($result.artists.recognizedName) | Should -Contain 'Godspeed You! Black Emperor'
        ($result.artists.recognizedName) | Should -Contain 'Silver Mountain Zion'
    }

    It 'flags a release folder with no artist wrapper, and an artist override resolves it' {
        $result = Invoke-ReshelfRecognition -SourceRoot $FixturesDir -SessionId 'session-8' -DataHome $dataHome
        ($result.unrecognized.reason) | Should -Contain 'release-without-artist-suspected'

        $overridesPath = Join-Path $OverridesDir 'full-override.json'
        $resolved = Invoke-ReshelfRecognition -SourceRoot $FixturesDir -SessionId 'session-9' -DataHome $dataHome -OverridesPath $overridesPath
        $someArtist = $resolved.artists | Where-Object { $_.recognizedName -eq 'Some Artist' }
        $someArtist | Should -Not -BeNullOrEmpty
    }

    It 'splits a flat "Artist - Album" release folder (no artist wrapper) into a review-flagged release' {
        $result = Invoke-ReshelfRecognition -SourceRoot $FixturesDir -SessionId 'session-18' -DataHome $dataHome

        $artist = $result.artists | Where-Object { $_.recognizedName -eq 'PULSAR OLYMP' }
        $artist | Should -Not -BeNullOrEmpty
        $artist.releases.Count | Should -Be 1

        $release = $artist.releases[0]
        $release.recognizedTitle | Should -Be '94Shine'
        $release.tracks.Count | Should -Be 2
        $release.needsReview | Should -Be $true
        $release.reviewReasons | Should -Contain 'artist-name-split-from-folder-name'

        # Not part of PULSAR OLYMP's own on-disk folder name, so it must not be misclassified as
        # its own artist bucket.
        ($result.artists.recognizedName) | Should -Not -Contain 'PULSAR OLYMP - 94Shine'
    }

    It 'still flags a flat release folder with no " - " separator as unrecognized (regression)' {
        $result = Invoke-ReshelfRecognition -SourceRoot $FixturesDir -SessionId 'session-19' -DataHome $dataHome

        $entry = $result.unrecognized | Where-Object { $_.path -like '*1999 Loose Album' }
        $entry | Should -Not -BeNullOrEmpty
        $entry.reason | Should -Be 'release-without-artist-suspected'
        ($result.artists.recognizedName) | Should -Not -Contain '1999 Loose Album'
    }

    It 'does not misparse a leading 4-digit non-year number (e.g. a catalog number) as recognizedYear' {
        $result = Invoke-ReshelfRecognition -SourceRoot $FixturesDir -SessionId 'session-21' -DataHome $dataHome

        $artist = $result.artists | Where-Object { $_.recognizedName -eq 'Isidor' }
        $artist | Should -Not -BeNullOrEmpty
        $release = $artist.releases[0]
        $release.recognizedYear | Should -BeNullOrEmpty
        $release.recognizedTitle | Should -Be '3218 (Soldier of Fortune Edition - Artwork)'
    }

    It 'does not split a release title containing " - " when a real artist context already exists' {
        $result = Invoke-ReshelfRecognition -SourceRoot $FixturesDir -SessionId 'session-20' -DataHome $dataHome

        $artist = $result.artists | Where-Object { $_.recognizedName -eq 'Live Wire' }
        $artist | Should -Not -BeNullOrEmpty
        $release = $artist.releases[0]
        $release.recognizedTitle | Should -Be 'Live - The Tour'
        $release.needsReview | Should -Be $false
        $release.reviewReasons | Should -Not -Contain 'artist-name-split-from-folder-name'
    }

    It 'flags an empty artist folder (no audio anywhere) as unrecognized' {
        $result = Invoke-ReshelfRecognition -SourceRoot $FixturesDir -SessionId 'session-10' -DataHome $dataHome

        $entry = $result.unrecognized | Where-Object { $_.path -like '*Empty Artist' }
        $entry.reason | Should -Be 'no-audio-files'
    }

    It 'builds cue-sheet virtual tracks and routes the playlist file to ignoredFiles' {
        $result = Invoke-ReshelfRecognition -SourceRoot $FixturesDir -SessionId 'session-11' -DataHome $dataHome

        $pinkFloyd = $result.artists | Where-Object { $_.recognizedName -eq 'Pink Floyd' }
        $release = $pinkFloyd.releases[0]
        $release.cueSheet | Should -Not -BeNullOrEmpty
        $release.tracks.Count | Should -Be 2
        ($release.tracks.isCueVirtualTrack) | Should -Not -Contain $false
        $release.tracks[0].cueTimestamp | Should -Be '00:00:00'
        # Each cue track must get its OWN duration (gap to the next track's start, or to the
        # whole file's end for the last track) - not a flat copy of the whole-file mock duration
        # (200, from the Describe-level Get-ReshelfAudioTags mock) onto every track.
        $release.tracks[0].durationSeconds | Should -Be 192.6
        $release.tracks[1].durationSeconds | Should -Be 7.4
        $release.ignoredFiles.Count | Should -Be 1
        $release.ignoredFiles[0].reason | Should -Be 'playlist-file'
    }

    It 'names cue-sheet virtual tracks from an .ape source as flac, since ffmpeg cannot write .ape' {
        # ffmpeg has no ape encoder/muxer, so a cue split of an .ape source always re-encodes to
        # .flac (see Invoke-ReshelfFfmpegSplit in Reshelf.Implementation.psm1). The track's format
        # here must already say 'flac' so proposedFileName matches what apply actually produces.
        # Built dynamically under $TestDrive rather than checked into the static fixture tree -
        # the shared fixture tree feeds Reshelf.Pipeline.Tests.ps1's golden-file comparisons, and a
        # new release there would need those golden files regenerated too.
        $sourceRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $releaseDir = Join-Path $sourceRoot 'APE Cue Band' '1993 APE Bootleg'
        New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $releaseDir 'Show.ape') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $releaseDir 'Show.cue') -Value @'
PERFORMER "APE Cue Band"
TITLE "APE Bootleg"
FILE "Show.ape" WAVE
  TRACK 01 AUDIO
    TITLE "Intro"
    INDEX 01 00:00:00
  TRACK 02 AUDIO
    TITLE "Main Set"
    INDEX 01 05:10:20
'@

        # Second track starts at 05:10:20 (~310s) - the Describe-level mock's flat 200s whole-file
        # duration is shorter than that (unrealistic; a real file can't be shorter than its own
        # last track), which would make the now-computed per-track duration negative. Override
        # with a duration that actually fits both tracks; this test only cares about format/
        # isLossless, not duration.
        Mock -ModuleName Reshelf.Recognition Get-ReshelfAudioTags {
            param($Path, $TagLibSharpPath, $DataHome)
            $ext = [System.IO.Path]::GetExtension($Path).TrimStart('.').ToLowerInvariant()
            return @{
                Artist            = $null
                Album             = $null
                Title             = [System.IO.Path]::GetFileNameWithoutExtension($Path)
                Format            = $ext
                IsLossless        = ($ext -in @('flac', 'wav', 'ape'))
                DurationSeconds   = 400
                EmbeddedCoverPath = $null
            }
        }

        $result = Invoke-ReshelfRecognition -SourceRoot $sourceRoot -SessionId 'session-11b' -DataHome $dataHome

        $band = $result.artists | Where-Object { $_.recognizedName -eq 'APE Cue Band' }
        $release = $band.releases[0]
        $release.cueSheet | Should -Not -BeNullOrEmpty
        $release.tracks.Count | Should -Be 2
        ($release.tracks.format) | Should -Not -Contain 'ape'
        $release.tracks[0].format | Should -Be 'flac'
        $release.tracks[0].isLossless | Should -Be $true
        $release.tracks[1].format | Should -Be 'flac'
        $release.tracks[1].isLossless | Should -Be $true
    }

    It 'falls back to whole-folder alphabetical order for unnumbered tracks' {
        $result = Invoke-ReshelfRecognition -SourceRoot $FixturesDir -SessionId 'session-12' -DataHome $dataHome

        $unnumbered = $result.artists | Where-Object { $_.recognizedName -eq 'Unnumbered' }
        $release = $unnumbered.releases[0]
        ($release.tracks.inferredTrackOrder) | Should -Not -Contain $false
        ($release.recognitionFlags) | Should -Contain 'no-track-number'
        $release.tracks[0].originalFileName | Should -Be 'Alpha Song.flac'
    }

    It 'records a reserved device folder name (CON) raw, without converting it' {
        # Built dynamically under $TestDrive rather than checked into the static fixture tree -
        # Git for Windows cannot index a file inside a folder literally named CON, even though
        # PowerShell 7 / .NET Core can create and read one fine.
        $sourceRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType File -Path (Join-Path $sourceRoot 'CON' '2005 Weird' '01 - Track.mp3') -Force | Out-Null

        $result = Invoke-ReshelfRecognition -SourceRoot $sourceRoot -SessionId 'session-13' -DataHome $dataHome

        $con = $result.artists | Where-Object { $_.recognizedName -eq 'CON' }
        $con | Should -Not -BeNullOrEmpty
    }

    It 'flags a near-path-length-limit release without throwing' {
        # Built dynamically under $TestDrive rather than checked into the static fixture tree -
        # Git for Windows refuses to index a path this long without core.longpaths enabled, even
        # though PowerShell 7 / .NET Core handles it fine.
        $sourceRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $paddingLength = [Math]::Max(10, 250 - $sourceRoot.Length - 'Long Artist \1990 Long Path Album'.Length)
        $longArtistName = 'Long Artist ' + ('a' * $paddingLength)
        New-Item -ItemType File -Path (Join-Path $sourceRoot $longArtistName '1990 Long Path Album' '01 - track.mp3') -Force | Out-Null

        { Invoke-ReshelfRecognition -SourceRoot $sourceRoot -SessionId 'session-14' -DataHome $dataHome } | Should -Not -Throw

        $result = Invoke-ReshelfRecognition -SourceRoot $sourceRoot -SessionId 'session-15' -DataHome $dataHome
        $deepArtist = $result.artists | Where-Object { $_.recognizedName -like 'Long Artist *' }
        $deepArtist.releases[0].recognitionFlags | Should -Contain 'path-near-length-limit'
    }

    It 'merges sourcePaths when the same artist name is found under two different parents' {
        $sourceRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $sourceRoot 'Genre A\Shared Artist\1999 Album One') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $sourceRoot 'Genre B\Shared Artist\2001 Album Two') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $sourceRoot 'Genre A\Shared Artist\1999 Album One\01 - Track.flac') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $sourceRoot 'Genre B\Shared Artist\2001 Album Two\01 - Track.flac') -Force | Out-Null

        $overridesPath = Join-Path $TestDrive 'merge-overrides.json'
        $overridesDoc = [pscustomobject]@{
            schemaVersion = 1
            sourceRoot    = $sourceRoot
            entries       = @(
                [pscustomobject]@{ relativePath = 'Genre A'; kind = 'grouping'; parentArtistName = $null; artistName = $null; notes = '' }
                [pscustomobject]@{ relativePath = 'Genre B'; kind = 'grouping'; parentArtistName = $null; artistName = $null; notes = '' }
            )
        }
        $overridesDoc | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $overridesPath -Encoding utf8

        $result = Invoke-ReshelfRecognition -SourceRoot $sourceRoot -SessionId 'session-16' -DataHome $dataHome -OverridesPath $overridesPath

        $sharedArtist = $result.artists | Where-Object { $_.recognizedName -eq 'Shared Artist' }
        $sharedArtist | Should -Not -BeNullOrEmpty
        $sharedArtist.releases.Count | Should -Be 2
        $sharedArtist.sourcePaths.Count | Should -Be 2
    }

    It 'treats a loose audio file mixed with a subfolder of its own audio as a suspected nested release, not unclassified' {
        # A direct audio file makes Test-IsReleaseFolder claim the folder as a 'release' before the
        # unclassified-folder check ever runs - so this case is caught via nested-release-suspected
        # review instead, not a hard unrecognized rejection.
        $sourceRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $messyDir = Join-Path $sourceRoot 'Some Artist' 'Messy Junk'
        New-Item -ItemType Directory -Path (Join-Path $messyDir 'Weird Sub') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $messyDir 'Bonus Track.flac') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $messyDir 'Weird Sub' '01 - Track.flac') -Force | Out-Null

        $result = Invoke-ReshelfRecognition -SourceRoot $sourceRoot -SessionId 'session-17' -DataHome $dataHome

        $result.unrecognized | Where-Object { $_.path -like '*Messy Junk' } | Should -BeNullOrEmpty
        $release = $result.artists.releases | Where-Object { $_.sourceFolderPath -like '*Messy Junk' }
        $release | Should -Not -BeNullOrEmpty
        $release.needsReview | Should -Be $true
        $release.reviewReasons | Should -Contain 'nested-release-suspected'
    }

    It 'ignores a loose non-audio file sitting next to release subfolders and still recognizes the releases' {
        # Real-world case: an artist folder with a "Discography.txt" (or similar liner-notes/info
        # file) dropped directly alongside the release subfolders - no structural meaning, shouldn't
        # block recognition of the releases underneath.
        $sourceRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $artistDir = Join-Path $sourceRoot 'Some Artist'
        $releaseDir = Join-Path $artistDir '2010 Some Album'
        New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $artistDir 'Discography.txt') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $releaseDir '01 - Track.flac') -Force | Out-Null

        $result = Invoke-ReshelfRecognition -SourceRoot $sourceRoot -SessionId 'session-17b' -DataHome $dataHome

        $result.unrecognized | Where-Object { $_.path -like '*Some Artist' } | Should -BeNullOrEmpty
        $artist = $result.artists | Where-Object { $_.recognizedName -eq 'Some Artist' }
        $artist | Should -Not -BeNullOrEmpty
        $artist.releases.Count | Should -Be 1
        $artist.releases[0].recognizedTitle | Should -Be 'Some Album'
    }

    It 'still recognizes a single-file + .cue release when an orphaned second .cue for an unused rip format is also present' {
        # Found against a real collection sample: a release with one real .flac plus both
        # "Album.flac.cue" (matches the flac) and "Album.wav.cue" (orphaned - no .wav ever existed).
        # Before the Get-ReshelfCueSheetPathForAudio fix, 2 .cue files disqualified the folder from
        # cue-release detection entirely, silently collapsing the whole album into one giant
        # "track" instead of splitting it per the cue sheet.
        $sourceRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $releaseDir = Join-Path $sourceRoot 'Some Artist' '2003 Some Album'
        New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $releaseDir 'Some Album.flac') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $releaseDir 'Some Album.wav.cue') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $releaseDir 'Some Album.flac.cue') -Value @'
TRACK 01 AUDIO
  TITLE "First Track"
  INDEX 01 00:00:00
TRACK 02 AUDIO
  TITLE "Second Track"
  INDEX 01 03:30:00
'@

        # Second track starts at 03:30:00 (210s) - the Describe-level mock's flat 200s whole-file
        # duration is shorter than that (unrealistic; a real file can't be shorter than its own
        # last track), which would make the now-computed per-track duration negative. Override
        # with a duration that actually fits both tracks; this test only cares about cue-file
        # selection and track titles, not duration.
        Mock -ModuleName Reshelf.Recognition Get-ReshelfAudioTags {
            param($Path, $TagLibSharpPath, $DataHome)
            $ext = [System.IO.Path]::GetExtension($Path).TrimStart('.').ToLowerInvariant()
            return @{
                Artist            = $null
                Album             = $null
                Title             = [System.IO.Path]::GetFileNameWithoutExtension($Path)
                Format            = $ext
                IsLossless        = ($ext -in @('flac', 'wav', 'ape'))
                DurationSeconds   = 300
                EmbeddedCoverPath = $null
            }
        }

        $result = Invoke-ReshelfRecognition -SourceRoot $sourceRoot -SessionId 'session-22' -DataHome $dataHome

        $artist = $result.artists | Where-Object { $_.recognizedName -eq 'Some Artist' }
        $release = $artist.releases[0]
        $release.cueSheet | Should -Not -BeNullOrEmpty
        $release.cueSheet.cueFilePath | Should -Be (Join-Path $releaseDir 'Some Album.flac.cue')
        $release.tracks.Count | Should -Be 2
        $release.tracks[1].existingTags.title | Should -Be 'Second Track'
    }
}

Describe 'Get-ReshelfCueSheetPathForAudio (private)' {
    BeforeAll {
        # FileInfo objects are built here in the test's own scope (not inside InModuleScope) and
        # handed in via -Parameters - same reason as Get-TestUnprotectedSecret elsewhere in this
        # repo's tests: a function/variable defined at this script's top level isn't visible inside
        # an InModuleScope block, which runs in the imported module's own scope instead.
        function New-FakeCueFileInfo {
            param([string]$Name)
            return [System.IO.FileInfo]::new((Join-Path $TestDrive $Name))
        }
    }

    It 'returns $null when there are no cue files' {
        $audio = New-FakeCueFileInfo 'Album.flac'
        InModuleScope Reshelf.Recognition -Parameters @{ audio = $audio } {
            param($audio)
            Get-ReshelfCueSheetPathForAudio -AudioFile $audio -CueFiles @() | Should -Be $null
        }
    }

    It 'returns the only cue file regardless of its name when exactly one exists' {
        $audio = New-FakeCueFileInfo 'Album.flac'
        $cue = New-FakeCueFileInfo 'tracklist.cue'
        InModuleScope Reshelf.Recognition -Parameters @{ audio = $audio; cue = $cue } {
            param($audio, $cue)
            (Get-ReshelfCueSheetPathForAudio -AudioFile $audio -CueFiles @($cue)).Name | Should -Be 'tracklist.cue'
        }
    }

    It 'picks the cue file matching audioname.ext.cue out of several' {
        $audio = New-FakeCueFileInfo 'Album.flac'
        $match = New-FakeCueFileInfo 'Album.flac.cue'
        $orphan = New-FakeCueFileInfo 'Album.wav.cue'
        InModuleScope Reshelf.Recognition -Parameters @{ audio = $audio; match = $match; orphan = $orphan } {
            param($audio, $match, $orphan)
            (Get-ReshelfCueSheetPathForAudio -AudioFile $audio -CueFiles @($match, $orphan)).Name | Should -Be 'Album.flac.cue'
        }
    }

    It 'picks the cue file matching the audio file''s base name out of several' {
        $audio = New-FakeCueFileInfo 'Album.flac'
        $match = New-FakeCueFileInfo 'Album.cue'
        $orphan = New-FakeCueFileInfo 'Album.wav.cue'
        InModuleScope Reshelf.Recognition -Parameters @{ audio = $audio; match = $match; orphan = $orphan } {
            param($audio, $match, $orphan)
            (Get-ReshelfCueSheetPathForAudio -AudioFile $audio -CueFiles @($match, $orphan)).Name | Should -Be 'Album.cue'
        }
    }

    It 'returns $null when several cue files exist and none names the audio file' {
        $audio = New-FakeCueFileInfo 'Album.flac'
        $a = New-FakeCueFileInfo 'Other.flac.cue'
        $b = New-FakeCueFileInfo 'Other.wav.cue'
        InModuleScope Reshelf.Recognition -Parameters @{ audio = $audio; a = $a; b = $b } {
            param($audio, $a, $b)
            Get-ReshelfCueSheetPathForAudio -AudioFile $audio -CueFiles @($a, $b) | Should -Be $null
        }
    }

    It 'prefers the audioname.ext.cue match over a basename.cue match naming the same audio file' {
        # Real-world case: "Album.ape.cue" and "Album.cue" both present, identical content, both
        # naming the one .ape that's actually there - not competing formats, just redundant naming.
        # Must still resolve to one cue file instead of the 2-matches-across-rules $null bailout.
        $audio = New-FakeCueFileInfo 'Album.ape'
        $exactNameCue = New-FakeCueFileInfo 'Album.ape.cue'
        $baseNameCue = New-FakeCueFileInfo 'Album.cue'
        InModuleScope Reshelf.Recognition -Parameters @{ audio = $audio; exactNameCue = $exactNameCue; baseNameCue = $baseNameCue } {
            param($audio, $exactNameCue, $baseNameCue)
            (Get-ReshelfCueSheetPathForAudio -AudioFile $audio -CueFiles @($exactNameCue, $baseNameCue)).Name | Should -Be 'Album.ape.cue'
        }
    }
}
