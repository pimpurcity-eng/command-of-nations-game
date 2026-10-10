shader_type spatial;
render_mode specular_disabled;
uniform sampler2D coast_mask : filter_linear, repeat_disable;
varying vec3 world;
void vertex() { world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 vec2 uv=(world.xz+vec2(60.0))/120.0;
 vec4 coast=texture(coast_mask,clamp(uv,vec2(0),vec2(1)));
 float distance_to_land=coast.g*8.0;
 vec3 sea=mix(vec3(0.22,0.43,0.47),vec3(0.09,0.24,0.31),smoothstep(0.0,2.6,distance_to_land));
 float wave_a=world.x*14.0+world.z*8.0+TIME*0.4;
 float wave_b=world.z*21.0-TIME*0.3;
 float wave_detail=1.0-smoothstep(0.7,2.5,max(fwidth(wave_a),fwidth(wave_b)));
 float ripple=sin(wave_a)*sin(wave_b)*wave_detail;
 float broad=sin(world.x*1.7+world.z*0.8+TIME*0.15);
 sea+=(ripple*0.004+broad*0.003)*vec3(0.7,1.0,1.0);
 // The province meshes now cover all land exactly, so the sea never paints land itself.
 // (The coast mask comes from a different, pixelated source; drawing it showed black
 // wedges and stair-stepped coastlines where it disagreed with the province outlines.)
 ALBEDO=sea;
 // Subtle broad waves remain stable at regional zoom.
 NORMAL=normalize(NORMAL+vec3(sin(world.x*1.7+TIME*0.15)*0.035,0.0,cos(world.z*1.3-TIME*0.12)*0.035));
 ROUGHNESS=0.82;
}
