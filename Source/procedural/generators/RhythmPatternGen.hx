package procedural.generators;

import procedural.IGenerator;
import procedural.MusicContext;
import procedural.NoteEvent;

/**
 * Rhythm pattern generator using string notation (x = hit, - = rest).
 * Example: "x-x-x---" creates a basic 8-step rhythm pattern.
 */
class RhythmPatternGen implements IGenerator {
    public var pattern:String;
    public var note:Int;
    public var vel:Int;
    public var channel:Int;
    public var beatLength:Float;
    
    public function new(pattern:String, note:Int = 60, vel:Int = 100, channel:Int = 0, beatLength:Float = 0.25) {
        this.pattern = pattern;
        this.note = note;
        this.vel = vel;
        this.channel = channel;
        this.beatLength = beatLength;
    }
    
    public function generate(ctx:MusicContext, out:Array<NoteEvent>):Void {
        var beat:Float = 0;
        while (beat < ctx.lengthBeats) {
            for (i in 0...pattern.length) {
                var c = pattern.charAt(i);
                if (c == 'x' || c == 'X') {
                    out.push({
                        note: note,
                        velocity: vel,
                        startBeat: beat,
                        durationBeats: beatLength,
                        channel: channel
                    });
                }
                beat += beatLength;
                if (beat >= ctx.lengthBeats) break;
            }
        }
    }
}
