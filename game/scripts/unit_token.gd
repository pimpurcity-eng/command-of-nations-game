class_name UnitToken
extends Control
## Call of War style army label (owner approved preview, 2026-10-13): a plate with the bold
## symbol of the army's unit type (UnitClasses), the number of units, and five health bars
## beside it. White for your armies, red for enemies you are at war with, grey for others;
## gold edge when selected. "token" (zoomed out) is a slightly smaller plate than "tag".
const TOKEN_SIZE: = Vector2(54, 27)  # owner 2026-10-15: tags were bigger than the tanks
const TAG_SIZE: = Vector2(58, 28)
## Owner 2026-10-15 ("can't see health bar"): a full-width bar under the plate.
const BAR_HEIGHT: = 6.0
var mode: = "token"
## Map class (UnitClasses.ALL) or menu kind; picks the symbol.
var kind: = "heavy"
var count: = 1
var health: = 100.0
var own: = true
var hostile: = false
var selected: = false

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func refresh() -> void:
	custom_minimum_size = TOKEN_SIZE if mode == "token" else TAG_SIZE
	size = custom_minimum_size
	queue_redraw()

func _fill() -> Color:
	if hostile: return Color("c63a30")
	return Color("faf8f2") if own else Color("c9ccd1")

func _draw() -> void:
	var font: = get_theme_default_font()
	var ink: = Color.WHITE if hostile else Color("161614")
	var plate: = Rect2(Vector2(1, 1), Vector2(size.x - 2, size.y - BAR_HEIGHT - 3))
	var face: = StyleBoxFlat.new()
	face.bg_color = _fill()
	face.set_corner_radius_all(6)
	face.border_color = Color("f3c440") if selected else Color(0.08, 0.08, 0.07, 0.9)
	face.set_border_width_all(3 if selected else 1)
	face.shadow_color = Color(0, 0, 0, 0.35)
	face.shadow_size = 3
	face.shadow_offset = Vector2(1, 2)
	draw_style_box(face, plate)
	# Symbol on the left, divider, count on the right.
	var split: = plate.position.x + plate.size.x * 0.62
	var picture: = UnitClasses.icon(UnitClasses.symbol(kind), ink)
	if picture != null:
		var area: = Rect2(plate.position + Vector2(5, 4), Vector2(split - plate.position.x - 9, plate.size.y - 8))
		var scale: = minf(area.size.x / picture.get_width(), area.size.y / picture.get_height())
		var drawn: = Vector2(picture.get_width(), picture.get_height()) * scale
		draw_texture_rect(picture, Rect2(area.get_center() - drawn * 0.5, drawn), false)
	draw_line(Vector2(split, plate.position.y + 5), Vector2(split, plate.end.y - 5), Color(1, 1, 1, 0.6) if hostile else Color(0.55, 0.53, 0.5), 1.0)
	var font_size: = 13
	draw_string(font, Vector2(split, plate.get_center().y + font_size * 0.36), str(count), HORIZONTAL_ALIGNMENT_CENTER, plate.end.x - split, font_size, ink)
	# Health bar under the plate: green, yellow below 60%, red below 30%.
	var bar: = Rect2(Vector2(3, size.y - BAR_HEIGHT - 1), Vector2(size.x - 6, BAR_HEIGHT))
	draw_rect(bar.grow(1.0), Color(0.04, 0.05, 0.04, 0.95))
	draw_rect(bar, Color(0.25, 0.26, 0.24))
	var colour: = Color("62c848") if health >= 60 else (Color("e0b84a") if health >= 30 else Color("d65448"))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(health / 100.0, 0.0, 1.0), bar.size.y)), colour)
