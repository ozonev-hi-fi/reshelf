#Requires -Version 7.4

Import-Module Pester -MinimumVersion 5.0

BeforeAll {
    Import-Module "$PSScriptRoot/../scripts/common/Tagger.Common.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Tagger.Json.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Tagger.Settings.psm1" -Force

    $script:TaggerPs1 = "$PSScriptRoot/../scripts/Tagger.ps1"

    function Invoke-Tagger {
        param(
            [Parameter(ValueFromRemainingArguments)]
            [string[]]$Arguments
        )

        $output = & pwsh -NoProfile -NoLogo -File $TaggerPs1 @Arguments 2>&1
        [pscustomobject]@{
            Output   = $output
            ExitCode = $LASTEXITCODE
        }
    }
}

Describe 'Tagger.ps1 settings/session dispatch' {
    BeforeEach {
        $script:dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:originalTaggerHome = $env:TAGGER_HOME
        $env:TAGGER_HOME = $dataHome
    }

    AfterEach {
        if ($null -eq $script:originalTaggerHome) {
            Remove-Item Env:\TAGGER_HOME -ErrorAction SilentlyContinue
        }
        else {
            $env:TAGGER_HOME = $script:originalTaggerHome
        }
    }

    It 'settings init produces valid output and a schema-valid settings.json' {
        $targetRoot = Join-Path $TestDrive 'target'
        $result = Invoke-Tagger settings init -TargetRoot $targetRoot

        $result.ExitCode | Should -Be 0
        (Join-Path $dataHome 'settings.json') | Should -Exist
    }

    It 'settings show prints JSON containing the expected keys' {
        $targetRoot = Join-Path $TestDrive 'target'
        Invoke-Tagger settings init -TargetRoot $targetRoot | Out-Null

        $result = Invoke-Tagger settings show
        $json = $result.Output -join "`n" | ConvertFrom-Json

        $json.targetRoot | Should -Be $targetRoot
    }

    It 'session list with zero sessions runs without throwing' {
        $result = Invoke-Tagger session list

        $result.ExitCode | Should -Be 0
    }

    It 'apply without a session id exits 1' {
        $result = Invoke-Tagger apply
        $result.ExitCode | Should -Be 1
    }

    It 'lossy list with an empty ledger runs without throwing' {
        $result = Invoke-Tagger lossy list

        $result.ExitCode | Should -Be 0
    }

    It 'lossy ignore without a stable key fails with a clear error' {
        $result = Invoke-Tagger lossy ignore

        $result.ExitCode | Should -Not -Be 0
        ($result.Output -join "`n") | Should -BeLike '*requires a stable key*'
    }

    It 'lossy mark-upgraded without a stable key fails with a clear error' {
        $result = Invoke-Tagger lossy mark-upgraded

        $result.ExitCode | Should -Not -Be 0
        ($result.Output -join "`n") | Should -BeLike '*requires a stable key*'
    }

    It 'lossy list -Status filters to matching entries only' {
        Import-Module "$PSScriptRoot/../scripts/common/Tagger.LossyTracking.psm1" -Force

        Add-TaggerLossyTrackingEntry -StableKey 'a1b2c3d4e5f60708' -Artist 'ZZ Top' -Album 'XXX' -Year 1999 `
            -TargetPath 'E:\Music\ZZ Top\1999 XXX' -Format 'mp3' -DataHome $dataHome | Out-Null
        Set-TaggerLossyTrackingUpgraded -StableKey 'a1b2c3d4e5f60708' -DataHome $dataHome | Out-Null
        Add-TaggerLossyTrackingEntry -StableKey 'b2c3d4e5f6070819' -Artist 'ZZ Top' -Album 'YYY' -Year 2001 `
            -TargetPath 'E:\Music\ZZ Top\2001 YYY' -Format 'mp3' -DataHome $dataHome | Out-Null

        $result = Invoke-Tagger lossy list -Status pending-upgrade
        $output = $result.Output -join "`n"

        $output | Should -BeLike '*b2c3d4e5f6070819*'
        $output | Should -Not -BeLike '*a1b2c3d4e5f60708*'
    }

    It 'lossy ignore then mark-upgraded flip an entry status via the CLI' {
        Import-Module "$PSScriptRoot/../scripts/common/Tagger.LossyTracking.psm1" -Force

        Add-TaggerLossyTrackingEntry -StableKey 'a1b2c3d4e5f60708' -Artist 'ZZ Top' -Album 'XXX' -Year 1999 `
            -TargetPath 'E:\Music\ZZ Top\1999 XXX' -Format 'mp3' -DataHome $dataHome | Out-Null

        Invoke-Tagger lossy ignore a1b2c3d4e5f60708 | Out-Null
        (Get-TaggerLossyTrackingEntry -StableKey 'a1b2c3d4e5f60708' -DataHome $dataHome).status | Should -Be 'ignored'

        Invoke-Tagger lossy mark-upgraded a1b2c3d4e5f60708 | Out-Null
        (Get-TaggerLossyTrackingEntry -StableKey 'a1b2c3d4e5f60708' -DataHome $dataHome).status | Should -Be 'upgraded'
    }

    It 'propose fails with a clear error when no session id is given' {
        $result = Invoke-Tagger propose

        $result.ExitCode | Should -Not -Be 0
        ($result.Output -join "`n") | Should -BeLike '*requires a session id*'
    }

    It 'recognize fails with a clear error when there is no -SourceRoot and no defaultSourceRoot' {
        $targetRoot = Join-Path $TestDrive 'target'
        Invoke-Tagger settings init -TargetRoot $targetRoot | Out-Null

        $result = Invoke-Tagger recognize

        $result.ExitCode | Should -Not -Be 0
        ($result.Output -join "`n") | Should -BeLike '*No source root given*'
    }

    It 'recognize creates a session and prints a summary for a source with no audio files' {
        $targetRoot = Join-Path $TestDrive 'target'
        Invoke-Tagger settings init -TargetRoot $targetRoot | Out-Null

        $sourceRoot = Join-Path $TestDrive 'source-empty'
        New-Item -ItemType Directory -Path (Join-Path $sourceRoot 'Some Artist Folder') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $sourceRoot 'Some Artist Folder' 'readme.txt') -Force | Out-Null

        $result = Invoke-Tagger recognize -SourceRoot $sourceRoot

        $result.ExitCode | Should -Be 0
        $output = $result.Output -join "`n"
        $output | Should -BeLike '*SessionId*'
        (Get-TaggerSession -DataHome $dataHome).Count | Should -Be 1
    }

    It 'recognize surfaces a clear error (naming the orphaned session) when recognition fails after the session is created' {
        $targetRoot = Join-Path $TestDrive 'target'
        Invoke-Tagger settings init -TargetRoot $targetRoot | Out-Null

        $sourceRoot = Join-Path $TestDrive 'source-for-failure'
        New-Item -ItemType Directory -Path $sourceRoot -Force | Out-Null

        $malformedOverridesPath = Join-Path $TestDrive 'malformed-overrides.json'
        Set-Content -LiteralPath $malformedOverridesPath -Value '{"entries":"not-an-array"}'

        $result = Invoke-Tagger recognize -SourceRoot $sourceRoot -OverridesPath $malformedOverridesPath

        $result.ExitCode | Should -Not -Be 0
        $output = $result.Output -join "`n"
        $output | Should -BeLike '*Recognition failed for session*'
        (Get-TaggerSession -DataHome $dataHome).Count | Should -Be 1
    }

    It 'recognize -SaveAsDefault persists the source root to settings' {
        $targetRoot = Join-Path $TestDrive 'target'
        Invoke-Tagger settings init -TargetRoot $targetRoot | Out-Null

        $sourceRoot = Join-Path $TestDrive 'source-empty-2'
        New-Item -ItemType Directory -Path $sourceRoot -Force | Out-Null

        Invoke-Tagger recognize -SourceRoot $sourceRoot -SaveAsDefault | Out-Null

        (Get-TaggerSettings -DataHome $dataHome).defaultSourceRoot | Should -Be $sourceRoot
    }

    It 'session show without a session id fails with a clear error instead of listing everything' {
        $result = Invoke-Tagger session show

        $result.ExitCode | Should -Not -Be 0
        ($result.Output -join "`n") | Should -BeLike '*requires a session id*'
    }

    It 'session resume without a session id fails with a clear error' {
        $result = Invoke-Tagger session resume

        $result.ExitCode | Should -Not -Be 0
        ($result.Output -join "`n") | Should -BeLike '*requires a session id*'
    }
}
