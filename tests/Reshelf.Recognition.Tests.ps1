#Requires -Version 7.4

Import-Module Pester -MinimumVersion 5.0

BeforeAll {
    Import-Module "$PSScriptRoot/../scripts/common/Reshelf.Common.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Reshelf.Json.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Reshelf.Recognition.psm1" -Force

    $script:FixturesDir = (Resolve-Path "$PSScriptRoot/fixtures/sample-source-tree").Path
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

    It 'does not treat an artist folder whose children are all album-wrapper folders as a grouping folder' {
        # Real-world case (AC-DC): every child of the artist folder is a "yyyy - Title" wrapper
        # around an edition subfolder, not a release folder itself - without the album-wrapper check,
        # Test-IsGroupingFolder would wrongly claim this folder (no direct release-shaped child, >=2
        # subfolders) and stop the walk from ever descending into it.
        InModuleScope Reshelf.Recognition -Parameters @{ fixturesDir = $script:FixturesDir } {
            param($fixturesDir)
            Test-IsGroupingFolder -Path (Join-Path $fixturesDir 'Wrapper Band') | Should -Be $false
        }
    }

    It 'does not treat an artist folder as a grouping folder when its category subfolders'' releases carry its name as cue PERFORMER (real-world Iron Maiden\Studio Albums + Compilation Albums case)' {
        InModuleScope Reshelf.Recognition {
            $artistDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N')) 'Iron Maiden'
            $release1 = Join-Path $artistDir 'Studio Albums' '1980 - Iron Maiden'
            $release2 = Join-Path $artistDir 'Compilation Albums' '1996 - Best Of The Beast'
            New-Item -ItemType File -Path (Join-Path $release1 'Iron Maiden.flac') -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $release1 'Iron Maiden.cue') -Value 'PERFORMER "Iron Maiden"'
            New-Item -ItemType File -Path (Join-Path $release2 'Best Of The Beast.flac') -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $release2 'Best Of The Beast.cue') -Value 'PERFORMER "Iron Maiden"'

            Test-IsGroupingFolder -Path $artistDir | Should -Be $false
        }
    }
}

