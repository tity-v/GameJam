shader_type canvas_item;

uniform bool night = false;
varying vec2 world_px;

void vertex() {
	world_px = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float variation(vec2 cell) {
	return fract(sin(dot(cell, vec2(23.13, 71.71))) * 4375.17);
}

void fragment() {
	vec4 tile = texture(TEXTURE, UV);
	vec3 color = tile.rgb;
	bool field = abs(color.r - 86.0/255.0) < 0.005;
	if (night) {
		// 月光照亮磨损的踏面，梁底的钢带沉入暗部。
		color = mix(vec3(0.135,0.132,0.205),vec3(0.72,0.71,0.83),clamp((tile.r-0.19)*1.56,0.0,1.0));
	}
	if (field) {
		vec2 p = floor(world_px);
		float course = floor(p.y/32.0);
		float length_px = night ? 96.0 : 112.0;
		vec2 shifted = p + vec2(mod(course,2.0)*length_px*0.5,0.0);
		vec2 block = floor(shifted / vec2(length_px,32.0));
		vec2 local = mod(shifted,vec2(length_px,32.0));
		float age = variation(block);
		color = night ? vec3(0.32,0.315,0.438) : vec3(0.365,0.425,0.468);
		color += (age-0.5) * (night ? 0.070 : 0.035);
		if (local.y >= 30.0 || local.x < 2.0) {
			color *= 0.79;
		} else if (local.y == 0.0 || local.x == 2.0) {
			color *= 1.07;
		}
		// 浇筑孔成对排布。夜站少数混凝土板局部剥落，露出骨料与旧砌砖。
		if ((local.x>=9.0 && local.x<12.0 || local.x>=length_px-12.0 && local.x<length_px-9.0) && local.y>=21.0 && local.y<23.0) {
			color *= 0.72;
		}
		if (night && age>0.73) {
			float seed = variation(block + vec2(9.0,4.0));
			vec2 chip = local - floor(vec2(20.0+seed*44.0,8.0+age*7.0));
			float width = 7.0 + seed*12.0;
			float slope = floor(chip.x*0.22);
			if (abs(chip.x)<width && chip.y>=slope && chip.y<slope+5.0-floor(abs(chip.x)*0.13)) {
				color = vec3(0.30,0.27,0.335);
				if (chip.y==slope) {
					color = vec3(0.395,0.361,0.422);
				}
			}
		}
	}
	COLOR = vec4(color,tile.a);
}
