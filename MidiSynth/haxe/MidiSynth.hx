
package;

#if cpp
import cpp.Lib;
#elseif hl
import hl.Bytes;
import hl.NativeArray;
#elseif js
import js.lib.Float32Array;
import js.lib.Uint8Array;
import js.html.XMLHttpRequest;
#end

import haxe.io.Bytes as HaxeBytes;

/**
 * Cross-platform MIDI synthesizer using TinySoundFont
 * Supports C++, HashLink, and HTML5/WebAssembly targets
 * 
 * Usage:
 * ```haxe
 * var synth = new MidiSynth("assets/soundfonts/GM.sf2");
 * synth.noteOn(0, 60, 127);  // Play middle C on channel 0
 * synth.noteOff(0, 60);       // Stop middle C
 * synth.render(buffer, samples);  // Render audio
 * ```
 */
#if cpp
@:headerCode('extern "C" {\n  void* tsf_bridge_init(const char* path);\n  void tsf_bridge_close(void* handle);\n  void tsf_bridge_set_output(void* handle, int sampleRate, int channels);\n  void tsf_bridge_note_on(void* handle, int channel, int note, int velocity);\n  void tsf_bridge_note_off(void* handle, int channel, int note);\n  void tsf_bridge_set_preset(void* handle, int channel, int bank, int preset);\n  void tsf_bridge_pitch_bend(void* handle, int channel, int pitch_wheel);\n  void tsf_bridge_control_change(void* handle, int channel, int controller, int value);\n  void tsf_bridge_channel_set_volume(void* handle, int channel, float volume);\n  int tsf_bridge_render(void* handle, void* buffer, int sampleCount);\n  void tsf_bridge_note_off_all(void* handle);\n  int tsf_bridge_active_voices(void* handle);\n}\n')
#if cpp
@:cppFileCode('#define TSF_IMPLEMENTATION\n#include "../../../../MidiSynth/cpp/tsf/tsf.h"\nextern "C" {\ntypedef void* TSFHandle;\n}\nstruct TSFSynth { tsf* synth; int sampleRate; int channels; };\nstatic TSFHandle tsf_bridge_init(const char* path) { if (!path) return NULL; tsf* synth = tsf_load_filename(path); if (!synth) return NULL; TSFSynth* handle = (TSFSynth*)malloc(sizeof(TSFSynth)); if (!handle) { tsf_close(synth); return NULL; } handle->synth = synth; handle->sampleRate = 44100; handle->channels = 2; tsf_set_output(synth, TSF_STEREO_INTERLEAVED, 44100, 0.0f); tsf_channel_set_bank_preset(synth, 0, 0, 0); return (TSFHandle)handle; }\nstatic void tsf_bridge_close(TSFHandle handle) { if (!handle) return; TSFSynth* synth = (TSFSynth*)handle; if (synth->synth) tsf_close(synth->synth); free(synth); }\nstatic void tsf_bridge_set_output(TSFHandle handle, int sample_rate, int channels) { if (!handle) return; TSFSynth* synth = (TSFSynth*)handle; synth->sampleRate = sample_rate; synth->channels = channels; enum TSFOutputMode mode = (channels == 1) ? TSF_MONO : TSF_STEREO_INTERLEAVED; tsf_set_output(synth->synth, mode, sample_rate, 0.0f); }\nstatic void tsf_bridge_note_on(TSFHandle handle, int channel, int note, int velocity) { if (!handle) return; TSFSynth* synth = (TSFSynth*)handle; float vel = velocity / 127.0f; tsf_channel_note_on(synth->synth, channel, note, vel); }\nstatic void tsf_bridge_note_off(TSFHandle handle, int channel, int note) { if (!handle) return; TSFSynth* synth = (TSFSynth*)handle; tsf_channel_note_off(synth->synth, channel, note); }\nstatic void tsf_bridge_set_preset(TSFHandle handle, int channel, int bank, int preset) { if (!handle) return; TSFSynth* synth = (TSFSynth*)handle; tsf_channel_set_bank_preset(synth->synth, channel, bank, preset); }\nstatic int tsf_bridge_render(TSFHandle handle, void* buffer, int sample_count) { if (!handle || !buffer || sample_count <= 0) return 0; TSFSynth* synth = (TSFSynth*)handle; tsf_render_float(synth->synth, (float*)buffer, sample_count, 0); return sample_count; }\nstatic void tsf_bridge_note_off_all(TSFHandle handle) { if (!handle) return; TSFSynth* synth = (TSFSynth*)handle; tsf_note_off_all(synth->synth); }\nstatic int tsf_bridge_active_voices(TSFHandle handle) { if (!handle) return 0; TSFSynth* synth = (TSFSynth*)handle; return tsf_active_voice_count(synth->synth); }\n')
#end
#end
class MidiSynth {
        /**
         * Set per-channel volume (0.0 = silent, 1.0 = full)
         * @param channel MIDI channel (0-15)
         * @param volume Volume as float (0.0-1.0)
         */
        public function setChannelVolume(channel:Int, volume:Float):Void {
            #if cpp
            MidiSynthNative.channelSetVolume(handle, channel, volume);
            #elseif hl
            tsf_channel_set_volume(handle, channel, volume);
            #elseif js
            if (handle != 0 && glue != null && glue.channelSetVolume != null) {
                untyped glue.channelSetVolume(handle, channel, volume);
            }
            #end
        }
    #if hl
        @:hlNative("tsfhl", "channel_set_volume")
        private static function tsf_channel_set_volume(handle:Dynamic, channel:Int, volume:Float):Void {}
    #end
    #if cpp
    private var handle:cpp.RawPointer<cpp.Void>;
    #elseif hl
    private var handle:Dynamic;
    #elseif js
    private var handle:Int;
    private var readyCallbacks:Array<Void->Void> = [];
    private var isReady:Bool = false;
    private static var wasmModule:Dynamic = null;
    private static var glue:Dynamic = null;
    #end
    
