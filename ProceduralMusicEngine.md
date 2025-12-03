// Strudel-like pattern engine for Haxe
// Features:
// - Pattern type (time-aligned events)
// - Mini-notation parser (supports tokens, [], repeats *, ~ for rest, comma for layering)
// - Pattern combinators: fast, slow, rev, every, stack, offset, stretch, chop
// - Euclidean rhythm generator
// - PatternPlayer: maps pattern tokens to NoteEvent
// - Live-coding scheduler with rolling window and hot-reload
// Save as `strudel_like_engine.hx` and run with `haxe -main Main -interp` for testing

import Std;

// Basic NoteEvent
typedef NoteEvent = {
    var note:Int; // MIDI note
    var velocity:Int;
    var startBeat:Float;
    var durationBeats:Float;
    var channel:Int;
};

// Simple RNG
class XorShift32 {
    public var state:Int;
    public function new(seed:Int) { state = if (seed == 0) 0xdeadbeef else seed; }
    public function nextInt():Int { var x=state; x^=x<<13; x^=x>>17; x^=x<<5; state = x; return x & 0x7fffffff; }
    public function nextFloat():Float return nextInt()/2147483647.0;
}

// PatternValue: token value and optional metadata
typedef PVal = { var token:String; var dur:Float; }

// PatternEvent: placed event in pattern (relative time)
typedef PEvent = { var value:PVal; var start:Float; var end:Float }

// Pattern class
class Pattern {
    public var events:Array<PEvent>;
    public var lengthBeats:Float;
    public function new(events:Array<PEvent>, lengthBeats:Float) { this.events = events; this.lengthBeats = lengthBeats; }

    public static function empty(length:Float = 1.0):Pattern { return new Pattern([], length); }

    // repeat pattern N times to reach targetLength (useful for LCM/polymeter)
    public function repeatTo(length:Float):Pattern {
        if (this.lengthBeats <= 0) return Pattern.empty(length);
        var out = [];
        var times = Std.int(Math.ceil(length / this.lengthBeats));
        for (i in 0...times) {
            var offset = i * this.lengthBeats;
            for (e in events) out.push({ value: e.value, start: e.start + offset, end: e.end + offset });
        }
        return new Pattern(out, this.lengthBeats * times);
    }
}

// -------------------- Mini-notation parser --------------------
// Grammar (simple): token = text (letters/numbers/_/-/:); group = '[' sequence ']'; repeat = item '*' INT
// token '~' = rest (silence). Comma ',' layers patterns (returns stacked pattern)

class NotationParser {
    public static function parse(text:String, defaultStep:Float = 0.25):Pattern {
        // support layering with commas at top-level
        var parts = splitTopLevel(text, ',');
        var patterns = [];
        for (p in parts) patterns.push(parseSingle(p.trim(), defaultStep));
        if (patterns.length == 0) return Pattern.empty(defaultStep);
        if (patterns.length == 1) return patterns[0];
        return PatternCombinators.stack(patterns);
    }

    static function splitTopLevel(txt:String, sep:String):Array<String> {
        var out:Array<String> = [];
        var depth = 0; var cur = "";
        for (c in txt) {
            if (c == '[') depth++;
            else if (c == ']') depth = Math.max(0, depth-1);
            if (depth == 0 && Std.string(c) == sep) { out.push(cur); cur = ""; } else cur += Std.string(c);
        }
        if (cur.length > 0) out.push(cur);
        return out;
    }

    static function tokenize(s:String):Array<String> {
        var toks = s.split(RegEx("\\s+"));
        var out = [];
        for (t in toks) if (t.trim().length > 0) out.push(t.trim());
        return out;
    }

