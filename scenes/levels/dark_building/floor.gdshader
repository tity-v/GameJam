shader_type canvas_item;
varying vec2 pos;
void vertex(){ pos = (MODEL_MATRIX * vec4(VERTEX,0.,1.)).xy; }
void fragment(){
 vec4 tile = texture(TEXTURE,UV);
 vec2 p = floor(pos);
 float course = floor(p.y/32.);
 float joint = mod(p.x+mod(course,2.)*48.,96.);
 vec3 ink = mix(vec3(0.028,0.058,0.059),vec3(0.52,0.60,0.53),smoothstep(0.19,0.82,tile.r));
 if(abs(tile.r-0.337)<0.005 && (joint<2. || mod(p.y,32.)>29.)) ink *= 0.61;
 COLOR = vec4(ink,tile.a);
}
