// Ruido de valor 2D barato, compartido por los shaders del mundo.

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.03) * 0.3 + vnoise(p * 4.1) * 0.15;
}

// Cobertura suavizada de una línea de media anchura w a distancia d (sin serrucho).
float aa_line(float d, float w) {
	float aa = max(fwidth(d), 1e-4);
	return (1.0 - smoothstep(w - aa, w + aa, d)) * clamp(w / aa, 0.0, 1.0);
}
