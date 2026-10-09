class_name ResearchPanel
extends CanvasLayer
## National research screen in the Call of War style (owner review 2026-10-09: "research
## should be separate from the cities"; reference screenshots of Call of War's research).
## Two research slots at the top, then either the category banners or a category's tech tree:
## a column per equipment family and a row per level (labelled with the day it unlocks).
## Tapping a level shows its cost and the RESEARCH button in the bar at the bottom.
const CATEGORIES: = ["Armor", "Mechanized", "Artillery", "Fighters", "Air defense", "Navy", "Missiles", "Drones"]
const CELL: = Vector2(150, 150)
var research: ResearchSystem
var panel: PanelContainer
var title: Label
var back_button: Button
var slots: Array = []
var overview: ScrollContainer
var tree_view: VBoxContainer
var tab_row: HBoxContainer
var column_titles: HBoxContainer
var grid: GridContainer
var cells: Array = []
var detail: Dictionary = {}
var message: Label
var category_index: = 0
var selected_id: = ""
var selected_level: = 2
var ui_timer: = 0.0

func setup(system: ResearchSystem, theme: Theme) -> void:
	research = system
	layer = 11
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
	var head: = CowUI.header("Research", true)
	title = head.title
	back_button = head.back
	back_button.pressed.connect(func(): _show_overview(true))
	head.close.pressed.connect(hide)
	column.add_child(head.bar)
	# Two research slots.
	var slot_row: = HBoxContainer.new()
	slot_row.add_theme_constant_override("separation", 8)
	var slot_margin: = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: slot_margin.add_theme_constant_override("margin_" + side, 8)
	slot_margin.add_child(slot_row)
	column.add_child(slot_margin)
	for i in ResearchSystem.SLOTS:
		var slot: = CowUI.status_box("research")
		var cancel: = Button.new()
		cancel.text = "✕"
		cancel.custom_minimum_size = Vector2(40, 60)
		cancel.add_theme_font_size_override("font_size", 20)
		for state in ["normal", "hover", "pressed"]: cancel.add_theme_stylebox_override(state, CowUI.box(CowUI.RED, 3))
		cancel.visible = false
		var inner: HBoxContainer = slot.panel.get_child(0)
		inner.add_child(cancel)
		inner.move_child(cancel, 0)
		slot.cancel = cancel
		slot_row.add_child(slot.panel)
		slots.append(slot)
	# Category banners.
	overview = ScrollContainer.new()
	overview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overview.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(overview)
	var banners: = VBoxContainer.new()
	banners.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	banners.add_theme_constant_override("separation", 8)
	var banner_margin: = MarginContainer.new()
	banner_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "bottom"]: banner_margin.add_theme_constant_override("margin_" + side, 8)
	banner_margin.add_child(banners)
	overview.add_child(banner_margin)
	for index in CATEGORIES.size():
		var families: = _families(index)
		if families.is_empty(): continue
		var banner: = Button.new()
		banner.custom_minimum_size.y = 118
		var art: = "banner_" + GameSession.player_country
		banner.add_theme_stylebox_override("normal", CowUI.skin(art, 6))
		banner.add_theme_stylebox_override("hover", CowUI.skin(art, 6, 0, Color(1.06, 1.06, 1.06)))
		banner.add_theme_stylebox_override("pressed", CowUI.skin(art, 6, 0, Color(0.92, 0.92, 0.92)))
		banner.pressed.connect(func(): show_category(index))
		var picture: = TextureRect.new()
		picture.texture = CowUI.equipment_picture(families[0].id)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.anchor_left = 0.45
		picture.anchor_right = 1.0
		picture.anchor_bottom = 1.0
		picture.offset_top = 6
		picture.offset_bottom = -6
		picture.offset_right = -10
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		banner.add_child(picture)
		var name: = CowUI.label(CATEGORIES[index], 34, CowUI.INK)
		name.anchor_top = 1.0
		name.anchor_bottom = 1.0
		name.offset_left = 18
		name.offset_top = -58
		name.offset_bottom = -12
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		banner.add_child(name)
		banners.add_child(banner)
	# Tech tree.
	tree_view = VBoxContainer.new()
	tree_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree_view.add_theme_constant_override("separation", 0)
	column.add_child(tree_view)
	var tab_scroll: = ScrollContainer.new()
	tab_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab_scroll.custom_minimum_size.y = 70
	tree_view.add_child(tab_scroll)
	tab_row = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 0)
	tab_scroll.add_child(tab_row)
	var board: = PanelContainer.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.add_theme_stylebox_override("panel", CowUI.skin("list", 8))
	tree_view.add_child(board)
	var board_column: = VBoxContainer.new()
	board_column.add_theme_constant_override("separation", 0)
	board.add_child(board_column)
	column_titles = HBoxContainer.new()
	column_titles.add_theme_constant_override("separation", 0)
	board_column.add_child(column_titles)
	var grid_scroll: = ScrollContainer.new()
	grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_column.add_child(grid_scroll)
	grid = GridContainer.new()
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	grid_scroll.add_child(grid)
	# Selected technology: cost, time and RESEARCH.
	var bar: = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", CowUI.skin("header", 4, 8))
	tree_view.add_child(bar)
	var bar_row: = HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 10)
	bar.add_child(bar_row)
	var picture: = TextureRect.new()
	picture.custom_minimum_size = Vector2(70, 60)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bar_row.add_child(picture)
	var info: = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_row.add_child(info)
	var name_label: = CowUI.label("", 16)
	name_label.clip_text = true
	info.add_child(name_label)
	var costs_back: = PanelContainer.new()
	costs_back.add_theme_stylebox_override("panel", CowUI.box(CowUI.ROW, 4, Color(0, 0, 0, 0), 0, 3))
	costs_back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	info.add_child(costs_back)
	var costs: = HBoxContainer.new()
	costs.add_theme_constant_override("separation", 8)
	costs_back.add_child(costs)
	var side: = VBoxContainer.new()
	bar_row.add_child(side)
	var time_row: = HBoxContainer.new()
	time_row.alignment = BoxContainer.ALIGNMENT_CENTER
	side.add_child(time_row)
	time_row.add_child(CowUI.Icon.new("clock", Color("ece6d6"), Vector2(20, 20)))
	var time: = CowUI.label("", 14)
	time_row.add_child(time)
	var start: = CowUI.action("RESEARCH", "flask")
	start.pressed.connect(func():
		var error: = _system().start(selected_id, selected_level)
		message.text = (EquipmentIdentity.title(selected_id) + " level " + str(selected_level) + " research started") if error.is_empty() else error
		_refresh())
	side.add_child(start)
	detail = {"picture": picture, "name": name_label, "costs": costs, "time": time, "start": start}
	var footer: = HBoxContainer.new()
	tree_view.add_child(footer)
	message = CowUI.label("", 13, CowUI.GOLD)
	message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message.clip_text = true
	footer.add_child(message)
	var modernize: = Button.new()
	modernize.text = "Modernize selected army"
	modernize.custom_minimum_size.y = 40
	modernize.tooltip_text = "Bring the selected army up to your researched levels. Costs 50% of production; the army stays put."
	modernize.pressed.connect(func():
		if research.armies.selected < 0: message.text = "Select an army on the map first"
		else: message.text = research.upgrade(research.armies.units[research.armies.selected])
		_refresh())
	footer.add_child(modernize)
	system.changed.connect(func():
		if visible: _refresh())
	get_viewport().size_changed.connect(_layout)
	_layout()
	hide()

