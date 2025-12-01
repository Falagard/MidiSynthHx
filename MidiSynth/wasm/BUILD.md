# WebAssembly Build Instructions

This directory contains the WebAssembly build for TinySoundFont.

## Prerequisites

Install Emscripten SDK:
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
source ./emsdk_env.sh  # Linux/macOS
# OR
emsdk_env.bat          # Windows
```

## Building

### Linux/macOS:
```bash
chmod +x build_wasm.sh
./build_wasm.sh
```

### Windows:
```bash
build_wasm.bat
```

This will generate:
- `tsf.js` - JavaScript loader and glue code
- `tsf.wasm` - WebAssembly binary

## Integration with OpenFL/HTML5

1. Copy `tsf.js` and `tsf.wasm` to your project's `Assets/` directory
2. Copy `tsf_glue.js` to your project's `Assets/` directory
3. Update `project.xml` to include these files:

```xml
<assets path="Assets/tsf.js" rename="tsf.js" if="html5" />
<assets path="Assets/tsf.wasm" rename="tsf.wasm" if="html5" />
<assets path="Assets/tsf_glue.js" rename="tsf_glue.js" if="html5" />
```

## Usage from Haxe

The unified `MidiSynth.hx` API will automatically use the WASM backend when compiled to HTML5.

### Low-level JavaScript API:

```javascript
// Load the WASM module
TSFModule().then(function(Module) {
    // Initialize glue
    TSFGlue.init(Module);
    
    // Load SF2 file
    fetch('assets/soundfont.sf2')
        .then(response => response.arrayBuffer())
        .then(buffer => {
            var handle = TSFGlue.initFromBuffer(buffer);
            TSFGlue.setOutput(handle, 44100, 2);
            
            // Play middle C
            TSFGlue.noteOn(handle, 0, 60, 127);
            
            // Render 1024 samples
            var audio = TSFGlue.render(handle, 1024);
            
            // Clean up
            TSFGlue.noteOff(handle, 0, 60);
            TSFGlue.close(handle);
        });
});
```

## Notes

- The WASM module needs to be loaded asynchronously in the browser
- SF2 files must be loaded via HTTP (fetch API) in HTML5 builds
- Memory is managed manually - ensure you call `close()` when done
- Audio rendering should be done in a Web Audio API AudioWorklet or ScriptProcessorNode

## File Sizes

The compiled WASM module is typically:
- `tsf.wasm`: ~100-200 KB (depends on optimization level)
- `tsf.js`: ~50-100 KB

Optimize for size with:
```bash
emcc ... -Oz -s ASSERTIONS=0 ...
```

## Debugging

For debug builds with better error messages:
```bash
emcc ... -O0 -g -s ASSERTIONS=1 -s SAFE_HEAP=1 ...
```
