// Billboard para partículas (mira siempre a la cámara, respeta escala y rotación
// de la partícula). Igual al que genera StandardMaterial3D en modo PARTICLES.

void billboard_vertex(inout mat4 modelview, mat4 view, mat4 inv_view, mat4 model, float angle) {
	mat4 world = mat4(normalize(inv_view[0]), normalize(inv_view[1]), normalize(inv_view[2]), model[3]);
	world = world * mat4(vec4(cos(angle), -sin(angle), 0.0, 0.0), vec4(sin(angle), cos(angle), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	modelview = view * world;
	modelview = modelview * mat4(vec4(length(model[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(model[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(model[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
