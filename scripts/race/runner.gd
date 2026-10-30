class_name Runner
extends RefCounted
## Estado de un corredor en la simulación: posición en beats (su reloj), carril,
## tempo, turbo y combo. Las reglas de velocidad viven acá para que el humano y los
## bots corran exactamente con las mismas.
##
## Loop de velocidad:
## - Agarrar doradas carga turbo (más con combo largo); los adornos cargan poco.
## - El acelerador gasta turbo y sube el tempo. Lo ganado se conserva: el tempo de
##   crucero sube con vos.
## - Cada dorada fallada baja un poco la crucero; varias seguidas bajan una marcha
##   entera. Piso en la marcha más baja.
## - Sin acelerar, el tempo va de a poco hacia la crucero.

const START_BPM := 120.0
const THROTTLE_BPM_PER_SEC := 15.0
const SETTLE_BPM_PER_SEC := 12.0
const TURBO_DRAIN_PER_SEC := 0.6
const GOLD_CHARGE := 0.006
## Carga extra por dorada con el combo lleno (se suma de a poco hasta COMBO_FULL).
const COMBO_CHARGE := 0.012
const COMBO_FULL := 16
const ADORN_CHARGE := 0.004
const MISS_BPM := 2.0
const MISSES_PER_GEAR := 3

enum Result { GOLD_HIT, GOLD_MISS, ADORN_HIT, ADORN_MISS }


## Un booster que el corredor cruzó en este tick.
class Crossing:
	var index: int
	var result: Result
	## Combo antes de este cruce (para saber cuánto se perdió al fallar).
	var combo_before: int
	var gear_dropped := false

	func _init(p_index: int, p_result: Result, p_combo_before: int) -> void:
		index = p_index
		result = p_result
		combo_before = p_combo_before


var clock := MusicClock.new()
var lane := 2
var turbo := 0.0
var cruise_bpm := START_BPM
var combo := 0
var best_combo := 0
var gold_hits := 0
var misses_in_row := 0
var gear_bpms: PackedFloat64Array
var min_bpm: float
var max_bpm: float
var _next_booster := 0


func _init(p_gear_bpms: PackedFloat64Array) -> void:
	gear_bpms = p_gear_bpms
	min_bpm = gear_bpms[0]
	max_bpm = gear_bpms[gear_bpms.size() - 1]
	reset(0.0)


func reset(start_beat: float) -> void:
	clock.beat = start_beat
	cruise_bpm = clampf(START_BPM, min_bpm, max_bpm)
	clock.bpm = cruise_bpm
	lane = 2
	turbo = 0.0
	combo = 0
	best_combo = 0
	gold_hits = 0
	misses_in_row = 0
	_next_booster = 0


## Avanza un tick. Devuelve los boosters cruzados (track puede ser null).
func step(input: PilotInput, delta: float, track: Track = null) -> Array[Crossing]:
	lane = clampi(lane + input.lane_steps, 0, Track.LANES - 1)
	if input.throttle and turbo > 0.0:
		turbo = maxf(turbo - TURBO_DRAIN_PER_SEC * delta, 0.0)
		clock.bpm = minf(clock.bpm + THROTTLE_BPM_PER_SEC * delta, max_bpm)
		cruise_bpm = maxf(cruise_bpm, clock.bpm)
	else:
		clock.bpm = move_toward(clock.bpm, cruise_bpm, SETTLE_BPM_PER_SEC * delta)
	clock.advance(delta)

	var crossings: Array[Crossing] = []
	if track:
		while _next_booster < track.boosters.size() and track.boosters[_next_booster].beat <= clock.beat:
			crossings.append(_cross(_next_booster, track.boosters[_next_booster]))
			_next_booster += 1
	return crossings


## Marcha actual: la más cercana al tempo (0 = la más baja).
func gear() -> int:
	return BasePlayer.pick_gear(gear_bpms, -1, clock.bpm)


## 0 a 1 según el tempo dentro del rango del género.
func intensity() -> float:
	return clampf(inverse_lerp(min_bpm, max_bpm, clock.bpm), 0.0, 1.0)


func _cross(index: int, booster: Booster) -> Crossing:
	var gold := booster.kind == Booster.Kind.GOLD
	var hit := booster.lane == lane
	var crossing := Crossing.new(index, _result(gold, hit), combo)
	if gold and hit:
		turbo = minf(turbo + GOLD_CHARGE + COMBO_CHARGE * minf(combo, COMBO_FULL) / COMBO_FULL, 1.0)
		combo += 1
		best_combo = maxi(best_combo, combo)
		gold_hits += 1
		misses_in_row = 0
	elif gold:
		combo = 0
		misses_in_row += 1
		cruise_bpm = maxf(cruise_bpm - MISS_BPM, min_bpm)
		if misses_in_row >= MISSES_PER_GEAR:
			misses_in_row = 0
			crossing.gear_dropped = _drop_gear()
	elif hit:
		turbo = minf(turbo + ADORN_CHARGE, 1.0)
	return crossing


## Baja la crucero a la marcha de abajo. Devuelve false si ya estaba en el piso.
func _drop_gear() -> bool:
	var below := min_bpm
	for bpm in gear_bpms:
		if bpm < cruise_bpm - 0.5:
			below = bpm
	var dropped := cruise_bpm > min_bpm
	cruise_bpm = below
	return dropped


static func _result(gold: bool, hit: bool) -> Result:
	if gold:
		return Result.GOLD_HIT if hit else Result.GOLD_MISS
	return Result.ADORN_HIT if hit else Result.ADORN_MISS
