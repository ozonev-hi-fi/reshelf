#Requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateSet('settings', 'session', 'recognize', 'propose', 'apply', 'lossy')]
    [string]$Command,

    [Parameter(Position = 1)]
    [string]$SubCommand,

    [Parameter(Position = 2)]
    [string]$SessionId,

    [string]$Key,
    [string]$Value,
    [string]$TargetRoot,
    [string]$DefaultSourceRoot,
    [string]$CopyMode,
    [switch]$Force,
    [string]$SourceRoot,
    [switch]$SaveAsDefault,
    [string]$OverridesPath
)

Import-Module (Join-Path $PSScriptRoot 'common' 'Tagger.Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'common' 'Tagger.Json.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'common' 'Tagger.Settings.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'common' 'Tagger.Recognition.psm1') -Force

switch ($Command) {
    'settings' {
        switch ($SubCommand) {
            'show' { Get-TaggerSettings | ConvertTo-Json -Depth 10 }
            'init' {
                Initialize-TaggerSettings -TargetRoot $TargetRoot -DefaultSourceRoot $DefaultSourceRoot -CopyMode $CopyMode -Force:$Force |
                    ConvertTo-Json -Depth 10
            }
            'set' { Set-TaggerSettings -Key $Key -Value $Value | ConvertTo-Json -Depth 10 }
            default { throw "Unknown 'settings' subcommand '$SubCommand'. Use show, init, or set." }
        }
    }
    'session' {
        switch ($SubCommand) {
            'list' { Get-TaggerSession | Select-Object sessionId, stage, sourceRoot, updatedAtUtc | Format-Table }
            'show' {
                if (-not $SessionId) { throw "'session show' requires a session id." }
                Get-TaggerSession -SessionId $SessionId | ConvertTo-Json -Depth 10
            }
            'resume' {
                if (-not $SessionId) { throw "'session resume' requires a session id." }
                Resume-TaggerSession -SessionId $SessionId | Format-List
            }
            default { throw "Unknown 'session' subcommand '$SubCommand'. Use list, show, or resume." }
        }
    }
    'recognize' {
        $settings = Get-TaggerSettings
        $resolvedSourceRoot = if ($SourceRoot) { $SourceRoot } else { $settings.defaultSourceRoot }
        if (-not $resolvedSourceRoot) {
            throw "No source root given and no defaultSourceRoot configured. Pass -SourceRoot, or run 'Tagger.ps1 settings set -Key defaultSourceRoot -Value <path>'."
        }

        if ($SaveAsDefault -and $SourceRoot) {
            Set-TaggerSettings -Key defaultSourceRoot -Value $SourceRoot | Out-Null
        }

        $session = New-TaggerSession -SourceRoot $resolvedSourceRoot
        try {
            $result = Invoke-TaggerRecognition -SourceRoot $resolvedSourceRoot -SessionId $session.sessionId -OverridesPath $OverridesPath -TagLibSharpPath $settings.taglibSharpPath
        }
        catch {
            throw "Recognition failed for session '$($session.sessionId)': $($_.Exception.Message) The session was created but has no recognition.json - fix the issue and run 'Tagger.ps1 recognize -SourceRoot $resolvedSourceRoot' again (this starts a new session)."
        }

        [pscustomobject]@{
            SessionId        = $session.sessionId
            ArtistCount      = $result.artists.Count
            ReleaseCount     = ($result.artists.releases | Measure-Object).Count
            UnrecognizedCount = $result.unrecognized.Count
        } | Format-List
    }
    default {
        Write-Warning "'$Command' is not implemented yet - see plan/05, 06, 08, or 09."
        exit 1
    }
}
