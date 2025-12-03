package procedural;

import procedural.MusicContext;
import procedural.NoteEvent;
import procedural.Scheduler;
import procedural.Section;
import procedural.StructuredSong;
import procedural.Track;
import procedural.IGenerator;
import procedural.IRule;

/**
 * Core procedural music engine for generating and scheduling music.
 */
class ProceduralMusicEngine {
    public var song:StructuredSong;
    public var synth:MidiSynth;
    public var scheduler:Scheduler;

    public function new(song:StructuredSong, synth:MidiSynth) {
        this.song = song;
        this.synth = synth;
        this.scheduler = new Scheduler(song, synth);
    }

    /**
     * Generate all note events for the song (calls song.render()).
     */
    public function generateAllEvents():Array<NoteEvent> {
        return song.render();
    }

    /**
     * Play the song using the scheduler and MidiSynth.
     */
    public function play():Void {
        scheduler.play();
    }

    /**
     * Stop playback of the procedural music.
     */
    public function stop():Void {
        scheduler.stop();
    }
}
