class_name CitySystem
extends Node3D
signal city_selected(city: Dictionary)
## Clear space at the actual city destination. Sized for the enlarged map units.
const GARRISON_PLAZA_RADIUS := 0.70
const SHOW_COURTYARD_DISK: = false
const RESOURCE_WORDS: = {"materials": "METAL", "electronics": "RARE EARTHS", "fuel": "OIL", "food": "FOOD"}
const RESOURCE_COLOURS: = {"materials": Color("d4dade"), "electronics": Color("d7a8ff"), "fuel": Color("ff9a7a"), "food": Color("9ee07e")}
var cities: Array = GeographicProjection.load_cities()
var armies: UnitSystem
var terrain: StrategicMap
var rig: StrategyCamera
var labels: Array[Button] = []
var rural_districts: Dictionary = {}
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
		label.text = spaced(city.name)
		label.tooltip_text = city.name + " · " + city.country + (" · Capital" if city.get("capital", false) else "")
		label.set_meta("capital", city.get("capital", false))
		label.add_theme_font_size_override("font_size", 19)
		label.add_theme_font_override("font", StrategyTheme.font("Oswald", 500))
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
		# Call of War city tag (owner approved preview 2026-10-13): flag, spaced name, and under
		# it a box with the city's resource and, for capitals, a star with its victory points.
		style.content_margin_left = 40
		hover.content_margin_left = 40
		var flag: = FlagSwatch.new()
		flag.name = "Flag"
		flag.country = controller_of(city)
		flag.anchor_top = 0.5
		flag.anchor_bottom = 0.5
		flag.offset_left = 7
		flag.offset_right = 33
		flag.offset_top = -8
		flag.offset_bottom = 8
		label.add_child(flag)
		var boxes: = HBoxContainer.new()
		boxes.name = "Boxes"
		boxes.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boxes.add_theme_constant_override("separation", 4)
		boxes.anchor_top = 1.0
		boxes.anchor_bottom = 1.0
		boxes.offset_left = 36
		boxes.offset_top = -6
		boxes.offset_bottom = 34
		# Owner 2026-10-13: "I can't tell what resource it is" - a big icon with its name.
		for resource in ResourceSites.city_resources(city.name):
			var box: = _tag_box()
			var stack: = HBoxContainer.new()
			stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stack.add_theme_constant_override("separation", 4)
			box.add_child(stack)
			var picture: = TextureRect.new()
			picture.texture = resource_picture(resource)
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			picture.custom_minimum_size = Vector2(34, 34)
			picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stack.add_child(picture)
			var word: = Label.new()
			word.text = RESOURCE_WORDS.get(resource, resource.to_upper())
			word.add_theme_font_size_override("font_size", 16)
			word.add_theme_font_override("font", StrategyTheme.font("Oswald", 600))
			word.add_theme_color_override("font_color", RESOURCE_COLOURS.get(resource, Color.WHITE))
			word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			stack.add_child(word)
			boxes.add_child(box)
		if city.get("capital", false):
			var star: = _tag_box()
			var points: = Label.new()
			points.text = "★ " + str(VictoryRules.PROVINCE_POINTS + VictoryRules.CAPITAL_POINTS)
			points.add_theme_font_size_override("font_size", 20)
			points.add_theme_color_override("font_color", Color("ecc86e"))
			star.add_child(points)
			boxes.add_child(star)
		label.add_child(boxes)
		label.pressed.connect( func(): select_city(city))
		label_layer.add_child(label)
		labels.append(label)
		var leader: = Line2D.new()
		leader.width = 1
		leader.default_color = ink.albedo_color
		label_layer.add_child(leader)
		leaders.append(leader)
		if OS.has_feature("mobile"):
			await get_tree().process_frame
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
			var model_path: = FacilityVisual.path(definition, city.country.to_lower(), current)
			if visual != null and visual.get_meta("facility_model", "") != model_path:
				district.remove_child(visual);visual.queue_free();visual = null
			if visual == null:
				visual = FacilityVisual.create(definition, city.country.to_lower(), current)
				visual.name = name
				# Spread around the city edge instead of a straight row south of it.
				var around: = TAU * (index + 0.5) / maxf(system.catalog.size(), 1.0) + float(city.name.hash() % 100) * 0.01
				visual.position = Vector3(cos(around) * 1.08, 0.09, sin(around) * 1.08)
				visual.rotation.y = -around
				if not visual.get_meta("original_colors", false): _paint_infrastructure(visual)
				district.add_child(visual)
			var infrastructure_world: = district.position + visual.position * district.scale
			visual.position.y = 0.09 + (terrain.elevation(Vector2(infrastructure_world.x, infrastructure_world.z)) - district.position.y) / district.scale.y
			visual.show()
			visual.scale = Vector3.ONE * (0.11 + 0.015 * (current - 1))
			visual.set_meta("building_level", current)
	sync_province_buildings(system)