func _system() -> ResearchSystem:
	return research

func _families(index: int) -> Array:
	return _system().economy.catalog.filter(func(spec: Dictionary): return spec.country == GameSession.player_country and spec.category == CATEGORIES[index])

func show_category(index: int) -> void:
	category_index = index
	var families: = _families(index)
	selected_id = families[0].id if not families.is_empty() else ""
	selected_level = clampi(_system().level(selected_id) + 1, 2, 5) if not selected_id.is_empty() else 2
	_build_tree()
	_show_overview(false)
	_refresh()

func _build_tree() -> void:
	for child in tab_row.get_children(): child.queue_free()
	for index in CATEGORIES.size():
		var families: = _families(index)
		if families.is_empty(): continue
		var tab: = CowUI.tab(CATEGORIES[index], "", index == category_index)
		tab.custom_minimum_size.x = 96
		var picture: = TextureRect.new()
		picture.texture = CowUI.equipment_picture(families[0].id)
		picture.custom_minimum_size = Vector2(44, 30)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var inner: VBoxContainer = tab.get_child(0)
		inner.add_child(picture)
		inner.move_child(picture, 0)
		tab.pressed.connect(func(): show_category(index))
		tab_row.add_child(tab)
	var families: = _families(category_index)
	for child in column_titles.get_children(): child.queue_free()
	var corner: = PanelContainer.new()
	corner.custom_minimum_size = Vector2(56, 52)
	corner.add_theme_stylebox_override("panel", CowUI.box(Color("cfcab8"), 0, Color("a39e8b"), 1))
	var day: = CowUI.label("Day", 15, CowUI.INK)
	day.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	corner.add_child(day)
	column_titles.add_child(corner)
	for spec in families:
		var heading: = PanelContainer.new()
		heading.custom_minimum_size = Vector2(CELL.x, 52)
		heading.add_theme_stylebox_override("panel", CowUI.box(Color("dcd7c6"), 0, Color("a39e8b"), 1, 4))
		var text: = CowUI.label(EquipmentIdentity.title(spec.id), 15, CowUI.INK)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text.clip_text = true
		heading.add_child(text)
		column_titles.add_child(heading)
	for child in grid.get_children(): child.queue_free()
	cells.clear()
	grid.columns = families.size() + 1
	for level in range(1, 6):
		var day_number: int = ResearchSystem.DAYS[level - 1]
		var day_cell: = PanelContainer.new()
		day_cell.custom_minimum_size = Vector2(56, CELL.y)
		day_cell.add_theme_stylebox_override("panel", CowUI.box(Color("cfcab8"), 0, Color("a39e8b"), 1))
		var shown: bool = level == 1 or ResearchSystem.DAYS[level - 2] != day_number
		var number: = CowUI.label(str(day_number) if shown else "", 34, CowUI.INK)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		day_cell.add_child(number)
		grid.add_child(day_cell)
		for spec in families:
			var cell: = TechCell.new(level > 1, level < 5)
			cell.custom_minimum_size = CELL
			var card: = Button.new()
			card.anchor_left = 0.5
			card.anchor_right = 0.5
			card.offset_left = -52
			card.offset_right = 52
			card.offset_top = 12
			card.offset_bottom = 112
			card.icon = CowUI.equipment_picture(spec.id)
			card.expand_icon = true
			card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			card.pressed.connect(func():
				selected_id = spec.id
				selected_level = level
				message.text = ""
				_refresh())
			cell.add_child(card)
			var ribbon: = CowUI.label("Level " + str(level), 14, Color("efe6cf"))
			ribbon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ribbon.add_theme_stylebox_override("normal", CowUI.box(Color("2c2b27"), 0, Color(0, 0, 0, 0), 0, 2))
			ribbon.anchor_left = 0.5
			ribbon.anchor_right = 0.5
			ribbon.offset_left = -52
			ribbon.offset_right = 52
			ribbon.offset_top = 116
			ribbon.offset_bottom = 140
			cell.add_child(ribbon)
			grid.add_child(cell)
			cells.append({"card": card, "id": spec.id, "level": level})

