class_name BasePlayer
extends Node
## Toca la base renderizada siguiendo al reloj musical.
##
## Hay una versión del loop por marcha de tempo. Dentro de una marcha, pitch_scale
## ajusta la velocidad al BPM exacto y un PitchShift en el bus compensa el cambio
## de tono, para que la base quede afinada con las notas en vivo. Al cambiar de
## marcha se hace crossfade entre dos "bandejas" (decks), cada una con su bus.

const CROSSFADE_SEC := 0.12
const RESYNC_THRESHOLD_SEC := 0.03
const GEAR_HYSTERESIS := 0.004  # en log(ratio): evita saltar de marcha en el borde

## Si se desactiva, la base cambia de tono al acelerar (para comparar de oído).
var compensate_pitch := true
var current_gear := -1
var last_drift_sec := 0.0

var _gear_bpms := PackedFloat64Array()
var _streams: Array[AudioStreamWAV] = []
var _cycle_beats := 8.0
var _decks: Array[Deck] = []
var _active := 0


class Deck:
	var player: AudioStreamPlayer
	var pitch_shift: AudioEffectPitchShift
	var gear := -1
	var fade := 0.0
	var target := 0.0


func setup(manifest: Dictionary, base_dir: String) -> void:
	_cycle_beats = manifest.cycle_beats
	for gear: Dictionary in manifest.gears:
		var stream: AudioStreamWAV = load(base_dir.path_join(gear.file))
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(gear.frames)
		_gear_bpms.append(gear.bpm)
		_streams.append(stream)
	for deck_name in [&"BaseA", &"BaseB"]:
		var deck := Deck.new()
		deck.pitch_shift = AudioEffectPitchShift.new()
		AudioBuses.ensure(deck_name, [deck.pitch_shift])
		deck.player = AudioStreamPlayer.new()
		deck.player.bus = deck_name
		add_child(deck.player)
		_decks.append(deck)


## La marcha más cercana al BPM, sin cambiar si la actual sigue casi igual de cerca.
static func pick_gear(gear_bpms: PackedFloat64Array, current: int, bpm: float) -> int:
	var nearest := 0
	var best := INF
	for i in gear_bpms.size():
		var deviation := absf(log(bpm / gear_bpms[i]))
		if deviation < best:
			best = deviation
			nearest = i
	if current >= 0 and absf(log(bpm / gear_bpms[current])) <= best + GEAR_HYSTERESIS:
		return current
	return nearest


func gear_bpm(gear: int) -> float:
	return _gear_bpms[gear]


func play(beat: float, bpm: float) -> void:
	stop()
	current_gear = pick_gear(_gear_bpms, -1, bpm)
	_start_deck(_decks[_active], current_gear, beat, bpm, 1.0)


func stop() -> void:
	for deck in _decks:
		deck.player.stop()
		deck.fade = 0.0
		deck.target = 0.0
	current_gear = -1


func _exit_tree() -> void:
	stop()


func update(beat: float, bpm: float, delta: float) -> void:
	if current_gear < 0:
		return
	var gear := pick_gear(_gear_bpms, current_gear, bpm)
	if gear != current_gear:
		current_gear = gear
		_decks[_active].target = 0.0
		_active = 1 - _active
		_start_deck(_decks[_active], gear, beat, bpm, 0.0)

	for deck in _decks:
		if not deck.player.playing:
			continue
		deck.fade = move_toward(deck.fade, deck.target, delta / CROSSFADE_SEC)
		if deck.fade <= 0.0 and deck.target <= 0.0:
			deck.player.stop()
			continue
		# Crossfade de igual potencia.
		deck.player.volume_db = linear_to_db(sin(deck.fade * PI / 2.0))
		_apply_ratio(deck, bpm)

	_correct_drift(_decks[_active], beat, bpm)


func _start_deck(deck: Deck, gear: int, beat: float, bpm: float, fade: float) -> void:
	deck.gear = gear
	deck.fade = fade
	deck.target = 1.0
	deck.player.stream = _streams[gear]
	deck.player.volume_db = linear_to_db(maxf(sin(fade * PI / 2.0), 0.0001))
	_apply_ratio(deck, bpm)
	deck.player.play(_file_position(beat, gear))


func _apply_ratio(deck: Deck, bpm: float) -> void:
	var ratio := bpm / _gear_bpms[deck.gear]
	deck.player.pitch_scale = ratio
	deck.pitch_shift.pitch_scale = 1.0 / ratio if compensate_pitch else 1.0


func _file_position(beat: float, gear: int) -> float:
	return fposmod(beat, _cycle_beats) * 60.0 / _gear_bpms[gear]


func _correct_drift(deck: Deck, beat: float, bpm: float) -> void:
	if not deck.player.playing:
		return
	var loop_sec := _cycle_beats * 60.0 / _gear_bpms[deck.gear]
	var expected := _file_position(beat, deck.gear)
	var actual := deck.player.get_playback_position() + AudioServer.get_time_since_last_mix() * deck.player.pitch_scale
	last_drift_sec = fposmod(actual - expected + loop_sec / 2.0, loop_sec) - loop_sec / 2.0
	if absf(last_drift_sec) > RESYNC_THRESHOLD_SEC:
		deck.player.seek(expected)
