@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

REM ============================================================
REM  start.bat - launch n8n locally (Windows)
REM  - Runs the built CLI directly via Node for a clean process
REM    tree that stop.bat can shut down reliably.
REM  - Records the PID in .n8n.pid and streams logs to n8n.log.
REM  Override the port with:  set N8N_PORT=5679 && start.bat
REM ============================================================

if "%N8N_PORT%"=="" set "N8N_PORT=5678"
set "PIDFILE=%~dp0.n8n.pid"
set "LOGFILE=%~dp0n8n.log"
set "ERRFILE=%~dp0n8n.err.log"

REM --- Refuse to start a second instance ---
if exist "%PIDFILE%" (
  set /p EXISTINGPID=<"%PIDFILE%"
  tasklist /FI "PID eq !EXISTINGPID!" 2>nul | find "!EXISTINGPID!" >nul
  if not errorlevel 1 (
    echo [start] n8n already appears to be running ^(PID !EXISTINGPID!^).
    echo [start] Run stop.bat first, or delete .n8n.pid if this is stale.
    exit /b 1
  )
  del "%PIDFILE%" >nul 2>&1
)

REM --- Make sure it has actually been built ---
if not exist "%~dp0packages\cli\dist\config\index.js" (
  echo [start] Build output not found ^(packages\cli\dist^). Run "pnpm build" first.
  exit /b 1
)

echo [start] Starting n8n on http://localhost:%N8N_PORT% ...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$env:N8N_PORT = '%N8N_PORT%';" ^
  "$p = Start-Process -FilePath 'node' -ArgumentList 'packages/cli/bin/n8n','start' -WorkingDirectory '%~dp0' -PassThru -WindowStyle Hidden -RedirectStandardOutput '%LOGFILE%' -RedirectStandardError '%ERRFILE%';" ^
  "Set-Content -Path '%PIDFILE%' -Value $p.Id -Encoding ascii;" ^
  "Write-Host ('[start] n8n launched. PID ' + $p.Id)"

if not exist "%PIDFILE%" (
  echo [start] Failed to launch n8n. Check %ERRFILE%.
  exit /b 1
)

echo [start] Logs:    %LOGFILE%
echo [start] Errors:  %ERRFILE%
echo [start] Editor:  http://localhost:%N8N_PORT%
echo [start] Stop it with: stop.bat
endlocal
