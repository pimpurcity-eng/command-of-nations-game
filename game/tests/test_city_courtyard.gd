extends SceneTree

class FlatMap extends StrategicMap:
	func elevation(_point: Vector2) -> float:
		return 0.0

var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var system := CitySystem.new()
	var flat := FlatMap.new()
	system.terrain = flat
	for city in GeographicProjection.load_cities():
		for capital in [true, false]:
			var district := Node3D.new()
			district.scale = Vector3.ONE * 0.72
			system._build_city_district(district, {"name": city.name, "capital": capital}, StandardMaterial3D.new())
			check(district.get_meta("urban_building_count") > 30, "City still has buildings")
			check(is_equal_approx(district.get_meta("garrison_plaza_radius"), 0.3888), "Courtyard world size")
			var tall := 0
			for child in district.get_children():
				if not child is MeshInstance3D: continue
				var vertices: PackedVector3Array = child.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				for vertex in vertices:
					# The pavement is the only geometry allowed in the reserved centre.
					if vertex.y <= 0.025: continue
					check(Vector2(vertex.x, vertex.z).length() >= CitySystem.GARRISON_PLAZA_RADIUS, "Building intrudes on garrison courtyard")
					if vertex.y > 0.3: tall += 1
			check(tall > 0, "Retains skyscrapers")
			district.free()
	check(is_equal_approx(UnitMapSize.limits("armor").x, 1.056), "Tank increased by 20 percent plus readability adjustment")
	check(UnitMapSize.limits("infantry").x * 0.65 * UnitSystem.garrison_scale({"visual_kind":"infantry", "equipment_id":"infantry_russia"}) * 0.71 < CitySystem.GARRISON_PLAZA_RADIUS * 0.72, "Readable infantry fits in compact courtyard")
	check(not CitySystem.SHOW_COURTYARD_DISK, "No white pavement disc")
	check(is_equal_approx(UnitSystem.garrison_scale({"visual_kind":"infantry", "equipment_id":"infantry_russia"}),1.6875), "Infantry readability boost")
	check(is_equal_approx(UnitSystem.garrison_scale({"visual_kind":"armor", "equipment_id":"tanks_russia"}),1.35), "Tank retains Claude garrison sizing")
	system.free()
	flat.free()
	print("CITY COURTYARD: ", checks, " checks; ", failures, " failures")
	quit(0 if failures == 0 else 1)
