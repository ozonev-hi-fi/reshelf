#Requires -Version 7.4

Import-Module Pester -MinimumVersion 5.0

BeforeAll {
    Import-Module "$PSScriptRoot/../scripts/common/Tagger.Common.psm1" -Force
}

Describe 'Resolve-TaggerDataHome' {
    BeforeEach {
        $script:originalTaggerHome = $env:TAGGER_HOME
        $script:originalLocalAppData = $env:LOCALAPPDATA
    }

    AfterEach {
        if ($null -eq $script:originalTaggerHome) {
            Remove-Item Env:\TAGGER_HOME -ErrorAction SilentlyContinue
        }
        else {
            $env:TAGGER_HOME = $script:originalTaggerHome
        }
        $env:LOCALAPPDATA = $script:originalLocalAppData
    }

    It 'creates and returns a writable directory' {
        $testHome = Join-Path $TestDrive 'TaggerHomeTest'
        $env:TAGGER_HOME = $testHome

        $result = Resolve-TaggerDataHome

        $result | Should -Exist
        { New-Item -ItemType File -Path (Join-Path $result 'probe.tmp') -Force } | Should -Not -Throw
    }

    It 'throws when the data home path exists but is a file, not a directory' {
        $testHome = Join-Path $TestDrive 'TaggerHomeAsFile.tmp'
        New-Item -ItemType File -Path $testHome -Force | Out-Null
        $env:TAGGER_HOME = $testHome

        { Resolve-TaggerDataHome } | Should -Throw
    }

    It 'throws when neither TAGGER_HOME nor LOCALAPPDATA is set' {
        Remove-Item Env:\TAGGER_HOME -ErrorAction SilentlyContinue
        Remove-Item Env:\LOCALAPPDATA -ErrorAction SilentlyContinue

        { Resolve-TaggerDataHome } | Should -Throw
    }
}

Describe 'ConvertTo-TaggerNormalizedText (private)' {
    It 'lowercases, trims, strips punctuation, and collapses whitespace' {
        InModuleScope Tagger.Common {
            ConvertTo-TaggerNormalizedText -Text "  ZZ Top's  Best!! " | Should -Be 'zz tops best'
        }
    }

    It 'treats different-case, different-punctuation input as equal' {
        InModuleScope Tagger.Common {
            $a = ConvertTo-TaggerNormalizedText -Text 'Talking Heads'
            $b = ConvertTo-TaggerNormalizedText -Text '  talking   HEADS  '
            $a | Should -Be $b
        }
    }
}

Describe 'Get-TaggerSha256Hex' {
    It 'produces a 64-character lowercase hex string' {
        Get-TaggerSha256Hex -Text 'anything' | Should -Match '^[0-9a-f]{64}$'
    }

    It 'is deterministic for the same input' {
        (Get-TaggerSha256Hex -Text 'D:\downloads\incoming') | Should -Be (Get-TaggerSha256Hex -Text 'D:\downloads\incoming')
    }

    It 'produces different hashes for different input' {
        (Get-TaggerSha256Hex -Text 'a') | Should -Not -Be (Get-TaggerSha256Hex -Text 'b')
    }
}

Describe 'Get-TaggerStableKey' {
    It 'produces a 16-character lowercase hex string' {
        $key = Get-TaggerStableKey -Artist 'ZZ Top' -Album 'XXX' -Year 1999
        $key | Should -Match '^[0-9a-f]{16}$'
    }

    It 'is deterministic for the same normalized input' {
        $first = Get-TaggerStableKey -Artist 'ZZ Top' -Album 'XXX' -Year 1999
        $second = Get-TaggerStableKey -Artist 'ZZ Top' -Album 'XXX' -Year 1999
        $first | Should -Be $second
    }

    It 'normalizes case and whitespace before hashing' {
        $first = Get-TaggerStableKey -Artist 'ZZ Top' -Album 'XXX' -Year 1999
        $second = Get-TaggerStableKey -Artist '  zz   top ' -Album ' xxx ' -Year 1999
        $first | Should -Be $second
    }

    It 'produces different keys for different years' {
        $first = Get-TaggerStableKey -Artist 'ZZ Top' -Album 'XXX' -Year 1999
        $second = Get-TaggerStableKey -Artist 'ZZ Top' -Album 'XXX' -Year 2000
        $first | Should -Not -Be $second
    }

    It 'accepts a null year' {
        { Get-TaggerStableKey -Artist 'ZZ Top' -Album 'XXX' -Year $null } | Should -Not -Throw
    }
}

Describe 'ConvertTo-TaggerLongPath' {
    It 'leaves a short path unchanged' {
        ConvertTo-TaggerLongPath -Path 'D:\music\ZZ Top\1999 XXX' | Should -Be 'D:\music\ZZ Top\1999 XXX'
    }

    It 'prefixes a near-limit local path with \\?\' {
        $longPath = 'D:\' + ('a' * 250)
        $result = ConvertTo-TaggerLongPath -Path $longPath
        $result | Should -Be "\\?\$longPath"
    }

    It 'prefixes a near-limit UNC path with \\?\UNC\' {
        $longPath = '\\server\share\' + ('a' * 250)
        $result = ConvertTo-TaggerLongPath -Path $longPath
        $result | Should -Be "\\?\UNC\server\share\$('a' * 250)"
    }

    It 'does not double-prefix an already-long-form path' {
        $alreadyPrefixed = '\\?\D:\' + ('a' * 250)
        ConvertTo-TaggerLongPath -Path $alreadyPrefixed | Should -Be $alreadyPrefixed
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

    It 'suffixes a reserved device name case-insensitively' {
        foreach ($name in @('CON', 'con', 'PRN', 'AUX', 'NUL', 'COM1', 'LPT9')) {
            $result = ConvertTo-SafeFileName -Name $name
            $result.SafeName | Should -Be "${name}_"
            $result.WasChanged | Should -Be $true
        }
    }

    It 'does not treat a reserved name as reserved when it is only part of the name' {
        $result = ConvertTo-SafeFileName -Name 'CONcert'
        $result.SafeName | Should -Be 'CONcert'
        $result.WasChanged | Should -Be $false
    }

    It 'records multiple substitutions for combined issues' {
        $result = ConvertTo-SafeFileName -Name 'Track: Name?.'
        $result.SafeName | Should -Be 'Track_ Name_'
        $result.Substitutions.Count | Should -BeGreaterThan 1
    }

    It 'handles an empty string without throwing' {
        { ConvertTo-SafeFileName -Name '' } | Should -Not -Throw
    }
}

