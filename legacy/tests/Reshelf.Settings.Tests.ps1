#Requires -Version 7.4

Import-Module Pester -MinimumVersion 5.0

BeforeAll {
    Import-Module "$PSScriptRoot/../scripts/common/Reshelf.Settings.psm1" -Force

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

    # An empty SecureString (what Read-Host -AsSecureString actually returns for a bare Enter
    # keypress) can't be built via ConvertTo-SecureString -String '' -AsPlainText -Force - that
    # cmdlet's own -String parameter rejects empty input outright, regardless of -AsPlainText/-Force.
    function New-EmptySecureString {
        return [System.Security.SecureString]::new()
    }

    # Reshelf.Settings.psm1 re-imports Reshelf.Common.psm1 internally as part of loading, which turns
    # it into a nested module of Reshelf.Settings - PowerShell then hides its commands from this
    # script's own top-level scope (same gotcha noted in Reshelf.EditProposal.Tests.ps1 and
    # Reshelf.LossyTracking.Tests.ps1). Routing through Settings' own module scope, which always has
    # it, avoids that fragility.
    function Get-TestUnprotectedSecret {
        param(
            [Parameter(Mandatory)]
            [string]$EncryptedText
        )

        return InModuleScope Reshelf.Settings -Parameters @{ enc = $EncryptedText } {
            param($enc)
            Unprotect-ReshelfSecret -EncryptedText $enc
        }
    }

    function New-TestSecureString {
        # Same intentional plaintext-to-SecureString pattern as Reshelf.Common.psm1's
        # Protect-ReshelfSecret - here it's simulating what Read-Host -AsSecureString returns, from a
        # known fake test value.
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '',
            Justification = 'Test fixture: builds a SecureString from a known fake value to mock what Read-Host -AsSecureString returns.')]
        param(
            [Parameter(Mandatory)]
            [string]$PlainText
        )

        return ConvertTo-SecureString -String $PlainText -AsPlainText -Force
    }
}

