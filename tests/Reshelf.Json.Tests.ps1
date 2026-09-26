#Requires -Version 7.4

Import-Module Pester -MinimumVersion 5.0

BeforeAll {
    Import-Module "$PSScriptRoot/../scripts/common/Reshelf.Json.psm1" -Force
}

Describe 'Test-ReshelfJson' {
    It 'validates a well-formed file via -Path' {
        $path = "$PSScriptRoot/fixtures/schema-examples/settings-example.json"
        Test-ReshelfJson -SchemaName settings -Path $path | Should -Be $true
    }

    It 'validates a well-formed in-memory object via -InputObject' {
        $obj = Get-Content -Raw "$PSScriptRoot/fixtures/schema-examples/settings-example.json" | ConvertFrom-Json
        Test-ReshelfJson -SchemaName settings -InputObject $obj | Should -Be $true
    }

    It 'validates a well-formed raw string via -Json' {
        $json = Get-Content -Raw "$PSScriptRoot/fixtures/schema-examples/settings-example.json"
        Test-ReshelfJson -SchemaName settings -Json $json | Should -Be $true
    }

    It 'returns false for a document missing a required field' {
        $obj = Get-Content -Raw "$PSScriptRoot/fixtures/schema-examples/settings-example.json" | ConvertFrom-Json
        $obj.PSObject.Properties.Remove('targetRoot')
        Test-ReshelfJson -SchemaName settings -InputObject $obj | Should -Be $false
    }

    It 'throws when the schema name does not resolve to a file' {
        { Test-ReshelfJson -SchemaName 'does-not-exist' -Json '{}' } | Should -Throw
    }

    It 'validates a single-element array via -InputObject without collapsing it to an object' {
        $entries = Get-Content -Raw "$PSScriptRoot/fixtures/schema-examples/lossy-tracking-example.json" | ConvertFrom-Json
        Test-ReshelfJson -SchemaName lossy-tracking -InputObject @($entries[0]) | Should -Be $true
    }

    It 'validates an empty array via -InputObject' {
        Test-ReshelfJson -SchemaName lossy-tracking -InputObject @() | Should -Be $true
    }
}

Describe 'Set-ReshelfJsonFile' {
    It 'writes the file and returns its path when the document is valid' {
        $settings = Get-Content -Raw "$PSScriptRoot/fixtures/schema-examples/settings-example.json" | ConvertFrom-Json
        $targetPath = Join-Path $TestDrive 'settings.json'

        $result = Set-ReshelfJsonFile -Path $targetPath -InputObject $settings -SchemaName settings

        $result | Should -Be $targetPath
        $targetPath | Should -Exist
    }

    It 'throws and does not create the file when the document is invalid' {
        $settings = Get-Content -Raw "$PSScriptRoot/fixtures/schema-examples/settings-example.json" | ConvertFrom-Json
        $settings.PSObject.Properties.Remove('targetRoot')
        $targetPath = Join-Path $TestDrive 'invalid-settings.json'

        { Set-ReshelfJsonFile -Path $targetPath -InputObject $settings -SchemaName settings } | Should -Throw
        $targetPath | Should -Not -Exist
    }

    It 'creates a missing parent directory' {
        $settings = Get-Content -Raw "$PSScriptRoot/fixtures/schema-examples/settings-example.json" | ConvertFrom-Json
        $targetPath = Join-Path $TestDrive 'nested/dir/settings.json'

        Set-ReshelfJsonFile -Path $targetPath -InputObject $settings -SchemaName settings | Out-Null

        $targetPath | Should -Exist
    }

    It 'writes a single-element array as a JSON array, not a bare object' {
        $entries = Get-Content -Raw "$PSScriptRoot/fixtures/schema-examples/lossy-tracking-example.json" | ConvertFrom-Json
        $targetPath = Join-Path $TestDrive 'lossy-tracking.json'

        Set-ReshelfJsonFile -Path $targetPath -InputObject @($entries[0]) -SchemaName lossy-tracking | Out-Null

        (Get-Content -Raw $targetPath).TrimStart().StartsWith('[') | Should -Be $true
    }
}
