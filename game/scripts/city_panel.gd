class_name CityPanel
extends CanvasLayer
## City screen in the Call of War style (owner review 2026-10-09: the building menu was
## complicated; reference screenshots of Call of War's city screen). Dark header with the
## city name, "construction" and "production" status boxes, a tab row, and a light list of
## buildings grouped in sections: picture, "Name Lvl. N", cost icons, build time and a green
## CONSTRUCT button. Research is national and opened from the Research tab, not here.
signal rally_requested(city_id: String)
signal production_requested(city_name: String)
signal research_requested  # kept for compatibility; research is opened from the HUD tab
const SECONDS_PER_HOUR: = 3600.0 / SimulationClock.REAL_SECONDS_PER_SIM_SECOND
const HIDDEN_BUILDINGS: = ["research_center"]  # research is national, not a city building
const SECTIONS: = [["Province economy", ["industry"]], ["Unit production", ["factory", "airbase"]]]
var clock: SimulationClock
var buildings: BuildingSystem
var panel: PanelContainer
var title: Label
var summary: Label
var income_row: HBoxContainer
var construction: Dictionary
var production: Dictionary
var rally_tab: Button
var list: VBoxContainer
var rows: Dictionary = {}
var message: Label
var city_id: = ""
var ui_timer: = 0.0

func setup(system: BuildingSystem, theme: Theme) -> void:
	buildings = system
	layer = 12
	var root: = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = theme
	add_child(root)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", CowUI.skin("panel_dark", 8))
	root.add_child(panel)
	var column: = VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	panel.add_child(column)
	var head: = CowUI.header("", false)
	title = head.title
	head.close.pressed.connect(hide)
	column.add_child(head.bar)
	# Ownership and income.
	var info: = PanelContainer.new()
	info.add_theme_stylebox_override("panel", CowUI.box(Color(0, 0, 0, 0), 0, Color(0, 0, 0, 0), 0, 8))
	column.add_child(info)
	var info_column: = VBoxContainer.new()
	info.add_child(info_column)
	summary = CowUI.label("", 14, Color("c9c3ae"))
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.clip_text = true
	info_column.add_child(summary)
	income_row = HBoxContainer.new()
	income_row.alignment = BoxContainer.ALIGNMENT_CENTER
	income_row.add_theme_constant_override("separation", 14)
	info_column.add_child(income_row)
	# Construction and production status.
	var boxes: = HBoxContainer.new()
	boxes.add_theme_constant_override("separation", 8)
	var boxes_margin: = MarginContainer.new()
	for side in ["left", "right", "bottom"]: boxes_margin.add_theme_constant_override("margin_" + side, 8)
	boxes_margin.add_child(boxes)
	column.add_child(boxes_margin)
	construction = CowUI.status_box("hammer")
	boxes.add_child(construction.panel)
	production = CowUI.status_box("produce")
	boxes.add_child(production.panel)
	production.panel.gui_input.connect(func(event: InputEvent):
		if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed and not event.is_echo(): _produce())
	# Tabs: Buildings (this list), Produce (unit production screen), Rally point.
	var tabs: = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 0)
	column.add_child(tabs)
	tabs.add_child(CowUI.tab("Buildings", "hammer", true))
	var produce_tab: = CowUI.tab("Produce", "produce", false)
	produce_tab.pressed.connect(_produce)
	tabs.add_child(produce_tab)
	rally_tab = CowUI.tab("Rally point", "flag", false)
	rally_tab.pressed.connect(func():
		var rally: Dictionary = buildings.economy.rally_points.get(city_id, {})
		if rally.get("country", "") == GameSession.player_country:
			buildings.economy.clear_rally(city_id)
			message.text = "Rally point cleared"
			_refresh()
		else:
			hide()
			rally_requested.emit(city_id))
	tabs.add_child(rally_tab)
	# Building list.
	var list_back: = PanelContainer.new()
	list_back.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_back.add_theme_stylebox_override("panel", CowUI.skin("list", 8))
	column.add_child(list_back)
	var scroll: = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_back.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	var listed: = {}
	for section in SECTIONS:
		list.add_child(CowUI.section(section[0]))
		for id in section[1]:
			if not buildings.spec(id).is_empty(): _add_row(buildings.spec(id))
			listed[id] = true
	var others: = buildings.catalog.filter(func(d: Dictionary): return not listed.has(d.id) and not d.id in HIDDEN_BUILDINGS)
	if not others.is_empty():
		list.add_child(CowUI.section("Special"))
		for definition in others: _add_row(definition)
	message = CowUI.label("", 13, CowUI.GOLD)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.custom_minimum_size.y = 28
	message.clip_text = true
	column.add_child(message)
	buildings.changed.connect(func():
		if visible: _refresh())
	get_viewport().size_changed.connect(_layout)
	_layout()
	hide()

