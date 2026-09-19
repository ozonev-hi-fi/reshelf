#Requires -Version 7.4

Import-Module Pester -MinimumVersion 5.0

BeforeAll {
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

    It 'recognize emits a not-implemented warning and exits 1' {
        $result = Invoke-Tagger recognize

        $result.ExitCode | Should -Be 1
        ($result.Output -join "`n") | Should -BeLike '*not implemented*'
    }

    It 'propose, apply, and lossy also emit a not-implemented warning and exit 1' {
        foreach ($command in @('propose', 'apply', 'lossy')) {
            $result = Invoke-Tagger $command
            $result.ExitCode | Should -Be 1
        }
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
