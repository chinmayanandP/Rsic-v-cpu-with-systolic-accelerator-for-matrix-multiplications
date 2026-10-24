@echo off
title RISC-V CPU Matrix Multiplication

cd /d "%~dp0"

:START
cls

where py >nul 2>nul

if %errorlevel%==0 (
    py -3 matrix_input.py
) else (
    python matrix_input.py
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

if errorlevel 2 exit /b
if errorlevel 1 goto START