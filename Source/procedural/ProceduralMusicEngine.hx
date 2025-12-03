package procedural;

import procedural.MusicContext;
import procedural.NoteEvent;
import procedural.Scheduler;
import procedural.Section;
import procedural.StructuredSong;
import procedural.Track;
import procedural.IGenerator;
import procedural.IRule;

/**
 * Core procedural music engine for generating and scheduling music.
 */
class ProceduralMusicEngine {
    public var song:StructuredSong;
    public var synth:MidiSynth;
    public var scheduler:Scheduler;

    // --- Strudel-like playback state ---
    private var strudelTimer:haxe.Timer;
    private var strudelChordIdx:Int = 0;
    private var strudelStep:Int = 0;
    private var strudelIsPlaying:Bool = false;
    private var strudelChords:Array<{root:String, type:String}>;
    private var strudelBpm:Int = 120;
    private var strudelChannelChord:Int = 0;
    private var strudelChannelLead:Int = 0;
    private var strudelAnchorMidi:Int = 60; // C4
    private var strudelChannelDrums:Int = 9; // GM percussion channel
    private var strudelChannelBass:Int = 1;  // Dedicated bass channel
    private var strudelBassAnchor:Int = 48;  // C3 anchor for bass

    public function new(song:StructuredSong, synth:MidiSynth) {
        this.song = song;
        this.synth = synth;
        this.scheduler = new Scheduler(song, synth);
    }

    /**
     * Generate all note events for the song (calls song.render()).
     */
    public function generateAllEvents():Array<NoteEvent> {
        return song.render();
    }

    /**
     * Play the song using the scheduler and MidiSynth.
     */
    public function play():Void {
        scheduler.play();
    }

    /**
     * Stop playback of the procedural music.
     */
    public function stop():Void {
        scheduler.stop();
    }

