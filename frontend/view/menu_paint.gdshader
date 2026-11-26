shader_type canvas_item;
uniform float motion = 1.0;
uniform float sweep : hint_range(0.0,1.0) = 1.0;
uniform sampler2D stroke_order : filter_linear, repeat_disable;
void fragment() {
	vec2 p = UV - .5;
	float phase = TIME*.48;
	vec2 drift = vec2(sin(phase+UV.y*9.),cos(phase*.81+UV.x*8.));
	vec2 uv = UV + motion*drift*dot(p,p)*.009;
	vec4 ink = texture(TEXTURE,uv);
	float age = sweep*1.18-.09-texture(stroke_order,uv).r;
	float coat = smoothstep(-.078,.078,age);
	float wet = 1.-smoothstep(.015,.080,age);
	COLOR = vec4(ink.rgb*(1.+wet*.22),ink.a*coat);
}
