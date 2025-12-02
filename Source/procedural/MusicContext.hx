package procedural;

/**
 * Context for music generation containing tempo, seed, and RNG state.
 */
class MusicContext {
    public var bpm:Int;
    public var seed:Int;
    public var rng:XorShift32;
    public var lengthBeats:Float;
    
    public function new(bpm:Int, seed:Int, lengthBeats:Float) {
        this.bpm = bpm;
        this.seed = seed;
        this.lengthBeats = lengthBeats;
        this.rng = new XorShift32(seed);
    }
}
