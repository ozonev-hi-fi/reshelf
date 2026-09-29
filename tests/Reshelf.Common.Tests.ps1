#Requires -Version 7.4

Import-Module Pester -MinimumVersion 5.0

BeforeAll {
    Import-Module "$PSScriptRoot/../scripts/common/Reshelf.Common.psm1" -Force
}

Describe 'Resolve-ReshelfDataHome' {
    BeforeEach {
        $script:originalReshelfHome = $env:RESHELF_HOME
        $script:originalLocalAppData = $env:LOCALAPPDATA
    }

    AfterEach {
        if ($null -eq $script:originalReshelfHome) {
            Remove-Item Env:\RESHELF_HOME -ErrorAction SilentlyContinue
        }
        else {
            $env:RESHELF_HOME = $script:originalReshelfHome
        }
        $env:LOCALAPPDATA = $script:originalLocalAppData
    }

    It 'creates and returns a writable directory' {
        $testHome = Join-Path $TestDrive 'ReshelfHomeTest'
        $env:RESHELF_HOME = $testHome

        $result = Resolve-ReshelfDataHome

        $result | Should -Exist
        { New-Item -ItemType File -Path (Join-Path $result 'probe.tmp') -Force } | Should -Not -Throw
    }

    It 'throws when the data home path exists but is a file, not a directory' {
        $testHome = Join-Path $TestDrive 'ReshelfHomeAsFile.tmp'
        New-Item -ItemType File -Path $testHome -Force | Out-Null
        $env:RESHELF_HOME = $testHome

        { Resolve-ReshelfDataHome } | Should -Throw
    }

    It 'defaults to a .data folder inside the repo when RESHELF_HOME is not set' {
        Remove-Item Env:\RESHELF_HOME -ErrorAction SilentlyContinue

        # This really resolves (and, if missing, creates) the repo's actual '.data' folder - the
        # same path production code defaults to - not a $TestDrive path, since the default is
        # defined relative to the module's own location. Left in place afterward on purpose: it's
        # the real target folder going forward, not test scratch to clean up.
        $result = Resolve-ReshelfDataHome

        $expected = (Resolve-Path (Join-Path $PSScriptRoot '..' '.data')).Path.TrimEnd('\')
        $result.TrimEnd('\') | Should -Be $expected
    }
}

Describe 'ConvertTo-ReshelfNormalizedText (private)' {
    It 'lowercases, trims, strips punctuation, and collapses whitespace' {
        InModuleScope Reshelf.Common {
            ConvertTo-ReshelfNormalizedText -Text "  ZZ Top's  Best!! " | Should -Be 'zz tops best'
        }
    }

    It 'treats different-case, different-punctuation input as equal' {
        InModuleScope Reshelf.Common {
            $a = ConvertTo-ReshelfNormalizedText -Text 'Talking Heads'
            $b = ConvertTo-ReshelfNormalizedText -Text '  talking   HEADS  '
            $a | Should -Be $b
        }
    }
}

Describe 'Get-ReshelfSha256Hex' {
    It 'produces a 64-character lowercase hex string' {
        Get-ReshelfSha256Hex -Text 'anything' | Should -Match '^[0-9a-f]{64}$'
    }

    It 'is deterministic for the same input' {
        (Get-ReshelfSha256Hex -Text 'D:\downloads\incoming') | Should -Be (Get-ReshelfSha256Hex -Text 'D:\downloads\incoming')
    }

    It 'produces different hashes for different input' {
        (Get-ReshelfSha256Hex -Text 'a') | Should -Not -Be (Get-ReshelfSha256Hex -Text 'b')
    }
}

Describe 'Get-ReshelfStableKey' {
    It 'produces a 16-character lowercase hex string' {
        $key = Get-ReshelfStableKey -Artist 'ZZ Top' -Album 'XXX' -Year 1999
        $key | Should -Match '^[0-9a-f]{16}$'
    }

    It 'is deterministic for the same normalized input' {
        $first = Get-ReshelfStableKey -Artist 'ZZ Top' -Album 'XXX' -Year 1999
        $second = Get-ReshelfStableKey -Artist 'ZZ Top' -Album 'XXX' -Year 1999
        $first | Should -Be $second
    }

    It 'normalizes case and whitespace before hashing' {
        $first = Get-ReshelfStableKey -Artist 'ZZ Top' -Album 'XXX' -Year 1999
        $second = Get-ReshelfStableKey -Artist '  zz   top ' -Album ' xxx ' -Year 1999
        $first | Should -Be $second
    }

    It 'produces different keys for different years' {
        $first = Get-ReshelfStableKey -Artist 'ZZ Top' -Album 'XXX' -Year 1999
        $second = Get-ReshelfStableKey -Artist 'ZZ Top' -Album 'XXX' -Year 2000
        $first | Should -Not -Be $second
    }

    It 'accepts a null year' {
        { Get-ReshelfStableKey -Artist 'ZZ Top' -Album 'XXX' -Year $null } | Should -Not -Throw
    }
}

Describe 'ConvertTo-ReshelfLongPath' {
    It 'leaves a short path unchanged' {
        ConvertTo-ReshelfLongPath -Path 'D:\music\ZZ Top\1999 XXX' | Should -Be 'D:\music\ZZ Top\1999 XXX'
    }

    It 'prefixes a near-limit local path with \\?\' {
        $longPath = 'D:\' + ('a' * 250)
        $result = ConvertTo-ReshelfLongPath -Path $longPath
        $result | Should -Be "\\?\$longPath"
    }

    It 'prefixes a near-limit UNC path with \\?\UNC\' {
        $longPath = '\\server\share\' + ('a' * 250)
        $result = ConvertTo-ReshelfLongPath -Path $longPath
        $result | Should -Be "\\?\UNC\server\share\$('a' * 250)"
    }

    It 'does not double-prefix an already-long-form path' {
        $alreadyPrefixed = '\\?\D:\' + ('a' * 250)
        ConvertTo-ReshelfLongPath -Path $alreadyPrefixed | Should -Be $alreadyPrefixed
    }
}

