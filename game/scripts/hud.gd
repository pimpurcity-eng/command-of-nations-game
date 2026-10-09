class_name StrategyHUD
extends CanvasLayer
## Portrait phone HUD in the Call of War layout:
##   top bar   - flag, resources, day/speed/play, city-capture score
##   right     - small square map buttons (zoom, cities, terrain view)
##   bottom    - tab bar (Diplomacy, Produce, Provinces, Market, Research, More); when one of
##               your armies is selected it is replaced by the army sheet with large
##               Stop / Split / Attack / Move buttons.
## Signals and the members used by main.gd are unchanged.
signal cancel_order_requested
signal delay_requested
signal forced_march_requested
signal upgrade_requested
signal rebase_requested
signal select_armies_requested
signal fire_control_requested
signal attack_requested
signal campaign_requested(page: String)
signal merge_requested
signal split_requested
signal stack_info_requested
signal add_destination_requested
signal declare_war_requested
signal new_match_requested
var city_scores: = {"russia": 0, "ukraine": 0}
signal army_roster_requested
signal research_requested
signal weapon_showcase_requested
signal exchange_requested
signal capital_requested
signal production_requested
signal pause_requested
signal speed_requested(speed: float)
signal save_requested
signal load_requested
signal stop_requested
signal move_requested
signal patrol_requested
signal unit_requested(index: int)
signal home_requested
signal zoom_requested(amount: float)
signal rotate_requested(amount: float)
signal city_requested(index: int)
signal terrain_mode_requested(enabled: bool)

const INK: = Color("f1ead5")
const MUTED: = Color("a9b1b4")
const GOLD: = Color("f2c94c")
const BAR: = Color(0.115, 0.13, 0.14, 0.94)

var detail: Label
var status: Label
var command_panel: PanelContainer
var top_bar: PanelContainer
var action_row: HBoxContainer
var nav_row: HBoxContainer
var toolbar: VBoxContainer
var mode_button: Button
var navigation_menu: MenuButton
var pause_button: Button
var speed_button: Button
var time_label: Label
var score_label: Label
var war_label: Label
var flag_badge: Glyph
var resource_values: Dictionary = {}
var unit_portrait: TextureRect
var health_bar: ProgressBar
var close_button: Button
var inspecting_unit: = false
var selected_unit: = -1
var move_button: Button
var stop_button: Button
var attack_button: Button
var split_button: Button
var patrol_button: Button
var armies_button: Button
var cancel_button: Button
var clock_paused: = true
var status_message: = "Select an army or city"
var choosing_destination: = false
var orders_menu: MenuButton
var own_unit: = false
var _speed: = 1.0

func _ready() -> void :
	var root: = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme: = StrategyTheme.create()
	root.theme = theme
	_build_top_bar(root)
	_build_toolbar(root)
	_build_bottom(root)
	get_viewport().size_changed.connect(_responsive_layout)
	_responsive_layout()

# ---------------------------------------------------------------- top bar
func _build_top_bar(root: Control) -> void:
	top_bar = PanelContainer.new()
	top_bar.add_theme_stylebox_override("panel", _skinned("header", Vector4(8, 6, 8, 6), 4))
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	root.add_child(top_bar)
	var column: = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	top_bar.add_child(column)
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	column.add_child(row)
	flag_badge = Glyph.new("flag", Color.WHITE, Vector2(40, 36))
	row.add_child(flag_badge)
	for resource in ProductionSystem.RESOURCES:
		var cell: = VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 0)
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(cell)
		var icon: = Glyph.new(resource, Color.WHITE, Vector2(26, 22))
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_child(icon)
		var value: = Label.new()
		value.text = "0"
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.add_theme_font_size_override("font_size", 16)
		value.add_theme_color_override("font_color", INK)
		value.tooltip_text = resource.capitalize()
		cell.add_child(value)
		resource_values[resource] = value
	var second: = HBoxContainer.new()
	second.add_theme_constant_override("separation", 6)
	column.add_child(second)
	time_label = _chip_label("D1 00:00")
	second.add_child(time_label)
	war_label = _chip_label("PEACE")
	second.add_child(war_label)
	var spacer: = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	second.add_child(spacer)
	score_label = _chip_label("★ 0/3")
	score_label.add_theme_color_override("font_color", GOLD)
	second.add_child(score_label)
	speed_button = _small_button("» 1x")
	speed_button.pressed.connect(func():
		_speed = {1.0: 2.0, 2.0: 4.0}.get(_speed, 1.0)
		speed_requested.emit(_speed))
	second.add_child(speed_button)
	pause_button = _small_button("Play")
	pause_button.custom_minimum_size.x = 76
	pause_button.pressed.connect(func(): pause_requested.emit())
	second.add_child(pause_button)

