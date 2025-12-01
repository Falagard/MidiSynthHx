# MidiSynthHx - AI Coding Agent Instructions

## Project Overview

**MidiSynthHx** (aka "MidiFeedi") is a cross-platform MIDI synthesizer for Haxe/OpenFL using TinySoundFont. It targets C++, HashLink, and HTML5/WebAssembly with a unified API.

**Key Architecture**: Platform-specific native bridges (C++, HashLink .hdll, WASM) → Unified Haxe API (`MidiSynth.hx`) → OpenFL audio integration via `SampleDataEvent`.

## Critical Build Dependencies

1. **TinySoundFont Header**: The `MidiSynth/cpp/tsf/tsf.h` is a stub. Run `download_tsf.bat` (Windows) or `download_tsf.sh` (Linux/Mac) to get the full implementation before building.
2. **SoundFont File**: Required at runtime - place a `.sf2` file at `Assets/soundfonts/GM.sf2` (see `MidiSynth/SOUNDFONT.md` for sources).
3. **Dependencies via hmm**: Run `hmm install` to install all haxelib dependencies + moonchart git dependency.

## Build System & Target-Specific Workflows

### C++ Target (Easiest - Auto-compiles)
```powershell
lime build cpp        # or: lime build windows/linux/mac
lime test cpp
```
- Native bridge compiles automatically via `MidiSynth/cpp/include.xml` included in `project.xml`
- C++ symbols defined inline in `MidiSynth.hx` via `@:cppFileCode` and `@:headerCode`
- Bridge implementation in `MidiSynth/cpp/tsf_bridge.cpp` wraps TinySoundFont C API

### HashLink Target (Requires Manual .hdll Build)
```powershell
# Step 1: Build native extension (Windows)
cd MidiSynth/hl
./build_hdll.bat      # Auto-locates MSVC tools and HashLink

# Step 2: Copy to output
Copy-Item tsfhl.hdll ../../Export/hl/bin/tsfhl.hdll -Force

# Step 3: Build/test
lime build hl
lime test hl
```
- Native bindings use `@:hlNative("tsfhl", "function_name")` annotations
- HashLink loads .hdll at runtime - must be in `Export/hl/bin/` or `%HASHLINK_PATH%`
- See `MidiSynth/hl/BUILD.md` for Linux/macOS manual compilation

### HTML5/WASM Target (Requires Emscripten)
```powershell
# Step 1: Build WASM module (requires Emscripten SDK)
cd MidiSynth/wasm
./build_wasm.ps1      # Windows - auto-activates emsdk
# or: ./build_wasm.sh  # Linux/Mac

# Step 2: Build/test
lime build html5
lime test html5
```
- Generates `tsf.js` (~28KB) and `tsf.wasm` (~49KB)
- **CRITICAL**: Must call `MidiSynth.initializeWasm(callback)` before creating instances in HTML5
- Audio requires user interaction (click/keypress) to start - browsers enforce autoplay policies
- Use lowercase `assets/` path in HTML5 vs `Assets/` in native targets

## Code Organization & Key Files

```
MidiSynth/              # Self-contained synthesizer module
├── haxe/
│   ├── MidiSynth.hx         # ★ Unified API - all platform #if conditionals here
│   └── MidiSynthNative.hx   # C++ extern declarations (cpp target only)
├── cpp/
│   ├── tsf_bridge.{h,cpp}   # C API wrapper for TinySoundFont
│   └── include.xml          # hxcpp build config (auto-included by project.xml)
├── hl/
│   ├── tsf_hl.c            # HashLink HL_PRIM bindings
│   └── build_hdll.bat      # Windows build automation
└── wasm/
    ├── tsf_wasm.cpp        # Emscripten WASM module
    ├── tsf_glue.js         # JS↔WASM memory bridge
    └── build_wasm.ps1      # Windows build (with emsdk auto-activation)

Source/
├── MidiSynthExample.hx  # ★ Complete working demo - keyboard→MIDI→audio
├── MainDemo.hx          # Entry point wrapper
└── Main.hx              # OpenFL main entry

project.xml              # ★ Build config - includes MidiSynth native extensions
hmm.json                 # Dependency lockfile (moonchart from git)
```

## Platform-Specific Conventions

### Conditional Compilation Pattern
```haxe
#if cpp
    // Direct C++ bridge via MidiSynthNative externs
#elseif hl
    // @:hlNative("tsfhl", "function_name") bindings
#elseif js
    // WASM module via TSFGlue JavaScript wrapper
#end
```

