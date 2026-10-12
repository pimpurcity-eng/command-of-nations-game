class_name GeographicProjection
extends RefCounted


const ORIGIN_LONGITUDE: = 32.0
const ORIGIN_LATITUDE: = 50.0
const SCALE: = 2.6
const EARTH_RADIUS: = 6371.0
static func project(longitude: float, latitude: float) -> Vector2:
	if not MapDefinition.is_regional(): return _laea(longitude, latitude)
	return Vector2((longitude - ORIGIN_LONGITUDE) * cos(deg_to_rad(50.0)) * SCALE, (ORIGIN_LATITUDE - latitude) * SCALE)
static func unproject(point: Vector2) -> Vector2:
	if not MapDefinition.is_regional(): return _laea_inverse(point)
	return Vector2(point.x / (SCALE * cos(deg_to_rad(50.0))) + ORIGIN_LONGITUDE, ORIGIN_LATITUDE - point.y / SCALE)
## Lambert azimuthal equal-area (larger maps such as Europe); same formulas as
## tools/build_europe_map.py.
static func _laea(longitude: float, latitude: float) -> Vector2:
	var projection: Dictionary = MapDefinition.data.projection
	if projection.type == "equal_earth": return _equal_earth(longitude, latitude)
	var lam: = deg_to_rad(longitude - projection.longitude)
	var phi: = deg_to_rad(latitude)
	var phi0: = deg_to_rad(projection.latitude)
	var k: = sqrt(2.0 / (1.0 + sin(phi0) * sin(phi) + cos(phi0) * cos(phi) * cos(lam)))
	var x: = EARTH_RADIUS * k * cos(phi) * sin(lam)
	var y: = EARTH_RADIUS * k * (cos(phi0) * sin(phi) - sin(phi0) * cos(phi) * cos(lam))
	return Vector2(x, -y) * float(projection.units_per_km)
static func _laea_inverse(point: Vector2) -> Vector2:
	var projection: Dictionary = MapDefinition.data.projection
	if projection.type == "equal_earth": return _equal_earth_inverse(point)
	var x: = point.x / float(projection.units_per_km)
	var y: = -point.y / float(projection.units_per_km)
	var rho: = sqrt(x * x + y * y)
	if rho < 1e-9: return Vector2(projection.longitude, projection.latitude)
	var c: = 2.0 * asin(clampf(rho / (2.0 * EARTH_RADIUS), -1.0, 1.0))
	var phi0: = deg_to_rad(projection.latitude)
	var phi: = asin(cos(c) * sin(phi0) + y * sin(c) * cos(phi0) / rho)
	var lam: = atan2(x * sin(c), rho * cos(phi0) * cos(c) - y * sin(phi0) * sin(c))
	return Vector2(rad_to_deg(lam) + projection.longitude, rad_to_deg(phi))
static func load_cities() -> Array:
	var path: = "res://data/cities.json" if MapDefinition.is_regional() else str(MapDefinition.data.get("cities", ""))
	if path.is_empty(): return []
	var cities: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
	for city in cities:
		city.point = project(city.longitude, city.latitude)
	return cities
## Equal Earth (Šavrič, Patterson, Jenny 2018): the world map; equal-area, so countries keep
## their true sizes. Same formulas as tools/build_europe_map.py.
const EE: = [1.340264, -0.081106, 0.000893, 0.003796]
static func _equal_earth(longitude: float, latitude: float) -> Vector2:
	var projection: Dictionary = MapDefinition.data.projection
	var lam: = deg_to_rad(longitude - projection.longitude)
	var t: = asin(sqrt(3.0) / 2.0 * sin(deg_to_rad(latitude)))
	var d: float = EE[0] + 3.0 * EE[1] * t * t + 7.0 * EE[2] * pow(t, 6) + 9.0 * EE[3] * pow(t, 8)
	var x: = EARTH_RADIUS * 2.0 * sqrt(3.0) * lam * cos(t) / (3.0 * d)
	var y: float = EARTH_RADIUS * (EE[0] * t + EE[1] * pow(t, 3) + EE[2] * pow(t, 7) + EE[3] * pow(t, 9))
	return Vector2(x, -y) * float(projection.units_per_km)
static func _equal_earth_inverse(point: Vector2) -> Vector2:
	var projection: Dictionary = MapDefinition.data.projection
	var x: = point.x / float(projection.units_per_km) / EARTH_RADIUS
	var y: = -point.y / float(projection.units_per_km) / EARTH_RADIUS
	var t: float = y / EE[0]
	for i in 12:
		var f: float = EE[0] * t + EE[1] * pow(t, 3) + EE[2] * pow(t, 7) + EE[3] * pow(t, 9) - y
		t -= f / (EE[0] + 3.0 * EE[1] * t * t + 7.0 * EE[2] * pow(t, 6) + 9.0 * EE[3] * pow(t, 8))
	var d: float = EE[0] + 3.0 * EE[1] * t * t + 7.0 * EE[2] * pow(t, 6) + 9.0 * EE[3] * pow(t, 8)
	var lam: = 3.0 * x * d / (2.0 * sqrt(3.0) * cos(t))
	return Vector2(rad_to_deg(lam) + projection.longitude, rad_to_deg(asin(clampf(sin(t) / (sqrt(3.0) / 2.0), -1.0, 1.0))))
