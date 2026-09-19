#Requires -Version 7.4

Import-Module (Join-Path $PSScriptRoot 'Tagger.Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Tagger.Json.psm1') -Force

$script:TaggerCategoryFolderNames = @('EPs', 'Singles', 'Lives', 'Live', 'Compilations', 'Bootlegs')
$script:TaggerAudioExtensions = @('.flac', '.mp3', '.m4a', '.wav', '.ogg', '.wma', '.aac', '.ape')
$script:TaggerTagLibSharpPath = $null
$script:TaggerDataHome = $null

# --- Format helpers -------------------------------------------------------

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

    return @(Get-ChildItem @params | Where-Object { $script:TaggerAudioExtensions -contains $_.Extension.ToLowerInvariant() })
}

# --- Heuristics -------------------------------------------------------------

function Test-IsDiscFolder {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    return [bool]($Name -match '(?i)^(CD|Disc|Disk)\s*\.?\s*(\d+)$')
}

function Get-TaggerDiscNumber {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($Name -match '(?i)^(CD|Disc|Disk)\s*\.?\s*(\d+)$') {
        return [int]$Matches[2]
    }
    return $null
}

function Get-TaggerDiscFolders {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $subfolders = @(Get-ChildItem -LiteralPath $Path -Directory -ErrorAction SilentlyContinue)
    $discs = foreach ($sub in $subfolders) {
        $number = Get-TaggerDiscNumber -Name $sub.Name
        if ($null -ne $number) {
            $sub | Add-Member -NotePropertyName DiscNumber -NotePropertyValue $number -PassThru -Force
        }
    }

    return @($discs | Sort-Object DiscNumber)
}

function Test-IsReleaseFolder {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if ((Get-TaggerAudioFilesInFolder -Path $Path).Count -ge 1) {
        return $true
    }

    $subfolders = @(Get-ChildItem -LiteralPath $Path -Directory -ErrorAction SilentlyContinue)
    if ($subfolders.Count -eq 0) {
        return $false
    }

    $discFolders = Get-TaggerDiscFolders -Path $Path
    if ($discFolders.Count -eq 0) {
        return $false
    }

    foreach ($disc in $discFolders) {
        if ((Get-TaggerAudioFilesInFolder -Path $disc.FullName).Count -ge 1) {
            return $true
        }
    }

    return $false
}

function Test-IsCategorySubfolder {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [string[]]$CategoryNames = $script:TaggerCategoryFolderNames
    )

    return [bool]($CategoryNames | Where-Object { $_ -ieq $Name })
}

function Test-IsGroupingFolder {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $files = @(Get-ChildItem -LiteralPath $Path -File -ErrorAction SilentlyContinue)
    if ($files.Count -gt 0) {
        return $false
    }

    $subfolders = @(Get-ChildItem -LiteralPath $Path -Directory -ErrorAction SilentlyContinue)
    if ($subfolders.Count -lt 2) {
        return $false
    }

    foreach ($sub in $subfolders) {
        if (Test-IsReleaseFolder -Path $sub.FullName) { return $false }
        if (Test-IsDiscFolder -Name $sub.Name) { return $false }
        if (Test-IsCategorySubfolder -Name $sub.Name) { return $false }
    }

    return $true
}

function Test-IsBandMemberFolder {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$ParentArtistName
    )

    $name = Split-Path -Leaf $Path

    if ((ConvertTo-TaggerNormalizedText -Text $name) -eq (ConvertTo-TaggerNormalizedText -Text $ParentArtistName)) {
        return $false
    }
    if (Test-IsCategorySubfolder -Name $name) {
        return $false
    }
    # A genuine band-member wrapper is a pure container, like a grouping folder - any loose file
    # sitting directly inside it (audio or not) is a sign of messiness that deserves human review
    # rather than an auto-classification.
    if (@(Get-ChildItem -LiteralPath $Path -File -ErrorAction SilentlyContinue).Count -gt 0) {
        return $false
    }

    $subfolders = @(Get-ChildItem -LiteralPath $Path -Directory -ErrorAction SilentlyContinue)
    foreach ($sub in $subfolders) {
        if (Test-IsReleaseFolder -Path $sub.FullName) {
            return $true
        }
    }

    return $false
}

