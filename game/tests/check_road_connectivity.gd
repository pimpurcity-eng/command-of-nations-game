extends SceneTree
func _initialize() -> void:
	var data: Dictionary = StrategicMap.road_graph(RegionData.territories())
	var nodes: Dictionary = {}
	for edge in data.edges:
		for p in [edge[0], edge[1]]:
			var key: Vector2i = Vector2i(roundi(p.x * 10000), roundi(p.y * 10000))
			if not nodes.has(key): nodes[key] = []
		var a: Vector2i = Vector2i(roundi(edge[0].x * 10000), roundi(edge[0].y * 10000))
		var b: Vector2i = Vector2i(roundi(edge[1].x * 10000), roundi(edge[1].y * 10000))
		nodes[a].append(b); nodes[b].append(a)
	var visited: Dictionary = {}
	var sizes: Array = []
	for start in nodes:
		if visited.has(start): continue
		var pending: Array = [start]
		var count: int = 0
		while not pending.is_empty():
			var here = pending.pop_back()
			if visited.has(here): continue
			visited[here] = true;count += 1
			pending.append_array(nodes[here])
		sizes.append(count)
	var disconnected: Array = []
	for title in data.hubs:
		var p: Vector2 = data.hubs[title]
		if not nodes.has(Vector2i(roundi(p.x * 10000), roundi(p.y * 10000))): disconnected.append(title)
	var city_misses: Array = []
	for city in GeographicProjection.load_cities():
		var p: Vector2 = city.point
		if not nodes.has(Vector2i(roundi(p.x * 10000), roundi(p.y * 10000))): city_misses.append(city.name)
	print("City hubs without local-road endpoint=", city_misses)
	print("Road graph: connected group sizes=", sizes, " isolated province hubs=", disconnected)
	quit()
