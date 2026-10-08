shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform vec4 route_color : source_color = vec4(0.96,0.79,0.44,1.0);
void fragment() {
 float stripe=fract(UV.x*3.0-TIME*0.65);
 if (stripe>0.67) discard;
 ALBEDO=route_color.rgb;
}