Describe 'ConvertTo-ReshelfCueTimestampSeconds' {
    It 'converts MM:SS:FF (CD-audio frames, 75/sec) to total seconds' {
        ConvertTo-ReshelfCueTimestampSeconds -CueTimestamp '09:26:73' | Should -Be 566.973
    }

    It 'converts a zero timestamp to zero seconds' {
        ConvertTo-ReshelfCueTimestampSeconds -CueTimestamp '00:00:00' | Should -Be 0
    }

    It 'does not misread MM:SS:FF as HH:MM:SS' {
        ConvertTo-ReshelfCueTimestampSeconds -CueTimestamp '03:12:45' | Should -Be 192.6
    }
}

Describe 'ConvertTo-SafeFileName' {
    It 'leaves an already-safe name unchanged' {
        $result = ConvertTo-SafeFileName -Name 'Poke Chop Sandwich'
        $result.SafeName | Should -Be 'Poke Chop Sandwich'
        $result.WasChanged | Should -Be $false
        $result.Substitutions | Should -BeNullOrEmpty
    }

    It 'replaces each Windows-invalid character with an underscore' {
        foreach ($char in @('<', '>', ':', '"', '/', '\', '|', '?', '*')) {
            $result = ConvertTo-SafeFileName -Name "Track${char}Name"
            $result.SafeName | Should -Be 'Track_Name'
            $result.WasChanged | Should -Be $true
            $result.Substitutions.Count | Should -BeGreaterThan 0
        }
    }

    It 'strips a trailing dot' {
        $result = ConvertTo-SafeFileName -Name 'Track Name.'
        $result.SafeName | Should -Be 'Track Name'
        $result.WasChanged | Should -Be $true
    }

    It 'strips a trailing space' {
        $result = ConvertTo-SafeFileName -Name 'Track Name '
        $result.SafeName | Should -Be 'Track Name'
        $result.WasChanged | Should -Be $true
    }

    It 'suffixes every reserved device name case-insensitively' {
        $reserved = @('CON', 'PRN', 'AUX', 'NUL') + (1..9 | ForEach-Object { "COM$_" }) + (1..9 | ForEach-Object { "LPT$_" })
        foreach ($name in $reserved + @('con', 'Nul', 'lpt3')) {
            $result = ConvertTo-SafeFileName -Name $name
            $result.SafeName | Should -Be "${name}_"
            $result.WasChanged | Should -Be $true
        }
    }

    It 'suffixes a reserved device name that has an extension, keeping the extension' {
        (ConvertTo-SafeFileName -Name 'CON.flac').SafeName | Should -Be 'CON_.flac'
        (ConvertTo-SafeFileName -Name 'nul.txt').SafeName | Should -Be 'nul_.txt'
        (ConvertTo-SafeFileName -Name 'COM1.tar.gz').SafeName | Should -Be 'COM1_.tar.gz'
        (ConvertTo-SafeFileName -Name 'CON.flac').Substitutions | Should -Be @("reserved device name 'CON' suffixed with '_'")
    }

    It 'does not treat a reserved name as reserved when it is only part of the name' {
        foreach ($name in @('CONcert', 'CONcert.flac', '01 CON.flac', 'COM10', '.CON')) {
            $result = ConvertTo-SafeFileName -Name $name
            $result.SafeName | Should -Be $name
            $result.WasChanged | Should -Be $false
        }
    }

    It 'records multiple substitutions for combined issues' {
        $result = ConvertTo-SafeFileName -Name 'Track: Name?.'
        $result.SafeName | Should -Be 'Track_ Name_'
        $result.Substitutions.Count | Should -BeGreaterThan 1
    }

    It 'handles an empty string without throwing' {
        { ConvertTo-SafeFileName -Name '' } | Should -Not -Throw
    }

    It 'prefixes substitution messages with the given context' {
        $result = ConvertTo-SafeFileName -Name 'A/B' -Context 'track file name'
        $result.Substitutions | Should -Be @("track file name: invalid character '/' replaced with '_'")
    }
}

Describe 'Test-ReshelfLooseCompanionFileName' {
    It 'returns true for a name starting with an ASCII letter' {
        Test-ReshelfLooseCompanionFileName -FileName 'Cover.jpg' | Should -Be $true
    }

    It 'returns true for a name starting with a non-ASCII (Cyrillic) letter' {
        Test-ReshelfLooseCompanionFileName -FileName 'Обложка.jpg' | Should -Be $true
    }

    It 'returns false for a name starting with a digit' {
        Test-ReshelfLooseCompanionFileName -FileName '01 back.jpg' | Should -Be $false
    }

    It 'returns false for a name starting with a symbol' {
        Test-ReshelfLooseCompanionFileName -FileName '(scan).png' | Should -Be $false
    }

    It 'returns false for an empty string' {
        Test-ReshelfLooseCompanionFileName -FileName '' | Should -Be $false
    }
}

Describe 'Get-ReshelfLooseCompanionFileName' {
    It 'leaves a name that already starts with a letter unchanged' {
        $result = Get-ReshelfLooseCompanionFileName -FileName 'folder.jpg' -Kind 'cover'
        $result.FileName | Should -Be 'folder.jpg'
        $result.WasPrefixed | Should -Be $false
    }

    It 'prefixes a digit-starting name with the kind word for each known kind' {
        $cases = @(
            @{ Kind = 'cover'; Expected = 'Cover' }
            @{ Kind = 'booklet'; Expected = 'Booklet' }
            @{ Kind = 'photo'; Expected = 'Photo' }
            @{ Kind = 'lyrics'; Expected = 'Lyrics' }
            @{ Kind = 'other'; Expected = 'Extra' }
        )
        foreach ($case in $cases) {
            $result = Get-ReshelfLooseCompanionFileName -FileName '01 back.jpg' -Kind $case.Kind
            $result.FileName | Should -Be "$($case.Expected) 01 back.jpg"
            $result.WasPrefixed | Should -Be $true
        }
    }

    It 'prefixes a symbol-starting name' {
        $result = Get-ReshelfLooseCompanionFileName -FileName '(scan).png' -Kind 'cover'
        $result.FileName | Should -Be 'Cover (scan).png'
        $result.WasPrefixed | Should -Be $true
    }

    It 'does not prefix a name starting with a non-ASCII letter' {
        $result = Get-ReshelfLooseCompanionFileName -FileName 'Обложка.jpg' -Kind 'cover'
        $result.FileName | Should -Be 'Обложка.jpg'
        $result.WasPrefixed | Should -Be $false
    }

    It 'sanitizes invalid filename characters before checking the letter rule' {
        $result = Get-ReshelfLooseCompanionFileName -FileName 'photo?.jpg' -Kind 'photo'
        $result.FileName | Should -Be 'photo_.jpg'
        $result.WasPrefixed | Should -Be $false
    }
}

Describe 'ConvertTo-ReshelfTruncatedSegment' {
    It 'leaves the segment unchanged when it already fits' {
        $result = ConvertTo-ReshelfTruncatedSegment -Prefix '2010 ' -Body 'A Short Album' -Suffix '' -MaxLength 250
        $result.Value | Should -Be '2010 A Short Album'
        $result.Truncated | Should -Be $false
    }

    It 'truncates only the body, keeping the prefix and suffix intact' {
        $longBody = 'A' * 100
        $result = ConvertTo-ReshelfTruncatedSegment -Prefix '01 ' -Body $longBody -Suffix '.flac' -MaxLength 30

        $result.Truncated | Should -Be $true
        $result.Value.Length | Should -Be 30
        $result.Value | Should -BeLike '01 *'
        $result.Value | Should -BeLike '*.flac'
    }

    It 'keeps at least one body character when the budget is smaller than prefix+suffix' {
        $result = ConvertTo-ReshelfTruncatedSegment -Prefix '01 ' -Body 'Some Title' -Suffix '.flac' -MaxLength 5

        $result.Truncated | Should -Be $true
        $result.Value | Should -BeLike '01 *.flac'
        { $result.Value } | Should -Not -Throw
    }

    It 'does not split a UTF-16 surrogate pair when the cut would land inside one' {
        $emoji = [char]::ConvertFromUtf32(0x1F600)
        $body = "Track $emoji Title"
        # Cuts exactly between the emoji's high and low surrogate.
        $cutIndex = $body.IndexOf($emoji[0]) + 1

        $result = ConvertTo-ReshelfTruncatedSegment -Prefix '' -Body $body -Suffix '' -MaxLength $cutIndex

        $result.Truncated | Should -Be $true
        $lastChar = $result.Value[$result.Value.Length - 1]
        [char]::IsHighSurrogate($lastChar) | Should -Be $false
    }
}

Describe 'Get-ReshelfFileSetHash' {
    BeforeEach {
        $script:hashTestDir = Join-Path $TestDrive ([Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:hashTestDir -Force | Out-Null
    }

    It 'is deterministic for the same file set' {
        $fileA = Join-Path $script:hashTestDir 'a.flac'
        $fileB = Join-Path $script:hashTestDir 'b.flac'
        Set-Content -LiteralPath $fileA -Value 'aaaa'
        Set-Content -LiteralPath $fileB -Value 'bb'

        $first = Get-ReshelfFileSetHash -FilePaths @($fileA, $fileB)
        $second = Get-ReshelfFileSetHash -FilePaths @($fileA, $fileB)
        $first | Should -Be $second
    }

    It 'is independent of input order' {
        $fileA = Join-Path $script:hashTestDir 'a.flac'
        $fileB = Join-Path $script:hashTestDir 'b.flac'
        Set-Content -LiteralPath $fileA -Value 'aaaa'
        Set-Content -LiteralPath $fileB -Value 'bb'

        $forward = Get-ReshelfFileSetHash -FilePaths @($fileA, $fileB)
        $reversed = Get-ReshelfFileSetHash -FilePaths @($fileB, $fileA)
        $forward | Should -Be $reversed
    }

    It 'is case-insensitive on file name' {
        $fileA = Join-Path $script:hashTestDir 'a.flac'
        Set-Content -LiteralPath $fileA -Value 'aaaa'

        $lower = Get-ReshelfFileSetHash -FilePaths @($fileA)
        $upper = Get-ReshelfFileSetHash -FilePaths @($fileA.ToUpperInvariant())
        $lower | Should -Be $upper
    }

    It 'produces a different hash when file size changes' {
        $fileA = Join-Path $script:hashTestDir 'a.flac'
        Set-Content -LiteralPath $fileA -Value 'aaaa'
        $before = Get-ReshelfFileSetHash -FilePaths @($fileA)

        Set-Content -LiteralPath $fileA -Value 'aaaaaaaa'
        $after = Get-ReshelfFileSetHash -FilePaths @($fileA)

        $before | Should -Not -Be $after
    }

    It 'is deterministic for an empty file list' {
        $first = Get-ReshelfFileSetHash -FilePaths @()
        $second = Get-ReshelfFileSetHash -FilePaths @()
        $first | Should -Be $second
    }
}

Describe 'Protect-ReshelfSecret / Unprotect-ReshelfSecret' {
    It 'round-trips plain text through DPAPI encryption' {
        $encrypted = Protect-ReshelfSecret -PlainText 'my-discogs-token'
        $encrypted | Should -Not -Be 'my-discogs-token'

        $decrypted = Unprotect-ReshelfSecret -EncryptedText $encrypted
        $decrypted | Should -Be 'my-discogs-token'
    }

    It 'produces an encrypted string that does not contain the original plain text' {
        $encrypted = Protect-ReshelfSecret -PlainText 'super-secret-value'
        $encrypted | Should -Not -BeLike '*super-secret-value*'
    }

    It 'throws for an empty string (ConvertTo-SecureString itself rejects empty plain text)' {
        # Not a Reshelf-specific limitation - documents real ConvertTo-SecureString -String behavior.
        # Callers that may have an empty/skipped secret (e.g. Reshelf.Settings.psm1's token prompt)
        # check for that before ever calling Protect-ReshelfSecret, rather than passing it through.
        { Protect-ReshelfSecret -PlainText '' } | Should -Throw
    }
}

Describe 'Import-ReshelfTagLibSharp' {
    AfterEach {
        InModuleScope Reshelf.Common {
            Set-ReshelfTagLibSharpContext -TagLibSharpPath $null -DataHome $null
        }
    }

    It 'falls back to the script-scoped DataHome (set by Set-ReshelfTagLibSharpContext) for auto-discovery' {
        InModuleScope Reshelf.Common {
            $dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
            $expectedPath = Join-Path $dataHome 'lib' 'TagLibSharp.dll'
            New-Item -ItemType Directory -Path (Split-Path $expectedPath) -Force | Out-Null
            New-Item -ItemType File -Path $expectedPath -Force | Out-Null

            Set-ReshelfTagLibSharpContext -DataHome $dataHome
            Mock Add-Type { }

            Import-ReshelfTagLibSharp

            Should -Invoke Add-Type -ParameterFilter { $Path -eq $expectedPath }
        }
    }

    It 'throws a clear error naming the resolved path when the DLL is missing there' {
        InModuleScope Reshelf.Common {
            $dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
            Set-ReshelfTagLibSharpContext -DataHome $dataHome

            { Import-ReshelfTagLibSharp } | Should -Throw '*TagLibSharp.dll not found*'
        }
    }
}

Describe 'Test-ReshelfIsAudioExtension' {
    It 'returns true for a known audio extension regardless of case' {
        Test-ReshelfIsAudioExtension -Extension '.FLAC' | Should -Be $true
    }

    It 'returns true for .mpc (Musepack)' {
        Test-ReshelfIsAudioExtension -Extension '.mpc' | Should -Be $true
    }

    It 'returns false for a non-audio extension' {
        Test-ReshelfIsAudioExtension -Extension '.txt' | Should -Be $false
    }

    It 'returns false, not a binding error, for an empty extension (a file with no extension)' {
        { Test-ReshelfIsAudioExtension -Extension '' } | Should -Not -Throw
        Test-ReshelfIsAudioExtension -Extension '' | Should -Be $false
    }
}

Describe 'Test-ReshelfIsLosslessFormat' {
    It 'returns true for .flac' {
        Test-ReshelfIsLosslessFormat -Extension '.flac' | Should -Be $true
    }

    It 'returns false for .mpc (Musepack is lossy)' {
        Test-ReshelfIsLosslessFormat -Extension '.mpc' | Should -Be $false
    }

    It 'returns false, not a binding error, for an empty extension' {
        { Test-ReshelfIsLosslessFormat -Extension '' } | Should -Not -Throw
        Test-ReshelfIsLosslessFormat -Extension '' | Should -Be $false
    }
}

Describe 'Get-ReshelfAudioFilesInFolder' {
    It 'returns only audio files, ignoring extensions like .txt/.m3u/.cue, without recursing by default' {
        $root = Join-Path $TestDrive 'flat'
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $root '01 Track.flac') -Value 'x' -NoNewline
        Set-Content -LiteralPath (Join-Path $root '02 Track.mp3') -Value 'x' -NoNewline
        Set-Content -LiteralPath (Join-Path $root 'readme.txt') -Value 'x' -NoNewline
        Set-Content -LiteralPath (Join-Path $root 'playlist.m3u') -Value 'x' -NoNewline
        New-Item -ItemType Directory -Path (Join-Path $root 'CD 1') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $root 'CD 1' '01 Nested.flac') -Value 'x' -NoNewline

        $result = @(Get-ReshelfAudioFilesInFolder -Path $root)

        $result.Count | Should -Be 2
        ($result.Name | Sort-Object) | Should -Be @('01 Track.flac', '02 Track.mp3')
    }

    It 'recurses into subfolders when -Recurse is passed' {
        $root = Join-Path $TestDrive 'nested'
        New-Item -ItemType Directory -Path (Join-Path $root 'CD 1') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $root 'CD 2') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $root 'CD 1' '01 Track.flac') -Value 'x' -NoNewline
        Set-Content -LiteralPath (Join-Path $root 'CD 2' '01 Track.flac') -Value 'x' -NoNewline

        $result = @(Get-ReshelfAudioFilesInFolder -Path $root -Recurse)

        $result.Count | Should -Be 2
    }

    It 'returns an empty array, not an error, for a folder with no audio files' {
        $root = Join-Path $TestDrive 'empty'
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $root 'notes.txt') -Value 'x' -NoNewline

        $result = @(Get-ReshelfAudioFilesInFolder -Path $root)

        $result.Count | Should -Be 0
    }
}

