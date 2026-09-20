@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Manage-Mod.ps1" -Action Install %*
if errorlevel 1 (
  echo.
  echo The operation failed. Read the message above.
  pause
  exit /b 1
)
pause
