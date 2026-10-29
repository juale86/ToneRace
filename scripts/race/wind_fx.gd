class_name WindFx
extends Node3D
## Sensación de aire: ráfagas finas que pasan alrededor de la cámara (van colgadas
## de ella) y polvo que levantan las ruedas traseras y queda atrás en el mundo.
## Cantidad, velocidad y largo crecen con el tempo.

const STREAKS := 120
const STREAK_RADIUS := 10.0
const STREAK_INNER := 4.5
const STREAK_DEPTH := 70.0
const DUST := 40

var _streaks := GPUParticles3D.new()
var _streak_mesh := QuadMesh.new()
var _streak_material := ShaderMaterial.new()
var _dust: Array[GPUParticles3D] = []


## camera: de dónde cuelgan las ráfagas. wheels: puntos (locales al auto) de donde sale el polvo.
func setup(camera: Camera3D, car: Node3D, wheels: Array[Vector3]) -> void:
	_streak_mesh.size = Vector2(0.07, 1.0)
	_streak_material.shader = preload("res://shaders/streak.gdshader")
	_streak_mesh.material = _streak_material

	_streaks.amount = STREAKS
	_streaks.lifetime = 1.2
	_streaks.local_coords = true
	_streaks.position = Vector3(0, 0, -STREAK_DEPTH)
	_streaks.draw_pass_1 = _streak_mesh
	_streaks.visibility_aabb = AABB(Vector3(-20, -20, -20), Vector3(40, 40, STREAK_DEPTH + 40))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	process.emission_ring_axis = Vector3.BACK
	process.emission_ring_radius = STREAK_RADIUS
	process.emission_ring_inner_radius = STREAK_INNER
	process.emission_ring_height = 30.0
	process.emission_shape_scale = Vector3(1.0, 0.45, 1.0)  # más por los costados que arriba
	process.direction = Vector3.BACK
	process.spread = 0.0
	process.gravity = Vector3.ZERO
	process.particle_flag_align_y = true
	process.color = Color(1.0, 0.93, 0.82, 0.45)
	process.color_ramp = _fade_in_out()
	_streaks.process_material = process
	camera.add_child(_streaks)

	var dust_mesh := QuadMesh.new()
	dust_mesh.size = Vector2.ONE * 0.9
	var dust_material := ShaderMaterial.new()
	dust_material.shader = preload("res://shaders/soft_particle.gdshader")
	dust_material.set_shader_parameter("boost", 1.0)
	dust_mesh.material = dust_material
	for wheel in wheels:
		var dust := GPUParticles3D.new()
		dust.amount = DUST
		dust.lifetime = 0.9
		dust.local_coords = false
		dust.position = wheel
		dust.draw_pass_1 = dust_mesh
		var dust_process := ParticleProcessMaterial.new()
		dust_process.direction = Vector3(0, 0.6, 1)
		dust_process.spread = 25.0
		dust_process.initial_velocity_min = 1.0
		dust_process.initial_velocity_max = 3.0
		dust_process.gravity = Vector3(0, 0.5, 0)
		dust_process.scale_min = 0.6
		dust_process.scale_max = 1.6
		dust_process.color = Color(0.85, 0.62, 0.45, 0.35)
		dust_process.color_ramp = _fade_in_out()
		var grow := Curve.new()
		grow.add_point(Vector2(0, 0.4))
		grow.add_point(Vector2(1, 1.8))
		var grow_texture := CurveTexture.new()
		grow_texture.curve = grow
		dust_process.scale_curve = grow_texture
		dust.process_material = dust_process
		car.add_child(dust)
		_dust.append(dust)


## speed: unidades/s del auto. intensity: 0 a 1 según el tempo.
func update(speed: float, intensity: float) -> void:
	var process: ParticleProcessMaterial = _streaks.process_material
	process.initial_velocity_min = speed * 1.3
	process.initial_velocity_max = speed * 1.9
	_streaks.amount_ratio = 0.15 + 0.85 * intensity * intensity
	_streak_material.set_shader_parameter("streak_length", 1.2 + 3.5 * intensity)
	for dust in _dust:
		dust.amount_ratio = 0.25 + 0.75 * intensity


static func _fade_in_out() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.2, Color(1, 1, 1, 1))
	gradient.add_point(0.75, Color(1, 1, 1, 1))
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture
