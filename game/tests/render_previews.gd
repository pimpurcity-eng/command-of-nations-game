extends SceneTree
## Renders a 3/4-view picture of every equipment model (with its camouflage) to
## res://assets/library/previews/<id>.png for menus. The folder is gitignored like the models.
##   godot --path . --script tests/render_previews.gd
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/library/previews"))
	var viewport: = SubViewport.new()
	viewport.size = Vector2i(320, 240)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world: = Node3D.new()
	viewport.add_child(world)
	var env: = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("c8d0d8")
	env.environment.ambient_light_energy = 0.6
	world.add_child(env)
	var sun: = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -40, 0)
	sun.light_energy = 1.2
	world.add_child(sun)
	var camera: = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	world.add_child(camera)
	for spec in EquipmentIdentity.catalog:
		var model: Node3D = UnitVisual.create(spec.get("visual_kind", "armor"), Color.WHITE, spec.id)
		if model.get_meta("missing_original_model", false): model.free(); continue
		model.rotation.y = deg_to_rad(-35)
		world.add_child(model)
		var bounds: = AABB()
		var first: = true
		for node in model.find_children("*", "MeshInstance3D", true, false):
			var mesh_node: MeshInstance3D = node
			var box: AABB = mesh_node.global_transform * mesh_node.mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		var center: = bounds.get_center()
		camera.size = maxf(bounds.size.length() * 0.6, 0.1)
		camera.look_at_from_position(center + Vector3(0.0, 0.55, 1.0).normalized() * 20.0, center)
		for i in 4: await process_frame
		viewport.get_texture().get_image().save_png("res://assets/library/previews/" + spec.id + ".png")
		model.free()
	print("previews done")
	quit()
