@echo off
setlocal EnableDelayedExpansion
title LOOP - srrobs-portfolio (ate parares)
color 0A
rem autopush-loop.bat - auto-push em loop visual com censura (ate parares)
rem UNICO ficheiro no root. Fica aberto a fazer commit+push de X em X segundos.
rem Seguro: nunca commita dados pessoais (var/, *.log, censurados).
rem Uso: duplo clique  (60s)  |  autopush-loop.bat 30  |  autopush-loop.bat 120

set "REPO=%~dp0"
if "%REPO:~-1%"=="\" set "REPO=%REPO:~0,-1%"
set "INTERVAL=%~1"
if "%INTERVAL%"=="" set "INTERVAL=60"
set "LOG=%REPO%\var\log\autopush.log"
set "PATH=%PATH%;C:\Program Files\Git\cmd;C:\Program Files\Git\bin"
if not exist "%REPO%\var\log" mkdir "%REPO%\var\log" 2>nul

echo ========================================================
echo  LOOP - auto-push ate parares  (VISUAL COM CENSURA)
echo  REPO: %REPO%
echo  Intervalo: %INTERVAL%s  |  Para PARAR: Ctrl+C ou fecha o X
echo  So commita: visitas_totals.json + ficheiros tracked (censura ativa)
echo ========================================================
echo.
echo [loop] a verificar a cada %INTERVAL%s...
echo.

:loop
echo --------------------------------------------------------
echo [%date% %time%] ciclo...

rem --- snapshot publico (agregados, sem IPs/HWIDs) ---
python -c "import pathlib, sys; sys.path.insert(0,'src'); import srrobs_visitas as sv; sv._DB_PATH[0]='var/visitas_portfolio.json'; d=sv.carregar(sv._db()); sv._gravar_snapshot(d)" >>"%LOG%" 2>&1
if errorlevel 1 echo [%date% %time%] aviso: snapshot falhou  & echo [aviso] snapshot falhou >> "%LOG%"

rem --- stage so ficheiros seguros ---
git add visitas_totals.json >>"%LOG%" 2>&1
git add -u >>"%LOG%" 2>&1

rem --- censura: bloqueia se staged contiver identificadores pessoais (ofuscado) ---
python -c "import subprocess,sys,base64; bl=['Z2VlazE3ODE=','b3BpcmF0YW51bWVybzE=','cm9iZXJ0MzNv','Um9iZXJ0b01GOTk4','eHJvYnM=','U2FuZGJveFxcUm9icw==','U2FuZGJveFxcRGV2','U2F2ZUZpbGVfTGl2ZQ==','VGVzc2VyYWN0U3R1ZGlv']; bad=[base64.b64decode(b).decode().lower() for b in bl]; rn=subprocess.run(['git','diff','--cached','--name-only','-z'], capture_output=True).stdout.decode(errors='ignore').split('\0'); non=[n for n in rn if n and 'autopush' not in n.lower()]; cmd=['git','diff','--cached','--no-color','--']+non if non else ['git','diff','--cached','--no-color','--','--nope']; diff=subprocess.run(cmd, capture_output=True, text=True, encoding='utf-8', errors='ignore').stdout.lower() if non else ''; empty=not non and len([n for n in rn if n])==1; diff2='' if empty else diff; hits=[b for b in bad if b in diff2]; print('censura: OK' if not hits else 'BLOCKED: '+str(hits)); sys.exit(1 if hits else 0)" >>"%LOG%" 2>&1
if errorlevel 1 (
  echo [BLOCKED] diff com identificador pessoal - reset
  echo [%date% %time%] BLOCKED censura >> "%LOG%"
  git diff --cached --name-only >>"%LOG%" 2>&1
  git reset HEAD >>"%LOG%" 2>&1
  git add visitas_totals.json >>"%LOG%" 2>&1
  python -c "import subprocess,sys,base64; bl=['Z2VlazE3ODE=','b3BpcmF0YW51bWVybzE=','cm9iZXJ0MzNv','Um9iZXJ0b01GOTk4','eHJvYnM=']; bad=[base64.b64decode(b).decode().lower() for b in bl]; diff=subprocess.run(['git','diff','--cached','--no-color'], capture_output=True, text=True, encoding='utf-8', errors='ignore').stdout.lower(); hits=[b for b in bad if b in diff]; sys.exit(1 if hits else 0)" >>"%LOG%" 2>&1
  if errorlevel 1 (
    echo [BLOCKED] persiste no snapshot - aborta ciclo
    git reset HEAD >>"%LOG%" 2>&1
    goto do_pull
  )
)

git diff --cached --quiet
if errorlevel 1 (
  echo [commit] alteracoes detetadas - a commitar...
  git commit -m "auto: sync %date% %time%" >>"%LOG%" 2>&1
  if errorlevel 1 echo [aviso] commit falhou
) else (
  echo [ok] sem alteracoes para commitar
)

:do_pull
git pull --rebase --autostash origin main >>"%LOG%" 2>&1
git push origin main >>"%LOG%" 2>&1
if errorlevel 1 (
  echo [aviso] push falhou (sem net ou conflito) - tenta no proximo ciclo
) else (
  for /f %%i in ('git log --oneline -1 2^>nul') do echo [push] %%i
)

echo [%date% %time%] ciclo concluido - proximo em %INTERVAL%s
echo [loop] proximo em %INTERVAL%s... (Ctrl+C para parar)
timeout /t %INTERVAL% /nobreak >nul
goto loop