# ---------------------------------------------------------------- right column
func _build_toolbar(root: Control) -> void:
	toolbar = VBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 6)
	toolbar.anchor_left = 1
	toolbar.anchor_right = 1
	root.add_child(toolbar)
	for entry in [["zoom_in", -0.18], ["zoom_out", 0.18]]:
		var button: = _square(entry[0])
		button.pressed.connect(func(): zoom_requested.emit(entry[1]))
		toolbar.add_child(button)
	var city_menu: = MenuButton.new()
	_style_square(city_menu, "city")
	for entry in [["Kyiv · Capital", 0], ["Lviv", 1], ["Odesa", 2], ["Kharkiv", 3], ["Dnipro", 4], ["Moscow · Capital", 5], ["Kursk", 6], ["Belgorod", 7], ["Voronezh", 8], ["Rostov-on-Don", 9]]:
		city_menu.get_popup().add_item(entry[0], entry[1])
	city_menu.get_popup().id_pressed.connect(func(index: int): city_requested.emit(index))
	toolbar.add_child(city_menu)
	mode_button = _square("terrain")
	mode_button.toggle_mode = true
	mode_button.tooltip_text = "Terrain / borders view"
	mode_button.toggled.connect(func(enabled: bool): terrain_mode_requested.emit(enabled))
	toolbar.add_child(mode_button)
	var north: = _square("north")
	north.tooltip_text = "Reset view"
	north.pressed.connect(func(): home_requested.emit())
	toolbar.add_child(north)
	# The full command list lives in this menu (opened from the "More" tab).
	navigation_menu = MenuButton.new()
	navigation_menu.visible = false
	for title in ["Reset north", "Rotate left", "Rotate right", "Terrain / borders", "Speed 1x", "Speed 2x", "Speed 4x", "Save game", "Load game", "Equipment & production", "Army roster", "New match", "Add destination to selected army", "Merge nearby friendly armies", "Split selected units", "Army composition / battle info", "Declare war on Ukraine", "Technology / day unlocks", "Capital / construction", "Supply exchange", "All weapon models", "Select several armies", "Fire control", "Attack enemy army", "Victory progress", "Diplomacy", "Delay / synchronize arrival", "Forced march", "Upgrade selected army", "Rebase aircraft"]:
		navigation_menu.get_popup().add_item(title)
	navigation_menu.get_popup().id_pressed.connect(func(index: int):
		match index:
			0: home_requested.emit()
			1: rotate_requested.emit(-0.18)
			2: rotate_requested.emit(0.18)
			3: mode_button.button_pressed = not mode_button.button_pressed
			4: speed_requested.emit(1.0)
			5: speed_requested.emit(2.0)
			6: speed_requested.emit(4.0)
			7: save_requested.emit()
			8: load_requested.emit()
			9: production_requested.emit()
			10: army_roster_requested.emit()
			11: new_match_requested.emit()
			12: add_destination_requested.emit()
			13: merge_requested.emit()
			14: split_requested.emit()
			15: stack_info_requested.emit()
			16: declare_war_requested.emit()
			17: research_requested.emit()
			18: capital_requested.emit()
			19: exchange_requested.emit()
			20: weapon_showcase_requested.emit()
			21: select_armies_requested.emit()
			22: fire_control_requested.emit()
			23: attack_requested.emit()
			24: campaign_requested.emit("victory")
			25: campaign_requested.emit("diplomacy")
			26: delay_requested.emit()
			27: forced_march_requested.emit()
			28: upgrade_requested.emit()
			29: rebase_requested.emit()
	)
	root.add_child(navigation_menu)

