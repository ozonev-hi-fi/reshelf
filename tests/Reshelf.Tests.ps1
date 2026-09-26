#Requires -Version 7.4

Import-Module Pester -MinimumVersion 5.0

BeforeAll {
    Import-Module "$PSScriptRoot/../scripts/common/Reshelf.Common.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Reshelf.Json.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Reshelf.Settings.psm1" -Force

    $script:ReshelfPs1 = "$PSScriptRoot/../scripts/Reshelf.ps1"

    function Invoke-Reshelf {
        param(
            [Parameter(ValueFromRemainingArguments)]
            [string[]]$Arguments
        )

        $output = & pwsh -NoProfile -NoLogo -File $ReshelfPs1 @Arguments 2>&1
        [pscustomobject]@{
            Output   = $output
            ExitCode = $LASTEXITCODE
        }
    }
}

Describe 'Reshelf.ps1 settings/session dispatch' {
    BeforeEach {
        $script:dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:originalReshelfHome = $env:RESHELF_HOME
        $env:RESHELF_HOME = $dataHome
    }

    AfterEach {
        if ($null -eq $script:originalReshelfHome) {
            Remove-Item Env:\RESHELF_HOME -ErrorAction SilentlyContinue
        }
        else {
            $env:RESHELF_HOME = $script:originalReshelfHome
        }
    }

    It 'settings init produces valid output and a schema-valid settings.json' {
        $targetRoot = Join-Path $TestDrive 'target'
        $result = Invoke-Reshelf settings init -TargetRoot $targetRoot

        $result.ExitCode | Should -Be 0
        (Join-Path $dataHome 'settings.json') | Should -Exist
    }

    It 'settings show prints JSON containing the expected keys' {
        $targetRoot = Join-Path $TestDrive 'target'
        Invoke-Reshelf settings init -TargetRoot $targetRoot | Out-Null

        $result = Invoke-Reshelf settings show
        $json = $result.Output -join "`n" | ConvertFrom-Json

        $json.targetRoot | Should -Be $targetRoot
    }

    It 'session list with zero sessions runs without throwing' {
        $result = Invoke-Reshelf session list

        $result.ExitCode | Should -Be 0
    }

    It 'apply without a session id exits 1' {
        $result = Invoke-Reshelf apply
        $result.ExitCode | Should -Be 1
    }

    It 'lossy list with an empty ledger runs without throwing' {
        $result = Invoke-Reshelf lossy list

        $result.ExitCode | Should -Be 0
    }

    It 'lossy ignore without a stable key fails with a clear error' {
        $result = Invoke-Reshelf lossy ignore

        $result.ExitCode | Should -Not -Be 0
        ($result.Output -join "`n") | Should -BeLike '*requires a stable key*'
    }

    It 'lossy mark-upgraded without a stable key fails with a clear error' {
        $result = Invoke-Reshelf lossy mark-upgraded

        $result.ExitCode | Should -Not -Be 0
        ($result.Output -join "`n") | Should -BeLike '*requires a stable key*'
    }

    It 'lossy list -Status filters to matching entries only' {
        Import-Module "$PSScriptRoot/../scripts/common/Reshelf.LossyTracking.psm1" -Force

        Add-ReshelfLossyTrackingEntry -StableKey 'a1b2c3d4e5f60708' -Artist 'ZZ Top' -Album 'XXX' -Year 1999 `
            -TargetPath 'E:\Music\ZZ Top\1999 XXX' -Format 'mp3' -DataHome $dataHome | Out-Null
        Set-ReshelfLossyTrackingUpgraded -StableKey 'a1b2c3d4e5f60708' -DataHome $dataHome | Out-Null
        Add-ReshelfLossyTrackingEntry -StableKey 'b2c3d4e5f6070819' -Artist 'ZZ Top' -Album 'YYY' -Year 2001 `
            -TargetPath 'E:\Music\ZZ Top\2001 YYY' -Format 'mp3' -DataHome $dataHome | Out-Null

        $result = Invoke-Reshelf lossy list -Status pending-upgrade
        $output = $result.Output -join "`n"

        $output | Should -BeLike '*b2c3d4e5f6070819*'
        $output | Should -Not -BeLike '*a1b2c3d4e5f60708*'
    }

    It 'lossy ignore then mark-upgraded flip an entry status via the CLI' {
        Import-Module "$PSScriptRoot/../scripts/common/Reshelf.LossyTracking.psm1" -Force

        Add-ReshelfLossyTrackingEntry -StableKey 'a1b2c3d4e5f60708' -Artist 'ZZ Top' -Album 'XXX' -Year 1999 `
            -TargetPath 'E:\Music\ZZ Top\1999 XXX' -Format 'mp3' -DataHome $dataHome | Out-Null

        Invoke-Reshelf lossy ignore a1b2c3d4e5f60708 | Out-Null
        (Get-ReshelfLossyTrackingEntry -StableKey 'a1b2c3d4e5f60708' -DataHome $dataHome).status | Should -Be 'ignored'

        Invoke-Reshelf lossy mark-upgraded a1b2c3d4e5f60708 | Out-Null
        (Get-ReshelfLossyTrackingEntry -StableKey 'a1b2c3d4e5f60708' -DataHome $dataHome).status | Should -Be 'upgraded'
    }

    It 'propose fails with a clear error when no session id is given' {
        $result = Invoke-Reshelf propose

        $result.ExitCode | Should -Not -Be 0
        ($result.Output -join "`n") | Should -BeLike '*requires a session id*'
    }

    It 'recognize fails with a clear error when there is no -SourceRoot and no defaultSourceRoot' {
        $targetRoot = Join-Path $TestDrive 'target'
        Invoke-Reshelf settings init -TargetRoot $targetRoot | Out-Null

        $result = Invoke-Reshelf recognize

        $result.ExitCode | Should -Not -Be 0
        ($result.Output -join "`n") | Should -BeLike '*No source root given*'
    }

    It 'recognize creates a session and prints a summary for a source with no audio files' {
        $targetRoot = Join-Path $TestDrive 'target'
        Invoke-Reshelf settings init -TargetRoot $targetRoot | Out-Null

        $sourceRoot = Join-Path $TestDrive 'source-empty'
        New-Item -ItemType Directory -Path (Join-Path $sourceRoot 'Some Artist Folder') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $sourceRoot 'Some Artist Folder' 'readme.txt') -Force | Out-Null

        $result = Invoke-Reshelf recognize -SourceRoot $sourceRoot

        $result.ExitCode | Should -Be 0
        $output = $result.Output -join "`n"
        $output | Should -BeLike '*SessionId*'
        (Get-ReshelfSession -DataHome $dataHome).Count | Should -Be 1
    }

    It 'recognize surfaces a clear error (naming the orphaned session) when recognition fails after the session is created' {
        $targetRoot = Join-Path $TestDrive 'target'
        Invoke-Reshelf settings init -TargetRoot $targetRoot | Out-Null

        $sourceRoot = Join-Path $TestDrive 'source-for-failure'
        New-Item -ItemType Directory -Path $sourceRoot -Force | Out-Null

        $malformedOverridesPath = Join-Path $TestDrive 'malformed-overrides.json'
        Set-Content -LiteralPath $malformedOverridesPath -Value '{"entries":"not-an-array"}'

        $result = Invoke-Reshelf recognize -SourceRoot $sourceRoot -OverridesPath $malformedOverridesPath

        $result.ExitCode | Should -Not -Be 0
        $output = $result.Output -join "`n"
        $output | Should -BeLike '*Recognition failed for session*'
        (Get-ReshelfSession -DataHome $dataHome).Count | Should -Be 1
    }

    It 'recognize -SaveAsDefault persists the source root to settings' {
        $targetRoot = Join-Path $TestDrive 'target'
        Invoke-Reshelf settings init -TargetRoot $targetRoot | Out-Null

        $sourceRoot = Join-Path $TestDrive 'source-empty-2'
        New-Item -ItemType Directory -Path $sourceRoot -Force | Out-Null

        Invoke-Reshelf recognize -SourceRoot $sourceRoot -SaveAsDefault | Out-Null

        (Get-ReshelfSettings -DataHome $dataHome).defaultSourceRoot | Should -Be $sourceRoot
    }

    It 'recognize -SourceRoot without -SaveAsDefault leaves defaultSourceRoot unchanged' {
        $targetRoot = Join-Path $TestDrive 'target'
        $originalDefaultSourceRoot = Join-Path $TestDrive 'source-original-default'
        New-Item -ItemType Directory -Path $originalDefaultSourceRoot -Force | Out-Null
        Invoke-Reshelf settings init -TargetRoot $targetRoot -DefaultSourceRoot $originalDefaultSourceRoot | Out-Null

        $otherSourceRoot = Join-Path $TestDrive 'source-other'
        New-Item -ItemType Directory -Path $otherSourceRoot -Force | Out-Null

        Invoke-Reshelf recognize -SourceRoot $otherSourceRoot | Out-Null

        (Get-ReshelfSettings -DataHome $dataHome).defaultSourceRoot | Should -Be $originalDefaultSourceRoot
    }

    It 'session show without a session id fails with a clear error instead of listing everything' {
        $result = Invoke-Reshelf session show

        $result.ExitCode | Should -Not -Be 0
        ($result.Output -join "`n") | Should -BeLike '*requires a session id*'
    }

    It 'session resume without a session id fails with a clear error' {
        $result = Invoke-Reshelf session resume

        $result.ExitCode | Should -Not -Be 0
        ($result.Output -join "`n") | Should -BeLike '*requires a session id*'
    }

    It 'session mark-reviewed without a session id fails with a clear error' {
        $result = Invoke-Reshelf session mark-reviewed

        $result.ExitCode | Should -Not -Be 0
        ($result.Output -join "`n") | Should -BeLike '*requires a session id*'
    }

    It 'session mark-reviewed sets stage to reviewed and resume reflects it' {
        $targetRoot = Join-Path $TestDrive 'target'
        Invoke-Reshelf settings init -TargetRoot $targetRoot | Out-Null

        $sourceRoot = Join-Path $TestDrive 'source-for-mark-reviewed'
        New-Item -ItemType Directory -Path $sourceRoot -Force | Out-Null

        $session = New-ReshelfSession -SourceRoot $sourceRoot -DataHome $dataHome
        Set-ReshelfSessionStage -SessionId $session.sessionId -Stage 'proposed' -DataHome $dataHome | Out-Null

        $result = Invoke-Reshelf session mark-reviewed -SessionId $session.sessionId
        $result.ExitCode | Should -Be 0

        (Get-ReshelfSession -SessionId $session.sessionId -DataHome $dataHome).stage | Should -Be 'reviewed'

        $resumeResult = Invoke-Reshelf session resume -SessionId $session.sessionId
        ($resumeResult.Output -join "`n") | Should -BeLike "*apply -SessionId $($session.sessionId)*"
    }

    It 'session resume via the CLI reports the right next command for every session stage' {
        $sourceRoot = Join-Path $TestDrive 'source-for-resume-stages'
        New-Item -ItemType Directory -Path $sourceRoot -Force | Out-Null
        $session = New-ReshelfSession -SourceRoot $sourceRoot -DataHome $dataHome

        $stageExpectations = [ordered]@{
            'recognized'        = "*propose -SessionId $($session.sessionId)*"
            'proposed'          = "*ui start*mark-reviewed -SessionId $($session.sessionId)*"
            'reviewed'          = "*apply -SessionId $($session.sessionId)*"
            'applied'           = '*complete*'
            'partially-applied' = "*apply -SessionId $($session.sessionId)*"
        }

        foreach ($stage in $stageExpectations.Keys) {
            Set-ReshelfSessionStage -SessionId $session.sessionId -Stage $stage -DataHome $dataHome | Out-Null

            $result = Invoke-Reshelf session resume -SessionId $session.sessionId
            $result.ExitCode | Should -Be 0
            # Format-List wraps a long NextCommand value across lines at the host's console width -
            # collapse all whitespace (including the wrap) to single spaces before matching.
            $flattenedOutput = ($result.Output -join ' ') -replace '\s+', ' '
            $flattenedOutput | Should -BeLike $stageExpectations[$stage] -Because "stage '$stage' should report its own next command"
        }
    }
}
