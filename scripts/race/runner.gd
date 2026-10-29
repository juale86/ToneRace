class_name Runner
extends RefCounted
## Estado de un corredor en la simulación: posición en beats (su reloj), carril y tempo.
##
## Provisorio hasta el paso 5: el acelerador sube el tempo y al soltarlo vuelve al crucero.

const CRUISE_BPM := 120.0
const THROTTLE_BPM_PER_SEC := 25.0
const RELEASE_BPM_PER_SEC := 12.0

var clock := MusicClock.new()
var lane := 2
var min_bpm: float
var max_bpm: float


func _init(p_min_bpm: float, p_max_bpm: float) -> void:
	min_bpm = p_min_bpm
	max_bpm = p_max_bpm
	clock.bpm = CRUISE_BPM


func reset(start_beat: float) -> void:
	clock.beat = start_beat
	clock.bpm = CRUISE_BPM
	lane = 2


func step(input: PilotInput, delta: float) -> void:
	lane = clampi(lane + input.lane_steps, 0, Track.LANES - 1)
	if input.throttle:
		clock.bpm = minf(clock.bpm + THROTTLE_BPM_PER_SEC * delta, max_bpm)
	else:
		clock.bpm = move_toward(clock.bpm, clampf(CRUISE_BPM, min_bpm, max_bpm), RELEASE_BPM_PER_SEC * delta)
	clock.advance(delta)