Describe 'Get-ReshelfRelativePath' {
    It 'returns the path under the source root with forward slashes, regardless of backslash depth' {
        $root = 'C:\Music\Source'
        $path = 'C:\Music\Source\Some Band\2010 Album\Scans\front.jpg'

        Get-ReshelfRelativePath -SourceRoot $root -Path $path | Should -Be 'Some Band/2010 Album/Scans/front.jpg'
    }

    It 'matches the root case-insensitively' {
        $root = 'c:\music\source'
        $path = 'C:\Music\Source\Some Band\front.jpg'

        Get-ReshelfRelativePath -SourceRoot $root -Path $path | Should -Be 'Some Band/front.jpg'
    }

    It 'tolerates a trailing separator on the root' {
        Get-ReshelfRelativePath -SourceRoot 'C:\Music\Source\' -Path 'C:\Music\Source\Album\file.jpg' | Should -Be 'Album/file.jpg'
    }

    It 'returns the path unchanged when it does not start with the given root' {
        $path = 'D:\Elsewhere\file.jpg'
        Get-ReshelfRelativePath -SourceRoot 'C:\Music\Source' -Path $path | Should -Be $path
    }

    It 'returns an empty string for a path identical to the root' {
        Get-ReshelfRelativePath -SourceRoot 'C:\Music\Source' -Path 'C:\Music\Source' | Should -Be ''
    }
}

