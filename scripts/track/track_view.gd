class_name TrackView
extends Node3D
## Dibuja una Track: la ruta, las líneas de carril, una marca por compás y los
## boosters. Todo procedural y provisorio hasta tener los modelos finales.

const MESH_STEP := 0.5  # beats entre cortes de la malla
const MARGIN_BEATS := 16.0
const EDGE_WIDTH := 0.25
const LINE_WIDTH := 0.06
const BOOSTER_HEIGHT := 0.5

const ROAD_COLOR := Color(0.05, 0.04, 0.09)
const EDGE_COLOR := Color(1.0, 0.2, 0.7)
const LINE_COLOR := Color(0.35, 0.25, 0.8)
const BAR_COLOR := Color(0.25, 0.2, 0.5)
const GOLD_COLOR := Color(1.0, 0.75, 0.15)
const ADORN_COLOR := Color(0.2, 0.9, 1.0)

var _track: Track
var _instances := {}  # índice de booster -> [MultiMesh, índice de instancia]


func build(track: Track) -> void:
	_track = track
	var half := Track.LANES * Track.LANE_WIDTH / 2.0
	_add_mesh(_strip_mesh(-half, half, 0.0), _material(ROAD_COLOR, 0.0))
	var lines := SurfaceTool.new()
	lines.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in range(1, Track.LANES):
		var x := -half + k * Track.LANE_WIDTH
		_append_strip(lines, x - LINE_WIDTH, x + LINE_WIDTH, 0.01)
	_add_mesh(lines.commit(), _material(LINE_COLOR, 1.5))
	var edges := SurfaceTool.new()
	edges.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_strip(edges, -half - EDGE_WIDTH, -half, 0.05)
	_append_strip(edges, half, half + EDGE_WIDTH, 0.05)
	_add_mesh(edges.commit(), _material(EDGE_COLOR, 3.0))
	_add_mesh(_bar_marks(half), _material(BAR_COLOR, 1.0))
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
	gold_mesh.material = _material(GOLD_COLOR, 2.5)
	var adorn_mesh := SphereMesh.new()
	adorn_mesh.radius = 0.35
	adorn_mesh.height = 0.7
	adorn_mesh.material = _material(ADORN_COLOR, 2.5)

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


func _strip_mesh(left: float, right: float, height: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_strip(st, left, right, height)
	return st.commit()


## Una cinta que sigue la pista entre los desplazamientos laterales left y right.
func _append_strip(st: SurfaceTool, left: float, right: float, height: float) -> void:
	var beat := -MARGIN_BEATS
	var previous := PackedVector3Array()
	while beat <= _track.length_beats + MARGIN_BEATS:
		var frame := _track.geometry.frame_at(beat)
		var up := frame.basis.y * height
		var current := PackedVector3Array([
			frame.origin + frame.basis.x * left + up,
			frame.origin + frame.basis.x * right + up,
		])
		if not previous.is_empty():
			_append_quad(st, previous[0], previous[1], current[1], current[0])
		previous = current
		beat += MESH_STEP


func _bar_marks(half: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bar := 0.0
	while bar <= _track.length_beats:
		var a := _track.geometry.frame_at(bar - 0.04)
		var b := _track.geometry.frame_at(bar + 0.04)
		var up := Vector3.UP * 0.02
		_append_quad(st,
			a.origin - a.basis.x * half + up, a.origin + a.basis.x * half + up,
			b.origin + b.basis.x * half + up, b.origin - b.basis.x * half + up)
		bar += 4.0
	return st.commit()


func _append_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v in [a, b, c, a, c, d]:
		st.add_vertex(v)


func _add_mesh(mesh: Mesh, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	add_child(instance)


func _material(color: Color, emission: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m