# --- Track / disc parsing ---------------------------------------------------

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

function Get-TaggerTrackOrder {
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()]
        [object[]]$AudioFiles = @()
    )

    $parsed = @(foreach ($file in $AudioFiles) {
            $info = ConvertFrom-TaggerTrackFileName -FileName $file.Name
            [pscustomobject]@{ File = $file; Number = $info.Number; Title = $info.Title; HasNumber = $info.HasNumber }
        })

    if ($parsed.Count -eq 0) {
        return @()
    }

    $allNumbered = @($parsed | Where-Object { -not $_.HasNumber }).Count -eq 0

    if ($allNumbered) {
        return @($parsed | Sort-Object Number | ForEach-Object {
                [pscustomobject]@{ File = $_.File; Number = $_.Number; Title = $_.Title; InferredOrder = $false }
            })
    }

    $index = 0
    return @($parsed | Sort-Object { $_.File.Name } | ForEach-Object {
            $index++
            [pscustomobject]@{ File = $_.File; Number = $index; Title = $_.Title; InferredOrder = $true }
        })
}

# --- Cue sheets --------------------------------------------------------------

function Test-IsCueSheetRelease {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $audioFiles = Get-TaggerAudioFilesInFolder -Path $Path
    $cueFiles = @(Get-ChildItem -LiteralPath $Path -File -Filter '*.cue' -ErrorAction SilentlyContinue)

    return ($audioFiles.Count -eq 1 -and $cueFiles.Count -eq 1)
}

function ConvertFrom-TaggerCueSheet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CueFilePath
    )

    try {
        $lines = Get-Content -LiteralPath (ConvertTo-TaggerLongPath -Path $CueFilePath) -ErrorAction Stop
    }
    catch {
        return $null
    }

    $tracks = [System.Collections.Generic.List[object]]::new()
    $currentNumber = $null
    $currentTitle = $null

    foreach ($line in $lines) {
        $trimmed = $line.Trim()

        if ($trimmed -match '^TRACK\s+(\d+)\s+AUDIO') {
            $currentNumber = [int]$Matches[1]
            $currentTitle = $null
        }
        elseif ($null -ne $currentNumber -and $trimmed -match '^TITLE\s+"(.*)"') {
            $currentTitle = $Matches[1]
        }
        elseif ($null -ne $currentNumber -and $trimmed -match '^INDEX\s+01\s+(\d{2}:\d{2}:\d{2})') {
            $title = if ($currentTitle) { $currentTitle } else { "Track $currentNumber" }
            $tracks.Add([pscustomobject]@{ Number = $currentNumber; Title = $title; Timestamp = $Matches[1] })
            $currentNumber = $null
            $currentTitle = $null
        }
    }

    if ($tracks.Count -eq 0) {
        return $null
    }

    return @($tracks | Sort-Object Number)
}

# --- Companion files ----------------------------------------------------------

function Resolve-TaggerCompanionKind {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FileName,

        [Parameter(Mandatory)]
        [string]$Extension
    )

    $imageExtensions = @('.jpg', '.jpeg', '.png', '.bmp', '.gif', '.tiff', '.webp')
    $textExtensions = @('.txt', '.pdf', '.nfo')
    $lower = $FileName.ToLowerInvariant()

    if ($imageExtensions -contains $Extension) {
        if ($lower -match 'photo') { return 'photo' }
        if ($lower -match 'booklet|back|insert') { return 'booklet' }
        return 'cover'
    }
    if ($textExtensions -contains $Extension) {
        if ($lower -match 'lyrics') { return 'lyrics' }
        return 'other'
    }

    return 'other'
}