Describe 'ConvertTo-ReshelfTitleCase' {
    It 'capitalizes the first letter of every whitespace-separated word' {
        ConvertTo-ReshelfTitleCase -Text 'aoki takamasa' | Should -Be 'Aoki Takamasa'
    }

    It 'capitalizes an all-lowercase single word (real "edbl" case)' {
        ConvertTo-ReshelfTitleCase -Text 'edbl' | Should -Be 'Edbl'
    }

    It 'leaves interior/existing capitalization untouched, e.g. an already-capitalized abbreviation' {
        ConvertTo-ReshelfTitleCase -Text 'DJ Shadow' | Should -Be 'DJ Shadow'
    }

    It 'returns an empty string unchanged' {
        ConvertTo-ReshelfTitleCase -Text '' | Should -Be ''
    }
}

Describe 'Remove-ReshelfInvisibleCharacters' {
    It 'strips a zero-width space (real Discogs "B-Sides" case)' {
        $withZwsp = 'B' + [char]0x200B + '-' + [char]0x200B + 'Sides'
        Remove-ReshelfInvisibleCharacters -Text $withZwsp | Should -Be 'B-Sides'
    }

    It 'strips a byte-order-mark character embedded mid-string' {
        $withBom = 'Some' + [char]0xFEFF + 'Title'
        Remove-ReshelfInvisibleCharacters -Text $withBom | Should -Be 'SomeTitle'
    }

    It 'leaves ordinary text unchanged' {
        Remove-ReshelfInvisibleCharacters -Text 'Ordinary Title' | Should -Be 'Ordinary Title'
    }
}
