package procedural;

import procedural.Section;
import procedural.MusicContext;
import procedural.NoteEvent;

/**
 * Structured song with multiple sections arranged in sequence.
 */
class StructuredSong {
    public var bpm:Int;
    public var seed:Int;
    public var sections:Array<{section:Section, startBeat:Float}>;
    
    public function new(bpm:Int, seed:Int) {
        this.bpm = bpm;
        this.seed = seed;
        this.sections = [];
    }
    
    public function addSection(section:Section, startBeat:Float):Void {
        sections.push({section: section, startBeat: startBeat});
    }
    
    public function render():Array<NoteEvent> {
        var all:Array<NoteEvent> = [];
        
        for (s in sections) {
            var ctx = new MusicContext(bpm, seed, s.section.lengthBeats);
            var secEvents = s.section.render(ctx);
            
            for (e in secEvents) {
                e.startBeat += s.startBeat;
            }
            
            for (e in secEvents) {
                all.push(e);
            }
        }
        
        all.sort(function(a, b) return a.startBeat < b.startBeat ? -1 : 1);
        return all;
    }
}
