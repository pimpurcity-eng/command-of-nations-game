extends SceneTree
## Reproduces Odesa's houses extending beyond the drawn coastline.
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", message)
	if not ok: failures += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var terrain := StrategicMap.new()
	root.add_child(terrain)
	while not terrain.build_finished: await process_frame
	var cities := CitySystem.new()
	cities.terrain = terrain
	for city in GeographicProjection.load_cities():
		var district := Node3D.new()
		district.position = terrain.position_at(city.point)
		district.scale = Vector3.ONE * (0.86 if city.get("capital", false) else 0.72)
		cities._build_city_district(district, city, StandardMaterial3D.new())
		var unsupported := 0
		var vertices := 0
		for node in district.find_children("*", "MeshInstance3D", true, false):
			for surface in node.mesh.get_surface_count():
				for point in node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
					var world: Vector3 = district.position + point * district.scale
					vertices += 1
					if not terrain.on_land(Vector2(world.x, world.z)): unsupported += 1
		check(vertices > 0, city.name + " still has city geometry")
		check(unsupported == 0, "%s: %d of %d city vertices beyond the coastline" % [city.name, unsupported, vertices])
		check(Vector2(district.position.x, district.position.z).is_equal_approx(city.point), city.name + " keeps the city/army destination")
		district.free()
	cities.free()
	terrain.queue_free()
	await process_frame
	print("RESULT coastal_cities checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
