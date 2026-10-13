class_name GoldPanel
extends CanvasLayer
## Gold (owner 2026-10-13): 10,000 free gold each match, only good for that match. Spend it to
## buy resources here, or on the gold buttons in the city and research screens to finish
## production, construction and research now. Buying more gold needs the store (Google Play
## billing), which is not connected yet.
var economy: ProductionSystem
var panel: PanelContainer
var balance: Label
var message: Label
var list: VBoxContainer

func setup(system: ProductionSystem, theme: Theme) -> void:
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
	var head: = CowUI.header("Gold", false)
	head.close.pressed.connect(hide)
	column.add_child(head.bar)
	balance = CowUI.label("", 26, CowUI.GOLD)
	balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(balance)
	var note: = CowUI.label("Every match starts with %s free gold, good for this match only. Use the gold buttons in cities and research to finish now." % StrategyHUD._thousands(GoldWallet.START), 17)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)
	var scroll: = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	list.add_child(_heading("Buy resources with gold"))
	for resource in ProductionSystem.RESOURCES:
		for amount in [GoldWallet.PACK, GoldWallet.PACK * 5]:
			var card: = PanelContainer.new()
			card.add_theme_stylebox_override("panel", CowUI.skin("row", 8, 10))
			list.add_child(card)
			var row: = HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			card.add_child(row)
			var picture: = TextureRect.new()
			picture.texture = ResourceSites.icon(resource)
			picture.custom_minimum_size = Vector2(44, 44)
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(picture)
			var item: = CowUI.label("%s %s" % [StrategyHUD._thousands(amount), NAMES.get(resource, resource.capitalize())], 22, CowUI.INK)
			item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(item)
			var buy: = CowUI.action("%s GOLD" % StrategyHUD._thousands(GoldWallet.resource_price(resource, amount)), "", CowUI.GREEN)
			buy.custom_minimum_size.x = 190
			buy.pressed.connect(func():
				var error: = economy.buy_with_gold(GameSession.player_country, resource, amount)
				message.text = error if not error.is_empty() else "Bought %s %s" % [StrategyHUD._thousands(amount), resource]
				refresh())
			row.add_child(buy)
	list.add_child(_heading("More gold"))
	var store: = CowUI.action("BUY MORE GOLD", "", CowUI.GREEN)
	store.pressed.connect(func(): message.text = "The gold store opens when Google Play purchases are connected.")
	list.add_child(store)
	message = CowUI.label("", 18, CowUI.GOLD)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(message)
	economy.changed.connect(func(): if visible: refresh())
	get_viewport().size_changed.connect(_layout)
	_layout()
	hide()

const NAMES: = {"funds": "Money", "manpower": "Manpower", "food": "Food", "materials": "Metal", "fuel": "Oil", "electronics": "Rare earths"}

func _heading(text: String) -> Label:
	var heading: = CowUI.label(text, 22, CowUI.GOLD)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return heading

func _layout() -> void:
	var size: = get_viewport().get_visible_rect().size
	var width: = minf(760, size.x)
	panel.position = Vector2((size.x - width) / 2, roundf(size.y * 0.06))
	panel.size = Vector2(width, size.y - panel.position.y)

func open() -> void:
	message.text = ""
	show()
	_layout()
	refresh()

func refresh() -> void:
	balance.text = StrategyHUD._thousands(int(economy.gold.get(GameSession.player_country, 0))) + " gold"
