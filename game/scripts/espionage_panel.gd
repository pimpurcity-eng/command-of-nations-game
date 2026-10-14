class_name EspionagePanel
extends CanvasLayer
## Espionage screen (owner 2026-10-14): choose a mission and a city, send a spy, see your spies
## and recall them.
var match_rules: MatchSystem
var economy: ProductionSystem
var panel: PanelContainer
var summary: Label
var mission_text: Label
var city_picker: OptionButton
var send_button: Button
var message: Label
var list: VBoxContainer
var mission_buttons: Dictionary = {}
var hack_buttons: Dictionary = {}
var hack_city_picker: OptionButton
var hack_city_ids: Array = []
var gold_label: Label
var hack_list: Label
var mission: = "intel"
var city_ids: Array = []
var _tick: = 0.0

func setup(rules: MatchSystem, system: ProductionSystem, theme: Theme) -> void:
	match_rules = rules
	economy = system
	layer = 13
	var root: = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = theme
	add_child(root)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", CowUI.skin("panel_dark", 8))
	root.add_child(panel)
	var column: = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var head: = CowUI.header("Espionage", false)
	head.close.pressed.connect(hide)
	column.add_child(head.bar)
	var scroll: = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var body: = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)
	summary = CowUI.label("", 20, CowUI.GOLD)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(summary)
	body.add_child(_heading("1 · Choose a mission"))
	var grid: = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	body.add_child(grid)
	for id in Espionage.MISSIONS:
		var button: = CowUI.action(Espionage.MISSIONS[id].name.to_upper(), Espionage.MISSIONS[id].icon, Color("3a4a55"))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 64
		var chosen: String = id
		button.pressed.connect(func(): mission = chosen; _fill_cities(); refresh())
		grid.add_child(button)
		mission_buttons[id] = button
	mission_text = CowUI.label("", 19)
	mission_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(mission_text)
	body.add_child(_heading("2 · Choose a city"))
	city_picker = OptionButton.new()
	city_picker.custom_minimum_size.y = 60
	city_picker.add_theme_font_size_override("font_size", 22)
	body.add_child(city_picker)
	send_button = CowUI.action("SEND SPY", "", CowUI.GREEN)
	send_button.custom_minimum_size.y = 68
	send_button.pressed.connect(_send)
	body.add_child(send_button)
	message = CowUI.label("", 19, CowUI.GOLD)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(message)
	body.add_child(_heading("Your spies"))
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	body.add_child(list)
	# Hackers (owner 2026-10-14): paid with gold.
	body.add_child(_heading("Hackers · paid with gold"))
	gold_label = CowUI.label("", 20, CowUI.GOLD)
	body.add_child(gold_label)
	body.add_child(CowUI.label("Blackout target:", 19))
	hack_city_picker = OptionButton.new()
	hack_city_picker.custom_minimum_size.y = 56
	hack_city_picker.add_theme_font_size_override("font_size", 21)
	body.add_child(hack_city_picker)
	for kind in Espionage.HACKS:
		var card: = PanelContainer.new()
		card.add_theme_stylebox_override("panel", CowUI.skin("row", 8, 10))
		body.add_child(card)
		var row: = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)
		var info: = CowUI.label(Espionage.HACKS[kind].name + "\n" + Espionage.HACKS[kind].text, 18, CowUI.INK)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var start: = CowUI.action("%d GOLD" % int(Espionage.HACKS[kind].gold), "", CowUI.GREEN)
		start.custom_minimum_size.x = 170
		var chosen: String = kind
		start.pressed.connect(func(): _hack(chosen))
		row.add_child(start)
		hack_buttons[kind] = start
	hack_list = CowUI.label("", 19)
	hack_list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(hack_list)
	get_viewport().size_changed.connect(_layout)
	_layout()
	hide()

func _heading(text: String) -> Label:
	var heading: = CowUI.label(text, 22, CowUI.GOLD)
	return heading

func _layout() -> void:
	var size: = get_viewport().get_visible_rect().size
	var width: = minf(760, size.x)
	panel.position = Vector2((size.x - width) / 2, roundf(size.y * 0.06))
	panel.scale = Vector2.ONE * CowUI.MENU_ZOOM
	panel.size = Vector2(width, size.y - panel.position.y) / CowUI.MENU_ZOOM

## Opens the screen, optionally with a city already chosen.
func open(city_id: String = "") -> void:
	message.text = ""
	show()
	_layout()
	if not city_id.is_empty():
		var city: Dictionary = economy.buildings.city(city_id)
		mission = "intel" if economy.controller(city) != GameSession.player_country else "counter"
	_fill_cities(city_id)
	_fill_hack_cities()
	refresh()

func _fill_cities(preferred: String = "") -> void:
	var previous: String = preferred if not preferred.is_empty() else (city_ids[city_picker.selected] if city_picker.selected >= 0 and city_picker.selected < city_ids.size() else "")
	city_picker.clear()
	city_ids.clear()
	var player: = GameSession.player_country
	var enemy: bool = Espionage.MISSIONS[mission].enemy
	var cities: Array = economy.cities.filter(func(city: Dictionary): return (economy.controller(city) != player) == enemy and not economy.controller(city).is_empty())
	var home: Dictionary = economy.buildings.capital(player)
	if not home.is_empty(): cities.sort_custom(func(a: Dictionary, b: Dictionary): return a.point.distance_to(home.point) < b.point.distance_to(home.point))
	for city in cities:
		city_picker.add_item(city.name + ("" if not enemy else "  ·  " + economy.controller(city).capitalize()))
		city_ids.append(city.id)
	var index: = city_ids.find(previous)
	if index >= 0: city_picker.select(index)

