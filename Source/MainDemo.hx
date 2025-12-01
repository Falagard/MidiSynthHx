package;

import openfl.display.Sprite;
import openfl.Lib;

/**
 * Main entry point for the MidiSynth demo application
 */
class MainDemo extends Sprite {
    public function new() {
        super();
        trace("MainDemo constructor started");
        
        try {
            // Create and add the MidiSynth example
            var example = new MidiSynthExample();
            addChild(example);
            trace("MidiSynthExample added successfully");
        } catch (e:Dynamic) {
            trace("ERROR in MainDemo constructor: " + Std.string(e));
        }
    }
    
    public static function main() {
        Lib.current.addChild(new MainDemo());
    }
}