Describe 'Get-TaggerFileSetHash' {
    BeforeEach {
        $script:hashTestDir = Join-Path $TestDrive ([Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:hashTestDir -Force | Out-Null
    }

    It 'is deterministic for the same file set' {
        $fileA = Join-Path $script:hashTestDir 'a.flac'
        $fileB = Join-Path $script:hashTestDir 'b.flac'
        Set-Content -LiteralPath $fileA -Value 'aaaa'
        Set-Content -LiteralPath $fileB -Value 'bb'

        $first = Get-TaggerFileSetHash -FilePaths @($fileA, $fileB)
        $second = Get-TaggerFileSetHash -FilePaths @($fileA, $fileB)
        $first | Should -Be $second
    }

    It 'is independent of input order' {
        $fileA = Join-Path $script:hashTestDir 'a.flac'
        $fileB = Join-Path $script:hashTestDir 'b.flac'
        Set-Content -LiteralPath $fileA -Value 'aaaa'
        Set-Content -LiteralPath $fileB -Value 'bb'

        $forward = Get-TaggerFileSetHash -FilePaths @($fileA, $fileB)
        $reversed = Get-TaggerFileSetHash -FilePaths @($fileB, $fileA)
        $forward | Should -Be $reversed
    }

    It 'is case-insensitive on file name' {
        $fileA = Join-Path $script:hashTestDir 'a.flac'
        Set-Content -LiteralPath $fileA -Value 'aaaa'

        $lower = Get-TaggerFileSetHash -FilePaths @($fileA)
        $upper = Get-TaggerFileSetHash -FilePaths @($fileA.ToUpperInvariant())
        $lower | Should -Be $upper
    }

    It 'produces a different hash when file size changes' {
        $fileA = Join-Path $script:hashTestDir 'a.flac'
        Set-Content -LiteralPath $fileA -Value 'aaaa'
        $before = Get-TaggerFileSetHash -FilePaths @($fileA)

        Set-Content -LiteralPath $fileA -Value 'aaaaaaaa'
        $after = Get-TaggerFileSetHash -FilePaths @($fileA)

        $before | Should -Not -Be $after
    }

    It 'is deterministic for an empty file list' {
        $first = Get-TaggerFileSetHash -FilePaths @()
        $second = Get-TaggerFileSetHash -FilePaths @()
        $first | Should -Be $second
    }
}

Describe 'Protect-TaggerSecret / Unprotect-TaggerSecret' {
    It 'round-trips plain text through DPAPI encryption' {
        $encrypted = Protect-TaggerSecret -PlainText 'my-discogs-token'
        $encrypted | Should -Not -Be 'my-discogs-token'

        $decrypted = Unprotect-TaggerSecret -EncryptedText $encrypted
        $decrypted | Should -Be 'my-discogs-token'
    }

    It 'produces an encrypted string that does not contain the original plain text' {
        $encrypted = Protect-TaggerSecret -PlainText 'super-secret-value'
        $encrypted | Should -Not -BeLike '*super-secret-value*'
    }

    It 'throws for an empty string (ConvertTo-SecureString itself rejects empty plain text)' {
        # Not a Tagger-specific limitation - documents real ConvertTo-SecureString -String behavior.
        # Callers that may have an empty/skipped secret (e.g. Tagger.Settings.psm1's token prompt)
        # check for that before ever calling Protect-TaggerSecret, rather than passing it through.
        { Protect-TaggerSecret -PlainText '' } | Should -Throw
    }
}

Describe 'Import-TaggerTagLibSharp' {
    AfterEach {
        InModuleScope Tagger.Common {
            Set-TaggerTagLibSharpContext -TagLibSharpPath $null -DataHome $null
        }
    }

    It 'falls back to the script-scoped DataHome (set by Set-TaggerTagLibSharpContext) for auto-discovery' {
        InModuleScope Tagger.Common {
            $dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
            $expectedPath = Join-Path $dataHome 'lib' 'TagLibSharp.dll'
            New-Item -ItemType Directory -Path (Split-Path $expectedPath) -Force | Out-Null
            New-Item -ItemType File -Path $expectedPath -Force | Out-Null

            Set-TaggerTagLibSharpContext -DataHome $dataHome
            Mock Add-Type { }

            Import-TaggerTagLibSharp

            Should -Invoke Add-Type -ParameterFilter { $Path -eq $expectedPath }
        }
    }

    It 'throws a clear error naming the resolved path when the DLL is missing there' {
        InModuleScope Tagger.Common {
            $dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
            Set-TaggerTagLibSharpContext -DataHome $dataHome

            { Import-TaggerTagLibSharp } | Should -Throw '*TagLibSharp.dll not found*'
        }
    }
}
