#Requires -Version 7.4

Import-Module Pester -MinimumVersion 5.0

BeforeAll {
    Import-Module "$PSScriptRoot/../scripts/common/Tagger.Discogs.psm1" -Force

    $script:SearchFixture = Get-Content -LiteralPath "$PSScriptRoot/fixtures/discogs-responses/search-response.json" -Raw | ConvertFrom-Json

    function Get-DiscogsUnauthorizedException {
        $httpResponse = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::Unauthorized)
        return [Microsoft.PowerShell.Commands.HttpResponseException]::new('Unauthorized', $httpResponse)
    }

    # Tagger.Discogs.psm1 re-imports Tagger.Common.psm1 internally as part of loading, which turns
    # it into a nested module of Tagger.Discogs - PowerShell then hides its commands from this
    # script's own top-level scope (same gotcha noted in Tagger.EditProposal.Tests.ps1 and
    # Tagger.LossyTracking.Tests.ps1). Routing through Discogs' own module scope, which always has
    # it, avoids that fragility.
    function Get-TestProtectedSecret {
        param(
            [Parameter(Mandatory)]
            [string]$PlainText
        )

        return InModuleScope Tagger.Discogs -Parameters @{ p = $PlainText } {
            param($p)
            Protect-TaggerSecret -PlainText $p
        }
    }
}

