shader_type canvas_item;
varying vec2 station_position;

float noise_cell(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 4375.5453);
}
void vertex() {
	station_position = VERTEX;
}
void fragment() {
	vec2 p = floor(station_position / 3.0);
	vec3 sky = mix(vec3(0.055,0.048,0.16),vec3(0.30,0.19,0.43),clamp(p.y/235.0,0.0,1.0));
	vec2 cell = floor(p/8.0);
	float star = step(0.91,noise_cell(cell)) * (1.0-step(1.0,length(mod(p,8.0)-vec2(3.0))));
	sky += star * mix(vec3(0.25,0.32,0.47),vec3(0.53,0.35,0.54),noise_cell(cell+vec2(4.0)));
	// 少数较亮的星在小窗口下也看得清，只出现在山脊上方。
	vec2 sector = floor(p / 29.0);
	vec2 seed = vec2(noise_cell(sector + vec2(5.0)), noise_cell(sector + vec2(17.0)));
	vec2 offset = abs(mod(p, 29.0) - floor(3.0 + seed * 23.0));
	if (seed.x > 0.66 && min(offset.x, offset.y) < 0.5 && max(offset.x, offset.y) <= 1.0) {
		sky += vec3(0.56, 0.57, 0.69) / (1.0 + 2.0 * max(offset.x, offset.y));
	}
	float veil = sin(p.x*0.022)+0.5*sin(p.x*0.053+1.6)+0.45*sin(p.y*0.09);
	float ribbon = p.y - 42.0 - 10.0*veil;
	if (abs(ribbon) < 8.0 + 4.0*veil) { sky += vec3(0.025,0.018,0.045); }
	if (abs(ribbon + 13.0) < 2.0) { sky += vec3(0.015,0.011,0.035); }
	float ridge = 108.0 + abs(mod(p.x+31.0,107.0)-53.5)*0.70 + abs(mod(p.x,39.0)-19.5)*0.34;
	if (p.y > ridge) {sky = vec3(0.126,0.105,0.239);}
	float ruins = 148.0+floor(noise_cell(vec2(floor(p.x/13.0),0.0))*7.0)*4.0;
	if (p.y>ruins) {sky = vec3(0.089,0.078,0.185);}
	if (p.y>ruins+3.0 && mod(p.x,13.0)>3.0 && mod(p.x,13.0)<6.0 && mod(p.y,8.0)<2.0 && noise_cell(floor(p/vec2(13.0,8.0)))>0.67) {
		sky += vec3(0.075,0.055,0.09);
	}
	COLOR = vec4(sky,1.0);
}
