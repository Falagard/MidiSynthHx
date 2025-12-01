// tsf_bridge.cpp
// Implementation of C API wrapper for TinySoundFont

#define TSF_IMPLEMENTATION
#include "tsf/tsf.h"
#include "tsf_bridge.h"
#ifdef HXCPP_API
#include <hx/CFFI.h>
#endif
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Internal struct to hold synth state
struct TSFSynth {
    tsf* synth;
    int sampleRate;
    int channels;
};

TSFHandle tsf_bridge_init(const char* path) {
    if (!path) return NULL;
    
    tsf* synth = tsf_load_filename(path);
    if (!synth) {
        fprintf(stderr, "Failed to load SoundFont: %s\n", path);
        return NULL;
    }
    
    TSFSynth* handle = (TSFSynth*)malloc(sizeof(TSFSynth));
    if (!handle) {
        tsf_close(synth);
        return NULL;
    }
    
    handle->synth = synth;
    handle->sampleRate = 44100;
    handle->channels = 2;
    
    // Set default output to stereo, 44.1kHz, 0dB gain
    tsf_set_output(synth, TSF_STEREO_INTERLEAVED, 44100, 0.0f);
    
    // Initialize channel 0 to use preset 0 (piano in most SoundFonts)
    tsf_channel_set_bank_preset(synth, 0, 0, 0);
    
    return (TSFHandle)handle;
}

TSFHandle tsf_bridge_init_memory(const void* buffer, int size) {
    if (!buffer || size <= 0) return NULL;
    
    tsf* synth = tsf_load_memory(buffer, size);
    if (!synth) {
        fprintf(stderr, "Failed to load SoundFont from memory\n");
        return NULL;
    }
    
    TSFSynth* handle = (TSFSynth*)malloc(sizeof(TSFSynth));
    if (!handle) {
        tsf_close(synth);
        return NULL;
    }
    
    handle->synth = synth;
    handle->sampleRate = 44100;
    handle->channels = 2;
    
    tsf_set_output(synth, TSF_STEREO_INTERLEAVED, 44100, 0.0f);
    tsf_channel_set_bank_preset(synth, 0, 0, 0);
    
    return (TSFHandle)handle;
}

void tsf_bridge_close(TSFHandle handle) {
    if (!handle) return;
    
    TSFSynth* synth = (TSFSynth*)handle;
    if (synth->synth) {
        tsf_close(synth->synth);
    }
    free(synth);
}

void tsf_bridge_set_output(TSFHandle handle, int sample_rate, int channels) {
    if (!handle) return;
    
    TSFSynth* synth = (TSFSynth*)handle;
    synth->sampleRate = sample_rate;
    synth->channels = channels;
    
    enum TSFOutputMode mode = (channels == 1) ? TSF_MONO : TSF_STEREO_INTERLEAVED;
    tsf_set_output(synth->synth, mode, sample_rate, 0.0f);
}

void tsf_bridge_note_on(TSFHandle handle, int channel, int note, int velocity) {
    if (!handle) return;
    
    TSFSynth* synth = (TSFSynth*)handle;
    
    // Convert MIDI velocity (0-127) to float (0.0-1.0)
    float vel = velocity / 127.0f;
    
    tsf_channel_note_on(synth->synth, channel, note, vel);
}

void tsf_bridge_note_off(TSFHandle handle, int channel, int note) {
    if (!handle) return;
    
    TSFSynth* synth = (TSFSynth*)handle;
    tsf_channel_note_off(synth->synth, channel, note);
}

void tsf_bridge_set_preset(TSFHandle handle, int channel, int bank, int preset) {
    if (!handle) return;
    
    TSFSynth* synth = (TSFSynth*)handle;
    tsf_channel_set_bank_preset(synth->synth, channel, bank, preset);
}

int tsf_bridge_render(TSFHandle handle, void* buffer, int sample_count) {
    if (!handle || !buffer || sample_count <= 0) return 0;
    
    TSFSynth* synth = (TSFSynth*)handle;
    
    // Clear buffer first (flag_mixing = 0)
    tsf_render_float(synth->synth, (float*)buffer, sample_count, 0);
    
    return sample_count;
}