Describe 'Get-DiscogsToken' {
    BeforeEach {
        $script:originalToken = $env:DISCOGS_ACCESS_TOKEN
        Remove-Item Env:\DISCOGS_ACCESS_TOKEN -ErrorAction SilentlyContinue
        # A non-existent data home for every test that doesn't care about settings.json, so
        # Get-DiscogsToken's discogsTokenEnvVar/DPAPI lookups never accidentally read this
        # machine's real Tagger data home.
        $script:emptyDataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    }

    AfterEach {
        if ($null -eq $script:originalToken) {
            Remove-Item Env:\DISCOGS_ACCESS_TOKEN -ErrorAction SilentlyContinue
        }
        else {
            $env:DISCOGS_ACCESS_TOKEN = $script:originalToken
        }
    }

    It 'returns the environment variable when set, without reading .env' {
        $env:DISCOGS_ACCESS_TOKEN = 'token-from-env-var'
        $missingEnvFile = Join-Path $TestDrive 'does-not-exist.env'

        $result = Get-DiscogsToken -EnvFilePath $missingEnvFile -DataHome $script:emptyDataHome

        $result | Should -Be 'token-from-env-var'
    }

    It 'falls back to the .env file when the environment variable is unset' {
        $envFile = Join-Path $TestDrive 'fallback.env'
        Set-Content -LiteralPath $envFile -Value @('# comment', '', 'DISCOGS_ACCESS_TOKEN=token-from-file')

        $result = Get-DiscogsToken -EnvFilePath $envFile -DataHome $script:emptyDataHome

        $result | Should -Be 'token-from-file'
    }

    It 'supports the export KEY=VALUE .env convention' {
        $envFile = Join-Path $TestDrive 'export-style.env'
        Set-Content -LiteralPath $envFile -Value @('export DISCOGS_ACCESS_TOKEN=token-from-export')

        $result = Get-DiscogsToken -EnvFilePath $envFile -DataHome $script:emptyDataHome

        $result | Should -Be 'token-from-export'
    }

    It 'strips an inline comment after an unquoted value' {
        $envFile = Join-Path $TestDrive 'inline-comment.env'
        Set-Content -LiteralPath $envFile -Value @('DISCOGS_ACCESS_TOKEN=abc123 # personal token')

        $result = Get-DiscogsToken -EnvFilePath $envFile -DataHome $script:emptyDataHome

        $result | Should -Be 'abc123'
    }

    It 'keeps a hash character inside a quoted value' {
        $envFile = Join-Path $TestDrive 'quoted-with-hash.env'
        Set-Content -LiteralPath $envFile -Value @('DISCOGS_ACCESS_TOKEN="abc#123"')

        $result = Get-DiscogsToken -EnvFilePath $envFile -DataHome $script:emptyDataHome

        $result | Should -Be 'abc#123'
    }

    It 'reads a custom env var name from settings.json''s discogsTokenEnvVar, not DISCOGS_ACCESS_TOKEN' {
        $dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $dataHome -Force | Out-Null
        [pscustomobject]@{ discogsTokenEnvVar = 'MY_DISCOGS_TOKEN' } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $dataHome 'settings.json') -Encoding utf8

        $originalCustomToken = $env:MY_DISCOGS_TOKEN
        $env:MY_DISCOGS_TOKEN = 'token-from-custom-env-var'
        try {
            $missingEnvFile = Join-Path $TestDrive 'does-not-exist-custom.env'
            $result = Get-DiscogsToken -EnvFilePath $missingEnvFile -DataHome $dataHome
            $result | Should -Be 'token-from-custom-env-var'
        }
        finally {
            if ($null -eq $originalCustomToken) { Remove-Item Env:\MY_DISCOGS_TOKEN -ErrorAction SilentlyContinue }
            else { $env:MY_DISCOGS_TOKEN = $originalCustomToken }
        }
    }

    It 'uses a custom discogsTokenEnvVar name for the .env file lookup too' {
        $dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $dataHome -Force | Out-Null
        [pscustomobject]@{ discogsTokenEnvVar = 'MY_DISCOGS_TOKEN' } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $dataHome 'settings.json') -Encoding utf8

        $envFile = Join-Path $TestDrive 'custom-name.env'
        Set-Content -LiteralPath $envFile -Value @('MY_DISCOGS_TOKEN=token-from-custom-file', 'DISCOGS_ACCESS_TOKEN=must-not-be-used')

        $result = Get-DiscogsToken -EnvFilePath $envFile -DataHome $dataHome
        $result | Should -Be 'token-from-custom-file'
    }

    It 'still defaults to DISCOGS_ACCESS_TOKEN when settings.json has no discogsTokenEnvVar key' {
        $dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $dataHome -Force | Out-Null
        [pscustomobject]@{ targetRoot = 'D:\Music' } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $dataHome 'settings.json') -Encoding utf8

        $envFile = Join-Path $TestDrive 'default-name-still-works.env'
        Set-Content -LiteralPath $envFile -Value @('DISCOGS_ACCESS_TOKEN=token-from-default-name')

        $result = Get-DiscogsToken -EnvFilePath $envFile -DataHome $dataHome
        $result | Should -Be 'token-from-default-name'
    }

    It 'throws naming both sources when neither is set' {
        $missingEnvFile = Join-Path $TestDrive 'still-missing.env'
        $emptyDataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))

        { Get-DiscogsToken -EnvFilePath $missingEnvFile -DataHome $emptyDataHome } | Should -Throw -ExpectedMessage '*DISCOGS_ACCESS_TOKEN*'
    }

    It 'falls through to the DPAPI-encrypted settings.json token when no env var and no .env file exist' {
        $missingEnvFile = Join-Path $TestDrive 'no-env-file.env'
        $dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $dataHome -Force | Out-Null
        $settings = [pscustomobject]@{ discogsTokenEncrypted = (Get-TestProtectedSecret -PlainText 'token-from-settings') }
        $settings | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $dataHome 'settings.json') -Encoding utf8

        $result = Get-DiscogsToken -EnvFilePath $missingEnvFile -DataHome $dataHome

        $result | Should -Be 'token-from-settings'
    }

    It 'still prefers the environment variable over an encrypted settings.json token (regression)' {
        $env:DISCOGS_ACCESS_TOKEN = 'token-from-env-var'
        $missingEnvFile = Join-Path $TestDrive 'no-env-file-2.env'
        $dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $dataHome -Force | Out-Null
        $settings = [pscustomobject]@{ discogsTokenEncrypted = (Get-TestProtectedSecret -PlainText 'token-from-settings') }
        $settings | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $dataHome 'settings.json') -Encoding utf8

        $result = Get-DiscogsToken -EnvFilePath $missingEnvFile -DataHome $dataHome

        $result | Should -Be 'token-from-env-var'
    }

    It 'still prefers the .env file over an encrypted settings.json token (regression)' {
        $envFile = Join-Path $TestDrive 'fallback-2.env'
        Set-Content -LiteralPath $envFile -Value @('DISCOGS_ACCESS_TOKEN=token-from-file')
        $dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $dataHome -Force | Out-Null
        $settings = [pscustomobject]@{ discogsTokenEncrypted = (Get-TestProtectedSecret -PlainText 'token-from-settings') }
        $settings | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $dataHome 'settings.json') -Encoding utf8

        $result = Get-DiscogsToken -EnvFilePath $envFile -DataHome $dataHome

        $result | Should -Be 'token-from-file'
    }
}

