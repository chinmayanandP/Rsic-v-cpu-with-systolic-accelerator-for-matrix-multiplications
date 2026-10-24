@echo off
setlocal
title Create Portable Phase 1 Vivado Project

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..\..\..") do set "REPO_ROOT=%%~fI"
set "TCL_SCRIPT=%REPO_ROOT%\phase1_riscv_cpu\scripts\vivado\create_project.tcl"

if not exist "%TCL_SCRIPT%" (
    echo ERROR: Project-creation Tcl script was not found:
    echo %TCL_SCRIPT%
    exit /b 1
)

set "VIVADO_COMMAND="

if defined XILINX_VIVADO (
    if exist "%XILINX_VIVADO%\bin\vivado.bat" (
        set "VIVADO_COMMAND=%XILINX_VIVADO%\bin\vivado.bat"
    )
)

if not defined VIVADO_COMMAND (
    for /f "delims=" %%I in ('where vivado.bat 2^>nul') do (
        if not defined VIVADO_COMMAND set "VIVADO_COMMAND=%%I"
    )
)

if not defined VIVADO_COMMAND (
    if exist "D:\vivado\2026.1\Vivado\bin\vivado.bat" (
        set "VIVADO_COMMAND=D:\vivado\2026.1\Vivado\bin\vivado.bat"
    )
)

if not defined VIVADO_COMMAND (
    echo ERROR: Vivado was not found.
    echo Set XILINX_VIVADO or add Vivado to PATH.
    exit /b 1
)

echo Vivado launcher: %VIVADO_COMMAND%
echo Repository: %REPO_ROOT%
echo.

call "%VIVADO_COMMAND%" -mode batch -source "%TCL_SCRIPT%"
set "VIVADO_RESULT=%ERRORLEVEL%"

if not "%VIVADO_RESULT%"=="0" (
    echo.
    echo ERROR: Vivado project creation failed with code %VIVADO_RESULT%.
    exit /b %VIVADO_RESULT%
)

echo.
echo Project created successfully:
echo %REPO_ROOT%\build\vivado\phase1_riscv_cpu.xpr

endlocal
exit /b 0

