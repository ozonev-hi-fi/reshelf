#Requires -Version 7.4

Import-Module (Join-Path $PSScriptRoot 'Reshelf.Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Reshelf.Json.psm1') -Force

$script:ReshelfCategoryFolderNames = @('EPs', 'Singles', 'Lives', 'Live', 'Compilations', 'Bootlegs')

# --- Heuristics -------------------------------------------------------------

function Test-IsDiscFolder {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    return [bool]($Name -match '(?i)^(CD|Disc|Disk)\s*\.?\s*(\d+)(\.|\s|-|$)')
}

function Get-ReshelfDiscNumber {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($Name -match '(?i)^(CD|Disc|Disk)\s*\.?\s*(\d+)(\.|\s|-|$)') {
        return [int]$Matches[2]
    }
    return $null
}

function Get-ReshelfDiscFolders {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $subfolders = @(Get-ChildItem -LiteralPath $Path -Directory -ErrorAction SilentlyContinue)
    $discs = foreach ($sub in $subfolders) {
        $number = Get-ReshelfDiscNumber -Name $sub.Name
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

    if ((Get-ReshelfAudioFilesInFolder -Path $Path).Count -ge 1) {
        return $true
    }

    $subfolders = @(Get-ChildItem -LiteralPath $Path -Directory -ErrorAction SilentlyContinue)
    if ($subfolders.Count -eq 0) {
        return $false
    }

    $discFolders = Get-ReshelfDiscFolders -Path $Path
    if ($discFolders.Count -eq 0) {
        return $false
    }

    foreach ($disc in $discFolders) {
        if ((Get-ReshelfAudioFilesInFolder -Path $disc.FullName).Count -ge 1) {
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

        [string[]]$CategoryNames = $script:ReshelfCategoryFolderNames
    )

    return [bool]($CategoryNames | Where-Object { $_ -ieq $Name })
}

function Test-IsAlbumWrapperFolder {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    # Real-world case (plan/12-ish): a release folder name ("yyyy - Title") sometimes wraps one or
    # more "edition" subfolders instead of holding tracks directly - e.g.
    # "AC-DC\1975 - T.N.T. (Australian Release)\1989 Australia Albert 465262 2\<tracks>". The leaf
    # name still reads as a release (a leading year), but Test-IsReleaseFolder itself requires audio
    # directly in the folder or in a *disc*-named subfolder, so this needs its own check.
    $leafName = Split-Path -Leaf $Path
    $yearSplit = Split-ReshelfLeadingYear -Text $leafName
    if ($null -eq $yearSplit.Year) {
        return $false
    }

    if ((Get-ReshelfAudioFilesInFolder -Path $Path).Count -gt 0) {
        return $false
    }

    $subfolders = @(Get-ChildItem -LiteralPath $Path -Directory -ErrorAction SilentlyContinue)
    $releaseSubfolders = @($subfolders | Where-Object { Test-IsReleaseFolder -Path $_.FullName })
    if ($releaseSubfolders.Count -eq 0) {
        return $false
    }

    # Every subfolder that has audio anywhere below it must itself be a release folder - otherwise
    # there's an unknown layer of nesting still hiding below (e.g. a genuine band-member folder),
    # and this shouldn't silently swallow it as if it were just another edition.
    foreach ($sub in $subfolders) {
        if ($releaseSubfolders -contains $sub) { continue }
        if ((Get-ReshelfAudioFilesInFolder -Path $sub.FullName -Recurse).Count -gt 0) {
            return $false
        }
    }

    return $true
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
        if (Test-IsAlbumWrapperFolder -Path $sub.FullName) { return $false }
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

    if ((ConvertTo-ReshelfNormalizedText -Text $name) -eq (ConvertTo-ReshelfNormalizedText -Text $ParentArtistName)) {
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

function Get-ReshelfTrackOrder {
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()]
        [object[]]$AudioFiles = @()
    )

    $parsed = @(foreach ($file in $AudioFiles) {
            $info = ConvertFrom-ReshelfTrackFileName -FileName $file.Name
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

function Get-ReshelfCueSheetPathForAudio {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo]$AudioFile,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.IO.FileInfo[]]$CueFiles
    )

    if ($CueFiles.Count -eq 0) { return $null }
    if ($CueFiles.Count -eq 1) { return $CueFiles[0] }

    # More than one .cue file usually means one per rip format sitting side by side (e.g. a
    # ".flac.cue" and a ".wav.cue" next to a single real .flac, the .wav rip never having been kept)
    # - pick the one that actually names the present audio file, instead of an arbitrary first match.
    # The two match rules are tried in priority order, not merged into one set: a real-world sample
    # had both "Album.ape.cue" (exact-name form) and "Album.cue" (basename form) naming the SAME
    # present .ape - that's redundant naming, not competing formats, so it must still resolve to one
    # cue file instead of bailing out to $null just because 2 files matched across the two rules.
    $exactNameMatch = @($CueFiles | Where-Object { $_.Name -ieq "$($AudioFile.Name).cue" })
    if ($exactNameMatch.Count -eq 1) { return $exactNameMatch[0] }

    $baseNameMatch = @($CueFiles | Where-Object { $_.BaseName -ieq $AudioFile.BaseName })
    if ($baseNameMatch.Count -eq 1) { return $baseNameMatch[0] }

    return $null
}

function Test-IsCueSheetRelease {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $audioFiles = Get-ReshelfAudioFilesInFolder -Path $Path
    if ($audioFiles.Count -ne 1) { return $false }

    $cueFiles = @(Get-ChildItem -LiteralPath $Path -File -Filter '*.cue' -ErrorAction SilentlyContinue)

    return ($null -ne (Get-ReshelfCueSheetPathForAudio -AudioFile $audioFiles[0] -CueFiles $cueFiles))
}

function ConvertFrom-ReshelfCueSheetText {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [byte[]]$Bytes
    )

    # A declared UTF-8 BOM is trustworthy as-is.
    if ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF) {
        return [System.Text.Encoding]::UTF8.GetString($Bytes, 3, $Bytes.Length - 3)
    }

    # No BOM: try strict UTF-8 first (throws on any invalid byte sequence, unlike the default decoder
    # which silently substitutes U+FFFD and loses data). Cue sheets ripped on Windows are very often
    # actually Windows-1252 (legacy ANSI codepage) - that's where accented letters (e.g. German
    # u-umlaut) show up as invalid UTF-8 sequences, so falling back to 1252 recovers them correctly.
    # Plain-ASCII cue sheets (the common case) are valid UTF-8 either way, so this only changes
    # behavior for genuinely non-UTF-8 files.
    $strictUtf8 = [System.Text.UTF8Encoding]::new($false, $true)
    try {
        return $strictUtf8.GetString($Bytes)
    }
    catch [System.Text.DecoderFallbackException] {
        return [System.Text.Encoding]::GetEncoding(1252).GetString($Bytes)
    }
}

