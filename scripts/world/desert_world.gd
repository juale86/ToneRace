class_name DesertWorld
extends Node3D
## Mundo del rock: desierto al atardecer. Arma el cielo, la luz, el suelo y los
## props a los costados de una Track. Es solo visual: usa su propio stream del
## seed ("escenario") para que cambiarlo nunca altere la jugabilidad.
##
## Lo lejano es barato: montañas pintadas en el cielo, dunas levantadas en el
## shader y props en MultiMesh por tramos (así la cámara descarta los que no ve).

const CHUNK_BEATS := 32.0
const GROUND_ROW_BEATS := 1.0
const GROUND_DROP := 0.35
## Distancias laterales de las columnas del suelo; más densas cerca de la ruta.
const GROUND_COLUMNS: Array[float] = [0.0, 8.0, 14.0, 22.0, 32.0, 45.0, 60.0, 78.0, 100.0, 125.0, 155.0, 190.0, 230.0]
const SUN_PITCH := deg_to_rad(-7.0)
const SUN_YAW := deg_to_rad(200.0)

const CACTUS_COLOR := Color(0.24, 0.42, 0.2)
const ROCK_COLOR := Color(0.62, 0.32, 0.2)
const MESA_COLOR := Color(0.7, 0.33, 0.2)

var _track: Track
var _rng: Rng
var _lowpoly := ShaderMaterial.new()
var _cactus := _cactus_mesh()
var _rock := _rock_mesh()
var _mesa := _mesa_mesh()


func build(track: Track) -> void:
	_track = track
	_rng = Rng.new(track.seed_value, "escenario")
	_lowpoly.shader = preload("res://shaders/lowpoly.gdshader")
	_add_environment()
	var sand := ShaderMaterial.new()
	sand.shader = preload("res://shaders/sand.gdshader")
	sand.set_shader_parameter("units_per_beat", TrackGeometry.UNITS_PER_BEAT)
	var end := track.length_beats + TrackView.MARGIN_BEATS
	var from := -TrackView.MARGIN_BEATS
	while from < end:
		var to := minf(from + CHUNK_BEATS, end)
		var ground := MeshInstance3D.new()
		ground.mesh = _ground_mesh(from, to)
		ground.material_override = sand
		add_child(ground)
		_add_props(from, to)
		from = to


