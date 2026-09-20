# Technical notes

## Automatic purchases

The patch adds `StartDefaultAutoBuy` methods to `KeyboardButtonTrigger`, `SpawnUnitButton` and `GameManager`. A call at the successful end of `GameManager.RestartGame` enables the existing hold/latch states for the configured troop buttons and resets their repeat timestamp. Normal level entry also calls RestartGame.

The normal purchase path is reused. No prices, currency, troop statistics or save data are edited. Existing StopHolding, keyboard handling and end-game cleanup remain unchanged. The original CanLock-dependent icon logic is retained, so icon presentation remains subject to the game's existing spell-selection condition.

## Wheel zoom

`SkillTreeCamera.HandleZoom` uses:

```text
targetZoom -= wheelDeltaY * zoomSpeed * 12 * (1 / 60)
```

The fixed reference interval replaces deltaTime for wheel input only. Camera smoothing continues to use deltaTime. This avoids reducing each scroll event's effect at higher frame rates. The 12x comparison is relative to the original at 60 FPS; it is not a promise of a fixed number of wheel notches on every mouse.

## Closest view

Before Awake normalizes settings, it applies:

```text
minZoom += 0.17 * (maxZoom - minZoom)
```

For an orthographic camera, a smaller size means more magnification. Raising the lower bound therefore reduces the maximum magnification. The fraction comes from the reference slider position, approximately 83% toward zoom-in. It is applied once per camera instance, using the scene's serialized settings. With constructor defaults of 2..50, the new minimum size is 10.16; scene values can differ.

Normalization subsequently clamps defaultZoom, and both wheel and slider use the updated bounds. The zoom-out bound is unchanged. Existing movement-bound calculations also reference minZoom and naturally use the new bound.

## File safety

Only `CrownSiege_Data/Managed/Assembly-CSharp.dll` is replaced. The installer rejects unknown hashes, checks bundled patch sources and Mono.Cecil, creates a verified original backup, generates the new file in temporary staging, checks its exact SHA-256, then uses same-directory atomic replacement. It rechecks the target and running game before replacement. Failure during generation leaves the installed library untouched.

Expected installed SHA-256:

```text
083D0655F8C794887AD0D508F9CD8715670865ED55B07406E95E243B634F801F
```
