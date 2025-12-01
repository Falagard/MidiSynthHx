#!/bin/bash
# build_wasm.sh
# Build TinySoundFont for WebAssembly

# Ensure emscripten is installed and active
# Install from: https://emscripten.org/docs/getting_started/downloads.html
# Activate with: source /path/to/emsdk/emsdk_env.sh

# Build command
emcc tsf_wasm.cpp ../cpp/tsf_bridge.cpp \
    -I../cpp \
    -I../cpp/tsf \
    -O3 \
    -s WASM=1 \
    -s EXPORTED_FUNCTIONS='["_wasm_tsf_init_memory","_wasm_tsf_close","_wasm_tsf_set_output","_wasm_tsf_note_on","_wasm_tsf_note_off","_wasm_tsf_set_preset","_wasm_tsf_render","_wasm_tsf_note_off_all","_wasm_tsf_active_voices","_malloc","_free"]' \
    -s EXPORTED_RUNTIME_METHODS='["ccall","cwrap","getValue","setValue"]' \
    -s ALLOW_MEMORY_GROWTH=1 \
    -s MODULARIZE=1 \
    -s EXPORT_NAME='TSFModule' \
    -s ENVIRONMENT='web' \
    -s TOTAL_MEMORY=16MB \
    --bind \
    -o tsf.js

echo "Build complete. Output: tsf.js and tsf.wasm"
echo "Copy these files to your web project's assets directory"
