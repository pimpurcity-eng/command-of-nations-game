class_name EuropeMapView
extends Node3D
## Also shows the 100-player world map (scenes/world_map.tscn sets map_id = "world100").
## The separate 20-player Europe map (owner requests 2026-10-12): no resources and no units
## yet. 20 player countries with 25 provinces and 5 cities each (Ukraine keeps its 27
## provinces); the other European countries are AI countries (not player slots) with one
## city each; Russia is the regional map's part plus its north (Karelia, Murmansk, Arkhangelsk).
## Explore it, tap a province to see who holds it, open the player list.
@export var map_id: = "europe20"
var map: StrategicMap
var cities: CitySystem
var rig: StrategyCamera
var info: Label
var info_panel: PanelContainer
var players_panel: PanelContainer

func _ready() -> void:
	MapDefinition.use(map_id)
	var view: Dictionary = MapDefinition.data.get("view", {})
	var environment: = WorldEnvironment.new()
	var settings: = Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("0b1925")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b8c8d5")
	settings.ambient_light_energy = 0.36
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = settings
	add_child(environment)
	var sun: = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -35, 0)
	sun.light_color = Color("fff1d5")
	sun.light_energy = 1.3
	add_child(sun)
	var origin: = MapDefinition.origin()
	var extent: = MapDefinition.extent()
	var sea: = MeshInstance3D.new()
	var plane: = PlaneMesh.new()
	plane.size = extent * 3.0 + Vector2(80, 80)  # to the horizon when zoomed out
	sea.mesh = plane
	sea.position = Vector3(origin.x + extent.x * 0.5, 0, origin.y + extent.y * 0.5)
	var ocean: = ShaderMaterial.new()
	ocean.shader = load("res://assets/ocean.gdshader")
	ocean.set_shader_parameter("coast_mask", MapDefinition.coast_mask())
	ocean.set_shader_parameter("mask_origin", origin)
	ocean.set_shader_parameter("mask_size", extent)
	sea.material_override = ocean
	add_child(sea)
	map = StrategicMap.new()
	add_child(map)
	map.territory_selected.connect(_show_province)
	_add_country_names()
	rig = StrategyCamera.new()
	rig.bounds_low = origin + Vector2(4, 4)
	rig.bounds_high = origin + extent - Vector2(4, 4)
	rig.max_distance = float(view.get("max_distance", 140.0))
	add_child(rig)
	var audio: = GameAudio.new()
	add_child(audio)
	audio.rig = rig
	audio.play_music("menu_theme")
	rig.camera.far = rig.max_distance * 2.8  # after add_child: StrategyCamera._ready sets 250
	var start: = GeographicProjection.project(float(view.get("longitude", 15.0)), float(view.get("latitude", 50.0)))
	rig.target = Vector3(start.x, 0, start.y)
	rig.distance = float(view.get("distance", 110.0))
	rig._snap(1.0)
	rig.map_clicked.connect(_tap)
	cities = CitySystem.new()
	add_child(cities)
	cities.setup(map, rig)
	for label in cities.labels: label.pressed.connect(func(): _show_city(cities.cities[cities.labels.find(label)]))
	_build_ui()

func _process(_delta: float) -> void:
	map.set_view_distance(rig.rendered_distance)

## Call of War style country names across each country's main land.
func _add_country_names() -> void:
	var largest: = {}
	for country in RegionData.countries():
		var box: = Rect2(country.polygon[0], Vector2.ZERO)
		for point in country.polygon: box = box.expand(point)
		if box.get_area() > largest.get(country.country_id, [0.0])[0]: largest[country.country_id] = [box.get_area(), box, country]
	for country_id in largest:
		var box: Rect2 = largest[country_id][1]
		var polygon: PackedVector2Array = largest[country_id][2].polygon
		var middle: = box.get_center()
		var half: = minf(box.size.x * 0.32, 9.0)
		if half < 0.6: continue
		# Shift the line to the widest row of the country near its middle.
		var best: = middle
		var best_width: = -1.0
		for step in 9:
			var y: = box.position.y + box.size.y * (0.3 + 0.05 * step)
			var hits: = []
			for i in polygon.size():
				var a: = polygon[i]
				var b: = polygon[(i + 1) % polygon.size()]
				if (a.y - y) * (b.y - y) < 0: hits.append(a.x + (y - a.y) / (b.y - a.y) * (b.x - a.x))
			hits.sort()
			for i in range(0, hits.size() - 1, 2):
				if hits[i + 1] - hits[i] > best_width:
					best_width = hits[i + 1] - hits[i]
					best = Vector2((hits[i] + hits[i + 1]) * 0.5, y)
		half = minf(half, best_width * 0.4)
		if half < 0.6: continue
		var label: = CountryMapLabel.new()
		add_child(label)
		label.setup(MapDefinition.country_name(country_id).to_upper(), PackedVector2Array([best - Vector2(half, 0), best + Vector2(half, 0)]), map)

