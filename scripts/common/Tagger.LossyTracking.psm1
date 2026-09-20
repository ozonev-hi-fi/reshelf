#Requires -Version 7.4

Import-Module (Join-Path $PSScriptRoot 'Tagger.Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Tagger.Json.psm1') -Force

function Get-TaggerLossyTrackingLedgerPath {
    [CmdletBinding()]
    param(
        [string]$DataHome
    )

    if (-not $DataHome) { $DataHome = Resolve-TaggerDataHome }
    return Join-Path $DataHome 'lossy-tracking.json'
}

function Get-TaggerLossyTrackingLedger {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [string]$DataHome
    )

    $ledgerPath = Get-TaggerLossyTrackingLedgerPath -DataHome $DataHome

    if (-not (Test-Path -LiteralPath $ledgerPath -PathType Leaf)) {
        return @()
    }

    if (-not (Test-TaggerJson -SchemaName lossy-tracking -Path $ledgerPath)) {
        throw "Lossy-tracking ledger at '$ledgerPath' does not match the lossy-tracking schema."
    }

    return @(Get-Content -LiteralPath $ledgerPath -Raw | ConvertFrom-Json)
}

function Get-TaggerLossyTrackingEntry {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [string]$StableKey,

        [string]$DataHome
    )

    return Get-TaggerLossyTrackingLedger -DataHome $DataHome |
        Where-Object { $_.stableKey -eq $StableKey } |
        Select-Object -First 1
}

function Add-TaggerLossyTrackingEntry {
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

    if (-not $DataHome) { $DataHome = Resolve-TaggerDataHome }

    $ledger = @(Get-TaggerLossyTrackingLedger -DataHome $DataHome)
    $nowUtc = $Now.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')

    $existing = $ledger | Where-Object { $_.stableKey -eq $StableKey } | Select-Object -First 1

    if ($existing) {
        $existing.lastCheckedUtc = $nowUtc
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

    $ledgerPath = Get-TaggerLossyTrackingLedgerPath -DataHome $DataHome
    Set-TaggerJsonFile -Path $ledgerPath -InputObject $ledger -SchemaName lossy-tracking -Depth 10 | Out-Null

    return $ledger
}

Export-ModuleMember -Function Get-TaggerLossyTrackingLedger, Get-TaggerLossyTrackingEntry, Add-TaggerLossyTrackingEntry
