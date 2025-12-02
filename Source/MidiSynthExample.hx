package;

import openfl.display.Sprite;
import moonchart.parsers.MidiParser;
import openfl.utils.ByteArray;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.events.KeyboardEvent;
import openfl.events.SampleDataEvent;
import openfl.media.Sound;
import openfl.media.SoundChannel;
import openfl.utils.Timer;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.ui.Keyboard;
import openfl.utils.ByteArray;
import openfl.events.TimerEvent;

#if cpp
import cpp.vm.Gc;
#elseif hl
import hl.Gc;
#end

/**
 * Example demonstrating MidiSynth integration with OpenFL
 * Features:
 * - Real-time audio synthesis using SampleDataEvent
 * - Keyboard input for playing notes (piano keys)
 * - Visual feedback
 */
class MidiSynthExample extends Sprite {
    private var synth:MidiSynth;
    private var sound:Sound;
    private var soundChannel:SoundChannel;
    private var infoText:TextField;
    private var renderTimer:Timer;
    private var audioQueue:Array<haxe.io.Bytes> = [];
    // --- MIDI File Loading and Playback ---
    private var midiLoadButton:openfl.display.SimpleButton;
    // Track active notes during playback for stuck note analysis
    private var playbackActiveNotes:Map<String, Int> = new Map();
    private var midiEvents:Array<Dynamic> = [];
    private var midiPlaybackTimer:Timer;
    private var midiPlaybackPos:Float = 0.0;
    private var midiIsPlaying:Bool = false;
    private var midiStartTime:Float = 0.0;
    private var midiLastTickTime:Float = 0.0; // last wall time in seconds
    private var midiPlaybackTime:Float = 0.0; // running playback time in ms
    private var midiTempo:Float = 500000.0; // microseconds per quarter note (default 120bpm)
    private var midiTicksPerQuarter:Int = 480; // default, will be set from file
    private var midiFileLoaded:Bool = false;
    
    // --- Procedural Music Engine ---
    private var proceduralEngine:ProceduralMusicEngine;
    private var proceduralPlayButton:openfl.display.SimpleButton;
    private var proceduralStopButton:openfl.display.SimpleButton;
    
    #if html5
    private var audioStarted:Bool = false;
    #end
    
    // Audio buffer configuration
    private static inline var SAMPLE_RATE:Int = 44100;
    private static inline var CHANNELS:Int = 2;
    private static inline var BUFFER_SIZE:Int = 2048; // Samples per callback (smaller for stability)
    
    // Keyboard to MIDI note mapping
    // A S D F G H J K L = C4 to E5 (white keys)
    // W E   T Y U   O P = C#4 to D#5 (black keys)
    private var keyToNote:Map<Int, Int>;
    private var activeNotes:Map<Int, Bool>;
    
    public function new() {
        super();
        
        activeNotes = new Map<Int, Bool>();
        setupKeyMapping();
        
        addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
    }
    
    private function onAddedToStage(e:Event):Void {
        removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
        
        // Create info text
        createInfoDisplay();
        
        // Initialize synthesizer
        #if html5
        // For HTML5, initialize WASM first, and delay audio start until user gesture
        MidiSynth.initializeWasm(function() {
            initializeSynth();
            stage.addEventListener(KeyboardEvent.KEY_DOWN, onStartAudio);
            stage.addEventListener(MouseEvent.MOUSE_DOWN, onStartAudio);
        });
        #else
        initializeSynth();
        #end

        // Add MIDI load button below infoText
        midiLoadButton = createMidiLoadButton();
        midiLoadButton.x = 10;
        midiLoadButton.y = infoText.y + infoText.height + 10;
        addChild(midiLoadButton);
        
        // Add procedural music buttons
        proceduralPlayButton = createProceduralPlayButton();
        proceduralPlayButton.x = 10;
        proceduralPlayButton.y = midiLoadButton.y + 40;
        addChild(proceduralPlayButton);
        
        proceduralStopButton = createProceduralStopButton();
        proceduralStopButton.x = 150;
        proceduralStopButton.y = proceduralPlayButton.y;
        addChild(proceduralStopButton);
    }

    #if html5
    private function onStartAudio(_e:Event):Void {
        if (audioStarted) return;
        audioStarted = true;
        try {
            initializeAudio();
            updateInfo("Audio started. Press keys to play notes.");
        } catch (e:Dynamic) {
            updateInfo("Audio init failed: " + Std.string(e));
        }
        stage.removeEventListener(KeyboardEvent.KEY_DOWN, onStartAudio);
        stage.removeEventListener(MouseEvent.MOUSE_DOWN, onStartAudio);
    }
    #end
    