func sync_province_buildings(system: BuildingSystem) -> void:
	for id in system.provinces.levels:
		var place: Dictionary = system.provinces.place(id)
		for index in ProvinceConstruction.ALLOWED.size():
			var kind: String = ProvinceConstruction.ALLOWED[index]
			var current: = system.provinces.level(id,kind)
			if current <= 0: continue
			if not rural_districts.has(id):
				var group: = Node3D.new()
				group.name = "ProvinceBuildings_"+str(rural_districts.size())
				group.position = terrain.position_at(place.point)
				add_child(group);rural_districts[id] = group
			var group: Node3D = rural_districts[id]
			var visual: = group.get_node_or_null(NodePath(kind)) as Node3D
			var definition: = system.spec(kind)
			var model_path: = FacilityVisual.path(definition, place.country.to_lower(), current, true)
			if visual != null and visual.get_meta("facility_model", "") != model_path:
				group.remove_child(visual);visual.queue_free();visual = null
			if visual == null:
				visual = FacilityVisual.create(definition, place.country.to_lower(), current, true)
				visual.name = kind
				var angle: = TAU*index/ProvinceConstruction.ALLOWED.size()
				visual.position = Vector3(cos(angle)*0.28,0.03,sin(angle)*0.28)
				if not visual.get_meta("original_colors", false): _paint_infrastructure(visual)
				group.add_child(visual)
			visual.scale = Vector3.ONE*(0.13+0.015*(current-1))
			visual.set_meta("building_level",current)
	# Restoring an older save also removes later, unsaved province structures.
	for id in rural_districts:
		for child in rural_districts[id].get_children(): child.visible = system.provinces.level(id,str(child.name)) > 0

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
## Performance (owner 2026-10-13, lag with 20 armies): city ownership, visibility and label
## text update 4 times a second; label positions only when the camera moved or that changed.
var _state_timer: = 0.0
var _view_key: Array = []
func _process(delta: float) -> void :
	if rig == null: return
	if labels.size() != cities.size(): return
	_state_timer -= delta
	var view_key: Array = [rig.camera.global_transform, get_viewport().get_visible_rect().size, rig.rendered_distance]
	if _state_timer > 0.0 and view_key == _view_key: return
	_view_key = view_key
	if _state_timer <= 0.0 and armies != null:
		_state_timer = 0.25
		for city in cities:
			var controller: = controller_of(city)
			districts[city.id].visible = true
			for facility in districts[city.id].get_children():
				if facility.has_meta("building_level"): facility.visible = controller == GameSession.player_country or armies.point_visible(city.point)
			var captured: bool = controller != city.country.to_lower()
			var index: = cities.find(city)
			labels[index].text = spaced(city.name) + (" · YOURS" if captured and controller == GameSession.player_country else " · ENEMY" if captured else "")
			var flag: = labels[index].get_node_or_null("Flag") as FlagSwatch
			if flag != null and flag.country != controller:
				flag.country = controller
				flag.queue_redraw()
			labels[index].tooltip_text = city.name + " · Controlled by " + controller.capitalize() + (" · Capital" if city.get("capital", false) else "")
	if _state_timer == 0.25 and armies != null:
		var system: BuildingSystem = _building_ref.get_ref() if _building_ref != null else null
		if system != null:
			for id in rural_districts:
				var place: Dictionary = system.provinces.place(id)
				rural_districts[id].visible = system.economy.controlled(place,GameSession.player_country) or armies.point_visible(place.point)
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
			# Include the resource / capital boxes under the name so tags never overlap them.
			var boxes: = label.get_node_or_null("Boxes") as Control
			var reach: = maxf(size.x, 36.0 + (boxes.size.x if boxes != null else 0.0))
			var bounds: = Rect2(point + offset, Vector2(reach, size.y + 40))
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
		entry.label.text = entry.base_text + (" · YOURS" if captured and controller == GameSession.player_country else " · ENEMY" if captured else "")
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
	var radius: = 34.0 * get_window().content_scale_factor  # owner: cities were hard to tap
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
## Owner review: the factory/warehouse models were bare white. Their pale surfaces get
## painted concrete walls and green-grey roofs; darker details keep their colour. Painted
## materials are shared (cached) so destroyed or replaced buildings never free them in use.
var _painted: Dictionary = {}
func _paint_infrastructure(root: Node) -> void :
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = node
		if mesh_instance.mesh == null: continue
		for surface in mesh_instance.mesh.get_surface_count():
			var source: = mesh_instance.get_active_material(surface) as BaseMaterial3D
			if source == null: continue
			var key: = source.get_instance_id()
			if not _painted.has(key):
				var paint: = source.duplicate() as BaseMaterial3D
				var tone: = source.albedo_color
				if tone.get_luminance() > 0.55:
					paint.albedo_color = Color("8d877a") if surface % 2 == 0 else Color("5f6b58")
				else: paint.albedo_color = tone.darkened(0.15)
				paint.roughness = 0.9
				_painted[key] = paint
			mesh_instance.set_surface_override_material(surface, _painted[key])
