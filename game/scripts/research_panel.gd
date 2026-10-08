class_name ResearchPanel
extends CanvasLayer
var research: ResearchSystem
var panel: PanelContainer
var category: OptionButton
var family: OptionButton
var title: Label
var details: Label
var message: Label
var queue: VBoxContainer
var start_button: Button
var portrait: TextureRect
var cards: Array[Button] = []
var families: Array = []
var selected_level: = 2
var ui_timer: = 0.0
var category_overview: VBoxContainer
var tree_content: VBoxContainer
var overview_button: Button
var day_grid: GridContainer
var day_cards: Array[Button] = []

func setup(system: ResearchSystem, theme: Theme) -> void :
	research = system
	layer = 11
	var root: = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = theme
	add_child(root)
	var dim: = ColorRect.new()
	dim.color = Color(0.01, 0.025, 0.04, 0.88)
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
	title = Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color("ebd5aa"))
	header.add_child(title)
	var close: = Button.new()
	close.text = "Close"
	close.custom_minimum_size.y = 44
	close.pressed.connect(hide)
	header.add_child(close)
	var scroll: = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var content: = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	category_overview = VBoxContainer.new()
	content.add_child(category_overview)
	overview_button = Button.new()
	overview_button.text = "‹ Research categories"
	overview_button.custom_minimum_size.y = 44
	overview_button.pressed.connect( func(): _show_overview(true))
	content.add_child(overview_button)
	tree_content = VBoxContainer.new()
	tree_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(tree_content)
	category = OptionButton.new()
	for label in ["Armor", "Mechanized", "Artillery", "Fighters", "Air defense", "Navy", "Missiles", "Drones"]: category.add_item(label)
	category.custom_minimum_size.y = 44
	category.item_selected.connect( func(_index: int): _populate())
	tree_content.add_child(category)
	family = OptionButton.new()
	family.custom_minimum_size.y = 44
	family.item_selected.connect( func(_index: int): _refresh())
	tree_content.add_child(family)
	var grid_scroll: = ScrollContainer.new()
	grid_scroll.custom_minimum_size.y = 320
	tree_content.add_child(grid_scroll)
	day_grid = GridContainer.new()
	grid_scroll.add_child(day_grid)
	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(220, 125)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tree_content.add_child(portrait)
	var tree_scroll: = ScrollContainer.new()
	tree_scroll.custom_minimum_size.y = 115
	tree_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tree_content.add_child(tree_scroll)
	tree_scroll.hide()
	var tree: = HBoxContainer.new()
	tree.add_theme_constant_override("separation", 8)
	tree_scroll.add_child(tree)
	for level in range(1, 6):
		var card: = Button.new()
		card.custom_minimum_size = Vector2(130, 95)
		card.pressed.connect( func(): selected_level = level;_refresh())
		tree.add_child(card)
		cards.append(card)
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tree_content.add_child(details)
	start_button = Button.new()
	start_button.text = "Start research"
	start_button.custom_minimum_size.y = 48
	start_button.pressed.connect( func():
		var error: = research.start(_id(), selected_level)
		message.text = "Research started" if error.is_empty() else error
		_refresh())
	column.add_child(start_button)
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.text = "Swipe the timeline. New production uses your researched level; existing armies need modernization."
	tree_content.add_child(message)
	queue = VBoxContainer.new()
	column.add_child(queue)
	column.move_child(queue, 1)
	var upgrade: = Button.new()
	upgrade.text = "Modernize selected army"
	upgrade.tooltip_text = "Costs 50% of production resources and time. Army remains stationary."
	upgrade.custom_minimum_size.y = 48
	upgrade.pressed.connect( func():
		if research.armies.selected < 0: message.text = "Select an army on the map first"
		else: message.text = research.upgrade(research.armies.units[research.armies.selected])
		_refresh())
	tree_content.add_child(upgrade)
	research.changed.connect( func():
		if visible: _refresh())
	for index in category.item_count:
		var tile: = Button.new()
		tile.text = category.get_item_text(index)
		tile.custom_minimum_size.y = 80
		tile.expand_icon = true
		tile.add_theme_constant_override("icon_max_width", 100)
		for spec in research.economy.catalog:
			if spec.country == GameSession.player_country and spec.category == tile.text:
				tile.icon = UnitVisual.preview_texture(spec.id)
				break
		tile.pressed.connect( func(): category.select(index);_populate();_show_overview(false))
		category_overview.add_child(tile)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_populate()
	hide()
func _layout() -> void :
	var size: = get_viewport().get_visible_rect().size
	panel.position = Vector2(maxf(12, (size.x - 820) * 0.5), 12)
	panel.size = Vector2(minf(820, size.x - 24), size.y - 24)
func _id() -> String:
	return families[family.selected].id if family.selected >= 0 and family.selected < families.size() else ""
