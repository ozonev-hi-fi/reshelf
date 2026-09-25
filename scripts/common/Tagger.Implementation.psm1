#Requires -Version 7.4

Import-Module (Join-Path $PSScriptRoot 'Tagger.Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Tagger.Json.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Tagger.LossyTracking.psm1') -Force

# Invoke-TaggerImplementation's last step calls Set-TaggerSessionStage (Tagger.Settings.psm1), but
# that module is deliberately NOT imported here: re-importing a module that a caller (Tagger.ps1,
# Invoke-Implementation.ps1) already imported directly hides that caller's own top-level copy of
# its functions (PowerShell nested-module shadowing - verified empirically, not theoretical).
# Every caller of this module must import Tagger.Settings.psm1 itself before calling
# Invoke-TaggerImplementation, same as Tagger.ps1's 'propose' case already relies on having
# imported Tagger.Settings.psm1 itself rather than via Tagger.EditProposal.psm1.

# --- apply-log.json ----------------------------------------------------------------

function Get-TaggerApplyLogPath {
    [CmdletBinding()]
    param(
        [string]$DataHome
    )

    if (-not $DataHome) { $DataHome = Resolve-TaggerDataHome }
    return Join-Path $DataHome 'apply-log.json'
}

function Get-TaggerApplyLog {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [string]$DataHome
    )

    $logPath = Get-TaggerApplyLogPath -DataHome $DataHome

    if (-not (Test-Path -LiteralPath $logPath -PathType Leaf)) {
        return @()
    }

    if (-not (Test-TaggerJson -SchemaName apply-log -Path $logPath)) {
        throw "Apply log at '$logPath' does not match the apply-log schema."
    }

    return @(Get-Content -LiteralPath $logPath -Raw | ConvertFrom-Json)
}

function Get-TaggerApplyLogEntry {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [string]$StableKey,

        [string]$DataHome
    )

    return Get-TaggerApplyLog -DataHome $DataHome | Where-Object { $_.stableKey -eq $StableKey } | Select-Object -First 1
}

function Add-TaggerApplyLogEntry {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [string]$StableKey,

        [Parameter(Mandatory)]
        [datetime]$AppliedAtUtc,

        [Parameter(Mandatory)]
        [ValidateSet('applied', 'failed', 'skipped')]
        [string]$Status,

        [Parameter(Mandatory)]
        [string]$TargetPath,

        [Parameter(Mandatory)]
        [string]$SourceFileSetHash,

        [AllowNull()]
        [string]$ErrorMessage,

        [Parameter(Mandatory)]
        [bool]$Truncated,

        [string]$DataHome
    )

    if (-not $DataHome) { $DataHome = Resolve-TaggerDataHome }

    # Upsert, not touch-only (unlike Add-TaggerLossyTrackingEntry) - a retry after a failure must
    # replace the old row wholesale (e.g. failed -> applied), not just bump a timestamp on it.
    $log = @(Get-TaggerApplyLog -DataHome $DataHome | Where-Object { $_.stableKey -ne $StableKey })

    $entry = [pscustomobject]@{
        stableKey         = $StableKey
        appliedAtUtc      = $AppliedAtUtc.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        status            = $Status
        targetPath        = $TargetPath
        sourceFileSetHash = $SourceFileSetHash
        errorMessage      = $ErrorMessage
        truncated         = $Truncated
    }
    $log = @($log) + $entry

    $logPath = Get-TaggerApplyLogPath -DataHome $DataHome
    Set-TaggerJsonFile -Path $logPath -InputObject $log -SchemaName apply-log -Depth 10 | Out-Null

    return $log
}

function Test-TaggerReleaseNeedsApply {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [object]$Release,

        [string]$DataHome
    )

    $entry = Get-TaggerApplyLogEntry -StableKey $Release.stableKey -DataHome $DataHome

    try {
        $sourcePaths = @($Release.tracks.sourceFilePath | Select-Object -Unique)
        $currentHash = Get-TaggerFileSetHash -FilePaths $sourcePaths
    }
    catch {
        # Source files can legitimately be gone by the time of a later re-run: a cue release's
        # single source file is always deleted after a successful split (manifesto SS4.4), and a
        # 'move'-mode release's sources are deleted after a successful commit. Their absence,
        # paired with a recorded 'applied' entry, is exactly what an already-completed release
        # looks like on rerun - not a reason to recompute a hash that has nothing left to hash.
        # No Hash is returned here (there's nothing left to hash) - the caller falls back to its
        # own sentinel for the rare case this release still needs to be (re-)applied anyway.
        $needsApply = -not ($entry -and $entry.status -eq 'applied')
        return [pscustomobject]@{ NeedsApply = $needsApply; Hash = $null }
    }

    $needsApply = (-not $entry) -or ($entry.status -ne 'applied') -or ($entry.sourceFileSetHash -ne $currentHash)
    return [pscustomobject]@{ NeedsApply = $needsApply; Hash = $currentHash }
}

