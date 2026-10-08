shader_type spatial;
// Su-57-inspired blue camouflage for Russian equipment. The pattern is projected
// triplanar in model space, so it works on any original model regardless of its UVs.
// If the model had its own texture, that texture's light/dark detail (tracks, panel lines,
// shadows baked into the paint) is kept and only the paint colour changes.
uniform sampler2D camo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D original : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_original = false;
uniform vec4 original_tint : source_color = vec4(1.0);
uniform float tiles = 2.0;
uniform float roughness_value = 0.7;
varying vec3 object_pos;
varying vec3 object_normal;
void vertex() {
	object_pos = VERTEX;
	object_normal = NORMAL;
}
vec3 triplanar(vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= max(w.x + w.y + w.z, 0.0001);
	return texture(camo, p.zy * tiles).rgb * w.x + texture(camo, p.xz * tiles).rgb * w.y + texture(camo, p.xy * tiles).rgb * w.z;
}
void fragment() {
	vec3 paint = triplanar(object_pos, normalize(object_normal));
	if (use_original) {
		vec3 source = texture(original, UV).rgb * original_tint.rgb;
		float detail = dot(source, vec3(0.299, 0.587, 0.114));
		// Mid-tone paint becomes camouflage; very dark parts (tracks, tyres) stay dark.
		paint *= clamp(detail / 0.55, 0.18, 1.25);
		paint = mix(source, paint, smoothstep(0.08, 0.22, detail));
	}
	ALBEDO = paint;
	ROUGHNESS = roughness_value;
}
