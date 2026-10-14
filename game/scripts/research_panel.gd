class_name ResearchPanel
extends CanvasLayer
## National research screen in the Call of War style (owner review 2026-10-09: "research
## should be separate from the cities"; reference screenshots of Call of War's research).
## Two research slots at the top, then either the category banners or a category's tech tree:
## a column per equipment family and a row per level (labelled with the day it unlocks).
## Tapping a level shows its cost and the RESEARCH button in the bar at the bottom.
const CATEGORIES: = ProductionGroups.TITLES
const CELL: = Vector2(150, 150)
const TREE_CELL: = Vector2(162, 188)
const CARD: = 128.0
const DAY_COLUMN: = 56.0
var research: ResearchSystem
var panel: PanelContainer
var title: Label
var back_button: Button
var slots: Array = []
var overview: ScrollContainer
var banners: VBoxContainer
var tree_scroll: ScrollContainer
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
var selected_upgrade: = false
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
	banners = VBoxContainer.new()
	banners.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	banners.add_theme_constant_override("separation", 8)
	var banner_margin: = MarginContainer.new()
	banner_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "bottom"]: banner_margin.add_theme_constant_override("margin_" + side, 8)
	banner_margin.add_child(banners)
	overview.add_child(banner_margin)
	_build_banners()
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
	board.add_theme_stylebox_override("panel", CowUI.box(Color("c4c1b6"), 0, Color("6c6a60"), 1, 0))
	tree_view.add_child(board)
	var board_column: = VBoxContainer.new()
	board_column.add_theme_constant_override("separation", 0)
	board.add_child(board_column)
	tree_scroll = ScrollContainer.new()
	tree_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_column.add_child(tree_scroll)
	var tree_content: = VBoxContainer.new()
	tree_content.add_theme_constant_override("separation", 0)
	tree_scroll.add_child(tree_content)
	column_titles = HBoxContainer.new()
	column_titles.add_theme_constant_override("separation", 0)
	tree_content.add_child(column_titles)
	grid = GridContainer.new()
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	tree_content.add_child(grid)
	# Room under the last row so level 5 is never hidden behind the scroll bar.
	var bottom_space: = Control.new()
	bottom_space.custom_minimum_size.y = 28
	tree_content.add_child(bottom_space)
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
	var level_badge := CityPanel.Chevrons.new()
	level_badge.anchor_left = 1.0
	level_badge.anchor_right = 1.0
	level_badge.offset_left = -22
	level_badge.offset_top = 0
	level_badge.offset_bottom = 30
	picture.add_child(level_badge)
	var info: = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_row.add_child(info)
	var name_label: = CowUI.label("", 16)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size.x = 220
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
		var error: = _system().start_upgrade(selected_id, selected_level) if selected_upgrade else _system().start(selected_id, selected_level)
		message.text = (EquipmentIdentity.title(selected_id) + " level " + EquipmentIdentity.roman_level(selected_level) + (" upgrade" if selected_upgrade else "") + " research started") if error.is_empty() else error
		_refresh())
	side.add_child(start)
	detail = {"picture": picture, "rank": level_badge, "name": name_label, "costs": costs, "time": time, "start": start}
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

