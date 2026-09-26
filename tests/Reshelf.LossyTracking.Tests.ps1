#Requires -Version 7.4

Import-Module Pester -MinimumVersion 5.0

BeforeAll {
    Import-Module "$PSScriptRoot/../scripts/common/Reshelf.Common.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Reshelf.Json.psm1" -Force
    Import-Module "$PSScriptRoot/../scripts/common/Reshelf.LossyTracking.psm1" -Force

    # Reshelf.LossyTracking.psm1 re-imports Common/Json internally as part of loading, which turns
    # them into nested modules of Reshelf.LossyTracking - PowerShell then hides their commands from
    # this script's own top-level scope (order-dependent on what else has imported them). Routing
    # through LossyTracking's own module scope, which always has them, avoids that fragility.
    function Test-LossyTrackingDocumentJson {
        param(
            [Parameter(Mandatory)]
            [string]$Path
        )

        return InModuleScope Reshelf.LossyTracking -Parameters @{ jsonPath = $Path } {
            param($jsonPath)
            Test-ReshelfJson -SchemaName lossy-tracking -Path $jsonPath
        }
    }
}

Describe 'Get-ReshelfLossyTrackingLedger' {
    BeforeEach {
        $script:dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:dataHome -Force | Out-Null
    }

    It 'returns an empty array when no ledger file exists' {
        $result = @(Get-ReshelfLossyTrackingLedger -DataHome $script:dataHome)
        $result.Count | Should -Be 0
    }

    It 'returns the parsed entries from an existing valid ledger' {
        $ledgerPath = Join-Path $script:dataHome 'lossy-tracking.json'
        $entry = [pscustomobject]@{
            stableKey = 'a1b2c3d4e5f60708'; artist = 'ZZ Top'; album = 'XXX'; year = 1999
            targetPath = 'E:\Music\ZZ Top\1999 XXX'; format = 'mp3'; status = 'pending-upgrade'
            firstDetectedUtc = '2026-09-19T10:00:00.000Z'; lastCheckedUtc = '2026-09-19T10:00:00.000Z'
            upgradedUtc = $null; notes = ''
        }
        Set-Content -LiteralPath $ledgerPath -Value (ConvertTo-Json -InputObject @($entry) -Depth 10)

        $result = @(Get-ReshelfLossyTrackingLedger -DataHome $script:dataHome)

        $result.Count | Should -Be 1
        $result[0].stableKey | Should -Be 'a1b2c3d4e5f60708'
    }

    It 'throws a clear error naming the file when the ledger does not match the schema' {
        $ledgerPath = Join-Path $script:dataHome 'lossy-tracking.json'
        Set-Content -LiteralPath $ledgerPath -Value '[{"stableKey":"missing-other-fields"}]'

        { Get-ReshelfLossyTrackingLedger -DataHome $script:dataHome } | Should -Throw -ExpectedMessage "*$ledgerPath*"
    }
}

