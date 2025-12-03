package procedural;

import procedural.IGenerator;
import procedural.MusicContext;
import procedural.NoteEvent;

/** Wraps PatternEngine to conform to IGenerator. */
class PatternAdapter implements IGenerator {
    public var engine:PatternEngine;
    public var pattern:String;
    public var defaultDur:Float;
    public var channel:Int;

    public function new(pattern:String, bpm:Int = 120, channel:Int = 9, defaultDur:Float = 0.25) {
        this.pattern = pattern;
        this.defaultDur = defaultDur;
        this.channel = channel;
        this.engine = new PatternEngine(bpm, channel);
    }

    public function generate(ctx:MusicContext, out:Array<NoteEvent>):Void {
        engine.bpm = ctx.bpm;
        engine.channel = channel;
        var ev = engine.render(pattern, ctx.lengthBeats, defaultDur);
        for (e in ev) out.push(e);
    }
}
