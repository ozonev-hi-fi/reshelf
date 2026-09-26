#Requires -Version 7.4

Import-Module (Join-Path $PSScriptRoot 'Reshelf.Settings.psm1') -Force
# Re-imported after Settings: Reshelf.Settings.psm1 imports this module internally too, which
# reparents it as one of Settings' nested modules and hides its exports from this module's own
# scope (same gotcha noted in Reshelf.ps1) - importing it again here restores top-level visibility
# for ConvertTo-ReshelfLongPath below.
Import-Module (Join-Path $PSScriptRoot 'Reshelf.Common.psm1') -Force

$script:ReshelfUiMimeTypes = @{
    '.html' = 'text/html'
    '.js'   = 'text/javascript'
    '.css'  = 'text/css'
    '.json' = 'application/json'
    '.png'  = 'image/png'
    '.jpg'  = 'image/jpeg'
    '.jpeg' = 'image/jpeg'
    '.svg'  = 'image/svg+xml'
    '.ico'  = 'image/x-icon'
}

function Resolve-ReshelfUiRequestPath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$UiRoot,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$RequestPath
    )

    $resolvedUiRoot = (Resolve-Path -LiteralPath $UiRoot).Path
    $relativePath = $RequestPath.TrimStart('/')
    if ([string]::IsNullOrEmpty($relativePath)) {
        $relativePath = 'index.html'
    }

    $candidatePath = Join-Path $resolvedUiRoot $relativePath

    if (-not (Test-Path -LiteralPath $candidatePath -PathType Leaf)) {
        return $null
    }

    $resolvedCandidate = (Resolve-Path -LiteralPath $candidatePath).Path
    $rootWithSeparator = $resolvedUiRoot.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if (-not $resolvedCandidate.StartsWith($rootWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $null
    }

    return $resolvedCandidate
}

function Get-ReshelfUiMimeType {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    if ($script:ReshelfUiMimeTypes.ContainsKey($extension)) {
        return $script:ReshelfUiMimeTypes[$extension]
    }

    return 'application/octet-stream'
}

$script:ReshelfUiSessionIdPattern = '^\d{4}-\d{2}-\d{2}-\d{4}$'

# --- API routing --------------------------------------------------------------
#
# The server used to serve static files only (proposal.json was read/written by the browser
# directly via the File System Access API). It now also reads/writes proposal.json itself, since
# it already runs with full local disk access and the browser doesn't - this removes every
# per-visit folder-permission click the old design needed. Still localhost-only, single-user; the
# session id pattern check below exists so a crafted id in a URL can't reach outside the sessions
# folder, matching the id shape New-ReshelfSessionId actually produces (e.g. "2026-09-25-0003").
function Get-ReshelfUiApiRoute {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$Method,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Path
    )

    if ($Method -eq 'GET' -and $Path -eq '/api/current-session') {
        return [pscustomobject]@{ Action = 'CurrentSession' }
    }
    if ($Method -eq 'GET' -and $Path -eq '/api/sessions') {
        return [pscustomobject]@{ Action = 'ListSessions' }
    }

    if ($Path -match '^/api/sessions/([^/]+)/proposal$') {
        $sessionId = $Matches[1]
        if ($sessionId -notmatch $script:ReshelfUiSessionIdPattern) {
            return [pscustomobject]@{ Action = 'BadRequest'; Message = "Invalid session id '$sessionId'." }
        }
        if ($Method -eq 'GET') {
            return [pscustomobject]@{ Action = 'GetProposal'; SessionId = $sessionId }
        }
        if ($Method -eq 'PUT') {
            return [pscustomobject]@{ Action = 'SaveProposal'; SessionId = $sessionId }
        }
    }

    if ($Method -eq 'GET' -and $Path -match '^/api/sessions/([^/]+)/local-file$') {
        $sessionId = $Matches[1]
        if ($sessionId -notmatch $script:ReshelfUiSessionIdPattern) {
            return [pscustomobject]@{ Action = 'BadRequest'; Message = "Invalid session id '$sessionId'." }
        }
        return [pscustomobject]@{ Action = 'LocalFile'; SessionId = $sessionId }
    }

    if ($Method -eq 'POST' -and $Path -match '^/api/sessions/([^/]+)/manual-cover$') {
        $sessionId = $Matches[1]
        if ($sessionId -notmatch $script:ReshelfUiSessionIdPattern) {
            return [pscustomobject]@{ Action = 'BadRequest'; Message = "Invalid session id '$sessionId'." }
        }
        return [pscustomobject]@{ Action = 'SaveManualCover'; SessionId = $sessionId }
    }

    if ($Method -eq 'GET' -and $Path -eq '/api/naming-templates') {
        return [pscustomobject]@{ Action = 'NamingTemplates' }
    }

    if ($Method -eq 'GET' -and $Path -eq '/api/lossy') {
        return [pscustomobject]@{ Action = 'ListLossy' }
    }
    if ($Path -match '^/api/lossy/([0-9a-f]{16})$') {
        $stableKey = $Matches[1]
        if ($Method -eq 'PUT') {
            return [pscustomobject]@{ Action = 'UpdateLossy'; StableKey = $stableKey }
        }
        if ($Method -eq 'DELETE') {
            return [pscustomobject]@{ Action = 'DeleteLossy'; StableKey = $stableKey }
        }
    }

    return $null
}

