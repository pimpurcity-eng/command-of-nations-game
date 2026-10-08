class_name TerrainProfile
extends RefCounted

static var cities: Array = GeographicProjection.load_cities()
static var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/province_terrain.json"))
static var carpathians: Array = [GeographicProjection.project(22.6, 48.7), GeographicProjection.project(24.1, 48.2), GeographicProjection.project(25.6, 47.6)]
static var caucasus: Array = [GeographicProjection.project(39.6, 44.0), GeographicProjection.project(42.3, 43.5), GeographicProjection.project(44.5, 42.9), GeographicProjection.project(47.6, 42.2)]
static var crimea: Array = [GeographicProjection.project(33.6, 44.55), GeographicProjection.project(35.0, 44.9)]
static func ridge_distance(point: Vector2, path: Array) -> float:
	var result: = INF
	for i in range(path.size() - 1): result = minf(result, point.distance_to(Geometry2D.get_closest_point_to_segment(point, path[i], path[i + 1])))
	return result
static func landform(longitude: float, latitude: float) -> String:
	if longitude >= 39.5 and latitude < 44.8: return "mountains" if latitude < 44.3 else "hills"
	if longitude >= 22 and longitude < 26.2 and latitude >= 47.6 and latitude < 49.1: return "mountains"
	if longitude >= 33 and longitude <= 35.5 and latitude < 45.1: return "mountains"
	if (longitude >= 35 and longitude <= 39.5 and latitude >= 50 and latitude <= 54.5) or (longitude >= 43.3 and longitude <= 46.5 and latitude >= 50 and latitude <= 55) or (longitude >= 36.8 and longitude <= 40.2 and latitude >= 47.7 and latitude < 49.5) or (longitude < 29 and latitude >= 48.2 and latitude < 50): return "hills"
	if latitude >= 52.0 or (longitude < 33.5 and latitude >= 50.3): return "forest"
	# Caspian lowland semi-desert (Kalmykia, Astrakhan).
	if longitude >= 44.2 and latitude >= 45.0 and latitude < 47.8: return "desert"
	return "plains"
static func sample(point: Vector2, urban: bool = true) -> String:
	if urban:
		for city in cities:
			if city.point.distance_squared_to(point) < 0.36: return "urban"
	var geo: = GeographicProjection.unproject(point)
	# Polissia's marshes count as forest: the old repeating sin*cos "wetlands" pattern drew
	# rectangular patches across Volyn, Rivne and Zhytomyr.
	return landform(geo.x, geo.y)
static func height(point: Vector2) -> float:
	var geo: = GeographicProjection.unproject(point)
	var mountain: = exp( - pow(ridge_distance(point, carpathians) / 1.15, 2)) * 2.2 + exp( - pow(ridge_distance(point, caucasus) / 1.4, 2)) * 3.0 + exp( - pow(ridge_distance(point, crimea) / 0.45, 2)) * 0.8
	var roughness: = sin(point.x * 3.1 + point.y * 1.2) * cos(point.y * 3.8) * 0.5 + 0.5
	var hills: = 0.35 if landform(geo.x, geo.y) == "hills" else 0.05
	return 0.18 + hills * (0.45 + roughness) + mountain * (0.72 + roughness * 0.28) + 0.03 * sin(point.x * 0.8) * cos(point.y * 0.6)
static func profile(country: String, province: String) -> Dictionary:
	return profiles.get(country + ":" + province, {"terrain": "plains", "forest_density": 0.12, "dryness": 0.3, "wetness": 0.0})