    private var sampleRate:Int;
    private var channels:Int;
    #if cpp
    private static var cffiRenderFn:Dynamic = null;
    private static inline function getCffiRender():Dynamic {
        if (cffiRenderFn == null) {
            // Prefer explicit bytes render primitive
            try {
                cffiRenderFn = cpp.Lib.load(null, "cffi_tsf_render_bytes", 3);
            } catch (_:Dynamic) {
                cffiRenderFn = cpp.Lib.load(null, "cffi_tsf_render", 3);
            }
        }
        return cffiRenderFn;
    }
    #end
    
    /**
     * Create a new MIDI synthesizer
     * @param soundFontPath Path to .sf2 SoundFont file
     * @param sampleRate Sample rate in Hz (default: 44100)
     * @param channels Number of output channels: 1=mono, 2=stereo (default: 2)
     */
    public function new(soundFontPath:String, sampleRate:Int = 44100, channels:Int = 2) {
        trace("MidiSynth constructor: path=" + soundFontPath);
        this.sampleRate = sampleRate;
        this.channels = channels;
        
        #if cpp
        trace("Calling initCpp...");
        initCpp(soundFontPath);
        #elseif hl
        initHashLink(soundFontPath);
        #elseif js
        initHtml5(soundFontPath);
        #else
        throw "MidiSynth: Unsupported target platform";
        #end
    }

    @:hlNative("tsfhl", "pitch_bend")
    private static function tsf_pitch_bend(handle:Dynamic, channel:Int, pitchWheel:Int):Void {}
    /**
     * Set pitch bend for a channel
     * @param channel MIDI channel (0-15)
     * @param pitchWheel Pitch wheel value (0-16383, center is 8192)
     */
    public function pitchBend(channel:Int, pitchWheel:Int):Void {
        #if cpp
        MidiSynthNative.pitchBend(handle, channel, pitchWheel);
        #elseif hl
        tsf_pitch_bend(handle, channel, pitchWheel);
        #elseif js
        if (handle != 0) {
            untyped glue.pitchBend(handle, channel, pitchWheel);
        }
        #end
    }
    
    @:hlNative("tsfhl", "control_change")
    private static function tsf_control_change(handle:Dynamic, channel:Int, controller:Int, value:Int):Void {}
    /**
     * Send a MIDI control change message
     * @param channel MIDI channel (0-15)
     * @param controller MIDI controller number (0-127)
     * @param value Controller value (0-127)
     */
    public function controlChange(channel:Int, controller:Int, value:Int):Void {
        #if cpp
        MidiSynthNative.controlChange(handle, channel, controller, value);
        #elseif hl
        tsf_control_change(handle, channel, controller, value);
        #elseif js
        if (handle != 0) {
            untyped glue.controlChange(handle, channel, controller, value);
        }
        #end
    }
    