function Get-TaggerCompanionFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $companions = [System.Collections.Generic.List[object]]::new()
    $ignored = [System.Collections.Generic.List[object]]::new()

    # Audio and .cue files are excluded by extension below regardless of which folder they're in
    # (they're tracks/cue sheets, handled elsewhere) - everything else, including a stray playlist
    # or image sitting inside a disc subfolder, is still a real companion/ignored file and must not
    # be dropped just because of where it happens to live.
    $allFiles = @(Get-ChildItem -LiteralPath $Path -File -Recurse -ErrorAction SilentlyContinue)
    foreach ($file in $allFiles) {
        $ext = $file.Extension.ToLowerInvariant()
        if ($script:TaggerAudioExtensions -contains $ext) { continue }
        if ($ext -eq '.cue') { continue }

        if ($ext -in @('.m3u', '.m3u8', '.pls')) {
            $ignored.Add([pscustomobject]@{ sourcePath = $file.FullName; reason = 'playlist-file' })
            continue
        }

        $placement = if ($file.DirectoryName -eq $Path) { 'loose' } else { 'nested' }
        $kind = Resolve-TaggerCompanionKind -FileName $file.Name -Extension $ext
        $companions.Add([pscustomobject]@{ sourcePath = $file.FullName; kind = $kind; placement = $placement })
    }

    return [pscustomobject]@{ Companions = @($companions); Ignored = @($ignored) }
}

# --- TagLibSharp --------------------------------------------------------------

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

function Get-TaggerAudioTags {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [string]$TagLibSharpPath,

        [string]$DataHome
    )

    Import-TaggerTagLibSharp -TagLibSharpPath $TagLibSharpPath -DataHome $DataHome

    $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    $file = [TagLib.File]::Create((ConvertTo-TaggerLongPath -Path $Path))
    try {
        $tag = $file.Tag
        $properties = $file.Properties

        return @{
            Artist          = if ($tag.FirstPerformer) { $tag.FirstPerformer } else { $null }
            Album           = if ($tag.Album) { $tag.Album } else { $null }
            Title           = if ($tag.Title) { $tag.Title } else { $null }
            Format          = $extension.TrimStart('.')
            IsLossless      = Test-TaggerIsLosslessFormat -Extension $extension
            DurationSeconds = [double]$properties.Duration.TotalSeconds
        }
    }
    finally {
        $file.Dispose()
    }
}

# --- Overrides -----------------------------------------------------------------

function Get-TaggerOverridesFileHash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SourceRoot
    )

    $normalized = $SourceRoot.TrimEnd('\', '/').ToLowerInvariant()
    return Get-TaggerSha256Hex -Text $normalized
}

function Get-TaggerOverrides {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SourceRoot,

        [string]$DataHome,

        [string]$OverridesPath
    )

    if (-not $OverridesPath) {
        if (-not $DataHome) { $DataHome = Resolve-TaggerDataHome }
        $hash = Get-TaggerOverridesFileHash -SourceRoot $SourceRoot
        $OverridesPath = Join-Path $DataHome 'overrides' "$hash.json"
    }

    if (-not (Test-Path -LiteralPath $OverridesPath -PathType Leaf)) {
        return [pscustomobject]@{ schemaVersion = 1; sourceRoot = $SourceRoot; entries = @() }
    }

    if (-not (Test-TaggerJson -SchemaName overrides -Path $OverridesPath)) {
        throw "Overrides file at '$OverridesPath' does not match the overrides schema."
    }

    return Get-Content -LiteralPath $OverridesPath -Raw | ConvertFrom-Json
}

function Resolve-TaggerFolderOverride {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Overrides,

        [Parameter(Mandatory)]
        [string]$RelativePath
    )

    $normalized = ($RelativePath -replace '\\', '/').ToLowerInvariant()

    return @($Overrides.entries) | Where-Object {
        (($_.relativePath -replace '\\', '/').ToLowerInvariant()) -eq $normalized
    } | Select-Object -First 1
}

