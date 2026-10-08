shader_type spatial;
// Call of War style orders: animated two-tone dashed path with an arrowhead for moves,
// red arc for attacks. Widths are in screen pixels (UV2 holds the pixel offset), so paths
// read the same at every zoom level.
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, depth_test_disabled;
uniform vec4 route_color : source_color = vec4(0.97, 0.83, 0.42, 1.0);
uniform vec4 route_dark : source_color = vec4(0.33, 0.26, 0.15, 1.0);
uniform vec4 attack_color : source_color = vec4(0.88, 0.24, 0.19, 1.0);
varying vec4 kind;
void vertex() {
	float view_depth = abs((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z);
	float units_per_pixel = 2.0 * view_depth / max(abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y, 1.0);
	VERTEX.xz += UV2 * units_per_pixel;
	kind = COLOR;
}
void fragment() {
	// kind.r: 1 = move, 0 = attack; kind.g: 1 = selected army; kind.b: 1 = arrowhead
	bool move = kind.r > 0.5;
	vec3 bright = move ? route_color.rgb : attack_color.rgb;
	vec3 dark = move ? route_dark.rgb : attack_color.rgb * 0.5;
	vec3 color = bright;
	if (kind.b < 0.5) {
		float dash = fract(UV.x * 2.4 - TIME * 0.9);
		color = dash < 0.55 ? bright : dark;
		// thin dark outline along both edges
		color = mix(color, dark * 0.6, smoothstep(0.65, 0.95, abs(UV.y)));
	}
	ALBEDO = color;
	ALPHA = kind.g > 0.5 ? 1.0 : 0.82;
}
