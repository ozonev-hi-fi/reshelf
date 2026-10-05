#Requires -Version 7.4

Import-Module (Join-Path $PSScriptRoot 'Reshelf.Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Reshelf.Json.psm1') -Force

function Get-ReshelfLossyTrackingLedgerPath {
    [CmdletBinding()]
    param(
        [string]$DataHome
    )

    if (-not $DataHome) { $DataHome = Resolve-ReshelfDataHome }
    return Join-Path $DataHome 'lossy-tracking.json'
}

function Get-ReshelfLossyTrackingLedger {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [string]$DataHome
    )

    $ledgerPath = Get-ReshelfLossyTrackingLedgerPath -DataHome $DataHome

    if (-not (Test-Path -LiteralPath $ledgerPath -PathType Leaf)) {
        return @()
    }

    if (-not (Test-ReshelfJson -SchemaName lossy-tracking -Path $ledgerPath)) {
        throw "Lossy-tracking ledger at '$ledgerPath' does not match the lossy-tracking schema."
    }

    return @(Get-Content -LiteralPath $ledgerPath -Raw | ConvertFrom-Json)
}

function Get-ReshelfLossyTrackingEntry {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [string]$StableKey,

        [string]$DataHome
    )

    return Get-ReshelfLossyTrackingLedger -DataHome $DataHome |
        Where-Object { $_.stableKey -eq $StableKey } |
        Select-Object -First 1
}

function Add-ReshelfLossyTrackingEntry {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [string]$StableKey,

        [Parameter(Mandatory)]
        [string]$Artist,

        [Parameter(Mandatory)]
        [string]$Album,

        [Parameter(Mandatory)]
        [int]$Year,

        [Parameter(Mandatory)]
        [string]$TargetPath,

        [Parameter(Mandatory)]
        [string]$Format,

        [string]$DataHome,

        [datetime]$Now = (Get-Date)
    )

    if (-not $DataHome) { $DataHome = Resolve-ReshelfDataHome }

    $ledger = @(Get-ReshelfLossyTrackingLedger -DataHome $DataHome)
    $nowUtc = $Now.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')

    $existing = $ledger | Where-Object { $_.stableKey -eq $StableKey } | Select-Object -First 1

    if ($existing) {
        $existing.lastCheckedUtc = $nowUtc
        # targetPath is the latest known location, not a first-sighting snapshot - targetRoot or the
        # naming templates can change between runs, and a stale path here points at nothing.
        $existing.targetPath = $TargetPath
    }
    else {
        $ledger = @($ledger) + [pscustomobject]@{
            stableKey        = $StableKey
            artist           = $Artist
            album            = $Album
            year             = $Year
            targetPath       = $TargetPath
            format           = $Format
            status           = 'pending-upgrade'
            firstDetectedUtc = $nowUtc
            lastCheckedUtc   = $nowUtc
            upgradedUtc      = $null
            notes            = ''
        }
    }

    $ledgerPath = Get-ReshelfLossyTrackingLedgerPath -DataHome $DataHome
    Set-ReshelfJsonFile -Path $ledgerPath -InputObject $ledger -SchemaName lossy-tracking -Depth 10 | Out-Null

    return $ledger
}

function Set-ReshelfLossyTrackingUpgraded {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [string]$StableKey,

        [string]$DataHome,

        [datetime]$Now = (Get-Date)
    )

    if (-not $DataHome) { $DataHome = Resolve-ReshelfDataHome }

    $ledger = @(Get-ReshelfLossyTrackingLedger -DataHome $DataHome)
    $existing = $ledger | Where-Object { $_.stableKey -eq $StableKey } | Select-Object -First 1

    if (-not $existing) {
        # Defensive, not a hard assumption - an upgrade should always have a prior pending-upgrade
        # row from Step 6, but a missing row here shouldn't block Implementation from finishing.
        Write-Warning "No lossy-tracking entry found for stable key '$StableKey' - nothing to mark upgraded."
        return $ledger
    }

    $existing.status = 'upgraded'
    $existing.upgradedUtc = $Now.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')

    $ledgerPath = Get-ReshelfLossyTrackingLedgerPath -DataHome $DataHome
    Set-ReshelfJsonFile -Path $ledgerPath -InputObject $ledger -SchemaName lossy-tracking -Depth 10 | Out-Null

    return $ledger
}

function Set-ReshelfLossyTrackingTargetPath {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [string]$StableKey,

        [Parameter(Mandatory)]
        [string]$TargetPath,

        [string]$DataHome
    )

    if (-not $DataHome) { $DataHome = Resolve-ReshelfDataHome }

    $ledger = @(Get-ReshelfLossyTrackingLedger -DataHome $DataHome)
    $existing = $ledger | Where-Object { $_.stableKey -eq $StableKey } | Select-Object -First 1

    if (-not $existing) {
        Write-Warning "No lossy-tracking entry found for stable key '$StableKey' - nothing to update."
        return $ledger
    }

    $existing.targetPath = $TargetPath

    $ledgerPath = Get-ReshelfLossyTrackingLedgerPath -DataHome $DataHome
    Set-ReshelfJsonFile -Path $ledgerPath -InputObject $ledger -SchemaName lossy-tracking -Depth 10 | Out-Null

    return $ledger
}

