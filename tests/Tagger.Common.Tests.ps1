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
