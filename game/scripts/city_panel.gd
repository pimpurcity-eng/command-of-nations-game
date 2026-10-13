class_name CityPanel
extends CanvasLayer
## City screen in the Call of War style (owner review 2026-10-09: the building menu was
## complicated; reference screenshots of Call of War's city screen). Dark header with the
## city name, "construction" and "production" status boxes, a tab row, and a light list of
## buildings grouped in sections: picture, "Name Lvl. N", cost icons, build time and a green
## CONSTRUCT button. Owner 2026-10-13 (Call of War city screenshots): unit tabs (Infantry,
## Ordnance, Tanks, Air, Naval) list each weapon ONCE at its current level with PRODUCE, and
## only the next research level under it ("only what's next in line").
signal rally_requested(city_id: String)
signal production_requested(city_name: String)
signal research_requested  # kept for compatibility; research is opened from the HUD tab
const SECONDS_PER_HOUR: = 3600.0 / SimulationClock.REAL_SECONDS_PER_SIM_SECOND
const HIDDEN_BUILDINGS: = ["research_center", "finance", "material_works", "electronics_plant", "fuel_depot"]  # research is national, not a city building
const SECTIONS := [["Economy", ["industry", "recruitment_center", "train_station", "capitol"]], ["Unit production", ["barracks", "tank_plant", "factory", "missile_factory", "airbase", "naval_base"]], ["Defence & roads", ["bunker", "infrastructure"]]]
var clock: SimulationClock
var research: ResearchSystem
var tab_row: HBoxContainer
var tab_index: = -1  # -1 = buildings, otherwise a ProductionGroups index
var unit_list: VBoxContainer
var unit_rows: Dictionary = {}
var scroll: ScrollContainer
var buildings: BuildingSystem
var panel: PanelContainer
var title: Label
var summary: Label
var income_row: HBoxContainer
var construction: Dictionary
var production: Dictionary
var rally_tab: Button
var section_labels: Array = []
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
	# Tabs: Buildings, one per unit group, Rally point.
	tab_row = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 0)
	column.add_child(tab_row)
	rally_tab = CowUI.tab("Rally", "flag", false)
	rally_tab.custom_minimum_size.x = 56
	rally_tab.pressed.connect(func():
		var rally: Dictionary = buildings.economy.rally_points.get(city_id, {})
		if rally.get("country", "") == GameSession.player_country:
			buildings.economy.clear_rally(city_id)
			message.text = "Rally point cleared"
			_refresh()
		else:
			hide()
			rally_requested.emit(city_id))
	_build_tabs()
	# Building list.
	var list_back: = PanelContainer.new()
	list_back.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_back.add_theme_stylebox_override("panel", CowUI.skin("list", 8))
	column.add_child(list_back)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_back.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	var lists: = VBoxContainer.new()
	lists.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lists)
	lists.add_child(list)
	unit_list = VBoxContainer.new()
	unit_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unit_list.add_theme_constant_override("separation", 6)
	unit_list.visible = false
	lists.add_child(unit_list)
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
	image.texture = load(definition.get("preview", AssetRoster.appearance(definition.asset_roster_id, GameSession.player_country).preview))
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
	rows[definition.id] = {"card":card, "picture":image, "name": name_label, "costs": costs, "time": time, "button": button}

func _build_tabs() -> void:
	for child in tab_row.get_children():
		tab_row.remove_child(child)
		if child != rally_tab: child.queue_free()
	var entries: Array = [-1]
	entries.append_array(ProductionGroups.CITY_TABS)
	for index in entries:
		var tab: Button
		if index < 0: tab = CowUI.tab("Buildings", "hammer", tab_index < 0)
		else:
			tab = CowUI.tab(ProductionGroups.CITY_TITLES[index], "", tab_index == index)
			var symbol: = UnitTypeIcon.silhouette(ProductionGroups.ICONS[index], CowUI.GOLD, Vector2(30, 26))
			symbol.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			var inner: VBoxContainer = tab.get_child(0)
			inner.add_child(symbol)
			inner.move_child(symbol, 0)
		tab.custom_minimum_size.x = 56
		var caption: Label = tab.get_child(0).get_child(1)
		caption.add_theme_font_size_override("font_size", 12)
		tab.pressed.connect(func(): show_tab(index))
		tab_row.add_child(tab)
	tab_row.add_child(rally_tab)

## -1 shows the buildings; a ProductionGroups index shows that group's weapons.
func show_tab(index: int) -> void:
	tab_index = index
	_build_tabs()
	list.visible = index < 0
	unit_list.visible = index >= 0
	for child in unit_list.get_children(): unit_list.remove_child(child); child.queue_free()
	unit_rows.clear()
	if index >= 0 and research != null:
		var families: Array = buildings.economy.catalog.filter(func(spec: Dictionary): return spec.country == GameSession.player_country and ProductionGroups.index(spec) == index)
		families.sort_custom(func(a, b): return a.category < b.category if a.category != b.category else a.name < b.name)
		for spec in families: _add_unit_row(spec)
	if scroll != null: scroll.scroll_vertical = 0
	if visible: _refresh()

