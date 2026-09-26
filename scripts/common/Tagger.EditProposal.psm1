#Requires -Version 7.4

Import-Module (Join-Path $PSScriptRoot 'Tagger.Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Tagger.Json.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Tagger.Discogs.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Tagger.LossyTracking.psm1') -Force
# Only for Get-TaggerApplyLogEntry/Test-TaggerAppliedEntryValid (Resolve-TaggerTargetComparison's
# re-run skip check below) - Tagger.Implementation.psm1 never imports this module back, so there's
# no cycle. Every caller that imports both (Tagger.ps1, Tagger.Pipeline.Tests.ps1) already imports
# Tagger.Implementation.psm1 directly *after* this module, which - same fix already relied on for
# Tagger.LossyTracking.psm1 above - restores its exports to that caller's own top-level scope
# instead of leaving them hidden as this module's nested copy.
Import-Module (Join-Path $PSScriptRoot 'Tagger.Implementation.psm1') -Force

# Starting point per plan/02 - not exposed in settings.schema.json (additionalProperties: false,
# no such field), so this stays a module constant rather than a configurable setting.
$script:DiscogsMatchThreshold = 0.85

# proposal.schema.json requires tags.year to be a non-nullable integer, so an unresolved year
# (no Discogs match, no recognized year) can't be represented as null - this sentinel (the
# schema's own minimum) is used instead and always paired with humanReview.required = true.
$script:UnresolvedYearSentinel = 1900

# --- String similarity -------------------------------------------------------

function Get-TaggerLevenshteinDistance {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$A,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$B
    )

    $lenA = $A.Length
    $lenB = $B.Length
    if ($lenA -eq 0) { return $lenB }
    if ($lenB -eq 0) { return $lenA }

    $distance = New-Object 'int[,]' ($lenA + 1), ($lenB + 1)
    for ($i = 0; $i -le $lenA; $i++) { $distance[$i, 0] = $i }
    for ($j = 0; $j -le $lenB; $j++) { $distance[0, $j] = $j }

    for ($i = 1; $i -le $lenA; $i++) {
        $iPrev = $i - 1
        for ($j = 1; $j -le $lenB; $j++) {
            $jPrev = $j - 1
            # PowerShell parses `$distance[$i - 1, $j]` as invoking op_Subtraction on the indexer's
            # result rather than as arithmetic inside the index - indices must be precomputed.
            $cost = if ($A[$iPrev] -eq $B[$jPrev]) { 0 } else { 1 }
            $deletion = $distance[$iPrev, $j] + 1
            $insertion = $distance[$i, $jPrev] + 1
            $substitution = $distance[$iPrev, $jPrev] + $cost
            $distance[$i, $j] = [Math]::Min([Math]::Min($deletion, $insertion), $substitution)
        }
    }

    return $distance[$lenA, $lenB]
}

function Get-TaggerStringSimilarity {
    [CmdletBinding()]
    [OutputType([double])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$A,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$B
    )

    if ($A.Length -eq 0 -and $B.Length -eq 0) { return 1.0 }
    if ($A.Length -eq 0 -or $B.Length -eq 0) { return 0.0 }

    $distance = Get-TaggerLevenshteinDistance -A $A -B $B
    $maxLen = [Math]::Max($A.Length, $B.Length)
    return 1.0 - ($distance / $maxLen)
}

# --- Discogs matching ----------------------------------------------------------

function Get-TaggerDiscogsSearchQuery {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$ArtistName,

        [Parameter(Mandatory)]
        [string]$Title,

        [Nullable[int]]$Year
    )

    $query = @{
        type          = 'release'
        artist        = $ArtistName
        release_title = $Title
    }
    if ($null -ne $Year) {
        $query['year'] = [string]$Year
    }
    return $query
}

