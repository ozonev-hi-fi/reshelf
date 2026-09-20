#Requires -Version 7.4

$script:TaggerAudioExtensions = @('.flac', '.mp3', '.m4a', '.wav', '.ogg', '.wma', '.aac', '.ape')
$script:TaggerInvalidFileNameChars = [System.IO.Path]::GetInvalidFileNameChars() + @('<', '>', ':', '"', '/', '\', '|', '?', '*')
$script:TaggerReservedDeviceNames = @('CON', 'PRN', 'AUX', 'NUL', 'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9', 'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9')

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

function Test-TaggerIsAudioExtension {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Extension
    )

    return $script:TaggerAudioExtensions -contains $Extension.ToLowerInvariant()
}

function Test-TaggerIsLosslessFormat {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Extension
    )

    $losslessExtensions = @('.flac', '.wav', '.ape', '.alac')
    return $losslessExtensions -contains $Extension.ToLowerInvariant()
}

function Get-TaggerAudioFilesInFolder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$Recurse
    )

    $params = @{ LiteralPath = $Path; File = $true; ErrorAction = 'SilentlyContinue' }
    if ($Recurse) { $params['Recurse'] = $true }

    return @(Get-ChildItem @params | Where-Object { Test-TaggerIsAudioExtension -Extension $_.Extension })
}

function ConvertFrom-TaggerTrackFileName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FileName
    )

    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($FileName)

    if ($baseName -match '^(\d+)\s*[-–]\s*(.+)$') {
        return [pscustomobject]@{ Number = [int]$Matches[1]; Title = $Matches[2].Trim(); HasNumber = $true }
    }
    if ($baseName -match '^(\d+)\s+(.+)$') {
        return [pscustomobject]@{ Number = [int]$Matches[1]; Title = $Matches[2].Trim(); HasNumber = $true }
    }

    return [pscustomobject]@{ Number = $null; Title = $baseName.Trim(); HasNumber = $false }
}

function ConvertTo-SafeFileName {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Name
    )

    $substitutions = [System.Collections.Generic.List[string]]::new()
    $result = $Name

    foreach ($invalidChar in $script:TaggerInvalidFileNameChars | Select-Object -Unique) {
        if ($result.Contains($invalidChar)) {
            $substitutions.Add("invalid character '$invalidChar' replaced with '_'")
            $result = $result.Replace([string]$invalidChar, '_')
        }
    }

    $trimmed = $result.TrimEnd('.', ' ')
    if ($trimmed -ne $result) {
        $substitutions.Add('trailing dot/space removed')
        $result = $trimmed
    }

    if ($script:TaggerReservedDeviceNames -icontains $result) {
        $substitutions.Add("reserved device name '$result' suffixed with '_'")
        $result = "${result}_"
    }

    return [pscustomobject]@{
        SafeName      = $result
        WasChanged    = ($result -ne $Name)
        Substitutions = @($substitutions)
    }
}

function Get-TaggerFileSetHash {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$FilePaths
    )

    $entries = foreach ($path in $FilePaths) {
        $item = Get-Item -LiteralPath (ConvertTo-TaggerLongPath -Path $path)
        "$($item.Name.ToLowerInvariant())|$($item.Length)"
    }

    $sorted = [string[]]@($entries)
    [Array]::Sort($sorted, [StringComparer]::Ordinal)
    $joined = $sorted -join "`n"
    return Get-TaggerSha256Hex -Text $joined
}

Export-ModuleMember -Function Resolve-TaggerDataHome, Get-TaggerStableKey, ConvertTo-TaggerLongPath, `
    ConvertTo-TaggerNormalizedText, Get-TaggerSha256Hex, Test-TaggerIsAudioExtension, Test-TaggerIsLosslessFormat, `
    Get-TaggerAudioFilesInFolder, ConvertFrom-TaggerTrackFileName, ConvertTo-SafeFileName, Get-TaggerFileSetHash
