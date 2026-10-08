class_name MapBorder
extends RefCounted
static func build(rings: Array, terrain: StrategicMap, width: float, color: Color) -> MeshInstance3D:
	var segments: Array = []
	for poly: PackedVector2Array in rings:
		for i in poly.size():
			segments.append([poly[i], poly[(i + 1) % poly.size()]])
	return build_segments(segments, terrain, width, color)
## Shared province edges appear in both neighbours' rings. Drawing them twice made borders
## look doubled (and twice as dark), so callers pass each edge once.
static func unique_segments(rings: Array) -> Array:
	var seen: Dictionary = {}
	var result: Array = []
	for poly: PackedVector2Array in rings:
		for i in poly.size():
			var a: = poly[i]
			var b: = poly[(i + 1) % poly.size()]
			var key: = _key(a, b)
			if seen.has(key): continue
			seen[key] = true
			result.append([a, b])
	return result
static func _key(a: Vector2, b: Vector2) -> String:
	var ka: = "%.4f,%.4f" % [a.x, a.y]
	var kb: = "%.4f,%.4f" % [b.x, b.y]
	return ka + "|" + kb if ka < kb else kb + "|" + ka
static func build_segments(segment_list: Array, terrain: StrategicMap, width: float, color: Color) -> MeshInstance3D:
	var surface: = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments: = 0
	for pair in segment_list:
		var a: Vector2 = pair[0]
		var b: Vector2 = pair[1]
		if a.distance_squared_to(b) < 1e-06: continue
		var normal: = Vector2( - (b - a).y, (b - a).x).normalized()
		var count: = maxi(1, ceili(a.distance_to(b) / 0.15))
		for j in count:
			var start: = a.lerp(b, j / float(count))
			var end: = a.lerp(b, (j + 1) / float(count))
			for vertex in [[start, -1.0], [start, 1.0], [end, 1.0], [start, -1.0], [end, 1.0], [end, -1.0]]:
				surface.set_uv(Vector2(vertex[1], 0))
				surface.set_uv2(normal)
				surface.set_normal(Vector3.UP)
				surface.add_vertex(terrain.position_at(vertex[0]) + Vector3.UP * 0.065)
			segments += 1
	var visual: = MeshInstance3D.new()
	if segments == 0: return visual
	visual.mesh = surface.commit()

	visual.extra_cull_margin = 0.5
	var material: = ShaderMaterial.new()
	material.shader = load("res://assets/map_border.gdshader")
	material.set_shader_parameter("width_pixels", width)
	material.set_shader_parameter("ink", color)
	visual.material_override = material
	visual.set_meta("border_segments", segments)
	return visual