func _populate() -> void :
	families.clear()
	family.clear()
	for spec in research.economy.catalog:
		if spec.country != GameSession.player_country or spec.category != category.get_item_text(category.selected): continue
		families.append(spec)
		family.add_item(EquipmentIdentity.title(spec.id))
	if not families.is_empty(): family.select(0)
	selected_level = 2
	for child in day_grid.get_children(): day_grid.remove_child(child);child.queue_free()
	day_cards.clear()
	day_grid.columns = families.size() + 1
	var heading: = Label.new()
	heading.text = "DAY"
	day_grid.add_child(heading)
	for spec in families:
		var label: = Label.new()
		label.text = EquipmentIdentity.title(spec.id)
		label.custom_minimum_size.x = 130
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		day_grid.add_child(label)
	for level in range(1, 6):
		var day: = Label.new()
		day.text = str(ResearchSystem.DAYS[level - 1])
		day_grid.add_child(day)
		for index in families.size():
			var card: = Button.new()
			card.custom_minimum_size = Vector2(130, 90)
			card.icon = UnitVisual.preview_texture(families[index].id)
			card.expand_icon = true
			card.add_theme_constant_override("icon_max_width", 42)
			card.set_meta("equipment", families[index].id)
			card.set_meta("level", level)
			card.pressed.connect( func(): family.select(index);selected_level = level;_refresh())
			day_grid.add_child(card)
			day_cards.append(card)
	_refresh()
func _refresh() -> void :
	var id: = _id()
	if id.is_empty(): return
	title.text = "TECHNOLOGY · DAY " + str(research.day())
	portrait.texture = UnitVisual.preview_texture(id)
	for i in cards.size():
		var target: = i + 1
		var state: = "COMPLETE" if research.level(id) >= target else ("DAY LOCK" if research.day() < ResearchSystem.DAYS[i] else "AVAILABLE")
		if target > research.level(id) + 1: state = "PREREQUISITE"
		var job: = research.active(id)
		if not job.is_empty() and job.level == target: state = str(int(job.progress / research.duration(target) * 100)) + "%"
		cards[i].icon = portrait.texture
		cards[i].expand_icon = true
		cards[i].add_theme_constant_override("icon_max_width", 44)
		cards[i].text = "DAY " + str(ResearchSystem.DAYS[i]) + "\nLEVEL " + str(target) + "\n" + state
		cards[i].modulate = Color("f5d592") if target == selected_level else (Color("a3d9c0") if state == "COMPLETE" else Color.WHITE)
	for card in day_cards:
		var equipment: String = card.get_meta("equipment")
		var target: int = card.get_meta("level")
		var reason: = research.reason(equipment, target)
		var state: = "Complete" if research.level(equipment) >= target else ("Available" if reason.is_empty() else "Locked")
		var active: = research.active(equipment)
		if not active.is_empty() and active.level == target: state = str(int(active.progress / research.duration(target) * 100)) + "%"
		card.text = "L" + str(target) + """
""" + state
		card.tooltip_text = reason
		card.modulate = Color("f5d592") if equipment == id and target == selected_level else Color.WHITE
	var error: = research.reason(id, selected_level)
	start_button.disabled = not error.is_empty()
	details.text = EquipmentIdentity.title(id) + " · LEVEL " + str(selected_level) + "\n" + ("Available from the start" if selected_level == 1 else "Research time: " + SimulationClock.duration(research.duration(selected_level)) + " · Damage +" + str((selected_level - 1) * 12) + "% over Level 1")
	details.text += "\n" + research.capital_status()
	if selected_level > 1:
		var bill: = research.cost(id, selected_level)
		for resource in ProductionSystem.RESOURCES: details.text += "\n" + resource.capitalize() + ": " + str(bill[resource]) + " / " + str(int(research.economy.stockpiles.russia[resource]))
	if not error.is_empty(): details.text += "\n" + error
	for child in queue.get_children(): queue.remove_child(child);child.queue_free()
	var count: = 0
	for job in research.jobs:
		if research.economy.equipment(job.equipment).country != GameSession.player_country: continue
		count += 1
		var row: = HBoxContainer.new()
		queue.add_child(row)
		var label: = Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = EquipmentIdentity.title(job.equipment) + " L" + str(job.level) + " · " + ("PAUSED · capital lost" if research.rate(GameSession.player_country) <= 0 else SimulationClock.duration((research.duration(job.level) - job.progress) / research.rate(GameSession.player_country), research.clock.speed))
		row.add_child(label)
		var cancel: = Button.new()
		cancel.text = "Cancel"
		cancel.custom_minimum_size.y = 44
		cancel.pressed.connect( func(): research.cancel(job.equipment);_refresh())
		row.add_child(cancel)
	if count == 0:
		var empty: = Label.new()
		empty.text = "RESEARCH SLOTS · 0/2 active"
		queue.add_child(empty)
	title.text += " · " + str(count) + "/2 slots"
func _show_overview(overview: bool) -> void :
	category_overview.visible = overview
	tree_content.visible = not overview
	overview_button.visible = not overview
	start_button.visible = not overview
func open() -> void :
	show()
	_show_overview(true)
	_layout()
	_refresh()
func _process(delta: float) -> void :
	if not visible: return
	ui_timer += delta
	if ui_timer >= 0.5:
		ui_timer = 0
		_refresh()
