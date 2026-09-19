#Requires -Version 7.4

function Resolve-TaggerDataHome {
    [CmdletBinding()]
    param()

    if ($env:TAGGER_HOME) {
        $dataHome = $env:TAGGER_HOME
    }
    elseif ($env:LOCALAPPDATA) {
        $dataHome = Join-Path $env:LOCALAPPDATA 'Tagger'
    }
    else {
        throw 'Cannot resolve Tagger data home: neither TAGGER_HOME nor LOCALAPPDATA is set.'
    }

    if (Test-Path -LiteralPath $dataHome) {
        if (-not (Test-Path -LiteralPath $dataHome -PathType Container)) {
            throw "Tagger data home '$dataHome' exists but is not a directory."
        }
    }
    else {
        New-Item -ItemType Directory -Path $dataHome -Force | Out-Null
    }

    return (Resolve-Path -LiteralPath $dataHome).Path
}

function ConvertTo-TaggerNormalizedText {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
    )

    $lowered = $Text.Trim().ToLowerInvariant()
    $stripped = [regex]::Replace($lowered, '[^\p{L}\p{Nd}\s]', '')
    return [regex]::Replace($stripped, '\s+', ' ').Trim()
}

function Get-TaggerSha256Hex {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
    )

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $hashBytes = [System.Security.Cryptography.SHA256]::HashData($bytes)
    return [System.Convert]::ToHexString($hashBytes).ToLowerInvariant()
}

function Get-TaggerStableKey {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Artist,

        [Parameter(Mandatory)]
        [string]$Album,

        [AllowNull()]
        [Nullable[int]]$Year
    )

    $normalizedArtist = ConvertTo-TaggerNormalizedText -Text $Artist
    $normalizedAlbum = ConvertTo-TaggerNormalizedText -Text $Album
    $normalizedYear = if ($null -eq $Year) { '' } else { [string]$Year }

    $canonical = "$normalizedArtist|$normalizedAlbum|$normalizedYear"
    return (Get-TaggerSha256Hex -Text $canonical).Substring(0, 16)
}

function ConvertTo-TaggerLongPath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [int]$Threshold = 240
    )

    if ($Path.StartsWith('\\?\')) {
        return $Path
    }

    if ($Path.Length -lt $Threshold) {
        return $Path
    }

    if ($Path.StartsWith('\\')) {
        return "\\?\UNC\" + $Path.Substring(2)
    }

    return "\\?\$Path"
}

Export-ModuleMember -Function Resolve-TaggerDataHome, Get-TaggerStableKey, ConvertTo-TaggerLongPath, `
    ConvertTo-TaggerNormalizedText, Get-TaggerSha256Hex
