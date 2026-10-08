class_name FireControlPanel
extends CanvasLayer
signal confirmed(mode: String)
var panel: PanelContainer
var chosen: = "at_will"
var buttons: Dictionary = {}
const MODES: = {
	"hold": {"title": "Hold fire", "description": "Fire only on an explicit attack order. Do not retaliate automatically."}, 
	"return": {"title": "Return fire", "description": "Do not initiate attacks. Retaliate when attacked by an enemy within weapon range."}, 
	"at_will": {"title": "Fire at will", "description": "Attack visible enemies in range while stationary. Existing movement orders take priority."}, 
	"offensive": {"title": "Offensive", "description": "Halt a route to fire at visible enemies in range. Resume the route when the target leaves range or is destroyed."}, 
	"aggressive": {"title": "Aggressive", "description": "Fire at visible foreign armies in range, even during peace. This declares war. Halt movement to fire, then resume the route."}}
func setup(theme: Theme) -> void :
	layer = 15
	var root: = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = theme
	add_child(root)
	var dim: = ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.03, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	panel = PanelContainer.new()
	root.add_child(panel)
	var column: = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var heading: = Label.new()
	heading.text = "FIRE CONTROL"
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", Color("e9cf87"))
	column.add_child(heading)
	var scroll: = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var body: = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	var group: = ButtonGroup.new()
	for id in MODES:
		var button: = Button.new()
		button.text = MODES[id].title
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size.y = 48
		button.pressed.connect( func(): chosen = id)
		buttons[id] = button
		body.add_child(button)
		var label: = Label.new()
		label.text = MODES[id].description
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(label)
	var actions: = HBoxContainer.new()
	column.add_child(actions)
	for title in ["Cancel", "Confirm"]:
		var button: = Button.new()
		button.text = title
		button.custom_minimum_size.y = 48
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(button)
		button.pressed.connect( func():
			if title == "Confirm": confirmed.emit(chosen)
			hide())
	get_viewport().size_changed.connect(_layout)
	hide()
func _layout() -> void :
	var size: = get_viewport().get_visible_rect().size
	panel.position = Vector2(maxf(12, (size.x - 550) * 0.5), 12)
	panel.size = Vector2(minf(550, size.x - 24), size.y - 24)
func open(mode: String) -> void :
	chosen = mode if MODES.has(mode) else "at_will"
	buttons[chosen].button_pressed = true
	_layout()
	show()