func _show_overview(show_banners: bool) -> void:
	overview.visible = show_banners
	tree_view.visible = not show_banners
	back_button.modulate.a = 0.0 if show_banners else 1.0
	back_button.disabled = show_banners

func open() -> void:
	show()
	_show_overview(true)
	_layout()
	_refresh()

func _layout() -> void:
	var size: = get_viewport().get_visible_rect().size
	var width: = minf(760.0, size.x)
	var top: = roundf(size.y * 0.06)
	panel.position = Vector2((size.x - width) * 0.5, top)
	panel.size = Vector2(width, size.y - top)

func _state(id: String, level: int) -> String:
	var system: = _system()
	if system.level(id) >= level: return "done"
	var job: = system.active(id)
	if not job.is_empty() and job.level == level: return "active"
	return "available" if system.reason(id, level).is_empty() else "locked"

func _refresh() -> void:
	var system: = _system()
	title.text = "Research"
	# Slots.
	var jobs: = system.jobs.filter(func(job: Dictionary): return system.economy.equipment(job.equipment).country == GameSession.player_country)
	for i in slots.size():
		var slot: Dictionary = slots[i]
		var job: Dictionary = jobs[i] if i < jobs.size() else {}
		slot.cancel.visible = not job.is_empty()
		slot.picture.visible = not job.is_empty()
		slot.icon.visible = job.is_empty()
		slot.bar.visible = not job.is_empty()
		if job.is_empty():
			slot.text.text = "No research"
			continue
		var total: = system.duration(job.level)
		slot.picture.texture = CowUI.equipment_picture(job.equipment)
		slot.text.text = "L" + str(job.level) + " · " + SimulationClock.duration(total - job.progress, system.clock.speed)
		slot.bar.max_value = total
		slot.bar.value = job.progress
		for connection in slot.cancel.pressed.get_connections(): slot.cancel.pressed.disconnect(connection.callable)
		var id: String = job.equipment
		slot.cancel.pressed.connect(func():
			system.cancel(id)
			message.text = "Research cancelled · unused resources refunded"
			_refresh())
	if not tree_view.visible or selected_id.is_empty(): return
	# Tree cards.
	for cell in cells:
		var state: = _state(cell.id, cell.level)
		var color: Color = {"done": Color("6f9a4a"), "active": Color("5b86b0"), "available": Color("d7b25a"), "locked": Color("8f8b7c")}[state]
		var chosen: bool = cell.id == selected_id and cell.level == selected_level
		var face: = CowUI.skin("btn_grey", 12, 6, Color(color.r * 1.75, color.g * 1.75, color.b * 1.75))
		if chosen:
			var ring: = CowUI.box(color.lightened(0.15), 6, CowUI.GOLD, 4, 6)
			for style_state in ["normal", "hover", "pressed"]: cell.card.add_theme_stylebox_override(style_state, ring)
		else:
			for style_state in ["normal", "hover", "pressed"]: cell.card.add_theme_stylebox_override(style_state, face)
		cell.card.modulate = Color(1, 1, 1, 0.7) if state == "locked" else Color.WHITE
	# Selected technology.
	detail.picture.texture = CowUI.equipment_picture(selected_id)
	detail.name.text = EquipmentIdentity.title(selected_id) + " · Level " + str(selected_level) + ("  (+" + str((selected_level - 1) * 12) + "% damage)" if selected_level > 1 else "")
	for child in detail.costs.get_children(): child.queue_free()
	var caption: Label = detail.start.get_meta("caption")
	var state: = _state(selected_id, selected_level)
	if selected_level <= 1 or state == "done":
		detail.time.text = ""
		caption.text = "RESEARCHED"
		detail.start.disabled = true
		return
	var bill: = system.cost(selected_id, selected_level)
	var stock: Dictionary = system.economy.stockpiles[GameSession.player_country]
	for resource in ProductionSystem.RESOURCES:
		if bill[resource] > 0: detail.costs.add_child(CowUI.cost(resource, bill[resource], stock[resource] >= bill[resource]))
	detail.time.text = " " + SimulationClock.duration(system.duration(selected_level))
	var reason: = system.reason(selected_id, selected_level)
	detail.start.disabled = not reason.is_empty()
	detail.start.tooltip_text = reason
	caption.text = "IN PROGRESS" if state == "active" else "RESEARCH"
	if not reason.is_empty() and state != "active" and message.text.is_empty(): message.text = reason

func _process(delta: float) -> void:
	if not visible: return
	ui_timer += delta
	if ui_timer >= 0.5:
		ui_timer = 0
		_refresh()

## Tech-tree cell: draws the connector line from the level above to the level below.
class TechCell extends Control:
	var above: bool
	var below: bool
	func _init(from_above: bool, to_below: bool) -> void:
		above = from_above
		below = to_below
	func _draw() -> void:
		var x: = size.x * 0.5
		if above: draw_line(Vector2(x, 0), Vector2(x, 12), Color("2c2b27"), 4)
		if below: draw_line(Vector2(x, 140), Vector2(x, size.y), Color("2c2b27"), 4)
		draw_line(Vector2(size.x, 0), Vector2(size.x, size.y), Color("a39e8b"), 1)
