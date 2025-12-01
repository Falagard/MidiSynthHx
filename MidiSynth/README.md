# MidiSynth Module - Cross-Platform MIDI Synthesizer for Haxe/OpenFL

A complete, self-contained audio synthesizer module for Haxe and OpenFL that supports C++, HashLink, and HTML5/WebAssembly targets using TinySoundFont.

## Features

- ✅ **Cross-platform**: C++, HashLink, and HTML5/WASM
- ✅ **SoundFont 2 support**: Load any .sf2 file
- ✅ **MIDI events**: Note on/off, preset selection
- ✅ **Real-time synthesis**: Integrates with OpenFL audio stream
- ✅ **Lightweight**: Based on TinySoundFont (single-header library)
- ✅ **Deterministic**: Same audio output across all platforms

## Quick Start

### 1. Project Structure

```
MidiFeedi/
├── MidiSynth/
│   ├── cpp/              # C++ native bridge
│   │   ├── tsf/          # TinySoundFont header
│   │   ├── tsf_bridge.h
│   │   └── tsf_bridge.cpp
│   ├── hl/               # HashLink native bindings
│   │   ├── tsf_hl.c
│   │   └── BUILD.md
│   ├── wasm/             # WebAssembly module
│   │   ├── tsf_wasm.cpp
│   │   ├── tsf_glue.js
│   │   ├── build_wasm.sh
│   │   └── BUILD.md
│   └── haxe/             # Unified Haxe API
│       └── MidiSynth.hx
├── Source/
│   ├── MidiSynthExample.hx  # Example implementation
│   └── MainDemo.hx          # Demo entry point
├── Assets/
│   └── soundfonts/
│       └── GM.sf2        # General MIDI SoundFont (required)
└── project.xml
```

### 2. Get a SoundFont

Download a General MIDI SoundFont (GM.sf2) and place it in `Assets/soundfonts/`:

**Free SoundFonts:**
- **MuseScore General SF2** (35 MB): https://ftp.osuosl.org/pub/musescore/soundfont/MuseScore_General/
- **FluidR3_GM** (141 MB): https://github.com/urish/cinto/blob/master/media/FluidR3%20GM.sf2
- **SGM-V2.01** (240 MB): https://www.dropbox.com/s/4x27l49kxcwamp5/SGM-V2.01.sf2

For testing, a minimal 1-2 MB SoundFont is sufficient.

### 3. Basic Usage

```haxe
import MidiSynth;

// Create synthesizer
var synth = new MidiSynth("assets/soundfonts/GM.sf2");

// Set instrument (channel 0, bank 0, preset 0 = piano)
synth.setPreset(0, 0, 0);

// Play middle C
synth.noteOn(0, 60, 127);

// Stop middle C
synth.noteOff(0, 60);

// Render audio (in your audio callback)
synth.render(buffer, sampleCount);

// Clean up
synth.dispose();
```

### 4. OpenFL Integration

```haxe
import openfl.events.SampleDataEvent;
import openfl.media.Sound;

var sound = new Sound();
sound.addEventListener(SampleDataEvent.SAMPLE_DATA, function(e:SampleDataEvent) {
    // Render 8192 samples per callback
    synth.render(e.data, 8192);
});
sound.play();
```

See `Source/MidiSynthExample.hx` for a complete working example with keyboard input.

## Building for Different Targets

### C++ Target

The C++ bridge will compile automatically when building for C++:

```bash
lime build cpp
lime test cpp
```

**Windows (Visual Studio):**
```bash
lime build windows
```

**Linux:**
```bash
lime build linux
```

**macOS:**
```bash
lime build mac
```

### HashLink Target

1. **Build the native .hdll:**

Follow instructions in `MidiSynth/hl/BUILD.md`

```bash
# Windows
cl /c /EHsc /I..\cpp ..\cpp\tsf_bridge.cpp /Fo:tsf_bridge.obj
cl /c /I"%HASHLINK_PATH%\include" tsf_hl.c /Fo:tsf_hl.obj
link /DLL /OUT:tsf.hdll tsf_hl.obj tsf_bridge.obj libhl.lib /LIBPATH:"%HASHLINK_PATH%"

# Linux/macOS
g++ -c -fPIC -I../cpp ../cpp/tsf_bridge.cpp -o tsf_bridge.o
gcc -c -fPIC -I$HASHLINK_PATH/include tsf_hl.c -o tsf_hl.o
gcc -shared -o tsf.hdll tsf_hl.o tsf_bridge.o -L$HASHLINK_PATH -lhl
```

2. **Copy tsf.hdll to your output directory**

3. **Build and run:**

```bash
lime build hl
lime test hl
```

### HTML5 / WebAssembly Target

1. **Install Emscripten:**

```bash
git clone https://github.com/emscripten-core/emsdk.git
cd emsdk
./emsdk install latest
./emsdk activate latest
source ./emsdk_env.sh  # Linux/Mac
# OR
emsdk_env.bat         # Windows
```

