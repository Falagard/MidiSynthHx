package procedural;

/**
 * Fast deterministic pseudo-random number generator using XorShift32 algorithm.
 * Provides consistent results across platforms for reproducible music generation.
 */
class XorShift32 {
    public var state:Int;
    
    public function new(seed:Int) {
        state = if (seed == 0) 0xdeadbeef else seed;
    }
    
    public function nextInt():Int {
        var x = state;
        x ^= x << 13;
        x ^= x >> 17;
        x ^= x << 5;
        state = x;
        return x & 0x7fffffff;
    }
    
    public function nextFloat():Float {
        return (nextInt() / 2147483647.0);
    }
    
    public function nextRange(min:Int, max:Int):Int {
        return min + Std.int(nextFloat() * (max - min + 1));
    }
}
