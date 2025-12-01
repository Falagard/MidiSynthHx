// tsf_hl.c
// HashLink native bindings for TinySoundFont bridge
// Build with: haxelib run haxe-hl-native compile

#define HL_NAME(n) tsfhl_##n
#include <hl.h>

// Include the TSF bridge (we'll link against the compiled library)
#include "../cpp/tsf_bridge.h"

// Define HashLink type for our handle
// In HL, we use vdynamic* to represent opaque pointers
#define _TSFHANDLE _ABSTRACT(tsf_handle)

// Initialize synthesizer from file path
// Haxe signature: function init(path:String):TSFHandle
HL_PRIM vdynamic* HL_NAME(init)(vstring* path) {
    if (!path) return NULL;
    int len = path->length;
    char* buf = (char*)malloc(len + 1);
    if (!buf) return NULL;
    memcpy(buf, path->bytes, len);
    buf[len] = '\0';
    TSFHandle handle = tsf_bridge_init(buf);
    free(buf);
    if (!handle) return NULL;
    
    vdynamic* dyn = hl_alloc_dynamic(&hlt_dyn);
    dyn->v.ptr = handle;
    return dyn;
}
DEFINE_PRIM(_DYN, init, _STRING);

// Initialize synthesizer from memory buffer
// Haxe signature: function initMemory(buffer:hl.Bytes, size:Int):TSFHandle
HL_PRIM vdynamic* HL_NAME(init_memory)(vbyte* buffer, int size) {
    TSFHandle handle = tsf_bridge_init_memory(buffer, size);
    if (!handle) return NULL;
    
    vdynamic* dyn = hl_alloc_dynamic(&hlt_dyn);
    dyn->v.ptr = handle;
    return dyn;
}
DEFINE_PRIM(_DYN, init_memory, _BYTES _I32);

// Close and free synthesizer
// Haxe signature: function close(handle:TSFHandle):Void
HL_PRIM void HL_NAME(close)(vdynamic* handle) {
    if (!handle || !handle->v.ptr) return;
    tsf_bridge_close((TSFHandle)handle->v.ptr);
    handle->v.ptr = NULL;
}
DEFINE_PRIM(_VOID, close, _DYN);

// Set output configuration
// Haxe signature: function setOutput(handle:TSFHandle, sampleRate:Int, channels:Int):Void
HL_PRIM void HL_NAME(set_output)(vdynamic* handle, int sample_rate, int channels) {
    if (!handle || !handle->v.ptr) return;
    tsf_bridge_set_output((TSFHandle)handle->v.ptr, sample_rate, channels);
}
DEFINE_PRIM(_VOID, set_output, _DYN _I32 _I32);

// Note on
// Haxe signature: function noteOn(handle:TSFHandle, channel:Int, note:Int, velocity:Int):Void
HL_PRIM void HL_NAME(note_on)(vdynamic* handle, int channel, int note, int velocity) {
    if (!handle || !handle->v.ptr) return;
    tsf_bridge_note_on((TSFHandle)handle->v.ptr, channel, note, velocity);
}
DEFINE_PRIM(_VOID, note_on, _DYN _I32 _I32 _I32);

// Note off
// Haxe signature: function noteOff(handle:TSFHandle, channel:Int, note:Int):Void
HL_PRIM void HL_NAME(note_off)(vdynamic* handle, int channel, int note) {
    if (!handle || !handle->v.ptr) return;
    tsf_bridge_note_off((TSFHandle)handle->v.ptr, channel, note);
}
DEFINE_PRIM(_VOID, note_off, _DYN _I32 _I32);

// Set preset (instrument)
// Haxe signature: function setPreset(handle:TSFHandle, channel:Int, bank:Int, preset:Int):Void
HL_PRIM void HL_NAME(set_preset)(vdynamic* handle, int channel, int bank, int preset) {
    if (!handle || !handle->v.ptr) return;
    tsf_bridge_set_preset((TSFHandle)handle->v.ptr, channel, bank, preset);
}
DEFINE_PRIM(_VOID, set_preset, _DYN _I32 _I32 _I32);

// Set pitch bend
// Haxe signature: function pitchBend(handle:TSFHandle, channel:Int, pitchWheel:Int):Void
HL_PRIM void HL_NAME(pitch_bend)(vdynamic* handle, int channel, int pitch_wheel) {
    if (!handle || !handle->v.ptr) return;
    tsf_bridge_pitch_bend((TSFHandle)handle->v.ptr, channel, pitch_wheel);
}
DEFINE_PRIM(_VOID, pitch_bend, _DYN _I32 _I32);

// MIDI control change
// Haxe signature: function controlChange(handle:TSFHandle, channel:Int, controller:Int, value:Int):Void
HL_PRIM void HL_NAME(control_change)(vdynamic* handle, int channel, int controller, int value) {
    if (!handle || !handle->v.ptr) return;
    tsf_bridge_control_change((TSFHandle)handle->v.ptr, channel, controller, value);
}
DEFINE_PRIM(_VOID, control_change, _DYN _I32 _I32 _I32);

// Render audio samples
// Haxe signature: function render(handle:TSFHandle, buffer:hl.Bytes, sampleCount:Int):Int
HL_PRIM int HL_NAME(render)(vdynamic* handle, vbyte* buffer, int sample_count) {
    if (!handle || !handle->v.ptr || !buffer) return 0;
    return tsf_bridge_render((TSFHandle)handle->v.ptr, (float*)buffer, sample_count);
}
DEFINE_PRIM(_I32, render, _DYN _BYTES _I32);

// Stop all notes
// Haxe signature: function noteOffAll(handle:TSFHandle):Void
HL_PRIM void HL_NAME(note_off_all)(vdynamic* handle) {
    if (!handle || !handle->v.ptr) return;
    tsf_bridge_note_off_all((TSFHandle)handle->v.ptr);
}
DEFINE_PRIM(_VOID, note_off_all, _DYN);

// Get active voice count
// Haxe signature: function activeVoices(handle:TSFHandle):Int
HL_PRIM int HL_NAME(active_voices)(vdynamic* handle) {
    if (!handle || !handle->v.ptr) return 0;
    return tsf_bridge_active_voices((TSFHandle)handle->v.ptr);
}
DEFINE_PRIM(_I32, active_voices, _DYN);

// Set per-channel volume
// Haxe signature: function channelSetVolume(handle:TSFHandle, channel:Int, volume:Float):Void
HL_PRIM void HL_NAME(channel_set_volume)(vdynamic* handle, int channel, double volume) {
    if (!handle || !handle->v.ptr) return;
    tsf_bridge_channel_set_volume((TSFHandle)handle->v.ptr, channel, (float)volume);
}
DEFINE_PRIM(_VOID, channel_set_volume, _DYN _I32 _F64);
