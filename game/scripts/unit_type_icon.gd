class_name UnitTypeIcon
extends Control
## Map symbol for an army when the camera is zoomed out (owner request 2026-10-13): far away
## you see what KIND of unit it is (tank, infantry, artillery, missile, aircraft, ship, air
## defence, support); zoom in for the 3D model, closer still for the health bar.
## Drawn with vectors (no textures), in the owner's country colour.
var kind: = "armor"
var faction: = Color("ef827c")
var selected: = false
var hostile: = false

static func category(visual_kind: String) -> String:
	match visual_kind:
		"armor", "ifv": return "tank"
		"infantry": return "infantry"
		"artillery": return "artillery"
		"missile_launcher": return "missile"
		"fighter", "bomber", "helicopter", "drone", "radar_aircraft": return "air"
		"naval", "carrier", "submarine": return "ship"
		"air_defense": return "air_defense"
	return "support"

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(30, 30)

func _draw() -> void:
	var r: = Rect2(Vector2.ZERO, size)
	var c: = r.get_center()
	var s: float = minf(size.x, size.y)
	# Badge: rounded square in the country colour, gold edge when selected, red edge for enemies at war.
	var edge: Color = Color("f5cf82") if selected else (Color("d84a3a") if hostile else Color(0, 0, 0, 0.55))
	draw_style_box(_box(faction.darkened(0.15), edge), r)
	var ink: = Color("fff8ea")
	var u: float = s / 30.0
	match category(kind):
		"tank":
			draw_rect(Rect2(c + Vector2(-9, -1) * u, Vector2(18, 7) * u), ink)            # hull
			draw_rect(Rect2(c + Vector2(-5, -6) * u, Vector2(9, 5) * u), ink)             # turret
			draw_line(c + Vector2(4, -4) * u, c + Vector2(12, -6) * u, ink, 2.0 * u)      # gun
			for x in [-7, -2, 3, 8]: draw_circle(c + Vector2(x, 7) * u, 1.6 * u, ink)    # wheels
		"infantry":
			draw_circle(c + Vector2(0, -7) * u, 3.0 * u, ink)
			draw_line(c + Vector2(0, -4) * u, c + Vector2(0, 4) * u, ink, 2.4 * u)
			draw_line(c + Vector2(-6, -1) * u, c + Vector2(6, -1) * u, ink, 2.0 * u)
			draw_line(c + Vector2(0, 4) * u, c + Vector2(-5, 10) * u, ink, 2.0 * u)
			draw_line(c + Vector2(0, 4) * u, c + Vector2(5, 10) * u, ink, 2.0 * u)
		"artillery":
			draw_line(c + Vector2(-6, 3) * u, c + Vector2(10, -8) * u, ink, 2.6 * u)     # barrel
			draw_rect(Rect2(c + Vector2(-9, 2) * u, Vector2(14, 4) * u), ink)             # carriage
			draw_circle(c + Vector2(-5, 8) * u, 3.0 * u, ink)
			draw_circle(c + Vector2(4, 8) * u, 3.0 * u, ink)
		"missile":
			var body: = PackedVector2Array([c + Vector2(0, -11) * u, c + Vector2(3, -6) * u, c + Vector2(3, 6) * u, c + Vector2(-3, 6) * u, c + Vector2(-3, -6) * u])
			draw_colored_polygon(body, ink)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-3, 3) * u, c + Vector2(-7, 9) * u, c + Vector2(-3, 7) * u]), ink)
			draw_colored_polygon(PackedVector2Array([c + Vector2(3, 3) * u, c + Vector2(7, 9) * u, c + Vector2(3, 7) * u]), ink)
		"air":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -11) * u, c + Vector2(2, -3) * u, c + Vector2(11, 2) * u, c + Vector2(11, 4) * u, c + Vector2(2, 2) * u, c + Vector2(2, 7) * u, c + Vector2(5, 10) * u, c + Vector2(-5, 10) * u, c + Vector2(-2, 7) * u, c + Vector2(-2, 2) * u, c + Vector2(-11, 4) * u, c + Vector2(-11, 2) * u, c + Vector2(-2, -3) * u]), ink)
		"ship":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-12, 1) * u, c + Vector2(12, 1) * u, c + Vector2(8, 7) * u, c + Vector2(-9, 7) * u]), ink)
			draw_rect(Rect2(c + Vector2(-4, -5) * u, Vector2(8, 6) * u), ink)
			draw_line(c + Vector2(1, -5) * u, c + Vector2(1, -10) * u, ink, 1.6 * u)
		"air_defense":
			draw_arc(c + Vector2(0, 2) * u, 8.0 * u, PI, TAU, 14, ink, 2.2 * u)          # radar dish
			draw_line(c + Vector2(0, 2) * u, c + Vector2(6, -7) * u, ink, 2.0 * u)
			draw_rect(Rect2(c + Vector2(-8, 4) * u, Vector2(16, 4) * u), ink)
		_:
			draw_rect(Rect2(c + Vector2(-10, -3) * u, Vector2(13, 8) * u), ink)           # truck
			draw_rect(Rect2(c + Vector2(4, -1) * u, Vector2(6, 6) * u), ink)
			draw_circle(c + Vector2(-6, 7) * u, 2.2 * u, ink)
			draw_circle(c + Vector2(6, 7) * u, 2.2 * u, ink)

func _box(fill: Color, edge: Color) -> StyleBoxFlat:
	var box: = StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(6)
	box.set_border_width_all(2)
	box.border_color = edge
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 2
	return box