# ---------------------------------------------------------------- bottom sheet
func _build_bottom(root: Control) -> void:
	command_panel = PanelContainer.new()
	command_panel.add_theme_stylebox_override("panel", _skinned("header", Vector4(8, 6, 8, 4), 4))
	command_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	command_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(command_panel)
	var column: = VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	command_panel.add_child(column)

	# Large order buttons (only for your own selected army).
	action_row = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 6)
	column.add_child(action_row)
	stop_button = _order_button("stop", "Stop", Color("3a3f42"))
	stop_button.pressed.connect(func(): stop_requested.emit())
	action_row.add_child(stop_button)
	split_button = _order_button("split", "Split", Color("3a3f42"))
	split_button.pressed.connect(func(): split_requested.emit())
	action_row.add_child(split_button)
	attack_button = _order_button("attack", "Attack", Color("b8413a"))
	attack_button.size_flags_stretch_ratio = 1.6
	attack_button.pressed.connect(func(): attack_requested.emit())
	action_row.add_child(attack_button)
	move_button = _order_button("move", "Move", Color("3f8a3a"))
	move_button.size_flags_stretch_ratio = 1.6
	move_button.disabled = true
	move_button.pressed.connect(func(): move_requested.emit())
	action_row.add_child(move_button)
	patrol_button = _order_button("patrol", "Patrol", Color("3a3f42"))
	patrol_button.pressed.connect(func(): patrol_requested.emit())
	patrol_button.visible = false
	action_row.add_child(patrol_button)
	armies_button = _order_button("add", "Armies", Color("3a3f42"))
	armies_button.pressed.connect(func(): select_armies_requested.emit())
	action_row.add_child(armies_button)
	cancel_button = _order_button("close", "Cancel", Color("6b2f2a"))
	cancel_button.visible = false
	cancel_button.pressed.connect(func(): cancel_order_requested.emit())
	action_row.add_child(cancel_button)
	orders_menu = MenuButton.new()
	_style_order(orders_menu, "more", "More", Color("3a3f42"))
	for title in ["Army details", "Attack enemy", "Fire control", "Add destination", "Merge nearby", "Split units", "Select armies", "Delay / sync arrival", "Forced march", "Upgrade army", "Rebase aircraft"]: orders_menu.get_popup().add_item(title)
	orders_menu.get_popup().id_pressed.connect(func(index: int):
		match index:
			0: stack_info_requested.emit()
			1: attack_requested.emit()
			2: fire_control_requested.emit()
			3: add_destination_requested.emit()
			4: merge_requested.emit()
			5: split_requested.emit()
			6: select_armies_requested.emit()
			7: delay_requested.emit()
			8: forced_march_requested.emit()
			9: upgrade_requested.emit()
			10: rebase_requested.emit()
	)
	action_row.add_child(orders_menu)

	# Selection card: thumbnail, name/status, close.
	var card: = HBoxContainer.new()
	card.add_theme_constant_override("separation", 8)
	column.add_child(card)
	unit_portrait = TextureRect.new()
	unit_portrait.custom_minimum_size = Vector2(64, 40)
	unit_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	unit_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	card.add_child(unit_portrait)
	detail = Label.new()
	detail.text = "REGIONAL COMMAND"
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_font_size_override("font_size", 14)
	detail.add_theme_color_override("font_color", INK)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.max_lines_visible = 2
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	card.add_child(detail)
	close_button = _square("close")
	close_button.pressed.connect(func():
		if choosing_destination: cancel_order_requested.emit()
		clear_unit_selection())
	card.add_child(close_button)
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size.y = 5
	health_bar.show_percentage = false
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_bar.add_theme_stylebox_override("fill", _flat(Color("5fb04a"), 2))
	health_bar.add_theme_stylebox_override("background", _flat(Color("2a3235"), 2))
	health_bar.visible = false
	column.add_child(health_bar)
	status = Label.new()
	status.text = "Select an army or a city."
	status.add_theme_font_size_override("font_size", 12)
	status.add_theme_color_override("font_color", MUTED)
	status.max_lines_visible = 2
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)

	# Tab bar.
	nav_row = HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", 0)
	column.add_child(nav_row)
	for entry in [["diplomacy", "Diplomacy"], ["produce", "Produce"], ["provinces", "Provinces"], ["market", "Market"], ["research", "Research"], ["more", "More"]]:
		var tab: = _tab(entry[0], entry[1])
		nav_row.add_child(tab)
		match entry[0]:
			"diplomacy": tab.pressed.connect(func(): campaign_requested.emit("diplomacy"))
			"produce": tab.pressed.connect(func(): production_requested.emit())
			"provinces": tab.pressed.connect(func(): capital_requested.emit())
			"market": tab.pressed.connect(func(): exchange_requested.emit())
			"research": tab.pressed.connect(func(): research_requested.emit())
			"more": tab.pressed.connect(func():
				var popup: = navigation_menu.get_popup()
				var size: = get_viewport().get_visible_rect().size
				popup.popup(Rect2i(Vector2i(int(size.x) - 300, int(size.y) - 520), Vector2i(290, 420))))
	_refresh_sheet()

