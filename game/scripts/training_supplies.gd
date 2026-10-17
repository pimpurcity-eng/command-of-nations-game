class_name TrainingSupplies
extends Node3D
## The one-time aid manifests remain loaded in the world until explicitly unloaded.
var game: Node
var vehicles: Dictionary = {}

func setup(main: Node) -> void:
	game = main
	refresh()

func refresh() -> void:
	for id in TrainingScenario.AID_LOADS:
		if id not in game.session.training.aid_pending and id not in game.session.training.aid_received: continue
		if not vehicles.has(id): vehicles[id] = _vehicle(id)
		var loaded: bool = id in game.session.training.aid_pending
		vehicles[id].set_meta("loaded", loaded)
		vehicles[id].get_node("Weapons").visible = loaded
		vehicles[id].get_node("Resources").visible = loaded
		vehicles[id].get_node("Manifest").text = ("AMERICAN AID · ODESA" if id == "odesa" else "EUROPEAN AID · LVIV") + ("\n%d weapons · Tap to unload" % TrainingScenario.equipment_count(id) if loaded else "\nCargo unloaded")

func _vehicle(id: String) -> Node3D:
	var load_spec: Dictionary = TrainingScenario.AID_LOADS[id]
	var sea: bool = load_spec.mode == "sea"
	var node := Node3D.new()
	node.name = "AidShip" if sea else "EuropeanAidTrain"
	node.set_meta("destination", id)
	node.set_meta("donor", load_spec.donor)
	node.set_meta("cargo_equipment_count", TrainingScenario.equipment_count(id))
	node.set_meta("cargo_resources", load_spec.resources.duplicate())
	add_child(node)
	var city: Dictionary = game.buildings.city(id)
	var point: Vector2 = city.point
	if sea and city.has("naval_spawn"):
		point = GeographicProjection.project(city.naval_spawn.longitude, city.naval_spawn.latitude)
	node.position = Vector3(point.x, 0.08, point.y) if sea else game.map.position_at(point) + Vector3(0.15, 0.03, 0.15)
	if not sea:
		# The train waits at the station on Lviv's western edge, in the open, not among the
		# city blocks (owner 2026-10-17: the train has to be seen coming in).
		var towards_border: Vector2 = (GeographicProjection.project(23.9, 50.2) - point).normalized()
		node.position = game.map.position_at(point + towards_border * 1.25) + Vector3(0, 0.03, 0)
	if not sea:
		var border := GeographicProjection.project(23.9, 50.2)
		node.rotation.y = atan2(point.x - border.x, point.y - border.y)
	var model_path := "res://assets/library/transport/civil_container_t1_feeder.glb" if sea else "res://assets/library/transport/train_diesel_locomotive.glb"
	if ResourceLoader.exists(model_path):
		var model: Node3D = game.trade._convoy_visual(load_spec.mode, "materials", "ukraine", 1)
		model.scale = Vector3.ONE * (2.0 if sea else 2.5)
		node.add_child(model)
	else:
		# Visible geometry also works while optional private transport models download.
		_fallback_vehicle(node, sea)
	var weapons := Node3D.new()
	weapons.name = "Weapons"
	node.add_child(weapons)
	var index := 0
	for family in load_spec.equipment:
		for _number in int(load_spec.equipment[family]):
			var equipment := TrainingScenario.aid_equipment(id, family)
			var spec := EquipmentIdentity.spec(equipment)
			var weapon := UnitVisual.create(spec.visual_kind, Color("73bcff"), equipment, 1)
			weapon.scale = Vector3.ONE * 0.13
			weapon.position = Vector3((-0.15 if index % 2 == 0 else 0.15) if sea else 0.0, 0.23 if sea else 0.17, -0.56 + float(index / 2) * 0.25 if sea else -0.30 + float(index) * 0.16)
			weapons.add_child(weapon)
			index += 1
	var resources := Node3D.new()
	resources.name = "Resources"
	node.add_child(resources)
	if sea:
		for i in 4:
			_box(resources, Vector3(0.13, 0.13, 0.16), Vector3(-0.22 + float(i % 2) * 0.44, 0.25, 0.69 + float(i / 2) * 0.17), Color("96774a"))
	var label := Label3D.new()
	label.name = "Manifest"
	label.position.y = 1.2
	label.font_size = 44
	label.outline_size = 12
	label.outline_modulate = Color(0, 0, 0, 0.85)
	label.pixel_size = 0.0022
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Color("ffe0a0")
	node.add_child(label)
	return node

func _fallback_vehicle(node: Node3D, sea: bool) -> void:
	if sea:
		_box(node, Vector3(0.66, 0.22, 1.95), Vector3(0, 0.04, 0.08), Color("364657"))
		_box(node, Vector3(0.61, 0.06, 1.85), Vector3(0, 0.18, 0.08), Color("a2a7a6"))
		_box(node, Vector3(0.42, 0.35, 0.32), Vector3(0, 0.35, -0.77), Color("d2d7d3"))
	else:
		for i in 4:
			_box(node, Vector3(0.32, 0.10, 0.47), Vector3(0, 0.10, -0.65 + float(i) * 0.5), Color("595f57"))
			for x in [-0.17, 0.17]:
				_box(node, Vector3(0.04, 0.10, 0.30), Vector3(x, 0.04, -0.65 + float(i) * 0.5), Color("24292e"))
		_box(node, Vector3(0.30, 0.30, 0.42), Vector3(0, 0.26, -0.65), Color("376e9e"))

func _box(parent: Node3D, size: Vector3, position: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = position
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	parent.add_child(mesh)

## The arrival itself (owner 2026-10-17: "I still want the train coming in and the boat"):
## the ship sails in from the open sea to Odesa, the train rolls from the Polish border to Lviv.
func arrive(id: String, seconds: float = 6.0) -> void:
	refresh()
	if not vehicles.has(id): return
	var vehicle: Node3D = vehicles[id]
	var berth: Vector3 = vehicle.position
	var start: Vector3
	if id == "odesa":
		start = berth + Vector3(1.6, 0.0, 3.4)
	else:
		var border := GeographicProjection.project(23.9, 50.2)
		start = game.map.position_at(border) + Vector3(0, 0.03, 0)
	var heading := Vector2(berth.x - start.x, berth.z - start.z)
	if heading.length() > 0.01: vehicle.rotation.y = atan2(heading.x, heading.y)
	vehicle.position = start
	var tween := vehicle.create_tween()
	tween.tween_property(vehicle, "position", berth, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Keep the camera on the vehicle while it comes in.
	tween.parallel().tween_method(func(_v: float):
		if game != null and game.rig != null: game.rig.target = vehicle.position, 0.0, 1.0, seconds)

func focus(id: String) -> void:
	if not vehicles.has(id): return
	game.rig.target = vehicles[id].position
	game.rig.distance = 7.0
	game.rig._snap(1.0)

func pick(camera: Camera3D, screen: Vector2) -> String:
	var result := ""
	var nearest := 54.0
	for id in vehicles:
		var position: Vector3 = vehicles[id].global_position
		if camera.is_position_behind(position): continue
		var distance := camera.unproject_position(position).distance_to(screen)
		if distance < nearest:
			nearest = distance
			result = id
	return result
