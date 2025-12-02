package procedural;

/**
 * Represents a single musical note event with timing, velocity, and duration.
 */
typedef NoteEvent = {
    var note:Int;
    var velocity:Int;
    var startBeat:Float;
    var durationBeats:Float;
    var channel:Int;
};
