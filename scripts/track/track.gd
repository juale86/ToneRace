class_name Track
extends RefCounted
## Una pista generada: estructura musical, boosters y geometría.

const LANES := 5
const LANE_WIDTH := 2.2

var seed_value: int
var version: int
var variation_order: Array[int] = []
var cycles: PackedStringArray
var cycle_beats: int
var length_beats: float
## Si es true, lo agudo va a la izquierda.
var inverted := false
var boosters: Array[Booster] = []
var geometry: TrackGeometry


static func lane_offset(lane: int) -> float:
	return (lane - (LANES - 1) / 2.0) * LANE_WIDTH


func count(kind: Booster.Kind) -> int:
	return boosters.filter(func(b: Booster) -> bool: return b.kind == kind).size()
