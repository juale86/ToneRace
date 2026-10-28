class_name TrackGeometry
extends RefCounted
## Forma 3D de la pista: curvas y subidas en función del beat.
##
## Es solo visual: la jugabilidad vive en beats y carriles, así que pequeñas
## diferencias de punto flotante entre dispositivos no cambian la carrera.

const STEP := 0.25  # beats entre muestras
const UNITS_PER_BEAT := 18.0
const MAX_YAW_PER_BEAT := deg_to_rad(4.0)
const MAX_PITCH := deg_to_rad(4.0)
## Más allá de este giro acumulado, las curvas solo pueden volver hacia el centro
## (así la pista nunca da la vuelta y se cruza consigo misma).
const MAX_HEADING := deg_to_rad(40.0)
const MAX_ELEVATION := 60.0

var _positions := PackedVector3Array()
var _headings := PackedFloat32Array()
var _pitches := PackedFloat32Array()


static func generate(rng: Rng, cycles: int, cycle_beats: int) -> TrackGeometry:
	# Una curva y una pendiente objetivo por ciclo, elegidas al llegar a cada ciclo
	# según hacia dónde apunta la pista. El primero y el último son rectos.
	var yaw_targets := PackedFloat32Array([0.0, 0.0])
	var pitch_targets := PackedFloat32Array([0.0, 0.0])

	var geometry := TrackGeometry.new()
	var position := Vector3.ZERO
	var heading := 0.0
	var samples := int(cycles * cycle_beats / STEP) + 1
	for i in samples:
		var beat := i * STEP
		var c := mini(int(beat / cycle_beats), cycles - 1)
		if c + 1 >= yaw_targets.size():
			# Se decide con la posición prevista si la curva actual sigue todo el ciclo.
			var last := c + 1 >= cycles
			var heading_ahead := heading + yaw_targets[c] * cycle_beats
			var height_ahead := position.y + sin(pitch_targets[c]) * UNITS_PER_BEAT * cycle_beats
			yaw_targets.append(0.0 if last else _pick(rng, heading_ahead / MAX_HEADING) * MAX_YAW_PER_BEAT)
			pitch_targets.append(0.0 if last else _pick(rng, height_ahead / MAX_ELEVATION) * MAX_PITCH)
		var t := smoothstep(0.0, 1.0, (beat - c * cycle_beats) / cycle_beats)
		var pitch := lerpf(pitch_targets[c], pitch_targets[c + 1], t)
		geometry._positions.append(position)
		geometry._headings.append(heading)
		geometry._pitches.append(pitch)
		heading += lerpf(yaw_targets[c], yaw_targets[c + 1], t) * STEP
		position += _basis(heading, pitch) * Vector3.FORWARD * UNITS_PER_BEAT * STEP
	return geometry


## -1, 0 o 1. Con |excess| >= 1 ya se fue demasiado para un lado: solo vuelve o sigue recto.
static func _pick(rng: Rng, excess: float) -> float:
	var options := [-1.0, 0.0, 0.0, 1.0]
	if excess >= 1.0:
		options = [-1.0, -1.0, 0.0]
	elif excess <= -1.0:
		options = [1.0, 1.0, 0.0]
	return options[rng.next_int(0, options.size() - 1)]


## Origen en el centro de la pista; basis.x apunta a la derecha, -basis.z hacia adelante.
func frame_at(beat: float) -> Transform3D:
	var last := _positions.size() - 1
	if beat <= 0.0:
		return _extrapolate(0, beat)
	if beat >= last * STEP:
		return _extrapolate(last, beat - last * STEP)
	var i := int(beat / STEP)
	var t := beat / STEP - i
	var basis := _basis(lerpf(_headings[i], _headings[i + 1], t), lerpf(_pitches[i], _pitches[i + 1], t))
	return Transform3D(basis, _positions[i].lerp(_positions[i + 1], t))


func _extrapolate(index: int, beats: float) -> Transform3D:
	var basis := _basis(_headings[index], _pitches[index])
	return Transform3D(basis, _positions[index] + basis * Vector3.FORWARD * UNITS_PER_BEAT * beats)


static func _basis(heading: float, pitch: float) -> Basis:
	return Basis.from_euler(Vector3(pitch, heading, 0.0))