Describe 'Test-IsAlbumWrapperFolder (private)' {
    It 'recognizes a "yyyy - Title" folder that wraps a single edition subfolder' {
        InModuleScope Reshelf.Recognition -Parameters @{ fixturesDir = $script:FixturesDir } {
            param($fixturesDir)
            Test-IsAlbumWrapperFolder -Path (Join-Path $fixturesDir 'Wrapper Band\1975 - Wrapped Album (Special Edition)') | Should -Be $true
        }
    }

    It 'recognizes a "yyyy - Title" folder that wraps more than one edition subfolder' {
        # Built under $TestDrive, not the shared fixture tree - two editions of the same album/year
        # necessarily propose the same target folder name downstream, which the full pipeline fixture
        # tree (Reshelf.Pipeline.Tests.ps1) can't resolve without a human picking one; this test only
        # cares about the predicate itself.
        InModuleScope Reshelf.Recognition {
            $wrapperDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N')) '1980 - Multi Edition Album'
            New-Item -ItemType File -Path (Join-Path $wrapperDir '1988 Germany Label 1' '01 - Track One.flac') -Force | Out-Null
            New-Item -ItemType File -Path (Join-Path $wrapperDir '1992 Australia Label 2' '01 - Track One.flac') -Force | Out-Null

            Test-IsAlbumWrapperFolder -Path $wrapperDir | Should -Be $true
        }
    }

    It 'recognizes a "yyyy - Title" folder whose single edition subfolder itself has disc subfolders' {
        InModuleScope Reshelf.Recognition -Parameters @{ fixturesDir = $script:FixturesDir } {
            param($fixturesDir)
            Test-IsAlbumWrapperFolder -Path (Join-Path $fixturesDir 'Wrapper Band\2000 - Per Disc Cue Album') | Should -Be $true
        }
    }

    It 'rejects a normal release folder with tracks directly inside it' {
        InModuleScope Reshelf.Recognition -Parameters @{ fixturesDir = $script:FixturesDir } {
            param($fixturesDir)
            Test-IsAlbumWrapperFolder -Path (Join-Path $fixturesDir 'ZZ Top\1999 XXX') | Should -Be $false
        }
    }

    It 'rejects a folder whose name has no leading year' {
        InModuleScope Reshelf.Recognition -Parameters @{ fixturesDir = $script:FixturesDir } {
            param($fixturesDir)
            Test-IsAlbumWrapperFolder -Path (Join-Path $fixturesDir 'ZZ Top') | Should -Be $false
        }
    }

    It 'rejects a "yyyy - Title" folder with a subfolder that hides audio below an unknown extra layer of nesting' {
        # A guard case, not a real-world fixture: one subfolder ("1970 Real Edition") is a genuine
        # edition, but the other ("Bonus Nested") has audio two levels further down without itself
        # being a release folder - this must not be silently swallowed as if it were just another
        # edition. Built under $TestDrive, not the shared fixture tree, since it exists purely to
        # exercise this one guard and would otherwise also need a Test-IsBandMemberFolder-shaped
        # explanation for why it doesn't become a bogus artist during a full recognition run.
        InModuleScope Reshelf.Recognition {
            $sourceRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
            $wrapperDir = Join-Path $sourceRoot '1965 - Partial Wrapper'
            New-Item -ItemType File -Path (Join-Path $wrapperDir '1970 Real Edition' '01 - Track.flac') -Force | Out-Null
            New-Item -ItemType File -Path (Join-Path $wrapperDir 'Bonus Nested' 'Deeper' '01 - Track.flac') -Force | Out-Null

            Test-IsAlbumWrapperFolder -Path $wrapperDir | Should -Be $false
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

    It 'rejects a category-folder-in-disguise whose release metadata matches the parent artist (real-world Iron Maiden\Studio Albums case)' {
        InModuleScope Reshelf.Recognition {
            $parentDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N')) 'Iron Maiden'
            $categoryDir = Join-Path $parentDir 'Studio Albums'
            $releaseDir = Join-Path $categoryDir '1980 - Iron Maiden'
            New-Item -ItemType File -Path (Join-Path $releaseDir 'Iron Maiden.flac') -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $releaseDir 'Iron Maiden.cue') -Value 'PERFORMER "Iron Maiden"'

            Test-IsBandMemberFolder -Path $categoryDir -ParentArtistName 'Iron Maiden' | Should -Be $false
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

    It 'parses a bracketed numbered filename (real Various-Artists rip case, "[01] Blind Guardian - ...")' {
        InModuleScope Reshelf.Recognition {
            $result = ConvertFrom-ReshelfTrackFileName -FileName "[01] Blind Guardian - Don't Talk To Stranger.mp3"
            $result.Number | Should -Be 1
            $result.Title | Should -Be "Blind Guardian - Don't Talk To Stranger"
            $result.HasNumber | Should -Be $true
            $result.ArtistPart | Should -Be 'Blind Guardian'
            $result.TitlePart | Should -Be "Don't Talk To Stranger"
        }
    }

    It 'parses a parenthesized numbered filename' {
        InModuleScope Reshelf.Recognition {
            $result = ConvertFrom-ReshelfTrackFileName -FileName '(02) Some Track.flac'
            $result.Number | Should -Be 2
            $result.Title | Should -Be 'Some Track'
            $result.HasNumber | Should -Be $true
        }
    }

    It 'does not read a parenthesized year as a track number' {
        InModuleScope Reshelf.Recognition {
            $result = ConvertFrom-ReshelfTrackFileName -FileName '(1999) Some Track.flac'
            $result.Number | Should -Be $null
            $result.HasNumber | Should -Be $false
        }
    }

    It 'leaves ArtistPart/TitlePart null when the title has no "Artist - Title" dash' {
        InModuleScope Reshelf.Recognition {
            $result = ConvertFrom-ReshelfTrackFileName -FileName '03 Some Track.mp3'
            $result.ArtistPart | Should -BeNullOrEmpty
            $result.TitlePart | Should -BeNullOrEmpty
        }
    }
}

Describe 'Remove-ReshelfArtistNamePrefixFromTitle (private)' {
    It 'strips the artist name and a dash separator regardless of letter case' {
        InModuleScope Reshelf.Recognition {
            $result = Remove-ReshelfArtistNamePrefixFromTitle -Title 'DANCE WITH THE DEAD - Blackout' -ArtistName 'Dance with the dead'
            $result.Title | Should -Be 'Blackout'
            $result.WasStripped | Should -Be $true
            $result.Year | Should -BeNullOrEmpty
        }
    }

    It 'strips a parenthesized year between the artist name and the separator, and returns it (real Aerosmith case)' {
        InModuleScope Reshelf.Recognition {
            $result = Remove-ReshelfArtistNamePrefixFromTitle -Title 'Aerosmith (1973) - Aerosmith [USA CK 32005]' -ArtistName 'Aerosmith'
            $result.Title | Should -Be 'Aerosmith [USA CK 32005]'
            $result.WasStripped | Should -Be $true
            $result.Year | Should -Be 1973
        }
    }

    It 'strips a bracketed year between the artist name and the separator' {
        InModuleScope Reshelf.Recognition {
            $result = Remove-ReshelfArtistNamePrefixFromTitle -Title 'Aerosmith [1977] - Draw the Line' -ArtistName 'Aerosmith'
            $result.Title | Should -Be 'Draw the Line'
            $result.WasStripped | Should -Be $true
            $result.Year | Should -Be 1977
        }
    }

    It 'leaves the title untouched when the 4-digit group is outside the year range' {
        InModuleScope Reshelf.Recognition {
            $result = Remove-ReshelfArtistNamePrefixFromTitle -Title 'Some Band (3218) - X' -ArtistName 'Some Band'
            $result.Title | Should -Be 'Some Band (3218) - X'
            $result.WasStripped | Should -Be $false
            $result.Year | Should -BeNullOrEmpty
        }
    }

    It 'strips a colon separator' {
        InModuleScope Reshelf.Recognition {
            $result = Remove-ReshelfArtistNamePrefixFromTitle -Title 'Some Band: Live Album' -ArtistName 'Some Band'
            $result.Title | Should -Be 'Live Album'
            $result.WasStripped | Should -Be $true
        }
    }

    It 'leaves the title untouched when it does not start with the artist name' {
        InModuleScope Reshelf.Recognition {
            $result = Remove-ReshelfArtistNamePrefixFromTitle -Title 'Live - The Tour' -ArtistName 'Live Wire'
            $result.Title | Should -Be 'Live - The Tour'
            $result.WasStripped | Should -Be $false
        }
    }

    It 'leaves the title untouched when the artist name is a prefix but not followed by a separator' {
        InModuleScope Reshelf.Recognition {
            $result = Remove-ReshelfArtistNamePrefixFromTitle -Title 'Dance With The Devil' -ArtistName 'Dance'
            $result.Title | Should -Be 'Dance With The Devil'
            $result.WasStripped | Should -Be $false
        }
    }

    It 'leaves the title untouched when stripping would leave nothing' {
        InModuleScope Reshelf.Recognition {
            $result = Remove-ReshelfArtistNamePrefixFromTitle -Title 'Some Band -' -ArtistName 'Some Band'
            $result.Title | Should -Be 'Some Band -'
            $result.WasStripped | Should -Be $false
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

Describe 'Get-ReshelfCueSheetHeader (private)' {
    It 'reads the disc-level PERFORMER and REM DISCNUMBER, ignoring a per-track PERFORMER' {
        InModuleScope Reshelf.Recognition {
            $path = Join-Path $TestDrive 'header.cue'
            Set-Content -LiteralPath $path -Value @'
REM DISCNUMBER 2
PERFORMER "Iron Maiden"
TITLE "Best Of The Beast (TOCP-50129)"
FILE "Iron Maiden - Best Of The Beast (TOCP-50129).flac" WAVE
  TRACK 01 AUDIO
    TITLE "Rime Of The Ancient Mariner (Live)"
    PERFORMER "A Different Performer"
    INDEX 01 00:00:00
'@
            $header = Get-ReshelfCueSheetHeader -CueFilePath $path
            $header.Performer | Should -Be 'Iron Maiden'
            $header.DiscNumber | Should -Be 2
        }
    }

    It 'returns $null fields when the cue has no header lines' {
        InModuleScope Reshelf.Recognition {
            $path = Join-Path $TestDrive 'no-header.cue'
            Set-Content -LiteralPath $path -Value @'
TRACK 01 AUDIO
  TITLE "Track"
  INDEX 01 00:00:00
'@
            $header = Get-ReshelfCueSheetHeader -CueFilePath $path
            $header.Performer | Should -BeNullOrEmpty
            $header.DiscNumber | Should -BeNullOrEmpty
        }
    }

    It 'returns $null for a missing cue file' {
        InModuleScope Reshelf.Recognition {
            Get-ReshelfCueSheetHeader -CueFilePath (Join-Path $TestDrive 'missing.cue') | Should -Be $null
        }
    }
}

Describe 'Get-ReshelfFlatDiscCuePairs (private)' {
    It 'pairs each audio file with its own distinct cue, ordering by the catalog-number hint in the folder name (real-world Iron Maiden "The X Factor" case)' {
        InModuleScope Reshelf.Recognition {
            $releaseDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N')) '1995 - The X Factor (TOCP-8588)'
            New-Item -ItemType File -Path (Join-Path $releaseDir 'Iron Maiden - The X Factor (TOCP-8588).flac') -Force | Out-Null
            New-Item -ItemType File -Path (Join-Path $releaseDir 'Iron Maiden - The X Factor (BCD-0033).flac') -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $releaseDir 'Iron Maiden - The X Factor (TOCP-8588).cue') -Value 'PERFORMER "Iron Maiden"'
            Set-Content -LiteralPath (Join-Path $releaseDir 'Iron Maiden - The X Factor (BCD-0033).cue') -Value 'PERFORMER "Iron Maiden"'

            $pairs = Get-ReshelfFlatDiscCuePairs -Path $releaseDir
            $pairs.Count | Should -Be 2
            $pairs[0].AudioFile.Name | Should -Be 'Iron Maiden - The X Factor (TOCP-8588).flac'
            $pairs[1].AudioFile.Name | Should -Be 'Iron Maiden - The X Factor (BCD-0033).flac'
        }
    }

    It 'orders by REM DISCNUMBER when every cue has one, even if it disagrees with the folder-name hint' {
        InModuleScope Reshelf.Recognition {
            $releaseDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N')) '1995 - The X Factor (TOCP-8588)'
            New-Item -ItemType File -Path (Join-Path $releaseDir 'Iron Maiden - The X Factor (TOCP-8588).flac') -Force | Out-Null
            New-Item -ItemType File -Path (Join-Path $releaseDir 'Iron Maiden - The X Factor (BCD-0033).flac') -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $releaseDir 'Iron Maiden - The X Factor (TOCP-8588).cue') -Value 'REM DISCNUMBER 2'
            Set-Content -LiteralPath (Join-Path $releaseDir 'Iron Maiden - The X Factor (BCD-0033).cue') -Value 'REM DISCNUMBER 1'

            $pairs = Get-ReshelfFlatDiscCuePairs -Path $releaseDir
            $pairs.Count | Should -Be 2
            $pairs[0].AudioFile.Name | Should -Be 'Iron Maiden - The X Factor (BCD-0033).flac'
            $pairs[1].AudioFile.Name | Should -Be 'Iron Maiden - The X Factor (TOCP-8588).flac'
        }
    }

    It 'returns an empty list when 2 audio files share a single cue (not one cue per disc)' {
        InModuleScope Reshelf.Recognition {
            $releaseDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N')) '2003 Some Album'
            New-Item -ItemType File -Path (Join-Path $releaseDir 'Track A.flac') -Force | Out-Null
            New-Item -ItemType File -Path (Join-Path $releaseDir 'Track B.flac') -Force | Out-Null
            New-Item -ItemType File -Path (Join-Path $releaseDir 'Album.cue') -Force | Out-Null

            Get-ReshelfFlatDiscCuePairs -Path $releaseDir | Should -BeNullOrEmpty
        }
    }

    It 'returns an empty list when fewer than 2 audio files are present' {
        InModuleScope Reshelf.Recognition {
            $releaseDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N')) '2003 Some Album'
            New-Item -ItemType File -Path (Join-Path $releaseDir 'Track A.flac') -Force | Out-Null
            New-Item -ItemType File -Path (Join-Path $releaseDir 'Track A.cue') -Force | Out-Null

            Get-ReshelfFlatDiscCuePairs -Path $releaseDir | Should -BeNullOrEmpty
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
            $result = Get-ReshelfCompanionFiles -Path $releaseDir -CueSheetPaths @((Join-Path $releaseDir 'Live In Concert.cue'))
            $result.Ignored.Count | Should -Be 1
            $result.Ignored[0].reason | Should -Be 'playlist-file'
        }
    }

    It 'routes an unused .cue file to ignored with reason cue-sheet-not-used when no CueSheetPaths is given' {
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

    It 'flags a release for review when a track''s audio properties could not be read' {
        Mock -ModuleName Reshelf.Recognition Get-ReshelfAudioTags {
            param($Path, $TagLibSharpPath, $DataHome)
            $ext = [System.IO.Path]::GetExtension($Path).TrimStart('.').ToLowerInvariant()
            $propertiesUnavailable = $Path -like '*Poke Chop Sandwich*'
            return @{
                Artist                = $null
                Album                 = $null
                Title                 = [System.IO.Path]::GetFileNameWithoutExtension($Path)
                Format                = $ext
                IsLossless            = ($ext -in @('flac', 'wav', 'ape'))
                DurationSeconds       = if ($propertiesUnavailable) { 0 } else { 200 }
                EmbeddedCoverPath     = $null
                PropertiesUnavailable = $propertiesUnavailable
            }
        }

        $result = Invoke-ReshelfRecognition -SourceRoot $FixturesDir -SessionId 'session-2d' -DataHome $dataHome

        $zzTop = $result.artists | Where-Object { $_.recognizedName -eq 'ZZ Top' }
        $release = $zzTop.releases | Where-Object { $_.recognizedTitle -eq 'XXX' }
        $release.needsReview | Should -Be $true
        $release.reviewReasons | Should -Contain 'audio-properties-unreadable'
        $affectedTrack = $release.tracks | Where-Object { $_.originalFileName -eq '01 - Poke Chop Sandwich.flac' }
        $affectedTrack.durationSeconds | Should -Be 0
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
            @{ Folder = '2006-Fire Without Flame'; Year = 2006; Title = 'Fire Without Flame' }
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

    It 'walks a grouping folder automatically, treating each subfolder as its own artist flagged for review' {
        $result = Invoke-ReshelfRecognition -SourceRoot $FixturesDir -SessionId 'session-6' -DataHome $dataHome

        ($result.unrecognized.reason) | Should -Not -Contain 'grouping-folder-suspected'
        $gybe = $result.artists | Where-Object { $_.recognizedName -eq 'Godspeed You! Black Emperor' }
        $silverMountainZion = $result.artists | Where-Object { $_.recognizedName -eq 'Silver Mountain Zion' }
        $gybe | Should -Not -BeNullOrEmpty
        $silverMountainZion | Should -Not -BeNullOrEmpty
        $gybe.releases | ForEach-Object {
            $_.needsReview | Should -Be $true
            $_.reviewReasons | Should -Contain 'grouping-folder-auto-resolved'
        }
    }

    It 'flags a release folder with no artist wrapper as unrecognized' {
        $result = Invoke-ReshelfRecognition -SourceRoot $FixturesDir -SessionId 'session-8' -DataHome $dataHome
        ($result.unrecognized.reason) | Should -Contain 'release-without-artist-suspected'
    }

    It 'promotes a release-without-artist folder into a recognized release when every track agrees on artist/album tags (real-world "edbl" case)' {
        # Real case (plan/12 milestone 3): a folder with no artist wrapper and no " - " in its own
        # name, but every track's tags agree - must not be dropped to unrecognized[] just because the
        # folder *name* can't be parsed.
        $sourceRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType File -Path (Join-Path $sourceRoot 'edbl' '01 Track One.flac') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $sourceRoot 'edbl' '02 Track Two.flac') -Force | Out-Null

        Mock -ModuleName Reshelf.Recognition Get-ReshelfAudioTags {
            param($Path, $TagLibSharpPath, $DataHome)
            return @{
                Artist = 'edbl'; Album = 'minibeats, vol.1'; Title = [System.IO.Path]::GetFileNameWithoutExtension($Path)
                Format = 'flac'; IsLossless = $true; DurationSeconds = 200; EmbeddedCoverPath = $null
            }
        }

        $result = Invoke-ReshelfRecognition -SourceRoot $sourceRoot -SessionId 'session-24' -DataHome $dataHome

        ($result.unrecognized.reason) | Should -Not -Contain 'release-without-artist-suspected'
        $artist = $result.artists | Where-Object { $_.recognizedName -eq 'edbl' }
        $artist | Should -Not -BeNullOrEmpty
        $release = $artist.releases[0]
        $release.recognizedTitle | Should -Be 'minibeats, vol.1'
        $release.tracks.Count | Should -Be 2
        $release.needsReview | Should -Be $true
        $release.reviewReasons | Should -Contain 'artist-and-album-from-tags'
    }

    It 'leaves a release-without-artist folder unrecognized when tracks disagree on artist/album tags' {
        $sourceRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType File -Path (Join-Path $sourceRoot 'Mixed' '01 Track One.flac') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $sourceRoot 'Mixed' '02 Track Two.flac') -Force | Out-Null

        Mock -ModuleName Reshelf.Recognition Get-ReshelfAudioTags {
            param($Path, $TagLibSharpPath, $DataHome)
            $isFirst = $Path -like '*01 Track One*'
            return @{
                Artist = if ($isFirst) { 'Artist A' } else { 'Artist B' }; Album = 'Some Album'
                Title = [System.IO.Path]::GetFileNameWithoutExtension($Path)
                Format = 'flac'; IsLossless = $true; DurationSeconds = 200; EmbeddedCoverPath = $null
            }
        }

        $result = Invoke-ReshelfRecognition -SourceRoot $sourceRoot -SessionId 'session-25' -DataHome $dataHome

        ($result.unrecognized.reason) | Should -Contain 'release-without-artist-suspected'
        ($result.artists.recognizedName) | Should -Not -Contain 'Artist A'
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

    It 'strips a release folder name that repeats its own artist name (real-world case), without needsReview' {
        # Confirmed against the real Discogs API (2026-09-26, plan/12 milestone 3): a release_title
        # search that still contains the artist name returns zero results even when the release
        # genuinely exists - this is a deterministic cleanup, not an ambiguous guess.
        $result = Invoke-ReshelfRecognition -SourceRoot $FixturesDir -SessionId 'session-23' -DataHome $dataHome

        $artist = $result.artists | Where-Object { $_.recognizedName -eq 'Dance With Ghosts' }
        $artist | Should -Not -BeNullOrEmpty
        $release = $artist.releases[0]
        $release.recognizedTitle | Should -Be 'Requiem'
        $release.recognitionFlags | Should -Contain 'artist-name-prefix-stripped'
        $release.needsReview | Should -Be $false
    }

    It 'parses the year when it sits between a repeated artist-name prefix and the title (real-world Nostromo case)' {
        $sourceRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType File -Path (Join-Path $sourceRoot 'Nostromo' 'Nostromo - 1998 - Argue FLAC' '01 - Track.flac') -Force | Out-Null

        $result = Invoke-ReshelfRecognition -SourceRoot $sourceRoot -SessionId 'session-26' -DataHome $dataHome

        $artist = $result.artists | Where-Object { $_.recognizedName -eq 'Nostromo' }
        $artist | Should -Not -BeNullOrEmpty
        $release = $artist.releases[0]
        $release.recognizedYear | Should -Be 1998
        $release.recognizedTitle | Should -Be 'Argue FLAC'
        $release.recognitionFlags | Should -Contain 'artist-name-prefix-stripped'
    }

    It 'parses the year when it sits in parentheses after a repeated artist-name prefix (real-world Aerosmith case)' {
        $sourceRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType File -Path (Join-Path $sourceRoot 'Aerosmith' 'Aerosmith (1979) - Night In The Ruts [Austria 466720 2]' '01 - Track.flac') -Force | Out-Null

        $result = Invoke-ReshelfRecognition -SourceRoot $sourceRoot -SessionId 'session-27' -DataHome $dataHome

        $artist = $result.artists | Where-Object { $_.recognizedName -eq 'Aerosmith' }
        $artist | Should -Not -BeNullOrEmpty
        $release = $artist.releases[0]
        $release.recognizedYear | Should -Be 1979
        $release.recognizedTitle | Should -Be 'Night In The Ruts [Austria 466720 2]'
        $release.recognitionFlags | Should -Contain 'artist-name-prefix-stripped'
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
        $release.cueSheets.Count | Should -Be 1
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
        $release.cueSheets.Count | Should -Be 1
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
        # "Genre A"/"Genre B" are plain filler folders (1 subfolder each, so neither qualifies as a
        # grouping folder) - each one's "Shared Artist" child is recognized as a band-member-shaped
        # wrapper (a pure container whose own child is a release folder), so the two "Shared Artist"
        # folders merge into one artist bucket purely from the walk's own heuristics, no override
        # needed.
        $sourceRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $sourceRoot 'Genre A\Shared Artist\1999 Album One') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $sourceRoot 'Genre B\Shared Artist\2001 Album Two') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $sourceRoot 'Genre A\Shared Artist\1999 Album One\01 - Track.flac') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $sourceRoot 'Genre B\Shared Artist\2001 Album Two\01 - Track.flac') -Force | Out-Null

        $result = Invoke-ReshelfRecognition -SourceRoot $sourceRoot -SessionId 'session-16' -DataHome $dataHome

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
        $release.cueSheets.Count | Should -Be 1
        $release.cueSheets[0].cueFilePath | Should -Be (Join-Path $releaseDir 'Some Album.flac.cue')
        $release.tracks.Count | Should -Be 2
        $release.tracks[1].existingTags.title | Should -Be 'Second Track'
    }

    It 'splits a flat multi-disc folder (several flac+cue pairs, no CD subfolders) into one disc per pair, ordered by catalog-number hint in the folder name (real-world Iron Maiden "The X Factor" case)' {
        $sourceRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $releaseDir = Join-Path $sourceRoot 'Iron Maiden' '1995 - The X Factor (TOCP-8588)'
        New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $releaseDir 'Iron Maiden - The X Factor (TOCP-8588).flac') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $releaseDir 'Iron Maiden - The X Factor (BCD-0033).flac') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $releaseDir 'Iron Maiden - The X Factor (TOCP-8588).cue') -Value @'
