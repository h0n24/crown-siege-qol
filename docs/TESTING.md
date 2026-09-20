# Testing

## Automated checks

`tests/Test-Installer.ps1` uses a disposable copy of the supported original DLL. It covers clean installation, status, repeated installation, uninstall, repeated uninstall, backup verification, unknown-file rejection, corrupt backups, modified package rejection, missing uninstall backup and recovery. Installation must generate the exact released SHA-256. Tests include a game path containing spaces.

Patch verification during development checked all 5,846 existing methods, including nested types, when adding faster zoom and the cap. Only the intended camera methods changed at those stages. Automatic-purchase verification checked the restart hook and added methods; 4,535 existing top-level methods were compared against the original.

These checks validate bytecode and installer behavior. They do not replace in-game testing.

## Manual gameplay checklist

- Start a new level without touching Q/W/E/R; confirm available troop slots purchase automatically when affordable.
- Restart a level; confirm purchase locks start enabled again.
- Press and release a troop key; confirm manual unlocking still works. Hold to re-enable the normal lock.
- Finish or exit a battle; confirm purchases stop. Open menus and return to a new battle.
- Check empty/locked troop slots and insufficient gold.
- Zoom in and out in the skill tree with both wheel and slider.
- Compare wheel response at low and high FPS; check that each wheel event has consistent strength.
- Check the closest view, default view, zoom-out limit, dragging and centering on a node.
- Reopen the skill tree repeatedly; confirm the closest-view limit does not move progressively.
- Check battle camera behavior is unchanged.
- Remove the mod and confirm original behavior returns.

Recorded feedback: the user confirmed the final fast wheel zoom felt good. The maximum-magnification cap still needs visual confirmation, and the full gameplay checklist has not been completed.