func _tap(screen: Vector2, _order: bool) -> void:
	if players_panel.visible:
		players_panel.hide()
		return
	var city_hit: = cities.pick_screen(screen)
	if not city_hit.is_empty():
		_show_city(city_hit.city)
		return
	var hit: = map.pick(rig.camera, screen)
	if hit.is_empty():
		info_panel.hide()
		return
	map.select(hit.territory)

func _show_province(territory: Dictionary) -> void:
	var country_id: String = territory.controller
	var role: = "Player nation (1 of %d)" % MapDefinition.players().size() if MapDefinition.is_player(country_id) else "AI nation · not a player slot"
	var count: = 0
	for t in map.territories:
		if t.playable and t.controller == country_id and t.id.ends_with("_0"): count += 1
	info.text = "%s\n%s · %s · %d provinces" % [territory.title, MapDefinition.country_name(country_id), role, count]
	info_panel.show()

func _show_city(city: Dictionary) -> void:
	info.text = "%s%s\n%s · %s" % ["★ " if city.get("capital", false) else "", city.name, city.country, "Capital" if city.get("capital", false) else "City"]
	info_panel.show()

func _build_ui() -> void:
	var layer: = CanvasLayer.new()
	add_child(layer)
	var root: = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = StrategyTheme.create()
	layer.add_child(root)
	var header: = CowUI.header(str(MapDefinition.data.name).to_upper().replace(" (", " · ").replace(")", ""), true)
	header.bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.close.hide()
	header.back.pressed.connect(_back)
	root.add_child(header.bar)
	var note: = CowUI.label("Map preview · no units or resources", 14, Color("dcc38b"))
	note.position = Vector2(16, 86)
	root.add_child(note)
	var players_button: = Button.new()
	players_button.text = "PLAYERS (%d)" % MapDefinition.players().size()
	players_button.custom_minimum_size = Vector2(150, 48)
	players_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	players_button.position = Vector2(-166, 80)
	players_button.pressed.connect(func(): players_panel.visible = not players_panel.visible)
	root.add_child(players_button)
	info_panel = PanelContainer.new()
	info_panel.add_theme_stylebox_override("panel", CowUI.box(Color(0.1, 0.11, 0.12, 0.92), 10, CowUI.LINE, 1, 14))
	info_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	info_panel.offset_left = 12
	info_panel.offset_right = -12
	info_panel.offset_top = -120
	info_panel.offset_bottom = -16
	info = CowUI.label("", 20)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_panel.add_child(info)
	info_panel.hide()
	root.add_child(info_panel)
	players_panel = PanelContainer.new()
	players_panel.add_theme_stylebox_override("panel", CowUI.box(Color(0.1, 0.11, 0.12, 0.95), 10, CowUI.LINE, 1, 14))
	players_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	players_panel.offset_left = 16
	players_panel.offset_right = -16
	players_panel.offset_top = 140
	players_panel.offset_bottom = -150
	var scroll: = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	players_panel.add_child(scroll)
	var rows: = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	scroll.add_child(rows)
	rows.add_child(CowUI.label("PLAYER NATIONS", 20, CowUI.GOLD))
	for country in MapDefinition.players():
		var row: = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var swatch: = ColorRect.new()
		swatch.color = Color(country.color)
		swatch.custom_minimum_size = Vector2(26, 26)
		row.add_child(swatch)
		var name_label: = CowUI.label(country.name, 18)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		row.add_child(CowUI.label("%d provinces · %d cities" % [country.provinces, country.cities], 16, Color("b9b3a0")))
		rows.add_child(row)
	var ai_names: = []
	for country in MapDefinition.data.ai_countries: ai_names.append(country.name)
	rows.add_child(CowUI.label("AI NATIONS (not players · 1 city each)", 20, CowUI.GOLD))
	var ai_label: = CowUI.label(", ".join(ai_names), 15, Color("cfc9b6"))
	ai_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ai_label.custom_minimum_size.x = 300
	rows.add_child(ai_label)
	players_panel.hide()
	root.add_child(players_panel)
	rig.input_blocked = func(position: Vector2) -> bool:
		for panel in [header.bar, players_button, info_panel, players_panel]:
			if panel.visible and panel.get_global_rect().has_point(position): return true
		return false

func _back() -> void:
	MapDefinition.use(MapDefinition.REGIONAL)
	get_tree().change_scene_to_file("res://scenes/main.tscn")