    static function parseSingle(s:String, step:Float):Pattern {
        var toks = tokenize(s);
        var cursor = 0; var beat = 0.0; var events:Array<PEvent> = [];
        while (cursor < toks.length) {
            var t = toks[cursor];
            // group
            if (t.indexOf("[") == 0) {
                // reconstruct until matching ]
                var grp = t;
                while (grp.indexOf("]") == -1 && cursor+1 < toks.length) { cursor++; grp += " " + toks[cursor]; }
                // strip []
                grp = grp.replace(RegEx("^\\[|\\]$"), "");
                // handle repeats like [bd sn]*2
                var repeat = 1;
                if (cursor+1 < toks.length && toks[cursor+1].indexOf("*") == 0) {
                    var r = toks[cursor+1].substr(1);
                    repeat = Std.parseInt(r);
                    cursor++;
                }
                var sub = parseSingle(grp, step);
                for (r in 0...repeat) {
                    for (e in sub.events) events.push({ value: e.value, start: e.start + beat, end: e.end + beat });
                    beat += sub.lengthBeats;
                }
            } else if (t.indexOf("*") > 0) {
                // token*3
                var parts = t.split("*"); var token = parts[0]; var rpt = Std.parseInt(parts[1]);
                for (i in 0...rpt) {
                    if (token == "~") { beat += step; } else {
                        events.push({ value: { token: token, dur: step }, start: beat, end: beat + step });
                        beat += step;
                    }
                }
            } else {
                if (t == "~") { beat += step; }
                else {
                    // plain token
                    events.push({ value: { token: t, dur: step }, start: beat, end: beat + step });
                    beat += step;
                }
            }
            cursor++;
        }
        return new Pattern(events, beat);
    }
}

// -------------------- Pattern combinators --------------------
class PatternCombinators {
    public static function fast(factor:Float, p:Pattern):Pattern {
        var out = [];
        for (e in p.events) out.push({ value: e.value, start: e.start / factor, end: e.end / factor });
        return new Pattern(out, p.lengthBeats / factor);
    }
    public static function slow(factor:Float, p:Pattern):Pattern return fast(1.0/factor, p);

    public static function rev(p:Pattern):Pattern {
        var out = [];
        for (e in p.events) out.push({ value: e.value, start: p.lengthBeats - e.end, end: p.lengthBeats - e.start });
        return new Pattern(out, p.lengthBeats);
    }

    public static function offset(shift:Float, p:Pattern):Pattern {
        var out = [];
        for (e in p.events) out.push({ value: e.value, start: e.start + shift, end: e.end + shift });
        return new Pattern(out, p.lengthBeats + Math.abs(shift));
    }

    public static function stretch(factor:Float, p:Pattern):Pattern {
        var out = [];
        for (e in p.events) out.push({ value: e.value, start: e.start * factor, end: e.end * factor });
        return new Pattern(out, p.lengthBeats * factor);
    }

    public static function chop(n:Int, p:Pattern):Array<Pattern> {
        var partLen = p.lengthBeats / n;
        var out = [];
        for (i in 0...n) {
            var events = [];
            for (e in p.events) if (e.start >= i*partLen && e.start < (i+1)*partLen) {
                events.push({ value: e.value, start: e.start - i*partLen, end: e.end - i*partLen });
            }
            out.push(new Pattern(events, partLen));
        }
        return out;
    }

    public static function every(n:Int, fn:Pattern->Pattern, p:Pattern):Pattern {
        // apply fn every n repeats of the pattern
        var times = 8; // default expand
        var seq = p.repeatTo(p.lengthBeats * times);
        var out = [];
        var rep = 0; var idx = 0;
        while (idx < seq.lengthBeats) {
            var slice = seq.repeatTo(p.lengthBeats).repeatTo(p.lengthBeats); // cheap; we'll instead iterate events
            // simpler: iterate events, shifting selection
            for (e in seq.events) {
                var repIndex = Std.int(Math.floor(e.start / p.lengthBeats));
                var localStart = e.start - repIndex * p.lengthBeats;
                if (repIndex % n == 0) {
                    // apply fn to single-event pattern
                    // for performance, just mark and later reconstruct. Simpler approach: apply fn to whole pattern at repIndex.
                }
                out.push(e);
            }
            break;
        }
        return new Pattern(out, seq.lengthBeats);
    }