func _fill_hack_cities() -> void:
	var previous: String = hack_city_ids[hack_city_picker.selected] if hack_city_picker.selected >= 0 and hack_city_picker.selected < hack_city_ids.size() else ""
	hack_city_picker.clear()
	hack_city_ids.clear()
	var player: = GameSession.player_country
	var cities: Array = economy.cities.filter(func(city: Dictionary): return economy.controller(city) != player and not economy.controller(city).is_empty())
	var home: Dictionary = economy.buildings.capital(player)
	if not home.is_empty(): cities.sort_custom(func(a: Dictionary, b: Dictionary): return a.point.distance_to(home.point) < b.point.distance_to(home.point))
	for city in cities:
		hack_city_picker.add_item(city.name)
		hack_city_ids.append(city.id)
	var index: = hack_city_ids.find(previous)
	if index >= 0: hack_city_picker.select(index)

func _hack(kind: String) -> void:
	var player: = GameSession.player_country
	var city: Dictionary = {}
	if Espionage.HACKS[kind].target == "city" and hack_city_picker.selected >= 0 and hack_city_picker.selected < hack_city_ids.size():
		city = economy.buildings.city(hack_city_ids[hack_city_picker.selected])
	var enemy: = GameSession.opponent_country()
	var result: = match_rules.espionage.hack(player, kind, city, economy.controller(city) if not city.is_empty() else "", enemy, int(economy.gold.get(player, 0)), economy.spend_gold, match_rules.spy_world())
	message.text = (Espionage.HACKS[kind].name + " started" + (" in " + city.name if not city.is_empty() else "")) if result.is_empty() else result
	if result.is_empty() or result.begins_with("BLOCKED"): economy.changed.emit()
	refresh()

func _send() -> void:
	if city_picker.selected < 0 or city_picker.selected >= city_ids.size():
		message.text = "Choose a city"
		return
	var city: Dictionary = economy.buildings.city(city_ids[city_picker.selected])
	var player: = GameSession.player_country
	if not economy.stockpiles.has(player): economy.stockpiles[player] = {}
	var error: = match_rules.espionage.send(player, city, mission, economy.controller(city), economy.stockpiles[player])
	if error.is_empty():
		message.text = "Spy sent to %s · arrives in %s" % [city.name, SimulationClock.duration(Espionage.TRAVEL)]
		economy.changed.emit()
	else:
		message.text = error
	refresh()

func refresh() -> void:
	var player: = GameSession.player_country
	var mine: Array = match_rules.espionage.owned(player)
	summary.text = "Spies %d / %d  ·  each spy costs %s money and %d manpower\nSpies do their work at the end of each day" % [mine.size(), Espionage.MAX_SPIES, StrategyHUD._thousands(int(Espionage.COST.funds)), int(Espionage.COST.manpower)]
	for id in mission_buttons:
		mission_buttons[id].modulate = Color.WHITE if id == mission else Color(1, 1, 1, 0.55)
	mission_text.text = Espionage.MISSIONS[mission].name + ": " + Espionage.MISSIONS[mission].text
	gold_label.text = "Your gold: " + StrategyHUD._thousands(int(economy.gold.get(player, 0)))
	var running: Array = []
	for active in match_rules.espionage.hacks:
		if active.country == player:
			var where: String = economy.buildings.city(active.city).get("name", "") if not str(active.city).is_empty() else ""
			running.append("%s%s · %s left" % [Espionage.HACKS[active.kind].name, " (" + where + ")" if not where.is_empty() else "", SimulationClock.duration(active.remaining)])
	hack_list.text = "Running: " + ", ".join(running) if not running.is_empty() else ""
	for child in list.get_children(): list.remove_child(child); child.queue_free()
	if mine.is_empty():
		var none: = CowUI.label("No spies yet.", 19)
		list.add_child(none)
	for spy in mine:
		var card: = PanelContainer.new()
		card.add_theme_stylebox_override("panel", CowUI.skin("row", 8, 10))
		list.add_child(card)
		var row: = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)
		var city: Dictionary = economy.buildings.city(spy.city)
		var state: String = ("on the way · " + SimulationClock.duration(spy.travel)) if spy.travel > 0.0 else "at work"
		var text: = CowUI.label("%s\n%s · %s" % [Espionage.MISSIONS[spy.mission].name, city.get("name", spy.city), state], 20, CowUI.INK)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		var recall: = CowUI.action("RECALL", "", Color("8a4b42"))
		recall.custom_minimum_size.x = 150
		var id: int = spy.id
		recall.pressed.connect(func():
			match_rules.espionage.recall(player, id)
			message.text = "Spy recalled"
			refresh())
		row.add_child(recall)

func _process(delta: float) -> void:
	if not visible: return
	_tick -= delta
	if _tick <= 0.0:
		_tick = 1.0
		refresh()
