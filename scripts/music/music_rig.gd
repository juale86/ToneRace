class_name MusicRig
extends Node
## Carga una obra y un género, y arma la base y el sampler.

var song: Song
var base: BasePlayer
var sampler: Sampler
## Rango de tempo del género (la primera y la última marcha renderizada).
var min_bpm: float
var max_bpm: float


func setup(song_id: String, genre_id: String) -> void:
	song = Song.load_json("res://data/songs/%s.json" % song_id)
	var genre_dir := "res://assets/audio/generated/%s" % genre_id
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(genre_dir.path_join("manifest.json")))
	min_bpm = manifest.gears.front().bpm
	max_bpm = manifest.gears.back().bpm
	base = BasePlayer.new()
	add_child(base)
	base.setup(manifest, genre_dir)
	sampler = Sampler.new()
	add_child(sampler)
	sampler.setup(manifest, genre_dir)
