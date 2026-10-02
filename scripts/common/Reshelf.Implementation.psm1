#Requires -Version 7.4

Import-Module (Join-Path $PSScriptRoot 'Reshelf.Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Reshelf.Json.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Reshelf.LossyTracking.psm1') -Force

# Invoke-ReshelfImplementation's last step calls Set-ReshelfSessionStage (Reshelf.Settings.psm1), but
# that module is deliberately NOT imported here: re-importing a module that a caller (Reshelf.ps1,
# Invoke-Implementation.ps1) already imported directly hides that caller's own top-level copy of
# its functions (PowerShell nested-module shadowing - verified empirically, not theoretical).
# Every caller of this module must import Reshelf.Settings.psm1 itself before calling
# Invoke-ReshelfImplementation, same as Reshelf.ps1's 'propose' case already relies on having
# imported Reshelf.Settings.psm1 itself rather than via Reshelf.EditProposal.psm1.

# --- apply-log.json ----------------------------------------------------------------

function Get-ReshelfApplyLogPath {
    [CmdletBinding()]
    param(
        [string]$DataHome
    )

    if (-not $DataHome) { $DataHome = Resolve-ReshelfDataHome }
    return Join-Path $DataHome 'apply-log.json'
}

function Get-ReshelfApplyLog {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [string]$DataHome
    )

    $logPath = Get-ReshelfApplyLogPath -DataHome $DataHome

    if (-not (Test-Path -LiteralPath $logPath -PathType Leaf)) {
        return @()
    }

    if (-not (Test-ReshelfJson -SchemaName apply-log -Path $logPath)) {
        throw "Apply log at '$logPath' does not match the apply-log schema."
    }

    return @(Get-Content -LiteralPath $logPath -Raw | ConvertFrom-Json)
}

function Get-ReshelfApplyLogEntry {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [string]$StableKey,

        [string]$DataHome
    )

    return Get-ReshelfApplyLog -DataHome $DataHome | Where-Object { $_.stableKey -eq $StableKey } | Select-Object -First 1
}

function Add-ReshelfApplyLogEntry {
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

    if (-not $DataHome) { $DataHome = Resolve-ReshelfDataHome }

    # Upsert, not touch-only (unlike Add-ReshelfLossyTrackingEntry) - a retry after a failure must
    # replace the old row wholesale (e.g. failed -> applied), not just bump a timestamp on it.
    $log = @(Get-ReshelfApplyLog -DataHome $DataHome | Where-Object { $_.stableKey -ne $StableKey })

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

    $logPath = Get-ReshelfApplyLogPath -DataHome $DataHome
    Set-ReshelfJsonFile -Path $logPath -InputObject $log -SchemaName apply-log -Depth 10 | Out-Null

    return $log
}

function Test-ReshelfAppliedEntryValid {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowNull()]
        [object]$Entry,

        [Parameter(Mandatory)]
        [string]$TargetRoot
    )

    # An 'applied' log entry only means "already done" if it still points at somewhere under
    # *this* run's TargetRoot and that folder is actually still there - otherwise (TargetRoot was
    # changed since, e.g. moved to a new drive/folder, or the folder was deleted/renamed outside
    # Reshelf) the log is stale and the release still needs a real apply, even though its recorded
    # status/hash look fine. OrdinalIgnoreCase because Windows paths are case-insensitive.
    # Shared between Test-ReshelfReleaseNeedsApply (this module, plan/08) and
    # Resolve-ReshelfTargetComparison (Reshelf.EditProposal.psm1, plan/06/10) - both need the exact
    # same "is this apply-log entry still trustworthy" answer, just for different callers.
    if (-not $Entry) { return $false }
    if ($Entry.status -ne 'applied') { return $false }

    $normalizedRoot = $TargetRoot.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if (-not $Entry.targetPath.StartsWith($normalizedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $false
    }

    return [bool](Test-Path -LiteralPath (ConvertTo-ReshelfLongPath -Path $Entry.targetPath))
}

function Test-ReshelfReleaseNeedsApply {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [object]$Release,

        [Parameter(Mandatory)]
        [string]$TargetRoot,

        [string]$DataHome
    )

    $entry = Get-ReshelfApplyLogEntry -StableKey $Release.stableKey -DataHome $DataHome
    $appliedEntryStillValid = Test-ReshelfAppliedEntryValid -Entry $entry -TargetRoot $TargetRoot

    try {
        $sourcePaths = @($Release.tracks.sourceFilePath | Select-Object -Unique)
        $currentHash = Get-ReshelfFileSetHash -FilePaths $sourcePaths
    }
    catch {
        # Reshelf never deletes or modifies source files (they are always read-only to it) - but a
        # source file can still legitimately go missing by the time of a later re-run for reasons
        # outside Reshelf's control (the user moved/deleted it, an external drive went offline,
        # ...). Its absence, paired with a still-valid 'applied' entry, is exactly what an
        # already-completed release looks like on rerun - not a reason to recompute a hash that
        # has nothing left to hash.
        # No Hash is returned here (there's nothing left to hash) - the caller falls back to its
        # own sentinel for the rare case this release still needs to be (re-)applied anyway.
        $needsApply = -not $appliedEntryStillValid
        return [pscustomobject]@{ NeedsApply = $needsApply; Hash = $null }
    }

    $needsApply = (-not $appliedEntryStillValid) -or ($entry.sourceFileSetHash -ne $currentHash)
    return [pscustomobject]@{ NeedsApply = $needsApply; Hash = $currentHash }
}

