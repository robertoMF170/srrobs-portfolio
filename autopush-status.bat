@echo off
setlocal EnableDelayedExpansion
rem autopush-status.bat - debug do modo oculto (wscript --watch)
rem Mostra se o watch esta a correr, ultimas linhas do log, e ultimo commit/push.
rem Uso: duplo clique ou:  autopush-status.bat
rem       autopush-status.bat --tail 50   (mostra 50 linhas)
rem Para debug em tempo real: autopush-status.bat --follow
set "REPO=%~dp0"
if "%REPO:~-1%"=="\" set "REPO=%REPO:~0,-1%"
set "TAIL=%~2"
if "%TAIL%"=="" set "TAIL=30"
if /I "%~1"=="--tail" set "TAIL=%~2"
if "%TAIL%"=="" set "TAIL=30"

echo ========================================================
echo  AUTOPUSH STATUS - debug
echo  REPO: %REPO%
echo ========================================================
echo.
echo [1] Processos a correr (watch / loop):
echo --------------------------------------------------------
wmic process where "name='python.exe'" get CommandLine,ProcessId 2>nul | findstr /i "autopush_watch" >nul 2>&1
if !errorlevel!==0 (
  echo  python autopush_watch a correr:
  wmic process where "name='python.exe'" get CommandLine,ProcessId 2>nul | findstr /i "autopush_watch"
) else (
  echo  (nenhum python autopush_watch encontrado via wmic - tenta tasklist)
  tasklist /FI "IMAGENAME eq python.exe" 2>nul | more
)
echo.
wmic process where "name='wscript.exe'" get CommandLine,ProcessId 2>nul | findstr /i "autopush" >nul 2>&1
if !errorlevel!==0 (
  echo  wscript autopush a correr:
  wmic process where "name='wscript.exe'" get CommandLine,ProcessId 2>nul | findstr /i "autopush"
) else (
  echo  (nenhum wscript autopush)
)
echo.
echo [2] Ultimas %TAIL% linhas de autopush.log:
echo --------------------------------------------------------
if exist "%REPO%\autopush.log" (
  powershell -NoProfile -Command "Get-Content -Tail %TAIL% -Encoding utf8 '%REPO%\autopush.log' | Out-String -Stream | ForEach-Object { $_ }"
) else (
  echo  (sem log ainda - correu alguma vez? Verifica autopush.log)
)
echo.
echo [3] Estado git:
echo --------------------------------------------------------
pushd "%REPO%" 2>nul
git status --porcelain 2>&1
if errorlevel 1 echo  (git status falhou)
echo.
echo Ultimo commit:
git log --oneline -1 2>&1
echo.
echo remotes:
git remote -v 2>&1
popd
echo.
if /I "%~1"=="--follow" (
  echo [4] FOLLOW - autopush.log em tempo real (Ctrl+C para sair):
  echo --------------------------------------------------------
  powershell -NoProfile -Command "Get-Content -Tail 20 -Wait -Encoding utf8 '%REPO%\autopush.log'"
)
echo.
echo Dicas:
echo  - Oculto ativo? Deve aparecer 1 linha em [1] com autopush_watch
echo  - Sem linha = nao esta a correr (volta a lancar: wscript autopush-silent.vbs --watch)
echo  - Log parado ha +30s e sem editar ficheiros = normal (watch espera debounce)
echo  - Para MATAR oculto: taskkill /F /IM python.exe  (mata TODOS pythons) ou
echo    powershell: Get-CimInstance Win32_Process -Filter "Name='python.exe'" ^| Where-Object { $_.CommandLine -like '*autopush_watch*' } ^| ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
echo.
pause
