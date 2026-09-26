@echo off
setlocal
rem autopush-watch.bat — MODO “ATÉ PARAR O PROJETO”
rem Vigia o portfolio e faz push MAL EDITAS um ficheiro (com debounce).
rem Corre até fechares esta janela ou Ctrl+C. Sem dados pessoais no commit.
rem
rem Uso:
rem   autopush-watch.bat                  (poll 0.8s, debounce 4s)
rem   autopush-watch.bat 2                (debounce 2s — push mais rápido)
rem   autopush-watch.bat --once           (só 1 ciclo, sem vigiar)
rem Oculto (sem janela):
rem   wscript autopush-silent.vbs --watch
rem   wscript autopush-silent.vbs --watch 2

set "REPO=%~dp0"
if "%REPO:~-1%"=="\" set "REPO=%REPO:~0,-1%"
set "DEBOUNCE=%~1"
if "%DEBOUNCE%"=="" set "DEBOUNCE=4"
if /I "%DEBOUNCE%"=="--once" (
  python -X utf8 "%REPO%\src\autopush_watch.py" --once
  exit /b %errorlevel%
)
if /I "%DEBOUNCE%"=="--watch" set "DEBOUNCE=%~2"
if "%DEBOUNCE%"=="" set "DEBOUNCE=4"

echo ========================================================
echo  WATCH — auto-push ate parares o projeto
echo  REPO: %REPO%
echo  Cada vez que guardas index.html/app.js/style.css/...
echo  espera %DEBOUNCE%s e faz git push automaticamente.
echo  Para PARAR: fecha esta janela ou Ctrl+C.
echo ========================================================
echo.
python -X utf8 "%REPO%\src\autopush_watch.py" --debounce %DEBOUNCE%