# ---------------------------------------------------------------- widgets
func _flat(color: Color, radius: int = 6, margin: Vector4 = Vector4(6, 4, 6, 4), border: Color = Color.TRANSPARENT, left: int = 0, top: int = 0, bottom: int = 0) -> StyleBoxFlat:
	var style: = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin.x
	style.content_margin_top = margin.y
	style.content_margin_right = margin.z
	style.content_margin_bottom = margin.w
	style.border_color = border
	style.border_width_left = left
	style.border_width_top = top
	style.border_width_bottom = bottom
	return style
## Textured skin piece (CowUI) with HUD content margins.
func _skinned(name: String, margin: Vector4, corner: int = 10, tint: Color = Color.WHITE) -> StyleBoxTexture:
	var style: = CowUI.skin(name, corner, 0, tint)
	style.content_margin_left = margin.x
	style.content_margin_top = margin.y
	style.content_margin_right = margin.z
	style.content_margin_bottom = margin.w
	return style
func _chip_label(text: String) -> Label:
	var label: = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", INK)
	label.add_theme_stylebox_override("normal", _flat(Color(0, 0, 0, 0.35), 4, Vector4(8, 3, 8, 3)))
	return label
func _small_button(text: String) -> Button:
	var button: = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(58, 34)
	button.add_theme_font_size_override("font_size", 14)
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, _skinned("btn_dark", Vector4(8, 2, 8, 2), 10, Color(1.25, 1.25, 1.25) if state == "pressed" else Color.WHITE))
	button.add_theme_font_override("font", CowUI.title_font())
	return button
func _square(kind: String) -> Button:
	var button: = Button.new()
	_style_square(button, kind)
	return button
func _style_square(button: Button, kind: String) -> void:
	button.custom_minimum_size = Vector2(44, 44)
	button.flat = false
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, _skinned("frame", Vector4.ZERO, 10, Color(1.2, 1.15, 1.05) if state == "pressed" else Color.WHITE))
	var glyph: = Glyph.new(kind, GOLD, Vector2(44, 44), 0.62)
	glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(glyph)
func _order_button(kind: String, text: String, color: Color) -> Button:
	var button: = Button.new()
	_style_order(button, kind, text, color)
	return button
