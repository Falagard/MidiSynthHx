package procedural.rules;

import procedural.IRule;
import procedural.MusicContext;
import procedural.NoteEvent;

/**
 * Quantizes notes to a chord progression.
 * Adjusts note pitches to fit the nearest chord tone in the current bar's chord.
 */
class ChordProgressionRule implements IRule {
    public var chords:Array<Array<Int>>;
    public var beatsPerBar:Int;
    
    public function new(chordNames:Array<String>, beatsPerBar:Int = 4) {
        this.beatsPerBar = beatsPerBar;
        chords = [];
        for (c in chordNames) chords.push(parseChord(c));
    }
    
    function parseChord(name:String):Array<Int> {
        var rootNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];
        var root = -1;
        for (i in 0...rootNames.length) {
            if (name.indexOf(rootNames[i]) == 0) {
                root = i;
                break;
            }
        }
        if (root == -1) root = 0; // Default to C
        var minor = name.toLowerCase().indexOf("m") != -1;
        return [root, root + (minor ? 3 : 4), root + 7];
    }
    
    public function apply(ctx:MusicContext, events:Array<NoteEvent>):Void {
        for (e in events) {
            var barIndex = Std.int(e.startBeat / beatsPerBar) % chords.length;
            var chord = chords[barIndex];
            var pitch = e.note;
            var best = pitch;
            var bestDist = 999;
            
            for (c in chord) {
                for (oct in -2...3) {
                    var target = c + 12 * (Std.int(pitch / 12) + oct);
                    var dist = Std.int(Math.abs(target - pitch));
                    if (dist < bestDist) {
                        bestDist = dist;
                        best = target;
                    }
                }
            }
            e.note = best;
        }
    }
}
