@echo off
rem ============================================================
rem knowledge-hub services launcher (manual entry, no windows)
rem Delegates to start-hidden.vbs which starts backend (5177)
rem and frontend (5178) with hidden windows.
rem NOTE: keep this file pure ASCII; chinese paths come from %~dp0.
rem ============================================================
start "" wscript.exe "%~dp0start-hidden.vbs"
