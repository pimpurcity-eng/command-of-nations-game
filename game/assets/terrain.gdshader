shader_type spatial;
render_mode unshaded, specular_disabled;
// Province colour of the owner (set by StrategicMap: sand = player, green = others).
uniform vec4 country_tint : source_color = vec4(0.3,0.6,0.5,1.0);
uniform float forest_density = 0.2;
uniform float dryness = 0.3;
uniform float wetness = 0.0;
uniform sampler2D land_detail : filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool selected = false;
uniform bool hostile = false;
uniform bool fog_enabled = false;
uniform sampler2D visibility_mask : filter_linear, repeat_disable;
// Kept for compatibility; terrain_weights replaces the nearest-filtered index lookups that
// produced square pixel edges.
uniform sampler2D terrain_types : filter_nearest, repeat_disable;
// R forest, G hills, B mountains, A desert (linear filtered, pre-blurred).
uniform sampler2D terrain_weights : filter_linear, repeat_disable;
// Natural Earth shaded relief for the same extent (flat land ~ 0.80).
uniform sampler2D relief : filter_linear_mipmap, repeat_disable;
uniform bool blank_context = false;
uniform float ownership_strength = 0.18;
// Call of War style: political colours are strong when zoomed out, subtle up close.
uniform float political = 0.0;
// Conquered (non-core) province: diagonal stripes.
uniform bool occupied = false;
uniform vec2 city_points[12];
uniform int city_count = 0;
uniform float time_scale = 0.0;
varying vec3 world;
varying float altitude;
varying float slope;

