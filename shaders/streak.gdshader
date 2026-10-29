shader_type spatial;
// Ráfaga de aire: línea fina estirada en la dirección del movimiento de la
// partícula (eje Y alineado a la velocidad) y girada para mirar a la cámara.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform;

uniform float streak_length = 3.0;

void vertex() {
	vec3 axis = normalize(MODEL_MATRIX[1].xyz);
	vec3 center = MODEL_MATRIX[3].xyz;
	vec3 side = normalize(cross(axis, CAMERA_POSITION_WORLD - center));
	vec3 world = center + side * VERTEX.x * length(MODEL_MATRIX[0].xyz) + axis * VERTEX.y * streak_length;
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
}

void fragment() {
	float across = 1.0 - abs(UV.x - 0.5) * 2.0;
	float along = sin(UV.y * 3.14159);
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * across * across * along;
}
