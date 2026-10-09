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
## Road network for armies (owner review: units travel only on roads, from province centre
## to province centre). Nodes are road ends (province centres and cities); each link keeps
## the drawn road's curve so armies follow the road on screen.
var graph: AStar2D
var nodes: Array[Vector2] = []
var links: Array = []  # {"a": id, "b": id, "points": PackedVector2Array from a to b}
var _node_of: Dictionary = {}
var _link_of: Dictionary = {}  # "a:b" -> link (either direction)
func _node(point: Vector2) -> int:
	var key: = Vector2i(roundi(point.x * 1000.0), roundi(point.y * 1000.0))
	if _node_of.has(key): return _node_of[key]
	var id: = nodes.size()
	nodes.append(point)
	_node_of[key] = id
	graph.add_point(id, point, 1.0 + maxf(0, terrain.elevation(point) - 1.0) * 0.3)
	return id
func _build_graph() -> void :
	graph = AStar2D.new()
	for road in terrain.roads:
		var a: = _node(road[0])
		var b: = _node(road[1])
		if a == b or _link_of.has("%d:%d" % [a, b]): continue
		var link: = {"a": a, "b": b, "points": StrategicMap.road_curve(road[0], road[1], road[2])}
		links.append(link)
		_link_of["%d:%d" % [a, b]] = link
		_link_of["%d:%d" % [b, a]] = link
		graph.connect_points(a, b)
## Road points from node a to node b, excluding a's own point.
func _leg(a: int, b: int) -> Array:
	var link: Dictionary = _link_of["%d:%d" % [a, b]]
	var points: Array = Array(link.points)
	if link.a != a: points.reverse()
	points.pop_front()
	return points
## The province centre that an order to `point` goes to.
func hub_for(point: Vector2) -> Vector2:
	for territory in terrain.territories:
		if territory.playable and RegionData.contains(territory, point): return terrain.province_hubs.get(territory.title, territory.center)
	return point
func nearest_land(point: Vector2) -> Vector2:
	if on_land(point): return point
	for radius in [0.2, 0.4, 0.8, 1.2, 2.0]:
		for angle in 16:
			var candidate: Vector2 = point + Vector2.from_angle(angle * TAU / 16.0) * radius
			if on_land(candidate): return candidate
	return point
func find_path(start: Vector2, finish: Vector2, kind: String = "armor") -> Array:
	if not on_land(finish): return []
	if graph == null: _build_graph()
	if nodes.is_empty(): return []
	for id in graph.get_point_ids(): graph.set_point_weight_scale(id, 1.0 / TerrainRules.multiplier(kind, TerrainProfile.sample(graph.get_point_position(id)), "speed"))
	var goal: = graph.get_closest_point(hub_for(finish))
	# Ways onto the network: already at a road end, part-way along a road (go to either
	# end along the road), or off-road (straight to the nearest road end).
	var entries: Array = []  # [node, points from start to node]
	var nearest: = graph.get_closest_point(start)
	if nodes[nearest].distance_to(start) < 0.05: entries.append([nearest, []])
	else:
		var best: = INF
		var on_link: Dictionary = {}
		var at: = 0
		for link in links:
			var points: PackedVector2Array = link.points
			for i in points.size():
				var d: = points[i].distance_to(start)
				if d < best:
					best = d
					on_link = link
					at = i
		if best < 0.08:
			var points: Array = Array(on_link.points)
			var toward_b: Array = points.slice(at + 1)
			var toward_a: Array = points.slice(0, at)
			toward_a.reverse()
			entries.append([on_link.b, toward_b])
			entries.append([on_link.a, toward_a])
		else: entries.append([nearest, [nodes[nearest]]])
	var result: Array = []
	var shortest: = INF
	for entry in entries:
		var ids: = graph.get_id_path(entry[0], goal)
		if ids.is_empty(): continue
		var path: Array = entry[1].duplicate()
		for i in ids.size() - 1: path.append_array(_leg(ids[i], ids[i + 1]))
		var length: = 0.0
		var previous: = start
		for point in path:
			length += previous.distance_to(point)
			previous = point
		if length < shortest:
			shortest = length
			result = path
	if result.is_empty() and entries.size() > 0 and entries[0][0] == goal: result = entries[0][1]
	return result
