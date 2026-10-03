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

# Subtracted from a Compilation/Box Set/Unofficial Release candidate's score. Small enough that an
# exact-title compilation still passes the threshold; large enough that a fuzzy one (real case:
# "Classic Aerosmith" for the 1973 album "Aerosmith") no longer wins silently.
$script:DiscogsCompilationPenalty = 0.10

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
    $editionWordPattern = '(?i)\b(special|deluxe|limited|expanded|anniversary|remaster(?:ed)?|bonus)\b'

    # EditionHints (used by Get-ReshelfDiscogsVersionRank to prefer a matching pressing among a
    # master's versions) - the noise words/groups this same function strips out of the search
    # title, kept instead of discarded, since they're exactly what tells one pressing/edition of a
    # master apart from another (e.g. a folder named "... Special Edition" should prefer a version
    # whose own title/format says "Special Edition" too).
    $editionHints = [System.Collections.Generic.List[string]]::new()

    $yearHint = $null
    foreach ($groupMatch in [regex]::Matches($trimmedRaw, $groupPattern)) {
        if (-not $yearHint -and $groupMatch.Value -match '(19|20)\d{2}') {
            $yearHint = [int]$Matches[0]
        }
        $inner = $groupMatch.Value.Trim().Trim('(', ')', '[', ']').Trim()
        if ($inner -and $inner -notmatch '^(19|20)\d{2}$') { $editionHints.Add($inner) }
    }
    foreach ($wordMatch in [regex]::Matches($trimmedRaw, $editionWordPattern)) {
        $editionHints.Add($wordMatch.Value)
    }

    $cleaned = [regex]::Replace($trimmedRaw, $groupPattern, '')
    $cleaned = [regex]::Replace($cleaned, '\s*[-–—]\s*$', '')
    $cleaned = [regex]::Replace($cleaned, "\s+$editionWordPattern\s*(edition)?\s*`$", '')
    $cleaned = [regex]::Replace($cleaned, '\s+', ' ').Trim()

    $titles = [System.Collections.Generic.List[string]]::new()
    $titles.Add($trimmedRaw)
    if ($cleaned -and $cleaned -ne $trimmedRaw) { $titles.Add($cleaned) }

    return [pscustomobject]@{ Titles = @($titles); YearHint = $yearHint; EditionHints = @($editionHints | Select-Object -Unique) }
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

function Get-ReshelfDiscogsTitleForms {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
    )

    # A title can carry a subtitle Discogs adds but a source folder never has ("Son De Mar" vs
    # "Son De Mar (Music From The Film By Bigas Luna)") - matching only the normalized raw text
    # missed that real case (plan/12) and left it "ambiguous" even though the release plainly
    # exists. Three forms are compared instead: raw normalized, with any parenthetical/bracketed
    # group stripped, and "compact" (no spaces at all - catches "Red Light" vs "Redlight").
    $normalized = ConvertTo-ReshelfNormalizedText -Text $Text
    $stripped = [regex]::Replace($Text, '\s*[\(\[][^\)\]]*[\)\]]', '')
    $strippedNormalized = ConvertTo-ReshelfNormalizedText -Text $stripped
    $compact = $normalized -replace '\s', ''

    return @($normalized, $strippedNormalized, $compact) | Select-Object -Unique
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
    $normalizedCandidateArtist = ConvertTo-ReshelfNormalizedText -Text $candidateArtist

    $artistScore = Get-ReshelfStringSimilarity -A $normalizedExpectedArtist -B $normalizedCandidateArtist

    $expectedTitleForms = Get-ReshelfDiscogsTitleForms -Text $ExpectedTitle
    $candidateTitleForms = Get-ReshelfDiscogsTitleForms -Text $candidateTitle
    $titleScore = 0.0
    foreach ($expectedForm in $expectedTitleForms) {
        foreach ($candidateForm in $candidateTitleForms) {
            $formScore = Get-ReshelfStringSimilarity -A $expectedForm -B $candidateForm
            if ($formScore -gt $titleScore) { $titleScore = $formScore }
        }
    }

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
    if ((@($Candidate.format) -join ', ') -match '(?i)\b(compilation|box set|unofficial release)\b') {
        $score -= $script:DiscogsCompilationPenalty
    }
    if ($score -lt 0) { $score = 0.0 }
    if ($score -gt 1) { $score = 1.0 }
    return $score
}

function Get-ReshelfDiscogsPlayableTracks {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [AllowNull()]
        [object[]]$Tracklist
    )

    # A Discogs tracklist entry can be a heading (no position, no audio - skipped), a plain track
    # (kept as-is, even one with its own sub_tracks like "3a"/"3b" - those stay one entry), or an
    # "index" entry that groups several real tracks under one heading with position '' and its own
    # count in sub_tracks (real case, plan/12: Guapo "Five Suns" has one index entry covering 5
    # movements plus 3 plain tracks after it - the plain position filter alone saw only 3 tracks
    # where the source rip has 8).
    $result = [System.Collections.Generic.List[object]]::new()
    foreach ($entry in @($Tracklist)) {
        if (-not $entry) { continue }

        if ([string]$entry.type_ -eq 'index' -and $entry.sub_tracks -and @($entry.sub_tracks).Count -gt 0) {
            foreach ($sub in @($entry.sub_tracks)) {
                if (-not $sub.position -or $sub.position.Trim() -eq '') { continue }
                # Discogs puts a per-track credit on the index entry when all its movements share
                # it - a copy (not the cached object) gets it so the sub-track still carries its artist.
                # (An empty array is falsy in PowerShell's boolean context, same as $null/missing, so
                # this also covers a sub-track whose own 'artists' happens to be an explicit @().)
                if (-not $sub.artists -and @($entry.artists).Count -gt 0) {
                    $sub = $sub | Select-Object *
                    $sub | Add-Member -NotePropertyName artists -NotePropertyValue @($entry.artists) -Force
                }
                $result.Add($sub)
            }
            continue
        }

        if ([string]$entry.type_ -eq 'heading') { continue }
        if (-not $entry.position -or $entry.position.Trim() -eq '') { continue }
        $result.Add($entry)
    }

    return @($result)
}

function Get-ReshelfDiscogsArtistCredit {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [object[]]$Artists
    )

    # Builds the Artist tag text from a Discogs artists[] array (release-level or per-track), e.g.
    # [{name:'A', join:'&'}, {name:'B (2)'}] -> 'A & B'. `name` (not `anv`) is used, the same as the
    # release artist. A feat. join ends the credit - per manifesto section 5 a featured artist never
    # goes into Artist, only into the title.
    $parts = [System.Collections.Generic.List[string]]::new()
    $pendingJoin = $null
    foreach ($artist in @($Artists)) {
        if (-not $artist) { continue }
        $name = Remove-ReshelfInvisibleCharacters -Text (([string]$artist.name).Trim() -replace '\s+\(\d+\)$', '')
        if ([string]::IsNullOrWhiteSpace($name)) { continue }

        if ($parts.Count -gt 0) {
            if ($pendingJoin -eq ',') { $parts.Add(', ') }
            elseif ($pendingJoin) { $parts.Add(" $pendingJoin ") }
            else { $parts.Add(', ') }
        }
        $parts.Add($name)

        $pendingJoin = ([string]$artist.join).Trim()
        if ($pendingJoin -match '^(feat\.?|ft\.?|featuring)$') { break }
    }

    if ($parts.Count -eq 0) { return $null }
    return ($parts -join '')
}

function Test-ReshelfIsCompilationArtist {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [object]$Match,

        [AllowEmptyString()]
        [string]$ArtistName
    )

    # A Various-Artists compilation only - Discogs files those under its "Various" artist (id 194).
    # The format word "Compilation" is not used: a single-artist "Greatest Hits" also has it.
    if ($Match.Status -eq 'matched') {
        $first = @($Match.Detail.artists)[0]
        if (-not $first) { return $false }
        return ([int]$first.id -eq 194) -or (([string]$first.name).Trim() -eq 'Various')
    }

    return ([string]$ArtistName).Trim() -in @('Various', 'Various Artists')
}