func _add_unit_row(spec: Dictionary) -> void:
	var card: = PanelContainer.new()
	card.add_theme_stylebox_override("panel", CowUI.skin("row", 6, 8))
	unit_list.add_child(card)
	var stack: = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	card.add_child(stack)
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	stack.add_child(row)
	var frame: = PanelContainer.new()
	frame.add_theme_stylebox_override("panel", CowUI.box(Color("e8e4d6"), 0, Color("2f2f2a"), 2, 2))
	row.add_child(frame)
	var image: = TextureRect.new()
	image.custom_minimum_size = Vector2(96, 80)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	frame.add_child(image)
	var rank: = Chevrons.new()
	rank.custom_minimum_size = Vector2(26, 30)
	rank.size_flags_horizontal = Control.SIZE_SHRINK_END
	rank.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	frame.add_child(rank)
	var middle: = VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(middle)
	var name_label: = CowUI.label("", 18, CowUI.INK)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	middle.add_child(name_label)
	var kind: = HBoxContainer.new()
	kind.add_theme_constant_override("separation", 4)
	middle.add_child(kind)
	kind.add_child(UnitTypeIcon.silhouette(spec.visual_kind, CowUI.INK, Vector2(20, 18)))
	var kind_label: = CowUI.label("", 13, Color("5a584e"))
	kind_label.clip_text = true
	kind_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kind.add_child(kind_label)
	var costs: = HBoxContainer.new()
	costs.add_theme_constant_override("separation", 10)
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
	var produce: = CowUI.action("PRODUCE", "")
	produce.pressed.connect(func():
		var place: = buildings.city(city_id)
		var error: = buildings.economy.schedule(spec.id, place.get("name", ""))
		message.text = (EquipmentIdentity.research_title(spec.id, research.level(spec.id)) + " added to " + place.get("name", "") + " production") if error.is_empty() else error
		_refresh())
	right_column.add_child(produce)
	# Only the next research level, as a bar under the card (like Call of War's "Lvl. 3 ... >>").
	var next_row: = HBoxContainer.new()
	next_row.add_theme_constant_override("separation", 8)
	stack.add_child(next_row)
	var bar: = ProgressBar.new()
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size.y = 40
	bar.add_theme_stylebox_override("background", CowUI.box(Color("c98a3e"), 4, Color("2f2f2a"), 2))
	bar.add_theme_stylebox_override("fill", CowUI.box(Color("e3ae5a"), 4))
	next_row.add_child(bar)
	var next_label: = CowUI.label("", 15, Color("201a10"))
	next_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	next_label.offset_left = 10
	next_label.offset_right = -10
	next_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	next_label.clip_text = true
	next_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	next_label.add_theme_font_override("font", CowUI.title_font())
	bar.add_child(next_label)
	var next_button: = CowUI.action("RESEARCH", "")
	next_button.custom_minimum_size = Vector2(118, 40)
	next_button.pressed.connect(func():
		var target: = research.level(spec.id) + 1
		var error: = research.start(spec.id, target)
		message.text = (EquipmentIdentity.research_title(spec.id, target) + " research started") if error.is_empty() else error
		_refresh())
	next_row.add_child(next_button)
	unit_rows[spec.id] = {"card": card, "picture": image, "rank": rank, "name": name_label, "kind": kind_label, "costs": costs, "time": time, "produce": produce, "next_row": next_row, "bar": bar, "next": next_label, "research": next_button}

func _refresh_units(place: Dictionary) -> void:
	var stock: Dictionary = buildings.economy.stockpiles[GameSession.player_country]
	for id in unit_rows:
		var row: Dictionary = unit_rows[id]
		var spec: = buildings.economy.equipment(id)
		var level: = research.level(id)
		row.picture.texture = CowUI.research_picture(id, level)
		row.rank.level = level
		row.rank.queue_redraw()
		row.name.text = EquipmentIdentity.research_title(id, level).trim_suffix(" · upgrade").replace(" · technology", "")
		row.kind.text = (str(spec.get("research_branch", "")) if not str(spec.get("research_branch", "")).is_empty() else str(spec.get("category", ""))) + " Lvl. " + str(level)
		for child in row.costs.get_children(): row.costs.remove_child(child); child.queue_free()
		for resource in ProductionSystem.RESOURCES:
			if spec.cost[resource] > 0: row.costs.add_child(CowUI.cost(resource, spec.cost[resource], stock[resource] >= spec.cost[resource]))
		row.time.text = " " + SimulationClock.duration(spec.seconds / maxf(buildings.production_rate(city_id, spec), 0.01))
		var blocked: = ""
		if spec.get("requires_port", false) and not place.has("naval_spawn"): blocked = "COASTAL ONLY"
		for building_id in spec.get("building_requirements", {}):
			if blocked.is_empty() and buildings.level(city_id, building_id) < int(spec.building_requirements[building_id]):
				blocked = "NEEDS " + buildings.spec(building_id).get("name", building_id).to_upper()
		row.produce.get_meta("caption").text = "PRODUCE" if blocked.is_empty() else blocked
		row.produce.get_meta("caption").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.produce.disabled = not blocked.is_empty()
		# Next research level only.
		row.next_row.visible = level < 5
		if level >= 5: continue
		var target: = level + 1
		var job: = research.active(id)
		var caption: Label = row.research.get_meta("caption")
		if not job.is_empty() and not job.get("refinement", false) and int(job.level) == target:
			var total: = research.job_duration(job)
			row.bar.max_value = total
			row.bar.value = job.progress
			row.next.text = "Lvl. " + str(target) + "   " + SimulationClock.duration(total - job.progress, research.clock.speed if research.clock != null else 1.0)
			caption.text = "RESEARCHING"
			row.research.disabled = true
			continue
		row.bar.max_value = 1.0
		row.bar.value = 0.0
		var reason: = research.reason(id, target)
		var day: = research.unlock_day(id, target)
		row.next.text = "Lvl. " + str(target) + "   " + (("Day " + str(day)) if research.day() < day else SimulationClock.duration(research.duration(target)))
		caption.text = "RESEARCH"
		row.research.disabled = not reason.is_empty()
		row.research.tooltip_text = reason

