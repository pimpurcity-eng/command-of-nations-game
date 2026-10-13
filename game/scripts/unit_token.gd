class_name UnitToken
extends Control
## Call of War style army marker (owner 2026-10-13, reference screenshots):
##  * "token" (zoomed out): a diamond with the unit-type symbol and the number of units.
##  * "tag" (zoomed in, beside the 3D model): small diamond, the unit count in a white pill
##    and a vertical five-segment health bar.
## White for your armies, red for enemies you are at war with, grey for others; gold edge
## when selected.
const TOKEN_SIZE: = Vector2(48, 48)
const TAG_SIZE: = Vector2(86, 30)
var mode: = "token"
var kind: = "armor"
var count: = 1
var health: = 100.0
var own: = true
var hostile: = false
var selected: = false
var symbol: UnitTypeIcon

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	symbol = UnitTypeIcon.silhouette("armor", Color.BLACK, Vector2(24, 20))
	add_child(symbol)

func refresh() -> void:
	custom_minimum_size = TOKEN_SIZE if mode == "token" else TAG_SIZE
	size = custom_minimum_size
	symbol.kind = kind
	symbol.ink = Color.WHITE if hostile else Color("1c1b18")
	if mode == "token":
		symbol.position = Vector2(12, 7)
		symbol.size = Vector2(24, 20)
	else:
		symbol.position = Vector2(5, 7)
		symbol.size = Vector2(18, 16)
	symbol.queue_redraw()
	queue_redraw()

func _fill() -> Color:
	if hostile: return Color("c8433a")
	return Color("f4f1e8") if own else Color("c9ccd1")

func _diamond(centre: Vector2, half: float) -> PackedVector2Array:
	return PackedVector2Array([centre + Vector2(0, -half), centre + Vector2(half, 0), centre + Vector2(0, half), centre + Vector2(-half, 0)])

func _draw() -> void:
	var font: = get_theme_default_font()
	var edge: = Color("f3c64f") if selected else Color(0.1, 0.1, 0.09, 0.85)
	var edge_width: = 3.0 if selected else 1.6
	if mode == "token":
		var centre: = size * 0.5
		var shape: = _diamond(centre, 22.0)
		draw_colored_polygon(_diamond(centre + Vector2(1.5, 2.5), 22.0), Color(0, 0, 0, 0.35))  # drop shadow
		draw_colored_polygon(shape, _fill())
		draw_polyline(shape + PackedVector2Array([shape[0]]), edge, edge_width, true)
		draw_string(font, Vector2(0, centre.y + 17), str(count), HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color.WHITE if hostile else Color("1c1b18"))
		return
	# Tag: pill with the count, diamond on the left, health segments on the right.
	var pill: = Rect2(Vector2(14, 4), Vector2(52, 22))
	var back: = StyleBoxFlat.new()
	back.bg_color = Color("f4f1e8")
	back.set_corner_radius_all(4)
	back.border_color = edge
	back.set_border_width_all(int(edge_width))
	back.shadow_color = Color(0, 0, 0, 0.3)
	back.shadow_size = 2
	draw_style_box(back, pill)
	draw_string(font, Vector2(30, 21), str(count), HORIZONTAL_ALIGNMENT_CENTER, 34, 16, Color("1c1b18"))
	var shape: = _diamond(Vector2(14, 15), 14.0)
	draw_colored_polygon(shape, _fill())
	draw_polyline(shape + PackedVector2Array([shape[0]]), edge, edge_width, true)
	var frame: = Rect2(Vector2(68, 2), Vector2(14, 26))
	draw_rect(frame, Color(0.08, 0.09, 0.07, 0.85))
	var filled: = clampi(ceili(health / 20.0), 0, 5)
	var colour: = Color("6cc04a") if health >= 60 else (Color("e0b84a") if health >= 30 else Color("d65448"))
	for i in 5:
		var segment: = Rect2(Vector2(70, 24 - i * 5 - 3), Vector2(10, 4))
		draw_rect(segment, colour if i < filled else Color(0.3, 0.32, 0.28))
