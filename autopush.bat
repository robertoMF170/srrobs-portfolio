@echo off
rem ===== srrobs-portfolio - auto-push (executado de 5 em 5 min pelo Agendador do Windows) =====
cd /d "D:\Portfolio"
if errorlevel 1 (
  echo [%date% %time%] ERRO: nao consegui entrar em D:\Portfolio >> "%TEMP%\srrobs-autopush.log"
  exit /b 1
)

rem garantir que o git esta no PATH do Agendador
set PATH=%PATH%;C:\Program Files\Git\cmd

set LOG=D:\Portfolio\autopush.log

rem === visitas: gera snapshot publico (agregados, sem IPs/HWIDs) ===
python -c "import pathlib, json, sys; sys.path.insert(0,'src'); import srrobs_visitas as sv; sv._DB_PATH[0]='var/visitas_portfolio.json'; d=sv.carregar(sv._db()); sv._gravar_snapshot(d)" >>"%LOG%" 2>&1

git add -A >>"%LOG%" 2>&1

rem so faz commit se houver alteracoes preparadas
git diff --cached --quiet
if not errorlevel 1 goto pull
git commit -m "auto: sync %date% %time%" >>"%LOG%" 2>&1

:pull
git pull --rebase --autostash origin main >>"%LOG%" 2>&1
git push origin main >>"%LOG%" 2>&1

echo [%date% %time%] ciclo concluido >>"%LOG%"
