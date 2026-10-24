@echo off
setlocal
title Phase 1 Python Environment Setup

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..\..\..") do set "REPO_ROOT=%%~fI"

set "VENV_DIR=%REPO_ROOT%\.venv"
set "REQUIREMENTS=%REPO_ROOT%\phase1_riscv_cpu\applications\image_processing_app\requirements.txt"

if not exist "%REQUIREMENTS%" (
    echo ERROR: Requirements file was not found:
    echo %REQUIREMENTS%
    pause
    exit /b 1
)

where py >nul 2>&1
if not errorlevel 1 (
    set "PYTHON_COMMAND=py -3"
    goto CREATE_ENV
)

where python >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python 3 was not found.
    echo Install Python 3 and run this setup again.
    pause
    exit /b 1
)

set "PYTHON_COMMAND=python"

:CREATE_ENV
if not exist "%VENV_DIR%\Scripts\python.exe" (
    echo Creating repository Python environment...
    %PYTHON_COMMAND% -m venv "%VENV_DIR%"
    if errorlevel 1 goto SETUP_FAILED
) else (
    echo Existing repository Python environment found.
)

echo Updating pip...
"%VENV_DIR%\Scripts\python.exe" -m pip install --upgrade pip
if errorlevel 1 goto SETUP_FAILED

echo Installing Phase 1 image-application requirements...
"%VENV_DIR%\Scripts\python.exe" -m pip install -r "%REQUIREMENTS%"
if errorlevel 1 goto SETUP_FAILED

echo Verifying required imports...
"%VENV_DIR%\Scripts\python.exe" -c "import numpy, PIL, imageio, cv2, pandas, matplotlib; print('ALL PHASE 1 PYTHON REQUIREMENTS INSTALLED')"
if errorlevel 1 goto SETUP_FAILED

echo.
echo ============================================================
echo PHASE 1 PYTHON ENVIRONMENT SETUP PASSED
echo Environment: %VENV_DIR%
echo ============================================================
exit /b 0

:SETUP_FAILED
echo.
echo ERROR: Phase 1 Python environment setup failed.
pause
exit /b 1