# --- Cue splitting -------------------------------------------------------------------

function ConvertTo-ReshelfFfmpegSeconds {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$CueTimestamp
    )

    # Feeding the raw MM:SS:FF cue timestamp straight to ffmpeg's -ss/-to (as this code used to)
    # makes ffmpeg read it as HH:MM:SS instead - minutes become hours, seconds become minutes,
    # frames become seconds. That's silently wrong whenever frames < 60 (ffmpeg just accepts the
    # bogus value), and loudly wrong (an invalid duration) whenever frames >= 60. Converting to
    # plain seconds here sidesteps the field-meaning mismatch entirely.
    $totalSeconds = ConvertTo-ReshelfCueTimestampSeconds -CueTimestamp $CueTimestamp

    # ffmpeg requires a dot decimal separator regardless of the machine's regional settings -
    # InvariantCulture avoids a comma showing up here on e.g. a Ukrainian-locale Windows box.
    return $totalSeconds.ToString('F3', [System.Globalization.CultureInfo]::InvariantCulture)
}

function ConvertFrom-ReshelfCueTrackRanges {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Tracks
    )

    # Grouped by sourceFilePath, not globally sorted by proposedTrackNumber - a per-disc-cue release
    # has one source audio file per disc, and proposedTrackNumber restarts at 1 on every disc (and
    # can be freely edited/reordered in the UI independently of the cue's own track order), so it
    # can't be trusted to lay out a single source file's split ranges. Within a group, only the
    # track's own cueTimestamp says where it starts.
    $groups = @($Tracks | Group-Object -Property sourceFilePath)

    $result = foreach ($group in $groups) {
        $sorted = @($group.Group | Sort-Object -Property { ConvertTo-ReshelfCueTimestampSeconds -CueTimestamp $_.cueTimestamp })
        for ($i = 0; $i -lt $sorted.Count; $i++) {
            $endTimestamp = if ($i -lt ($sorted.Count - 1)) { ConvertTo-ReshelfFfmpegSeconds $sorted[$i + 1].cueTimestamp } else { $null }
            [pscustomobject]@{
                Track          = $sorted[$i]
                StartTimestamp = ConvertTo-ReshelfFfmpegSeconds $sorted[$i].cueTimestamp
                EndTimestamp   = $endTimestamp
            }
        }
    }

    return @($result)
}

function Invoke-ReshelfFfmpegSplit {
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

    # ffmpeg ships an ape *decoder* but no ape encoder/muxer (Monkey's Audio's own licensing terms
    # historically blocked third-party encoders) - stream-copying (-c copy) into a .ape output
    # always fails. An .ape source must be re-encoded instead; Reshelf.Recognition.psm1 already
    # points these tracks' proposedFileName at .flac for the same reason, so the codec below must
    # match that container.
    #
    # A .flac source must ALSO re-encode, for a different reason: a -c copy remux only copies the
    # packets that fall inside -ss/-to, but it does not recompute the FLAC STREAMINFO block's
    # total_samples field, which still reflects the original, untrimmed file. Every split track
    # then reports the whole album's duration instead of its own - correct audio content, wrong
    # duration metadata. Re-encoding forces ffmpeg to recompute total_samples from the samples it
    # actually writes. Every other source format (e.g. .wav, .mp3) keeps the lossless,
    # zero-recompression copy - their own container headers are rewritten correctly on remux.
    $sourceExtension = [System.IO.Path]::GetExtension($SourceAudioPath).ToLowerInvariant()
    if ($sourceExtension -in @('.ape', '.flac')) {
        $ffmpegArgs.AddRange([string[]]@('-c:a', 'flac'))
    }
    else {
        $ffmpegArgs.AddRange([string[]]@('-c', 'copy'))
    }
    $ffmpegArgs.Add("`"$OutputPath`"")

    $process = Start-Process -FilePath $FfmpegPath -ArgumentList $ffmpegArgs -NoNewWindow -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "ffmpeg split failed (exit code $($process.ExitCode)) for '$SourceAudioPath' -> '$OutputPath'."
    }
}

function Invoke-ReshelfFfmpegResize {
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
    # See Invoke-ReshelfFfmpegSplit - path-bearing arguments need literal double quotes because
    # Start-Process -ArgumentList does not quote array elements containing spaces.
    $ffmpegArgs = @('-hide_banner', '-loglevel', 'error', '-y', '-i', "`"$SourceImagePath`"", '-vf', $scaleFilter, "`"$OutputPath`"")

    $process = Start-Process -FilePath $FfmpegPath -ArgumentList $ffmpegArgs -NoNewWindow -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "ffmpeg resize failed (exit code $($process.ExitCode)) for '$SourceImagePath' -> '$OutputPath'."
    }
}

