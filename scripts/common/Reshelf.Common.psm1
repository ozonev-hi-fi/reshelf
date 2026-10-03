#Requires -Version 7.4

$script:ReshelfAudioExtensions = @('.flac', '.mp3', '.m4a', '.wav', '.ogg', '.wma', '.aac', '.ape', '.mpc')
$script:ReshelfInvalidFileNameChars = [System.IO.Path]::GetInvalidFileNameChars() + @('<', '>', ':', '"', '/', '\', '|', '?', '*')
$script:ReshelfReservedDeviceNames = @('CON', 'PRN', 'AUX', 'NUL', 'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9', 'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9')

# Set once per Recognition/Implementation run (via Set-ReshelfTagLibSharpContext) so the many deep,
# per-file callers of Import-ReshelfTagLibSharp don't each need -TagLibSharpPath/-DataHome threaded
# all the way down their call chains.
$script:ReshelfTagLibSharpPath = $null
$script:ReshelfDataHome = $null

function Resolve-ReshelfDataHome {
    [CmdletBinding()]
    param()

    # Default is a git-ignored '.data' folder inside the repo (same $PSScriptRoot '..' '..' pattern
    # Reshelf.Json.psm1 and Reshelf.Settings.psm1 use for schemas/config) - keeps all generated/user
    # data next to the code instead of scattered in the profile, while staying untracked by git.
    # RESHELF_HOME still overrides this for anyone who wants a different location.
    if ($env:RESHELF_HOME) {
        $dataHome = $env:RESHELF_HOME
    }
    else {
        $dataHome = Join-Path $PSScriptRoot '..' '..' '.data'
    }

    if (Test-Path -LiteralPath $dataHome) {
        if (-not (Test-Path -LiteralPath $dataHome -PathType Container)) {
            throw "Reshelf data home '$dataHome' exists but is not a directory."
        }
    }
    else {
        New-Item -ItemType Directory -Path $dataHome -Force | Out-Null
    }

    return (Resolve-Path -LiteralPath $dataHome).Path
}

function ConvertTo-ReshelfNormalizedText {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
    )

    # NFKC first: folds "compatibility" forms (most visibly, full-width Latin letters/digits used in
    # Japanese releases, e.g. "ＢＢ") down to their ordinary form before casing/stripping - without
    # it, a full-width "ＢＢ" and plain "bb" score as two completely different strings even though
    # they're the same text to a human.
    $normalizedForm = $Text.Trim().Normalize([System.Text.NormalizationForm]::FormKC)
    $lowered = $normalizedForm.ToLowerInvariant()
    $stripped = [regex]::Replace($lowered, '[^\p{L}\p{Nd}\s]', '')
    return [regex]::Replace($stripped, '\s+', ' ').Trim()
}

function Test-ReshelfHasJapaneseScript {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
    )

    # Hiragana, Katakana, CJK ideographs (kanji) and half-width Katakana (U+FF66-FF9F) - enough to
    # recognize a Japanese release title/artist credit without pulling in a full script-detection
    # library. CJK ideographs alone could in principle be Chinese, but in this collection they only
    # ever show up as kanji inside a Japanese title, so treating them as "Japanese" here is fine.
    return [bool]([regex]::IsMatch($Text, '[\p{IsHiragana}\p{IsKatakana}\p{IsCJKUnifiedIdeographs}ｦ-ﾟ]'))
}

function Test-ReshelfIsRomanizedText {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
    if (Test-ReshelfHasJapaneseScript -Text $Text) { return $false }
    return [bool]([regex]::IsMatch($Text, '\p{L}'))
}

function Join-ReshelfBilingualName {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [string]$Romanized,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Original
    )

    # Discogs' own convention for a Japanese release is "{Romanized} = {Original}" (e.g. "Rokkinpo
    # Goroshi = ロッキンポ殺し") - this only ever adds a romanized half the encyclopedia itself didn't
    # already give, never replaces or reformats what Discogs returned. The spacing around "=" isn't
    # even consistent in Discogs' own text (real case: "...「F」= 爪爪爪..." has no space before it but
    # one after), so this only checks for the character itself, not a fixed " = " shape.
    if ($Original.Contains('=')) { return $Original }
    if (-not (Test-ReshelfHasJapaneseScript -Text $Original)) { return $Original }
    if (-not (Test-ReshelfIsRomanizedText -Text $Romanized)) { return $Original }

    return "$Romanized = $Original"
}

