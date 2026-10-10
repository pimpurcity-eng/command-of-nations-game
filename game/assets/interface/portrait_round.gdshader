shader_type canvas_item;
void fragment() {
	vec2 dimensions = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 half_size = dimensions * 0.5;
	float radius = min(dimensions.x, dimensions.y) * 0.12;
	vec2 distance_to_edge = abs(UV * dimensions - half_size) - (half_size - vec2(radius));
	float edge = length(max(distance_to_edge, vec2(0.0))) + min(max(distance_to_edge.x, distance_to_edge.y), 0.0) - radius;
	COLOR.a *= 1.0 - smoothstep(-1.5, 0.5, edge);
}