func _facade(color: String, glass: String, roof: String, floor_height: float, bay: float, window_w: float, window_h: float, shine: float) -> ShaderMaterial:
	var material: = ShaderMaterial.new()
	material.shader = load("res://assets/building_facade.gdshader")
	material.set_shader_parameter("facade", Color(color).darkened(0.1))  # weathered paint
	material.set_shader_parameter("glass", Color(glass))
	material.set_shader_parameter("roof", Color(roof))
	material.set_shader_parameter("floor_height", floor_height)
	material.set_shader_parameter("bay_width", bay)
	material.set_shader_parameter("window_width", window_w)
	material.set_shader_parameter("window_height", window_h)
	material.set_shader_parameter("shine", shine)
	return material
func _city_block(parent: Node3D, size: Vector3, center: Vector3, angle: float, material: Material) -> void :
	var batches: Dictionary = parent.get_meta("building_batches", {})
	var key: = material.get_instance_id()
	if not batches.has(key):
		var tool: = SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tool.set_material(material)
		batches[key] = tool
	var mesh: = BoxMesh.new()
	mesh.size = size
	batches[key].append_from(mesh, 0, Transform3D(Basis(Vector3.UP, angle), center))
	parent.set_meta("building_batches", batches)
## Modern city: glass skyscrapers downtown, Soviet-era apartment blocks around them,
## low-rise houses on the outskirts, radial avenues and a ring road.
func _build_city_district(district: Node3D, city: Dictionary, _ink: StandardMaterial3D) -> void :
	var rng: = RandomNumberGenerator.new()
	rng.seed = city.name.hash()
	var capital: bool = city.get("capital", false)
	var plaza: = StandardMaterial3D.new()
	plaza.albedo_color = Color("a9aaac")
	plaza.roughness = 1.0
	var park: = StandardMaterial3D.new()
	park.albedo_color = Color("5f7046")
	park.roughness = 1.0
	var towers: Array[ShaderMaterial] = [
		_facade("2f3a44", "536675", "3b4248", 0.0105, 0.009, 0.86, 0.78, 1.0),
		_facade("3c4a4f", "596a75", "41484c", 0.0105, 0.010, 0.82, 0.74, 1.0),
		_facade("454b50", "5e6b75", "42484d", 0.0105, 0.009, 0.84, 0.72, 0.9),
		_facade("8f8a80", "44515b", "5d5f60", 0.0115, 0.011, 0.55, 0.62, 0.4)]
	# Owner chose concept 1: grey concrete, subtle blue-grey glass and slate roofs.
	var blocks: Array[ShaderMaterial] = [
		_facade("a3a29d", "3c4650", "6f6a62", 0.0125, 0.012, 0.42, 0.5, 0.0),
		_facade("8d9295", "39424a", "5b6166", 0.0125, 0.012, 0.42, 0.5, 0.0),
		_facade("b0afa8", "414a52", "5d625a", 0.0125, 0.013, 0.40, 0.48, 0.0),
		_facade("929ba2", "3a4047", "5a5f66", 0.0125, 0.012, 0.40, 0.5, 0.0),
		_facade("a8aaa7", "3c4650", "64696b", 0.0125, 0.012, 0.42, 0.5, 0.0),
		_facade("858d92", "3a4047", "535b60", 0.0125, 0.012, 0.40, 0.5, 0.0)]
	var houses: Array[ShaderMaterial] = [
		_facade("b5b4ad", "3f4850", "555c63", 0.016, 0.016, 0.38, 0.42, 0.0),
		_facade("a4a8a9", "3f4850", "555c63", 0.016, 0.016, 0.38, 0.42, 0.0),
		_facade("b9bab4", "3f4850", "555c63", 0.016, 0.016, 0.38, 0.42, 0.0),
		_facade("aeb0ab", "3f4850", "555c63", 0.016, 0.016, 0.38, 0.42, 0.0),
		_facade("989ea1", "3f4850", "555c63", 0.016, 0.016, 0.38, 0.42, 0.0)]
	var roof_tiles: Array[StandardMaterial3D] = []
	for color in ["4f565e", "626568", "555e62", "474e56"]:
		var tile: = StandardMaterial3D.new()
		tile.albedo_color = Color(color)
		tile.roughness = 0.9
		roof_tiles.append(tile)
	var taken: Array = []  # [Vector2 position, radius]
	var avenues: Array = []
	var avenue_count: = rng.randi_range(4, 6)
	var base_angle: = rng.randf() * TAU
	for i in avenue_count:
		var angle: = base_angle + TAU * i / avenue_count + rng.randf_range(-0.2, 0.2)
		avenues.append(angle)
		# Owner review: no extra road strips inside cities; the avenues stay as gaps between
		# the buildings (streets) without asphalt bands radiating from the centre.
	# Irregular city outline instead of a perfect circle.
	var phase_a: = rng.randf() * TAU
	var phase_b: = rng.randf() * TAU
	var reach: = func(angle: float) -> float:
		return 0.86 + 0.13 * sin(2.0 * angle + phase_a) + 0.09 * sin(3.0 * angle + phase_b)
	var courtyard := CylinderMesh.new()
	courtyard.top_radius = GARRISON_PLAZA_RADIUS
	courtyard.bottom_radius = GARRISON_PLAZA_RADIUS
	courtyard.height = 0.008
	courtyard.radial_segments = 48
	# Owner 2026-10-13: "take out the disks" - the centre stays clear for the garrison, but
	# no pavement disk is drawn (it read as a white disc on phones).
	if SHOW_COURTYARD_DISK: _city_mesh(district, courtyard, Vector3(0, 0.004, 0), plaza)
	district.set_meta("garrison_plaza_radius", GARRISON_PLAZA_RADIUS * district.scale.x)
	taken.append([Vector2.ZERO, GARRISON_PLAZA_RADIUS + 0.025])
	var place: = func(point: Vector2, radius: float) -> bool:
		for angle in avenues:
			var direction: = Vector2(cos(angle), sin(angle))
			var along: = point.dot(direction)
			if along > 0 and absf(point.cross(direction)) < radius + 0.022: return false
		for item in taken:
			if point.distance_to(item[0]) < radius + item[1] + 0.008: return false
		taken.append([point, radius])
		return true
	var built: = 0
	# Downtown skyscrapers.
	var tower_count: = 22 if capital else 13
	var tallest: = 1.05 if capital else 0.62
	for attempt in 400:
		if built >= tower_count: break
		var r: = rng.randf_range(0.79, 1.03)
		# Tall skyline behind the courtyard; lower buildings encircle the units.
		var a: = -PI * 0.5 + rng.randf_range(-0.9, 0.9)
		var point: = Vector2(cos(a), sin(a)) * r
		var footprint: = rng.randf_range(0.05, 0.085)
		if not place.call(point, footprint * 0.72): continue
		var height: = lerpf(tallest, tallest * 0.35, (r - 0.79) / 0.24) * rng.randf_range(0.7, 1.0)
		var material: = towers[rng.randi_range(0, towers.size() - 1)]
		var turn: = base_angle + rng.randf_range(-0.15, 0.15)
		_city_block(district, Vector3(footprint, height, footprint * rng.randf_range(0.75, 1.0)), Vector3(point.x, 0.02 + height * 0.5, point.y), turn, material)
		if rng.randf() < 0.45:
			var crown: = height * rng.randf_range(0.12, 0.25)
			_city_block(district, Vector3(footprint * 0.66, crown, footprint * 0.66), Vector3(point.x, 0.02 + height + crown * 0.5, point.y), turn, material)
			if height > tallest * 0.8:
				_city_block(district, Vector3(0.006, 0.12, 0.006), Vector3(point.x, 0.02 + height + crown + 0.06, point.y), turn, plaza)
		built += 1
	# Apartment blocks (long slabs) around downtown.
	for attempt in 900:
		if built >= tower_count + 95: break
		var a: = rng.randf() * TAU
		var r: float = rng.randf_range(0.72, 1.02) * float(reach.call(a))
		var point: = Vector2(cos(a), sin(a)) * r
		var length: = rng.randf_range(0.1, 0.19)
		if not place.call(point, length * 0.5): continue
		var height: = rng.randf_range(0.07, 0.17)
		var facing: = -a + (PI * 0.5 if rng.randf() < 0.6 else 0.0)
		_city_block(district, Vector3(length, height, 0.036), Vector3(point.x, 0.02 + height * 0.5, point.y), facing, blocks[rng.randi_range(0, blocks.size() - 1)])
		built += 1
	# Parks.
	for attempt in 60:
		var a: = rng.randf() * TAU
		var r: float = rng.randf_range(0.72, 1.0) * float(reach.call(a))
		var point: = Vector2(cos(a), sin(a)) * r
		if place.call(point, 0.06): _city_block(district, Vector3(0.12, 0.011, 0.1), Vector3(point.x, 0.017, point.y), -a, park)
	# Low-rise houses with pitched roofs on the outskirts.
	for attempt in 1400:
		if built >= tower_count + 95 + 190: break
		var a: = rng.randf() * TAU
		var r: float = rng.randf_range(0.83, 1.08) * float(reach.call(a))
		var point: = Vector2(cos(a), sin(a)) * r
		if not place.call(point, 0.022): continue
		var height: = rng.randf_range(0.026, 0.05)
		var turn: = -a + rng.randf_range(-0.2, 0.2)
		var width: = rng.randf_range(0.032, 0.048)
		_city_block(district, Vector3(width, height, width * 0.8), Vector3(point.x, 0.02 + height * 0.5, point.y), turn, houses[rng.randi_range(0, houses.size() - 1)])
		var pitched: = PrismMesh.new()
		pitched.size = Vector3(width + 0.006, 0.018, width * 0.8 + 0.006)
		var batches: Dictionary = district.get_meta("building_batches", {})
		var roof: StandardMaterial3D = roof_tiles[rng.randi_range(0, roof_tiles.size() - 1)]
		var key: = roof.get_instance_id()
		if not batches.has(key):
			var tool: = SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			tool.set_material(roof)
			batches[key] = tool
			district.set_meta("building_batches", batches)
		batches[key].append_from(pitched, 0, Transform3D(Basis(Vector3.UP, turn), Vector3(point.x, 0.02 + height + 0.009, point.y)))
		built += 1
	district.set_meta("urban_building_count", built)
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