function Invoke-ReshelfCoverDownload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Url,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    # A Discogs-matched release's chosenCandidateUrl is a remote https:// image URL - only the
    # no-match fallback in Reshelf.EditProposal.psm1 ever picks a local companion-file path.
    # Without this, cover art would only ever get embedded in that fallback case.
    Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing
}

# --- Tagging -------------------------------------------------------------------------
# Tags and cover art are written via TagLibSharp (in-process, Add-Type - no external process, no
# GUI, no manual Action-Group authoring), the same library Reshelf.Recognition.psm1 uses to read
# tags. Kept as its own function (no inline TagLib calls elsewhere) so tests can
# `Mock -ModuleName Reshelf.Implementation Set-ReshelfAudioTags` the same way the ffmpeg/cover-
# download wrappers are mocked.

function Set-ReshelfAudioTags {
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

    Import-ReshelfTagLibSharp -TagLibSharpPath $TagLibSharpPath -DataHome $DataHome

    $longPath = ConvertTo-ReshelfLongPath -Path $Path

    # Same fallback as Get-ReshelfAudioTags (Reshelf.Recognition.psm1): a leading ID3v2 tag on a
    # .mpc file (nonstandard for Musepack, but real taggers write it) makes TagLib#'s MusePack
    # properties reader throw CorruptFileException before it ever gets to the tag itself. Tag
    # writing doesn't need audio properties, so ReadStyle.None (skip property parsing) is enough
    # to open the file and still write/save the tag correctly.
    try {
        $file = [TagLib.File]::Create($longPath)
    }
    catch [TagLib.CorruptFileException] {
        $file = [TagLib.File]::Create($longPath, [TagLib.ReadStyle]::None)
    }
    try {
        $file.Tag.Performers = @($Tags.artist)
        $file.Tag.AlbumArtists = @($Tags.albumArtist)
        $file.Tag.Album = $Tags.album
        $file.Tag.Year = [uint32]$Tags.year
        $file.Tag.Disc = [uint32]$Tags.discNumber
        $file.Tag.Track = [uint32]$Tags.track
        $file.Tag.Title = $Tags.title

        # IsCompilation (TCMP/cpil/COMPILATION) lives only on the format-specific tag classes, not
        # on the base TagLib.Tag - each one is fetched (without creating it) and set when present, so
        # both true and false are written and an old flag gets cleared too. Formats with no such tag
        # (e.g. plain wav) are silently skipped.
        $isCompilation = [bool]$Tags.isCompilation
        foreach ($tagType in @([TagLib.TagTypes]::Id3v2, [TagLib.TagTypes]::Apple, [TagLib.TagTypes]::Xiph)) {
            $formatTag = $file.GetTag($tagType, $false)
            if ($formatTag) { $formatTag.IsCompilation = $isCompilation }
        }

        if ($CoverImagePath -and (Test-Path -LiteralPath (ConvertTo-ReshelfLongPath -Path $CoverImagePath) -PathType Leaf)) {
            # The Picture(string) constructor reads the file's bytes and auto-detects MimeType from
            # its extension (verified against the real TagLibSharp.dll: a .jpg round-trips as
            # image/jpeg) - simpler and less error-prone than building a ByteVector by hand.
            $picture = [TagLib.Picture]::new((ConvertTo-ReshelfLongPath -Path $CoverImagePath))
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
# The relative-path helper itself lives in Reshelf.Common.psm1 (shared with
# Reshelf.Recognition.psm1) - already imported above.

function Resolve-ReshelfCompanionTargetPath {
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

    if ($CompanionFile.placement -eq 'nested') {
        $fileNameSan = (ConvertTo-SafeFileName -Name (Split-Path -Leaf $CompanionFile.sourcePath)).SafeName
        $relative = Get-ReshelfRelativePath -SourceRoot $ReleaseSourceFolderPath -Path $CompanionFile.sourcePath
        $relativeDir = Split-Path -Parent $relative
        if ($relativeDir) {
            return Join-Path $ReleaseFolderPath $relativeDir $fileNameSan
        }
        return Join-Path $ReleaseFolderPath $fileNameSan
    }

    # Loose: manifesto SS4.5 - a loose companion must start with a letter, so alphabetical sorting
    # in a file explorer always puts numbered tracks first. The Edit Proposal step
    # (New-ReshelfCompanionProposal) already computed the letter-first proposedFileName - a '_'
    # prefix (the old behavior here) sorts *before* digits in Explorer, which is the opposite of
    # what SS4.5 wants, so it's never used. A $null/missing proposedFileName only happens for a
    # proposal.json written before this field existed - fall back to computing it fresh here.
    $fileNameSan = if ($CompanionFile.proposedFileName) {
        (ConvertTo-SafeFileName -Name $CompanionFile.proposedFileName).SafeName
    }
    else {
        (Get-ReshelfLooseCompanionFileName -FileName (Split-Path -Leaf $CompanionFile.sourcePath) -Kind $CompanionFile.kind).FileName
    }
    return Join-Path $ReleaseFolderPath $fileNameSan
}

# --- Path-length truncation -----------------------------------------------------------
# ConvertTo-ReshelfLongPath (Reshelf.Common.psm1) already lifts the hard ~260-char Windows path
# limit via the \\?\ prefix, but plan/10 also wants human-facing names kept short by construction:
# some external tools and everyday Explorer/zip/cloud-sync use don't handle \\?\ consistently, so a
# fully-assembled target path is still truncated above ~250 chars, with the cut always recorded
# rather than silent. NOTE: the guarantee this produces (final path <= MaxPathLength) assumes
# TargetRoot itself, which can never be truncated, still leaves room for at least the structural
# prefixes/extension - an already-very-deep TargetRoot is a real, if narrow, ceiling on what this
# can promise, same as it would be for any path-shortening scheme.

function Split-ReshelfTrackFileName {
    # Splits a proposed track file name into its never-truncated leading track-number prefix (if
    # any), the truncatable title body, and the extension. Mirrors both forms
    # ConvertFrom-ReshelfTrackFileName (Reshelf.Common.psm1) already accepts - dash-separated
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

function Get-ReshelfRemainingPathBudget {
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

function Resolve-ReshelfTruncatedReleaseNames {
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
    # checked to 1900-2100 like Reshelf.Recognition.psm1's equivalent pattern, so a catalog-number-
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
            Split    = Split-ReshelfTrackFileName -FileName $_.proposedFileName
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
    $artistBudget = Get-ReshelfRemainingPathBudget -MaxLength $MaxPathLength -Consumed ($root.Length + 1) `
        -Reserved (1 + $releaseFloor + 1 + $maxTrackFloor)
    $artistResult = ConvertTo-ReshelfTruncatedSegment -Prefix '' -Body $Release.proposed.artistFolderName -Suffix '' -MaxLength $artistBudget
    if ($artistResult.Truncated) { $truncatedAny = $true }
    $artistFolderName = $artistResult.Value

    # Release folder budget likewise reserves room for '\' + the largest track floor after it.
    $releaseBudget = Get-ReshelfRemainingPathBudget -MaxLength $MaxPathLength -Consumed ($root.Length + 1 + $artistFolderName.Length + 1) `
        -Reserved (1 + $maxTrackFloor)
    $releaseResult = ConvertTo-ReshelfTruncatedSegment -Prefix $releasePrefix -Body $releaseBody -Suffix '' `
        -MaxLength ([Math]::Max($releaseBudget, $releaseFloor))
    if ($releaseResult.Truncated) { $truncatedAny = $true }
    $releaseFolderName = $releaseResult.Value

    # Track file names: preserve the leading numeric track-order prefix and the file extension.
    # Because the folder levels above reserved room for $maxTrackFloor (which already includes the
    # disambiguation reserve), every track's own floor - and one collision retry - is guaranteed to
    # fit in the budget computed here.
    $releasePathLength = $root.Length + 1 + $artistFolderName.Length + 1 + $releaseFolderName.Length + 1
    $trackBudget = Get-ReshelfRemainingPathBudget -MaxLength $MaxPathLength -Consumed $releasePathLength -Reserved 0

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
            $candidate = ConvertTo-ReshelfTruncatedSegment -Prefix $prefix -Body $body -Suffix $suffix -MaxLength $trackBudget
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

function Invoke-ReshelfReleaseStaging {
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

    $truncatedLayout = Resolve-ReshelfTruncatedReleaseNames -Release $Release -TargetRoot $TargetRoot
    $finalTargetPath = Join-Path $TargetRoot $truncatedLayout.ArtistFolderName $truncatedLayout.ReleaseFolderName
    $stagingReleasePath = Join-Path $StagingRoot $Release.stableKey
    $truncated = $truncatedLayout.Truncated

    try {
        # Validate companion targets before touching any file - a naming problem here (an
        # included loose companion that doesn't start with a letter, per manifesto SS4.5, or two
        # files that would land on the same target path) must fail this release cleanly rather
        # than leave a half-written staging folder or silently overwrite one file with another.
        $includedCompanions = @($Release.companionFiles | Where-Object { $_.include -ne $false })
        $trackFileNameSet = [System.Collections.Generic.HashSet[string]]::new(
            [string[]]@($truncatedLayout.TrackFileNames.Values), [System.StringComparer]::OrdinalIgnoreCase)
        $companionTargetPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

        foreach ($companion in $includedCompanions) {
            $companionTargetPath = Resolve-ReshelfCompanionTargetPath -CompanionFile $companion -ReleaseSourceFolderPath $Release.sourceFolderPath `
                -ReleaseFolderPath $stagingReleasePath

            if ($companion.placement -eq 'loose') {
                $targetFileName = Split-Path -Leaf $companionTargetPath
                if (-not (Test-ReshelfLooseCompanionFileName -FileName $targetFileName)) {
                    throw "Companion file '$($companion.sourcePath)' has an invalid target name '$targetFileName' - a loose companion must start with a letter (manifesto SS4.5). Rename it in the Editing UI."
                }
                if ($trackFileNameSet.Contains($targetFileName)) {
                    throw "Companion file '$($companion.sourcePath)' would be named '$targetFileName', the same as a track file name. Rename it in the Editing UI."
                }
            }

            if (-not $companionTargetPaths.Add($companionTargetPath)) {
                throw "Two companion files would both be copied to '$companionTargetPath'. Rename one of them in the Editing UI."
            }
        }

        if ($PSCmdlet.ShouldProcess($stagingReleasePath, 'Create staging folder')) {
            New-Item -ItemType Directory -Path (ConvertTo-ReshelfLongPath -Path $stagingReleasePath) -Force | Out-Null
        }

        $stagedTrackInfos = [System.Collections.Generic.List[object]]::new()

        # Branch per track, not per release: a per-disc-cue release can mix cue-image discs with
        # ordinary track-file discs (Reshelf.Recognition.psm1's 'album-wrapper'/per-disc-cue case),
        # so isCueVirtualTrack decides each track's own path rather than $Release.cueSheets as a
        # whole. Each cue track is split from its OWN sourceFilePath - a per-disc-cue release has one
        # source file per disc, not one shared file for the whole release.
        $cueTracks = @($Release.tracks | Where-Object { $_.isCueVirtualTrack })
        $normalTracks = @($Release.tracks | Where-Object { -not $_.isCueVirtualTrack })

        if ($cueTracks.Count -gt 0) {
            $cueStagedInfos = [System.Collections.Generic.List[object]]::new()
            $ranges = ConvertFrom-ReshelfCueTrackRanges -Tracks $cueTracks
            foreach ($range in $ranges) {
                $outputPath = Join-Path $stagingReleasePath $truncatedLayout.TrackFileNames[$range.Track.proposedFileName]
                if ($PSCmdlet.ShouldProcess($outputPath, 'ffmpeg split track from cue source')) {
                    Invoke-ReshelfFfmpegSplit -SourceAudioPath $range.Track.sourceFilePath -StartTimestamp $range.StartTimestamp `
                        -EndTimestamp $range.EndTimestamp -OutputPath $outputPath -FfmpegPath $FfmpegPath
                }
                $cueStagedInfos.Add([pscustomobject]@{ FilePath = $outputPath; Tags = $range.Track.tags; HasExistingCover = [bool]$range.Track.existingCoverArtPath })
            }

            # Defensive: the ffmpeg wrapper already throws on a non-zero exit code, so this only
            # catches the rarer case of it exiting 0 without actually producing every output file.
            if (-not $WhatIfPreference) {
                foreach ($info in $cueStagedInfos) {
                    if (-not (Test-Path -LiteralPath (ConvertTo-ReshelfLongPath -Path $info.FilePath) -PathType Leaf)) {
                        throw "Cue split for release '$($Release.stableKey)' did not produce expected file '$($info.FilePath)'."
                    }
                }
            }
            $stagedTrackInfos.AddRange([object[]]$cueStagedInfos)
        }

        foreach ($track in $normalTracks) {
            $outputPath = Join-Path $stagingReleasePath $truncatedLayout.TrackFileNames[$track.proposedFileName]
            if ($PSCmdlet.ShouldProcess($outputPath, 'Copy track')) {
                # -ErrorAction Stop: Copy-Item's default is a non-terminating error, which would
                # otherwise let execution continue as if the copy succeeded - the release would
                # then fail two steps later at tag-writing, with a message blaming the missing
                # staged file instead of the real cause (the source file is gone).
                Copy-Item -LiteralPath (ConvertTo-ReshelfLongPath -Path $track.sourceFilePath) -Destination (ConvertTo-ReshelfLongPath -Path $outputPath) -Force -ErrorAction Stop
            }
            $stagedTrackInfos.Add([pscustomobject]@{ FilePath = $outputPath; Tags = $track.tags; HasExistingCover = [bool]$track.existingCoverArtPath })
        }

        $coverOutputPath = $null
        if ($Release.coverArt.chosenCandidateUrl) {
            # A dot-prefixed tool-specific name, never a plain 'cover.jpg': a loose companion named
            # 'cover.jpg' (valid per manifesto SS4.5) is copied into this same staging folder below,
            # and a shared name let the working-file cleanup delete that real companion with it.
            $coverOutputPath = Join-Path $stagingReleasePath '.reshelf-cover-resized.jpg'
            $sourceForResize = $Release.coverArt.chosenCandidateUrl

            if ($sourceForResize -match '^https?://') {
                $downloadPath = Join-Path $stagingReleasePath 'cover-source.download'
                if ($PSCmdlet.ShouldProcess($downloadPath, 'Download cover art')) {
                    Invoke-ReshelfCoverDownload -Url $sourceForResize -OutputPath $downloadPath
                }
                $sourceForResize = $downloadPath
            }

            if ($PSCmdlet.ShouldProcess($coverOutputPath, 'Resize cover art')) {
                Invoke-ReshelfFfmpegResize -SourceImagePath $sourceForResize -MaxDimension $Release.coverArt.targetMaxDimension `
                    -OutputPath $coverOutputPath -FfmpegPath $FfmpegPath
            }
        }

        # 'existing (embedded)' means "keep whatever's already embedded" - a track that already had
        # its own cover (HasExistingCover) is left untouched instead of having $coverOutputPath
        # re-embedded into it; a track with no cover still gets $coverOutputPath so the release
        # doesn't end up with some tracks illustrated and others blank.
        $chosenCoverCandidate = $Release.coverArt.candidates | Where-Object { $_.url -eq $Release.coverArt.chosenCandidateUrl } | Select-Object -First 1
        $isKeepExistingCover = [bool]($chosenCoverCandidate -and $chosenCoverCandidate.sourceEdition -eq 'existing (embedded)')

        foreach ($info in $stagedTrackInfos) {
            $coverPathForTrack = if ($isKeepExistingCover -and $info.HasExistingCover) { $null } else { $coverOutputPath }
            if ($PSCmdlet.ShouldProcess($info.FilePath, 'Write tags via TagLibSharp')) {
                Set-ReshelfAudioTags -Path $info.FilePath -Tags $info.Tags -CoverImagePath $coverPathForTrack -TagLibSharpPath $TagLibSharpPath
            }
        }

        foreach ($companion in $includedCompanions) {
            $companionTargetPath = Resolve-ReshelfCompanionTargetPath -CompanionFile $companion -ReleaseSourceFolderPath $Release.sourceFolderPath `
                -ReleaseFolderPath $stagingReleasePath
            if ($PSCmdlet.ShouldProcess($companionTargetPath, 'Copy companion file')) {
                $companionParentDir = Split-Path -Path $companionTargetPath -Parent
                if ($companionParentDir -and -not (Test-Path -LiteralPath (ConvertTo-ReshelfLongPath -Path $companionParentDir))) {
                    New-Item -ItemType Directory -Path (ConvertTo-ReshelfLongPath -Path $companionParentDir) -Force | Out-Null
                }
                Copy-Item -LiteralPath (ConvertTo-ReshelfLongPath -Path $companion.sourcePath) -Destination (ConvertTo-ReshelfLongPath -Path $companionTargetPath) -Force -ErrorAction Stop
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

function Move-ReshelfStagedReleaseToTarget {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$StagingPath,

        [Parameter(Mandatory)]
        [string]$FinalPath,

        [Parameter(Mandatory)]
        [string]$TargetAction
    )

    if ($PSCmdlet.ShouldProcess($FinalPath, "Move staged release from '$StagingPath'")) {
        $parentDir = Split-Path -Path $FinalPath -Parent
        if ($parentDir -and -not (Test-Path -LiteralPath (ConvertTo-ReshelfLongPath -Path $parentDir))) {
            New-Item -ItemType Directory -Path (ConvertTo-ReshelfLongPath -Path $parentDir) -Force | Out-Null
        }

        # Only a release Step 6 knew had an existing folder may replace one: update-existing, or a
        # conflict a human approved (plan/10: never *silently* overwritten). Checked here, right
        # before the delete, instead of trusting Step 6: a wrong targetAction there (real case,
        # plan/12 milestone 7: 'create-new' for a folder that existed) must fail the release, not
        # destroy whatever is already in the target.
        if (Test-Path -LiteralPath (ConvertTo-ReshelfLongPath -Path $FinalPath)) {
            if ($TargetAction -notin @('update-existing', 'conflict')) {
                throw "target folder '$FinalPath' already exists but the proposal says '$TargetAction'; re-run propose"
            }
            Remove-Item -LiteralPath (ConvertTo-ReshelfLongPath -Path $FinalPath) -Recurse -Force
        }

        Move-Item -LiteralPath (ConvertTo-ReshelfLongPath -Path $StagingPath) -Destination (ConvertTo-ReshelfLongPath -Path $FinalPath) -Force
    }

    return $FinalPath
}

# --- Orchestration ---------------------------------------------------------------------

function Invoke-ReshelfImplementation {
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
        [ValidateSet('copy')]
        [string]$CopyMode,

        [string]$FfmpegPath,

        [string]$TagLibSharpPath,

        [string]$DataHome,

        [switch]$IncludeUnresolved
    )

    if (-not $DataHome) { $DataHome = Resolve-ReshelfDataHome }

    # Mirrors Import-ReshelfTagLibSharp's own fallback just above this module in the import chain:
    # an empty settings.ffmpegPath (the documented default, plan/01) means "resolve via PATH", not
    # "no ffmpeg" - 'ffmpeg' here lets Start-Process find it on PATH, same as any other CLI call to it.
    if (-not $FfmpegPath) { $FfmpegPath = 'ffmpeg' }

    if (-not (Test-ReshelfJson -SchemaName proposal -Path $ProposalPath)) {
        throw "Proposal document at '$ProposalPath' does not match the proposal schema."
    }
    $proposal = Get-Content -LiteralPath $ProposalPath -Raw | ConvertFrom-Json

    $stagingRoot = Join-Path $TargetRoot '.reshelf-staging'
    $releases = @($proposal.artists.releases)

    $appliedCount = 0
    $skippedCount = 0
    $failedCount = 0
    $rejectedCount = 0

    foreach ($release in $releases) {
        # A rejected release is a human's deliberate, permanent "never apply this" decision (e.g.
        # one of two different physical pressings of the same album that only turned out to
        # collide this late) - unlike a merely unresolved release, -IncludeUnresolved must never
        # override it: that flag means "apply what hasn't been looked at yet", not "override an
        # explicit no". Checked, and counted, separately from the ordinary skip path below.
        if ($release.humanReview.rejected) {
            $rejectedCount++
            continue
        }

        # humanReview.required/.resolved is the one general "does a human need to look at this
        # before apply touches it" gate (set by Reshelf.EditProposal.psm1's New-ReshelfProposedRelease
        # for every reason it flags a release, not just an ambiguous Discogs match) - gating on it
        # directly, for whatever reason it was set, is correct; special-casing just the ambiguous
        # case let a targetAction: "conflict" release (pre-existing, different target content)
        # proceed straight through to Move-ReshelfStagedReleaseToTarget's unconditional overwrite.
        if (-not $release.humanReview.resolved -and -not $IncludeUnresolved) {
            $skippedCount++
            continue
        }

        $needsApplyResult = Test-ReshelfReleaseNeedsApply -Release $release -TargetRoot $TargetRoot -DataHome $DataHome
        if (-not $needsApplyResult.NeedsApply) {
            $skippedCount++
            continue
        }

        $stagingReleasePath = Join-Path $stagingRoot $release.stableKey
        $finalTargetPath = Join-Path $TargetRoot $release.proposed.artistFolderName $release.proposed.releaseFolderName
        # Test-ReshelfReleaseNeedsApply already computed this hash once for the skip decision - reuse
        # it instead of hashing every source file again. It can be $null when the source files went
        # missing for reasons outside Reshelf's control (Reshelf itself never deletes them) but the
        # release still needs (re-)applying anyway (e.g. a previously-failed attempt) - fall back to
        # the same "can't compute one" sentinel used elsewhere in this function for that case.
        $sourceHash = if ($needsApplyResult.Hash) { $needsApplyResult.Hash } else { 'unavailable-source-missing' }

        # Reset before every iteration - the outer catch below falls back to this when a failure
        # happens before staging assigns it, and a stale value from a *previous* release would
        # otherwise leak through if that ever happened.
        $stagingResult = $null

        try {
            $stagingResult = Invoke-ReshelfReleaseStaging -Release $release -StagingRoot $stagingRoot -TargetRoot $TargetRoot `
                -FfmpegPath $FfmpegPath -TagLibSharpPath $TagLibSharpPath

            if ($stagingResult.Success) {
                if ($PSCmdlet.ShouldProcess($stagingResult.TargetPath, 'Commit staged release to target')) {
                    Move-ReshelfStagedReleaseToTarget -StagingPath $stagingReleasePath -FinalPath $stagingResult.TargetPath `
                        -TargetAction $release.targetAction | Out-Null
                }

                # Source files are always read-only to Reshelf: nothing here ever deletes or modifies
                # a source path, cue-sheet or otherwise, no matter what CopyMode says. A prior
                # design deleted the cue-sheet source after a successful split, and deleted moved
                # per-track/companion sources in a "move" copy mode - both were removed after an
                # incident destroyed source releases that had no other backup. CopyMode now only
                # ever accepts 'copy' (enforced in Reshelf.Settings.psm1); the parameter and its
                # ValidateSet stay for backward-compatible callers, but nothing branches on it here.

                if ($release.lossyLossless.action -eq 'replace-existing') {
                    if ($PSCmdlet.ShouldProcess($release.stableKey, 'Mark lossy-tracking entry upgraded')) {
                        Set-ReshelfLossyTrackingUpgraded -StableKey $release.stableKey -DataHome $DataHome | Out-Null
                    }
                }
                elseif ($release.lossyLossless.action -eq 'log-for-upgrade') {
                    # Step 6 logged the *proposed* path; the committed one can differ (a folder name
                    # edited in the UI, or path truncation), so the ledger is corrected to the real one.
                    if ($PSCmdlet.ShouldProcess($release.stableKey, 'Update lossy-tracking entry target path')) {
                        Set-ReshelfLossyTrackingTargetPath -StableKey $release.stableKey -TargetPath $stagingResult.TargetPath `
                            -DataHome $DataHome | Out-Null
                    }
                }

                if ($PSCmdlet.ShouldProcess($release.stableKey, 'Record apply-log entry')) {
                    Add-ReshelfApplyLogEntry -StableKey $release.stableKey -AppliedAtUtc (Get-Date) -Status 'applied' `
                        -TargetPath $stagingResult.TargetPath -SourceFileSetHash $sourceHash -ErrorMessage $null `
                        -Truncated $stagingResult.Truncated -DataHome $DataHome | Out-Null
                }

                $appliedCount++
            }
            else {
                if ($PSCmdlet.ShouldProcess($release.stableKey, 'Record apply-log entry')) {
                    Add-ReshelfApplyLogEntry -StableKey $release.stableKey -AppliedAtUtc (Get-Date) -Status 'failed' `
                        -TargetPath $stagingResult.TargetPath -SourceFileSetHash $sourceHash -ErrorMessage $stagingResult.ErrorMessage `
                        -Truncated $stagingResult.Truncated -DataHome $DataHome | Out-Null
                }
                $failedCount++
            }
        }
        catch {
            # Belt-and-braces: Invoke-ReshelfReleaseStaging already catches its own internal
            # failures, but this covers anything thrown outside it (the commit move itself, or
            # Set-ReshelfLossyTrackingUpgraded) - one release's failure must never stop the batch.
            # $sourceHash was already resolved (real hash or the sentinel) before this try block.
            # Prefer $stagingResult's (possibly-truncated) TargetPath/Truncated - it reflects what
            # was actually staged/committed. $finalTargetPath (raw, untruncated names) is only a
            # fallback for the case staging never got the chance to run at all.
            $failureTargetPath = if ($stagingResult) { $stagingResult.TargetPath } else { $finalTargetPath }
            $failureTruncated = if ($stagingResult) { $stagingResult.Truncated } else { $false }
            if ($PSCmdlet.ShouldProcess($release.stableKey, 'Record apply-log entry')) {
                Add-ReshelfApplyLogEntry -StableKey $release.stableKey -AppliedAtUtc (Get-Date) -Status 'failed' `
                    -TargetPath $failureTargetPath -SourceFileSetHash $sourceHash -ErrorMessage $_.Exception.Message `
                    -Truncated $failureTruncated -DataHome $DataHome | Out-Null
            }
            $failedCount++
        }
    }

    # Every successfully-applied release already moved itself out of staging (step 8, plan/08); a
    # failed release's staging folder is deliberately left behind for inspection (plan/08 "Edge
    # cases"). So this only ever removes the empty .reshelf-staging wrapper itself, never a release
    # that is still sitting there because it failed.
    if ((Test-Path -LiteralPath $stagingRoot) -and -not (Get-ChildItem -LiteralPath $stagingRoot -Force -ErrorAction SilentlyContinue)) {
        if ($PSCmdlet.ShouldProcess($stagingRoot, 'Remove empty staging folder')) {
            Remove-Item -LiteralPath $stagingRoot -Force -ErrorAction SilentlyContinue
        }
    }

    $finalStage = if ($failedCount -eq 0) { 'applied' } else { 'partially-applied' }
    if ($PSCmdlet.ShouldProcess($SessionId, 'Update session stage')) {
        Set-ReshelfSessionStage -SessionId $SessionId -Stage $finalStage -DataHome $DataHome | Out-Null
    }

    return [pscustomobject]@{ Applied = $appliedCount; Skipped = $skippedCount; Failed = $failedCount; Rejected = $rejectedCount }
}

Export-ModuleMember -Function Get-ReshelfApplyLogPath, Get-ReshelfApplyLog, Get-ReshelfApplyLogEntry, Add-ReshelfApplyLogEntry, `
    Test-ReshelfAppliedEntryValid, Test-ReshelfReleaseNeedsApply, ConvertTo-ReshelfFfmpegSeconds, ConvertFrom-ReshelfCueTrackRanges, Invoke-ReshelfFfmpegSplit, `
    Invoke-ReshelfFfmpegResize, Invoke-ReshelfCoverDownload, Set-ReshelfAudioTags, Resolve-ReshelfCompanionTargetPath, `
    Resolve-ReshelfTruncatedReleaseNames, Invoke-ReshelfReleaseStaging, Move-ReshelfStagedReleaseToTarget, Invoke-ReshelfImplementation