# --- Session discovery ---------------------------------------------------------

function Get-ReshelfUiSessionsSummary {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [string]$DataHome
    )

    $sessions = @(Get-ReshelfSession -DataHome $DataHome)
    return @($sessions | ForEach-Object {
            [pscustomobject]@{
                sessionId    = $_.sessionId
                sourceRoot   = $_.sourceRoot
                stage        = $_.stage
                updatedAtUtc = $_.updatedAtUtc
                hasProposal  = [bool]($_.proposalPath -and (Test-Path -LiteralPath $_.proposalPath -PathType Leaf))
            }
        })
}

function Get-ReshelfUiCurrentSession {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$DataHome
    )

    # Get-ReshelfSession already sorts by updatedAtUtc descending, so the first entry here with a
    # proposal.json is the most recently updated session that's actually ready to review.
    $summary = Get-ReshelfUiSessionsSummary -DataHome $DataHome
    return $summary | Where-Object { $_.hasProposal } | Select-Object -First 1
}

# --- Reading/writing one session's proposal.json -------------------------------

function Get-ReshelfUiProposalContent {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$DataHome,

        [Parameter(Mandatory)]
        [string]$SessionId
    )

    $session = Get-ReshelfSession -SessionId $SessionId -DataHome $DataHome
    if (-not $session.proposalPath -or -not (Test-Path -LiteralPath $session.proposalPath -PathType Leaf)) {
        throw "Session '$SessionId' has no proposal.json yet."
    }

    return Get-Content -LiteralPath $session.proposalPath -Raw
}

function Save-ReshelfUiProposalContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DataHome,

        [Parameter(Mandatory)]
        [string]$SessionId,

        [Parameter(Mandatory)]
        [string]$Content
    )

    # Validate before writing anything - a malformed request body must never overwrite a good file.
    try {
        $null = $Content | ConvertFrom-Json
    }
    catch {
        throw "Request body is not valid JSON: $($_.Exception.Message)"
    }

    $session = Get-ReshelfSession -SessionId $SessionId -DataHome $DataHome
    if (-not $session.proposalPath) {
        throw "Session '$SessionId' has no proposal.json path recorded."
    }

    # Same single rolling backup the browser used to write itself before every save.
    if (Test-Path -LiteralPath $session.proposalPath -PathType Leaf) {
        $backupPath = Join-Path (Split-Path -Parent $session.proposalPath) 'proposal.backup.json'
        Copy-Item -LiteralPath $session.proposalPath -Destination $backupPath -Force
    }

    Set-Content -LiteralPath $session.proposalPath -Value $Content -Encoding utf8 -NoNewline
}

# --- Serving a local cover image (companion-file fallback, not a Discogs URL) --------

function Get-ReshelfUiManualCoversDir {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$DataHome,

        [Parameter(Mandatory)]
        [string]$SessionId
    )

    return Join-Path $DataHome 'sessions' $SessionId 'manual-covers'
}