function Get-TaggerDiscogsCandidateScore {
    [CmdletBinding()]
    [OutputType([double])]
    param(
        [Parameter(Mandatory)]
        [string]$ExpectedArtist,

        [Parameter(Mandatory)]
        [string]$ExpectedTitle,

        [Nullable[int]]$ExpectedYear,

        [Parameter(Mandatory)]
        [object]$Candidate
    )

    $rawTitle = [string]$Candidate.title
    $separatorIndex = $rawTitle.IndexOf(' - ')
    if ($separatorIndex -ge 0) {
        $candidateArtist = $rawTitle.Substring(0, $separatorIndex)
        $candidateTitle = $rawTitle.Substring($separatorIndex + 3)
    }
    else {
        $candidateArtist = ''
        $candidateTitle = $rawTitle
    }

    $normalizedExpectedArtist = ConvertTo-TaggerNormalizedText -Text $ExpectedArtist
    $normalizedExpectedTitle = ConvertTo-TaggerNormalizedText -Text $ExpectedTitle
    $normalizedCandidateArtist = ConvertTo-TaggerNormalizedText -Text $candidateArtist
    $normalizedCandidateTitle = ConvertTo-TaggerNormalizedText -Text $candidateTitle

    $artistScore = Get-TaggerStringSimilarity -A $normalizedExpectedArtist -B $normalizedCandidateArtist
    $titleScore = Get-TaggerStringSimilarity -A $normalizedExpectedTitle -B $normalizedCandidateTitle

    $candidateYear = $null
    if ($Candidate.year) {
        try { $candidateYear = [int]$Candidate.year } catch { $candidateYear = $null }
    }

    $yearAdjustment = 0.0
    if ($null -ne $ExpectedYear -and $null -ne $candidateYear) {
        if ($ExpectedYear -eq $candidateYear) { $yearAdjustment = 0.05 }
        elseif ([Math]::Abs($ExpectedYear - $candidateYear) -gt 1) { $yearAdjustment = -0.05 }
    }

    $score = ($artistScore * 0.5) + ($titleScore * 0.5) + $yearAdjustment
    if ($score -lt 0) { $score = 0.0 }
    if ($score -gt 1) { $score = 1.0 }
    return $score
}

function Resolve-TaggerDiscogsMatch {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$ArtistName,

        [Parameter(Mandatory)]
        [string]$Title,

        [Nullable[int]]$Year,

        [string]$DataHome,

        [int]$CacheTtlDays = 30,

        [int]$RateLimitPerMinute = 55
    )

    try {
        $query = Get-TaggerDiscogsSearchQuery -ArtistName $ArtistName -Title $Title -Year $Year
        $searchResult = Invoke-DiscogsRequest -Path '/database/search' -Query $query -CacheTtlDays $CacheTtlDays -RateLimitPerMinute $RateLimitPerMinute -DataHome $DataHome

        $releaseResults = @($searchResult.results | Where-Object { $_.type -eq 'release' })

        if ($releaseResults.Count -eq 0) {
            return [pscustomobject]@{ Status = 'not-found'; SelectedReleaseId = $null; Candidates = @(); Detail = $null; ErrorNote = $null }
        }

        $scored = @(foreach ($result in $releaseResults) {
                $score = Get-TaggerDiscogsCandidateScore -ExpectedArtist $ArtistName -ExpectedTitle $Title -ExpectedYear $Year -Candidate $result
                $candidateYear = $null
                if ($result.year) { try { $candidateYear = [int]$result.year } catch { $candidateYear = $null } }
                $formatText = (@($result.format) -join ', ')
                if (-not $formatText) { $formatText = 'Unknown' }
                $titleText = [string]$result.title
                if (-not $titleText) { $titleText = 'Unknown' }

                [pscustomobject]@{
                    releaseId = [int]$result.id
                    title     = $titleText
                    year      = $candidateYear
                    format    = $formatText
                    score     = [Math]::Round($score, 4)
                }
            })

        $sorted = @($scored | Sort-Object -Property score -Descending)
        $top = $sorted[0]
        $topCandidates = @($sorted | Select-Object -First 5)

        if ($top.score -ge $script:DiscogsMatchThreshold) {
            $detail = Invoke-DiscogsRequest -Path "/releases/$($top.releaseId)" -CacheTtlDays $CacheTtlDays -RateLimitPerMinute $RateLimitPerMinute -DataHome $DataHome
            return [pscustomobject]@{
                Status            = 'matched'
                SelectedReleaseId = $top.releaseId
                Candidates        = $topCandidates
                Detail            = $detail
                ErrorNote         = $null
            }
        }

        return [pscustomobject]@{
            Status            = 'ambiguous'
            SelectedReleaseId = $null
            Candidates        = $topCandidates
            Detail            = $null
            ErrorNote         = $null
        }
    }
    catch {
        return [pscustomobject]@{
            Status            = 'not-found'
            SelectedReleaseId = $null
            Candidates        = @()
            Detail            = $null
            ErrorNote         = "Discogs lookup failed: $($_.Exception.Message)"
        }
    }
}

# --- Naming templates ----------------------------------------------------------

function Expand-TaggerNamingTemplate {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Template,

        [Parameter(Mandatory)]
        [hashtable]$Values
    )

    $result = $Template
    foreach ($key in $Values.Keys) {
        $result = $result.Replace("{$key}", [string]$Values[$key])
    }
    return $result
}

