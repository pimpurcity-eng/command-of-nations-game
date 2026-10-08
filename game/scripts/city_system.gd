class_name CitySystem
extends Node3D
signal city_selected(city: Dictionary)
var cities: Array = GeographicProjection.load_cities()
var armies: UnitSystem
var terrain: StrategicMap
var rig: StrategyCamera
var labels: Array[Button] = []
var leaders: Array[Line2D] = []
var national_labels: Array = []
var province_labels: Array = []
var label_layer: CanvasLayer
var districts: Dictionary = {}
var _building_ref: WeakRef
func setup(map: StrategicMap, camera_rig: StrategyCamera) -> void :
	terrain = map
	rig = camera_rig
	label_layer = CanvasLayer.new()
	label_layer.layer = 2
	add_child(label_layer)
	for city in cities:
		var nearest: = INF
		for territory in terrain.territories:
			if territory.country != city.country: continue
			if RegionData.contains(territory, city.point):
				city.sector = territory.id
				break
			var distance: float = city.point.distance_to(territory.center)
			if distance < nearest:
				nearest = distance
				city.sector = territory.id
		var district: = Node3D.new()
		district.position = terrain.position_at(city.point)
		district.scale = Vector3.ONE * 0.72
		add_child(district)
		districts[city.id] = district
		var ink: = StandardMaterial3D.new()
		ink.albedo_color = Color("73bcff") if city.country == "Ukraine" else Color("ef827c")
		_build_city_district(district, city, ink)
		var label: = Button.new()
		label.custom_minimum_size.y = 44
		label.text = ("★ " if city.get("capital", false) else "") + city.name.to_upper()
		label.tooltip_text = city.name + " · " + city.country + (" · Capital" if city.get("capital", false) else "")
		label.set_meta("capital", city.get("capital", false))
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color("efe9d3"))
		label.add_theme_color_override("font_outline_color", Color("07121b"))
		label.add_theme_constant_override("outline_size", 2)
		var style: = StyleBoxFlat.new()
		style.bg_color = Color(0.06, 0.07, 0.08, 0.72)
		style.expand_margin_top = -10
		style.expand_margin_bottom = -10
		style.border_color = ink.albedo_color.darkened(0.25)
		style.border_width_bottom = 0
		if city.get("capital", false):
			style.border_color = Color("d0b777")
			style.border_width_top = 0
		style.set_corner_radius_all(0)
		style.content_margin_left = 6
		style.content_margin_right = 6
		style.content_margin_top = 3
		style.content_margin_bottom = 3
		label.add_theme_stylebox_override("normal", style)
		var hover: = style.duplicate() as StyleBoxFlat
		hover.bg_color = Color("233945")
		label.add_theme_stylebox_override("hover", hover)
		label.add_theme_stylebox_override("pressed", hover)
		label.pressed.connect( func(): select_city(city))
		label_layer.add_child(label)
		labels.append(label)
		var leader: = Line2D.new()
		leader.width = 1
		leader.default_color = ink.albedo_color
		label_layer.add_child(leader)
		leaders.append(leader)
	for spec in [["UKRAINE", [[25.5, 49.3], [29.7, 49.6], [34.2, 50.0]]], ["RUSSIA", [[36.0, 53.0], [39.5, 54.0], [44.0, 54.6]]]]:
		var points: = PackedVector2Array()
		for coordinate in spec[1]: points.append(GeographicProjection.project(coordinate[0], coordinate[1]))
		var label: = CountryMapLabel.new()
		terrain.add_child(label)
		label.setup(spec[0], points, terrain)
		national_labels.append(label)
	var named: Dictionary = {}
	for province in terrain.territories:
		if not province.playable or named.has(province.title): continue
		named[province.title] = true
		var label: = _map_label(province.province.to_upper(), 11, Color("e3dcc6"))
		province_labels.append({"label": label, "point": province.center, "territory": province, "base_text": province.province.to_upper()})
func setup_buildings(system: BuildingSystem) -> void :
	_building_ref = weakref(system)
	system.changed.connect(sync_buildings)
	sync_buildings()
