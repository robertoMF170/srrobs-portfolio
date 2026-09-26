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

git add -A >>"%LOG%" 2>&1

rem so faz commit se houver alteracoes preparadas
git diff --cached --quiet
if not errorlevel 1 goto pull
git commit -m "auto: sync %date% %time%" >>"%LOG%" 2>&1

:pull
git pull --rebase --autostash origin main >>"%LOG%" 2>&1
git push origin main >>"%LOG%" 2>&1

echo [%date% %time%] ciclo concluido >>"%LOG%"
