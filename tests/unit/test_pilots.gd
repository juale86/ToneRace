extends GutTest


func _pilot_input(lane_steps := 0, throttle := false) -> PilotInput:
	var input := PilotInput.new()
	input.lane_steps = lane_steps
	input.throttle = throttle
	return input


func _action(action: StringName, pressed := true) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	return event


func _track_with_gold(beats_and_lanes: Array) -> Track:
	var track := Track.new()
	for pair: Array in beats_and_lanes:
		track.boosters.append(Booster.new(pair[0], pair[1], Booster.Kind.GOLD))
	return track


## 14 marchas de 100 a 180 BPM, como el género rock.
func _gears() -> PackedFloat64Array:
	var gears := PackedFloat64Array()
	for i in 14:
		gears.append(100.0 * pow(1.8, i / 13.0))
	return gears


func _runner() -> Runner:
	return Runner.new(_gears())


## Avanza hasta pasar el beat dado, sin tocar los controles.
func _drive_to(runner: Runner, track: Track, beat: float) -> Array[Runner.Crossing]:
	var all: Array[Runner.Crossing] = []
	while runner.clock.beat < beat:
		all.append_array(runner.step(_pilot_input(), 1.0 / 60.0, track))
	return all


func test_runner_clamps_lane() -> void:
	var runner := _runner()
	runner.step(_pilot_input(-5), 1.0 / 60.0)
	assert_eq(runner.lane, 0)
	runner.step(_pilot_input(9), 1.0 / 60.0)
	assert_eq(runner.lane, Track.LANES - 1)


func test_throttle_without_turbo_does_nothing() -> void:
	var runner := _runner()
	for i in 60 * 2:
		runner.step(_pilot_input(0, true), 1.0 / 60.0)
	assert_eq(runner.clock.bpm, Runner.START_BPM)


func test_throttle_spends_turbo_and_keeps_the_speed_gained() -> void:
	var runner := _runner()
	runner.turbo = 1.0
	for i in 60:
		runner.step(_pilot_input(0, true), 1.0 / 60.0)
	assert_almost_eq(runner.turbo, 1.0 - Runner.TURBO_DRAIN_PER_SEC, 0.01)
	assert_almost_eq(runner.clock.bpm, Runner.START_BPM + Runner.THROTTLE_BPM_PER_SEC, 0.01)
	var gained := runner.clock.bpm
	for i in 60 * 5:
		runner.step(_pilot_input(), 1.0 / 60.0)
	assert_eq(runner.clock.bpm, gained, "al soltar se queda en la crucero ganada")
	for i in 60 * 10:
		runner.turbo = 1.0
		runner.step(_pilot_input(0, true), 1.0 / 60.0)
	assert_eq(runner.clock.bpm, runner.max_bpm, "tope en la marcha más alta")


func test_gold_hits_charge_turbo_more_with_combo() -> void:
	var runner := _runner()
	var track := _track_with_gold([[1.0, 2], [2.0, 2]])
	var crossings := _drive_to(runner, track, 1.0)
	assert_eq(crossings.size(), 1)
	assert_eq(crossings[0].result, Runner.Result.GOLD_HIT)
	var first := runner.turbo
	assert_almost_eq(first, Runner.GOLD_CHARGE, 0.0001)
	_drive_to(runner, track, 2.0)
	assert_gt(runner.turbo - first, first, "la segunda, con combo, carga más")
	assert_eq(runner.combo, 2)


func test_adorns_charge_a_little_and_dont_touch_combo() -> void:
	var runner := _runner()
	var track := Track.new()
	track.boosters.append(Booster.new(1.0, 2, Booster.Kind.ADORN))
	track.boosters.append(Booster.new(2.0, 0, Booster.Kind.ADORN))
	var crossings := _drive_to(runner, track, 2.0)
	assert_eq(crossings[0].result, Runner.Result.ADORN_HIT)
	assert_eq(crossings[1].result, Runner.Result.ADORN_MISS)
	assert_almost_eq(runner.turbo, Runner.ADORN_CHARGE, 0.0001)
	assert_eq(runner.combo, 0)
	assert_eq(runner.cruise_bpm, Runner.START_BPM, "fallar un adorno no frena")


func test_missing_golds_slows_down_and_drops_a_gear() -> void:
	var runner := _runner()
	var track := _track_with_gold([[1.0, 2], [2.0, 0], [3.0, 0], [4.0, 0]])
	_drive_to(runner, track, 1.0)
	var crossings := _drive_to(runner, track, 2.0)
	assert_eq(crossings[0].result, Runner.Result.GOLD_MISS)
	assert_eq(crossings[0].combo_before, 1)
	assert_eq(runner.combo, 0)
	assert_eq(runner.cruise_bpm, Runner.START_BPM - Runner.MISS_BPM)
	_drive_to(runner, track, 3.0)
	crossings = _drive_to(runner, track, 4.0)
	assert_true(crossings[0].gear_dropped, "la tercera seguida baja de marcha")
	var gears := _gears()
	assert_lt(runner.cruise_bpm, Runner.START_BPM - Runner.MISS_BPM * 3)
	assert_true(runner.cruise_bpm in gears, "cae justo en una marcha")
	assert_lt(runner.clock.bpm, Runner.START_BPM, "y el tempo va bajando")


