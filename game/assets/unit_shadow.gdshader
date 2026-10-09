shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
uniform float opacity = 0.3;
void fragment() {
	float distance_from_center = length((UV - vec2(0.5)) * 2.0);
	ALBEDO = vec3(0.025, 0.035, 0.035);
	ALPHA = (1.0 - smoothstep(0.25, 1.0, distance_from_center)) * opacity;
}
