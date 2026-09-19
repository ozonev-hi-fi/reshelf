#Requires -Version 7.4
# Test-Json's -LiteralPath and full JSON Schema 2020-12 support (used by every
# schemas/*.schema.json file) were only added in PowerShell 7.4.

function Resolve-TaggerSchemaPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SchemaName
    )

    $schemaPath = Join-Path $PSScriptRoot '..' '..' 'schemas' "$SchemaName.schema.json"
    if (-not (Test-Path -LiteralPath $schemaPath -PathType Leaf)) {
        throw "Schema '$SchemaName' not found at '$schemaPath'."
    }

    return (Resolve-Path -LiteralPath $schemaPath).Path
}

function Test-TaggerJson {
    [CmdletBinding(DefaultParameterSetName = 'ByPath')]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$SchemaName,

        [Parameter(Mandatory, ParameterSetName = 'ByPath')]
        [string]$Path,

        [Parameter(Mandatory, ParameterSetName = 'ByInputObject')]
        [object]$InputObject,

        [Parameter(Mandatory, ParameterSetName = 'ByJson')]
        [string]$Json,

        [int]$Depth = 10
    )

    $schemaFile = Resolve-TaggerSchemaPath -SchemaName $SchemaName

    switch ($PSCmdlet.ParameterSetName) {
        'ByPath' { return Test-Json -LiteralPath $Path -SchemaFile $schemaFile }
        'ByJson' { return Test-Json -Json $Json -SchemaFile $schemaFile }
        'ByInputObject' {
            $json = ConvertTo-Json -InputObject $InputObject -Depth $Depth
            return Test-Json -Json $json -SchemaFile $schemaFile
        }
    }
}

function Set-TaggerJsonFile {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string]$SchemaName,

        [int]$Depth = 10
    )

    $json = ConvertTo-Json -InputObject $InputObject -Depth $Depth
    if (-not (Test-TaggerJson -SchemaName $SchemaName -Json $json -ErrorAction SilentlyContinue)) {
        throw "Document for '$Path' does not match schema '$SchemaName'."
    }

    $parentDir = Split-Path -Path $Path -Parent
    if ($parentDir -and -not (Test-Path -LiteralPath $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    Set-Content -LiteralPath $Path -Value $json -Encoding utf8
    return $Path
}

Export-ModuleMember -Function Test-TaggerJson, Set-TaggerJsonFile
