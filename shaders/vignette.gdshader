shader_type canvas_item;
// Destello en los bordes de la pantalla (por ejemplo al cortarse el combo).

uniform vec3 color : source_color = vec3(1.0, 0.15, 0.1);
uniform float amount = 0.0;

void fragment() {
	vec2 d = (UV - 0.5) * vec2(1.0, 1.3);
	float edge = smoothstep(0.35, 0.75, length(d));
	COLOR = vec4(color, edge * amount);
}
