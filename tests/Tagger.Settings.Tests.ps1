#Requires -Version 7.4

Import-Module Pester -MinimumVersion 5.0

BeforeAll {
    Import-Module "$PSScriptRoot/../scripts/common/Tagger.Settings.psm1" -Force

    function Set-SessionStage {
        param(
            [Parameter(Mandatory)][string]$DataHome,
            [Parameter(Mandatory)][string]$SessionId,
            [Parameter(Mandatory)][string]$Stage
        )

        $sessionFile = Join-Path $DataHome 'sessions' $SessionId 'session.json'
        $session = Get-Content -LiteralPath $sessionFile -Raw | ConvertFrom-Json
        $session.stage = $Stage
        $session | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $sessionFile -Encoding utf8
    }
}

Describe 'Initialize-TaggerSettings' {
    BeforeEach {
        $script:dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:targetRoot = Join-Path $TestDrive 'target'
    }

    It 'writes valid settings using only supplied params without prompting' {
        Mock -ModuleName Tagger.Settings Read-Host { throw 'Read-Host should not be called.' }

        $result = Initialize-TaggerSettings -TargetRoot $targetRoot -DefaultSourceRoot 'D:\source' -CopyMode 'move' -DataHome $dataHome

        $result.targetRoot | Should -Be $targetRoot
        $result.defaultSourceRoot | Should -Be 'D:\source'
        $result.copyMode | Should -Be 'move'
        (Join-Path $dataHome 'settings.json') | Should -Exist
    }

    It 'prompts only for fields left unsupplied, in an interactive host' {
        Mock -ModuleName Tagger.Settings Test-TaggerHostIsInteractive { $true }
        Mock -ModuleName Tagger.Settings Read-Host { 'D:\prompted-source' } -ParameterFilter { $Prompt -like 'Default source root*' }
        Mock -ModuleName Tagger.Settings Read-Host { 'copy' } -ParameterFilter { $Prompt -like 'Copy mode*' }

        $result = Initialize-TaggerSettings -TargetRoot $targetRoot -DataHome $dataHome

        $result.defaultSourceRoot | Should -Be 'D:\prompted-source'
        $result.copyMode | Should -Be 'copy'
        Should -Invoke -ModuleName Tagger.Settings Read-Host -Times 2
    }

    It 'fails fast with a clear message when TargetRoot is missing in a non-interactive host' {
        Mock -ModuleName Tagger.Settings Test-TaggerHostIsInteractive { $false }

        { Initialize-TaggerSettings -DataHome $dataHome } | Should -Throw '*non-interactive*'
    }

    It 'throws when settings.json already exists and -Force is not passed' {
        Initialize-TaggerSettings -TargetRoot $targetRoot -DataHome $dataHome | Out-Null

        { Initialize-TaggerSettings -TargetRoot $targetRoot -DataHome $dataHome } | Should -Throw '*already exists*'
    }

    It 'overwrites existing settings.json when -Force is passed' {
        Initialize-TaggerSettings -TargetRoot $targetRoot -DataHome $dataHome | Out-Null

        $newTargetRoot = Join-Path $TestDrive 'target2'
        $result = Initialize-TaggerSettings -TargetRoot $newTargetRoot -DataHome $dataHome -Force

        $result.targetRoot | Should -Be $newTargetRoot
    }

    It 'defaults CopyMode to copy when skipped non-interactively' {
        Mock -ModuleName Tagger.Settings Test-TaggerHostIsInteractive { $false }

        $result = Initialize-TaggerSettings -TargetRoot $targetRoot -DataHome $dataHome

        $result.copyMode | Should -Be 'copy'
    }

    It 'accepts a mixed-case -CopyMode value and normalizes it to lowercase' {
        $result = Initialize-TaggerSettings -TargetRoot $targetRoot -CopyMode 'Move' -DataHome $dataHome

        $result.copyMode | Should -Be 'move'
    }

    It 'throws when TargetRoot is not writable' {
        $unwritableTargetRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType File -Path $unwritableTargetRoot -Force | Out-Null

        { Initialize-TaggerSettings -TargetRoot $unwritableTargetRoot -DataHome $dataHome } | Should -Throw
    }

    It 'produces a settings.json that validates against the settings schema' {
        Initialize-TaggerSettings -TargetRoot $targetRoot -DataHome $dataHome | Out-Null

        Test-Json -LiteralPath (Join-Path $dataHome 'settings.json') -SchemaFile "$PSScriptRoot/../schemas/settings.schema.json" | Should -Be $true
    }
}

