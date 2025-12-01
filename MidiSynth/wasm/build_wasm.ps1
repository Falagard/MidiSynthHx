# Build TinySoundFont for WebAssembly

$ErrorActionPreference = "Stop"

Write-Host "Activating emsdk..." -ForegroundColor Cyan

# Source emsdk environment
Push-Location C:\Src\ge\emsdk
& cmd /c "emsdk_env.bat && set" | ForEach-Object {
    if ($_ -match '^([^=]+)=(.*)$') {
        [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
    }
}
Pop-Location

# Verify emcc is available
if (-not (Get-Command emcc -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: emcc not found after emsdk activation" -ForegroundColor Red
    exit 1
}

Write-Host "`nBuilding TinySoundFont WASM..." -ForegroundColor Cyan

emcc tsf_wasm.cpp `
    -I..\cpp `
    -I..\cpp\tsf `
    -O3 `
    -s WASM=1 `
    -s "EXPORTED_FUNCTIONS=['_wasm_tsf_init_memory','_wasm_tsf_close','_wasm_tsf_set_output','_wasm_tsf_note_on','_wasm_tsf_note_off','_wasm_tsf_set_preset','_wasm_tsf_render','_wasm_tsf_note_off_all','_wasm_tsf_active_voices','_malloc','_free']" `
    -s "EXPORTED_RUNTIME_METHODS=['ccall','cwrap','getValue','setValue']" `
    -s ALLOW_MEMORY_GROWTH=1 `
    -s MODULARIZE=1 `
    -s EXPORT_NAME="TSFModule" `
    -s ENVIRONMENT="web" `
    -s TOTAL_MEMORY=16MB `
    --bind `
    -o tsf.js

if ($LASTEXITCODE -ne 0) {
    Write-Host "`nBuild failed." -ForegroundColor Red
    exit 1
}

Write-Host "`nBuild complete:" -ForegroundColor Green
Write-Host "  tsf.js"
Write-Host "  tsf.wasm"
Write-Host ""