func _add_environment() -> void:
	var sky_material := ShaderMaterial.new()
	sky_material.shader = preload("res://shaders/desert_sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.85, 0.5, 0.32)
	env.fog_density = 0.0028
	env.fog_aerial_perspective = 0.6
	env.fog_sky_affect = 0.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	# El sol queda adelante y bajo: la luz viene hacia la cámara, atardecer a contraluz.
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(SUN_PITCH, SUN_YAW, 0.0)
	sun.light_color = Color(1.0, 0.72, 0.48)
	sun.light_energy = 1.3
	add_child(sun)


## Franja ancha que sigue la pista, un poco por debajo de la ruta.
func _ground_mesh(from: float, to: float) -> ArrayMesh:
	var columns := PackedFloat32Array()
	for i in range(GROUND_COLUMNS.size() - 1, 0, -1):
		columns.append(-GROUND_COLUMNS[i])
	columns.append_array(GROUND_COLUMNS)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var previous := PackedVector3Array()
	var previous_beat := from
	var beat := from
	while true:
		var frame := _track.geometry.frame_at(beat)
		var row := PackedVector3Array()
		for x in columns:
			row.append(frame.origin + frame.basis.x * x - frame.basis.y * GROUND_DROP)
		if not previous.is_empty():
			for c in columns.size() - 1:
				var corners := [previous[c], previous[c + 1], row[c + 1], row[c]]
				var uvs := [Vector2(columns[c], previous_beat), Vector2(columns[c + 1], previous_beat), Vector2(columns[c + 1], beat), Vector2(columns[c], beat)]
				for k in [0, 2, 1, 0, 3, 2]:  # horario visto desde arriba = cara frontal
					st.set_uv(uvs[k])
					st.add_vertex(corners[k])
		previous = row
		previous_beat = beat
		if beat >= to:
			break
		beat = minf(beat + GROUND_ROW_BEATS, to)
	return st.commit()


func _add_props(from: float, to: float) -> void:
	var cacti: Array[Transform3D] = []
	var rocks: Array[Transform3D] = []
	var mesas: Array[Transform3D] = []
	var cactus_colors: Array[Color] = []
	var rock_colors: Array[Color] = []
	var mesa_colors: Array[Color] = []
	var beat := from
	while beat < to:
		for side in [-1.0, 1.0]:
			if _rng.chance(0.45):
				var size := 0.8 + _rng.next_float() * 0.9
				cacti.append(_place(beat, side * (10.0 + _rng.next_float() * 55.0), Vector3.ONE * size))
				cactus_colors.append(_vary(CACTUS_COLOR, 0.12))
			if _rng.chance(0.7):
				var size := 0.4 + pow(_rng.next_float(), 3.0) * 4.0
				var shape := Vector3(1.0 + _rng.next_float(), 0.5 + _rng.next_float() * 0.6, 1.0 + _rng.next_float())
				rocks.append(_place(beat, side * (9.0 + _rng.next_float() * 60.0), shape * size))
				rock_colors.append(_vary(ROCK_COLOR, 0.15))
			if _rng.chance(0.06):
				var width := 25.0 + _rng.next_float() * 45.0
				var height := 18.0 + _rng.next_float() * 35.0
				# La base queda enterrada bajo las dunas.
				var mesa := _place(beat, side * (95.0 + _rng.next_float() * 110.0), Vector3(width, height + 25.0, width * (0.5 + _rng.next_float() * 0.5)))
				mesa.origin -= Vector3.UP * 25.0
				mesas.append(mesa)
				mesa_colors.append(_vary(MESA_COLOR, 0.1))
		beat += 1.0
	_add_multimesh(_cactus, cacti, cactus_colors)
	_add_multimesh(_rock, rocks, rock_colors)
	_add_multimesh(_mesa, mesas, mesa_colors)


func _place(beat: float, lateral: float, scale: Vector3) -> Transform3D:
	var frame := _track.geometry.frame_at(beat + _rng.next_float())
	var basis := Basis(Vector3.UP, _rng.next_float() * TAU).scaled_local(scale)
	return Transform3D(basis, frame.origin + frame.basis.x * lateral - Vector3.UP * GROUND_DROP)


func _vary(color: Color, amount: float) -> Color:
	var k := 1.0 + (_rng.next_float() * 2.0 - 1.0) * amount
	return Color(color.r * k, color.g * k, color.b * k)


func _add_multimesh(mesh: Mesh, transforms: Array[Transform3D], colors: Array[Color]) -> void:
	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colors[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	instance.material_override = _lowpoly
	add_child(instance)


static func _cactus_mesh() -> ArrayMesh:
	var trunk := _cylinder(0.32, 0.38, 1.0)
	return _merge([
		[trunk, Transform3D(Basis().scaled(Vector3(1, 3.2, 1)), Vector3(0, 1.6, 0))],
		[trunk, Transform3D(Basis(Vector3.BACK, PI / 2).scaled_local(Vector3(0.7, 0.8, 0.7)), Vector3(0.55, 1.3, 0))],
		[trunk, Transform3D(Basis().scaled(Vector3(0.7, 1.1, 0.7)), Vector3(0.9, 1.75, 0))],
		[trunk, Transform3D(Basis(Vector3.BACK, PI / 2).scaled_local(Vector3(0.65, 0.6, 0.65)), Vector3(-0.45, 1.9, 0))],
		[trunk, Transform3D(Basis().scaled(Vector3(0.65, 0.8, 0.65)), Vector3(-0.72, 2.2, 0))],
	])


static func _rock_mesh() -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radial_segments = 6
	sphere.rings = 3
	return _merge([[sphere, Transform3D()]])


static func _mesa_mesh() -> ArrayMesh:
	var mesa := _cylinder(0.42, 0.5, 1.0)
	mesa.radial_segments = 7
	return _merge([[mesa, Transform3D(Basis(), Vector3(0, 0.5, 0))]])


static func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 6
	mesh.rings = 0
	return mesh


static func _merge(parts: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	for part: Array in parts:
		st.append_from(part[0], 0, part[1])
	return st.commit()
