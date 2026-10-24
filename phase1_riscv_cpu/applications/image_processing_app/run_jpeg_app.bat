@echo off
setlocal
title RISC-V JPEG Compression Application

cd /d "%~dp0"

if not exist "jpeg_env\Scripts\python.exe" (
    echo ERROR: Python environment was not found.
    echo Expected: %~dp0jpeg_env\Scripts\python.exe
    pause
    exit /b 1
)

if not exist "riscv_jpeg_app.py" (
    echo ERROR: riscv_jpeg_app.py was not found.
    echo Save it in the same folder as this BAT file.
    pause
    exit /b 1
)

:RUN_IMAGE
cls
echo ============================================================
echo             RISC-V JPEG COMPRESSION APPLICATION
echo ============================================================
echo.
echo Select your image in the file-selection window.
echo.
echo Processing includes:
echo   - Automatic JPEG size reduction
echo   - Original image resolution preserved
echo   - RTL CPU matrix validation
echo   - Original and output image display
echo   - File sizes, matrix jobs, CPU cycles and timing
echo.
echo Processing may take several minutes.
echo Run only one instance of this application at a time.
echo.

"%~dp0jpeg_env\Scripts\python.exe" -u "%~dp0riscv_jpeg_app.py"

if errorlevel 1 (
    echo.
    echo The application returned an error.
    echo Review the messages above.
)

echo.
echo ============================================================
echo   1 - Another image
echo   2 - Exit
echo ============================================================
echo.

choice /c 12 /n

if errorlevel 2 goto EXIT_APP
if errorlevel 1 goto RUN_IMAGE
goto EXIT_APP

:EXIT_APP
endlocal
exit /b