func _produce() -> void:
	var place: = buildings.city(city_id)
	if place.is_empty() or not buildings.economy.controlled(place, GameSession.player_country): return
	hide()
	production_requested.emit(place.name)

func _add_row(definition: Dictionary) -> void:
	var card: = PanelContainer.new()
	card.add_theme_stylebox_override("panel", CowUI.skin("row", 6, 8))
	list.add_child(card)
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var frame: = PanelContainer.new()
	frame.add_theme_stylebox_override("panel", CowUI.box(Color("e8e4d6"), 0, Color("2f2f2a"), 2, 2))
	row.add_child(frame)
	var image: = TextureRect.new()
	image.custom_minimum_size = Vector2(88, 80)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture = load(AssetRoster.appearance(definition.asset_roster_id, GameSession.player_country).preview)
	frame.add_child(image)
	var middle: = VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(middle)
	var name_label: = CowUI.label(definition.name, 18, CowUI.INK)
	name_label.clip_text = true
	middle.add_child(name_label)
	var effect: = CowUI.label(_effect(definition), 12, Color("5a584e"))
	effect.clip_text = true
	middle.add_child(effect)
	var costs: = HBoxContainer.new()
	costs.add_theme_constant_override("separation", 12)
	middle.add_child(costs)
	var right: = PanelContainer.new()
	right.add_theme_stylebox_override("panel", CowUI.box(Color(0.55, 0.52, 0.44, 0.22), 6, Color(0, 0, 0, 0), 0, 5))
	row.add_child(right)
	var right_column: = VBoxContainer.new()
	right_column.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_child(right_column)
	var time_row: = HBoxContainer.new()
	time_row.alignment = BoxContainer.ALIGNMENT_CENTER
	right_column.add_child(time_row)
	time_row.add_child(CowUI.Icon.new("clock", CowUI.INK, Vector2(22, 22)))
	var time: = CowUI.label("", 15, CowUI.INK)
	time_row.add_child(time)
	var button: = CowUI.action("CONSTRUCT", "hammer")
	button.pressed.connect(func():
		var error: = buildings.schedule(city_id, definition.id)
		message.text = (definition.name + " construction planned") if error.is_empty() else error
		_refresh())
	right_column.add_child(button)
	rows[definition.id] = {"name": name_label, "costs": costs, "time": time, "button": button}

func _effect(definition: Dictionary) -> String:
	match definition.id:
		"factory": return "+25% unit production speed per level"
		"industry": return "+25% city income per level"
		"airbase": return "Base for aircraft; more per level"
	return ""

func open(place: Dictionary) -> void:
	city_id = place.id
	message.text = ""
	show()
	_layout()
	_refresh()

func _layout() -> void:
	var size: = get_viewport().get_visible_rect().size
	var width: = minf(760.0, size.x)
	var top: = roundf(size.y * 0.06)
	panel.position = Vector2((size.x - width) * 0.5, top)
	panel.size = Vector2(width, size.y - top)

func _jobs_here() -> Array:
	var place: = buildings.city(city_id)
	return buildings.jobs.filter(func(job: Dictionary): return job.city == city_id and job.get("country", place.country.to_lower()) == GameSession.player_country)