func _build_banners() -> void:
	for child in banners.get_children(): banners.remove_child(child); child.queue_free()
	for index in CATEGORIES.size():
		var families := _families(index)
		if families.is_empty(): continue
		var banner := Button.new()
		banner.custom_minimum_size.y = 164
		for state in ["normal", "hover", "pressed"]:
			var color: Color = {"normal": Color("293238"), "hover": Color("344047"), "pressed": Color("20282d")}[state]
			banner.add_theme_stylebox_override(state, CowUI.box(color, 6, Color("526068"), 1))
		banner.pressed.connect(func(): show_category(index))
		var hero: Dictionary = families[0]
		for spec in families:
			if _system().unlock_day(spec.id, 1) < _system().unlock_day(hero.id, 1): hero = spec
		var picture := TextureRect.new()
		picture.texture = CowUI.equipment_picture(hero.id)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.anchor_left = 1.0
		picture.anchor_right = 1.0
		picture.offset_left = -162
		picture.offset_right = -14
		picture.offset_top = 8
		picture.offset_bottom = 156
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		banner.add_child(picture)
		var symbol := UnitTypeIcon.silhouette(ProductionGroups.ICONS[index], CowUI.GOLD, Vector2(42, 40))
		symbol.offset_left = 18
		symbol.offset_right = 60
		symbol.offset_top = 64
		symbol.offset_bottom = 104
		banner.add_child(symbol)
		var name := CowUI.label(CATEGORIES[index], 32, Color("f4ecd8"))
		name.add_theme_font_override("font", CowUI.title_font())
		name.anchor_right = 1.0
		name.offset_left = 78
		name.offset_right = -176
		name.offset_top = 58
		name.offset_bottom = 110
		name.clip_text = true
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		banner.add_child(name)
		banners.add_child(banner)

func _system() -> ResearchSystem:
	return research

func _families(index: int) -> Array:
	# Owner 2026-10-13: economy upgrades are city buildings, not research; retired families are hidden.
	var result: Array = _system().economy.catalog.filter(func(spec: Dictionary): return spec.country == GameSession.player_country and ProductionGroups.index(spec) == index and ProductionGroups.offered(spec))
	result.sort_custom(ProductionGroups.before)
	return result

func show_category(index: int) -> void:
	selected_upgrade = false
	category_index = index
	var families: = _families(index)
	selected_id = families[0].id if not families.is_empty() else ""
	selected_level = clampi(_system().level(selected_id) + 1, 1, 5) if not selected_id.is_empty() else 1
	_build_tree()
	_show_overview(false)
	tree_scroll.scroll_vertical = 0
	tree_scroll.scroll_horizontal = 0
	_refresh()

