shader_type spatial;
render_mode unshaded;
varying vec2 paving_position;
void vertex() { paving_position = VERTEX.xz; }
void fragment() {
 vec2 p = paving_position * 10.0;
 vec2 f = fract(p);
 vec2 aa = max(fwidth(p), vec2(0.004));
 vec2 joints = smoothstep(vec2(0.025)-aa, vec2(0.025)+aa, min(f,1.0-f));
 float slab = joints.x*joints.y;
 ALBEDO = mix(vec3(0.18,0.20,0.22),vec3(0.30,0.32,0.34),slab);
 ROUGHNESS = 1.0;
}
