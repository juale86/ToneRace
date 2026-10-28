extends Node
## Banco de pruebas del paso 1: el Canon suena desde datos con tempo variable.
##
## Flecha arriba/abajo: acelerar/frenar (simula el acelerador)
## 1-5: saltar a 80/95/110/125/140 BPM
## M: melodía on/off   P: compensación de tono on/off
## Espacio: pausa      R: reiniciar

const MIN_BPM := 80.0
const MAX_BPM := 140.0
const BPM_PER_SEC := 20.0
const PRESETS := [80.0, 95.0, 110.0, 125.0, 140.0]
const COUNT_IN_BEATS := 4.0

var song: Song
var clock := MusicClock.new()
var base: BasePlayer
var sampler: Sampler
var melody: Sequencer
var cycles: PackedStringArray
var melody_on := true
var paused := false

@onready var _label: Label = $UI/Info


func _ready() -> void:
	var rig := MusicRig.new()
	add_child(rig)
	rig.setup("canon", "rock")
	song = rig.song
	base = rig.base
	sampler = rig.sampler
	var order: Array[int] = []
	order.assign(range(song.variations.size()))
	cycles = song.cycle_lines(order)
	melody = Sequencer.new(song.melody_events(cycles))
	_restart()
	if "--autotest" in OS.get_cmdline_user_args():
		_autotest()


## Barre el tempo de 80 a 140 y vuelta, e imprime la deriva del audio. Uso:
## godot --path . -- --autotest
func _autotest() -> void:
	var worst := 0.0
	var resyncs := 0
	var gear_changes := 0
	var last_gear := base.current_gear
	for step in 24 * 60:  # 24 segundos de frames de ~16 ms
		await get_tree().process_frame
		var t := step / 60.0
		clock.bpm = 80.0 + 60.0 * (1.0 - absf(fmod(t / 12.0, 2.0) - 1.0))
		if t > 1.0:
			worst = maxf(worst, absf(base.last_drift_sec))
			if absf(base.last_drift_sec) > BasePlayer.RESYNC_THRESHOLD_SEC:
				resyncs += 1
		if base.current_gear != last_gear:
			gear_changes += 1
			last_gear = base.current_gear
	print("AUTOTEST deriva máx %.1f ms, resincronizaciones %d, cambios de marcha %d" % [worst * 1000.0, resyncs, gear_changes])
	get_tree().quit()


func _restart() -> void:
	clock.bpm = 100.0
	clock.beat = -COUNT_IN_BEATS
	melody.reset()
	base.play(clock.beat, clock.bpm)


func _physics_process(delta: float) -> void:
	if paused:
		return
	if Input.is_key_pressed(KEY_UP):
		clock.bpm = minf(clock.bpm + BPM_PER_SEC * delta, MAX_BPM)
	if Input.is_key_pressed(KEY_DOWN):
		clock.bpm = maxf(clock.bpm - BPM_PER_SEC * delta, MIN_BPM)

	var previous := clock.beat
	clock.advance(delta)
	for e in melody.collect(previous, clock.beat):
		if melody_on:
			sampler.play_note("lead", e.midi, e.duration * clock.seconds_per_beat(), -4.0)

	if clock.beat >= cycles.size() * song.cycle_beats:
		_restart()


func _process(delta: float) -> void:
	if paused:
		return
	var tick := 1.0 / Engine.physics_ticks_per_second
	var beat := clock.interpolated(Engine.get_physics_interpolation_fraction(), tick)
	base.update(beat, clock.bpm, delta)

	var cycle := int(floor(beat / song.cycle_beats))
	var line := cycles[cycle] if cycle >= 0 and cycle < cycles.size() else ""
	_label.text = "\n".join([
		"%s — paso 1: reloj + secuenciador" % song.title,
		"BPM %.1f   marcha %d (%.1f BPM, pitch %.3f)" % [
			clock.bpm, base.current_gear, base.gear_bpm(base.current_gear), clock.bpm / base.gear_bpm(base.current_gear)],
		"beat %.2f   compás %d   acorde %s" % [beat, int(floor(beat / song.beats_per_bar)) + 1, song.chord_at(beat)],
		"ciclo %d/%d   línea %s" % [cycle + 1, cycles.size(), line if line != "" else "(intro)"],
		"deriva audio %+.1f ms" % (base.last_drift_sec * 1000.0),
		"melodía %s   compensación de tono %s" % ["ON" if melody_on else "off", "ON" if base.compensate_pitch else "off"],
		"",
		"↑/↓ tempo · 1-5 presets · M melodía · P compensación · Espacio pausa · R reiniciar",
	])


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_M:
			melody_on = not melody_on
		KEY_P:
			base.compensate_pitch = not base.compensate_pitch
		KEY_R:
			_restart()
		KEY_SPACE:
			paused = not paused
			if paused:
				base.stop()
			else:
				base.play(clock.beat, clock.bpm)
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			clock.bpm = PRESETS[event.keycode - KEY_1]