func _style_order(button: Button, kind: String, text: String, color: Color) -> void:
	button.text = text
	button.custom_minimum_size = Vector2(54, 64)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.add_theme_font_size_override("font_size", 13)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Glossy bevelled faces (tools/make_ui_skin.py): red Attack, green Move, metal otherwise.
	var face: = "btn_red" if color.r > color.g * 1.4 else ("btn_green" if color.g > color.r * 1.25 else "btn_dark")
	for state in ["normal", "hover", "pressed", "disabled"]:
		var texture: = "btn_grey" if state == "disabled" else face
		button.add_theme_stylebox_override(state, _skinned(texture, Vector4(4, 30, 4, 4), 12, Color(1.15, 1.15, 1.15) if state == "pressed" else Color.WHITE))
	button.add_theme_font_override("font", CowUI.title_font())
	button.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	button.add_theme_constant_override("shadow_offset_y", 1)
	var glyph: = Glyph.new(kind, Color.WHITE, Vector2(28, 28))
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.anchor_left = 0.5
	glyph.anchor_right = 0.5
	glyph.offset_left = -14
	glyph.offset_right = 14
	glyph.offset_top = 5
	glyph.offset_bottom = 33
	button.add_child(glyph)
func _tab(kind: String, text: String) -> Button:
	var button: = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 60)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", INK)
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, _flat(Color(0, 0, 0, 0) if state != "pressed" else Color(1, 1, 1, 0.08), 0, Vector4(0, 30, 0, 2)))
	var glyph: = Glyph.new(kind, GOLD, Vector2(28, 28))
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.anchor_left = 0.5
	glyph.anchor_right = 0.5
	glyph.offset_left = -14
	glyph.offset_right = 14
	glyph.offset_top = 3
	glyph.offset_bottom = 31
	button.add_child(glyph)
	return button

# ---------------------------------------------------------------- layout
func _responsive_layout() -> void :
	var size: = get_viewport().get_visible_rect().size
	top_bar.offset_bottom = top_bar.get_combined_minimum_size().y
	toolbar.offset_left = -52
	toolbar.offset_right = -8
	toolbar.offset_top = top_bar.get_combined_minimum_size().y + 10
	var compact: = size.x < 520
	for value in resource_values.values(): value.add_theme_font_size_override("font_size", 14 if compact else 16)
	for tab in nav_row.get_children(): tab.add_theme_font_size_override("font_size", 11 if compact else 12)
func _refresh_sheet() -> void:
	var commanding: = inspecting_unit and own_unit
	action_row.visible = commanding or choosing_destination
	nav_row.visible = not commanding and not choosing_destination
	close_button.visible = inspecting_unit or choosing_destination
	unit_portrait.visible = inspecting_unit

# ---------------------------------------------------------------- API used by main.gd
func show_territory(t: Dictionary) -> void :
	inspecting_unit = false
	health_bar.visible = false
	detail.text = t.title.to_upper() + "  /  " + ("YOURS" if t.controller == GameSession.player_country else t.controller.to_upper()) + " · " + str(t.get("terrain", "plains")).to_upper()
	_refresh_sheet()
func show_status(message: String) -> void :
	status_message = message
	status.text = ("PAUSED · Tap Play to run orders · " if clock_paused else "") + message
	status.add_theme_color_override("font_color", Color("ebd5aa") if clock_paused else MUTED)
func show_clock(elapsed: float, speed: float, paused: bool) -> void :
	var seconds: = int(elapsed * SimulationClock.REAL_SECONDS_PER_SIM_SECOND)
	time_label.text = "Day %d · %02d:%02d" % [1 + seconds / 86400, (seconds % 86400) / 3600, (seconds % 3600) / 60]
	_speed = speed
	speed_button.text = "» %dx" % int(speed)
	var mine: int = city_scores.get(GameSession.player_country, 0)
	score_label.text = "★ %d/3" % mine
	score_label.tooltip_text = "City captures · Russia %d/3 · Ukraine %d/3" % [city_scores.russia, city_scores.ukraine]
	var at_war: = navigation_menu.text.begins_with("War")
	war_label.text = "AT WAR" if at_war else "PEACE"
	war_label.add_theme_color_override("font_color", Color("ff8f80") if at_war else MUTED)
	flag_badge.country = GameSession.player_country
	flag_badge.queue_redraw()
	clock_paused = paused
	pause_button.text = "Play" if paused else "Pause"
	pause_button.add_theme_color_override("font_color", GOLD if paused else INK)
	show_status(status_message)