Describe 'Initialize-ReshelfSettings' {
    BeforeEach {
        $script:dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:targetRoot = Join-Path $TestDrive 'target'
    }

    It 'writes valid settings using only supplied params without prompting' {
        # Test-ReshelfHostIsInteractive is mocked false, not just relied on the real (non-interactive
        # test-runner) console state, so this stays deterministic on any machine - the Discogs token
        # prompt is unconditional on interactivity (it has no -Value param to pre-supply), so without
        # this it would fire and hit the "should not be called" mock below on a real interactive host.
        Mock -ModuleName Reshelf.Settings Test-ReshelfHostIsInteractive { $false }
        Mock -ModuleName Reshelf.Settings Read-Host { throw 'Read-Host should not be called.' }

        $result = Initialize-ReshelfSettings -TargetRoot $targetRoot -DefaultSourceRoot 'D:\source' -CopyMode 'copy' -DataHome $dataHome

        $result.targetRoot | Should -Be $targetRoot
        $result.defaultSourceRoot | Should -Be 'D:\source'
        $result.copyMode | Should -Be 'copy'
        $result.discogsTokenEncrypted | Should -Be ''
        (Join-Path $dataHome 'settings.json') | Should -Exist
    }

    It 'prompts only for fields left unsupplied, in an interactive host' {
        Mock -ModuleName Reshelf.Settings Test-ReshelfHostIsInteractive { $true }
        Mock -ModuleName Reshelf.Settings Read-Host { 'D:\prompted-source' } -ParameterFilter { $Prompt -like 'Default source root*' }
        Mock -ModuleName Reshelf.Settings Read-Host { New-EmptySecureString } -ParameterFilter { $Prompt -like 'Discogs Personal Access Token*' }

        $result = Initialize-ReshelfSettings -TargetRoot $targetRoot -DataHome $dataHome

        $result.defaultSourceRoot | Should -Be 'D:\prompted-source'
        # copyMode has no real choice any more ('move' was removed for source-file safety), so it's
        # no longer prompted for - always 'copy' unless the caller explicitly passes -CopyMode.
        $result.copyMode | Should -Be 'copy'
        $result.discogsTokenEncrypted | Should -Be ''
        Should -Invoke -ModuleName Reshelf.Settings Read-Host -Times 2
    }

    It 'encrypts and stores a Discogs token entered at the prompt, round-trippable back to the original value' {
        Mock -ModuleName Reshelf.Settings Test-ReshelfHostIsInteractive { $true }
        Mock -ModuleName Reshelf.Settings Read-Host { New-TestSecureString -PlainText 'my-real-token' } -ParameterFilter { $Prompt -like 'Discogs Personal Access Token*' }

        $result = Initialize-ReshelfSettings -TargetRoot $targetRoot -DefaultSourceRoot 'D:\source' -CopyMode 'copy' -DataHome $dataHome

        $result.discogsTokenEncrypted | Should -Not -BeNullOrEmpty
        $result.discogsTokenEncrypted | Should -Not -Be 'my-real-token'
        (Get-TestUnprotectedSecret -EncryptedText $result.discogsTokenEncrypted) | Should -Be 'my-real-token'
    }

    It 'leaves the token empty when skipped (empty response) at the prompt' {
        Mock -ModuleName Reshelf.Settings Test-ReshelfHostIsInteractive { $true }
        Mock -ModuleName Reshelf.Settings Read-Host { New-EmptySecureString } -ParameterFilter { $Prompt -like 'Discogs Personal Access Token*' }

        $result = Initialize-ReshelfSettings -TargetRoot $targetRoot -DefaultSourceRoot 'D:\source' -CopyMode 'copy' -DataHome $dataHome

        $result.discogsTokenEncrypted | Should -Be ''
    }

    It 'leaves the token empty and never prompts for it in a non-interactive host' {
        Mock -ModuleName Reshelf.Settings Test-ReshelfHostIsInteractive { $false }
        Mock -ModuleName Reshelf.Settings Read-Host { throw 'Read-Host should not be called for the token prompt.' } -ParameterFilter { $Prompt -like 'Discogs Personal Access Token*' }

        $result = Initialize-ReshelfSettings -TargetRoot $targetRoot -DataHome $dataHome

        $result.discogsTokenEncrypted | Should -Be ''
    }

    It 'fails fast with a clear message when TargetRoot is missing in a non-interactive host' {
        Mock -ModuleName Reshelf.Settings Test-ReshelfHostIsInteractive { $false }

        { Initialize-ReshelfSettings -DataHome $dataHome } | Should -Throw '*non-interactive*'
    }

    It 'throws when settings.json already exists and -Force is not passed' {
        Initialize-ReshelfSettings -TargetRoot $targetRoot -DataHome $dataHome | Out-Null

        { Initialize-ReshelfSettings -TargetRoot $targetRoot -DataHome $dataHome } | Should -Throw '*already exists*'
    }

    It 'overwrites existing settings.json when -Force is passed' {
        Initialize-ReshelfSettings -TargetRoot $targetRoot -DataHome $dataHome | Out-Null

        $newTargetRoot = Join-Path $TestDrive 'target2'
        $result = Initialize-ReshelfSettings -TargetRoot $newTargetRoot -DataHome $dataHome -Force

        $result.targetRoot | Should -Be $newTargetRoot
    }

    It 'defaults CopyMode to copy when skipped non-interactively' {
        Mock -ModuleName Reshelf.Settings Test-ReshelfHostIsInteractive { $false }

        $result = Initialize-ReshelfSettings -TargetRoot $targetRoot -DataHome $dataHome

        $result.copyMode | Should -Be 'copy'
    }

    It 'accepts a mixed-case -CopyMode value and normalizes it to lowercase' {
        $result = Initialize-ReshelfSettings -TargetRoot $targetRoot -CopyMode 'Copy' -DataHome $dataHome

        $result.copyMode | Should -Be 'copy'
    }

    It 'rejects -CopyMode move - it was removed for source-file safety' {
        { Initialize-ReshelfSettings -TargetRoot $targetRoot -CopyMode 'move' -DataHome $dataHome } | Should -Throw '*no longer supported*'
    }

    It 'throws when TargetRoot is not writable' {
        $unwritableTargetRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType File -Path $unwritableTargetRoot -Force | Out-Null

        { Initialize-ReshelfSettings -TargetRoot $unwritableTargetRoot -DataHome $dataHome } | Should -Throw
    }

    It 'produces a settings.json that validates against the settings schema' {
        Initialize-ReshelfSettings -TargetRoot $targetRoot -DataHome $dataHome | Out-Null

        Test-Json -LiteralPath (Join-Path $dataHome 'settings.json') -SchemaFile "$PSScriptRoot/../schemas/settings.schema.json" | Should -Be $true
    }
}

