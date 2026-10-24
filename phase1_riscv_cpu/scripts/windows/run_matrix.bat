@echo off
setlocal
title RISC-V CPU Matrix Multiplication

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..\..\..") do set "REPO_ROOT=%%~fI"

set "MATRIX_APP=%REPO_ROOT%\phase1_riscv_cpu\software\matrix_input\matrix_input.py"

if not exist "%MATRIX_APP%" (
    echo ERROR: Matrix application not found:
    echo %MATRIX_APP%
    exit /b 1
)

:START
cls

where py >nul 2>nul

if %errorlevel%==0 (
    py -3 "%MATRIX_APP%"
) else (
    python "%MATRIX_APP%"
)

set "APP_RESULT=%errorlevel%"

if not "%APP_RESULT%"=="0" (
    echo.
    echo Matrix application returned error %APP_RESULT%.
)

echo.
echo ==========================================
echo MATRIX MULTIPLICATION COMPLETED
echo ==========================================
echo.
echo Press 1 for new matrices
echo Press 2 to exit
echo.

choice /c 12 /n /m ""

if errorlevel 2 goto EXIT_APP
if errorlevel 1 goto START

:EXIT_APP
endlocal
exit /b 0
