class_name Tutorial
extends CanvasLayer
## First-play tutorial (owner request 2026-10-12). A short card at the top of the screen walks a
## new player through the basics; each step advances by itself when the player does it. Shown
## once (remembered in user://settings.cfg); "Skip" ends it.
const SETTINGS_PATH: = "user://settings.cfg"
const STEPS: = [
	["choose", "Choose your opening: build a peaceful economy or prepare a military campaign. Both can win."],
	["select", "Tap one of your armies to select it."],
	["move", "Now tap the map (or a city) to move it there. Ground armies travel along the roads."],
	["play", "Tap Play (top right) to let time run. Orders happen in real time."],
	["city", "Tap one of your cities to build up your economy and produce new forces."],
	["research", "Open Research to unlock better tanks, aircraft and air defence."],
	["war", "Ready? Select an army, tap Attack and then an enemy army. Attacking declares war."],
	["victory", "Tap the ★ score (or More → Victory progress) to see how to win: domination, economy, elimination or points."],
]
var chosen: = false
var peaceful: = true
var game: Node
var step: = 0
var panel: PanelContainer
var text: Label
var _poll: = 0.0

static func done() -> bool:
	var settings: = ConfigFile.new()
	settings.load(SETTINGS_PATH)
	return settings.get_value("tutorial", "done", false)

static func mark_done() -> void:
	var settings: = ConfigFile.new()
	settings.load(SETTINGS_PATH)
	settings.set_value("tutorial", "done", true)
	settings.save(SETTINGS_PATH)

func setup(main: Node, theme: Theme) -> void:
	game = main
	layer = 12
	var root: = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	add_child(root)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", CowUI.box(Color(0.08, 0.1, 0.11, 0.93), 10, CowUI.GOLD, 1, 12))
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 12
	panel.offset_right = -12
	panel.offset_top = 132
	root.add_child(panel)
	var column: = VBoxContainer.new()
	panel.add_child(column)
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	text = CowUI.label("", 18)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var skip: = Button.new()
	skip.text = "Skip"
	skip.custom_minimum_size = Vector2(80, 44)
	skip.pressed.connect(finish)
	row.add_child(skip)
	var paths: = HBoxContainer.new()
	column.add_child(paths)
	for style in ["Economy", "Military"]:
		var button: = Button.new()
		button.text = style
		button.custom_minimum_size.y = 44
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func():
			peaceful = style == "Economy"
			chosen = true
			paths.hide())
		paths.add_child(button)
	_show()

func _show() -> void:
	text.text = "TUTORIAL %d/%d · %s" % [step + 1, STEPS.size(), STEPS[step][1]]

## Whether the current step's action has happened.
func step_done(id: String) -> bool:
	var units: UnitSystem = game.units
	var mine: bool = units.selected >= 0 and units.units[units.selected].country == GameSession.player_country
	match id:
		"choose": return chosen
		"select": return mine
		"move": return mine and units.units[units.selected].get("moving", false)
		"play": return not game.clock.paused
		"city": return game.city_panel != null and game.city_panel.visible
		"research": return game.research_panel != null and game.research_panel.visible
		"war": return peaceful or game.match_rules.at_war
		"victory": return game.campaign_panel != null and game.campaign_panel.visible
	return true

func _process(delta: float) -> void:
	_poll += delta
	if _poll < 0.3: return
	_poll = 0.0
	# The card steps aside while a full-screen menu is open (it covered the menu titles).
	var menu_open: = false
	for name in ["city_panel", "province_panel", "research_panel", "production_panel", "campaign_panel", "exchange_panel", "trade_panel", "army_selection", "army_command"]:
		var menu = game.get(name)
		if menu != null and is_instance_valid(menu) and menu.visible: menu_open = true
	panel.visible = not menu_open
	if step_done(STEPS[step][0]):
		step += 1
		if step >= STEPS.size():
			game.hud.show_status("TUTORIAL COMPLETE · Good luck, Commander")
			finish()
			return
		_show()

func finish() -> void:
	mark_done()
	queue_free()
