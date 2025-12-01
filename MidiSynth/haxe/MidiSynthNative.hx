package;

#if cpp
@:headerCode('extern "C" {\n  void* tsf_bridge_init(const char* path);\n  void tsf_bridge_close(void* handle);\n  void tsf_bridge_set_output(void* handle, int sampleRate, int channels);\n  void tsf_bridge_note_on(void* handle, int channel, int note, int velocity);\n  void tsf_bridge_note_off(void* handle, int channel, int note);\n  void tsf_bridge_set_preset(void* handle, int channel, int bank, int preset);\n  int tsf_bridge_render(void* handle, float* buffer, int sampleCount);\n  void tsf_bridge_note_off_all(void* handle);\n  int tsf_bridge_active_voices(void* handle);\n}\n')
extern class MidiSynthNative {
    @:native("tsf_bridge_init")
    public static function init(path:cpp.ConstCharStar):cpp.RawPointer<cpp.Void>;

    @:native("tsf_bridge_close")
    public static function close(handle:cpp.RawPointer<cpp.Void>):Void;

    @:native("tsf_bridge_set_output")
    public static function setOutput(handle:cpp.RawPointer<cpp.Void>, sampleRate:Int, channels:Int):Void;

    @:native("tsf_bridge_note_on")
    public static function noteOn(handle:cpp.RawPointer<cpp.Void>, channel:Int, note:Int, velocity:Int):Void;

    @:native("tsf_bridge_note_off")
    public static function noteOff(handle:cpp.RawPointer<cpp.Void>, channel:Int, note:Int):Void;

    @:native("tsf_bridge_set_preset")
    public static function setPreset(handle:cpp.RawPointer<cpp.Void>, channel:Int, bank:Int, preset:Int):Void;

    @:native("tsf_bridge_render")
    public static function render(handle:cpp.RawPointer<cpp.Void>, buffer:cpp.RawPointer<cpp.Float32>, sampleCount:Int):Int;

    @:native("tsf_bridge_note_off_all")
    public static function noteOffAll(handle:cpp.RawPointer<cpp.Void>):Void;

    @:native("tsf_bridge_active_voices")
    public static function activeVoices(handle:cpp.RawPointer<cpp.Void>):Int;
}
#end
