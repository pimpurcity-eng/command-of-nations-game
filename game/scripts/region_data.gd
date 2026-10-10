class_name RegionData
extends RefCounted
const COUNTRY_IDS: = ["UKR", "RUS", "BLR", "POL", "ROU", "MDA", "GEO", "TUR", "SVK", "HUN", "LVA", "LTU", "EST", "FIN", "BGR", "SRB", "DEU", "CZE", "AZE", "ARM"]
static var country_cache: Array = []
static func countries() -> Array:
	if not country_cache.is_empty(): return country_cache
	var bounds: = PackedVector2Array([Vector2(-24, -27), Vector2(26, -27), Vector2(26, 21), Vector2(-24, 21)])
	for code in COUNTRY_IDS:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + code + ".geo.json"))
		var feature: Dictionary = data.features[0]
		var geometry: Dictionary = feature.geometry
		var rings: Array = geometry.coordinates if geometry.type == "MultiPolygon" else [geometry.coordinates]
		for polygon in rings:
			var projected: = PackedVector2Array()
			for point in polygon[0]: projected.append(GeographicProjection.project(point[0], point[1]))
			if projected[0].is_equal_approx(projected[-1]): projected.remove_at(projected.size() - 1)
			for clipped in Geometry2D.intersect_polygons(projected, bounds):
				if clipped.size() > 2 and not Geometry2D.triangulate_polygon(clipped).is_empty():
					country_cache.append({"country": feature.properties.name, "polygon": clipped, "code": code})
	return country_cache
static func territories() -> Array:
	var result: Array = []
	for country in countries():
		if country.country not in ["Ukraine", "Russia"]:
			result.append(sector(country.code.to_lower() + str(result.size()), country.country, country.country, country.polygon, false))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/administrative_regions.json"))
	var sites: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/province_sites.json"))
	var cities: = GeographicProjection.load_cities()
	for feature in data.features:
		var props: Dictionary = feature.properties
		var polygons: Array = feature.geometry.coordinates if feature.geometry.type == "MultiPolygon" else [feature.geometry.coordinates]
		var piece_index: = 0
		for polygon_index in polygons.size():
			var polygon: Array = polygons[polygon_index]
			var poly: = PackedVector2Array()
			for point in polygon[0]: poly.append(GeographicProjection.project(point[0], point[1]))
			if poly[0].is_equal_approx(poly[-1]): poly.remove_at(poly.size() - 1)
			if poly.size() < 3 or Geometry2D.triangulate_polygon(poly).is_empty(): continue
			var entry: = sector(props.id + "_" + str(piece_index), props.name + " region", props.country, poly, true)
			piece_index += 1
			entry.province = props.name
			entry.holes = []
			for i in range(1, polygon.size()):
				var hole: = PackedVector2Array()
				for point in polygon[i]: hole.append(GeographicProjection.project(point[0], point[1]))
				entry.holes.append(hole)
			entry.mesh_polygons = []
			for coordinates in feature.mesh_polygons[polygon_index]:
				var patch: = PackedVector2Array()
				for point in coordinates: patch.append(GeographicProjection.project(point[0], point[1]))
				if patch[0].is_equal_approx(patch[-1]): patch.remove_at(patch.size() - 1)
				entry.mesh_polygons.append(patch)
			entry.center = GeographicProjection.project(feature.centers[polygon_index][0], feature.centers[polygon_index][1])
			var nearest: = INF
			var profile_name: String = props.name
			for site in sites:
				if site.country != props.country: continue
				var point: = GeographicProjection.project(site.longitude, site.latitude)
				if point.distance_to(entry.center) < nearest:
					nearest = point.distance_to(entry.center)
					profile_name = site.name
			entry.terrain_profile = TerrainProfile.profile(props.country, profile_name)
			entry.terrain = entry.terrain_profile.get("terrain", "plains")
			for city in cities:
				if city.country == props.country and contains(entry, city.point): entry.center = city.point
			result.append(entry)
	return result
static func contains(region: Dictionary, point: Vector2) -> bool:
	if not Geometry2D.is_point_in_polygon(point, region.polygon): return false
	for hole in region.get("holes", []):
		if Geometry2D.is_point_in_polygon(point, hole): return false
	return true
static func _half_plane(poly: PackedVector2Array, site: Vector2, other: Vector2) -> PackedVector2Array:
	var result: = PackedVector2Array()
	if poly.is_empty(): return result
	var normal: = other - site
	var midpoint: = (site + other) * 0.5
	for i in poly.size():
		var a: = poly[i]
		var b: = poly[(i + 1) % poly.size()]
		var da: = (a - midpoint).dot(normal)
		var db: = (b - midpoint).dot(normal)
		if da <= 0: result.append(a)
		if (da <= 0) != (db <= 0): result.append(a.lerp(b, da / (da - db)))
	return result
static func sector(id: String, title: String, country: String, polygon: PackedVector2Array, playable: bool) -> Dictionary:
	var triangles: = Geometry2D.triangulate_polygon(polygon)
	var center: = (polygon[triangles[0]] + polygon[triangles[1]] + polygon[triangles[2]]) / 3.0
	return {"id": id, "title": title, "country": country, "polygon": polygon, "center": center, "playable": playable, "owner": country.to_lower(), "controller": country.to_lower()}
