extends SceneTree
## Renders the hero vehicle of each research group on a transparent background (owner
## 2026-10-13: "make better pictures" for the research banners, like Call of War).
##   xvfb-run -a godot --path . --script tools/render_banner_heroes.gd
## Output: $HERO_DIR/<country>_<group>.png (composited by tools/make_banners.py).
const HEROES := ["", "fighters", "artillery", "advanced_tanks", "fleet", "infantry", "missiles"]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var out: = OS.get_environment("HERO_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	var view: = SubViewport.new()
	view.size = Vector2i(1200, 760)
	view.transparent_bg = true
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var env: = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("cfd6e0")
	env.environment.ambient_light_energy = 0.55
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	view.add_child(env)
	var key: = DirectionalLight3D.new()
	key.light_color = Color("ffe2b8")
	key.light_energy = 1.6
	key.rotation_degrees = Vector3(-38, -30, 0)
	view.add_child(key)
	var rim: = DirectionalLight3D.new()
	rim.light_color = Color("9fc2ff")
	rim.light_energy = 0.7
	rim.rotation_degrees = Vector3(-20, 150, 0)
	view.add_child(rim)
	var camera: = Camera3D.new()
	camera.fov = 26
	view.add_child(camera)
	for country in ["russia", "ukraine"]:
		for group in HEROES.size():
			var path: = ""
			if group == 0:
				var industry: Dictionary = {}
				var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/buildings.json"))
				for definition in (data if data is Array else data.get("buildings", [])):
					if definition.id == "industry": industry = definition
				path = FacilityVisual.path(industry, country, 5)
			else:
				var id: String = HEROES[group] + "_" + country
				if EquipmentIdentity.spec(id).is_empty(): continue
				path = str(EquipmentIdentity.research_tier(id, 5).get("model", EquipmentIdentity.research_tier(id, 1).get("model", "")))
			if path.is_empty() or not ResourceLoader.exists(path):
				print("MISSING ", country, " ", group, " ", path); continue
			var model: = UnitVisual.merged((load(path) as PackedScene).instantiate() as Node3D)
			var holder: = Node3D.new()
			holder.add_child(model)
			view.add_child(holder)
			var bounds: = UnitVisual.model_bounds(model, 0.0)
			var scale: = 2.0 / maxf(bounds.get_longest_axis_size(), 0.001)
			model.scale = Vector3.ONE * scale
			model.position = -bounds.get_center() * scale
			# Infantry stands as a squad of three.
			if group == 5:
				for offset in [Vector3(-0.75, 0, -0.6), Vector3(0.7, 0, -0.45)]:
					var mate: = model.duplicate() as Node3D
					mate.position += offset
					holder.add_child(mate)
			holder.rotation_degrees.y = -32.0 if group != 1 else -20.0
			# Low three-quarter view, then zoom until the model fills about 85% of the frame.
			var direction: = Vector3(0, 0.16 if group != 1 else 0.3, 1).normalized()
			var distance: = 6.0
			var image: Image
			for attempt in 4:
				camera.position = direction * distance
				camera.look_at(Vector3.ZERO)
				for i in 6: await process_frame
				image = view.get_texture().get_image()
				var used: = image.get_used_rect()
				if used.size.x <= 0: break
				var fill: = maxf(float(used.size.x) / view.size.x, float(used.size.y) / view.size.y)
				if absf(fill - 0.85) < 0.05: break
				distance *= fill / 0.85
				# Re-centre on the model's visible middle.
				var centre: = Vector2(used.position) + Vector2(used.size) * 0.5 - Vector2(view.size) * 0.5
				holder.position -= Vector3(centre.x, -centre.y, 0) * (distance * 0.0009)
			image.save_png(out.path_join(country + "_" + str(group) + ".png"))
			print("HERO ", country, " ", group, " ", path.get_file())
			holder.queue_free()
			await process_frame
	quit()