func sync_buildings() -> void :
	var system: BuildingSystem = _building_ref.get_ref() if _building_ref != null else null
	if system == null: return
	for city in cities:
		var district: Node3D = districts[city.id]
		for index in system.catalog.size():
			var definition: Dictionary = system.catalog[index]
			var current: = system.level(city.id, definition.id)
			var name: String = "Infrastructure_" + definition.id
			var visual: = district.get_node_or_null(NodePath(name)) as Node3D
			if current == 0:
				if visual != null: visual.hide()
				continue
			if visual == null:
				var appearance: = AssetRoster.appearance(definition.asset_roster_id, city.country.to_lower())
				visual = (load(appearance.model) as PackedScene).instantiate() as Node3D
				visual.name = name
				visual.position = Vector3(-0.88 + index * 0.63, 0.09, 0.96)
				district.add_child(visual)
			var infrastructure_world: = district.position + visual.position * district.scale
			visual.position.y = 0.09 + (terrain.elevation(Vector2(infrastructure_world.x, infrastructure_world.z)) - district.position.y) / district.scale.y
			visual.show()
			visual.scale = Vector3.ONE * (0.16 + 0.02 * (current - 1))
			visual.set_meta("building_level", current)
func _map_label(text: String, size: int, color: Color) -> Label:
	var label: = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("15222a"))
	label.add_theme_constant_override("outline_size", 2)
	label_layer.add_child(label)
	return label
func select_city(city: Dictionary) -> void :
	city_selected.emit(city)
func _process(_delta: float) -> void :
	if rig == null: return
	if armies != null:
		for city in cities:
			var controller: = controller_of(city)
			districts[city.id].visible = controller == "russia" or armies.point_visible(city.point)
			var captured: bool = controller != city.country.to_lower()
			var index: = cities.find(city)
			labels[index].text = ("★ " if city.get("capital", false) else "") + city.name.to_upper() + (" · YOURS" if captured and controller == "russia" else " · ENEMY" if captured else "")
			labels[index].tooltip_text = city.name + " · Controlled by " + controller.capitalize() + (" · Capital" if city.get("capital", false) else "")
	var transform: = label_layer.get_final_transform().affine_inverse()
	var viewport_size: = transform * get_viewport().get_visible_rect().size
	var bottom: = 174.0 if viewport_size.x < 700 and viewport_size.y > viewport_size.x else 164.0
	var top: = 132.0 if viewport_size.x > viewport_size.y and viewport_size.y < 600 else 168.0
	if top == 132:
		bottom = 124
		if viewport_size.x >= 800: top = 100
	var safe: = Rect2(Vector2(12, top), Vector2(viewport_size.x - 24, maxf(0, viewport_size.y - bottom - top)))
	var occupied: Array[Rect2] = []
	for i in cities.size():
		var anchor: = terrain.position_at(cities[i].point) + Vector3.UP * 0.7
		var point: = transform * rig.camera.unproject_position(anchor)
		var label: = labels[i]
		label.visible = false
		leaders[i].visible = false
		label.set_meta("screen_anchor", point)
		if rig.camera.is_position_behind(anchor) or not safe.has_point(point): continue
		var size: = label.size
		var offsets: = [Vector2( - size.x * 0.5, - size.y - 10), Vector2( - size.x * 0.5, 12), Vector2(16, - size.y * 0.5), Vector2( - size.x - 16, - size.y * 0.5), Vector2(16, - size.y - 18), Vector2( - size.x - 16, 18), Vector2( - size.x * 0.5, - size.y - 42), Vector2( - size.x * 0.5, 42)]
		for offset in offsets:
			var bounds: = Rect2(point + offset, size)
			if not safe.encloses(bounds): continue
			var clear: = true
			for previous in occupied:
				if bounds.grow(6).intersects(previous): clear = false
			if not clear: continue
			label.position = bounds.position
			label.visible = true
			occupied.append(bounds)
			var end: = Vector2(clampf(point.x, bounds.position.x, bounds.end.x), clampf(point.y, bounds.position.y, bounds.end.y))
			leaders[i].points = PackedVector2Array([point, end])
			leaders[i].visible = offset != offsets[0]
			break
	for label in national_labels: label.update_zoom(rig.rendered_distance)
	for entry in province_labels:
		var controller: String = entry.territory.controller
		var captured: bool = controller != entry.territory.owner
		entry.label.text = entry.base_text + (" · YOURS" if captured and controller == "russia" else " · ENEMY" if captured else "")
		entry.label.tooltip_text = "Controlled by " + controller.capitalize()
		var anchor: = terrain.position_at(entry.point)
		var point: = transform * rig.camera.unproject_position(anchor)
		entry.label.position = point - entry.label.size * 0.5
		var province: bool = province_labels.has(entry)
		if province: entry.label.position.y += 24
		var bounds: = Rect2(entry.label.position, entry.label.size)
		entry.label.visible = (rig.rendered_distance > 8 and rig.rendered_distance < 38 if province else rig.rendered_distance >= 38) and not rig.camera.is_position_behind(anchor) and safe.encloses(bounds)
		for previous in occupied:
			if bounds.grow(5).intersects(previous): entry.label.visible = false
		if entry.label.visible: occupied.append(bounds)