Describe 'Set-ReshelfDiscogsToken' {
    BeforeEach {
        $script:dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:targetRoot = Join-Path $TestDrive 'target'
        Mock -ModuleName Reshelf.Settings Test-ReshelfHostIsInteractive { $false }
        Initialize-ReshelfSettings -TargetRoot $targetRoot -DefaultSourceRoot 'D:\source' -CopyMode 'copy' -DataHome $dataHome | Out-Null
    }

    It 'updates an existing settings.json token and leaves every other field untouched' {
        Mock -ModuleName Reshelf.Settings Test-ReshelfHostIsInteractive { $true }
        Mock -ModuleName Reshelf.Settings Read-Host { New-TestSecureString -PlainText 'updated-token' }

        $before = Get-ReshelfSettings -DataHome $dataHome
        $result = Set-ReshelfDiscogsToken -DataHome $dataHome

        (Get-TestUnprotectedSecret -EncryptedText $result.discogsTokenEncrypted) | Should -Be 'updated-token'
        $result.targetRoot | Should -Be $before.targetRoot
        $result.defaultSourceRoot | Should -Be $before.defaultSourceRoot
        $result.copyMode | Should -Be $before.copyMode
    }

    It 'throws and never prompts when the host is not interactive' {
        Mock -ModuleName Reshelf.Settings Test-ReshelfHostIsInteractive { $false }
        Mock -ModuleName Reshelf.Settings Read-Host { throw 'Read-Host should not be called.' }

        { Set-ReshelfDiscogsToken -DataHome $dataHome } | Should -Throw '*interactive*'
    }
}

Describe 'Get-ReshelfSettings' {
    BeforeEach {
        $script:dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:targetRoot = Join-Path $TestDrive 'target'
    }

    It 'returns parsed settings when the file is valid' {
        Initialize-ReshelfSettings -TargetRoot $targetRoot -DataHome $dataHome | Out-Null

        $result = Get-ReshelfSettings -DataHome $dataHome

        $result.targetRoot | Should -Be $targetRoot
    }

    It 'calls Initialize-ReshelfSettings when settings.json is missing' {
        Mock -ModuleName Reshelf.Settings Initialize-ReshelfSettings { [pscustomobject]@{ targetRoot = 'stub' } }

        Get-ReshelfSettings -DataHome $dataHome | Out-Null

        Should -Invoke -ModuleName Reshelf.Settings Initialize-ReshelfSettings -Times 1
    }

    It 'throws a clear error when the on-disk file fails schema validation' {
        New-Item -ItemType Directory -Path $dataHome -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $dataHome 'settings.json') -Value '{"copyMode":"copy"}'

        { Get-ReshelfSettings -DataHome $dataHome } | Should -Throw '*does not match*'
    }

    It 'overrides a stale on-disk dataHome with the resolved data home the file was actually read from' {
        Initialize-ReshelfSettings -TargetRoot $targetRoot -DataHome $dataHome | Out-Null
        $settingsPath = Join-Path $dataHome 'settings.json'
        $onDisk = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
        $onDisk.dataHome = 'C:\stale\path'
        $onDisk | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $settingsPath -Encoding utf8

        $result = Get-ReshelfSettings -DataHome $dataHome

        $result.dataHome | Should -Be $dataHome
    }
}