# --- Cue splitting -------------------------------------------------------------------

function ConvertFrom-TaggerCueTrackRanges {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Tracks
    )

    $sorted = @($Tracks | Sort-Object -Property proposedTrackNumber)

    $result = for ($i = 0; $i -lt $sorted.Count; $i++) {
        $endTimestamp = if ($i -lt ($sorted.Count - 1)) { $sorted[$i + 1].cueTimestamp } else { $null }
        [pscustomobject]@{
            Track          = $sorted[$i]
            StartTimestamp = $sorted[$i].cueTimestamp
            EndTimestamp   = $endTimestamp
        }
    }

    return @($result)
}

function Invoke-TaggerFfmpegSplit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SourceAudioPath,

        [Parameter(Mandatory)]
        [string]$StartTimestamp,

        [AllowNull()]
        [string]$EndTimestamp,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter(Mandatory)]
        [string]$FfmpegPath
    )

    # Start-Process -ArgumentList joins array elements with a single space and does not quote
    # elements containing spaces - a real path like "...\1994 Live In Concert (Bootleg)\..." would
    # otherwise be split into multiple broken argv entries by the child ffmpeg process. Every
    # path-bearing value gets wrapped in literal double quotes; flags/timestamps don't need it.
    $ffmpegArgs = [System.Collections.Generic.List[string]]::new()
    $ffmpegArgs.AddRange([string[]]@('-hide_banner', '-loglevel', 'error', '-y', '-i', "`"$SourceAudioPath`"", '-ss', $StartTimestamp))
    if ($EndTimestamp) { $ffmpegArgs.AddRange([string[]]@('-to', $EndTimestamp)) }
    $ffmpegArgs.AddRange([string[]]@('-c', 'copy', "`"$OutputPath`""))

    $process = Start-Process -FilePath $FfmpegPath -ArgumentList $ffmpegArgs -NoNewWindow -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "ffmpeg split failed (exit code $($process.ExitCode)) for '$SourceAudioPath' -> '$OutputPath'."
    }
}

function Invoke-TaggerFfmpegResize {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SourceImagePath,

        [Parameter(Mandatory)]
        [int]$MaxDimension,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter(Mandatory)]
        [string]$FfmpegPath
    )

    # Scale down only - min(N,iw/ih) + force_original_aspect_ratio=decrease never upscales a
    # source that's already smaller than the target max dimension.
    $scaleFilter = "scale=w='min($MaxDimension,iw)':h='min($MaxDimension,ih)':force_original_aspect_ratio=decrease"
    # See Invoke-TaggerFfmpegSplit - path-bearing arguments need literal double quotes because
    # Start-Process -ArgumentList does not quote array elements containing spaces.
    $ffmpegArgs = @('-hide_banner', '-loglevel', 'error', '-y', '-i', "`"$SourceImagePath`"", '-vf', $scaleFilter, "`"$OutputPath`"")

    $process = Start-Process -FilePath $FfmpegPath -ArgumentList $ffmpegArgs -NoNewWindow -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "ffmpeg resize failed (exit code $($process.ExitCode)) for '$SourceImagePath' -> '$OutputPath'."
    }
}

function Invoke-TaggerCoverDownload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Url,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    # A Discogs-matched release's chosenCandidateUrl is a remote https:// image URL - only the
    # no-match fallback in Tagger.EditProposal.psm1 ever picks a local companion-file path.
    # Without this, cover art would only ever get embedded in that fallback case.
    Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing
}

# --- Tagging -------------------------------------------------------------------------
# Tags and cover art are written via TagLibSharp (in-process, Add-Type - no external process, no
# GUI, no manual Action-Group authoring), the same library Tagger.Recognition.psm1 uses to read
# tags. Kept as its own function (no inline TagLib calls elsewhere) so tests can
# `Mock -ModuleName Tagger.Implementation Set-TaggerAudioTags` the same way the ffmpeg/cover-
# download wrappers are mocked.

