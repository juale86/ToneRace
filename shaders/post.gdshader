shader_type spatial;
// Postes al costado de la ruta, uno por beat. El reflector de arriba destella en
// cada beat; los de comienzo de compás (INSTANCE_CUSTOM.x = 1) más fuerte.

global uniform float beat;
uniform vec3 pole_color : source_color = vec3(0.85, 0.82, 0.78);
uniform vec3 light_color : source_color = vec3(1.0, 0.5, 0.15);
uniform float top = 1.0;

varying float is_light;
varying float strength;

void vertex() {
	is_light = step(top, VERTEX.y);
	float bar = INSTANCE_CUSTOM.x;
	float bar_pulse = exp(-fract(beat / 4.0) * 4.0 * 4.0);
	strength = 1.0 + 2.5 * exp(-fract(beat) * 6.0) + bar * 3.0 * bar_pulse;
}

void fragment() {
	ALBEDO = mix(pole_color, light_color, is_light);
	EMISSION = light_color * is_light * strength;
	ROUGHNESS = 0.8;
}