function Get-TaggerProposalPadWidth {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [int]$TotalTrackCount,

        # settings.json's trackNumberPadWidth (plan/04): a configurable floor, not a fixed value -
        # 2 reproduces the original hardcoded behavior, but a release with more tracks than this
        # still gets a wider, correctly-sortable number regardless of the setting.
        [int]$MinWidth = 2
    )

    return [Math]::Max($MinWidth, $TotalTrackCount.ToString().Length)
}

function New-TaggerProposedReleaseNames {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$ArtistName,

        [Parameter(Mandatory)]
        [object]$Release,

        [Parameter(Mandatory)]
        [object]$Match,

        [Parameter(Mandatory)]
        [string]$ReleaseFolderTemplate
    )

    if ($Match.Status -eq 'matched') {
        $artistRaw = ($Match.Detail.artists[0].name -replace '\s+\(\d+\)$', '')
        $titleRaw = $Match.Detail.title
        $yearRaw = $Match.Detail.year
    }
    else {
        $artistRaw = $ArtistName
        $titleRaw = $Release.recognizedTitle
        $yearRaw = $Release.recognizedYear
    }

    $usedSentinelYear = $false
    if ($null -eq $yearRaw) {
        $yearRaw = $script:UnresolvedYearSentinel
        $usedSentinelYear = $true
    }

    $artistSan = ConvertTo-SafeFileName -Name $artistRaw -Context 'artist folder name'
    $titleSan = ConvertTo-SafeFileName -Name $titleRaw -Context 'release folder name'

    $folderName = (Expand-TaggerNamingTemplate -Template $ReleaseFolderTemplate -Values @{ year = [int]$yearRaw; album = $titleSan.SafeName }).Trim()

    return [pscustomobject]@{
        ArtistFolderName  = $artistSan.SafeName
        ReleaseFolderName = $folderName
        Year              = [int]$yearRaw
        Artist            = $artistRaw
        Album             = $titleRaw
        UsedSentinelYear  = $usedSentinelYear
        Substitutions     = @($artistSan.Substitutions + $titleSan.Substitutions)
    }
}

# --- Track naming and tagging ---------------------------------------------------

function New-TaggerProposedTrackSet {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Tracks,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$DiscogsTracks,

        [Parameter(Mandatory)]
        [object]$Names,

        [Parameter(Mandatory)]
        [string]$TrackFileTemplate,

        [int]$TrackNumberPadWidth = 2
    )

    $substitutions = [System.Collections.Generic.List[string]]::new()

    # Group tracks by discFolder in first-seen order - a single-disc release has every track's
    # discFolder as $null, which naturally becomes one group (disc 1).
    $discOrder = [System.Collections.Generic.List[string]]::new()
    $discGroups = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[object]]]::new()
    foreach ($track in $Tracks) {
        $key = if ($null -eq $track.discFolder) { '' } else { $track.discFolder }
        if (-not $discGroups.ContainsKey($key)) {
            $discOrder.Add($key)
            $discGroups[$key] = [System.Collections.Generic.List[object]]::new()
        }
        $discGroups[$key].Add($track)
    }

    $padWidth = Get-TaggerProposalPadWidth -TotalTrackCount $Tracks.Count -MinWidth $TrackNumberPadWidth
    $useDiscogsTitles = ($DiscogsTracks.Count -gt 0)

    $continuous = 0
    $discIndex = 0
    $result = [System.Collections.Generic.List[object]]::new()

    foreach ($discKey in $discOrder) {
        $discIndex++
        $trackIndexInDisc = 0
        foreach ($track in $discGroups[$discKey]) {
            $trackIndexInDisc++
            $continuous++

            if ($useDiscogsTitles) {
                $rawTitle = $DiscogsTracks[$continuous - 1].title
            }
            elseif ($track.existingTags.title) {
                $rawTitle = $track.existingTags.title
            }
            else {
                $rawTitle = (ConvertFrom-TaggerTrackFileName -FileName $track.originalFileName).Title
            }

            $titleSan = ConvertTo-SafeFileName -Name $rawTitle -Context 'track file name'
            if ($titleSan.Substitutions.Count -gt 0) { $substitutions.AddRange([string[]]$titleSan.Substitutions) }

            # {trackNumber} here is the continuous, zero-padded, cross-disc filename number - never
            # tags.track below, which restarts at 1 per disc. These are two different numbers per
            # manifesto section 5 and must not be conflated.
            $padded = $continuous.ToString('0' * $padWidth)
            $fileNameCore = Expand-TaggerNamingTemplate -Template $TrackFileTemplate -Values @{ trackNumber = $padded; title = $titleSan.SafeName }
            $proposedFileName = "$fileNameCore.$($track.format)"

            $tags = [pscustomobject]@{
                artist      = $Names.Artist
                albumArtist = $Names.Artist
                album       = $Names.Album
                year        = $Names.Year
                discNumber  = $discIndex
                track       = $trackIndexInDisc
                title       = $rawTitle
            }

            $extended = $track | Select-Object *
            $extended | Add-Member -NotePropertyName proposedFileName -NotePropertyValue $proposedFileName -Force
            $extended | Add-Member -NotePropertyName proposedDiscNumber -NotePropertyValue $discIndex -Force
            $extended | Add-Member -NotePropertyName proposedTrackNumber -NotePropertyValue $trackIndexInDisc -Force
            $extended | Add-Member -NotePropertyName proposedTitle -NotePropertyValue $rawTitle -Force
            $extended | Add-Member -NotePropertyName tags -NotePropertyValue $tags -Force

            $result.Add($extended)
        }
    }

    return [pscustomobject]@{ Tracks = @($result); Substitutions = @($substitutions) }
}