func show_army_roster(units: Array) -> void :
	var popup: = PopupMenu.new()
	add_child(popup)
	for i in units.size():
		if units[i].country != GameSession.player_country: continue
		popup.add_item(units[i].country.capitalize() + " · " + EquipmentIdentity.title(units[i].equipment_id) + " · " + units[i].name, i)
	popup.id_pressed.connect(func(index: int): unit_requested.emit(index))
	popup.popup_hide.connect(func(): popup.queue_free())
	var size: = get_viewport().get_visible_rect().size
	popup.popup_centered_clamped(Vector2i(mini(460, int(size.x) - 24), mini(400, int(size.y) - 24)))
func show_unit(unit: Dictionary) -> void :
	inspecting_unit = true
	own_unit = unit.country == GameSession.player_country
	show_health(unit.health)
	detail.text = EquipmentIdentity.title(unit.equipment_id).to_upper() + " / " + unit.country.to_upper() + " · " + str(int(unit.health)) + "%"
	unit_portrait.texture = UnitVisual.preview_texture(unit.equipment_id)
	move_button.disabled = not own_unit
	stop_button.disabled = not own_unit
	show_air_commands(unit.visual_kind == "fighter")
func show_air_commands(aircraft: bool) -> void :
	patrol_button.visible = aircraft and not choosing_destination
	armies_button.visible = not aircraft and not choosing_destination
	split_button.visible = not aircraft and not choosing_destination
	attack_button.visible = not choosing_destination
	stop_button.visible = not choosing_destination
	orders_menu.visible = not choosing_destination
	cancel_button.visible = choosing_destination
	move_button.text = "Fly" if aircraft else "Move"
	stop_button.text = "Return" if aircraft else "Stop"
	_refresh_sheet()
func set_order_mode(enabled: bool) -> void :
	choosing_destination = enabled
	cancel_button.visible = enabled
	show_air_commands(move_button.text == "Fly")
	move_button.modulate = Color("ffe0a0") if enabled else Color.WHITE
func show_health(value: float) -> void :
	health_bar.visible = inspecting_unit
	health_bar.value = value
	health_bar.tooltip_text = "Army health: %d%%" % roundi(value)
func clear_unit_selection() -> void :
	health_bar.visible = false
	inspecting_unit = false
	own_unit = false
	move_button.disabled = true
	stop_button.disabled = true
	detail.text = "REGIONAL COMMAND"
	_refresh_sheet()
func show_resources(_country: String, stockpile: Dictionary) -> void :
	for resource in ProductionSystem.RESOURCES:
		var amount: = int(stockpile[resource])
		resource_values[resource].text = ("%.1fk" % (amount / 1000.0)) if amount >= 10000 else str(amount)


