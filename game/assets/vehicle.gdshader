shader_type spatial;
uniform vec4 base_color : source_color = vec4(0.25,0.29,0.19,1.0);
varying vec3 local_position;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() { local_position=VERTEX; }
void fragment() {
 vec2 p=local_position.xz*7.0+local_position.y*vec2(3.0,2.0);
 float patch=noise(p);
 vec3 paint=base_color.rgb;
 paint=mix(paint,paint*0.52,smoothstep(0.54,0.60,patch));
 paint=mix(paint,vec3(0.34,0.31,0.22),1.0-smoothstep(0.30,0.36,patch));
 float dust=(1.0-smoothstep(0.15,0.4,local_position.y))*0.35;
 paint=mix(paint,vec3(0.30,0.27,0.21),dust);
 float grain=noise(local_position.xz*180.0+local_position.y*11.0);
 ALBEDO=paint*(0.94+grain*0.10);
 ROUGHNESS=0.76;
 METALLIC=0.12;
}
