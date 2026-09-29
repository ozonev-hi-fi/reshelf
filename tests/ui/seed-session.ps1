#Requires -Version 7.4
<#
.SYNOPSIS
    Seeds one fresh Reshelf session (with a real proposal.json) for the Playwright UI suite.
.DESCRIPTION
    Creates real audio files (via ffmpeg) and real companion/cover images (from tests/ui/fixtures)
    under a fresh subfolder of -SourceRoot, then writes a schema-valid proposal.json for two
    releases:
      - "rich" - an ambiguous Discogs match, 3 cover candidates (large/needs-resize, small/as-is,
        and a deliberately unreachable "remote-style" URL - see NOTE below), a nested companion, a
        loose companion with a proposed name, and a loose companion with proposedFileName == null
        (the pre-existing-field backfill case), plus one ignored playlist and one ignored
        not-used cue file.
      - "minimal" - a single track, no companions/ignored files at all (the "No other files"
        empty-state case), a resolved/matched Discogs status, one cover candidate.
    Prints the resulting {sessionId, proposalPath, sourceFolderPath, rich, minimal} as JSON on
    stdout so the calling spec (via helpers.js) knows exactly which stableKey/album to target.

    NOTE on the "remote" cover candidate: it points at https://example.invalid/cover-remote.jpg,
    which never resolves - this suite runs with no real network access to Discogs, so a genuinely
    fetchable remote URL isn't available. It still exercises the real branch in
    resolveCoverImageSrc() (app.js) that leaves an http(s) URL untouched instead of routing it
    through /api/.../local-file - specs assert on the resulting <img src>, not on the image
    successfully decoding.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$DataHome,

    [Parameter(Mandatory)]
    [string]$SourceRoot,

    [Parameter(Mandatory)]
    [string]$Label
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '..' '..' 'scripts' 'common' 'Reshelf.Settings.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..' '..' 'scripts' 'common' 'Reshelf.Json.psm1') -Force

$fixturesDir = Join-Path $PSScriptRoot 'fixtures'
$suffix = [guid]::NewGuid().ToString('N').Substring(0, 8)
$releaseSourceRoot = Join-Path $SourceRoot "$Label-$suffix" 'Aurora Fields'

function New-StableKey {
    return [guid]::NewGuid().ToString('N').Substring(0, 16)
}

function New-SilentFlac {
    param([Parameter(Mandatory)] [string]$Path)
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    & ffmpeg -hide_banner -loglevel error -y -f lavfi -i 'sine=frequency=440:duration=1' -c:a flac $Path
    if ($LASTEXITCODE -ne 0) { throw "ffmpeg failed to generate '$Path' (exit $LASTEXITCODE)." }
}

function New-Track {
    param(
        [Parameter(Mandatory)] [string]$SourceFilePath,
        [Parameter(Mandatory)] [string]$ProposedFileName,
        [Parameter(Mandatory)] [int]$ProposedTrackNumber,
        [Parameter(Mandatory)] [string]$Title,
        [Parameter(Mandatory)] [string]$Artist,
        [Parameter(Mandatory)] [string]$Album,
        [Parameter(Mandatory)] [int]$Year,

        # Per-track Artist, distinct from Album Artist - only a compilation release passes this;
        # everyone else keeps Artist == Album Artist, same as before.
        [string]$TrackArtist,
        [bool]$IsCompilation = $false
    )
    [pscustomobject]@{
        sourceFilePath            = $SourceFilePath
        discFolder                = $null
        originalFileName          = (Split-Path -Leaf $SourceFilePath)
        detectedTrackNumberInDisc = $ProposedTrackNumber
        inferredTrackOrder        = $false
        existingTags              = [pscustomobject]@{ artist = $null; album = $null; title = $null }
        existingCoverArtPath      = $null
        format                    = 'flac'
        isLossless                = $true
        durationSeconds           = 1.0
        cueTimestamp              = $null
        isCueVirtualTrack         = $false
        proposedFileName          = $ProposedFileName
        proposedDiscNumber        = 1
        proposedTrackNumber       = $ProposedTrackNumber
        proposedTitle             = $Title
        tags                      = [pscustomobject]@{
            artist        = if ($TrackArtist) { $TrackArtist } else { $Artist }
            albumArtist   = $Artist
            album         = $Album
            year          = $Year
            discNumber    = 1
            track         = $ProposedTrackNumber
            title         = $Title
            isCompilation = $IsCompilation
        }
    }
}

# --- "rich" release: exercises companions, cover sizing, ambiguous match ------------------------

