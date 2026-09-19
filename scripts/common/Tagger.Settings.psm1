#Requires -Version 7.4

Import-Module (Join-Path $PSScriptRoot 'Tagger.Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Tagger.Json.psm1') -Force

function Test-TaggerHostIsInteractive {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return -not [Console]::IsInputRedirected
}

function New-TaggerSessionId {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$DataHome,

        [datetime]$Date = (Get-Date)
    )

    $datePrefix = $Date.ToString('yyyy-MM-dd')
    $sessionsDir = Join-Path $DataHome 'sessions'

    $existingCount = 0
    if (Test-Path -LiteralPath $sessionsDir) {
        $existingCount = @(Get-ChildItem -LiteralPath $sessionsDir -Directory -Filter "$datePrefix-*").Count
    }

    $sequence = ($existingCount + 1).ToString('0000')
    return "$datePrefix-$sequence"
}

function Assert-TaggerPathWritable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        try {
            New-Item -ItemType Directory -Path $Path -Force -ErrorAction Stop | Out-Null
        }
        catch {
            throw "Target root '$Path' does not exist and could not be created: $($_.Exception.Message)"
        }
    }

    $probeFile = Join-Path $Path ".tagger-write-probe-$([guid]::NewGuid().ToString('N')).tmp"
    try {
        [System.IO.File]::WriteAllText($probeFile, '')
        Remove-Item -LiteralPath $probeFile -Force -ErrorAction Stop
    }
    catch {
        throw "Target root '$Path' is not writable: $($_.Exception.Message)"
    }
}

function Get-TaggerSettings {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string]$DataHome
    )

    if (-not $DataHome) {
        $DataHome = Resolve-TaggerDataHome
    }

    $settingsPath = Join-Path $DataHome 'settings.json'
    if (-not (Test-Path -LiteralPath $settingsPath -PathType Leaf)) {
        return Initialize-TaggerSettings -DataHome $DataHome
    }

    if (-not (Test-TaggerJson -SchemaName settings -Path $settingsPath)) {
        throw "Settings file at '$settingsPath' does not match the settings schema. Fix it manually or re-run 'Tagger.ps1 settings init -Force'."
    }

    return Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
}

function Initialize-TaggerSettings {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string]$TargetRoot,
        [string]$DefaultSourceRoot,
        [string]$CopyMode,
        [string]$DataHome,
        [switch]$Force
    )

    if (-not $DataHome) {
        $DataHome = Resolve-TaggerDataHome
    }

    $settingsPath = Join-Path $DataHome 'settings.json'
    if ((Test-Path -LiteralPath $settingsPath) -and -not $Force) {
        throw "Settings file already exists at '$settingsPath'. Use -Force to overwrite."
    }

    if (-not $TargetRoot) {
        if (-not (Test-TaggerHostIsInteractive)) {
            throw "Target root is required, but this is a non-interactive host. Run: Tagger.ps1 settings init -TargetRoot <path>"
        }
        $TargetRoot = Read-Host 'Target root (where organized music will be written)'
    }
    if (-not $TargetRoot) {
        throw 'Target root is required.'
    }

    if (-not $DefaultSourceRoot) {
        if (Test-TaggerHostIsInteractive) {
            $DefaultSourceRoot = Read-Host 'Default source root (optional, press Enter to skip)'
        }
        if (-not $DefaultSourceRoot) {
            $DefaultSourceRoot = ''
        }
    }

    if (-not $CopyMode) {
        if (Test-TaggerHostIsInteractive) {
            $promptedCopyMode = Read-Host 'Copy mode: copy or move (default: copy)'
            $CopyMode = if ($promptedCopyMode) { $promptedCopyMode } else { 'copy' }
        }
        else {
            $CopyMode = 'copy'
        }
    }

    $CopyMode = $CopyMode.ToLowerInvariant()
    if ($CopyMode -notin @('copy', 'move')) {
        throw "Invalid copy mode '$CopyMode'. Must be 'copy' or 'move'."
    }

    Assert-TaggerPathWritable -Path $TargetRoot

    $defaultsPath = Join-Path $PSScriptRoot '..' '..' 'config' 'settings.default.json'
    $settings = Get-Content -LiteralPath $defaultsPath -Raw | ConvertFrom-Json

    $settings.defaultSourceRoot = $DefaultSourceRoot
    $settings.targetRoot = $TargetRoot
    $settings.copyMode = $CopyMode
    $settings.dataHome = $DataHome

    Set-TaggerJsonFile -Path $settingsPath -InputObject $settings -SchemaName settings | Out-Null

    return $settings
}

