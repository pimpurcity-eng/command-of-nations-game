class_name MapDefinition
extends RefCounted
## Geography and scenario selection. Gameplay continues through the shared campaign systems.
const REGIONAL: = "regional"
const EUROPE: = "europe20"
static var id: = REGIONAL
static var data: Dictionary = {}
static var _provinces: Dictionary = {}
static var _cities: Array = []

static func is_regional() -> bool: return id == REGIONAL or id.is_empty()
static func origin() -> Vector2:
	if is_regional(): return Vector2(-24,-27)
	return Vector2(data.frame.origin[0], data.frame.origin[1])
static func extent() -> Vector2:
	if is_regional(): return Vector2(50,48)
	return Vector2(data.frame.extent[0], data.frame.extent[1])
static func bounds() -> Rect2: return Rect2(origin(),extent())
static func save_path() -> String: return "user://regional_save.json" if is_regional() else "user://europe20_save.json"
static func scene_path() -> String: return "res://scenes/main.tscn" if is_regional() else "res://scenes/europe_campaign.tscn"
static func players() -> Array:
	return [{"id":"ukraine","name":"Ukraine","color":"376bba"},{"id":"russia","name":"Russia","color":"ad4741"}] if is_regional() else data.get("players",[])
static func countries() -> Array: return players() if is_regional() else data.get("players",[])+data.get("ai_countries",[])
static func country_name(country: String) -> String:
	for item in countries():
		if item.id == country: return item.name
	return country.replace("_"," ").capitalize()
static func country_color(country: String) -> Color:
	for item in countries():
		if item.id == country: return Color(item.color)
	return Color("9a9a8c")
static func provinces() -> Dictionary:
	if _provinces.is_empty() and not is_regional(): _provinces = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/europe20/provinces.json"))
	return _provinces
static func city_data() -> Array:
	if _cities.is_empty():
		var path: = "res://data/cities.json" if is_regional() else "res://data/maps/europe20/cities.json"
		_cities = JSON.parse_string(FileAccess.get_file_as_string(path))
	return _cities.duplicate(true)
static func use(map_id: String) -> void:
	assert(map_id in [REGIONAL,EUROPE])
	if map_id == id and (map_id == REGIONAL or not data.is_empty()): return
	id = map_id
	data = {} if is_regional() else JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/europe20/map.json"))
	_provinces.clear();_cities.clear()
	RegionData.country_cache.clear()
	TerrainVisualMap.reset()
	TerrainProfile.reload()
	ResourceSites._data.clear()
	CitySystem.plaza_offsets.clear()
	UnitSystem._city_points.clear()
	StrategicMap._towns.clear()
	GameSession.scenario_path = "res://data/scenario_regional.json" if is_regional() else "res://data/maps/europe20/scenario.json"
	EquipmentIdentity.catalog = CountryTraits.apply(EquipmentEconomy.apply(EquipmentRosters.catalogue()))
	EquipmentIdentity.refinements.clear()
	EconomyResearch._catalog.clear()
	GameSession.enemy_country = ""
	if not players().any(func(c):return c.id == GameSession.player_country): GameSession.player_country = "russia" if is_regional() else "poland"

static func launch(tree: SceneTree, map_id: String, country: String = "") -> void:
	if MatchClient.active != null: return
	var current: = tree.current_scene
	# A freshly booted home screen has not loaded the user's saved campaign yet.
	# Only write a paused, actually played match, never overwrite a save with that fresh world.
	if current != null and current.has_method("autosave") and bool(current.get("paused_to_home")): current.autosave()
	GameSession.weapons_test = false
	use(map_id)
	if not country.is_empty() and players().any(func(c):return c.id == country): GameSession.player_country = country
	tree.change_scene_to_file("res://scenes/startup.tscn")
