extends GutTest

var _saved_volume: float
var _saved_muted: bool


func before_each() -> void:
	_saved_volume = AudioSettings.volume
	_saved_muted = AudioSettings.muted


func after_each() -> void:
	AudioSettings.volume = _saved_volume
	AudioSettings.muted = _saved_muted
	AudioSettings._save()  # los tests no deben pisar la configuración del jugador


func test_volume_steps_and_clamps() -> void:
	AudioSettings.volume = 0.8
	AudioSettings.muted = false
	AudioSettings.change(1)
	AudioSettings.change(1)
	AudioSettings.change(1)
	assert_eq(AudioSettings.volume, 1.0)
	for i in 15:
		AudioSettings.change(-1)
	assert_eq(AudioSettings.volume, 0.0)
	assert_true(AudioServer.is_bus_mute(0), "a volumen 0 el bus queda mudo")


func test_mute_toggles_and_raising_volume_unmutes() -> void:
	AudioSettings.volume = 0.5
	AudioSettings.muted = false
	AudioSettings.toggle_mute()
	assert_eq(AudioSettings.level(), 0.0)
	assert_true(AudioServer.is_bus_mute(0))
	AudioSettings.change(-1)
	assert_true(AudioSettings.muted, "bajar no saca el silencio")
	AudioSettings.change(1)
	assert_false(AudioSettings.muted)
	assert_almost_eq(AudioSettings.level(), 0.5, 0.0001)
	assert_false(AudioServer.is_bus_mute(0))
