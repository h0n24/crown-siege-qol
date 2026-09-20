# Crown Siege QoL

A small Windows mod for Crown Siege: automatic troop purchases from the start of each battle, faster skill-tree zoom, and a more comfortable maximum magnification.

## What changes

| Feature | Behavior |
| --- | --- |
| Automatic purchases | The Q, W, E and R troop slots start with their purchase locks enabled when a level starts or restarts. No long key hold is needed. |
| Faster skill-tree zoom | Mouse-wheel sensitivity is 12 times the original 60-FPS baseline. Each wheel step has the same strength regardless of frame rate. |
| Maximum magnification | The closest view is limited to approximately the preferred reference view, 17% back from the original zoom-in end of the slider. |

Purchases still use the game's normal prices, available gold and repeat timing. Pressing a troop key retains the game's manual unlock behavior. End-of-battle cleanup remains in place. The zoom cap applies to both the wheel and the slider. Maximum zoom-out and the battle camera are unchanged.

## Download and install

1. Download **CrownSiegeQoL-1.0.0.zip** from [Releases](https://github.com/h0n24/crown-siege-qol/releases).
2. Close Crown Siege completely.
3. Extract the ZIP to a normal folder. Do not run it from inside the ZIP viewer.
4. Double-click **Install.cmd**. If prompted, enter the game folder containing `CrownSiege.exe`.
5. Wait for **Install completed successfully**, then start the game normally.

Windows PowerShell 5.1 is included with supported Windows installations. No mod loader, .NET SDK, separate dependency download or administrator account is required when your account can write to the game folder. The installer works offline.

If you extract the package inside the game folder, the installer can detect the game in its parent folder. Otherwise, it asks for the location. It does not scan your drives.

Advanced path selection:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Manage-Mod.ps1 -Action Install -GamePath "D:\Games\Crown Siege"
```

The execution-policy option applies only to that PowerShell process; it does not change your system policy.

## Status and removal

Run **Status.cmd** to identify the installed library and check the backup.

To remove the mod, close the game and run **Uninstall.cmd**, selecting the same game folder. The installer restores the verified original library and retains the backup. Save files are not modified by the installer.

The backup is stored next to the game library:

```text
CrownSiege_Data\Managed\Assembly-CSharp.dll.CrownSiegeQoL.original
```

Repeated install and uninstall operations are safe no-ops when the requested state is already present.

## Compatibility

- Windows, Unity Mono build of Crown Siege displaying **v1.0.0_c** in the reference screenshots.
- Compatibility is determined by the original `Assembly-CSharp.dll` SHA-256, not the displayed version alone:

```text
EEADF5456180D945C15F2794BDD46266F0D11DFEF4377718EDBEFC3471E1AF9C
```

The installer refuses unknown builds and other modifications to this DLL. Updates and game-file verification can replace the mod; a newer game build needs a compatible mod release. Do not restore an old backup over an updated game. Game libraries are not included in this repository or the release ZIP.

## Troubleshooting

- **Unsupported game library:** your build differs or another DLL mod is installed. Do not rename an unknown file to bypass the checks. Restore the game through your platform, then use a matching release.
- **Package verification failed:** extract a fresh release ZIP. Keep `src`, `lib` and `package-hashes.json` together with the installer.
- **Close Crown Siege:** fully exit the game, then retry.
- **Access denied:** choose the correct game folder and ensure your account can write there. Do not disable antivirus protection.
- **Backup missing on uninstall:** restore the game with your platform's file verification or reinstall feature.
- **No visible change:** restart the game after installing and run Status.cmd. Zoom changes apply to the skill tree, not battles.

## Verification status

The author confirmed the faster zoom felt good in-game. The final zoom cap is an estimate from a supplied screenshot and still needs visual confirmation. Automatic purchase locks have been inspected in the game code, but a complete manual gameplay regression has not been recorded.

The release is checked against the exact supported original DLL. See [testing](docs/TESTING.md) for automated coverage and the manual checklist, and [technical notes](docs/TECHNICAL.md) for implementation details. Please report the game version, installer message and reproduction steps in [Issues](https://github.com/h0n24/crown-siege-qol/issues); do not upload your game DLL or save files.

## Source and license

The patch source is in `src`. `Manage-Mod.ps1` stages all three patches against your own original library, verifies the resulting hash, and atomically replaces the installed file. See [development](docs/DEVELOPMENT.md) for rebuilding and testing.

Mod code is MIT licensed. Mono.Cecil 0.11.6 is bundled under its MIT license; see [THIRD-PARTY-LICENSES.txt](THIRD-PARTY-LICENSES.txt). Crown Siege and its game assets belong to their respective owners. This is an unofficial mod.
