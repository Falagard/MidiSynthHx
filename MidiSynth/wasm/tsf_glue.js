// tsf_glue.js
// JavaScript glue code for TinySoundFont WASM module
// This provides a clean API for Haxe to interact with the WASM module

var TSFGlue = (function() {
    var module = null;
    var initialized = false;
    
    // Storage for SF2 data in WASM memory
    var sf2BufferPtr = null;
    var sf2BufferSize = 0;
    
    return {
        // Initialize the WASM module (call once at startup)
        init: function(wasmModule) {
            module = wasmModule;
            initialized = true;
            console.log("TSF WASM module initialized");
        },
        
        // Load SoundFont from ArrayBuffer/Uint8Array
        // Returns handle (pointer) to synth instance
        initFromBuffer: function(arrayBuffer) {
            if (!initialized) {
                console.error("TSF module not initialized");
                return 0;
            }
            
            var buffer = new Uint8Array(arrayBuffer);
            sf2BufferSize = buffer.length;
            
            // Allocate memory in WASM heap
            sf2BufferPtr = module._malloc(sf2BufferSize);
            if (sf2BufferPtr === 0) {
                console.error("Failed to allocate memory for SF2");
                return 0;
            }
            
            // Copy SF2 data to WASM memory
            module.HEAPU8.set(buffer, sf2BufferPtr);
            
            // Initialize synth with SF2 data
            var handle = module._wasm_tsf_init_memory(sf2BufferPtr, sf2BufferSize);
            
            if (handle === 0) {
                console.error("Failed to initialize TinySoundFont");
                module._free(sf2BufferPtr);
                sf2BufferPtr = null;
                return 0;
            }
            
            console.log("TinySoundFont initialized, handle:", handle);
            return handle;
        },
        
        // Close and free synthesizer
        close: function(handle) {
            if (handle && handle !== 0) {
                module._wasm_tsf_close(handle);
            }
            if (sf2BufferPtr) {
                module._free(sf2BufferPtr);
                sf2BufferPtr = null;
            }
        },
        
        // Set audio output parameters
        setOutput: function(handle, sampleRate, channels) {
            module._wasm_tsf_set_output(handle, sampleRate, channels);
        },
        
        // Trigger note on
        noteOn: function(handle, channel, note, velocity) {
            module._wasm_tsf_note_on(handle, channel, note, velocity);
        },
        
        // Trigger note off
        noteOff: function(handle, channel, note) {
            module._wasm_tsf_note_off(handle, channel, note);
        },
        
        // Set instrument preset
        setPreset: function(handle, channel, bank, preset) {
            module._wasm_tsf_set_preset(handle, channel, bank, preset);
        },
        
        // Render audio samples
        // Returns Float32Array with rendered audio
        render: function(handle, sampleCount) {
            // Calculate total floats needed (samples * channels)
            // Assuming stereo (2 channels)
            var totalFloats = sampleCount * 2;
            var bufferPtr = module._malloc(totalFloats * 4); // 4 bytes per float
            
            if (bufferPtr === 0) {
                console.error("Failed to allocate render buffer");
                return null;
            }
            
            // Render audio into WASM memory
            var rendered = module._wasm_tsf_render(handle, bufferPtr, sampleCount);
            
            // Copy from WASM heap to JavaScript Float32Array
            var output = new Float32Array(totalFloats);
            output.set(module.HEAPF32.subarray(bufferPtr / 4, (bufferPtr / 4) + totalFloats));
            
            // Free temporary buffer
            module._free(bufferPtr);
            
            return output;
        },
        
        // Stop all notes
        noteOffAll: function(handle) {
            module._wasm_tsf_note_off_all(handle);
        },
        
        // Get active voice count
        activeVoices: function(handle) {
            return module._wasm_tsf_active_voices(handle);
        }
    };
})();

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
    module.exports = TSFGlue;
}
