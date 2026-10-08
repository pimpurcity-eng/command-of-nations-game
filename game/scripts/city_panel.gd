class_name CityPanel
extends CanvasLayer
signal rally_requested(city_id: String)
signal production_requested(city_name: String)
signal research_requested
var clock: SimulationClock
var play_button: Button
var buildings: BuildingSystem
var panel: PanelContainer
var title: Label
var summary: Label
var building_list: ItemList
var portrait: TextureRect
var details: Label
var build_button: Button
var produce_button: Button
var research_button: Button
var message: Label
var queue_list: ItemList
var cancel_button: Button
var rally_button: Button
var rally_status: Label
var city_id: = ""
var chosen: = "factory"
var queue_ids: Array[int] = []
var ui_timer: = 0.0
var building_rows: VBoxContainer
var row_controls: Dictionary = {}
var queue_summary: Label

func setup(system: BuildingSystem, theme: Theme) -> void :
	buildings = system
	layer = 12
	var root: = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = theme
	add_child(root)
	var dim: = ColorRect.new()
	dim.color = Color(0.01, 0.025, 0.04, 0.85)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	panel = PanelContainer.new()
	root.add_child(panel)
	panel.add_theme_stylebox_override("panel", StrategyTheme.surface("panel", 14))
	var column: = VBoxContainer.new()
	panel.add_child(column)
	var header: = HBoxContainer.new()
	column.add_child(header)
	title = Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_color_override("font_color", Color("ebd5aa"))
	header.add_child(title)
	var close: = _button("Close")
	close.pressed.connect(hide)
	header.add_child(close)
	queue_summary = _label(column)
	var scroll: = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var content: = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	summary = _label(content)
	var commands: = HBoxContainer.new()
	content.add_child(commands)
	produce_button = _button("Produce units")
	produce_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	produce_button.pressed.connect( func():
		var place: = buildings.city(city_id)
		if place.is_empty(): return
		hide()
		production_requested.emit(place.name))
	commands.add_child(produce_button)
	research_button = _button("Research")
	research_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	research_button.pressed.connect( func(): hide();research_requested.emit())
	commands.add_child(research_button)
	rally_status = _label(content)
	var rally_commands: = HBoxContainer.new()
	content.add_child(rally_commands)
	rally_button = _button("Set rally point")
	rally_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rally_button.pressed.connect( func(): hide();rally_requested.emit(city_id))
	rally_commands.add_child(rally_button)
	var clear_rally: = _button("Clear rally")
	clear_rally.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear_rally.pressed.connect( func(): buildings.economy.clear_rally(city_id);_refresh())
	rally_commands.add_child(clear_rally)
	_label(content, "CITY BUILDINGS · upgrades affect the simulation")
	building_list = ItemList.new()
	building_list.custom_minimum_size.y = 136
	building_list.add_theme_constant_override("v_separation", 12)
	building_list.fixed_icon_size = Vector2i(32, 32)
	building_list.item_selected.connect( func(index: int):
		chosen = buildings.catalog[index].id
		_refresh())
	content.add_child(building_list)
	building_rows = VBoxContainer.new()
	building_rows.add_theme_constant_override("separation", 10)
	content.add_child(building_rows)
	for definition in buildings.catalog:
		var row: = HBoxContainer.new()
		building_rows.add_child(row)
		var image: = TextureRect.new()
		image.custom_minimum_size = Vector2(64, 64)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.texture = load(AssetRoster.appearance(definition.asset_roster_id, GameSession.player_country).preview)
		row.add_child(image)
		var body: = VBoxContainer.new()
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(body)
		var info: = _label(body)
		var action: = _button("Construct")
		action.pressed.connect( func():
			chosen = definition.id
			var error: = buildings.schedule(city_id, chosen)
			message.text = "Planned · resources charged when construction starts" if error.is_empty() else error
			_refresh())
		body.add_child(action)
		row_controls[definition.id] = {"info": info, "action": action}
	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(140, 72)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	content.add_child(portrait)
	details = _label(content)
	build_button = _button("Upgrade building")
	build_button.pressed.connect( func():
		var error: = buildings.schedule(city_id, chosen)
		message.text = "Planned · resources charged when construction starts" if error.is_empty() else error
		_refresh())
	column.add_child(build_button)
	message = _label(column, "Plan up to 8 orders. Waiting orders charge resources when they start.")
	message.max_lines_visible = 2
	play_button = _button("Play · construction paused")
	play_button.pressed.connect( func():
		if clock != null and clock.paused: clock.toggle_pause())
	column.add_child(play_button)
	_label(content, "CONSTRUCTION QUEUE · one active building per city")
	queue_list = ItemList.new()
	queue_list.custom_minimum_size.y = 110
	queue_list.add_theme_constant_override("v_separation", 12)
	queue_list.item_selected.connect( func(_index: int): cancel_button.disabled = false)
	content.add_child(queue_list)
	cancel_button = _button("Cancel order · refund unused resources")
	cancel_button.pressed.connect( func():
		var selection: = queue_list.get_selected_items()
		if not selection.is_empty() and selection[0] < queue_ids.size():
			message.text = buildings.cancel(queue_ids[selection[0]])
		_refresh())
	content.add_child(cancel_button)
	var reorder: = HBoxContainer.new()
	content.add_child(reorder)
	for direction in [-1, 1]:
		var button: = _button("Move up" if direction == -1 else "Move down")
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		reorder.add_child(button)
		button.pressed.connect( func():
			var selection: = queue_list.get_selected_items()
			if selection.is_empty() or selection[0] >= queue_ids.size(): message.text = "Select a waiting order first";return
			var error: = buildings.reorder(queue_ids[selection[0]], direction)
			message.text = "Queue reordered" if error.is_empty() else error)
	buildings.changed.connect( func():
		if visible: _refresh())
	get_viewport().size_changed.connect(_layout)
	_layout()
	hide()
