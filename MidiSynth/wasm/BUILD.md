# WebAssembly Build Instructions

This directory contains the WebAssembly build for TinySoundFont.

## Prerequisites

### Windows

1. **Install Python 3.x** (if not already installed):
   - Download from https://www.python.org/downloads/
   - During installation, check "Add Python to PATH"
   - Verify: `py --version` in PowerShell should work

2. **Install Emscripten SDK**:
```powershell
# Clone to a convenient location (e.g., C:\Src\emsdk)
git clone https://github.com/emscripten-core/emsdk.git C:\Src\emsdk
cd C:\Src\emsdk

# Install and activate latest
emsdk install latest
emsdk activate latest
```

Note: The build script (`build_wasm.ps1`) will automatically activate emsdk, so you don't need to run `emsdk_env.bat` manually.

### Linux/macOS

```bash
# Clone the repo
git clone https://github.com/emscripten-core/emsdk.git

# Enter directory
cd emsdk

# Install latest
./emsdk install latest

# Activate
./emsdk activate latest

# Set up environment (run this in each new terminal)
source ./emsdk_env.sh
```

## Building

### Windows (PowerShell):
```powershell
.\build_wasm.ps1
```

The script will:
- Auto-detect emsdk location (checks common paths)
- Activate the emsdk environment
- Compile `tsf_wasm.cpp` to WASM

### Linux/macOS:
```bash
chmod +x build_wasm.sh
./build_wasm.sh
```

This will generate:
- `tsf.js` - JavaScript loader and glue code (~50-100 KB)
- `tsf.wasm` - WebAssembly binary (~50 KB)

## Integration with OpenFL/HTML5

1. The WASM files and glue script are already in the correct location
2. Your `project.xml` should include:

```xml
<section if="html5">
    <!-- Custom template for script loading -->
    <template path="templates/html5/template/index.html" />
    
    <!-- WASM module files -->
    <assets path="MidiSynth/wasm/tsf.js" rename="tsf.js" type="text" embed="false" />
    <assets path="MidiSynth/wasm/tsf.wasm" rename="tsf.wasm" type="binary" embed="false" />
    <assets path="MidiSynth/wasm/tsf_glue.js" rename="tsf_glue.js" type="text" embed="false" />
</section>
```

3. Initialize WASM before creating `MidiSynth` instances:

```haxe
#if html5
MidiSynth.initializeWasm(function() {
    // Now you can create MidiSynth instances
    synth = new MidiSynth("assets/soundfonts/GM.sf2", 44100, 2);
});
#else
// Other targets can create synth directly
synth = new MidiSynth("Assets/soundfonts/GM.sf2", 44100, 2);
#end
```

## Usage from Haxe

The unified `MidiSynth.hx` API automatically uses the WASM backend for HTML5:

```haxe
// Initialize WASM (HTML5 only)
#if html5
MidiSynth.initializeWasm(function() {
    trace("WASM ready!");
    setupSynth();
});
#else
setupSynth();
#end

function setupSynth() {
    // Create synth
    var synth = new MidiSynth(
        #if html5 "assets/soundfonts/GM.sf2" 
        #else "Assets/soundfonts/GM.sf2" #end,
        44100, 2
    );
    
    // Set piano preset
    synth.setPreset(0, 0, 0);
    
    // Play notes
    synth.noteOn(0, 60, 127);  // Middle C
    
    // Render audio in your audio callback
    // For OpenFL/SampleDataEvent:
    sound.addEventListener(SampleDataEvent.SAMPLE_DATA, function(e) {
        var audioData = synth.render(null, 2048);
        // audioData is Float32Array for HTML5
        for (i in 0...audioData.length) {
            e.data.writeFloat(audioData[i]);
        }
    });
}
```

## Important Notes for HTML5

### Asynchronous Loading
- WASM module and SoundFont files load asynchronously in browsers
- Always call `MidiSynth.initializeWasm()` before creating instances
- SoundFont loading happens in constructor callback

### Audio Context Requirements
- Modern browsers require user interaction before playing audio
- Start audio playback after a click/keypress event:

```haxe
stage.addEventListener(MouseEvent.CLICK, function(e) {
    if (!audioStarted) {
        sound.play();  // Start audio output
        audioStarted = true;
    }
});
```

### Memory Management
- Memory buffer access uses `setValue`/`getValue` for compatibility
- Audio rendering is optimized with direct HEAP access when available
- Larger buffer sizes (6+ buffers) recommended to avoid dropouts

### Performance Tips
- Use `BUFFER_SIZE = 2048` or higher for HTML5
- Increase `MAX_QUEUE_SIZE = 6` for smoother playback
- Render multiple buffers per timer tick to stay ahead of consumption

## Low-level JavaScript API

If you need direct access (advanced usage):

```javascript
// Module loads asynchronously
TSFModule().then(function(Module) {
    // Initialize glue layer
    TSFGlue.init(Module);
    
    // Load SF2 file
    fetch('assets/soundfonts/GM.sf2')
        .then(response => response.arrayBuffer())
        .then(buffer => {
            var handle = TSFGlue.initFromBuffer(buffer);
            TSFGlue.setOutput(handle, 44100, 2);
            TSFGlue.setPreset(handle, 0, 0, 0);
            
            // Play middle C
            TSFGlue.noteOn(handle, 0, 60, 127);
            
            // Render 1024 samples (returns Float32Array)
            var audioData = TSFGlue.render(handle, 1024);
            
            // Clean up
            TSFGlue.noteOff(handle, 0, 60);
            TSFGlue.close(handle);
        });
});
```

## File Sizes

Typical compiled sizes (with `-O3` optimization):
- `tsf.wasm`: ~49 KB
- `tsf.js`: ~28 KB
- `tsf_glue.js`: ~6 KB

Total overhead: **~83 KB** for full MIDI synthesis in the browser!

## Debugging

For debug builds with better error messages:
```bash
emcc tsf_wasm.cpp -I../cpp -I../cpp/tsf -O0 -g \
  -s WASM=1 -s MODULARIZE=1 -s EXPORT_NAME="TSFModule" \
  -s EXPORTED_FUNCTIONS="['_malloc','_free','_wasm_tsf_init_memory',...]" \
  -s EXPORTED_RUNTIME_METHODS="['ccall','cwrap','setValue','getValue']" \
  -s ASSERTIONS=1 -s SAFE_HEAP=1 \
  -o tsf.js
```

View browser console for detailed logging during initialization and playback.

## Troubleshooting

### "Python not found" error
- Install Python 3.x from python.org
- Ensure `py.exe` launcher is available (test with `py --version`)

### "emsdk not found" error
- Update `$emsdkPath` in `build_wasm.ps1` to your emsdk location
- Or set `EMSDK` environment variable

### "HEAP views not ready" error (Fixed in current version)
- The code now uses `setValue`/`getValue` for compatibility
- Direct HEAP access is attempted as optimization fallback

### Audio dropouts/stuttering
- Increase `MAX_QUEUE_SIZE` in MidiSynthExample.hx
- Use larger `BUFFER_SIZE` (2048 or 4096)
- Check browser console for render timing issues

### No sound in browser
- Ensure audio context started after user gesture (click/keypress)
- Check browser console for autoplay policy blocks
- Verify SoundFont loaded successfully (check for handle > 0)
