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
## The player deliberately inspected this market item; used by the guided training.
var inspected_world_item: Dictionary = {}

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
		if label == "Transport market": button.set_meta("tutorial_action", "transport_market")
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
			detail.text = "From %s · %s every %s\n%s\nChoose a cargo:" % [plan.city.name, "train" if mode == "rail" else "ship", SimulationClock.duration(TradeNetwork.DEPARTURE_EVERY), carry_text(plan.city.id, mode)]
			var cargo_row: = HBoxContainer.new()
			cargo_row.add_theme_constant_override("separation", 6)
			text.add_child(cargo_row)
			for cargo in TradeNetwork.CARGO:
				var button: = Button.new()
				button.text = cargo.capitalize()
				button.set_meta("tutorial_action", "create_trade_route")
				button.custom_minimum_size = Vector2(0, 40)
				button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				button.pressed.connect(func():
					var error: = trade.open_route(me, partner, cargo)
					message.text = ("Trade route to %s opened · %s" % [trade.partner_name(partner), cargo]) if error.is_empty() else error
					_refresh())
				cargo_row.add_child(button)
	else:
		var city: = trade.buildings.city(route.city)
		detail.text = "%s → %s · %s · each %s carries %s %s · paid import · next departure in %s · %d on the way\n%s" % [city.get("name", route.city), trade.partner_name(partner), route.cargo.capitalize(), "train" if route.mode == "rail" else "ship", TransportMarket._thousands(roundi(trade.delivery_amount(route))), route.cargo, SimulationClock.duration(maxf(0.0, route.timer)), trade.convoys.filter(func(c: Dictionary): return c.route == route.id).size(), carry_text(route.city, route.mode)]
		var close: = CowUI.action("Close", "", CowUI.RED)
		close.pressed.connect(func():
			trade.close_route(route.id)
			message.text = "Trade route to %s closed" % trade.partner_name(partner)
			_refresh())
		actions.add_child(close)
	return card

## Owner 2026-10-16: "It doesn't have how much the train and shipping carry, so every level
## should be higher." Trade-route load per cargo at this terminal level, and the next level.
func carry_text(city_id: String, mode: String) -> String:
	var building: = "train_station" if mode == "rail" else "naval_base"
	var level: = trade.buildings.level(city_id, building)
	var top: = int(trade.buildings.spec(building).get("max_level", 3))
	var factor: = trade.market.scale(city_id, mode, "materials") if trade.market != null else TransportMarket.level_scale(level)
	var parts: Array = []
	for cargo in TradeNetwork.CARGO:
		parts.append("%s %s" % [cargo.capitalize(), TransportMarket._thousands(roundi(trade.per_trip(cargo, mode, city_id)))])
	var text: = "Each %s carries %s (%s level %d)" % ["train" if mode == "rail" else "ship", " · ".join(parts), "station" if mode == "rail" else "port", level]
	if level < top and level > 0:
		var gain: = TransportMarket.level_scale(level + 1) / maxf(TransportMarket.level_scale(level), 0.01)
		text += " · level %d: %s food (+%d%%)" % [level + 1, TransportMarket._thousands(roundi(trade.per_trip("food", mode, city_id) * gain)), roundi((gain - 1.0) * 100.0)]
	elif factor <= 0.0 and mode == "sea":
		text += " · research cargo ships to sail"
	return text

## Market cargo slots per trip from a city, now and at the next terminal level.
func market_capacity_text(city_id: String) -> String:
	var market: TransportMarket = trade.market
	var lines: Array = ["TRANSPORT CAPACITY PER TRIP · 1 slot = 100 resources or 1 light vehicle (planes 2, heavy 4)"]
	for mode in TransportMarket.MODES:
		var building: String = market.facility(mode)
		var level: = market.facility_level(city_id, mode)
		var top: = int(trade.buildings.spec(building).get("max_level", 3))
		var slots: = market.capacity(city_id, mode)
		var line: = "%s · %s level %d: %d slots = %s cargo" % [TransportMarket.TRANSPORT_NAME[mode].capitalize(), trade.buildings.spec(building).get("name", building), level, slots, TransportMarket._thousands(slots * int(TransportMarket.RESOURCE_LOAD))]
		if level == 0: line += " (build one to ship)"
		if level < top:
			var vessel: = market.vessel_level(city_id, "materials") if mode == "sea" else 1
			var next: = TransportMarket.capacity_at(mode, level + 1, vessel)
			line += " · level %d: %s" % [level + 1, TransportMarket._thousands(next * int(TransportMarket.RESOURCE_LOAD))]
		if mode == "sea": line += " · ship research Lv%d (fuel: tanker Lv%d)" % [market.vessel_level(city_id, "materials"), market.vessel_level(city_id, "fuel")]
		lines.append(line)
	return "\n".join(lines)

