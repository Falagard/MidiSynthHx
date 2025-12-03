package procedural;

import procedural.Track;
import procedural.MusicContext;
import procedural.NoteEvent;
import procedural.XorShift32;

/**
 * Represents a song section (verse, chorus, bridge, etc.) with multiple tracks.
 */
class Section {
    public var name:String;
    public var lengthBeats:Float;
    public var tracks:Array<Track>;

    public function new(name:String, lengthBeats:Float) {
        this.name = name;
        this.lengthBeats = lengthBeats;
        this.tracks = [];
    }

    public function addTrack(t:Track):Void {
        tracks.push(t);
    }

    public function render(ctx:MusicContext):Array<NoteEvent> {
        var events:Array<NoteEvent> = [];

        for (track in tracks) {
            var localSeed = ctx.seed + track.name.length * 7919;
            ctx.rng = new XorShift32(localSeed);

            var trackEvents:Array<NoteEvent> = [];
            track.generator.generate(ctx, trackEvents);

            for (rule in track.rules) {
                rule.apply(ctx, trackEvents);
            }

            for (e in trackEvents) {
                e.channel = track.channel;
                events.push(e);
            }
        }

        return events;
    }
}