function Get-ReshelfVariousArtistsEvidence {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Tracks,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$FolderArtistName
    )

    # Real case (session 2026-10-03-0001): "DIO\1999 - Holy Dio" is a tribute album - 18 tracks by
    # 18 different bands, none of them DIO - that Discogs files under "Various", so a search with
    # the folder artist finds nothing. The tracks' own artists are the evidence a human uses: the
    # existing Artist tag first, then the "Artist - Title" part of the file name - the latter only
    # when EVERY track has one, since a single-artist title can have a dash too ("Song - Live").
    $fileNameInfos = @($Tracks | ForEach-Object { ConvertFrom-ReshelfTrackFileName -FileName ([string]$_.originalFileName) })
    $useFileNames = ($fileNameInfos.Count -gt 0) -and (@($fileNameInfos | Where-Object { -not $_.ArtistPart }).Count -eq 0)

    $trackArtists = [string[]]::new($Tracks.Count)
    $fileNameArtists = [string[]]::new($Tracks.Count)
    for ($i = 0; $i -lt $Tracks.Count; $i++) {
        if ($useFileNames) { $fileNameArtists[$i] = $fileNameInfos[$i].ArtistPart }
        $tagArtist = [string]$Tracks[$i].existingTags.artist
        $trackArtists[$i] = if (-not [string]::IsNullOrWhiteSpace($tagArtist)) { $tagArtist.Trim() } else { $fileNameArtists[$i] }
    }

    # A featured guest is not a different performer ("Metallica feat. X" is still Metallica), so
    # the feat. part is cut before comparing.
    $normalize = {
        param([string]$Name)
        $mainName = [regex]::Split($Name, '(?i)\s+(?:feat\.?|ft\.?|featuring)\s+')[0]
        ConvertTo-ReshelfNormalizedText -Text $mainName
    }
    $normalizedFolderArtist = & $normalize $FolderArtistName
    $normalizedArtists = @($trackArtists | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { & $normalize $_ } | Where-Object { $_ })

    $distinctCount = @($normalizedArtists | Select-Object -Unique).Count
    $differingCount = @($normalizedArtists | Where-Object { $_ -ne $normalizedFolderArtist }).Count
    $trackCount = $Tracks.Count

    $looksLikeVarious = ($trackCount -ge 3) -and ($distinctCount -ge 3) -and ($differingCount -gt ($trackCount / 2)) -and
    (([string]$FolderArtistName).Trim() -notin @('Various', 'Various Artists'))

    return [pscustomobject]@{
        LooksLikeVarious    = $looksLikeVarious
        DistinctArtistCount = $distinctCount
        DifferingTrackCount = $differingCount
        TrackCount          = $trackCount
        TrackArtists        = $trackArtists
        FileNameArtists     = $fileNameArtists
    }
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

function Get-ReshelfDiscogsVersionRank {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [object]$Version,

        [Nullable[int]]$FolderYear,

        [string[]]$EditionHints = @()
    )

    # A sort key for one entry of /masters/{id}/versions, used to pick which concrete pressing of
    # a master best matches the source rip when the track count alone doesn't decide it (real case,
    # plan/12: Koenjihyakkei "Angherr Shisspa" ties 5 versions on title/artist/year score - without
    # this, search-result order alone picked a 2019 reissue with no cover image over the 2005
    # original). Lower-priority fields only break ties left by the ones before them.
    $releasedYear = $null
    if ($Version.released -and ([string]$Version.released) -match '(19|20)\d{2}') {
        try { $releasedYear = [int]$Matches[0] } catch { $releasedYear = $null }
    }
    $yearMatch = ($null -ne $FolderYear -and $null -ne $releasedYear -and $FolderYear -eq $releasedYear)

    $versionText = "$($Version.format) $($Version.title)"
    $editionMatch = $false
    foreach ($hint in $EditionHints) {
        if ($hint -and $versionText -match [regex]::Escape($hint)) { $editionMatch = $true; break }
    }

    # Real case (AC-DC "T.N.T.", master 8648): an 8-Track Cartridge version has the same track
    # count as the source but a physically different track order (tapes split "programs" to
    # balance side lengths) - it must rank below the common formats, not above them. CD/File is
    # the best match for a digital rip; Vinyl/Cassette is the next most common and reliable; every
    # other, rarer format (8-Track Cartridge, Reel-To-Reel, MiniDisc, SACD, ...) is more likely to
    # have a nonstandard tracklist and so ranks last.
    $majorFormats = @($Version.major_formats)
    $formatRank = if ($majorFormats -contains 'CD' -or $majorFormats -contains 'File') { 0 }
    elseif ($majorFormats -contains 'Vinyl' -or $majorFormats -contains 'Cassette') { 1 }
    else { 2 }

    $unwantedRank = if ([string]$Version.format -match '(?i)\b(promo|test pressing|unofficial|acetate)\b') { 1 } else { 0 }

    $inCollection = 0
    if ($Version.stats -and $Version.stats.community -and $Version.stats.community.in_collection) {
        try { $inCollection = [int]$Version.stats.community.in_collection } catch { $inCollection = 0 }
    }

    return [pscustomobject]@{
        YearMatch    = $yearMatch
        EditionMatch = $editionMatch
        FormatRank   = $formatRank
        UnwantedRank = $unwantedRank
        InCollection = $inCollection
    }
}

