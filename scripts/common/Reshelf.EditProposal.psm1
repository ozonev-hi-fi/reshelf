#Requires -Version 7.4

Import-Module (Join-Path $PSScriptRoot 'Reshelf.Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Reshelf.Json.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Reshelf.Discogs.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Reshelf.LossyTracking.psm1') -Force
# Only for Get-ReshelfApplyLogEntry/Test-ReshelfAppliedEntryValid (Resolve-ReshelfTargetComparison's
# re-run skip check below) - Reshelf.Implementation.psm1 never imports this module back, so there's
# no cycle. Every caller that imports both (Reshelf.ps1, Reshelf.Pipeline.Tests.ps1) already imports
# Reshelf.Implementation.psm1 directly *after* this module, which - same fix already relied on for
# Reshelf.LossyTracking.psm1 above - restores its exports to that caller's own top-level scope
# instead of leaving them hidden as this module's nested copy.
Import-Module (Join-Path $PSScriptRoot 'Reshelf.Implementation.psm1') -Force

# Starting point per plan/02 - not exposed in settings.schema.json (additionalProperties: false,
# no such field), so this stays a module constant rather than a configurable setting.
$script:DiscogsMatchThreshold = 0.85

# proposal.schema.json requires tags.year to be a non-nullable integer, so an unresolved year
# (no Discogs match, no recognized year) can't be represented as null - this sentinel (the
# schema's own minimum) is used instead and always paired with humanReview.required = true.
$script:UnresolvedYearSentinel = 1900

# --- String similarity -------------------------------------------------------

function Get-ReshelfLevenshteinDistance {
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

function Get-ReshelfStringSimilarity {
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

    $distance = Get-ReshelfLevenshteinDistance -A $A -B $B
    $maxLen = [Math]::Max($A.Length, $B.Length)
    return 1.0 - ($distance / $maxLen)
}

# --- Discogs matching ----------------------------------------------------------

function Get-ReshelfDiscogsSearchTitleVariants {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$Title
    )

    # Real cases (plan/12 milestone 3): a source folder name often carries more than the Discogs
    # release_title - a parenthetical sub-title/catalog/pressing note ("Violator (1990) (ALFA
    # ALCB-35) (1st Japan 1990)"), or a trailing edition word ("Forwards Special Edition") - and
    # Discogs' search field match fails outright when release_title still contains that noise, even
    # for a release that demonstrably exists (confirmed directly against the live API). "Raw" is
    # tried first (still finds a real one-word-off title), "cleaned" second.
    $trimmedRaw = $Title.Trim()
    $groupPattern = '\s*[\(\[][^\)\]]*[\)\]]'

    $yearHint = $null
    foreach ($groupMatch in [regex]::Matches($trimmedRaw, $groupPattern)) {
        if (-not $yearHint -and $groupMatch.Value -match '(19|20)\d{2}') {
            $yearHint = [int]$Matches[0]
        }
    }

    $cleaned = [regex]::Replace($trimmedRaw, $groupPattern, '')
    $cleaned = [regex]::Replace($cleaned, '\s*[-–—]\s*$', '')
    $cleaned = [regex]::Replace($cleaned, '(?i)\s+\b(special|deluxe|limited|expanded|anniversary|remastered)\b\s*(edition)?\s*$', '')
    $cleaned = [regex]::Replace($cleaned, '\s+', ' ').Trim()

    $titles = [System.Collections.Generic.List[string]]::new()
    $titles.Add($trimmedRaw)
    if ($cleaned -and $cleaned -ne $trimmedRaw) { $titles.Add($cleaned) }

    return [pscustomobject]@{ Titles = @($titles); YearHint = $yearHint }
}