$richAlbum = "Departure Songs $suffix"
$richYear = 2016
$richFolder = Join-Path $releaseSourceRoot "$richYear $richAlbum"

$t1Path = Join-Path $richFolder '01 Track.flac'
$t2Path = Join-Path $richFolder '02 Track.flac'
New-SilentFlac -Path $t1Path
New-SilentFlac -Path $t2Path

$nestedCompanionPath = Join-Path $richFolder 'Scans' 'inner.jpg'
New-Item -ItemType Directory -Path (Split-Path -Parent $nestedCompanionPath) -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $fixturesDir 'nested-companion.jpg') -Destination $nestedCompanionPath -Force

$looseCompanionPath = Join-Path $richFolder '01 back.jpg'
Copy-Item -LiteralPath (Join-Path $fixturesDir 'loose-companion.jpg') -Destination $looseCompanionPath -Force

$looseNoNamePath = Join-Path $richFolder '02 extra.jpg'
Copy-Item -LiteralPath (Join-Path $fixturesDir 'loose-companion.jpg') -Destination $looseNoNamePath -Force

$largeCoverPath = Join-Path $richFolder 'front-large.jpg'
Copy-Item -LiteralPath (Join-Path $fixturesDir 'large-cover.jpg') -Destination $largeCoverPath -Force
$smallCoverPath = Join-Path $richFolder 'front-small.jpg'
Copy-Item -LiteralPath (Join-Path $fixturesDir 'small-cover.jpg') -Destination $smallCoverPath -Force

$ignoredPlaylistPath = Join-Path $richFolder 'setlist.m3u'
Set-Content -LiteralPath $ignoredPlaylistPath -Value '#EXTM3U' -NoNewline
$ignoredCuePath = Join-Path $richFolder 'alt-pressing.cue'
Set-Content -LiteralPath $ignoredCuePath -Value 'REM not the cue actually used' -NoNewline

$richStableKey = New-StableKey
$richRelease = [pscustomobject]@{
    stableKey             = $richStableKey
    recognizedTitle       = $richAlbum
    recognizedYear        = $richYear
    sourceFolderPath      = $richFolder
    discFolderCount       = 1
    tracks                = @(
        (New-Track -SourceFilePath $t1Path -ProposedFileName '01 Track.flac' -ProposedTrackNumber 1 -Title 'First Track' -Artist 'Aurora Fields' -Album $richAlbum -Year $richYear),
        (New-Track -SourceFilePath $t2Path -ProposedFileName '02 Track.flac' -ProposedTrackNumber 2 -Title 'Second Track' -Artist 'Aurora Fields' -Album $richAlbum -Year $richYear)
    )
    companionFiles        = @(
        [pscustomobject]@{ sourcePath = $nestedCompanionPath; kind = 'photo'; placement = 'nested'; include = $true; proposedFileName = $null }
        [pscustomobject]@{ sourcePath = $looseCompanionPath; kind = 'booklet'; placement = 'loose'; include = $true; proposedFileName = 'Booklet 01 back.jpg' }
        # Deliberately no proposedFileName (the pre-existing-field backfill case app.js's
        # renderCompanionTable handles - see plan/07).
        [pscustomobject]@{ sourcePath = $looseNoNamePath; kind = 'other'; placement = 'loose'; include = $true; proposedFileName = $null }
    )
    ignoredFiles          = @(
        [pscustomobject]@{ sourcePath = $ignoredPlaylistPath; reason = 'playlist-file' }
        [pscustomobject]@{ sourcePath = $ignoredCuePath; reason = 'cue-sheet-not-used' }
    )
    cueSheet              = $null
    recognitionConfidence = 1.0
    recognitionFlags      = @()
    needsReview           = $true
    reviewReasons         = @('ambiguous-discogs-match')
    discogsMatch          = [pscustomobject]@{
        status            = 'ambiguous'
        selectedReleaseId = $null
        candidates        = @(
            [pscustomobject]@{ releaseId = 1001; title = "$richAlbum (Original Press)"; year = $richYear; format = 'CD'; score = 0.82 }
            [pscustomobject]@{ releaseId = 1002; title = "$richAlbum (Reissue)"; year = $richYear; format = 'Vinyl'; score = 0.75 }
        )
    }
    proposed              = [pscustomobject]@{ artistFolderName = 'Aurora Fields'; releaseFolderName = "$richYear $richAlbum"; year = $richYear; album = $richAlbum }
    coverArt              = [pscustomobject]@{
        candidates          = @(
            [pscustomobject]@{ url = $largeCoverPath; sourceEdition = 'Original Press'; width = 3120; height = 3200 }
            [pscustomobject]@{ url = $smallCoverPath; sourceEdition = 'Reissue'; width = 500; height = 500 }
            [pscustomobject]@{ url = 'https://example.invalid/cover-remote.jpg'; sourceEdition = 'Discogs (unreachable in this suite)'; width = 1200; height = 1200 }
        )
        chosenCandidateUrl  = $largeCoverPath
        targetMaxDimension  = 600
    }
    lossyLossless         = [pscustomobject]@{ isLossy = $false; action = 'none' }
    targetAction          = 'create-new'
    humanReview           = [pscustomobject]@{ required = $true; resolved = $false; rejected = $false; notes = '' }
}