function Sort-ReshelfDiscogsVersions {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Versions,

        [Nullable[int]]$FolderYear,

        [string[]]$EditionHints = @()
    )

    $ranked = @($Versions | ForEach-Object {
            [pscustomobject]@{ Version = $_; Rank = Get-ReshelfDiscogsVersionRank -Version $_ -FolderYear $FolderYear -EditionHints $EditionHints }
        })

    $sorted = $ranked | Sort-Object -Property `
        @{ Expression = { -not $_.Rank.YearMatch } }, `
        @{ Expression = { -not $_.Rank.EditionMatch } }, `
        @{ Expression = { $_.Rank.UnwantedRank } }, `
        @{ Expression = { $_.Rank.FormatRank } }, `
        @{ Expression = { $_.Rank.InCollection }; Descending = $true }

    return @($sorted | ForEach-Object { $_.Version })
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
        $trackCount = @(Get-ReshelfDiscogsPlayableTracks -Tracklist $detail.tracklist).Count
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

function Get-ReshelfScoredDiscogsCandidates {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Results,

        [Parameter(Mandatory)]
        [object]$Variants,

        [Parameter(Mandatory)]
        [string]$ArtistName,

        [Nullable[int]]$Year
    )

    # Shared by the master search, the artist-master-list fallback, and the release search - all
    # three score a raw Discogs search result the same way and shape it into the same candidate
    # record the UI's radio picker already renders (releaseId/title/year/format/score unchanged).
    return @(foreach ($result in $Results) {
            # Scored against every title variant, not just the one that happened to return
            # results, and the best score kept - a candidate can score well against the raw
            # title even when only the cleaned variant's search actually found it (or vice versa).
            $score = ($Variants.Titles | ForEach-Object {
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
}

function Get-ReshelfMasterVersionCandidates {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Versions,

        [Parameter(Mandatory)]
        [string]$ArtistName,

        [Parameter(Mandatory)]
        [double]$Score,

        [int]$Limit = 5
    )

    # Every version of the same master already scored as a match against artist/title (that's why
    # a master was picked at all) - so the same master score is reused for each version instead of
    # rescoring it, and the list is only as long as the UI's radio picker shows (5).
    return @($Versions | Select-Object -First $Limit | ForEach-Object {
            $releasedYear = $null
            if ($_.released -and ([string]$_.released) -match '(19|20)\d{2}') {
                try { $releasedYear = [int]$Matches[0] } catch { $releasedYear = $null }
            }
            $majorFormats = (@($_.major_formats) -join ', ')
            $formatText = if ($majorFormats) { "$majorFormats, $($_.format)" } else { [string]$_.format }
            if (-not $formatText) { $formatText = 'Unknown' }
            $titleText = "$ArtistName - $($_.title)"

            [pscustomobject]@{
                releaseId = [int]$_.id
                title     = $titleText
                year      = $releasedYear
                format    = $formatText
                score     = [Math]::Round($Score, 4)
            }
        })
}

function Select-ReshelfDiscogsMasterVersion {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [int]$MasterId,

        [int]$SourceTrackCount = 0,

        [Nullable[int]]$FolderYear,

        [string[]]$EditionHints = @(),

        [string]$DataHome,

        [int]$CacheTtlDays = 30,

        [int]$RateLimitPerMinute = 55
    )

    $master = Invoke-DiscogsRequest -Path "/masters/$MasterId" -CacheTtlDays $CacheTtlDays -RateLimitPerMinute $RateLimitPerMinute -DataHome $DataHome
    $versionsResult = Invoke-DiscogsRequest -Path "/masters/$MasterId/versions" -Query @{ per_page = '100' } -CacheTtlDays $CacheTtlDays -RateLimitPerMinute $RateLimitPerMinute -DataHome $DataHome
    $versions = @($versionsResult.versions)
    $hasEditionHints = (@($EditionHints | Where-Object { $_ }).Count -gt 0)

    $mainReleaseId = 0
    if ($master.main_release) { try { $mainReleaseId = [int]$master.main_release } catch { $mainReleaseId = 0 } }

    $chosenId = 0
    $chosenDetail = $null

    # The master's main_release is trusted outright when the source's own track count agrees and
    # there's no edition-name hint pointing at a different pressing - this is the common case (most
    # releases only have one edition anyone actually ripped) and saves probing every version.
    if ($mainReleaseId -gt 0) {
        $mainDetail = Invoke-DiscogsRequest -Path "/releases/$mainReleaseId" -CacheTtlDays $CacheTtlDays -RateLimitPerMinute $RateLimitPerMinute -DataHome $DataHome
        $mainTrackCount = @(Get-ReshelfDiscogsPlayableTracks -Tracklist $mainDetail.tracklist).Count
        if ($SourceTrackCount -le 0 -or (-not $hasEditionHints -and $mainTrackCount -eq $SourceTrackCount)) {
            $chosenId = $mainReleaseId
            $chosenDetail = $mainDetail
        }
    }

    if (-not $chosenDetail) {
        $sortedVersions = Sort-ReshelfDiscogsVersions -Versions $versions -FolderYear $FolderYear -EditionHints $EditionHints
        # Bounded to 8 (wider than the release-search probe, since a master can have many more
        # pressings than a plain search returns) - each fetch is cached.
        $probeLimit = [Math]::Min(8, $sortedVersions.Count)
        for ($i = 0; $i -lt $probeLimit; $i++) {
            $versionId = [int]$sortedVersions[$i].id
            $detail = if ($versionId -eq $mainReleaseId -and $mainDetail) { $mainDetail }
            else { Invoke-DiscogsRequest -Path "/releases/$versionId" -CacheTtlDays $CacheTtlDays -RateLimitPerMinute $RateLimitPerMinute -DataHome $DataHome }
            $trackCount = @(Get-ReshelfDiscogsPlayableTracks -Tracklist $detail.tracklist).Count
            if ($SourceTrackCount -le 0 -or $trackCount -eq $SourceTrackCount) {
                $chosenId = $versionId
                $chosenDetail = $detail
                break
            }
        }

        if (-not $chosenDetail) {
            # No probed version has the source's exact count - fall back to the main release (the
            # caller's own track-count mismatch note/alignment then applies), or the best-ranked
            # version when there isn't even a main release.
            if ($mainDetail) {
                $chosenId = $mainReleaseId
                $chosenDetail = $mainDetail
            }
            elseif ($sortedVersions.Count -gt 0) {
                $chosenId = [int]$sortedVersions[0].id
                $chosenDetail = Invoke-DiscogsRequest -Path "/releases/$chosenId" -CacheTtlDays $CacheTtlDays -RateLimitPerMinute $RateLimitPerMinute -DataHome $DataHome
            }
        }
    }

    # Source rips are digital files, so a CD/File pressing with the same track count as the chosen
    # Vinyl/Cassette edition is a closer match to what's actually on disk (real case, plan/12:
    # OOIOO "Feather Float" master's main_release is a vinyl edition).
    if ($chosenDetail) {
        $chosenMajorFormats = @($chosenDetail.formats | ForEach-Object { $_.name })
        if ($chosenMajorFormats -contains 'Vinyl' -or $chosenMajorFormats -contains 'Cassette') {
            $chosenTrackCount = @(Get-ReshelfDiscogsPlayableTracks -Tracklist $chosenDetail.tracklist).Count
            $cdCandidates = @($versions | Where-Object { [int]$_.id -ne $chosenId -and (@($_.major_formats) -contains 'CD' -or @($_.major_formats) -contains 'File') })
            $sortedCd = Sort-ReshelfDiscogsVersions -Versions $cdCandidates -FolderYear $FolderYear -EditionHints $EditionHints
            $cdProbeLimit = [Math]::Min(3, $sortedCd.Count)
            for ($i = 0; $i -lt $cdProbeLimit; $i++) {
                $cdVersionId = [int]$sortedCd[$i].id
                $cdDetail = Invoke-DiscogsRequest -Path "/releases/$cdVersionId" -CacheTtlDays $CacheTtlDays -RateLimitPerMinute $RateLimitPerMinute -DataHome $DataHome
                $cdTrackCount = @(Get-ReshelfDiscogsPlayableTracks -Tracklist $cdDetail.tracklist).Count
                if ($cdTrackCount -eq $chosenTrackCount) {
                    $chosenId = $cdVersionId
                    $chosenDetail = $cdDetail
                    break
                }
            }
        }
    }

    return [pscustomobject]@{ ReleaseId = $chosenId; Detail = $chosenDetail; Master = $master; Versions = $versions }
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

        # --- Step 1a: master search - Discogs groups every pressing of a release under one master,
        # so searching type=master first (rather than type=release) finds the right work even when
        # every individual release is a tie on title/artist/year score (real case, plan/12:
        # Koenjihyakkei "Angherr Shisspa" has 5 same-scoring release editions with no reason from
        # search order alone to prefer one; its master lets version ranking below decide instead). ---
        $masterResults = [System.Collections.Generic.List[object]]::new()
        foreach ($variantTitle in $variants.Titles) {
            foreach ($attemptYear in $yearAttempts) {
                $query = Get-ReshelfDiscogsSearchQuery -ArtistName $ArtistName -Title $variantTitle -Year $attemptYear
                $query['type'] = 'master'
                $searchResult = Invoke-DiscogsRequest -Path '/database/search' -Query $query -CacheTtlDays $CacheTtlDays -RateLimitPerMinute $RateLimitPerMinute -DataHome $DataHome
                $masterResults.AddRange([object[]]@($searchResult.results | Where-Object { $_.type -eq 'master' }))
            }
        }
        $masterResults = @($masterResults | Sort-Object -Property id -Unique)
        $scoredMasters = Get-ReshelfScoredDiscogsCandidates -Results $masterResults -Variants $variants -ArtistName $ArtistName -Year $Year
        $eligibleMasters = @($scoredMasters | Where-Object { $_.score -ge $script:DiscogsMatchThreshold })

        # --- Step 1b: artist master list - a Discogs release_title search can fail outright on a
        # title Discogs itself spells differently (real case: "Redlight" vs a folder named "Red
        # Light" returns zero release_title results either way) - listing every master credited to
        # the artist and scoring locally still finds it. Only tried when 1a found nothing eligible,
        # and skipped outright for "Various"/"Various Artists" - that artist's master list runs into
        # the thousands and sorts nothing like a real artist's, so paging through it would only waste
        # rate-limited calls on a release this step was never going to find. ---
        $isVariousArtistSearch = ([string]$ArtistName).Trim() -in @('Various', 'Various Artists')
        if ($eligibleMasters.Count -eq 0 -and -not $isVariousArtistSearch) {
            $artistMasters = [System.Collections.Generic.List[object]]::new()
            for ($page = 1; $page -le 3; $page++) {
                $query = @{ type = 'master'; artist = $ArtistName; per_page = '100'; page = "$page" }
                $searchResult = Invoke-DiscogsRequest -Path '/database/search' -Query $query -CacheTtlDays $CacheTtlDays -RateLimitPerMinute $RateLimitPerMinute -DataHome $DataHome
                $pageResults = @($searchResult.results | Where-Object { $_.type -eq 'master' })
                if ($pageResults.Count -eq 0) { break }
                $artistMasters.AddRange([object[]]$pageResults)
                if ($pageResults.Count -lt 100) { break }
            }
            if ($artistMasters.Count -gt 0) {
                $scoredArtistMasters = Get-ReshelfScoredDiscogsCandidates -Results @($artistMasters) -Variants $variants -ArtistName $ArtistName -Year $Year
                $eligibleFromArtistList = @($scoredArtistMasters | Where-Object { $_.score -ge $script:DiscogsMatchThreshold })
                if ($eligibleFromArtistList.Count -gt 0) {
                    $scoredMasters = $scoredArtistMasters
                    $eligibleMasters = $eligibleFromArtistList
                }
            }
        }

        if ($eligibleMasters.Count -gt 0) {
            $bestMaster = @($eligibleMasters | Sort-Object -Property score -Descending)[0]
            $picked = Select-ReshelfDiscogsMasterVersion -MasterId $bestMaster.releaseId -SourceTrackCount $SourceTrackCount `
                -FolderYear $effectiveYear -EditionHints $variants.EditionHints -DataHome $DataHome -CacheTtlDays $CacheTtlDays -RateLimitPerMinute $RateLimitPerMinute

            return [pscustomobject]@{
                Status            = 'matched'
                SelectedReleaseId = $picked.ReleaseId
                Candidates        = Get-ReshelfMasterVersionCandidates -Versions $picked.Versions -ArtistName $ArtistName -Score $bestMaster.score
                Detail            = $picked.Detail
                MasterId          = $bestMaster.releaseId
                Master            = $picked.Master
                ErrorNote         = $null
            }
        }

        # --- Step 1c: release search - today's original behavior, used when no master (eligible or
        # not) was found at all. ---
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
            return [pscustomobject]@{ Status = 'not-found'; SelectedReleaseId = $null; Candidates = @(); Detail = $null; MasterId = $null; Master = $null; ErrorNote = $null }
        }

        $scoredReleases = Get-ReshelfScoredDiscogsCandidates -Results $releaseResults -Variants $variants -ArtistName $ArtistName -Year $Year
        $sortedReleases = @($scoredReleases | Sort-Object -Property score -Descending)
        $topCandidates = @($sortedReleases | Select-Object -First 5)
        $eligibleReleases = @($sortedReleases | Where-Object { $_.score -ge $script:DiscogsMatchThreshold })

        if ($eligibleReleases.Count -eq 0) {
            # Neither a master nor a plain release was eligible - the ambiguous candidate list
            # combines both, since a low-confidence master's main release is just as valid a
            # human-reviewed pick as a low-confidence plain release (real case, plan/12: an obscure
            # release can be missing from one search type but present, if unconfident, in the other).
            $masterCandidates = @(foreach ($scoredMaster in @($scoredMasters | Sort-Object -Property score -Descending | Select-Object -First 5)) {
                    try {
                        $masterDetail = Invoke-DiscogsRequest -Path "/masters/$($scoredMaster.releaseId)" -CacheTtlDays $CacheTtlDays -RateLimitPerMinute $RateLimitPerMinute -DataHome $DataHome
                        $mainId = 0
                        if ($masterDetail.main_release) { try { $mainId = [int]$masterDetail.main_release } catch { $mainId = 0 } }
                        if ($mainId -gt 0) {
                            [pscustomobject]@{ releaseId = $mainId; title = $scoredMaster.title; year = $scoredMaster.year; format = $scoredMaster.format; score = $scoredMaster.score }
                        }
                    }
                    catch {
                        Write-Verbose "Could not fetch master $($scoredMaster.releaseId) for ambiguous candidate list: $($_.Exception.Message)"
                    }
                })

            $combinedCandidates = @($masterCandidates + $topCandidates) | Sort-Object -Property score -Descending
            $uniqueCandidates = @($combinedCandidates | Group-Object -Property releaseId | ForEach-Object { $_.Group[0] } | Sort-Object -Property score -Descending | Select-Object -First 5)

            return [pscustomobject]@{
                Status            = 'ambiguous'
                SelectedReleaseId = $null
                Candidates        = $uniqueCandidates
                Detail            = $null
                MasterId          = $null
                Master            = $null
                ErrorNote         = $null
            }
        }

        $bestRelease = $eligibleReleases[0]
        $bestReleaseResult = $releaseResults | Where-Object { [int]$_.id -eq $bestRelease.releaseId } | Select-Object -First 1
        $bestMasterId = 0
        if ($bestReleaseResult -and $bestReleaseResult.master_id) { try { $bestMasterId = [int]$bestReleaseResult.master_id } catch { $bestMasterId = 0 } }

        if ($bestMasterId -gt 0) {
            $picked = Select-ReshelfDiscogsMasterVersion -MasterId $bestMasterId -SourceTrackCount $SourceTrackCount `
                -FolderYear $effectiveYear -EditionHints $variants.EditionHints -DataHome $DataHome -CacheTtlDays $CacheTtlDays -RateLimitPerMinute $RateLimitPerMinute

            return [pscustomobject]@{
                Status            = 'matched'
                SelectedReleaseId = $picked.ReleaseId
                Candidates        = Get-ReshelfMasterVersionCandidates -Versions $picked.Versions -ArtistName $ArtistName -Score $bestRelease.score
                Detail            = $picked.Detail
                MasterId          = $bestMasterId
                Master            = $picked.Master
                ErrorNote         = $null
            }
        }

        $picked = Select-ReshelfBestDiscogsCandidate -Eligible $eligibleReleases -SourceTrackCount $SourceTrackCount `
            -DataHome $DataHome -CacheTtlDays $CacheTtlDays -RateLimitPerMinute $RateLimitPerMinute

        return [pscustomobject]@{
            Status            = 'matched'
            SelectedReleaseId = $picked.ReleaseId
            Candidates        = $topCandidates
            Detail            = $picked.Detail
            MasterId          = $null
            Master            = $null
            ErrorNote         = $null
        }
    }
    catch {
        return [pscustomobject]@{
            Status            = 'not-found'
            SelectedReleaseId = $null
            Candidates        = @()
            Detail            = $null
            MasterId          = $null
            Master            = $null
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
        # The master's year is the release's original year (a master groups every pressing under
        # one original work) - preferred over the specific pressing's own year so a later reissue
        # (e.g. Koenjihyakkei "Angherr Shisspa", picked pressing from 2019) still tags/folders as
        # its true 2005 release year. Falls back to the pressing's year when there's no master, or
        # the master's year is unknown (Discogs represents that as 0, which is also falsy here).
        $yearRaw = if ($Match.Master -and $Match.Master.year) { $Match.Master.year } else { $Match.Detail.year }
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
        IsCompilation     = (Test-ReshelfIsCompilationArtist -Match $Match -ArtistName $ArtistName)
        UsedSentinelYear  = $usedSentinelYear
        Substitutions     = @($artistSan.Substitutions + $titleSan.Substitutions)
    }
}

