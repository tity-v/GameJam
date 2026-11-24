shader_type canvas_item;

uniform vec4 sources[32];
uniform int count = 0;
uniform float drift = 0.0;
// 由内向外衰减曲线。1.0 = 线性（原行为）；越大中心越保、外圈越早暗。
uniform float falloff = 1.0;
varying vec2 location;

float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float brush_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 t = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), t.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), t.x), t.y);
}

void vertex() {
	location = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float opening = 0.0;
	for (int i = 0; i < count; i++) {
		vec4 s = sources[i];
		float raw = clamp((s.w - distance(location, s.xy)) / max(0.01, s.w - s.z), 0.0, 1.0);
		opening = max(opening, pow(raw, falloff));
	}
	vec3 paint = vec3(0.0);
	float coverage = 1.0 - opening;
	if (opening > 0.0 && opening < 1.0) {
		// 大笔块决定轮廓，斜向窄笔束和刷毛只在过渡带内留痕。
		vec2 p = location + vec2(sin(drift * 0.55), cos(drift * 0.39)) * 2.0;
		vec2 brush = vec2(dot(p, vec2(0.91, -0.41)), dot(p, vec2(0.41, 0.91)));
		float patch = brush_noise(p / 28.0);
		float stroke = brush_noise(brush / vec2(24.0, 3.4));
		float hair = brush_noise(brush / vec2(13.0, 1.3));
		float t = opening + opening * (1.0 - opening) *
			((patch - 0.5) * 1.9 + (stroke - 0.5) * 1.35 + (hair - 0.5) * 0.45);
		float reveal = 0.24 * smoothstep(0.08, 0.17, t)
			+ 0.40 * smoothstep(0.32, 0.43, t) + 0.36 * smoothstep(0.65, 0.83, t);
		coverage = 1.0 - reveal;
		paint = vec3(0.085, 0.091, 0.093) * (0.3 + 0.7 * stroke) * sin(3.14159 * reveal);
	}
	COLOR = vec4(paint, coverage);
}
