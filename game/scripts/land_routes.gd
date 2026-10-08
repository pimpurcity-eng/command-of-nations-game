class_name LandRoutes
extends RefCounted
var terrain: StrategicMap
func on_land(point: Vector2) -> bool:
	for territory in terrain.territories:
		if territory.playable and RegionData.contains(territory, point): return true
	return false
func clear_segment(a: Vector2, b: Vector2) -> bool:
	var steps: = maxi(1, int(ceil(a.distance_to(b) / 0.25)))
	for i in range(steps + 1):
		if not on_land(a.lerp(b, float(i) / steps)): return false
	return true
var graph: AStar2D
func _build_graph() -> void :
	graph = AStar2D.new()
	var index: = 2
	for territory in terrain.territories:
		if territory.playable:
			graph.add_point(index, territory.center, 1.0 + maxf(0, terrain.elevation(territory.center) - 1.0) * 0.3)
			index += 1
	for i in range(2, index):
		for j in range(i + 1, index):
			var a: = graph.get_point_position(i)
			var b: = graph.get_point_position(j)
			if a.distance_to(b) < 8 and clear_segment(a, b): graph.connect_points(i, j)
func nearest_land(point: Vector2) -> Vector2:
	if on_land(point): return point
	for radius in [0.2, 0.4, 0.8, 1.2, 2.0]:
		for angle in 16:
			var candidate: Vector2 = point + Vector2.from_angle(angle * TAU / 16.0) * radius
			if on_land(candidate): return candidate
	return point
func find_path(start: Vector2, finish: Vector2, kind: String = "armor") -> Array:
	if not on_land(start) or not on_land(finish): return []
	if clear_segment(start, finish): return [finish]
	if graph == null: _build_graph()
	for id in graph.get_point_ids(): graph.set_point_weight_scale(id, 1.0 / TerrainRules.multiplier(kind, TerrainProfile.sample(graph.get_point_position(id)), "speed"))
	graph.add_point(0, start)
	graph.add_point(1, finish)
	for index in graph.get_point_ids():
		if index < 2: continue
		var point: = graph.get_point_position(index)
		for endpoint in [0, 1]:
			var anchor: = start if endpoint == 0 else finish
			if anchor.distance_to(point) < 8 and clear_segment(anchor, point): graph.connect_points(endpoint, index)
	var result: Array = []
	for point in graph.get_point_path(0, 1): result.append(point)
	graph.remove_point(0)
	graph.remove_point(1)
	if not result.is_empty(): result.pop_front()
	return result
