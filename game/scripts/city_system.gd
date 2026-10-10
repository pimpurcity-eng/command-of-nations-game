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
		# The city's resource specialties as badges at the right end of its name tag.
		var specialties: = ResourceSites.city_resources(city.name)
		if not specialties.is_empty():
			style.content_margin_right = 8 + specialties.size() * 18
			hover.content_margin_right = style.content_margin_right
			var icons: = HBoxContainer.new()
			icons.add_theme_constant_override("separation", 1)
			icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icons.anchor_left = 1.0
			icons.anchor_right = 1.0
			icons.anchor_top = 0.5
			icons.anchor_bottom = 0.5
			icons.offset_left = -(4 + specialties.size() * 18)
			icons.offset_right = -4
			icons.offset_top = -8
			icons.offset_bottom = 8
			for resource in specialties:
				var badge: = TextureRect.new()
				badge.texture = ResourceSites.icon(resource)
				badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				badge.custom_minimum_size = Vector2(17, 17)
				badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
				icons.add_child(badge)
			label.add_child(icons)
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
				# Spread around the city edge instead of a straight row south of it.
				var around: = TAU * (index + 0.5) / maxf(system.catalog.size(), 1.0) + float(city.name.hash() % 100) * 0.01
				visual.position = Vector3(cos(around) * 1.08, 0.09, sin(around) * 1.08)
				visual.rotation.y = -around
				_paint_infrastructure(visual)
				district.add_child(visual)
			var infrastructure_world: = district.position + visual.position * district.scale
			visual.position.y = 0.09 + (terrain.elevation(Vector2(infrastructure_world.x, infrastructure_world.z)) - district.position.y) / district.scale.y
			visual.show()
			visual.scale = Vector3.ONE * (0.11 + 0.015 * (current - 1))
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
	plaza.albedo_color = Color("b3ab98")
	plaza.roughness = 1.0
	var park: = StandardMaterial3D.new()
	park.albedo_color = Color("5f7046")
	park.roughness = 1.0
	var towers: Array[ShaderMaterial] = [
		_facade("2f3a44", "4f7593", "3b4248", 0.0105, 0.009, 0.86, 0.78, 1.0),
		_facade("3c4a4f", "5d8a8f", "41484c", 0.0105, 0.010, 0.82, 0.74, 1.0),
		_facade("4a4136", "8a6f45", "3f3a34", 0.0105, 0.009, 0.84, 0.72, 0.9),
		_facade("8f8a80", "44515b", "5d5f60", 0.0115, 0.011, 0.55, 0.62, 0.4)]
	# Owner review: "paint all the buildings" - painted Soviet-era blocks and houses instead
	# of pale beige/white boxes.
	var blocks: Array[ShaderMaterial] = [
		_facade("b98a52", "3c4650", "6f6a62", 0.0125, 0.012, 0.42, 0.5, 0.0),
		_facade("a6604a", "39424a", "5e4a40", 0.0125, 0.012, 0.42, 0.5, 0.0),
		_facade("7f9670", "414a52", "5d625a", 0.0125, 0.013, 0.40, 0.48, 0.0),
		_facade("7c8ea3", "3a4047", "5a5f66", 0.0125, 0.012, 0.40, 0.5, 0.0),
		_facade("c2a35c", "3c4650", "6a5f50", 0.0125, 0.012, 0.42, 0.5, 0.0),
		_facade("8e5440", "3a4047", "4f4038", 0.0125, 0.012, 0.40, 0.5, 0.0)]
	var houses: Array[ShaderMaterial] = [
		_facade("d1b15e", "3f4850", "8e5b47", 0.016, 0.016, 0.38, 0.42, 0.0),
		_facade("c98a6e", "3f4850", "8e5b47", 0.016, 0.016, 0.38, 0.42, 0.0),
		_facade("9fb48a", "3f4850", "8e5b47", 0.016, 0.016, 0.38, 0.42, 0.0),
		_facade("c9b48f", "3f4850", "8e5b47", 0.016, 0.016, 0.38, 0.42, 0.0),
		_facade("a3634c", "3f4850", "8e5b47", 0.016, 0.016, 0.38, 0.42, 0.0)]
	var roof_tiles: Array[StandardMaterial3D] = []
	for color in ["8a3d2c", "6e4a36", "4f5f45", "5b4038"]:
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
	_city_block(district, Vector3(0.22, 0.012, 0.22), Vector3(0, 0.018, 0), base_angle, plaza)
	taken.append([Vector2.ZERO, 0.12])
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
		var r: = sqrt(rng.randf()) * 0.3
		var a: = rng.randf() * TAU
		var point: = Vector2(cos(a), sin(a)) * r
		var footprint: = rng.randf_range(0.05, 0.085)
		if not place.call(point, footprint * 0.72): continue
		var height: = lerpf(tallest, tallest * 0.35, r / 0.3) * rng.randf_range(0.7, 1.0)
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
		var r: float = rng.randf_range(0.26, 0.72) * float(reach.call(a))
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
		var r: float = rng.randf_range(0.3, 0.8) * float(reach.call(a))
		var point: = Vector2(cos(a), sin(a)) * r
		if place.call(point, 0.06): _city_block(district, Vector3(0.12, 0.011, 0.1), Vector3(point.x, 0.017, point.y), -a, park)
	# Low-rise houses with pitched roofs on the outskirts.
	for attempt in 1400:
		if built >= tower_count + 95 + 190: break
		var a: = rng.randf() * TAU
		var r: float = rng.randf_range(0.55, 1.0) * float(reach.call(a))
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
