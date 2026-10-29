class_name HitFx
extends Node3D
## Efectos al agarrar un booster: un destello donde estaba, una onda fina sobre la
## ruta, chispas y corcheas de luz que suben. Va colgado del auto, así acompaña al
## jugador en vez de quedar atrás a toda velocidad. Usa un pool fijo: no crea
## nodos durante la carrera.

const POOL := 6
const RING_SECONDS := 0.35
const RING_SIZE := 4.5
const FLASH_SECONDS := 0.18
const FLASH_SIZE := 3.2

var _rings: Array[MeshInstance3D] = []
var _flashes: Array[MeshInstance3D] = []
var _ages := PackedFloat32Array()
var _sparks: Array[GPUParticles3D] = []
var _notes: Array[GPUParticles3D] = []
var _next := 0


func _ready() -> void:
	var ring_shader := preload("res://shaders/hit_ring.gdshader")
	var soft_shader := preload("res://shaders/soft_particle.gdshader")
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * RING_SIZE
	var flash_mesh := QuadMesh.new()
	flash_mesh.size = Vector2.ONE

	var spark_mesh := QuadMesh.new()
	spark_mesh.size = Vector2.ONE * 0.18
	spark_mesh.material = _shader_material(soft_shader)
	var note_mesh := QuadMesh.new()
	note_mesh.size = Vector2.ONE * 0.95
	note_mesh.material = _shader_material(preload("res://shaders/note_particle.gdshader"))

	for i in POOL:
		var ring := MeshInstance3D.new()
		ring.mesh = plane
		ring.material_override = _shader_material(ring_shader)
		ring.position.y = 0.06
		ring.visible = false
		add_child(ring)
		_rings.append(ring)

		var flash := MeshInstance3D.new()
		flash.mesh = flash_mesh
		var flash_material := _shader_material(soft_shader)
		flash_material.set_shader_parameter("boost", 3.0)
		flash.material_override = flash_material
		flash.position.y = 0.6
		flash.visible = false
		add_child(flash)
		_flashes.append(flash)
		_ages.append(1.0)

		var sparks := _particles(spark_mesh, 14, 0.45)
		var spark_process: ParticleProcessMaterial = sparks.process_material
		spark_process.spread = 70.0
		spark_process.initial_velocity_min = 5.0
		spark_process.initial_velocity_max = 10.0
		spark_process.gravity = Vector3(0, -14, 0)
		_sparks.append(sparks)

		var notes := _particles(note_mesh, 3, 0.8)
		var note_process: ParticleProcessMaterial = notes.process_material
		note_process.spread = 45.0
		note_process.initial_velocity_min = 2.5
		note_process.initial_velocity_max = 4.0
		note_process.gravity = Vector3(0, -1.5, 0)
		note_process.angle_min = -20.0
		note_process.angle_max = 20.0
		note_process.scale_min = 0.7
		note_process.scale_max = 1.1
		note_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		note_process.emission_sphere_radius = 0.5
		_notes.append(notes)


## lateral: posición del booster respecto del auto. strength (0 a 1) crece con el
## combo: más corcheas cuanto más largo.
func hit(color: Color, lateral: float, strength: float) -> void:
	var i := _next
	_next = (_next + 1) % POOL
	_ages[i] = 0.0
	for node: Node3D in [_rings[i], _flashes[i], _sparks[i], _notes[i]]:
		node.position.x = lateral
	_rings[i].visible = true
	_flashes[i].visible = true
	(_rings[i].material_override as ShaderMaterial).set_shader_parameter("color", color)
	(_flashes[i].material_override as ShaderMaterial).set_shader_parameter("color", color)
	var bright := Color(color.r * 1.6, color.g * 1.6, color.b * 1.6)
	(_sparks[i].process_material as ParticleProcessMaterial).color = bright
	(_notes[i].process_material as ParticleProcessMaterial).color = bright
	_sparks[i].restart()
	_notes[i].amount_ratio = lerpf(0.34, 1.0, strength)
	_notes[i].restart()


func _process(delta: float) -> void:
	for i in POOL:
		if not _rings[i].visible:
			continue
		_ages[i] += delta
		var ring_age := _ages[i] / RING_SECONDS
		var flash_age := _ages[i] / FLASH_SECONDS
		(_rings[i].material_override as ShaderMaterial).set_shader_parameter("age", minf(ring_age, 1.0))
		_flashes[i].visible = flash_age < 1.0
		_flashes[i].scale = Vector3.ONE * FLASH_SIZE * (0.5 + flash_age)
		(_flashes[i].material_override as ShaderMaterial).set_shader_parameter("fade", 1.0 - flash_age)
		_rings[i].visible = ring_age < 1.0


func _particles(mesh: Mesh, amount: int, lifetime: float) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.one_shot = true
	particles.emitting = false
	particles.amount = amount
	particles.lifetime = lifetime
	particles.explosiveness = 1.0
	particles.local_coords = true  # viajan con el auto
	particles.position.y = 0.5
	particles.draw_pass_1 = mesh
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade
	process.color_ramp = fade_texture
	particles.process_material = process
	add_child(particles)
	return particles


static func _shader_material(shader: Shader) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	return material
