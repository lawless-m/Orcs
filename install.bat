@echo off
REM Double-click this file to install.
REM It just runs install.ps1 and asks you a couple of questions.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -Interactive
echo.
pause