function ConvertTo-ReshelfCueTimestampSeconds {
    [CmdletBinding()]
    [OutputType([double])]
    param(
        [Parameter(Mandatory)]
        [string]$CueTimestamp
    )

    # A cue sheet's INDEX 01 timestamp is MM:SS:FF - minutes, seconds, CD-audio frames
    # (00-74, 75 frames/sec), NOT HH:MM:SS.
    $parts = $CueTimestamp -split ':'
    $minutes = [int]$parts[0]
    $seconds = [int]$parts[1]
    $frames = [int]$parts[2]
    return [Math]::Round((($minutes * 60) + $seconds + ($frames / 75.0)), 3)
}

function Get-ReshelfSha256Hex {
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

function Get-ReshelfStableKey {
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

    $normalizedArtist = ConvertTo-ReshelfNormalizedText -Text $Artist
    $normalizedAlbum = ConvertTo-ReshelfNormalizedText -Text $Album
    $normalizedYear = if ($null -eq $Year) { '' } else { [string]$Year }

    $canonical = "$normalizedArtist|$normalizedAlbum|$normalizedYear"
    return (Get-ReshelfSha256Hex -Text $canonical).Substring(0, 16)
}

function Remove-ReshelfInvisibleCharacters {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
    )

    # Real case (plan/12 milestone 3): Discogs returned a release title containing zero-width
    # spaces around a dash ("B​-​Sides"), invisible in the browser/UI but embedded
    # verbatim into file/folder names and tags if left untouched. \p{Cf} (Unicode "format" category)
    # covers zero-width space/non-joiner/joiner, the byte-order mark, and similar invisible marks.
    return [regex]::Replace($Text, '\p{Cf}', '')
}

function ConvertTo-ReshelfTitleCase {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
    )

    # Deliberately minimal: only the first letter of each whitespace-separated word is
    # uppercased, and nothing else is touched - preserves existing internal casing that's
    # meaningful (e.g. "DJ", "McDonald") instead of a full Title Case library's word-list guessing.
    # Only ever applied to a name with no Discogs (or, later, Bandcamp) match - those encyclopedias
    # are trusted for casing (e.g. "edbl" stays lowercase when Discogs itself says so).
    return [regex]::Replace($Text, '(?<=^|\s)(\p{Ll})', { param($m) $m.Value.ToUpperInvariant() })
}

function ConvertTo-ReshelfLongPath {
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

function Test-ReshelfIsAudioExtension {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # AllowEmptyString: a file with no extension at all (e.g. a stray companion file) is a
        # legitimate, non-crashing input here - it's simply never audio. Without this attribute,
        # PowerShell's binder rejects '' outright for a Mandatory string parameter.
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Extension
    )

    return $script:ReshelfAudioExtensions -contains $Extension.ToLowerInvariant()
}

function Test-ReshelfIsLosslessFormat {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Extension
    )

    $losslessExtensions = @('.flac', '.wav', '.ape', '.alac')
    return $losslessExtensions -contains $Extension.ToLowerInvariant()
}

function Get-ReshelfAudioFilesInFolder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$Recurse
    )

    $params = @{ LiteralPath = $Path; File = $true; ErrorAction = 'SilentlyContinue' }
    if ($Recurse) { $params['Recurse'] = $true }

    return @(Get-ChildItem @params | Where-Object { Test-ReshelfIsAudioExtension -Extension $_.Extension })
}

function ConvertFrom-ReshelfTrackFileName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FileName
    )

    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($FileName)

    $number = $null
    $title = $baseName.Trim()
    if ($baseName -match '^(\d+)\s*[-–]\s*(.+)$' -or $baseName -match '^(\d+)\s+(.+)$') {
        $number = [int]$Matches[1]
        $title = $Matches[2].Trim()
    }
    # "[01] Title" / "(01) Title" (real case: a Various-Artists rip named "[01] Blind Guardian -
    # Don't Talk To Stranger.mp3"). At most 3 digits, so a leading "(1999) ..." year group is
    # never read as a track number.
    elseif ($baseName -match '^[\[\(](\d{1,3})[\]\)]\s*(?:[-–]\s*)?(.+)$') {
        $number = [int]$Matches[1]
        $title = $Matches[2].Trim()
    }

    # A possible "Artist - Title" split of the title, e.g. "Blind Guardian - Don't Talk To
    # Stranger". Only a candidate - a single-artist title can have a dash too ("Song - Live"), so
    # callers decide when to trust it (Reshelf.EditProposal's Various-Artists evidence uses it only
    # when every track of a release has one).
    $artistPart = $null
    $titlePart = $null
    if ($title -match '^(.+?)\s+[-–]\s+(.+)$') {
        $artistPart = $Matches[1].Trim()
        $titlePart = $Matches[2].Trim()
    }

    return [pscustomobject]@{
        Number     = $number
        Title      = $title
        HasNumber  = ($null -ne $number)
        ArtistPart = $artistPart
        TitlePart  = $titlePart
    }
}

