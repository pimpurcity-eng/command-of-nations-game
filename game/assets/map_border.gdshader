shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 ink : source_color = vec4(0.23,0.25,0.22,0.85);
uniform float width_pixels = 1.0;
void vertex() {
 float view_depth = abs((MODELVIEW_MATRIX * vec4(VERTEX,1.0)).z);
 float units_per_pixel = 2.0*view_depth/max(abs(PROJECTION_MATRIX[1][1])*VIEWPORT_SIZE.y,1.0);
 VERTEX.xz += UV2 * UV.x * units_per_pixel * width_pixels;
}
void fragment() {
 float edge = abs(UV.x);
 float feather = max(fwidth(edge),0.08);
 ALBEDO = ink.rgb;
 ALPHA = ink.a*(1.0-smoothstep(1.0-feather,1.0,edge));
}