Describe 'Get-TaggerSettings' {
    BeforeEach {
        $script:dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:targetRoot = Join-Path $TestDrive 'target'
    }

    It 'returns parsed settings when the file is valid' {
        Initialize-TaggerSettings -TargetRoot $targetRoot -DataHome $dataHome | Out-Null

        $result = Get-TaggerSettings -DataHome $dataHome

        $result.targetRoot | Should -Be $targetRoot
    }

    It 'calls Initialize-TaggerSettings when settings.json is missing' {
        Mock -ModuleName Tagger.Settings Initialize-TaggerSettings { [pscustomobject]@{ targetRoot = 'stub' } }

        Get-TaggerSettings -DataHome $dataHome | Out-Null

        Should -Invoke -ModuleName Tagger.Settings Initialize-TaggerSettings -Times 1
    }

    It 'throws a clear error when the on-disk file fails schema validation' {
        New-Item -ItemType Directory -Path $dataHome -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $dataHome 'settings.json') -Value '{"copyMode":"copy"}'

        { Get-TaggerSettings -DataHome $dataHome } | Should -Throw '*does not match*'
    }
}

Describe 'Set-TaggerSettings' {
    BeforeEach {
        $script:dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:targetRoot = Join-Path $TestDrive 'target'
        Initialize-TaggerSettings -TargetRoot $targetRoot -DataHome $dataHome | Out-Null
    }

    It 'updates and persists a top-level string key' {
        $result = Set-TaggerSettings -Key 'discogsTokenEnvVar' -Value 'MY_TOKEN' -DataHome $dataHome

        $result.discogsTokenEnvVar | Should -Be 'MY_TOKEN'
        (Get-TaggerSettings -DataHome $dataHome).discogsTokenEnvVar | Should -Be 'MY_TOKEN'
    }

    It 'coerces a string value to the field''s real type' {
        $result = Set-TaggerSettings -Key 'cacheTtlDays' -Value '45' -DataHome $dataHome

        $result.cacheTtlDays | Should -Be 45
        $result.cacheTtlDays | Should -BeOfType [int]
    }

    It 'throws for an unknown key' {
        { Set-TaggerSettings -Key 'notAKey' -Value 'x' -DataHome $dataHome } | Should -Throw '*Unknown settings key*'
    }

    It 'throws for an invalid copyMode' {
        { Set-TaggerSettings -Key 'copyMode' -Value 'shred' -DataHome $dataHome } | Should -Throw '*Invalid copy mode*'
    }

    It 'accepts a mixed-case copyMode value and normalizes it to lowercase' {
        $result = Set-TaggerSettings -Key 'copyMode' -Value 'Move' -DataHome $dataHome

        $result.copyMode | Should -Be 'move'
    }

    It 're-validates writability when changing targetRoot' {
        $newTargetRoot = Join-Path $TestDrive 'newTarget'

        $result = Set-TaggerSettings -Key 'targetRoot' -Value $newTargetRoot -DataHome $dataHome

        $result.targetRoot | Should -Be $newTargetRoot
        $newTargetRoot | Should -Exist
    }
}

Describe 'New-TaggerSessionId (private)' {
    It 'starts at 0001 for a new date and increments per existing session' {
        InModuleScope Tagger.Settings {
            $dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
            $date = Get-Date '2026-09-19'

            $first = New-TaggerSessionId -DataHome $dataHome -Date $date
            $first | Should -Be '2026-09-19-0001'

            New-Item -ItemType Directory -Path (Join-Path $dataHome 'sessions' $first) -Force | Out-Null

            $second = New-TaggerSessionId -DataHome $dataHome -Date $date
            $second | Should -Be '2026-09-19-0002'
        }
    }

    It 'resets to 0001 for a different date' {
        InModuleScope Tagger.Settings {
            $dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path (Join-Path $dataHome 'sessions' '2026-09-19-0001') -Force | Out-Null

            $result = New-TaggerSessionId -DataHome $dataHome -Date (Get-Date '2026-09-20')

            $result | Should -Be '2026-09-20-0001'
        }
    }
}

Describe 'New-TaggerSession' {
    BeforeEach {
        $script:dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    }

    It 'creates the session folder and a session.json with stage recognized' {
        $session = New-TaggerSession -SourceRoot 'D:\source' -DataHome $dataHome

        $session.stage | Should -Be 'recognized'
        $session.proposalPath | Should -Be $null
        (Join-Path $dataHome 'sessions' $session.sessionId 'session.json') | Should -Exist
    }

    It 'retries instead of clobbering when the computed session id already exists (simulated race)' {
        InModuleScope Tagger.Settings -Parameters @{ dataHome = $dataHome } {
            $existingDir = Join-Path $dataHome 'sessions' '2026-01-01-0001'
            New-Item -ItemType Directory -Path $existingDir -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $existingDir 'session.json') -Value '"sentinel"'

            $script:tggrCallCount = 0
            Mock New-TaggerSessionId {
                $script:tggrCallCount++
                if ($script:tggrCallCount -eq 1) { '2026-01-01-0001' } else { '2026-01-01-0002' }
            }

            $session = New-TaggerSession -SourceRoot 'D:\source' -DataHome $dataHome

            $session.sessionId | Should -Be '2026-01-01-0002'
            (Get-Content -LiteralPath (Join-Path $existingDir 'session.json') -Raw).Trim() | Should -Be '"sentinel"'
        }
    }

    It 'gives two sessions created the same day sequential ids' {
        $first = New-TaggerSession -SourceRoot 'D:\source1' -DataHome $dataHome
        $second = New-TaggerSession -SourceRoot 'D:\source2' -DataHome $dataHome

        $first.sessionId | Should -Not -Be $second.sessionId
    }

    It 'produces a session.json that validates against the session schema' {
        $session = New-TaggerSession -SourceRoot 'D:\source' -DataHome $dataHome

        $sessionFile = Join-Path $dataHome 'sessions' $session.sessionId 'session.json'
        Test-Json -LiteralPath $sessionFile -SchemaFile "$PSScriptRoot/../schemas/session.schema.json" | Should -Be $true
    }
}