func _market() -> void:
	for child in list.get_children(): list.remove_child(child); child.queue_free()
	title.text = "Transport market"
	summary.text = "Sell equipment or resources. Infantry cannot be sold. Cargo arrives by train, ship or cargo plane; each station, port or airbase level carries more per trip (see capacity below). Ships and trains can be attacked. Buyer payment is held until delivery; destroyed cargo is lost and the buyer is refunded."
	var market: TransportMarket = trade.market
	var me: = GameSession.player_country
	var cities: Array = trade._cities_of(me)
	if cities.is_empty(): return
	list.add_child(CowUI.label("WORLD PRICES · shared by every nation",18))
	var world_pick: = OptionButton.new()
	var world_items: Array = []
	for cargo in TradeNetwork.CARGO:
		world_pick.add_item(cargo.capitalize()); world_items.append({"cargo":cargo})
	for spec in EquipmentIdentity.catalog:
		if spec.get("retired",false) or spec.get("research_only",false) or UnitClasses.of(spec) == "infantry": continue
		world_pick.add_item(spec.country.capitalize() + " · " + spec.name)
		world_items.append({"equipment_id":spec.id,"level":1})
	list.add_child(world_pick)
	var world_level: = SpinBox.new(); world_level.min_value = 1; world_level.max_value = 5
	list.add_child(CowUI.label("Weapon research level",14)); list.add_child(world_level)
	var world_label: = CowUI.label("",14); world_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; list.add_child(world_label)
	var show_world: = func():
		var item: Dictionary = world_items[world_pick.selected].duplicate()
		item.level = int(world_level.value)
		var floor_price: float = trade.world_prices.resource(item.cargo) if item.has("cargo") else market.unit_floor(item)
		var item_name: String = item.cargo.capitalize() if item.has("cargo") else EquipmentIdentity.research_title(item.equipment_id,item.level)
		world_label.text = "%s · world minimum %.2f per %s · completed net purchases drive demand; prices cool over time" % [item_name,floor_price,"resource unit" if item.has("cargo") else "weapon unit"]
	world_pick.set_meta("tutorial_action", "world_price_item")
	world_pick.item_selected.connect(func(i):
		inspected_world_item = world_items[i].duplicate()
		show_world.call())
	world_level.value_changed.connect(func(_v): show_world.call())
	show_world.call()
	var refresh: = Button.new()
	refresh.text = "Refresh offers and shipments"
	refresh.custom_minimum_size.y = 44
	refresh.pressed.connect(_market)
	list.add_child(refresh)
	var city_pick: = OptionButton.new()
	for city in cities: city_pick.add_item(city.name)
	list.add_child(CowUI.label("Your selling / receiving city", 16))
	list.add_child(city_pick)
	var capacity_label: = CowUI.label(market_capacity_text(cities[0].id), 14, Color("f1c27a"))
	capacity_label.name = "TransportCapacity"
	capacity_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(capacity_label)
	city_pick.item_selected.connect(func(i): capacity_label.text = market_capacity_text(cities[i].id))
	var cargo_pick: = OptionButton.new()
	var choices: Array = []
	for cargo in TradeNetwork.CARGO:
		choices.append({"cargo": cargo})
		cargo_pick.add_item(cargo.capitalize())
	for unit in trade.armies.units:
		if unit.country != me or not TransportMarket.sale_allowed(unit): continue
		choices.append({"unit": unit.id, "minimum": market.unit_floor(unit)})
		cargo_pick.add_item("%s · minimum %d" % [unit.name, market.unit_floor(unit)])
	list.add_child(CowUI.label("Cargo or equipment to sell",16))
	list.add_child(cargo_pick)
	var amount: = SpinBox.new()
	amount.min_value = 1; amount.max_value = 100000; amount.value = 100
	list.add_child(CowUI.label("Resource quantity (equipment is sold one unit at a time)",14))
	list.add_child(amount)
	var price: = SpinBox.new()
	price.min_value = 1; price.max_value = 100000000; price.value = 100
	list.add_child(CowUI.label("Total asking price / Wanted budget",16))
	list.add_child(price)
	var minimum: = CowUI.label("",14)
	list.add_child(minimum)
	var update_minimum: = func():
		var choice: Dictionary = choices[cargo_pick.selected]
		var floor_price: int = int(choice.minimum) if choice.has("unit") else ceili(trade.world_prices.resource(choice.cargo) * amount.value)
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
	var request_mode: = OptionButton.new()
	for transport in TransportMarket.MODES: request_mode.add_item({"rail":"Train", "sea":"Ship", "air":"Cargo plane"}[transport])
	list.add_child(CowUI.label("Wanted delivery method",14)); list.add_child(request_mode)
	var wanted: = Button.new(); wanted.text = "Post Wanted: selected world item"; wanted.custom_minimum_size.y = 44
	wanted.pressed.connect(func():
		var item: Dictionary = world_items[world_pick.selected]
		var error: = market.post_request(me,cities[city_pick.selected].id,item.get("cargo",item.get("equipment_id","")),int(world_level.value),int(amount.value) if item.has("cargo") else 1,int(price.value),TransportMarket.MODES[request_mode.selected])
		message.text = "Wanted request submitted; funds checked when a seller fills it" if error.is_empty() else error
		_market())
	list.add_child(wanted)
	list.add_child(CowUI.label("WANTED",20))
	for request in market.requests:
		var name: String = request.cargo.capitalize() if request.cargo != "equipment" else EquipmentIdentity.research_title(request.equipment_id,int(request.level))
		var text: = CowUI.label("%s wants %d %s · budget %d · world minimum %d · %s" % [request.buyer.capitalize(),request.amount,name,request.budget,market.request_floor(request),request.mode],14)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; list.add_child(text)
		var action: = Button.new(); action.custom_minimum_size.y = 44
		action.text = "Withdraw Wanted request" if request.buyer == me else "Fill request from selected city for %d" % request.budget
		action.pressed.connect(func():
			var error: String = market.cancel_request(me,int(request.id)) if request.buyer == me else market.fulfil_request(me,int(request.id),cities[city_pick.selected].id)
			message.text = "Wanted action submitted" if error.is_empty() else error
			_market())
		list.add_child(action)
	list.add_child(CowUI.label("OFFERS",20))
	if market.offers.is_empty(): list.add_child(CowUI.label("No player offers yet. List cargo or ask a trade partner to sell.",14))
	for offer in market.offers:
		var name: String = offer.unit.get("name", offer.cargo.capitalize())
		var slots: int = ceili(float(offer.amount) / TransportMarket.RESOURCE_LOAD) if offer.unit.is_empty() else TransportMarket.load_size(offer.unit)
		var text: = CowUI.label("%s · %s · %d · asking %d · world minimum %d · needs %d cargo slot%s" % [offer.seller.capitalize(),name,offer.amount,offer.price,market.offer_floor(offer),slots,"" if slots == 1 else "s"],16)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(text)
		if offer.seller == me:
			if int(offer.price) < market.offer_floor(offer):
				var update: = Button.new(); update.text = "Update to world minimum"; update.custom_minimum_size.y = 44
				update.pressed.connect(func():
					var error: = market.reprice(me,int(offer.id),market.offer_floor(offer))
					message.text = "Price update submitted" if error.is_empty() else error
					_market())
				list.add_child(update)
			var cancel: = Button.new(); cancel.text = "Withdraw offer"; cancel.custom_minimum_size.y = 44
			cancel.pressed.connect(func():
				var error: = market.cancel(me,int(offer.id))
				message.text = "Withdrawal submitted" if error.is_empty() else error
				_market())
			list.add_child(cancel)
		else:
			for mode in TransportMarket.MODES:
				var buy: = Button.new()
				buy.text = "Buy via %s · carries %d slots from %s" % [TransportMarket.TRANSPORT_NAME[mode], market.capacity(str(offer.city), mode, str(offer.cargo)), trade.buildings.city(str(offer.city)).get("name", offer.city)]
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
