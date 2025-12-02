package procedural.rules;

import procedural.IRule;
import procedural.MusicContext;
import procedural.NoteEvent;

/**
 * Arpeggiates simultaneous notes by spreading them across time.
 * Sorts notes by pitch and staggers their start times.
 */
class ArpeggiateRule implements IRule {
    public var stepBeat:Float;
    
    public function new(stepBeat:Float = 0.25) {
        this.stepBeat = stepBeat;
    }
    
    public function apply(ctx:MusicContext, events:Array<NoteEvent>):Void {
        var groups = new Map<String, Array<NoteEvent>>();
        
        for (e in events) {
            var k = Std.string(Math.round(e.startBeat * 1000) / 1000);
            if (!groups.exists(k)) groups.set(k, []);
            groups.get(k).push(e);
        }
        
        for (k in groups.keys()) {
            var g = groups.get(k);
            g.sort(function(a, b) return a.note - b.note);
            var i = 0;
            for (e in g) {
                e.startBeat += i * stepBeat;
                i++;
            }
        }
        
        events.sort(function(a, b) return a.startBeat < b.startBeat ? -1 : 1);
    }
}