## Small vector icons (no external icon art needed).
class Glyph extends Control:
	var kind: String
	var tint: Color
	var country: = ""
	var scale_factor: = 1.0
	func _init(glyph_kind: String, color: Color, minimum: Vector2, glyph_scale: float = 1.0) -> void:
		kind = glyph_kind
		tint = color
		scale_factor = glyph_scale
		custom_minimum_size = minimum
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var s: = minf(size.x, size.y)
		var c: = size * 0.5
		var u: = s / 24.0 * scale_factor
		var line: = maxf(2.0, 2.2 * u)
		match kind:
			"flag":
				var rect: = Rect2(c - Vector2(size.x * 0.46, size.y * 0.32), Vector2(size.x * 0.92, size.y * 0.64))
				var colors: Array = [Color("1f5fbf"), Color("f6c700")] if country == "ukraine" else [Color.WHITE, Color("1f4fb3"), Color("d0312d")]
				for i in colors.size():
					var band: = Rect2(rect.position + Vector2(0, rect.size.y * i / colors.size()), Vector2(rect.size.x, rect.size.y / colors.size()))
					draw_rect(band, colors[i])
				draw_rect(rect, Color(0, 0, 0, 0.6), false, 1.5)
			"funds", "materials", "electronics", "fuel", "manpower":
				# Shaded resource icons (tools/make_ui_skin.py), as in the menus.
				var side: = minf(size.x, size.y) * 1.25
				draw_texture_rect(ResourceSites.icon(kind), Rect2(c - Vector2(side, side) * 0.5, Vector2(side, side)), false)
			"funds_vector":
				draw_rect(Rect2(c - Vector2(11, 6) * u, Vector2(22, 12) * u), Color("4f9a45"))
				draw_rect(Rect2(c - Vector2(11, 6) * u, Vector2(22, 12) * u), Color("2d5f28"), false, 1.5)
				draw_circle(c, 3.2 * u, Color("9fd18f"))
			"materials_vector":
				draw_rect(Rect2(c - Vector2(10, 9) * u, Vector2(20, 18) * u), Color("9a6b3c"))
				draw_line(c + Vector2(-10, -9) * u, c + Vector2(10, 9) * u, Color("5e3d1d"), 1.6 * u)
				draw_line(c + Vector2(10, -9) * u, c + Vector2(-10, 9) * u, Color("5e3d1d"), 1.6 * u)
				draw_rect(Rect2(c - Vector2(10, 9) * u, Vector2(20, 18) * u), Color("5e3d1d"), false, 1.5)
			"electronics_vector":
				draw_rect(Rect2(c - Vector2(7, 7) * u, Vector2(14, 14) * u), Color("3d6b7a"))
				for i in 3:
					var o: = (-4 + i * 4) * u
					draw_line(c + Vector2(o, -7 * u), c + Vector2(o, -10 * u), Color("9fc4cf"), 1.5 * u)
					draw_line(c + Vector2(o, 7 * u), c + Vector2(o, 10 * u), Color("9fc4cf"), 1.5 * u)
					draw_line(c + Vector2(-7 * u, o), c + Vector2(-10 * u, o), Color("9fc4cf"), 1.5 * u)
					draw_line(c + Vector2(7 * u, o), c + Vector2(10 * u, o), Color("9fc4cf"), 1.5 * u)
			"fuel_vector":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-7, -6) * u, c + Vector2(-2, -10) * u, c + Vector2(7, -10) * u, c + Vector2(7, 10) * u, c + Vector2(-7, 10) * u]), Color("c8352e"))
				draw_line(c + Vector2(-4, -2) * u, c + Vector2(4, 7) * u, Color("ffb3a8"), 1.5 * u)
				draw_line(c + Vector2(4, -2) * u, c + Vector2(-4, 7) * u, Color("ffb3a8"), 1.5 * u)
			"manpower_vector":
				draw_arc(c + Vector2(0, 3) * u, 9 * u, PI, TAU, 16, Color("7a8a4e"), 7 * u)
				draw_line(c + Vector2(-12, 4) * u, c + Vector2(12, 4) * u, Color("55623a"), 2.5 * u)
			"zoom_in", "zoom_out":
				draw_line(c - Vector2(9, 0) * u, c + Vector2(9, 0) * u, tint, line)
				if kind == "zoom_in": draw_line(c - Vector2(0, 9) * u, c + Vector2(0, 9) * u, tint, line)
			"city":
				for b in [[-9, 2, 6, 9], [-2, -6, 6, 17], [5, -1, 5, 12]]:
					draw_rect(Rect2(c + Vector2(b[0], b[1]) * u, Vector2(b[2], b[3]) * u), tint)
			"terrain":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-11, 8) * u, c + Vector2(-3, -7) * u, c + Vector2(2, 1) * u, c + Vector2(5, -3) * u, c + Vector2(11, 8) * u]), tint)
			"north":
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -11) * u, c + Vector2(7, 9) * u, c + Vector2(0, 5) * u, c + Vector2(-7, 9) * u]), tint)
			"close":
				draw_line(c - Vector2(7, 7) * u, c + Vector2(7, 7) * u, tint, line)
				draw_line(c + Vector2(-7, 7) * u, c + Vector2(7, -7) * u, tint, line)
			"stop":
				draw_rect(Rect2(c - Vector2(8, 8) * u, Vector2(16, 16) * u), Color(0.82, 0.84, 0.85))
			"split":
				draw_line(c + Vector2(-9, 0) * u, c + Vector2(0, 0) * u, tint, line)
				draw_line(c, c + Vector2(9, -8) * u, tint, line)
				draw_line(c, c + Vector2(9, 8) * u, tint, line)
			"attack":
				draw_colored_polygon(PackedVector2Array([c + Vector2(3, -12) * u, c + Vector2(-7, 2) * u, c + Vector2(-1, 2) * u, c + Vector2(-4, 12) * u, c + Vector2(7, -3) * u, c + Vector2(1, -3) * u]), Color("ffd84a"))
			"move":
				draw_arc(c + Vector2(-2, 9) * u, 12 * u, -PI * 0.5, -PI * 0.08, 12, Color("ffd84a"), line * 1.3)
				draw_colored_polygon(PackedVector2Array([c + Vector2(7, -3) * u, c + Vector2(13, 7) * u, c + Vector2(4, 7) * u]), Color("ffd84a"))
			"patrol":
				draw_arc(c, 9 * u, 0, TAU * 0.8, 20, tint, line)
			"add":
				draw_line(c - Vector2(8, 0) * u, c + Vector2(8, 0) * u, GOLD, line)
				draw_line(c - Vector2(0, 8) * u, c + Vector2(0, 8) * u, GOLD, line)
			"more":
				for i in 3: draw_line(c + Vector2(-9, -6 + i * 6) * u, c + Vector2(9, -6 + i * 6) * u, tint, line)
			"diplomacy":
				for x in [-6, 6]:
					draw_circle(c + Vector2(x, -4) * u, 3.5 * u, tint)
					draw_arc(c + Vector2(x, 9) * u, 6 * u, PI, TAU, 10, tint, 3 * u)
				draw_circle(c + Vector2(0, -6) * u, 4 * u, tint)
				draw_arc(c + Vector2(0, 8) * u, 7 * u, PI, TAU, 10, tint, 3.5 * u)
			"produce":
				draw_rect(Rect2(c + Vector2(-11, 1) * u, Vector2(22, 7) * u), tint)
				draw_rect(Rect2(c + Vector2(-5, -5) * u, Vector2(10, 6) * u), tint)
				draw_line(c + Vector2(5, -2) * u, c + Vector2(13, -4) * u, tint, 2 * u)
			"provinces":
				for i in 3:
					draw_rect(Rect2(c + Vector2(-10, -9 + i * 7) * u, Vector2(4, 4) * u), tint)
					draw_line(c + Vector2(-3, -7 + i * 7) * u, c + Vector2(10, -7 + i * 7) * u, tint, 2.5 * u)
			"market":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-11, -3) * u, c + Vector2(11, -3) * u, c + Vector2(8, 9) * u, c + Vector2(-8, 9) * u]), tint)
				draw_arc(c + Vector2(0, -3) * u, 6 * u, PI, TAU, 10, tint, 2 * u)
			"research":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-3, -11) * u, c + Vector2(3, -11) * u, c + Vector2(3, -3) * u, c + Vector2(10, 10) * u, c + Vector2(-10, 10) * u, c + Vector2(-3, -3) * u]), tint)
