shader_type sky;
// Atardecer en el desierto: degradé, sol (la luz direccional 0) y una cadena de
// montañas lejanas pintada en el cielo, sin geometría.

#include "res://shaders/noise.gdshaderinc"

uniform vec3 top_color : source_color = vec3(0.1, 0.08, 0.25);
uniform vec3 mid_color : source_color = vec3(0.75, 0.3, 0.32);
uniform vec3 horizon_color : source_color = vec3(1.0, 0.6, 0.32);
uniform vec3 sun_color : source_color = vec3(1.0, 0.82, 0.5);
uniform vec3 mountain_color : source_color = vec3(0.32, 0.16, 0.22);
uniform float sun_radius = 0.06;

void sky() {
	vec3 dir = EYEDIR;
	float y = dir.y;
	vec3 col = mix(horizon_color, mid_color, smoothstep(0.0, 0.18, y));
	col = mix(col, top_color, smoothstep(0.12, 0.65, y));
	if (LIGHT0_ENABLED) {
		float sd = dot(dir, LIGHT0_DIRECTION);
		col += sun_color * pow(max(sd, 0.0), 6.0) * 0.45;
		float disk = smoothstep(cos(sun_radius), cos(sun_radius * 0.92), sd);
		// Franjas horizontales en la mitad de abajo del sol.
		float below = dir.y - LIGHT0_DIRECTION.y;
		float stripes = step(0.5, fract(below * 160.0)) * step(below, 0.0);
		col = mix(col, sun_color * 2.2, disk * (1.0 - stripes * smoothstep(0.0, -sun_radius, below)));
	}
	vec2 around = normalize(dir.xz + vec2(1e-4)) * 3.0;
	float ridge = 0.015 + fbm(around * 1.7) * 0.07 + vnoise(around * 9.0) * 0.008;
	float mountain = 1.0 - smoothstep(ridge - 0.002, ridge + 0.002, y);
	vec3 far_hills = mix(mountain_color, horizon_color, 0.35);
	col = mix(col, far_hills, mountain);
	if (y < 0.0) {
		col = mix(mountain_color, horizon_color * 0.7, 0.5);
	}
	COLOR = col;
}
