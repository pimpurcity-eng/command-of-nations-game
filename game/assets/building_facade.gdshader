shader_type spatial;
// Building facades with windows laid out in real floor heights and bays (model space), so
// a 30-storey tower shows 30 floors and a house shows two. Flat tops use the roof colour.
uniform vec4 facade : source_color = vec4(0.70, 0.67, 0.61, 1.0);
uniform vec4 glass : source_color = vec4(0.30, 0.38, 0.45, 1.0);
uniform vec4 roof : source_color = vec4(0.36, 0.37, 0.38, 1.0);
uniform float floor_height = 0.012;
uniform float bay_width = 0.011;
uniform float window_width = 0.5;
uniform float window_height = 0.5;
uniform float shine = 0.0;
varying vec3 local_position;
varying vec3 local_normal;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() {
	local_position = VERTEX;
	local_normal = NORMAL;
}
void fragment() {
	vec3 n = normalize(local_normal);
	if (abs(n.y) > 0.6) {
		ALBEDO = roof.rgb;
		ROUGHNESS = 0.92;
	} else {
		float across = abs(n.x) > abs(n.z) ? local_position.z : local_position.x;
		vec2 grid = vec2(across / bay_width, local_position.y / floor_height);
		vec2 cell = fract(grid);
		vec2 aa = fwidth(grid) * 0.8;
		float wx = smoothstep(0.5 - window_width * 0.5 - aa.x, 0.5 - window_width * 0.5 + aa.x, cell.x) * (1.0 - smoothstep(0.5 + window_width * 0.5 - aa.x, 0.5 + window_width * 0.5 + aa.x, cell.x));
		float wy = smoothstep(0.5 - window_height * 0.5 - aa.y, 0.5 - window_height * 0.5 + aa.y, cell.y) * (1.0 - smoothstep(0.5 + window_height * 0.5 - aa.y, 0.5 + window_height * 0.5 + aa.y, cell.y));
		float window_mask = wx * wy;
		float variation = hash(floor(grid));
		vec3 pane = glass.rgb * (0.82 + variation * 0.36);
		pane = mix(pane, vec3(0.78, 0.85, 0.9), shine * 0.25 * smoothstep(0.3, 1.0, cell.y));
		vec3 color = mix(facade.rgb, pane, window_mask);
		// When windows are smaller than a pixel, show their average instead of shimmering.
		float detail = 1.0 - smoothstep(0.35, 0.9, max(fwidth(grid.x), fwidth(grid.y)));
		vec3 average = mix(facade.rgb, glass.rgb, window_width * window_height);
		color = mix(average, color, detail);
		// Slight darkening toward the ground for depth.
		color *= 0.86 + 0.14 * smoothstep(0.0, 0.08, local_position.y);
		ALBEDO = color;
		ROUGHNESS = mix(0.9, 0.35, shine * window_mask);
		METALLIC = shine * 0.2 * window_mask;
	}
}
