package procedural;

/**
 * Interface for music generators that produce note events.
 */
interface IGenerator {
    public function generate(ctx:MusicContext, out:Array<NoteEvent>):Void;
}