## "MOSCOW" -> "M O S C O W", like Call of War city names.
static func spaced(name: String) -> String:
	var letters: PackedStringArray = []
	for character in name.to_upper(): letters.append(character)
	return " ".join(letters)

## The owner's resource icon (model pack) for a city resource, or the simple icon.
static func resource_picture(resource: String) -> Texture2D:
	var file: String = {"materials": "metal", "electronics": "rare_earth", "fuel": "oil", "food": "food"}.get(resource, "")
	var path: = "res://assets/library/buildings_oct12/resource_%s_icon128.png" % file
	if not file.is_empty() and ResourceLoader.exists(path): return load(path)
	return ResourceSites.icon(resource)

static func _tag_box() -> PanelContainer:
	var box: = PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back: = StyleBoxFlat.new()
	back.bg_color = Color(0.11, 0.12, 0.13, 0.92)
	back.set_corner_radius_all(4)
	back.set_content_margin_all(2)
	back.content_margin_left = 3
	back.content_margin_right = 3
	back.shadow_color = Color(0, 0, 0, 0.35)
	back.shadow_size = 2
	box.add_theme_stylebox_override("panel", back)
	return box

## The controlling country's flag on a city tag.
class FlagSwatch extends Control:
	var country: = ""
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var colours: Array = [Color("2f6bc7"), Color("f2c418")] if country == "ukraine" else [Color("f2f2ee"), Color("2853a8"), Color("c8372d")]
		for i in colours.size():
			draw_rect(Rect2(Vector2(0, size.y * i / colours.size()), Vector2(size.x, size.y / colours.size())), colours[i])
		draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK, false, 1.0)


## Owner 2026-10-13: a nuked city is left a burned-out ruin - buildings collapse to a fraction
## of their height and are scorched black.
static var _burnt: StandardMaterial3D
func devastate(city_id: String) -> void:
	if not districts.has(city_id): return
	var district: Node3D = districts[city_id]
	if district.get_meta("devastated", false): return
	district.set_meta("devastated", true)
	if _burnt == null:
		_burnt = StandardMaterial3D.new()
		_burnt.albedo_color = Color(0.13, 0.12, 0.11)
		_burnt.roughness = 1.0
	for node in district.find_children("*", "MeshInstance3D", true, false):
		var mesh: = node as MeshInstance3D
		mesh.material_override = _burnt
		mesh.scale.y *= 0.35