func _refresh() -> void:
	var place: = buildings.city(city_id)
	if place.is_empty(): return
	var controlled: = buildings.economy.controlled(place, GameSession.player_country)
	var own: bool = place.country.to_lower() == GameSession.player_country or controlled
	var captured: bool = controlled and place.country.to_lower() != GameSession.player_country
	title.text = ("★ " if buildings.is_capital(place) else "") + place.name
	summary.text = ("YOURS · " + ("captured city · income 25%" if captured else ("capital" if buildings.is_capital(place) else "core city"))) if controlled else ("Controlled by " + buildings.economy.controller(place).capitalize())
	# Income per hour at 1x (industry level, specialties, capture penalty).
	for child in income_row.get_children(): child.queue_free()
	var specialties: = ResourceSites.city_resources(place.name)
	var base: = {"funds": 1.0, "materials": 0.18, "electronics": 0.08, "fuel": 0.12, "manpower": 0.1}
	var multiplier: = buildings.rate(city_id, "industry") * (0.25 if captured else 1.0)
	var bonus: float = ResourceSites.data().get("city_specialty_bonus", 0.0)
	for resource in ProductionSystem.RESOURCES:
		var item: = CowUI.cost(resource, base[resource] * multiplier * (1.0 + bonus if resource in specialties else 1.0) * SECONDS_PER_HOUR, true)
		var amount: Label = item.get_child(1)
		amount.text = "+" + amount.text + "/h"
		amount.add_theme_color_override("font_color", CowUI.GOLD if resource in specialties else Color("d9d3c0"))
		income_row.add_child(item)
	income_row.visible = own
	var rally: Dictionary = buildings.economy.rally_points.get(city_id, {})
	rally_tab.get_child(0).get_child(1).text = "Clear rally" if rally.get("country", "") == GameSession.player_country else "Rally point"
	rally_tab.disabled = not controlled
	list.visible = own
	var paused: = not controlled or (clock != null and clock.paused)
	# Construction status.
	var jobs: = _jobs_here()
	construction.bar.visible = not jobs.is_empty() and own
	if not own: construction.text.text = "Enemy city"
	elif jobs.is_empty(): construction.text.text = "No construction"
	else:
		var job: Dictionary = jobs[0]
		var total: = buildings.duration(job.building, job.level)
		construction.text.text = buildings.spec(job.building).name + " " + str(int(job.level)) + ("  ·  " + ("waiting" if not job.get("paid", true) else ("paused" if paused else SimulationClock.duration(total - job.progress))))
		if jobs.size() > 1: construction.text.text += "  (+" + str(jobs.size() - 1) + ")"
		construction.bar.max_value = total
		construction.bar.value = job.progress
	# Production status.
	production.text.text = "No production" if own else "Hidden"
	production.bar.visible = false
	production.picture.visible = false
	production.icon.visible = true
	if own:
		for job in buildings.economy.jobs:
			if job.city != place.name or buildings.economy.equipment(job.equipment).country != GameSession.player_country: continue
			var spec: Dictionary = buildings.economy.equipment(job.equipment)
			var seconds: float = (spec.seconds - job.progress) / buildings.rate(city_id, "factory")
			production.text.text = EquipmentIdentity.title(job.equipment) + "  ·  " + ("paused" if paused else SimulationClock.duration(seconds))
			production.picture.texture = UnitVisual.preview_texture(job.equipment)
			production.picture.visible = true
			production.icon.visible = false
			production.bar.visible = true
			production.bar.max_value = spec.seconds
			production.bar.value = job.progress
			break
	if not own: return
	# Building rows.
	var stock: Dictionary = buildings.economy.stockpiles[GameSession.player_country]
	for id in rows:
		var row: Dictionary = rows[id]
		var definition: = buildings.spec(id)
		var current: = buildings.level(city_id, id)
		var target: = current + 1 + jobs.filter(func(j: Dictionary): return j.building == id).size()
		row.name.text = definition.name + " Lvl. " + str(current)
		for child in row.costs.get_children(): child.queue_free()
		var caption: Label = row.button.get_meta("caption")
		if target > int(definition.max_level):
			row.time.text = "—"
			caption.text = "MAX LEVEL"
			row.button.disabled = true
			continue
		var bill: = buildings.cost(id, target)
		for resource in ProductionSystem.RESOURCES:
			if bill[resource] > 0: row.costs.add_child(CowUI.cost(resource, bill[resource], stock[resource] >= bill[resource]))
		row.time.text = " " + SimulationClock.duration(buildings.duration(id, target))
		var reason: = buildings.reason(city_id, id, GameSession.player_country, false)
		row.button.disabled = not reason.is_empty()
		row.button.tooltip_text = reason
		caption.text = ("QUEUE LVL. " if not jobs.is_empty() else "CONSTRUCT LVL. ") + str(target)

func _process(delta: float) -> void:
	if not visible: return
	ui_timer += delta
	if ui_timer >= 0.5:
		ui_timer = 0
		_refresh()