### Audio Rendering Pipeline
1. **Timer-driven pre-render**: `onRenderTick()` fills `audioQueue` with pre-rendered buffers
2. **SampleDataEvent callback**: `onSampleData()` consumes queue → writes to OpenFL ByteArray
3. **Buffer sizes**: Native=2048 samples, HTML5=2048+ (higher for WASM overhead)
4. **Queue depth**: `MAX_QUEUE_SIZE=3` (native) or `6` (HTML5) to prevent underruns

### Path Conventions
- **Native targets**: `Assets/soundfonts/GM.sf2` (capital A)
- **HTML5**: `assets/soundfonts/GM.sf2` (lowercase a)
- Use conditional: `#if html5 "assets/..." #else "Assets/..." #end`

## Common Tasks & Workflows

### Adding a New MIDI Event (e.g., Pitch Bend)
1. Add C API function in `tsf_bridge.{h,cpp}` wrapping TinySoundFont
2. Add `@:hlNative` declaration in `MidiSynth.hx` (HL section)
3. Add C++ extern in `MidiSynthNative.hx`
4. Add WASM export in `tsf_wasm.cpp` + glue function in `tsf_glue.js`
5. Add public method to `MidiSynth.hx` with #if conditionals for all targets
6. See existing `pitchBend()` implementation as reference

### Debugging Audio Issues
- Check `getActiveVoices()` returns >0 when notes playing (synthesizer working)
- Verify `audioQueue.length` stays >0 in `onSampleData()` (pre-rendering keeping up)
- For HTML5: Check browser console for WASM initialization errors
- For HashLink: Ensure `tsfhl.hdll` is in `Export/hl/bin/` with correct permissions

### Testing Across Targets
```powershell
# Native (fastest iteration)
lime test cpp

# HashLink (after building .hdll once)
lime test hl

# HTML5 (requires HTTP server - lime auto-starts one)
lime test html5
```

## Anti-Patterns to Avoid

❌ **Don't** call `render()` in a tight loop - use timer-driven pre-rendering (see `MidiSynthExample.hx`)
❌ **Don't** create MidiSynth before `initializeWasm()` completes in HTML5
❌ **Don't** mix `Assets/` and `assets/` paths - use conditional compilation
❌ **Don't** modify `tsf.h` directly - it's a vendor library, wrap in `tsf_bridge.cpp`
❌ **Don't** forget to copy `.hdll` to output directory when rebuilding HashLink extension

## Extending the Synthesizer

### Adding New Instruments
- Change `preset` parameter in `synth.setPreset(channel, bank, preset)`
- General MIDI presets: 0=Piano, 24=Guitar, 40=Violin, 56=Trumpet, 73=Flute
- Full list: https://www.midi.org/specifications/item/gm-level-1-sound-set

### MIDI File Playback
- See `MidiSynthExample.hx` for complete implementation using `moonchart` parser
- Parse MIDI → extract events → schedule via `haxe.Timer` → call `noteOn/noteOff`
- Handle tempo changes (META_EVENT) and program changes

### Performance Tuning
- Increase buffer size for lower CPU (higher latency): `BUFFER_SIZE = 4096`
- Decrease buffer size for lower latency (higher CPU): `BUFFER_SIZE = 1024`
- HTML5 needs larger `MAX_QUEUE_SIZE` (6+) due to WASM overhead
- Monitor `audioQueue.length` - should stay 2-4 for optimal latency

## Key Resources

- **TinySoundFont**: https://github.com/schellingb/TinySoundFont (core synthesis engine)
- **OpenFL Audio**: `openfl.events.SampleDataEvent` for dynamic audio generation
- **Haxe CFFI**: C++ native extensions via `cpp.Lib` and extern classes
- **HashLink Native**: `@:hlNative` macro for binding C functions
- **Emscripten**: WebAssembly compilation with `ccall/cwrap` exports

## Quick Reference Commands

```powershell
# Setup (one-time)
hmm install
cd MidiSynth/cpp && ./download_tsf.bat

# Build native extension (HashLink only)
cd MidiSynth/hl && ./build_hdll.bat

# Build WASM (HTML5 only)
cd MidiSynth/wasm && ./build_wasm.ps1

# Build & test
lime test cpp          # C++ (auto-compiles)
lime test hl           # HashLink (after manual .hdll build)
lime test html5        # HTML5 (after WASM build)
```

## VSCode Task

Use the predefined task "Run OpenFL C++ build" (in `.vscode/tasks.json`) via `Ctrl+Shift+B` or run `lime test cpp` directly.

---

When modifying this project, **always test the example first** (`MidiSynthExample.hx`) after changes - it exercises all API methods with visual/audio feedback.
