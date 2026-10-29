class_name HumanPilot
extends Pilot
## Piloto que lee el InputMap (teclado, gamepad y los controles táctiles, que
## mandan las mismas acciones). Los toques entre dos ticks se acumulan.
## Mantener un lado apretado sigue cambiando de carril, como el autorepeat de un teclado.

const REPEAT_DELAY_TICKS := 12
const REPEAT_EVERY_TICKS := 5

var _lane_steps := 0
var _riff := false
var _voice := false
var _held := 0
var _held_ticks := 0


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
	var held := int(Input.is_action_pressed(&"lane_right")) - int(Input.is_action_pressed(&"lane_left"))
	if held != 0 and held == _held:
		_held_ticks += 1
		var repeat := _held_ticks - REPEAT_DELAY_TICKS
		if repeat >= 0 and repeat % REPEAT_EVERY_TICKS == 0:
			_lane_steps += held
	else:
		_held = held
		_held_ticks = 0
	var input := PilotInput.new()
	input.lane_steps = _lane_steps
	input.throttle = Input.is_action_pressed(&"throttle")
	input.riff = _riff
	input.voice = _voice
	_lane_steps = 0
	_riff = false
	_voice = false
	return input
