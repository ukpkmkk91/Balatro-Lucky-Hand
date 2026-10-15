@echo off
setlocal
title Balatro Lucky Hand - Installer
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install\Install.ps1" %*
set "result=%errorlevel%"
echo.
if not "%result%"=="0" echo Installation did not complete. Read the message above.
pause
exit /b %result%