Describe 'Set-ReshelfSettings' {
    BeforeEach {
        $script:dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:targetRoot = Join-Path $TestDrive 'target'
        Initialize-ReshelfSettings -TargetRoot $targetRoot -DataHome $dataHome | Out-Null
    }

    It 'updates and persists a top-level string key' {
        $result = Set-ReshelfSettings -Key 'discogsTokenEnvVar' -Value 'MY_TOKEN' -DataHome $dataHome

        $result.discogsTokenEnvVar | Should -Be 'MY_TOKEN'
        (Get-ReshelfSettings -DataHome $dataHome).discogsTokenEnvVar | Should -Be 'MY_TOKEN'
    }

    It 'coerces a string value to the field''s real type' {
        $result = Set-ReshelfSettings -Key 'cacheTtlDays' -Value '45' -DataHome $dataHome

        $result.cacheTtlDays | Should -Be 45
        $result.cacheTtlDays | Should -BeOfType [int]
    }

    It 'throws for an unknown key' {
        { Set-ReshelfSettings -Key 'notAKey' -Value 'x' -DataHome $dataHome } | Should -Throw '*Unknown settings key*'
    }

    It 'throws for an invalid copyMode' {
        { Set-ReshelfSettings -Key 'copyMode' -Value 'shred' -DataHome $dataHome } | Should -Throw '*Invalid copy mode*'
    }

    It 'accepts a mixed-case copyMode value and normalizes it to lowercase' {
        $result = Set-ReshelfSettings -Key 'copyMode' -Value 'Copy' -DataHome $dataHome

        $result.copyMode | Should -Be 'copy'
    }

    It 'rejects copyMode move - it was removed for source-file safety' {
        { Set-ReshelfSettings -Key 'copyMode' -Value 'move' -DataHome $dataHome } | Should -Throw '*no longer supported*'
    }

    It 're-validates writability when changing targetRoot' {
        $newTargetRoot = Join-Path $TestDrive 'newTarget'

        $result = Set-ReshelfSettings -Key 'targetRoot' -Value $newTargetRoot -DataHome $dataHome

        $result.targetRoot | Should -Be $newTargetRoot
        $newTargetRoot | Should -Exist
    }
}

Describe 'New-ReshelfSessionId (private)' {
    It 'starts at 0001 for a new date and increments per existing session' {
        InModuleScope Reshelf.Settings {
            $dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
            $date = Get-Date '2026-09-19'

            $first = New-ReshelfSessionId -DataHome $dataHome -Date $date
            $first | Should -Be '2026-09-19-0001'

            New-Item -ItemType Directory -Path (Join-Path $dataHome 'sessions' $first) -Force | Out-Null

            $second = New-ReshelfSessionId -DataHome $dataHome -Date $date
            $second | Should -Be '2026-09-19-0002'
        }
    }

    It 'resets to 0001 for a different date' {
        InModuleScope Reshelf.Settings {
            $dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path (Join-Path $dataHome 'sessions' '2026-09-19-0001') -Force | Out-Null

            $result = New-ReshelfSessionId -DataHome $dataHome -Date (Get-Date '2026-09-20')

            $result | Should -Be '2026-09-20-0001'
        }
    }
}

Describe 'New-ReshelfSession' {
    BeforeEach {
        $script:dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    }

    It 'creates the session folder and a session.json with stage recognized' {
        $session = New-ReshelfSession -SourceRoot 'D:\source' -DataHome $dataHome

        $session.stage | Should -Be 'recognized'
        $session.proposalPath | Should -Be $null
        (Join-Path $dataHome 'sessions' $session.sessionId 'session.json') | Should -Exist
    }

    It 'retries instead of clobbering when the computed session id already exists (simulated race)' {
        InModuleScope Reshelf.Settings -Parameters @{ dataHome = $dataHome } {
            $existingDir = Join-Path $dataHome 'sessions' '2026-01-01-0001'
            New-Item -ItemType Directory -Path $existingDir -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $existingDir 'session.json') -Value '"sentinel"'

            $script:tggrCallCount = 0
            Mock New-ReshelfSessionId {
                $script:tggrCallCount++
                if ($script:tggrCallCount -eq 1) { '2026-01-01-0001' } else { '2026-01-01-0002' }
            }

            $session = New-ReshelfSession -SourceRoot 'D:\source' -DataHome $dataHome

            $session.sessionId | Should -Be '2026-01-01-0002'
            (Get-Content -LiteralPath (Join-Path $existingDir 'session.json') -Raw).Trim() | Should -Be '"sentinel"'
        }
    }

    It 'gives two sessions created the same day sequential ids' {
        $first = New-ReshelfSession -SourceRoot 'D:\source1' -DataHome $dataHome
        $second = New-ReshelfSession -SourceRoot 'D:\source2' -DataHome $dataHome

        $first.sessionId | Should -Not -Be $second.sessionId
    }

    It 'produces a session.json that validates against the session schema' {
        $session = New-ReshelfSession -SourceRoot 'D:\source' -DataHome $dataHome

        $sessionFile = Join-Path $dataHome 'sessions' $session.sessionId 'session.json'
        Test-Json -LiteralPath $sessionFile -SchemaFile "$PSScriptRoot/../schemas/session.schema.json" | Should -Be $true
    }
}