function Get-ReshelfDiscogsSearchQuery {
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

function Get-ReshelfDiscogsCandidateScore {
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

    $normalizedExpectedArtist = ConvertTo-ReshelfNormalizedText -Text $ExpectedArtist
    $normalizedExpectedTitle = ConvertTo-ReshelfNormalizedText -Text $ExpectedTitle
    $normalizedCandidateArtist = ConvertTo-ReshelfNormalizedText -Text $candidateArtist
    $normalizedCandidateTitle = ConvertTo-ReshelfNormalizedText -Text $candidateTitle

    $artistScore = Get-ReshelfStringSimilarity -A $normalizedExpectedArtist -B $normalizedCandidateArtist
    $titleScore = Get-ReshelfStringSimilarity -A $normalizedExpectedTitle -B $normalizedCandidateTitle

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

function Get-ReshelfDiscogsFormatPreferenceRank {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$FormatText
    )

    # Lower is more likely to be the "main" release a collection copy should be tagged against -
    # used only as a tie-breaker when no eligible candidate's tracklist count matches the source
    # (real case: Pivot "O Soundtrack My Heart" had 5 same-scoring candidates - a 7" single, a promo
    # CDr, and 3 albums - and the search result order alone gave no reason to prefer one).
    if ($FormatText -match '(?i)\balbum\b') { return 0 }
    if ($FormatText -match '(?i)\bep\b') { return 1 }
    if ($FormatText -match '(?i)\bsingle\b') { return 2 }
    if ($FormatText -match '(?i)\bpromo\b') { return 3 }
    return 4
}

function Select-ReshelfBestDiscogsCandidate {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [object[]]$Eligible,

        [int]$SourceTrackCount = 0,

        [string]$DataHome,

        [int]$CacheTtlDays = 30,

        [int]$RateLimitPerMinute = 55
    )

    # $SourceTrackCount <= 0 means the caller doesn't know (or care) - keep the pre-existing
    # behavior of trusting the top-scored candidate with exactly one detail fetch.
    if ($SourceTrackCount -le 0 -or $Eligible.Count -eq 1) {
        $top = $Eligible[0]
        $detail = Invoke-DiscogsRequest -Path "/releases/$($top.releaseId)" -CacheTtlDays $CacheTtlDays -RateLimitPerMinute $RateLimitPerMinute -DataHome $DataHome
        return [pscustomobject]@{ ReleaseId = $top.releaseId; Detail = $detail }
    }

    # Bounded to 5 detail fetches (same width as the Candidates list shown in the UI) - a real
    # release rarely has more than a handful of same-scoring editions, and each fetch is cached.
    $probeLimit = [Math]::Min(5, $Eligible.Count)
    $probed = [System.Collections.Generic.List[object]]::new()
    for ($i = 0; $i -lt $probeLimit; $i++) {
        $candidate = $Eligible[$i]
        $detail = Invoke-DiscogsRequest -Path "/releases/$($candidate.releaseId)" -CacheTtlDays $CacheTtlDays -RateLimitPerMinute $RateLimitPerMinute -DataHome $DataHome
        $trackCount = @($detail.tracklist | Where-Object { $_.position -and $_.position.Trim() -ne '' }).Count
        if ($trackCount -eq $SourceTrackCount) {
            return [pscustomobject]@{ ReleaseId = $candidate.releaseId; Detail = $detail }
        }
        $probed.Add([pscustomobject]@{ Candidate = $candidate; Detail = $detail })
    }

    # None of the probed candidates has the source's exact track count - prefer an Album-format
    # edition over EP/Single/Promo/etc among only the ones actually probed, instead of blindly
    # keeping the top-scored one (which search-result order alone doesn't make more "correct").
    $preferred = @($probed | Sort-Object { Get-ReshelfDiscogsFormatPreferenceRank -FormatText $_.Candidate.format })[0]
    return [pscustomobject]@{ ReleaseId = $preferred.Candidate.releaseId; Detail = $preferred.Detail }
}

