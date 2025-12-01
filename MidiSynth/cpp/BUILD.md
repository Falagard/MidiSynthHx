# MidiSynth C++ Build Instructions

This directory contains the C++ native bridge for TinySoundFont.

## Overview

The C++ bridge wraps TinySoundFont in a C API that's compatible with:
- Haxe CFFI (C++)
- HashLink native extensions
- WebAssembly/Emscripten

## Files

- `tsf/tsf.h` - TinySoundFont single-header library
- `tsf_bridge.h` - C API header
- `tsf_bridge.cpp` - C API implementation

## Building with OpenFL/Lime

For C++ targets, the bridge compiles automatically via `project.xml`:

```bash
lime build cpp
lime build windows
lime build linux
lime build mac
```

The build system will:
1. Compile `tsf_bridge.cpp` with TinySoundFont included
2. Link into a native dynamic library (.dll, .so, .dylib)
3. Generate CFFI bindings automatically

## Manual Compilation (Advanced)

### Windows (MSVC)

```bash
cl /c /EHsc /O2 tsf_bridge.cpp /Fo:tsf_bridge.obj
link /DLL /OUT:tsf.dll tsf_bridge.obj
```

### Linux (GCC)

```bash
g++ -c -fPIC -O3 tsf_bridge.cpp -o tsf_bridge.o
g++ -shared -o libtsf.so tsf_bridge.o
```

### macOS (Clang)

```bash
clang++ -c -fPIC -O3 tsf_bridge.cpp -o tsf_bridge.o
clang++ -dynamiclib -o libtsf.dylib tsf_bridge.o
```

## API Reference

All functions use C linkage (`extern "C"`).

### TSFHandle tsf_bridge_init(const char* path)
Initialize synthesizer from .sf2 file.
- Returns: Handle to synth instance, or NULL on error

### TSFHandle tsf_bridge_init_memory(const void* buffer, int size)
Initialize from memory buffer.
- Returns: Handle to synth instance, or NULL on error

### void tsf_bridge_close(TSFHandle handle)
Free synthesizer resources.

### void tsf_bridge_set_output(TSFHandle handle, int sample_rate, int channels)
Configure audio output.
- `sample_rate`: Samples per second (e.g., 44100)
- `channels`: 1 = mono, 2 = stereo

### void tsf_bridge_note_on(TSFHandle handle, int channel, int note, int velocity)
Trigger note on.
- `channel`: MIDI channel 0-15
- `note`: MIDI note 0-127
- `velocity`: Velocity 0-127

### void tsf_bridge_note_off(TSFHandle handle, int channel, int note)
Trigger note off.

### void tsf_bridge_set_preset(TSFHandle handle, int channel, int bank, int preset)
Set instrument preset.
- `bank`: Instrument bank (usually 0)
- `preset`: Preset number 0-127

### int tsf_bridge_render(TSFHandle handle, float* buffer, int sample_count)
Render audio samples.
- `buffer`: Output buffer (float32, interleaved stereo if channels=2)
- `sample_count`: Number of samples (frames) to render
- Returns: Samples rendered

### void tsf_bridge_note_off_all(TSFHandle handle)
Stop all notes.

### int tsf_bridge_active_voices(TSFHandle handle)
Get active voice count.
- Returns: Number of currently playing voices

## Optimization Flags

For production builds, use:
- `-O3` or `/O2` - Maximum optimization
- `-DNDEBUG` - Disable assertions
- `-ffast-math` - Fast floating-point math (use with caution)

## Threading

TinySoundFont is not thread-safe. If calling from multiple threads:
- Use a mutex around all API calls
- Or ensure only audio thread calls `render()` and control thread calls note on/off

## Memory Usage

- Base overhead: ~100 KB
- Per voice: ~1-2 KB
- SoundFont samples: Varies by SF2 file (5-500 MB typical)

## Notes

- TinySoundFont uses floating-point internally
- All MIDI velocity values are normalized to 0.0-1.0
- SoundFont is loaded entirely into memory (not streaming)
