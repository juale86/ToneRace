class_name Booster
extends RefCounted
## Un booster en la pista. Al agarrarlo suenan sus notas (en beats absolutos).

enum Kind { GOLD, ADORN }

var beat: float
var lane: int
var kind: Kind
var notes: Array[NoteEvent] = []


func _init(p_beat: float, p_lane: int, p_kind: Kind) -> void:
	beat = p_beat
	lane = p_lane
	kind = p_kind