function Set-TaggerAudioTags {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [object]$Tags,

        [string]$CoverImagePath,

        [string]$TagLibSharpPath,

        [string]$DataHome
    )

    Import-TaggerTagLibSharp -TagLibSharpPath $TagLibSharpPath -DataHome $DataHome

    $file = [TagLib.File]::Create((ConvertTo-TaggerLongPath -Path $Path))
    try {
        $file.Tag.Performers = @($Tags.artist)
        $file.Tag.AlbumArtists = @($Tags.albumArtist)
        $file.Tag.Album = $Tags.album
        $file.Tag.Year = [uint32]$Tags.year
        $file.Tag.Disc = [uint32]$Tags.discNumber
        $file.Tag.Track = [uint32]$Tags.track
        $file.Tag.Title = $Tags.title

        if ($CoverImagePath -and (Test-Path -LiteralPath (ConvertTo-TaggerLongPath -Path $CoverImagePath) -PathType Leaf)) {
            # The Picture(string) constructor reads the file's bytes and auto-detects MimeType from
            # its extension (verified against the real TagLibSharp.dll: a .jpg round-trips as
            # image/jpeg) - simpler and less error-prone than building a ByteVector by hand.
            $picture = [TagLib.Picture]::new((ConvertTo-TaggerLongPath -Path $CoverImagePath))
            $picture.Type = [TagLib.PictureType]::FrontCover
            $file.Tag.Pictures = @($picture)
        }

        $file.Save()
    }
    finally {
        $file.Dispose()
    }
}

# --- Companion files -----------------------------------------------------------------
# The relative-path helper itself lives in Tagger.Common.psm1 (shared with
# Tagger.Recognition.psm1) - already imported above.

function Resolve-TaggerCompanionTargetPath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [object]$CompanionFile,

        [Parameter(Mandatory)]
        [string]$ReleaseSourceFolderPath,

        [Parameter(Mandatory)]
        [string]$ReleaseFolderPath
    )

    $fileNameSan = (ConvertTo-SafeFileName -Name (Split-Path -Leaf $CompanionFile.sourcePath)).SafeName

    if ($CompanionFile.placement -eq 'nested') {
        $relative = Get-TaggerRelativePath -SourceRoot $ReleaseSourceFolderPath -Path $CompanionFile.sourcePath
        $relativeDir = Split-Path -Parent $relative
        if ($relativeDir) {
            return Join-Path $ReleaseFolderPath $relativeDir $fileNameSan
        }
        return Join-Path $ReleaseFolderPath $fileNameSan
    }

    # Loose: manifesto SS4.5 - companions must sort after numbered tracks, so a sanitized name
    # that would otherwise start with a digit gets a fixed '_' prefix.
    if ($fileNameSan -match '^\d') {
        $fileNameSan = "_$fileNameSan"
    }
    return Join-Path $ReleaseFolderPath $fileNameSan
}

# --- Path-length truncation -----------------------------------------------------------
# ConvertTo-TaggerLongPath (Tagger.Common.psm1) already lifts the hard ~260-char Windows path
# limit via the \\?\ prefix, but plan/10 also wants human-facing names kept short by construction:
# some external tools and everyday Explorer/zip/cloud-sync use don't handle \\?\ consistently, so a
# fully-assembled target path is still truncated above ~250 chars, with the cut always recorded
# rather than silent. NOTE: the guarantee this produces (final path <= MaxPathLength) assumes
# TargetRoot itself, which can never be truncated, still leaves room for at least the structural
# prefixes/extension - an already-very-deep TargetRoot is a real, if narrow, ceiling on what this
# can promise, same as it would be for any path-shortening scheme.

function Split-TaggerTrackFileName {
    # Splits a proposed track file name into its never-truncated leading track-number prefix (if
    # any), the truncatable title body, and the extension. Mirrors both forms
    # ConvertFrom-TaggerTrackFileName (Tagger.Common.psm1) already accepts - dash-separated
    # ("01 - Title") and space-separated ("01 Title") - so the "never truncate the NN prefix"
    # guarantee holds regardless of which TrackFileTemplate produced the name, not just the default.
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$FileName
    )

    $extension = [System.IO.Path]::GetExtension($FileName)
    $withoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($FileName)

    if ($withoutExtension -match '^(\d+\s*[-–]\s*)') {
        $prefix = $Matches[1]
    }
    elseif ($withoutExtension -match '^(\d+\s+)') {
        $prefix = $Matches[1]
    }
    else {
        $prefix = ''
    }

    return [pscustomobject]@{
        Prefix    = $prefix
        Body      = $withoutExtension.Substring($prefix.Length)
        Extension = $extension
    }
}

function Get-TaggerRemainingPathBudget {
    # MaxLength minus what's already consumed (including the separator leading into this segment)
    # minus what must be reserved for every segment still to come (including their own leading
    # separators) - centralizes the subtraction so each call site only has to state its own
    # consumed/reserved tallies instead of re-deriving the whole formula independently.
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [int]$MaxLength,

        [Parameter(Mandatory)]
        [int]$Consumed,

        [Parameter(Mandatory)]
        [int]$Reserved
    )

    return [Math]::Max($MaxLength - $Consumed - $Reserved, 1)
}

