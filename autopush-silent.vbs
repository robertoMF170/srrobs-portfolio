' Executa o autopush.bat de forma oculta (sem janela a piscar a cada 5 minutos)
CreateObject("Wscript.Shell").Run """" & WScript.Arguments(0) & """", 0, False
