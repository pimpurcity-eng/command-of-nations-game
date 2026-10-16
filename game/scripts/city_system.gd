class_name CitySystem
extends Node3D
signal city_selected(city: Dictionary)
## Clear space at the actual city destination. Sized for the enlarged map units.
const GARRISON_PLAZA_RADIUS := 0.30
# Owner 2026-10-14: "make the square in the middle a lot smaller".
## District units around the army spot kept free of buildings while an army stands there.
## Owner 2026-10-15: "The garden in the middle of the city went smaller, but the square didn't" -
## the bare ground around the garden now follows the garden instead of a tank-sized circle.
const GARRISON_CLEAR_RADIUS: = 0.46  # owner 2026-10-16: a little bigger again for the bigger units
## How far a capital's houses reach (other towns ~1.55), before the district scale.
const CAPITAL_REACH: = 1.97
const CAPITAL_EDGE: = 1.55
static var GARRISON_SQUARE := Rect2(-0.30, -0.28, 0.60, 0.56)
## Where a city's army stands (owner review 2026-10-14): "centre", or at the city's edge -
## "front" (facing the camera), "side" (east edge) or "outside" (just past the last houses).
## The spot is filled with buildings while no army is there.
static var garrison_layout: = "centre"  # owner 2026-10-15: armies stand in the middle of a round town (Call of War)
const GARRISON_LAYOUTS: = {"centre": Rect2(-0.31, -0.30, 0.62, 0.60),  # owner 2026-10-15: square way too big
	 "front": Rect2(-0.30, 0.62, 0.60, 0.50), "side": Rect2(0.50, -0.26, 0.50, 0.52), "outside": Rect2(-0.30, 1.16, 0.60, 0.46)}
## World offset of each city's army spot from the city point, keyed by city_key(point).
static var plaza_offsets: Dictionary = {}
static func city_key(point: Vector2) -> String: return "%.3f,%.3f" % [point.x, point.y]
static func plaza_point(city_point: Vector2) -> Vector2: return city_point + plaza_offsets.get(city_key(city_point), Vector2.ZERO)
## True for the city itself and for its army spot (which can lie at or past the city edge).
static func near_city(point: Vector2, city_point: Vector2) -> bool:
	return point.distance_to(city_point) < UnitSystem.CITY_RADIUS or point.distance_to(plaza_point(city_point)) < 0.45
