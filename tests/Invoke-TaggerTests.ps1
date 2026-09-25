#Requires -Version 7.4

<#
.SYNOPSIS
    Runs the Tagger Pester test suite.
.DESCRIPTION
    Thin wrapper around Invoke-Pester with one deliberate convenience: -SkipIntegration excludes
    tests/Tagger.TagLibSharp.Integration.Tests.ps1 (tag 'Integration'), which needs a real
    TagLibSharp.dll and a real ffmpeg on the machine running the tests and fails (not skips) if
    either is missing - see plan/11-testing-and-verification-strategy.md.
.PARAMETER SkipIntegration
    Excludes the 'Integration'-tagged tests.
.PARAMETER Path
    Test file(s)/folder(s) to run. Defaults to this script's own folder (tests/).
.EXAMPLE
    pwsh tests/Invoke-TaggerTests.ps1 -SkipIntegration
.EXAMPLE
    pwsh tests/Invoke-TaggerTests.ps1
#>
[CmdletBinding()]
param(
    [switch]$SkipIntegration,

    [string[]]$Path = $PSScriptRoot
)

Import-Module Pester -MinimumVersion 5.0

$config = New-PesterConfiguration
$config.Run.Path = $Path
$config.Run.Exit = $true
$config.Output.Verbosity = 'Detailed'

if ($SkipIntegration) {
    $config.Filter.ExcludeTag = 'Integration'
}

Invoke-Pester -Configuration $config