Describe 'Resume-TaggerSession' {
    BeforeEach {
        $script:dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:session = New-TaggerSession -SourceRoot 'D:\source' -DataHome $dataHome
    }

    It 'reports the next command for stage recognized' {
        $result = Resume-TaggerSession -SessionId $session.sessionId -DataHome $dataHome
        $result.NextCommand | Should -BeLike "*propose*$($session.sessionId)*"
    }

    It 'reports the next step for stage proposed' {
        Set-SessionStage -DataHome $dataHome -SessionId $session.sessionId -Stage 'proposed'
        $result = Resume-TaggerSession -SessionId $session.sessionId -DataHome $dataHome
        $result.NextCommand | Should -BeLike '*editing UI*'
    }

    It 'reports the next command for stage reviewed' {
        Set-SessionStage -DataHome $dataHome -SessionId $session.sessionId -Stage 'reviewed'
        $result = Resume-TaggerSession -SessionId $session.sessionId -DataHome $dataHome
        $result.NextCommand | Should -BeLike "*apply*$($session.sessionId)*"
    }

    It 'reports completion for stage applied' {
        Set-SessionStage -DataHome $dataHome -SessionId $session.sessionId -Stage 'applied'
        $result = Resume-TaggerSession -SessionId $session.sessionId -DataHome $dataHome
        $result.NextCommand | Should -BeLike '*complete*'
    }

    It 'reports the next command for stage partially-applied' {
        Set-SessionStage -DataHome $dataHome -SessionId $session.sessionId -Stage 'partially-applied'
        $result = Resume-TaggerSession -SessionId $session.sessionId -DataHome $dataHome
        $result.NextCommand | Should -BeLike "*apply*$($session.sessionId)*"
    }

    It 'throws for an unknown session id' {
        { Resume-TaggerSession -SessionId '2000-01-01-0001' -DataHome $dataHome } | Should -Throw '*not found*'
    }
}

Describe 'Complete-TaggerSession' {
    It 'sets stage to applied and persists it' {
        $dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $session = New-TaggerSession -SourceRoot 'D:\source' -DataHome $dataHome

        $result = Complete-TaggerSession -SessionId $session.sessionId -DataHome $dataHome

        $result.stage | Should -Be 'applied'
        (Get-TaggerSession -SessionId $session.sessionId -DataHome $dataHome).stage | Should -Be 'applied'
    }
}

Describe 'Get-TaggerSession' {
    BeforeEach {
        $script:dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    }

    It 'returns all sessions sorted by updatedAtUtc descending' {
        $first = New-TaggerSession -SourceRoot 'D:\source1' -DataHome $dataHome
        Start-Sleep -Milliseconds 20
        $second = New-TaggerSession -SourceRoot 'D:\source2' -DataHome $dataHome

        $result = Get-TaggerSession -DataHome $dataHome

        $result[0].sessionId | Should -Be $second.sessionId
        $result[1].sessionId | Should -Be $first.sessionId
    }

    It 'returns a single session by id' {
        $session = New-TaggerSession -SourceRoot 'D:\source' -DataHome $dataHome

        (Get-TaggerSession -SessionId $session.sessionId -DataHome $dataHome).sourceRoot | Should -Be 'D:\source'
    }

    It 'throws for a missing session id' {
        { Get-TaggerSession -SessionId '2000-01-01-0001' -DataHome $dataHome } | Should -Throw '*not found*'
    }

    It 'throws a clear error when session.json fails schema validation' {
        $session = New-TaggerSession -SourceRoot 'D:\source' -DataHome $dataHome
        $sessionFile = Join-Path $dataHome 'sessions' $session.sessionId 'session.json'
        Set-Content -LiteralPath $sessionFile -Value '{"stage":"recognized"}'

        { Get-TaggerSession -SessionId $session.sessionId -DataHome $dataHome } | Should -Throw '*does not match*'
    }

    It 'returns an empty collection when no sessions exist' {
        @(Get-TaggerSession -DataHome $dataHome).Count | Should -Be 0
    }
}
