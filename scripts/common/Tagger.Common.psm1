#Requires -Version 7.0

function Resolve-TaggerDataHome {
    [CmdletBinding()]
    param()

    if ($env:TAGGER_HOME) {
        $dataHome = $env:TAGGER_HOME
    }
    elseif ($env:LOCALAPPDATA) {
        $dataHome = Join-Path $env:LOCALAPPDATA 'Tagger'
    }
    else {
        throw 'Cannot resolve Tagger data home: neither TAGGER_HOME nor LOCALAPPDATA is set.'
    }

    if (Test-Path -LiteralPath $dataHome) {
        if (-not (Test-Path -LiteralPath $dataHome -PathType Container)) {
            throw "Tagger data home '$dataHome' exists but is not a directory."
        }
    }
    else {
        New-Item -ItemType Directory -Path $dataHome -Force | Out-Null
    }

    return (Resolve-Path -LiteralPath $dataHome).Path
}

Export-ModuleMember -Function Resolve-TaggerDataHome
