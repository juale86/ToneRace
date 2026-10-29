class_name HitFx
extends Node3D
## Efectos al agarrar un booster: una onda de luz que se expande sobre la ruta y
## chispas que suben. Se ubica en el auto cada frame, así los efectos acompañan
## al jugador en vez de quedar atrás a toda velocidad. Usa un pool fijo: no crea
## nodos durante la carrera.

const POOL := 6
const RING_SECONDS := 0.45
const RING_SIZE := 5.5

var _rings: Array[MeshInstance3D] = []
var _ring_ages := PackedFloat32Array()
var _sparks: Array[GPUParticles3D] = []
var _next := 0


func _ready() -> void:
	var ring_shader := preload("res://shaders/hit_ring.gdshader")
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * RING_SIZE
	var spark_mesh := QuadMesh.new()
	spark_mesh.size = Vector2.ONE * 0.22
	var spark_material := StandardMaterial3D.new()
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	spark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	spark_material.vertex_color_use_as_albedo = true
	spark_mesh.material = spark_material
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade
	for i in POOL:
		var ring := MeshInstance3D.new()
		ring.mesh = plane
		var material := ShaderMaterial.new()
		material.shader = ring_shader
		ring.material_override = material
		ring.position.y = 0.06
		ring.visible = false
		add_child(ring)
		_rings.append(ring)
		_ring_ages.append(1.0)

		var sparks := GPUParticles3D.new()
		sparks.one_shot = true
		sparks.emitting = false
		sparks.amount = 12
		sparks.lifetime = 0.6
		sparks.explosiveness = 1.0
		sparks.position.y = 0.5
		sparks.draw_pass_1 = spark_mesh
		var process := ParticleProcessMaterial.new()
		process.direction = Vector3.UP
		process.spread = 40.0
		process.initial_velocity_min = 4.0
		process.initial_velocity_max = 8.0
		process.gravity = Vector3(0, -9, 0)
		process.scale_min = 0.6
		process.scale_max = 1.4
		process.color_ramp = fade_texture
		sparks.process_material = process
		add_child(sparks)
		_sparks.append(sparks)


## lateral: posición del booster respecto del auto, para centrar la onda.
func hit(color: Color, lateral: float) -> void:
	var i := _next
	_next = (_next + 1) % POOL
	_ring_ages[i] = 0.0
	_rings[i].position.x = lateral
	_rings[i].visible = true
	(_rings[i].material_override as ShaderMaterial).set_shader_parameter("color", color)
	var sparks := _sparks[i]
	sparks.position.x = lateral
	(sparks.process_material as ParticleProcessMaterial).color = Color(color.r * 2.0, color.g * 2.0, color.b * 2.0)
	sparks.restart()


func _process(delta: float) -> void:
	for i in POOL:
		if not _rings[i].visible:
			continue
		_ring_ages[i] += delta / RING_SECONDS
		if _ring_ages[i] >= 1.0:
			_rings[i].visible = false
		else:
			(_rings[i].material_override as ShaderMaterial).set_shader_parameter("age", _ring_ages[i])