func pick_screen(screen: Vector2) -> Dictionary:
	var nearest: Dictionary = {}
	var radius: = 22.0 * get_window().content_scale_factor
	for city in cities:
		var anchor: = terrain.position_at(city.point) + Vector3.UP * 0.2
		if rig.camera.is_position_behind(anchor): continue
		var distance: = rig.camera.unproject_position(anchor).distance_to(screen)
		if distance < radius:
			radius = distance
			nearest = {"city": city, "distance": distance}
	return nearest
func controller_of(city: Dictionary) -> String:
	for province in terrain.territories:
		if province.id == city.sector: return province.controller
	return city.country.to_lower()
func _city_box(parent: Node3D, size: Vector3, position: Vector3, material: Material) -> void :
	var batches: Dictionary = parent.get_meta("building_batches", {})
	var key: = material.get_instance_id()
	if not batches.has(key):
		var tool: = SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tool.set_material(material)
		batches[key] = tool
	var mesh: = BoxMesh.new()
	mesh.size = size
	batches[key].append_from(mesh, 0, Transform3D(Basis.IDENTITY, position))
	parent.set_meta("building_batches", batches)
func _city_mesh(parent: Node3D, mesh: Mesh, position: Vector3, material: Material) -> void :
	var batches: Dictionary = parent.get_meta("building_batches", {})
	var key: = material.get_instance_id()
	if not batches.has(key):
		var tool: = SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tool.set_material(material)
		batches[key] = tool
	batches[key].append_from(mesh, 0, Transform3D(Basis.IDENTITY, position))
	parent.set_meta("building_batches", batches)
