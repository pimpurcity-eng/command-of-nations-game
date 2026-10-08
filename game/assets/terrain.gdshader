shader_type spatial;
render_mode unshaded, specular_disabled;
uniform vec4 country_tint : source_color = vec4(0.3,0.6,0.5,1.0);
uniform float forest_density = 0.2;
uniform float dryness = 0.3;
uniform float wetness = 0.0;
uniform sampler2D land_detail : filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool selected = false;
uniform bool hostile = false;
uniform bool fog_enabled = false;
uniform sampler2D visibility_mask : filter_linear, repeat_disable;
uniform sampler2D terrain_types : filter_nearest, repeat_disable;
uniform bool blank_context = false;
uniform float ownership_strength = 0.18;
varying vec3 world;
varying float altitude;
varying float slope;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() {
 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 altitude=VERTEX.y; slope=1.0-NORMAL.y;
}
void fragment() {
 float terrain=floor(texture(terrain_types,(world.xz-vec2(-24.0,-27.0))/vec2(50.0,48.0)).r*255.0+0.5);
 float is_forest=1.0-step(0.5,abs(terrain-1.0));
 float is_hills=1.0-step(0.5,abs(terrain-2.0));
 float is_mountain=1.0-step(0.5,abs(terrain-3.0));
 float is_urban=1.0-step(0.5,abs(terrain-4.0));
 float is_wet=1.0-step(0.5,abs(terrain-5.0));
 float macro=noise(world.xz*0.36);
 vec3 detail=texture(land_detail,world.xz*0.35).rgb;
 float fine=detail.r*0.72+detail.g*0.28;
 vec3 meadow=mix(vec3(0.48,0.53,0.36),vec3(0.74,0.73,0.52),fine);
 float woodland=is_forest*(0.65+macro*0.35);
 meadow=mix(meadow,vec3(0.73,0.65,0.45)*(0.8+fine*0.4),dryness*0.65);
 vec3 color=mix(meadow,vec3(0.30,0.39,0.25)*(0.85+fine*0.30),woodland*(0.60+detail.b*0.30));
 vec2 field_uv=mat2(vec2(0.86,0.5),vec2(-0.5,0.86))*world.xz*2.4;
 vec2 cell=floor(field_uv);vec2 local=fract(field_uv);
 float field=hash(cell);
 float farmland=(1.0-max(max(is_forest,is_mountain),max(is_wet,is_urban)))*smoothstep(0.35,0.5,field)*(1.0-smoothstep(0.85,1.5,altitude));
 vec3 crop=mix(vec3(0.48,0.54,0.34),vec3(0.71,0.65,0.45),hash(cell+19.0));
 float furrow_phase=(field_uv.x+field_uv.y*0.2)*80.0;
 float furrows=sin(furrow_phase)*0.012*(1.0-smoothstep(0.5,2.0,fwidth(furrow_phase)));
 color=mix(color,crop+furrows,farmland*0.7);
 float edge_distance=min(min(local.x,local.y),min(1.0-local.x,1.0-local.y));
 float edge_width=max(0.012,fwidth(field_uv.x)+fwidth(field_uv.y));
 float hedgerow=1.0-smoothstep(0.0,edge_width,edge_distance);
 hedgerow*=1.0-smoothstep(0.08,0.25,edge_width);
 color=mix(color,vec3(0.21,0.28,0.13),hedgerow*farmland*0.35);
 vec3 rock=mix(vec3(0.45,0.43,0.35),vec3(0.73,0.67,0.55),fine);
 float rocky=max(is_mountain*(0.55+macro*0.3),is_hills*(0.15+macro*0.20));
 rocky=max(rocky,smoothstep(0.18,0.48,slope)*max(is_mountain,is_hills));
 color=mix(color,rock,rocky);
 color=mix(color,vec3(0.83,0.85,0.82),smoothstep(3.2,4.0,altitude)*(0.45+fine*0.4));
 color=mix(color,vec3(0.30,0.39,0.32)*(0.85+fine*0.25),is_wet*0.8);
 vec3 urban=mix(vec3(0.53,0.48,0.43),vec3(0.72,0.62,0.54),fine);
 color=mix(color,urban,is_urban*0.86);
 color=mix(color,country_tint.rgb,ownership_strength*0.65);
 if (selected) color=mix(color,vec3(0.90,0.76,0.34),0.28);
 if (fog_enabled) {
  float visibility=texture(visibility_mask,(world.xz-vec2(-24.0,-27.0))/vec2(50.0,48.0)).r;
  float luminance=dot(color,vec3(0.2126,0.7152,0.0722));
  color=mix(vec3(luminance)*vec3(0.64,0.68,0.70),color,visibility);
 }
 if (hostile) color=mix(color,vec3(0.64,0.27,0.23),0.42);
 ALBEDO=blank_context ? mix(vec3(0.38,0.43,0.34),vec3(0.47,0.51,0.41),fine) : color;
 ROUGHNESS=0.94;
}
