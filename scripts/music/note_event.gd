class_name NoteEvent
extends RefCounted
## Una nota (o silencio) ubicada en el tiempo musical.

const REST := -1

var beat: float
var duration: float
var midi: int


func _init(p_beat: float, p_duration: float, p_midi: int) -> void:
	beat = p_beat
	duration = p_duration
	midi = p_midi


func is_rest() -> bool:
	return midi == REST


func shifted(by_beats: float) -> NoteEvent:
	return NoteEvent.new(beat + by_beats, duration, midi)
