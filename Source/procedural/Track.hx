package procedural;

import procedural.IGenerator;
import procedural.IRule;

/**
 * Represents a single musical track with a generator and rules.
 */
class Track {
    public var name:String;
    public var generator:IGenerator;
    public var rules:Array<IRule>;
    public var channel:Int = 0;
    
    public function new(name:String, generator:IGenerator) {
        this.name = name;
        this.generator = generator;
        this.rules = [];
    }
    
    public function addRule(r:IRule):Void {
        rules.push(r);
    }
}
