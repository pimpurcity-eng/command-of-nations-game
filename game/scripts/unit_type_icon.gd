class_name UnitTypeIcon
extends Control
## Map symbol for an army when the camera is zoomed out (owner request 2026-10-13): far away
## you see what KIND of unit it is (tank, infantry, artillery, missile, aircraft, ship, air
## defence, support); zoom in for the 3D model, closer still for the health bar.
## Drawn from the bold symbol pictures in assets/interface/unit_classes (UnitClasses).
var kind: = "armor"
var faction: = Color("ef827c")
var selected: = false
var hostile: = false
## Plain silhouette (no badge) in `ink`, for tabs and banners in the Call of War style.
var plain: = false
var ink: = Color("fff8ea")

static func silhouette(visual_kind: String, color: Color, minimum: Vector2) -> UnitTypeIcon:
	var icon: = UnitTypeIcon.new()
	icon.kind = visual_kind
	icon.plain = true
	icon.ink = color
	icon.custom_minimum_size = minimum
	return icon

static func category(visual_kind: String) -> String:
	match visual_kind:
		"armor", "ifv": return "tank"
		"infantry": return "infantry"
		"artillery": return "artillery"
		"missile_launcher": return "missile"
		"fighter", "bomber", "helicopter", "radar_aircraft": return "air"
		"naval", "carrier", "submarine": return "ship"
		"air_defense": return "air_defense"
		"drone": return "drone"
		"medic": return "medic"
	return "support"

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(30, 30)

func _draw() -> void:
	var r: = Rect2(Vector2.ZERO, size)
	var c: = r.get_center()
	var s: float = minf(size.x, size.y)
	# Badge: rounded square in the country colour, gold edge when selected, red edge for enemies at war.
	if not plain:
		var edge: Color = Color("f5cf82") if selected else (Color("d84a3a") if hostile else Color(0, 0, 0, 0.55))
		draw_style_box(_box(faction.darkened(0.15), edge), r)
	# Bold Call of War style symbol pictures (owner 2026-10-13: no more stick men).
	var picture: = UnitClasses.icon(UnitClasses.symbol(kind), ink)
	if picture == null: return
	var area: = r.grow(-s * (0.04 if plain else 0.14))
	var scale: = minf(area.size.x / picture.get_width(), area.size.y / picture.get_height())
	var drawn: = Vector2(picture.get_width(), picture.get_height()) * scale
	draw_texture_rect(picture, Rect2(area.get_center() - drawn * 0.5, drawn), false)

func _box(fill: Color, edge: Color) -> StyleBoxFlat:
	var box: = StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(6)
	box.set_border_width_all(2)
	box.border_color = edge
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 2
	return box