    private function initializeSynth():Void {
        try {
            trace("Attempting to create MidiSynth...");
            // Create synthesizer with GM.sf2 SoundFont
            // Use the correct packaged Assets path for native targets
            synth = new MidiSynth(
                #if html5
                    "assets/soundfonts/GM.small.sf2"
                #else
                    "Assets/soundfonts/GM.sf2"
                #end
                , SAMPLE_RATE, CHANNELS);
            trace("MidiSynth created successfully");
            
            // Set up channel 0 with piano (preset 0)
            trace("Calling setPreset(0,0,0)...");
            try {
                synth.setPreset(0, 0, 0);
                trace("setPreset completed");
            } catch (e:Dynamic) {
                trace("ERROR in setPreset: " + Std.string(e));
                throw e;
            }
            
            updateInfo("MidiSynth initialized successfully!\nPress keys to play notes.");
            
            // Set up audio output
            trace("Calling initializeAudio()...");
            #if !html5
            try {
                initializeAudio();
                trace("initializeAudio completed");
            } catch (e:Dynamic) {
                trace("ERROR in initializeAudio: " + Std.string(e));
                // Do not rethrow here; keep app alive for diagnostics
                updateInfo("Audio init failed, running without sound.\n" + Std.string(e));
            }
            #end
            
            // Set up keyboard input
            stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
            stage.addEventListener(KeyboardEvent.KEY_UP, onKeyUp);
            
        } catch (e:Dynamic) {
            updateInfo("ERROR: Failed to initialize MidiSynth\n" + Std.string(e));
        }
    }
    
    private function initializeAudio():Void {
        // Create a Sound object for dynamic audio generation
        sound = new Sound();

        // Register callback for sample data BEFORE starting playback
        sound.addEventListener(SampleDataEvent.SAMPLE_DATA, onSampleData);

        // Start playback - this will begin calling onSampleData
        soundChannel = sound.play();
        if (soundChannel == null) {
            throw "Failed to start audio playback";
        }

        // Start a timer to render audio - match callback frequency (not faster)
        // SampleDataEvent typically fires ~20-40 times per second
        var ms = Math.floor(1000 * BUFFER_SIZE / SAMPLE_RATE); // Render at consumption rate
        renderTimer = new Timer(ms);
        renderTimer.addEventListener(TimerEvent.TIMER, onRenderTick);
        renderTimer.start();

        // Minimal prefill - for HTML5 fill the entire buffer
        #if html5
        for (i in 0...MAX_QUEUE_SIZE) {
            var silence = haxe.io.Bytes.alloc(BUFFER_SIZE * CHANNELS * 4);
            for (j in 0...BUFFER_SIZE * CHANNELS) silence.setFloat(j * 4, 0.0);
            audioQueue.push(silence);
        }
        #else
        for (i in 0...2) {
            var silence = haxe.io.Bytes.alloc(BUFFER_SIZE * CHANNELS * 4);
            for (j in 0...BUFFER_SIZE * CHANNELS) silence.setFloat(j * 4, 0.0);
            audioQueue.push(silence);
        }
        #end
    }    private var renderCount:Int = 0;
    #if html5
    private static inline var MAX_QUEUE_SIZE:Int = 6; // More buffering for WASM overhead
    #else
    private static inline var MAX_QUEUE_SIZE:Int = 3; // Keep latency minimal (~70ms)
    #end
    
    private function onRenderTick(e:TimerEvent):Void {
        // For HTML5, render multiple buffers per tick to compensate for WASM overhead
        #if html5
        var buffersToRender = MAX_QUEUE_SIZE - audioQueue.length;
        for (i in 0...buffersToRender) {
            if (audioQueue.length >= MAX_QUEUE_SIZE) break;
            renderOneBuffer();
        }
        #else
        // Don't render if queue is already full
        if (audioQueue.length >= MAX_QUEUE_SIZE) {
            return;
        }
        renderOneBuffer();
        #end
    }
    
