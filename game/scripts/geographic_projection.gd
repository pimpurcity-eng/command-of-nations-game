class_name GeographicProjection
extends RefCounted


const ORIGIN_LONGITUDE: = 32.0
const ORIGIN_LATITUDE: = 50.0
const SCALE: = 2.6
static func project(longitude: float, latitude: float) -> Vector2:
	return Vector2((longitude - ORIGIN_LONGITUDE) * cos(deg_to_rad(50.0)) * SCALE, (ORIGIN_LATITUDE - latitude) * SCALE)
static func unproject(point: Vector2) -> Vector2:
	return Vector2(point.x / (SCALE * cos(deg_to_rad(50.0))) + ORIGIN_LONGITUDE, ORIGIN_LATITUDE - point.y / SCALE)
static func load_cities() -> Array:
	var cities: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/cities.json"))
	for city in cities:
		city.point = project(city.longitude, city.latitude)
	return cities