function Get-ReshelfDiscogsTitleAlignment {
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
    $alignedIndices = [System.Collections.Generic.List[int]]::new()

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
            return [pscustomobject]@{ Aligned = $false; Tracks = @(); Indices = @(); MissingNote = $null }
        }

        [void]$usedDiscogsIndices.Add($bestIndex)
        $aligned.Add($DiscogsTracks[$bestIndex])
        $alignedIndices.Add($bestIndex + 1)
    }

    $missing = @(for ($i = 0; $i -lt $DiscogsTracks.Count; $i++) {
            if (-not $usedDiscogsIndices.Contains($i)) {
                "$($DiscogsTracks[$i].position) $($DiscogsTracks[$i].title)".Trim()
            }
        })
    $missingNote = if ($missing.Count -gt 0) { "missing on source: $($missing -join ', ')" } else { $null }

    return [pscustomobject]@{ Aligned = $true; Tracks = @($aligned); Indices = @($alignedIndices); MissingNote = $missingNote }
}

function Get-ReshelfDiscogsNumberAlignment {
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

    # Real case (plan/12): OOIOO "Feather Float" is missing one track (07 Asozan) and several of
    # its file names carry a differently-transliterated title ("(Kanji)") that title-similarity
    # alone never clears 0.8 for - but its file-derived track numbers still line up 1:1 with
    # Discogs position numbers for every track the source does have, so pairing by number succeeds
    # where pairing by title didn't. Deliberately narrow: single disc only, no inferred order (a
    # number this method trusts must have actually come from the file name), and no repeats.
    $singleDisc = (@($SourceTracks | Where-Object { $null -ne $_.discFolder }).Count -eq 0)
    $noInferredOrder = (@($SourceTracks | Where-Object { $_.inferredTrackOrder }).Count -eq 0)
    $numbers = @($SourceTracks | ForEach-Object { $_.detectedTrackNumberInDisc })
    $numbersInRange = (@($numbers | Where-Object { $null -eq $_ -or [int]$_ -lt 1 -or [int]$_ -gt $DiscogsTracks.Count }).Count -eq 0)
    $numbersUnique = $numbersInRange -and (@($numbers | Select-Object -Unique).Count -eq $numbers.Count)

    if (-not ($singleDisc -and $noInferredOrder -and $numbersUnique) -or $SourceTracks.Count -eq 0) {
        return [pscustomobject]@{ Aligned = $false; Tracks = @(); Indices = @(); MissingNote = $null }
    }

    $usedDiscogsIndices = [System.Collections.Generic.HashSet[int]]::new()
    $aligned = [System.Collections.Generic.List[object]]::new()
    $alignedIndices = [System.Collections.Generic.List[int]]::new()
    $matchingTitleCount = 0

    foreach ($sourceTrack in $SourceTracks) {
        $discogsIndex = [int]$sourceTrack.detectedTrackNumberInDisc - 1
        [void]$usedDiscogsIndices.Add($discogsIndex)
        $aligned.Add($DiscogsTracks[$discogsIndex])
        $alignedIndices.Add($discogsIndex + 1)

        $sourceTitle = if ($sourceTrack.existingTags.title) { $sourceTrack.existingTags.title } `
            else { (ConvertFrom-ReshelfTrackFileName -FileName $sourceTrack.originalFileName).Title }
        $titleScore = Get-ReshelfStringSimilarity -A (ConvertTo-ReshelfNormalizedText -Text $sourceTitle) `
            -B (ConvertTo-ReshelfNormalizedText -Text $DiscogsTracks[$discogsIndex].title)
        if ($titleScore -ge 0.8) { $matchingTitleCount++ }
    }

    # At least 2/3 of the number-paired tracks must still agree on title, or the numbers merely
    # happening to be in range would be trusted as a real alignment when they aren't one.
    if (($matchingTitleCount / $SourceTracks.Count) -lt (2.0 / 3.0)) {
        return [pscustomobject]@{ Aligned = $false; Tracks = @(); Indices = @(); MissingNote = $null }
    }

    $missing = @(for ($i = 0; $i -lt $DiscogsTracks.Count; $i++) {
            if (-not $usedDiscogsIndices.Contains($i)) {
                "$($DiscogsTracks[$i].position) $($DiscogsTracks[$i].title)".Trim()
            }
        })
    $missingNote = if ($missing.Count -gt 0) { "missing on source: $($missing -join ', ')" } else { $null }

    return [pscustomobject]@{ Aligned = $true; Tracks = @($aligned); Indices = @($alignedIndices); MissingNote = $missingNote }
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

    $titleAlignment = Get-ReshelfDiscogsTitleAlignment -SourceTracks $SourceTracks -DiscogsTracks $DiscogsTracks
    if ($titleAlignment.Aligned) {
        return [pscustomobject]@{
            Aligned = $true; Tracks = $titleAlignment.Tracks; Indices = $titleAlignment.Indices
            MissingNote = $titleAlignment.MissingNote; Method = 'title'
        }
    }

    $numberAlignment = Get-ReshelfDiscogsNumberAlignment -SourceTracks $SourceTracks -DiscogsTracks $DiscogsTracks
    if ($numberAlignment.Aligned) {
        return [pscustomobject]@{
            Aligned = $true; Tracks = $numberAlignment.Tracks; Indices = $numberAlignment.Indices
            MissingNote = $numberAlignment.MissingNote; Method = 'number'
        }
    }

    return [pscustomobject]@{ Aligned = $false; Tracks = @(); Indices = @(); MissingNote = $null; Method = $null }
}

