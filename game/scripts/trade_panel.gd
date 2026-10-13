class_name TradePanel
extends CanvasLayer
## Trade screen (owner request 2026-10-13: trade instead of a market). One card per trade
## partner: how the goods travel (rail / sea), what is needed, and the active route with its
## cargo and next delivery. Opening a route sends real trains or ships across the map.
var trade: TradeNetwork
var panel: PanelContainer
var title: Label
var summary: Label
var list: VBoxContainer
var message: Label

func setup(network: TradeNetwork, theme: Theme) -> void:
	trade = network
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
	var head: = CowUI.header("Trade", false)
	title = head.title
	head.close.pressed.connect(hide)
	column.add_child(head.bar)
	var info: = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: info.add_theme_constant_override("margin_" + side, 10)
	column.add_child(info)
	summary = CowUI.label("", 15, Color("d8d1bc"))
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_child(summary)
	var scroll: = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var body: = PanelContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_stylebox_override("panel", CowUI.box(CowUI.LIST, 0, Color(0, 0, 0, 0), 0, 8))
	scroll.add_child(body)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	body.add_child(list)
	message = CowUI.label("", 14, Color("f1c27a"))
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var foot: = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: foot.add_theme_constant_override("margin_" + side, 8)
	foot.add_child(message)
	column.add_child(foot)
	trade.changed.connect(func(): if visible: _refresh())
	get_viewport().size_changed.connect(_layout)
	hide()

func open() -> void:
	message.text = ""
	_layout()
	_refresh()
	show()

func _layout() -> void:
	var size: = get_viewport().get_visible_rect().size
	var width: = minf(760.0, size.x)
	var top: = roundf(size.y * 0.06)
	panel.position = Vector2((size.x - width) * 0.5, top)
	panel.size = Vector2(width, size.y - top)

func _refresh() -> void:
	var me: = GameSession.player_country
	for child in list.get_children(): list.remove_child(child); child.queue_free()
	var mine: = trade.routes_of(me)
	summary.text = "%d of %d trade routes open · trains need a train station, ships a naval base · deliveries count as income (economic victory) · armies move twice as fast by rail through friendly provinces with a station" % [mine.size(), TradeNetwork.MAX_ROUTES_PER_COUNTRY]
	for partner in trade.partners_for(me):
		list.add_child(_card(me, partner))

func _card(me: String, partner: String) -> Control:
	var card: = PanelContainer.new()
	card.add_theme_stylebox_override("panel", CowUI.box(CowUI.ROW, 8, Color("b8b29e"), 1, 10))
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var mode: = trade.partner_mode(partner)
	var badge: = CowUI.label("RAIL" if mode == "rail" else "SEA", 14, Color.WHITE)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.custom_minimum_size = Vector2(64, 64)
	badge.add_theme_stylebox_override("normal", CowUI.box(Color("5b6b48") if mode == "rail" else Color("3f6680"), 8))
	row.add_child(badge)
	var text: = VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	row.add_child(text)
	var name_label: = CowUI.label(trade.partner_name(partner) + ("  ·  player" if not TradeNetwork.PARTNERS.has(partner) else ""), 20, CowUI.INK)
	name_label.add_theme_font_override("font", CowUI.title_font())
	text.add_child(name_label)
	var route: Dictionary = {}
	for r in trade.routes_of(me):
		if r.partner == partner: route = r
	var detail: = CowUI.label("", 14, Color("4a4840"))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(detail)
	var actions: = VBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	row.add_child(actions)
	if route.is_empty():
		var plan: = trade.plan(me, partner)
		if plan.has("error"):
			detail.text = plan.error
		else:
			detail.text = "From %s · %s every %s · choose a cargo:" % [plan.city.name, "train" if mode == "rail" else "ship", SimulationClock.duration(TradeNetwork.DEPARTURE_EVERY)]
			var cargo_row: = HBoxContainer.new()
			cargo_row.add_theme_constant_override("separation", 6)
			text.add_child(cargo_row)
			for cargo in TradeNetwork.CARGO:
				var button: = Button.new()
				button.text = cargo.capitalize()
				button.custom_minimum_size = Vector2(0, 40)
				button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				button.pressed.connect(func():
					var error: = trade.open_route(me, partner, cargo)
					message.text = ("Trade route to %s opened · %s" % [trade.partner_name(partner), cargo]) if error.is_empty() else error
					_refresh())
				cargo_row.add_child(button)
	else:
		var city: = trade.buildings.city(route.city)
		detail.text = "%s → %s · %s · +%d %s per delivery · next departure in %s · %d on the way" % [city.get("name", route.city), trade.partner_name(partner), route.cargo.capitalize(), roundi(trade.delivery_amount(route)), route.cargo, SimulationClock.duration(maxf(0.0, route.timer)), trade.convoys.filter(func(c: Dictionary): return c.route == route.id).size()]
		var close: = CowUI.action("Close", "", CowUI.RED)
		close.pressed.connect(func():
			trade.close_route(route.id)
			message.text = "Trade route to %s closed" % trade.partner_name(partner)
			_refresh())
		actions.add_child(close)
	return card