func _build_tree() -> void:
	for child in tab_row.get_children(): tab_row.remove_child(child);child.queue_free()
	for index in CATEGORIES.size():
		var tab_families: = _families(index)
		if tab_families.is_empty(): continue
		var tab: = CowUI.tab(CATEGORIES[index], "", index == category_index)
		tab.custom_minimum_size.x = 96
		var symbol: = UnitTypeIcon.silhouette(ProductionGroups.ICONS[index], CowUI.GOLD, Vector2(34, 28))
		symbol.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var inner: VBoxContainer = tab.get_child(0)
		inner.add_child(symbol)
		inner.move_child(symbol, 0)
		tab.pressed.connect(func(): show_category(index))
		tab_row.add_child(tab)
	# Call of War tree (owner 2026-10-13): a column per family, a row per DAY; each level sits
	# on the day it unlocks, with a line down the column to the next level.
	var families: = _families(category_index)
	var cell_size: = TREE_CELL
	for child in column_titles.get_children(): column_titles.remove_child(child);child.queue_free()
	var corner: = PanelContainer.new()
	corner.custom_minimum_size = Vector2(DAY_COLUMN, 64)
	corner.add_theme_stylebox_override("panel", CowUI.box(Color("cfcbbd"), 0, Color("a9a596"), 1))
	var day: = CowUI.label("Day", 16, CowUI.INK)
	day.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	corner.add_child(day)
	column_titles.add_child(corner)
	for spec in families:
		var heading: = PanelContainer.new()
		heading.custom_minimum_size = Vector2(cell_size.x, 64)
		heading.add_theme_stylebox_override("panel", CowUI.box(Color("dedbcf"), 0, Color("a9a596"), 1, 4))
		var text: = CowUI.label(str(spec.get("research_branch", "")) if not str(spec.get("research_branch", "")).is_empty() else EquipmentIdentity.title(spec.id), 16, CowUI.INK)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.max_lines_visible = 2
		text.custom_minimum_size.x = cell_size.x - 8
		heading.add_child(text)
		column_titles.add_child(heading)
	for child in grid.get_children(): grid.remove_child(child);child.queue_free()
	cells.clear()
	grid.columns = families.size() + 1
	# Rows: each unlock day, repeated when a family unlocks several levels on the same day.
	var slots: Dictionary = {}  # day -> rows needed
	var placed: Dictionary = {}  # "id:level" -> [day, sub-row]
	for spec in families:
		var per_day: Dictionary = {}
		for level in range(1, 6):
			var unlock: = _system().unlock_day(spec.id, level)
			var sub: int = per_day.get(unlock, 0)
			per_day[unlock] = sub + 1
			slots[unlock] = maxi(slots.get(unlock, 0), sub + 1)
			placed[spec.id + ":" + str(level)] = [unlock, sub]
	var days: Array = slots.keys()
	days.sort()
	var rows: Array = []
	for unlock in days:
		for sub in slots[unlock]: rows.append([unlock, sub])
	for r in rows.size():
		var day_cell: = PanelContainer.new()
		day_cell.custom_minimum_size = Vector2(DAY_COLUMN, cell_size.y)
		day_cell.add_theme_stylebox_override("panel", CowUI.box(Color("cfcbbd")))
		var number: = CowUI.label(str(rows[r][0]) if rows[r][1] == 0 else "", 38, CowUI.INK)
		number.add_theme_font_override("font", CowUI.title_font())
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		day_cell.add_child(number)
		grid.add_child(day_cell)
		for spec in families:
			var level: = 0
			var first_row: = rows.size()
			var last_row: = -1
			for l in range(1, 6):
				var at: Array = placed[spec.id + ":" + str(l)]
				var row_of: = rows.find(at)
				first_row = mini(first_row, row_of)
				last_row = maxi(last_row, row_of)
				if row_of == r: level = l
			var cell: = TreeCell.new()
			cell.custom_minimum_size = cell_size
			cell.above = r > first_row and r <= last_row
			cell.below = r >= first_row and r < last_row
			cell.has_card = level > 0
			grid.add_child(cell)
			if level == 0: continue
			var card: = Button.new()
			card.anchor_left = 0.5
			card.anchor_right = 0.5
			card.offset_left = -CARD * 0.5
			card.offset_right = CARD * 0.5
			card.offset_top = 10
			card.offset_bottom = 10 + CARD
			var portrait: = TextureRect.new()
			portrait.texture = CowUI.research_picture(spec.id, level)
			portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			for side in ["offset_left", "offset_top"]: portrait.set(side, 6)
			for side in ["offset_right", "offset_bottom"]: portrait.set(side, -6)
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(portrait)
			var rank: = CityPanel.Chevrons.new()
			rank.level = level
			rank.anchor_left = 1.0
			rank.anchor_right = 1.0
			rank.offset_left = -34
			rank.offset_right = -6
			rank.offset_top = 6
			rank.offset_bottom = 40
			card.add_child(rank)
			var chosen_id: String = spec.id
			var chosen_level: = level
			card.pressed.connect(func():
				selected_id = chosen_id
				selected_level = chosen_level
				selected_upgrade = false
				message.text = ""
				_refresh())
			cell.add_child(card)
			var caption: = CowUI.label("Level " + EquipmentIdentity.roman_level(level), 15, Color("f4ecd8"))
			caption.add_theme_font_override("font", CowUI.title_font())
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			caption.add_theme_stylebox_override("normal", CowUI.box(Color("26231d"), 2))
			caption.anchor_left = 0.5
			caption.anchor_right = 0.5
			caption.offset_left = -CARD * 0.5
			caption.offset_right = CARD * 0.5
			caption.offset_top = 16 + CARD
			caption.offset_bottom = 42 + CARD
			caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
			caption.tooltip_text = EquipmentIdentity.research_title(spec.id, level)
			cell.add_child(caption)
			cells.append({"card": card, "id": spec.id, "level": level})

