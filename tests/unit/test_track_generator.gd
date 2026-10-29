extends GutTest

var song: Song


func before_all() -> void:
	song = Song.load_json("res://data/songs/canon.json")


func _fingerprint(track: Track) -> Array:
	var result := [track.variation_order, track.inverted]
	for b in track.boosters:
		var notes := []
		for n in b.notes:
			notes.append([n.beat, n.duration, n.midi])
		result.append([b.beat, b.lane, b.kind, notes])
	return result


func test_same_seed_same_track() -> void:
	var a := TrackGenerator.generate(song, 424242)
	var b := TrackGenerator.generate(song, 424242)
	assert_eq(_fingerprint(a), _fingerprint(b))
	assert_eq(a.geometry.frame_at(100.3), b.geometry.frame_at(100.3))


func test_different_seeds_differ() -> void:
	var a := TrackGenerator.generate(song, 1)
	var b := TrackGenerator.generate(song, 2)
	assert_ne(_fingerprint(a), _fingerprint(b))


func test_structure() -> void:
	var track := TrackGenerator.generate(song, 7)
	assert_eq(track.variation_order.size(), TrackGenerator.VARIATIONS_PER_RACE)
	assert_eq(track.cycles.size(), 1 + 2 * TrackGenerator.VARIATIONS_PER_RACE + song.finale.size())
	assert_eq(track.length_beats, float(track.cycles.size() * song.cycle_beats))
	for i in range(1, track.variation_order.size()):
		assert_ne(track.variation_order[i], track.variation_order[i - 1], "no repite variación seguida")


func test_every_melody_note_is_in_exactly_one_gold_booster() -> void:
	for seed_value in [3, 99, 123456]:
		var track := TrackGenerator.generate(song, seed_value)
		var expected := song.melody_events(track.cycles).size()
		var got := 0
		for b in track.boosters:
			if b.kind == Booster.Kind.GOLD:
				got += b.notes.size()
				for n in b.notes:
					assert_true(n.beat >= b.beat and n.beat < b.beat + TrackGenerator.GROUP_BEATS)
		assert_eq(got, expected, "seed %d" % seed_value)


func test_boosters_are_in_lanes_and_never_overlap() -> void:
	for seed_value in [3, 99, 123456]:
		var track := TrackGenerator.generate(song, seed_value)
		var slots := {}
		for b in track.boosters:
			assert_between(b.lane, 0, Track.LANES - 1)
			var slot := roundi(b.beat / TrackGenerator.GROUP_BEATS)
			assert_false(slots.has(slot), "dos boosters en la misma corchea (beat %s)" % b.beat)
			slots[slot] = true


func test_track_never_turns_back_on_itself() -> void:
	for seed_value in range(200):
		var track := TrackGenerator.generate(song, seed_value * 7919)
		var beat := 0.0
		while beat <= track.length_beats:
			var forward := -track.geometry.frame_at(beat).basis.z
			assert_true(forward.dot(Vector3.FORWARD) > 0.0, "seed %d beat %s apunta hacia atrás" % [seed_value, beat])
			beat += 2.0


func test_no_boosters_in_intro() -> void:
	var track := TrackGenerator.generate(song, 5)
	for b in track.boosters:
		assert_true(b.beat >= song.cycle_beats)


func _golds(track: Track) -> Array[Booster]:
	var result: Array[Booster] = []
	for b in track.boosters:
		if b.kind == Booster.Kind.GOLD:
			result.append(b)
	return result


func test_gold_lanes_follow_the_melody_contour() -> void:
	for seed_value in range(40):
		var track := TrackGenerator.generate(song, seed_value * 7919)
		var golds := _golds(track)
		var direction := -1 if track.inverted else 1
		for i in range(1, golds.size()):
			var interval := golds[i].notes[0].midi - golds[i - 1].notes[0].midi
			var step := (golds[i].lane - golds[i - 1].lane) * direction
			if interval == 0:
				assert_eq(step, 0, "nota repetida, mismo carril (seed %d beat %s)" % [seed_value, golds[i].beat])
			else:
				assert_true(step * interval >= 0, "la nota sube y el carril baja (seed %d beat %s)" % [seed_value, golds[i].beat])


func test_gold_jumps_always_fit_the_time() -> void:
	for seed_value in range(40):
		var golds := _golds(TrackGenerator.generate(song, seed_value * 7919))
		for i in range(1, golds.size()):
			var gap := golds[i].beat - golds[i - 1].beat
			assert_true(absi(golds[i].lane - golds[i - 1].lane) <= TrackGenerator.max_lane_steps(gap),
				"salto imposible (seed %d beat %s)" % [seed_value, golds[i].beat])


func test_gold_line_moves_when_the_note_changes() -> void:
	var golds := _golds(TrackGenerator.generate(song, 31337))
	var changes := 0
	var moves := 0
	for i in range(1, golds.size()):
		if golds[i].notes[0].midi != golds[i - 1].notes[0].midi:
			changes += 1
			if golds[i].lane != golds[i - 1].lane:
				moves += 1
	assert_gt(float(moves) / changes, 0.7, "la línea no se queda pegada a un borde")


func test_adorn_pitch_rises_with_lane_and_fits_chord() -> void:
	var previous := 0
	for lane in Track.LANES:
		var midi := TrackGenerator._adorn_pitch("G", lane, false)
		assert_gt(midi, previous)
		assert_has(Notation.chord_pitch_classes("G"), midi % 12)
		previous = midi


func test_gold_line_does_not_zigzag_for_long() -> void:
	for seed_value in range(20):
		var golds := _golds(TrackGenerator.generate(song, seed_value * 7919))
		var last_dir := 0
		var chain := 0
		for i in range(1, golds.size()):
			var dir := signi(golds[i].lane - golds[i - 1].lane)
			chain = chain + 1 if dir != 0 and dir == -last_dir else 0
			last_dir = dir
			assert_true(chain <= TrackGenerator.ZIGZAG_CAP, "zigzag largo (seed %d beat %s)" % [seed_value, golds[i].beat])