function Resolve-TaggerTruncatedReleaseNames {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [object]$Release,

        [Parameter(Mandatory)]
        [string]$TargetRoot,

        [int]$MaxPathLength = 250
    )

    $truncatedAny = $false
    $root = $TargetRoot.TrimEnd('\', '/')

    # Release folder (Level 2): preserve a leading "yyyy " prefix if the name has one. Bounds-
    # checked to 1900-2100 like Tagger.Recognition.psm1's equivalent pattern, so a catalog-number-
    # prefixed title (e.g. "3218 (Edition) Album Title") isn't mistaken for a year and protected
    # from truncation it was never meant to have.
    $releaseRaw = $Release.proposed.releaseFolderName
    $releasePrefix = ''
    $releaseBody = $releaseRaw
    if ($releaseRaw -match '^(\d{4})(\s+)' -and [int]$Matches[1] -ge 1900 -and [int]$Matches[1] -le 2100) {
        $releasePrefix = $Matches[1] + $Matches[2]
        $releaseBody = $releaseRaw.Substring($releasePrefix.Length)
    }
    # Never-truncated floor for the release folder (prefix + at least 1 body char) - reserved up
    # front so the artist-folder truncation below never eats into the room the release folder needs.
    $releaseFloor = $releasePrefix.Length + 1

    # Parse every track's prefix/body/extension exactly once and reuse it below instead of
    # re-parsing per track a second time in the main loop.
    $parsedTracks = @($Release.tracks) | ForEach-Object {
        [pscustomobject]@{
            Original = $_.proposedFileName
            Split    = Split-TaggerTrackFileName -FileName $_.proposedFileName
        }
    }

    # Per-track floor (prefix + at least 1 body char + extension), plus a reserve for the '~N'
    # disambiguation tag a name collision (see below) might still need to append - sized to the
    # largest tag any track in this release could ever need (at most Count distinct collisions).
    $maxTrackFloor = if ($parsedTracks) {
        ($parsedTracks | ForEach-Object { $_.Split.Prefix.Length + 1 + $_.Split.Extension.Length } | Measure-Object -Maximum).Maximum
    }
    else { 1 }
    $disambiguationReserve = 1 + [Math]::Max(1, $parsedTracks.Count).ToString().Length
    $maxTrackFloor += $disambiguationReserve

    # Artist folder (Level 1): no structural prefix defined for it, so the whole name is the body.
    # Reserves room for '\' + release folder's floor + '\' + the largest track floor, so truncating
    # the artist name can never starve the levels below it of their own minimum.
    $artistBudget = Get-TaggerRemainingPathBudget -MaxLength $MaxPathLength -Consumed ($root.Length + 1) `
        -Reserved (1 + $releaseFloor + 1 + $maxTrackFloor)
    $artistResult = ConvertTo-TaggerTruncatedSegment -Prefix '' -Body $Release.proposed.artistFolderName -Suffix '' -MaxLength $artistBudget
    if ($artistResult.Truncated) { $truncatedAny = $true }
    $artistFolderName = $artistResult.Value

    # Release folder budget likewise reserves room for '\' + the largest track floor after it.
    $releaseBudget = Get-TaggerRemainingPathBudget -MaxLength $MaxPathLength -Consumed ($root.Length + 1 + $artistFolderName.Length + 1) `
        -Reserved (1 + $maxTrackFloor)
    $releaseResult = ConvertTo-TaggerTruncatedSegment -Prefix $releasePrefix -Body $releaseBody -Suffix '' `
        -MaxLength ([Math]::Max($releaseBudget, $releaseFloor))
    if ($releaseResult.Truncated) { $truncatedAny = $true }
    $releaseFolderName = $releaseResult.Value

    # Track file names: preserve the leading numeric track-order prefix and the file extension.
    # Because the folder levels above reserved room for $maxTrackFloor (which already includes the
    # disambiguation reserve), every track's own floor - and one collision retry - is guaranteed to
    # fit in the budget computed here.
    $releasePathLength = $root.Length + 1 + $artistFolderName.Length + 1 + $releaseFolderName.Length + 1
    $trackBudget = Get-TaggerRemainingPathBudget -MaxLength $MaxPathLength -Consumed $releasePathLength -Reserved 0

    $trackFileNames = @{}
    $usedNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($parsedTrack in $parsedTracks) {
        $prefix = $parsedTrack.Split.Prefix
        $body = $parsedTrack.Split.Body
        $extension = $parsedTrack.Split.Extension

        # Attempt 1 has no disambiguation tag; a collision with an already-used name (only possible
        # when two tracks share the same prefix - e.g. neither has a recognizable track-number
        # prefix - and their bodies land on the same truncated text) retries with a "~2", "~3", ...
        # tag appended before the extension instead of one track silently overwriting another in
        # staging, per this project's "never silently overwritten" rule (plan/10's re-run table).
        $attempt = 1
        do {
            $suffix = if ($attempt -eq 1) { $extension } else { "~$attempt$extension" }
            $candidate = ConvertTo-TaggerTruncatedSegment -Prefix $prefix -Body $body -Suffix $suffix -MaxLength $trackBudget
            if ($candidate.Truncated) { $truncatedAny = $true }
            $finalName = $candidate.Value
            $attempt++
        } while (-not $usedNames.Add($finalName))

        $trackFileNames[$parsedTrack.Original] = $finalName
    }

    return [pscustomobject]@{
        ArtistFolderName  = $artistFolderName
        ReleaseFolderName = $releaseFolderName
        TrackFileNames    = $trackFileNames
        Truncated         = $truncatedAny
    }
}

# --- Per-release staging ---------------------------------------------------------------

function Invoke-TaggerReleaseStaging {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [object]$Release,

        [Parameter(Mandatory)]
        [string]$StagingRoot,

        [Parameter(Mandatory)]
        [string]$TargetRoot,

        [Parameter(Mandatory)]
        [string]$FfmpegPath,

        [string]$TagLibSharpPath
    )

    $truncatedLayout = Resolve-TaggerTruncatedReleaseNames -Release $Release -TargetRoot $TargetRoot
    $finalTargetPath = Join-Path $TargetRoot $truncatedLayout.ArtistFolderName $truncatedLayout.ReleaseFolderName
    $stagingReleasePath = Join-Path $StagingRoot $Release.stableKey
    $truncated = $truncatedLayout.Truncated

    try {
        if ($PSCmdlet.ShouldProcess($stagingReleasePath, 'Create staging folder')) {
            New-Item -ItemType Directory -Path (ConvertTo-TaggerLongPath -Path $stagingReleasePath) -Force | Out-Null
        }

        $stagedTrackInfos = [System.Collections.Generic.List[object]]::new()

        if ($Release.cueSheet) {
            $ranges = ConvertFrom-TaggerCueTrackRanges -Tracks $Release.tracks
            foreach ($range in $ranges) {
                $outputPath = Join-Path $stagingReleasePath $truncatedLayout.TrackFileNames[$range.Track.proposedFileName]
                if ($PSCmdlet.ShouldProcess($outputPath, 'ffmpeg split track from cue source')) {
                    Invoke-TaggerFfmpegSplit -SourceAudioPath $Release.cueSheet.audioFilePath -StartTimestamp $range.StartTimestamp `
                        -EndTimestamp $range.EndTimestamp -OutputPath $outputPath -FfmpegPath $FfmpegPath
                }
                $stagedTrackInfos.Add([pscustomobject]@{ FilePath = $outputPath; Tags = $range.Track.tags })
            }

            # Defensive: the ffmpeg wrapper already throws on a non-zero exit code, so this only
            # catches the rarer case of it exiting 0 without actually producing every output file.
            if (-not $WhatIfPreference) {
                foreach ($info in $stagedTrackInfos) {
                    if (-not (Test-Path -LiteralPath (ConvertTo-TaggerLongPath -Path $info.FilePath) -PathType Leaf)) {
                        throw "Cue split for release '$($Release.stableKey)' did not produce expected file '$($info.FilePath)'."
                    }
                }
            }
        }
        else {
            foreach ($track in $Release.tracks) {
                $outputPath = Join-Path $stagingReleasePath $truncatedLayout.TrackFileNames[$track.proposedFileName]
                if ($PSCmdlet.ShouldProcess($outputPath, 'Copy track')) {
                    Copy-Item -LiteralPath (ConvertTo-TaggerLongPath -Path $track.sourceFilePath) -Destination (ConvertTo-TaggerLongPath -Path $outputPath) -Force
                }
                $stagedTrackInfos.Add([pscustomobject]@{ FilePath = $outputPath; Tags = $track.tags })
            }
        }

        $coverOutputPath = $null
        if ($Release.coverArt.chosenCandidateUrl) {
            # A dot-prefixed tool-specific name, never a plain 'cover.jpg': a loose companion named
            # 'cover.jpg' (valid per manifesto SS4.5) is copied into this same staging folder below,
            # and a shared name let the working-file cleanup delete that real companion with it.
            $coverOutputPath = Join-Path $stagingReleasePath '.tagger-cover-resized.jpg'
            $sourceForResize = $Release.coverArt.chosenCandidateUrl

            if ($sourceForResize -match '^https?://') {
                $downloadPath = Join-Path $stagingReleasePath 'cover-source.download'
                if ($PSCmdlet.ShouldProcess($downloadPath, 'Download cover art')) {
                    Invoke-TaggerCoverDownload -Url $sourceForResize -OutputPath $downloadPath
                }
                $sourceForResize = $downloadPath
            }

            if ($PSCmdlet.ShouldProcess($coverOutputPath, 'Resize cover art')) {
                Invoke-TaggerFfmpegResize -SourceImagePath $sourceForResize -MaxDimension $Release.coverArt.targetMaxDimension `
                    -OutputPath $coverOutputPath -FfmpegPath $FfmpegPath
            }
        }

        foreach ($info in $stagedTrackInfos) {
            if ($PSCmdlet.ShouldProcess($info.FilePath, 'Write tags via TagLibSharp')) {
                Set-TaggerAudioTags -Path $info.FilePath -Tags $info.Tags -CoverImagePath $coverOutputPath -TagLibSharpPath $TagLibSharpPath
            }
        }

        foreach ($companion in @($Release.companionFiles)) {
            $companionTargetPath = Resolve-TaggerCompanionTargetPath -CompanionFile $companion -ReleaseSourceFolderPath $Release.sourceFolderPath `
                -ReleaseFolderPath $stagingReleasePath
            if ($PSCmdlet.ShouldProcess($companionTargetPath, 'Copy companion file')) {
                $companionParentDir = Split-Path -Path $companionTargetPath -Parent
                if ($companionParentDir -and -not (Test-Path -LiteralPath (ConvertTo-TaggerLongPath -Path $companionParentDir))) {
                    New-Item -ItemType Directory -Path (ConvertTo-TaggerLongPath -Path $companionParentDir) -Force | Out-Null
                }
                Copy-Item -LiteralPath (ConvertTo-TaggerLongPath -Path $companion.sourcePath) -Destination (ConvertTo-TaggerLongPath -Path $companionTargetPath) -Force
            }
        }

        # The resized cover / the raw cover download are working files that only exist to get
        # embedded into each track's tags - manifesto SS4 defines an exact target layout (tracks +
        # companions only; a Discogs cover lives embedded, not as a loose file), so neither may
        # survive into the moved-to-target release folder. A source companion file is not a
        # working file and is left alone.
        if ($Release.coverArt.chosenCandidateUrl -and $PSCmdlet.ShouldProcess($coverOutputPath, 'Remove cover-art working files')) {
            Remove-Item -LiteralPath $coverOutputPath -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath (Join-Path $stagingReleasePath 'cover-source.download') -Force -ErrorAction SilentlyContinue
        }

        return [pscustomobject]@{ Success = $true; TargetPath = $finalTargetPath; Truncated = $truncated; ErrorMessage = $null }
    }
    catch {
        return [pscustomobject]@{ Success = $false; TargetPath = $finalTargetPath; Truncated = $truncated; ErrorMessage = $_.Exception.Message }
    }
}

