#Requires -Version 7.4
[CmdletBinding()]
param(
    [int]$Port = 4173,
    [string]$UiRoot = (Join-Path $PSScriptRoot '..' 'ui'),

    # Skips the Start-Process launch below - used by the Playwright suite (tests/ui), which drives
    # its own browser instance and would otherwise get a second, unwanted real browser window on
    # every automated run.
    [switch]$NoBrowser
)

Import-Module (Join-Path $PSScriptRoot 'common' 'Tagger.UiServer.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'common' 'Tagger.Settings.psm1') -Force

$resolvedUiRoot = (Resolve-Path -LiteralPath $UiRoot -ErrorAction SilentlyContinue).Path
if (-not $resolvedUiRoot) {
    throw "UI root '$UiRoot' does not exist. Nothing to serve."
}

# Resolved once at startup, same as every CLI command - the browser never picks or knows this
# path; the server reads/writes proposal.json on its behalf instead of via a browser folder pick.
$dataHome = (Get-TaggerSettings).dataHome

function Write-TaggerUiJsonResponse {
    param($Response, [int]$StatusCode, $Payload)

    $Response.StatusCode = $StatusCode
    $Response.ContentType = 'application/json'
    $json = $Payload | ConvertTo-Json -Depth 20
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $Response.ContentLength64 = $bytes.Length
    $Response.OutputStream.Write($bytes, 0, $bytes.Length)
}

function Write-TaggerUiRawJsonResponse {
    # Writes a JSON string through as-is (proposal.json's own content) instead of round-tripping
    # it through ConvertFrom-Json/ConvertTo-Json, which would reformat it and risk losing precision
    # on values PowerShell doesn't round-trip exactly.
    param($Response, [int]$StatusCode, [string]$Json)

    $Response.StatusCode = $StatusCode
    $Response.ContentType = 'application/json'
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Json)
    $Response.ContentLength64 = $bytes.Length
    $Response.OutputStream.Write($bytes, 0, $bytes.Length)
}

function Write-TaggerUiErrorResponse {
    param($Response, [int]$StatusCode, [string]$Message)
    Write-TaggerUiJsonResponse -Response $Response -StatusCode $StatusCode -Payload @{ error = $Message }
}

function Read-TaggerUiRequestBody {
    param($Request)
    $reader = [System.IO.StreamReader]::new($Request.InputStream, $Request.ContentEncoding)
    try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}

function Read-TaggerUiRequestBodyBytes {
    # Reads the raw request body as bytes, not text - StreamReader (Read-TaggerUiRequestBody
    # above) decodes as UTF8, which would corrupt binary image data. Checked against
    # ContentLength64 as a cheap early reject, then against the actual buffered length too,
    # since a client's declared Content-Length header isn't trustworthy on its own.
    param($Request, [long]$MaxBytes = 20MB)

    if ($Request.ContentLength64 -gt $MaxBytes) {
        throw "Uploaded file exceeds the $($MaxBytes / 1MB) MB limit."
    }

    $memoryStream = [System.IO.MemoryStream]::new()
    try {
        $Request.InputStream.CopyTo($memoryStream)
        if ($memoryStream.Length -gt $MaxBytes) {
            throw "Uploaded file exceeds the $($MaxBytes / 1MB) MB limit."
        }
        return $memoryStream.ToArray()
    }
    finally {
        $memoryStream.Dispose()
    }
}

