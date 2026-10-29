class_name TrackView
extends Node3D
## Dibuja una Track: la ruta (asfalto, carriles y marcas de beat/compás salen de
## un shader), postes que destellan con el beat y los boosters, que laten. Todo
## procedural; el beat les llega por el parámetro global de shader "beat".

const MESH_STEP := 0.25  # beats entre cortes de la malla
const MARGIN_BEATS := 16.0
const SHOULDER := 1.6
const BOOSTER_HEIGHT := 0.5
const POST_GAP := 0.9  # distancia del poste al borde de la banquina
const POST_HEIGHT := 1.3

const GOLD_COLOR := Color(1.0, 0.75, 0.15)
const ADORN_COLOR := Color(0.2, 0.9, 1.0)

var _track: Track
var _instances := {}  # índice de booster -> [MultiMesh, índice de instancia]


func build(track: Track) -> void:
	_track = track
	var half := Track.LANES * Track.LANE_WIDTH / 2.0
	var road := ShaderMaterial.new()
	road.shader = preload("res://shaders/road.gdshader")
	road.set_shader_parameter("half_width", half)
	road.set_shader_parameter("lane_width", Track.LANE_WIDTH)
	road.set_shader_parameter("lanes", float(Track.LANES))
	road.set_shader_parameter("units_per_beat", TrackGeometry.UNITS_PER_BEAT)
	var instance := MeshInstance3D.new()
	instance.mesh = _road_mesh(-half - SHOULDER, half + SHOULDER)
	instance.material_override = road
	add_child(instance)
	_build_posts(half + SHOULDER + POST_GAP)
	_build_boosters()


func hide_booster(index: int) -> void:
	var entry: Array = _instances[index]
	var mm: MultiMesh = entry[0]
	mm.set_instance_transform(entry[1], Transform3D().scaled(Vector3.ZERO))


func booster_position(booster: Booster) -> Vector3:
	var frame := _track.geometry.frame_at(booster.beat)
	return frame.origin + frame.basis.x * Track.lane_offset(booster.lane) + frame.basis.y * BOOSTER_HEIGHT


func _build_boosters() -> void:
	var gold_mesh := BoxMesh.new()
	gold_mesh.size = Vector3(1.4, 0.35, 0.7)
	gold_mesh.material = _booster_material(GOLD_COLOR, 0.0)
	var adorn_mesh := SphereMesh.new()
	adorn_mesh.radius = 0.35
	adorn_mesh.height = 0.7
	adorn_mesh.radial_segments = 8
	adorn_mesh.rings = 4
	adorn_mesh.material = _booster_material(ADORN_COLOR, 1.5)

	var by_kind := {Booster.Kind.GOLD: [], Booster.Kind.ADORN: []}
	for i in _track.boosters.size():
		by_kind[_track.boosters[i].kind].append(i)
	for kind in by_kind:
		var indices: Array = by_kind[kind]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = gold_mesh if kind == Booster.Kind.GOLD else adorn_mesh
		mm.instance_count = indices.size()
		for n in indices.size():
			var booster := _track.boosters[indices[n]]
			var frame := _track.geometry.frame_at(booster.beat)
			mm.set_instance_transform(n, Transform3D(frame.basis, booster_position(booster)))
			_instances[indices[n]] = [mm, n]
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = mm
		add_child(instance)


## Un poste por beat a cada lado; los de comienzo de compás, más altos.
func _build_posts(lateral: float) -> void:
	var pole := BoxMesh.new()
	pole.size = Vector3(0.14, POST_HEIGHT, 0.14)
	var light := BoxMesh.new()
	light.size = Vector3(0.24, 0.24, 0.24)
	var st := SurfaceTool.new()
	st.append_from(pole, 0, Transform3D(Basis(), Vector3(0, POST_HEIGHT / 2.0, 0)))
	st.append_from(light, 0, Transform3D(Basis(), Vector3(0, POST_HEIGHT + 0.12, 0)))
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/post.gdshader")
	material.set_shader_parameter("top", POST_HEIGHT - 0.01)
	var mesh := st.commit()
	mesh.surface_set_material(0, material)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	var beats := int(_track.length_beats) + 1
	mm.instance_count = beats * 2
	for b in beats:
		var frame := _track.geometry.frame_at(b)
		var bar := b % 4 == 0
		var scale := Vector3(1.0, 1.6, 1.0) if bar else Vector3.ONE
		for side in 2:
			var x := lateral * (1.0 if side == 1 else -1.0)
			mm.set_instance_transform(b * 2 + side, Transform3D(frame.basis.scaled_local(scale), frame.origin + frame.basis.x * x))
			mm.set_instance_custom_data(b * 2 + side, Color(1.0 if bar else 0.0, 0, 0, 0))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	add_child(instance)


## Cinta que sigue la pista entre los desplazamientos laterales left y right,
## con UV = (lateral, beat) para el shader.
func _road_mesh(left: float, right: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var beat := -MARGIN_BEATS
	var previous := PackedVector3Array()
	while beat <= _track.length_beats + MARGIN_BEATS:
		var frame := _track.geometry.frame_at(beat)
		var current := PackedVector3Array([frame.origin + frame.basis.x * left, frame.origin + frame.basis.x * right])
		if not previous.is_empty():
			var corners := [previous[0], previous[1], current[1], current[0]]
			var uvs := [Vector2(left, beat - MESH_STEP), Vector2(right, beat - MESH_STEP), Vector2(right, beat), Vector2(left, beat)]
			for k in [0, 2, 1, 0, 3, 2]:  # horario visto desde arriba = cara frontal
				st.set_uv(uvs[k])
				st.add_vertex(corners[k])
		previous = current
		beat += MESH_STEP
	st.generate_normals()
	return st.commit()


func _booster_material(color: Color, spin: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/booster.gdshader")
	material.set_shader_parameter("color", color)
	material.set_shader_parameter("spin", spin)
	return material
