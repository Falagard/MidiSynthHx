// Complete procedural music engine with Rhythm Patterns, Rules, Weighted Markov Melody Generator, and Song Sections

import Std;

typedef NoteEvent = {
    var note:Int;
    var velocity:Int;
    var startBeat:Float;
    var durationBeats:Float;
    var channel:Int;
};

class XorShift32 {
    public var state:Int;
    public function new(seed:Int) { state = if (seed == 0) 0xdeadbeef else seed; }
    public function nextInt():Int { var x=state; x^=x<<13; x^=x>>17; x^=x<<5; state=x; return x & 0x7fffffff; }
    public function nextFloat():Float { return (nextInt()/2147483647.0); }
    public function nextRange(min:Int,max:Int):Int { return min+Std.int(nextFloat()*(max-min+1)); }
}

class MusicContext { public var bpm:Int; public var seed:Int; public var rng:XorShift32; public var lengthBeats:Float;
    public function new(bpm:Int, seed:Int, lengthBeats:Float){this.bpm=bpm; this.seed=seed; this.lengthBeats=lengthBeats; this.rng=new XorShift32(seed);}
}

interface IGenerator { public function generate(ctx:MusicContext,out:Array<NoteEvent>):Void; }
interface IRule { public function apply(ctx:MusicContext,events:Array<NoteEvent>):Void; }

// --- Rhythm Pattern Generator ---
class RhythmPatternGen implements IGenerator {
    public var pattern:String; public var note:Int; public var vel:Int; public var channel:Int; public var beatLength:Float;
    public function new(pattern:String, note:Int = 60, vel:Int = 100, channel:Int = 0, beatLength:Float = 0.25) {
        this.pattern = pattern; this.note = note; this.vel = vel; this.channel = channel; this.beatLength = beatLength;
    }
    public function generate(ctx:MusicContext, out:Array<NoteEvent>):Void {
        var beat:Float = 0;
        while (beat < ctx.lengthBeats) {
            for (c in pattern) {
                if (c == 'x' || c == 'X') out.push({ note: note, velocity: vel, startBeat: beat, durationBeats: beatLength, channel: channel });
                beat += beatLength;
                if (beat >= ctx.lengthBeats) break;
            }
        }
    }
}

// --- Weighted Markov Chain Melody Generator ---
class WeightedMarkovMelodyGen implements IGenerator {
    public var order:Int; public var transitions:Map<String,Array<{note:Int,weight:Float}>>; public var baseNote:Int;
    public function new(order:Int=1, baseNote:Int=60){
        this.order=order; this.baseNote=baseNote;
        transitions=new Map();
        generateDefaultTransitions();
    }
    function generateDefaultTransitions():Void {
        var scale = [0,2,4,5,7,9,11];
        for (n in scale){
            var weighted:Array<{note:Int,weight:Float}> = [];
            for (s in scale){
                var w = if (s==n) 0.1 else 1.0;
                weighted.push({note:s, weight:w});
            }
            transitions.set(Std.string(n), weighted);
        }
    }
    public function generate(ctx:MusicContext, out:Array<NoteEvent>):Void {
        var beat:Float=0; var rng=ctx.rng; var lastNotes:Array<Int>=[baseNote];
        while(beat<ctx.lengthBeats){
            var key = Std.string(lastNotes.slice(Math.max(0,lastNotes.length-order),lastNotes.length).join(","));
            var options = transitions.get(key);
            if (options==null) options=[{note:baseNote,weight:1.0}];
            var totalWeight:Float=0; for(o in options) totalWeight+=o.weight;
            var r:Float = rng.nextFloat()*totalWeight; var selected:Int = options[0].note;
            for(o in options){ r -= o.weight; if(r<=0){ selected=o.note; break; } }
            var dur = if(rng.nextFloat()<0.3) 1.0 else 0.5;
            var vel = rng.nextRange(80,110);
            out.push({note:60+selected, velocity:vel, startBeat:beat, durationBeats:dur, channel:0});
            lastNotes.push(selected);
            beat+=dur;
        }
    }
}

// --- Rules ---
class ChordProgressionRule implements IRule {
    public var chords:Array<Array<Int>>; public var beatsPerBar:Int;
    public function new(chordNames:Array<String>, beatsPerBar:Int = 4) {
        this.beatsPerBar = beatsPerBar; chords = []; for (c in chordNames) chords.push(parseChord(c));
    }
    function parseChord(name:String):Array<Int> {
        var rootNames = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"];
        var root = -1; for (i in 0...rootNames.length) if (name.indexOf(rootNames[i]) == 0) root = i;
        var minor = name.toLowerCase().indexOf("m") != -1;
        return [root, root + (minor?3:4), root + 7];
    }
    public function apply(ctx:MusicContext, events:Array<NoteEvent>):Void {
        for (e in events){
            var barIndex = Std.int(e.startBeat / beatsPerBar) % chords.length;
            var chord = chords[barIndex]; var pitch = e.note; var best = pitch; var bestDist = 999;
            for (c in chord) for (oct in -2...3){ var target = c+12*(Std.int(pitch/12)+oct); var dist=Std.int(Math.abs(target-pitch)); if(dist<bestDist){bestDist=dist;best=target;} }
            e.note = best;
        }
    }
}

