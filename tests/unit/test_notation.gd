extends GutTest


func test_note_to_midi() -> void:
	assert_eq(Notation.note_to_midi("C4"), 60)
	assert_eq(Notation.note_to_midi("A4"), 69)
	assert_eq(Notation.note_to_midi("F#5"), 78)
	assert_eq(Notation.note_to_midi("Bb3"), 58)
	assert_eq(Notation.note_to_midi("D2"), 38)


func test_parse_line_uses_default_and_explicit_durations() -> void:
	var events := Notation.parse_line("@0.5 D4 E4:1 r F#4")
	assert_eq(events.size(), 4)
	assert_eq(events[1].beat, 0.5)
	assert_eq(events[1].duration, 1.0)
	assert_true(events[2].is_rest())
	assert_eq(events[3].beat, 2.0)
	assert_eq(Notation.length_of(events), 2.5)


func test_chord_pitch_classes() -> void:
	assert_eq(Notation.chord_pitch_classes("D"), PackedInt32Array([2, 6, 9]))
	assert_eq(Notation.chord_pitch_classes("F#m"), PackedInt32Array([6, 9, 1]))
	assert_eq(Notation.chord_pitch_classes("Bm"), PackedInt32Array([11, 2, 6]))
