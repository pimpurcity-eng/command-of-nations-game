class_name ArmyDetailsPanel
extends CanvasLayer
## Army Details in the Call of War style (owner 2026-10-13, reference screenshots): header card
## with the lead unit, strength / speed / total hit points, army status, combat statistics
## (attack and defence against every unit type), the full unit list with the strongest unit on
## top, terrain influences and class distribution. Works for enemy armies too (inspection).
## Combat statistics against the six unit types (owner 2026-10-13); aircraft are listed below.
const TARGETS: = [["infantry", "Infantry"], ["light", "Light armour"], ["heavy", "Heavy armour"], ["air", "Planes"], ["naval", "Ships"], ["submarine", "Submarines"]]
const CLASS_NAMES: = {"infantry": "Infantry", "ifv": "Light armour", "armor": "Heavy armour", "artillery": "Artillery", "missile_launcher": "Missiles",
	"air_defense": "Air defence", "support": "Support", "fighter": "Aircraft", "naval": "Ships"}
## Tapping a unit picture opens that unit's research card (owner 2026-10-14).
signal unit_info_requested(equipment_id: String, level: int)
var panel: PanelContainer
var content: VBoxContainer
var title: Label

func setup(theme: Theme) -> void :
	layer = 13
	var root: = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = theme
	add_child(root)
	var dim: = ColorRect.new()
	dim.color = Color(0.01, 0.025, 0.04, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent): if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed: hide())
	root.add_child(dim)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", CowUI.skin("panel_dark", 8))
	root.add_child(panel)
	var column: = VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	panel.add_child(column)
	var head: = CowUI.header("Army Details", false)
	title = head.title
	head.close.pressed.connect(hide)
	column.add_child(head.bar)
	var scroll: = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 0)
	scroll.add_child(content)
	get_viewport().size_changed.connect(_layout)
	hide()

func _layout() -> void :
	var size: = get_viewport().get_visible_rect().size
	var width: = minf(760.0, size.x)
	var top: = roundf(size.y * 0.04)
	panel.position = Vector2((size.x - width) * 0.5, top)
	panel.scale = Vector2.ONE * CowUI.MENU_ZOOM
	panel.size = Vector2(width, size.y - top * 2) / CowUI.MENU_ZOOM

# ---------------------------------------------------------------- building blocks

func _section(text: String) -> VBoxContainer:
	var bar: = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", CowUI.box(Color("777569"), 0, Color("1a1d20"), 1, 14))
	content.add_child(bar)
	var row: = HBoxContainer.new()
	bar.add_child(row)
	var label: = CowUI.label(text.to_upper(), 22, Color("efe6cf"))
	label.add_theme_font_override("font", CowUI.title_font())
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var arrow: = CowUI.label("▲", 20, CowUI.GOLD)
	row.add_child(arrow)
	var body: = VBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	content.add_child(body)
	bar.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			body.visible = not body.visible
			arrow.text = "▲" if body.visible else "▼")
	return body

func _row(body: VBoxContainer, cells: Array, header: bool = false, icon_kind: String = "") -> HBoxContainer:
	var back: = PanelContainer.new()
	back.add_theme_stylebox_override("panel", CowUI.box(Color("b8b5a7") if header else CowUI.LIST, 0, Color("14171a"), 1, 10))
	body.add_child(back)
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	back.add_child(row)
	if not icon_kind.is_empty():
		var tag: = PanelContainer.new()
		tag.add_theme_stylebox_override("panel", CowUI.box(Color("7a2a24"), 4, Color(0, 0, 0, 0), 0, 3))
		tag.add_child(UnitTypeIcon.silhouette(icon_kind, Color("f2e6d0"), Vector2(30, 24)))
		row.add_child(tag)
	for i in cells.size():
		var label: = CowUI.label(str(cells[i]), 17 if not header else 15, CowUI.INK)
		if i == 0:
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.clip_text = true
			label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		else:
			label.custom_minimum_size.x = 78 if cells.size() > 3 else 110
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			if not header: label.add_theme_font_override("font", CowUI.title_font())
		row.add_child(label)
	return row

