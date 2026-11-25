shader_type canvas_item;
render_mode unshaded;

uniform float progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float envelope = sin(progress * 3.14159265);
	float scan_y = mix(0.12, 0.88, progress);
	float accent = 1.0 - smoothstep(0.0, 0.055, abs(UV.y - scan_y));
	COLOR.rgb += vec3(0.20, 0.37, 0.34) * accent * envelope * COLOR.a;
}
