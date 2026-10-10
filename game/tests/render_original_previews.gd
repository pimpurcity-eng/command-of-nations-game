extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(600, 400)
	var world = Node3D.new(); root.add_child(world)
	var environment = WorldEnvironment.new()
	var settings = Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("26383c")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 0.65
	environment.environment = settings; world.add_child(environment)
	var sun = DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-45, -30, 0); sun.light_energy = 1.2; world.add_child(sun)
	var camera = Camera3D.new(); camera.position = Vector3(2.1, 1.7, 2.7); camera.fov = 38; world.add_child(camera); camera.look_at(Vector3(0, 0.35, 0)); camera.current = true
	for id in ["t90m", "uploadec7e", "upload661a", "upload3b99", "upload7a7e", "upload20ab"]:
		var model = load("res://assets/library/" + id + "_original.glb").instantiate()
		world.add_child(model)
		for i in 5: await process_frame
		root.get_texture().get_image().save_png("/workspace/scratch/9cc4c8c712c9/recovered-game/assets/library/" + id + "_original_preview.png")
		model.queue_free(); await process_frame
	quit()