func test_cruise_never_goes_below_lowest_gear() -> void:
	var runner := _runner()
	var pairs := []
	for i in 60:
		pairs.append([1.0 + i, 0])
	var track := _track_with_gold(pairs)
	_drive_to(runner, track, 61.0)
	assert_eq(runner.cruise_bpm, runner.min_bpm)
	assert_eq(runner.gear(), 0)


func test_runner_is_deterministic_for_same_inputs() -> void:
	var a := _runner()
	var b := _runner()
	var pairs := []
	for i in 40:
		pairs.append([0.5 + i * 0.75, (i * 3) % Track.LANES])
	var track := _track_with_gold(pairs)
	for i in 600:
		for runner: Runner in [a, b]:
			runner.step(_pilot_input(1 if i % 37 == 0 else -1 if i % 53 == 0 else 0, i % 120 < 50), 1.0 / 60.0, track)
	assert_eq(a.clock.beat, b.clock.beat)
	assert_eq(a.lane, b.lane)
	assert_eq(a.turbo, b.turbo)
	assert_eq(a.cruise_bpm, b.cruise_bpm)


func test_autopilot_aims_at_next_gold_booster() -> void:
	var track := _track_with_gold([[1.0, 4], [2.0, 0]])
	var adorn := Booster.new(0.5, 1, Booster.Kind.ADORN)
	track.boosters.push_front(adorn)
	var runner := _runner()
	var pilot := AutoPilot.new()
	assert_eq(pilot.decide(runner, track).lane_steps, 2, "ignora adornos")
	runner.clock.beat = 1.5
	assert_eq(pilot.decide(runner, track).lane_steps, -2)
	assert_false(pilot.decide(runner, track).throttle, "sin turbo no acelera")
	runner.turbo = 1.0
	assert_true(pilot.decide(runner, track).throttle)
	pilot.free()


func test_human_pilot_counts_taps_between_ticks() -> void:
	var pilot := HumanPilot.new()
	pilot._unhandled_input(_action(&"lane_right"))
	pilot._unhandled_input(_action(&"lane_right"))
	pilot._unhandled_input(_action(&"lane_right", false))
	pilot._unhandled_input(_action(&"lane_left"))
	pilot._unhandled_input(_action(&"riff"))
	var input := pilot.decide(null, null)
	assert_eq(input.lane_steps, 1)
	assert_true(input.riff)
	assert_false(input.voice)
	var next := pilot.decide(null, null)
	assert_eq(next.lane_steps, 0, "los toques se consumen")
	assert_false(next.riff)
	pilot.free()


func test_touch_zones() -> void:
	var area := Vector2(1280, 720)
	assert_eq(TouchControls.action_at(Vector2(100, 100), area), &"lane_left")
	assert_eq(TouchControls.action_at(Vector2(1200, 400), area), &"lane_right")
	assert_eq(TouchControls.action_at(Vector2(100, 650), area), &"riff")
	assert_eq(TouchControls.action_at(Vector2(300, 650), area), &"voice")
	assert_eq(TouchControls.action_at(Vector2(640, 650), area), &"", "zona muerta en el centro de la franja")
	assert_eq(TouchControls.action_at(Vector2(1100, 650), area), &"throttle")


func test_holding_a_side_keeps_changing_lanes() -> void:
	var pilot := HumanPilot.new()
	Input.action_press(&"lane_right")
	var steps := 0
	for tick in HumanPilot.REPEAT_DELAY_TICKS:
		steps += pilot.decide(null, null).lane_steps
	assert_eq(steps, 0, "no repite antes de la demora")
	for tick in HumanPilot.REPEAT_EVERY_TICKS * 3:
		steps += pilot.decide(null, null).lane_steps
	assert_eq(steps, 3)
	Input.action_release(&"lane_right")
	assert_eq(pilot.decide(null, null).lane_steps, 0)
	pilot.free()


func test_touch_on_a_blocker_does_nothing() -> void:
	var touch := TouchControls.new()
	touch.size = Vector2(1000, 600)
	var blocker := Control.new()
	touch.add_child(blocker)
	add_child_autofree(touch)
	blocker.position = Vector2(800, 0)
	blocker.size = Vector2(200, 60)
	touch.blockers.append(blocker)
	assert_true(touch._blocked(Vector2(900, 30)))
	assert_false(touch._blocked(Vector2(900, 100)))
