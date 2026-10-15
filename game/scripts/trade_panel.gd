class_name TradePanel
extends CanvasLayer
## Trade screen (owner request 2026-10-13: trade instead of a market). One card per trade
## partner: how the goods travel (rail / sea), what is needed, and the active route with its
## cargo and next delivery. Opening a route sends real trains or ships across the map.
var market_view: = false
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
	var tabs: = HBoxContainer.new()
	column.add_child(tabs)
	for label in ["Trade routes", "Transport market"]:
		var button: = Button.new()
		button.text = label
		button.custom_minimum_size.y = 44
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func():
			market_view = label == "Transport market"
			if market_view: _market()
			else: _refresh())
		tabs.add_child(button)
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
	trade.changed.connect(func(): if visible and not market_view: _refresh())
	get_viewport().size_changed.connect(_layout)
	hide()

func open() -> void:
	message.text = ""
	_layout()
	if market_view: _market()
	else: _refresh()
	show()

func _layout() -> void:
	var size: = get_viewport().get_visible_rect().size
	var width: = minf(760.0, size.x)
	var top: = roundf(size.y * 0.06)
	panel.position = Vector2((size.x - width) * 0.5, top)
	panel.size = Vector2(width, size.y - top)

func _refresh() -> void:
	title.text = "Trade"
	var me: = GameSession.player_country
	for child in list.get_children(): list.remove_child(child); child.queue_free()
	var mine: = trade.routes_of(me)
	summary.text = "%d of %d trade routes open · trains need a train station, ships a naval base · neutral imports cost funds; player sales use Transport market · armies move twice as fast by rail through friendly provinces with a station" % [mine.size(), TradeNetwork.MAX_ROUTES_PER_COUNTRY]
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
		detail.text = "%s → %s · %s · +%d %s per delivery · paid import · next departure in %s · %d on the way" % [city.get("name", route.city), trade.partner_name(partner), route.cargo.capitalize(), roundi(trade.delivery_amount(route)), route.cargo, SimulationClock.duration(maxf(0.0, route.timer)), trade.convoys.filter(func(c: Dictionary): return c.route == route.id).size()]
		var close: = CowUI.action("Close", "", CowUI.RED)
		close.pressed.connect(func():
			trade.close_route(route.id)
			message.text = "Trade route to %s closed" % trade.partner_name(partner)
			_refresh())
		actions.add_child(close)
	return card

func _market() -> void:
	for child in list.get_children(): list.remove_child(child); child.queue_free()
	title.text = "Transport market"
	summary.text = "Sell equipment or resources. Infantry cannot be sold. Cargo arrives by train, ship or cargo plane; terminals have five levels. Ships and trains can be attacked. Buyer payment is held until delivery; destroyed cargo is lost and the buyer is refunded."
	var market: TransportMarket = trade.market
	var me: = GameSession.player_country
	var cities: Array = trade._cities_of(me)
	if cities.is_empty(): return
	var refresh: = Button.new()
	refresh.text = "Refresh offers and shipments"
	refresh.custom_minimum_size.y = 44
	refresh.pressed.connect(_market)
	list.add_child(refresh)
	var city_pick: = OptionButton.new()
	for city in cities: city_pick.add_item(city.name)
	list.add_child(CowUI.label("Your selling / receiving city", 16))
	list.add_child(city_pick)
	var cargo_pick: = OptionButton.new()
	var choices: Array = []
	for cargo in TradeNetwork.CARGO:
		choices.append({"cargo": cargo})
		cargo_pick.add_item(cargo.capitalize())
	for unit in trade.armies.units:
		if unit.country != me or not TransportMarket.sale_allowed(unit): continue
		choices.append({"unit": unit.id, "minimum": TransportMarket.minimum_price(unit)})
		cargo_pick.add_item("%s · minimum %d" % [unit.name, TransportMarket.minimum_price(unit)])
	list.add_child(CowUI.label("Cargo or equipment to sell",16))
	list.add_child(cargo_pick)
	var amount: = SpinBox.new()
	amount.min_value = 1; amount.max_value = 100000; amount.value = 100
	list.add_child(CowUI.label("Resource quantity (equipment is sold one unit at a time)",14))
	list.add_child(amount)
	var price: = SpinBox.new()
	price.min_value = 1; price.max_value = 100000000; price.value = 100
	list.add_child(CowUI.label("Total asking price",16))
	list.add_child(price)
	var minimum: = CowUI.label("",14)
	list.add_child(minimum)
	var update_minimum: = func():
		var choice: Dictionary = choices[cargo_pick.selected]
		var floor_price: int = int(choice.minimum) if choice.has("unit") else ceili(TradeNetwork.value_of(choice.cargo, amount.value))
		minimum.text = "Minimum total price: %d" % floor_price
		price.min_value = floor_price
	cargo_pick.item_selected.connect(func(_i): update_minimum.call())
	amount.value_changed.connect(func(_v): update_minimum.call())
	update_minimum.call()
	var sell: = Button.new()
	sell.text = "List cargo for sale"
	sell.custom_minimum_size.y = 44
	sell.pressed.connect(func():
		var choice: Dictionary = choices[cargo_pick.selected]
		var error: String
		if choice.has("unit"): error = market.list_unit(me,cities[city_pick.selected].id,choice.unit,int(price.value))
		else: error = market.list_resource(me,cities[city_pick.selected].id,choice.cargo,int(amount.value),int(price.value))
		message.text = "Offer submitted" if error.is_empty() else error
		_market())
	list.add_child(sell)
	list.add_child(CowUI.label("OFFERS",20))
	if market.offers.is_empty(): list.add_child(CowUI.label("No player offers yet. List cargo or ask a trade partner to sell.",14))
	for offer in market.offers:
		var name: String = offer.unit.get("name", offer.cargo.capitalize())
		var text: = CowUI.label("%s · %s · %d · total %d" % [offer.seller.capitalize(),name,offer.amount,offer.price],16)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(text)
		if offer.seller == me:
			var cancel: = Button.new(); cancel.text = "Withdraw offer"; cancel.custom_minimum_size.y = 44
			cancel.pressed.connect(func():
				var error: = market.cancel(me,int(offer.id))
				message.text = "Withdrawal submitted" if error.is_empty() else error
				_market())
			list.add_child(cancel)
		else:
			for mode in TransportMarket.MODES:
				var buy: = Button.new()
				buy.text = "Buy via " + {"rail":"train", "sea":"ship", "air":"cargo plane"}[mode]
				buy.custom_minimum_size.y = 44
				buy.pressed.connect(func():
					var error: = market.buy(me,int(offer.id),cities[city_pick.selected].id,mode)
					message.text = "Purchase submitted; funds held until arrival" if error.is_empty() else error
					_market())
				list.add_child(buy)
	list.add_child(CowUI.label("SHIPMENTS",20))
	for shipment in market.shipments:
		if me not in [shipment.seller,shipment.buyer]: continue
		var text: = CowUI.label("#%d · %s · %s → %s · %s · %d%% health" % [shipment.id,shipment.mode,shipment.seller.capitalize(),shipment.buyer.capitalize(),shipment.status,roundi(shipment.health)],14)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(text)
	for record in market.history:
		if me not in [record.seller,record.buyer]: continue
		list.add_child(CowUI.label("#%d · %s" % [record.id,record.status],14))
