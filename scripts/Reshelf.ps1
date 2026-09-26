#Requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateSet('settings', 'session', 'recognize', 'propose', 'apply', 'lossy', 'ui')]
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
    [string]$OverridesPath,
    [ValidateSet('pending-upgrade', 'upgraded', 'ignored')]
    [string]$Status,
    [int]$Port,
    [switch]$IncludeUnresolved,
    [switch]$WhatIf
)

Import-Module (Join-Path $PSScriptRoot 'common' 'Reshelf.Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'common' 'Reshelf.Json.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'common' 'Reshelf.Settings.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'common' 'Reshelf.Recognition.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'common' 'Reshelf.Discogs.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'common' 'Reshelf.EditProposal.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'common' 'Reshelf.Implementation.psm1') -Force
# Re-imported last: Reshelf.EditProposal.psm1 and Reshelf.Implementation.psm1 both import this module
# internally too, which reparents it as one of their nested modules and hides its exports from this
# script's scope - importing it again here restores top-level visibility for the 'lossy' command.
Import-Module (Join-Path $PSScriptRoot 'common' 'Reshelf.LossyTracking.psm1') -Force

switch ($Command) {
    'settings' {
        switch ($SubCommand) {
            'show' { Get-ReshelfSettings | ConvertTo-Json -Depth 10 }
            'init' {
                Initialize-ReshelfSettings -TargetRoot $TargetRoot -DefaultSourceRoot $DefaultSourceRoot -CopyMode $CopyMode -Force:$Force |
                    ConvertTo-Json -Depth 10
            }
            'set' { Set-ReshelfSettings -Key $Key -Value $Value | ConvertTo-Json -Depth 10 }
            'set-token' { Set-ReshelfDiscogsToken | ConvertTo-Json -Depth 10 }
            default { throw "Unknown 'settings' subcommand '$SubCommand'. Use show, init, set, or set-token." }
        }
    }
    'session' {
        switch ($SubCommand) {
            'list' { Get-ReshelfSession | Select-Object sessionId, stage, sourceRoot, updatedAtUtc | Format-Table }
            'show' {
                if (-not $SessionId) { throw "'session show' requires a session id." }
                Get-ReshelfSession -SessionId $SessionId | ConvertTo-Json -Depth 10
            }
            'resume' {
                if (-not $SessionId) { throw "'session resume' requires a session id." }
                Resume-ReshelfSession -SessionId $SessionId | Format-List
            }
            'mark-reviewed' {
                if (-not $SessionId) { throw "'session mark-reviewed' requires a session id." }
                $settings = Get-ReshelfSettings
                Set-ReshelfSessionStage -SessionId $SessionId -Stage 'reviewed' -DataHome $settings.dataHome | Out-Null
                Get-ReshelfSession -SessionId $SessionId -DataHome $settings.dataHome | Format-List
            }
            default { throw "Unknown 'session' subcommand '$SubCommand'. Use list, show, resume, or mark-reviewed." }
        }
    }
    'recognize' {
        $settings = Get-ReshelfSettings
        $resolvedSourceRoot = if ($SourceRoot) { $SourceRoot } else { $settings.defaultSourceRoot }
        if (-not $resolvedSourceRoot) {
            throw "No source root given and no defaultSourceRoot configured. Pass -SourceRoot, or run 'Reshelf.ps1 settings set -Key defaultSourceRoot -Value <path>'."
        }

        if ($SaveAsDefault -and $SourceRoot) {
            Set-ReshelfSettings -Key defaultSourceRoot -Value $SourceRoot | Out-Null
        }

        $session = New-ReshelfSession -SourceRoot $resolvedSourceRoot
        try {
            $result = Invoke-ReshelfRecognition -SourceRoot $resolvedSourceRoot -SessionId $session.sessionId -OverridesPath $OverridesPath -TagLibSharpPath $settings.taglibSharpPath
        }
        catch {
            throw "Recognition failed for session '$($session.sessionId)': $($_.Exception.Message) The session was created but has no recognition.json - fix the issue and run 'Reshelf.ps1 recognize -SourceRoot $resolvedSourceRoot' again (this starts a new session)."
        }

        [pscustomobject]@{
            SessionId        = $session.sessionId
            ArtistCount      = $result.artists.Count
            ReleaseCount     = ($result.artists.releases | Measure-Object).Count
            UnrecognizedCount = $result.unrecognized.Count
        } | Format-List
    }
    'propose' {
        if (-not $SessionId) {
            throw "'propose' requires a session id. Usage: Reshelf.ps1 propose -SessionId <id>"
        }

        $settings = Get-ReshelfSettings
        $dataHome = $settings.dataHome
        $session = Get-ReshelfSession -SessionId $SessionId -DataHome $dataHome

        try {
            $result = Invoke-ReshelfEditProposal -SessionId $SessionId -RecognitionPath $session.recognitionPath `
                -TargetRoot $settings.targetRoot -ReleaseFolderTemplate $settings.namingTemplates.releaseFolder `
                -TrackFileTemplate $settings.namingTemplates.trackFile -TrackNumberPadWidth $settings.trackNumberPadWidth `
                -CoverMaxDimension $settings.coverMaxDimension `
                -CacheTtlDays $settings.cacheTtlDays -RateLimitPerMinute $settings.rateLimitPerMinute -DataHome $dataHome
        }
        catch {
            throw "Edit proposal failed for session '$SessionId': $($_.Exception.Message)"
        }

        $proposalPath = Join-Path $dataHome 'sessions' $SessionId 'proposal.json'
        Set-ReshelfSessionStage -SessionId $SessionId -Stage 'proposed' -ProposalPath $proposalPath -DataHome $dataHome | Out-Null

        $releases = @($result.artists.releases)
        [pscustomobject]@{
            SessionId        = $SessionId
            ArtistCount      = $result.artists.Count
            ReleaseCount     = $releases.Count
            MatchedCount     = @($releases | Where-Object { $_.discogsMatch.status -eq 'matched' }).Count
            NeedsReviewCount = @($releases | Where-Object { $_.humanReview.required }).Count
        } | Format-List
    }
    'apply' {
        if (-not $SessionId) {
            throw "'apply' requires a session id. Usage: Reshelf.ps1 apply -SessionId <id>"
        }

        $settings = Get-ReshelfSettings
        $dataHome = $settings.dataHome
        $session = Get-ReshelfSession -SessionId $SessionId -DataHome $dataHome

        $result = Invoke-ReshelfImplementation -SessionId $SessionId -ProposalPath $session.proposalPath `
            -TargetRoot $settings.targetRoot -CopyMode $settings.copyMode -FfmpegPath $settings.ffmpegPath `
            -TagLibSharpPath $settings.taglibSharpPath -DataHome $dataHome -IncludeUnresolved:$IncludeUnresolved -WhatIf:$WhatIf

        [pscustomobject]@{
            SessionId = $SessionId
            Applied   = $result.Applied
            Skipped   = $result.Skipped
            Rejected  = $result.Rejected
            Failed    = $result.Failed
        } | Format-List
    }
    'ui' {
        switch ($SubCommand) {
            'start' {
                $uiServerScript = Join-Path $PSScriptRoot 'Start-ReshelfUiServer.ps1'
                if ($Port) { & $uiServerScript -Port $Port } else { & $uiServerScript }
            }
            default { throw "Unknown 'ui' subcommand '$SubCommand'. Use start." }
        }
    }
    'lossy' {
        switch ($SubCommand) {
            'list' {
                $ledger = @(Get-ReshelfLossyTrackingLedger)
                if ($Status) { $ledger = @($ledger | Where-Object { $_.status -eq $Status }) }
                $ledger | Select-Object stableKey, artist, album, year, format, status, targetPath | Format-Table
            }
            'ignore' {
                $stableKey = $SessionId
                if (-not $stableKey) { throw "'lossy ignore' requires a stable key." }
                Set-ReshelfLossyTrackingIgnored -StableKey $stableKey | Out-Null
            }
            'mark-upgraded' {
                $stableKey = $SessionId
                if (-not $stableKey) { throw "'lossy mark-upgraded' requires a stable key." }
                Set-ReshelfLossyTrackingUpgraded -StableKey $stableKey | Out-Null
            }
            default { throw "Unknown 'lossy' subcommand '$SubCommand'. Use list, ignore, or mark-upgraded." }
        }
    }
    # No 'default' branch here: $Command's own [ValidateSet] above already rejects any value not
    # listed in this switch before the script body ever runs, so one could never be reached.
}