# --- Cover art -------------------------------------------------------------------

function Get-TaggerImageDimensions {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    try {
        if (-not ('System.Drawing.Image' -as [type])) {
            Add-Type -AssemblyName System.Drawing
        }
        $image = [System.Drawing.Image]::FromFile((ConvertTo-TaggerLongPath -Path $Path))
        try {
            return [pscustomobject]@{ Width = $image.Width; Height = $image.Height }
        }
        finally {
            $image.Dispose()
        }
    }
    catch {
        return [pscustomobject]@{ Width = 1; Height = 1 }
    }
}

function New-TaggerCoverArtProposal {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [object]$Match,

        [Parameter(Mandatory)]
        [object]$Release,

        [Parameter(Mandatory)]
        [int]$CoverMaxDimension
    )

    $candidates = [System.Collections.Generic.List[object]]::new()

    # An embedded cover is offered - and defaulted to - regardless of a Discogs match, so a track
    # that already carries a good cover isn't silently overwritten by a Discogs image the user never
    # asked to swap in. 'existing (embedded)' is read back as a literal string by
    # Tagger.Implementation.psm1 to decide whether to leave a track's picture tag untouched, the same
    # way this function already reads '(alternate)' below - not just a display label.
    $embeddedTrack = @($Release.tracks | Where-Object { $_.existingCoverArtPath }) | Select-Object -First 1
    if ($embeddedTrack) {
        $dims = Get-TaggerImageDimensions -Path $embeddedTrack.existingCoverArtPath
        $candidates.Add([pscustomobject]@{
                url           = $embeddedTrack.existingCoverArtPath
                sourceEdition = 'existing (embedded)'
                width         = $dims.Width
                height        = $dims.Height
            })
    }

    if ($Match.Status -eq 'matched' -and $Match.Detail.images -and @($Match.Detail.images).Count -gt 0) {
        $formatLabel = "$($Match.Detail.country) $($Match.Detail.formats[0].name)".Trim()
        if (-not $formatLabel) { $formatLabel = 'unknown edition' }
        foreach ($image in @($Match.Detail.images)) {
            $edition = if ($image.type -eq 'primary') { $formatLabel } else { "$formatLabel (alternate)" }
            $candidates.Add([pscustomobject]@{
                    url           = $image.uri
                    sourceEdition = $edition
                    width         = [int]$image.width
                    height        = [int]$image.height
                })
        }
    }
    else {
        foreach ($cover in @($Release.companionFiles | Where-Object { $_.kind -eq 'cover' })) {
            $dims = Get-TaggerImageDimensions -Path $cover.sourcePath
            $candidates.Add([pscustomobject]@{
                    url           = $cover.sourcePath
                    sourceEdition = 'existing (local)'
                    width         = $dims.Width
                    height        = $dims.Height
                })
        }
    }

    $chosen = $null
    $embeddedCandidate = $candidates | Where-Object { $_.sourceEdition -eq 'existing (embedded)' } | Select-Object -First 1
    if ($embeddedCandidate) {
        $chosen = $embeddedCandidate.url
    }
    else {
        $nonAlternate = @($candidates | Where-Object { $_.sourceEdition -notmatch '\(alternate\)$' })
        if ($nonAlternate.Count -gt 0) {
            $chosen = $nonAlternate[0].url
        }
        elseif ($candidates.Count -gt 0) {
            $chosen = $candidates[0].url
        }
    }

    return [pscustomobject]@{
        candidates         = @($candidates)
        chosenCandidateUrl = $chosen
        targetMaxDimension = $CoverMaxDimension
    }
}

