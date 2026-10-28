class_name TrackGenerator
extends RefCounted
## Genera una pista a partir de una obra y un seed. Mismo seed + misma VERSION
## = misma pista. Si se cambia cómo se genera algo, hay que subir VERSION.
##
## - Línea dorada: las notas de la melodía, agrupadas de a corchea (como mucho
##   2 boosters por beat). El carril sigue el contorno de la línea: la nota más
##   grave de la línea va a un borde y la más aguda al otro.
## - Adornos: 2 a 4 por ciclo, en corcheas libres, con notas del acorde del
##   momento que suben con el carril.

const VERSION := 1
const VARIATIONS_PER_RACE := 12
const GROUP_BEATS := 0.5
const ADORN_LOWEST := 74  # D5
const ADORN_DURATION := 0.5


static func generate(song: Song, seed_value: int, variations := VARIATIONS_PER_RACE) -> Track:
	var track := Track.new()
	track.seed_value = seed_value
	track.version = VERSION
	track.cycle_beats = song.cycle_beats
	track.variation_order = _variation_order(Rng.new(seed_value, "variaciones"), song.variations.size(), variations)
	track.cycles = song.cycle_lines(track.variation_order)
	track.length_beats = track.cycles.size() * song.cycle_beats
	track.inverted = Rng.new(seed_value, "carriles").chance(0.5)

	var gold := _gold_boosters(song, track)
	var adorns := _adorn_boosters(song, track, gold, Rng.new(seed_value, "adornos"))
	track.boosters.append_array(gold)
	track.boosters.append_array(adorns)
	track.boosters.sort_custom(func(a: Booster, b: Booster) -> bool:
		return a.beat < b.beat or (a.beat == b.beat and a.lane < b.lane))

	track.geometry = TrackGeometry.generate(Rng.new(seed_value, "geometria"), track.cycles.size(), song.cycle_beats)
	return track


static func _variation_order(rng: Rng, bank_size: int, count: int) -> Array[int]:
	var order: Array[int] = []
	for i in count:
		var v := rng.randi_range(0, bank_size - 1)
		if not order.is_empty() and v == order.back():
			v = (v + rng.randi_range(1, bank_size - 1)) % bank_size
		order.append(v)
	return order


static func _gold_boosters(song: Song, track: Track) -> Array[Booster]:
	var result: Array[Booster] = []
	for i in track.cycles.size():
		var line_name := track.cycles[i]
		if line_name == Song.INTRO:
			continue
		var lanes := _contour_lanes(song.lines[line_name], track.inverted)
		var current: Booster = null
		for e: NoteEvent in song.lines[line_name]:
			if e.is_rest():
				continue
			var note := e.shifted(i * song.cycle_beats)
			if current == null or floorf(note.beat / GROUP_BEATS) != floorf(current.beat / GROUP_BEATS):
				current = Booster.new(note.beat, lanes[note.midi], Booster.Kind.GOLD)
				result.append(current)
			current.notes.append(note)
	return result


## midi -> carril, repartiendo las alturas distintas de la línea entre los carriles.
static func _contour_lanes(events: Array[NoteEvent], inverted: bool) -> Dictionary:
	var pitches: Array[int] = []
	for e in events:
		if not e.is_rest() and e.midi not in pitches:
			pitches.append(e.midi)
	pitches.sort()
	var lanes := {}
	for i in pitches.size():
		var lane := 2 if pitches.size() == 1 else roundi(float(i) / (pitches.size() - 1) * (Track.LANES - 1))
		lanes[pitches[i]] = Track.LANES - 1 - lane if inverted else lane
	return lanes


static func _adorn_boosters(song: Song, track: Track, gold: Array[Booster], rng: Rng) -> Array[Booster]:
	var taken := {}  # slot de corchea -> carril del dorado
	for b in gold:
		taken[int(b.beat / GROUP_BEATS)] = b.lane
	var slots_per_cycle := int(song.cycle_beats / GROUP_BEATS)

	var result: Array[Booster] = []
	for i in track.cycles.size():
		if track.cycles[i] == Song.INTRO:
			continue
		var first_slot := i * slots_per_cycle
		var wanted := rng.randi_range(2, 4)
		var placed := 0
		for attempt in 12:
			if placed == wanted:
				break
			var slot := first_slot + rng.randi_range(0, slots_per_cycle - 1)
			if taken.has(slot):
				continue
			var lane := clampi(_previous_gold_lane(taken, slot) + rng.randi_range(-2, 2), 0, Track.LANES - 1)
			taken[slot] = lane
			var beat := slot * GROUP_BEATS
			var booster := Booster.new(beat, lane, Booster.Kind.ADORN)
			booster.notes.append(NoteEvent.new(beat, ADORN_DURATION, _adorn_pitch(song.chord_at(beat), lane, track.inverted)))
			result.append(booster)
			placed += 1
	return result


static func _previous_gold_lane(taken: Dictionary, slot: int) -> int:
	for s in range(slot - 1, maxi(slot - 16, -1), -1):
		if taken.has(s):
			return taken[s]
	return 2


## La n-ésima nota del acorde desde ADORN_LOWEST, siguiendo la regla carril = altura.
static func _adorn_pitch(chord: String, lane: int, inverted: bool) -> int:
	var step := Track.LANES - 1 - lane if inverted else lane
	var pcs := Notation.chord_pitch_classes(chord)
	var midi := ADORN_LOWEST
	var found := -1
	while true:
		if posmod(midi, 12) in pcs:
			found += 1
			if found == step:
				return midi
		midi += 1
	return midi
