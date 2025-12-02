package procedural;

import procedural.StructuredSong;
import procedural.NoteEvent;
import openfl.utils.Timer;
import openfl.events.TimerEvent;

/**
 * Scheduler for real-time playback of a StructuredSong using MidiSynth.
 */
class Scheduler {
    public var song:StructuredSong;
    public var synth:MidiSynth;
    
    private var events:Array<NoteEvent>;
    private var eventIndex:Int = 0;
    private var playbackTimer:Timer;
    private var startTime:Float = 0;
    private var playbackTime:Float = 0;
    private var lastTickTime:Float = 0;
    public var isPlaying:Bool = false;
    private var activeNotes:Map<String, Bool>;
    
    public function new(song:StructuredSong, synth:MidiSynth) {
        this.song = song;
        this.synth = synth;
        this.activeNotes = new Map();
    }
    
    public function play():Void {
        if (isPlaying) return;
        
        // Render all events
        events = song.render();
        trace('--- Playing BPM:' + song.bpm + ' with ' + events.length + ' events');
        
        // Set up instruments for each channel
        setupInstruments();
        
        eventIndex = 0;
        isPlaying = true;
        startTime = haxe.Timer.stamp();
        lastTickTime = startTime;
        playbackTime = 0;
        
        // Start playback timer (5ms intervals for precision)
        playbackTimer = new Timer(5);
        playbackTimer.addEventListener(TimerEvent.TIMER, onPlaybackTick);
        playbackTimer.start();
    }
    
    public function stop():Void {
        if (!isPlaying) return;
        
        isPlaying = false;
        if (playbackTimer != null) {
            playbackTimer.stop();
            playbackTimer = null;
        }
        
        // Stop all active notes
        synth.panicStopAllNotes();
        activeNotes = new Map();
        
        trace('Playback stopped');
    }
    
    private function setupInstruments():Void {
        // Scan for unique channels and set their instruments
        var channelInstruments = new Map<Int, Int>();
        for (e in events) {
            if (!channelInstruments.exists(e.channel)) {
                channelInstruments.set(e.channel, 0); // Default to piano
            }
        }
        
        for (ch in channelInstruments.keys()) {
            synth.setPreset(ch, 0, channelInstruments.get(ch));
        }
    }
    
    private function onPlaybackTick(e:TimerEvent):Void {
        if (!isPlaying) return;
        
        var now = haxe.Timer.stamp();
        var delta = (now - lastTickTime) * 1000.0; // ms since last tick
        lastTickTime = now;
        playbackTime += delta;
        
        // Convert beats to milliseconds
        var beatsPerSecond = song.bpm / 60.0;
        var currentBeat = playbackTime / 1000.0 * beatsPerSecond;
        
        // Process all events up to current time
        while (eventIndex < events.length) {
            var ev = events[eventIndex];
            if (ev.startBeat > currentBeat) break;
            
            // Trigger note on
            synth.noteOn(ev.channel, ev.note, ev.velocity);
            var key = ev.channel + ":" + ev.note;
            activeNotes.set(key, true);
            
            // Schedule note off
            var noteOffDelay = Std.int(ev.durationBeats / beatsPerSecond * 1000);
            scheduleNoteOff(ev.channel, ev.note, noteOffDelay);
            
            eventIndex++;
        }
        
        // Stop if done
        if (eventIndex >= events.length && activeNotes.keys().hasNext() == false) {
            stop();
        }
    }
    
    private function scheduleNoteOff(channel:Int, note:Int, delayMs:Int):Void {
        haxe.Timer.delay(function() {
            synth.noteOff(channel, note);
            var key = channel + ":" + note;
            activeNotes.remove(key);
        }, delayMs);
    }
}