# --- Target comparison -------------------------------------------------------------

function Build-TaggerTargetIndex {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.Dictionary[string, object]])]
    param(
        [Parameter(Mandatory)]
        [string]$TargetRoot
    )

    $index = [System.Collections.Generic.Dictionary[string, object]]::new()

    if (-not (Test-Path -LiteralPath $TargetRoot -PathType Container)) {
        return $index
    }

    $artistDirs = @(Get-ChildItem -LiteralPath $TargetRoot -Directory -ErrorAction SilentlyContinue)
    foreach ($artistDir in $artistDirs) {
        $releaseDirs = @(Get-ChildItem -LiteralPath $artistDir.FullName -Directory -ErrorAction SilentlyContinue)
        foreach ($releaseDir in $releaseDirs) {
            if ($releaseDir.Name -notmatch '^(\d{4})\s+(.+)$') { continue }
            $year = [int]$Matches[1]
            $album = $Matches[2].Trim()
            $stableKey = Get-TaggerStableKey -Artist $artistDir.Name -Album $album -Year $year

            # First occurrence wins on a stableKey collision - a pre-existing target-side data
            # inconsistency, not something this index is responsible for fixing.
            if (-not $index.ContainsKey($stableKey)) {
                $index[$stableKey] = [pscustomobject]@{
                    Path              = $releaseDir.FullName
                    ArtistFolderName  = $artistDir.Name
                    ReleaseFolderName = $releaseDir.Name
                }
            }
        }
    }

    return $index
}

function Test-TaggerTargetReleaseExists {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [System.Collections.Generic.Dictionary[string, object]]$TargetIndex,

        [Parameter(Mandatory)]
        [string]$StableKey
    )

    if ($TargetIndex.ContainsKey($StableKey)) {
        return $TargetIndex[$StableKey]
    }
    return $null
}

