class_name CarView
extends Node3D
## Muscle car placeholder armado con primitivas. El origen queda en el piso, en el
## centro del auto; -Z es adelante. Se inclina al cambiar de carril y gira las ruedas.

const WHEEL_RADIUS := 0.3
const MAX_ROLL := deg_to_rad(9.0)
const MAX_YAW := deg_to_rad(12.0)
## Velocidad lateral (unidades/s) que produce la inclinación máxima.
const LEAN_AT := 20.0
const LEAN_SMOOTHING := 12.0

var _body := Node3D.new()
var _wheels: Array[Node3D] = []
var _lean := 0.0
var _wheel_angle := 0.0


func _ready() -> void:
	add_child(_body)
	var paint := _material(Color(0.85, 0.1, 0.15), 0.5)
	var glass := _material(Color(0.05, 0.05, 0.1), 0.0)
	var dark := _material(Color(0.08, 0.08, 0.09), 0.0)
	var stripe := _material(Color(0.95, 0.9, 0.85), 0.3)
	_box(Vector3(1.5, 0.42, 2.9), Vector3(0, 0.45, 0), paint)
	_box(Vector3(0.3, 0.02, 2.92), Vector3(0, 0.67, 0), stripe)
	_box(Vector3(1.2, 0.36, 1.2), Vector3(0, 0.84, 0.3), glass)
	_box(Vector3(0.5, 0.12, 0.6), Vector3(0, 0.72, -0.85), dark)  # toma de aire
	_box(Vector3(1.5, 0.06, 0.3), Vector3(0, 0.9, 1.3), dark)  # alerón
	for x in [-0.6, 0.6]:
		_box(Vector3(0.06, 0.24, 0.1), Vector3(x, 0.75, 1.3), dark)
		_box(Vector3(0.3, 0.12, 0.04), Vector3(x * 1.05, 0.5, -1.46), _material(Color(1.0, 0.95, 0.7), 3.0))
		_box(Vector3(0.36, 0.1, 0.04), Vector3(x * 1.05, 0.52, 1.46), _material(Color(1.0, 0.05, 0.05), 2.5))
	var wheel_mesh := CylinderMesh.new()
	wheel_mesh.top_radius = WHEEL_RADIUS
	wheel_mesh.bottom_radius = WHEEL_RADIUS
	wheel_mesh.height = 0.3
	wheel_mesh.radial_segments = 12
	wheel_mesh.material = dark
	for x in [-0.72, 0.72]:
		for z in [-0.95, 0.95]:
			var hub := Node3D.new()
			hub.position = Vector3(x, WHEEL_RADIUS, z)
			_body.add_child(hub)
			var wheel := MeshInstance3D.new()
			wheel.mesh = wheel_mesh
			wheel.rotation.z = PI / 2.0
			hub.add_child(wheel)
			# Un rayo claro para que se note el giro.
			var spoke := MeshInstance3D.new()
			var spoke_mesh := BoxMesh.new()
			spoke_mesh.size = Vector3(0.32, 0.08, 0.5)
			spoke_mesh.material = stripe
			spoke.mesh = spoke_mesh
			hub.add_child(spoke)
			_wheels.append(hub)


## speed: unidades/s hacia adelante. lateral_speed: unidades/s hacia la derecha.
func animate(delta: float, speed: float, lateral_speed: float) -> void:
	var target := clampf(lateral_speed / LEAN_AT, -1.0, 1.0)
	_lean = lerpf(_lean, target, 1.0 - exp(-LEAN_SMOOTHING * delta))
	_body.rotation = Vector3(0.0, -_lean * MAX_YAW, -_lean * MAX_ROLL)
	_wheel_angle = fmod(_wheel_angle - speed * delta / WHEEL_RADIUS, TAU)
	for hub in _wheels:
		hub.rotation.x = _wheel_angle


func _box(size: Vector3, at: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = at
	_body.add_child(part)


static func _material(color: Color, glow: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material
