#Requires -Version 7.4

Import-Module Pester -MinimumVersion 5.0

BeforeAll {
    $script:FixturesDir = "$PSScriptRoot/fixtures/schema-examples"
}

Describe 'Schema examples validate against their schema' {
    It 'recognition-example.json validates against recognition.schema.json' {
        Test-Json -LiteralPath "$FixturesDir/recognition-example.json" -SchemaFile "$PSScriptRoot/../schemas/recognition.schema.json" | Should -Be $true
    }

    It 'proposal-example.json validates against proposal.schema.json' {
        Test-Json -LiteralPath "$FixturesDir/proposal-example.json" -SchemaFile "$PSScriptRoot/../schemas/proposal.schema.json" | Should -Be $true
    }

    It 'settings-example.json validates against settings.schema.json' {
        Test-Json -LiteralPath "$FixturesDir/settings-example.json" -SchemaFile "$PSScriptRoot/../schemas/settings.schema.json" | Should -Be $true
    }

    It 'session-example.json validates against session.schema.json' {
        Test-Json -LiteralPath "$FixturesDir/session-example.json" -SchemaFile "$PSScriptRoot/../schemas/session.schema.json" | Should -Be $true
    }

    It 'lossy-tracking-example.json validates against lossy-tracking.schema.json' {
        Test-Json -LiteralPath "$FixturesDir/lossy-tracking-example.json" -SchemaFile "$PSScriptRoot/../schemas/lossy-tracking.schema.json" | Should -Be $true
    }

    It 'overrides-example.json validates against overrides.schema.json' {
        Test-Json -LiteralPath "$FixturesDir/overrides-example.json" -SchemaFile "$PSScriptRoot/../schemas/overrides.schema.json" | Should -Be $true
    }
}

Describe 'recognition.json can be extended into a valid proposal.json' {
    It 'validates after adding the proposal-only fields' {
        $recognition = Get-Content -Raw "$FixturesDir/recognition-example.json" | ConvertFrom-Json

        $release = $recognition.artists[0].releases[0]
        $track = $release.tracks[0]

        $track | Add-Member -NotePropertyName proposedFileName -NotePropertyValue '01 Poke Chop Sandwich.flac'
        $track | Add-Member -NotePropertyName proposedDiscNumber -NotePropertyValue 1
        $track | Add-Member -NotePropertyName proposedTrackNumber -NotePropertyValue 1
        $track | Add-Member -NotePropertyName proposedTitle -NotePropertyValue 'Poke Chop Sandwich'
        $track | Add-Member -NotePropertyName tags -NotePropertyValue ([pscustomobject]@{
                artist      = 'ZZ Top'
                albumArtist = 'ZZ Top'
                album       = 'XXX'
                year        = 1999
                discNumber  = 1
                track       = 1
                title       = 'Poke Chop Sandwich'
            })

        $release | Add-Member -NotePropertyName discogsMatch -NotePropertyValue ([pscustomobject]@{
                status             = 'matched'
                selectedReleaseId  = 123456
                candidates         = @(
                    [pscustomobject]@{ releaseId = 123456; title = 'XXX'; year = 1999; format = 'CD, Album'; score = 0.97 }
                )
            })
        $release | Add-Member -NotePropertyName proposed -NotePropertyValue ([pscustomobject]@{
                artistFolderName  = 'ZZ Top'
                releaseFolderName = '1999 XXX'
                year              = 1999
                album             = 'XXX'
            })
        $release | Add-Member -NotePropertyName coverArt -NotePropertyValue ([pscustomobject]@{
                candidates         = @(
                    [pscustomobject]@{ url = 'https://example.com/cover.jpg'; sourceEdition = 'US CD'; width = 1200; height = 1200 }
                )
                chosenCandidateUrl = 'https://example.com/cover.jpg'
                targetMaxDimension = 600
            })
        $release | Add-Member -NotePropertyName lossyLossless -NotePropertyValue ([pscustomobject]@{ isLossy = $false; action = 'none' })
        $release | Add-Member -NotePropertyName targetAction -NotePropertyValue 'create-new'
        $release | Add-Member -NotePropertyName humanReview -NotePropertyValue ([pscustomobject]@{ required = $false; resolved = $true; notes = '' })

        $json = $recognition | ConvertTo-Json -Depth 20
        Test-Json -Json $json -SchemaFile "$PSScriptRoot/../schemas/proposal.schema.json" | Should -Be $true
    }
}