function Set-ReshelfLossyTrackingIgnored {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [string]$StableKey,

        [string]$DataHome
    )

    if (-not $DataHome) { $DataHome = Resolve-ReshelfDataHome }

    $ledger = @(Get-ReshelfLossyTrackingLedger -DataHome $DataHome)
    $existing = $ledger | Where-Object { $_.stableKey -eq $StableKey } | Select-Object -First 1

    if (-not $existing) {
        Write-Warning "No lossy-tracking entry found for stable key '$StableKey' - nothing to ignore."
        return $ledger
    }

    $existing.status = 'ignored'

    $ledgerPath = Get-ReshelfLossyTrackingLedgerPath -DataHome $DataHome
    Set-ReshelfJsonFile -Path $ledgerPath -InputObject $ledger -SchemaName lossy-tracking -Depth 10 | Out-Null

    return $ledger
}

function Set-ReshelfLossyTrackingStatus {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [string]$StableKey,

        [Parameter(Mandatory)]
        [ValidateSet('pending-upgrade', 'upgraded', 'ignored')]
        [string]$Status,

        # Omitted entirely leaves notes untouched - distinct from an explicit '' clear. A typed
        # [string]$Notes can't tell those apart on its own (PowerShell binds an un-supplied string
        # parameter to '', not $null), so $PSBoundParameters is checked below instead.
        [AllowEmptyString()]
        [string]$Notes,

        [string]$DataHome,

        [datetime]$Now = (Get-Date)
    )

    if (-not $DataHome) { $DataHome = Resolve-ReshelfDataHome }

    $ledger = @(Get-ReshelfLossyTrackingLedger -DataHome $DataHome)
    $existing = $ledger | Where-Object { $_.stableKey -eq $StableKey } | Select-Object -First 1

    if (-not $existing) {
        Write-Warning "No lossy-tracking entry found for stable key '$StableKey' - nothing to update."
        return $ledger
    }

    $existing.status = $Status
    if ($Status -eq 'upgraded') {
        # Only set once - re-saving an already-upgraded row (e.g. a notes-only edit in the UI) must
        # not keep bumping its upgradedUtc forward.
        if (-not $existing.upgradedUtc) { $existing.upgradedUtc = $Now.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ') }
    }
    else {
        $existing.upgradedUtc = $null
    }
    if ($PSBoundParameters.ContainsKey('Notes')) { $existing.notes = $Notes }

    $ledgerPath = Get-ReshelfLossyTrackingLedgerPath -DataHome $DataHome
    Set-ReshelfJsonFile -Path $ledgerPath -InputObject $ledger -SchemaName lossy-tracking -Depth 10 | Out-Null

    return $ledger
}

function Remove-ReshelfLossyTrackingEntry {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [string]$StableKey,

        [string]$DataHome
    )

    if (-not $DataHome) { $DataHome = Resolve-ReshelfDataHome }

    $ledger = @(Get-ReshelfLossyTrackingLedger -DataHome $DataHome)
    $existing = $ledger | Where-Object { $_.stableKey -eq $StableKey } | Select-Object -First 1

    if (-not $existing) {
        Write-Warning "No lossy-tracking entry found for stable key '$StableKey' - nothing to remove."
        return $ledger
    }

    # Unlike Set-ReshelfLossyTrackingIgnored (a deliberate "I know, I don't care" record that stays
    # in the ledger), this permanently drops the row - for a mistaken entry, a duplicate, or one the
    # user no longer wants tracked at all (plan/09's "ignored" and outright deletion are both
    # supported, for different reasons).
    $ledger = @($ledger | Where-Object { $_.stableKey -ne $StableKey })

    $ledgerPath = Get-ReshelfLossyTrackingLedgerPath -DataHome $DataHome
    Set-ReshelfJsonFile -Path $ledgerPath -InputObject $ledger -SchemaName lossy-tracking -Depth 10 | Out-Null

    return $ledger
}

Export-ModuleMember -Function Get-ReshelfLossyTrackingLedger, Get-ReshelfLossyTrackingEntry, Add-ReshelfLossyTrackingEntry, `
    Set-ReshelfLossyTrackingUpgraded, Set-ReshelfLossyTrackingTargetPath, Set-ReshelfLossyTrackingIgnored, Set-ReshelfLossyTrackingStatus, `
    Remove-ReshelfLossyTrackingEntry
