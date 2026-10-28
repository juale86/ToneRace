extends GutTest

var song: Song


func before_all() -> void:
	song = Song.load_json("res://data/songs/canon.json")


func test_bass_and_every_line_last_exactly_one_cycle() -> void:
	assert_eq(Notation.length_of(song.bass), float(song.cycle_beats), "bajo")
	for line_name: String in song.lines:
		assert_eq(Notation.length_of(song.lines[line_name]), float(song.cycle_beats), line_name)


func test_chords_cover_one_cycle() -> void:
	assert_eq(song.chords.size(), song.cycle_beats)


## Toda nota que cae sobre un beat entero tiene que ser nota del acorde de ese beat.
func test_notes_on_the_beat_are_chord_tones() -> void:
	for line_name: String in song.lines:
		for e: NoteEvent in song.lines[line_name]:
			if e.is_rest() or not is_equal_approx(e.beat, roundf(e.beat)):
				continue
			var chord := song.chord_at(e.beat)
			assert_has(Notation.chord_pitch_classes(chord), e.midi % 12,
				"%s beat %s: nota %d sobre %s" % [line_name, e.beat, e.midi, chord])


func test_variations_and_finale_reference_existing_lines() -> void:
	for v in song.variations:
		for line_name in v:
			assert_has(song.lines, line_name)
	for line_name in song.finale:
		assert_has(song.lines, line_name)


func test_cycle_lines_has_intro_variations_and_finale() -> void:
	var order: Array[int] = [2, 0]
	var cycles := song.cycle_lines(order)
	assert_eq(cycles, PackedStringArray(["", "L5", "L6", "L1", "L2", "L5", "L6"]))


func test_melody_events_are_offset_by_cycle() -> void:
	var events := song.melody_events(PackedStringArray(["", "L1"]))
	assert_eq(events.size(), 8)
	assert_eq(events[0].beat, float(song.cycle_beats))
	assert_eq(events[0].midi, Notation.note_to_midi("F#5"))
