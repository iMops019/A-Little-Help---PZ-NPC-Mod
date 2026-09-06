@echo off
REM Double-click to deploy A Little Help into Project Zomboid.
REM Pass-through args work too, e.g.:  dev-deploy.bat -Launch
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy.ps1" %*
echo.
pause
