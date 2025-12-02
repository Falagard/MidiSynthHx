package procedural.generators;

import procedural.IGenerator;
import procedural.MusicContext;
import procedural.NoteEvent;

/**
 * Weighted Markov chain melody generator.
 * Generates melodies by following weighted transition probabilities between scale degrees.
 */
class WeightedMarkovMelodyGen implements IGenerator {
    public var order:Int;
    public var transitions:Map<String, Array<{note:Int, weight:Float}>>;
    public var baseNote:Int;
    
    public function new(order:Int = 1, baseNote:Int = 60) {
        this.order = order;
        this.baseNote = baseNote;
        transitions = new Map();
        generateDefaultTransitions();
    }
    
    function generateDefaultTransitions():Void {
        var scale = [0, 2, 4, 5, 7, 9, 11]; // Major scale intervals
        for (n in scale) {
            var weighted:Array<{note:Int, weight:Float}> = [];
            for (s in scale) {
                var w = if (s == n) 0.1 else 1.0; // Reduce repeat probability
                weighted.push({note: s, weight: w});
            }
            transitions.set(Std.string(n), weighted);
        }
    }
    
    public function generate(ctx:MusicContext, out:Array<NoteEvent>):Void {
        var beat:Float = 0;
        var rng = ctx.rng;
        var lastNotes:Array<Int> = [0]; // Start on root
        
        while (beat < ctx.lengthBeats) {
            var sliceStart = Std.int(Math.max(0, lastNotes.length - order));
            var key = lastNotes.slice(sliceStart, lastNotes.length).join(",");
            var options = transitions.get(key);
            if (options == null) options = [{note: 0, weight: 1.0}];
            
            var totalWeight:Float = 0;
            for (o in options) totalWeight += o.weight;
            
            var r:Float = rng.nextFloat() * totalWeight;
            var selected:Int = options[0].note;
            for (o in options) {
                r -= o.weight;
                if (r <= 0) {
                    selected = o.note;
                    break;
                }
            }
            
            var dur = if (rng.nextFloat() < 0.3) 1.0 else 0.5;
            var vel = rng.nextRange(80, 110);
            
            out.push({
                note: baseNote + selected,
                velocity: vel,
                startBeat: beat,
                durationBeats: dur,
                channel: 0
            });
            
            lastNotes.push(selected);
            beat += dur;
        }
    }
}
