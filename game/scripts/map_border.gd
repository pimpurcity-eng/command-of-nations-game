class_name MapBorder
extends RefCounted
static func build(rings: Array, terrain: StrategicMap, width: float, color: Color) -> MeshInstance3D:
	var surface: = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments: = 0
	for poly: PackedVector2Array in rings:
		for i in poly.size():
			var a: = poly[i]
			var b: = poly[(i + 1) % poly.size()]
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
