# MidiSynth Quick Start Guide

Get up and running with MidiSynth in 5 minutes!

## Step 1: Get TinySoundFont Header

The included `tsf.h` is a minimal stub. Download the full version:

```bash
cd MidiSynth/cpp
./download_tsf.sh      # Linux/Mac
# OR
download_tsf.bat       # Windows
```

Or manually download from:
https://raw.githubusercontent.com/schellingb/TinySoundFont/master/tsf.h

## Step 2: Get a SoundFont

You need a .sf2 SoundFont file. Quick options:

### Option A: Download GeneralUser GS (Recommended)
1. Visit: http://www.schristiancollins.com/generaluser.php
2. Download and extract
3. Copy `GeneralUser GS v1.471.sf2` to `Assets/soundfonts/GM.sf2`

### Option B: Download FluidR3_GM
1. Search for "FluidR3_GM.sf2 download"
2. Download the ~141 MB file
3. Copy to `Assets/soundfonts/GM.sf2`

### Option C: Find a smaller one
- Search archive.org for "soundfont sf2"
- Look for files between 1-10 MB for testing

See `SOUNDFONT.md` for more options.

## Step 3: Test the Basic Example

### C++ Target (Easiest)

```bash
# Build
lime build cpp

# Test
lime test cpp
```

Press keys A-L to play notes like a piano!

### HashLink Target

1. First, build the native extension:
```bash
cd MidiSynth/hl
# Follow BUILD.md instructions for your platform
```

2. Copy `tsf.hdll` to your project's Export/hl/bin directory

3. Build and test:
```bash
lime build hl
lime test hl
```

### HTML5 Target

1. Install Emscripten (see MidiSynth/wasm/BUILD.md)

2. Build the WASM module:
```bash
cd MidiSynth/wasm
./build_wasm.sh      # Linux/Mac
# OR
build_wasm.bat       # Windows
```

3. Build and test:
```bash
lime build html5
lime test html5
```

## Step 4: Use in Your Own Code

### Basic Example

```haxe
import MidiSynth;

class MyApp {
    var synth:MidiSynth;
    
    function init() {
        // Create synth
        synth = new MidiSynth("assets/soundfonts/GM.sf2");
        
        // Set piano on channel 0
        synth.setPreset(0, 0, 0);
        
        // Play middle C
        synth.noteOn(0, 60, 127);
        
        // Later: stop the note
        synth.noteOff(0, 60);
    }
}
```

### With OpenFL Audio

```haxe
import openfl.events.SampleDataEvent;
import openfl.media.Sound;

var sound = new Sound();
sound.addEventListener(SampleDataEvent.SAMPLE_DATA, onAudio);
sound.play();

function onAudio(e:SampleDataEvent) {
    synth.render(e.data, 8192);
}
```

See `Source/MidiSynthExample.hx` for a complete working example.

## Keyboard Controls (in Example)

**White Keys (C major scale):**
- Z X C V B N M = C3 to B3
- A S D F G H J K L = C4 to E5

**Black Keys (sharps):**
- W E T Y U O P = C#4 to D#5

**Special:**
- SPACE = Stop all notes (panic)

## Common Issues

### "Failed to load SoundFont"
- Check that GM.sf2 exists in `Assets/soundfonts/`
- Verify the path in your code matches
- Ensure Assets directory is in project.xml

### "Cannot load library tsf"
- For C++: Library should build automatically
- For HashLink: You need to manually build tsf.hdll
- For HTML5: You need to build the WASM module first

### No sound
- Check that synth.noteOn() is being called
- Verify render() is being called in audio callback
- Test with `trace(synth.getActiveVoices())` - should be > 0 when notes playing

### Compilation errors
- Ensure you downloaded the full tsf.h (not the stub)
- Check that all source paths are in project.xml
- For C++, verify compiler has access to MidiSynth/cpp directory

## Next Steps

1. **Try different instruments**: Change the preset number in `setPreset()`
   - 0 = Piano, 24 = Guitar, 40 = Violin, 56 = Trumpet, etc.

2. **Add MIDI file playback**: Parse .mid files and feed events to synth

3. **Create a music app**: Build a sequencer, drum machine, or synthesizer

4. **Optimize**: Adjust buffer sizes, sample rates for your target platform

## Resources

- **Full Documentation**: See `MidiSynth/README.md`
- **SoundFont Guide**: See `MidiSynth/SOUNDFONT.md`
- **Build Instructions**: See BUILD.md files in cpp/, hl/, wasm/ directories
- **TinySoundFont**: https://github.com/schellingb/TinySoundFont
- **MIDI Specification**: https://www.midi.org/specifications

## Get Help

If you run into issues:
1. Check the BUILD.md for your target platform
2. Verify your SoundFont file is valid
3. Test with the provided MidiSynthExample first
4. Check OpenFL/Lime documentation for audio issues

Happy music making! 🎹🎵
