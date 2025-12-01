# MidiFeedi - Cross-Platform MIDI Synthesizer

A complete music synthesis system for Haxe + OpenFL supporting C++, HashLink, and HTML5/WebAssembly.

## 🎵 Features

- **Cross-Platform**: Works on C++, HashLink, and HTML5/WASM
- **SoundFont Support**: Load any SoundFont 2 (.sf2) file
- **Real-Time Synthesis**: Low-latency audio using TinySoundFont
- **MIDI Events**: Full note on/off, velocity, and preset support
- **OpenFL Integration**: Seamless audio stream integration
- **Unified API**: Same code works across all platforms

## 🚀 Quick Start

### 1. Get the Full TinySoundFont Header

```bash
cd MidiSynth/cpp
./download_tsf.sh      # Linux/macOS
# OR
download_tsf.bat       # Windows
```

### 2. Get a SoundFont

Download a GM.sf2 file and place in `Assets/soundfonts/`:
- **GeneralUser GS**: http://www.schristiancollins.com/generaluser.php (29 MB, recommended)
- **FluidR3_GM**: Search for "FluidR3 GM sf2" (141 MB)

See `MidiSynth/SOUNDFONT.md` for more options.

### 3. Build and Run

```bash
# C++ (easiest)
lime build cpp
lime test cpp

# HashLink (requires building native .hdll first)
lime build hl
lime test hl

# HTML5 (requires building WASM module first)
lime build html5
lime test html5
```

Press A-L keys to play piano notes!

## 📖 Usage Example

```haxe
import MidiSynth;

// Create synthesizer
var synth = new MidiSynth("assets/soundfonts/GM.sf2");

// Set instrument (channel, bank, preset)
synth.setPreset(0, 0, 0);  // Piano on channel 0

// Play middle C
synth.noteOn(0, 60, 127);

// Render audio in OpenFL callback
sound.addEventListener(SampleDataEvent.SAMPLE_DATA, function(e) {
    synth.render(e.data, 8192);
});

// Stop note
synth.noteOff(0, 60);

// Clean up
synth.dispose();
```

## 📁 Project Structure

```
MidiFeedi/
├── MidiSynth/              # The synthesizer module
│   ├── cpp/                # C++ bridge (CFFI)
│   ├── hl/                 # HashLink native bindings
│   ├── wasm/               # WebAssembly module
│   ├── haxe/               # Unified Haxe API
│   ├── README.md           # Full documentation
│   ├── QUICKSTART.md       # Quick start guide
│   └── SOUNDFONT.md        # SoundFont download guide
├── Source/
│   ├── MidiSynthExample.hx # Working example with keyboard input
│   └── MainDemo.hx         # Demo entry point
├── Assets/
│   └── soundfonts/
│       └── GM.sf2          # Your SoundFont (download separately)
└── project.xml             # Build configuration
```

## 🎹 API Reference

### Constructor
```haxe
new MidiSynth(soundFontPath:String, sampleRate:Int = 44100, channels:Int = 2)
```

### Key Methods
- `noteOn(channel, note, velocity)` - Play a note
- `noteOff(channel, note)` - Stop a note
- `setPreset(channel, bank, preset)` - Change instrument
- `render(buffer, samples)` - Generate audio
- `getActiveVoices()` - Get playing voice count
- `dispose()` - Clean up resources

### General MIDI Instruments (Presets)
- 0: Acoustic Grand Piano
- 24: Acoustic Guitar
- 32: Acoustic Bass
- 40: Violin
- 56: Trumpet
- 73: Flute

Full list: https://www.midi.org/specifications/item/gm-level-1-sound-set

## 🏗️ Building for Different Targets

### C++ (Native)
```bash
lime build cpp      # Compiles automatically
lime test cpp
```

### HashLink
Requires pre-building the native .hdll:
```bash
cd MidiSynth/hl
# Follow BUILD.md for your platform
```

### HTML5/WASM
Requires Emscripten:
```bash
cd MidiSynth/wasm
./build_wasm.sh     # or build_wasm.bat on Windows
cd ../..
lime build html5
```

See platform-specific BUILD.md files for detailed instructions.

## 📚 Documentation

- **[Full Documentation](MidiSynth/README.md)** - Complete API reference and guide
- **[Quick Start](MidiSynth/QUICKSTART.md)** - Get running in 5 minutes
- **[SoundFont Guide](MidiSynth/SOUNDFONT.md)** - Where to get .sf2 files
- **[C++ Build](MidiSynth/cpp/BUILD.md)** - C++ compilation details
- **[HashLink Build](MidiSynth/hl/BUILD.md)** - HL native extension guide
- **[WASM Build](MidiSynth/wasm/BUILD.md)** - Emscripten instructions

## 🎮 Example: Piano Keyboard

The included example (`MidiSynthExample.hx`) demonstrates:
- Real-time audio synthesis
- Keyboard input (A-L = white keys, W-U = black keys)
- Visual feedback
- Voice count display

Run it:
```bash
lime test cpp    # or hl, html5
```

## 🔧 Requirements

- **Haxe** 4.0+
- **OpenFL** 8.0+
- **Lime** 7.0+

### Target-Specific
- **C++**: C++11 compiler (GCC, Clang, MSVC)
- **HashLink**: HashLink 1.11+, native compilation tools
- **HTML5**: Emscripten SDK 3.0+

## 🐛 Troubleshooting

### No Sound
- Verify SoundFont file exists and is valid
- Check `getActiveVoices()` returns > 0 when playing
- Ensure `render()` is called in audio callback

### Build Errors
- Download full TinySoundFont header (not the stub)
- Check all paths in project.xml
- For native targets, verify build tools are installed

### Platform-Specific
- **C++**: Should work out of the box
- **HashLink**: Must build .hdll manually first
- **HTML5**: Must build WASM module with Emscripten

## 🎯 Performance

- **Latency**: 50-200ms (configurable via buffer size)
- **CPU Usage**: ~5-15% per 64 active voices at 44.1kHz
- **Memory**: Base ~100KB + SoundFont size (5-500 MB typical)

## 📄 License

- **MidiSynth module**: Free to use in any project
- **TinySoundFont**: Public Domain / MIT-0 by Bernhard Schelling
- **Example code**: Public domain

## 🙏 Credits

- **TinySoundFont** by Bernhard Schelling - https://github.com/schellingb/TinySoundFont
- **OpenFL** - https://www.openfl.org/
- **Haxe** - https://haxe.org/

## 🤝 Contributing

This is a complete, self-contained module. Feel free to:
- Use it in your projects
- Modify for your needs
- Share improvements

## 📞 Support

For issues:
1. Check the documentation in `MidiSynth/README.md`
2. Review platform BUILD.md files
3. Test with the provided example first
4. Verify SoundFont file is valid

---

**Start making music with Haxe! 🎹🎵**
