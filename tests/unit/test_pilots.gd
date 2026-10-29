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


func test_runner_clamps_lane() -> void:
	var runner := Runner.new(100.0, 180.0)
	runner.step(_pilot_input(-5), 1.0 / 60.0)
	assert_eq(runner.lane, 0)
	runner.step(_pilot_input(9), 1.0 / 60.0)
	assert_eq(runner.lane, Track.LANES - 1)


func test_throttle_raises_bpm_up_to_max_and_release_returns_to_cruise() -> void:
	var runner := Runner.new(100.0, 180.0)
	for i in 60 * 10:
		runner.step(_pilot_input(0, true), 1.0 / 60.0)
	assert_eq(runner.clock.bpm, 180.0)
	for i in 60 * 10:
		runner.step(_pilot_input(), 1.0 / 60.0)
	assert_eq(runner.clock.bpm, Runner.CRUISE_BPM)


func test_runner_is_deterministic_for_same_inputs() -> void:
	var a := Runner.new(100.0, 180.0)
	var b := Runner.new(100.0, 180.0)
	for i in 600:
		for runner: Runner in [a, b]:
			runner.step(_pilot_input(1 if i % 37 == 0 else 0, i % 120 < 50), 1.0 / 60.0)
	assert_eq(a.clock.beat, b.clock.beat)
	assert_eq(a.lane, b.lane)


func test_autopilot_aims_at_next_gold_booster() -> void:
	var track := _track_with_gold([[1.0, 4], [2.0, 0]])
	var adorn := Booster.new(0.5, 1, Booster.Kind.ADORN)
	track.boosters.push_front(adorn)
	var runner := Runner.new(100.0, 180.0)
	runner.reset(0.0)
	var pilot := AutoPilot.new()
	assert_eq(pilot.decide(runner, track).lane_steps, 2, "ignora adornos")
	runner.clock.beat = 1.5
	assert_eq(pilot.decide(runner, track).lane_steps, -2)
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