function Set-TaggerSettings {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$Key,

        [Parameter(Mandatory)]
        [string]$Value,

        [string]$DataHome
    )

    if (-not $DataHome) {
        $DataHome = Resolve-TaggerDataHome
    }

    $settings = Get-TaggerSettings -DataHome $DataHome

    if ($settings.PSObject.Properties.Name -notcontains $Key) {
        $validKeys = ($settings.PSObject.Properties.Name | Sort-Object) -join ', '
        throw "Unknown settings key '$Key'. Valid keys: $validKeys."
    }

    $currentValue = $settings.$Key
    if ($currentValue -is [System.Management.Automation.PSCustomObject]) {
        throw "Setting key '$Key' is a nested object and cannot be set directly. Edit settings.json manually for now."
    }

    $newValue =
    if ($currentValue -is [int] -or $currentValue -is [long]) { [int]$Value }
    elseif ($currentValue -is [bool]) { [System.Convert]::ToBoolean($Value) }
    else { $Value }

    if ($Key -eq 'copyMode') {
        $newValue = $newValue.ToLowerInvariant()
        if ($newValue -notin @('copy', 'move')) {
            throw "Invalid copy mode '$newValue'. Must be 'copy' or 'move'."
        }
    }

    if ($Key -eq 'targetRoot') {
        Assert-TaggerPathWritable -Path $newValue
    }

    $settings.$Key = $newValue

    $settingsPath = Join-Path $DataHome 'settings.json'
    Set-TaggerJsonFile -Path $settingsPath -InputObject $settings -SchemaName settings | Out-Null

    return $settings
}

function New-TaggerSession {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$SourceRoot,

        [string]$RecognitionPath,

        [string]$DataHome
    )

    if (-not $DataHome) {
        $DataHome = Resolve-TaggerDataHome
    }

    $sessionDir = $null
    $sessionId = $null
    $maxAttempts = 5
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        $candidateId = New-TaggerSessionId -DataHome $DataHome
        $candidateDir = Join-Path $DataHome 'sessions' $candidateId
        try {
            New-Item -ItemType Directory -Path $candidateDir -ErrorAction Stop | Out-Null
            $sessionId = $candidateId
            $sessionDir = $candidateDir
            break
        }
        catch {
            continue
        }
    }
    if (-not $sessionDir) {
        throw "Could not allocate a new session id after $maxAttempts attempts (concurrent session creation?)."
    }

    if (-not $RecognitionPath) {
        $RecognitionPath = Join-Path $sessionDir 'recognition.json'
    }

    $now = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $session = [pscustomobject]@{
        sessionId       = $sessionId
        sourceRoot      = $SourceRoot
        createdAtUtc    = $now
        updatedAtUtc    = $now
        stage           = 'recognized'
        recognitionPath = $RecognitionPath
        proposalPath    = $null
    }

    $sessionFile = Join-Path $sessionDir 'session.json'
    Set-TaggerJsonFile -Path $sessionFile -InputObject $session -SchemaName session | Out-Null

    return $session
}

function Read-TaggerSessionFile {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-TaggerJson -SchemaName session -Path $Path)) {
        throw "Session file at '$Path' does not match the session schema."
    }

    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Get-TaggerSession {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string]$SessionId,

        [string]$DataHome
    )

    if (-not $DataHome) {
        $DataHome = Resolve-TaggerDataHome
    }

    $sessionsDir = Join-Path $DataHome 'sessions'

    if ($SessionId) {
        $sessionFile = Join-Path $sessionsDir $SessionId 'session.json'
        if (-not (Test-Path -LiteralPath $sessionFile -PathType Leaf)) {
            throw "Session '$SessionId' not found."
        }
        return Read-TaggerSessionFile -Path $sessionFile
    }

    if (-not (Test-Path -LiteralPath $sessionsDir)) {
        return @()
    }

    $sessions = foreach ($dir in Get-ChildItem -LiteralPath $sessionsDir -Directory) {
        $sessionFile = Join-Path $dir.FullName 'session.json'
        if (Test-Path -LiteralPath $sessionFile -PathType Leaf) {
            Read-TaggerSessionFile -Path $sessionFile
        }
    }

    return @($sessions | Sort-Object -Property updatedAtUtc -Descending)
}

function Resume-TaggerSession {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$SessionId,

        [string]$DataHome
    )

    $session = Get-TaggerSession -SessionId $SessionId -DataHome $DataHome

    $nextCommand = switch ($session.stage) {
        'recognized' { "Tagger.ps1 propose -SessionId $SessionId" }
        'proposed' { 'Open the editing UI (see plan/07-editing-ui-module.md) to review proposal.json' }
        'reviewed' { "Tagger.ps1 apply -SessionId $SessionId" }
        'applied' { 'Nothing - session complete.' }
        'partially-applied' { "Tagger.ps1 apply -SessionId $SessionId" }
        default { throw "Unknown session stage '$($session.stage)' for session '$SessionId'." }
    }

    return [pscustomobject]@{
        SessionId   = $SessionId
        Stage       = $session.stage
        NextCommand = $nextCommand
    }
}

function Complete-TaggerSession {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$SessionId,

        [string]$DataHome
    )

    if (-not $DataHome) {
        $DataHome = Resolve-TaggerDataHome
    }

    $session = Get-TaggerSession -SessionId $SessionId -DataHome $DataHome
    $session.stage = 'applied'
    $session.updatedAtUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')

    $sessionFile = Join-Path $DataHome 'sessions' $SessionId 'session.json'
    Set-TaggerJsonFile -Path $sessionFile -InputObject $session -SchemaName session | Out-Null

    return $session
}

Export-ModuleMember -Function Get-TaggerSettings, Initialize-TaggerSettings, Set-TaggerSettings, `
    New-TaggerSession, Resume-TaggerSession, Complete-TaggerSession, Get-TaggerSession