const vec2 MAP_ORIGIN = vec2(-24.0, -27.0);
const vec2 MAP_EXTENT = vec2(50.0, 48.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	mat2 r = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 4; i++) { v += a * noise(p); p = r * p * 2.03; a *= 0.5; }
	return v;
}
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// The mesh is flat; the virtual altitude comes in the vertex colour (strategic_map.gd).
	altitude = COLOR.r * 4.0;
	slope = 1.0 - NORMAL.y;
}
void fragment() {
	vec2 p = world.xz;
	vec2 uv = (p - MAP_ORIGIN) / MAP_EXTENT;
	// Domain-warp the lookup so terrain borders follow organic, irregular lines.
	vec2 warp = (vec2(fbm(p * 0.9), fbm(p * 0.9 + 17.3)) - 0.5) * 0.012;
	vec4 w = texture(terrain_weights, uv + warp);
	float edge_noise = fbm(p * 2.2) * 0.35;
	float forest = smoothstep(0.30, 0.62, w.r + edge_noise - 0.17);
	// Hills and mountains follow the real relief: ruggedness = local variation of the
	// shaded relief, so uplands have natural outlines instead of the rule boxes' rectangles.
	vec2 texel = vec2(1.5) / vec2(textureSize(relief, 0));
	float r0 = texture(relief, uv).r;
	float rugged = abs(texture(relief, uv + vec2(texel.x, 0.0)).r - r0) + abs(texture(relief, uv + vec2(0.0, texel.y)).r - r0)
		+ abs(texture(relief, uv - vec2(texel.x, 0.0)).r - r0) + abs(texture(relief, uv - vec2(0.0, texel.y)).r - r0);
	float hills = clamp(smoothstep(0.03, 0.10, rugged) * 0.8 + w.g * 0.25, 0.0, 1.0);
	float mountains = clamp(smoothstep(0.12, 0.30, rugged) * smoothstep(0.1, 0.6, w.b + w.g * 0.4 + rugged), 0.0, 1.0);
	float desert = smoothstep(0.30, 0.65, w.a + edge_noise - 0.17);

	// Two detail scales rotated against each other so the texture never shows a tiling grid.
	vec3 d1 = texture(land_detail, p * 0.31).rgb;
	vec3 d2 = texture(land_detail, mat2(vec2(0.6, 0.8), vec2(-0.8, 0.6)) * p * 0.083 + 0.37).rgb;
	float fine = mix(d1.r, d2.g, 0.5);
	float macro = fbm(p * 0.22);

	// Plains / steppe: soft patchwork of greens and harvested khaki, no hard field edges.
	vec3 lush = vec3(0.50, 0.56, 0.37);
	vec3 dry = vec3(0.74, 0.70, 0.50);
	float patches = smoothstep(0.35, 0.75, fbm(p * 1.6 + 3.1));
	vec3 color = mix(lush, dry, clamp(dryness * 0.8 + patches * 0.45 + (macro - 0.5) * 0.5, 0.0, 1.0));
	color *= 0.90 + fine * 0.22;

	// Forest: dark canopy with clearings.
	float canopy = fbm(p * 7.0);
	vec3 woods = mix(vec3(0.24, 0.33, 0.21), vec3(0.36, 0.44, 0.27), canopy);
	color = mix(color, woods, forest * (0.82 + canopy * 0.18));

	// Hills: olive-tan uplands.
	color = mix(color, vec3(0.62, 0.60, 0.43) * (0.9 + fine * 0.2), hills * 0.55);
	// Mountains: rock and snow on the high ridges.
	vec3 rock = mix(vec3(0.46, 0.43, 0.37), vec3(0.70, 0.66, 0.57), fine);
	color = mix(color, rock, mountains * 0.85);
	color = mix(color, vec3(0.90, 0.91, 0.92), smoothstep(3.0, 3.9, altitude) * mountains * (0.5 + fine * 0.4));
	// Desert: pale sand with wind ripples (smooth sine ripples, warped by noise).
	float ripple = sin((p.x * 0.8 + p.y * 0.35) * 9.0 + fbm(p * 1.3) * 9.0) * 0.5 + 0.5;
	vec3 sand = mix(vec3(0.80, 0.70, 0.53), vec3(0.88, 0.79, 0.62), ripple * 0.6 + fine * 0.4);
	color = mix(color, sand, desert * 0.9);
	// Wet lowland tint where the province profile asks for it.
	color = mix(color, vec3(0.33, 0.42, 0.33), wetness * 0.25 * (1.0 - mountains));

	// Urban ground around city centres (soft round districts, not squares).
	float urban = 0.0;
	for (int i = 0; i < 12; i++) {
		if (i >= city_count) break;
		float dist = length(p - city_points[i]) + (fbm(p * 3.0 + float(i)) - 0.5) * 0.25;
		urban = max(urban, 1.0 - smoothstep(0.35, 0.75, dist));
	}
	color = mix(color, mix(vec3(0.55, 0.51, 0.46), vec3(0.70, 0.64, 0.56), fine), urban * 0.8);

	// Real relief shading (Carpathians, Crimea, Caucasus, Donets ridge, river valleys).
	float shade = texture(relief, uv).r / 0.80;
	float relief_strength = 0.55 + hills * 0.30 + mountains * 0.35;
	color *= clamp(mix(1.0, shade, relief_strength), 0.62, 1.3);

	// Political colour (Call of War): sand = yours, green = other nations, red = at war.
	vec3 political_color = hostile ? vec3(0.74, 0.36, 0.31) : country_tint.rgb;
	float tint = clamp(ownership_strength * 0.65 + political * 0.55, 0.0, 0.78);
	if (hostile) tint = clamp(0.30 + political * 0.40, 0.0, 0.75);
	color = mix(color, political_color * (0.82 + 0.25 * shade), tint);

	// Conquered territory: wide diagonal stripes, anti-aliased.
	if (occupied) {
		float s = fract((p.x + p.y) * 1.6);
		float aa = fwidth((p.x + p.y) * 1.6) * 1.5;
		float stripe = smoothstep(0.5 - aa, 0.5 + aa, s) * (1.0 - smoothstep(1.0 - aa, 1.0, s));
		color = mix(color, color * 1.18 + 0.04, stripe * 0.6);
	}
	if (selected) color = mix(color, vec3(0.95, 0.80, 0.36), 0.22);
	if (fog_enabled) {
		float visibility = texture(visibility_mask, uv).r;
		float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));
		color = mix(vec3(luminance) * vec3(0.64, 0.68, 0.70), color, visibility);
	}
	vec3 context = mix(vec3(0.44, 0.50, 0.40), vec3(0.52, 0.57, 0.46), fine) * clamp(mix(1.0, shade, 0.6), 0.6, 1.3);
	ALBEDO = blank_context ? context : color;
	ROUGHNESS = 0.94;
}