function Invoke-TaggerUiApiRequest {
    param($Route, $Request, $Response, [string]$DataHome)

    switch ($Route.Action) {
        'BadRequest' {
            Write-TaggerUiErrorResponse -Response $Response -StatusCode 400 -Message $Route.Message
        }
        'CurrentSession' {
            $current = Get-TaggerUiCurrentSession -DataHome $DataHome
            if (-not $current) {
                Write-TaggerUiJsonResponse -Response $Response -StatusCode 200 -Payload @{
                    found   = $false
                    message = 'No session has a proposal yet - run recognize and propose first.'
                }
                return
            }
            $proposalContent = Get-TaggerUiProposalContent -DataHome $DataHome -SessionId $current.sessionId
            $json = [pscustomobject]@{
                found        = $true
                sessionId    = $current.sessionId
                sourceRoot   = $current.sourceRoot
                stage        = $current.stage
                updatedAtUtc = $current.updatedAtUtc
                proposal     = ($proposalContent | ConvertFrom-Json)
            } | ConvertTo-Json -Depth 20
            Write-TaggerUiRawJsonResponse -Response $Response -StatusCode 200 -Json $json
        }
        'ListSessions' {
            $summary = Get-TaggerUiSessionsSummary -DataHome $DataHome
            Write-TaggerUiJsonResponse -Response $Response -StatusCode 200 -Payload $summary
        }
        'GetProposal' {
            try {
                $content = Get-TaggerUiProposalContent -DataHome $DataHome -SessionId $Route.SessionId
                Write-TaggerUiRawJsonResponse -Response $Response -StatusCode 200 -Json $content
            }
            catch {
                Write-TaggerUiErrorResponse -Response $Response -StatusCode 404 -Message $_.Exception.Message
            }
        }
        'SaveProposal' {
            try {
                $body = Read-TaggerUiRequestBody -Request $Request
                Save-TaggerUiProposalContent -DataHome $DataHome -SessionId $Route.SessionId -Content $body
                Write-TaggerUiJsonResponse -Response $Response -StatusCode 200 -Payload @{ savedAtUtc = (Get-Date).ToUniversalTime().ToString('o') }
            }
            catch {
                Write-TaggerUiErrorResponse -Response $Response -StatusCode 400 -Message $_.Exception.Message
            }
        }
        'LocalFile' {
            try {
                $requestedPath = [System.Web.HttpUtility]::ParseQueryString($Request.Url.Query)['path']
                if (-not $requestedPath) {
                    Write-TaggerUiErrorResponse -Response $Response -StatusCode 400 -Message "Missing 'path' query parameter."
                    return
                }
                $file = Get-TaggerUiLocalFileBytes -DataHome $DataHome -SessionId $Route.SessionId -RequestedPath $requestedPath
                $Response.StatusCode = 200
                $Response.ContentType = $file.ContentType
                $Response.ContentLength64 = $file.Bytes.Length
                $Response.OutputStream.Write($file.Bytes, 0, $file.Bytes.Length)
            }
            catch {
                Write-TaggerUiErrorResponse -Response $Response -StatusCode 403 -Message $_.Exception.Message
            }
        }
        'SaveManualCover' {
            try {
                $fileName = [System.Web.HttpUtility]::ParseQueryString($Request.Url.Query)['filename']
                if (-not $fileName) {
                    Write-TaggerUiErrorResponse -Response $Response -StatusCode 400 -Message "Missing 'filename' query parameter."
                    return
                }
                $bytes = Read-TaggerUiRequestBodyBytes -Request $Request
                $saved = Save-TaggerUiManualCoverFile -DataHome $DataHome -SessionId $Route.SessionId -FileName $fileName -Bytes $bytes
                Write-TaggerUiJsonResponse -Response $Response -StatusCode 200 -Payload @{
                    url    = $saved.Url
                    width  = $saved.Width
                    height = $saved.Height
                }
            }
            catch {
                Write-TaggerUiErrorResponse -Response $Response -StatusCode 400 -Message $_.Exception.Message
            }
        }
    }
}

$url = "http://localhost:$Port/"
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add($url)
$listener.Start()

Write-Host "Tagger UI running at $url - press Ctrl+C to stop."
if (-not $NoBrowser) {
    Start-Process $url
}

try {
    while ($listener.IsListening) {
        # GetContext() blocks synchronously and, on PowerShell 7 (.NET), can no longer be
        # force-aborted by Ctrl+C - Thread.Abort (what Windows PowerShell 5.1 used for this) was
        # removed in .NET Core/5+. Polling GetContextAsync() in short slices instead gives the
        # engine a safe point after every timeout to act on a pending Ctrl+C, so the server still
        # exits promptly even with no request coming in to unblock a plain GetContext() call.
        $contextTask = $listener.GetContextAsync()
        while ($listener.IsListening -and -not $contextTask.Wait(200)) { }
        if (-not $listener.IsListening) { break }
        $context = $contextTask.GetAwaiter().GetResult()
        $request = $context.Request
        $response = $context.Response

        try {
            $route = Get-TaggerUiApiRoute -Method $request.HttpMethod -Path $request.Url.AbsolutePath
            if ($route) {
                Invoke-TaggerUiApiRequest -Route $route -Request $request -Response $response -DataHome $dataHome
            }
            else {
                $filePath = Resolve-TaggerUiRequestPath -UiRoot $resolvedUiRoot -RequestPath $request.Url.AbsolutePath
                if (-not $filePath) {
                    $response.StatusCode = 404
                    $body = [System.Text.Encoding]::UTF8.GetBytes("Not found: $($request.Url.AbsolutePath)")
                    $response.ContentLength64 = $body.Length
                    $response.OutputStream.Write($body, 0, $body.Length)
                }
                else {
                    $bytes = [System.IO.File]::ReadAllBytes($filePath)
                    $response.ContentType = Get-TaggerUiMimeType -Path $filePath
                    $response.ContentLength64 = $bytes.Length
                    $response.OutputStream.Write($bytes, 0, $bytes.Length)
                }
            }
        }
        catch {
            # A single bad request (file deleted/locked between the existence check and the read,
            # permission error, etc.) must not take down the listener loop for every other tab.
            Write-Warning "Request for '$($request.Url.AbsolutePath)' failed: $($_.Exception.Message)"
            try {
                $response.StatusCode = 500
                $body = [System.Text.Encoding]::UTF8.GetBytes('Internal server error')
                $response.ContentLength64 = $body.Length
                $response.OutputStream.Write($body, 0, $body.Length)
            }
            catch {
                # Response already broken (e.g. client disconnected) - nothing more we can do for it.
            }
        }
        finally {
            $response.OutputStream.Close()
        }
    }
}
finally {
    $listener.Stop()
    $listener.Close()
}
