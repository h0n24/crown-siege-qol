#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Install','Uninstall','Status')][string]$Action = 'Install',
    [string]$GamePath
)
$ErrorActionPreference = 'Stop'
$originalHash = 'EEADF5456180D945C15F2794BDD46266F0D11DFEF4377718EDBEFC3471E1AF9C'
$installedHash = '083D0655F8C794887AD0D508F9CD8715670865ED55B07406E95E243B634F801F'
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
if (!$GamePath) {
    foreach ($candidate in @($PSScriptRoot, (Split-Path $PSScriptRoot -Parent), (Get-Location).Path)) {
        if (Test-Path -LiteralPath (Join-Path $candidate 'CrownSiege.exe')) { $GamePath = $candidate; break }
    }
}
if (!$GamePath) { $GamePath = (Read-Host 'Enter the Crown Siege folder containing CrownSiege.exe').Trim('"') }
$GamePath = (Resolve-Path -LiteralPath $GamePath).Path
$target = Join-Path $GamePath 'CrownSiege_Data/Managed/Assembly-CSharp.dll'
$backup = "$target.CrownSiegeQoL.original"
if (!(Test-Path -LiteralPath (Join-Path $GamePath 'CrownSiege.exe')) -or !(Test-Path -LiteralPath $target)) {
    throw 'This is not a Crown Siege installation. Select the folder containing CrownSiege.exe.'
}
$currentHash = Hash $target
if ($Action -eq 'Status') {
    if ($currentHash -eq $installedHash) { Write-Output 'Crown Siege QoL 1.0.0 is installed.' }
    elseif ($currentHash -eq $originalHash) { Write-Output 'Supported original game detected. Mod is not installed.' }
    else { Write-Output 'Unknown game library. This version or another modification is not supported.' }
    if (Test-Path -LiteralPath $backup) {
        if ((Hash $backup) -eq $originalHash) { Write-Output 'Verified original backup available.' }
        else { Write-Output 'WARNING: backup does not match the supported original.' }
    } else { Write-Output 'No installer backup found.' }
    return
}
if (Get-Process CrownSiege -ErrorAction SilentlyContinue) { throw 'Close Crown Siege before changing its files.' }
if ($Action -eq 'Install' -and $currentHash -eq $installedHash) {
    Write-Output 'Crown Siege QoL 1.0.0 is already installed. No changes made.'; return
}
if ($Action -eq 'Uninstall' -and $currentHash -eq $originalHash) {
    Write-Output 'The original game is already restored. No changes made.'; return
}
if ($currentHash -ne $originalHash -and $currentHash -ne $installedHash) {
    throw 'Unsupported game library. Nothing changed. This installer requires the exact supported build without other DLL patches.'
}
if (Test-Path -LiteralPath $backup) {
    if ((Hash $backup) -ne $originalHash) { throw 'Backup verification failed. Nothing changed; preserve your files and reinstall a clean supported game build.' }
}
$stageRoot = Join-Path ([IO.Path]::GetTempPath()) ('CrownSiegeQoL-' + [Guid]::NewGuid().ToString('N'))
$stageFile = "$target.CrownSiegeQoL.$([Guid]::NewGuid().ToString('N')).tmp"
try {
    if ($Action -eq 'Install') {
        $manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'package-hashes.json') -Raw | ConvertFrom-Json
        foreach ($entry in $manifest.PSObject.Properties) {
            if ((Hash (Join-Path $PSScriptRoot $entry.Name)) -ne $entry.Value) { throw "Package verification failed: $($entry.Name). Download and extract a fresh copy." }
        }
        $stageManaged = Join-Path $stageRoot 'CrownSiege_Data/Managed'
        New-Item -ItemType Directory -Path $stageManaged -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'src') -Destination $stageRoot -Recurse
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'lib') -Destination $stageRoot -Recurse
        $generated = Join-Path $stageManaged 'Assembly-CSharp.dll'
        Copy-Item -LiteralPath $target -Destination $generated
        & (Join-Path $stageRoot 'src/enable-default-autobuy.ps1') | Out-Null
        & (Join-Path $stageRoot 'src/speed-up-skill-tree-zoom.ps1') | Out-Null
        & (Join-Path $stageRoot 'src/limit-skill-tree-zoom.ps1') | Out-Null
        if ((Hash $generated) -ne $installedHash) { throw 'Generated library verification failed. The game was not changed.' }
        if (!(Test-Path -LiteralPath $backup)) { Copy-Item -LiteralPath $target -Destination $backup }
        if ((Hash $backup) -ne $originalHash) { throw 'Original backup verification failed.' }
        Copy-Item -LiteralPath $generated -Destination $stageFile
        $expectedHash = $installedHash
    } else {
        if (!(Test-Path -LiteralPath $backup)) { throw 'Original backup is missing. Use the game platform file verification/reinstall feature to restore the game.' }
        Copy-Item -LiteralPath $backup -Destination $stageFile
        $expectedHash = $originalHash
    }
    if ((Hash $stageFile) -ne $expectedHash) { throw 'Staged file verification failed.' }
    if ((Hash $target) -ne $currentHash) { throw 'Game library changed during installation. Nothing replaced.' }
    if (Get-Process CrownSiege -ErrorAction SilentlyContinue) { throw 'The game started during installation. Close it and try again.' }
    # Same-directory atomic replacement; the original backup is retained.
    [IO.File]::Replace($stageFile, $target, [System.Management.Automation.Language.NullString]::Value)
    if ((Hash $target) -ne $expectedHash) { throw 'Unexpected post-install hash. Restore the verified original backup.' }
    Write-Output "$Action completed successfully. Start Crown Siege normally."
} finally {
    if (Test-Path -LiteralPath $stageFile) { Remove-Item -LiteralPath $stageFile -Force }
    if (Test-Path -LiteralPath $stageRoot) {
        $resolvedStage = [IO.Path]::GetFullPath($stageRoot)
        $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
        if (!$resolvedStage.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -or !(Split-Path $resolvedStage -Leaf).StartsWith('CrownSiegeQoL-')) { throw 'Unexpected staging path; refusing cleanup.' }
        try { Remove-Item -LiteralPath $resolvedStage -Recurse -Force } catch { Write-Warning "Could not fully clean temporary staging folder: $resolvedStage" }
    }
}