function ConvertFrom-ReshelfCueSheet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CueFilePath
    )

    try {
        $bytes = [System.IO.File]::ReadAllBytes((ConvertTo-ReshelfLongPath -Path $CueFilePath))
        $text = ConvertFrom-ReshelfCueSheetText -Bytes $bytes
        $lines = $text -split "`r`n|`r|`n"
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

function New-ReshelfCueVirtualTracks {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo]$AudioFile,

        [Parameter(Mandatory)]
        [System.IO.FileInfo]$CueFile,

        # The disc subfolder this cue/audio pair lives in, for a per-disc-cue release ("CD 1", "CD
        # 2", ...) - $null for a whole-release cue with no disc subfolders.
        [string]$DiscFolderName
    )

    $tracks = [System.Collections.Generic.List[object]]::new()
    $reviewReasons = [System.Collections.Generic.List[string]]::new()
    $needsReview = $false

    $audioTags = Get-ReshelfAudioTags -Path $AudioFile.FullName
    if ($audioTags.PropertiesUnavailable) {
        $needsReview = $true
        $reviewReasons.Add('audio-properties-unreadable')
    }
    # ffmpeg has no ape encoder/muxer (see Invoke-ReshelfFfmpegSplit in Reshelf.Implementation.psm1),
    # so a cue split of an .ape source can never stream-copy into .ape - it re-encodes to .flac
    # instead. Naming these tracks 'flac' here keeps proposedFileName (Reshelf.EditProposal.psm1) in
    # sync with what the split actually produces. Still fully lossless - isLossless below is untouched.
    $cueSplitFormat = if ($audioTags.Format -eq 'ape') { 'flac' } else { $audioTags.Format }
    $cueTracks = ConvertFrom-ReshelfCueSheet -CueFilePath $CueFile.FullName

    if ($null -eq $cueTracks) {
        $needsReview = $true
        $reviewReasons.Add('unparseable-cue-sheet')
        $tracks.Add([pscustomobject]@{
                sourceFilePath            = $AudioFile.FullName
                discFolder                = $DiscFolderName
                originalFileName          = $AudioFile.Name
                detectedTrackNumberInDisc = 1
                inferredTrackOrder        = $true
                existingTags              = [pscustomobject]@{ artist = $audioTags.Artist; album = $audioTags.Album; title = $audioTags.Title }
                existingCoverArtPath      = $audioTags.EmbeddedCoverPath
                format                    = $cueSplitFormat
                isLossless                = $audioTags.IsLossless
                durationSeconds           = $audioTags.DurationSeconds
                cueTimestamp              = '00:00:00'
                isCueVirtualTrack         = $true
            })
    }
    else {
        # Each cue track's own duration is the gap to the next track's start (or, for the last
        # track, the gap to the whole file's end) - a flat copy of the whole-file duration onto
        # every track (as this used to do) is wrong for every track but the first.
        # ConvertFrom-ReshelfCueSheet already returns tracks sorted by Number.
        $cueTracksSorted = @($cueTracks)
        for ($i = 0; $i -lt $cueTracksSorted.Count; $i++) {
            $cueTrack = $cueTracksSorted[$i]
            $startSeconds = ConvertTo-ReshelfCueTimestampSeconds -CueTimestamp $cueTrack.Timestamp
            $endSeconds = if ($i -lt ($cueTracksSorted.Count - 1)) {
                ConvertTo-ReshelfCueTimestampSeconds -CueTimestamp $cueTracksSorted[$i + 1].Timestamp
            }
            else {
                $audioTags.DurationSeconds
            }
            $tracks.Add([pscustomobject]@{
                    sourceFilePath            = $AudioFile.FullName
                    discFolder                = $DiscFolderName
                    originalFileName          = $AudioFile.Name
                    detectedTrackNumberInDisc = $cueTrack.Number
                    inferredTrackOrder        = $false
                    existingTags              = [pscustomobject]@{ artist = $audioTags.Artist; album = $audioTags.Album; title = $cueTrack.Title }
                    existingCoverArtPath      = $audioTags.EmbeddedCoverPath
                    format                    = $cueSplitFormat
                    isLossless                = $audioTags.IsLossless
                    durationSeconds           = [Math]::Round(($endSeconds - $startSeconds), 3)
                    cueTimestamp              = $cueTrack.Timestamp
                    isCueVirtualTrack         = $true
                })
        }
    }

    return [pscustomobject]@{ Tracks = @($tracks); ReviewReasons = @($reviewReasons); NeedsReview = $needsReview }
}

# --- Companion files ----------------------------------------------------------

