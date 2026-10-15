extends SceneTree
class FlatMap extends StrategicMap:
	func elevation(_p: Vector2) -> float: return 0.0
class VisibleArmies extends UnitSystem:
	func visible_to_player(unit: Dictionary) -> bool: return unit.get("test_visible",true)
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
		for capital in [true,false]:
			var district := Node3D.new()
			district.scale = Vector3.ONE*0.72
			system._build_city_district(district,{"name":city.name,"capital":capital},StandardMaterial3D.new())
			var core: Node3D = district.get_node("CityCore")
			var square: Node3D = district.get_node("GarrisonSquare")
			check(district.get_meta("urban_building_count") > 100,"Dense city has street blocks")
			check(district.get_meta("core_building_count") > 5,"Empty city centre has buildings")
			check(district.get_meta("permanent_building_count") > 70,"Occupied city retains a substantial district")
			check(core.visible and not square.visible,"Empty city starts full without a square")
			var tall := 0
			for child in district.get_children():
				if not child is MeshInstance3D: continue
				var vertices: PackedVector3Array = child.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				for vertex in vertices:
					if vertex.y > 0.02:
						check(not CitySystem.GARRISON_SQUARE.has_point(Vector2(vertex.x,vertex.z)),"Permanent building obstructs garrison square")
					if vertex.y > 0.5: tall += 1
			check(tall > 0,"Skyscraper cluster remains while occupied")
			var core_meshes := core.get_child_count()
			CitySystem.set_garrison_visible(district,true)
			check(not core.visible and square.visible,"Unit arrival exposes square")
			CitySystem.set_garrison_visible(district,false)
			check(core.visible and not square.visible,"Unit departure restores full city")
			check(core.get_child_count() == core_meshes,"Toggling does not regenerate models")
			district.free()
	var armies := VisibleArmies.new()
	system.armies = armies
	var node := Node3D.new()
	var city := {"point":Vector2.ZERO}
	var unit := {"node":node,"health":100.0,"visual_kind":"infantry","equipment_id":"infantry_russia","level":1}
	armies.units = [unit]
	check(system._city_has_garrison(city),"Live ground army opens city centre")
	node.position.x = UnitSystem.CITY_RADIUS + 0.01
	check(not system._city_has_garrison(city),"Army outside city does not leave a square")
	node.position.x = 0
	unit.health = 0
	check(not system._city_has_garrison(city),"Destroyed army restores city")
	unit.health = 100
	unit.test_visible = false
	check(not system._city_has_garrison(city),"Hidden enemy cannot reveal itself through city geometry")
	unit.test_visible = true
	unit.visual_kind = "naval"
	check(not system._city_has_garrison(city),"Ships do not clear city centre")
	unit.visual_kind = "fighter"
	unit.flight_mode = "patrol"
	check(not system._city_has_garrison(city),"Overflying aircraft do not clear city centre")
	unit.flight_mode = "grounded"
	check(system._city_has_garrison(city),"Grounded aircraft open city centre")
	armies.units = []
	check(not system._city_has_garrison(city),"Last unit leaving restores the city")
	check(is_equal_approx(UnitSystem.garrison_scale({"visual_kind":"armor","equipment_id":"tanks_russia"}),1.40),"Tank garrison is larger")
	check(is_equal_approx(UnitSystem.garrison_scale({"visual_kind":"infantry","equipment_id":"infantry_russia"}),1.40*1.6),"Infantry garrison is readable")
	node.free();armies.free();system.free();flat.free()
	print("CITY COURTYARD: ",checks," checks; ",failures," failures")
	quit(0 if failures == 0 else 1)
