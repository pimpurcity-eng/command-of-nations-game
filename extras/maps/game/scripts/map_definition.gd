class_name MapDefinition
extends RefCounted
## Which map is loaded. "regional" is the Russia–Ukraine campaign map (all the original
## hard-coded behaviour); other ids load data/maps/<id>/ (map.json + provinces.json), built by
## tools/build_europe_map.py. Switch with use() before building a StrategicMap.

const REGIONAL: = "regional"
const REGIONAL_ORIGIN: = Vector2(-24, -27)
const REGIONAL_EXTENT: = Vector2(50, 48)
static var id: = REGIONAL
static var data: Dictionary = {}
static var _colors: Dictionary = {}
static var _provinces: Dictionary = {}

static func use(map_id: String) -> void:
	if map_id == id: return
	id = map_id
	data = {}
	_colors = {}
	_provinces = {}
	if map_id != REGIONAL:
		data = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s/map.json" % map_id))
		for country in data.players + data.ai_countries: _colors[country.id] = Color(country.color)
	# Everything cached in map coordinates belongs to the previous map.
	RegionData.country_cache = []
	TerrainVisualMap.reset()
	TerrainProfile.reload()

static func is_regional() -> bool:
	# Empty while scripts that MapDefinition depends on run their static initializers.
	return id == REGIONAL or id.is_empty() or not data.has("projection")

static func origin() -> Vector2:
	if is_regional(): return REGIONAL_ORIGIN
	return Vector2(data.frame.origin[0], data.frame.origin[1])

static func extent() -> Vector2:
	if is_regional(): return REGIONAL_EXTENT
	return Vector2(data.frame.extent[0], data.frame.extent[1])

static func relief() -> Texture2D:
	return load("res://assets/materials/relief.png" if is_regional() else data.relief)

static func coast_mask() -> Texture2D:
	return load("res://assets/coast_mask.png" if is_regional() else data.coast_mask)

static func country_color(country_id: String) -> Color:
	return _colors.get(country_id, Color("9a9a8c"))

static func players() -> Array:
	return data.get("players", [])

static func is_player(country_id: String) -> bool:
	return players().any(func(c: Dictionary): return c.id == country_id)

static func country_name(country_id: String) -> String:
	for country in data.get("players", []) + data.get("ai_countries", []):
		if country.id == country_id: return country.name
	return country_id.capitalize()

## The map's provinces.json (features, outlines), parsed once.
static func provinces() -> Dictionary:
	if _provinces.is_empty() and not is_regional():
		_provinces = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s/provinces.json" % id))
	return _provinces
