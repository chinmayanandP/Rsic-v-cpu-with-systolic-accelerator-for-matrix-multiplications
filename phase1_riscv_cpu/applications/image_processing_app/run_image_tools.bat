@echo off
setlocal
title Image Processing Application

cd /d "%~dp0"

if not exist "jpeg_env\Scripts\python.exe" (
    echo ERROR: jpeg_env\Scripts\python.exe was not found.
    pause
    exit /b 1
)

:MAIN_MENU
cls
echo ==================================================
echo            IMAGE PROCESSING APPLICATION
echo ==================================================
echo.
echo   1 - Image compressor
echo   2 - RGB to grayscale
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
if not exist "riscv_jpeg_app.py" (
    echo ERROR: riscv_jpeg_app.py was not found.
    goto AFTER_OPERATION
)

"jpeg_env\Scripts\python.exe" -u "riscv_jpeg_app.py"
if errorlevel 1 echo The compression application returned an error.
goto AFTER_OPERATION

:GRAYSCALE
if not exist "image_conversion_app.py" (
    echo ERROR: image_conversion_app.py was not found.
    goto AFTER_OPERATION
)

"jpeg_env\Scripts\python.exe" -u "image_conversion_app.py" --mode gray
if errorlevel 1 echo The grayscale operation returned an error.
goto AFTER_OPERATION

:COLORIZE
if not exist "image_conversion_app.py" (
    echo ERROR: image_conversion_app.py was not found.
    goto AFTER_OPERATION
)

"jpeg_env\Scripts\python.exe" -u "image_conversion_app.py" --mode color
if errorlevel 1 echo The colourization operation returned an error.
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

:EXIT_APP
endlocal
exit /b