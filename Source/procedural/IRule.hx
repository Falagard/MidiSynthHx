package procedural;

/**
 * Interface for rules that transform or filter note events.
 */
interface IRule {
    public function apply(ctx:MusicContext, events:Array<NoteEvent>):Void;
}
