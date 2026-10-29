shader_type spatial;
// Suelo del desierto. Cerca de la ruta es plano; lejos se levantan dunas en el
// vértice (sin geometría extra). UV.x = lateral en unidades, UV.y = beat.

#include "res://shaders/noise.gdshaderinc"

uniform float units_per_beat = 18.0;
uniform float flat_until = 70.0;
uniform float dune_height = 16.0;
uniform vec3 sand_light : source_color = vec3(0.86, 0.58, 0.36);
uniform vec3 sand_dark : source_color = vec3(0.62, 0.36, 0.22);

varying vec2 p;

void vertex() {
	p = vec2(UV.x, UV.y * units_per_beat);
	float far = smoothstep(flat_until, flat_until + 50.0, abs(UV.x));
	VERTEX.y += far * (fbm(p * 0.011) * dune_height + vnoise(p * 0.05) * 2.0);
}

void fragment() {
	float n = fbm(p * 0.08);
	float ripples = sin(p.x * 0.7 + p.y * 0.25 + n * 6.0) * 0.5 + 0.5;
	ALBEDO = mix(sand_dark, sand_light, clamp(n * 0.9 + ripples * 0.2, 0.0, 1.0));
	NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	ROUGHNESS = 1.0;
}
