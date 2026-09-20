# Development

## Requirements

- Windows PowerShell 5.1 or PowerShell 7 on Windows.
- Your own exact supported original Crown Siege installation.
- Mono.Cecil 0.11.6 is included in `lib` (the net40 build for Windows PowerShell compatibility).

No game assemblies are committed. The source ZIP and release package include the same installer and patch sources.

## Build and verify

Installing with `Manage-Mod.ps1` builds the patched DLL from the supplied game's original DLL. For development, use a disposable fixture containing a copy of your original DLL; never experiment on your only game copy. Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-Installer.ps1 -OriginalDll "path\to\original\Assembly-CSharp.dll"
```

The fixture has a non-executable CrownSiege.exe marker only, so no game is launched. Tests do not modify the source DLL or your installed game.

## Patch order

1. `src/enable-default-autobuy.ps1`
2. `src/speed-up-skill-tree-zoom.ps1`
3. `src/limit-skill-tree-zoom.ps1`

The installer copies these scripts and Mono.Cecil into a fresh temporary layout and invokes them in that order. Internal backup files in staging allow each step to verify against its predecessor. Do not run the low-level scripts inside an installed game or use them as a replacement for the public installer.

To change parameters or support a new build, update the patch source, original/output hashes, package manifest and tests together. The public installer deliberately has no force/skip-verification option. Do not accept a new hash without inspecting the corresponding methods and running the manual checklist.

## Packaging

The release ZIP contains this repository's installer, source, documentation, tests and licensed Mono.Cecil dependency. Exclude `.git`, test fixtures, all original/patched game DLLs, logs, save files and temporary staging output. Generate `package-hashes.json` from files in `src` and `lib/Mono.Cecil.dll` using SHA-256 after editing patch sources. Test the extracted ZIP before publishing.