function Get-TaggerRelativePath {
    [CmdletBinding()]
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

# --- Orchestration ---------------------------------------------------------------

function Resolve-TaggerFolderKind {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Context,

        [string]$ArtistName,

        [Parameter(Mandatory)]
        [object]$Overrides,

        [Parameter(Mandatory)]
        [string]$SourceRoot
    )

    $relativePath = Get-TaggerRelativePath -SourceRoot $SourceRoot -Path $Path
    $override = Resolve-TaggerFolderOverride -Overrides $Overrides -RelativePath $relativePath

    if ($override) {
        switch ($override.kind) {
            'grouping' { return [pscustomobject]@{ Kind = 'grouping'; IsOverrideResolved = $true } }
            'category' { return [pscustomobject]@{ Kind = 'category'; ParentArtistName = $override.parentArtistName } }
            'band-member' { return [pscustomobject]@{ Kind = 'band-member'; ArtistNameOverride = $override.artistName } }
            'artist' { return [pscustomobject]@{ Kind = 'release'; OverrideArtistName = $override.artistName } }
        }
    }

    $leafName = Split-Path -Leaf $Path
    $inArtistLikeBody = $Context -in @('ArtistBody', 'CategoryBody', 'BandMemberBody')

    if ($inArtistLikeBody -and (Test-IsCategorySubfolder -Name $leafName)) {
        return [pscustomobject]@{ Kind = 'category'; ParentArtistName = $ArtistName }
    }

    if (Test-IsReleaseFolder -Path $Path) {
        return [pscustomobject]@{ Kind = 'release' }
    }

    if ($inArtistLikeBody -and $ArtistName -and (Test-IsBandMemberFolder -Path $Path -ParentArtistName $ArtistName)) {
        return [pscustomobject]@{ Kind = 'band-member' }
    }

    if (Test-IsGroupingFolder -Path $Path) {
        return [pscustomobject]@{ Kind = 'grouping'; IsOverrideResolved = $false }
    }

    $hasAnyAudio = (Get-TaggerAudioFilesInFolder -Path $Path -Recurse).Count -gt 0
    if (-not $hasAnyAudio) {
        return [pscustomobject]@{ Kind = 'unrecognized'; Reason = 'no-audio-files' }
    }

    # Loose (non-audio) files sitting directly alongside subfolders is exactly the "random leftovers
    # mixed with subfolders" case - genuinely unclear, so it's flagged rather than guessed.
    $directFiles = @(Get-ChildItem -LiteralPath $Path -File -ErrorAction SilentlyContinue)
    $hasSubfolders = @(Get-ChildItem -LiteralPath $Path -Directory -ErrorAction SilentlyContinue).Count -gt 0
    if ($directFiles.Count -gt 0 -and $hasSubfolders) {
        return [pscustomobject]@{ Kind = 'unrecognized'; Reason = 'unclassified-folder' }
    }

    # Not ambiguous (doesn't look like a grouping/category/band-member folder), and audio exists
    # somewhere below - treat as a transparent nesting layer rather than flagging it. At Root this
    # bootstraps the artist name from the folder's own name; deeper down, it just keeps walking
    # under whatever artist name is already in effect (e.g. a plain "Albums" filler folder).
    if ($Context -eq 'Root') {
        return [pscustomobject]@{ Kind = 'pass-through'; NewArtistName = $leafName }
    }

    return [pscustomobject]@{ Kind = 'pass-through'; NewArtistName = $null }
}

function New-TaggerUnrecognizedEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Reason,

        [string[]]$Children = @()
    )

    return [pscustomobject]@{ path = $Path; reason = $Reason; children = @($Children) }
}

function Merge-TaggerArtistBucket {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.Dictionary[string, object]]$ArtistsMap,

        [Parameter(Mandatory)]
        [string]$ArtistName,

        [Parameter(Mandatory)]
        [string]$ReleaseFolderParent,

        [Parameter(Mandatory)]
        [object]$Release
    )

    $key = ConvertTo-TaggerNormalizedText -Text $ArtistName
    if (-not $ArtistsMap.ContainsKey($key)) {
        $ArtistsMap[$key] = [pscustomobject]@{
            recognizedName = $ArtistName
            sourcePaths    = [System.Collections.Generic.List[string]]::new()
            releases       = [System.Collections.Generic.List[object]]::new()
        }
    }

    $bucket = $ArtistsMap[$key]
    if (-not $bucket.sourcePaths.Contains($ReleaseFolderParent)) {
        $bucket.sourcePaths.Add($ReleaseFolderParent)
    }
    $bucket.releases.Add($Release)
}

