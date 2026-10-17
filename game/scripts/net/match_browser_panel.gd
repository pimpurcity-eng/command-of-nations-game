class_name MatchBrowserPanel
extends CanvasLayer
## Browse real rounds before connecting to a country. Unreachable rounds never look empty.
signal selected(entry: Dictionary)
signal cancelled
var rows: VBoxContainer
var search: LineEdit
var entries: Array = []
var clients: Array[MatchClient] = []
var saved_only := false

func open(theme: Theme, mine: bool = false) -> void:
	layer = 22
	saved_only = mine
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.theme = theme
	add_child(screen)
	var shade := ColorRect.new()
	shade.color = Color("0c1720")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(shade)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 24; scroll.offset_right = -24; scroll.offset_top = 30; scroll.offset_bottom = -24
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	screen.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	scroll.add_child(body)
	_label(body, "MY GAMES" if mine else "NEW GAMES", 36)
	_label(body, "Every round has its own country, day and Resume. Regular multiplayer requires completed training and commander level 10.", 22)
	var tabs := HBoxContainer.new()
	body.add_child(tabs)
	_button(tabs, "MY GAMES").pressed.connect(func(): saved_only = true; _rebuild())
	_button(tabs, "NEW GAMES").pressed.connect(func(): saved_only = false; _rebuild())
	search = LineEdit.new()
	search.placeholder_text = "Search map, country or game ID"
	search.custom_minimum_size.y = 64
	search.text_changed.connect(func(_value): _filter())
	body.add_child(search)
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 16)
	body.add_child(rows)
	_button(body, "REFRESH GAMES").pressed.connect(_rebuild)
	_button(body, "BACK").pressed.connect(func(): cancelled.emit(); queue_free())
	_rebuild()

func _label(parent: Node, value: String, pixels: int) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", pixels)
	parent.add_child(label)
	return label

func _button(parent: Node, value: String) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 64
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 23)
	parent.add_child(button)
	return button

func _rebuild() -> void:
	for client in clients: client.leave(); client.queue_free()
	clients.clear(); entries.clear()
	for child in rows.get_children(): rows.remove_child(child); child.queue_free()
	var matches := OnlineGames.games() if saved_only else OnlineGames.configured()
	# Discover an existing seat on another device through each real configured server.
	if saved_only and not OnlineGames.account_id().is_empty():
		for entry in OnlineGames.configured():
			if not matches.any(func(row): return OnlineGames.key(row) == OnlineGames.key(entry)): matches.append(entry)
	if matches.is_empty(): _label(rows, "Sign in to see your matches." if OnlineGames.account_id().is_empty() and saved_only else "No matches yet. Start training or choose New Games.", 24)
	for entry in matches:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", CowUI.box(Color("172a35"), 12, MobileStartPanel.GOLD, 1, 20))
		rows.add_child(card)
		var column := VBoxContainer.new(); column.add_theme_constant_override("separation", 12); card.add_child(column)
		var name := str(entry.get("title", "Europe" if entry.map == MapDefinition.EUROPE else "Russia vs Ukraine"))
		_label(column, name.to_upper() + " · GAME " + str(entry.match), 28)
		var info := _label(column, "Checking live availability…", 23)
		var button := _button(column, "CHECKING…")
		button.disabled = true
		var record := {"entry": entry.duplicate(true), "card": card, "info": info, "button": button, "ready": false, "search": (name + " " + str(entry.match) + " " + str(entry.get("country", ""))).to_lower()}
		entries.append(record)
		button.pressed.connect(func(): selected.emit(record.entry); queue_free())
		if not entry.get("enabled", true): info.text = "Coming soon"; button.text = "COMING SOON"; continue
		_probe(record)
	_filter()

func _probe(record: Dictionary) -> void:
	var client := MatchClient.new()
	add_child(client); clients.append(client)
	var auth := PlayerAuth.current
	var token := auth.access_token if is_instance_valid(auth) and auth.signed_in() else ""
	client.lobby_received.connect(func(data: Dictionary):
		if not is_instance_valid(record.info): return
		record.ready = true
		var own := str(data.get("own_country", ""))
		var capacity := int(data.get("capacity", 0)); var players := int(data.get("players", 0))
		var ended := not str(data.get("winner", "")).is_empty()
		record.info.text = "Day %d · %d/%d players · %d× speed%s" % [1 + int(float(data.get("time", 0)) / VictoryRules.DAY), players, capacity, int(data.get("speed", 1)), (" · You command " + own.capitalize()) if not own.is_empty() else ""]
		record.button.text = "RESUME" if not own.is_empty() else "FINISHED" if ended else "FULL" if players >= capacity else "CHOOSE COUNTRY"
		record.button.disabled = own.is_empty() and (ended or players >= capacity)
		record.entry["resume"] = not own.is_empty()
		if not own.is_empty():
			record.entry["country"] = own
			OnlineGames.remember(record.entry)
		elif saved_only: record.card.hide()
		client.leave())
	client.closed.connect(func(reason):
		if record.ready or not is_instance_valid(record.info): return
		record.info.text = "Unavailable · " + (reason if not str(reason).is_empty() else "could not reach this round")
		record.button.text = "UNAVAILABLE")
	if client.preview(str(record.entry.url), token, str(record.entry.match), str(record.entry.map)) != OK:
		record.info.text = "Unavailable · could not connect"; record.button.text = "UNAVAILABLE"
	get_tree().create_timer(10.0).timeout.connect(func():
		if is_instance_valid(client) and not record.ready and is_instance_valid(record.info):
			record.info.text = "Unavailable · connection timed out"; record.button.text = "UNAVAILABLE"; client.leave())

func _filter() -> void:
	for record in entries: record.card.visible = search.text.strip_edges().is_empty() or str(record.search).contains(search.text.strip_edges().to_lower())

func _exit_tree() -> void:
	for client in clients:
		if is_instance_valid(client): client.leave()