    /**
     * Set sustain pedal (damper pedal) for a channel
     * @param channel MIDI channel (0-15)
     * @param on True to press pedal, false to release
     */
    public function sustainPedal(channel:Int, on:Bool):Void {
        controlChange(channel, 64, on ? 127 : 0);
    }
    
    /**
     * Set channel volume
     * @param channel MIDI channel (0-15)
     * @param volume Volume level (0-127)
     */
    public function channelVolume(channel:Int, volume:Int):Void {
        controlChange(channel, 7, volume);
    }
    
    /**
     * Set channel pan (stereo position)
     * @param channel MIDI channel (0-15)
     * @param pan Pan value (0=full left, 64=center, 127=full right)
     */
    public function channelPan(channel:Int, pan:Int):Void {
        controlChange(channel, 10, pan);
    }
    
    /**
     * Set expression (dynamics control)
     * @param channel MIDI channel (0-15)
     * @param expression Expression level (0-127)
     */
    public function channelExpression(channel:Int, expression:Int):Void {
        controlChange(channel, 11, expression);
    }
    
    /**
     * Set modulation wheel (vibrato/effects)
     * @param channel MIDI channel (0-15)
     * @param modulation Modulation depth (0-127)
     */
    public function modulationWheel(channel:Int, modulation:Int):Void {
        controlChange(channel, 1, modulation);
    }
    
    /**
     * Reset all controllers on a channel
     * @param channel MIDI channel (0-15)
     */
    public function resetControllers(channel:Int):Void {
        controlChange(channel, 121, 0);
    }
    
    #if cpp
    // ============================================
    // C++ / CFFI Implementation
    // ============================================
    
    private function initCpp(path:String):Void {
        try {
            trace("initCpp(native): " + path);
            var cpath:cpp.ConstCharStar = cpp.ConstCharStar.fromString(path);
            handle = MidiSynthNative.init(cpath);
            if (handle == null) throw "Failed to load SoundFont: " + path;
            MidiSynthNative.setOutput(handle, sampleRate, channels);
        } catch (e:Dynamic) {
            trace("ERROR in initCpp(native): " + Std.string(e));
            throw e;
        }
    }
    
    // Load CFFI exported primitives (cffi_ prefix defined in tsf_bridge.cpp)
    // Use null as the library name to access statically linked CFFI primitives
    // No Lib.load for cpp; using hxcpp externs in MidiSynthNative
    #end
    
    #if hl
    // ============================================
    // HashLink Implementation
    // ============================================
    
    private function initHashLink(path:String):Void {
        var fileBytes = sys.io.File.getBytes(path);
        handle = tsf_init_memory(fileBytes, fileBytes.length);
        if (handle == null) {
            throw "Failed to load SoundFont (memory): " + path;
        }
        tsf_set_output(handle, sampleRate, channels);
    }
    
    @:hlNative("tsfhl", "init_memory")
    private static function tsf_init_memory(buf:Bytes, size:Int):Dynamic { return null; }
    
    @:hlNative("tsfhl", "close")
    private static function tsf_close(handle:Dynamic):Void {}
    
    @:hlNative("tsfhl", "set_output")
    private static function tsf_set_output(handle:Dynamic, sampleRate:Int, channels:Int):Void {}
    
    @:hlNative("tsfhl", "note_on")
    private static function tsf_note_on(handle:Dynamic, channel:Int, note:Int, velocity:Int):Void {}
    
    @:hlNative("tsfhl", "note_off")
    private static function tsf_note_off(handle:Dynamic, channel:Int, note:Int):Void {}
    
    @:hlNative("tsfhl", "set_preset")
    private static function tsf_set_preset(handle:Dynamic, channel:Int, bank:Int, preset:Int):Void {}
    
    @:hlNative("tsfhl", "render")
    private static function tsf_render(handle:Dynamic, buffer:Bytes, samples:Int):Int { return 0; }
    
    @:hlNative("tsfhl", "note_off_all")
    private static function tsf_note_off_all(handle:Dynamic):Void {}

    @:hlNative("tsfhl", "active_voices")
    private static function tsf_active_voices(handle:Dynamic):Int { return 0; }
    #end
    
    #if js
    // ============================================
    // HTML5 / WebAssembly Implementation
    // ============================================
    
    private static var initialized:Bool = false;
    private static var initPromises:Array<Void->Void> = [];
    
