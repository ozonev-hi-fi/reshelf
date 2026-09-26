#Requires -Version 7.4

Import-Module Pester -MinimumVersion 5.0

BeforeAll {
    Import-Module "$PSScriptRoot/../scripts/common/Tagger.UiServer.psm1" -Force
    # Tagger.UiServer.psm1 only re-exports its own functions (see its Export-ModuleMember) - it
    # doesn't re-export Settings' New-TaggerSession/Get-TaggerSession/Set-TaggerSessionStage, which
    # these fixtures need directly, so Settings is imported again here for this script's own scope.
    Import-Module "$PSScriptRoot/../scripts/common/Tagger.Settings.psm1" -Force

    # Builds a real, schema-valid session folder via the same functions the CLI uses, optionally
    # with a proposal.json (and, when requested, a local cover image referenced from it) - so these
    # tests exercise the exact on-disk shape Get-TaggerSession expects, not a hand-rolled fixture.
    function New-UiTestSession {
        param(
            [Parameter(Mandatory)][string]$DataHome,
            [Parameter(Mandatory)][string]$SourceRoot,
            [string]$Stage = 'proposed',
            [switch]$WithProposal,
            [string]$LocalCoverPath,
            [string]$UpdatedAtUtc
        )

        $session = New-TaggerSession -SourceRoot $SourceRoot -DataHome $DataHome
        $sessionDir = Join-Path $DataHome 'sessions' $session.sessionId

        if ($WithProposal) {
            $proposalPath = Join-Path $sessionDir 'proposal.json'
            $candidates = @()
            if ($LocalCoverPath) {
                $candidates = @([pscustomobject]@{ url = $LocalCoverPath; sourceEdition = 'existing (local)'; width = 100; height = 100 })
            }
            $proposal = [pscustomobject]@{
                sessionId = $session.sessionId
                artists   = @([pscustomobject]@{
                        recognizedName = 'Some Artist'
                        releases       = @([pscustomobject]@{
                                stableKey = 'abc123'
                                coverArt  = [pscustomobject]@{ candidates = $candidates }
                            })
                    })
            }
            $proposal | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $proposalPath -Encoding utf8
            Set-TaggerSessionStage -SessionId $session.sessionId -Stage $Stage -ProposalPath $proposalPath -DataHome $DataHome | Out-Null
        }
        else {
            Set-TaggerSessionStage -SessionId $session.sessionId -Stage $Stage -DataHome $DataHome | Out-Null
        }

        if ($UpdatedAtUtc) {
            # Set-TaggerSessionStage always stamps "now" - overwritten directly here so tests can
            # deterministically control ordering instead of racing the real clock.
            $sessionFile = Join-Path $sessionDir 'session.json'
            $onDisk = Get-Content -LiteralPath $sessionFile -Raw | ConvertFrom-Json
            $onDisk.updatedAtUtc = $UpdatedAtUtc
            $onDisk | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $sessionFile -Encoding utf8
        }

        return Get-TaggerSession -SessionId $session.sessionId -DataHome $DataHome
    }
}

Describe 'Resolve-TaggerUiRequestPath' {
    BeforeEach {
        $script:uiRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:uiRoot -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:uiRoot 'nested') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:uiRoot 'index.html') -Value '<html></html>'
        Set-Content -LiteralPath (Join-Path $script:uiRoot 'app.js') -Value 'console.log(1);'
        Set-Content -LiteralPath (Join-Path $script:uiRoot 'nested' 'thing.css') -Value 'body {}'

        $script:outsideDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:outsideDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:outsideDir 'secret.txt') -Value 'top secret'
    }

    It 'maps the root request to index.html' {
        $result = Resolve-TaggerUiRequestPath -UiRoot $script:uiRoot -RequestPath '/'
        $result | Should -Be (Resolve-Path (Join-Path $script:uiRoot 'index.html')).Path
    }

    It 'maps an empty request path to index.html' {
        $result = Resolve-TaggerUiRequestPath -UiRoot $script:uiRoot -RequestPath ''
        $result | Should -Be (Resolve-Path (Join-Path $script:uiRoot 'index.html')).Path
    }

    It 'resolves a top-level file request' {
        $result = Resolve-TaggerUiRequestPath -UiRoot $script:uiRoot -RequestPath '/app.js'
        $result | Should -Be (Resolve-Path (Join-Path $script:uiRoot 'app.js')).Path
    }

    It 'resolves a nested file request' {
        $result = Resolve-TaggerUiRequestPath -UiRoot $script:uiRoot -RequestPath '/nested/thing.css'
        $result | Should -Be (Resolve-Path (Join-Path $script:uiRoot 'nested' 'thing.css')).Path
    }

    It 'returns null for a missing file' {
        $result = Resolve-TaggerUiRequestPath -UiRoot $script:uiRoot -RequestPath '/does-not-exist.html'
        $result | Should -BeNullOrEmpty
    }

    It 'returns null for a path-traversal attempt outside the ui root' {
        $relativeTraversal = "../$([System.IO.Path]::GetFileName($script:outsideDir))/secret.txt"
        $result = Resolve-TaggerUiRequestPath -UiRoot $script:uiRoot -RequestPath "/$relativeTraversal"
        $result | Should -BeNullOrEmpty
    }
}