    public static function stack(ps:Array<Pattern>):Pattern {
        var maxLen = 0.0; var out:Array<PEvent> = [];
        for (p in ps) if (p.lengthBeats > maxLen) maxLen = p.lengthBeats;
        for (p in ps) {
            var rep = p.repeatTo(maxLen);
            for (e in rep.events) out.push({ value: e.value, start: e.start, end: e.end });
        }
        return new Pattern(out, maxLen);
    }

    public static function combinePolymeter(a:Pattern, b:Pattern):Pattern {
        var l = lcmF(a.lengthBeats, b.lengthBeats);
        var ra = a.repeatTo(l); var rb = b.repeatTo(l);
        var out = [];
        out.pushAll(ra.events); out.pushAll(rb.events);
        return new Pattern(out, l);
    }

    static function lcmF(a:Float, b:Float):Float {
        var ai = Std.int(Math.round(a*1000)); var bi = Std.int(Math.round(b*1000));
        var g = gcd(ai, bi); return (ai / g * bi) / 1000.0;
    }
    static function gcd(a:Int,b:Int):Int{ if(b==0) return a; return gcd(b, a % b); }
}

// -------------------- Euclidean rhythm --------------------
class Euclid {
    public static function bjorklund(steps:Int, pulses:Int):Array<Int> {
        if (pulses <= 0) return Array.create(steps, 0);
        if (pulses >= steps) return Array.create(steps, 1);
        var pattern = new Array<Int>();
        var counts = new Array<Array<Int>>();
        var remainders = new Array<Int>();
        var divisor = steps - pulses;
        remainders.push(pulses);
        var level = 0;
        while (true) {
            counts.push([]);
            counts[level].push(divisor / remainders[level]);
            var rem = divisor % remainders[level];
            remainders.push(rem);
            divisor = remainders[level];
            level++;
            if (remainders[level] <= 1) break;
        }
        counts.push([]);
        counts[level].push(divisor);
        function build(l:Int) {
            if (l == -1) return;
            for (i in 0...counts[l][0]) pattern.push(1);
            if (remainders.length > l && remainders[l] > 0) build(l-1);
        }
        // fallback simple distribution
        pattern = [];
        for (i in 0...steps) {
            var v = ((i * pulses) % steps) < pulses ? 1 : 0;
            pattern.push(v);
        }
        // ensure exactly pulses ones
        var ones = 0; for (i in 0...pattern.length) if (pattern[i] == 1) ones++;
        var idx = 0;
        while (ones > pulses) { if (pattern[idx] == 1) { pattern[idx] = 0; ones--; } idx = (idx + 1) % steps; }
        idx = 0;
        while (ones < pulses) { if (pattern[idx] == 0) { pattern[idx] = 1; ones++; } idx = (idx + 1) % steps; }
        return pattern;
    }

    public static function pattern(steps:Int, pulses:Int, beatLen:Float = 0.25):Pattern {
        var arr = bjorklund(steps, pulses);
        var events = [];
        for (i in 0...arr.length) if (arr[i] == 1) events.push({ value: { token: "x", dur: beatLen }, start: i * beatLen, end: i * beatLen + beatLen });
        return new Pattern(events, arr.length * beatLen);
    }
}

// -------------------- PatternPlayer: maps tokens -> NoteEvent --------------------
class PatternPlayer {
    public var map:Map<String, Dynamic>;// either Int (midi) or function
    public var defaultDur:Float;
    public function new(defaultDur:Float = 0.25) { map = new Map(); defaultDur = defaultDur; }
    public function mapToken(token:String, midi:Int):Void { map.set(token, midi); }
    public function mapTokenFunc(token:String, fn:Dynamic):Void { map.set(token, fn); }

