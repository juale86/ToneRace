extends Node3D
## Banco de pruebas: la pista generada por seed, con el auto y los controles.
##
## ←/→ o A/D: carril (apaga el piloto automático)   ↑, W o espacio: acelerar
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

var rig: MusicRig
var runner: Runner
var track: Track
var view: TrackView
var world: DesertWorld
var human := HumanPilot.new()
var auto := AutoPilot.new()
var lateral := 0.0
var autopilot := true
var gold_hits := 0
var combo := 0
var best_combo := 0
var _next_booster := 0
var _pending: Array[PendingNote] = []
var _message := ""
var _message_left := 0.0

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
	runner = Runner.new(rig.min_bpm, rig.max_bpm)
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
		await get_tree().create_timer(30.0).timeout
		print("AUTOTEST piloto %s, doradas %d, combo %d, mejor %d, beat %.1f" % [autopilot, gold_hits, combo, best_combo, runner.clock.beat])
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
	gold_hits = 0
	combo = 0
	best_combo = 0
	_next_booster = 0
	_pending.clear()
	rig.base.play(runner.clock.beat, runner.clock.bpm)


func _physics_process(delta: float) -> void:
	var input := human.decide(runner, track)
	if input.lane_steps != 0:
		autopilot = false
	if autopilot:
		input.lane_steps = auto.decide(runner, track).lane_steps
	if input.riff:
		_show("Riff: llega en el paso 6")
	if input.voice:
		_show("Voz: llega en el paso 6")
	runner.step(input, delta)

	while _next_booster < track.boosters.size() and track.boosters[_next_booster].beat <= runner.clock.beat:
		_cross(_next_booster)
		_next_booster += 1
	_play_pending()

	if runner.clock.beat >= track.length_beats + COUNT_IN_BEATS:
		_start(track.seed_value)


func _cross(index: int) -> void:
	var booster := track.boosters[index]
	var gold := booster.kind == Booster.Kind.GOLD
	if booster.lane != runner.lane:
		if gold:
			combo = 0
		return
	view.hide_booster(index)
	for note in booster.notes:
		_pending.append(PendingNote.new(note, "lead" if gold else "adorn"))
	if gold:
		gold_hits += 1
		combo += 1
		best_combo = maxi(best_combo, combo)


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

	var previous := lateral
	lateral = move_toward(lateral, Track.lane_offset(runner.lane), LATERAL_SPEED * delta)
	var speed := clock.bpm / 60.0 * TrackGeometry.UNITS_PER_BEAT
	_car.animate(delta, speed, (lateral - previous) / delta if delta > 0.0 else 0.0)
	var frame := track.geometry.frame_at(beat)
	_car.global_transform = Transform3D(frame.basis, frame.origin + frame.basis.x * lateral)

	var back := track.geometry.frame_at(beat - CAMERA_BACK / TrackGeometry.UNITS_PER_BEAT)
	var ahead := track.geometry.frame_at(beat + CAMERA_LOOK / TrackGeometry.UNITS_PER_BEAT)
	_camera.fov = remap(clock.bpm, rig.min_bpm, rig.max_bpm, FOV_MIN, FOV_MAX)
	_camera.global_position = back.origin + back.basis.y * CAMERA_HEIGHT + back.basis.x * lateral * 0.5
	_camera.look_at(ahead.origin + ahead.basis.x * lateral * 0.3, back.basis.y)

	_message_left = maxf(_message_left - delta, 0.0)
	var cycle := int(floor(beat / track.cycle_beats))
	var line := track.cycles[cycle] if cycle >= 0 and cycle < track.cycles.size() else ""
	_label.text = "\n".join([
		"Pista %s  (generador v%d)%s" % [SeedCode.encode(track.seed_value), track.version, "  agudo ←" if track.inverted else ""],
		"BPM %.0f   ciclo %d/%d   %s" % [clock.bpm, cycle + 1, track.cycles.size(), line if line != "" else "intro"],
		"doradas %d/%d   combo %d (mejor %d)" % [gold_hits, track.count(Booster.Kind.GOLD), combo, best_combo],
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
