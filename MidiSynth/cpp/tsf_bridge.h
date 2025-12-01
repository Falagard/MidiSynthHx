// tsf_bridge.h
// C API wrapper for TinySoundFont - compatible with Haxe CFFI
// Cross-platform bridge for C++, HashLink, and WebAssembly

#ifndef TSF_BRIDGE_H
#define TSF_BRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

// Opaque handle to the synthesizer instance
typedef void* TSFHandle;

// Initialize the synthesizer with a SoundFont file
// Returns a handle to the synth instance, or NULL on failure
// path: filesystem path to .sf2 file
TSFHandle tsf_bridge_init(const char* path);

// Initialize from memory buffer (for HTML5/embedded scenarios)
// Returns a handle to the synth instance, or NULL on failure
// buffer: pointer to SF2 data in memory
// size: size of buffer in bytes
TSFHandle tsf_bridge_init_memory(const void* buffer, int size);

// Clean up and free the synthesizer
void tsf_bridge_close(TSFHandle handle);

// Configure audio output parameters
// handle: synthesizer instance
// sample_rate: samples per second (e.g., 44100)
// channels: 1 for mono, 2 for stereo
void tsf_bridge_set_output(TSFHandle handle, int sample_rate, int channels);

// Trigger a note on event
// handle: synthesizer instance
// channel: MIDI channel (0-15)
// note: MIDI note number (0-127, 60 = middle C)
// velocity: note velocity (0-127)
void tsf_bridge_note_on(TSFHandle handle, int channel, int note, int velocity);

// Trigger a note off event
// handle: synthesizer instance
// channel: MIDI channel (0-15)
// note: MIDI note number (0-127)
void tsf_bridge_note_off(TSFHandle handle, int channel, int note);

// Set the preset (instrument) for a channel
// handle: synthesizer instance
// channel: MIDI channel (0-15)
// bank: instrument bank (usually 0 for General MIDI)
// preset: preset number (0-127, e.g., 0 = piano)
void tsf_bridge_set_preset(TSFHandle handle, int channel, int bank, int preset);

// Render audio samples
// handle: synthesizer instance
// buffer: output buffer (float32 PCM, interleaved stereo if channels=2)
// sample_count: number of samples to render (frames, not total floats)
// Returns: number of samples actually rendered
int tsf_bridge_render(TSFHandle handle, void* buffer, int sample_count);

// Stop all currently playing notes
void tsf_bridge_note_off_all(TSFHandle handle);

// Get the number of active voices
int tsf_bridge_active_voices(TSFHandle handle);

#ifdef __cplusplus
}
#endif

#endif // TSF_BRIDGE_H
