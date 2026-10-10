class_name StrategyTheme
extends RefCounted
static func surface(name: String, margin: float = 12.0) -> StyleBoxFlat:
	var style: = StyleBoxFlat.new()
	style.bg_color = Color({"panel": "20282d", "button": "344047", "hover": "44564f", "pressed": "293932", "disabled": "283137"}.get(name, "20282d"))
	style.border_color = Color("52605e")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(margin)
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

## Consistent scalable typography; included fonts use SIL Open Font License.
static var _fonts: Dictionary = {}
static func font(family: String, weight: int) -> Font:
	var key: = family + str(weight)
	if not _fonts.has(key):
		var variation: = FontVariation.new()
		variation.base_font = load("res://assets/fonts/" + family + ".ttf")
		variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		_fonts[key] = variation
	return _fonts[key]
static func create() -> Theme:
	var theme: = Theme.new()
	theme.default_font_size = 16
	theme.default_font = font("RobotoCondensed", 400)
	theme.set_font("font", "Button", font("RobotoCondensed", 500))
	for type_name in ["Button", "OptionButton", "MenuButton"]:
		for state in ["normal", "hover", "pressed", "disabled"]:
			theme.set_stylebox(state, type_name, surface("button" if state == "normal" else state))
		var focus: = StyleBoxFlat.new()
		focus.bg_color = Color.TRANSPARENT
		focus.border_color = Color("e2c66f")
		focus.set_border_width_all(2)
		focus.set_corner_radius_all(3)
		theme.set_stylebox("focus", type_name, focus)
		theme.set_color("font_color", type_name, Color("f1ead5"))
		theme.set_color("font_hover_color", type_name, Color("ffe9aa"))
		theme.set_color("font_pressed_color", type_name, Color("ffe9aa"))
		theme.set_color("font_disabled_color", type_name, Color("8e9298"))
	for type_name in ["PanelContainer", "ItemList", "PopupMenu", "AcceptDialog"]:
		theme.set_stylebox("panel", type_name, surface("panel"))
	var selected: = StyleBoxFlat.new()
	selected.bg_color = Color("444b3a")
	selected.border_color = Color("cdb66c")
	selected.border_width_left = 3
	selected.content_margin_left = 8
	for state in ["selected", "selected_focus", "hovered"]: theme.set_stylebox(state, "ItemList", selected)
	theme.set_stylebox("hover", "PopupMenu", selected)
	for type_name in ["Label", "ItemList", "PopupMenu", "RichTextLabel"]:
		theme.set_color("font_color", type_name, Color("e5e2d8"))
	theme.set_color("font_selected_color", "ItemList", Color("ffe6a3"))
	theme.set_font_size("font_size", "PopupMenu", 16)
	theme.set_constant("v_separation", "PopupMenu", 20)
	theme.set_constant("v_separation", "ItemList", 14)
	return theme
