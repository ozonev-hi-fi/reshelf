#Requires -Version 7.4

$script:TaggerUiMimeTypes = @{
    '.html' = 'text/html'
    '.js'   = 'text/javascript'
    '.css'  = 'text/css'
    '.json' = 'application/json'
    '.png'  = 'image/png'
    '.jpg'  = 'image/jpeg'
    '.jpeg' = 'image/jpeg'
    '.svg'  = 'image/svg+xml'
    '.ico'  = 'image/x-icon'
}

function Resolve-TaggerUiRequestPath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$UiRoot,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$RequestPath
    )

    $resolvedUiRoot = (Resolve-Path -LiteralPath $UiRoot).Path
    $relativePath = $RequestPath.TrimStart('/')
    if ([string]::IsNullOrEmpty($relativePath)) {
        $relativePath = 'index.html'
    }

    $candidatePath = Join-Path $resolvedUiRoot $relativePath

    if (-not (Test-Path -LiteralPath $candidatePath -PathType Leaf)) {
        return $null
    }

    $resolvedCandidate = (Resolve-Path -LiteralPath $candidatePath).Path
    $rootWithSeparator = $resolvedUiRoot.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if (-not $resolvedCandidate.StartsWith($rootWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $null
    }

    return $resolvedCandidate
}

function Get-TaggerUiMimeType {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    if ($script:TaggerUiMimeTypes.ContainsKey($extension)) {
        return $script:TaggerUiMimeTypes[$extension]
    }

    return 'application/octet-stream'
}

Export-ModuleMember -Function Resolve-TaggerUiRequestPath, Get-TaggerUiMimeType
