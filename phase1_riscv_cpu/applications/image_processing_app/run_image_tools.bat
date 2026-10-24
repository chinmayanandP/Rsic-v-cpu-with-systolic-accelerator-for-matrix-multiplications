@echo off
setlocal
title Image Processing Application

set "APP_DIR=%~dp0"
for %%I in ("%APP_DIR%..\..\..") do set "REPO_ROOT=%%~fI"

cd /d "%APP_DIR%"

set "PYTHON_EXE="
set "USE_PY_LAUNCHER="

if exist "%APP_DIR%jpeg_env\Scripts\python.exe" (
    set "PYTHON_EXE=%APP_DIR%jpeg_env\Scripts\python.exe"
) else if exist "%REPO_ROOT%\.venv\Scripts\python.exe" (
    set "PYTHON_EXE=%REPO_ROOT%\.venv\Scripts\python.exe"
) else (
    where py >nul 2>&1
    if not errorlevel 1 set "USE_PY_LAUNCHER=1"
)

if not defined PYTHON_EXE if not defined USE_PY_LAUNCHER (
    where python >nul 2>&1
    if not errorlevel 1 set "PYTHON_EXE=python"
)

if not defined PYTHON_EXE if not defined USE_PY_LAUNCHER (
    echo ERROR: Python 3 was not found.
    echo Create jpeg_env, create .venv in the repository, or add Python to PATH.
    pause
    exit /b 1
)

:MAIN_MENU
cls
echo ==================================================
echo            IMAGE PROCESSING APPLICATION
echo ==================================================
echo.
echo   1 - Image compressor - RISC-V validation
echo   2 - RGB to grayscale - RISC-V/Vivado
echo   3 - Grayscale to colour - AI
echo   4 - Exit
echo.

choice /c 1234 /n

if errorlevel 4 goto EXIT_APP
if errorlevel 3 goto COLORIZE
if errorlevel 2 goto GRAYSCALE
if errorlevel 1 goto COMPRESS
goto MAIN_MENU

:COMPRESS
if not exist "%APP_DIR%riscv_jpeg_app.py" (
    echo ERROR: riscv_jpeg_app.py was not found.
    goto AFTER_OPERATION
)

echo.
echo Starting RISC-V JPEG application...
call :RUN_PYTHON -u "%APP_DIR%riscv_jpeg_app.py"

if errorlevel 1 (
    echo.
    echo ERROR: The compression application returned an error.
) else (
    echo.
    echo JPEG application completed successfully.
)

goto AFTER_OPERATION

:GRAYSCALE
if not exist "%APP_DIR%riscv_grayscale_app.py" (
    echo ERROR: riscv_grayscale_app.py was not found.
    goto AFTER_OPERATION
)

echo.
echo Starting RISC-V/Vivado grayscale application...
echo RGB pixels will be processed through the RISC-V RTL simulation.
echo.

call :RUN_PYTHON -u "%APP_DIR%riscv_grayscale_app.py"

if errorlevel 1 (
    echo.
    echo ERROR: The RISC-V grayscale application returned an error.
) else (
    echo.
    echo RISC-V grayscale application completed successfully.
)

goto AFTER_OPERATION

:COLORIZE
if not exist "%APP_DIR%image_conversion_app.py" (
    echo ERROR: image_conversion_app.py was not found.
    goto AFTER_OPERATION
)

echo.
echo Starting AI grayscale-to-colour application...
call :RUN_PYTHON -u "%APP_DIR%image_conversion_app.py" --mode color

if errorlevel 1 (
    echo.
    echo ERROR: The colourization application returned an error.
) else (
    echo.
    echo Colourization completed successfully.
)

goto AFTER_OPERATION

:AFTER_OPERATION
echo.
echo ==================================================
echo   1 - Main menu
echo   2 - Exit
echo ==================================================
echo.

choice /c 12 /n

if errorlevel 2 goto EXIT_APP
if errorlevel 1 goto MAIN_MENU
goto EXIT_APP

:RUN_PYTHON
if defined PYTHON_EXE (
    "%PYTHON_EXE%" %*
) else (
    py -3 %*
)
exit /b %errorlevel%

:EXIT_APP
endlocal
exit /b
