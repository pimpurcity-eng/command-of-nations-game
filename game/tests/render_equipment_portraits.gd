extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var viewport: = SubViewport.new()
	viewport.size = Vector2i(640, 400)
	viewport.transparent_bg = false
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene: = Node3D.new()
	viewport.add_child(scene)
	var environment: = WorldEnvironment.new()
	var settings: = Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("34434e")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("c9d5dd")
	settings.ambient_light_energy = 0.8
	environment.environment = settings
	scene.add_child(environment)
	var light: = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	light.light_energy = 1.6
	light.shadow_enabled = true
	scene.add_child(light)
	var ground: = MeshInstance3D.new()
	var plane: = PlaneMesh.new()
	plane.size = Vector2(200, 200)
	ground.mesh = plane
	var floor_material: = StandardMaterial3D.new()
	floor_material.albedo_color = Color("4c5d64")
	floor_material.roughness = 0.95
	ground.material_override = floor_material
	scene.add_child(ground)
	var camera: = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.35
	camera.position = Vector3(2.5, 1.5, 3.4)
	scene.add_child(camera)
	camera.look_at(Vector3(0, 0.3, 0))
	camera.current = true
	DirAccess.make_dir_recursive_absolute("res://assets/interface/portraits")
	for spec in EquipmentIdentity.catalog:
		camera.size = 1.5 if spec.visual_kind == "naval" else 1.15 if spec.visual_kind == "fighter" else 1.0
		var model: = UnitVisual.create(spec.visual_kind, Color.WHITE, spec.id)
		scene.add_child(model)
		for i in 6: await process_frame
		viewport.get_texture().get_image().save_png("res://assets/interface/portraits/" + spec.id + ".png")
		model.queue_free()
		await process_frame
	print("Equipment portraits rendered")
	quit()