function ConvertTo-SafeFileName {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Name,

        [string]$Context = ''
    )

    $prefix = if ($Context) { "${Context}: " } else { '' }
    $substitutions = [System.Collections.Generic.List[string]]::new()
    $result = $Name

    foreach ($invalidChar in $script:ReshelfInvalidFileNameChars | Select-Object -Unique) {
        if ($result.Contains($invalidChar)) {
            $substitutions.Add("${prefix}invalid character '$invalidChar' replaced with '_'")
            $result = $result.Replace([string]$invalidChar, '_')
        }
    }

    $trimmed = $result.TrimEnd('.', ' ')
    if ($trimmed -ne $result) {
        $substitutions.Add("${prefix}trailing dot/space removed")
        $result = $trimmed
    }

    # Win32 reserves a device name even with an extension after it ("CON.flac", "nul.tar.gz"), so
    # only the part before the first dot is checked; the suffix goes right after that part so the
    # extension survives unchanged.
    $dotIndex = $result.IndexOf('.')
    $stem = if ($dotIndex -ge 0) { $result.Substring(0, $dotIndex) } else { $result }
    if ($script:ReshelfReservedDeviceNames -icontains $stem) {
        $substitutions.Add("${prefix}reserved device name '$stem' suffixed with '_'")
        $result = "${stem}_" + $result.Substring($stem.Length)
    }

    return [pscustomobject]@{
        SafeName      = $result
        WasChanged    = ($result -ne $Name)
        Substitutions = @($substitutions)
    }
}

function Test-ReshelfLooseCompanionFileName {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$FileName
    )

    # Manifesto SS4.5: a loose companion (directly in the release folder, next to numbered
    # tracks) must start with a letter, so normal alphabetical sorting in a file explorer
    # always puts tracks first. \p{L} covers non-ASCII letters (e.g. Cyrillic) too, not just A-Z.
    return $FileName -match '^\p{L}'
}

# Kind -> the word prefixed onto a loose companion file name that doesn't start with a letter,
# so the result both satisfies Test-ReshelfLooseCompanionFileName and stays human-readable about
# what the file actually is (a plain '_' prefix, the old behavior, gave no such hint and also
# broke manifesto SS4.5: Explorer sorts '_' *before* digits, so it would still sort above tracks).
$script:ReshelfCompanionKindPrefixWords = @{
    cover   = 'Cover'
    booklet = 'Booklet'
    photo   = 'Photo'
    lyrics  = 'Lyrics'
    other   = 'Extra'
}

function Get-ReshelfLooseCompanionFileName {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$FileName,

        [Parameter(Mandatory)]
        [string]$Kind
    )

    $safe = (ConvertTo-SafeFileName -Name $FileName).SafeName

    if (Test-ReshelfLooseCompanionFileName -FileName $safe) {
        return [pscustomobject]@{ FileName = $safe; WasPrefixed = $false }
    }

    $prefixWord = $script:ReshelfCompanionKindPrefixWords[$Kind]
    if (-not $prefixWord) { $prefixWord = $script:ReshelfCompanionKindPrefixWords['other'] }

    return [pscustomobject]@{ FileName = "$prefixWord $safe"; WasPrefixed = $true }
}

