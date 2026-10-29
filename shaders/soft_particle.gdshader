shader_type spatial;
// Mancha redonda y suave mirando a la cámara (destellos, chispas, polvo). El color
// sale del de la partícula (COLOR) por el uniform color; boost > 1 hace que brille.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

#include "res://shaders/billboard.gdshaderinc"

uniform vec3 color : source_color = vec3(1.0);
uniform float boost = 2.0;
uniform float fade = 1.0;

void vertex() {
	billboard_vertex(MODELVIEW_MATRIX, VIEW_MATRIX, INV_VIEW_MATRIX, MODEL_MATRIX, INSTANCE_CUSTOM.x);
}

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float soft = pow(clamp(1.0 - r, 0.0, 1.0), 1.6);
	ALBEDO = COLOR.rgb * color * boost;
	ALPHA = soft * COLOR.a * fade;
}