## Owner 2026-10-16 ("you can heal armies with gold", Call of War): a damaged army of yours shows
## a gold button that heals every unit to full (GoldWallet.heal_price).
var heal_button: Button
var heal_note: Label
func _heal_row(body: VBoxContainer, armies: UnitSystem, terrain: StrategicMap, lead: Dictionary, group: Array) -> void:
	var economy: ProductionSystem = armies.air.economy
	var price: = GoldWallet.heal_price(economy, group)
	if price <= 0 or armies.air.is_air(lead) and lead.get("flight_mode", "grounded") != "grounded": return
	var back: = PanelContainer.new()
	back.add_theme_stylebox_override("panel", CowUI.box(CowUI.LIST, 0, Color("14171a"), 1, 10))
	body.add_child(back)
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	back.add_child(row)
	var words: = VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	words.add_child(CowUI.label("Heal army to full health", 17, CowUI.INK))
	heal_note = CowUI.label("Price follows each unit's value and the health it has lost", 13, Color("3c3a33"))
	heal_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(heal_note)
	heal_button = CowUI.gold_finish_button()
	heal_button.tooltip_text = "Heal with gold"
	var caption: = heal_button.get_child(0).get_child(0) as Label
	if caption != null: caption.text = "HEAL"
	row.add_child(heal_button)
	var lead_id: String = lead.id
	CowUI.gold_button(heal_button, price, func():
		var error: = GoldWallet.heal_army(economy, armies, GameSession.player_country, lead_id, price)
		if not error.is_empty():
			heal_note.text = error
			return
		if MatchClient.active != null:
			heal_note.text = "Healing ordered"
			heal_button.disabled = true
			return
		open(armies, terrain))

## Fire control buttons for one army (owner 2026-10-16, Call of War stances).
func _fire_control(body: VBoxContainer, armies: UnitSystem, terrain: StrategicMap, lead: Dictionary) -> void:
	var current: = str(lead.get("fire_mode", "at_will"))
	var mode_row: = _row(body, ["Fire control", FireControlPanel.MODES.get(current, FireControlPanel.MODES.at_will).title])
	mode_row.tooltip_text = FireControlPanel.MODES.get(current, FireControlPanel.MODES.at_will).description
	var buttons: = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	body.add_child(buttons)
	for mode in FireControlPanel.MODES:
		var button: = Button.new()
		button.text = FireControlPanel.MODES[mode].title
		button.tooltip_text = FireControlPanel.MODES[mode].description
		button.toggle_mode = true
		button.button_pressed = mode == current
		button.custom_minimum_size.y = 48
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		button.name = "Fire_" + mode
		buttons.add_child(button)
		button.pressed.connect(func():
			armies.set_fire_mode(mode, [lead])
			open(armies, terrain))

static func strength(unit: Dictionary) -> float:
	# Potential already includes condition, doctrine and terrain: never multiply health twice.
	var combat: = CombatSystem.new()
	var best: = 0.0
	for target in UnitClasses.ALL: best = maxf(best, combat.potential([unit], target, false, true))
	return best

# ---------------------------------------------------------------- open

func _link_picture(picture: TextureRect, unit: Dictionary) -> void:
	var id: String = unit.equipment_id
	var level: = int(unit.get("level", 1))
	picture.mouse_filter = Control.MOUSE_FILTER_STOP
	picture.tooltip_text = "Unit card"
	picture.gui_input.connect(func(event: InputEvent):
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
			unit_info_requested.emit(id, level))
