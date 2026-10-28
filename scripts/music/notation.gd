class_name Notation
extends RefCounted
## Parser de la notación de texto de data/songs (misma lógica que tools/render_audio.py).
##
## 'F#5' o 'F#5:1.5' (duración en beats), '@0.5' fija la duración por defecto, 'r' = silencio.

const NOTE_OFFSETS := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
const CHORD_INTERVALS := {"": [0, 4, 7], "m": [0, 3, 7]}


## 'F#5' -> 78. C4 = 60.
static func note_to_midi(note_name: String) -> int:
	var letter := note_name[0].to_upper()
	var i := 1
	var accidental := 0
	while i < note_name.length() and (note_name[i] == "#" or note_name[i] == "b"):
		accidental += 1 if note_name[i] == "#" else -1
		i += 1
	return 12 * (int(note_name.substr(i)) + 1) + NOTE_OFFSETS[letter] + accidental


## Incluye los silencios (midi = NoteEvent.REST) para que el largo de la línea sea exacto.
static func parse_line(text: String) -> Array[NoteEvent]:
	var events: Array[NoteEvent] = []
	var t := 0.0
	var default_duration := 1.0
	for token in text.split(" ", false):
		if token.begins_with("@"):
			default_duration = float(token.substr(1))
			continue
		var parts := token.split(":")
		var duration := float(parts[1]) if parts.size() > 1 else default_duration
		var midi := NoteEvent.REST if parts[0] == "r" else note_to_midi(parts[0])
		events.append(NoteEvent.new(t, duration, midi))
		t += duration
	return events


static func length_of(events: Array[NoteEvent]) -> float:
	var total := 0.0
	for e in events:
		total += e.duration
	return total


static func chord_pitch_classes(symbol: String) -> PackedInt32Array:
	var root: int = NOTE_OFFSETS[symbol[0]]
	var quality := symbol.substr(1)
	if quality.begins_with("#") or quality.begins_with("b"):
		root += 1 if quality[0] == "#" else -1
		quality = quality.substr(1)
	var result := PackedInt32Array()
	for interval in CHORD_INTERVALS[quality]:
		result.append(posmod(root + interval, 12))
	return result