# --- "minimal" release: no companions/ignored files, already matched ---------------------------

$minimalAlbum = "Quiet Interlude $suffix"
$minimalYear = 2018
$minimalFolder = Join-Path $releaseSourceRoot "$minimalYear $minimalAlbum"
$m1Path = Join-Path $minimalFolder '01 Track.flac'
New-SilentFlac -Path $m1Path

$minimalStableKey = New-StableKey
$minimalRelease = [pscustomobject]@{
    stableKey             = $minimalStableKey
    recognizedTitle       = $minimalAlbum
    recognizedYear        = $minimalYear
    sourceFolderPath      = $minimalFolder
    discFolderCount       = 1
    tracks                = @(
        (New-Track -SourceFilePath $m1Path -ProposedFileName '01 Track.flac' -ProposedTrackNumber 1 -Title 'Only Track' -Artist 'Aurora Fields' -Album $minimalAlbum -Year $minimalYear)
    )
    companionFiles        = @()
    ignoredFiles          = @()
    cueSheet              = $null
    recognitionConfidence = 1.0
    recognitionFlags      = @()
    # true (not ambiguous, unlike "rich"): exercises the plain needsReview badge path in
    # getReleaseStatus (app.js) on its own, distinct from the ambiguous-match path "rich" covers.
    needsReview           = $true
    reviewReasons         = @('no-track-number')
    discogsMatch          = [pscustomobject]@{ status = 'matched'; selectedReleaseId = 2001; candidates = @() }
    proposed              = [pscustomobject]@{ artistFolderName = 'Aurora Fields'; releaseFolderName = "$minimalYear $minimalAlbum"; year = $minimalYear; album = $minimalAlbum }
    coverArt              = [pscustomobject]@{
        candidates         = @(
            [pscustomobject]@{ url = $smallCoverPath; sourceEdition = 'Original Press'; width = 500; height = 500 }
        )
        chosenCandidateUrl = $smallCoverPath
        targetMaxDimension = 600
    }
    lossyLossless         = [pscustomobject]@{ isLossy = $false; action = 'none' }
    targetAction          = 'create-new'
    humanReview           = [pscustomobject]@{ required = $false; resolved = $false; rejected = $false; notes = '' }
}

# --- "empty" release: no cover candidates at all, no companions/ignored files -------------------
# (the "Add cover from file..." control must still be visible against an empty gallery.)

$emptyAlbum = "Bare Sessions $suffix"
$emptyYear = 2020
$emptyFolder = Join-Path $releaseSourceRoot "$emptyYear $emptyAlbum"
$e1Path = Join-Path $emptyFolder '01 Track.flac'
New-SilentFlac -Path $e1Path

$emptyStableKey = New-StableKey
$emptyRelease = [pscustomobject]@{
    stableKey             = $emptyStableKey
    recognizedTitle       = $emptyAlbum
    recognizedYear        = $emptyYear
    sourceFolderPath      = $emptyFolder
    discFolderCount       = 1
    tracks                = @(
        (New-Track -SourceFilePath $e1Path -ProposedFileName '01 Track.flac' -ProposedTrackNumber 1 -Title 'Only Track' -Artist 'Aurora Fields' -Album $emptyAlbum -Year $emptyYear)
    )
    companionFiles        = @()
    ignoredFiles          = @()
    cueSheet              = $null
    recognitionConfidence = 1.0
    recognitionFlags      = @()
    needsReview           = $false
    reviewReasons         = @()
    discogsMatch          = [pscustomobject]@{ status = 'matched'; selectedReleaseId = 3001; candidates = @() }
    proposed              = [pscustomobject]@{ artistFolderName = 'Aurora Fields'; releaseFolderName = "$emptyYear $emptyAlbum"; year = $emptyYear; album = $emptyAlbum }
    coverArt              = [pscustomobject]@{ candidates = @(); chosenCandidateUrl = $null; targetMaxDimension = 600 }
    lossyLossless         = [pscustomobject]@{ isLossy = $false; action = 'none' }
    targetAction          = 'create-new'
    humanReview           = [pscustomobject]@{ required = $false; resolved = $true; rejected = $false; notes = '' }
}

