class_name AudioSettings
extends RefCounted
## Volumen general y silencio, aplicados al bus Master y guardados en user://.

const PATH := "user://settings.cfg"
const STEP := 0.1
const DEFAULT_VOLUME := 0.8

static var volume := DEFAULT_VOLUME
static var muted := false


static func load_saved() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		volume = clampf(config.get_value("audio", "volume", DEFAULT_VOLUME), 0.0, 1.0)
		muted = config.get_value("audio", "muted", false)
	apply()


static func change(steps: int) -> void:
	volume = clampf(snappedf(volume + steps * STEP, STEP), 0.0, 1.0)
	# Subir el volumen saca el silencio: es lo que uno espera al tocar "+".
	if steps > 0:
		muted = false
	_save()


static func toggle_mute() -> void:
	muted = not muted
	_save()


## Volumen efectivo, 0 si está en silencio.
static func level() -> float:
	return 0.0 if muted else volume


static func apply() -> void:
	var master := AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_volume_db(master, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(master, muted or volume <= 0.0)


static func _save() -> void:
	apply()
	var config := ConfigFile.new()
	config.set_value("audio", "volume", volume)
	config.set_value("audio", "muted", muted)
	config.save(PATH)
