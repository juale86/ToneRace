shader_type spatial;
// Onda de luz al agarrar un booster: un anillo que se expande sobre la ruta.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.75, 0.15);
uniform float age = 1.0;  // 0 = recién nace, 1 = terminó

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float radius = mix(0.1, 0.95, sqrt(age));
	float width = mix(0.025, 0.07, age);
	float band = 1.0 - smoothstep(0.0, width, abs(r - radius));
	ALBEDO = color * 2.5;
	ALPHA = band * (1.0 - age) * (1.0 - age);
}
