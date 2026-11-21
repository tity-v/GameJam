shader_type canvas_item;
varying vec2 world_px;

void vertex() {
	world_px = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 tile = texture(TEXTURE, UV);
	float value = dot(tile.rgb, vec3(0.299, 0.587, 0.114));
	vec2 p = floor(world_px);
	// 保留图集标出的踏面与透明区域，楼板侧面绘成错缝预制板。
	vec3 concrete = mix(vec3(0.285,0.35,0.405), vec3(0.42,0.49,0.55), smoothstep(0.34,0.77,value));
	float course = floor(p.y/32.0);
	vec2 seam = mod(p+vec2(mod(course,2.0)*48.0,0.0),vec2(96.0,32.0));
	if (seam.x < 2.0 || seam.y > 29.9) {concrete *= 0.83;}
	if (seam.x >= 8.0 && seam.x < 12.0 && seam.y >= 23.0 && seam.y < 26.0) {concrete *= 0.87;}
	if (value > 0.83) {concrete = vec3(0.80,0.84,0.87);}
	// 薄钢板保留一条连续的搪瓷亮边，在缩小窗口时也能看到落点。
	float row = mod(p.y,32.0);
	if (row < 8.0 && texture(TEXTURE, UV + vec2(0.0, 8.0)*TEXTURE_PIXEL_SIZE).a < 0.05) {
		concrete = row < 4.0 ? vec3(0.82,0.87,0.89) : vec3(0.28,0.35,0.41);
	}
	COLOR = vec4(concrete,tile.a);
}