func _build_city_district(district: Node3D, city: Dictionary, ink: StandardMaterial3D) -> void :
	var asphalt: = StandardMaterial3D.new()
	asphalt.albedo_color = Color("55534b")
	asphalt.roughness = 1.0
	var paving: = StandardMaterial3D.new()
	paving.albedo_color = Color("aaa28b")
	paving.roughness = 1.0
	var garden: = StandardMaterial3D.new()
	garden.albedo_color = Color("78805b")
	garden.roughness = 1.0
	var roof: = StandardMaterial3D.new()
	roof.albedo_color = Color("936e5b")
	roof.roughness = 0.92
	var slate: = StandardMaterial3D.new()
	slate.albedo_color = Color("777b78")
	slate.roughness = 0.94
	var facades: Array[ShaderMaterial] = []
	for color in ["d1c9b5", "aaa99d", "b9b9af", "c0ad98"]:
		var material: = ShaderMaterial.new()
		material.shader = load("res://assets/building_facade.gdshader")
		material.set_shader_parameter("facade", Color(color))
		facades.append(material)


	for offset in [-0.4725, 0.0525, 0.5775]:

		for segment in 16:
			_city_box(district, Vector3(1.95 / 16.0, 0.012, 0.045), Vector3(-0.975 + (segment + 0.5) * 1.95 / 16.0, 0.018, offset), asphalt)
			_city_box(district, Vector3(0.045, 0.012, 1.75 / 16.0), Vector3(offset, 0.018, -0.875 + (segment + 0.5) * 1.75 / 16.0), asphalt)
	var rng: = RandomNumberGenerator.new()
	rng.seed = city.name.hash()
	var building_count: = 0
	for x in 18:
		for z in 18:
			if x in [4, 9, 14] or z in [4, 9, 14]: continue
			var position: = Vector3((x - 8.5) * 0.105, 0, (z - 8.5) * 0.105)

			if Vector2(position.x / 0.94, position.z / 0.8).length() > rng.randf_range(0.9, 1.12): continue
			if rng.randf() < 0.08:
				_city_box(district, Vector3(0.09, 0.01, 0.09), position + Vector3.UP * 0.017, garden)
				continue
			if absf(position.x) < 0.025 or absf(position.z) < 0.025: continue
			var central: = x in [6, 7, 8, 9] and z in [6, 7, 8, 9]
			var height: = rng.randf_range(0.18, 0.32) if central else rng.randf_range(0.06, 0.16)
			if central and city.name in ["Moscow", "Kyiv"]: height *= 1.3
			var width: = rng.randf_range(0.07, 0.095)
			var depth: = rng.randf_range(0.07, 0.095)
			_city_box(district, Vector3(0.1, 0.012, 0.1), position + Vector3.UP * 0.012, paving)
			var roof_material: Material = slate if central or rng.randf() < 0.3 else roof
			_city_box(district, Vector3(width, height, depth), position + Vector3(0, 0.02 + height * 0.5, 0), facades[rng.randi_range(0, 3)])
			if not central and rng.randf() < 0.72:
				var pitched_roof: = PrismMesh.new()
				pitched_roof.size = Vector3(width + 0.012, 0.035, depth + 0.012)
				_city_mesh(district, pitched_roof, position + Vector3(0, 0.035 + height, 0), roof_material)
			else:
				_city_box(district, Vector3(width + 0.008, 0.012, depth + 0.008), position + Vector3(0, 0.026 + height, 0), roof_material)
			building_count += 1
	district.set_meta("urban_building_count", building_count)


	var stone: = StandardMaterial3D.new()
	stone.albedo_color = Color("c4b9a0")
	_city_box(district, Vector3(0.28, 0.018, 0.28), Vector3(0, 0.022, 0), stone)
	var civic_height: = 0.28 if city.get("capital", false) else 0.12
	_city_box(district, Vector3(0.18, civic_height, 0.12), Vector3(0, civic_height * 0.5 + 0.03, -0.18), facades[0])
	_city_box(district, Vector3(0.19, 0.012, 0.13), Vector3(0, civic_height + 0.035, -0.18), roof)
	if city.get("capital", false):
		_city_box(district, Vector3(0.055, 0.13, 0.055), Vector3(0, civic_height + 0.1, -0.18), stone)
		var cap: = PrismMesh.new()
		cap.size = Vector3(0.075, 0.045, 0.075)
		_city_mesh(district, cap, Vector3(0, civic_height + 0.18, -0.18), roof)
	for tool in district.get_meta("building_batches").values():
		var visual: = MeshInstance3D.new()
		tool.index()
		var original: ArrayMesh = tool.commit()
		var arrays: = original.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]

		for i in vertices.size():
			var world: = district.position + vertices[i] * district.scale
			vertices[i].y += (terrain.elevation(Vector2(world.x, world.z)) - district.position.y) / district.scale.y
		arrays[Mesh.ARRAY_VERTEX] = vertices
		var fitted: = ArrayMesh.new()
		fitted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		fitted.surface_set_material(0, original.surface_get_material(0))
		visual.mesh = fitted
		district.add_child(visual)
	district.remove_meta("building_batches")