func _button(text: String) -> Button:
	var button: = Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 13)
	return button
func _label(parent: Node, text: String = "") -> Label:
	var label: = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label
func open(place: Dictionary) -> void :
	city_id = place.id
	chosen = "factory"
	message.text = "Construction and unit production use separate queues. Pause freezes both."
	show()
	_layout()
	_refresh()
func _layout() -> void :
	var size: = get_viewport().get_visible_rect().size
	panel.position = Vector2(maxf(10, (size.x - 720) * 0.5), 10)
	panel.size = Vector2(minf(720, size.x - 20), size.y - 20)
func _refresh() -> void :
	var place: = buildings.city(city_id)
	if place.is_empty(): return
	var controlled: = buildings.economy.controlled(place, GameSession.player_country)
	var own: bool = place.country.to_lower() == GameSession.player_country or controlled
	title.text = place.name.to_upper() + " · " + ("CAPITAL" if buildings.is_capital(place) else "CITY")
	var controller: = buildings.economy.controller(place)
	summary.text = ("YOURS · YOUR COUNTRY" if controlled else "Controlled by " + controller.capitalize()) + " · " + ("Captured city · income 25%" if controlled and place.country.to_lower() != GameSession.player_country else "Core city" if controlled else "Your orders are paused while this city is outside your control" if own else "Foreign city")
	rally_button.disabled = not controlled
	var rally: Dictionary = buildings.economy.rally_points.get(city_id, {})
	rally_status.text = "RALLY: " + ("Set · new units follow this destination" if rally.get("country", "") == GameSession.player_country else "Not set")
	produce_button.disabled = not own or not controlled
	research_button.visible = place.id == buildings.capitals.get(GameSession.player_country, "")
	research_button.disabled = not own or not controlled
	building_list.hide()
	building_rows.visible = own
	portrait.visible = own
	details.visible = own
	build_button.visible = own
	queue_list.visible = own
	cancel_button.visible = own
	queue_summary.text = ""
	if own:
		queue_summary.text = "Construction: idle"
		for job in buildings.jobs:
			if job.get("country", place.country.to_lower()) != GameSession.player_country: continue
			if job.city == city_id:
				var seconds: float = buildings.duration(job.building, job.level) - job.progress
				queue_summary.text = "Construction: " + buildings.spec(job.building).name + " L" + str(job.level) + " · " + ("PAUSED" if not controlled or (clock != null and clock.paused) else SimulationClock.duration(seconds) + " left at 1x")
				break
		queue_summary.text += "\nProduction: idle"
		for job in buildings.economy.jobs:
			if buildings.economy.equipment(job.equipment).country != GameSession.player_country: continue
			if job.city == place.name:
				var spec: Dictionary = buildings.economy.equipment(job.equipment)
				var seconds: float = (spec.seconds - job.progress) / buildings.rate(city_id, "factory")
				queue_summary.text = queue_summary.text.replace("Production: idle", "Production: " + EquipmentIdentity.title(job.equipment) + " · " + ("PAUSED" if not controlled or (clock != null and clock.paused) else SimulationClock.duration(seconds) + " left at 1x"))
				break
	if not own:
		summary.text += "\nEnemy research, resources and construction details are hidden."
		message.text = "Ukraine is controlled by AI."
		return
	summary.text += "\n"
	for resource in ProductionSystem.RESOURCES: summary.text += resource.capitalize() + " " + str(int(buildings.economy.stockpiles.russia[resource])) + "  "
	building_list.clear()
	for definition in buildings.catalog:
		var current: = buildings.level(city_id, definition.id)
		var appearance: = AssetRoster.appearance(definition.asset_roster_id, GameSession.player_country)
		var label: String = definition.name + " · " + ("Capital only" if definition.capital_only and not buildings.is_capital(place) else "L" + str(current) + " / " + str(int(definition.max_level)))
		building_list.add_item(label, load(appearance.preview))
		if definition.id == chosen: building_list.select(building_list.item_count - 1)
	for entry in buildings.catalog:
		var level: = buildings.level(city_id, entry.id) + 1
		var reason: = buildings.reason(city_id, entry.id, GameSession.player_country, false)
		var row: Dictionary = row_controls[entry.id]
		row.action.disabled = not reason.is_empty()
		var queued_here: = buildings.jobs.any( func(job: Dictionary): return job.city == city_id and job.get("country", place.country.to_lower()) == GameSession.player_country)
		row.action.text = (("Queue L" if queued_here else "Construct L") + str(level)) if level <= entry.max_level else "Fully upgraded"
		row.info.text = entry.name + " · L" + str(buildings.level(city_id, entry.id))
		if level <= entry.max_level:
			row.info.text += "\n" + SimulationClock.duration(buildings.duration(entry.id, level)) + " at 1x"
			var cost: = buildings.cost(entry.id, level)
			for resource in ProductionSystem.RESOURCES:
				if cost[resource] > 0: row.info.text += " · " + resource.capitalize() + " " + str(cost[resource])
		if not reason.is_empty(): row.info.text += "\n" + reason
	var definition: = buildings.spec(chosen)
	var appearance: = AssetRoster.appearance(definition.asset_roster_id, GameSession.player_country)
	portrait.texture = load(appearance.preview)
	var target: = buildings.level(city_id, chosen) + 1
	var error: = buildings.reason(city_id, chosen, GameSession.player_country, false)
	build_button.disabled = not error.is_empty()
	build_button.text = "Upgrade to Level " + str(target) if target <= definition.max_level else "Maximum level reached"
	details.text = definition.description
	if target <= definition.max_level and not (definition.capital_only and not buildings.is_capital(place)):
		details.text += "\nConstruction: " + SimulationClock.duration(buildings.duration(chosen, target)) + " at 1x"
		var bill: = buildings.cost(chosen, target)
		for resource in ProductionSystem.RESOURCES: details.text += "\n" + resource.capitalize() + ": " + str(bill[resource])
	if not error.is_empty(): details.text += "\n" + error
	var selected_id: = -1
	var selection: = queue_list.get_selected_items()
	if not selection.is_empty() and selection[0] < queue_ids.size(): selected_id = queue_ids[selection[0]]
	queue_list.clear()
	queue_ids.clear()
	for job in buildings.jobs:
		if job.city != city_id or job.get("country", place.country.to_lower()) != GameSession.player_country: continue
		var active: = queue_ids.is_empty()
		queue_ids.append(int(job.id))
		var state: = "Paused · city lost" if not controlled else (("Waiting for resources" if not job.get("paid", true) else SimulationClock.duration(buildings.duration(job.building, job.level) - job.progress) + " left at 1x") if active else "Waiting")
		queue_list.add_item(buildings.spec(job.building).name + " L" + str(int(job.level)) + " · " + state)
		if int(job.id) == selected_id: queue_list.select(queue_ids.size() - 1)
	cancel_button.disabled = queue_list.get_selected_items().is_empty()
	if queue_ids.is_empty(): queue_list.add_item("No construction queued")
func _process(delta: float) -> void :
	if not visible: return
	if clock != null: play_button.visible = clock.paused
	ui_timer += delta
	if ui_timer >= 0.5:
		ui_timer = 0
		_refresh()