function Move-TaggerStagedReleaseToTarget {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$StagingPath,

        [Parameter(Mandatory)]
        [string]$FinalPath
    )

    if ($PSCmdlet.ShouldProcess($FinalPath, "Move staged release from '$StagingPath'")) {
        $parentDir = Split-Path -Path $FinalPath -Parent
        if ($parentDir -and -not (Test-Path -LiteralPath (ConvertTo-TaggerLongPath -Path $parentDir))) {
            New-Item -ItemType Directory -Path (ConvertTo-TaggerLongPath -Path $parentDir) -Force | Out-Null
        }

        # A pre-existing final folder only happens for the update-existing/replace-existing case -
        # targetAction already decided back in Step 6 this is a clean replace, never a conflict -
        # so removing it here is safe. Move-Item onto an existing folder would otherwise fail.
        if (Test-Path -LiteralPath (ConvertTo-TaggerLongPath -Path $FinalPath)) {
            Remove-Item -LiteralPath (ConvertTo-TaggerLongPath -Path $FinalPath) -Recurse -Force
        }

        Move-Item -LiteralPath (ConvertTo-TaggerLongPath -Path $StagingPath) -Destination (ConvertTo-TaggerLongPath -Path $FinalPath) -Force
    }

    return $FinalPath
}

# --- Orchestration ---------------------------------------------------------------------

