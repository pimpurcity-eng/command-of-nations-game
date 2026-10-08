class_name ExchangePanel
extends CanvasLayer
var exchange: = SupplyExchange.new()
var panel: PanelContainer
var stock: Label
var quantity: SpinBox
var message: Label
func setup(economy: ProductionSystem, theme: Theme) -> void :
	exchange.economy = economy
	layer = 14
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
	var column: = VBoxContainer.new()
	panel.add_child(column)
	var close: = Button.new()
	close.text = "SUPPLY EXCHANGE · Close"
	close.custom_minimum_size.y = 48
	close.pressed.connect(hide)
	column.add_child(close)
	var scroll: = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var body: = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	stock = Label.new()
	stock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(stock)
	var note: = Label.new()
	note.text = "Single-player supplier · immediate trades\nFunds are currency. Manpower cannot be bought.\nQuantity per trade:"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(note)
	quantity = SpinBox.new()
	quantity.min_value = 1
	quantity.max_value = 10000
	quantity.value = 10
	quantity.custom_minimum_size.y = 48
	body.add_child(quantity)
	for resource in SupplyExchange.PRICES:
		var label: = Label.new()
		label.text = resource.capitalize() + " · Buy " + str(SupplyExchange.PRICES[resource].buy) + " / Sell " + str(SupplyExchange.PRICES[resource].sell) + " funds each"
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(label)
		var row: = HBoxContainer.new()
		body.add_child(row)
		for buying in [true, false]:
			var button: = Button.new()
			button.text = "Buy" if buying else "Sell"
			button.custom_minimum_size.y = 48
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.pressed.connect( func():
				var error: = exchange.transact(resource, quantity.value, buying)
				message.text = ("Bought " if buying else "Sold ") + str(int(quantity.value)) + " " + resource if error.is_empty() else error
				_refresh())
			row.add_child(button)
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(message)
	get_viewport().size_changed.connect(_layout)
	hide()
func _refresh() -> void :
	stock.text = ""
	for resource in ProductionSystem.RESOURCES: stock.text += resource.capitalize() + ": " + str(int(exchange.economy.stockpiles[GameSession.player_country][resource])) + "  "
func _layout() -> void :
	var size: = get_viewport().get_visible_rect().size
	panel.position = Vector2(maxf(12, (size.x - 550) * 0.5), 12)
	panel.size = Vector2(minf(550, size.x - 24), size.y - 24)
func open() -> void :
	_refresh()
	_layout()
	show()