PERFORMER "Iron Maiden"
FILE "Iron Maiden - The X Factor (TOCP-8588).flac" WAVE
  TRACK 01 AUDIO
    TITLE "Sign Of The Cross"
    INDEX 01 00:00:00
  TRACK 02 AUDIO
    TITLE "Lord Of The Flies"
    INDEX 01 02:00:00
'@
        Set-Content -LiteralPath (Join-Path $releaseDir 'Iron Maiden - The X Factor (BCD-0033).cue') -Value @'
PERFORMER "Iron Maiden"
FILE "Iron Maiden - The X Factor (BCD-0033).flac" WAVE
  TRACK 01 AUDIO
    TITLE "Justice Of The Peace"
    INDEX 01 00:00:00
'@

        $result = Invoke-ReshelfRecognition -SourceRoot $sourceRoot -SessionId 'session-29' -DataHome $dataHome

        $artist = $result.artists | Where-Object { $_.recognizedName -eq 'Iron Maiden' }
        $release = $artist.releases[0]
        $release.discFolderCount | Should -Be 2
        $release.cueSheets.Count | Should -Be 2
        $release.needsReview | Should -Be $true
        $release.reviewReasons | Should -Contain 'flat-multi-disc-cue-pairs'
        ($release.ignoredFiles.reason) | Should -Not -Contain 'cue-sheet-not-used'
        $discOrder = @($release.tracks | ForEach-Object discFolder | Select-Object -Unique)
        $discOrder[0] | Should -BeLike '*TOCP-8588*'
        $discOrder[1] | Should -BeLike '*BCD-0033*'
        ($release.tracks | Where-Object { $_.discFolder -like '*TOCP-8588*' }).Count | Should -Be 2
        ($release.tracks | Where-Object { $_.discFolder -like '*BCD-0033*' }).Count | Should -Be 1
    }

    It 'orders flat multi-disc pairs by REM DISCNUMBER, even when it disagrees with the catalog-number hint in the folder name' {
        $sourceRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $releaseDir = Join-Path $sourceRoot 'Iron Maiden' '1995 - The X Factor (TOCP-8588)'
        New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $releaseDir 'Iron Maiden - The X Factor (TOCP-8588).flac') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $releaseDir 'Iron Maiden - The X Factor (BCD-0033).flac') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $releaseDir 'Iron Maiden - The X Factor (TOCP-8588).cue') -Value @'
