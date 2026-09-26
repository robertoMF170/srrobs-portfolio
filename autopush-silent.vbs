' autopush-silent.vbs - executa tarefa oculta (sem janela a piscar)
' 1 ciclo:      wscript autopush-silent.vbs
'               duplo clique -> 1 push
' loop X seg:   wscript autopush-silent.vbs --loop 60
' watch:        wscript autopush-silent.vbs --watch
' watch+debounce: wscript autopush-silent.vbs --watch 2
' legado:       wscript autopush-silent.vbs "C:\path\autopush.bat" --loop 60
Option Explicit
Dim sh, fso, repo, target, args, i, a0
Set sh = CreateObject("Wscript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
repo = fso.GetParentFolderName(WScript.ScriptFullName)

If WScript.Arguments.Count = 0 Then
  sh.Run """" & repo & "\autopush.bat"" --once", 0, False
  WScript.Quit 0
End If

a0 = LCase(WScript.Arguments(0))

' --watch -> watch oculto (via python)
If a0 = "--watch" Then
  args = " --debounce 4"
  If WScript.Arguments.Count >= 2 Then args = " --debounce " & WScript.Arguments(1)
  sh.Run "python -X utf8 """ & repo & "\src\autopush_watch.py""" & args, 0, False
  WScript.Quit 0
End If

' --loop N -> loop oculto via autopush.bat
If a0 = "--loop" Then
  args = ""
  For i = 0 To WScript.Arguments.Count - 1
    args = args & " " & WScript.Arguments(i)
  Next
  sh.Run """" & repo & "\autopush.bat""" & args, 0, False
  WScript.Quit 0
End If

' --once -> 1 ciclo
If a0 = "--once" Then
  sh.Run """" & repo & "\autopush.bat"" --once", 0, False
  WScript.Quit 0
End If

' se 1o arg e um .bat/.cmd legado, delega
If InStr(a0, ".bat") > 0 Or InStr(a0, ".cmd") > 0 Then
  target = WScript.Arguments(0)
  args = ""
  For i = 1 To WScript.Arguments.Count - 1
    args = args & " " & WScript.Arguments(i)
  Next
  sh.Run """" & target & """" & args, 0, False
Else
  args = ""
  For i = 0 To WScript.Arguments.Count - 1
    args = args & " " & WScript.Arguments(i)
  Next
  sh.Run """" & repo & "\autopush.bat""" & args, 0, False
End If
