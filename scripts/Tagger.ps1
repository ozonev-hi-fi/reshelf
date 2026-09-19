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
    [switch]$Force
)

Import-Module (Join-Path $PSScriptRoot 'common' 'Tagger.Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'common' 'Tagger.Json.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'common' 'Tagger.Settings.psm1') -Force

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
    default {
        Write-Warning "'$Command' is not implemented yet - see plan/05, 06, 08, or 09."
        exit 1
    }
}