function Resolve-ReshelfCompanionKind {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FileName,

        # AllowEmptyString: see Test-ReshelfIsAudioExtension in Reshelf.Common.psm1 - a companion
        # file with no extension at all falls through to kind 'other' below, instead of the
        # Mandatory string binder rejecting '' before this function even runs.
        [Parameter(Mandatory)]
        [AllowEmptyString()]
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

function Get-ReshelfCompanionFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        # The cue sheet(s) actually used to split this release's tracks (see Test-IsCueSheetRelease
        # above) - one per disc for a per-disc-cue release, or a single entry for a whole-release cue.
        # Those files are superseded by the split and must stay silently excluded here - they're
        # neither companions nor something to flag. Any *other* .cue sitting in the folder is not
        # used for anything, so it must not just vanish; it's routed to Ignored below.
        [string[]]$CueSheetPaths = @()
    )

    $companions = [System.Collections.Generic.List[object]]::new()
    $ignored = [System.Collections.Generic.List[object]]::new()

    # Audio files are excluded by extension below regardless of which folder they're in (they're
    # tracks, handled elsewhere) - everything else, including a stray playlist or image sitting
    # inside a disc subfolder, is still a real companion/ignored file and must not be dropped just
    # because of where it happens to live.
    $allFiles = @(Get-ChildItem -LiteralPath $Path -File -Recurse -ErrorAction SilentlyContinue)
    foreach ($file in $allFiles) {
        $ext = $file.Extension.ToLowerInvariant()
        if (Test-ReshelfIsAudioExtension -Extension $ext) { continue }
        if ($ext -eq '.cue') {
            if ($CueSheetPaths -contains $file.FullName) { continue }
            $ignored.Add([pscustomobject]@{ sourcePath = $file.FullName; reason = 'cue-sheet-not-used' })
            continue
        }

        if ($ext -in @('.m3u', '.m3u8', '.pls')) {
            $ignored.Add([pscustomobject]@{ sourcePath = $file.FullName; reason = 'playlist-file' })
            continue
        }

        $placement = if ($file.DirectoryName -eq $Path) { 'loose' } else { 'nested' }
        $kind = Resolve-ReshelfCompanionKind -FileName $file.Name -Extension $ext
        $companions.Add([pscustomobject]@{ sourcePath = $file.FullName; kind = $kind; placement = $placement })
    }

    return [pscustomobject]@{ Companions = @($companions); Ignored = @($ignored) }
}

# --- TagLibSharp --------------------------------------------------------------
# Import-ReshelfTagLibSharp itself now lives in Reshelf.Common.psm1 (shared with
# Reshelf.Implementation.psm1's tag-writing) - already imported above, no new import needed.

function Save-ReshelfEmbeddedCoverToCache {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [object]$Picture,

        [string]$DataHome
    )

    $bytes = $Picture.Data.Data
    if (-not $bytes -or $bytes.Length -eq 0) { return $null }

    # Get-ReshelfEffectiveDataHome (not Resolve-ReshelfDataHome directly) so this cache lands in
    # whatever data home the current run was actually configured with (Set-ReshelfTagLibSharpContext,
    # called once by Invoke-ReshelfRecognition) rather than always the repo-default '.data' folder.
    $DataHome = Get-ReshelfEffectiveDataHome -DataHome $DataHome

    $hashBytes = [System.Security.Cryptography.SHA256]::HashData($bytes)
    $hashHex = [System.Convert]::ToHexString($hashBytes).ToLowerInvariant()

    $extension = switch ($Picture.MimeType) {
        'image/png' { '.png' }
        'image/jpeg' { '.jpg' }
        default { '.jpg' }
    }

    $cacheDir = Join-Path $DataHome 'embedded-covers'
    if (-not (Test-Path -LiteralPath $cacheDir)) {
        New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
    }

    $cachePath = Join-Path $cacheDir "$hashHex$extension"
    if (-not (Test-Path -LiteralPath $cachePath -PathType Leaf)) {
        [System.IO.File]::WriteAllBytes($cachePath, $bytes)
    }

    return $cachePath
}

function Get-ReshelfAudioTags {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [string]$TagLibSharpPath,

        [string]$DataHome
    )

    Import-ReshelfTagLibSharp -TagLibSharpPath $TagLibSharpPath -DataHome $DataHome

    $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    $longPath = ConvertTo-ReshelfLongPath -Path $Path

    # Some real-world files carry a tag TagLib#'s properties reader for their format doesn't expect
    # (e.g. an ID3v2 tag prepended to a .mpc, which its MusePack stream-header parser can't skip) and
    # throw TagLib.CorruptFileException only while parsing audio properties (duration, etc.) - the
    # tags themselves are still perfectly readable. Falling back to a tag-only read (ReadStyle.None,
    # which skips property parsing entirely) keeps that track instead of failing the whole recognize
    # run over unrelated tracks; callers flag PropertiesUnavailable tracks for review.
    $propertiesUnavailable = $false
    try {
        $file = [TagLib.File]::Create($longPath)
    }
    catch [TagLib.CorruptFileException] {
        $file = [TagLib.File]::Create($longPath, [TagLib.ReadStyle]::None)
        $propertiesUnavailable = $true
    }
    try {
        $tag = $file.Tag
        $properties = $file.Properties

        $embeddedCoverPath = $null
        $pictures = @($tag.Pictures)
        if ($pictures.Count -gt 0) {
            $picture = $pictures | Where-Object { $_.Type -eq [TagLib.PictureType]::FrontCover } | Select-Object -First 1
            if (-not $picture) { $picture = $pictures[0] }
            $embeddedCoverPath = Save-ReshelfEmbeddedCoverToCache -Picture $picture -DataHome $DataHome
        }

        return @{
            Artist                = if ($tag.FirstPerformer) { $tag.FirstPerformer } else { $null }
            Album                 = if ($tag.Album) { $tag.Album } else { $null }
            Title                 = if ($tag.Title) { $tag.Title } else { $null }
            Format                = $extension.TrimStart('.')
            IsLossless            = Test-ReshelfIsLosslessFormat -Extension $extension
            DurationSeconds       = if ($propertiesUnavailable) { 0.0 } else { [double]$properties.Duration.TotalSeconds }
            EmbeddedCoverPath     = $embeddedCoverPath
            PropertiesUnavailable = $propertiesUnavailable
        }
    }
    finally {
        $file.Dispose()
    }
}