2. **Build WASM module:**

```bash
cd MidiSynth/wasm
./build_wasm.sh       # Linux/Mac
# OR
build_wasm.bat        # Windows
```

This generates `tsf.js` and `tsf.wasm`.

3. **Build and test:**

```bash
lime build html5
lime test html5
```

**Important for HTML5:**
- SoundFont files must be loaded via HTTP (not from local filesystem in browser)
- Call `MidiSynth.initializeWasm()` before creating MidiSynth instances
- Audio rendering is asynchronous

## API Reference

### MidiSynth Class

#### Constructor
```haxe
new MidiSynth(soundFontPath:String, sampleRate:Int = 44100, channels:Int = 2)
```
- `soundFontPath`: Path to .sf2 SoundFont file
- `sampleRate`: Audio sample rate in Hz (typically 44100 or 48000)
- `channels`: 1 for mono, 2 for stereo

#### Methods

**noteOn(channel:Int, note:Int, velocity:Int):Void**
- Trigger a note on event
- `channel`: MIDI channel 0-15
- `note`: MIDI note number 0-127 (60 = middle C)
- `velocity`: Note velocity 0-127 (127 = full volume)

**noteOff(channel:Int, note:Int):Void**
- Trigger a note off event
- `channel`: MIDI channel 0-15
- `note`: MIDI note number 0-127

**noteOffAll():Void**
- Stop all currently playing notes (panic button)

**setPreset(channel:Int, bank:Int, preset:Int):Void**
- Set the instrument for a channel
- `channel`: MIDI channel 0-15
- `bank`: Instrument bank (usually 0 for GM)
- `preset`: Preset number 0-127 (see General MIDI instrument list)

**render(buffer:Any, sampleCount:Int):Int**
- Render audio samples
- `buffer`: Output buffer (platform-specific type)
- `sampleCount`: Number of samples (frames) to render
- Returns: Number of samples actually rendered

**getActiveVoices():Int**
- Returns the number of currently active voices

**dispose():Void**
- Clean up and free resources

#### HTML5-Specific

**static initializeWasm(onComplete:Void->Void):Void**
- Initialize WASM module (must call before creating instances)
- `onComplete`: Callback when initialization is complete

## General MIDI Instruments (Preset Numbers)

Common presets for `setPreset(channel, 0, preset)`:

- 0: Acoustic Grand Piano
- 1: Bright Acoustic Piano
- 4: Electric Piano 1
- 16: Drawbar Organ
- 24: Acoustic Guitar (nylon)
- 25: Acoustic Guitar (steel)
- 32: Acoustic Bass
- 40: Violin
- 48: String Ensemble 1
- 56: Trumpet
- 73: Flute
- 80: Lead 1 (square)

Full list: https://www.midi.org/specifications/item/gm-level-1-sound-set

## Performance Tips

1. **Buffer Size**: Use 2048-8192 samples per callback for good latency/performance balance
2. **Voice Limit**: TinySoundFont has no hard voice limit, but monitor `getActiveVoices()`
3. **SoundFont Size**: Smaller SoundFonts load faster and use less memory
4. **Sample Rate**: 44100 Hz is standard; higher rates increase CPU usage

## Troubleshooting

### "Failed to load SoundFont"
- Check that the .sf2 file exists at the specified path
- Ensure Assets directory is properly configured in project.xml
- For HTML5, verify the file is accessible via HTTP

### "Cannot load library tsf.hdll" (HashLink)
- Verify the .hdll is compiled and in the output directory
- Check that it matches your platform (.dll on Windows, .so on Linux, .dylib on macOS)
- Ensure HashLink version matches the one used to compile the .hdll

### No audio output
- Verify `sound.play()` returns a non-null SoundChannel
- Check that `render()` is being called in SampleDataEvent
- Ensure buffer is being filled with samples (not silence)
- Test with `getActiveVoices()` to verify notes are playing

### Clicks/pops in audio
- Increase buffer size (BUFFER_SIZE constant)
- Ensure audio callback doesn't block or take too long
- Check for buffer underruns

## Example: Piano Keyboard

See `Source/MidiSynthExample.hx` for a complete example that includes:
- Real-time audio synthesis
- Keyboard input (ASDF = white keys, WETYU = black keys)
- Visual feedback
- Active voice count display

Run with:
```bash
lime test cpp     # or hl, html5
```

## License

- **TinySoundFont**: Public Domain / MIT-0
- **MidiSynth module**: Use freely in your projects

## Credits

- TinySoundFont by Bernhard Schelling: https://github.com/schellingb/TinySoundFont
- OpenFL: https://www.openfl.org/
- Haxe: https://haxe.org/

## Support

For issues or questions:
1. Check the BUILD.md files in each platform directory
2. Verify your SoundFont file is valid
3. Test with the provided MidiSynthExample
4. Check OpenFL and Lime documentation for audio issues

---

**Happy synthesizing! 🎹🎵**
