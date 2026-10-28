extends GutTest


func _events(beats: Array) -> Array[NoteEvent]:
	var events: Array[NoteEvent] = []
	for b: float in beats:
		events.append(NoteEvent.new(b, 0.5, 60))
	return events


func test_sequencer_returns_events_in_half_open_range() -> void:
	var seq := Sequencer.new(_events([0.0, 1.0, 1.5, 3.0]))
	assert_eq(seq.collect(-1.0, 0.0).size(), 1, "incluye el borde superior")
	assert_eq(seq.collect(0.0, 1.5).size(), 2)
	assert_eq(seq.collect(1.5, 2.9).size(), 0)
	assert_eq(seq.collect(2.9, 10.0).size(), 1)
	assert_true(seq.is_finished())


func test_sequencer_sorts_events() -> void:
	var seq := Sequencer.new(_events([2.0, 0.0, 1.0]))
	var got := seq.collect(-1.0, 1.5)
	assert_eq(got.size(), 2)
	assert_eq(got[0].beat, 0.0)


func test_clock_is_deterministic_for_same_ticks() -> void:
	var a := MusicClock.new()
	var b := MusicClock.new()
	for i in 600:
		for clock in [a, b]:
			clock.bpm = 80.0 + (i % 60)
			clock.advance(1.0 / 60.0)
	assert_eq(a.beat, b.beat)


func test_clock_advances_bpm_over_60_beats_per_second() -> void:
	var clock := MusicClock.new()
	clock.bpm = 120.0
	for i in 60:
		clock.advance(1.0 / 60.0)
	assert_almost_eq(clock.beat, 2.0, 1e-9)


func test_pick_gear_picks_nearest_on_start() -> void:
	var gears := PackedFloat64Array([80.0, 100.0, 120.0])
	assert_eq(BasePlayer.pick_gear(gears, -1, 85.0), 0)
	assert_eq(BasePlayer.pick_gear(gears, -1, 117.0), 2)


func test_pick_gear_keeps_current_near_the_border() -> void:
	var gears := PackedFloat64Array([80.0, 100.0, 120.0])
	var border := sqrt(80.0 * 100.0)  # punto medio en escala logarítmica
	assert_eq(BasePlayer.pick_gear(gears, 0, border + 0.1), 0, "histéresis")
	assert_eq(BasePlayer.pick_gear(gears, 0, border + 2.0), 1)
