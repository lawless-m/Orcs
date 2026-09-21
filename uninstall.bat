@echo off
REM Double-click this file to remove the mod.
REM Your own maps and your game saves are left alone.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -Uninstall
echo.
pause
