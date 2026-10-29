shader_type canvas_item;
// Líneas de velocidad en los bordes de la pantalla; más y más rápidas con el tempo.

global uniform float speed;  // 0 = marcha más baja, 1 = la más alta
uniform float rays = 260.0;

float hash(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

void fragment() {
	vec2 d = UV - vec2(0.5, 0.45);
	d.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float r = length(d);
	float cell = floor((atan(d.y, d.x) / 6.2831853 + 0.5) * rays);
	float present = step(1.0 - (0.08 + 0.22 * speed), hash(cell));
	float seg = fract(r * 1.4 - TIME * (0.8 + 2.4 * speed) - hash(cell + 3.1) * 7.0);
	float dash = smoothstep(0.0, 0.05, seg) * smoothstep(0.3, 0.1, seg);
	float edge = smoothstep(0.35, 0.8, r);
	COLOR = vec4(1.0, 0.92, 0.8, present * dash * edge * (0.06 + 0.24 * speed * speed));
}
