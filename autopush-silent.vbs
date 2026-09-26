' autopush-silent.vbs — executa o autopush.bat sem janela (oculto)
' Uso sem args: duplo clique -> 1 ciclo oculto
' Loop oculto: wscript autopush-silent.vbs --loop 60
'   ou:        wscript //nologo autopush-silent.vbs "D:\Portfolio\autopush.bat" --loop 60
Option Explicit
Dim sh, repo, target, args, i
Set sh = CreateObject("Wscript.Shell")

' se o 1o arg parece um .bat/.cmd, usa-o; senao usa o autopush.bat da mesma pasta
If WScript.Arguments.Count >= 1 Then
  If InStr(LCase(WScript.Arguments(0)), ".bat") > 0 Or InStr(LCase(WScript.Arguments(0)), ".cmd") > 0 Then
    target = WScript.Arguments(0)
    args = ""
    For i = 1 To WScript.Arguments.Count - 1
      args = args & " " & WScript.Arguments(i)
    Next
    sh.Run """" & target & """" & args, 0, False
  Else
    repo = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
    args = ""
    For i = 0 To WScript.Arguments.Count - 1
      args = args & " " & WScript.Arguments(i)
    Next
    sh.Run """" & repo & "\autopush.bat""" & args, 0, False
  End If
Else
  repo = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
  sh.Run """" & repo & "\autopush.bat"" --once", 0, False
End If
