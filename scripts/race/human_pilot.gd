class_name HumanPilot
extends Pilot
## Piloto que lee el InputMap (teclado, gamepad y los controles táctiles, que
## mandan las mismas acciones). Los toques entre dos ticks se acumulan.

var _lane_steps := 0
var _riff := false
var _voice := false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"lane_left"):
		_lane_steps -= 1
	elif event.is_action_pressed(&"lane_right"):
		_lane_steps += 1
	elif event.is_action_pressed(&"riff"):
		_riff = true
	elif event.is_action_pressed(&"voice"):
		_voice = true


func decide(_runner: Runner, _track: Track) -> PilotInput:
	var input := PilotInput.new()
	input.lane_steps = _lane_steps
	input.throttle = Input.is_action_pressed(&"throttle")
	input.riff = _riff
	input.voice = _voice
	_lane_steps = 0
	_riff = false
	_voice = false
	return input
