package procedural.rules;

import procedural.IRule;
import procedural.MusicContext;
import procedural.NoteEvent;

/**
 * Randomly removes notes based on a probability threshold.
 * Useful for creating variation and sparse textures.
 */
class ProbabilityRule implements IRule {
    public var chance:Float;
    
    public function new(chance:Float) {
        this.chance = chance;
    }
    
    public function apply(ctx:MusicContext, events:Array<NoteEvent>):Void {
        var rng = ctx.rng;
        var i = events.length - 1;
        while (i >= 0) {
            if (rng.nextFloat() < chance) {
                events.splice(i, 1);
            }
            i--;
        }
    }
}