function New-TaggerReleaseRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$ArtistName
    )

    $leafName = Split-Path -Leaf $Path
    if ($leafName -match '^(\d{4})\s+(.+)$') {
        $year = [int]$Matches[1]
        $title = $Matches[2].Trim()
    }
    else {
        $year = $null
        $title = $leafName
    }

    $recognitionFlags = [System.Collections.Generic.List[string]]::new()
    $reviewReasons = [System.Collections.Generic.List[string]]::new()
    $needsReview = $false

    if ((ConvertTo-TaggerLongPath -Path $Path) -ne $Path) {
        $recognitionFlags.Add('path-near-length-limit')
    }

    $discFolders = Get-TaggerDiscFolders -Path $Path
    $tracks = [System.Collections.Generic.List[object]]::new()
    $cueSheet = $null

    if ($discFolders.Count -eq 0) {
        if (Test-IsCueSheetRelease -Path $Path) {
            $audioFile = (Get-TaggerAudioFilesInFolder -Path $Path)[0]
            $cueFile = Get-ChildItem -LiteralPath $Path -File -Filter '*.cue' | Select-Object -First 1
            $cueSheet = [pscustomobject]@{ cueFilePath = $cueFile.FullName; audioFilePath = $audioFile.FullName }
            $audioTags = Get-TaggerAudioTags -Path $audioFile.FullName
            $cueTracks = ConvertFrom-TaggerCueSheet -CueFilePath $cueFile.FullName

            if ($null -eq $cueTracks) {
                $needsReview = $true
                $reviewReasons.Add('unparseable-cue-sheet')
                $tracks.Add([pscustomobject]@{
                        sourceFilePath            = $audioFile.FullName
                        discFolder                = $null
                        originalFileName          = $audioFile.Name
                        detectedTrackNumberInDisc = 1
                        inferredTrackOrder        = $true
                        existingTags              = @{ artist = $audioTags.Artist; album = $audioTags.Album; title = $audioTags.Title }
                        format                    = $audioTags.Format
                        isLossless                = $audioTags.IsLossless
                        durationSeconds           = $audioTags.DurationSeconds
                        cueTimestamp              = '00:00:00'
                        isCueVirtualTrack         = $true
                    })
            }
            else {
                foreach ($cueTrack in $cueTracks) {
                    $tracks.Add([pscustomobject]@{
                            sourceFilePath            = $audioFile.FullName
                            discFolder                = $null
                            originalFileName          = $audioFile.Name
                            detectedTrackNumberInDisc = $cueTrack.Number
                            inferredTrackOrder        = $false
                            existingTags              = @{ artist = $audioTags.Artist; album = $audioTags.Album; title = $cueTrack.Title }
                            format                    = $audioTags.Format
                            isLossless                = $audioTags.IsLossless
                            durationSeconds           = $audioTags.DurationSeconds
                            cueTimestamp              = $cueTrack.Timestamp
                            isCueVirtualTrack         = $true
                        })
                }
            }
        }
        else {
            $ordered = Get-TaggerTrackOrder -AudioFiles (Get-TaggerAudioFilesInFolder -Path $Path)
            foreach ($item in $ordered) {
                $audioTags = Get-TaggerAudioTags -Path $item.File.FullName
                if ($item.InferredOrder) { $recognitionFlags.Add('no-track-number') }
                $tracks.Add([pscustomobject]@{
                        sourceFilePath            = $item.File.FullName
                        discFolder                = $null
                        originalFileName          = $item.File.Name
                        detectedTrackNumberInDisc = $item.Number
                        inferredTrackOrder        = $item.InferredOrder
                        existingTags              = @{ artist = $audioTags.Artist; album = $audioTags.Album; title = $audioTags.Title }
                        format                    = $audioTags.Format
                        isLossless                = $audioTags.IsLossless
                        durationSeconds           = $audioTags.DurationSeconds
                        cueTimestamp              = $null
                        isCueVirtualTrack         = $false
                    })
            }
        }

        $subReleaseCandidates = @(Get-ChildItem -LiteralPath $Path -Directory -ErrorAction SilentlyContinue |
                Where-Object { Test-IsReleaseFolder -Path $_.FullName })
        if ($tracks.Count -gt 0 -and $subReleaseCandidates.Count -gt 0) {
            $needsReview = $true
            $reviewReasons.Add('nested-release-suspected')
        }
    }
    else {
        foreach ($discFolder in $discFolders) {
            if (Test-IsCueSheetRelease -Path $discFolder.FullName) {
                $needsReview = $true
                $reviewReasons.Add('per-disc-cue-not-yet-supported')
                $audioFile = (Get-TaggerAudioFilesInFolder -Path $discFolder.FullName)[0]
                $audioTags = Get-TaggerAudioTags -Path $audioFile.FullName
                $tracks.Add([pscustomobject]@{
                        sourceFilePath            = $audioFile.FullName
                        discFolder                = $discFolder.Name
                        originalFileName          = $audioFile.Name
                        detectedTrackNumberInDisc = 1
                        inferredTrackOrder        = $true
                        existingTags              = @{ artist = $audioTags.Artist; album = $audioTags.Album; title = $audioTags.Title }
                        format                    = $audioTags.Format
                        isLossless                = $audioTags.IsLossless
                        durationSeconds           = $audioTags.DurationSeconds
                        cueTimestamp              = $null
                        isCueVirtualTrack         = $false
                    })
                continue
            }

            $ordered = Get-TaggerTrackOrder -AudioFiles (Get-TaggerAudioFilesInFolder -Path $discFolder.FullName)
            foreach ($item in $ordered) {
                $audioTags = Get-TaggerAudioTags -Path $item.File.FullName
                if ($item.InferredOrder) { $recognitionFlags.Add('no-track-number') }
                $tracks.Add([pscustomobject]@{
                        sourceFilePath            = $item.File.FullName
                        discFolder                = $discFolder.Name
                        originalFileName          = $item.File.Name
                        detectedTrackNumberInDisc = $item.Number
                        inferredTrackOrder        = $item.InferredOrder
                        existingTags              = @{ artist = $audioTags.Artist; album = $audioTags.Album; title = $audioTags.Title }
                        format                    = $audioTags.Format
                        isLossless                = $audioTags.IsLossless
                        durationSeconds           = $audioTags.DurationSeconds
                        cueTimestamp              = $null
                        isCueVirtualTrack         = $false
                    })
            }
        }

        # A multi-disc release folder should only have audio files inside its disc subfolders - any
        # audio file sitting loose at this level doesn't belong to a known disc and would otherwise
        # be silently dropped (it's excluded from tracks above, and companion scanning skips audio
        # extensions too). Record it as a track anyway so nothing vanishes, and flag it for review.
        $looseAudioFiles = Get-TaggerAudioFilesInFolder -Path $Path
        if ($looseAudioFiles.Count -gt 0) {
            $needsReview = $true
            $reviewReasons.Add('track-outside-disc-folder-suspected')
            $ordered = Get-TaggerTrackOrder -AudioFiles $looseAudioFiles
            foreach ($item in $ordered) {
                $audioTags = Get-TaggerAudioTags -Path $item.File.FullName
                if ($item.InferredOrder) { $recognitionFlags.Add('no-track-number') }
                $tracks.Add([pscustomobject]@{
                        sourceFilePath            = $item.File.FullName
                        discFolder                = $null
                        originalFileName          = $item.File.Name
                        detectedTrackNumberInDisc = $item.Number
                        inferredTrackOrder        = $item.InferredOrder
                        existingTags              = @{ artist = $audioTags.Artist; album = $audioTags.Album; title = $audioTags.Title }
                        format                    = $audioTags.Format
                        isLossless                = $audioTags.IsLossless
                        durationSeconds           = $audioTags.DurationSeconds
                        cueTimestamp              = $null
                        isCueVirtualTrack         = $false
                    })
            }
        }
    }

    $companions = Get-TaggerCompanionFiles -Path $Path

    $confidence = 1.0
    if ($recognitionFlags.Count -gt 0) { $confidence = 0.8 }
    if ($needsReview) { $confidence = 0.5 }

    return [pscustomobject]@{
        stableKey              = Get-TaggerStableKey -Artist $ArtistName -Album $title -Year $year
        recognizedTitle        = $title
        recognizedYear         = $year
        sourceFolderPath       = $Path
        discFolderCount        = [Math]::Max(1, $discFolders.Count)
        tracks                 = @($tracks)
        companionFiles         = @($companions.Companions)
        ignoredFiles           = @($companions.Ignored)
        cueSheet               = $cueSheet
        recognitionConfidence  = $confidence
        recognitionFlags       = @($recognitionFlags | Select-Object -Unique)
        needsReview            = $needsReview
        reviewReasons          = @($reviewReasons | Select-Object -Unique)
    }
}

