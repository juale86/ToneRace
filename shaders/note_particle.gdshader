shader_type spatial;
// Corchea de luz (♪) para las partículas que suben al agarrar una nota.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

#include "res://shaders/billboard.gdshaderinc"

void vertex() {
	billboard_vertex(MODELVIEW_MATRIX, VIEW_MATRIX, INV_VIEW_MATRIX, MODEL_MATRIX, INSTANCE_CUSTOM.x);
}

float note_shape(vec2 p) {
	// Cabeza: elipse inclinada abajo a la izquierda.
	vec2 h = p - vec2(0.4, 0.74);
	float a = radians(-25.0);
	h = mat2(vec2(cos(a), -sin(a)), vec2(sin(a), cos(a))) * h;
	float head = length(h / vec2(0.17, 0.115)) - 1.0;
	// Plica: barra vertical a la derecha de la cabeza.
	float stem = max(abs(p.x - 0.55) - 0.035, max(0.16 - p.y, p.y - 0.72));
	// Corchete: arco que baja desde la punta de la plica.
	vec2 f = p - vec2(0.55, 0.42);
	float ring = abs(length(f / vec2(0.22, 0.26)) - 1.0) - 0.16;
	float flag = max(ring, max(-f.x, f.y));
	float d = min(head * 0.12, min(stem, flag * 0.2));
	float aa = fwidth(d);
	return 1.0 - smoothstep(-aa, aa, d);
}

void fragment() {
	float shape = note_shape(UV);
	float glow = pow(max(1.0 - length(UV - vec2(0.48, 0.55)) * 2.4, 0.0), 2.0) * 0.3;
	ALBEDO = COLOR.rgb * 2.5;
	ALPHA = (shape + glow) * COLOR.a;
}
