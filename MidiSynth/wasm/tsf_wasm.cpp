// tsf_wasm.cpp
// WebAssembly wrapper for TinySoundFont
// Build with Emscripten

#define TSF_IMPLEMENTATION
#include "../cpp/tsf/tsf.h"

#include <emscripten.h>
#include <emscripten/bind.h>
#include <stdlib.h>

using namespace emscripten;

// Internal handle structure
struct TSFSynth {
    tsf* synth;
    int sampleRate;
    int channels;
};

// EMSCRIPTEN_KEEPALIVE ensures these functions are exported to JavaScript
extern "C" {

// Initialize synth from memory buffer
// JavaScript will need to load the SF2 file and pass it as a Uint8Array
EMSCRIPTEN_KEEPALIVE
TSFSynth* wasm_tsf_init_memory(const void* buffer, int size) {
    if (!buffer || size <= 0) return nullptr;
    
    tsf* synth = tsf_load_memory(buffer, size);
    if (!synth) return nullptr;
    
    TSFSynth* handle = (TSFSynth*)malloc(sizeof(TSFSynth));
    if (!handle) {
        tsf_close(synth);
        return nullptr;
    }
    
    handle->synth = synth;
    handle->sampleRate = 44100;
    handle->channels = 2;
    
    // Set default output
    tsf_set_output(synth, TSF_STEREO_INTERLEAVED, 44100, 0.0f);
    
    return handle;
}

EMSCRIPTEN_KEEPALIVE
void wasm_tsf_close(TSFSynth* handle) {
    if (!handle) return;
    if (handle->synth) tsf_close(handle->synth);
    free(handle);
}

EMSCRIPTEN_KEEPALIVE
void wasm_tsf_set_output(TSFSynth* handle, int sample_rate, int channels) {
    if (!handle) return;
    
    handle->sampleRate = sample_rate;
    handle->channels = channels;
    
    enum TSFOutputMode mode = (channels == 1) ? TSF_MONO : TSF_STEREO_INTERLEAVED;
    tsf_set_output(handle->synth, mode, sample_rate, 0.0f);
}

EMSCRIPTEN_KEEPALIVE
void wasm_tsf_note_on(TSFSynth* handle, int channel, int note, int velocity) {
    if (!handle) return;
    float vel = velocity / 127.0f;
    tsf_channel_note_on(handle->synth, channel, note, vel);
}

EMSCRIPTEN_KEEPALIVE
void wasm_tsf_note_off(TSFSynth* handle, int channel, int note) {
    if (!handle) return;
    tsf_channel_note_off(handle->synth, channel, note);
}

EMSCRIPTEN_KEEPALIVE
void wasm_tsf_set_preset(TSFSynth* handle, int channel, int bank, int preset) {
    if (!handle) return;
    tsf_channel_set_bank_preset(handle->synth, channel, bank, preset);
}

EMSCRIPTEN_KEEPALIVE
int wasm_tsf_render(TSFSynth* handle, float* buffer, int sample_count) {
    if (!handle || !buffer || sample_count <= 0) return 0;
    tsf_render_float(handle->synth, buffer, sample_count, 0);
    return sample_count;
}

EMSCRIPTEN_KEEPALIVE
void wasm_tsf_note_off_all(TSFSynth* handle) {
    if (!handle) return;
    tsf_note_off_all(handle->synth);
}

EMSCRIPTEN_KEEPALIVE
int wasm_tsf_active_voices(TSFSynth* handle) {
    if (!handle) return 0;
    return tsf_active_voice_count(handle->synth);
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