    private function renderOneBuffer():Void {
        
        try {
            #if cpp
            // Render one buffer per tick to match consumption rate
            var bytes = synth.renderBytes(BUFFER_SIZE);
            audioQueue.push(bytes);
            #elseif hl
            var hlbuf = new hl.Bytes(BUFFER_SIZE * CHANNELS * 4);
            synth.render(hlbuf, BUFFER_SIZE);
            var bytes = haxe.io.Bytes.alloc(BUFFER_SIZE * CHANNELS * 4);
            for (i in 0...BUFFER_SIZE * CHANNELS) bytes.setFloat(i * 4, hlbuf.getF32(i * 4));
            audioQueue.push(bytes);
            #elseif js
            var audioData = synth.render(null, BUFFER_SIZE);
            #if debug
            trace("JS render tick: got " + (audioData != null ? BUFFER_SIZE : 0) + " samples");
            #end
            var bytes = haxe.io.Bytes.alloc(BUFFER_SIZE * CHANNELS * 4);
            if (audioData != null) {
                for (i in 0...BUFFER_SIZE * CHANNELS) bytes.setFloat(i * 4, untyped audioData[i]);
            }
            audioQueue.push(bytes);
            #if debug
            trace("Queue length after push (js): " + audioQueue.length);
            #end
            #else
            var bytes = haxe.io.Bytes.alloc(BUFFER_SIZE * CHANNELS * 4);
            audioQueue.push(bytes);
            #end
        } catch (err:Dynamic) {
            // On error, push silence
            var silence = haxe.io.Bytes.alloc(BUFFER_SIZE * CHANNELS * 4);
            for (i in 0...BUFFER_SIZE * CHANNELS) silence.setFloat(i * 4, 0.0);
            audioQueue.push(silence);
            audioQueue.push(silence);
        }
    }
    
    private function onSampleData(event:SampleDataEvent):Void {
        #if (cpp || hl)
        var bytes:Null<haxe.io.Bytes> = audioQueue.length > 0 ? audioQueue.shift() : null;

        if (bytes == null || bytes.length == 0) {
            // Underrun: write silence
            for (i in 0...BUFFER_SIZE * CHANNELS) event.data.writeFloat(0.0);
            return;
        }

        // Write buffered audio samples (float32 interleaved)
        var MASTER_GAIN = 0.7; // Reduce to 70% to prevent clipping
        for (i in 0...BUFFER_SIZE * CHANNELS) {
            var sample = bytes.getFloat(i * 4) * MASTER_GAIN;
            // Clamp to [-1, 1] just in case
            if (sample > 1.0) sample = 1.0;
            else if (sample < -1.0) sample = -1.0;
            event.data.writeFloat(sample);
        }
        #elseif js
        // HTML5/WASM path: consume queued buffers rendered via WASM synth
        var bytes:Null<haxe.io.Bytes> = audioQueue.length > 0 ? audioQueue.shift() : null;
        if (bytes == null || bytes.length == 0) {
            // Underrun: write silence
            for (i in 0...BUFFER_SIZE * CHANNELS) event.data.writeFloat(0.0);
            return;
        }
        for (i in 0...BUFFER_SIZE * CHANNELS) {
            event.data.writeFloat(bytes.getFloat(i * 4));
        }
        #else
        // Other targets: consume JS queue if available, else silence
        var bytes:Null<haxe.io.Bytes> = audioQueue.length > 0 ? audioQueue.shift() : null;
        if (bytes == null || bytes.length == 0) {
            for (i in 0...BUFFER_SIZE * CHANNELS) event.data.writeFloat(0.0);
        } else {
            for (i in 0...BUFFER_SIZE * CHANNELS) event.data.writeFloat(bytes.getFloat(i * 4));
        }
        #end
    }
    
    private function setupKeyMapping():Void {
        keyToNote = new Map<Int, Int>();
        
        // White keys (C major scale starting at C4 = MIDI 60)
        keyToNote.set(Keyboard.A, 60);  // C4
        keyToNote.set(Keyboard.S, 62);  // D4
        keyToNote.set(Keyboard.D, 64);  // E4
        keyToNote.set(Keyboard.F, 65);  // F4
        keyToNote.set(Keyboard.G, 67);  // G4
        keyToNote.set(Keyboard.H, 69);  // A4
        keyToNote.set(Keyboard.J, 71);  // B4
        keyToNote.set(Keyboard.K, 72);  // C5
        keyToNote.set(Keyboard.L, 74);  // D5
        
        // Black keys (sharps)
        keyToNote.set(Keyboard.W, 61);  // C#4
        keyToNote.set(Keyboard.E, 63);  // D#4
        keyToNote.set(Keyboard.T, 66);  // F#4
        keyToNote.set(Keyboard.Y, 68);  // G#4
        keyToNote.set(Keyboard.U, 70);  // A#4
        keyToNote.set(Keyboard.O, 73);  // C#5
        keyToNote.set(Keyboard.P, 75);  // D#5
        
        // Lower octave
        keyToNote.set(Keyboard.Z, 48);  // C3
        keyToNote.set(Keyboard.X, 50);  // D3
        keyToNote.set(Keyboard.C, 52);  // E3
        keyToNote.set(Keyboard.V, 53);  // F3
        keyToNote.set(Keyboard.B, 55);  // G3
        keyToNote.set(Keyboard.N, 57);  // A3
        keyToNote.set(Keyboard.M, 59);  // B3
    }
    
