@echo off
chcp 65001 >nul
setlocal EnableExtensions DisableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
set "REPORT=%SCRIPT_DIR%pc_report.txt"
set "PS_SCRIPT=%SCRIPT_DIR%pc_info.ps1"

> "%REPORT%" echo ============================================================
call :log "CLIENT COMPUTER AUDIT"
call :log "Starting date and time: %date% %time%"
call :log ""

if not exist "%PS_SCRIPT%" (
    call :log "ERROR: pc_info.ps1 was not found."
    goto :error
)

call :log "Collecting computer information..."
call :log "Checking installed software..."
call :log ""

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -ReportPath "%REPORT%"
set "RESULT=%ERRORLEVEL%"

if not "%RESULT%"=="0" goto :error

call :log ""
call :log "Audit completed successfully."
echo.
echo Report saved:
echo %REPORT%
echo.
pause
exit /b 0

:error
echo.
echo An error occurred. Check the report.
echo %REPORT%
pause
exit /b 1

:log
if "%~1"=="" (
    echo(
    >>"%REPORT%" echo(
    exit /b 0
)
echo %~1
>>"%REPORT%" echo %~1
exit /b 0