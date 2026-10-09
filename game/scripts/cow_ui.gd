class_name CowUI
extends RefCounted
## Shared look for the full-screen menus (city, research), modelled on the Call of War
## screens the owner sent: dark header with a centred title and square close button, dark
## status boxes, a tab row, and a light list of picture rows with green action buttons.
const DARK: = Color("23272b")
const DARKER: = Color("1a1d20")
const LINE: = Color("4a4f52")
const GOLD: = Color("e9c46a")
const LIST: = Color("cdc8b6")
const ROW: = Color("dcd7c6")
const INK: = Color("2a2a26")
const GREEN: = Color("4f8a3a")
const RED: = Color("b5413a")

## Textured 9-patch from assets/interface/skin (tools/make_ui_skin.py).
static func skin(name: String, corner: int = 8, margin: int = 0, tint: Color = Color.WHITE) -> StyleBoxTexture:
	var style: = StyleBoxTexture.new()
	style.texture = load("res://assets/interface/skin/" + name + ".png")
	style.set_texture_margin_all(corner)
	style.set_content_margin_all(margin)
	style.modulate_color = tint
	return style

static func title_font() -> Font:
	return StrategyTheme.font("Oswald", 600)

static func box(color: Color, radius: int = 0, border: Color = Color(0, 0, 0, 0), width: int = 0, margin: int = 0) -> StyleBoxFlat:
	var style: = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = border
	style.set_border_width_all(width)
	style.set_content_margin_all(margin)
	return style

static func label(text: String, size: int, color: Color = Color("efe6cf")) -> Label:
	var result: = Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	if size >= 18: result.add_theme_font_override("font", title_font())
	return result

## Square framed button holding an icon (close, back).
static func square(kind: String) -> Button:
	var button: = Button.new()
	button.custom_minimum_size = Vector2(52, 52)
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, skin("frame", 10, 0, Color.WHITE if state == "normal" else Color(1.15, 1.1, 1.0)))
	var icon: = Icon.new(kind, GOLD, Vector2(52, 52))
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(icon)
	return button

## Dark header: optional back button, centred title, close button.
static func header(title_text: String, with_back: bool) -> Dictionary:
	var bar: = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", skin("header", 4, 8))
	var row: = HBoxContainer.new()
	bar.add_child(row)
	var back: = square("back")
	back.modulate.a = 1.0 if with_back else 0.0
	back.disabled = not with_back
	row.add_child(back)
	var title: = label(title_text, 32, Color("f3e6c4"))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	row.add_child(title)
	var close: = square("close")
	row.add_child(close)
	return {"bar": bar, "title": title, "back": back, "close": close}

## Dark status box ("No construction", "No research"): icon + text + progress bar.
static func status_box(kind: String) -> Dictionary:
	var panel: = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.y = 84
	panel.add_theme_stylebox_override("panel", skin("inset", 10, 10))
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var picture: = TextureRect.new()
	picture.custom_minimum_size = Vector2(56, 56)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.visible = false
	row.add_child(picture)
	var icon: Control = StrategyHUD.Glyph.new(kind, Color("ece6d6"), Vector2(44, 56), 0.9) if kind in ["produce", "research"] else Icon.new(kind, Color("ece6d6"), Vector2(44, 56))
	row.add_child(icon)
	var column: = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(column)
	var text: = label("", 17, Color("ece6d6"))
	text.add_theme_font_override("font", StrategyTheme.font("RobotoCondensed", 500))
	text.clip_text = true
	column.add_child(text)
	var bar: = ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 8
	bar.add_theme_stylebox_override("background", box(Color("3a3f42"), 2))
	bar.add_theme_stylebox_override("fill", box(Color("b8863b"), 2))
	bar.visible = false
	column.add_child(bar)
	return {"panel": panel, "picture": picture, "icon": icon, "text": text, "bar": bar}

## Tab row button (icon above caption); `selected` gets the gold underline.
static func tab(caption: String, kind: String, selected: bool) -> Button:
	var button: = Button.new()
	button.custom_minimum_size = Vector2(84, 64)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, skin("tab_on" if selected else "tab_off", 6, 0, Color.WHITE if state == "normal" or selected else Color(1.2, 1.2, 1.2)))
	var column: = VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(column)
	if not kind.is_empty():
		var icon: Control = StrategyHUD.Glyph.new(kind, GOLD, Vector2(28, 26)) if kind in ["produce", "research", "city", "flag"] else Icon.new(kind, GOLD, Vector2(28, 26))
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(icon)
	var text: = label(caption, 14, GOLD if selected else Color("e3d9bd"))
	text.add_theme_font_override("font", title_font())
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(text)
	return button

