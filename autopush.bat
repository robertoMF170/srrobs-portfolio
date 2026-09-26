@echo off
setlocal EnableDelayedExpansion
rem ===== srrobs-portfolio - auto-push SEGURO (sem vazar dados pessoais) =====
rem - Corre de qualquer pasta: usa a pasta do .bat como REPO
rem - 1 ciclo:   autopush.bat              (gera snapshot + add -u + commit + push)
rem - 1 ciclo:   autopush.bat --once       (igual, usado pelo loop)
rem - loop:      autopush.bat --loop 60    (repete a cada 60s ate fechar janela)
rem - ou:        autopush-loop.bat 30      (wrapper visivel, mesmo efeito)
rem - oculto:    wscript autopush-silent.vbs "%REPO%\autopush.bat" --loop 60
rem LEAK-PROOF:
rem   * var/, *.log, *.es3, github-setup/, .freebuff/, shots/, etc tudo ignorado
rem   * So commita: visitas_totals.json (agregados sem IP/HWID) + ficheiros tracked modificados (git add -u)
rem   * Ficheiros novos untracked NAO entram -> evita commit acidental de saves/prints

set "REPO=%~dp0"
if "%REPO:~-1%"=="\" set "REPO=%REPO:~0,-1%"
cd /d "%REPO%" 2>nul
if errorlevel 1 (
  echo [%date% %time%] ERRO: nao consegui entrar em %REPO% >> "%TEMP%\srrobs-autopush.log"
  exit /b 1
)
set "PATH=%PATH%;C:\Program Files\Git\cmd;C:\Program Files\Git\bin"
set "LOG=%REPO%\autopush.log"

if /I "%~1"=="--loop" goto do_loop
if /I "%~1"=="--once" goto once
goto once

:do_loop
set "INTERVAL=%~2"
if "!INTERVAL!"=="" set "INTERVAL=60"
echo [%date% %time%] loop iniciado: a cada !INTERVAL!s em %REPO% >> "%LOG%"
:loop
call "%~f0" --once >> "%LOG%" 2>&1
timeout /t !INTERVAL! /nobreak >nul
goto loop

:once
rem === snapshot publico (agregados, sem IPs/HWIDs) ===
python -c "import pathlib, sys; sys.path.insert(0,'src'); import srrobs_visitas as sv; sv._DB_PATH[0]='var/visitas_portfolio.json'; d=sv.carregar(sv._db()); sv._gravar_snapshot(d)" >>"%LOG%" 2>&1
if errorlevel 1 echo [%date% %time%] aviso: falha ao gerar snapshot >> "%LOG%"

rem === stage SO ficheiros seguros ===
git add visitas_totals.json >>"%LOG%" 2>&1
git add -u >>"%LOG%" 2>&1

rem === guard: bloqueia commit se staged diff contiver identificadores pessoais ===
rem Usa lista ofuscada (base64) para o proprio .bat nao disparar o guard
python -c "import subprocess,sys,base64; bl=['Z2VlazE3ODE=','b3BpcmF0YW51bWVybzE=','cm9iZXJ0MzNv','Um9iZXJ0b01GOTk4','eHJvYnM=','U2FuZGJveFxcUm9icw==','U2FuZGJveFxcRGV2','U2F2ZUZpbGVfTGl2ZQ==','VGVzc2VyYWN0U3R1ZGlv']; bad=[base64.b64decode(b).decode().lower() for b in bl]; diff=subprocess.run(['git','diff','--cached','--no-color'], capture_output=True, text=True).stdout.lower(); hits=[b for b in bad if b in diff and 'autopush.bat' not in diff.lower().split(b)[0][-500:]]; real=[]; out=subprocess.run(['git','diff','--cached','--name-only'], capture_output=True, text=True).stdout; files=[f.strip() for f in out.splitlines()]; diff2=subprocess.run(['git','diff','--cached','--no-color','--']+[f for f in files if 'autopush' not in f.lower()], capture_output=True, text=True).stdout.lower() if files else ''; hits=[b for b in bad if b in diff2]; print('guard: diff limpo' if not hits else 'BLOCKED personal: '+str(hits)); sys.exit(1 if hits else 0)" >>"%LOG%" 2>&1
if errorlevel 1 (
  echo [%date% %time%] BLOCKED: diff contem identificador pessoal, resetando >> "%LOG%"
  git diff --cached --name-only >>"%LOG%" 2>&1
  git reset HEAD >>"%LOG%" 2>&1
  rem tenta so o snapshot se estiver limpo
  git add visitas_totals.json >>"%LOG%" 2>&1
  python -c "import subprocess,sys,base64; bl=['Z2VlazE3ODE=','b3BpcmF0YW51bWVybzE=','cm9iZXJ0MzNv','Um9iZXJ0b01GOTk4','eHJvYnM=']; bad=[base64.b64decode(b).decode().lower() for b in bl]; diff=subprocess.run(['git','diff','--cached','--no-color'], capture_output=True, text=True).stdout.lower(); hits=[b for b in bad if b in diff]; sys.exit(1 if hits else 0)" >>"%LOG%" 2>&1
  if errorlevel 1 (
    echo [%date% %time%] BLOCKED persistiu no snapshot, abortando ciclo >> "%LOG%"
    git reset HEAD >>"%LOG%" 2>&1
    goto pull
  )
)

git diff --cached --quiet
if not errorlevel 1 goto pull
git commit -m "auto: sync %date% %time%" >>"%LOG%" 2>&1
if errorlevel 1 (
  echo [%date% %time%] aviso: commit falhou >> "%LOG%"
  goto pull
)

:pull
git pull --rebase --autostash origin main >>"%LOG%" 2>&1
git push origin main >>"%LOG%" 2>&1
if errorlevel 1 echo [%date% %time%] aviso: push falhou (sem net ou conflito) >> "%LOG%"
echo [%date% %time%] ciclo concluido >> "%LOG%"
exit /b 0
