@echo off
setlocal EnableDelayedExpansion

cd /d "%~dp0"
chcp 65001 >nul 2>&1
title LinkMe Android

set EXIT_CODE=0
where powershell >nul 2>&1
if %ERRORLEVEL% neq 0 goto :err_no_powershell

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_build.ps1" -EnvRoot ""
set EXIT_CODE=%ERRORLEVEL%

if %EXIT_CODE% neq 0 goto :err_build_failed
goto :end

:err_no_powershell
set EXIT_CODE=1
echo [ERROR] PowerShell not found. Run as administrator.
goto :end

:err_build_failed

:end
pause
exit /b %EXIT_CODE%
