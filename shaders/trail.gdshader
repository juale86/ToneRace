shader_type spatial;
// Estela de las luces traseras: se desvanece a lo largo (UV.y).
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.1, 0.08);
uniform float strength = 0.0;

void fragment() {
	float across = 1.0 - abs(UV.x - 0.5) * 2.0;
	ALBEDO = color * 2.0;
	ALPHA = strength * pow(1.0 - UV.y, 2.5) * smoothstep(0.0, 0.6, across);
}
