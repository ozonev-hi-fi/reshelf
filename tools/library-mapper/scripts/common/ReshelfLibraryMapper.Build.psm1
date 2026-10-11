#Requires -Version 7.4

function ConvertTo-LibraryMapTrack {
    <#
        Legacy's recognition.json track carries `existingCoverArtPath`, a machine-local cache
        file path - not portable/comparable across two maps generated on different machines.
        Legacy already names that cached file by its own SHA-256 content hash
        (Save-ReshelfEmbeddedCoverToCache), so the hash can be read straight off the filename
        stem with no extra hashing work, and used in its place.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [object]$Track
    )

    $coverSha256 = $null
    if ($Track.existingCoverArtPath) {
        $coverSha256 = [System.IO.Path]::GetFileNameWithoutExtension($Track.existingCoverArtPath)
    }

    return [pscustomobject]@{
        sourceFilePath            = $Track.sourceFilePath
        discFolder                = $Track.discFolder
        originalFileName          = $Track.originalFileName
        detectedTrackNumberInDisc = $Track.detectedTrackNumberInDisc
        inferredTrackOrder        = $Track.inferredTrackOrder
        existingTags              = $Track.existingTags
        embeddedCoverSha256       = $coverSha256
        format                    = $Track.format
        isLossless                = $Track.isLossless
        durationSeconds           = $Track.durationSeconds
        cueTimestamp              = $Track.cueTimestamp
        isCueVirtualTrack         = $Track.isCueVirtualTrack
    }
}

function ConvertTo-LibraryMapRelease {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [object]$Release
    )

    $tracks = @(foreach ($track in @($Release.tracks)) {
            ConvertTo-LibraryMapTrack -Track $track
        })

    return [pscustomobject]@{
        stableKey             = $Release.stableKey
        recognizedTitle       = $Release.recognizedTitle
        recognizedYear        = $Release.recognizedYear
        recognizedReleaseDate = $Release.recognizedReleaseDate
        recognizedReleaseType = $Release.recognizedReleaseType
        editionFolderName     = $Release.editionFolderName
        sourceFolderPath      = $Release.sourceFolderPath
        discFolderCount       = $Release.discFolderCount
        tracks                = $tracks
        companionFiles        = $Release.companionFiles
        ignoredFiles          = $Release.ignoredFiles
        cueSheets             = $Release.cueSheets
        recognitionConfidence = $Release.recognitionConfidence
        recognitionFlags      = $Release.recognitionFlags
        needsReview           = $Release.needsReview
        reviewReasons         = $Release.reviewReasons
    }
}

