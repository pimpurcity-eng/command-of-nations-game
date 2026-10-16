class_name MatchLobbyPanel
extends CanvasLayer
## One real match entry. A future games list can open this same country picker.
signal cancelled
var client: MatchClient
var countries: OptionButton
var info: Label
var nation: Label
var status: Label
var join_button: Button
var refresh_button: Button
var seats: Dictionary = {}
var own_country: = ""
var joining: = false
var refresh_elapsed: = 0.0
var surface: PanelContainer

func open(theme: Theme, connection: MatchClient) -> void:
	client = connection
	layer = 21
	var screen: = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.theme = theme
	add_child(screen)
	var shade: = ColorRect.new()
	shade.color = Color(0.02, 0.05, 0.08, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(shade)
	surface = PanelContainer.new()
	var style: = StyleBoxFlat.new()
	style.bg_color = Color("14232d")
	style.border_color = MobileStartPanel.GOLD
	style.set_border_width_all(1)
	style.set_content_margin_all(24)
	style.set_corner_radius_all(8)
	surface.add_theme_stylebox_override("panel", style)
	screen.add_child(surface)
	var scroll: = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	surface.add_child(scroll)
	var body: = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	scroll.add_child(body)
	_label(body, "EUROPE — ONLINE TEST", 30, MobileStartPanel.GOLD)
	info = _label(body, "Checking the match…", 21)
	_label(body, "CHOOSE YOUR COUNTRY", 20, MobileStartPanel.GOLD)
	countries = OptionButton.new()
	countries.custom_minimum_size.y = 64
	countries.disabled = true
	countries.item_selected.connect(func(_index): _show_nation())
	body.add_child(countries)
	nation = _label(body, "Your country is reserved for your account for this match.", 21)
	_label(body, "The match continues while you are away. AI covers unclaimed countries and takes over after 48 hours of inactivity.", 19, MobileStartPanel.MUTED)
	status = _label(body, "Connecting to the match server…", 20, MobileStartPanel.MUTED)
	join_button = _button(body, "JOIN MATCH  →")
	join_button.disabled = true
	join_button.pressed.connect(func():
		if countries.selected < 0 or joining: return
		joining = true
		join_button.disabled = true
		countries.disabled = true
		status.text = "Reserving your country…"
		client.join_country(str(countries.get_item_metadata(countries.selected))))
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	body.add_child(row)
	refresh_button = _button(row, "REFRESH")
	refresh_button.pressed.connect(func():
		if not joining: client.refresh_lobby())
	_button(row, "BACK").pressed.connect(func():
		client.leave()
		cancelled.emit()
		queue_free())
	client.lobby_received.connect(show_match)
	client.closed.connect(func(reason):
		join_button.disabled = true
		countries.disabled = true
		refresh_button.disabled = true
		status.text = (reason if not reason.is_empty() else "Match server unavailable") + " · go back and try again")
	get_viewport().size_changed.connect(_layout)
	_layout()

func _label(parent: Node, text: String, size: int, color: Color = MobileStartPanel.INK) -> Label:
	var label: = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String) -> Button:
	var button: = Button.new()
	button.text = text
	button.custom_minimum_size.y = 64
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 22)
	parent.add_child(button)
	return button

func _layout() -> void:
	var area: = get_viewport().get_visible_rect().size
	var width: = minf(680, area.x - 32)
	surface.position = Vector2((area.x - width) / 2, 32)
	surface.size = Vector2(width, maxf(250, area.y - 64))

func show_match(data: Dictionary) -> void:
	seats = data.get("seats", {})
	own_country = str(data.get("own_country", ""))
	var previous: = str(countries.get_item_metadata(countries.selected)) if countries.selected >= 0 else GameSession.player_country
	countries.clear()
	var chosen: = -1
	var first_free: = -1
	for country in MapDefinition.players():
		var seat: Dictionary = seats.get(country.id, {})
		var taken: bool = seat.get("claimed", false) and country.id != own_country
		var suffix: = " · YOUR COUNTRY" if country.id == own_country else (" · TAKEN" if taken else " · AVAILABLE")
		countries.add_item(country.name + suffix)
		var index: = countries.item_count - 1
		countries.set_item_metadata(index, country.id)
		countries.set_item_disabled(index, taken or (not own_country.is_empty() and country.id != own_country))
		if not taken and first_free < 0: first_free = index
		if country.id == own_country or (own_country.is_empty() and country.id == previous and not taken): chosen = index
	if chosen < 0: chosen = first_free
	countries.select(chosen)
	countries.disabled = joining or not own_country.is_empty() or chosen < 0
	var finished: bool = not str(data.get("winner", "")).is_empty()
	join_button.text = "RESUME MATCH  →" if not own_country.is_empty() else "JOIN MATCH  →"
	join_button.disabled = joining or chosen < 0 or (finished and own_country.is_empty())
	info.text = "Game %s · Day %d · %d/%d players · %d× speed" % [str(data.get("match", "")), 1 + int(float(data.get("time", 0)) / VictoryRules.DAY), int(data.get("players", 0)), int(data.get("capacity", 20)), int(data.get("speed", 1))]
	status.text = "Match complete" if finished else ("This match is full" if chosen < 0 else "Choose a country and join" if own_country.is_empty() else "Your country is ready to resume")
	_show_nation()

func _show_nation() -> void:
	if countries.selected < 0:
		nation.text = "All countries have been claimed."
		return
	var country: = str(countries.get_item_metadata(countries.selected))
	nation.text = MapDefinition.country_name(country) + " · " + Doctrine.info(country).name + " doctrine\n" + Doctrine.summary(country) + "\n7 starting cities · 30 starting units"

func _process(delta: float) -> void:
	refresh_elapsed += delta
	if refresh_elapsed >= 10.0 and client != null and not joining:
		refresh_elapsed = 0
		client.refresh_lobby()
