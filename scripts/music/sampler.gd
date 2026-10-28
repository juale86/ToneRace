class_name Sampler
extends Node
## Toca notas sueltas con las muestras renderizadas (una por nota y rol).
## Las notas suenan a su altura real; no dependen del tempo.

const VOICES := 24
const RELEASE_SEC := 0.08
const BUS := &"Live"

var _samples := {}  # rol -> {midi -> AudioStreamWAV}
var _ranges := {}  # rol -> Vector2i(low, high)
var _voices: Array[Voice] = []


class Voice:
	var player: AudioStreamPlayer
	var started_at := 0.0
	var release_at := 0.0
	var gain := 1.0
	var base_db := 0.0


func setup(manifest: Dictionary, base_dir: String) -> void:
	AudioBuses.ensure(BUS)
	for role: String in manifest.live:
		var spec: Dictionary = manifest.live[role]
		var notes := {}
		for midi in range(int(spec.low), int(spec.high) + 1):
			notes[midi] = load(base_dir.path_join("notes/%s/%d.wav" % [role, midi]))
		_samples[role] = notes
		_ranges[role] = Vector2i(int(spec.low), int(spec.high))
	for i in VOICES:
		var voice := Voice.new()
		voice.player = AudioStreamPlayer.new()
		voice.player.bus = BUS
		add_child(voice.player)
		_voices.append(voice)


## La nota se transpone por octavas si cae fuera del rango del rol.
func play_note(role: String, midi: int, duration_sec: float, volume_db := 0.0) -> void:
	var range_: Vector2i = _ranges[role]
	while midi < range_.x:
		midi += 12
	while midi > range_.y:
		midi -= 12
	var now := _now()
	var voice := _free_voice()
	voice.player.stream = _samples[role][midi]
	voice.player.volume_db = volume_db
	voice.base_db = volume_db
	voice.gain = 1.0
	voice.started_at = now
	voice.release_at = now + duration_sec
	voice.player.play()


func _process(delta: float) -> void:
	var now := _now()
	for voice in _voices:
		if not voice.player.playing or now < voice.release_at:
			continue
		voice.gain -= delta / RELEASE_SEC
		if voice.gain <= 0.0:
			voice.player.stop()
		else:
			voice.player.volume_db = voice.base_db + linear_to_db(voice.gain)


func _free_voice() -> Voice:
	var oldest := _voices[0]
	for voice in _voices:
		if not voice.player.playing:
			return voice
		if voice.started_at < oldest.started_at:
			oldest = voice
	return oldest


func _now() -> float:
	return Time.get_ticks_usec() / 1_000_000.0
