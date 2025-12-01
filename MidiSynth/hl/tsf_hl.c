// tsf_hl.c
// HashLink native bindings for TinySoundFont bridge
// Build with: haxelib run haxe-hl-native compile

#define HL_NAME(n) tsf_##n
#include <hl.h>

// Include the TSF bridge (we'll link against the compiled library)
#include "../cpp/tsf_bridge.h"

// Define HashLink type for our handle
// In HL, we use vdynamic* to represent opaque pointers
#define _TSFHANDLE _ABSTRACT(tsf_handle)

// Initialize synthesizer from file path
// Haxe signature: function init(path:String):TSFHandle
HL_PRIM vdynamic* HL_NAME(init)(vbyte* path) {
    TSFHandle handle = tsf_bridge_init((const char*)path);
    if (!handle) return NULL;
    
    vdynamic* dyn = hl_alloc_dynamic(&hlt_dyn);
    dyn->v.ptr = handle;
    return dyn;
}
DEFINE_PRIM(_TSFHANDLE, init, _BYTES);

// Initialize synthesizer from memory buffer
// Haxe signature: function initMemory(buffer:hl.Bytes, size:Int):TSFHandle
HL_PRIM vdynamic* HL_NAME(init_memory)(vbyte* buffer, int size) {
    TSFHandle handle = tsf_bridge_init_memory(buffer, size);
    if (!handle) return NULL;
    
    vdynamic* dyn = hl_alloc_dynamic(&hlt_dyn);
    dyn->v.ptr = handle;
    return dyn;
}
DEFINE_PRIM(_TSFHANDLE, init_memory, _BYTES _I32);

// Close and free synthesizer
// Haxe signature: function close(handle:TSFHandle):Void
HL_PRIM void HL_NAME(close)(vdynamic* handle) {
    if (!handle || !handle->v.ptr) return;
    tsf_bridge_close((TSFHandle)handle->v.ptr);
    handle->v.ptr = NULL;
}
DEFINE_PRIM(_VOID, close, _TSFHANDLE);

// Set output configuration
// Haxe signature: function setOutput(handle:TSFHandle, sampleRate:Int, channels:Int):Void
HL_PRIM void HL_NAME(set_output)(vdynamic* handle, int sample_rate, int channels) {
    if (!handle || !handle->v.ptr) return;
    tsf_bridge_set_output((TSFHandle)handle->v.ptr, sample_rate, channels);
}
DEFINE_PRIM(_VOID, set_output, _TSFHANDLE _I32 _I32);

// Note on
// Haxe signature: function noteOn(handle:TSFHandle, channel:Int, note:Int, velocity:Int):Void
HL_PRIM void HL_NAME(note_on)(vdynamic* handle, int channel, int note, int velocity) {
    if (!handle || !handle->v.ptr) return;
    tsf_bridge_note_on((TSFHandle)handle->v.ptr, channel, note, velocity);
}
DEFINE_PRIM(_VOID, note_on, _TSFHANDLE _I32 _I32 _I32);

// Note off
// Haxe signature: function noteOff(handle:TSFHandle, channel:Int, note:Int):Void
HL_PRIM void HL_NAME(note_off)(vdynamic* handle, int channel, int note) {
    if (!handle || !handle->v.ptr) return;
    tsf_bridge_note_off((TSFHandle)handle->v.ptr, channel, note);
}
DEFINE_PRIM(_VOID, note_off, _TSFHANDLE _I32 _I32);

// Set preset (instrument)
// Haxe signature: function setPreset(handle:TSFHandle, channel:Int, bank:Int, preset:Int):Void
HL_PRIM void HL_NAME(set_preset)(vdynamic* handle, int channel, int bank, int preset) {
    if (!handle || !handle->v.ptr) return;
    tsf_bridge_set_preset((TSFHandle)handle->v.ptr, channel, bank, preset);
}
DEFINE_PRIM(_VOID, set_preset, _TSFHANDLE _I32 _I32 _I32);

// Render audio samples
// Haxe signature: function render(handle:TSFHandle, buffer:hl.Bytes, sampleCount:Int):Int
HL_PRIM int HL_NAME(render)(vdynamic* handle, vbyte* buffer, int sample_count) {
    if (!handle || !handle->v.ptr || !buffer) return 0;
    return tsf_bridge_render((TSFHandle)handle->v.ptr, (float*)buffer, sample_count);
}
DEFINE_PRIM(_I32, render, _TSFHANDLE _BYTES _I32);

// Stop all notes
// Haxe signature: function noteOffAll(handle:TSFHandle):Void
HL_PRIM void HL_NAME(note_off_all)(vdynamic* handle) {
    if (!handle || !handle->v.ptr) return;
    tsf_bridge_note_off_all((TSFHandle)handle->v.ptr);
}
DEFINE_PRIM(_VOID, note_off_all, _TSFHANDLE);

// Get active voice count
// Haxe signature: function activeVoices(handle:TSFHandle):Int
HL_PRIM int HL_NAME(active_voices)(vdynamic* handle) {
    if (!handle || !handle->v.ptr) return 0;
    return tsf_bridge_active_voices((TSFHandle)handle->v.ptr);
}
DEFINE_PRIM(_I32, active_voices, _TSFHANDLE);