function Resolve-TaggerTargetComparison {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [object]$Release,

        [Parameter(Mandatory)]
        [string]$StableKey,

        [Parameter(Mandatory)]
        [string]$ProposedTargetPath,

        [Parameter(Mandatory)]
        [string]$TargetRoot,

        [Parameter(Mandatory)]
        [System.Collections.Generic.Dictionary[string, object]]$TargetIndex,

        [Parameter(Mandatory)]
        [System.Collections.Generic.Dictionary[string, object]]$SessionSeen,

        [Parameter(Mandatory)]
        [object]$Names,

        [Parameter(Mandatory)]
        [string]$DataHome
    )

    $sourcePaths = @($Release.tracks.sourceFilePath | Select-Object -Unique)
    $sourceHash = Get-TaggerFileSetHash -FilePaths $sourcePaths

    $totalTracks = $Release.tracks.Count
    $losslessCount = @($Release.tracks | Where-Object { $_.isLossless }).Count
    $sourceIsLossless = ($losslessCount -eq $totalTracks)
    $sourceIsLossy = -not $sourceIsLossless
    $forcedReviewNote = $null

    if ($losslessCount -gt 0 -and $losslessCount -lt $totalTracks) {
        # Conservative: a release that's part lossless/part lossy is treated as lossy for the
        # decision below rather than guessing which half matters more.
        $forcedReviewNote = 'release has mixed lossless/lossy source tracks; treated as lossy for target comparison'
    }

    # Check same-session duplicates first (plan/10's "same release, two sources, one session" case)
    # before touching disk - this also means a target folder is never hashed twice in one run.
    $baseline = $null
    $appliedEntryMatchesSource = $false
    if ($SessionSeen.ContainsKey($StableKey)) {
        $baseline = $SessionSeen[$StableKey]
    }
    else {
        # Prefer apply-log.json's own record of what was actually applied over re-hashing the
        # target folder's current file names/sizes: Implementation (plan/08) renames every file and
        # rewrites its tags on apply, so a target file set can never hash equal to its own source's
        # name|size hash again afterwards - comparing them here would always land on 'conflict' and
        # break re-run idempotency (plan/12 milestone 7). Test-TaggerAppliedEntryValid is the exact
        # "is this log entry still trustworthy" check Test-TaggerReleaseNeedsApply
        # (Tagger.Implementation.psm1) already uses for its own, equivalent skip decision.
        #
        # Looked up by $StableKey directly (the apply-log's own key), not through $TargetIndex -
        # Build-TaggerTargetIndex recomputes a folder's stableKey from its *current* on-disk name,
        # which for an unresolved-year release (script:UnresolvedYearSentinel, 1900) never equals
        # this release's real stableKey (computed with Year = $null) - that recomputed index can't
        # be used to find this release's own applied entry.
        $applyLogEntry = Get-TaggerApplyLogEntry -StableKey $StableKey -DataHome $DataHome
        if ((Test-TaggerAppliedEntryValid -Entry $applyLogEntry -TargetRoot $TargetRoot) -and `
                ($applyLogEntry.sourceFileSetHash -eq $sourceHash)) {
            $appliedEntryMatchesSource = $true
        }

        $entry = Test-TaggerTargetReleaseExists -TargetIndex $TargetIndex -StableKey $StableKey
        if ($entry) {
            $targetFiles = @(Get-TaggerAudioFilesInFolder -Path $entry.Path -Recurse)
            $targetHash = Get-TaggerFileSetHash -FilePaths $targetFiles.FullName
            $targetIsLossless = $targetFiles.Count -gt 0
            foreach ($file in $targetFiles) {
                if (-not (Test-TaggerIsLosslessFormat -Extension $file.Extension)) {
                    $targetIsLossless = $false
                    break
                }
            }
            $baseline = [pscustomobject]@{ Hash = $targetHash; IsLossless = $targetIsLossless }
        }
    }

    if ($appliedEntryMatchesSource) {
        $targetAction = 'skip-existing-identical'
    }
    elseif ($null -eq $baseline) {
        $targetAction = 'create-new'
    }
    elseif ($baseline.Hash -eq $sourceHash) {
        $targetAction = 'skip-existing-identical'
    }
    elseif ($sourceIsLossless -and -not $baseline.IsLossless) {
        $targetAction = 'update-existing'
    }
    else {
        $targetAction = 'conflict'
        $conflictNote = 'target conflict: existing target differs from source and is not a lossy-to-lossless upgrade'
        $forcedReviewNote = if ($forcedReviewNote) { "$forcedReviewNote; $conflictNote" } else { $conflictNote }
    }

    if ($targetAction -eq 'update-existing') {
        $lossyLossless = [pscustomobject]@{ isLossy = $false; action = 'replace-existing' }
    }
    elseif ($sourceIsLossy) {
        $lossyLossless = [pscustomobject]@{ isLossy = $true; action = 'log-for-upgrade' }
    }
    else {
        $lossyLossless = [pscustomobject]@{ isLossy = $false; action = 'none' }
    }

    if ($sourceIsLossy) {
        # Upserted on every sighting, not just create-new, so lastCheckedUtc keeps advancing even
        # while a release sits pending-upgrade across many re-runs (plan/09's add-or-touch lifecycle).
        Add-TaggerLossyTrackingEntry -StableKey $StableKey -Artist $Names.ArtistFolderName -Album $Names.Album `
            -Year $Names.Year -TargetPath $ProposedTargetPath -Format $Release.tracks[0].format -DataHome $DataHome | Out-Null
    }

    $SessionSeen[$StableKey] = [pscustomobject]@{ Hash = $sourceHash; IsLossless = $sourceIsLossless }

    return [pscustomobject]@{
        TargetAction     = $targetAction
        LossyLossless    = $lossyLossless
        ForcedReviewNote = $forcedReviewNote
    }
}

# --- Orchestration -----------------------------------------------------------------

# --- Companion files ------------------------------------------------------------------

function New-TaggerCompanionProposal {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$CompanionFiles
    )

    $notes = [System.Collections.Generic.List[string]]::new()
    $requiresReview = $false

    $companions = foreach ($companion in $CompanionFiles) {
        $proposedFileName = $null

        if ($companion.placement -eq 'loose') {
            $originalName = Split-Path -Leaf $companion.sourcePath
            $renamed = Get-TaggerLooseCompanionFileName -FileName $originalName -Kind $companion.kind
            $proposedFileName = $renamed.FileName
            if ($renamed.WasPrefixed) {
                $requiresReview = $true
                $notes.Add("Companion '$originalName' renamed to '$proposedFileName' (must start with a letter).")
            }
        }

        [pscustomobject]@{
            sourcePath       = $companion.sourcePath
            kind             = $companion.kind
            placement        = $companion.placement
            include          = $true
            proposedFileName = $proposedFileName
        }
    }

    return [pscustomobject]@{
        Companions     = @($companions)
        Notes          = @($notes)
        RequiresReview = $requiresReview
    }
}

