// tsf_hl_combined.cpp
// Combined compilation unit for HashLink native library
// This ensures TSF_IMPLEMENTATION is defined only once

// First, compile the C++ bridge with TSF implementation
#include "../cpp/tsf_bridge.cpp"

// Then compile the HashLink bindings
// We need to wrap the C code in extern "C" since we're compiling as C++
extern "C" {
    #include <hl.h>
}

// Now include the HashLink wrapper logic
// We can't directly #include the .c file because it has its own includes
// So we'll manually include the binding code here

#include "../cpp/tsf_bridge.h"

// Define HashLink type for our handle
#define _TSFHANDLE _DYN // Simplify: use dynamic handle type
#define HL_NAME(n) tsfprim_##n

extern "C" { // Begin C linkage for HL primitives
// Initialize synthesizer from file path
HL_PRIM vdynamic* HL_NAME(init)(vstring* path) {
    const char* cpath = (const char*)path->bytes;
    TSFHandle handle = tsf_bridge_init(cpath);
    if (!handle) return NULL;
    
    vdynamic* dyn = hl_alloc_dynamic(&hlt_dyn);
    dyn->v.ptr = handle;
    return dyn;
}
DEFINE_PRIM(_DYN, init, _STRING);

// Initialize synthesizer from memory buffer
HL_PRIM vdynamic* HL_NAME(init_memory)(vbyte* buffer, int size) {
    TSFHandle handle = tsf_bridge_init_memory(buffer, size);
    if (!handle) return NULL;
    
    vdynamic* dyn = hl_alloc_dynamic(&hlt_dyn);
    dyn->v.ptr = handle;
    return dyn;
}
DEFINE_PRIM(_DYN, init_memory, _BYTES _I32);

// Close and free synthesizer
HL_PRIM void HL_NAME(close)(vdynamic* handle) {
    if (!handle || !handle->v.ptr) return;
    tsf_bridge_close((TSFHandle)handle->v.ptr);
    handle->v.ptr = NULL;
}
DEFINE_PRIM(_VOID, close, _DYN);

// Set output configuration
HL_PRIM void HL_NAME(set_output)(vdynamic* handle, int sample_rate, int channels) {
    if (!handle || !handle->v.ptr) return;
    tsf_bridge_set_output((TSFHandle)handle->v.ptr, sample_rate, channels);
}
DEFINE_PRIM(_VOID, set_output, _DYN _I32 _I32);

// Note on
HL_PRIM void HL_NAME(note_on)(vdynamic* handle, int channel, int note, int velocity) {
    if (!handle || !handle->v.ptr) return;
    tsf_bridge_note_on((TSFHandle)handle->v.ptr, channel, note, velocity);
}
DEFINE_PRIM(_VOID, note_on, _DYN _I32 _I32 _I32);

// Note off
HL_PRIM void HL_NAME(note_off)(vdynamic* handle, int channel, int note) {
    if (!handle || !handle->v.ptr) return;
    tsf_bridge_note_off((TSFHandle)handle->v.ptr, channel, note);
}
DEFINE_PRIM(_VOID, note_off, _DYN _I32 _I32);

// Set preset (instrument)
HL_PRIM void HL_NAME(set_preset)(vdynamic* handle, int channel, int bank, int preset) {
    if (!handle || !handle->v.ptr) return;
    tsf_bridge_set_preset((TSFHandle)handle->v.ptr, channel, bank, preset);
}
DEFINE_PRIM(_VOID, set_preset, _DYN _I32 _I32 _I32);

// Render audio samples
HL_PRIM int HL_NAME(render)(vdynamic* handle, vbyte* buffer, int sample_count) {
    if (!handle || !handle->v.ptr || !buffer) return 0;
    return tsf_bridge_render((TSFHandle)handle->v.ptr, (float*)buffer, sample_count);
}
DEFINE_PRIM(_I32, render, _DYN _BYTES _I32);

// Stop all notes
HL_PRIM void HL_NAME(note_off_all)(vdynamic* handle) {
    if (!handle || !handle->v.ptr) return;
    tsf_bridge_note_off_all((TSFHandle)handle->v.ptr);
}
DEFINE_PRIM(_VOID, note_off_all, _DYN);

// Get active voice count
HL_PRIM int HL_NAME(active_voices)(vdynamic* handle) {
    if (!handle || !handle->v.ptr) return 0;
    return tsf_bridge_active_voices((TSFHandle)handle->v.ptr);
}
DEFINE_PRIM(_I32, active_voices, _DYN);
} // end extern "C"