    // --- Strudel-like helpers ---
    private static var tonics = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];
    private static function tonicToMidi(tonic:String, octave:Int):Int {
        var idx = tonics.indexOf(tonic);
        return idx >= 0 ? idx + 12 * (octave + 1) : 60;
    }
    private static function chordIntervals(type:String, blues:Bool):Array<Int> {
        // Bluesy chords prefer cleaner shell voicings (1–3–b7) to reduce muddiness
        if (blues) {
            switch (type) {
                case "M": return [0, 4, 10]; // 1,3,b7 (dominant shell)
                case "m": return [0, 3, 10]; // 1,b3,b7 (minor 7 shell)
                case "o": return [0, 3, 6];  // dim triad
                default: return [0, 4, 10];
            }
        } else {
            switch (type) {
                case "M": return [0, 4, 7];
                case "m": return [0, 3, 7];
                case "o": return [0, 3, 6];
                default: return [0, 4, 7];
            }
        }
    }
    private static function degreeToInterval(deg:Int):Int {
        // Prefer chord tones to avoid dissonance: 0 (root), 4/3 (third), 7 (fifth)
        return switch (deg) {
            case 0: 0;     // root
            case 3: 3;     // minor third
            case 4: 4;     // major third
            case 7: 7;     // perfect fifth
            // gentle extensions
            case 9: 9;     // sixth
            case 12: 12;   // octave
            default: deg;  // direct semitone offset
        };
    }

    /**
     * Play Strudel-like stack: gated chords + lead degrees following chords.
     * chords: array of {root:String, type:String}
     */
    public function playStrudelLike(
        bpm:Int,
        chords:Array<{root:String, type:String}>,
        channelChord:Int = 0,
        channelLead:Int = 0,
        blues:Bool = false,
        walkingBass:Bool = false,
        swing:Bool = false,
        safeHarmony:Bool = true,
        chordProgram:Int = 4,   // Electric Piano 1
        leadProgram:Int = 81,   // Lead 1 (square)
        bassProgram:Int = 32    // Acoustic Bass
    ):Void {
        stopStrudelLike();
        this.strudelBpm = bpm;
        // If blues mode, derive a simple 12‑bar I–IV–V progression from first chord root
        if (blues && chords != null && chords.length > 0) {
            var keyRoot = chords[0].root;
            var idx = tonics.indexOf(keyRoot);
            if (idx < 0) idx = 0;
            // I (idx), IV (idx+5), V (idx+7)
            function tonicAt(offset:Int):String {
                return tonics[(idx + offset) % tonics.length];
            }
            var I = {root: tonicAt(0), type: "M"};
            var IV = {root: tonicAt(5), type: "M"};
            var V = {root: tonicAt(7), type: "M"};
            // 12‑bar template (each step = one beat group here): I I I I | IV IV I I | V IV I V
            this.strudelChords = [I, I, I, I, IV, IV, I, I, V, IV, I, V];
        } else {
            this.strudelChords = chords;
        }
        this.strudelChannelChord = channelChord;
        this.strudelChannelLead = channelLead;
        // Set instruments (GM)
        try { synth.setPreset(this.strudelChannelChord, 0, chordProgram); } catch (_:Dynamic) {}
        try { synth.setPreset(this.strudelChannelLead, 0, leadProgram); } catch (_:Dynamic) {}
        try { synth.setPreset(strudelChannelBass, 0, bassProgram); } catch (_:Dynamic) {}
        this.strudelChordIdx = 0;
        this.strudelStep = 0;
        this.strudelIsPlaying = true;

        var msPerBeat = Std.int(60000 / bpm);
        var swingOn = swing ? Std.int(msPerBeat * 0.6) : Std.int(msPerBeat / 2);
        var swingOff = swing ? Std.int(msPerBeat * 0.4) : Std.int(msPerBeat / 2);
        // Rhythm gate: "< x - x x>*4" => steps: play, rest, play, play (repeat 4)
        var gate = [true, false, true, true];
        var gateLen = gate.length;

        // Lead follows chord tones to stay consonant
        var leadIdx = 0;

        strudelTimer = new haxe.Timer(msPerBeat);
        strudelTimer.run = function() {
            if (!strudelIsPlaying || strudelChords == null || strudelChords.length == 0) return;
            var chord = strudelChords[strudelChordIdx % strudelChords.length];
            var rootMidi = tonicToMidi(chord.root, 4);

            // Gate chords
            var doPlayChord = gate[strudelStep % gateLen];
            if (doPlayChord) {
                var ints = chordIntervals(chord.type, blues);
                for (i in 0...ints.length) synth.noteOn(strudelChannelChord, rootMidi + ints[i], 100);
                // Turn off chord at half-beat to mimic gate
                haxe.Timer.delay(function() {
                    for (i in 0...ints.length) synth.noteOff(strudelChannelChord, rootMidi + ints[i]);
                }, swingOff);
            }

            // Lead selection
            var baseLead:Int;
            if (safeHarmony) {
                // Strictly chord tones + octave to avoid clashes
                var chordTones = chordIntervals(chord.type, blues);
                var safeSet = [chordTones[0], chordTones[1], chordTones[2], 12];
                var pick = safeSet[leadIdx % safeSet.length];
                baseLead = rootMidi + pick;
            } else if (blues) {
                var keyRoot = strudelChords[0].root;
                var keyMidi = tonicToMidi(keyRoot, 4);
                var bluesScale = [0, 3, 4, 6, 7, 10, 12];
                var pick = bluesScale[leadIdx % bluesScale.length];
                baseLead = keyMidi + pick;
            } else {
                var chordTones2 = chordIntervals(chord.type, false);
                var pick2 = chordTones2[leadIdx % chordTones2.length];
                baseLead = rootMidi + pick2;
            }
            // Choose octave nearest to anchor (C4) to keep lead centered
            // --- Drums: enhanced 8-step groove ---
            var step8 = strudelStep % 8;
            var KICK = 36; var SNARE = 38; var HHO = 42; var HHC = 46; var CRASH = 49; var TOM1 = 45;
            // Hats: off-beat closed hats on every step, with lighter velocity on odd steps
            var hhVel = (step8 % 2 == 0) ? 85 : 70;
            synth.noteOn(strudelChannelDrums, HHC, hhVel);
            haxe.Timer.delay(function() synth.noteOff(strudelChannelDrums, HHC), Std.int(msPerBeat / 2));
            // Occasional open hat on step 6 for breath
            if (step8 == 6) {
                synth.noteOn(strudelChannelDrums, HHO, 78);
                haxe.Timer.delay(function() synth.noteOff(strudelChannelDrums, HHO), Std.int(msPerBeat / 2));
            }
            // Kicks: 0, 2, 4(soft), 7(ghost)
            if (step8 == 0 || step8 == 2) {
                synth.noteOn(strudelChannelDrums, KICK, 112);
                haxe.Timer.delay(function() synth.noteOff(strudelChannelDrums, KICK), Std.int(msPerBeat / 2));
            } else if (step8 == 4) {
                synth.noteOn(strudelChannelDrums, KICK, 96);
                haxe.Timer.delay(function() synth.noteOff(strudelChannelDrums, KICK), Std.int(msPerBeat / 2));
            } else if (step8 == 7) {
                synth.noteOn(strudelChannelDrums, KICK, 88);
                haxe.Timer.delay(function() synth.noteOff(strudelChannelDrums, KICK), Std.int(msPerBeat / 2));
            }
            // Snares: 3, 7 main backbeat; 5 ghost
            if (step8 == 3 || step8 == 7) {
                synth.noteOn(strudelChannelDrums, SNARE, 108);
                haxe.Timer.delay(function() synth.noteOff(strudelChannelDrums, SNARE), Std.int(msPerBeat / 2));
            } else if (step8 == 5) {
                synth.noteOn(strudelChannelDrums, SNARE, 82);
                haxe.Timer.delay(function() synth.noteOff(strudelChannelDrums, SNARE), Std.int(msPerBeat / 2));
            }
            // Crash accent on bar start (every 8 steps)
            if (step8 == 0 && (strudelChordIdx % 2 == 0)) {
                synth.noteOn(strudelChannelDrums, CRASH, 100);
                haxe.Timer.delay(function() synth.noteOff(strudelChannelDrums, CRASH), Std.int(msPerBeat / 2));
            }
            var leadNote = baseLead;
            var diff = leadNote - strudelAnchorMidi;
            while (diff > 6) { leadNote -= 12; diff = leadNote - strudelAnchorMidi; }
            while (diff < -6) { leadNote += 12; diff = leadNote - strudelAnchorMidi; }
            synth.noteOn(strudelChannelLead, leadNote, 100);
            haxe.Timer.delay(function() synth.noteOff(strudelChannelLead, leadNote), swingOff);

            // --- Bass line ---
            var bassRoot = tonicToMidi(chord.root, 2);
            var bdiff = bassRoot - strudelBassAnchor;
            while (bdiff > 6) { bassRoot -= 12; bdiff = bassRoot - strudelBassAnchor; }
            while (bdiff < -6) { bassRoot += 12; bdiff = bassRoot - strudelBassAnchor; }
            var bassNote:Int;
            if (walkingBass) {
                // Walking pattern with chromatic approach into next chord root
                var nextChord = strudelChords[(strudelChordIdx + 1) % strudelChords.length];
                var nextRoot = tonicToMidi(nextChord.root, 2);
                // Normalize nextRoot near bass anchor
                var nbdiff = nextRoot - strudelBassAnchor;
                while (nbdiff > 6) { nextRoot -= 12; nbdiff = nextRoot - strudelBassAnchor; }
                while (nbdiff < -6) { nextRoot += 12; nbdiff = nextRoot - strudelBassAnchor; }
                switch (step8) {
                    case 0: bassNote = bassRoot;            // root
                    case 1: bassNote = bassRoot + (blues ? 3 : 2); // b3 (blues) or 2
                    case 2: bassNote = bassRoot + 7;        // fifth
                    case 3: bassNote = bassRoot + (blues ? 10 : 9); // b7 or 6
                    case 4: bassNote = bassRoot + 12;       // octave
                    case 5: bassNote = bassRoot + 11;       // chromatic down to next
                    case 6: bassNote = nextRoot - 1;        // approach below
                    case 7: bassNote = nextRoot;            // land on next root
                    default: bassNote = bassRoot;
                }
                synth.noteOn(strudelChannelBass, bassNote, 105);
                // Swing: lengthen on-beats, shorten off-beats
                var len = (step8 % 2 == 0) ? swingOn : swingOff;
                haxe.Timer.delay(function() synth.noteOff(strudelChannelBass, bassNote), len);
            } else {
                // Simple root–fifth–root–octave
                switch (step8) {
                    case 0: bassNote = bassRoot;            // root
                    case 2: bassNote = bassRoot + 7;        // fifth
                    case 4: bassNote = bassRoot;            // root
                    case 6: bassNote = bassRoot + 12;       // octave
                    default: bassNote = bassRoot;           // fill
                }
                synth.noteOn(strudelChannelBass, bassNote, 105);
                haxe.Timer.delay(function() synth.noteOff(strudelChannelBass, bassNote), msPerBeat);
            }

            // advance
            strudelStep++;
            if (strudelStep % gateLen == 0) strudelChordIdx++;
            leadIdx++;
        };
    }

    public function stopStrudelLike():Void {
        if (strudelTimer != null) strudelTimer.stop();
        strudelTimer = null;
        strudelIsPlaying = false;
        // Send all-notes-off for safety
        if (synth != null) synth.noteOffAll();
    }
}