function New-TaggerProposedRelease {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$ArtistName,

        [Parameter(Mandatory)]
        [object]$Release,

        [Parameter(Mandatory)]
        [string]$TargetRoot,

        [Parameter(Mandatory)]
        [string]$ReleaseFolderTemplate,

        [Parameter(Mandatory)]
        [string]$TrackFileTemplate,

        [int]$TrackNumberPadWidth = 2,

        [Parameter(Mandatory)]
        [int]$CoverMaxDimension,

        [Parameter(Mandatory)]
        [int]$CacheTtlDays,

        [Parameter(Mandatory)]
        [int]$RateLimitPerMinute,

        [Parameter(Mandatory)]
        [System.Collections.Generic.Dictionary[string, object]]$TargetIndex,

        [Parameter(Mandatory)]
        [System.Collections.Generic.Dictionary[string, object]]$SessionSeen,

        [Parameter(Mandatory)]
        [string]$DataHome
    )

    $notes = [System.Collections.Generic.List[string]]::new()
    $requiresReview = $false

    # Recognition's own ambiguity flags (grouping-folder cases, band-member-as-artist cases,
    # artist-name-split-from-folder-name, etc.) must carry through to the one general "does a
    # human need to look at this" gate Implementation actually checks - they were previously
    # silently dropped unless one of this function's own unrelated checks happened to also trip.
    if ($Release.needsReview) {
        $requiresReview = $true
        if ($Release.reviewReasons) { $notes.AddRange([string[]]@($Release.reviewReasons)) }
    }

    $match = Resolve-TaggerDiscogsMatch -ArtistName $ArtistName -Title $Release.recognizedTitle -Year $Release.recognizedYear `
        -DataHome $DataHome -CacheTtlDays $CacheTtlDays -RateLimitPerMinute $RateLimitPerMinute

    if ($match.ErrorNote) {
        $notes.Add($match.ErrorNote)
        $requiresReview = $true
    }
    if ($match.Status -ne 'matched') {
        $requiresReview = $true
        $notes.Add("Discogs match status: $($match.Status)")
    }

    $names = New-TaggerProposedReleaseNames -ArtistName $ArtistName -Release $Release -Match $match -ReleaseFolderTemplate $ReleaseFolderTemplate
    if ($names.Substitutions.Count -gt 0) { $notes.AddRange([string[]]$names.Substitutions) }
    if ($names.UsedSentinelYear) {
        $requiresReview = $true
        $notes.Add('UNRESOLVED YEAR: placeholder value used, must be corrected before applying.')
    }

    $discogsTracks = @()
    if ($match.Status -eq 'matched') {
        $discogsTracks = @($match.Detail.tracklist | Where-Object { $_.position -and $_.position.Trim() -ne '' })
        if ($discogsTracks.Count -ne $Release.tracks.Count) {
            $requiresReview = $true
            $notes.Add("Discogs tracklist has $($discogsTracks.Count) tracks but source has $($Release.tracks.Count); falling back to source titles.")
            $discogsTracks = @()
        }
    }

    $trackSet = New-TaggerProposedTrackSet -Tracks $Release.tracks -DiscogsTracks $discogsTracks -Names $names -TrackFileTemplate $TrackFileTemplate `
        -TrackNumberPadWidth $TrackNumberPadWidth
    if ($trackSet.Substitutions.Count -gt 0) { $notes.AddRange([string[]]$trackSet.Substitutions) }

    $coverArt = New-TaggerCoverArtProposal -Match $match -Release $Release -CoverMaxDimension $CoverMaxDimension
    if ($coverArt.candidates.Count -eq 0) {
        $requiresReview = $true
        $notes.Add('No cover art candidates found from Discogs or local companion files.')
    }

    $companionProposal = New-TaggerCompanionProposal -CompanionFiles $Release.companionFiles
    if ($companionProposal.Notes.Count -gt 0) { $notes.AddRange([string[]]$companionProposal.Notes) }
    if ($companionProposal.RequiresReview) { $requiresReview = $true }

    $proposedTargetPath = Join-Path $TargetRoot $names.ArtistFolderName $names.ReleaseFolderName
    $comparison = Resolve-TaggerTargetComparison -Release $Release -StableKey $Release.stableKey -ProposedTargetPath $proposedTargetPath `
        -TargetRoot $TargetRoot -TargetIndex $TargetIndex -SessionSeen $SessionSeen -Names $names -DataHome $DataHome
    if ($comparison.ForcedReviewNote) {
        $requiresReview = $true
        $notes.Add($comparison.ForcedReviewNote)
    }

    $discogsMatchDoc = [pscustomobject]@{
        status            = $match.Status
        selectedReleaseId = $match.SelectedReleaseId
        candidates        = @($match.Candidates)
    }

    $proposedDoc = [pscustomobject]@{
        artistFolderName  = $names.ArtistFolderName
        releaseFolderName = $names.ReleaseFolderName
        year              = $names.Year
        album             = $names.Album
    }

    $humanReview = [pscustomobject]@{
        required = $requiresReview
        resolved = -not $requiresReview
        rejected = $false
        notes    = ($notes -join '; ')
    }

    return [pscustomobject]@{
        stableKey             = $Release.stableKey
        recognizedTitle       = $Release.recognizedTitle
        recognizedYear        = $Release.recognizedYear
        sourceFolderPath      = $Release.sourceFolderPath
        discFolderCount       = $Release.discFolderCount
        tracks                = $trackSet.Tracks
        companionFiles        = $companionProposal.Companions
        ignoredFiles          = $Release.ignoredFiles
        cueSheet              = $Release.cueSheet
        recognitionConfidence = $Release.recognitionConfidence
        recognitionFlags      = $Release.recognitionFlags
        needsReview           = $Release.needsReview
        reviewReasons         = $Release.reviewReasons
        discogsMatch          = $discogsMatchDoc
        proposed              = $proposedDoc
        coverArt              = $coverArt
        lossyLossless         = $comparison.LossyLossless
        targetAction          = $comparison.TargetAction
        humanReview           = $humanReview
    }
}

function Invoke-TaggerEditProposal {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$SessionId,

        [Parameter(Mandatory)]
        [string]$RecognitionPath,

        [Parameter(Mandatory)]
        [string]$TargetRoot,

        [string]$DataHome,

        [string]$ReleaseFolderTemplate = '{year} {album}',

        [string]$TrackFileTemplate = '{trackNumber} {title}',

        [int]$TrackNumberPadWidth = 2,

        [int]$CoverMaxDimension = 600,

        [int]$CacheTtlDays = 30,

        [int]$RateLimitPerMinute = 55,

        [string]$ProposalPath
    )

    if (-not $DataHome) { $DataHome = Resolve-TaggerDataHome }
    if (-not $ProposalPath) { $ProposalPath = Join-Path $DataHome 'sessions' $SessionId 'proposal.json' }

    if (-not (Test-TaggerJson -SchemaName recognition -Path $RecognitionPath)) {
        throw "Recognition document at '$RecognitionPath' does not match the recognition schema."
    }
    $recognition = Get-Content -LiteralPath $RecognitionPath -Raw | ConvertFrom-Json

    $targetIndex = Build-TaggerTargetIndex -TargetRoot $TargetRoot
    $sessionSeen = [System.Collections.Generic.Dictionary[string, object]]::new()

    $artists = @(foreach ($artist in @($recognition.artists)) {
            $releases = @(foreach ($release in @($artist.releases)) {
                    New-TaggerProposedRelease -ArtistName $artist.recognizedName -Release $release -TargetRoot $TargetRoot `
                        -ReleaseFolderTemplate $ReleaseFolderTemplate -TrackFileTemplate $TrackFileTemplate -TrackNumberPadWidth $TrackNumberPadWidth `
                        -CoverMaxDimension $CoverMaxDimension -CacheTtlDays $CacheTtlDays -RateLimitPerMinute $RateLimitPerMinute `
                        -TargetIndex $targetIndex -SessionSeen $sessionSeen -DataHome $DataHome
                })

            [pscustomobject]@{
                recognizedName = $artist.recognizedName
                sourcePaths    = @($artist.sourcePaths)
                releases       = $releases
            }
        })

    $document = [pscustomobject]@{
        schemaVersion  = 1
        sessionId      = $SessionId
        sourceRoot     = $recognition.sourceRoot
        generatedAtUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        artists        = $artists
        unrecognized   = @($recognition.unrecognized)
    }

    Set-TaggerJsonFile -Path $ProposalPath -InputObject $document -SchemaName proposal -Depth 20 | Out-Null

    return (Get-Content -LiteralPath $ProposalPath -Raw | ConvertFrom-Json)
}

Export-ModuleMember -Function Invoke-TaggerEditProposal, Build-TaggerTargetIndex, Test-TaggerTargetReleaseExists
