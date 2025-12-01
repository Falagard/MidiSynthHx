@echo off
REM Build script for tsf.hdll (HashLink native library)
REM Compiles TinySoundFont bridge for HashLink on Windows

setlocal enabledelayedexpansion

echo ========================================
echo Building tsf.hdll for HashLink
echo ========================================
echo.

REM ==============================
REM 1. Find HashLink installation
REM ==============================
set HASHLINK_PATH=%HASHLINK_PATH%

if "%HASHLINK_PATH%"=="" (
    echo HASHLINK_PATH not set, attempting to locate hl.exe...
    for %%i in (hl.exe) do set HL_EXE=%%~$PATH:i
    if "!HL_EXE!"=="" (
        echo ERROR: Cannot find hl.exe in PATH and HASHLINK_PATH is not set
        echo Please set HASHLINK_PATH environment variable to your HashLink installation directory
        echo Example: set HASHLINK_PATH=C:\HashLink
        exit /b 1
    )
    for %%i in ("!HL_EXE!") do set HASHLINK_PATH=%%~dpi
    set HASHLINK_PATH=!HASHLINK_PATH:~0,-1!
    echo Found HashLink at: !HASHLINK_PATH!
) else (
    echo Using HASHLINK_PATH: %HASHLINK_PATH%
)

REM Verify HashLink files exist
if not exist "%HASHLINK_PATH%\include\hl.h" (
    echo ERROR: Cannot find hl.h in %HASHLINK_PATH%\include\
    echo Please verify HASHLINK_PATH is correct
    exit /b 1
)

if not exist "%HASHLINK_PATH%\libhl.lib" (
    echo ERROR: Cannot find libhl.lib in %HASHLINK_PATH%
    echo Please verify HASHLINK_PATH is correct
    exit /b 1
)

echo HashLink headers and libraries found OK
echo.

REM ==============================
REM 2. Setup Visual Studio environment
REM ==============================
echo Setting up Visual Studio build environment...

REM Try to find vswhere
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" (
    echo ERROR: Cannot find vswhere.exe
    echo Please ensure Visual Studio 2017 or later is installed
    exit /b 1
)

REM Find latest Visual Studio installation
for /f "usebackq tokens=*" %%i in (`"%VSWHERE%" -latest -property installationPath`) do (
    set VS_PATH=%%i
)

if "%VS_PATH%"=="" (
    echo ERROR: Cannot locate Visual Studio installation
    exit /b 1
)

echo Found Visual Studio at: %VS_PATH%

REM Setup build environment
set "VCVARS=%VS_PATH%\VC\Auxiliary\Build\vcvars64.bat"
if not exist "%VCVARS%" (
    echo ERROR: Cannot find vcvars64.bat at %VCVARS%
    exit /b 1
)

REM Call vcvars64.bat to setup environment
call "%VCVARS%" >nul 2>&1
if errorlevel 1 (
    echo ERROR: Failed to setup Visual Studio environment
    exit /b 1
)

echo Build environment configured
echo.

REM ==============================
REM 3. Clean previous build artifacts
REM ==============================
if exist tsf_bridge.obj del /Q tsf_bridge.obj
if exist tsf_hl.obj del /Q tsf_hl.obj
if exist tsfhl.hdll del /Q tsfhl.hdll
if exist tsfhl.lib del /Q tsfhl.lib
if exist tsfhl.exp del /Q tsfhl.exp

REM ==============================
REM 4. Compile tsf_bridge.cpp (C++ TinySoundFont bridge)
REM ==============================
echo [1/3] Compiling tsf_bridge.cpp...
cl /c /EHsc /O2 /MD /nologo ^
    /I..\cpp ^
    ..\cpp\tsf_bridge.cpp ^
    /Fo:tsf_bridge.obj

if errorlevel 1 (
    echo ERROR: Failed to compile tsf_bridge.cpp
    exit /b 1
)
echo tsf_bridge.obj created successfully
echo.

REM 5. Compile tsf_hl.c (HashLink bindings)
REM ==============================
echo [2/3] Compiling tsf_hl.c...
cl /c /O2 /MD /nologo ^
    /I"%HASHLINK_PATH%\include" ^
    /I..\cpp ^
    tsf_hl.c ^
    /Fo:tsf_hl.obj

if errorlevel 1 (
    echo ERROR: Failed to compile tsf_hl.c
    exit /b 1
)
echo tsf_hl.obj created successfully
echo.

REM 6. Link into tsfhl.hdll
REM ==============================
echo [3/3] Linking tsfhl.hdll...
link /DLL /NOLOGO ^
    /OUT:tsfhl.hdll ^
    tsf_hl.obj tsf_bridge.obj ^
    libhl.lib ^
    /LIBPATH:"%HASHLINK_PATH%"

if errorlevel 1 (
    echo ERROR: Failed to link tsf.hdll
    exit /b 1
)

echo.
echo ========================================
echo Build completed successfully!
echo ========================================
echo Output: tsfhl.hdll
echo.
echo Next steps:
echo 1. Copy tsf.hdll to Export/hl/bin/ (or let Lime do it automatically)
echo 2. Run: lime build hl
echo 3. Run: lime test hl
echo.

REM ==============================
REM 7. Optional: Copy to HashLink directory
REM ==============================
set /p COPY_TO_HL="Copy tsfhl.hdll to HashLink directory? (y/n): "
if /i "%COPY_TO_HL%"=="y" (
    copy tsfhl.hdll "%HASHLINK_PATH%\tsfhl.hdll" >nul
    echo Copied to %HASHLINK_PATH%\tsfhl.hdll
)

endlocal
