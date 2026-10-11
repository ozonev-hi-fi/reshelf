#Requires -Version 7.4

function Get-LibraryMapperSettings {
    <#
        Loads tools/library-mapper/config/settings.default.json (tracked) and merges
        config/settings.local.json over it if present (gitignored, already covered by the
        repo's existing `*.local.json` rule - no contributor's real paths ever get committed).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$ToolRoot
    )

    $configDir = Join-Path $ToolRoot 'config'
    $defaultPath = Join-Path $configDir 'settings.default.json'
    $localPath = Join-Path $configDir 'settings.local.json'

    if (-not (Test-Path -LiteralPath $defaultPath -PathType Leaf)) {
        throw "Settings default file not found at '$defaultPath'."
    }

    $settings = Get-Content -LiteralPath $defaultPath -Raw | ConvertFrom-Json -AsHashtable

    if (Test-Path -LiteralPath $localPath -PathType Leaf) {
        $local = Get-Content -LiteralPath $localPath -Raw | ConvertFrom-Json -AsHashtable
        foreach ($key in $local.Keys) {
            $settings[$key] = $local[$key]
        }
    }

    return [pscustomobject]$settings
}

Export-ModuleMember -Function Get-LibraryMapperSettings
