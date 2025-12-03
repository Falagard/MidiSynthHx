package procedural;

/**
 * Minimal Strudel/Tidal-style pattern engine.
 * Supports space-separated steps, ~ for rest, [] for grouping, and speed multiplier with *n.
 * Maps symbolic tokens to MIDI notes per channel.
 */
class PatternEngine {
    public var bpm:Int;
    public var channel:Int;
    public var tokenToNote:Map<String, Int>;

    public function new(bpm:Int = 120, channel:Int = 0) {
        this.bpm = bpm;
        this.channel = channel;
        tokenToNote = new Map();
        // Basic drum map (GM kit): bd=kick, sn=snare, hh=closed hat
        tokenToNote.set("bd", 36);
        tokenToNote.set("sn", 38);
        tokenToNote.set("hh", 42);
        // Simple melody aliases
        tokenToNote.set("c4", 60);
        tokenToNote.set("d4", 62);
        tokenToNote.set("e4", 64);
        tokenToNote.set("g4", 67);
        tokenToNote.set("a4", 69);
    }

    /** Convert beats to seconds. */
    inline function beatToSeconds(beats:Float):Float {
        return (60.0 / bpm) * beats;
    }

    /** Parse a simple pattern string into NoteEvents over given lengthBeats. */
    public function render(pattern:String, lengthBeats:Float, defaultDur:Float = 0.25):Array<NoteEvent> {
        var events:Array<NoteEvent> = [];
        var tokens = tokenize(pattern);
        var stepDur:Float = defaultDur;
        var beat:Float = 0.0;

        while (beat < lengthBeats) {
            for (t in tokens) {
                if (t == "~") {
                    beat += stepDur; if (beat >= lengthBeats) break;
                    continue;
                }
                if (StringTools.startsWith(t, "*")) {
                    var mul = Std.parseFloat(t.substr(1));
                    if (!Math.isNaN(mul) && mul > 0) stepDur = defaultDur / mul;
                    continue;
                }
                var note = tokenToNote.get(t);
                if (note != null) {
                    events.push({
                        note: note,
                        velocity: 110,
                        startBeat: beat,
                        durationBeats: stepDur,
                        channel: channel
                    });
                }
                beat += stepDur;
                if (beat >= lengthBeats) break;
            }
        }
        return events;
    }

    /** Tokenize: split by spaces and flatten simple groups like [bd sn]. */
    function tokenize(p:String):Array<String> {
        var out:Array<String> = [];
        var i = 0; var n = p.length;
        while (i < n) {
            var c = p.charAt(i);
            if (c == ' ') { i++; continue; }
            if (c == '[') {
                var j = i + 1; var group = "";
                while (j < n && p.charAt(j) != ']') { group += p.charAt(j); j++; }
                var parts = group.split(" ");
                for (part in parts) if (part.length > 0) out.push(part);
                i = j + 1; continue;
            }
            // read token until space or bracket
            var tok = "";
            while (i < n) {
                var ch = p.charAt(i);
                if (ch == ' ' || ch == '[' || ch == ']') break;
                tok += ch; i++;
            }
            if (tok.length > 0) out.push(tok);
        }
        return out;
    }
}
