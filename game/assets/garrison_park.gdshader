shader_type spatial;
render_mode unshaded;
// Owner 2026-10-14: the city centre under a garrison is a green park with footpaths, not grey paving.
uniform vec2 half_size = vec2(0.65, 0.625);
varying vec2 local_position;
void vertex() { local_position = VERTEX.xz; }
float band(float d, float w) { float aa = max(fwidth(d), 0.002); return 1.0 - smoothstep(w - aa, w + aa, abs(d)); }
void fragment() {
 vec2 p = local_position / half_size;
 // Owner 2026-10-15: round, not square.
 if (length(p) > 1.0) discard;
 float n = fract(sin(dot(floor(local_position * 40.0), vec2(12.9898, 78.233))) * 43758.5453);
 vec3 grass = mix(vec3(0.33, 0.45, 0.24), vec3(0.38, 0.51, 0.27), n);
 // Footpaths: a cross, a diagonal and a loop round a small central fountain plaza.
 float path = max(band(p.x, 0.035), band(p.y, 0.035));
 path = max(path, band(length(p) - 0.55, 0.03));
 path = max(path, band(p.x - p.y, 0.03) * step(0.62, length(p)));
 float plaza = 1.0 - smoothstep(0.14, 0.15, length(p));
 float water = 1.0 - smoothstep(0.07, 0.08, length(p));
 // Kerb round the park edge.
 float edge = 1.0 - smoothstep(0.93, 0.95, length(p));
 vec3 colour = mix(grass, vec3(0.72, 0.70, 0.64), max(path, plaza));
 colour = mix(colour, vec3(0.36, 0.55, 0.66), water);
 colour = mix(vec3(0.55, 0.56, 0.55), colour, edge);
 ALBEDO = colour;
 ROUGHNESS = 1.0;
}
