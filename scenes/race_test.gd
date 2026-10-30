extends Node3D
## Banco de pruebas: la pista generada por seed, con el auto y los controles.
##
## ←/→ o A/D: carril (apaga el piloto automático)   ↑, W o espacio: acelerar (gasta turbo)
## Z: Riff   X: Voz   P: piloto automático   N: pista nueva   R: reiniciar la misma pista
## Táctil (o mouse): mitades de arriba = carril; abajo Riff/Voz a la izquierda, acelerador a la derecha.
## Seed fijo: godot --path . -- --seed=K7PX3M     Controles táctiles visibles en PC: -- --touch

const COUNT_IN_BEATS := 4.0
const LATERAL_SPEED := 22.0
# Distancias de cámara en unidades del mundo, independientes de la escala de la pista.
const CAMERA_BACK := 6.5
const CAMERA_LOOK := 30.0
const CAMERA_HEIGHT := 2.3
const FOV_MIN := 72.0
const FOV_MAX := 88.0
const MESSAGE_SECONDS := 1.2
## Sacudida de cámara (unidades) a la marcha más alta; crece con el cuadrado del tempo.
const SHAKE_MAX := 0.09
## Apertura extra de cámara (grados) mientras se gasta turbo.
const TURBO_FOV := 8.0

var rig: MusicRig
var runner: Runner
var track: Track
var view: TrackView
var world: DesertWorld
var human := HumanPilot.new()
var auto := AutoPilot.new()
var lateral := 0.0
var autopilot := true
var _pending: Array[PendingNote] = []
var _turbo_kick := 0.0
var _message := ""
var _message_left := 0.0
var _fx := HitFx.new()
var _wind := WindFx.new()
var _hud := RaceHud.new()

@onready var _camera: Camera3D = $Camera
@onready var _car: CarView = $Car
@onready var _label: Label = $UI/Info
@onready var _touch: TouchControls = $UI/Touch


class PendingNote:
	var note: NoteEvent
	var role: String

	func _init(p_note: NoteEvent, p_role: String) -> void:
		note = p_note
		role = p_role


func _ready() -> void:
	rig = MusicRig.new()
	add_child(rig)
	rig.setup("canon", "rock")
	runner = Runner.new(rig.gear_bpms)
	_car.add_child(_fx)
	add_child(_wind)
	_wind.setup(_camera, _car, CarView.REAR_WHEELS)
	$UI.add_child(_hud)
	$UI.move_child(_hud, 0)
	add_child(human)
	add_child(auto)
	var args := OS.get_cmdline_user_args()
	_touch.visible = DisplayServer.is_touchscreen_available() or "--touch" in args
	var seed_value := SeedCode.random()
	for arg in args:
		if arg.begins_with("--seed="):
			var decoded := SeedCode.decode(arg.trim_prefix("--seed="))
			if decoded >= 0:
				seed_value = decoded
	_start(seed_value)
	if "--autotest" in args:
		var seconds := 30.0
		for arg in args:
			if arg.begins_with("--autotest-seconds="):
				seconds = arg.trim_prefix("--autotest-seconds=").to_float()
		await get_tree().create_timer(seconds).timeout
		print("AUTOTEST piloto %s, doradas %d, combo %d, mejor %d, beat %.1f, BPM %.1f, marcha %d, turbo %.2f" % [
			autopilot, runner.gold_hits, runner.combo, runner.best_combo, runner.clock.beat, runner.clock.bpm, runner.gear() + 1, runner.turbo])
		get_tree().quit()


func _start(seed_value: int) -> void:
	track = TrackGenerator.generate(rig.song, seed_value)
	if view:
		view.queue_free()
	view = TrackView.new()
	add_child(view)
	view.build(track)
	if world:
		world.queue_free()
	world = DesertWorld.new()
	add_child(world)
	world.build(track)
	runner.reset(-COUNT_IN_BEATS)
	lateral = Track.lane_offset(runner.lane)
	_pending.clear()
	rig.base.play(runner.clock.beat, runner.clock.bpm)


func _physics_process(delta: float) -> void:
	var input := human.decide(runner, track)
	if input.lane_steps != 0:
		autopilot = false
	if autopilot:
		var auto_input := auto.decide(runner, track)
		input.lane_steps = auto_input.lane_steps
		input.throttle = input.throttle or auto_input.throttle
	if input.riff:
		_show("Riff: llega en el paso 6")
	if input.voice:
		_show("Voz: llega en el paso 6")
	_hud.throttling = input.throttle and runner.turbo > 0.0
	for crossing in runner.step(input, delta, track):
		_cross(crossing)
	_play_pending()

	if runner.clock.beat >= track.length_beats + COUNT_IN_BEATS:
		_start(track.seed_value)