Describe 'Get-TaggerUiMimeType' {
    It 'maps <Extension> to <Expected>' -ForEach @(
        @{ Extension = 'index.html'; Expected = 'text/html' }
        @{ Extension = 'app.js'; Expected = 'text/javascript' }
        @{ Extension = 'styles.css'; Expected = 'text/css' }
        @{ Extension = 'data.json'; Expected = 'application/json' }
        @{ Extension = 'cover.png'; Expected = 'image/png' }
        @{ Extension = 'cover.jpg'; Expected = 'image/jpeg' }
        @{ Extension = 'cover.svg'; Expected = 'image/svg+xml' }
        @{ Extension = 'unknown.bin'; Expected = 'application/octet-stream' }
    ) {
        Get-TaggerUiMimeType -Path $Extension | Should -Be $Expected
    }
}

Describe 'Get-TaggerUiApiRoute' {
    It 'routes GET /api/current-session' {
        (Get-TaggerUiApiRoute -Method 'GET' -Path '/api/current-session').Action | Should -Be 'CurrentSession'
    }

    It 'routes GET /api/sessions' {
        (Get-TaggerUiApiRoute -Method 'GET' -Path '/api/sessions').Action | Should -Be 'ListSessions'
    }

    It 'routes GET /api/sessions/{id}/proposal to GetProposal with the session id' {
        $route = Get-TaggerUiApiRoute -Method 'GET' -Path '/api/sessions/2026-09-25-0001/proposal'
        $route.Action | Should -Be 'GetProposal'
        $route.SessionId | Should -Be '2026-09-25-0001'
    }

    It 'routes PUT /api/sessions/{id}/proposal to SaveProposal with the session id' {
        $route = Get-TaggerUiApiRoute -Method 'PUT' -Path '/api/sessions/2026-09-25-0001/proposal'
        $route.Action | Should -Be 'SaveProposal'
        $route.SessionId | Should -Be '2026-09-25-0001'
    }

    It 'routes GET /api/sessions/{id}/local-file to LocalFile with the session id' {
        $route = Get-TaggerUiApiRoute -Method 'GET' -Path '/api/sessions/2026-09-25-0001/local-file'
        $route.Action | Should -Be 'LocalFile'
        $route.SessionId | Should -Be '2026-09-25-0001'
    }

    It 'routes POST /api/sessions/{id}/manual-cover to SaveManualCover with the session id' {
        $route = Get-TaggerUiApiRoute -Method 'POST' -Path '/api/sessions/2026-09-25-0001/manual-cover'
        $route.Action | Should -Be 'SaveManualCover'
        $route.SessionId | Should -Be '2026-09-25-0001'
    }

    It 'returns $null for GET on the manual-cover path' {
        Get-TaggerUiApiRoute -Method 'GET' -Path '/api/sessions/2026-09-25-0001/manual-cover' | Should -Be $null
    }

    It 'rejects a session id that does not match the real yyyy-mm-dd-nnnn shape' {
        $route = Get-TaggerUiApiRoute -Method 'GET' -Path '/api/sessions/not-a-real-session-id/proposal'
        $route.Action | Should -Be 'BadRequest'
    }

    It 'falls through to static-file serving for a multi-segment path traversal attempt' {
        # A traversal attempt like "../../secret" contains a slash, so it never matches the single
        # -segment session id pattern at all - it falls through to Resolve-TaggerUiRequestPath's own
        # traversal protection (Resolve-TaggerUiRequestPath tests) rather than reaching this router.
        Get-TaggerUiApiRoute -Method 'GET' -Path '/api/sessions/../../secret/proposal' | Should -Be $null
    }

    It 'returns $null for a plain static-file request, so it falls through to file serving' {
        Get-TaggerUiApiRoute -Method 'GET' -Path '/app.js' | Should -Be $null
    }

    It 'returns $null for an unsupported verb on a known path' {
        Get-TaggerUiApiRoute -Method 'DELETE' -Path '/api/sessions/2026-09-25-0001/proposal' | Should -Be $null
    }
}

