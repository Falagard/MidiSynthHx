// tsf_wasm.cpp
// WebAssembly wrapper for TinySoundFont
// Build with Emscripten

#define TSF_IMPLEMENTATION
#include "../cpp/tsf/tsf.h"
#include "../cpp/tsf_bridge.h"

#include <emscripten.h>
#include <emscripten/bind.h>

using namespace emscripten;

// EMSCRIPTEN_KEEPALIVE ensures these functions are exported to JavaScript
extern "C" {

// Initialize synth from memory buffer
// JavaScript will need to load the SF2 file and pass it as a Uint8Array
EMSCRIPTEN_KEEPALIVE
TSFHandle wasm_tsf_init_memory(const void* buffer, int size) {
    return tsf_bridge_init_memory(buffer, size);
}

EMSCRIPTEN_KEEPALIVE
void wasm_tsf_close(TSFHandle handle) {
    tsf_bridge_close(handle);
}

EMSCRIPTEN_KEEPALIVE
void wasm_tsf_set_output(TSFHandle handle, int sample_rate, int channels) {
    tsf_bridge_set_output(handle, sample_rate, channels);
}

EMSCRIPTEN_KEEPALIVE
void wasm_tsf_note_on(TSFHandle handle, int channel, int note, int velocity) {
    tsf_bridge_note_on(handle, channel, note, velocity);
}

EMSCRIPTEN_KEEPALIVE
void wasm_tsf_note_off(TSFHandle handle, int channel, int note) {
    tsf_bridge_note_off(handle, channel, note);
}

EMSCRIPTEN_KEEPALIVE
void wasm_tsf_set_preset(TSFHandle handle, int channel, int bank, int preset) {
    tsf_bridge_set_preset(handle, channel, bank, preset);
}

EMSCRIPTEN_KEEPALIVE
int wasm_tsf_render(TSFHandle handle, float* buffer, int sample_count) {
    return tsf_bridge_render(handle, buffer, sample_count);
}

EMSCRIPTEN_KEEPALIVE
void wasm_tsf_note_off_all(TSFHandle handle) {
    tsf_bridge_note_off_all(handle);
}

EMSCRIPTEN_KEEPALIVE
int wasm_tsf_active_voices(TSFHandle handle) {
    return tsf_bridge_active_voices(handle);
}

} // extern "C"

// Embind bindings (alternative API, more type-safe from JS)
EMSCRIPTEN_BINDINGS(tsf_module) {
    function("initMemory", &wasm_tsf_init_memory, allow_raw_pointers());
    function("close", &wasm_tsf_close, allow_raw_pointers());
    function("setOutput", &wasm_tsf_set_output, allow_raw_pointers());
    function("noteOn", &wasm_tsf_note_on, allow_raw_pointers());
    function("noteOff", &wasm_tsf_note_off, allow_raw_pointers());
    function("setPreset", &wasm_tsf_set_preset, allow_raw_pointers());
    function("render", &wasm_tsf_render, allow_raw_pointers());
    function("noteOffAll", &wasm_tsf_note_off_all, allow_raw_pointers());
    function("activeVoices", &wasm_tsf_active_voices, allow_raw_pointers());
}
