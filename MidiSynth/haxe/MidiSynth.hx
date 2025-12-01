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
@:cppFileCode('#define TSF_IMPLEMENTATION\n#include "../../../../MidiSynth/cpp/tsf/tsf.h"\nextern "C" {\ntypedef void* TSFHandle;\n}\nstruct TSFSynth { tsf* synth; int sampleRate; int channels; };\nstatic TSFHandle tsf_bridge_init(const char* path) { if (!path) return NULL; tsf* synth = tsf_load_filename(path); if (!synth) return NULL; TSFSynth* handle = (TSFSynth*)malloc(sizeof(TSFSynth)); if (!handle) { tsf_close(synth); return NULL; } handle->synth = synth; handle->sampleRate = 44100; handle->channels = 2; tsf_set_output(synth, TSF_STEREO_INTERLEAVED, 44100, 0.0f); tsf_channel_set_bank_preset(synth, 0, 0, 0); return (TSFHandle)handle; }\nstatic void tsf_bridge_close(TSFHandle handle) { if (!handle) return; TSFSynth* synth = (TSFSynth*)handle; if (synth->synth) tsf_close(synth->synth); free(synth); }\nstatic void tsf_bridge_set_output(TSFHandle handle, int sample_rate, int channels) { if (!handle) return; TSFSynth* synth = (TSFSynth*)handle; synth->sampleRate = sample_rate; synth->channels = channels; enum TSFOutputMode mode = (channels == 1) ? TSF_MONO : TSF_STEREO_INTERLEAVED; tsf_set_output(synth->synth, mode, sample_rate, 0.0f); }\nstatic void tsf_bridge_note_on(TSFHandle handle, int channel, int note, int velocity) { if (!handle) return; TSFSynth* synth = (TSFSynth*)handle; float vel = velocity / 127.0f; tsf_channel_note_on(synth->synth, channel, note, vel); }\nstatic void tsf_bridge_note_off(TSFHandle handle, int channel, int note) { if (!handle) return; TSFSynth* synth = (TSFSynth*)handle; tsf_channel_note_off(synth->synth, channel, note); }\nstatic void tsf_bridge_set_preset(TSFHandle handle, int channel, int bank, int preset) { if (!handle) return; TSFSynth* synth = (TSFSynth*)handle; tsf_channel_set_bank_preset(synth->synth, channel, bank, preset); }\nstatic int tsf_bridge_render(TSFHandle handle, float* buffer, int sample_count) { if (!handle || !buffer || sample_count <= 0) return 0; TSFSynth* synth = (TSFSynth*)handle; tsf_render_float(synth->synth, buffer, sample_count, 0); return sample_count; }\nstatic void tsf_bridge_note_off_all(TSFHandle handle) { if (!handle) return; TSFSynth* synth = (TSFSynth*)handle; tsf_note_off_all(synth->synth); }\nstatic int tsf_bridge_active_voices(TSFHandle handle) { if (!handle) return 0; TSFSynth* synth = (TSFSynth*)handle; return tsf_active_voice_count(synth->synth); }\n')
#end
class MidiSynth {
    #if cpp
    private var handle:cpp.RawPointer<cpp.Void>;
    #elseif hl
    private var handle:Dynamic;
    #elseif js
    private var handle:Int;
    private static var wasmModule:Dynamic = null;
    private static var glue:Dynamic = null;
    #end
    
    private var sampleRate:Int;
    private var channels:Int;
    
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
        var pathBytes = Bytes.fromString(path);
        handle = tsf_init(pathBytes);
        if (handle == null) {
            throw "Failed to load SoundFont: " + path;
        }
        tsf_set_output(handle, sampleRate, channels);
    }
    
    @:hlNative("tsf", "init")
    private static function tsf_init(path:Bytes):Dynamic { return null; }
    
    @:hlNative("tsf", "close")
    private static function tsf_close(handle:Dynamic):Void {}
    
    @:hlNative("tsf", "set_output")
    private static function tsf_set_output(handle:Dynamic, sampleRate:Int, channels:Int):Void {}
    
    @:hlNative("tsf", "note_on")
    private static function tsf_note_on(handle:Dynamic, channel:Int, note:Int, velocity:Int):Void {}
    
    @:hlNative("tsf", "note_off")
    private static function tsf_note_off(handle:Dynamic, channel:Int, note:Int):Void {}
    
    @:hlNative("tsf", "set_preset")
    private static function tsf_set_preset(handle:Dynamic, channel:Int, bank:Int, preset:Int):Void {}
    
    @:hlNative("tsf", "render")
    private static function tsf_render(handle:Dynamic, buffer:Bytes, samples:Int):Int { return 0; }
    
    @:hlNative("tsf", "note_off_all")
    private static function tsf_note_off_all(handle:Dynamic):Void {}
    
    @:hlNative("tsf", "active_voices")
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
            trace("MidiSynth initialized for HTML5");
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
        
        // Load TSF WASM module
        untyped __js__("
            TSFModule().then(function(Module) {
                TSFGlue.init(Module);
            });
        ");
        
        glue = untyped __js__("TSFGlue");
        initialized = true;
        
        onComplete();
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
     * Stop all currently playing notes
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
     * Set the instrument preset for a channel
     * @param channel MIDI channel (0-15)
     * @param bank Instrument bank (usually 0 for General MIDI)
     * @param preset Preset number (0-127, e.g., 0 = Acoustic Grand Piano)
     */
    public function setPreset(channel:Int, bank:Int, preset:Int):Void {
        #if cpp
        MidiSynthNative.setPreset(handle, channel, bank, preset);
        #elseif hl
        tsf_set_preset(handle, channel, bank, preset);
        #elseif js
        if (handle != 0) {
            untyped glue.setPreset(handle, channel, bank, preset);
        }
        #end
    }
    
    /**
     * Render audio samples
     * @param buffer Output buffer (Float32 array, interleaved stereo if channels=2)
     * @param sampleCount Number of samples to render (frames, not total floats)
     * @return Number of samples actually rendered
     */
    public function render(buffer:Any, sampleCount:Int):Int {
        #if cpp
        // For C++, accept openfl ByteArray and render via pointer
        var ba:openfl.utils.ByteArray = cast buffer;
        ba.length = sampleCount * channels * 4;
        ba.position = 0;
        var dataPtr:cpp.Pointer<cpp.UInt8> = untyped ba.getData();
        var floatPtr:cpp.RawPointer<cpp.Float32> = cast dataPtr.raw;
        return MidiSynthNative.render(handle, floatPtr, sampleCount);
        #elseif hl
        // For HashLink, buffer should be hl.Bytes
        return tsf_render(handle, cast buffer, sampleCount);
        #elseif js
        if (handle != 0) {
            var audioData:Float32Array = untyped glue.render(handle, sampleCount);
            // Copy to provided buffer if needed
            if (Std.is(buffer, Float32Array)) {
                var typedBuffer:Float32Array = cast buffer;
                typedBuffer.set(audioData);
            }
            return sampleCount;
        }
        return 0;
        #else
        return 0;
        #end
    }
    
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