Describe 'Get-DiscogsQueryPair' {
    It 'sorts keys and passes single values through' {
        $pairs = InModuleScope Tagger.Discogs {
            Get-DiscogsQueryPair -Query @{ q = 'Radiohead'; type = 'release' }
        }

        ($pairs | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join '&' | Should -Be 'q=Radiohead&type=release'
    }

    It 'repeats the key for each element of an array value instead of joining them into one string' {
        $pairs = InModuleScope Tagger.Discogs {
            Get-DiscogsQueryPair -Query @{ format = @('CD', 'Album') }
        }

        $pairs.Count | Should -Be 2
        $pairs[0].Key | Should -Be 'format'
        $pairs[0].Value | Should -Be 'CD'
        $pairs[1].Key | Should -Be 'format'
        $pairs[1].Value | Should -Be 'Album'
    }
}

Describe 'Remove-DiscogsExpiredCache' {
    BeforeEach {
        $script:dataHome = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
        $script:cacheDir = Join-Path $script:dataHome 'cache' 'discogs'
        New-Item -ItemType Directory -Path $script:cacheDir -Force | Out-Null
    }

    It 'is a no-op, not an error, when the cache folder does not exist yet' {
        $emptyDataHome = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())

        { Remove-DiscogsExpiredCache -DataHome $emptyDataHome -CacheTtlDays 30 } | Should -Not -Throw
        Remove-DiscogsExpiredCache -DataHome $emptyDataHome -CacheTtlDays 30 | Should -Be 0
    }

    It 'is a no-op when the cache folder exists but is empty' {
        Remove-DiscogsExpiredCache -DataHome $script:dataHome -CacheTtlDays 30 | Should -Be 0
    }

    It 'leaves a fresh entry alone' {
        $freshFile = Join-Path $script:cacheDir 'fresh.json'
        Set-Content -LiteralPath $freshFile -Value '{"ok":true}' -Encoding utf8

        Remove-DiscogsExpiredCache -DataHome $script:dataHome -CacheTtlDays 30 | Should -Be 0
        Test-Path -LiteralPath $freshFile | Should -Be $true
    }

    It 'physically deletes an entry older than the TTL, not just ignores it' {
        $staleFile = Join-Path $script:cacheDir 'stale.json'
        Set-Content -LiteralPath $staleFile -Value '{"ok":true}' -Encoding utf8
        (Get-Item -LiteralPath $staleFile).LastWriteTime = (Get-Date).AddDays(-31)

        $deletedCount = Remove-DiscogsExpiredCache -DataHome $script:dataHome -CacheTtlDays 30

        $deletedCount | Should -Be 1
        Test-Path -LiteralPath $staleFile | Should -Be $false
    }

    It 'deletes a corrupt entry (fails to parse as JSON) even if it is not yet expired' {
        $corruptFile = Join-Path $script:cacheDir 'corrupt.json'
        Set-Content -LiteralPath $corruptFile -Value '{not valid json' -Encoding utf8

        $deletedCount = Remove-DiscogsExpiredCache -DataHome $script:dataHome -CacheTtlDays 30

        $deletedCount | Should -Be 1
        Test-Path -LiteralPath $corruptFile | Should -Be $false
    }

    It 'deletes only the expired/corrupt entries, leaving fresh ones in place, and returns the correct count' {
        $freshFile = Join-Path $script:cacheDir 'fresh.json'
        Set-Content -LiteralPath $freshFile -Value '{"ok":true}' -Encoding utf8
        $staleFile = Join-Path $script:cacheDir 'stale.json'
        Set-Content -LiteralPath $staleFile -Value '{"ok":true}' -Encoding utf8
        (Get-Item -LiteralPath $staleFile).LastWriteTime = (Get-Date).AddDays(-31)
        $corruptFile = Join-Path $script:cacheDir 'corrupt.json'
        Set-Content -LiteralPath $corruptFile -Value 'not json' -Encoding utf8

        Remove-DiscogsExpiredCache -DataHome $script:dataHome -CacheTtlDays 30 | Should -Be 2

        Test-Path -LiteralPath $freshFile | Should -Be $true
        Test-Path -LiteralPath $staleFile | Should -Be $false
        Test-Path -LiteralPath $corruptFile | Should -Be $false
    }

    It 'warns instead of throwing when a stale entry cannot be deleted (e.g. locked by another process)' {
        $staleFile = Join-Path $script:cacheDir 'locked.json'
        Set-Content -LiteralPath $staleFile -Value '{"ok":true}' -Encoding utf8
        (Get-Item -LiteralPath $staleFile).LastWriteTime = (Get-Date).AddDays(-31)

        $handle = [System.IO.File]::Open($staleFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
        try {
            { Remove-DiscogsExpiredCache -DataHome $script:dataHome -CacheTtlDays 30 -WarningAction SilentlyContinue } | Should -Not -Throw
        }
        finally {
            $handle.Close()
        }
    }
}

Describe 'Invoke-DiscogsRequest' {
    BeforeEach {
        $env:DISCOGS_ACCESS_TOKEN = 'test-token'
        $script:dataHome = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())

        Mock -ModuleName Tagger.Discogs Start-Sleep {}

        InModuleScope Tagger.Discogs {
            $script:DiscogsRequestTimestamps = [System.Collections.Generic.List[datetime]]::new()
            $script:DiscogsLowRemainingSignal = $false
            $script:DiscogsCachePrunedDataHomes = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        }
    }

    It 'physically deletes an expired cache entry from an earlier run on its first call for a data home' {
        Mock -ModuleName Tagger.Discogs Invoke-DiscogsHttpRequest {
            [PSCustomObject]@{ Body = $script:SearchFixture; Headers = @{} }
        }

        $cacheDir = Join-Path $script:dataHome 'cache' 'discogs'
        New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
        $staleFile = Join-Path $cacheDir 'leftover-from-a-past-run.json'
        Set-Content -LiteralPath $staleFile -Value '{"results":[]}' -Encoding utf8
        (Get-Item -LiteralPath $staleFile).LastWriteTime = (Get-Date).AddDays(-31)

        Invoke-DiscogsRequest -Path '/database/search' -Query @{ q = 'Radiohead' } -CacheTtlDays 30 -DataHome $script:dataHome | Out-Null

        Test-Path -LiteralPath $staleFile | Should -Be $false
    }

    It 'prunes only once per data home per process, not on every call' {
        Mock -ModuleName Tagger.Discogs Invoke-DiscogsHttpRequest {
            [PSCustomObject]@{ Body = $script:SearchFixture; Headers = @{} }
        }
        Mock -ModuleName Tagger.Discogs Remove-DiscogsExpiredCache { 0 }

        Invoke-DiscogsRequest -Path '/database/search' -Query @{ q = 'one' } -DataHome $script:dataHome | Out-Null
        Invoke-DiscogsRequest -Path '/database/search' -Query @{ q = 'two' } -DataHome $script:dataHome | Out-Null

        Should -Invoke -ModuleName Tagger.Discogs Remove-DiscogsExpiredCache -Times 1 -Exactly
    }

    It 'calls the HTTP wrapper on a cache miss and writes a cache file' {
        Mock -ModuleName Tagger.Discogs Invoke-DiscogsHttpRequest {
            [PSCustomObject]@{ Body = $script:SearchFixture; Headers = @{} }
        }

        $result = Invoke-DiscogsRequest -Path '/database/search' -Query @{ q = 'Radiohead' } -DataHome $script:dataHome

        $result.results.Count | Should -Be 2
        Should -Invoke -ModuleName Tagger.Discogs Invoke-DiscogsHttpRequest -Times 1 -Exactly
        (Get-ChildItem -Path (Join-Path $script:dataHome 'cache' 'discogs') -Filter '*.json').Count | Should -Be 1
    }

    It 'reads from the cache on a second identical call instead of calling the HTTP wrapper again' {
        Mock -ModuleName Tagger.Discogs Invoke-DiscogsHttpRequest {
            [PSCustomObject]@{ Body = $script:SearchFixture; Headers = @{} }
        }

        Invoke-DiscogsRequest -Path '/database/search' -Query @{ q = 'Radiohead' } -DataHome $script:dataHome | Out-Null
        $second = Invoke-DiscogsRequest -Path '/database/search' -Query @{ q = 'Radiohead' } -DataHome $script:dataHome

        $second.results.Count | Should -Be 2
        Should -Invoke -ModuleName Tagger.Discogs Invoke-DiscogsHttpRequest -Times 1 -Exactly
    }

    It 'bypasses a stale cache file and calls the HTTP wrapper again' {
        Mock -ModuleName Tagger.Discogs Invoke-DiscogsHttpRequest {
            [PSCustomObject]@{ Body = $script:SearchFixture; Headers = @{} }
        }

        Invoke-DiscogsRequest -Path '/database/search' -Query @{ q = 'Radiohead' } -CacheTtlDays 30 -DataHome $script:dataHome | Out-Null

        $cacheFile = Get-ChildItem -Path (Join-Path $script:dataHome 'cache' 'discogs') -Filter '*.json' | Select-Object -First 1
        $cacheFile.LastWriteTime = (Get-Date).AddDays(-2)

        Invoke-DiscogsRequest -Path '/database/search' -Query @{ q = 'Radiohead' } -CacheTtlDays 1 -DataHome $script:dataHome | Out-Null

        Should -Invoke -ModuleName Tagger.Discogs Invoke-DiscogsHttpRequest -Times 2 -Exactly
    }

    It 'throws on a 401 without retrying' {
        Mock -ModuleName Tagger.Discogs Invoke-DiscogsHttpRequest {
            throw Get-DiscogsUnauthorizedException
        }

        { Invoke-DiscogsRequest -Path '/database/search' -Query @{ q = 'Radiohead' } -DataHome $script:dataHome } | Should -Throw -ExpectedMessage '*401*'
        Should -Invoke -ModuleName Tagger.Discogs Invoke-DiscogsHttpRequest -Times 1 -Exactly
    }

    It 'retries a transient failure and returns the result once it succeeds' {
        $script:callCount = 0
        Mock -ModuleName Tagger.Discogs Invoke-DiscogsHttpRequest {
            $script:callCount++
            if ($script:callCount -eq 1) {
                throw 'The operation timed out.'
            }
            [PSCustomObject]@{ Body = $script:SearchFixture; Headers = @{} }
        }

        $result = Invoke-DiscogsRequest -Path '/database/search' -Query @{ q = 'Radiohead' } -DataHome $script:dataHome

        $result.results.Count | Should -Be 2
        Should -Invoke -ModuleName Tagger.Discogs Invoke-DiscogsHttpRequest -Times 2 -Exactly
    }

    It 'throws after exhausting all retry attempts on a persistent transient failure' {
        Mock -ModuleName Tagger.Discogs Invoke-DiscogsHttpRequest {
            throw 'The operation timed out.'
        }

        { Invoke-DiscogsRequest -Path '/database/search' -Query @{ q = 'Radiohead' } -DataHome $script:dataHome } | Should -Throw -ExpectedMessage '*failed after 3 attempts*'
        Should -Invoke -ModuleName Tagger.Discogs Invoke-DiscogsHttpRequest -Times 3 -Exactly
    }

    It 'sleeps once the self-imposed per-minute ceiling is reached' {
        Mock -ModuleName Tagger.Discogs Invoke-DiscogsHttpRequest {
            [PSCustomObject]@{ Body = $script:SearchFixture; Headers = @{} }
        }

        Invoke-DiscogsRequest -Path '/database/search' -Query @{ q = 'one' } -RateLimitPerMinute 2 -DataHome $script:dataHome | Out-Null
        Invoke-DiscogsRequest -Path '/database/search' -Query @{ q = 'two' } -RateLimitPerMinute 2 -DataHome $script:dataHome | Out-Null
        Should -Invoke -ModuleName Tagger.Discogs Start-Sleep -Times 0 -Exactly

        Invoke-DiscogsRequest -Path '/database/search' -Query @{ q = 'three' } -RateLimitPerMinute 2 -DataHome $script:dataHome | Out-Null
        Should -Invoke -ModuleName Tagger.Discogs Start-Sleep -Times 1 -Exactly
    }

    It 'does not crash when RateLimitPerMinute is 0' {
        Mock -ModuleName Tagger.Discogs Invoke-DiscogsHttpRequest {
            [PSCustomObject]@{ Body = $script:SearchFixture; Headers = @{} }
        }

        { Invoke-DiscogsRequest -Path '/database/search' -Query @{ q = 'Radiohead' } -RateLimitPerMinute 0 -DataHome $script:dataHome } | Should -Not -Throw
    }

    It 'proactively throttles the next call after a low X-Discogs-Ratelimit-Remaining response' {
        $script:callCount = 0
        Mock -ModuleName Tagger.Discogs Invoke-DiscogsHttpRequest {
            $script:callCount++
            $headers = if ($script:callCount -eq 1) { @{ 'X-Discogs-Ratelimit-Remaining' = @('1') } } else { @{} }
            [PSCustomObject]@{ Body = $script:SearchFixture; Headers = $headers }
        }

        Invoke-DiscogsRequest -Path '/database/search' -Query @{ q = 'one' } -DataHome $script:dataHome | Out-Null
        Should -Invoke -ModuleName Tagger.Discogs Start-Sleep -Times 0 -Exactly

        Invoke-DiscogsRequest -Path '/database/search' -Query @{ q = 'two' } -DataHome $script:dataHome | Out-Null
        Should -Invoke -ModuleName Tagger.Discogs Start-Sleep -Times 1 -Exactly
    }

    It 'resolves the data home itself when -DataHome is not supplied' {
        $script:originalTaggerHome = $env:TAGGER_HOME
        $env:TAGGER_HOME = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())

        try {
            Mock -ModuleName Tagger.Discogs Invoke-DiscogsHttpRequest {
                [PSCustomObject]@{ Body = $script:SearchFixture; Headers = @{} }
            }

            $result = Invoke-DiscogsRequest -Path '/database/search' -Query @{ q = 'Radiohead' }

            $result.results.Count | Should -Be 2
            (Get-ChildItem -Path (Join-Path $env:TAGGER_HOME 'cache' 'discogs') -Filter '*.json').Count | Should -Be 1
        }
        finally {
            if ($null -eq $script:originalTaggerHome) {
                Remove-Item Env:\TAGGER_HOME -ErrorAction SilentlyContinue
            }
            else {
                $env:TAGGER_HOME = $script:originalTaggerHome
            }
        }
    }

    It 'sends repeated query-string keys for an array-valued query parameter' {
        $capturedUri = $null
        Mock -ModuleName Tagger.Discogs Invoke-DiscogsHttpRequest {
            $script:capturedUri = $Uri
            [PSCustomObject]@{ Body = $script:SearchFixture; Headers = @{} }
        }

        Invoke-DiscogsRequest -Path '/database/search' -Query @{ format = @('CD', 'Album') } -DataHome $script:dataHome | Out-Null

        $script:capturedUri | Should -Be 'https://api.discogs.com/database/search?format=CD&format=Album'
    }
}