function Invoke-TaggerFolderWalk {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Dir,

        [Parameter(Mandatory)]
        [string]$Context,

        [string]$ArtistName,

        [Parameter(Mandatory)]
        [object]$Overrides,

        [Parameter(Mandatory)]
        [string]$SourceRoot,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.Dictionary[string, object]]$ArtistsMap,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$UnrecognizedList
    )

    $children = @(Get-ChildItem -LiteralPath $Dir -Directory -ErrorAction SilentlyContinue)

    foreach ($child in $children) {
        $kind = Resolve-TaggerFolderKind -Path $child.FullName -Context $Context -ArtistName $ArtistName -Overrides $Overrides -SourceRoot $SourceRoot

        switch ($kind.Kind) {
            'release' {
                $targetArtist = if ($ArtistName) { $ArtistName } elseif ($kind.OverrideArtistName) { $kind.OverrideArtistName } else { $null }
                if (-not $targetArtist) {
                    $childNames = @((Get-ChildItem -LiteralPath $child.FullName -ErrorAction SilentlyContinue).Name)
                    $UnrecognizedList.Add((New-TaggerUnrecognizedEntry -Path $child.FullName -Reason 'release-without-artist-suspected' -Children $childNames))
                    continue
                }
                $release = New-TaggerReleaseRecord -Path $child.FullName -ArtistName $targetArtist
                Merge-TaggerArtistBucket -ArtistsMap $ArtistsMap -ArtistName $targetArtist -ReleaseFolderParent (Split-Path -Parent $child.FullName) -Release $release
            }
            'category' {
                $parentArtist = if ($kind.ParentArtistName) { $kind.ParentArtistName } else { $ArtistName }
                Invoke-TaggerFolderWalk -Dir $child.FullName -Context 'CategoryBody' -ArtistName $parentArtist -Overrides $Overrides -SourceRoot $SourceRoot -ArtistsMap $ArtistsMap -UnrecognizedList $UnrecognizedList
            }
            'band-member' {
                $newArtist = if ($kind.ArtistNameOverride) { $kind.ArtistNameOverride } else { $child.Name }
                Invoke-TaggerFolderWalk -Dir $child.FullName -Context 'BandMemberBody' -ArtistName $newArtist -Overrides $Overrides -SourceRoot $SourceRoot -ArtistsMap $ArtistsMap -UnrecognizedList $UnrecognizedList
            }
            'grouping' {
                if ($kind.IsOverrideResolved) {
                    $grandchildren = @(Get-ChildItem -LiteralPath $child.FullName -Directory -ErrorAction SilentlyContinue)
                    foreach ($grandchild in $grandchildren) {
                        Invoke-TaggerFolderWalk -Dir $grandchild.FullName -Context 'ArtistBody' -ArtistName $grandchild.Name -Overrides $Overrides -SourceRoot $SourceRoot -ArtistsMap $ArtistsMap -UnrecognizedList $UnrecognizedList
                    }
                }
                else {
                    $childNames = @((Get-ChildItem -LiteralPath $child.FullName -Directory -ErrorAction SilentlyContinue).Name)
                    $UnrecognizedList.Add((New-TaggerUnrecognizedEntry -Path $child.FullName -Reason 'grouping-folder-suspected' -Children $childNames))
                }
            }
            'pass-through' {
                $nextArtist = if ($kind.NewArtistName) { $kind.NewArtistName } else { $ArtistName }
                $nextContext = if ($Context -eq 'Root') { 'ArtistBody' } else { $Context }
                Invoke-TaggerFolderWalk -Dir $child.FullName -Context $nextContext -ArtistName $nextArtist -Overrides $Overrides -SourceRoot $SourceRoot -ArtistsMap $ArtistsMap -UnrecognizedList $UnrecognizedList
            }
            'unrecognized' {
                $childNames = @((Get-ChildItem -LiteralPath $child.FullName -ErrorAction SilentlyContinue).Name)
                $UnrecognizedList.Add((New-TaggerUnrecognizedEntry -Path $child.FullName -Reason $kind.Reason -Children $childNames))
            }
        }
    }
}

