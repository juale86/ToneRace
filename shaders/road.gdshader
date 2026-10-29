shader_type spatial;
// Ruta: asfalto, banquinas, líneas de carril, bordes y marcas de beat/compás.
// UV.x = desplazamiento lateral en unidades, UV.y = beat. Todo se calcula por
// píxel con bordes suavizados, así las líneas finas no titilan a lo lejos.

#include "res://shaders/noise.gdshaderinc"

uniform float half_width = 5.5;
uniform float lane_width = 2.2;
uniform float lanes = 5.0;
uniform float units_per_beat = 18.0;
uniform float beats_per_bar = 4.0;
uniform vec3 asphalt : source_color = vec3(0.09, 0.08, 0.09);
uniform vec3 gravel : source_color = vec3(0.45, 0.3, 0.2);
uniform vec3 lane_color : source_color = vec3(1.0, 0.88, 0.7);
uniform vec3 edge_color : source_color = vec3(1.0, 0.45, 0.1);
uniform vec3 bar_color : source_color = vec3(1.0, 0.6, 0.25);

void fragment() {
	float x = UV.x;
	float beat = UV.y;
	vec2 p = vec2(x, beat * units_per_beat);
	float ax = abs(x);
	float grain = vnoise(p * 2.5) * 0.6 + vnoise(p * 11.0) * 0.4;
	float on_road = 1.0 - smoothstep(half_width + 0.15, half_width + 0.3, ax);
	vec3 col = mix(gravel * (0.75 + 0.5 * grain), asphalt * (0.8 + 0.45 * grain), on_road);

	// Líneas de carril: continuas, con un trazo más brillante que arranca en cada beat.
	float f = (x + half_width) / lane_width;
	float k = round(f);
	float inner = step(0.5, k) * step(k, lanes - 0.5);  // k = 0 y k = lanes son los bordes
	float dash = 1.0 - smoothstep(0.4, 0.4 + max(fwidth(beat), 1e-4), fract(beat));
	float lane_line = aa_line(abs(f - k) * lane_width, 0.1) * inner * (0.6 + 0.4 * dash);
	float edge = aa_line(abs(ax - half_width), 0.13);
	float bar_z = abs(beat / beats_per_bar - round(beat / beats_per_bar)) * beats_per_bar * units_per_beat;
	float beat_z = abs(beat - round(beat)) * units_per_beat;
	float inside = on_road * (1.0 - edge);
	float bar = aa_line(bar_z, 0.35) * inside;
	float beat_mark = aa_line(beat_z, 0.1) * inside * (1.0 - bar);

	col = mix(col, lane_color, lane_line);
	col = mix(col, bar_color, bar * 0.7);
	col = mix(col, bar_color * 0.6, beat_mark * 0.35);
	col = mix(col, edge_color, edge);
	ALBEDO = col;
	ROUGHNESS = 0.85;
	EMISSION = lane_color * lane_line * 1.6 + edge_color * edge * 2.4 + bar_color * bar * 0.8;
}
