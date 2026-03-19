@echo off
REM ==============================================================================
REM E-Learning Courseware Download Tool Launcher
REM ==============================================================================
REM
REM This batch file launches the PowerShell script with proper execution policy
REM
REM ==============================================================================

setlocal enabledelayedexpansion

cd /d "%~dp0"

REM Check if PowerShell is available
where powershell >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo Error: PowerShell not found
    echo Please install PowerShell to use this tool
    pause
    exit /b 1
)

REM Run PowerShell script with Bypass execution policy
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0Courseware_Download.ps1"
set PS_EXIT_CODE=%ERRORLEVEL%

REM Show completion message
echo.
if !PS_EXIT_CODE! equ 0 (
    echo Script completed successfully.
) else (
    echo Script exited with code: !PS_EXIT_CODE!
)

REM Pause to let user see the result
echo Press any key to close...
pause >nul

endlocal
exit /b !PS_EXIT_CODE!
