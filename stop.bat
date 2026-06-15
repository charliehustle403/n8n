@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

REM ============================================================
REM  stop.bat - cleanly stop the n8n instance started by start.bat
REM  - Asks the process tree to exit, waits, then force-kills if
REM    it is still alive (graceful-then-forceful).
REM  - Falls back to killing whatever is listening on N8N_PORT
REM    if the PID file is missing.
REM ============================================================

if "%N8N_PORT%"=="" set "N8N_PORT=5678"
set "PIDFILE=%~dp0.n8n.pid"

if not exist "%PIDFILE%" (
  echo [stop] No .n8n.pid found - falling back to port %N8N_PORT%.
  goto :byport
)

set /p N8NPID=<"%PIDFILE%"
if "%N8NPID%"=="" (
  echo [stop] .n8n.pid was empty - falling back to port %N8N_PORT%.
  del "%PIDFILE%" >nul 2>&1
  goto :byport
)

tasklist /FI "PID eq %N8NPID%" 2>nul | find "%N8NPID%" >nul
if errorlevel 1 (
  echo [stop] PID %N8NPID% is not running ^(already stopped^). Cleaning up.
  del "%PIDFILE%" >nul 2>&1
  goto :byport
)

echo [stop] Asking n8n ^(PID %N8NPID%^) to shut down...
taskkill /PID %N8NPID% /T >nul 2>&1

REM Give n8n a few seconds to close DB connections and exit cleanly
powershell -NoProfile -Command "Start-Sleep -Seconds 4"

tasklist /FI "PID eq %N8NPID%" 2>nul | find "%N8NPID%" >nul
if not errorlevel 1 (
  echo [stop] Still alive - forcing shutdown of the process tree...
  taskkill /PID %N8NPID% /T /F >nul 2>&1
)

del "%PIDFILE%" >nul 2>&1
echo [stop] n8n stopped.

:byport
REM --- Safety net: kill any leftover listener on the port ---
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$conns = Get-NetTCPConnection -LocalPort %N8N_PORT% -State Listen -ErrorAction SilentlyContinue;" ^
  "if ($conns) {" ^
  "  $procs = $conns.OwningProcess | Sort-Object -Unique;" ^
  "  foreach ($procId in $procs) {" ^
  "    Write-Host ('[stop] Killing leftover listener on port %N8N_PORT% (PID ' + $procId + ')');" ^
  "    taskkill /PID $procId /T /F | Out-Null" ^
  "  }" ^
  "}"

endlocal