func _append_upgrades(families: Array, level: int, cell_size: Vector2) -> void:
	var label_cell: = Control.new()
	label_cell.custom_minimum_size = Vector2(56,104)
	grid.add_child(label_cell)
	for spec in families:
		var cell: = TechCell.new(true,true)
		cell.custom_minimum_size = Vector2(cell_size.x,104)
		var card: = Button.new()
		card.anchor_left=0.5;card.anchor_right=0.5
		card.offset_left=-cell_size.x*0.43;card.offset_right=cell_size.x*0.43
		card.offset_top=12;card.offset_bottom=90
		var caption: = CowUI.label("UPGRADE · "+EquipmentIdentity.research_title(spec.id,level)+"\nDay "+str(_system().upgrade_day(spec.id,level))+" · +6% effectiveness",16,CowUI.INK)
		caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		caption.offset_left=8;caption.offset_right=-8
		caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
		card.add_child(caption)
		card.pressed.connect(func():
			selected_id=spec.id;selected_level=level;selected_upgrade=true;message.text="";_refresh())
		cell.add_child(card);grid.add_child(cell)
		cells.append({"card":card,"id":spec.id,"level":level,"refinement":true})

func _show_overview(show_banners: bool) -> void:
	overview.visible = show_banners
	tree_view.visible = not show_banners
	back_button.modulate.a = 0.0 if show_banners else 1.0
	back_button.disabled = show_banners

func open() -> void:
	show()
	_build_banners()
	_show_overview(true)
	_layout()
	_refresh()

func _layout() -> void:
	var size: = get_viewport().get_visible_rect().size
	var width: = minf(760.0, size.x)
	var top: = roundf(size.y * 0.06)
	panel.position = Vector2((size.x - width) * 0.5, top)
	panel.scale = Vector2.ONE * CowUI.MENU_ZOOM
	panel.size = Vector2(width, size.y - top) / CowUI.MENU_ZOOM

func _state(id: String, level: int, refinement: bool = false) -> String:
	var system: = _system()
	if refinement:
		if system.refined(id,level): return "done"
		var upgrade: = system.active(id)
		if upgrade.get("refinement",false) and int(upgrade.get("level",0)) == level: return "active"
		return "available" if system.upgrade_reason(id,level).is_empty() else "locked"
	if system.level(id) >= level: return "done"
	var job: = system.active(id)
	if not job.is_empty() and not job.get("refinement",false) and job.level == level: return "active"
	return "available" if system.reason(id, level).is_empty() else "locked"

