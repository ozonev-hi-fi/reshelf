#Requires -Version 7.4
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$SessionId,

    [Parameter(Mandatory)]
    [string]$ProposalPath,

    [Parameter(Mandatory)]
    [string]$TargetRoot,

    [Parameter(Mandatory)]
    [ValidateSet('copy', 'move')]
    [string]$CopyMode,

    [Parameter(Mandatory)]
    [string]$FfmpegPath,

    [string]$TagLibSharpPath,

    [string]$DataHome,

    [switch]$IncludeUnresolved
)

Import-Module (Join-Path $PSScriptRoot '..' 'common' 'Tagger.Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..' 'common' 'Tagger.Json.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..' 'common' 'Tagger.Settings.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..' 'common' 'Tagger.LossyTracking.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..' 'common' 'Tagger.Implementation.psm1') -Force

Invoke-TaggerImplementation -SessionId $SessionId -ProposalPath $ProposalPath -TargetRoot $TargetRoot `
    -CopyMode $CopyMode -FfmpegPath $FfmpegPath -TagLibSharpPath $TagLibSharpPath `
    -DataHome $DataHome -IncludeUnresolved:$IncludeUnresolved -WhatIf:$WhatIfPreference
