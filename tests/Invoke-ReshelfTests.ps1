#Requires -Version 7.4

<#
.SYNOPSIS
    Runs the Reshelf Pester test suite.
.DESCRIPTION
    Thin wrapper around Invoke-Pester with two deliberate conveniences:
    -SkipIntegration excludes tests/Reshelf.TagLibSharp.Integration.Tests.ps1 (tag 'Integration'),
    which needs a real TagLibSharp.dll and a real ffmpeg on the machine running the tests and
    fails (not skips) if either is missing - see plan/11-testing-and-verification-strategy.md.
    -IncludeUi additionally runs the Playwright UI suite (tests/ui) after the Pester tests pass -
    see plan/11's "UI verification" section. It needs a one-time `npm install` and
    `npx playwright install chromium` inside tests/ui first; the default (Pester-only) path needs
    no Node at all, so -IncludeUi is opt-in rather than automatic.
.PARAMETER SkipIntegration
    Excludes the 'Integration'-tagged tests.
.PARAMETER IncludeUi
    Also runs the Playwright UI suite in tests/ui, after the Pester tests pass. Skipped (with a
    warning, not a failure) if tests/ui/node_modules is missing - run `npm install` there first.
.PARAMETER Path
    Test file(s)/folder(s) to run. Defaults to this script's own folder (tests/). Ignored by the
    -IncludeUi Playwright step, which always runs its own full suite.
.EXAMPLE
    pwsh tests/Invoke-ReshelfTests.ps1 -SkipIntegration
.EXAMPLE
    pwsh tests/Invoke-ReshelfTests.ps1
.EXAMPLE
    pwsh tests/Invoke-ReshelfTests.ps1 -IncludeUi
#>
[CmdletBinding()]
param(
    [switch]$SkipIntegration,

    [switch]$IncludeUi,

    [string[]]$Path = $PSScriptRoot
)

Import-Module Pester -MinimumVersion 5.0

$config = New-PesterConfiguration
$config.Run.Path = $Path
# Exit is set below, once it's known whether a Playwright step still needs to run after this -
# Run.Exit = $true would end the process immediately on Invoke-Pester returning, before -IncludeUi
# ever got a chance to run.
$config.Run.Exit = $false
$config.Run.PassThru = $true
$config.Output.Verbosity = 'Detailed'

if ($SkipIntegration) {
    $config.Filter.ExcludeTag = 'Integration'
}

$pesterResult = Invoke-Pester -Configuration $config
$pesterFailed = $pesterResult.FailedCount -gt 0

if (-not $IncludeUi) {
    exit ($pesterFailed ? 1 : 0)
}

if ($pesterFailed) {
    Write-Warning 'Pester tests failed - skipping the Playwright UI suite.'
    exit 1
}

$uiDir = Join-Path $PSScriptRoot 'ui'
$uiNodeModules = Join-Path $uiDir 'node_modules'
if (-not (Test-Path -LiteralPath $uiNodeModules -PathType Container)) {
    Write-Warning "tests/ui/node_modules not found - run 'npm install' (and 'npx playwright install chromium') in tests/ui first. Skipping the UI suite."
    exit 0
}

Push-Location $uiDir
try {
    & npx playwright test
    $playwrightExitCode = $LASTEXITCODE
}
finally {
    Pop-Location
}

exit $playwrightExitCode
