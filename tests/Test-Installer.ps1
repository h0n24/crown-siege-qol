#requires -Version 5.1
param([Parameter(Mandatory=$true)][string]$OriginalDll)
$ErrorActionPreference = 'Stop'
$originalHash = 'EEADF5456180D945C15F2794BDD46266F0D11DFEF4377718EDBEFC3471E1AF9C'
$modHash = '083D0655F8C794887AD0D508F9CD8715670865ED55B07406E95E243B634F801F'
if ((Get-FileHash -LiteralPath $OriginalDll).Hash -ne $originalHash) { throw 'Provide the exact supported original DLL.' }
$package = Split-Path $PSScriptRoot -Parent
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('CrownSiegeQoL-test-' + [Guid]::NewGuid().ToString('N'))
$game = Join-Path $testRoot 'Game with spaces'
$managed = Join-Path $game 'CrownSiege_Data/Managed'
New-Item -ItemType Directory -Path $managed -Force | Out-Null
Set-Content -LiteralPath (Join-Path $game 'CrownSiege.exe') -Value 'Fixture marker, not an executable.'
$dll = Join-Path $managed 'Assembly-CSharp.dll'
$backup = "$dll.CrownSiegeQoL.original"
Copy-Item -LiteralPath $OriginalDll -Destination $dll
$manager = Join-Path $package 'Manage-Mod.ps1'
function AssertHash([string]$Path, [string]$Expected) {
    if ((Get-FileHash -LiteralPath $Path).Hash -ne $Expected) { throw "Hash mismatch: $Path" }
}
function ExpectFailure([scriptblock]$Body) {
    $failed = $false
    try { & $Body | Out-Null } catch { $failed = $true }
    if (!$failed) { throw 'Expected rejection, but the operation succeeded.' }
}
try {
    & $manager -Action Status -GamePath $game
    & $manager -Action Install -GamePath $game
    AssertHash $dll $modHash
    AssertHash $backup $originalHash
    & $manager -Action Install -GamePath $game
    AssertHash $dll $modHash
    & $manager -Action Status -GamePath $game
    & $manager -Action Uninstall -GamePath $game
    AssertHash $dll $originalHash
    & $manager -Action Uninstall -GamePath $game
    Write-Output 'PASS: install, status, repeated install, uninstall, repeated uninstall and original backup.'

    Set-Content -LiteralPath $dll -Value 'Unknown game update'
    $unknownHash = (Get-FileHash -LiteralPath $dll).Hash
    ExpectFailure { & $manager -Action Install -GamePath $game }
    ExpectFailure { & $manager -Action Uninstall -GamePath $game }
    AssertHash $dll $unknownHash
    Write-Output 'PASS: unknown game/other mod rejection without replacement.'

    Copy-Item -LiteralPath $OriginalDll -Destination $dll -Force
    Set-Content -LiteralPath $backup -Value 'Corrupt backup'
    ExpectFailure { & $manager -Action Install -GamePath $game }
    AssertHash $dll $originalHash
    Copy-Item -LiteralPath $OriginalDll -Destination $backup -Force
    Write-Output 'PASS: corrupt backup rejection.'

    $badPackage = Join-Path $testRoot 'Tampered package'
    New-Item -ItemType Directory -Path $badPackage | Out-Null
    foreach ($item in @('Manage-Mod.ps1','package-hashes.json','src','lib')) { Copy-Item -LiteralPath (Join-Path $package $item) -Destination $badPackage -Recurse }
    Add-Content -LiteralPath (Join-Path $badPackage 'src/limit-skill-tree-zoom.ps1') -Value '# modified'
    ExpectFailure { & (Join-Path $badPackage 'Manage-Mod.ps1') -Action Install -GamePath $game }
    AssertHash $dll $originalHash
    Write-Output 'PASS: modified package rejection before game changes.'

    & $manager -Action Install -GamePath $game
    Remove-Item -LiteralPath $backup
    ExpectFailure { & $manager -Action Uninstall -GamePath $game }
    AssertHash $dll $modHash
    Copy-Item -LiteralPath $OriginalDll -Destination $backup
    Set-Content -LiteralPath $backup -Value 'Corrupt backup'
    ExpectFailure { & $manager -Action Uninstall -GamePath $game }
    AssertHash $dll $modHash
    Copy-Item -LiteralPath $OriginalDll -Destination $backup -Force
    & $manager -Action Uninstall -GamePath $game
    AssertHash $dll $originalHash
    Write-Output 'PASS: missing/corrupt uninstall backup rejection and subsequent recovery.'
    Write-Output 'All installer tests passed. The source DLL and installed game were not modified.'
} finally {
    $resolved = [IO.Path]::GetFullPath($testRoot)
    $prefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (!$resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -or !(Split-Path $resolved -Leaf).StartsWith('CrownSiegeQoL-test-')) { throw 'Unexpected test path; refusing cleanup.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
