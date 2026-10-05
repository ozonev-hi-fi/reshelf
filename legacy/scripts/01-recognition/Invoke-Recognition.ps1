#Requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$SourceRoot,

    [Parameter(Mandatory)]
    [string]$SessionId,

    [string]$DataHome,

    [string]$TagLibSharpPath
)

Import-Module (Join-Path $PSScriptRoot '..' 'common' 'Reshelf.Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..' 'common' 'Reshelf.Json.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..' 'common' 'Reshelf.Recognition.psm1') -Force

Invoke-ReshelfRecognition -SourceRoot $SourceRoot -SessionId $SessionId -DataHome $DataHome -TagLibSharpPath $TagLibSharpPath
