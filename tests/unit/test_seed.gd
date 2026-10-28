extends GutTest


func _sequence(rng: Rng, n: int) -> Array[int]:
	var values: Array[int] = []
	for i in n:
		values.append(rng.next_u32())
	return values


func test_rng_same_seed_and_stream_repeat() -> void:
	assert_eq(_sequence(Rng.new(1234, "a"), 50), _sequence(Rng.new(1234, "a"), 50))


func test_rng_streams_and_seeds_are_independent() -> void:
	assert_ne(_sequence(Rng.new(1234, "a"), 5), _sequence(Rng.new(1234, "b"), 5))
	assert_ne(_sequence(Rng.new(1234, "a"), 5), _sequence(Rng.new(1235, "a"), 5))


func test_rng_values_stay_in_32_bits() -> void:
	for v in _sequence(Rng.new(987654321, "x"), 2000):
		assert_between(v, 0, Rng.MASK)


func test_rng_ranges() -> void:
	var rng := Rng.new(42, "rangos")
	var seen := {}
	for i in 500:
		var v := rng.next_int(-2, 2)
		assert_between(v, -2, 2)
		seen[v] = true
		var f := rng.next_float()
		assert_true(f >= 0.0 and f < 1.0)
	assert_eq(seen.size(), 5, "salen todos los valores")


## Regresión: chance() llegó a usar el randf() global de Godot en vez del propio.
func test_rng_helpers_are_deterministic() -> void:
	var a := Rng.new(77, "h")
	var b := Rng.new(77, "h")
	for i in 200:
		assert_eq(a.chance(0.5), b.chance(0.5))
		assert_eq(a.next_float(), b.next_float())
		assert_eq(a.next_int(0, 9), b.next_int(0, 9))


## Si este test falla, cambió el generador: todas las pistas existentes cambiarían.
## Solo se actualiza junto con TrackGenerator.VERSION.
func test_rng_golden_values() -> void:
	assert_eq(_sequence(Rng.new(1, "golden"), 4), RNG_GOLDEN)


# Calculados con una implementación independiente en Python (ver historial de git).
const RNG_GOLDEN: Array[int] = [1418050591, 3347772435, 3311214823, 3207799074]


func test_seed_code_round_trip() -> void:
	for value in [0, 1, 30, 31, 123456, SeedCode.COUNT - 1]:
		var code := SeedCode.encode(value)
		assert_eq(code.length(), SeedCode.LENGTH)
		assert_eq(SeedCode.decode(code), value, code)


func test_seed_code_rejects_invalid_and_accepts_lowercase() -> void:
	assert_eq(SeedCode.decode("ABC"), -1, "corto")
	assert_eq(SeedCode.decode("ABCDE0"), -1, "0 no está en el alfabeto")
	assert_eq(SeedCode.decode("ABCDEI"), -1, "I no está en el alfabeto")
	assert_eq(SeedCode.decode(" k7px3m "), SeedCode.decode("K7PX3M"))
