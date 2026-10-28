class_name Sequencer
extends RefCounted
## Recorre una lista de eventos y devuelve los que el reloj acaba de cruzar.

var _events: Array[NoteEvent]
var _next := 0


func _init(events: Array[NoteEvent]) -> void:
	_events = events.duplicate()
	_events.sort_custom(func(a: NoteEvent, b: NoteEvent) -> bool: return a.beat < b.beat)


## Eventos con from_beat < beat <= to_beat. Se llama con rangos crecientes.
func collect(from_beat: float, to_beat: float) -> Array[NoteEvent]:
	var result: Array[NoteEvent] = []
	while _next < _events.size() and _events[_next].beat <= to_beat:
		if _events[_next].beat > from_beat:
			result.append(_events[_next])
		_next += 1
	return result


func reset() -> void:
	_next = 0


func is_finished() -> bool:
	return _next >= _events.size()
