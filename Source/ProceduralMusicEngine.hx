package;

import procedural.*;
import procedural.generators.*;
import procedural.rules.*;

/**
 * ProceduralMusicEngine: High-level API for creating and playing procedural music.
 * 
 * Example usage:
 *   var engine = new ProceduralMusicEngine(synth);
 *   engine.createDefaultSong();
 *   engine.play();
 *   engine.stop();
 */
class ProceduralMusicEngine {
    public var synth:MidiSynth;
    public var song:StructuredSong;
    public var scheduler:Scheduler;
    
    public function new(synth:MidiSynth) {
        this.synth = synth;
    }
    
    /**
     * Create a default song structure (verse-chorus-verse).
     */
    public function createDefaultSong(bpm:Int = 120, seed:Int = 42):Void {
        song = new StructuredSong(bpm, seed);

        var intro = new Section("intro", 16);
        var introMelody = new Track("intro", new WeightedMarkovMelodyGen(1, 77));
        introMelody.channel = 0;
        intro.addTrack(introMelody);
        
        // Create verse section (16 beats)
        var verse = new Section("verse", 16);
        var verseMelody = new Track("melody", new WeightedMarkovMelodyGen(1, 60));
        verseMelody.channel = 0;
        verse.addTrack(verseMelody);
        
        var verseBass = new Track("bass", new RhythmPatternGen("x---x---x---x---", 36, 100, 1, 0.25));
        verseBass.channel = 1;
        verse.addTrack(verseBass);

        var verseDrum = new Track("drums", new RhythmPatternGen("--x---x-", 38, 110, 9, 0.25));
        verseDrum.channel = 9;
        verse.addTrack(verseDrum);
        
        // Create chorus section (8 beats)
        var chorus = new Section("chorus", 8);
        var chorusMelody = new Track("melody", new WeightedMarkovMelodyGen(1, 67));
        chorusMelody.channel = 0;
        chorusMelody.addRule(new ChordProgressionRule(["C", "Am", "F", "G"]));
        chorus.addTrack(chorusMelody);
        
        var chorusDrum = new Track("drums", new RhythmPatternGen("x-xx--x-", 38, 110, 9, 0.25));
        chorusDrum.channel = 9;
        chorus.addTrack(chorusDrum);

        var chorusBass = new Track("chorusbass", new RhythmPatternGen("x--xx---x--xx-x-", 36, 100, 1, 0.25));
        chorusBass.channel = 1;
        chorus.addTrack(chorusBass);
        
        // Arrange song: verse -> chorus -> verse
        song.addSection(intro, 0);
        song.addSection(verse, 16);
        song.addSection(chorus, 32);
        song.addSection(verse, 40);
        
        // Create scheduler
        scheduler = new Scheduler(song, synth);
    }
    
    /**
     * Create a custom song from sections.
     */
    public function createCustomSong(bpm:Int, seed:Int, sections:Array<Section>, arrangement:Array<Float>):Void {
        song = new StructuredSong(bpm, seed);
        
        for (i in 0...sections.length) {
            song.addSection(sections[i], arrangement[i]);
        }
        
        scheduler = new Scheduler(song, synth);
    }
    
    /**
     * Start playback.
     */
    public function play():Void {
        if (scheduler == null) {
            trace("No song loaded. Call createDefaultSong() or createCustomSong() first.");
            return;
        }
        scheduler.play();
    }
    
    /**
     * Stop playback.
     */
    public function stop():Void {
        if (scheduler != null) {
            scheduler.stop();
        }
    }
    
}
