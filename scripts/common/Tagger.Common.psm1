#Requires -Version 7.4

$script:TaggerAudioExtensions = @('.flac', '.mp3', '.m4a', '.wav', '.ogg', '.wma', '.aac', '.ape')
$script:TaggerInvalidFileNameChars = [System.IO.Path]::GetInvalidFileNameChars() + @('<', '>', ':', '"', '/', '\', '|', '?', '*')
$script:TaggerReservedDeviceNames = @('CON', 'PRN', 'AUX', 'NUL', 'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9', 'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9')

# Set once per Recognition/Implementation run (via Set-TaggerTagLibSharpContext) so the many deep,
# per-file callers of Import-TaggerTagLibSharp don't each need -TagLibSharpPath/-DataHome threaded
# all the way down their call chains.
$script:TaggerTagLibSharpPath = $null
$script:TaggerDataHome = $null

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

function ConvertTo-TaggerTruncatedSegment {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Prefix,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Body,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Suffix,

        [Parameter(Mandatory)]
        [int]$MaxLength
    )

    $full = "$Prefix$Body$Suffix"
    if ($full.Length -le $MaxLength) {
        return [pscustomobject]@{ Value = $full; Truncated = $false }
    }

    # Prefix (e.g. a "yyyy "/"NN " structural prefix) and Suffix (e.g. a file extension) are never
    # touched - only Body is shortened. A budget below 1 still keeps a single body character rather
    # than colliding Prefix directly into Suffix, so the result stays visually recognizable as
    # truncated instead of silently dropping the human-readable part entirely.
    $bodyBudget = $MaxLength - $Prefix.Length - $Suffix.Length
    if ($bodyBudget -lt 1) { $bodyBudget = 1 }
    $cutLength = [Math]::Min($bodyBudget, $Body.Length)

    # A body containing an astral-plane character (emoji, some CJK extensions) is stored as a UTF-16
    # surrogate pair - cutting between the two halves would produce a malformed/unpaired surrogate.
    # Back off by one char when the cut would land there.
    if ($cutLength -gt 0 -and $cutLength -lt $Body.Length -and [char]::IsHighSurrogate($Body[$cutLength - 1])) {
        $cutLength--
    }

    $truncatedBody = $Body.Substring(0, $cutLength).TrimEnd()

    return [pscustomobject]@{ Value = "$Prefix$truncatedBody$Suffix"; Truncated = $true }
}

function Get-TaggerRelativePath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$SourceRoot,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $normalizedRoot = $SourceRoot.TrimEnd('\', '/')
    if (-not $Path.StartsWith($normalizedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $Path
    }

    $relative = $Path.Substring($normalizedRoot.Length).TrimStart('\', '/')
    return ($relative -replace '\\', '/')
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

# --- Secrets at rest ------------------------------------------------------------
# Windows DPAPI via the built-in SecureString cmdlets - only decryptable by this Windows user, on
# this machine. Generic (not Discogs-specific): any secret this tool needs to persist should use
# these two, not hand-roll its own encoding.

function Protect-TaggerSecret {
    [CmdletBinding()]
    [OutputType([string])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '',
        Justification = 'Intentional: turning a plaintext secret into a SecureString so ConvertFrom-SecureString can DPAPI-encrypt it for storage is this function''s entire purpose.')]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$PlainText
    )

    return (ConvertTo-SecureString -String $PlainText -AsPlainText -Force) | ConvertFrom-SecureString
}

function Unprotect-TaggerSecret {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$EncryptedText
    )

    return (ConvertTo-SecureString -String $EncryptedText) | ConvertFrom-SecureString -AsPlainText
}

# --- TagLibSharp --------------------------------------------------------------
# Shared by Tagger.Recognition.psm1 (reading tags) and Tagger.Implementation.psm1 (writing tags) -
# both go through the same TagLibSharp.dll load, so there is exactly one Add-Type call site.

function Set-TaggerTagLibSharpContext {
    [CmdletBinding()]
    param(
        [string]$TagLibSharpPath,

        [string]$DataHome
    )

    $script:TaggerTagLibSharpPath = $TagLibSharpPath
    $script:TaggerDataHome = $DataHome
}

function Import-TaggerTagLibSharp {
    [CmdletBinding()]
    param(
        [string]$TagLibSharpPath,

        [string]$DataHome
    )

    if ('TagLib.File' -as [type]) {
        return
    }

    if (-not $TagLibSharpPath) { $TagLibSharpPath = $script:TaggerTagLibSharpPath }

    if (-not $TagLibSharpPath) {
        if (-not $DataHome) { $DataHome = $script:TaggerDataHome }
        if (-not $DataHome) { $DataHome = Resolve-TaggerDataHome }
        $TagLibSharpPath = Join-Path $DataHome 'lib' 'TagLibSharp.dll'
    }

    if (-not (Test-Path -LiteralPath $TagLibSharpPath -PathType Leaf)) {
        throw "TagLibSharp.dll not found at '$TagLibSharpPath'. Download the TagLibSharp NuGet package (e.g. 'dotnet add package TagLibSharp' in a throwaway project), copy TagLibSharp.dll from its lib/netstandard2.0 folder to that path, or set settings.taglibSharpPath to its location."
    }

    Add-Type -Path $TagLibSharpPath
}

Export-ModuleMember -Function Resolve-TaggerDataHome, Get-TaggerStableKey, ConvertTo-TaggerLongPath, `
    ConvertTo-TaggerNormalizedText, Get-TaggerSha256Hex, Test-TaggerIsAudioExtension, Test-TaggerIsLosslessFormat, `
    Get-TaggerAudioFilesInFolder, ConvertFrom-TaggerTrackFileName, ConvertTo-SafeFileName, Get-TaggerFileSetHash, `
    Set-TaggerTagLibSharpContext, Import-TaggerTagLibSharp, Protect-TaggerSecret, Unprotect-TaggerSecret, Get-TaggerRelativePath, `
    ConvertTo-TaggerTruncatedSegment