function Get-ReshelfUiLocalFileBytes {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$DataHome,

        [Parameter(Mandatory)]
        [string]$SessionId,

        [Parameter(Mandatory)]
        [string]$RequestedPath
    )

    # Only ever serves a path this session's own proposal.json already names as a cover
    # candidate, or a file this session's own manual-cover upload endpoint wrote - never an
    # arbitrary file - since this listener has no other access control. The manual-covers
    # branch exists because a just-uploaded candidate lives only in the browser's in-memory
    # proposal until Save, so it can't be found in on-disk proposal.json yet.
    $manualCoversDir = Get-ReshelfUiManualCoversDir -DataHome $DataHome -SessionId $SessionId
    $isUnderManualCoversDir = $false
    if (Test-Path -LiteralPath $manualCoversDir -PathType Container) {
        $resolvedManualCoversDir = (Resolve-Path -LiteralPath $manualCoversDir).Path
        $resolvedRequestedPath = $null
        if (Test-Path -LiteralPath $RequestedPath -PathType Leaf) {
            $resolvedRequestedPath = (Resolve-Path -LiteralPath $RequestedPath).Path
        }
        if ($resolvedRequestedPath) {
            $rootWithSeparator = $resolvedManualCoversDir.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
            $isUnderManualCoversDir = $resolvedRequestedPath.StartsWith($rootWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)
        }
    }

    if (-not $isUnderManualCoversDir) {
        $content = Get-ReshelfUiProposalContent -DataHome $DataHome -SessionId $SessionId
        $proposal = $content | ConvertFrom-Json

        $allowedPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($artist in $proposal.artists) {
            foreach ($release in $artist.releases) {
                foreach ($candidate in @($release.coverArt.candidates)) {
                    if ($candidate.url -and $candidate.url -notmatch '^https?://') {
                        [void]$allowedPaths.Add($candidate.url)
                    }
                }
            }
        }

        if (-not $allowedPaths.Contains($RequestedPath)) {
            throw "Path '$RequestedPath' is not a known local cover file for session '$SessionId'."
        }
    }

    if (-not (Test-Path -LiteralPath $RequestedPath -PathType Leaf)) {
        throw "File '$RequestedPath' no longer exists."
    }

    $bytes = [System.IO.File]::ReadAllBytes((ConvertTo-ReshelfLongPath -Path $RequestedPath))
    return [pscustomobject]@{
        Bytes       = $bytes
        ContentType = Get-ReshelfUiMimeType -Path "file$([System.IO.Path]::GetExtension($RequestedPath))"
    }
}

# --- Saving a manually uploaded cover image ------------------------------------

$script:ReshelfUiManualCoverExtensions = @('.jpg', '.jpeg', '.png')
$script:ReshelfUiManualCoverMaxBytes = 20MB

function Get-ReshelfUiImageDimensions {
    # Local copy of Reshelf.EditProposal.psm1's Get-ReshelfImageDimensions - not imported from
    # there to avoid pulling in its Discogs/lossy-tracking dependencies for no reason. Unlike
    # that copy, a read failure here throws instead of returning a silent 1x1 placeholder,
    # since the caller needs to delete the just-written file when this fails.
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

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

function Save-ReshelfUiManualCoverFile {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$DataHome,

        [Parameter(Mandatory)]
        [string]$SessionId,

        [Parameter(Mandatory)]
        [string]$FileName,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [byte[]]$Bytes
    )

    if (-not $Bytes -or $Bytes.Length -eq 0) {
        throw 'Uploaded file is empty.'
    }
    if ($Bytes.Length -gt $script:ReshelfUiManualCoverMaxBytes) {
        throw "Uploaded file exceeds the $($script:ReshelfUiManualCoverMaxBytes / 1MB) MB limit."
    }

    $extension = [System.IO.Path]::GetExtension($FileName).ToLowerInvariant()
    if ($extension -notin $script:ReshelfUiManualCoverExtensions) {
        $allowed = $script:ReshelfUiManualCoverExtensions -join ', '
        throw "Unsupported image type '$extension' - allowed: $allowed."
    }

    # Confirms the session exists (throws "Session '...' not found." otherwise) without
    # requiring a proposal.json to already exist - this endpoint never reads/writes it.
    $null = Get-ReshelfSession -SessionId $SessionId -DataHome $DataHome

    $coversDir = Get-ReshelfUiManualCoversDir -DataHome $DataHome -SessionId $SessionId
    if (-not (Test-Path -LiteralPath $coversDir -PathType Container)) {
        New-Item -ItemType Directory -Path $coversDir -Force | Out-Null
    }

    $savedFileName = "$([guid]::NewGuid().ToString('N'))$extension"
    $savedPath = Join-Path $coversDir $savedFileName
    [System.IO.File]::WriteAllBytes((ConvertTo-ReshelfLongPath -Path $savedPath), $Bytes)

    try {
        $dimensions = Get-ReshelfUiImageDimensions -Path $savedPath
    }
    catch {
        Remove-Item -LiteralPath $savedPath -Force -ErrorAction SilentlyContinue
        throw "Uploaded file is not a readable image: $($_.Exception.Message)"
    }

    return [pscustomobject]@{
        Url    = $savedPath
        Width  = $dimensions.Width
        Height = $dimensions.Height
    }
}

Export-ModuleMember -Function Resolve-ReshelfUiRequestPath, Get-ReshelfUiMimeType, Get-ReshelfUiApiRoute, `
    Get-ReshelfUiSessionsSummary, Get-ReshelfUiCurrentSession, Get-ReshelfUiProposalContent, `
    Save-ReshelfUiProposalContent, Get-ReshelfUiLocalFileBytes, Save-ReshelfUiManualCoverFile