func open(armies: UnitSystem, terrain: StrategicMap) -> void :
	for child in content.get_children(): content.remove_child(child); child.queue_free()
	var lead: Dictionary = armies.units[armies.selected]
	var group: Array = armies.stacks.members(lead).duplicate()
	# Strongest unit on top (owner).
	group.sort_custom(func(a, b): return strength(a) > strength(b))
	# The same top unit as the map badge and the unit card, so all show the same picture.
	var top: Dictionary = armies.stacks.leader(group)
	group.erase(top)
	group.push_front(top)
	var own: bool = lead.country == GameSession.player_country
	title.text = "Army Details" if own else "Enemy Army"
	# Header card: picture, flag, name, country, terrain.
	var hero: = Control.new()
	hero.custom_minimum_size.y = 380
	content.add_child(hero)
	var picture: = TextureRect.new()
	picture.texture = CowUI.research_picture(top.equipment_id, top.get("level", 1))
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_link_picture(picture, top)
	hero.add_child(picture)
	var level_badge := CityPanel.Chevrons.new()
	level_badge.level = int(top.get("level", 1))
	level_badge.anchor_left = 1.0
	level_badge.anchor_right = 1.0
	level_badge.offset_left = -64
	level_badge.offset_right = -12
	level_badge.offset_top = 12
	level_badge.offset_bottom = 72
	hero.add_child(level_badge)
	var band: = PanelContainer.new()
	band.add_theme_stylebox_override("panel", CowUI.box(Color(0, 0, 0, 0.72), 0, Color(0, 0, 0, 0), 0, 10))
	band.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	band.offset_top = -86
	hero.add_child(band)
	var band_row: = HBoxContainer.new()
	band_row.add_theme_constant_override("separation", 14)
	band.add_child(band_row)
	var flag: = TextureRect.new()
	flag.texture = CowUI.icon_texture("flag_" + lead.country)
	flag.custom_minimum_size = Vector2(80, 56)
	flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	band_row.add_child(flag)
	var names: = VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	band_row.add_child(names)
	var army_name: = CowUI.label(EquipmentIdentity.research_title(top.equipment_id, top.get("level", 1)) + (" group" if group.size() > 1 else ""), 22, Color("f4ecd8"))
	army_name.clip_text = true
	names.add_child(army_name)
	names.add_child(CowUI.label(lead.country.capitalize() + ("" if own else "  ·  enemy"), 16, Color("c9c3ae")))
	var point: = Vector2(lead.node.position.x, lead.node.position.z)
	var biome: String = terrain.terrain_at(point)
	band_row.add_child(CowUI.label(biome.capitalize(), 16, Color("c9c3ae")))
	# Strength / speed / hit points.
	var total_strength: = 0.0
	var hp: = UnitStats.group_hp(group)
	for member in group: total_strength += strength(member)
	var stats: = _section("Army")
	_row(stats, ["Strength", "%.1f" % total_strength])
	# Owner 2026-10-16: speed in game km/h with what changes it here (terrain, own land, roads, rail).
	_row(stats, ["Speed", "%d km/h" % roundi(ArmyStacks.km_per_hour(armies.stacks.movement_speed(group, point)))])
	var factors: Array = armies.stacks.speed_factors(group, point).filter(func(f: Array): return not is_equal_approx(float(f[1]), 1.0))
	if not factors.is_empty(): _row(stats, ["", ", ".join(factors.map(func(f: Array): return "%s ×%.2f" % [str(f[0]).capitalize(), float(f[1])]))])
	_row(stats, ["Hit points", "%s / %d" % [UnitStats.number(hp.x), roundi(hp.y)]])
	var bar: = ProgressBar.new()
	bar.custom_minimum_size.y = 22
	bar.show_percentage = false
	bar.max_value = hp.y
	bar.value = hp.x
	bar.add_theme_stylebox_override("background", CowUI.box(Color("15181b"), 2))
	bar.add_theme_stylebox_override("fill", CowUI.box(Color("5aa83a"), 2))
	stats.add_child(bar)
	if own: _heal_row(stats, armies, terrain, lead, group)
	# Army status.
	var status: = _section("Army status")
	_row(status, ["Army size", str(group.size())])
	_row(status, ["State", CombatSystem.battle_label(lead, armies._land_owner(lead)).capitalize() if lead.get("engaged", false) else ("Moving" if lead.get("moving", false) else "Ready")])
	if own and not armies.air.is_air(lead): _fire_control(status, armies, terrain, lead)
	# The same HP damage used by land, air and naval combat, including both doctrine and terrain.
	var combat: = CombatSystem.new()
	var table: = _section("Combat statistics")
	_row(table, ["Damage against type", "Attack", "Defence"], true)
	for target in TARGETS:
		_row(table, ["vs. " + target[1], "%.1f" % combat.potential(group, target[0]), "%.1f" % combat.potential(group, target[0], false, true)], false, target[0])
	# Units, strongest first.
	var list: = _section("Units")
	_row(list, ["Unit", "HP", "Strength"], true)
	for member in group:
		var back: = PanelContainer.new()
		back.add_theme_stylebox_override("panel", CowUI.box(Color("1d2127"), 0, Color("14171a"), 1, 10))
		list.add_child(back)
		var row: = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		back.add_child(row)
		var frame: = PanelContainer.new()
		frame.add_theme_stylebox_override("panel", CowUI.box(Color("2a2e33"), 2, Color("e9d9a0"), 2, 2))
		row.add_child(frame)
		var stack: = Control.new()
		stack.custom_minimum_size = Vector2(140, 104)
		frame.add_child(stack)
		var pic: = TextureRect.new()
		pic.texture = CowUI.research_picture(member.equipment_id, member.get("level", 1))
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pic.offset_bottom = -18
		_link_picture(pic, member)
		stack.add_child(pic)
		var rank: = CityPanel.Chevrons.new()
		rank.level = int(member.get("level", 1))
		rank.anchor_left = 1.0; rank.anchor_right = 1.0
		rank.offset_left = -28; rank.offset_right = -2; rank.offset_top = 2; rank.offset_bottom = 32
		stack.add_child(rank)
		var health: = ProgressBar.new()
		health.show_percentage = false
		health.value = member.health
		health.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		health.offset_top = -16
		health.add_theme_stylebox_override("background", CowUI.box(Color("15181b"), 0))
		health.add_theme_stylebox_override("fill", CowUI.box(Color("5aa83a") if member.health >= 60 else (Color("d8b14a") if member.health >= 30 else Color("c8433a")), 0))
		stack.add_child(health)
		var name_box: = VBoxContainer.new()
		name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_box)
		var unit_name: = CowUI.label(EquipmentIdentity.research_title(member.equipment_id, member.get("level", 1)), 17, Color("efe6cf"))
		unit_name.clip_text = true
		unit_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_box.add_child(unit_name)
		name_box.add_child(CowUI.label("Level " + EquipmentIdentity.roman_level(int(member.get("level", 1))) + " · " + str(EquipmentIdentity.spec(member.equipment_id).get("research_branch", "")), 14, Color("bfb8a6")))
		for value in [UnitStats.hp_label(member), "%.1f" % strength(member)]:
			var cell: = CowUI.label(value, 17, Color("efe6cf"))
			cell.custom_minimum_size.x = 110
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_theme_font_override("font", CowUI.title_font())
			row.add_child(cell)
	# Attack and defence terrain effects are different and must be shown separately.
	var terrain_body: = _section("Terrain influences")
	_row(terrain_body, ["Terrain: " + biome.capitalize(), "Speed", "Attack", "Defence"], true)
	var seen: = {}
	for member in group:
		var role: = UnitStats.profile_id(member)
		if armies.air.is_air(member) or armies.is_naval(member) or seen.has(role): continue
		seen[role] = true
		var values: Array = [str(UnitStats.profile(member).name)]
		for effect in ["speed", "attack", "defense"]:
			var percent: = roundi((TerrainRules.for_unit(member, biome, effect) - 1.0) * 100)
			values.append(("%+d%%" % percent) if percent != 0 else "—")
		_row(terrain_body, values, false, member.visual_kind)
	# Class distribution.
	var classes: = {}
	for member in group:
		var unit_class: = UnitClasses.of(member)
		classes[unit_class] = classes.get(unit_class, 0) + 1
	var dist: = _section("Class distribution")
	_row(dist, ["Unit class", "Share"], true)
	for kind in classes:
		_row(dist, [UnitClasses.NAMES.get(kind, str(kind).capitalize()), "%d%%" % roundi(100.0 * classes[kind] / group.size())], false, kind)
	_layout()
	show()
