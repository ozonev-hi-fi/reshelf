#Requires -Version 7.4
<#
Shared test-only helpers used by more than one *.Tests.ps1 file. Not part of the shipped product
(scripts/common/) - imported directly by test files that need it.
#>

# plan/11 "-WhatIf ... compare directory listing before/after": one sorted line per file (path,
# size, last write time) under every root, plus a marker for whether each root exists, so any
# created, deleted or rewritten file anywhere shows up as a diff. Files only, not folders: an
# intermediate folder's own LastWriteTimeUtc can tick forward on Windows for reasons that have
# nothing to do with this tool (background indexing, AV scans), so comparing it would make this
# assertion flaky without catching any write this tool didn't already make through one of its
# files. Used by tests/Tagger.Implementation.Tests.ps1 and tests/Tagger.Pipeline.Tests.ps1 (was
# duplicated verbatim in both before this module existed).
function Get-TreeSnapshot {
    param([Parameter(Mandatory)] [string[]]$Path)
    $lines = foreach ($root in $Path) {
        if (-not (Test-Path -LiteralPath $root)) { "[$root] missing"; continue }
        "[$root] exists"
        Get-ChildItem -LiteralPath $root -Recurse -Force -File | ForEach-Object {
            "[$root]$($_.FullName.Substring($root.Length))|$($_.Length)|$($_.LastWriteTimeUtc.Ticks)"
        }
    }
    return @($lines | Sort-Object)
}

Export-ModuleMember -Function Get-TreeSnapshot
