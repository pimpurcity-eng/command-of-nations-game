class_name ProductionPanel
extends CanvasLayer
var clock: SimulationClock
var play_button: Button
var build_button: Button
var production: ProductionSystem
var unit_system: UnitSystem
var country_picker: OptionButton
var city_picker: OptionButton
var category_picker: OptionButton
var equipment_list: ItemList
var queue_list: ItemList
var resources: Label
var details: Label
var message: Label
var panel: PanelContainer
var filtered: Array = []
var chosen: = ""
var queue_ids: Array = []
var city_names: Array[String] = []
func setup(system: ProductionSystem, units: UnitSystem, theme: Theme) -> void :
	production = system
	unit_system = units
	layer = 10
	var root: = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = theme
	add_child(root)
	var dim: = ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.04, 0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	panel = PanelContainer.new()
	root.add_child(panel)
	panel.add_theme_stylebox_override("panel", StrategyTheme.surface("panel", 14))
	var column: = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var header: = HBoxContainer.new()
	column.add_child(header)
	var title: = Label.new()
	title.text = "EQUIPMENT & PRODUCTION"
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color("ebd5aa"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close: = Button.new()
	close.text = "Close"
	close.custom_minimum_size.y = 48
	close.pressed.connect(hide)
	header.add_child(close)
	var scroll: = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var content: = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	country_picker = OptionButton.new()
	country_picker.add_item("Ukraine", 0)
	country_picker.add_item("Russia", 1)
	country_picker.select(1)
	country_picker.custom_minimum_size.y = 48
	country_picker.item_selected.connect( func(_index: int): _populate())
	content.add_child(country_picker)
	resources = _label(content, "")
	resources.add_theme_color_override("font_color", Color("ebd5aa"))
	var selectors: = VBoxContainer.new()
	content.add_child(selectors)
	city_picker = OptionButton.new()
	city_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	city_picker.custom_minimum_size.y = 48
	city_picker.item_selected.connect( func(_index: int): _show_details())
	selectors.add_child(city_picker)
	category_picker = OptionButton.new()
	for title_text in ["All equipment", "Armor", "Mechanized", "Artillery", "Fighters", "Bombers", "Air defense", "Navy", "Missiles", "Drones"]: category_picker.add_item(title_text)
	category_picker.custom_minimum_size.y = 48
	category_picker.item_selected.connect( func(_index: int): _populate_equipment())
	selectors.add_child(category_picker)
	equipment_list = ItemList.new()
	equipment_list.custom_minimum_size.y = 420
	equipment_list.fixed_icon_size = Vector2i(88, 60)
	equipment_list.add_theme_constant_override("v_separation", 12)
	equipment_list.item_selected.connect( func(index: int):
		chosen = filtered[index].id
		_show_details())
	content.add_child(equipment_list)
	details = _label(content, "")
	var build: = Button.new()
	build_button = build
	build.text = "Queue production"
	build.custom_minimum_size.y = 48
	build.pressed.connect( func():
		var error: = production.schedule(chosen, city_names[city_picker.selected] if city_picker.selected >= 0 else "")
		message.text = "Planned · resources charged when production starts" if error.is_empty() else error)
	column.add_child(build)
	message = _label(column, "Plan up to 8 orders per city. Waiting orders start when resources and buildings are available.")
	message.max_lines_visible = 2
	play_button = Button.new()
	play_button.text = "Play · production paused"
	play_button.custom_minimum_size.y = 48
	play_button.pressed.connect( func():
		if clock != null and clock.paused: clock.toggle_pause())
	column.add_child(play_button)
	_label(content, "CITY QUEUES · ONE ACTIVE ORDER PER CITY")
	queue_list = ItemList.new()
	queue_list.custom_minimum_size.y = 115
	queue_list.add_theme_constant_override("v_separation", 12)
	content.add_child(queue_list)
	var actions: = HBoxContainer.new()
	content.add_child(actions)
	for title_text in ["Cancel selected", "Select newest unit"]:
		var button: = Button.new()
		button.text = title_text
		button.custom_minimum_size.y = 48
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if title_text == "Cancel selected":
			button.pressed.connect( func():
				var selection: = queue_list.get_selected_items()
				if selection.is_empty() or selection[0] >= queue_ids.size(): message.text = "Select a queued order first"
				else: production.cancel(queue_ids[selection[0]]))
		else:
			button.pressed.connect( func():
				for index in range(unit_system.units.size() - 1, -1, -1):
					if unit_system.units[index].country == GameSession.player_country:
						unit_system.select_unit(index)
						break
				hide())
		actions.add_child(button)
	var reorder: = HBoxContainer.new()
	content.add_child(reorder)
	for direction in [-1, 1]:
		var button: = Button.new()
		button.text = "Move up" if direction == -1 else "Move down"
		button.custom_minimum_size.y = 48
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		reorder.add_child(button)
		button.pressed.connect( func():
			var selection: = queue_list.get_selected_items()
			if selection.is_empty() or selection[0] >= queue_ids.size(): message.text = "Select a waiting order first";return
			var error: = production.reorder(queue_ids[selection[0]], direction)
			message.text = "Queue reordered" if error.is_empty() else error)
	production.changed.connect(_refresh)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_populate()
	hide()
func _label(parent: Node, text: String) -> Label:
	var label: = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label
func _country() -> String:
	return GameSession.player_country
func _populate() -> void :
	city_picker.clear()
	city_names.clear()
	for city in production.cities:
		if city.country.to_lower() == _country() or production.controlled(city, _country()):
			city_names.append(city.name)
			city_picker.add_item(city.name + (" · CAPITAL" if city.get("capital", false) and city.country.to_lower() == _country() else ""))
	_populate_equipment()
func _populate_equipment() -> void :
	filtered.clear()
	equipment_list.clear()
	for spec in production.catalog:
		if spec.country != _country(): continue
		if category_picker.selected != 0 and spec.category != category_picker.get_item_text(category_picker.selected): continue
		filtered.append(spec)
		equipment_list.add_item(spec.name + " · " + spec.category, CowUI.equipment_picture(spec.id))
	if not filtered.is_empty():
		equipment_list.select(0)
		chosen = filtered[0].id
	_show_details()
	_refresh()
func _show_details() -> void :
	var spec: = production.equipment(chosen)
	if spec.is_empty(): return
	var multiplier: = 1.0
	if production.buildings != null and city_picker.selected >= 0:
		for place in production.cities:
			if place.name == city_names[city_picker.selected]: multiplier = production.buildings.rate(place.id, "factory")
	details.text = spec.name + " · " + SimulationClock.duration(spec.seconds / multiplier) + " at 1x · L" + str(production.research.level(spec.id) if production.research != null else 1) + "\n"
	for resource in ProductionSystem.RESOURCES:
		details.text += resource.capitalize() + " " + str(int(spec.cost[resource])) + "  "
	for id in spec.get("building_requirements", {}): details.text += "\nRequires " + id + " L" + str(spec.building_requirements[id])
	if spec.visual_kind == "missile_launcher": details.text += "\nStops to fire automatically during war · Range " + str(int(spec.strike_range * 40)) + " game km · timed salvo rounds"
	if spec.visual_kind == "fighter": details.text += "\nOperating radius: " + str(int(spec.air_range * 40)) + " game km · Fly / Patrol / Return"
func _refresh() -> void :
	if resources == null or not visible: return
	var country: = _country()
	resources.text = ""
	for resource in ProductionSystem.RESOURCES:
		resources.text += resource.capitalize() + " " + str(int(production.stockpiles[country][resource])) + "   "
	var selected_id: = -1
	var selection: = queue_list.get_selected_items()
	if not selection.is_empty() and selection[0] < queue_ids.size(): selected_id = queue_ids[selection[0]]
	queue_list.clear()
	queue_ids.clear()
	var active_cities: Dictionary = {}
	for job in production.jobs:
		var spec: = production.equipment(job.equipment)
		if spec.country != country: continue
		var active: = not active_cities.has(job.city)
		active_cities[job.city] = true
		queue_ids.append(int(job.id))
		var multiplier: = 1.0
		var held: = false
		for place in production.cities:
			if place.name != job.city: continue
			held = not production.controlled(place, spec.country)
			if production.buildings != null: multiplier = production.buildings.rate(place.id, "factory")
		queue_list.add_item(job.city + " · " + spec.name + " · " + ("PAUSED · city lost" if held else (("Waiting for resources / buildings" if not job.get("paid", true) else SimulationClock.duration((spec.seconds - job.progress) / multiplier) + " left at 1x") if active else "Waiting")))
		if int(job.id) == selected_id: queue_list.select(queue_ids.size() - 1)
	if queue_ids.is_empty(): queue_list.add_item("No queued production")
func _layout() -> void :
	var size: = get_viewport().get_visible_rect().size
	var width: = minf(740, size.x - 20)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 1
	panel.offset_left = - width * 0.5
	panel.offset_right = width * 0.5
	panel.offset_top = 10
	panel.offset_bottom = -10
func open(city_name: String = "") -> void :
	country_picker.select(0 if GameSession.player_country == "ukraine" else 1)
	country_picker.disabled = true
	_populate()
	show()
	_populate()
	if city_names.has(city_name): city_picker.select(city_names.find(city_name))
	_show_details()
	_refresh()

func _process(_delta: float) -> void :
	if visible and clock != null: play_button.visible = clock.paused
