package;

import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.events.SampleDataEvent;
import openfl.media.Sound;
import openfl.media.SoundChannel;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.ui.Keyboard;
import openfl.utils.ByteArray;

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
    
    // Audio buffer configuration
    private static inline var SAMPLE_RATE:Int = 44100;
    private static inline var CHANNELS:Int = 2;
    private static inline var BUFFER_SIZE:Int = 8192; // Samples per callback
    
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
        // For HTML5, we need to initialize WASM first
        MidiSynth.initializeWasm(function() {
            initializeSynth();
        });
        #else
        initializeSynth();
        #end
    }
    
    private function initializeSynth():Void {
        try {
            trace("Attempting to create MidiSynth...");
            // Create synthesizer with GM.sf2 SoundFont
            synth = new MidiSynth("assets/soundfonts/GM.sf2", SAMPLE_RATE, CHANNELS);
            trace("MidiSynth created successfully");
            
            // Set up channel 0 with piano (preset 0)
            synth.setPreset(0, 0, 0);
            
            updateInfo("MidiSynth initialized successfully!\nPress keys to play notes.");
            
            // Set up audio output
            initializeAudio();
            
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
        
        // Register callback for sample data
        sound.addEventListener(SampleDataEvent.SAMPLE_DATA, onSampleData);
        
        // Start playback
        soundChannel = sound.play();
        
        trace("Audio stream started");
    }
    
    private function onSampleData(event:SampleDataEvent):Void {
        // This callback is called when OpenFL needs more audio data
        // We render audio from the synthesizer and write it to the output buffer
        
        #if cpp
        // For C++, we can render directly
        var buffer = new ByteArray();
        buffer.length = BUFFER_SIZE * CHANNELS * 4; // 4 bytes per float
        
        // Render samples from synth
        synth.render(buffer, BUFFER_SIZE);
        
        // Write to output
        buffer.position = 0;
        for (i in 0...BUFFER_SIZE * CHANNELS) {
            var sample = buffer.readFloat();
            event.data.writeFloat(sample);
        }
        
        #elseif hl
        // For HashLink, similar approach
        var buffer = new hl.Bytes(BUFFER_SIZE * CHANNELS * 4);
        synth.render(buffer, BUFFER_SIZE);
        
        // Convert to ByteArray for OpenFL
        for (i in 0...BUFFER_SIZE * CHANNELS) {
            var sample = buffer.getF32(i * 4);
            event.data.writeFloat(sample);
        }
        
        #elseif js
        // For HTML5, render returns Float32Array
        var audioData = synth.render(null, BUFFER_SIZE);
        
        if (audioData != null) {
            for (i in 0...BUFFER_SIZE * CHANNELS) {
                event.data.writeFloat(untyped audioData[i]);
            }
        } else {
            // Write silence if not ready
            for (i in 0...BUFFER_SIZE * CHANNELS) {
                event.data.writeFloat(0.0);
            }
        }
        
        #else
        // Fallback: write silence
        for (i in 0...BUFFER_SIZE * CHANNELS) {
            event.data.writeFloat(0.0);
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
            // Panic button - stop all notes
            synth.noteOffAll();
            activeNotes = new Map<Int, Bool>();
            updateInfo("All notes stopped");
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
}