function Get-ReshelfDiscogsPositionParts {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Position
    )

    $text = if ($Position) { $Position.Trim() } else { '' }
    if ($text -match '^(?:CD|DVD|Disc)?\s*(\d+)\s*[-.]\s*(\d+)$') {
        return [pscustomobject]@{ Disc = [int]$Matches[1]; Track = [int]$Matches[2] }
    }
    if ($text -match '^(\d+)$') {
        return [pscustomobject]@{ Disc = $null; Track = [int]$Matches[1] }
    }
    # Vinyl/cassette sides ("A1", "B2") and anything else carry no usable disc/track number.
    return [pscustomobject]@{ Disc = $null; Track = $null }
}

# --- Track naming and tagging ---------------------------------------------------

function New-ReshelfProposedTrackSet {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Tracks,

        # The FULL Discogs tracklist, not only the tracks the source has - a track's index in it is
        # its real position on the release, so a track missing from the source keeps its gap.
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$DiscogsTracks,

        # 1-based index into $DiscogsTracks for each entry of $Tracks (same order). Empty means
        # the two lists line up one-to-one.
        [int[]]$DiscogsIndices = @(),

        [Parameter(Mandatory)]
        [object]$Names,

        [Parameter(Mandatory)]
        [string]$TrackFileTemplate,

        [int]$TrackNumberPadWidth = 2,

        # Per-track artist parsed from each file name's "NN Artist - Title" shape (same order as
        # $Tracks), from Get-ReshelfVariousArtistsEvidence. Empty/omitted entries fall through to
        # the existing behavior unchanged.
        [string[]]$FileNameArtists = @()
    )

    $substitutions = [System.Collections.Generic.List[string]]::new()
    $notes = [System.Collections.Generic.List[string]]::new()

    # Group tracks by discFolder in first-seen order - a single-disc release has every track's
    # discFolder as $null, which naturally becomes one group (disc 1).
    $discOrder = [System.Collections.Generic.List[string]]::new()
    $discGroups = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[int]]]::new()
    for ($i = 0; $i -lt $Tracks.Count; $i++) {
        $key = if ($null -eq $Tracks[$i].discFolder) { '' } else { $Tracks[$i].discFolder }
        if (-not $discGroups.ContainsKey($key)) {
            $discOrder.Add($key)
            $discGroups[$key] = [System.Collections.Generic.List[int]]::new()
        }
        $discGroups[$key].Add($i)
    }

    $useDiscogs = ($DiscogsTracks.Count -gt 0 -and $Tracks.Count -gt 0)
    if ($useDiscogs -and $DiscogsIndices.Count -eq 0) { $DiscogsIndices = @(1..$Tracks.Count) }

    # Per manifesto sections 4.4/5 these are two different numbers: trackNumbers restart at 1 per
    # disc (the Track tag), fileNumbers keep counting across discs (the filename's NN). Both follow
    # the real release position, so a missing track leaves a gap in both instead of shifting the rest.
    $trackNumbers = [int[]]::new($Tracks.Count)
    $fileNumbers = [int[]]::new($Tracks.Count)
    $numbersResolved = $false

    if ($useDiscogs) {
        if ($discOrder.Count -le 1) {
            for ($i = 0; $i -lt $Tracks.Count; $i++) {
                $trackNumbers[$i] = $DiscogsIndices[$i]
                $fileNumbers[$i] = $DiscogsIndices[$i]
            }
            $numbersResolved = $true
        }
        else {
            $parts = @(for ($i = 0; $i -lt $Tracks.Count; $i++) {
                    Get-ReshelfDiscogsPositionParts -Position $DiscogsTracks[$DiscogsIndices[$i] - 1].position
                })
            if (@($parts | Where-Object { $null -eq $_.Disc -or $null -eq $_.Track }).Count -eq 0) {
                for ($i = 0; $i -lt $Tracks.Count; $i++) {
                    $trackNumbers[$i] = $parts[$i].Track
                    $fileNumbers[$i] = $DiscogsIndices[$i]
                }
                $numbersResolved = $true
            }
        }
    }

    if (-not $numbersResolved) {
        $offset = 0
        $discIndex = 0
        foreach ($discKey in $discOrder) {
            $discIndex++
            $indices = $discGroups[$discKey]
            $detected = @($indices | ForEach-Object { $Tracks[$_].detectedTrackNumberInDisc })
            $useDetected = (@($indices | Where-Object { $Tracks[$_].inferredTrackOrder }).Count -eq 0) -and
            (@($detected | Where-Object { $null -eq $_ -or [int]$_ -lt 1 }).Count -eq 0)
            if ($useDetected -and @($detected | Select-Object -Unique).Count -ne $detected.Count) {
                $useDetected = $false
                $notes.Add("track numbers from source file names are not unique on disc $discIndex; renumbered sequentially")
            }

            # Some rips number a later disc's files continuously ("CD2\11 - ...") instead of from 1 -
            # every number being above the running offset means that, so the offset is taken back out.
            $numberShift = 0
            if ($useDetected -and $offset -gt 0 -and ($detected | Measure-Object -Minimum).Minimum -gt $offset) {
                $numberShift = $offset
            }

            $position = 0
            foreach ($i in $indices) {
                $position++
                $trackNumbers[$i] = if ($useDetected) { [int]$Tracks[$i].detectedTrackNumberInDisc - $numberShift } else { $position }
                $fileNumbers[$i] = $offset + $trackNumbers[$i]
            }
            $offset += ($indices | ForEach-Object { $trackNumbers[$_] } | Measure-Object -Maximum).Maximum
        }
    }

    $highestFileNumber = if ($Tracks.Count -gt 0) { ($fileNumbers | Measure-Object -Maximum).Maximum } else { 0 }
    $padWidth = Get-ReshelfProposalPadWidth -TotalTrackCount $highestFileNumber -MinWidth $TrackNumberPadWidth

    $discIndex = 0
    $result = [System.Collections.Generic.List[object]]::new()

    foreach ($discKey in $discOrder) {
        $discIndex++
        foreach ($i in $discGroups[$discKey]) {
            $track = $Tracks[$i]
            $fileNameInfo = ConvertFrom-ReshelfTrackFileName -FileName $track.originalFileName
            $fileNameArtist = if ($i -lt $FileNameArtists.Count) { $FileNameArtists[$i] } else { $null }

            if ($useDiscogs) {
                $rawTitle = Remove-ReshelfInvisibleCharacters -Text $DiscogsTracks[$DiscogsIndices[$i] - 1].title
            }
            elseif ($track.existingTags.title) {
                $rawTitle = ConvertTo-ReshelfTitleCase -Text $track.existingTags.title
            }
            elseif ($Names.IsCompilation -and -not $track.existingTags.artist -and $fileNameArtist -and $fileNameInfo.TitlePart) {
                # A compilation track without any tags, numbered "NN Artist - Title": once the
                # Artist half is used below, the Title half is the right fallback title too
                # (not "Artist - Title" repeated into the Title tag).
                $rawTitle = ConvertTo-ReshelfTitleCase -Text $fileNameInfo.TitlePart
            }
            else {
                $rawTitle = ConvertTo-ReshelfTitleCase -Text $fileNameInfo.Title
            }

            $titleSan = ConvertTo-SafeFileName -Name $rawTitle -Context 'track file name'
            if ($titleSan.Substitutions.Count -gt 0) { $substitutions.AddRange([string[]]$titleSan.Substitutions) }

            $padded = $fileNumbers[$i].ToString('0' * $padWidth)
            $fileNameCore = Expand-ReshelfNamingTemplate -Template $TrackFileTemplate -Values @{ trackNumber = $padded; title = $titleSan.SafeName }
            $proposedFileName = "$fileNameCore.$($track.format)"

            # Per-track Artist: Discogs' own per-track credit wins when it has one (this covers any
            # release with per-track credits, not only "Various" ones - a split release keeps its
            # tracks' real artists too). Failing that, a compilation falls back to the file's own
            # existing Artist tag, then to the artist parsed from the file name ("NN Artist -
            # Title"), and only then to the release/Album Artist ("Various") plus a note that
            # forces human review, since silently mislabeling a compilation track is worse than
            # asking someone to look.
            $discogsCredit = $null
            if ($useDiscogs) {
                $discogsCredit = Get-ReshelfDiscogsArtistCredit -Artists @($DiscogsTracks[$DiscogsIndices[$i] - 1].artists)
            }
            if ($discogsCredit) {
                $trackArtist = $discogsCredit
            }
            elseif ($Names.IsCompilation -and $track.existingTags.artist) {
                $trackArtist = ConvertTo-ReshelfTitleCase -Text $track.existingTags.artist
            }
            elseif ($Names.IsCompilation -and $fileNameArtist) {
                $trackArtist = ConvertTo-ReshelfTitleCase -Text $fileNameArtist
            }
            elseif ($Names.IsCompilation) {
                $trackArtist = $Names.Artist
                $notes.Add("Track $($trackNumbers[$i]): no track artist from Discogs or file tags; Artist set to '$($Names.Artist)'.")
            }
            else {
                $trackArtist = $Names.Artist
            }

            $tags = [pscustomobject]@{
                artist        = $trackArtist
                albumArtist   = $Names.Artist
                album         = $Names.Album
                year          = $Names.Year
                discNumber    = $discIndex
                track         = $trackNumbers[$i]
                title         = $rawTitle
                isCompilation = [bool]$Names.IsCompilation
            }

            $extended = $track | Select-Object *
            $extended | Add-Member -NotePropertyName proposedFileName -NotePropertyValue $proposedFileName -Force
            $extended | Add-Member -NotePropertyName proposedDiscNumber -NotePropertyValue $discIndex -Force
            $extended | Add-Member -NotePropertyName proposedTrackNumber -NotePropertyValue $trackNumbers[$i] -Force
            $extended | Add-Member -NotePropertyName proposedTitle -NotePropertyValue $rawTitle -Force
            $extended | Add-Member -NotePropertyName tags -NotePropertyValue $tags -Force

            $result.Add($extended)
        }
    }

    return [pscustomobject]@{ Tracks = @($result); Substitutions = @($substitutions); Notes = @($notes) }
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
    elseif ($Match.Status -eq 'matched' -and $Match.Master -and $Match.Master.images -and @($Match.Master.images).Count -gt 0) {
        # The chosen pressing itself has no photos on Discogs (real case, plan/12: Grails "Burning
        # Off Impurities" picked a no-image "NO NUMBER" CD edition) - the master's own images (its
        # main release's cover) are a better default than nothing, since they're still the correct
        # release, just not necessarily this exact pressing's own photo.
        foreach ($image in @($Match.Master.images)) {
            $edition = if ($image.type -eq 'primary') { 'master (main release)' } else { 'master (main release) (alternate)' }
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

function Test-ReshelfSameLossyRelease {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$OldAlbum,

        [Parameter(Mandatory)]
        [string]$NewAlbum
    )

    # An exact normalized match is too strict for this: the whole reason a lossless re-import can
    # miss its own ledger row is that the two album *names* genuinely differ (e.g. an older lossy
    # import's messy folder-derived name "Forwards Special Edition" vs. a later lossless import's
    # Discogs-matched "Forwards") - the same noise Get-ReshelfDiscogsSearchTitleVariants already
    # models for search, reused here instead of inventing a second, separate fuzzy-match heuristic.
    $oldVariants = @((Get-ReshelfDiscogsSearchTitleVariants -Title $OldAlbum).Titles | ForEach-Object { ConvertTo-ReshelfNormalizedText -Text $_ })
    $newVariants = @((Get-ReshelfDiscogsSearchTitleVariants -Title $NewAlbum).Titles | ForEach-Object { ConvertTo-ReshelfNormalizedText -Text $_ })

    foreach ($oldVariant in $oldVariants) {
        if ($newVariants -contains $oldVariant) { return $true }
    }
    return $false
}

function Find-ReshelfPreviousLossyEntry {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$StableKey,

        [Parameter(Mandatory)]
        [string]$Artist,

        [Parameter(Mandatory)]
        [string]$Album,

        [Parameter(Mandatory)]
        [int]$Year,

        [string]$DataHome
    )

    $entry = Get-ReshelfLossyTrackingEntry -StableKey $StableKey -DataHome $DataHome

    if (-not $entry -or $entry.status -ne 'pending-upgrade') {
        # A lossless re-import can land under a different stableKey than the lossy import the
        # ledger already knows about - stableKey is derived from *this run's* recognized/proposed
        # names, and a source folder renamed between imports (real case: "Forwards Special Edition"
        # vs. Discogs's own "Forwards") changes it. Fall back to a normalized artist|album|year
        # match against every still-pending ledger row before concluding there's nothing to warn
        # about.
        $normalizedArtist = ConvertTo-ReshelfNormalizedText -Text $Artist
        $entry = Get-ReshelfLossyTrackingLedger -DataHome $DataHome | Where-Object {
            $_.status -eq 'pending-upgrade' -and $_.year -eq $Year -and
            (ConvertTo-ReshelfNormalizedText -Text $_.artist) -eq $normalizedArtist -and
            (Test-ReshelfSameLossyRelease -OldAlbum $_.album -NewAlbum $Album)
        } | Select-Object -First 1
    }

    if (-not $entry) { return $null }

    $targetExists = (Test-Path -LiteralPath $entry.targetPath -PathType Container) -and `
        (@(Get-ReshelfAudioFilesInFolder -Path $entry.targetPath -Recurse).Count -gt 0)

    return [pscustomobject]@{
        TargetPath       = $entry.targetPath
        Format           = $entry.format
        FirstDetectedUtc = $entry.firstDetectedUtc
        TargetExists     = $targetExists
    }
}

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
        $applyLogEntryValid = Test-ReshelfAppliedEntryValid -Entry $applyLogEntry -TargetRoot $TargetRoot
        if ($applyLogEntryValid -and ($applyLogEntry.sourceFileSetHash -eq $sourceHash)) {
            $appliedEntryMatchesSource = $true
        }

        # The existing target folder is looked up strongest link first. $TargetIndex alone isn't
        # enough for the same reason as above: it keys a folder by its *target* name, while
        # $StableKey comes from the *source* folder's names - they differ whenever Discogs corrected
        # them (real case, plan/12 milestone 7: source "PULSAR OLYMP - 94Shine" vs. target
        # "Pulsar Olymp\2015 94 Shine"), which hid an existing lossy folder and broke the upgrade.
        $existingPath = $null
        if ($applyLogEntryValid) {
            $existingPath = $applyLogEntry.targetPath
        }
        elseif ((Test-Path -LiteralPath $ProposedTargetPath -PathType Container) -and `
                @(Get-ReshelfAudioFilesInFolder -Path $ProposedTargetPath -Recurse).Count -gt 0) {
            $existingPath = $ProposedTargetPath
        }
        else {
            $indexEntry = Test-ReshelfTargetReleaseExists -TargetIndex $TargetIndex -StableKey $StableKey
            if ($indexEntry) { $existingPath = $indexEntry.Path }
        }

        if ($existingPath) {
            $targetFiles = @(Get-ReshelfAudioFilesInFolder -Path $existingPath -Recurse)
            $targetHash = Get-ReshelfFileSetHash -FilePaths $targetFiles.FullName
            $targetIsLossless = $targetFiles.Count -gt 0
            foreach ($file in $targetFiles) {
                if (-not (Test-ReshelfIsLosslessFormat -Extension $file.Extension)) {
                    $targetIsLossless = $false
                    break
                }
            }
            $baseline = [pscustomobject]@{ Hash = $targetHash; IsLossless = $targetIsLossless; Path = $existingPath }
        }
    }

    # Only worth asking when there's otherwise nothing at this stableKey (the direct
    # stableKey-matched path below - update-existing/skip-existing-identical/conflict - already
    # covers a real upgrade at the *same* location) and the source itself is lossless (a lossy
    # release re-imported under a new name isn't "the upgrade" of anything).
    $previousLossyInfo = $null
    if ($sourceIsLossless -and $null -eq $baseline -and -not $appliedEntryMatchesSource) {
        $previousLossyInfo = Find-ReshelfPreviousLossyEntry -StableKey $StableKey -Artist $Names.Artist -Album $Names.Album `
            -Year $Names.Year -DataHome $DataHome
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
    elseif ($sourceIsLossless -and -not $baseline.IsLossless -and $baseline.Path -and
        -not [string]::Equals($baseline.Path.TrimEnd('\', '/'), $ProposedTargetPath.TrimEnd('\', '/'), [System.StringComparison]::OrdinalIgnoreCase)) {
        # The lossy copy lives under an older name (e.g. edited in the UI before its apply) - apply
        # replaces only the *proposed* path, so it would leave that folder behind. Same "keep both,
        # only warn" rule as a ledger match found by name (plan/09).
        $targetAction = 'create-new'
        $previousLossyInfo = Find-ReshelfPreviousLossyEntry -StableKey $StableKey -Artist $Names.Artist -Album $Names.Album `
            -Year $Names.Year -DataHome $DataHome
        if (-not $previousLossyInfo -or -not [string]::Equals($previousLossyInfo.TargetPath, $baseline.Path, [System.StringComparison]::OrdinalIgnoreCase)) {
            $firstFile = @(Get-ReshelfAudioFilesInFolder -Path $baseline.Path -Recurse) | Select-Object -First 1
            $previousLossyInfo = [pscustomobject]@{
                TargetPath       = $baseline.Path
                Format           = if ($firstFile) { $firstFile.Extension.TrimStart('.').ToLowerInvariant() } else { 'unknown' }
                FirstDetectedUtc = (Get-Item -LiteralPath $baseline.Path).CreationTimeUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
                TargetExists     = $true
            }
        }
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
    elseif ($previousLossyInfo) {
        # "Keep both, only warn" (see plan/09): the old lossy copy sits at a different path than
        # this run's own proposed target, so apply must never touch or delete it automatically -
        # only surface it for the user to reconcile by hand.
        $action = if ($previousLossyInfo.TargetExists) { 'previously-lossy-different-location' } else { 'previously-lossy-target-missing' }
        $lossyLossless = [pscustomobject]@{
            isLossy       = $false
            action        = $action
            previousLossy = [pscustomobject]@{
                targetPath       = $previousLossyInfo.TargetPath
                format           = $previousLossyInfo.Format
                firstDetectedUtc = $previousLossyInfo.FirstDetectedUtc
                targetExists     = $previousLossyInfo.TargetExists
            }
        }
        $previousLossyNote = if ($previousLossyInfo.TargetExists) {
            "Previously imported as $($previousLossyInfo.Format) at '$($previousLossyInfo.TargetPath)' (first seen $($previousLossyInfo.FirstDetectedUtc)) - that folder still exists and will be kept as-is; remove it yourself if you don't want both."
        }
        else {
            "You previously had this release as $($previousLossyInfo.Format) at '$($previousLossyInfo.TargetPath)' (first seen $($previousLossyInfo.FirstDetectedUtc)) - that folder is not in the target now, so keep this in mind when managing your real collection."
        }
        $forcedReviewNote = if ($forcedReviewNote) { "$forcedReviewNote; $previousLossyNote" } else { $previousLossyNote }
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

    # Real case (session 2026-10-03-0001, "DIO\1999 - Holy Dio"): a Various-Artists release filed
    # under its tracks' shared folder (not under "Various") never matches on that folder's own
    # name - Discogs files it under "Various" instead. The tracks themselves are the evidence a
    # human would use, so when the folder-artist search comes back empty/ambiguous AND most tracks
    # clearly have a different artist each, "Various" is tried too before giving up.
    $effectiveArtistName = $ArtistName
    $vaEvidence = Get-ReshelfVariousArtistsEvidence -Tracks $Release.tracks -FolderArtistName $ArtistName
    $usedVariousArtistsFallback = $false
    if ($match.Status -ne 'matched' -and $vaEvidence.LooksLikeVarious) {
        $variousMatch = Resolve-ReshelfDiscogsMatch -ArtistName 'Various' -Title $Release.recognizedTitle -Year $Release.recognizedYear `
            -SourceTrackCount $Release.tracks.Count -DataHome $DataHome -CacheTtlDays $CacheTtlDays -RateLimitPerMinute $RateLimitPerMinute
        $match = $variousMatch
        $effectiveArtistName = 'Various'
        $usedVariousArtistsFallback = $true
    }

    if ($match.ErrorNote) {
        $notes.Add($match.ErrorNote)
        $requiresReview = $true
    }
    if ($match.Status -ne 'matched') {
        $requiresReview = $true
        $notes.Add("Discogs match status: $($match.Status)")
    }
    if ($usedVariousArtistsFallback) {
        $requiresReview = $true
        $notes.Add("Tracks have $($vaEvidence.DistinctArtistCount) different artists (none is '$ArtistName'); proposed as Various Artists compilation.")
    }

    $names = New-ReshelfProposedReleaseNames -ArtistName $effectiveArtistName -Release $Release -Match $match -ReleaseFolderTemplate $ReleaseFolderTemplate
    if ($names.Substitutions.Count -gt 0) { $notes.AddRange([string[]]$names.Substitutions) }
    if ($names.UsedSentinelYear) {
        $requiresReview = $true
        $notes.Add('UNRESOLVED YEAR: placeholder value used, must be corrected before applying.')
    }

    $discogsTracks = @()
    $discogsIndices = @()
    if ($match.Status -eq 'matched') {
        $rawDiscogsTracks = @(Get-ReshelfDiscogsPlayableTracks -Tracklist $match.Detail.tracklist)
        if ($rawDiscogsTracks.Count -eq $Release.tracks.Count) {
            $discogsTracks = $rawDiscogsTracks
        }
        else {
            $alignment = Resolve-ReshelfDiscogsTrackAlignment -SourceTracks $Release.tracks -DiscogsTracks $rawDiscogsTracks
            $requiresReview = $true
            if ($alignment.Aligned) {
                $discogsTracks = $rawDiscogsTracks
                $discogsIndices = $alignment.Indices
                $methodText = if ($alignment.Method -eq 'number') { 'track number' } else { 'title' }
                $note = "Discogs tracklist has $($rawDiscogsTracks.Count) tracks but source has $($Release.tracks.Count); aligned by $methodText."
                if ($alignment.MissingNote) { $note = "$note $($alignment.MissingNote)." }
                $notes.Add($note)
            }
            else {
                $notes.Add("Discogs tracklist has $($rawDiscogsTracks.Count) tracks but source has $($Release.tracks.Count); falling back to source titles.")
                $discogsTracks = @()
            }
        }
    }

    $trackSet = New-ReshelfProposedTrackSet -Tracks $Release.tracks -DiscogsTracks $discogsTracks -DiscogsIndices $discogsIndices `
        -Names $names -TrackFileTemplate $TrackFileTemplate -TrackNumberPadWidth $TrackNumberPadWidth -FileNameArtists $vaEvidence.FileNameArtists
    if ($trackSet.Substitutions.Count -gt 0) { $notes.AddRange([string[]]$trackSet.Substitutions) }
    if ($trackSet.Notes.Count -gt 0) {
        $notes.AddRange([string[]]$trackSet.Notes)
        $requiresReview = $true
    }

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
        masterId          = $match.MasterId
    }

    $proposedDoc = [pscustomobject]@{
        artistFolderName  = $names.ArtistFolderName
        releaseFolderName = $names.ReleaseFolderName
        year              = $names.Year
        album             = $names.Album
        isCompilation     = [bool]$names.IsCompilation
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
        editionFolderName     = $Release.editionFolderName
        sourceFolderPath      = $Release.sourceFolderPath
        discFolderCount       = $Release.discFolderCount
        tracks                = $trackSet.Tracks
        companionFiles        = $companionProposal.Companions
        ignoredFiles          = $Release.ignoredFiles
        cueSheets             = $Release.cueSheets
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

function Update-ReshelfReleaseForDiscogsSelection {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [object]$Release,

        [Parameter(Mandatory)]
        [int]$SelectedReleaseId,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$SiblingReleases,

        [Parameter(Mandatory)]
        [string]$ArtistName,

        [Parameter(Mandatory)]
        [string]$TargetRoot,

        [Parameter(Mandatory)]
        [string]$ReleaseFolderTemplate,

        [Parameter(Mandatory)]
        [string]$TrackFileTemplate,

        [int]$TrackNumberPadWidth = 2,

        [Parameter(Mandatory)]
        [int]$CoverMaxDimension,

        [int]$CacheTtlDays = 30,

        [int]$RateLimitPerMinute = 55,

        [Parameter(Mandatory)]
        [string]$DataHome
    )

    $notes = [System.Collections.Generic.List[string]]::new()
    $requiresReview = $false

    $detail = Invoke-DiscogsRequest -Path "/releases/$SelectedReleaseId" -CacheTtlDays $CacheTtlDays -RateLimitPerMinute $RateLimitPerMinute -DataHome $DataHome

    # A manual edition pick still deserves the master's year and its cover-art fallback (C3/C4
    # above), not just what this one pressing itself carries - fetched only when the picked release
    # actually belongs to a master.
    $masterId = 0
    if ($detail.master_id) { try { $masterId = [int]$detail.master_id } catch { $masterId = 0 } }
    $master = $null
    if ($masterId -gt 0) {
        $master = Invoke-DiscogsRequest -Path "/masters/$masterId" -CacheTtlDays $CacheTtlDays -RateLimitPerMinute $RateLimitPerMinute -DataHome $DataHome
    }

    # Same shape Resolve-ReshelfDiscogsMatch returns for a 'matched' release - Candidates is kept
    # as-is (it's just the scored search-result list already shown in the UI's radio picker),
    # only Detail/SelectedReleaseId/Status reflect the user's own explicit pick.
    $match = [pscustomobject]@{
        Status            = 'matched'
        SelectedReleaseId = $SelectedReleaseId
        Candidates        = $Release.discogsMatch.candidates
        Detail            = $detail
        MasterId          = $(if ($masterId -gt 0) { $masterId } else { $null })
        Master            = $master
        ErrorNote         = $null
    }

    $names = New-ReshelfProposedReleaseNames -ArtistName $ArtistName -Release $Release -Match $match -ReleaseFolderTemplate $ReleaseFolderTemplate
    if ($names.Substitutions.Count -gt 0) { $notes.AddRange([string[]]$names.Substitutions) }
    if ($names.UsedSentinelYear) {
        $requiresReview = $true
        $notes.Add('UNRESOLVED YEAR: placeholder value used, must be corrected before applying.')
    }

    $discogsTracks = @()
    $discogsIndices = @()
    $rawDiscogsTracks = @(Get-ReshelfDiscogsPlayableTracks -Tracklist $detail.tracklist)
    if ($rawDiscogsTracks.Count -eq $Release.tracks.Count) {
        $discogsTracks = $rawDiscogsTracks
    }
    else {
        $alignment = Resolve-ReshelfDiscogsTrackAlignment -SourceTracks $Release.tracks -DiscogsTracks $rawDiscogsTracks
        $requiresReview = $true
        if ($alignment.Aligned) {
            $discogsTracks = $rawDiscogsTracks
            $discogsIndices = $alignment.Indices
            $methodText = if ($alignment.Method -eq 'number') { 'track number' } else { 'title' }
            $note = "Discogs tracklist has $($rawDiscogsTracks.Count) tracks but source has $($Release.tracks.Count); aligned by $methodText."
            if ($alignment.MissingNote) { $note = "$note $($alignment.MissingNote)." }
            $notes.Add($note)
        }
        else {
            $notes.Add("Discogs tracklist has $($rawDiscogsTracks.Count) tracks but source has $($Release.tracks.Count); falling back to source titles.")
            $discogsTracks = @()
        }
    }

    $trackSet = New-ReshelfProposedTrackSet -Tracks $Release.tracks -DiscogsTracks $discogsTracks -DiscogsIndices $discogsIndices `
        -Names $names -TrackFileTemplate $TrackFileTemplate -TrackNumberPadWidth $TrackNumberPadWidth
    if ($trackSet.Substitutions.Count -gt 0) { $notes.AddRange([string[]]$trackSet.Substitutions) }
    if ($trackSet.Notes.Count -gt 0) {
        $notes.AddRange([string[]]$trackSet.Notes)
        $requiresReview = $true
    }

    $coverArt = New-ReshelfCoverArtProposal -Match $match -Release $Release -CoverMaxDimension $CoverMaxDimension

    $targetIndex = Build-ReshelfTargetIndex -TargetRoot $TargetRoot

    # A hand-built stand-in for the SessionSeen dictionary a full propose run builds incrementally
    # across every release - here there is only one release being recomputed, so every *other*
    # release's own Hash/IsLossless (same fields Resolve-ReshelfTargetComparison itself derives at
    # its own lines computing $sourceHash/$sourceIsLossless) is precomputed up front instead.
    $sessionSeen = [System.Collections.Generic.Dictionary[string, object]]::new()
    foreach ($sibling in $SiblingReleases) {
        $siblingSourcePaths = @($sibling.tracks.sourceFilePath | Select-Object -Unique)
        $siblingHash = Get-ReshelfFileSetHash -FilePaths $siblingSourcePaths
        $siblingTotalTracks = $sibling.tracks.Count
        $siblingLosslessCount = @($sibling.tracks | Where-Object { $_.isLossless }).Count
        $sessionSeen[$sibling.stableKey] = [pscustomobject]@{
            Hash       = $siblingHash
            IsLossless = ($siblingTotalTracks -gt 0 -and $siblingLosslessCount -eq $siblingTotalTracks)
        }
    }

    $proposedTargetPath = Join-Path $TargetRoot $names.ArtistFolderName $names.ReleaseFolderName
    $comparison = Resolve-ReshelfTargetComparison -Release $Release -StableKey $Release.stableKey -ProposedTargetPath $proposedTargetPath `
        -TargetRoot $TargetRoot -TargetIndex $targetIndex -SessionSeen $sessionSeen -Names $names -DataHome $DataHome
    if ($comparison.ForcedReviewNote) {
        $requiresReview = $true
        $notes.Add($comparison.ForcedReviewNote)
    }

    $discogsMatchDoc = [pscustomobject]@{
        status            = 'matched'
        selectedReleaseId = $SelectedReleaseId
        candidates        = @($Release.discogsMatch.candidates)
        masterId          = $match.MasterId
    }

    $proposedDoc = [pscustomobject]@{
        artistFolderName  = $names.ArtistFolderName
        releaseFolderName = $names.ReleaseFolderName
        year              = $names.Year
        album             = $names.Album
        isCompilation     = [bool]$names.IsCompilation
    }

    return [pscustomobject]@{
        tracks         = $trackSet.Tracks
        proposed       = $proposedDoc
        discogsMatch   = $discogsMatchDoc
        coverArt       = $coverArt
        lossyLossless  = $comparison.LossyLossless
        targetAction   = $comparison.TargetAction
        notes          = @($notes)
        requiresReview = $requiresReview
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

Export-ModuleMember -Function Invoke-ReshelfEditProposal, Build-ReshelfTargetIndex, Test-ReshelfTargetReleaseExists, Update-ReshelfReleaseForDiscogsSelection