    private function onKeyDown(e:KeyboardEvent):Void {
        var note = keyToNote.get(e.keyCode);
        
        if (note != null && !activeNotes.exists(note)) {
            // Play note with full velocity
            synth.noteOn(0, note, 127);
            activeNotes.set(note, true);
            
            updateInfo("Playing note: " + note + " (" + getNoteNamemidi(note) + ")\n" +
                      "Active voices: " + synth.getActiveVoices());
        }
        
        // Special keys
        if (e.keyCode == Keyboard.SPACE) {
            // Old panic: stop all notes on current channel only
            synth.noteOffAll();
            activeNotes = new Map<Int, Bool>();
            updateInfo("All notes stopped");
        } else if (e.keyCode == Keyboard.ESCAPE) {
            // PANIC: stop all notes on all channels and reset controllers
            for (channel in 0...16) {
                // Release sustain pedal
                synth.controlChange(channel, 64, 0);
                // All Notes Off
                synth.controlChange(channel, 123, 0);
                // All Sound Off (immediate)
                synth.controlChange(channel, 120, 0);
            }
            synth.noteOffAll();
            synth.panicStopAllNotes(); // Also resets controllers
            activeNotes = new Map<Int, Bool>();
            updateInfo("PANIC: All notes, sound, and controllers reset");
        }
    }
    
    private function createProceduralPlayButton():openfl.display.SimpleButton {
        var up:Sprite = new Sprite();
        up.graphics.beginFill(0x22AA22);
        up.graphics.drawRect(0, 0, 130, 32);
        up.graphics.endFill();
        var tf = new TextField();
        tf.text = "Play Procedural";
        tf.width = 130;
        tf.height = 32;
        tf.selectable = false;
        up.addChild(tf);

        var over:Sprite = new Sprite();
        over.graphics.beginFill(0x44CC44);
        over.graphics.drawRect(0, 0, 130, 32);
        over.graphics.endFill();
        var tf2 = new TextField();
        tf2.text = "Play Procedural";
        tf2.width = 130;
        tf2.height = 32;
        tf2.selectable = false;
        over.addChild(tf2);

        var down:Sprite = new Sprite();
        down.graphics.beginFill(0x116611);
        down.graphics.drawRect(0, 0, 130, 32);
        down.graphics.endFill();
        var tf3 = new TextField();
        tf3.text = "Play Procedural";
        tf3.width = 130;
        tf3.height = 32;
        tf3.selectable = false;
        down.addChild(tf3);

        var button = new openfl.display.SimpleButton(up, over, down, up);
        button.addEventListener(MouseEvent.CLICK, onProceduralPlay);
        return button;
    }
    
    private function createProceduralStopButton():openfl.display.SimpleButton {
        var up:Sprite = new Sprite();
        up.graphics.beginFill(0xAA2222);
        up.graphics.drawRect(0, 0, 130, 32);
        up.graphics.endFill();
        var tf = new TextField();
        tf.text = "Stop Procedural";
        tf.width = 130;
        tf.height = 32;
        tf.selectable = false;
        up.addChild(tf);

        var over:Sprite = new Sprite();
        over.graphics.beginFill(0xCC4444);
        over.graphics.drawRect(0, 0, 130, 32);
        over.graphics.endFill();
        var tf2 = new TextField();
        tf2.text = "Stop Procedural";
        tf2.width = 130;
        tf2.height = 32;
        tf2.selectable = false;
        over.addChild(tf2);

        var down:Sprite = new Sprite();
        down.graphics.beginFill(0x661111);
        down.graphics.drawRect(0, 0, 130, 32);
        down.graphics.endFill();
        var tf3 = new TextField();
        tf3.text = "Stop Procedural";
        tf3.width = 130;
        tf3.height = 32;
        tf3.selectable = false;
        down.addChild(tf3);

        var button = new openfl.display.SimpleButton(up, over, down, up);
        button.addEventListener(MouseEvent.CLICK, onProceduralStop);
        return button;
    }
    
