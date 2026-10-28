class_name Song
extends RefCounted
## Una obra cargada desde data/songs/*.json.
##
## La carrera se arma como una lista de ciclos (cada ciclo dura cycle_beats y
## repite el bajo). Cada ciclo tiene una línea de melodía, o "" si no tiene.

const INTRO := ""

var title: String
var beats_per_bar: int
var cycle_beats: int
var chords: PackedStringArray
var bass: Array[NoteEvent]
var lines: Dictionary = {}  # nombre -> Array[NoteEvent]
var variations: Array[PackedStringArray] = []
var finale: PackedStringArray


static func load_json(path: String) -> Song:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var song := Song.new()
	song.title = data.title
	song.beats_per_bar = int(data.beats_per_bar)
	song.cycle_beats = int(data.cycle_beats)
	song.chords = PackedStringArray(data.chords)
	song.bass = Notation.parse_line(data.bass)
	for line_name: String in data.lines:
		song.lines[line_name] = Notation.parse_line(data.lines[line_name])
	for v in data.variations:
		song.variations.append(PackedStringArray(v))
	song.finale = PackedStringArray(data.finale)
	return song


## Intro (sin melodía) + las variaciones en el orden dado + el final.
func cycle_lines(variation_order: Array[int]) -> PackedStringArray:
	var result := PackedStringArray([INTRO])
	for index in variation_order:
		result.append_array(variations[index])
	result.append_array(finale)
	return result


## Notas de la melodía en beats absolutos, sin silencios.
func melody_events(cycles: PackedStringArray) -> Array[NoteEvent]:
	var events: Array[NoteEvent] = []
	for i in cycles.size():
		if cycles[i] == INTRO:
			continue
		for e: NoteEvent in lines[cycles[i]]:
			if not e.is_rest():
				events.append(e.shifted(i * cycle_beats))
	return events


func chord_at(beat: float) -> String:
	return chords[int(floor(fposmod(beat, cycle_beats)))]
