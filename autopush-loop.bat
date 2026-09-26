@echo off
setlocal
rem autopush-loop.bat [segundos]
rem Corre o autopush de X em X segundos, sem janela a piscar se usares o .vbs
rem Uso: autopush-loop.bat 60    (a cada 60s)
rem      autopush-loop.bat 30    (a cada 30s)
rem Para parar: fecha a janela ou encontra o PID com tasklist ^| find "cmd"

set "REPO=%~dp0"
if "%REPO:~-1%"=="\" set "REPO=%REPO:~0,-1%"
set "INTERVAL=%~1"
if "%INTERVAL%"=="" set "INTERVAL=60"

echo Loop auto-push do portfolio a cada %INTERVAL%s
echo REPO: %REPO%
echo Para parar fecha esta janela (Ctrl+C).
echo.

:loop
call "%REPO%\autopush.bat" --once
echo [%date% %time%] proximo em %INTERVAL%s ...
timeout /t %INTERVAL% /nobreak >nul
goto loop