func _effect(definition: Dictionary) -> String:
	match definition.id:
		"factory": return "Artillery, air defence & support"
		"industry": return "+25% city income per level"
		"tank_plant": return "Tanks & mechanized vehicles"
		"barracks": return "Infantry production"
		"naval_base": return "Ships, submarines & carriers · coastal cities"
		"airbase": return "Base for aircraft; more per level"
	return ""

func open(place: Dictionary) -> void:
	city_id = place.id
	message.text = ""
	show_tab(-1)
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
	var own: bool = controlled
	var scouted := controlled or (buildings.economy.armies != null and buildings.economy.armies.point_visible(place.point))
	var captured: bool = controlled and place.country.to_lower() != GameSession.player_country
	title.text = ("★ " if buildings.is_capital(place) else "") + place.name
	summary.text = ("YOURS · " + ("captured city · income 25%" if captured else ("capital" if buildings.is_capital(place) else "core city"))) if controlled else ("Controlled by " + buildings.economy.controller(place).capitalize())
	summary.text += " · MORALE " + str(roundi(buildings.economy.morale_factor(place)*100.0)) + "%"
	# Income per hour at 1x (industry level, specialties, capture penalty).
	for child in income_row.get_children(): child.queue_free()
	var specialties: = ResourceSites.city_resources(place.name)
	var income: = buildings.economy.city_income(place)
	for resource in ProductionSystem.RESOURCES:
		var item: = CowUI.cost(resource, income[resource] * SECONDS_PER_HOUR, true)
		var amount: Label = item.get_child(1)
		amount.text = "+" + amount.text + "/h"
		amount.add_theme_color_override("font_color", CowUI.GOLD if resource in specialties else Color("d9d3c0"))
		income_row.add_child(item)
	income_row.visible = own
	var rally: Dictionary = buildings.economy.rally_points.get(city_id, {})
	rally_tab.get_child(0).get_child(1).text = "Clear rally" if rally.get("country", "") == GameSession.player_country else "Rally point"
	rally_tab.disabled = not controlled
	list.visible = own and tab_index < 0
	unit_list.visible = own and tab_index >= 0
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
			var seconds: float = (spec.seconds - job.progress) / buildings.production_rate(city_id, spec)
			production.text.text = EquipmentIdentity.title(job.equipment) + "  ·  " + ("paused" if paused else SimulationClock.duration(seconds))
			production.picture.texture = CowUI.equipment_picture(job.equipment)
			production.picture.visible = true
			production.icon.visible = false
			production.bar.visible = true
			production.bar.max_value = spec.seconds
			production.bar.value = job.progress
			break
	if not own: return
	if tab_index >= 0:
		_refresh_units(place)
		return
	# Building rows.
	var stock: Dictionary = buildings.economy.stockpiles[GameSession.player_country]
	for id in rows:
		var row: Dictionary = rows[id]
		var definition: = buildings.spec(id)
		row.card.visible = not definition.get("coastal_only", false) or place.has("naval_spawn")
		if not row.card.visible: continue
		var current: = buildings.level(city_id, id)
		row.picture.texture = FacilityVisual.preview(definition,place.country.to_lower(),mini(current+1,int(definition.max_level)))
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

## Call of War rank badge: a dark shield with one chevron per level.
class Chevrons extends Control:
	var level: = 1
	func _init() -> void: mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var w: = size.x
		var h: = size.y
		draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.78), Vector2(w * 0.5, h), Vector2(0, h * 0.78)]), Color(0.08, 0.08, 0.07, 0.92))
		var step: = h * 0.15
		for i in clampi(level, 1, 5):
			var y: = h * 0.72 - i * step
			draw_polyline(PackedVector2Array([Vector2(w * 0.18, y + step * 0.6), Vector2(w * 0.5, y), Vector2(w * 0.82, y + step * 0.6)]), Color("f3dc9a"), 2.4)