    private function initHtml5(path:String):Void {
        // For HTML5, we need to load the WASM module and SF2 asynchronously
        // This is a synchronous constructor, so we'll throw if not pre-initialized
        if (!initialized) {
            throw "MidiSynth HTML5: Must call MidiSynth.initializeWasm() before creating instances";
        }
        
        // Load SF2 file asynchronously
        loadSoundFont(path, function(arrayBuffer:js.lib.ArrayBuffer) {
            handle = untyped glue.initFromBuffer(arrayBuffer);
            if (handle == 0) {
                throw "Failed to initialize SoundFont from: " + path;
            }
            untyped glue.setOutput(handle, sampleRate, channels);
            isReady = true;
            trace("MidiSynth initialized for HTML5");
            // Execute any pending callbacks
            for (cb in readyCallbacks) {
                try { cb(); } catch (e:Dynamic) { trace("Error in ready callback: " + e); }
            }
            readyCallbacks = [];
        });
    }
    
    /**
     * Initialize WASM module (HTML5 only)
     * Must be called once before creating MidiSynth instances
     * @param onComplete Callback when initialization is complete
     */
    public static function initializeWasm(onComplete:Void->Void):Void {
        #if js
        if (initialized) {
            onComplete();
            return;
        }
        
        // Dynamically load tsf_glue.js then tsf.js
        var loadScript = function(url:String, callback:Void->Void) {
            var script = js.Browser.document.createScriptElement();
            script.src = url;
            script.onload = function() callback();
            script.onerror = function() {
                trace("Failed to load script: " + url);
                throw "Failed to load WASM script: " + url;
            };
            js.Browser.document.head.appendChild(script);
        };
        
        // Load tsf_glue.js first
        loadScript("tsf_glue.js", function() {
            trace("tsf_glue.js loaded");
            
            // Then load tsf.js (WASM module)
            loadScript("tsf.js", function() {
                trace("tsf.js loaded, initializing TSFModule...");
                
                // Now TSFModule should be available
                js.Syntax.code("
                    TSFModule().then(function(Module) {{
                        window.TSFModuleInstance = Module;
                        console.log('TSFModule initialized, exports:', Object.keys(Module).length, 'functions');
                        // The Module itself is the glue - pass it directly to TSFGlue
                        // TSFGlue will use Module._malloc and direct memory access via setValue/getValue
                        TSFGlue.init(Module);
                    }});
                ");
                
                glue = js.Syntax.code("TSFGlue");
                initialized = true;
                
                // Wait a bit for WASM to initialize
                haxe.Timer.delay(function() {
                    trace("WASM initialization complete");
                    onComplete();
                }, 100);
            });
        });
        #end
    }
    
    private function loadSoundFont(path:String, onComplete:js.lib.ArrayBuffer->Void):Void {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", path, true);
        xhr.responseType = js.html.XMLHttpRequestResponseType.ARRAYBUFFER;
        
        xhr.onload = function() {
            if (xhr.status == 200) {
                onComplete(xhr.response);
            } else {
                throw "Failed to load SoundFont: " + path + " (status: " + xhr.status + ")";
            }
        };
        
        xhr.onerror = function() {
            throw "Network error loading SoundFont: " + path;
        };
        
        xhr.send();
    }
    #end
    
    /**
     * Trigger a note on event
     * @param channel MIDI channel (0-15)
     * @param note MIDI note number (0-127, 60 = middle C)
     * @param velocity Note velocity (0-127)
     */
    public function noteOn(channel:Int, note:Int, velocity:Int):Void {
        #if cpp
        MidiSynthNative.noteOn(handle, channel, note, velocity);
        #elseif hl
        tsf_note_on(handle, channel, note, velocity);
        #elseif js
        if (handle != 0) {
            untyped glue.noteOn(handle, channel, note, velocity);
        }
        #end
    }
    
    /**
     * Trigger a note off event
     * @param channel MIDI channel (0-15)
     * @param note MIDI note number (0-127)
     */
    public function noteOff(channel:Int, note:Int):Void {
        #if cpp
        MidiSynthNative.noteOff(handle, channel, note);
        #elseif hl
        tsf_note_off(handle, channel, note);
        #elseif js
        if (handle != 0) {
            untyped glue.noteOff(handle, channel, note);
        }
        #end
    }
    

    /**
     * Stop all currently playing notes on the synth (all channels)
     */
    public function noteOffAll():Void {
        #if cpp
        MidiSynthNative.noteOffAll(handle);
        #elseif hl
        tsf_note_off_all(handle);
        #elseif js
        if (handle != 0) {
            untyped glue.noteOffAll(handle);
        }
        #end
    }

    /**
     * Panic: stop all notes and reset controllers on all channels
     */
    public function panicStopAllNotes():Void {
        // Stop all notes and reset controllers on all 16 MIDI channels
        for (channel in 0...16) {
            noteOffAll();
            resetControllers(channel);
        }
    }
    
    /**
     * Set the instrument preset for a channel
     * @param channel MIDI channel (0-15)
     * @param bank Instrument bank (usually 0 for General MIDI)
     * @param preset Preset number (0-127, e.g., 0 = Acoustic Grand Piano)
     */
    public function setPreset(channel:Int, bank:Int, preset:Int):Void {
        // Enforce General MIDI drum channel: channel 9 (MIDI channel 10) always uses bank 128
        var actualBank = (channel == 9) ? 128 : bank;
        #if cpp
        MidiSynthNative.setPreset(handle, channel, actualBank, preset);
        #elseif hl
        tsf_set_preset(handle, channel, actualBank, preset);
        #elseif js
        if (isReady && handle != 0) {
            untyped glue.setPreset(handle, channel, actualBank, preset);
        } else {
            // Defer until ready
            readyCallbacks.push(function() {
                untyped glue.setPreset(handle, channel, actualBank, preset);
            });
        }
        #end
    }
    
    /**
     * Render audio samples
     * @param buffer Output buffer (Float32 array, interleaved stereo if channels=2)
     * @param sampleCount Number of samples to render (frames, not total floats)
     * @return Number of samples actually rendered (or Float32Array for JS)
     */
    public function render(buffer:Any, sampleCount:Int):Dynamic {
        #if cpp
        // For C++, render via CFFI into a Bytes buffer, then copy to ByteArray
        var ba:openfl.utils.ByteArray = cast buffer;
        var totalFloats = sampleCount * channels;
        var bytes:HaxeBytes = HaxeBytes.alloc(totalFloats * 4);
        var rendered:Int = getCffiRender()(handle, bytes, sampleCount);
        ba.length = totalFloats * 4;
        ba.position = 0;
        if (rendered <= 0) {
            // write silence
            for (i in 0...totalFloats) ba.writeFloat(0.0);
            return 0;
        }
        // Copy raw bytes (float32 PCM) directly
        ba.writeBytes(bytes, 0, totalFloats * 4);
        ba.position = 0;
        return rendered;
        #elseif hl
        // For HashLink, buffer should be hl.Bytes
        return tsf_render(handle, cast buffer, sampleCount);
        #elseif js
        if (handle != 0) {
            var audioData:Float32Array = untyped glue.render(handle, sampleCount);
            // Copy to provided buffer if needed
            if (buffer != null && Std.is(buffer, Float32Array)) {
                var typedBuffer:Float32Array = cast buffer;
                typedBuffer.set(audioData);
            }
            return audioData; // Return the Float32Array for JS
        }
        return null;
        #else
        return 0;
        #end
    }

    #if cpp
    /**
     * Render audio samples to Bytes (C++ fast path)
     */
    public function renderBytes(sampleCount:Int):HaxeBytes {
        if (sampleCount <= 0) return HaxeBytes.alloc(0);
        var totalFloats = sampleCount * channels;
        var bytes:HaxeBytes = HaxeBytes.alloc(totalFloats * 4);
        // Get raw pointer to Bytes data using hxcpp API
        var ptr:cpp.RawPointer<cpp.Void> = untyped __cpp__("(void*)({0}->b->GetBase())", bytes);
        var rendered:Int = MidiSynthNative.render(handle, ptr, sampleCount);
        if (rendered <= 0) return HaxeBytes.alloc(0);
        return bytes;
    }
    #end
    
    /**
     * Get the number of currently active voices
     * @return Active voice count
     */
    public function getActiveVoices():Int {
        #if cpp
        return MidiSynthNative.activeVoices(handle);
        #elseif hl
        return tsf_active_voices(handle);
        #elseif js
        if (handle != 0) {
            return untyped glue.activeVoices(handle);
        }
        return 0;
        #else
        return 0;
        #end
    }
    
    /**
     * Clean up and free resources
     */
    public function dispose():Void {
        #if cpp
        if (handle != null) {
            MidiSynthNative.close(handle);
            handle = null;
        }
        #elseif hl
        if (handle != null) {
            tsf_close(handle);
            handle = null;
        }
        #elseif js
        if (handle != 0) {
            untyped glue.close(handle);
            handle = 0;
        }
        #end
    }
}
