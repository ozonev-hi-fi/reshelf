#Requires -Version 7.0

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
