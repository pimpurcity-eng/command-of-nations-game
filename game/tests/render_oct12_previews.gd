extends SceneTree
func _initialize(): call_deferred("run")
func run():
	root.size = Vector2i(512,384)
	var world: = Node3D.new()
	root.add_child(world)
	var environment: = WorldEnvironment.new()
	var settings: = Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("39454a")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 0.65
	environment.environment = settings
	world.add_child(environment)
	var sun: = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50,-30,0)
	sun.light_energy = 1.3
	world.add_child(sun)
	var camera: = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.0
	camera.position = Vector3(4,4,5)
	world.add_child(camera)
	camera.look_at(Vector3(0,0.35,0))
	var done: Dictionary = {}
	for spec in EquipmentIdentity.catalog:
		if spec.visual_kind != "naval": continue
		for level in range(1,6):
			var path: String = EquipmentIdentity.research_tier(spec.id,level).model
			if done.has(path): continue
			done[path] = true
			var model: = UnitVisual.create("naval",Color.WHITE,spec.id,level)
			camera.size = 3.4 if spec.get("role","")=="carrier" else 2.0
			world.add_child(model)
			for i in 5: await process_frame
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path.trim_suffix(".glb")+"_oct12_preview.png"))
			world.remove_child(model);model.queue_free()
			await process_frame
	print("NAVAL PREVIEWS ",done.size())
	world.queue_free();await process_frame;quit()
