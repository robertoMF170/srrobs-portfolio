@echo off
setlocal
chcp 65001 >nul
rem Launch from PowerShell at the repository root with: .\autopush-loop.bat
rem Ctrl+C stops the loop. The protected portfolio files are never staged or pushed.
set "SCRIPT=%~dp0todo\autopush-loop.ps1"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File "%SCRIPT%" %*
exit /b %ERRORLEVEL%
