@echo off
setlocal EnableExtensions
cd /d "%~dp0"

REM ============================================================
REM  status.bat - report whether the local n8n instance is up
REM  - Reads .n8n.pid (written by start.bat) and verifies it.
REM  - Reports PID, port, uptime, memory, and an HTTP health
REM    check against the editor.
REM  Exit code: 0 = running, 1 = not running.
REM ============================================================

if "%N8N_PORT%"=="" set "N8N_PORT=5678"
set "PIDFILE=%~dp0.n8n.pid"

set "TRACKEDPID="
if exist "%PIDFILE%" set /p TRACKEDPID=<"%PIDFILE%"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$port = '%N8N_PORT%';" ^
  "$tracked = '%TRACKEDPID%'.Trim();" ^
  "$conns = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue;" ^
  "$listenPid = if ($conns) { ($conns.OwningProcess | Sort-Object -Unique)[0] } else { $null };" ^
  "$running = $false;" ^
  "Write-Host '';" ^
  "Write-Host '  n8n status' -ForegroundColor Cyan;" ^
  "Write-Host '  ----------';" ^
  "if ($tracked) {" ^
  "  $p = Get-Process -Id $tracked -ErrorAction SilentlyContinue;" ^
  "  if ($p) {" ^
  "    $running = $true;" ^
  "    $up = (Get-Date) - $p.StartTime;" ^
  "    $mem = [math]::Round($p.WorkingSet64/1MB,1);" ^
  "    Write-Host ('  State    : RUNNING') -ForegroundColor Green;" ^
  "    Write-Host ('  PID      : ' + $tracked + '  (from .n8n.pid)');" ^
  "    Write-Host ('  Uptime   : ' + ('{0}h {1}m {2}s' -f [int]$up.TotalHours, $up.Minutes, $up.Seconds));" ^
  "    Write-Host ('  Memory   : ' + $mem + ' MB');" ^
  "  } else {" ^
  "    Write-Host ('  State    : NOT RUNNING (stale .n8n.pid for PID ' + $tracked + ')') -ForegroundColor Yellow;" ^
  "  }" ^
  "} else {" ^
  "  Write-Host '  State    : NOT RUNNING (no .n8n.pid)' -ForegroundColor Yellow;" ^
  "}" ^
  "Write-Host ('  Port     : ' + $port);" ^
  "if ($listenPid) {" ^
  "  if ($listenPid -eq $tracked) { $owner = 'our n8n'; $lcolor = 'Green' } else { $owner = 'PID ' + $listenPid + ' - NOT our tracked process'; $lcolor = 'Yellow' };" ^
  "  Write-Host ('  Listener : yes (' + $owner + ')') -ForegroundColor $lcolor;" ^
  "  $running = $true;" ^
  "} else {" ^
  "  Write-Host '  Listener : none on this port';" ^
  "}" ^
  "$health = 'unreachable';" ^
  "try {" ^
  "  $r = Invoke-WebRequest -Uri ('http://localhost:' + $port + '/healthz') -UseBasicParsing -TimeoutSec 4 -ErrorAction Stop;" ^
  "  $health = 'OK (' + [int]$r.StatusCode + ')';" ^
  "} catch {" ^
  "  if ($_.Exception.Response) { $health = 'HTTP ' + [int]$_.Exception.Response.StatusCode } ;" ^
  "}" ^
  "Write-Host ('  Editor   : http://localhost:' + $port);" ^
  "Write-Host ('  Health   : ' + $health);" ^
  "Write-Host '';" ^
  "if ($running) { exit 0 } else { exit 1 }"

endlocal & exit /b %ERRORLEVEL%
