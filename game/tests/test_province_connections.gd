extends SceneTree
## Regression: a common neighbour must not remove a province's direct side road.
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS ", message)
	else:
		failures += 1
		push_error(message)
func province(title: String, center: Vector2, points: Array) -> Dictionary:
	var t: = RegionData.sector(title, title, "Russia", PackedVector2Array(points), true)
	t.center = center
	return t
func edge_exists(edges: Array, a: Vector2, b: Vector2) -> bool:
	return edges.any(func(e): return (e[0].is_equal_approx(a) and e[1].is_equal_approx(b)) or (e[1].is_equal_approx(a) and e[0].is_equal_approx(b)))
func _initialize() -> void:
	var a: = Vector2(-2, -1)
	var b: = Vector2(2, -1)
	var c: = Vector2(0, 0.5)
	var triangle: Array = [
		province("West", a, [Vector2(-4,-2), Vector2(0,-2), Vector2(0,0), Vector2(-4,0)]),
		province("East", b, [Vector2(0,-2), Vector2(4,-2), Vector2(4,0), Vector2(0,0)]),
		province("North", c, [Vector2(-4,0), Vector2(0,0), Vector2(4,0), Vector2(4,2), Vector2(-4,2)])]
	var g: Dictionary = StrategicMap.road_graph(triangle)
	check(edge_exists(g.edges, a, b), "side road remains even when the northern detour is shorter than the direct edge")
	check(edge_exists(g.edges, a, c) and edge_exists(g.edges, b, c), "both northern connections remain")
	check(g.edges.size() == 3, "three touching provinces have all three direct roads without duplicates")
	var map: = StrategicMap.new()
	map.territories = triangle
	map.roads = g.edges
	map.province_hubs = g.hubs
	var navigation: = LandRoutes.new()
	navigation.terrain = map
	for pair in [[a,b], [b,a]]:
		var path: Array = navigation.find_path(pair[0], pair[1], "test_equal_speed")
		check(not path.is_empty() and path[-1].is_equal_approx(pair[1]), "direct side road works in both directions")
		check(not path.any(func(p): return p.distance_to(c) < 0.2), "units do not detour through the northern province centre")
	map.free()
	var real: Dictionary = StrategicMap.road_graph(RegionData.territories())
	for pair in [["Lviv region", "Rivne region"], ["Kyiv region", "Poltava region"], ["Sumy region", "Kharkiv region"], ["Bryansk region", "Kursk region"]]:
		check(edge_exists(real.edges, real.hubs[pair[0]], real.hubs[pair[1]]), "restored direct connection: " + pair[0] + " / " + pair[1])
	print("RESULT failures=", failures, " local_roads=", real.edges.size())
	quit(1 if failures else 0)
