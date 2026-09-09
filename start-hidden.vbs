' ============================================================
' knowledge-hub services starter (hidden, no cmd windows)
' Starts backend (5177, tsx watch) and frontend (5178, vite)
' with window style 0 = hidden. Safe to run repeatedly.
' NOTE: keep this file pure ASCII; chinese paths resolved at
' runtime via script folder (Unicode safe).
' ============================================================
Dim fso, root, shell
Set fso = CreateObject("Scripting.FileSystemObject")
root = fso.GetParentFolderName(WScript.ScriptFullName)
Set shell = CreateObject("WScript.Shell")

On Error Resume Next

' backend
shell.CurrentDirectory = root & "\server"
shell.Run "cmd /c npm run dev", 0, False

' frontend
shell.CurrentDirectory = root & "\web"
shell.Run "cmd /c npm run dev", 0, False

' quick check after a short wait
WScript.Sleep 8000
Dim ports
ports = shell.Run("cmd /c netstat -ano | findstr ""5177"" | findstr LISTENING >nul 2>&1", 0, True)
If ports <> 0 Then
  shell.CurrentDirectory = root & "\server"
  shell.Run "cmd /c npm run dev", 0, False
End If
ports = shell.Run("cmd /c netstat -ano | findstr ""5178"" | findstr LISTENING >nul 2>&1", 0, True)
If ports <> 0 Then
  shell.CurrentDirectory = root & "\web"
  shell.Run "cmd /c npm run dev", 0, False
End If
