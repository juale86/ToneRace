class_name Rng
extends RefCounted
## Generador pseudoaleatorio propio (xoshiro128**), determinista en cualquier
## plataforma y versión de Godot. Solo usa enteros de 32 bits enmascarados, así
## que ninguna multiplicación desborda los 64 bits de GDScript.
##
## Cada sistema usa su propio stream (Rng.new(seed, "geometria")): agregar
## llamadas en un sistema no cambia lo que generan los demás.

const MASK := 0xFFFFFFFF

var _s0 := 0
var _s1 := 0
var _s2 := 0
var _s3 := 0


func _init(seed_value: int, stream: String) -> void:
	var x := (seed_value & MASK) ^ ((seed_value >> 32) & MASK) ^ _fnv1a(stream)
	var state: Array[int] = []
	for i in 4:
		x = (x + 0x9E3779B9) & MASK
		var z := x
		z = _mul32(z ^ (z >> 16), 0x85EBCA6B)
		z = _mul32(z ^ (z >> 13), 0xC2B2AE35)
		state.append(z ^ (z >> 16))
	_s0 = state[0]
	_s1 = state[1]
	_s2 = state[2]
	_s3 = state[3] if state.any(func(v: int) -> bool: return v != 0) else 1


func next_u32() -> int:
	var result := _mul32(_rotl(_mul32(_s1, 5), 7), 9)
	var t := (_s1 << 9) & MASK
	_s2 ^= _s0
	_s3 ^= _s1
	_s1 ^= _s2
	_s0 ^= _s3
	_s2 ^= t
	_s3 = _rotl(_s3, 11)
	return result


## En [0, 1).
func randf() -> float:
	return next_u32() / 4294967296.0


## En [low, high], ambos incluidos.
func randi_range(low: int, high: int) -> int:
	return low + next_u32() % (high - low + 1)


func chance(probability: float) -> bool:
	return randf() < probability


static func _mul32(a: int, b: int) -> int:
	return (a * (b & 0xFFFF) + (((a * (b >> 16)) & 0xFFFF) << 16)) & MASK


static func _rotl(x: int, k: int) -> int:
	return ((x << k) | (x >> (32 - k))) & MASK


static func _fnv1a(text: String) -> int:
	var h := 0x811C9DC5
	for byte in text.to_utf8_buffer():
		h = _mul32(h ^ byte, 0x01000193)
	return h
