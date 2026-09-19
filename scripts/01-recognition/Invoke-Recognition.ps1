#Requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$SourceRoot,

    [Parameter(Mandatory)]
    [string]$SessionId,

    [string]$DataHome,

    [string]$OverridesPath,

    [string]$TagLibSharpPath
)

Import-Module (Join-Path $PSScriptRoot '..' 'common' 'Tagger.Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..' 'common' 'Tagger.Json.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..' 'common' 'Tagger.Recognition.psm1') -Force

Invoke-TaggerRecognition -SourceRoot $SourceRoot -SessionId $SessionId -DataHome $DataHome -OverridesPath $OverridesPath -TagLibSharpPath $TagLibSharpPath