## Green (or red) action button with an icon above its caption, like CONSTRUCT.
static func action(caption: String, kind: String, color: Color = GREEN) -> Button:
	var button: = Button.new()
	button.custom_minimum_size = Vector2(118, 56)
	var face: = "btn_red" if color == RED else ("btn_dark" if color == DARK else "btn_green")
	for state in ["normal", "hover", "pressed", "disabled"]:
		var texture: = "btn_grey" if state == "disabled" else (face + "_pressed" if state == "pressed" and face == "btn_green" else face)
		button.add_theme_stylebox_override(state, skin(texture, 12, 0, Color(1.12, 1.12, 1.12) if state == "hover" else Color.WHITE))
	var column: = VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(column)
	if not kind.is_empty():
		var icon: = Icon.new(kind, Color.WHITE, Vector2(24, 24))
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(icon)
	var text: = label(caption, 13, Color.WHITE)
	text.add_theme_font_override("font", title_font())
	text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	text.add_theme_constant_override("shadow_offset_y", 1)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(text)
	button.set_meta("caption", text)
	return button

## Resource cost: icon with the amount underneath (red when unaffordable).
static func cost(resource: String, amount: float, enough: bool) -> VBoxContainer:
	var column: = VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon: = TextureRect.new()
	icon.texture = ResourceSites.icon(resource)
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(icon)
	var value: = label(short(amount), 13, INK if enough else Color("b0302a"))
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(value)
	return column

static func short(amount: float) -> String:
	if amount >= 1000000: return "%.1fm" % (amount / 1000000.0)
	if amount >= 1000: return "%.1fk" % (amount / 1000.0)
	return str(int(amount))

## Section caption in the light list ("Unit production").
static func section(text: String) -> Label:
	var caption: = label(text, 20, INK)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.custom_minimum_size.y = 48
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return caption

## Small vector icons not in the HUD set: hammer, clock, back, close.
class Icon extends Control:
	var kind: String
	var tint: Color
	func _init(icon_kind: String, color: Color, minimum: Vector2) -> void:
		kind = icon_kind
		tint = color
		custom_minimum_size = minimum
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c: = size * 0.5
		var u: = minf(size.x, size.y) / 24.0
		if tint.get_luminance() > 0.5:
			# Soft drop shadow under light icons so they read as embossed, not flat.
			var keep: = tint
			tint = Color(0, 0, 0, 0.45)
			draw_set_transform(Vector2(1.2, 1.6) * u)
			_shape(c, u)
			draw_set_transform(Vector2.ZERO)
			tint = keep
		_shape(c, u)
	func _shape(c: Vector2, u: float) -> void:
		match kind:
			"hammer":
				draw_line(c + Vector2(-4, -2) * u, c + Vector2(5, 9) * u, tint, 2.6 * u)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-9, -5) * u, c + Vector2(-2, -10) * u, c + Vector2(2, -6) * u, c + Vector2(-5, -1) * u]), tint)
			"clock":
				draw_arc(c, 8 * u, 0, TAU, 24, tint, 1.8 * u)
				draw_line(c, c + Vector2(0, -5) * u, tint, 1.8 * u)
				draw_line(c, c + Vector2(4, 1) * u, tint, 1.8 * u)
			"back":
				draw_polyline(PackedVector2Array([c + Vector2(4, -9) * u, c + Vector2(-5, 0) * u, c + Vector2(4, 9) * u]), tint, 3.2 * u)
			"close":
				draw_line(c + Vector2(-8, -8) * u, c + Vector2(8, 8) * u, tint, 3.2 * u)
				draw_line(c + Vector2(8, -8) * u, c + Vector2(-8, 8) * u, tint, 3.2 * u)
			"flask":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-3, -9) * u, c + Vector2(3, -9) * u, c + Vector2(3, -2) * u, c + Vector2(9, 9) * u, c + Vector2(-9, 9) * u, c + Vector2(-3, -2) * u]), tint)
			"chevrons":
				for dx in [-4, 4]: draw_polyline(PackedVector2Array([c + Vector2(dx - 4, -7) * u, c + Vector2(dx + 3, 0) * u, c + Vector2(dx - 4, 7) * u]), tint, 3.0 * u)