function Invoke-TaggerImplementation {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$SessionId,

        [Parameter(Mandatory)]
        [string]$ProposalPath,

        [Parameter(Mandatory)]
        [string]$TargetRoot,

        [Parameter(Mandatory)]
        [ValidateSet('copy', 'move')]
        [string]$CopyMode,

        [Parameter(Mandatory)]
        [string]$FfmpegPath,

        [string]$TagLibSharpPath,

        [string]$DataHome,

        [switch]$IncludeUnresolved
    )

    if (-not $DataHome) { $DataHome = Resolve-TaggerDataHome }

    if (-not (Test-TaggerJson -SchemaName proposal -Path $ProposalPath)) {
        throw "Proposal document at '$ProposalPath' does not match the proposal schema."
    }
    $proposal = Get-Content -LiteralPath $ProposalPath -Raw | ConvertFrom-Json

    $stagingRoot = Join-Path $TargetRoot '.tagger-staging'
    $releases = @($proposal.artists.releases)

    $appliedCount = 0
    $skippedCount = 0
    $failedCount = 0

    foreach ($release in $releases) {
        # humanReview.required/.resolved is the one general "does a human need to look at this
        # before apply touches it" gate (set by Tagger.EditProposal.psm1's New-TaggerProposedRelease
        # for every reason it flags a release, not just an ambiguous Discogs match) - gating on it
        # directly, for whatever reason it was set, is correct; special-casing just the ambiguous
        # case let a targetAction: "conflict" release (pre-existing, different target content)
        # proceed straight through to Move-TaggerStagedReleaseToTarget's unconditional overwrite.
        if (-not $release.humanReview.resolved -and -not $IncludeUnresolved) {
            $skippedCount++
            continue
        }

        $needsApplyResult = Test-TaggerReleaseNeedsApply -Release $release -DataHome $DataHome
        if (-not $needsApplyResult.NeedsApply) {
            $skippedCount++
            continue
        }

        $stagingReleasePath = Join-Path $stagingRoot $release.stableKey
        $finalTargetPath = Join-Path $TargetRoot $release.proposed.artistFolderName $release.proposed.releaseFolderName
        # Test-TaggerReleaseNeedsApply already computed this hash once for the skip decision - reuse
        # it instead of hashing every source file again. It can be $null when the source files were
        # legitimately gone (cue/move-mode cleanup from a prior run) but the release still needs
        # (re-)applying anyway (e.g. a previously-failed attempt) - fall back to the same
        # "can't compute one" sentinel used elsewhere in this function for that case.
        $sourceHash = if ($needsApplyResult.Hash) { $needsApplyResult.Hash } else { 'unavailable-source-missing' }

        # Reset before every iteration - the outer catch below falls back to this when a failure
        # happens before staging assigns it, and a stale value from a *previous* release would
        # otherwise leak through if that ever happened.
        $stagingResult = $null

        try {
            $stagingResult = Invoke-TaggerReleaseStaging -Release $release -StagingRoot $stagingRoot -TargetRoot $TargetRoot `
                -FfmpegPath $FfmpegPath -TagLibSharpPath $TagLibSharpPath

            if ($stagingResult.Success) {
                if ($PSCmdlet.ShouldProcess($stagingResult.TargetPath, 'Commit staged release to target')) {
                    Move-TaggerStagedReleaseToTarget -StagingPath $stagingReleasePath -FinalPath $stagingResult.TargetPath | Out-Null
                }

                if ($release.cueSheet) {
                    # Manifesto SS4.4: the single-file+cue source is fully superseded by the split,
                    # in both copy and move mode - unlike ordinary per-track sources, which 'copy'
                    # mode otherwise leaves untouched.
                    if ($PSCmdlet.ShouldProcess($release.cueSheet.cueFilePath, 'Delete cue-sheet source files')) {
                        Remove-Item -LiteralPath (ConvertTo-TaggerLongPath -Path $release.cueSheet.cueFilePath) -Force -ErrorAction SilentlyContinue
                        Remove-Item -LiteralPath (ConvertTo-TaggerLongPath -Path $release.cueSheet.audioFilePath) -Force -ErrorAction SilentlyContinue
                    }
                }
                elseif ($CopyMode -eq 'move') {
                    if ($PSCmdlet.ShouldProcess($release.stableKey, 'Delete moved source track and companion files')) {
                        foreach ($sourcePath in @($release.tracks.sourceFilePath | Select-Object -Unique)) {
                            Remove-Item -LiteralPath (ConvertTo-TaggerLongPath -Path $sourcePath) -Force -ErrorAction SilentlyContinue
                        }
                        # Companions (covers, booklets, photos) are staged/copied alongside the
                        # tracks - without also deleting these, a "move" leaves them behind even
                        # though every track was removed, which isn't actually a move.
                        foreach ($companionPath in @($release.companionFiles.sourcePath | Select-Object -Unique)) {
                            Remove-Item -LiteralPath (ConvertTo-TaggerLongPath -Path $companionPath) -Force -ErrorAction SilentlyContinue
                        }
                    }
                }

                if ($release.lossyLossless.action -eq 'replace-existing') {
                    if ($PSCmdlet.ShouldProcess($release.stableKey, 'Mark lossy-tracking entry upgraded')) {
                        Set-TaggerLossyTrackingUpgraded -StableKey $release.stableKey -DataHome $DataHome | Out-Null
                    }
                }

                if ($PSCmdlet.ShouldProcess($release.stableKey, 'Record apply-log entry')) {
                    Add-TaggerApplyLogEntry -StableKey $release.stableKey -AppliedAtUtc (Get-Date) -Status 'applied' `
                        -TargetPath $stagingResult.TargetPath -SourceFileSetHash $sourceHash -ErrorMessage $null `
                        -Truncated $stagingResult.Truncated -DataHome $DataHome | Out-Null
                }

                $appliedCount++
            }
            else {
                if ($PSCmdlet.ShouldProcess($release.stableKey, 'Record apply-log entry')) {
                    Add-TaggerApplyLogEntry -StableKey $release.stableKey -AppliedAtUtc (Get-Date) -Status 'failed' `
                        -TargetPath $stagingResult.TargetPath -SourceFileSetHash $sourceHash -ErrorMessage $stagingResult.ErrorMessage `
                        -Truncated $stagingResult.Truncated -DataHome $DataHome | Out-Null
                }
                $failedCount++
            }
        }
        catch {
            # Belt-and-braces: Invoke-TaggerReleaseStaging already catches its own internal
            # failures, but this covers anything thrown outside it (the commit move itself, or
            # Set-TaggerLossyTrackingUpgraded) - one release's failure must never stop the batch.
            # $sourceHash was already resolved (real hash or the sentinel) before this try block.
            # Prefer $stagingResult's (possibly-truncated) TargetPath/Truncated - it reflects what
            # was actually staged/committed. $finalTargetPath (raw, untruncated names) is only a
            # fallback for the case staging never got the chance to run at all.
            $failureTargetPath = if ($stagingResult) { $stagingResult.TargetPath } else { $finalTargetPath }
            $failureTruncated = if ($stagingResult) { $stagingResult.Truncated } else { $false }
            if ($PSCmdlet.ShouldProcess($release.stableKey, 'Record apply-log entry')) {
                Add-TaggerApplyLogEntry -StableKey $release.stableKey -AppliedAtUtc (Get-Date) -Status 'failed' `
                    -TargetPath $failureTargetPath -SourceFileSetHash $sourceHash -ErrorMessage $_.Exception.Message `
                    -Truncated $failureTruncated -DataHome $DataHome | Out-Null
            }
            $failedCount++
        }
    }

    # Every successfully-applied release already moved itself out of staging (step 8, plan/08); a
    # failed release's staging folder is deliberately left behind for inspection (plan/08 "Edge
    # cases"). So this only ever removes the empty .tagger-staging wrapper itself, never a release
    # that is still sitting there because it failed.
    if ((Test-Path -LiteralPath $stagingRoot) -and -not (Get-ChildItem -LiteralPath $stagingRoot -Force -ErrorAction SilentlyContinue)) {
        if ($PSCmdlet.ShouldProcess($stagingRoot, 'Remove empty staging folder')) {
            Remove-Item -LiteralPath $stagingRoot -Force -ErrorAction SilentlyContinue
        }
    }

    $finalStage = if ($failedCount -eq 0) { 'applied' } else { 'partially-applied' }
    if ($PSCmdlet.ShouldProcess($SessionId, 'Update session stage')) {
        Set-TaggerSessionStage -SessionId $SessionId -Stage $finalStage -DataHome $DataHome | Out-Null
    }

    return [pscustomobject]@{ Applied = $appliedCount; Skipped = $skippedCount; Failed = $failedCount }
}

Export-ModuleMember -Function Get-TaggerApplyLogPath, Get-TaggerApplyLog, Get-TaggerApplyLogEntry, Add-TaggerApplyLogEntry, `
    Test-TaggerReleaseNeedsApply, ConvertFrom-TaggerCueTrackRanges, Invoke-TaggerFfmpegSplit, Invoke-TaggerFfmpegResize, `
    Invoke-TaggerCoverDownload, Set-TaggerAudioTags, Resolve-TaggerCompanionTargetPath, Resolve-TaggerTruncatedReleaseNames, `
    Invoke-TaggerReleaseStaging, Move-TaggerStagedReleaseToTarget, Invoke-TaggerImplementation
