// tsf_glue.js
// JavaScript glue code for TinySoundFont WASM module
// This provides a clean API for Haxe to interact with the WASM module

var TSFGlue = (function() {
    var module = null;
    var initialized = false;
    var pendingInitCallbacks = [];
    
    // Storage for SF2 data in WASM memory
    var sf2BufferPtr = null;
    var sf2BufferSize = 0;
    
    return {
        // Initialize the WASM module (call once at startup)
        init: function(wasmModule) {
            module = wasmModule;
            // In MODULARIZE builds, runtime may not be initialized yet
            var finalize = function() {
                initialized = true;
                var hasHeapU8 = !!module.HEAPU8;
                var hasHeapF32 = !!module.HEAPF32;
                var hasMalloc = !!module._malloc;
                var hasFree = !!module._free;
                if (!hasHeapU8 || !hasHeapF32 || !hasMalloc || !hasFree) {
                    console.warn("TSF WASM module missing expected exports/views", {
                        hasHeapU8: hasHeapU8, hasHeapF32: hasHeapF32, hasMalloc: hasMalloc, hasFree: hasFree
                    });
                    // Attempt to recover views from Module buffer
                    try {
                        var buf = undefined;
                        if (module.HEAPU8 && module.HEAPU8.buffer) buf = module.HEAPU8.buffer;
                        else if (module.HEAPF32 && module.HEAPF32.buffer) buf = module.HEAPF32.buffer;
                        else if (module.HEAP8 && module.HEAP8.buffer) buf = module.HEAP8.buffer;
                        else if (module.HEAP32 && module.HEAP32.buffer) buf = module.HEAP32.buffer;
                        else if (module.asm && module.asm.memory && module.asm.memory.buffer) buf = module.asm.memory.buffer;
                        else if (module.asm && module.asm.exports && module.asm.exports.memory && module.asm.exports.memory.buffer) buf = module.asm.exports.memory.buffer;
                        if (buf) {
                            if (!hasHeapU8) module.HEAPU8 = new Uint8Array(buf);
                            if (!hasHeapF32) module.HEAPF32 = new Float32Array(buf);
                        }
                    } catch (e) { console.warn("Unable to construct HEAP views", e); }
                }
                console.log("TSF WASM module initialized");
                // Flush any pending callbacks
                while (pendingInitCallbacks.length > 0) {
                    try { pendingInitCallbacks.shift()(); } catch (e) { console.error(e); }
                }
            };
            if (typeof module.onRuntimeInitialized === 'function') {
                // If the runtime is already initialized, call immediately
                if (module.calledRun) {
                    finalize();
                } else {
                    module.onRuntimeInitialized = finalize;
                }
            } else {
                // No hook exposed; attempt to finalize immediately
                finalize();
            }
        },
        
        // Load SoundFont from ArrayBuffer/Uint8Array
        // Returns handle (pointer) to synth instance
        initFromBuffer: function(arrayBuffer) {
            if (!initialized) {
                console.warn("TSF module not initialized yet; deferring initFromBuffer until runtime ready");
                pendingInitCallbacks.push(function() {
                    TSFGlue.initFromBuffer(arrayBuffer);
                });
                return 0;
            }
            
            var buffer = (arrayBuffer instanceof Uint8Array) ? arrayBuffer : new Uint8Array(arrayBuffer);
            sf2BufferSize = buffer.length;
            
            // Allocate memory in WASM heap
            sf2BufferPtr = module._malloc(sf2BufferSize);
            if (sf2BufferPtr === 0) {
                console.error("Failed to allocate memory for SF2");
                return 0;
            }
            
            // Copy SF2 data to WASM memory using setValue (byte-by-byte)
            try {
                for (var i = 0; i < buffer.length; i++) {
                    module.setValue(sf2BufferPtr + i, buffer[i], 'i8');
                }
                console.log("Copied", buffer.length, "bytes to WASM heap at", sf2BufferPtr);
            } catch (e) {
                console.error("Failed to copy SF2 to WASM heap:", e);
                module._free(sf2BufferPtr);
                sf2BufferPtr = null;
                return 0;
            }
            
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
            // Try to access memory buffer directly for performance
            var output = new Float32Array(totalFloats);
            try {
                // Attempt direct memory access via wasmMemory or HEAPF32
                var heapF32 = null;
                if (module.HEAPF32) {
                    heapF32 = module.HEAPF32;
                } else if (module.wasmMemory && module.wasmMemory.buffer) {
                    heapF32 = new Float32Array(module.wasmMemory.buffer);
                } else if (module.asm && module.asm.memory && module.asm.memory.buffer) {
                    heapF32 = new Float32Array(module.asm.memory.buffer);
                }
                
                if (heapF32) {
                    // Fast path: bulk copy from WASM heap
                    var heapIndex = bufferPtr >> 2; // Divide by 4 (float size)
                    output.set(heapF32.subarray(heapIndex, heapIndex + totalFloats));
                } else {
                    // Fallback: slow getValue loop
                    for (var i = 0; i < totalFloats; i++) {
                        output[i] = module.getValue(bufferPtr + (i * 4), 'float');
                    }
                }
            } catch (e) {
                // On error, use slow path
                for (var i = 0; i < totalFloats; i++) {
                    output[i] = module.getValue(bufferPtr + (i * 4), 'float');
                }
            }
            
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