function Resolve-ReshelfArtistAlbumFromTags {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    # Real-world case (plan/12 milestone 3): a folder with audio files directly inside it and no
    # artist wrapper (e.g. "edbl" containing "edbl - edbl minibeats, vol.1 - 01 ....flac") was always
    # routed to unrecognized[], even when every track agrees on its own artist/album tags - dropping
    # a folder that's clearly a real release just because its *name* doesn't parse. Only promoted
    # when every track agrees (a mixed-tags folder is genuinely ambiguous and stays unrecognized, per
    # plan/10's "nothing ambiguous is auto-guessed").
    $audioFiles = Get-ReshelfAudioFilesInFolder -Path $Path
    if ($audioFiles.Count -eq 0) { return $null }

    $artist = $null
    $album = $null
    foreach ($file in $audioFiles) {
        $tags = Get-ReshelfAudioTags -Path $file.FullName
        if (-not $tags.Artist -or -not $tags.Album) { return $null }

        if ($null -eq $artist) {
            $artist = $tags.Artist
            $album = $tags.Album
        }
        elseif ((ConvertTo-ReshelfNormalizedText -Text $tags.Artist) -ne (ConvertTo-ReshelfNormalizedText -Text $artist) -or `
            (ConvertTo-ReshelfNormalizedText -Text $tags.Album) -ne (ConvertTo-ReshelfNormalizedText -Text $album)) {
            return $null
        }
    }

    return [pscustomobject]@{ Artist = $artist; Album = $album }
}

# --- Orchestration ---------------------------------------------------------------

function Resolve-ReshelfFolderKind {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Context,

        [string]$ArtistName
    )

    $leafName = Split-Path -Leaf $Path
    $inArtistLikeBody = $Context -in @('ArtistBody', 'CategoryBody', 'BandMemberBody')

    if ($inArtistLikeBody -and (Test-IsCategorySubfolder -Name $leafName)) {
        return [pscustomobject]@{ Kind = 'category'; ParentArtistName = $ArtistName }
    }

    if (Test-IsReleaseFolder -Path $Path) {
        return [pscustomobject]@{ Kind = 'release' }
    }

    if (Test-IsAlbumWrapperFolder -Path $Path) {
        return [pscustomobject]@{ Kind = 'album-wrapper' }
    }

    if ($inArtistLikeBody -and $ArtistName -and (Test-IsBandMemberFolder -Path $Path -ParentArtistName $ArtistName)) {
        return [pscustomobject]@{ Kind = 'band-member' }
    }

    if (Test-IsGroupingFolder -Path $Path) {
        return [pscustomobject]@{ Kind = 'grouping' }
    }

    $hasAnyAudio = (Get-ReshelfAudioFilesInFolder -Path $Path -Recurse).Count -gt 0
    if (-not $hasAnyAudio) {
        return [pscustomobject]@{ Kind = 'unrecognized'; Reason = 'no-audio-files' }
    }

    # By this point Test-IsReleaseFolder (above) has already claimed any folder with a direct audio
    # file as a 'release' (flagged nested-release-suspected downstream if it also has subfolders with
    # their own audio) - so any direct files still present here are necessarily non-audio (discography
    # .txt, liner notes, cover art, Thumbs.db, playlists, ...). That's common real-world clutter with
    # no structural meaning, so it's ignored rather than blocking recognition of the folder.

    # Not ambiguous (doesn't look like a grouping/category/band-member folder), and audio exists
    # somewhere below - treat as a transparent nesting layer rather than flagging it. At Root this
    # bootstraps the artist name from the folder's own name; deeper down, it just keeps walking
    # under whatever artist name is already in effect (e.g. a plain "Albums" filler folder).
    if ($Context -eq 'Root') {
        return [pscustomobject]@{ Kind = 'pass-through'; NewArtistName = $leafName }
    }

    return [pscustomobject]@{ Kind = 'pass-through'; NewArtistName = $null }
}

function New-ReshelfUnrecognizedEntry {
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

function Add-ReshelfInheritedReviewReasons {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [object]$Release,

        # Review reasons that apply to this release because of something an ancestor folder in the
        # walk already decided (e.g. 'grouping-folder-auto-resolved' - every release found below a
        # grouping folder is auto-classified rather than human-confirmed, so it still needs a look).
        [string[]]$InheritedReviewReasons = @()
    )

    if ($InheritedReviewReasons.Count -gt 0) {
        $Release.needsReview = $true
        $Release.reviewReasons = @(@($Release.reviewReasons) + $InheritedReviewReasons | Select-Object -Unique)
    }

    return $Release
}

function Merge-ReshelfArtistBucket {
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

    $key = ConvertTo-ReshelfNormalizedText -Text $ArtistName
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

function Split-ReshelfLeadingYear {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$Text
    )

    # The leading-4-digits-is-a-year guess only makes sense within the schema's own recognizedYear
    # range (1900-2100, proposal/recognition.schema.json) - without this bound, text that merely
    # starts with a 4-digit catalog number (e.g. a split "Artist - 3218 (Edition)" folder name,
    # real-world case) would misparse "3218" as a year and fail schema validation outright.
    # The optional whitespace-surrounded dash/en-dash covers the manifesto section 1 source format
    # "yyyy - Release Name"; an unspaced dash ("1999-2003 Anthology") is deliberately not a separator.
    if ($Text -match '^(\d{4})(?:\s+[-–])?\s+(.+)$' -and [int]$Matches[1] -ge 1900 -and [int]$Matches[1] -le 2100) {
        return [pscustomobject]@{ Year = [int]$Matches[1]; Title = $Matches[2].Trim() }
    }

    # Real-world case: "2006-Fire Without Flame" - a release year glued directly to the title with
    # no space at all. The spaced pattern above intentionally skips this (see its own comment), so
    # it falls through to here. Only accept it when the remainder does NOT itself look like a second
    # year (e.g. "1999-2003 Anthology") - that's the exact ambiguous shape the spaced-pattern comment
    # above is protecting against, and gluing-with-no-space must preserve it instead of guessing.
    if ($Text -match '^(\d{4})[-–](.+)$' -and [int]$Matches[1] -ge 1900 -and [int]$Matches[1] -le 2100) {
        $candidateTitle = $Matches[2].Trim()
        $looksLikeSecondYear = $candidateTitle -match '^(\d{4})(\s|$)' -and [int]$Matches[1] -ge 1900 -and [int]$Matches[1] -le 2100
        if (-not $looksLikeSecondYear) {
            return [pscustomobject]@{ Year = [int]$Matches[1]; Title = $candidateTitle }
        }
    }

    return [pscustomobject]@{ Year = $null; Title = $Text }
}

function Remove-ReshelfArtistNamePrefixFromTitle {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Title,

        [Parameter(Mandatory)]
        [string]$ArtistName
    )

    # Real-world case: a release folder repeats its own artist folder's name verbatim (often in a
    # different letter case), e.g. artist folder "Dance with the dead" containing release folder
    # "DANCE WITH THE DEAD - Blackout". Confirmed against the real Discogs API (2026-09-26): searching
    # with release_title still containing the artist name returns zero results, while the same search
    # with just "Blackout" returns real matches - so this is a deterministic, non-ambiguous cleanup,
    # not a guess that belongs in reviewReasons/needsReview like New-ReshelfReleaseRecord's other
    # splitting heuristics.
    # Real-world case (Aerosmith "Aerosmith (1973) - Aerosmith [USA CK 32005]"): the year can also sit
    # in parentheses/brackets between the artist name and the separator.
    $pattern = '^\s*' + [regex]::Escape($ArtistName) + '\s*(?:[\(\[]\s*(?<year>\d{4})\s*[\)\]]\s*)?[-:–—]\s*'
    $match = [regex]::Match($Title, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    if ($match.Success -and $match.Length -lt $Title.Length) {
        $year = $null
        if ($match.Groups['year'].Success) {
            $year = [int]$match.Groups['year'].Value
            # Same bound as Split-ReshelfLeadingYear - a 4-digit catalog number is not a year.
            if ($year -lt 1900 -or $year -gt 2100) {
                return [pscustomobject]@{ Title = $Title; WasStripped = $false; Year = $null }
            }
        }
        return [pscustomobject]@{ Title = $Title.Substring($match.Length); WasStripped = $true; Year = $year }
    }

    return [pscustomobject]@{ Title = $Title; WasStripped = $false; Year = $null }
}

function New-ReshelfReleaseRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$ArtistName,

        # When set, used instead of $Path's own leaf name for year/title parsing - needed when the
        # caller already stripped an artist-name prefix off the real on-disk folder name (see
        # Invoke-ReshelfFolderWalk's 'release' branch) and the real $Path can't reflect that. Also
        # used by the 'album-wrapper' branch, where $Path is the edition subfolder but title/year
        # must come from the album folder's own name instead.
        [string]$FolderNameOverride,

        # Set by the 'album-wrapper' branch when $Path is an edition/pressing subfolder nested
        # inside an album folder (e.g. "1989 Australia Albert 465262 2" inside
        # "1975 - T.N.T. (Australian Release)") - stored as-is, never parsed for year/title.
        [string]$EditionFolderName,

        # Set by the 'album-wrapper' branch only when an album folder holds more than one edition
        # subfolder - folds the edition folder name into the stableKey's album text so each edition
        # gets a distinct key (recognizedTitle/recognizedYear alone would collide, since they all
        # come from the same album folder name).
        [string]$StableKeyDisambiguator
    )

    $leafName = if ($FolderNameOverride) { $FolderNameOverride } else { Split-Path -Leaf $Path }
    $yearSplit = Split-ReshelfLeadingYear -Text $leafName
    $year = $yearSplit.Year
    $title = $yearSplit.Title

    $recognitionFlags = [System.Collections.Generic.List[string]]::new()
    $reviewReasons = [System.Collections.Generic.List[string]]::new()
    $needsReview = $false

    $prefixStrip = Remove-ReshelfArtistNamePrefixFromTitle -Title $title -ArtistName $ArtistName
    if ($prefixStrip.WasStripped) {
        $title = $prefixStrip.Title
        $recognitionFlags.Add('artist-name-prefix-stripped')

        if ($null -eq $year -and $null -ne $prefixStrip.Year) {
            $year = $prefixStrip.Year
        }

        # Real-world case (Nostromo's "Nostromo - 1998 - Argue FLAC"): the year sits between the
        # artist-name prefix and the title, so the leading-year parse above never saw it - only
        # after the artist prefix is gone does the remaining text start with the year.
        if ($null -eq $year) {
            $yearSplitAfterPrefixStrip = Split-ReshelfLeadingYear -Text $title
            if ($null -ne $yearSplitAfterPrefixStrip.Year) {
                $year = $yearSplitAfterPrefixStrip.Year
                $title = $yearSplitAfterPrefixStrip.Title
            }
        }
    }

    if ((ConvertTo-ReshelfLongPath -Path $Path) -ne $Path) {
        $recognitionFlags.Add('path-near-length-limit')
    }

    $discFolders = Get-ReshelfDiscFolders -Path $Path
    $tracks = [System.Collections.Generic.List[object]]::new()
    $cueSheets = [System.Collections.Generic.List[object]]::new()

    if ($discFolders.Count -eq 0) {
        if (Test-IsCueSheetRelease -Path $Path) {
            $audioFile = (Get-ReshelfAudioFilesInFolder -Path $Path)[0]
            $cueFilesHere = @(Get-ChildItem -LiteralPath $Path -File -Filter '*.cue' -ErrorAction SilentlyContinue)
            $cueFile = Get-ReshelfCueSheetPathForAudio -AudioFile $audioFile -CueFiles $cueFilesHere
            $cueSheets.Add([pscustomobject]@{ cueFilePath = $cueFile.FullName; audioFilePath = $audioFile.FullName })
            $cueResult = New-ReshelfCueVirtualTracks -AudioFile $audioFile -CueFile $cueFile -DiscFolderName $null
            $tracks.AddRange([object[]]$cueResult.Tracks)
            if ($cueResult.NeedsReview) { $needsReview = $true }
            foreach ($reason in $cueResult.ReviewReasons) { $reviewReasons.Add($reason) }
        }
        else {
            $ordered = Get-ReshelfTrackOrder -AudioFiles (Get-ReshelfAudioFilesInFolder -Path $Path)
            foreach ($item in $ordered) {
                $audioTags = Get-ReshelfAudioTags -Path $item.File.FullName
                if ($item.InferredOrder) { $recognitionFlags.Add('no-track-number') }
                if ($audioTags.PropertiesUnavailable) {
                    $needsReview = $true
                    $reviewReasons.Add('audio-properties-unreadable')
                }
                $tracks.Add([pscustomobject]@{
                        sourceFilePath            = $item.File.FullName
                        discFolder                = $null
                        originalFileName          = $item.File.Name
                        detectedTrackNumberInDisc = $item.Number
                        inferredTrackOrder        = $item.InferredOrder
                        existingTags              = [pscustomobject]@{ artist = $audioTags.Artist; album = $audioTags.Album; title = $audioTags.Title }
                        existingCoverArtPath      = $audioTags.EmbeddedCoverPath
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
                $audioFile = (Get-ReshelfAudioFilesInFolder -Path $discFolder.FullName)[0]
                $cueFilesHere = @(Get-ChildItem -LiteralPath $discFolder.FullName -File -Filter '*.cue' -ErrorAction SilentlyContinue)
                $cueFile = Get-ReshelfCueSheetPathForAudio -AudioFile $audioFile -CueFiles $cueFilesHere
                $cueSheets.Add([pscustomobject]@{ cueFilePath = $cueFile.FullName; audioFilePath = $audioFile.FullName })
                $cueResult = New-ReshelfCueVirtualTracks -AudioFile $audioFile -CueFile $cueFile -DiscFolderName $discFolder.Name
                $tracks.AddRange([object[]]$cueResult.Tracks)
                if ($cueResult.NeedsReview) { $needsReview = $true }
                foreach ($reason in $cueResult.ReviewReasons) { $reviewReasons.Add($reason) }
                continue
            }

            $ordered = Get-ReshelfTrackOrder -AudioFiles (Get-ReshelfAudioFilesInFolder -Path $discFolder.FullName)
            foreach ($item in $ordered) {
                $audioTags = Get-ReshelfAudioTags -Path $item.File.FullName
                if ($item.InferredOrder) { $recognitionFlags.Add('no-track-number') }
                if ($audioTags.PropertiesUnavailable) {
                    $needsReview = $true
                    $reviewReasons.Add('audio-properties-unreadable')
                }
                $tracks.Add([pscustomobject]@{
                        sourceFilePath            = $item.File.FullName
                        discFolder                = $discFolder.Name
                        originalFileName          = $item.File.Name
                        detectedTrackNumberInDisc = $item.Number
                        inferredTrackOrder        = $item.InferredOrder
                        existingTags              = [pscustomobject]@{ artist = $audioTags.Artist; album = $audioTags.Album; title = $audioTags.Title }
                        existingCoverArtPath      = $audioTags.EmbeddedCoverPath
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
        $looseAudioFiles = Get-ReshelfAudioFilesInFolder -Path $Path
        if ($looseAudioFiles.Count -gt 0) {
            $needsReview = $true
            $reviewReasons.Add('track-outside-disc-folder-suspected')
            $ordered = Get-ReshelfTrackOrder -AudioFiles $looseAudioFiles
            foreach ($item in $ordered) {
                $audioTags = Get-ReshelfAudioTags -Path $item.File.FullName
                if ($item.InferredOrder) { $recognitionFlags.Add('no-track-number') }
                if ($audioTags.PropertiesUnavailable) {
                    $needsReview = $true
                    $reviewReasons.Add('audio-properties-unreadable')
                }
                $tracks.Add([pscustomobject]@{
                        sourceFilePath            = $item.File.FullName
                        discFolder                = $null
                        originalFileName          = $item.File.Name
                        detectedTrackNumberInDisc = $item.Number
                        inferredTrackOrder        = $item.InferredOrder
                        existingTags              = [pscustomobject]@{ artist = $audioTags.Artist; album = $audioTags.Album; title = $audioTags.Title }
                        existingCoverArtPath      = $audioTags.EmbeddedCoverPath
                        format                    = $audioTags.Format
                        isLossless                = $audioTags.IsLossless
                        durationSeconds           = $audioTags.DurationSeconds
                        cueTimestamp              = $null
                        isCueVirtualTrack         = $false
                    })
            }
        }
    }

    $companions = Get-ReshelfCompanionFiles -Path $Path -CueSheetPaths @($cueSheets.cueFilePath)

    $confidence = 1.0
    if ($recognitionFlags.Count -gt 0) { $confidence = 0.8 }
    if ($needsReview) { $confidence = 0.5 }

    $stableKeyAlbum = if ($StableKeyDisambiguator) { "$title [$StableKeyDisambiguator]" } else { $title }

    return [pscustomobject]@{
        stableKey              = Get-ReshelfStableKey -Artist $ArtistName -Album $stableKeyAlbum -Year $year
        recognizedTitle        = $title
        recognizedYear         = $year
        editionFolderName      = if ($EditionFolderName) { $EditionFolderName } else { $null }
        sourceFolderPath       = $Path
        discFolderCount        = [Math]::Max(1, $discFolders.Count)
        tracks                 = @($tracks)
        companionFiles         = @($companions.Companions)
        ignoredFiles           = @($companions.Ignored)
        cueSheets              = @($cueSheets)
        recognitionConfidence  = $confidence
        recognitionFlags       = @($recognitionFlags | Select-Object -Unique)
        needsReview            = $needsReview
        reviewReasons          = @($reviewReasons | Select-Object -Unique)
    }
}

function Invoke-ReshelfFolderWalk {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Dir,

        [Parameter(Mandatory)]
        [string]$Context,

        [string]$ArtistName,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.Dictionary[string, object]]$ArtistsMap,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$UnrecognizedList,

        # Review reasons every release found below here must carry, because an ancestor folder in
        # this same walk was already auto-classified rather than human-confirmed (currently just a
        # grouping folder - see the 'grouping' case below).
        [string[]]$InheritedReviewReasons = @()
    )

    $children = @(Get-ChildItem -LiteralPath $Dir -Directory -ErrorAction SilentlyContinue)

    foreach ($child in $children) {
        $kind = Resolve-ReshelfFolderKind -Path $child.FullName -Context $Context -ArtistName $ArtistName

        switch ($kind.Kind) {
            'release' {
                $targetArtist = $ArtistName
                if (-not $targetArtist) {
                    # No artist context - see if the folder name itself is a flat "Artist - Album"
                    # pairing (e.g. "PULSAR OLYMP - 94Shine") before giving up. A guessed split is
                    # never silently trusted: it always forces human review (see plan/10's "nothing
                    # ambiguous is auto-guessed" principle).
                    if ($child.Name -match '^(.+?)\s+-\s+(.+)$') {
                        $splitArtist = $Matches[1].Trim()
                        $splitFolderName = $Matches[2].Trim()
                        if ($splitArtist -and $splitFolderName) {
                            $release = New-ReshelfReleaseRecord -Path $child.FullName -ArtistName $splitArtist -FolderNameOverride $splitFolderName
                            $release.needsReview = $true
                            $release.reviewReasons = @($release.reviewReasons) + 'artist-name-split-from-folder-name'
                            $release = Add-ReshelfInheritedReviewReasons -Release $release -InheritedReviewReasons $InheritedReviewReasons
                            Merge-ReshelfArtistBucket -ArtistsMap $ArtistsMap -ArtistName $splitArtist -ReleaseFolderParent (Split-Path -Parent $child.FullName) -Release $release
                            continue
                        }
                    }
                    $tagInfo = Resolve-ReshelfArtistAlbumFromTags -Path $child.FullName
                    if ($tagInfo) {
                        $release = New-ReshelfReleaseRecord -Path $child.FullName -ArtistName $tagInfo.Artist -FolderNameOverride $tagInfo.Album
                        $release.needsReview = $true
                        $release.reviewReasons = @($release.reviewReasons) + 'artist-and-album-from-tags'
                        $release = Add-ReshelfInheritedReviewReasons -Release $release -InheritedReviewReasons $InheritedReviewReasons
                        Merge-ReshelfArtistBucket -ArtistsMap $ArtistsMap -ArtistName $tagInfo.Artist -ReleaseFolderParent (Split-Path -Parent $child.FullName) -Release $release
                        continue
                    }
                    $childNames = @((Get-ChildItem -LiteralPath $child.FullName -ErrorAction SilentlyContinue).Name)
                    $UnrecognizedList.Add((New-ReshelfUnrecognizedEntry -Path $child.FullName -Reason 'release-without-artist-suspected' -Children $childNames))
                    continue
                }
                $release = New-ReshelfReleaseRecord -Path $child.FullName -ArtistName $targetArtist
                $release = Add-ReshelfInheritedReviewReasons -Release $release -InheritedReviewReasons $InheritedReviewReasons
                Merge-ReshelfArtistBucket -ArtistsMap $ArtistsMap -ArtistName $targetArtist -ReleaseFolderParent (Split-Path -Parent $child.FullName) -Release $release
            }
            'album-wrapper' {
                # A release folder ("yyyy - Title") that wraps one or more edition/pressing
                # subfolders instead of holding tracks directly - e.g.
                # "AC-DC\1975 - T.N.T. (Australian Release)\1989 Australia Albert 465262 2\<tracks>".
                # Title/year always come from this album folder's own name, never the edition
                # folder's - see Test-IsAlbumWrapperFolder above.
                $albumFolderName = $child.Name
                $editionFolders = @(Get-ChildItem -LiteralPath $child.FullName -Directory -ErrorAction SilentlyContinue |
                        Where-Object { Test-IsReleaseFolder -Path $_.FullName })
                $hasMultipleEditions = $editionFolders.Count -gt 1
                $hasLooseFiles = @(Get-ChildItem -LiteralPath $child.FullName -File -ErrorAction SilentlyContinue).Count -gt 0

                foreach ($editionFolder in $editionFolders) {
                    $disambiguator = if ($hasMultipleEditions) { $editionFolder.Name } else { $null }
                    $extraReviewReasons = [System.Collections.Generic.List[string]]::new()
                    if ($hasMultipleEditions) { $extraReviewReasons.Add('multiple-editions-in-album-folder') }
                    if ($hasLooseFiles) { $extraReviewReasons.Add('album-folder-has-loose-files') }

                    $targetArtist = $ArtistName
                    if (-not $targetArtist) {
                        # Same no-artist fallback as the 'release' case above, but splitting the
                        # ALBUM folder's own name (not the edition folder's).
                        if ($albumFolderName -match '^(.+?)\s+-\s+(.+)$') {
                            $splitArtist = $Matches[1].Trim()
                            $splitFolderName = $Matches[2].Trim()
                            if ($splitArtist -and $splitFolderName) {
                                $release = New-ReshelfReleaseRecord -Path $editionFolder.FullName -ArtistName $splitArtist `
                                    -FolderNameOverride $splitFolderName -EditionFolderName $editionFolder.Name -StableKeyDisambiguator $disambiguator
                                $release.needsReview = $true
                                $release.reviewReasons = @($release.reviewReasons) + 'artist-name-split-from-folder-name' + @($extraReviewReasons)
                                $release = Add-ReshelfInheritedReviewReasons -Release $release -InheritedReviewReasons $InheritedReviewReasons
                                Merge-ReshelfArtistBucket -ArtistsMap $ArtistsMap -ArtistName $splitArtist -ReleaseFolderParent (Split-Path -Parent $child.FullName) -Release $release
                                continue
                            }
                        }
                        $tagInfo = Resolve-ReshelfArtistAlbumFromTags -Path $editionFolder.FullName
                        if ($tagInfo) {
                            $release = New-ReshelfReleaseRecord -Path $editionFolder.FullName -ArtistName $tagInfo.Artist `
                                -FolderNameOverride $tagInfo.Album -EditionFolderName $editionFolder.Name -StableKeyDisambiguator $disambiguator
                            $release.needsReview = $true
                            $release.reviewReasons = @($release.reviewReasons) + 'artist-and-album-from-tags' + @($extraReviewReasons)
                            $release = Add-ReshelfInheritedReviewReasons -Release $release -InheritedReviewReasons $InheritedReviewReasons
                            Merge-ReshelfArtistBucket -ArtistsMap $ArtistsMap -ArtistName $tagInfo.Artist -ReleaseFolderParent (Split-Path -Parent $child.FullName) -Release $release
                            continue
                        }
                        $childNames = @((Get-ChildItem -LiteralPath $editionFolder.FullName -ErrorAction SilentlyContinue).Name)
                        $UnrecognizedList.Add((New-ReshelfUnrecognizedEntry -Path $editionFolder.FullName -Reason 'release-without-artist-suspected' -Children $childNames))
                        continue
                    }

                    $release = New-ReshelfReleaseRecord -Path $editionFolder.FullName -ArtistName $targetArtist `
                        -FolderNameOverride $albumFolderName -EditionFolderName $editionFolder.Name -StableKeyDisambiguator $disambiguator
                    if ($extraReviewReasons.Count -gt 0) {
                        $release.needsReview = $true
                        $release.reviewReasons = @($release.reviewReasons) + @($extraReviewReasons)
                    }
                    $release = Add-ReshelfInheritedReviewReasons -Release $release -InheritedReviewReasons $InheritedReviewReasons
                    Merge-ReshelfArtistBucket -ArtistsMap $ArtistsMap -ArtistName $targetArtist -ReleaseFolderParent (Split-Path -Parent $child.FullName) -Release $release
                }
            }
            'category' {
                $parentArtist = if ($kind.ParentArtistName) { $kind.ParentArtistName } else { $ArtistName }
                Invoke-ReshelfFolderWalk -Dir $child.FullName -Context 'CategoryBody' -ArtistName $parentArtist -ArtistsMap $ArtistsMap -UnrecognizedList $UnrecognizedList -InheritedReviewReasons $InheritedReviewReasons
            }
            'band-member' {
                Invoke-ReshelfFolderWalk -Dir $child.FullName -Context 'BandMemberBody' -ArtistName $child.Name -ArtistsMap $ArtistsMap -UnrecognizedList $UnrecognizedList -InheritedReviewReasons $InheritedReviewReasons
            }
            'grouping' {
                # Not an override escape hatch anymore - every grouping folder is walked, with each
                # subfolder treated as its own artist. Nothing ambiguous is auto-guessed silently
                # though (plan/10): every release found this way is flagged for a human to confirm,
                # since there's no name-based check that the subfolders really are distinct artists.
                $grandchildren = @(Get-ChildItem -LiteralPath $child.FullName -Directory -ErrorAction SilentlyContinue)
                foreach ($grandchild in $grandchildren) {
                    Invoke-ReshelfFolderWalk -Dir $grandchild.FullName -Context 'ArtistBody' -ArtistName $grandchild.Name `
                        -ArtistsMap $ArtistsMap -UnrecognizedList $UnrecognizedList `
                        -InheritedReviewReasons (@($InheritedReviewReasons) + 'grouping-folder-auto-resolved')
                }
            }
            'pass-through' {
                $nextArtist = if ($kind.NewArtistName) { $kind.NewArtistName } else { $ArtistName }
                $nextContext = if ($Context -eq 'Root') { 'ArtistBody' } else { $Context }
                Invoke-ReshelfFolderWalk -Dir $child.FullName -Context $nextContext -ArtistName $nextArtist -ArtistsMap $ArtistsMap -UnrecognizedList $UnrecognizedList -InheritedReviewReasons $InheritedReviewReasons
            }
            'unrecognized' {
                $childNames = @((Get-ChildItem -LiteralPath $child.FullName -ErrorAction SilentlyContinue).Name)
                $UnrecognizedList.Add((New-ReshelfUnrecognizedEntry -Path $child.FullName -Reason $kind.Reason -Children $childNames))
            }
        }
    }
}