Describe 'Get-ReshelfLossyTrackingEntry' {
    BeforeEach {
        $script:dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:dataHome -Force | Out-Null
    }

    It 'returns $null when no entry matches the stable key' {
        $result = Get-ReshelfLossyTrackingEntry -StableKey 'doesnotexist00000' -DataHome $script:dataHome
        $result | Should -BeNullOrEmpty
    }

    It 'returns the matching entry when present' {
        Add-ReshelfLossyTrackingEntry -StableKey 'a1b2c3d4e5f60708' -Artist 'ZZ Top' -Album 'XXX' -Year 1999 `
            -TargetPath 'E:\Music\ZZ Top\1999 XXX' -Format 'mp3' -DataHome $script:dataHome | Out-Null

        $result = Get-ReshelfLossyTrackingEntry -StableKey 'a1b2c3d4e5f60708' -DataHome $script:dataHome

        $result.artist | Should -Be 'ZZ Top'
    }
}

Describe 'Add-ReshelfLossyTrackingEntry' {
    BeforeEach {
        $script:dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:dataHome -Force | Out-Null
    }

    It 'creates a new pending-upgrade entry with matching firstDetectedUtc and lastCheckedUtc' {
        $now = Get-Date '2026-09-19T10:00:00Z'
        Add-ReshelfLossyTrackingEntry -StableKey 'a1b2c3d4e5f60708' -Artist 'ZZ Top' -Album 'XXX' -Year 1999 `
            -TargetPath 'E:\Music\ZZ Top\1999 XXX' -Format 'mp3' -DataHome $script:dataHome -Now $now | Out-Null

        $entry = Get-ReshelfLossyTrackingEntry -StableKey 'a1b2c3d4e5f60708' -DataHome $script:dataHome

        $entry.status | Should -Be 'pending-upgrade'
        $entry.firstDetectedUtc | Should -Be $entry.lastCheckedUtc
        $entry.upgradedUtc | Should -BeNullOrEmpty
    }

    It 'updates lastCheckedUtc but keeps firstDetectedUtc on a second call for the same stable key' {
        $first = Get-Date '2026-09-19T10:00:00Z'
        $second = Get-Date '2026-09-20T11:00:00Z'

        Add-ReshelfLossyTrackingEntry -StableKey 'a1b2c3d4e5f60708' -Artist 'ZZ Top' -Album 'XXX' -Year 1999 `
            -TargetPath 'E:\Music\ZZ Top\1999 XXX' -Format 'mp3' -DataHome $script:dataHome -Now $first | Out-Null
        Add-ReshelfLossyTrackingEntry -StableKey 'a1b2c3d4e5f60708' -Artist 'ZZ Top' -Album 'XXX' -Year 1999 `
            -TargetPath 'E:\Music\ZZ Top\1999 XXX' -Format 'mp3' -DataHome $script:dataHome -Now $second | Out-Null

        $entry = Get-ReshelfLossyTrackingEntry -StableKey 'a1b2c3d4e5f60708' -DataHome $script:dataHome

        # ConvertFrom-Json auto-converts ISO-8601-looking strings to [datetime] (Kind=Utc), while
        # Get-Date on a "...Z" string returns local-Kind time - comparing raw Ticks would differ
        # even for the same instant, so both sides are normalized to UTC before comparing.
        ([datetime]$entry.firstDetectedUtc).ToUniversalTime() | Should -Be $first.ToUniversalTime()
        ([datetime]$entry.lastCheckedUtc).ToUniversalTime() | Should -Be $second.ToUniversalTime()
    }

    It 'replaces a stale targetPath on a later sighting but keeps status and firstDetectedUtc' {
        $first = Get-Date '2026-09-19T10:00:00Z'

        Add-ReshelfLossyTrackingEntry -StableKey 'a1b2c3d4e5f60708' -Artist 'ZZ Top' -Album 'XXX' -Year 1999 `
            -TargetPath 'E:\OldRoot\ZZ Top\1999 XXX' -Format 'mp3' -DataHome $script:dataHome -Now $first | Out-Null
        Add-ReshelfLossyTrackingEntry -StableKey 'a1b2c3d4e5f60708' -Artist 'ZZ Top' -Album 'XXX' -Year 1999 `
            -TargetPath 'E:\Music\ZZ Top\1999 XXX' -Format 'mp3' -DataHome $script:dataHome | Out-Null

        $entry = Get-ReshelfLossyTrackingEntry -StableKey 'a1b2c3d4e5f60708' -DataHome $script:dataHome

        $entry.targetPath | Should -Be 'E:\Music\ZZ Top\1999 XXX'
        $entry.status | Should -Be 'pending-upgrade'
        ([datetime]$entry.firstDetectedUtc).ToUniversalTime() | Should -Be $first.ToUniversalTime()
    }

    It 'leaves a pre-seeded ignored entry as ignored' {
        Add-ReshelfLossyTrackingEntry -StableKey 'a1b2c3d4e5f60708' -Artist 'ZZ Top' -Album 'XXX' -Year 1999 `
            -TargetPath 'E:\Music\ZZ Top\1999 XXX' -Format 'mp3' -DataHome $script:dataHome | Out-Null

        $ledgerPath = Join-Path $script:dataHome 'lossy-tracking.json'
        $ledger = Get-Content -LiteralPath $ledgerPath -Raw | ConvertFrom-Json
        $ledger[0].status = 'ignored'
        Set-Content -LiteralPath $ledgerPath -Value (ConvertTo-Json -InputObject @($ledger) -Depth 10)

        Add-ReshelfLossyTrackingEntry -StableKey 'a1b2c3d4e5f60708' -Artist 'ZZ Top' -Album 'XXX' -Year 1999 `
            -TargetPath 'E:\Music\ZZ Top\1999 XXX' -Format 'mp3' -DataHome $script:dataHome | Out-Null

        $entry = Get-ReshelfLossyTrackingEntry -StableKey 'a1b2c3d4e5f60708' -DataHome $script:dataHome
        $entry.status | Should -Be 'ignored'
    }

    It 'leaves a pre-seeded upgraded entry as upgraded' {
        Add-ReshelfLossyTrackingEntry -StableKey 'a1b2c3d4e5f60708' -Artist 'ZZ Top' -Album 'XXX' -Year 1999 `
            -TargetPath 'E:\Music\ZZ Top\1999 XXX' -Format 'mp3' -DataHome $script:dataHome | Out-Null

        $ledgerPath = Join-Path $script:dataHome 'lossy-tracking.json'
        $ledger = Get-Content -LiteralPath $ledgerPath -Raw | ConvertFrom-Json
        $ledger[0].status = 'upgraded'
        $ledger[0].upgradedUtc = '2026-09-21T00:00:00.000Z'
        Set-Content -LiteralPath $ledgerPath -Value (ConvertTo-Json -InputObject @($ledger) -Depth 10)

        Add-ReshelfLossyTrackingEntry -StableKey 'a1b2c3d4e5f60708' -Artist 'ZZ Top' -Album 'XXX' -Year 1999 `
            -TargetPath 'E:\Music\ZZ Top\1999 XXX' -Format 'mp3' -DataHome $script:dataHome | Out-Null

        $entry = Get-ReshelfLossyTrackingEntry -StableKey 'a1b2c3d4e5f60708' -DataHome $script:dataHome
        $entry.status | Should -Be 'upgraded'
        ([datetime]$entry.upgradedUtc).ToUniversalTime() | Should -Be (Get-Date '2026-09-21T00:00:00Z').ToUniversalTime()
    }

    It 'writes a ledger file that validates against the lossy-tracking schema' {
        Add-ReshelfLossyTrackingEntry -StableKey 'a1b2c3d4e5f60708' -Artist 'ZZ Top' -Album 'XXX' -Year 1999 `
            -TargetPath 'E:\Music\ZZ Top\1999 XXX' -Format 'mp3' -DataHome $script:dataHome | Out-Null

        $ledgerPath = Join-Path $script:dataHome 'lossy-tracking.json'
        Test-LossyTrackingDocumentJson -Path $ledgerPath | Should -Be $true
    }
}

Describe 'Set-ReshelfLossyTrackingTargetPath' {
    BeforeEach {
        $script:dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:dataHome -Force | Out-Null
    }

    It 'sets targetPath for an existing entry and leaves status unchanged' {
        Add-ReshelfLossyTrackingEntry -StableKey 'a1b2c3d4e5f60708' -Artist 'ZZ Top' -Album 'XXX' -Year 1999 `
            -TargetPath 'E:\Music\ZZ Top\1999 XXX' -Format 'mp3' -DataHome $script:dataHome | Out-Null

        Set-ReshelfLossyTrackingTargetPath -StableKey 'a1b2c3d4e5f60708' -TargetPath 'E:\Music\ZZ Top\1999 XXX (Edited)' `
            -DataHome $script:dataHome | Out-Null

        $entry = Get-ReshelfLossyTrackingEntry -StableKey 'a1b2c3d4e5f60708' -DataHome $script:dataHome
        $entry.targetPath | Should -Be 'E:\Music\ZZ Top\1999 XXX (Edited)'
        $entry.status | Should -Be 'pending-upgrade'
    }

    It 'warns and returns the ledger unchanged when the stable key does not exist' {
        Add-ReshelfLossyTrackingEntry -StableKey 'a1b2c3d4e5f60708' -Artist 'ZZ Top' -Album 'XXX' -Year 1999 `
            -TargetPath 'E:\Music\ZZ Top\1999 XXX' -Format 'mp3' -DataHome $script:dataHome | Out-Null

        $result = Set-ReshelfLossyTrackingTargetPath -StableKey 'doesnotexist0000' -TargetPath 'E:\Elsewhere' `
            -DataHome $script:dataHome -WarningAction SilentlyContinue

        @($result).Count | Should -Be 1
        $result[0].targetPath | Should -Be 'E:\Music\ZZ Top\1999 XXX'
    }

    It 'writes a ledger file that validates against the lossy-tracking schema' {
        Add-ReshelfLossyTrackingEntry -StableKey 'a1b2c3d4e5f60708' -Artist 'ZZ Top' -Album 'XXX' -Year 1999 `
            -TargetPath 'E:\Music\ZZ Top\1999 XXX' -Format 'mp3' -DataHome $script:dataHome | Out-Null
        Set-ReshelfLossyTrackingTargetPath -StableKey 'a1b2c3d4e5f60708' -TargetPath 'E:\Music\ZZ Top\1999 XXX (Edited)' `
            -DataHome $script:dataHome | Out-Null

        $ledgerPath = Join-Path $script:dataHome 'lossy-tracking.json'
        Test-LossyTrackingDocumentJson -Path $ledgerPath | Should -Be $true
    }
}

Describe 'Set-ReshelfLossyTrackingIgnored' {
    BeforeEach {
        $script:dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:dataHome -Force | Out-Null
    }

    It 'sets status to ignored for an existing entry' {
        Add-ReshelfLossyTrackingEntry -StableKey 'a1b2c3d4e5f60708' -Artist 'ZZ Top' -Album 'XXX' -Year 1999 `
            -TargetPath 'E:\Music\ZZ Top\1999 XXX' -Format 'mp3' -DataHome $script:dataHome | Out-Null

        Set-ReshelfLossyTrackingIgnored -StableKey 'a1b2c3d4e5f60708' -DataHome $script:dataHome | Out-Null

        $entry = Get-ReshelfLossyTrackingEntry -StableKey 'a1b2c3d4e5f60708' -DataHome $script:dataHome
        $entry.status | Should -Be 'ignored'
    }

    It 'warns and returns the ledger unchanged when the stable key does not exist' {
        Add-ReshelfLossyTrackingEntry -StableKey 'a1b2c3d4e5f60708' -Artist 'ZZ Top' -Album 'XXX' -Year 1999 `
            -TargetPath 'E:\Music\ZZ Top\1999 XXX' -Format 'mp3' -DataHome $script:dataHome | Out-Null

        $result = Set-ReshelfLossyTrackingIgnored -StableKey 'doesnotexist0000' -DataHome $script:dataHome -WarningAction SilentlyContinue

        @($result).Count | Should -Be 1
        $result[0].status | Should -Be 'pending-upgrade'
    }

    It 'writes a ledger file that validates against the lossy-tracking schema' {
        Add-ReshelfLossyTrackingEntry -StableKey 'a1b2c3d4e5f60708' -Artist 'ZZ Top' -Album 'XXX' -Year 1999 `
            -TargetPath 'E:\Music\ZZ Top\1999 XXX' -Format 'mp3' -DataHome $script:dataHome | Out-Null
        Set-ReshelfLossyTrackingIgnored -StableKey 'a1b2c3d4e5f60708' -DataHome $script:dataHome | Out-Null

        $ledgerPath = Join-Path $script:dataHome 'lossy-tracking.json'
        Test-LossyTrackingDocumentJson -Path $ledgerPath | Should -Be $true
    }
}
