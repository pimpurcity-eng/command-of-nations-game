class_name TerrainProfile
extends RefCounted

static var cities: Array = GeographicProjection.load_cities()
static var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/province_terrain.json"))
static var carpathians: Array = [GeographicProjection.project(22.6, 48.7), GeographicProjection.project(24.1, 48.2), GeographicProjection.project(25.6, 47.6)]
static var caucasus: Array = [GeographicProjection.project(39.6, 44.0), GeographicProjection.project(42.3, 43.5), GeographicProjection.project(44.5, 42.9), GeographicProjection.project(47.6, 42.2)]
static var crimea: Array = [GeographicProjection.project(33.6, 44.55), GeographicProjection.project(35.0, 44.9)]
static var _city_cells: Dictionary = {}
static var _city_count: = -1
static var _city_order: Dictionary = {}
static func nearby_cities(point: Vector2) -> Array:
	if _city_count!=cities.size():
		_city_count=cities.size();_city_cells.clear();_city_order.clear()
		for city in cities:
			_city_order[city.id]=_city_order.size()
			var cell: = Vector2i(floori(city.point.x/2),floori(city.point.y/2))
			if not _city_cells.has(cell): _city_cells[cell]=[]
			_city_cells[cell].append(city)
	var center: = Vector2i(floori(point.x/2),floori(point.y/2))
	var result: Array = []
	for x in range(-1,2):
		for y in range(-1,2): result.append_array(_city_cells.get(center+Vector2i(x,y),[]))
	result.sort_custom(func(a,b):return _city_order[a.id]<_city_order[b.id])
	return result
static func reload() -> void:
	cities = GeographicProjection.load_cities()
	_city_count=-1;_city_cells.clear();_city_order.clear()
	carpathians = [GeographicProjection.project(22.6,48.7),GeographicProjection.project(24.1,48.2),GeographicProjection.project(25.6,47.6)]
	caucasus = [GeographicProjection.project(39.6,44.0),GeographicProjection.project(42.3,43.5),GeographicProjection.project(44.5,42.9),GeographicProjection.project(47.6,42.2)]
	crimea = [GeographicProjection.project(33.6,44.55),GeographicProjection.project(35.0,44.9)]
static func ridge_distance(point: Vector2, path: Array) -> float:
	var result: = INF
	for i in range(path.size() - 1): result = minf(result, point.distance_to(Geometry2D.get_closest_point_to_segment(point, path[i], path[i + 1])))
	return result
static func landform(longitude: float, latitude: float) -> String:
	if not MapDefinition.is_regional():
		# Broad strategic terrain regions; the game keeps flat, traversable ground meshes.
		if (longitude > 5 and longitude < 16 and latitude > 45 and latitude < 48) or (longitude > -2 and longitude < 3 and latitude > 42 and latitude < 43.5) or (longitude > 6 and longitude < 18 and latitude > 59): return "mountains"
		if (longitude > 18 and longitude < 28 and latitude > 40 and latitude < 47) or (longitude > -9 and longitude < 1 and latitude > 38 and latitude < 43): return "hills"
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
		for city in nearby_cities(point):
			if city.point.distance_squared_to(point) < 0.36: return "urban"
	var geo: = GeographicProjection.unproject(point)
	# Polissia's marshes count as forest: the old repeating sin*cos "wetlands" pattern drew
	# rectangular patches across Volyn, Rivne and Zhytomyr.
	return landform(geo.x, geo.y)
## Owner review 2026-10-09: the map is totally flat (Call of War style) so units, roads,
## cities and flags always sit exactly on the ground; hills and mountains are painted by the
## terrain shader from relief_height() (shading, rock, snow) instead of raising the mesh.
const FLAT_HEIGHT: = 0.2
static func height(_point: Vector2) -> float:
	return FLAT_HEIGHT
## The landscape's virtual height: drives the painted relief only.
static func relief_height(point: Vector2) -> float:
	# Cities stand on level ground: blend towards the height at the city centre.
	var raw: = _raw_height(point)
	for city in nearby_cities(point):
		var d: float = city.point.distance_to(point)
		if d < 1.25: raw = lerpf(_raw_height(city.point), raw, smoothstep(0.8, 1.25, d))
	return raw
static func _raw_height(point: Vector2) -> float:
	var geo: = GeographicProjection.unproject(point)
	var mountain: = exp( - pow(ridge_distance(point, carpathians) / 1.15, 2)) * 2.2 + exp( - pow(ridge_distance(point, caucasus) / 1.4, 2)) * 3.0 + exp( - pow(ridge_distance(point, crimea) / 0.45, 2)) * 0.8
	var roughness: = sin(point.x * 3.1 + point.y * 1.2) * cos(point.y * 3.8) * 0.5 + 0.5
	# Soft-edged upland zones: the hard landform boxes made cliffs (e.g. along 50°N at Kharkiv).
	var hills: = lerpf(0.05, 0.35, hill_weight(geo.x, geo.y))
	return 0.18 + hills * (0.45 + roughness) + mountain * (0.72 + roughness * 0.28) + 0.03 * sin(point.x * 0.8) * cos(point.y * 0.6)
## 0..1 membership of the hill boxes used by landform(), with ~0.6 degree soft edges.
static func hill_weight(longitude: float, latitude: float) -> float:
	var boxes: = [[35.0, 39.5, 50.0, 54.5], [43.3, 46.5, 50.0, 55.0], [36.8, 40.2, 47.7, 49.5], [18.0, 29.0, 48.2, 50.0], [39.5, 50.0, 44.3, 44.8]]
	var weight: = 0.0
	for b in boxes:
		var w: = smoothstep(b[0] - 0.6, b[0] + 0.6, longitude) * (1.0 - smoothstep(b[1] - 0.6, b[1] + 0.6, longitude))
		w *= smoothstep(b[2] - 0.6, b[2] + 0.6, latitude) * (1.0 - smoothstep(b[3] - 0.6, b[3] + 0.6, latitude))
		weight = maxf(weight, w)
	return weight
static func profile(country: String, province: String) -> Dictionary:
	return profiles.get(country + ":" + province, {"terrain": "plains", "forest_density": 0.12, "dryness": 0.3, "wetness": 0.0})
