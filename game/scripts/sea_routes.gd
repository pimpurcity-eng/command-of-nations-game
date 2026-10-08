class_name SeaRoutes
extends RefCounted

const CELL: = 0.5
const LIMIT: = 59.0
var mask: Image
var graph: AStar2D
func on_sea(point: Vector2) -> bool:
	if absf(point.x) > LIMIT or absf(point.y) > LIMIT: return false
	if mask == null: mask = (load("res://assets/coast_mask.png") as Texture2D).get_image()
	var uv: = (point + Vector2(60, 60)) / 120.0
	return mask.get_pixel(clampi(int(uv.x * (mask.get_width() - 1)), 0, mask.get_width() - 1), clampi(int(uv.y * (mask.get_height() - 1)), 0, mask.get_height() - 1)).r < 0.5
func clear_segment(a: Vector2, b: Vector2) -> bool:
	var steps: = maxi(1, int(ceil(a.distance_to(b) / 0.05)))
	for i in range(steps + 1):
		if not on_sea(a.lerp(b, float(i) / steps)): return false
	return true
func find_path(start: Vector2, finish: Vector2) -> Array:
	if not on_sea(start) or not on_sea(finish): return []
	if clear_segment(start, finish): return [finish]
	if graph == null: _build_graph()
	graph.add_point(0, start)
	graph.add_point(1, finish)
	for index in graph.get_point_ids():
		if index < 2: continue
		var point: = graph.get_point_position(index)
		for endpoint in [0, 1]:
			var anchor: = start if endpoint == 0 else finish
			if anchor.distance_to(point) < CELL * 2 and clear_segment(anchor, point): graph.connect_points(endpoint, index)
	var result: Array = []
	for point in graph.get_point_path(0, 1): result.append(point)
	graph.remove_point(0)
	graph.remove_point(1)
	if not result.is_empty(): result.pop_front()

	var simplified: Array = []
	var anchor: = start
	var i: = 0
	while i < result.size():
		var last: = i
		for j in range(i + 1, result.size()):
			if not clear_segment(anchor, result[j]): break
			last = j
		simplified.append(result[last])
		anchor = result[last]
		i = last + 1
	return simplified if simplified.size() <= 256 else []
func _build_graph() -> void :
	graph = AStar2D.new()
	var cells: Dictionary = {}
	var extent: = int(floor(LIMIT / CELL))
	var index: = 2
	for x in range( - extent, extent + 1):
		for y in range( - extent, extent + 1):
			var cell: = Vector2i(x, y)
			var point: = Vector2(cell) * CELL
			if not on_sea(point): continue
			cells[cell] = index
			graph.add_point(index, point)
			index += 1
	for cell in cells:
		for offset in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
			var neighbor: Vector2i = cell + offset
			if cells.has(neighbor) and clear_segment(Vector2(cell) * CELL, Vector2(neighbor) * CELL): graph.connect_points(cells[cell], cells[neighbor])
	_add_kerch_passage(cells, index)

func _add_kerch_passage(cells: Dictionary, next_id: int) -> void :


	var a: = GeographicProjection.project(35.8, 45.8)
	var b: = GeographicProjection.project(37.4, 44.8)
	var detail: = 0.06
	var local: Dictionary = {}
	for x in range(floori(a.x / detail), ceili(b.x / detail) + 1):
		for y in range(floori(a.y / detail), ceili(b.y / detail) + 1):
			var cell: = Vector2i(x, y)
			var point: = Vector2(cell) * detail
			if not on_sea(point): continue
			local[cell] = next_id
			graph.add_point(next_id, point)
			next_id += 1
	for cell in local:
		var point: = Vector2(cell) * detail
		for offset in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
			var neighbor: Vector2i = cell + offset
			if local.has(neighbor) and clear_segment(point, Vector2(neighbor) * detail): graph.connect_points(local[cell], local[neighbor])
		var coarse: = Vector2i(roundi(point.x / CELL), roundi(point.y / CELL))
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var candidate: = coarse + Vector2i(dx, dy)
				if cells.has(candidate) and point.distance_to(Vector2(candidate) * CELL) < CELL * 1.5 and clear_segment(point, Vector2(candidate) * CELL): graph.connect_points(local[cell], cells[candidate])