Describe 'Get-TaggerUiSessionsSummary / Get-TaggerUiCurrentSession' {
    BeforeEach {
        $script:dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    }

    It 'reports hasProposal true only for a session with an on-disk proposal.json' {
        New-UiTestSession -DataHome $dataHome -SourceRoot 'D:\A' -Stage 'recognized' | Out-Null
        New-UiTestSession -DataHome $dataHome -SourceRoot 'D:\B' -Stage 'proposed' -WithProposal | Out-Null

        $summary = Get-TaggerUiSessionsSummary -DataHome $dataHome
        $summary.Count | Should -Be 2
        ($summary | Where-Object { $_.sourceRoot -eq 'D:\A' }).hasProposal | Should -Be $false
        ($summary | Where-Object { $_.sourceRoot -eq 'D:\B' }).hasProposal | Should -Be $true
    }

    It 'returns an empty list when no sessions exist yet' {
        Get-TaggerUiSessionsSummary -DataHome $dataHome | Should -BeNullOrEmpty
    }

    It 'picks the most recently updated session that has a proposal, ignoring a newer one without' {
        New-UiTestSession -DataHome $dataHome -SourceRoot 'D:\Older' -Stage 'proposed' -WithProposal `
            -UpdatedAtUtc '2026-01-01T00:00:00.000Z' | Out-Null
        New-UiTestSession -DataHome $dataHome -SourceRoot 'D:\NewerNoProposal' -Stage 'recognized' `
            -UpdatedAtUtc '2026-06-01T00:00:00.000Z' | Out-Null

        $current = Get-TaggerUiCurrentSession -DataHome $dataHome
        $current.sourceRoot | Should -Be 'D:\Older'
    }

    It 'returns $null when no session has a proposal yet' {
        New-UiTestSession -DataHome $dataHome -SourceRoot 'D:\A' -Stage 'recognized' | Out-Null
        Get-TaggerUiCurrentSession -DataHome $dataHome | Should -Be $null
    }
}

Describe 'Get-TaggerUiProposalContent / Save-TaggerUiProposalContent' {
    BeforeEach {
        $script:dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:session = New-UiTestSession -DataHome $dataHome -SourceRoot 'D:\A' -Stage 'proposed' -WithProposal
    }

    It 'reads back the exact on-disk proposal.json content' {
        $content = Get-TaggerUiProposalContent -DataHome $dataHome -SessionId $session.sessionId
        ($content | ConvertFrom-Json).artists[0].recognizedName | Should -Be 'Some Artist'
    }

    It 'throws a clear error for a session with no proposal.json' {
        $bare = New-UiTestSession -DataHome $dataHome -SourceRoot 'D:\B' -Stage 'recognized'
        { Get-TaggerUiProposalContent -DataHome $dataHome -SessionId $bare.sessionId } | Should -Throw '*no proposal.json*'
    }

    It 'writes a rolling backup of the previous content before saving new content' {
        $newContent = '{"artists":[]}'
        Save-TaggerUiProposalContent -DataHome $dataHome -SessionId $session.sessionId -Content $newContent

        $backupPath = Join-Path $dataHome 'sessions' $session.sessionId 'proposal.backup.json'
        (Get-Content -LiteralPath $backupPath -Raw | ConvertFrom-Json).artists[0].recognizedName | Should -Be 'Some Artist'
        (Get-Content -LiteralPath $session.proposalPath -Raw | ConvertFrom-Json).artists.Count | Should -Be 0
    }

    It 'rejects an invalid JSON body without touching the existing file' {
        { Save-TaggerUiProposalContent -DataHome $dataHome -SessionId $session.sessionId -Content 'not json' } | Should -Throw '*not valid JSON*'
        (Get-Content -LiteralPath $session.proposalPath -Raw | ConvertFrom-Json).artists[0].recognizedName | Should -Be 'Some Artist'
    }
}

