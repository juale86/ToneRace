shader_type spatial;
// Props low-poly: color por instancia (MultiMesh) y caras planas.

void fragment() {
	ALBEDO = COLOR.rgb;
	NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	ROUGHNESS = 0.95;
}