function New-ReshelfLibraryMap {
    <#
        Walks LibraryRoot one top-level child folder at a time (e.g. once per artist), calling
        legacy's own Invoke-ReshelfRecognition (legacy/scripts/common/Reshelf.Recognition.psm1)
        for each - reusing its folder-kind heuristics, tag reading and companion-file
        classification rather than re-implementing any of it. legacy/ itself is only imported
        (read-only), never modified.

        Each top-level call is isolated in its own try/catch: Get-ReshelfAudioTags only catches
        TagLib.CorruptFileException internally, so any other exception (a different TagLib
        exception, a flaky-media IOException, a permission error) would otherwise abort the
        entire run over a single bad file. Invoke-ReshelfFolderWalk already evaluates each
        top-level child independently (Context='Root'), so splitting the walk this way is
        behavior-preserving, not an approximation - it just bounds a crash to one top-level
        folder instead of the whole library.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$LibraryRoot,

        [Parameter(Mandatory)]
        [string]$Label,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter(Mandatory)]
        [string]$DataHome,

        [string]$TagLibSharpPath,

        # Top-level child names (case-insensitive, exact match) to skip entirely - never walked,
        # never recognized. For a LibraryRoot that mixes real music folders with unrelated ones
        # (e.g. a phone storage root's default Android folders: DCIM, Download, Android, ...).
        [string[]]$ExcludeTopLevelName
    )

    if (-not (Test-Path -LiteralPath $LibraryRoot -PathType Container)) {
        throw "Library root '$LibraryRoot' does not exist or is not a directory."
    }
    $resolvedLibraryRoot = (Resolve-Path -LiteralPath $LibraryRoot).Path

    $legacyCommonDir = Join-Path $PSScriptRoot '..' '..' '..' '..' 'legacy' 'scripts' 'common'
    Import-Module (Join-Path $legacyCommonDir 'Reshelf.Common.psm1') -Force
    Import-Module (Join-Path $legacyCommonDir 'Reshelf.Json.psm1') -Force
    Import-Module (Join-Path $legacyCommonDir 'Reshelf.Recognition.psm1') -Force

    $artistBuckets = [ordered]@{}
    $unrecognized = [System.Collections.Generic.List[object]]::new()
    $errors = [System.Collections.Generic.List[object]]::new()

    $topLevelChildren = @(Get-ChildItem -LiteralPath $resolvedLibraryRoot -Directory -ErrorAction SilentlyContinue)
    if ($ExcludeTopLevelName) {
        $topLevelChildren = @($topLevelChildren | Where-Object { $_.Name -notin $ExcludeTopLevelName })
    }

    $index = 0
    foreach ($child in $topLevelChildren) {
        $index++
        $safeName = (ConvertTo-SafeFileName -Name $child.Name).SafeName
        $sessionId = '{0}-{1:0000}-{2}' -f $Label, $index, $safeName

        try {
            $childDocument = Invoke-ReshelfRecognition -SourceRoot $child.FullName -SessionId $sessionId `
                -DataHome $DataHome -TagLibSharpPath $TagLibSharpPath

            foreach ($artist in @($childDocument.artists)) {
                $key = ConvertTo-ReshelfNormalizedText -Text $artist.recognizedName
                if (-not $artistBuckets.Contains($key)) {
                    $artistBuckets[$key] = [pscustomobject]@{
                        recognizedName = $artist.recognizedName
                        sourcePaths    = [System.Collections.Generic.List[string]]::new()
                        releases       = [System.Collections.Generic.List[object]]::new()
                    }
                }
                $bucket = $artistBuckets[$key]
                foreach ($sourcePath in @($artist.sourcePaths)) {
                    if (-not $bucket.sourcePaths.Contains($sourcePath)) {
                        $bucket.sourcePaths.Add($sourcePath)
                    }
                }
                foreach ($release in @($artist.releases)) {
                    $bucket.releases.Add((ConvertTo-LibraryMapRelease -Release $release))
                }
            }

            foreach ($entry in @($childDocument.unrecognized)) {
                $unrecognized.Add($entry)
            }
        }
        catch {
            $errors.Add([pscustomobject]@{
                    path    = $child.FullName
                    phase   = 'walk-isolation'
                    message = $_.Exception.Message
                })
        }
    }

    # Best-effort accessibility pass: legacy's own walk uses -ErrorAction SilentlyContinue
    # throughout and never surfaces permission-denied subtrees anywhere; this is the only way to
    # know they happened. It says *that* a path was inaccessible, not necessarily which specific
    # release that broke. Recurses per included top-level child (not the whole LibraryRoot), so an
    # excluded tree (e.g. a phone's Android/DCIM folders) is never even listed.
    foreach ($child in $topLevelChildren) {
        $accessErrors = $null
        Get-ChildItem -LiteralPath $child.FullName -Recurse -ErrorAction SilentlyContinue -ErrorVariable accessErrors |
            Out-Null
        foreach ($accessError in @($accessErrors)) {
            $errors.Add([pscustomobject]@{
                    path    = [string]$accessError.TargetObject
                    phase   = 'accessibility'
                    message = $accessError.Exception.Message
                })
        }
    }

    $artists = @($artistBuckets.Values | ForEach-Object {
            [pscustomobject]@{
                recognizedName = $_.recognizedName
                sourcePaths    = @($_.sourcePaths)
                releases       = @($_.releases)
            }
        })

    $releaseCount = 0
    $trackCount = 0
    foreach ($artist in $artists) {
        $releaseCount += $artist.releases.Count
        foreach ($release in $artist.releases) {
            $trackCount += $release.tracks.Count
        }
    }

    $document = [pscustomobject]@{
        schemaVersion  = 1
        label          = $Label
        libraryRoot    = $resolvedLibraryRoot
        generatedAtUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        stats          = [pscustomobject]@{
            artistCount       = $artists.Count
            releaseCount      = $releaseCount
            trackCount        = $trackCount
            unrecognizedCount = $unrecognized.Count
            errorCount        = $errors.Count
        }
        artists        = $artists
        unrecognized   = @($unrecognized)
        errors         = @($errors)
    }

    $schemaPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..' '..' 'schemas' 'library-map.schema.json')).Path
    $json = ConvertTo-Json -InputObject $document -Depth 20

    if (-not (Test-Json -Json $json -SchemaFile $schemaPath)) {
        throw "Generated library map for label '$Label' does not match library-map.schema.json."
    }

    $parentDir = Split-Path -Path $OutputPath -Parent
    if ($parentDir -and -not (Test-Path -LiteralPath $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }
    Set-Content -LiteralPath $OutputPath -Value $json -Encoding utf8

    return $OutputPath
}

Export-ModuleMember -Function New-ReshelfLibraryMap
