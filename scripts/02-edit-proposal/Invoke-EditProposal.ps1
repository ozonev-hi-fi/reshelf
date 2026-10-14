#Requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$SessionId,

    [Parameter(Mandatory)]
    [string]$RecognitionPath,

    [Parameter(Mandatory)]
    [string]$TargetRoot,

    [string]$DataHome,

    [string]$ReleaseFolderTemplate = '{year} {album}',

    [string]$TrackFileTemplate = '{trackNumber} {title}',

    [int]$TrackNumberPadWidth = 2,

    [int]$CoverMaxDimension = 600,

    [int]$CacheTtlDays = 30,

    [int]$RateLimitPerMinute = 55,

    [string]$ProposalPath
)

Import-Module (Join-Path $PSScriptRoot '..' 'common' 'Reshelf.Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..' 'common' 'Reshelf.Json.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..' 'common' 'Reshelf.Discogs.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..' 'common' 'Reshelf.LossyTracking.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..' 'common' 'Reshelf.EditProposal.psm1') -Force

Invoke-ReshelfEditProposal -SessionId $SessionId -RecognitionPath $RecognitionPath -TargetRoot $TargetRoot -DataHome $DataHome `
    -ReleaseFolderTemplate $ReleaseFolderTemplate -TrackFileTemplate $TrackFileTemplate -TrackNumberPadWidth $TrackNumberPadWidth `
    -CoverMaxDimension $CoverMaxDimension `
    -CacheTtlDays $CacheTtlDays -RateLimitPerMinute $RateLimitPerMinute -ProposalPath $ProposalPath