func _cross(crossing: Runner.Crossing) -> void:
	var booster := track.boosters[crossing.index]
	match crossing.result:
		Runner.Result.GOLD_MISS:
			if crossing.combo_before > 0:
				_hud.on_combo_break(crossing.combo_before)
			if crossing.gear_dropped:
				_hud.on_gear_drop()
			return
		Runner.Result.ADORN_MISS:
			return
	var gold := crossing.result == Runner.Result.GOLD_HIT
	view.hide_booster(crossing.index)
	var color := TrackView.GOLD_COLOR if gold else TrackView.ADORN_COLOR
	_fx.hit(color, Track.lane_offset(booster.lane) - lateral, clampf(runner.combo / 16.0, 0.0, 1.0))
	_car.flash(color)
	for note in booster.notes:
		_pending.append(PendingNote.new(note, "lead" if gold else "adorn"))
	if gold:
		_hud.on_hit(runner.combo)


## Las notas de un booster pueden caer un poco después de agarrarlo (corcheas agrupadas).
func _play_pending() -> void:
	var remaining: Array[PendingNote] = []
	for p in _pending:
		if p.note.beat <= runner.clock.beat:
			var volume := -4.0 if p.role == "lead" else -8.0
			rig.sampler.play_note(p.role, p.note.midi, p.note.duration * runner.clock.seconds_per_beat(), volume)
		else:
			remaining.append(p)
	_pending = remaining


func _show(message: String) -> void:
	_message = message
	_message_left = MESSAGE_SECONDS


func _process(delta: float) -> void:
	var clock := runner.clock
	var tick := 1.0 / Engine.physics_ticks_per_second
	var beat := clock.interpolated(Engine.get_physics_interpolation_fraction(), tick)
	rig.base.update(beat, clock.bpm, delta)
	_turbo_kick = lerpf(_turbo_kick, 1.0 if _hud.throttling else 0.0, 1.0 - exp(-6.0 * delta))
	var intensity := runner.intensity()
	_hud.set_speed(runner.turbo, runner.gear(), rig.gear_bpms.size(), clock.bpm)
	RenderingServer.global_shader_parameter_set(&"beat", beat)
	RenderingServer.global_shader_parameter_set(&"speed", intensity)
	_wind.update(clock.bpm / 60.0 * TrackGeometry.UNITS_PER_BEAT, maxf(intensity, _turbo_kick))

	var previous := lateral
	lateral = move_toward(lateral, Track.lane_offset(runner.lane), LATERAL_SPEED * delta)
	var speed := clock.bpm / 60.0 * TrackGeometry.UNITS_PER_BEAT
	_car.animate(delta, speed, (lateral - previous) / delta if delta > 0.0 else 0.0, intensity)
	var frame := track.geometry.frame_at(beat)
	_car.global_transform = Transform3D(frame.basis, frame.origin + frame.basis.x * lateral)

	var back := track.geometry.frame_at(beat - CAMERA_BACK / TrackGeometry.UNITS_PER_BEAT)
	var ahead := track.geometry.frame_at(beat + CAMERA_LOOK / TrackGeometry.UNITS_PER_BEAT)
	_camera.fov = remap(clock.bpm, rig.min_bpm, rig.max_bpm, FOV_MIN, FOV_MAX) + TURBO_FOV * _turbo_kick
	_camera.global_position = back.origin + back.basis.y * CAMERA_HEIGHT + back.basis.x * lateral * 0.5
	_camera.look_at(ahead.origin + ahead.basis.x * lateral * 0.3, back.basis.y)
	var t := Time.get_ticks_msec() / 1000.0
	var shake := SHAKE_MAX * intensity * intensity
	_camera.position += _camera.basis * Vector3(sin(t * 37.0) + sin(t * 23.0) * 0.5, sin(t * 41.0) * 0.6, 0.0) * shake

	_message_left = maxf(_message_left - delta, 0.0)
	var cycle := int(floor(beat / track.cycle_beats))
	var line := track.cycles[cycle] if cycle >= 0 and cycle < track.cycles.size() else ""
	_label.text = "\n".join([
		"Pista %s  (generador v%d)%s" % [SeedCode.encode(track.seed_value), track.version, "  agudo ←" if track.inverted else ""],
		"BPM %.0f (crucero %.0f)   ciclo %d/%d   %s" % [clock.bpm, runner.cruise_bpm, cycle + 1, track.cycles.size(), line if line != "" else "intro"],
		"doradas %d/%d   combo %d (mejor %d)" % [runner.gold_hits, track.count(Booster.Kind.GOLD), runner.combo, runner.best_combo],
		"piloto automático %s" % ("ON" if autopilot else "off"),
		"←/→ carril · ↑ acelerar · Z Riff · X Voz · P piloto · N pista nueva · R reiniciar",
		_message if _message_left > 0.0 else "",
	])


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_P:
			autopilot = not autopilot
		KEY_N:
			_start(SeedCode.random())
		KEY_R:
			_start(track.seed_value)