function ConvertTo-ReshelfTruncatedSegment {
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

function Get-ReshelfRelativePath {
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

function Get-ReshelfFileSetHash {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$FilePaths
    )

    $entries = foreach ($path in $FilePaths) {
        # -ErrorAction Stop: Get-Item's default is a non-terminating error, which would otherwise
        # leave $item as $null and fail one line later with a confusing "cannot call a method on a
        # null-valued expression" instead of this cmdlet's own clear "cannot find path" message.
        $item = Get-Item -LiteralPath (ConvertTo-ReshelfLongPath -Path $path) -ErrorAction Stop
        "$($item.Name.ToLowerInvariant())|$($item.Length)"
    }

    $sorted = [string[]]@($entries)
    [Array]::Sort($sorted, [StringComparer]::Ordinal)
    $joined = $sorted -join "`n"
    return Get-ReshelfSha256Hex -Text $joined
}

# --- Secrets at rest ------------------------------------------------------------
# Windows DPAPI via the built-in SecureString cmdlets - only decryptable by this Windows user, on
# this machine. Generic (not Discogs-specific): any secret this tool needs to persist should use
# these two, not hand-roll its own encoding.

function Protect-ReshelfSecret {
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

function Unprotect-ReshelfSecret {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$EncryptedText
    )

    return (ConvertTo-SecureString -String $EncryptedText) | ConvertFrom-SecureString -AsPlainText
}

# --- TagLibSharp --------------------------------------------------------------
# Shared by Reshelf.Recognition.psm1 (reading tags) and Reshelf.Implementation.psm1 (writing tags) -
# both go through the same TagLibSharp.dll load, so there is exactly one Add-Type call site.

function Set-ReshelfTagLibSharpContext {
    [CmdletBinding()]
    param(
        [string]$TagLibSharpPath,

        [string]$DataHome
    )

    $script:ReshelfTagLibSharpPath = $TagLibSharpPath
    $script:ReshelfDataHome = $DataHome
}

function Get-ReshelfEffectiveDataHome {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string]$DataHome
    )

    # Same fallback Import-ReshelfTagLibSharp already uses to locate the DLL (explicit param, else
    # the context Set-ReshelfTagLibSharpContext stashed for this run, else the on-disk default) -
    # exposed here so callers outside this module (e.g. Reshelf.Recognition.psm1's embedded-cover
    # cache) resolve to the same data home a run was actually configured with, not always the
    # repo-default '.data' folder.
    if (-not $DataHome) { $DataHome = $script:ReshelfDataHome }
    if (-not $DataHome) { $DataHome = Resolve-ReshelfDataHome }
    return $DataHome
}

function Import-ReshelfTagLibSharp {
    [CmdletBinding()]
    param(
        [string]$TagLibSharpPath,

        [string]$DataHome
    )

    if ('TagLib.File' -as [type]) {
        return
    }

    if (-not $TagLibSharpPath) { $TagLibSharpPath = $script:ReshelfTagLibSharpPath }

    if (-not $TagLibSharpPath) {
        if (-not $DataHome) { $DataHome = $script:ReshelfDataHome }
        if (-not $DataHome) { $DataHome = Resolve-ReshelfDataHome }
        $TagLibSharpPath = Join-Path $DataHome 'lib' 'TagLibSharp.dll'
    }

    if (-not (Test-Path -LiteralPath $TagLibSharpPath -PathType Leaf)) {
        throw "TagLibSharp.dll not found at '$TagLibSharpPath'. Download the TagLibSharp NuGet package (e.g. 'dotnet add package TagLibSharp' in a throwaway project), copy TagLibSharp.dll from its lib/netstandard2.0 folder to that path, or set settings.taglibSharpPath to its location."
    }

    Add-Type -Path $TagLibSharpPath
}

Export-ModuleMember -Function Resolve-ReshelfDataHome, Get-ReshelfEffectiveDataHome, Get-ReshelfStableKey, ConvertTo-ReshelfLongPath, `
    ConvertTo-ReshelfNormalizedText, ConvertTo-ReshelfCueTimestampSeconds, Get-ReshelfSha256Hex, Test-ReshelfIsAudioExtension, Test-ReshelfIsLosslessFormat, `
    Get-ReshelfAudioFilesInFolder, ConvertFrom-ReshelfTrackFileName, ConvertTo-SafeFileName, Get-ReshelfFileSetHash, `
    Set-ReshelfTagLibSharpContext, Import-ReshelfTagLibSharp, Protect-ReshelfSecret, Unprotect-ReshelfSecret, Get-ReshelfRelativePath, `
    ConvertTo-ReshelfTruncatedSegment, Test-ReshelfLooseCompanionFileName, Get-ReshelfLooseCompanionFileName, `
    Remove-ReshelfInvisibleCharacters, ConvertTo-ReshelfTitleCase, `
    Test-ReshelfHasJapaneseScript, Test-ReshelfIsRomanizedText, Join-ReshelfBilingualName