function New-TaggerRecognitionDocument {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SessionId,

        [Parameter(Mandatory)]
        [string]$SourceRoot,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.Dictionary[string, object]]$ArtistsMap,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$UnrecognizedList
    )

    $artists = @($ArtistsMap.Values | ForEach-Object {
            [pscustomobject]@{
                recognizedName = $_.recognizedName
                sourcePaths    = @($_.sourcePaths)
                releases       = @($_.releases)
            }
        })

    return [pscustomobject]@{
        schemaVersion   = 1
        sessionId       = $SessionId
        sourceRoot      = $SourceRoot
        generatedAtUtc  = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        artists         = $artists
        unrecognized    = @($UnrecognizedList)
    }
}

function Invoke-TaggerRecognition {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$SourceRoot,

        [Parameter(Mandatory)]
        [string]$SessionId,

        [string]$DataHome,

        [string]$OverridesPath,

        [string]$TagLibSharpPath
    )

    if (-not $DataHome) { $DataHome = Resolve-TaggerDataHome }

    if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) {
        throw "Source root '$SourceRoot' does not exist or is not a directory."
    }
    $resolvedSourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path

    $script:TaggerTagLibSharpPath = $TagLibSharpPath
    $script:TaggerDataHome = $DataHome

    $overridesParams = @{ SourceRoot = $resolvedSourceRoot }
    if ($OverridesPath) { $overridesParams['OverridesPath'] = $OverridesPath } else { $overridesParams['DataHome'] = $DataHome }
    $overrides = Get-TaggerOverrides @overridesParams

    $artistsMap = [System.Collections.Generic.Dictionary[string, object]]::new()
    $unrecognizedList = [System.Collections.Generic.List[object]]::new()

    Invoke-TaggerFolderWalk -Dir $resolvedSourceRoot -Context 'Root' -ArtistName $null `
        -Overrides $overrides -SourceRoot $resolvedSourceRoot -ArtistsMap $artistsMap -UnrecognizedList $unrecognizedList

    $document = New-TaggerRecognitionDocument -SessionId $SessionId -SourceRoot $resolvedSourceRoot -ArtistsMap $artistsMap -UnrecognizedList $unrecognizedList

    $outputPath = Join-Path $DataHome 'sessions' $SessionId 'recognition.json'
    Set-TaggerJsonFile -Path $outputPath -InputObject $document -SchemaName recognition -Depth 20 | Out-Null

    return (Get-Content -LiteralPath $outputPath -Raw | ConvertFrom-Json)
}

Export-ModuleMember -Function Invoke-TaggerRecognition, Get-TaggerAudioTags