func _refresh() -> void:
	var system: = _system()
	title.text = CATEGORIES[category_index] + " research" if tree_view.visible else "Research"
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
			slot.gold.visible = false
			continue
		var total: = system.job_duration(job)
		slot.picture.texture = CowUI.research_picture(job.equipment, job.level)
		slot.text.text = ("Upgrade " if job.get("refinement",false) else "Level ") + EquipmentIdentity.roman_level(job.level) + " · " + SimulationClock.duration(total - job.progress, system.clock.speed)
		slot.bar.max_value = total
		slot.bar.value = job.progress
		for connection in slot.cancel.pressed.get_connections(): slot.cancel.pressed.disconnect(connection.callable)
		var id: String = job.equipment
		slot.cancel.pressed.connect(func():
			system.cancel(id)
			message.text = "Research cancelled · unused resources refunded"
			_refresh())
		CowUI.gold_button(slot.gold, system.speedup_price(job), func():
			var error: String = system.finish_now(id, GameSession.player_country)
			message.text = error if not error.is_empty() else "Research finished with gold"
			_refresh())
	if not tree_view.visible or selected_id.is_empty(): return
	# Tree cards.
	for cell in cells:
		var state: = _state(cell.id, cell.level,cell.get("refinement",false))
		# Call of War colours: green = researched, gold = can research now, blue = researching, grey = later.
		var color: Color = {"done": Color("6f9440"), "active": Color("4f7fae"), "available": Color("d8b65a"), "locked": Color("9a978c")}[state]
		var chosen: bool = cell.id == selected_id and cell.level == selected_level and bool(cell.get("refinement",false)) == selected_upgrade
		var face: = CowUI.box(color, 2, Color("2b2820"), 2)
		if chosen:
			var ring: = CowUI.box(color, 2, Color("fff1b8"), 4)
			for style_state in ["normal", "hover", "pressed"]: cell.card.add_theme_stylebox_override(style_state, ring)
		else:
			for style_state in ["normal", "hover", "pressed"]: cell.card.add_theme_stylebox_override(style_state, face)
		cell.card.modulate = Color.WHITE
	# Selected technology.
	detail.picture.texture = CowUI.research_picture(selected_id, selected_level)
	detail.rank.level = selected_level
	detail.rank.queue_redraw()
	detail.name.text = EquipmentIdentity.title(selected_id) + " · Level " + EquipmentIdentity.roman_level(selected_level) + ("  (+" + str((selected_level - 1) * 12) + "% damage)" if selected_level > 1 else "")
	var tier: Dictionary = EquipmentIdentity.research_tier(selected_id, selected_level)
	if not tier.is_empty():
		detail.name.text = EquipmentIdentity.research_title(selected_id, selected_level) + " · Level " + EquipmentIdentity.roman_level(selected_level) + " · Day " + str(system.unlock_day(selected_id, selected_level))
		if tier.has("range") and tier.has("damage"):
			detail.name.text += "\n" + tier.get("improvement", "") + " · Range " + str(tier.range) + " · AA " + str(tier.damage) + "\n" + ("Jets, bombers, helicopters · cannot see drones" if selected_id.begins_with("patriot") else "Drones, helicopters, attacking jets · cannot reach bombers") + " · " + EquipmentIdentity.spec(selected_id).get("model_status", "")
		else:
			detail.name.text += "\n" + tier.get("improvement", "")
	if selected_upgrade:
		detail.name.text = EquipmentIdentity.research_title(selected_id,selected_level)+" · Upgrade "+EquipmentIdentity.roman_level(selected_level)+" · Day "+str(system.upgrade_day(selected_id,selected_level))+"\n+6% combat effectiveness for this model · applies nationally"
	for child in detail.costs.get_children(): detail.costs.remove_child(child);child.queue_free()
	var caption: Label = detail.start.get_meta("caption")
	var state: = _state(selected_id, selected_level,selected_upgrade)
	if state == "done":
		detail.time.text = ""
		caption.text = "RESEARCHED"
		detail.start.disabled = true
		return
	var bill: = system.upgrade_cost(selected_id,selected_level) if selected_upgrade else system.cost(selected_id, selected_level)
	var stock: Dictionary = system.economy.stockpiles[GameSession.player_country]
	for resource in ProductionSystem.RESOURCES:
		if bill[resource] > 0: detail.costs.add_child(CowUI.cost(resource, bill[resource], stock[resource] >= bill[resource]))
	detail.time.text = " " + SimulationClock.duration(system.upgrade_duration(selected_level) if selected_upgrade else system.duration(selected_level))
	var reason: = system.upgrade_reason(selected_id,selected_level) if selected_upgrade else system.reason(selected_id, selected_level)
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
		if above: draw_line(Vector2(x, 0), Vector2(x, 12), Color("98aaa7"), 2)
		if below: draw_line(Vector2(x, size.y - 14), Vector2(x, size.y), Color("98aaa7"), 2)

## Tree cell: the column line runs through cells between a family's levels.
class TreeCell extends Control:
	var above: = false
	var below: = false
	var has_card: = false
	func _draw() -> void:
		var x: = size.x * 0.5
		var line: = Color("2f2c25")
		if has_card:
			if above: draw_line(Vector2(x, 0), Vector2(x, 10), line, 3)
			if below: draw_line(Vector2(x, 10 + 128 + 32), Vector2(x, size.y), line, 3)
		elif above and below:
			draw_line(Vector2(x, 0), Vector2(x, size.y), line, 3)
			draw_colored_polygon(PackedVector2Array([Vector2(x - 6, size.y * 0.5 - 4), Vector2(x + 6, size.y * 0.5 - 4), Vector2(x, size.y * 0.5 + 5)]), Color("8d897b"))
