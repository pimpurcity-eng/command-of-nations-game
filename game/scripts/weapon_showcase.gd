class_name WeaponShowcase
extends CanvasLayer
var entries: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/weapon_showcase.json"))
var models: Array[Node3D] = []
var rig: StrategyCamera
var title: Label
var index: = 0
var clock: SimulationClock
var previous_pause: = true
func setup(theme: Theme, simulation: SimulationClock) -> void :
	clock = simulation
	layer = 20
	var root: = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = theme
	add_child(root)
	var container: = SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	root.add_child(container)
	var viewport: = SubViewport.new()
	viewport.own_world_3d = true
	viewport.handle_input_locally = true
	container.add_child(viewport)
	var world: = Node3D.new()
	viewport.add_child(world)
	var environment: = WorldEnvironment.new()
	var settings: = Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("172733")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("c2ced6")
	settings.ambient_light_energy = 0.55
	environment.environment = settings
	world.add_child(environment)
	var sun: = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -30, 0)
	sun.light_energy = 1.2
	world.add_child(sun)
	var floor: = MeshInstance3D.new()
	var plane: = PlaneMesh.new()
	plane.size = Vector2(45, 35)
	floor.mesh = plane
	var material: = StandardMaterial3D.new()
	material.albedo_color = Color("434f52")
	floor.material_override = material
	world.add_child(floor)
	for entry in entries:
		var model: = (load(entry.model) as PackedScene).instantiate() as Node3D
		model.position = Vector3((models.size() % 6 - 2.5) * 4.0, 0.1, (int(models.size() / 6) - 2) * 4.0)
		model.scale = Vector3.ONE * 0.5
		world.add_child(model)
		models.append(model)
	rig = StrategyCamera.new()
	world.add_child(rig)
	rig.map_clicked.connect( func(screen: Vector2, _order: bool):
		var best: = 55.0
		for i in models.size():
			if rig.camera.is_position_behind(models[i].global_position): continue
			var distance: = rig.camera.unproject_position(models[i].global_position).distance_to(screen)
			if distance < best: best = distance;index = i
		_refresh(false))
	var bar: = VBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -140
	root.add_child(bar)
	title = Label.new()
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bar.add_child(title)
	var buttons: = HBoxContainer.new()
	bar.add_child(buttons)
	for text in ["Previous", "All", "Next", "Close"]:
		var button: = Button.new()
		button.text = text
		button.custom_minimum_size.y = 48
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect( func():
			match text:
				"Previous": index = posmod(index - 1, entries.size());_refresh(true)
				"Next": index = (index + 1) % entries.size();_refresh(true)
				"All": rig.target = Vector3.ZERO;rig.distance = 55
				"Close": clock.paused = previous_pause;hide()
			)
		buttons.add_child(button)
	hide()
func _refresh(focus: bool) -> void :
	var entry: Dictionary = entries[index]
	title.text = "WEAPONS SHOWCASE · " + str(index + 1) + " / " + str(entries.size()) + "\n" + entry.name + " · " + entry.kind + " · " + entry.theme + "\nDrag to pan · Pinch to zoom · Models only; no battle orders"
	if focus:
		rig.target = models[index].position
		rig.distance = 8
func open() -> void :
	previous_pause = clock.paused
	clock.paused = true
	show()
	_refresh(true)
