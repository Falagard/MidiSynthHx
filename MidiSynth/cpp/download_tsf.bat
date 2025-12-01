@echo off
REM Download the full TinySoundFont header from GitHub

echo Downloading TinySoundFont...

curl -L https://raw.githubusercontent.com/schellingb/TinySoundFont/master/tsf.h -o tsf\tsf.h

if %ERRORLEVEL% EQU 0 (
    echo [OK] TinySoundFont downloaded successfully to tsf\tsf.h
    dir tsf\tsf.h | find "tsf.h"
) else (
    echo [ERROR] Failed to download TinySoundFont
    echo Please download manually from:
    echo https://github.com/schellingb/TinySoundFont/blob/master/tsf.h
    exit /b 1
)