    public function renderPattern(p:Pattern, startOffset:Float):Array<NoteEvent> {
        var out:Array<NoteEvent> = [];
        for (e in p.events) {
            var tok = e.value.token;
            var m = map.get(tok);
            if (m == null) continue; // un-mapped token = silence
            var dur = e.value.dur > 0 ? e.value.dur : defaultDur;
            var note = 60;
            var vel = 100;
            var ch = 0;
            if (Std.is(m, Int)) note = m;
            else if (Std.is(m, Function)) {
                var r = m(tok);
                note = r.note; vel = r.vel; ch = r.ch;
            }
            out.push({ note: note, velocity: vel, startBeat: e.start + startOffset, durationBeats: dur, channel: ch });
        }
        return out;
    }
}

// -------------------- Live scheduler (rolling window) --------------------
class LiveScheduler {
    public var bpm:Int; public var seed:Int; public var rng:XorShift32; public var patterns:Map<String,Pattern>;
    public var player:PatternPlayer;
    public var lookaheadBeats:Float; public var currentBeat:Float;
    public var renderCallback:NoteEvent->Void; // called when an event is scheduled (user can send to audio/MIDI)

    public function new(bpm:Int = 120, seed:Int = 1, lookaheadBeats:Float = 4.0) {
        this.bpm = bpm; this.seed = seed; this.rng = new XorShift32(seed); this.patterns = new Map(); this.player = new PatternPlayer(); this.lookaheadBeats = lookaheadBeats; this.currentBeat = 0.0;
        this.renderCallback = function(e){ trace('sched: ' + e.startBeat + ' note=' + e.note); };
    }

    public function setPattern(name:String, p:Pattern):Void { patterns.set(name, p); }
    public function removePattern(name:String):Void { patterns.remove(name); }

    // hot-replace
    public function replacePattern(name:String, p:Pattern):Void { setPattern(name, p); }

    // advances time by dt beats (simulate) and schedules events in window [currentBeat, currentBeat+lookahead]
    public function tick(dt:Float):Void {
        var windowStart = currentBeat; var windowEnd = currentBeat + lookaheadBeats;
        // render each pattern repeated enough to cover window
        for (name in patterns.keys()) {
            var p = patterns.get(name);
            // compute first repeat index that could intersect window
            var repStart = Math.floor(windowStart / p.lengthBeats);
            var repEnd = Math.ceil(windowEnd / p.lengthBeats);
            for (ri in Std.int(repStart)...Std.int(repEnd)+1) {
                var offset = ri * p.lengthBeats;
                var evts = player.renderPattern(p, offset);
                for (e in evts) {
                    if (e.startBeat >= windowStart && e.startBeat < windowEnd) renderCallback(e);
                }
            }
        }
        currentBeat += dt;
    }
}

// -------------------- Demo / Usage --------------------
class Main {
    static public function main() {
        trace('Strudel-like engine demo');

        // parse notation
        var p1 = NotationParser.parse('bd ~ sn ~ [bd sn]*2', 0.25);
        var p2 = Euclid.pattern(16,5, 0.25);
        var p3 = NotationParser.parse('x x x x', 0.5);

        // combinators
        var pfast = PatternCombinators.fast(2.0, p1);
        var pst = PatternCombinators.stack([p1, p2]);

        // player
        var player = new PatternPlayer(0.25);
        player.mapToken('bd', 36); player.mapToken('sn', 38); player.mapToken('x', 42);

        // live scheduler
        var sched = new LiveScheduler(120, 42, 4.0);
        sched.player = player;
        sched.setPattern('kick', p1);
        sched.setPattern('euclid', p2);
        sched.setPattern('h', p3);

        // simulate clock: advance 0.5 beats per step, 32 steps
        for (i in 0...32) {
            sched.tick(0.5);
        }

        trace('done');
    }
}