void tsf_bridge_note_off_all(TSFHandle handle) {
    if (!handle) return;
    
    TSFSynth* synth = (TSFSynth*)handle;
    tsf_note_off_all(synth->synth);
}

int tsf_bridge_active_voices(TSFHandle handle) {
    if (!handle) return 0;
    
    TSFSynth* synth = (TSFSynth*)handle;
    return tsf_active_voice_count(synth->synth);
}

#ifdef HXCPP_API
// CFFI wrappers for Haxe cpp.Lib.load
static value cffi_tsf_init(value vpath) {
    const char* path = val_string(vpath);
    TSFHandle h = tsf_bridge_init(path);
    return alloc_int((intptr_t)h);
}
DEFINE_PRIM(cffi_tsf_init,1);

static value cffi_tsf_close(value vhandle) {
    TSFHandle h = (TSFHandle)(intptr_t)val_int(vhandle);
    tsf_bridge_close(h);
    return alloc_null();
}
DEFINE_PRIM(cffi_tsf_close,1);

static value cffi_tsf_set_output(value vhandle, value vsr, value vch) {
    TSFHandle h = (TSFHandle)(intptr_t)val_int(vhandle);
    int sr = val_int(vsr);
    int ch = val_int(vch);
    tsf_bridge_set_output(h, sr, ch);
    return alloc_null();
}
DEFINE_PRIM(cffi_tsf_set_output,3);

static value cffi_tsf_note_on(value vhandle, value vchan, value vnote, value vvel) {
    TSFHandle h = (TSFHandle)(intptr_t)val_int(vhandle);
    tsf_bridge_note_on(h, val_int(vchan), val_int(vnote), val_int(vvel));
    return alloc_null();
}
DEFINE_PRIM(cffi_tsf_note_on,4);

static value cffi_tsf_note_off(value vhandle, value vchan, value vnote) {
    TSFHandle h = (TSFHandle)(intptr_t)val_int(vhandle);
    tsf_bridge_note_off(h, val_int(vchan), val_int(vnote));
    return alloc_null();
}
DEFINE_PRIM(cffi_tsf_note_off,3);

static value cffi_tsf_set_preset(value vhandle, value vchan, value vbank, value vpreset) {
    TSFHandle h = (TSFHandle)(intptr_t)val_int(vhandle);
    tsf_bridge_set_preset(h, val_int(vchan), val_int(vbank), val_int(vpreset));
    return alloc_null();
}
DEFINE_PRIM(cffi_tsf_set_preset,4);

static value cffi_tsf_render(value vhandle, value vbuf, value vsamples) {
    TSFHandle h = (TSFHandle)(intptr_t)val_int(vhandle);
    int samples = val_int(vsamples);
    buffer buf = val_to_buffer(vbuf);
    float* ptr = (float*)buffer_data(buf);
    int rendered = tsf_bridge_render(h, ptr, samples);
    return alloc_int(rendered);
}
DEFINE_PRIM(cffi_tsf_render,3);

// Explicit bytes render primitive (alias) for audio callback usage
static value cffi_tsf_render_bytes(value vhandle, value vbuf, value vsamples) {
    return cffi_tsf_render(vhandle, vbuf, vsamples);
}
DEFINE_PRIM(cffi_tsf_render_bytes,3);

static value cffi_tsf_note_off_all(value vhandle) {
    TSFHandle h = (TSFHandle)(intptr_t)val_int(vhandle);
    tsf_bridge_note_off_all(h);
    return alloc_null();
}
DEFINE_PRIM(cffi_tsf_note_off_all,1);

static value cffi_tsf_active_voices(value vhandle) {
    TSFHandle h = (TSFHandle)(intptr_t)val_int(vhandle);
    return alloc_int(tsf_bridge_active_voices(h));
}
DEFINE_PRIM(cffi_tsf_active_voices,1);
#endif