const SHOW_COURTYARD_DISK: = false
## City look being reviewed with the owner (2026-10-14): classic, downtown, grid or green.
static var city_style: = "town"  # owner 2026-10-15: round, warm Call of War town; the grid looked like a parking lot
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
	GARRISON_SQUARE = GARRISON_LAYOUTS.get(garrison_layout, GARRISON_LAYOUTS.centre)
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
		# Owner 2026-10-14 ("cities connecting", Belgorod and Kharkiv): a city close to another is
		# drawn smaller so the two never run into each other (outer houses reach ~1.42 units).
		var neighbour: = INF
		for other in cities:
			if other != city: neighbour = minf(neighbour, city.point.distance_to(other.point))
		# Round towns reach ~1.55 units (uneven edge, houses), so leave a clear gap between the two.
		# Owner 2026-10-15: the capital is a bigger city with more buildings (reach ~1.97 units).
		var reach: float = CAPITAL_REACH if city.get("capital", false) else 1.55
		district.scale = Vector3.ONE * clampf((neighbour * 0.5 - 0.18) / reach, 0.34, 0.86 if city.get("capital", false) else 0.72)
		district.set_meta("reach", reach * district.scale.x)
		plaza_offsets[city_key(city.point)] = GARRISON_SQUARE.get_center() * district.scale.x
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
		style.content_margin_left = 46
		hover.content_margin_left = 46
		# Owner 2026-10-14: "put the resource where the flag is on the city tab, don't need the flag".
		var resources: Array = ResourceSites.city_resources(city.name)
		if not resources.is_empty():
			var symbol: = TextureRect.new()
			symbol.name = "Resource"
			symbol.texture = resource_picture(resources[0])
			symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			symbol.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
			symbol.tooltip_text = RESOURCE_WORDS.get(resources[0], str(resources[0]).to_upper())
			symbol.anchor_top = 0.5
			symbol.anchor_bottom = 0.5
			symbol.offset_left = 2
			symbol.offset_right = 42
			symbol.offset_top = -20
			symbol.offset_bottom = 20
			label.add_child(symbol)
		else:
			style.content_margin_left = 6
			hover.content_margin_left = 6
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
		for resource in resources.slice(1):
			var box: = _tag_box()
			var stack: = HBoxContainer.new()
			stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stack.add_theme_constant_override("separation", 4)
			box.add_child(stack)
			var picture: = TextureRect.new()
			picture.texture = resource_picture(resource)
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			# Owner 2026-10-14: "take off the word metal and oil... just put a symbol beside the city".
			picture.custom_minimum_size = Vector2(40, 40)
			picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
			picture.tooltip_text = RESOURCE_WORDS.get(resource, resource.to_upper())
			stack.add_child(picture)
			# A coloured edge in the resource's colour keeps the symbol readable on any terrain.
			var edge: = box.get_theme_stylebox("panel").duplicate() as StyleBoxFlat if box.get_theme_stylebox("panel") is StyleBoxFlat else null
			if edge != null:
				edge.border_color = RESOURCE_COLOURS.get(resource, Color.WHITE)
				edge.set_border_width_all(2)
				box.add_theme_stylebox_override("panel", edge)
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
		if UnitSystem.mobile_device() and FrameBudget.spent():
			await get_tree().process_frame
			FrameBudget.restart()
	_place_national_labels()
	var named: Dictionary = {}
	for province in terrain.territories:
		if not province.playable or named.has(province.title): continue
		named[province.title] = true
		var label: = _map_label(province.province.to_upper(), 11, Color("e3dcc6"))
		province_labels.append({"label": label, "point": province.center, "territory": province, "base_text": province.province.to_upper()})
## Owner 2026-10-15 ("when you take the Ukrainian property, the Russia symbol should go over a
## little bit more"): each country's name moves with the land it holds - its path is shifted by how
## far the centre of its provinces has moved since the start - and is rebuilt when land changes hands.
const NATIONAL_NAMES: = [["UKRAINE", "ukraine", [[25.5, 49.3], [29.7, 49.6], [34.2, 50.0]]], ["RUSSIA", "russia", [[36.0, 53.0], [39.5, 54.0], [44.0, 54.6]]]]
var _home_centres: Dictionary = {}
var _labels_revision: = -1
func _place_national_labels() -> void:
	for label in national_labels: label.queue_free()
	national_labels.clear()
	for spec in NATIONAL_NAMES:
		var held: = CountryMapLabel.held_centre(spec[1], terrain.territories)
		if not _home_centres.has(spec[1]):
			var home: = 0.0
			var sum: = Vector2.ZERO
			for t in terrain.territories:
				if t.playable and t.owner == spec[1]:
					var area: = 0.0
					for i in t.polygon.size(): area += (t.polygon[i] as Vector2).cross(t.polygon[(i + 1) % t.polygon.size()])
					sum += (t.center as Vector2) * absf(area)
					home += absf(area)
			_home_centres[spec[1]] = sum / home if home > 0.0 else held
		var shift: Vector2 = held - _home_centres[spec[1]] if held != Vector2.ZERO else Vector2.ZERO
		var points: = PackedVector2Array()
		for coordinate in spec[2]: points.append(GeographicProjection.project(coordinate[0], coordinate[1]) + shift)
		var label: = CountryMapLabel.new()
		terrain.add_child(label)
		label.setup(spec[0], points, terrain)
		if rig != null: label.update_zoom(rig.rendered_distance)
		national_labels.append(label)
	_labels_revision = armies.terrain_revision if armies != null else 0
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
				# Owner 2026-10-15 ("the buildings that are completed in a city, you should be able to
				# see them"): they stand in a ring just outside the houses instead of among them.
				var around: = TAU * (index + 0.5) / maxf(system.catalog.size(), 1.0) + float(city.name.hash() % 100) * 0.01
				var ring: float = (CAPITAL_EDGE if city.get("capital", false) else 1.22) + 0.3
				# Coastal towns (Odesa, Rostov): turn the spot round the town until it is on land.
				for turn in 24:
					var spot: = district.position + Vector3(cos(around) * ring, 0, sin(around) * ring) * district.scale
					if terrain == null or terrain.on_land(Vector2(spot.x, spot.z)): break
					around += TAU / 24.0
				visual.position = Vector3(cos(around) * ring, 0.09, sin(around) * ring)
				visual.rotation.y = -around
				if not visual.get_meta("original_colors", false): _paint_infrastructure(visual)
				district.add_child(visual)
			var infrastructure_world: = district.position + visual.position * district.scale
			visual.position.y = 0.09 + (terrain.elevation(Vector2(infrastructure_world.x, infrastructure_world.z)) - district.position.y) / district.scale.y
			visual.show()
			visual.scale = Vector3.ONE * (0.16 + 0.02 * (current - 1))
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
				# Aircraft land on the province point, so its airfield sits right under them.
				if kind == "airbase": visual.position = Vector3(0, 0.03, 0)
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
			set_garrison_visible(districts[city.id], _city_has_garrison(city))
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
	if armies != null and armies.terrain_revision != _labels_revision: _place_national_labels()
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
## Owner 2026-10-15 ("click the city and the unit separately"): the whole town is the city's tap
## area (its houses, not just the centre where the garrison stands); the caller checks armies first.
func pick_screen(screen: Vector2) -> Dictionary:
	var nearest: Dictionary = {}
	var best: = INF
	for city in cities:
		var anchor: = terrain.position_at(city.point) + Vector3.UP * 0.2
		if rig.camera.is_position_behind(anchor): continue
		var centre: = rig.camera.unproject_position(anchor)
		var distance: = centre.distance_to(screen)
		var district: Node3D = districts.get(city.id)
		var reach: float = float(district.get_meta("reach", 1.0)) * 0.85 if district != null else 0.6
		var edge: = rig.camera.unproject_position(anchor + rig.camera.global_transform.basis.x * reach).distance_to(centre)
		var radius: = maxf(edge, 34.0 * TapScale.of(self))
		if distance < radius and distance / radius < best:
			best = distance / radius
			nearest = {"city": city, "distance": distance}
	return nearest
