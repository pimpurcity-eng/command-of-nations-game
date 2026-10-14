extends SceneTree
class FlatMap extends StrategicMap:
	func elevation(_p: Vector2) -> float: return 0.0

func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(720, 960)
	var scene := Node3D.new()
	root.add_child(scene)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("87967b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c9d0d2")
	env.ambient_light_energy = 0.65
	environment.environment = env
	scene.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	scene.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.7
	camera.position = Vector3(0, 4.8, 3.0)
	scene.add_child(camera)
	camera.look_at(Vector3(0, 0.15, 0))
	var flat := FlatMap.new()
	var cities := CitySystem.new()
	cities.terrain = flat
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20,20)
	ground.mesh = plane
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color("718064")
	grass.roughness = 1.0
	ground.material_override = grass
	scene.add_child(ground)
	var out := OS.get_environment("CITY_REVIEW_DIR")
	for spec in [["Moscow",true,"armor","tanks_russia"],["Tula",false,"infantry","infantry_russia"]]:
		var district := Node3D.new()
		district.scale = Vector3.ONE * 0.72
		scene.add_child(district)
		cities._build_city_district(district,{"name":spec[0],"capital":spec[1]}, StandardMaterial3D.new())
		var unit := UnitVisual.create(spec[2],Color("77a87a"),spec[3],1)
		unit.scale = Vector3.ONE * 0.65 * UnitSystem.garrison_scale({"visual_kind":spec[2],"equipment_id":spec[3],"level":1})
		unit.position.y = 0.018
		unit.rotation_degrees.y = -35
		scene.add_child(unit)
		for i in 30: await process_frame
		root.get_texture().get_image().save_png(out.path_join(spec[0]+".png"))
		print(spec[0], " original=",not unit.get_meta("missing_original_model",false)," bounds=",UnitVisual.model_bounds(unit,0))
		district.free();unit.free()
	cities.free();flat.free()
	quit()
