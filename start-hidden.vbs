' ============================================================
' knowledge-hub services starter (hidden, no cmd windows)
' Starts backend (5177, tsx watch) and frontend (5178, vite)
' with window style 0 = hidden. Safe to run repeatedly.
'
' 2026-09-10 fix: probe the port BEFORE launching (used to launch
' unconditionally). Previously every run spawned one more vite; when
' 5178 was taken vite silently fell back to 5179/5180, and several
' instances shared the same web\node_modules\.vite\deps pre-bundle
' cache. They overwrite each other and the local patches stop taking
' effect (fishbone branch spacing falls back to the upstream formula
' and nodes overlap). Paired with server.strictPort in
' web\vite.config.ts so a port clash fails fast instead of spawning
' stray instances.
'
' Each service writes a log (server\_run_logs\*.log) so a hidden
' startup failure is diagnosable.
' NOTE: keep this file pure ASCII; chinese paths resolved at
' runtime via script folder (Unicode safe).
' ============================================================
Dim fso, root, shell, logDir
Set fso = CreateObject("Scripting.FileSystemObject")
root = fso.GetParentFolderName(WScript.ScriptFullName)
Set shell = CreateObject("WScript.Shell")
logDir = root & "\server\_run_logs"
If Not fso.FolderExists(logDir) Then fso.CreateFolder(logDir)

On Error Resume Next

Function IsListening(port)
  Dim rc
  rc = shell.Run("cmd /c netstat -ano | findstr """ & port & """ | findstr LISTENING >nul 2>&1", 0, True)
  IsListening = (rc = 0)
End Function

' --- backend (5177): start only when not listening -------------------
If Not IsListening(5177) Then
  shell.CurrentDirectory = root & "\server"
  shell.Run "cmd /c npm run dev > """ & logDir & "\backend.log"" 2>&1", 0, False
End If

' --- frontend (5178): start only when not listening ------------------
If Not IsListening(5178) Then
  shell.CurrentDirectory = root & "\web"
  shell.Run "cmd /c npm run dev > """ & logDir & "\frontend.log"" 2>&1", 0, False
End If

' --- health check after a short wait; retry whichever is still down --
WScript.Sleep 10000

If Not IsListening(5177) Then
  shell.CurrentDirectory = root & "\server"
  shell.Run "cmd /c npm run dev >> """ & logDir & "\backend.log"" 2>&1", 0, False
End If
If Not IsListening(5178) Then
  shell.CurrentDirectory = root & "\web"
  shell.Run "cmd /c npm run dev >> """ & logDir & "\frontend.log"" 2>&1", 0, False
End If