class ArpeggiateRule implements IRule { public var stepBeat:Float; public function new(stepBeat:Float=0.25){this.stepBeat=stepBeat;}
    public function apply(ctx:MusicContext, events:Array<NoteEvent>):Void{
        var groups = new Map<Float, Array<NoteEvent>>(); for (e in events){ var k=Math.round(e.startBeat*1000)/1000; if(!groups.exists(k))groups.set(k,[]); groups.get(k).push(e); }
        for(k in groups.keys()){ var g=groups.get(k); g.sort(function(a,b) return a.note-b.note); var i=0; for(e in g){ e.startBeat+=i*stepBeat;i++; } }
        events.sort(function(a,b) return a.startBeat<b.startBeat?-1:1);
    }
}

class ProbabilityRule implements IRule { public var chance:Float; public function new(chance:Float){this.chance=chance;}
    public function apply(ctx:MusicContext, events:Array<NoteEvent>):Void{ var rng=ctx.rng; var i=events.length-1; while(i>=0){ if(rng.nextFloat()<chance) events.splice(i,1); i--; } }
}

// --- Track ---
class Track { public var name:String; public var generator:IGenerator; public var rules:Array<IRule>; public var channel:Int=0;
    public function new(name:String, generator:IGenerator){ this.name=name; this.generator=generator; this.rules=[]; }
    public function addRule(r:IRule):Void{ rules.push(r); }
}

// --- Section (Verse/Chorus/Bridge) ---
class Section {
    public var name:String;
    public var lengthBeats:Float;
    public var tracks:Array<Track>;
    public function new(name:String, lengthBeats:Float){ this.name=name; this.lengthBeats=lengthBeats; this.tracks=[]; }
    public function addTrack(t:Track):Void{ tracks.push(t); }
    public function render(ctx:MusicContext):Array<NoteEvent>{
        var events:Array<NoteEvent>=[];
        for(track in tracks){
            var localSeed = ctx.seed + Std.string(track.name).length*7919;
            ctx.rng = new XorShift32(localSeed);
            var trackEvents:Array<NoteEvent>=[];
            track.generator.generate(ctx,trackEvents);
            for(rule in track.rules) rule.apply(ctx,trackEvents);
            for(e in trackEvents) events.push(e);
        }
        return events;
    }
}

// --- Structured Song ---
class StructuredSong {
    public var bpm:Int;
    public var seed:Int;
    public var sections:Array<{section:Section, startBeat:Float}>;
    public function new(bpm:Int, seed:Int){ this.bpm=bpm; this.seed=seed; this.sections=[]; }
    public function addSection(section:Section, startBeat:Float):Void{ sections.push({section:section, startBeat:startBeat}); }
    public function render():Array<NoteEvent>{
        var all:Array<NoteEvent>=[];
        for(s in sections){
            var ctx = new MusicContext(bpm, seed, s.section.lengthBeats);
            var secEvents = s.section.render(ctx);
            for(e in secEvents) e.startBeat += s.startBeat;
            all.pushAll(secEvents);
        }
        all.sort(function(a,b) return a.startBeat<b.startBeat?-1:1);
        return all;
    }
}

// --- Scheduler ---
class Scheduler { public var song:StructuredSong; public function new(song:StructuredSong){this.song=song;}
    public function play():Void{
        var events = song.render();
        trace('--- Playing BPM:'+song.bpm);
        for(e in events) trace('['+e.startBeat+' beats] ch'+e.channel+' note='+e.note+' vel='+e.velocity+' dur='+e.durationBeats);
    }
}

// --- Main ---
class Main {
    static public function main(){
        var verse = new Section("verse",16);
        verse.addTrack(new Track("melody", new WeightedMarkovMelodyGen(1,64)));

        var chorus = new Section("chorus",8);
        chorus.addTrack(new Track("melody", new WeightedMarkovMelodyGen(1,67)));

        var song = new StructuredSong(120,42);
        song.addSection(verse,0);
        song.addSection(chorus,16);
        song.addSection(verse,24); // repeat verse

        var sched = new Scheduler(song);
        sched.play();
    }
}