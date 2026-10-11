#Requires -Version 7.4
<#
    .SYNOPSIS
    Generates a library-map.schema.json document for one of your two library states
    (e.g. "before" and "after") by reusing legacy's recognition pipeline, read-only.

    .EXAMPLE
    ./New-ReshelfLibraryMap.ps1 -LibraryRoot 'D:\Music' -Label before

    .EXAMPLE
    ./New-ReshelfLibraryMap.ps1 -Label after
    # Resolves the root from tools/library-mapper/config/settings.local.json's "afterRoot".

    .EXAMPLE
    ./New-ReshelfLibraryMap.ps1 -LibraryRoot 'F:\' -Label before -ExcludeTopLevelName 'DCIM','Download','Android'
    # Skips those top-level folders entirely - never walked, never recognized.
#>
[CmdletBinding()]
param(
    [string]$LibraryRoot,

    [Parameter(Mandatory)]
    [string]$Label,

    [string]$OutputPath,

    [string]$DataHome,

    [string]$TagLibSharpPath,

    [string[]]$ExcludeTopLevelName,

    [switch]$Force
)

$scriptsRoot = $PSScriptRoot
$toolRoot = (Resolve-Path (Join-Path $scriptsRoot '..')).Path
$repoRoot = (Resolve-Path (Join-Path $toolRoot '..' '..')).Path

Import-Module (Join-Path $scriptsRoot 'common' 'ReshelfLibraryMapper.Settings.psm1') -Force
Import-Module (Join-Path $scriptsRoot 'common' 'ReshelfLibraryMapper.Build.psm1') -Force

$settings = Get-LibraryMapperSettings -ToolRoot $toolRoot

if (-not $LibraryRoot) {
    $rootSettingName = "${Label}Root"
    $LibraryRoot = $settings.$rootSettingName
    if (-not $LibraryRoot) {
        throw "No -LibraryRoot given and settings has no '$rootSettingName' configured. " +
            "Pass -LibraryRoot, or add '$rootSettingName' to tools/library-mapper/config/settings.local.json."
    }
}

if (-not $OutputPath) {
    $OutputPath = Join-Path $repoRoot 'local' 'maps' "$Label.library-map.json"
}

if (-not $DataHome) {
    $dataHomeRoot = if ($settings.dataHomeRoot) { $settings.dataHomeRoot } else { 'local/.data' }
    $DataHome = Join-Path $repoRoot $dataHomeRoot $Label
}

if (-not $TagLibSharpPath) {
    $TagLibSharpPath = $settings.taglibSharpPath
}

if ((Test-Path -LiteralPath $OutputPath -PathType Leaf) -and -not $Force) {
    throw "Output file '$OutputPath' already exists. Pass -Force to overwrite."
}

$writtenPath = New-ReshelfLibraryMap -LibraryRoot $LibraryRoot -Label $Label -OutputPath $OutputPath `
    -DataHome $DataHome -TagLibSharpPath $TagLibSharpPath -ExcludeTopLevelName $ExcludeTopLevelName

Write-Host "Library map for '$Label' written to: $writtenPath"