func controller_of(city: Dictionary) -> String:
	for province in terrain.territories:
		if province.id == city.sector: return province.controller
	return city.country.to_lower()
func _city_box(parent: Node3D, size: Vector3, position: Vector3, material: Material) -> void :
	if not _city_footprint_on_land(parent, size, position): return
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
	var bounds: = mesh.get_aabb()
	if not _city_footprint_on_land(parent, bounds.size, position + bounds.get_center()): return
	var batches: Dictionary = parent.get_meta("building_batches", {})
	var key: = material.get_instance_id()
	if not batches.has(key):
		var tool: = SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tool.set_material(material)
		batches[key] = tool
	batches[key].append_from(mesh, 0, Transform3D(Basis.IDENTITY, position))
	parent.set_meta("building_batches", batches)
## Keep complete houses, roofs and park pieces on the drawn land. Odesa's city centre is
## beside the coast; checking the centre alone lets the rest of a building hang over water.
## Only the visual footprint changes: city coordinates, garrisons and naval spawns stay put.
func _city_footprint_on_land(parent: Node3D, size: Vector3, center: Vector3, angle: float = 0.0) -> bool:
	var district: Node3D = parent if parent.has_meta("clip_city_to_land") else parent.get_parent() as Node3D
	if district == null or not district.get_meta("clip_city_to_land", false): return true
	var turn: = Basis(Vector3.UP, angle)
	for x in [-0.5, 0.0, 0.5]:
		for z in [-0.5, 0.0, 0.5]:
			var local: Vector3 = center + turn * Vector3(size.x * x, 0, size.z * z)
			var world: Vector3 = district.position + local * district.scale
			if not terrain.on_land(Vector2(world.x, world.z)): return false
	return true
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
## Box faces: outward normal and the two in-face axes.
const _BOX_FACES: = [
	[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)], [Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
	[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)], [Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)], [Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)]]
