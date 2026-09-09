@echo off
rem ============================================================
rem knowledge-hub services keepalive script (idempotent)
rem Checks ports 5177 (backend tsx watch) and 5178 (frontend vite)
rem and starts them if not listening. Safe to run repeatedly.
rem Spawns detached minimized windows (independent of caller).
rem NOTE: keep this file pure ASCII; chinese paths come from %~dp0.
rem ============================================================
set "ROOT=%~dp0"

rem ---- backend 5177 ----
netstat -ano | findstr ":5177" | findstr "LISTENING" >nul 2>&1
if errorlevel 1 (
  start "kh-backend" /min cmd /c "cd /d ""%ROOT%server"" && npm run dev"
)

rem ---- frontend 5178 ----
netstat -ano | findstr ":5178" | findstr "LISTENING" >nul 2>&1
if errorlevel 1 (
  start "kh-frontend" /min cmd /c "cd /d ""%ROOT%web"" && npm run dev"
)

rem ---- self check (ping delay works in non-interactive sessions) ----
ping -n 12 127.0.0.1 >nul
set "OK=1"
netstat -ano | findstr ":5177" | findstr "LISTENING" >nul 2>&1 || set "OK=0"
netstat -ano | findstr ":5178" | findstr "LISTENING" >nul 2>&1 || set "OK=0"
if "%OK%"=="1" (
  echo [ok] services up: 5177 backend / 5178 frontend
) else (
  echo [warn] not listening yet - check npm install or port conflicts
)
