shader_type spatial;
render_mode specular_disabled;
uniform vec4 facade : source_color = vec4(0.70,0.67,0.61,1.0);
varying vec3 facade_normal;
void vertex() { facade_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL); }
void fragment() {
 vec2 grid=UV*vec2(5.0,4.0);
 vec2 pane=fract(grid);
 float windows=step(0.22,pane.x)*step(pane.x,0.69)*step(0.28,pane.y)*step(pane.y,0.64);
 // Derivatives suppress tiny facade lines at regional zoom to prevent sparkle.
 float detail=1.0-smoothstep(0.18,0.45,max(fwidth(grid.x),fwidth(grid.y)));
 windows*=detail*(1.0-step(0.65,abs(facade_normal.y)));
 vec3 glass=mix(vec3(0.16,0.20,0.22),vec3(0.34,0.39,0.40),pane.y);
 ALBEDO=mix(facade.rgb,glass,windows*0.75);
 ROUGHNESS=0.90;
}