# --- "compilation" release: Various Artists, each track its own Artist tag ---------------------

$compilationAlbum = "Best Of Everywhere $suffix"
$compilationYear = 2008
$compilationFolder = Join-Path $releaseSourceRoot "$compilationYear $compilationAlbum"
$c1Path = Join-Path $compilationFolder '01 Track.flac'
$c2Path = Join-Path $compilationFolder '02 Track.flac'
New-SilentFlac -Path $c1Path
New-SilentFlac -Path $c2Path

$compilationStableKey = New-StableKey
$compilationRelease = [pscustomobject]@{
    stableKey             = $compilationStableKey
    recognizedTitle       = $compilationAlbum
    recognizedYear        = $compilationYear
    sourceFolderPath      = $compilationFolder
    discFolderCount       = 1
    tracks                = @(
        (New-Track -SourceFilePath $c1Path -ProposedFileName '01 Track.flac' -ProposedTrackNumber 1 -Title 'One Song' -Artist 'Various' -TrackArtist 'First Act' -Album $compilationAlbum -Year $compilationYear -IsCompilation $true),
        (New-Track -SourceFilePath $c2Path -ProposedFileName '02 Track.flac' -ProposedTrackNumber 2 -Title 'Another Song' -Artist 'Various' -TrackArtist 'Second Act' -Album $compilationAlbum -Year $compilationYear -IsCompilation $true)
    )
    companionFiles        = @()
    ignoredFiles          = @()
    cueSheet              = $null
    recognitionConfidence = 1.0
    recognitionFlags      = @()
    needsReview           = $false
    reviewReasons         = @()
    discogsMatch          = [pscustomobject]@{ status = 'matched'; selectedReleaseId = 4001; candidates = @() }
    proposed              = [pscustomobject]@{ artistFolderName = 'Various'; releaseFolderName = "$compilationYear $compilationAlbum"; year = $compilationYear; album = $compilationAlbum; isCompilation = $true }
    coverArt              = [pscustomobject]@{ candidates = @(); chosenCandidateUrl = $null; targetMaxDimension = 600 }
    lossyLossless         = [pscustomobject]@{ isLossy = $false; action = 'none' }
    targetAction          = 'create-new'
    humanReview           = [pscustomobject]@{ required = $false; resolved = $true; rejected = $false; notes = '' }
}

$proposalDoc = [pscustomobject]@{
    schemaVersion  = 1
    sessionId      = 'placeholder' # overwritten below with the real allocated session id
    sourceRoot     = $releaseSourceRoot
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    artists        = @(
        [pscustomobject]@{ recognizedName = 'Aurora Fields'; sourcePaths = @($releaseSourceRoot); releases = @($richRelease, $minimalRelease, $emptyRelease, $compilationRelease) }
    )
    unrecognized   = @()
}

$session = New-ReshelfSession -SourceRoot $releaseSourceRoot -DataHome $DataHome
$proposalDoc.sessionId = $session.sessionId

$proposalPath = Join-Path $DataHome 'sessions' $session.sessionId 'proposal.json'
Set-ReshelfJsonFile -Path $proposalPath -InputObject $proposalDoc -SchemaName proposal -Depth 20 | Out-Null
Set-ReshelfSessionStage -SessionId $session.sessionId -Stage 'reviewed' -ProposalPath $proposalPath -DataHome $DataHome | Out-Null

[pscustomobject]@{
    sessionId        = $session.sessionId
    proposalPath     = $proposalPath
    sourceFolderPath = $releaseSourceRoot
    rich             = [pscustomobject]@{ stableKey = $richStableKey; album = $richAlbum; year = $richYear }
    minimal          = [pscustomobject]@{ stableKey = $minimalStableKey; album = $minimalAlbum; year = $minimalYear }
    empty            = [pscustomobject]@{ stableKey = $emptyStableKey; album = $emptyAlbum; year = $emptyYear }
    compilation      = [pscustomobject]@{ stableKey = $compilationStableKey; album = $compilationAlbum; year = $compilationYear }
} | ConvertTo-Json -Depth 5 -Compress
