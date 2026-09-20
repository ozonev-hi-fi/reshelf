#Requires -Version 7.4

Import-Module Pester -MinimumVersion 5.0

BeforeAll {
    Import-Module "$PSScriptRoot/../scripts/common/Tagger.UiServer.psm1" -Force
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