func _city_block(parent: Node3D, size: Vector3, center: Vector3, angle: float, material: Material) -> void :
	if not _city_footprint_on_land(parent, size, center, angle): return
	var batches: Dictionary = parent.get_meta("building_batches", {})
	var key: = material.get_instance_id()
	if not batches.has(key):
		var tool: = SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tool.set_material(material)
		batches[key] = tool
	# Owner 2026-10-15 (start too slow): write the box directly. Generating a BoxMesh for each
	# of ~3,000 blocks took about 1 ms each; the shape and normals are identical.
	var tool: SurfaceTool = batches[key]
	var turn: = Basis(Vector3.UP, angle)
	var half: = size * 0.5
	for face in _BOX_FACES:
		var normal: Vector3 = turn * face[0]
		var u: Vector3 = face[1]
		var v: Vector3 = face[2]
		var corners: = [face[0] - u - v, face[0] + u - v, face[0] + u + v, face[0] - u + v]
		for index in [0, 2, 1, 0, 3, 2]:  # same winding as Godot's BoxMesh
			tool.set_normal(normal)
			tool.add_vertex(center + turn * (corners[index] * half))
	parent.set_meta("building_batches", batches)
## Modern city: glass skyscrapers downtown, Soviet-era apartment blocks around them,
## low-rise houses on the outskirts, radial avenues and a ring road.
func _build_city_district(district: Node3D, city: Dictionary, _ink: StandardMaterial3D) -> void :
	district.set_meta("clip_city_to_land", terrain != null and terrain._ground_ready)
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
		_facade("2f3a44", "536675", "3b4248", 0.018, 0.015, 0.86, 0.78, 1.0),
		_facade("3c4a4f", "596a75", "41484c", 0.018, 0.015, 0.82, 0.74, 1.0),
		_facade("454b50", "5e6b75", "42484d", 0.018, 0.015, 0.84, 0.72, 0.9),
		_facade("8f8a80", "44515b", "5d5f60", 0.020, 0.016, 0.55, 0.62, 0.4)]
	# Owner chose concept 1: grey concrete, subtle blue-grey glass and slate roofs.
	var blocks: Array[ShaderMaterial] = [
		_facade("a3a29d", "3c4650", "6f6a62", 0.022, 0.018, 0.42, 0.5, 0.0),
		_facade("8d9295", "39424a", "5b6166", 0.022, 0.018, 0.42, 0.5, 0.0),
		_facade("b0afa8", "414a52", "5d625a", 0.022, 0.019, 0.40, 0.48, 0.0),
		_facade("929ba2", "3a4047", "5a5f66", 0.022, 0.018, 0.40, 0.5, 0.0),
		_facade("a8aaa7", "3c4650", "64696b", 0.022, 0.018, 0.42, 0.5, 0.0),
		_facade("858d92", "3a4047", "535b60", 0.022, 0.018, 0.40, 0.5, 0.0)]
	var houses: Array[ShaderMaterial] = [
		_facade("b5b4ad", "3f4850", "555c63", 0.016, 0.016, 0.38, 0.42, 0.0),
		_facade("a4a8a9", "3f4850", "555c63", 0.016, 0.016, 0.38, 0.42, 0.0),
		_facade("b9bab4", "3f4850", "555c63", 0.016, 0.016, 0.38, 0.42, 0.0),
		_facade("aeb0ab", "3f4850", "555c63", 0.016, 0.016, 0.38, 0.42, 0.0),
		_facade("989ea1", "3f4850", "555c63", 0.016, 0.016, 0.38, 0.42, 0.0)]
	if city_style == "town":
		# Call of War towns: warm plaster walls and terracotta roofs, a few glass towers.
		blocks = [
			_facade("d8cbb0", "4a5560", "8a5a44", 0.022, 0.018, 0.42, 0.5, 0.0),
			_facade("c9b48f", "45505a", "7d4f3a", 0.022, 0.018, 0.42, 0.5, 0.0),
			_facade("e2d9c6", "4a5560", "8f6248", 0.022, 0.019, 0.40, 0.48, 0.0),
			_facade("c79e7e", "45505a", "754836", 0.022, 0.018, 0.40, 0.5, 0.0),
			_facade("b9b2a3", "4a5560", "6e6258", 0.022, 0.018, 0.42, 0.5, 0.0)]
		houses = [
			_facade("e6dcc4", "4f4a44", "8a5a44", 0.016, 0.016, 0.38, 0.42, 0.0),
			_facade("d9c39a", "4f4a44", "8a5a44", 0.016, 0.016, 0.38, 0.42, 0.0),
			_facade("cfa98a", "4f4a44", "8a5a44", 0.016, 0.016, 0.38, 0.42, 0.0),
			_facade("ece6d8", "4f4a44", "8a5a44", 0.016, 0.016, 0.38, 0.42, 0.0),
			_facade("c4b49a", "4f4a44", "8a5a44", 0.016, 0.016, 0.38, 0.42, 0.0)]
	var roof_tiles: Array[StandardMaterial3D] = []
	for color in (["a4553a", "8e4a33", "b5653f", "7a4a3a", "9c5b45"] if city_style == "town" else ["4f565e", "626568", "555e62", "474e56"]):
		var tile: = StandardMaterial3D.new()
		tile.albedo_color = Color(color)
		tile.roughness = 0.9
		roof_tiles.append(tile)
	# Dense streets and clustered skyline, with a reversible centre rather than a ring.
	var core := Node3D.new()
	core.name = "CityCore"
	district.add_child(core)
	var square := Node3D.new()
	square.name = "GarrisonSquare"
	district.add_child(square)
	var paving := ShaderMaterial.new()
	paving.shader = load("res://assets/garrison_park.gdshader")
	paving.set_shader_parameter("half_size", GARRISON_SQUARE.size * 0.5)
	var surface := PlaneMesh.new()
	surface.size = GARRISON_SQUARE.size
	surface.subdivide_width = 10
	surface.subdivide_depth = 10
	var centre := GARRISON_SQUARE.get_center()
	_city_mesh(square, surface, Vector3(centre.x, 0.005, centre.y), paving)
	# Park trees along the edge, clear of the middle where the garrison stands.
	var leaves: = StandardMaterial3D.new()
	leaves.albedo_color = Color("3f6a32")
	leaves.roughness = 1.0
	var trunk: = StandardMaterial3D.new()
	trunk.albedo_color = Color("5a4632")
	var park_rng: = RandomNumberGenerator.new()
	park_rng.seed = city.name.hash() + 7
	for i in 12:
		var t: = float(i) / 12.0 * 4.0
		var side: = int(t)
		var along: = fmod(t, 1.0) * 2.0 - 1.0
		var edge: = [Vector2(along, -1), Vector2(1, along), Vector2(-along, 1), Vector2(-1, -along)][side] as Vector2
		var spot: = centre + edge * (GARRISON_SQUARE.size * 0.5 - Vector2(0.04, 0.04))
		spot += Vector2(park_rng.randf_range(-0.015, 0.015), park_rng.randf_range(-0.015, 0.015))
		var stem: = CylinderMesh.new()
		stem.top_radius = 0.006
		stem.bottom_radius = 0.008
		stem.height = 0.04
		_city_mesh(square, stem, Vector3(spot.x, 0.025, spot.y), trunk)
		var crown: = SphereMesh.new()
		var r: = park_rng.randf_range(0.032, 0.045)
		crown.radius = r
		crown.height = r * 2.0
		crown.radial_segments = 8
		crown.rings = 4
		_city_mesh(square, crown, Vector3(spot.x, 0.045 + r * 0.8, spot.y), leaves)
	square.visible = false
	var built := 0
	var permanent := 0
	var removable := 0
	# A tight skyline behind the centre remains present while the garrison is visible.
	for row in range(3):
		for column in range(5 if capital else 4):
			var point := Vector2((column - (2.0 if capital else 1.5)) * 0.22, -0.79 - row * 0.20)
			point += Vector2(rng.randf_range(-0.025,0.025),rng.randf_range(-0.015,0.015))
			var height := (1.15 if capital else 0.82) * (0.70 + 0.30 * (1.0 - absf(point.x))) * rng.randf_range(0.70,1.0)
			var width := rng.randf_range(0.13,0.18)
			if not _city_footprint_on_land(district, Vector3(width, 0, width * 0.85), Vector3(point.x, 0, point.y)): continue
			_dense_tower(district, point, width, height, towers[(row+column)%towers.size()])
			built += 1
			permanent += 1
	# Style ground: asphalt for downtown and grid cities, a green base for the garden city.
	if city_style in ["downtown", "grid", "green"]:
		var ground_paint: = StandardMaterial3D.new()
		ground_paint.albedo_color = Color("3b5532") if city_style == "green" else Color("55595d")
		ground_paint.roughness = 1.0
		var plate: Mesh
		if city_style == "grid":
			plate = BoxMesh.new(); (plate as BoxMesh).size = Vector3(2.2, 0.004, 2.2)
		else:
			plate = CylinderMesh.new(); (plate as CylinderMesh).top_radius = 1.12 if city_style == "downtown" else 1.3; (plate as CylinderMesh).bottom_radius = (plate as CylinderMesh).top_radius; (plate as CylinderMesh).height = 0.004; (plate as CylinderMesh).radial_segments = 40
		_city_mesh(district, plate, Vector3(0, 0.002, 0), ground_paint)
	# Regular street blocks densely fill the city, including the removable garrison core.
	var span: int = 9 if capital else 7
	for row in range(-span, span + 1):
		for column in range(-span, span + 1):
			var point := Vector2(column * 0.18, row * 0.18)
			match city_style:
				"downtown": if point.length() > 1.02: continue
				"grid":
					if absf(point.x) > 1.0 or absf(point.y) > 1.0: continue
					# Straight avenues every fourth row and column.
					if (row % 4 == 0 or column % 4 == 0) and not GARRISON_SQUARE.has_point(point): continue
				"green": if point.length() > 1.22: continue
				"town":
					# Irregular round edge, like a real town seen from above.
					var bearing: = point.angle()
					var edge: = (CAPITAL_EDGE if capital else 1.22) * (1.0 + 0.10 * sin(3.0 * bearing + float(city.name.hash() % 7)) + 0.06 * sin(5.0 * bearing))
					if point.length() > edge: continue
				_: if point.length() > 1.34: continue
			if point.y < -0.66 and absf(point.x) < 0.57: continue # permanent skyline
			# Two small avenues run between rows of blocks, rather than cutting a circular void.
			if city_style == "classic" and column == 0 and row > 4: continue
			point += Vector2(rng.randf_range(-0.012,0.012),rng.randf_range(-0.012,0.012))
			var width := rng.randf_range(0.115,0.145)
			var radius := width * 0.8
			# Owner 2026-10-15: a tank parked in the city must not have buildings poking through
			# it. The cleared area is as big as a garrisoned tank; the park in it stays small.
			var inside := GARRISON_SQUARE.grow(radius).has_point(point) or point.distance_to(GARRISON_SQUARE.get_center()) < GARRISON_CLEAR_RADIUS + radius
			var target: Node3D = core if inside else district
			if city_style == "town": point += Vector2(rng.randf_range(-0.03,0.03),rng.randf_range(-0.03,0.03))
			# Cull the whole building before adding its base and roof, so no roof is left floating.
			if not _city_footprint_on_land(target, Vector3(width + 0.008, 0, width * 0.85 + 0.008), Vector3(point.x, 0, point.y)): continue
			if (city_style == "green" and point.length() > 0.62 and rng.randf() < 0.42) or (city_style == "town" and not inside and point.length() > (1.15 if capital else 0.85) and rng.randf() < 0.30):
				# Garden city: trees between the apartment blocks.
				var crown_size: = rng.randf_range(0.045, 0.065)
				var crown: = SphereMesh.new(); crown.radius = crown_size; crown.height = crown_size * 2.0; crown.radial_segments = 8; crown.rings = 4
				_city_mesh(target, crown, Vector3(point.x, 0.04 + crown_size, point.y), leaves)
				continue
			var central := point.length() < (0.78 if city_style == "downtown" else 0.6 if city_style == "grid" else 0.72 if capital else 0.55)
			if city_style == "grid": central = absf(point.x) < 0.5 and absf(point.y) < 0.5
			if central:
				var height := rng.randf_range(0.30,0.65) * (1.25 if capital else 1.0)
				if city_style == "town": height *= 0.8
				if city_style == "downtown": height *= 1.0 + 0.6 * (1.0 - point.length() / 0.78)
				_dense_tower(target, point, width, height, towers[rng.randi_range(0,towers.size()-1)])
			elif point.length() < (1.3 if capital else 1.01):
				var height := rng.randf_range(0.13,0.25)
				_city_block(target,Vector3(width,height,width*0.78),Vector3(point.x,0.02+height*0.5,point.y),0,blocks[rng.randi_range(0,blocks.size()-1)])
				# Roof parapets make apartments read as buildings, not featureless blocks.
				_city_block(target,Vector3(width*0.9,0.018,width*0.7),Vector3(point.x,0.02+height+0.009,point.y),0,roof_tiles[1])
			else:
				var height := rng.randf_range(0.065,0.10)
				_city_block(target,Vector3(width,height,width*0.78),Vector3(point.x,0.02+height*0.5,point.y),0,houses[rng.randi_range(0,houses.size()-1)])
				var roof := PrismMesh.new()
				roof.size = Vector3(width+0.008,0.04,width*0.78+0.008)
				_city_mesh(target,roof,Vector3(point.x,0.02+height+0.02,point.y),roof_tiles[rng.randi_range(0,roof_tiles.size()-1)])
			built += 1
			if inside: removable += 1
			else: permanent += 1
	district.set_meta("urban_building_count",built)
	district.set_meta("permanent_building_count",permanent)
	district.set_meta("core_building_count",removable)
	district.set_meta("garrison_plaza_radius",GARRISON_PLAZA_RADIUS*district.scale.x)
	_finish_city_batches(district,district)
	_finish_city_batches(core,district)
	_finish_city_batches(square,district)
	set_garrison_visible(district,false)

