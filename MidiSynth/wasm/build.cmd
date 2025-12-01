@echo off
REM Wrapper script that properly activates emsdk then builds

echo Activating emsdk...
call C:\Src\ge\emsdk\emsdk_env.bat

if "%EMSDK%"=="" (
  echo ERROR: Failed to activate emsdk
  exit /b 1
)

echo.
echo Building TinySoundFont WASM...
cd /d %~dp0

emcc tsf_wasm.cpp ..\cpp\tsf_bridge.cpp ^
    -I..\cpp ^
    -I..\cpp\tsf ^
    -O3 ^
    -s WASM=1 ^
    -s EXPORTED_FUNCTIONS="['_wasm_tsf_init_memory','_wasm_tsf_close','_wasm_tsf_set_output','_wasm_tsf_note_on','_wasm_tsf_note_off','_wasm_tsf_set_preset','_wasm_tsf_render','_wasm_tsf_note_off_all','_wasm_tsf_active_voices','_malloc','_free']" ^
    -s EXPORTED_RUNTIME_METHODS="['ccall','cwrap','getValue','setValue']" ^
    -s ALLOW_MEMORY_GROWTH=1 ^
    -s MODULARIZE=1 ^
    -s EXPORT_NAME="TSFModule" ^
    -s ENVIRONMENT="web" ^
    -s TOTAL_MEMORY=16MB ^
    --bind ^
    -o tsf.js

if %ERRORLEVEL% NEQ 0 (
  echo Build failed.
  exit /b 1
)

echo.
echo Build complete:
echo   tsf.js
echo   tsf.wasm
echo.