Describe 'Get-TaggerUiLocalFileBytes' {
    BeforeEach {
        $script:dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:coverPath = Join-Path $TestDrive ([guid]::NewGuid().ToString('N') + '.jpg')
        Set-Content -LiteralPath $script:coverPath -Value 'fake-jpeg-bytes' -NoNewline
        $script:session = New-UiTestSession -DataHome $dataHome -SourceRoot 'D:\A' -Stage 'proposed' `
            -WithProposal -LocalCoverPath $script:coverPath
    }

    It 'serves a path the session proposal already names as a cover candidate' {
        $result = Get-TaggerUiLocalFileBytes -DataHome $dataHome -SessionId $session.sessionId -RequestedPath $coverPath
        $result.ContentType | Should -Be 'image/jpeg'
        [System.Text.Encoding]::UTF8.GetString($result.Bytes) | Should -Be 'fake-jpeg-bytes'
    }

    It 'refuses a path that is not one of the session''s known cover candidates' {
        $otherPath = Join-Path $TestDrive 'not-referenced.jpg'
        Set-Content -LiteralPath $otherPath -Value 'nope'
        { Get-TaggerUiLocalFileBytes -DataHome $dataHome -SessionId $session.sessionId -RequestedPath $otherPath } |
            Should -Throw '*not a known local cover file*'
    }

    It 'serves a file under manual-covers even though it is not yet a named proposal.json candidate' {
        # A just-uploaded manual cover lives only in the browser's in-memory proposal until Save,
        # so it can never appear in on-disk proposal.json's candidate list at this point - the
        # manual-covers folder itself is the trust boundary instead, since only
        # Save-TaggerUiManualCoverFile ever writes into it.
        $coversDir = Join-Path $dataHome 'sessions' $session.sessionId 'manual-covers'
        New-Item -ItemType Directory -Path $coversDir -Force | Out-Null
        $manualPath = Join-Path $coversDir 'abc123.jpg'
        Set-Content -LiteralPath $manualPath -Value 'fake-manual-cover-bytes' -NoNewline

        $result = Get-TaggerUiLocalFileBytes -DataHome $dataHome -SessionId $session.sessionId -RequestedPath $manualPath
        [System.Text.Encoding]::UTF8.GetString($result.Bytes) | Should -Be 'fake-manual-cover-bytes'
    }
}

Describe 'Save-TaggerUiManualCoverFile' {
    BeforeAll {
        # A real, minimal 1x1 PNG - needed because the function actually decodes the image to
        # read its dimensions, so arbitrary bytes with a ".png" extension aren't enough.
        $script:onePixelPngBytes = [Convert]::FromBase64String(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=')
    }

    BeforeEach {
        $script:dataHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:session = New-UiTestSession -DataHome $dataHome -SourceRoot 'D:\A' -Stage 'recognized'
    }

    It 'saves a valid upload under manual-covers with its real pixel dimensions' {
        $result = Save-TaggerUiManualCoverFile -DataHome $dataHome -SessionId $session.sessionId `
            -FileName 'front.png' -Bytes $onePixelPngBytes

        $result.Width | Should -Be 1
        $result.Height | Should -Be 1
        $result.Url | Should -Match ([regex]::Escape((Join-Path $dataHome 'sessions' $session.sessionId 'manual-covers')))
        Test-Path -LiteralPath $result.Url -PathType Leaf | Should -Be $true
    }

    It 'rejects an unsupported file extension' {
        { Save-TaggerUiManualCoverFile -DataHome $dataHome -SessionId $session.sessionId `
                -FileName 'front.gif' -Bytes $onePixelPngBytes } | Should -Throw '*Unsupported image type*'
    }

    It 'rejects an empty upload' {
        { Save-TaggerUiManualCoverFile -DataHome $dataHome -SessionId $session.sessionId `
                -FileName 'front.png' -Bytes @() } | Should -Throw '*empty*'
    }

    It 'rejects an upload over the size limit' {
        $oversized = [byte[]]::new(21MB)
        { Save-TaggerUiManualCoverFile -DataHome $dataHome -SessionId $session.sessionId `
                -FileName 'front.png' -Bytes $oversized } | Should -Throw '*20 MB limit*'
    }

    It 'rejects an unknown session id' {
        { Save-TaggerUiManualCoverFile -DataHome $dataHome -SessionId '2026-01-01-9999' `
                -FileName 'front.png' -Bytes $onePixelPngBytes } | Should -Throw '*not found*'
    }

    It 'deletes the written file and throws when the uploaded bytes are not a readable image' {
        $badBytes = [System.Text.Encoding]::UTF8.GetBytes('not actually a png')
        { Save-TaggerUiManualCoverFile -DataHome $dataHome -SessionId $session.sessionId `
                -FileName 'front.png' -Bytes $badBytes } | Should -Throw '*not a readable image*'

        $coversDir = Join-Path $dataHome 'sessions' $session.sessionId 'manual-covers'
        Get-ChildItem -LiteralPath $coversDir -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }
}
