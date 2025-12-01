package;

import openfl.Lib;

class Main {
    public static function main() {
        trace("Main.main() started");
        try {
            // Launch the MidiSynth demo entry point
            Lib.current.addChild(new MainDemo());
            trace("MainDemo added successfully");
        } catch (e:Dynamic) {
            trace("ERROR in Main.main(): " + Std.string(e));
        }
    }
}