    private function onProceduralPlay(e:MouseEvent):Void {
        if (proceduralEngine == null) {
            proceduralEngine = new ProceduralMusicEngine(synth);
            proceduralEngine.createDefaultSong(120, Std.int(Math.random() * 10000));
        }
        proceduralEngine.play();
        updateInfo("Procedural music started (BPM: 120)");
    }
    
    private function onProceduralStop(e:MouseEvent):Void {
        if (proceduralEngine != null) {
            proceduralEngine.stop();
            updateInfo("Procedural music stopped");
        }
    }
    
    private function onKeyUp(e:KeyboardEvent):Void {
        var note = keyToNote.get(e.keyCode);
        
        if (note != null && activeNotes.exists(note)) {
            synth.noteOff(0, note);
            activeNotes.remove(note);
            
            updateInfo("Released note: " + note + " (" + getNoteName(note) + ")\n" +
                      "Active voices: " + synth.getActiveVoices());
        }
    }
    
    private function getNoteName(midiNote:Int):String {
        var noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];
        var octave = Math.floor(midiNote / 12) - 1;
        var noteName = noteNames[midiNote % 12];
        return noteName + octave;
    }
    
    private function getNoteNamemidi(midiNote:Int):String {
        return getNoteName(midiNote);
    }
    
    private function createInfoDisplay():Void {
        infoText = new TextField();
        infoText.width = stage.stageWidth;
        infoText.height = 200;
        infoText.x = 10;
        infoText.y = 10;
        infoText.multiline = true;
        infoText.wordWrap = true;
        infoText.selectable = false;
        
        var format = new TextFormat();
        format.size = 16;
        format.color = 0xFFFFFF;
        format.font = "_sans";
        infoText.defaultTextFormat = format;
        
        addChild(infoText);
        
        updateInfo("Initializing MidiSynth...");
        // Add play/stop buttons for MIDI
        var playBtn = new openfl.display.SimpleButton();
        var up = new Sprite(); up.graphics.beginFill(0x228822); up.graphics.drawRect(0,0,60,28); up.graphics.endFill();
        var tf = new TextField(); tf.text = "Play"; tf.width = 60; tf.height = 28; tf.selectable = false; up.addChild(tf);
        playBtn.upState = playBtn.overState = playBtn.downState = playBtn.hitTestState = up;
        playBtn.x = 140; playBtn.y = 220;
        playBtn.addEventListener(MouseEvent.CLICK, function(_) startMidiPlayback());
        addChild(playBtn);

        var stopBtn = new openfl.display.SimpleButton();
        var up2 = new Sprite(); up2.graphics.beginFill(0xAA2222); up2.graphics.drawRect(0,0,60,28); up2.graphics.endFill();
        var tf2 = new TextField(); tf2.text = "Stop"; tf2.width = 60; tf2.height = 28; tf2.selectable = false; up2.addChild(tf2);
        stopBtn.upState = stopBtn.overState = stopBtn.downState = stopBtn.hitTestState = up2;
        stopBtn.x = 210; stopBtn.y = 220;
        stopBtn.addEventListener(MouseEvent.CLICK, function(_) stopMidiPlayback());
        addChild(stopBtn);
    }
    
    private function updateInfo(text:String):Void {
        if (infoText != null) {
            infoText.text = text;
        }
        trace(text);
    }
    
    /**
     * Clean up resources when done
     */
    public function dispose():Void {
        if (soundChannel != null) {
            soundChannel.stop();
        }
        
        if (sound != null) {
            sound.removeEventListener(SampleDataEvent.SAMPLE_DATA, onSampleData);
        }
        
        if (stage != null) {
            stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
            stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyUp);
        }
        
        if (synth != null) {
            synth.dispose();
        }
    }
    // --- MIDI File Loading and Playback ---
    private function createMidiLoadButton():openfl.display.SimpleButton {
        var up:Sprite = new Sprite();
        up.graphics.beginFill(0x4444AA);
        up.graphics.drawRect(0, 0, 120, 32);
        up.graphics.endFill();
        var tf = new TextField();
        tf.text = "Load MIDI File";
        tf.width = 120;
        tf.height = 32;
        tf.selectable = false;
        up.addChild(tf);

        var over:Sprite = new Sprite();
        over.graphics.beginFill(0x6666CC);
        over.graphics.drawRect(0, 0, 120, 32);
        over.graphics.endFill();
        var tf2 = new TextField();
        tf2.text = "Load MIDI File";
        tf2.width = 120;
        tf2.height = 32;
        tf2.selectable = false;
        over.addChild(tf2);

        var down:Sprite = new Sprite();
        down.graphics.beginFill(0x222288);
        down.graphics.drawRect(0, 0, 120, 32);
        down.graphics.endFill();
        var tf3 = new TextField();
        tf3.text = "Load MIDI File";
        tf3.width = 120;
        tf3.height = 32;
        tf3.selectable = false;
        down.addChild(tf3);

        var button = new openfl.display.SimpleButton(up, over, down, up);
        button.addEventListener(MouseEvent.CLICK, onMidiLoadClick);
        return button;
    }

    private function onMidiLoadClick(e:MouseEvent):Void {
        #if html5
        // Use <input type="file"> for HTML5
        var input:js.html.InputElement = cast js.Browser.document.createElement('input');
        input.type = 'file';
        input.accept = '.mid,.midi';
        input.onchange = function(ev) {
            var files = input.files;
            if (files != null && files.length > 0) {
                var file = files[0];
                var reader = new js.html.FileReader();
                reader.onload = function(_) {
                    var bytes = haxe.io.Bytes.ofData(reader.result);
                    onMidiFileLoaded(bytes);
                };
                reader.readAsArrayBuffer(file);
            }
        };
        input.click();
        #else
        // Native: use openfl.utils.FileReference
        var fileRef = new openfl.net.FileReference();
        fileRef.addEventListener(openfl.events.Event.SELECT, function(_) {
            fileRef.load();
        });
        fileRef.addEventListener(openfl.events.Event.COMPLETE, function(_) {
            var bytes = fileRef.data;
            onMidiFileLoaded(bytes);
        });
        fileRef.browse([new openfl.net.FileFilter("MIDI Files", "*.mid;*.midi")]);
        #end
    }

    private function onMidiFileLoaded(bytes:haxe.io.Bytes):Void {
        updateInfo("MIDI file loaded: " + bytes.length + " bytes\nParsing MIDI file...");
        try {
            midiEvents = parseMidiFile(bytes);
            midiFileLoaded = true;
            trace('First 10 parsed MIDI events:');
            for (i in 0...Std.int(Math.min(10, midiEvents.length))) {
                var ev = midiEvents[i];
                var msg = '  [' + i + '] time=' + Std.string(ev.time) + ' type=' + Std.string(ev.type) + ' ch=' + Std.string(ev.channel);
                if (Reflect.hasField(ev, "note")) msg += ' note=' + Std.string(ev.note);
                if (Reflect.hasField(ev, "velocity")) msg += ' vel=' + Std.string(ev.velocity);
                if (Reflect.hasField(ev, "program")) msg += ' program=' + Std.string(ev.program);
                if (Reflect.hasField(ev, "pitchBend")) msg += ' pitchBend=' + Std.string(ev.pitchBend);
                trace(msg);
            }
            updateInfo('MIDI file parsed. Found ' + midiEvents.length + ' note events. Ready to play.');
        } catch (e:Dynamic) {
            midiFileLoaded = false;
            updateInfo('ERROR parsing MIDI file: ' + Std.string(e));
            #if debug
            trace('MIDI parse error: ' + Std.string(e));
            #end
        }
        // Optionally, auto-start playback
        //startMidiPlayback();
    }

    // Parse MIDI file and return event list using moonchart
    private function parseMidiFile(bytes:haxe.io.Bytes):Array<Dynamic> {
        try {
            var parser = new MidiParser();
            var midi = parser.parseBytes(bytes);
            var events = [];
            var ticksPerQuarter = midi.division;
            var tempo = 500000.0; // default 120bpm
            var usPerTick = tempo / ticksPerQuarter; // microseconds per tick
            var msPerTick = usPerTick / 1000.0; // milliseconds per tick
            var currentTime = 0.0;
            var lastTick = 0;
            // Find tempo if present
            for (track in midi.tracks) {
                for (event in track) {
                    switch (event) {
                        case TEMPO_CHANGE(t, tick):
                            tempo = t;
                            usPerTick = tempo / ticksPerQuarter;
                        default:
                            // ignore
                    }
                }
            }
            // Parse note, program change, and pitch bend events
            for (track in midi.tracks) {
                lastTick = 0;
                currentTime = 0.0;
                for (event in track) {
                    var tick = 0;
                    switch (event) {
                        case MESSAGE(bytes, t):
                            tick = t;
                            var dt = tick - lastTick;
                            currentTime += dt * msPerTick; // ms
                            lastTick = tick;
                            var status = bytes[0] & 0xF0;
                            var channel = bytes[0] & 0x0F;
                            if (status == 0x90 && bytes[2] > 0) {
                                // Note on
                                events.push({time: currentTime, type: "on", channel: channel, note: bytes[1], velocity: bytes[2], program: 0, pitchBend: 0});
                            } else if ((status == 0x80) || (status == 0x90 && bytes[2] == 0)) {
                                // Note off
                                events.push({time: currentTime, type: "off", channel: channel, note: bytes[1], velocity: 0, program: 0, pitchBend: 0});
                            } else if (status == 0xC0) {
                                // Program change
                                events.push({time: currentTime, type: "program", channel: channel, note: 0, velocity: 0, program: bytes[1], pitchBend: 0});
                            } else if (status == 0xE0) {
                                // Pitch bend (0xE0)
                                var lsb = bytes[1];
                                var msb = bytes[2];
                                var pitchWheel = (msb << 7) | lsb; // 14-bit value
                                events.push({time: currentTime, type: "pitchbend", channel: channel, note: 0, velocity: 0, program: 0, pitchBend: pitchWheel});
                            } else if (status == 0xB0) {
                                // Control change (0xB0)
                                var controller = bytes[1];
                                var value = bytes[2];
                                events.push({
                                    time: currentTime,
                                    type: "control",
                                    channel: channel,
                                    note: controller, // store controller number in note
                                    velocity: value,  // controller value
                                    program: 0,
                                    pitchBend: 0
                                });
                            }
                        default:
                            // ignore
                    }
                }
            }
            return events;
        } catch (e:Dynamic) {
            #if debug
            trace('parseMidiFile error: ' + Std.string(e));
            #end
            throw e;
        }
    }

    // Start MIDI playback
    private function startMidiPlayback():Void {
            // Reset playback note tracking
            playbackActiveNotes = new Map();
        if (!midiFileLoaded || midiEvents.length == 0) {
            updateInfo("No MIDI loaded or no events.");
            return;
        }

        // --- Set initial instrument (program) for each channel ---
        var channelPrograms = new Map<Int, Int>();
        // Default to program 0 (Acoustic Grand Piano) for all channels
        for (ch in 0...16) channelPrograms.set(ch, 0);
        // Scan for first program change per channel
        for (ev in midiEvents) {
            if (Reflect.hasField(ev, "type") && ev.type == "program" &&
                Reflect.hasField(ev, "channel") && Reflect.hasField(ev, "program")) {
                var ch = ev.channel;
                var prog = ev.program;
                if (!channelPrograms.exists(ch) || channelPrograms.get(ch) == 0) {
                    channelPrograms.set(ch, prog);
                }
            }
        }

        // Set preset for each channel before playback, and log
        for (ch in 0...16) {
            var progVal = channelPrograms.get(ch);
            var progMaybe = Std.isOfType(progVal, Int) ? progVal : Std.parseInt(Std.string(progVal));
            var prog:Int = (progMaybe != null) ? progMaybe : 0;
            trace('Initial program for channel ' + ch + ': ' + prog);
            synth.setPreset(ch, 0, prog);
        }

        midiIsPlaying = true;
        midiPlaybackPos = 0.0;
        midiStartTime = haxe.Timer.stamp();
        midiLastTickTime = midiStartTime;
        midiPlaybackTime = 0.0;
        if (midiPlaybackTimer != null) midiPlaybackTimer.stop();
        midiPlaybackTimer = new Timer(5);
        midiPlaybackTimer.addEventListener(TimerEvent.TIMER, onMidiPlaybackTick);
        midiPlaybackTimer.start();
        updateInfo("MIDI playback started.");
    }

    // Stop MIDI playback
    private function stopMidiPlayback():Void {
        midiIsPlaying = false;
        if (midiPlaybackTimer != null) midiPlaybackTimer.stop();
        // After playback, keep rendering audio until all voices are silent (release tail)
        var releaseTimeoutMs = 1500; // Max time to wait for release (ms)
        var releaseCheckInterval = 50; // ms
        var waited = 0;
        // Immediately stop all notes and controllers
        if (synth != null) {
            synth.panicStopAllNotes();
        }
        function logActiveVoices() {
            var voices = synth.getActiveVoices();
            trace('Active voices after stop: ' + voices);
            // Print stuck notes summary
            if (playbackActiveNotes != null && playbackActiveNotes.keys().hasNext()) {
                var stuckList = [];
                for (key in playbackActiveNotes.keys()) {
                    var count = playbackActiveNotes.get(key);
                    if (count > 0) stuckList.push(key + " (" + count + ")");
                }
                if (stuckList.length > 0) {
                    trace('Stuck notes after playback: ' + stuckList.join(", "));
                } else {
                    trace('No stuck notes detected in playback event tracking.');
                }
            }
            #if debug
            if (voices > 0 && Reflect.hasField(synth, 'debugListVoices')) {
                var stuck = Reflect.callMethod(synth, Reflect.field(synth, 'debugListVoices'), []);
                trace('Stuck voices detail: ' + Std.string(stuck));
            }
            #end
        }
        function checkReleaseTail() {
            var voices = synth.getActiveVoices();
            if (voices > 0 && waited < releaseTimeoutMs) {
                waited += releaseCheckInterval;
                haxe.Timer.delay(checkReleaseTail, releaseCheckInterval);
            } else {
                logActiveVoices();
                updateInfo("MIDI playback stopped.");
            }
        }
        checkReleaseTail();
    }

    // MIDI playback timer tick
    private function onMidiPlaybackTick(e:TimerEvent):Void {
        if (!midiIsPlaying) return;
        var now = haxe.Timer.stamp();
        var delta = (now - midiLastTickTime) * 1000.0; // ms since last tick
        midiLastTickTime = now;
        midiPlaybackTime += delta;
        // Play all events whose time <= midiPlaybackTime
        while (midiPlaybackPos < midiEvents.length) {
            var ev = midiEvents[Std.int(midiPlaybackPos)];
            var evTime:Float = cast(ev.time, Float);
            if (evTime > midiPlaybackTime) break;
            var ch = Std.int(ev.channel);
            var note = Std.isOfType(ev.note, Int) ? ev.note : Std.parseInt(Std.string(ev.note));
            var velocity = Std.isOfType(ev.velocity, Int) ? ev.velocity : Std.parseInt(Std.string(ev.velocity));
            switch (ev.type) {
                case "on":
                    if (Reflect.hasField(ev, "note") && Reflect.hasField(ev, "velocity") && Std.isOfType(ev.note, Int) && Std.isOfType(ev.velocity, Int)) {
                        var key = ch + ":" + note;
                        if (playbackActiveNotes.exists(key) && playbackActiveNotes.get(key) > 0) {
                            trace('WARNING: NOTE ON received for already active note: channel=' + ch + ' note=' + note + ' (count=' + playbackActiveNotes.get(key) + ')');
                            // Workaround: forcibly send NOTE OFF before NOTE ON
                            synth.noteOff(ch, note);
                            // Track note-off
                            var v = playbackActiveNotes.get(key) - 1;
                            if (v <= 0) playbackActiveNotes.remove(key); else playbackActiveNotes.set(key, v);
                        }
                        synth.noteOn(ch, note, velocity);
                        // Track note-on
                        playbackActiveNotes.set(key, (playbackActiveNotes.exists(key) ? playbackActiveNotes.get(key) : 0) + 1);
                    }
                case "off":
                    if (Reflect.hasField(ev, "note") && Std.isOfType(ev.note, Int)) {
                        synth.noteOff(ch, note);
                        // Track note-off
                        var key = ch + ":" + note;
                        if (playbackActiveNotes.exists(key)) {
                            var v = playbackActiveNotes.get(key) - 1;
                            if (v <= 0) playbackActiveNotes.remove(key); else playbackActiveNotes.set(key, v);
                        }
                    }
                case "program":
                    if (Reflect.hasField(ev, "program")) {
                        var progVal = ev.program;
                        var progMaybe = Std.isOfType(progVal, Int) ? progVal : Std.parseInt(Std.string(progVal));
                        var prog:Int = (progMaybe != null) ? progMaybe : 0;
                        trace('Program change: channel ' + ch + ' -> program ' + prog);
                        synth.setPreset(ch, 0, prog);
                    }
                case "pitchbend":
                    if (Reflect.hasField(ev, "pitchBend") && Std.isOfType(ev.pitchBend, Int)) {
                        synth.pitchBend(ch, ev.pitchBend);
                    }
                case "control":
                    // Use ev.note as controller number, ev.velocity as value
                    if (Std.isOfType(ev.note, Int) && Std.isOfType(ev.velocity, Int)) {
                        if (note == 64) {
                            trace('SUSTAIN PEDAL: channel=' + ch + ' value=' + velocity);
                        }
                        synth.controlChange(ch, note, velocity);
                    }
            }
            midiPlaybackPos++;
        }
        // Stop if done
        if (midiPlaybackPos >= midiEvents.length) {
            stopMidiPlayback();
        }
    }
}
