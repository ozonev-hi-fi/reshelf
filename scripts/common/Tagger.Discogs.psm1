#Requires -Version 7.4

Import-Module (Join-Path $PSScriptRoot 'Tagger.Common.psm1') -Force

$script:DiscogsRequestTimestamps = [System.Collections.Generic.List[datetime]]::new()
$script:DiscogsLowRemainingSignal = $false

function Get-DiscogsToken {
    [CmdletBinding()]
    param(
        [string]$EnvFilePath = (Join-Path $PSScriptRoot '..' '..' '.env'),

        [string]$DataHome
    )

    if ($env:DISCOGS_ACCESS_TOKEN) {
        return $env:DISCOGS_ACCESS_TOKEN
    }

    if (Test-Path -LiteralPath $EnvFilePath -PathType Leaf) {
        foreach ($line in Get-Content -LiteralPath $EnvFilePath) {
            $trimmed = $line.Trim()
            if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }
            if ($trimmed -match '^(?:export\s+)?DISCOGS_ACCESS_TOKEN\s*=\s*(.+)$') {
                $rawValue = $Matches[1].Trim()

                if ($rawValue.Length -ge 2 -and ($rawValue[0] -eq '"' -or $rawValue[0] -eq "'")) {
                    $quoteChar = $rawValue[0]
                    $endIndex = $rawValue.IndexOf($quoteChar, 1)
                    $value = if ($endIndex -gt 0) { $rawValue.Substring(1, $endIndex - 1) } else { $rawValue.Trim($quoteChar) }
                }
                else {
                    $hashIndex = $rawValue.IndexOf('#')
                    if ($hashIndex -ge 0) {
                        $rawValue = $rawValue.Substring(0, $hashIndex).TrimEnd()
                    }
                    $value = $rawValue
                }

                if ($value) { return $value }
            }
        }
    }

    # Third, friendlier fallback: a token entered via 'settings init' or 'settings set-token' and
    # stored DPAPI-encrypted in settings.json. Checked last so nothing already working today (the
    # env var or .env file) changes priority.
    if (-not $DataHome) { $DataHome = Resolve-TaggerDataHome }
    $settingsPath = Join-Path $DataHome 'settings.json'
    if (Test-Path -LiteralPath $settingsPath -PathType Leaf) {
        $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
        if ($settings.discogsTokenEncrypted) {
            return Unprotect-TaggerSecret -EncryptedText $settings.discogsTokenEncrypted
        }
    }

    throw "Discogs access token not found. Checked environment variable 'DISCOGS_ACCESS_TOKEN', .env file at '$EnvFilePath', and settings.json's discogsTokenEncrypted at '$settingsPath'. Set one of these, or run 'Tagger.ps1 settings set-token'."
}

function Get-DiscogsQueryPair {
    [CmdletBinding()]
    param(
        [hashtable]$Query = @{}
    )

    foreach ($key in ($Query.Keys | Sort-Object)) {
        $values = $Query[$key]
        if (($values -is [System.Collections.IEnumerable]) -and ($values -isnot [string])) {
            foreach ($value in $values) {
                [PSCustomObject]@{ Key = $key; Value = [string]$value }
            }
        }
        else {
            [PSCustomObject]@{ Key = $key; Value = [string]$values }
        }
    }
}

function Get-DiscogsCacheKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [hashtable]$Query = @{}
    )

    $pairs = @(Get-DiscogsQueryPair -Query $Query)
    $canonical = "${Path}?" + (($pairs | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join '&')
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($canonical)
    $hashBytes = [System.Security.Cryptography.SHA256]::HashData($bytes)

    return [System.Convert]::ToHexString($hashBytes).ToLowerInvariant()
}

function Wait-DiscogsRateLimit {
    [CmdletBinding()]
    param(
        [int]$RateLimitPerMinute = 55
    )

    $now = Get-Date
    $windowStart = $now.AddSeconds(-60)
    $script:DiscogsRequestTimestamps.RemoveAll([Predicate[datetime]]{ param($t) $t -le $windowStart }) | Out-Null

    $ceilingReached = $script:DiscogsRequestTimestamps.Count -ge $RateLimitPerMinute
    $shouldThrottle = $ceilingReached -or $script:DiscogsLowRemainingSignal
    $script:DiscogsLowRemainingSignal = $false

    if ($shouldThrottle -and $script:DiscogsRequestTimestamps.Count -gt 0) {
        $oldest = $script:DiscogsRequestTimestamps[0]
        $sleepSeconds = 60 - ($now - $oldest).TotalSeconds
        if ($sleepSeconds -gt 0) {
            Start-Sleep -Seconds $sleepSeconds
        }
    }
}

