shader_type spatial;
// Boosters: laten en cada beat (crecen y brillan) y giran despacio.

global uniform float beat;
uniform vec3 color : source_color = vec3(1.0, 0.75, 0.15);
uniform float spin = 0.0;

varying float pulse;

void vertex() {
	pulse = exp(-fract(beat) * 5.0);
	float a = beat * spin;
	VERTEX.xz = mat2(vec2(cos(a), -sin(a)), vec2(sin(a), cos(a))) * VERTEX.xz;
	VERTEX *= 1.0 + 0.18 * pulse;
}

void fragment() {
	ALBEDO = color;
	EMISSION = color * (1.8 + 2.6 * pulse);
}