func _dense_tower(parent: Node3D, point: Vector2, width: float, height: float, material: Material) -> void:
	if not _city_footprint_on_land(parent, Vector3(width, 0, width * 0.85), Vector3(point.x, 0, point.y)): return
	_city_block(parent,Vector3(width,height,width*0.85),Vector3(point.x,0.02+height*0.5,point.y),0,material)
	var crown := height*0.16
	_city_block(parent,Vector3(width*0.70,crown,width*0.60),Vector3(point.x,0.02+height+crown*0.5,point.y),0,material)

func _finish_city_batches(parent: Node3D, district: Node3D) -> void:
	if not parent.has_meta("building_batches"): return
	for tool in parent.get_meta("building_batches",{}).values():
		var visual := MeshInstance3D.new()
		tool.index()
		var original: ArrayMesh = tool.commit()
		var arrays := original.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		# Owner 2026-10-15 (start too slow): one height lookup per ground position; a box's 24
		# corners share 4 of them. Same heights, about six times fewer lookups.
		var heights: Dictionary = {}
		for i in vertices.size():
			var world := district.position + vertices[i] * district.scale
			var ground := Vector2(world.x,world.z)
			if not heights.has(ground): heights[ground] = terrain.elevation(ground)
			vertices[i].y += (float(heights[ground])-district.position.y)/district.scale.y
		arrays[Mesh.ARRAY_VERTEX] = vertices
		var fitted := ArrayMesh.new()
		fitted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		fitted.surface_set_material(0,original.surface_get_material(0))
		visual.mesh = fitted
		parent.add_child(visual)
	parent.remove_meta("building_batches")

static func set_garrison_visible(district: Node3D, occupied: bool) -> void:
	district.get_node("CityCore").visible = not occupied
	district.get_node("GarrisonSquare").visible = occupied
	district.set_meta("has_garrison",occupied)

func _city_has_garrison(city: Dictionary) -> bool:
	if armies == null: return false
	for unit in armies.units:
		if unit.health <= 0 or armies.is_naval(unit): continue
		if armies.air.is_air(unit) and unit.get("flight_mode","grounded") != "grounded": continue
		if not armies.visible_to_player(unit): continue
		var at := Vector2(unit.node.position.x,unit.node.position.z)
		if near_city(at, city.point): return true
	return false



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