function Invoke-DiscogsHttpRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Uri,

        [Parameter(Mandatory)]
        [hashtable]$Headers
    )

    $responseHeaders = $null
    $body = Invoke-RestMethod -Uri $Uri -Headers $Headers -Method Get -ResponseHeadersVariable responseHeaders
    return [PSCustomObject]@{
        Body    = $body
        Headers = $responseHeaders
    }
}

function Invoke-DiscogsRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [hashtable]$Query = @{},

        [int]$CacheTtlDays = 30,

        [int]$RateLimitPerMinute = 55,

        [string]$DataHome
    )

    if (-not $DataHome) {
        $DataHome = Resolve-TaggerDataHome
    }

    $cacheKey = Get-DiscogsCacheKey -Path $Path -Query $Query
    $cacheDir = Join-Path $DataHome 'cache' 'discogs'
    $cacheFile = Join-Path $cacheDir "$cacheKey.json"

    $cacheItem = Get-Item -LiteralPath $cacheFile -ErrorAction SilentlyContinue
    if ($cacheItem) {
        $age = (Get-Date) - $cacheItem.LastWriteTime
        if ($age.TotalDays -lt $CacheTtlDays) {
            return Get-Content -LiteralPath $cacheFile -Raw | ConvertFrom-Json
        }
    }

    $token = Get-DiscogsToken
    $uri = "https://api.discogs.com$Path"
    if ($Query.Count -gt 0) {
        $pairs = @(Get-DiscogsQueryPair -Query $Query)
        $queryString = ($pairs | ForEach-Object {
                "$([System.Uri]::EscapeDataString($_.Key))=$([System.Uri]::EscapeDataString($_.Value))"
            }) -join '&'
        $uri = "${uri}?$queryString"
    }

    $headers = @{
        'Authorization' = "Discogs token=$token"
        'User-Agent'    = 'TaggerPersonalOrganizer/0.1 (+local)'
    }

    $maxAttempts = 3
    $backoffSeconds = @(1, 2, 4)
    $result = $null

    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        Wait-DiscogsRateLimit -RateLimitPerMinute $RateLimitPerMinute

        try {
            $result = Invoke-DiscogsHttpRequest -Uri $uri -Headers $headers
            $script:DiscogsRequestTimestamps.Add((Get-Date))
            break
        }
        catch {
            $script:DiscogsRequestTimestamps.Add((Get-Date))

            $statusCode = $null
            if ($_.Exception.Response) {
                try { $statusCode = [int]$_.Exception.Response.StatusCode } catch { $statusCode = $null }
            }

            if ($statusCode -eq 401) {
                throw "Discogs request to '$Path' failed with 401 Unauthorized. Check DISCOGS_ACCESS_TOKEN."
            }

            if ($attempt -eq $maxAttempts) {
                throw "Discogs request to '$Path' failed after $maxAttempts attempts: $($_.Exception.Message)"
            }

            Start-Sleep -Seconds $backoffSeconds[$attempt - 1]
        }
    }

    try {
        $remainingValues = $result.Headers['X-Discogs-Ratelimit-Remaining']
        if ($remainingValues) {
            $remaining = [int]($remainingValues | Select-Object -First 1)
            if ($remaining -le 2) {
                $script:DiscogsLowRemainingSignal = $true
            }
        }
    }
    catch {
        # Header parsing is best-effort; never let it fail an otherwise successful request.
        Write-Verbose "Could not parse X-Discogs-Ratelimit-Remaining header: $($_.Exception.Message)"
    }

    if (-not (Test-Path -LiteralPath $cacheDir)) {
        New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
    }
    $result.Body | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $cacheFile -Encoding utf8

    return $result.Body
}

Export-ModuleMember -Function Get-DiscogsToken, Invoke-DiscogsRequest
