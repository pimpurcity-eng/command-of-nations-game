class_name GeographicProjection
extends RefCounted


const ORIGIN_LONGITUDE: = 32.0
const ORIGIN_LATITUDE: = 50.0
const SCALE: = 2.6
static func project(longitude: float, latitude: float) -> Vector2:
	if not MapDefinition.is_regional(): return _laea(longitude,latitude)
	return Vector2((longitude - ORIGIN_LONGITUDE) * cos(deg_to_rad(50.0)) * SCALE, (ORIGIN_LATITUDE - latitude) * SCALE)
static func unproject(point: Vector2) -> Vector2:
	if not MapDefinition.is_regional(): return _laea_inverse(point)
	return Vector2(point.x / (SCALE * cos(deg_to_rad(50.0))) + ORIGIN_LONGITUDE, ORIGIN_LATITUDE - point.y / SCALE)
static func load_cities() -> Array:
	var cities: Array = MapDefinition.city_data()
	for city in cities:
		city.point = project(city.longitude, city.latitude)
	return cities

static func _laea(longitude: float, latitude: float) -> Vector2:
	var p: Dictionary = MapDefinition.data.projection
	var lon: = deg_to_rad(longitude-float(p.longitude))
	var lat: = deg_to_rad(latitude)
	var center: = deg_to_rad(float(p.latitude))
	var k: = sqrt(2.0/(1.0+sin(center)*sin(lat)+cos(center)*cos(lat)*cos(lon)))
	return Vector2(6371.0*k*cos(lat)*sin(lon),-6371.0*k*(cos(center)*sin(lat)-sin(center)*cos(lat)*cos(lon)))*float(p.units_per_km)
static func _laea_inverse(point: Vector2) -> Vector2:
	var p: Dictionary = MapDefinition.data.projection
	var x: = point.x/float(p.units_per_km)
	var y: = -point.y/float(p.units_per_km)
	var rho: = sqrt(x*x+y*y)
	if rho < 0.0000001: return Vector2(p.longitude,p.latitude)
	var c: = 2.0*asin(clampf(rho/(2.0*6371.0),-1,1))
	var lat0: = deg_to_rad(float(p.latitude))
	return Vector2(float(p.longitude)+rad_to_deg(atan2(x*sin(c),rho*cos(lat0)*cos(c)-y*sin(lat0)*sin(c))),rad_to_deg(asin(cos(c)*sin(lat0)+y*sin(c)*cos(lat0)/rho)))