Describe 'Resume-ReshelfSession' {
    BeforeEach {
        $script:dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:session = New-ReshelfSession -SourceRoot 'D:\source' -DataHome $dataHome
    }

    It 'reports the next command for stage recognized' {
        $result = Resume-ReshelfSession -SessionId $session.sessionId -DataHome $dataHome
        $result.NextCommand | Should -BeLike "*propose*$($session.sessionId)*"
    }

    It 'reports the next step for stage proposed' {
        Set-SessionStage -DataHome $dataHome -SessionId $session.sessionId -Stage 'proposed'
        $result = Resume-ReshelfSession -SessionId $session.sessionId -DataHome $dataHome
        $result.NextCommand | Should -BeLike '*ui start*'
        $result.NextCommand | Should -BeLike "*mark-reviewed*$($session.sessionId)*"
    }

    It 'reports the next command for stage reviewed' {
        Set-SessionStage -DataHome $dataHome -SessionId $session.sessionId -Stage 'reviewed'
        $result = Resume-ReshelfSession -SessionId $session.sessionId -DataHome $dataHome
        $result.NextCommand | Should -BeLike "*apply*$($session.sessionId)*"
    }

    It 'reports completion for stage applied' {
        Set-SessionStage -DataHome $dataHome -SessionId $session.sessionId -Stage 'applied'
        $result = Resume-ReshelfSession -SessionId $session.sessionId -DataHome $dataHome
        $result.NextCommand | Should -BeLike '*complete*'
    }

    It 'reports the next command for stage partially-applied' {
        Set-SessionStage -DataHome $dataHome -SessionId $session.sessionId -Stage 'partially-applied'
        $result = Resume-ReshelfSession -SessionId $session.sessionId -DataHome $dataHome
        $result.NextCommand | Should -BeLike "*apply*$($session.sessionId)*"
    }

    It 'throws for an unknown session id' {
        { Resume-ReshelfSession -SessionId '2000-01-01-0001' -DataHome $dataHome } | Should -Throw '*not found*'
    }
}

Describe 'Get-ReshelfSession' {
    BeforeEach {
        $script:dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    }

    It 'returns all sessions sorted by updatedAtUtc descending' {
        $first = New-ReshelfSession -SourceRoot 'D:\source1' -DataHome $dataHome
        Start-Sleep -Milliseconds 20
        $second = New-ReshelfSession -SourceRoot 'D:\source2' -DataHome $dataHome

        $result = Get-ReshelfSession -DataHome $dataHome

        $result[0].sessionId | Should -Be $second.sessionId
        $result[1].sessionId | Should -Be $first.sessionId
    }

    It 'returns a single session by id' {
        $session = New-ReshelfSession -SourceRoot 'D:\source' -DataHome $dataHome

        (Get-ReshelfSession -SessionId $session.sessionId -DataHome $dataHome).sourceRoot | Should -Be 'D:\source'
    }

    It 'throws for a missing session id' {
        { Get-ReshelfSession -SessionId '2000-01-01-0001' -DataHome $dataHome } | Should -Throw '*not found*'
    }

    It 'throws a clear error when session.json fails schema validation' {
        $session = New-ReshelfSession -SourceRoot 'D:\source' -DataHome $dataHome
        $sessionFile = Join-Path $dataHome 'sessions' $session.sessionId 'session.json'
        Set-Content -LiteralPath $sessionFile -Value '{"stage":"recognized"}'

        { Get-ReshelfSession -SessionId $session.sessionId -DataHome $dataHome } | Should -Throw '*does not match*'
    }

    It 'returns an empty collection when no sessions exist' {
        @(Get-ReshelfSession -DataHome $dataHome).Count | Should -Be 0
    }
}