REM DISCNUMBER 2
PERFORMER "Iron Maiden"
FILE "Iron Maiden - The X Factor (TOCP-8588).flac" WAVE
  TRACK 01 AUDIO
    TITLE "Sign Of The Cross"
    INDEX 01 00:00:00
'@
        Set-Content -LiteralPath (Join-Path $releaseDir 'Iron Maiden - The X Factor (BCD-0033).cue') -Value @'
REM DISCNUMBER 1
PERFORMER "Iron Maiden"
FILE "Iron Maiden - The X Factor (BCD-0033).flac" WAVE
  TRACK 01 AUDIO
    TITLE "Justice Of The Peace"
    INDEX 01 00:00:00
'@

        $result = Invoke-ReshelfRecognition -SourceRoot $sourceRoot -SessionId 'session-30' -DataHome $dataHome

        $artist = $result.artists | Where-Object { $_.recognizedName -eq 'Iron Maiden' }
        $release = $artist.releases[0]
        $discOrder = @($release.tracks | ForEach-Object discFolder | Select-Object -Unique)
        $discOrder[0] | Should -BeLike '*BCD-0033*'
        $discOrder[1] | Should -BeLike '*TOCP-8588*'
    }

    It 'falls back to the old ordinary-track behavior when 2 audio files share a single cue (not one cue per disc)' {
        $sourceRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $releaseDir = Join-Path $sourceRoot 'Some Artist' '2003 Some Album'
        New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $releaseDir '01 - Track One.flac') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $releaseDir '02 - Track Two.flac') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $releaseDir 'Album.cue') -Force | Out-Null

        $result = Invoke-ReshelfRecognition -SourceRoot $sourceRoot -SessionId 'session-31' -DataHome $dataHome

        $artist = $result.artists | Where-Object { $_.recognizedName -eq 'Some Artist' }
        $release = $artist.releases[0]
        $release.discFolderCount | Should -Be 1
        $release.cueSheets.Count | Should -Be 0
        $release.tracks.Count | Should -Be 2
        ($release.tracks.isCueVirtualTrack) | Should -Not -Contain $true
        $cueEntry = $release.ignoredFiles | Where-Object { $_.sourcePath -like '*Album.cue' }
        $cueEntry.reason | Should -Be 'cue-sheet-not-used'
    }

    It 'walks an artist folder with category subfolders whose releases carry its name as cue PERFORMER into one artist bucket (real-world Iron Maiden\Studio Albums + Compilation Albums case)' {
        $sourceRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $release1 = Join-Path $sourceRoot 'Iron Maiden' 'Studio Albums' '1980 - Iron Maiden'
        $release2 = Join-Path $sourceRoot 'Iron Maiden' 'Compilation Albums' '1996 - Best Of The Beast'
        New-Item -ItemType File -Path (Join-Path $release1 'Iron Maiden.flac') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $release1 'Iron Maiden.cue') -Value 'PERFORMER "Iron Maiden"'
        New-Item -ItemType File -Path (Join-Path $release2 'Best Of The Beast.flac') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $release2 'Best Of The Beast.cue') -Value 'PERFORMER "Iron Maiden"'

        $result = Invoke-ReshelfRecognition -SourceRoot $sourceRoot -SessionId 'session-32' -DataHome $dataHome

        $ironMaiden = $result.artists | Where-Object { $_.recognizedName -eq 'Iron Maiden' }
        $ironMaiden | Should -Not -BeNullOrEmpty
        $ironMaiden.releases.Count | Should -Be 2
        ($result.artists.recognizedName) | Should -Not -Contain 'Studio Albums'
        ($result.artists.recognizedName) | Should -Not -Contain 'Compilation Albums'
        ($ironMaiden.releases.reviewReasons) | Should -Not -Contain 'grouping-folder-auto-resolved'
    }

    It 'recognizes a "yyyy - Title" album wrapper around a single edition subfolder, title/year from the album folder' {
        $result = Invoke-ReshelfRecognition -SourceRoot $FixturesDir -SessionId 'session-26' -DataHome $dataHome

        $artist = $result.artists | Where-Object { $_.recognizedName -eq 'Wrapper Band' }
        $artist | Should -Not -BeNullOrEmpty
        $release = $artist.releases | Where-Object { $_.recognizedTitle -eq 'Wrapped Album (Special Edition)' }
        $release | Should -Not -BeNullOrEmpty
        $release.recognizedYear | Should -Be 1975
        $release.editionFolderName | Should -Be '1989 Country Label 123'
        $release.sourceFolderPath | Should -Be (Join-Path $FixturesDir 'Wrapper Band\1975 - Wrapped Album (Special Edition)\1989 Country Label 123')
        $release.tracks.Count | Should -Be 2
        $release.needsReview | Should -Be $false
    }

    It 'splits an album wrapper with two edition subfolders into two reviewed releases with distinct stableKeys' {
        # Built under its own source root, not the shared fixture tree - see the note on the matching
        # Test-IsAlbumWrapperFolder unit test above.
        $sourceRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType File -Path (Join-Path $sourceRoot 'Wrapper Band' '1980 - Multi Edition Album' '1988 Germany Label 1' '01 - Track One.flac') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $sourceRoot 'Wrapper Band' '1980 - Multi Edition Album' '1992 Australia Label 2' '01 - Track One.flac') -Force | Out-Null

        $result = Invoke-ReshelfRecognition -SourceRoot $sourceRoot -SessionId 'session-27' -DataHome $dataHome

        $artist = $result.artists | Where-Object { $_.recognizedName -eq 'Wrapper Band' }
        $releases = @($artist.releases | Where-Object { $_.recognizedTitle -eq 'Multi Edition Album' })
        $releases.Count | Should -Be 2
        ($releases.editionFolderName | Sort-Object -Unique).Count | Should -Be 2
        ($releases.stableKey | Sort-Object -Unique).Count | Should -Be 2
        $releases | ForEach-Object {
            $_.needsReview | Should -Be $true
            $_.reviewReasons | Should -Contain 'multiple-editions-in-album-folder'
        }
    }

    It 'flags a release for review when its album wrapper folder has a loose file, and does not copy that file in' {
        $result = Invoke-ReshelfRecognition -SourceRoot $FixturesDir -SessionId 'session-28' -DataHome $dataHome

        $artist = $result.artists | Where-Object { $_.recognizedName -eq 'Wrapper Band' }
        $release = $artist.releases | Where-Object { $_.recognizedTitle -eq 'Loose Files Album' }
        $release | Should -Not -BeNullOrEmpty
        $release.needsReview | Should -Be $true
        $release.reviewReasons | Should -Contain 'album-folder-has-loose-files'
        ($release.companionFiles.sourcePath + $release.ignoredFiles.sourcePath) | Should -Not -Contain (Join-Path $FixturesDir 'Wrapper Band\1990 - Loose Files Album\cover.jpg')
    }

    It 'builds cueSheets per disc for a per-disc-cue release nested inside an album wrapper' {
        $result = Invoke-ReshelfRecognition -SourceRoot $FixturesDir -SessionId 'session-29' -DataHome $dataHome

        $artist = $result.artists | Where-Object { $_.recognizedName -eq 'Wrapper Band' }
        $release = $artist.releases | Where-Object { $_.recognizedTitle -eq 'Per Disc Cue Album' }
        $release | Should -Not -BeNullOrEmpty
        $release.cueSheets.Count | Should -Be 2
        $release.discFolderCount | Should -Be 2
        $release.tracks.Count | Should -Be 3
        ($release.tracks.isCueVirtualTrack) | Should -Not -Contain $false
        ($release.tracks | Where-Object { $_.discFolder -eq 'CD 1' }).Count | Should -Be 2
        ($release.tracks | Where-Object { $_.discFolder -eq 'CD 2' }).Count | Should -Be 1
        ($release.ignoredFiles | Where-Object { $_.reason -eq 'cue-sheet-not-used' }) | Should -BeNullOrEmpty
        $release.reviewReasons | Should -Not -Contain 'per-disc-cue-not-yet-supported'
    }

    It 'mixes a cue-image disc with a normal numbered-track disc in the same release' {
        $result = Invoke-ReshelfRecognition -SourceRoot $FixturesDir -SessionId 'session-30' -DataHome $dataHome

        $artist = $result.artists | Where-Object { $_.recognizedName -eq 'Wrapper Band' }
        $release = $artist.releases | Where-Object { $_.recognizedTitle -eq 'Mixed Disc Album' }
        $release | Should -Not -BeNullOrEmpty
        $release.cueSheets.Count | Should -Be 1
        $cd1Tracks = @($release.tracks | Where-Object { $_.discFolder -eq 'CD 1' })
        $cd2Tracks = @($release.tracks | Where-Object { $_.discFolder -eq 'CD 2' })
        $cd1Tracks.Count | Should -Be 2
        ($cd1Tracks.isCueVirtualTrack) | Should -Not -Contain $false
        $cd2Tracks.Count | Should -Be 2
        ($cd2Tracks.isCueVirtualTrack) | Should -Not -Contain $true
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
