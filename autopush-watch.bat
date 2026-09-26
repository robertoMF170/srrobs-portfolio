@echo off
setlocal EnableDelayedExpansion
title WATCH - srrobs-portfolio (ate parares)
color 0A
rem autopush-watch.bat - MODO VISUAL "ATE PARAR O PROJETO"
rem Fica aberto em loop visual: mostra quando alteras um ficheiro e faz push.
rem Fecha so com Ctrl+C ou X.
rem Uso:
rem   duplo clique em autopush-watch.bat          (debounce 4s)
rem   autopush-watch.bat 2                        (debounce 2s, push mais rapido)
rem   autopush-watch.bat --once                   (so 1 ciclo, sem vigiar)

set "REPO=%~dp0"
if "%REPO:~-1%"=="\" set "REPO=%REPO:~0,-1%"
set "DEBOUNCE=%~1"
if "%DEBOUNCE%"=="" set "DEBOUNCE=4"
if /I "%DEBOUNCE%"=="--once" (
  echo [once] 1 ciclo...
  python -X utf8 "%REPO%\src\autopush_watch.py" --once
  if errorlevel 1 (
    echo [ERRO] python falhou. Tenta: py -3 -X utf8 src\autopush_watch.py --once
    py -3 -X utf8 "%REPO%\src\autopush_watch.py" --once
  )
  echo.
  echo [once] concluido. Pressiona qualquer tecla para fechar.
  pause >nul
  exit /b %errorlevel%
)
if /I "%DEBOUNCE%"=="--watch" set "DEBOUNCE=%~2"
if "%DEBOUNCE%"=="" set "DEBOUNCE=4"

set "PY=python"
where python >nul 2>&1
if errorlevel 1 (
  where py >nul 2>&1
  if not errorlevel 1 set "PY=py -3"
)

if not exist "%REPO%\src\autopush_watch.py" (
  echo [ERRO] nao encontrei src\autopush_watch.py em %REPO%
  pause
  exit /b 1
)

echo ========================================================
echo  WATCH - auto-push ate parares o projeto  (VISUAL)
echo  REPO: %REPO%
echo  Vigia: index.html / app.js / style.css / visitas_totals.json ...
echo  Debounce: %DEBOUNCE%s  (espera %DEBOUNCE%s apos gravar antes de push)
echo  Ao gravar diz: [watch: alteracao detectada (ficheiro)] -^> push
echo  Para PARAR: Ctrl+C ou fecha o X
echo ========================================================
echo  Se fechar sozinho, le o erro abaixo e corre autopush-status.bat
echo.

:run_watch
echo [watch] a iniciar...
echo.
%PY% -X utf8 "%REPO%\src\autopush_watch.py" --debounce %DEBOUNCE%
set "RC=%errorlevel%"
echo.
echo --------------------------------------------------------
if "%RC%"=="0" (
  echo [watch] parado com codigo 0 (Ctrl+C ou parado normal).
) else (
  echo [watch] saiu com codigo %RC% - pode ter dado erro.
  echo Ultimas linhas do log:
  if exist "%REPO%\autopush.log" powershell -NoProfile -Command "Get-Content -Tail 20 -Encoding utf8 '%REPO%\autopush.log'" 2>nul
  echo.
  echo Tentando reiniciar em 3s... (Ctrl+C para nao reiniciar)
  timeout /t 3 >nul
  goto run_watch
)
echo.
echo Pressiona qualquer tecla para fechar (ou fecha o X).
pause >nul
exit /b %RC%