function Resolve-ReshelfDiscogsMatch {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$ArtistName,

        [Parameter(Mandatory)]
        [string]$Title,

        [Nullable[int]]$Year,

        # 0 (default) means "unknown" - callers that don't have a source track count yet (or don't
        # care, e.g. tests) get the pre-existing single-top-candidate behavior unchanged.
        [int]$SourceTrackCount = 0,

        [string]$DataHome,

        [int]$CacheTtlDays = 30,

        [int]$RateLimitPerMinute = 55
    )

    try {
        $variants = Get-ReshelfDiscogsSearchTitleVariants -Title $Title
        $effectiveYear = if ($null -ne $Year) { $Year } else { $variants.YearHint }

        # A ladder of at most 4 cached searches (2 title variants x with/without year), stopping at
        # the first one that returns anything - not every combination up front, since most releases
        # match on the very first (raw, with year) attempt and the rest would be wasted calls.
        # Select-Object -Unique drops $null entries entirely rather than collapsing them to one
        # (confirmed directly - @($null, $null) | Select-Object -Unique returns zero items), so a
        # null-safe dedupe is built by hand instead: [$effectiveYear, $null] normally, or just
        # [$null] when there's no year to try at all. The whole if-expression is wrapped in the
        # outer @() - an inner-only @($null) still collapses to plain $null when it's the sole
        # output of an if/else branch (confirmed directly), losing the one attempt entirely.
        $yearAttempts = @(if ($null -ne $effectiveYear) { $effectiveYear; $null } else { $null })

        $releaseResults = @()
        foreach ($variantTitle in $variants.Titles) {
            foreach ($attemptYear in $yearAttempts) {
                $query = Get-ReshelfDiscogsSearchQuery -ArtistName $ArtistName -Title $variantTitle -Year $attemptYear
                $searchResult = Invoke-DiscogsRequest -Path '/database/search' -Query $query -CacheTtlDays $CacheTtlDays -RateLimitPerMinute $RateLimitPerMinute -DataHome $DataHome
                $releaseResults = @($searchResult.results | Where-Object { $_.type -eq 'release' })
                if ($releaseResults.Count -gt 0) { break }
            }
            if ($releaseResults.Count -gt 0) { break }
        }

        if ($releaseResults.Count -eq 0) {
            return [pscustomobject]@{ Status = 'not-found'; SelectedReleaseId = $null; Candidates = @(); Detail = $null; ErrorNote = $null }
        }

        $scored = @(foreach ($result in $releaseResults) {
                # Scored against every title variant, not just the one that happened to return
                # results, and the best score kept - a candidate can score well against the raw
                # title even when only the cleaned variant's search actually found it (or vice
                # versa).
                $score = ($variants.Titles | ForEach-Object {
                        Get-ReshelfDiscogsCandidateScore -ExpectedArtist $ArtistName -ExpectedTitle $_ -ExpectedYear $Year -Candidate $result
                    } | Measure-Object -Maximum).Maximum
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
        $topCandidates = @($sorted | Select-Object -First 5)
        $eligible = @($sorted | Where-Object { $_.score -ge $script:DiscogsMatchThreshold })

        if ($eligible.Count -eq 0) {
            return [pscustomobject]@{
                Status            = 'ambiguous'
                SelectedReleaseId = $null
                Candidates        = $topCandidates
                Detail            = $null
                ErrorNote         = $null
            }
        }

        $picked = Select-ReshelfBestDiscogsCandidate -Eligible $eligible -SourceTrackCount $SourceTrackCount `
            -DataHome $DataHome -CacheTtlDays $CacheTtlDays -RateLimitPerMinute $RateLimitPerMinute

        return [pscustomobject]@{
            Status            = 'matched'
            SelectedReleaseId = $picked.ReleaseId
            Candidates        = $topCandidates
            Detail            = $picked.Detail
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

function Expand-ReshelfNamingTemplate {
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

function Get-ReshelfProposalPadWidth {
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

function New-ReshelfProposedReleaseNames {
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
        # Discogs is the encyclopedia here and has priority for casing/text as-is (e.g. "edbl" is
        # kept lowercase when Discogs itself agrees) - only invisible characters are stripped, never
        # a case change. (Bandcamp will get the same priority once plan/13 adds it.)
        $artistRaw = Remove-ReshelfInvisibleCharacters -Text ($Match.Detail.artists[0].name -replace '\s+\(\d+\)$', '')
        $titleRaw = Remove-ReshelfInvisibleCharacters -Text $Match.Detail.title
        $yearRaw = $Match.Detail.year
    }
    else {
        # No encyclopedia entry to defer to - Title Case is applied so a folder/tag name like
        # "aoki takamasa" (all-lowercase source folder) reads as "Aoki Takamasa" instead of
        # silently keeping whatever casing the source folder happened to use.
        $artistRaw = ConvertTo-ReshelfTitleCase -Text $ArtistName
        $titleRaw = ConvertTo-ReshelfTitleCase -Text $Release.recognizedTitle
        $yearRaw = $Release.recognizedYear
    }

    $usedSentinelYear = $false
    if ($null -eq $yearRaw) {
        $yearRaw = $script:UnresolvedYearSentinel
        $usedSentinelYear = $true
    }

    $artistSan = ConvertTo-SafeFileName -Name $artistRaw -Context 'artist folder name'
    $titleSan = ConvertTo-SafeFileName -Name $titleRaw -Context 'release folder name'

    $folderName = (Expand-ReshelfNamingTemplate -Template $ReleaseFolderTemplate -Values @{ year = [int]$yearRaw; album = $titleSan.SafeName }).Trim()

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

function Resolve-ReshelfDiscogsTrackAlignment {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$SourceTracks,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$DiscogsTracks
    )

    # Real case (plan/12 milestone 3): a Discogs tracklist can be longer than the source not because
    # of a bad match, but because the source is genuinely missing a track (never ripped, a bonus
    # track, etc.) - the caller's plain count check can't tell that apart from a wrong-edition match,
    # so this tries a title-similarity alignment before giving up to a full fallback. Every source
    # track must find its own distinct Discogs track (score >= 0.8) - a single miss falls the whole
    # release back to source titles (Aligned = $false), same as before this function existed.
    $usedDiscogsIndices = [System.Collections.Generic.HashSet[int]]::new()
    $aligned = [System.Collections.Generic.List[object]]::new()

    foreach ($sourceTrack in $SourceTracks) {
        $sourceTitle = if ($sourceTrack.existingTags.title) { $sourceTrack.existingTags.title } `
            else { (ConvertFrom-ReshelfTrackFileName -FileName $sourceTrack.originalFileName).Title }
        $normalizedSourceTitle = ConvertTo-ReshelfNormalizedText -Text $sourceTitle

        $bestIndex = -1
        $bestScore = 0.0
        for ($i = 0; $i -lt $DiscogsTracks.Count; $i++) {
            if ($usedDiscogsIndices.Contains($i)) { continue }
            $candidateScore = Get-ReshelfStringSimilarity -A $normalizedSourceTitle -B (ConvertTo-ReshelfNormalizedText -Text $DiscogsTracks[$i].title)
            if ($candidateScore -gt $bestScore) { $bestScore = $candidateScore; $bestIndex = $i }
        }

        if ($bestIndex -lt 0 -or $bestScore -lt 0.8) {
            return [pscustomobject]@{ Aligned = $false; Tracks = @(); MissingNote = $null }
        }

        [void]$usedDiscogsIndices.Add($bestIndex)
        $aligned.Add($DiscogsTracks[$bestIndex])
    }

    $missing = @(for ($i = 0; $i -lt $DiscogsTracks.Count; $i++) {
            if (-not $usedDiscogsIndices.Contains($i)) {
                "$($DiscogsTracks[$i].position) $($DiscogsTracks[$i].title)".Trim()
            }
        })
    $missingNote = if ($missing.Count -gt 0) { "missing on source: $($missing -join ', ')" } else { $null }

    return [pscustomobject]@{ Aligned = $true; Tracks = @($aligned); MissingNote = $missingNote }
}

# --- Track naming and tagging ---------------------------------------------------

function New-ReshelfProposedTrackSet {
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

    $padWidth = Get-ReshelfProposalPadWidth -TotalTrackCount $Tracks.Count -MinWidth $TrackNumberPadWidth
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
                $rawTitle = Remove-ReshelfInvisibleCharacters -Text $DiscogsTracks[$continuous - 1].title
            }
            elseif ($track.existingTags.title) {
                $rawTitle = ConvertTo-ReshelfTitleCase -Text $track.existingTags.title
            }
            else {
                $rawTitle = ConvertTo-ReshelfTitleCase -Text (ConvertFrom-ReshelfTrackFileName -FileName $track.originalFileName).Title
            }

            $titleSan = ConvertTo-SafeFileName -Name $rawTitle -Context 'track file name'
            if ($titleSan.Substitutions.Count -gt 0) { $substitutions.AddRange([string[]]$titleSan.Substitutions) }

            # {trackNumber} here is the continuous, zero-padded, cross-disc filename number - never
            # tags.track below, which restarts at 1 per disc. These are two different numbers per
            # manifesto section 5 and must not be conflated.
            $padded = $continuous.ToString('0' * $padWidth)
            $fileNameCore = Expand-ReshelfNamingTemplate -Template $TrackFileTemplate -Values @{ trackNumber = $padded; title = $titleSan.SafeName }
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

function Get-ReshelfImageDimensions {
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
        $image = [System.Drawing.Image]::FromFile((ConvertTo-ReshelfLongPath -Path $Path))
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

function New-ReshelfCoverArtProposal {
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
    # Reshelf.Implementation.psm1 to decide whether to leave a track's picture tag untouched, the same
    # way this function already reads '(alternate)' below - not just a display label.
    $embeddedTrack = @($Release.tracks | Where-Object { $_.existingCoverArtPath }) | Select-Object -First 1
    if ($embeddedTrack) {
        $dims = Get-ReshelfImageDimensions -Path $embeddedTrack.existingCoverArtPath
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
            $dims = Get-ReshelfImageDimensions -Path $cover.sourcePath
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

function Build-ReshelfTargetIndex {
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
            $stableKey = Get-ReshelfStableKey -Artist $artistDir.Name -Album $album -Year $year

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

function Test-ReshelfTargetReleaseExists {
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

function Resolve-ReshelfTargetComparison {
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
    $sourceHash = Get-ReshelfFileSetHash -FilePaths $sourcePaths

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
        # break re-run idempotency (plan/12 milestone 7). Test-ReshelfAppliedEntryValid is the exact
        # "is this log entry still trustworthy" check Test-ReshelfReleaseNeedsApply
        # (Reshelf.Implementation.psm1) already uses for its own, equivalent skip decision.
        #
        # Looked up by $StableKey directly (the apply-log's own key), not through $TargetIndex -
        # Build-ReshelfTargetIndex recomputes a folder's stableKey from its *current* on-disk name,
        # which for an unresolved-year release (script:UnresolvedYearSentinel, 1900) never equals
        # this release's real stableKey (computed with Year = $null) - that recomputed index can't
        # be used to find this release's own applied entry.
        $applyLogEntry = Get-ReshelfApplyLogEntry -StableKey $StableKey -DataHome $DataHome
        if ((Test-ReshelfAppliedEntryValid -Entry $applyLogEntry -TargetRoot $TargetRoot) -and `
                ($applyLogEntry.sourceFileSetHash -eq $sourceHash)) {
            $appliedEntryMatchesSource = $true
        }

        $entry = Test-ReshelfTargetReleaseExists -TargetIndex $TargetIndex -StableKey $StableKey
        if ($entry) {
            $targetFiles = @(Get-ReshelfAudioFilesInFolder -Path $entry.Path -Recurse)
            $targetHash = Get-ReshelfFileSetHash -FilePaths $targetFiles.FullName
            $targetIsLossless = $targetFiles.Count -gt 0
            foreach ($file in $targetFiles) {
                if (-not (Test-ReshelfIsLosslessFormat -Extension $file.Extension)) {
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
        Add-ReshelfLossyTrackingEntry -StableKey $StableKey -Artist $Names.ArtistFolderName -Album $Names.Album `
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

function New-ReshelfCompanionProposal {
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
            $renamed = Get-ReshelfLooseCompanionFileName -FileName $originalName -Kind $companion.kind
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

function New-ReshelfProposedRelease {
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

    $match = Resolve-ReshelfDiscogsMatch -ArtistName $ArtistName -Title $Release.recognizedTitle -Year $Release.recognizedYear `
        -SourceTrackCount $Release.tracks.Count -DataHome $DataHome -CacheTtlDays $CacheTtlDays -RateLimitPerMinute $RateLimitPerMinute

    if ($match.ErrorNote) {
        $notes.Add($match.ErrorNote)
        $requiresReview = $true
    }
    if ($match.Status -ne 'matched') {
        $requiresReview = $true
        $notes.Add("Discogs match status: $($match.Status)")
    }

    $names = New-ReshelfProposedReleaseNames -ArtistName $ArtistName -Release $Release -Match $match -ReleaseFolderTemplate $ReleaseFolderTemplate
    if ($names.Substitutions.Count -gt 0) { $notes.AddRange([string[]]$names.Substitutions) }
    if ($names.UsedSentinelYear) {
        $requiresReview = $true
        $notes.Add('UNRESOLVED YEAR: placeholder value used, must be corrected before applying.')
    }

    $discogsTracks = @()
    if ($match.Status -eq 'matched') {
        $rawDiscogsTracks = @($match.Detail.tracklist | Where-Object { $_.position -and $_.position.Trim() -ne '' })
        if ($rawDiscogsTracks.Count -eq $Release.tracks.Count) {
            $discogsTracks = $rawDiscogsTracks
        }
        else {
            $alignment = Resolve-ReshelfDiscogsTrackAlignment -SourceTracks $Release.tracks -DiscogsTracks $rawDiscogsTracks
            $requiresReview = $true
            if ($alignment.Aligned) {
                $discogsTracks = $alignment.Tracks
                $note = "Discogs tracklist has $($rawDiscogsTracks.Count) tracks but source has $($Release.tracks.Count); aligned by title."
                if ($alignment.MissingNote) { $note = "$note $($alignment.MissingNote)." }
                $notes.Add($note)
            }
            else {
                $notes.Add("Discogs tracklist has $($rawDiscogsTracks.Count) tracks but source has $($Release.tracks.Count); falling back to source titles.")
                $discogsTracks = @()
            }
        }
    }

    $trackSet = New-ReshelfProposedTrackSet -Tracks $Release.tracks -DiscogsTracks $discogsTracks -Names $names -TrackFileTemplate $TrackFileTemplate `
        -TrackNumberPadWidth $TrackNumberPadWidth
    if ($trackSet.Substitutions.Count -gt 0) { $notes.AddRange([string[]]$trackSet.Substitutions) }

    $coverArt = New-ReshelfCoverArtProposal -Match $match -Release $Release -CoverMaxDimension $CoverMaxDimension
    if ($coverArt.candidates.Count -eq 0) {
        $requiresReview = $true
        $notes.Add('No cover art candidates found from Discogs or local companion files.')
    }

    $companionProposal = New-ReshelfCompanionProposal -CompanionFiles $Release.companionFiles
    if ($companionProposal.Notes.Count -gt 0) { $notes.AddRange([string[]]$companionProposal.Notes) }
    if ($companionProposal.RequiresReview) { $requiresReview = $true }

    $proposedTargetPath = Join-Path $TargetRoot $names.ArtistFolderName $names.ReleaseFolderName
    $comparison = Resolve-ReshelfTargetComparison -Release $Release -StableKey $Release.stableKey -ProposedTargetPath $proposedTargetPath `
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

function Invoke-ReshelfEditProposal {
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

    if (-not $DataHome) { $DataHome = Resolve-ReshelfDataHome }
    if (-not $ProposalPath) { $ProposalPath = Join-Path $DataHome 'sessions' $SessionId 'proposal.json' }

    if (-not (Test-ReshelfJson -SchemaName recognition -Path $RecognitionPath)) {
        throw "Recognition document at '$RecognitionPath' does not match the recognition schema."
    }
    $recognition = Get-Content -LiteralPath $RecognitionPath -Raw | ConvertFrom-Json

    $targetIndex = Build-ReshelfTargetIndex -TargetRoot $TargetRoot
    $sessionSeen = [System.Collections.Generic.Dictionary[string, object]]::new()

    $artists = @(foreach ($artist in @($recognition.artists)) {
            $releases = @(foreach ($release in @($artist.releases)) {
                    New-ReshelfProposedRelease -ArtistName $artist.recognizedName -Release $release -TargetRoot $TargetRoot `
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

    Set-ReshelfJsonFile -Path $ProposalPath -InputObject $document -SchemaName proposal -Depth 20 | Out-Null

    return (Get-Content -LiteralPath $ProposalPath -Raw | ConvertFrom-Json)
}

Export-ModuleMember -Function Invoke-ReshelfEditProposal, Build-ReshelfTargetIndex, Test-ReshelfTargetReleaseExists
