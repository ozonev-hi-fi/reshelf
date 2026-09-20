#Requires -Version 7.4
[CmdletBinding()]
param(
    [int]$Port = 4173,
    [string]$UiRoot = (Join-Path $PSScriptRoot '..' 'ui')
)

Import-Module (Join-Path $PSScriptRoot 'common' 'Tagger.UiServer.psm1') -Force

$resolvedUiRoot = (Resolve-Path -LiteralPath $UiRoot -ErrorAction SilentlyContinue).Path
if (-not $resolvedUiRoot) {
    throw "UI root '$UiRoot' does not exist. Nothing to serve."
}

$url = "http://localhost:$Port/"
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add($url)
$listener.Start()

Write-Host "Tagger UI running at $url - press Ctrl+C to stop."
Start-Process $url

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        try {
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
