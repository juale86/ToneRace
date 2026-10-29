class_name TrackGenerator
extends RefCounted
## Genera una pista a partir de una obra y un seed. Mismo seed + misma VERSION
## = misma pista. Si se cambia cómo se genera algo, hay que subir VERSION.
##
## - Línea dorada: las notas de la melodía, agrupadas de a corchea (como mucho
##   2 boosters por beat). El carril sigue el contorno de la melodía: si la nota
##   sube, el carril va hacia lo agudo; si baja, hacia lo grave; si se repite, se
##   queda. El salto está limitado por el tiempo hasta la nota anterior, para que
##   siempre se pueda llegar.
## - Adornos: 2 a 4 por ciclo, en corcheas libres, a un carril de la dorada
##   anterior, con notas del acorde del momento que suben con el carril.

const VERSION := 3
const VARIATIONS_PER_RACE := 12
const GROUP_BEATS := 0.5
const ADORN_LOWEST := 74  # D5
const ADORN_DURATION := 0.5
## Dificultad normal: carriles que se pueden saltar por corchea entre dos doradas.
const LANES_PER_GROUP := 1
## Costos al elegir carriles: quedarse quieto cuando la nota cambia, y cada
## carril de diferencia con el salto que pide el intervalo.
const STILL_COST := 3.0
const SIZE_COST := 0.5


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
		var v := rng.next_int(0, bank_size - 1)
		if not order.is_empty() and v == order.back():
			v = (v + rng.next_int(1, bank_size - 1)) % bank_size
		order.append(v)
	return order


static func _gold_boosters(song: Song, track: Track) -> Array[Booster]:
	var result: Array[Booster] = []
	var pitches := PackedInt32Array()  # la primera nota de cada booster
	for i in track.cycles.size():
		var line_name := track.cycles[i]
		if line_name == Song.INTRO:
			continue
		var current: Booster = null
		for e: NoteEvent in song.lines[line_name]:
			if e.is_rest():
				continue
			var note := e.shifted(i * song.cycle_beats)
			if current == null or floorf(note.beat / GROUP_BEATS) != floorf(current.beat / GROUP_BEATS):
				current = Booster.new(note.beat, 0, Booster.Kind.GOLD)
				result.append(current)
				pitches.append(note.midi)
			current.notes.append(note)
	var lanes := _contour_lanes(result, pitches)
	for i in result.size():
		result[i].lane = Track.LANES - 1 - lanes[i] if track.inverted else lanes[i]
	return result


## Elige el carril de cada booster (0 = grave) con programación dinámica sobre
## toda la carrera. Reglas fijas: nota repetida = mismo carril, nota más aguda
## nunca va hacia lo grave (y al revés), y el salto entra en el tiempo disponible.
## Entre los caminos posibles prefiere moverse cuando la nota cambia y saltos
## proporcionales al intervalo.
static func _contour_lanes(boosters: Array[Booster], pitches: PackedInt32Array) -> PackedInt32Array:
	var n := boosters.size()
	var lanes := PackedInt32Array()
	lanes.resize(n)
	if n == 0:
		return lanes
	var costs := PackedFloat64Array()
	var from := PackedInt32Array()
	costs.resize(n * Track.LANES)
	from.resize(n * Track.LANES)
	for lane in Track.LANES:
		costs[lane] = absf(lane - 2) * SIZE_COST  # el auto arranca en el centro
	for i in range(1, n):
		var interval := pitches[i] - pitches[i - 1]
		var wanted := _wanted_steps(interval)
		var reach := max_lane_steps(boosters[i].beat - boosters[i - 1].beat)
		for lane in Track.LANES:
			var best := INF
			for prev in Track.LANES:
				var step := lane - prev
				if absi(step) > reach or (interval == 0 and step != 0) or step * interval < 0:
					continue
				var cost := costs[(i - 1) * Track.LANES + prev] + absi(absi(step) - wanted) * SIZE_COST
				if step == 0 and interval != 0:
					cost += STILL_COST
				if cost < best:
					best = cost
					from[i * Track.LANES + lane] = prev
			costs[i * Track.LANES + lane] = best
	var last := 0
	for lane in Track.LANES:
		if costs[(n - 1) * Track.LANES + lane] < costs[(n - 1) * Track.LANES + last]:
			last = lane
	for i in range(n - 1, -1, -1):
		lanes[i] = last
		last = from[i * Track.LANES + last]
	return lanes


## Cuántos carriles se pueden cruzar entre dos doradas separadas por `gap` beats.
static func max_lane_steps(gap: float) -> int:
	return maxi(1, int(gap / GROUP_BEATS + 0.001)) * LANES_PER_GROUP


## Salto ideal para un intervalo: grado conjunto = 1 carril, una quinta o más = 3.
static func _wanted_steps(interval: int) -> int:
	var size := absi(interval)
	if size == 0:
		return 0
	if size <= 4:
		return 1
	if size <= 7:
		return 2
	return 3


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
		var wanted := rng.next_int(2, 4)
		var placed := 0
		for attempt in 12:
			if placed == wanted:
				break
			var slot := first_slot + rng.next_int(0, slots_per_cycle - 1)
			if taken.has(slot):
				continue
			var lane := clampi(_previous_gold_lane(taken, slot) + rng.next_int(-1, 1), 0, Track.LANES - 1)
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