function New-ReshelfRecognitionDocument {
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

function Invoke-ReshelfRecognition {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$SourceRoot,

        [Parameter(Mandatory)]
        [string]$SessionId,

        [string]$DataHome,

        [string]$TagLibSharpPath
    )

    if (-not $DataHome) { $DataHome = Resolve-ReshelfDataHome }

    if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) {
        throw "Source root '$SourceRoot' does not exist or is not a directory."
    }
    $resolvedSourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path

    Set-ReshelfTagLibSharpContext -TagLibSharpPath $TagLibSharpPath -DataHome $DataHome

    $artistsMap = [System.Collections.Generic.Dictionary[string, object]]::new()
    $unrecognizedList = [System.Collections.Generic.List[object]]::new()

    Invoke-ReshelfFolderWalk -Dir $resolvedSourceRoot -Context 'Root' -ArtistName $null `
        -ArtistsMap $artistsMap -UnrecognizedList $unrecognizedList

    $document = New-ReshelfRecognitionDocument -SessionId $SessionId -SourceRoot $resolvedSourceRoot -ArtistsMap $artistsMap -UnrecognizedList $unrecognizedList

    $outputPath = Join-Path $DataHome 'sessions' $SessionId 'recognition.json'
    Set-ReshelfJsonFile -Path $outputPath -InputObject $document -SchemaName recognition -Depth 20 | Out-Null

    return (Get-Content -LiteralPath $outputPath -Raw | ConvertFrom-Json)
}

Export-ModuleMember -Function Invoke-ReshelfRecognition, Get-ReshelfAudioTags
