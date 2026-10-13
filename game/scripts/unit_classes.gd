class_name UnitClasses
extends RefCounted
## The six Call of War unit types (owner 2026-10-13: "categorize them ... doing that many
## different calculations will be crazy"). Every unit belongs to one; map labels show its
## symbol and every weapon attacks and defends against just these six.
##   infantry  - all foot soldiers
##   light     - APCs/IFVs, light tanks, trucks and support vehicles, artillery, rocket and
##               missile launchers, air defence
##   heavy     - main battle tanks
##   air       - jets, bombers, helicopters, drones, transport and radar aircraft
##   naval     - surface warships and carriers
##   submarine - submarines
const ALL: = ["infantry", "light", "heavy", "air", "naval", "submarine"]
const NAMES: = {"infantry": "Infantry", "light": "Light armour", "heavy": "Heavy armour", "air": "Planes", "naval": "Ships", "submarine": "Submarines"}
const ICON_DIR: = "res://assets/interface/unit_classes/"

## The class of a unit (or an equipment family dictionary).
static func of(unit: Dictionary) -> String:
	var id: String = str(unit.get("equipment_id", unit.get("id", "")))
	var spec: Dictionary = EquipmentIdentity.spec(id) if not id.is_empty() else {}
	var kind: String = str(unit.get("visual_kind", spec.get("visual_kind", "")))
	var role: String = str(spec.get("role", unit.get("role", "")))
	match kind:
		"infantry": return "infantry"
		"fighter", "bomber", "helicopter", "radar_aircraft": return "air"
		"naval", "carrier": return "submarine" if role == "submarine" else "naval"
		"submarine": return "submarine"
		"armor": return "light" if id.begins_with("light_tank") else "heavy"
	return "light"

## Symbol pictures: assets/interface/unit_classes/<class>.png, drawn from src/<class>.svg.
static var _icons: Dictionary = {}
## A symbol tinted `ink`; its white details (wheels, windows) become `detail` (or see-through).
static func icon(name: String, ink: Color = Color.BLACK, detail: Color = Color(1, 1, 1, 0)) -> Texture2D:
	var key: String = name + ":" + ink.to_html() + ":" + detail.to_html()
	if not _icons.has(key):
		var source: Texture2D = load(ICON_DIR + name + ".png")
		if source == null:
			_icons[key] = null
			return null
		var image: = source.get_image()
		image.convert(Image.FORMAT_RGBA8)
		for y in image.get_height():
			for x in image.get_width():
				var c: = image.get_pixel(x, y)
				if c.a <= 0.0: continue
				var dark: = 1.0 - c.v
				var out: Color = ink.lerp(detail, 1.0 - dark) if detail.a > 0.0 else Color(ink.r, ink.g, ink.b, ink.a * c.a * dark)
				if detail.a > 0.0: out.a = c.a
				image.set_pixel(x, y, out)
		_icons[key] = ImageTexture.create_from_image(image)
	return _icons[key]

## The symbol for any map/menu kind: only the six approved class icons are used (owner
## 2026-10-13: "six icons only"). Artillery, launchers, air defence and support vehicles are
## light armour; drones are planes.
static func symbol(kind: String) -> String:
	match kind:
		"armor", "tank", "heavy": return "heavy"
		"infantry", "medic": return "infantry"
		"fighter", "bomber", "helicopter", "radar_aircraft", "air", "drone": return "air"
		"naval", "carrier", "ship": return "naval"
		"submarine": return "submarine"
	return "light"
