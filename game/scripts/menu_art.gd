class_name MenuArt
extends RefCounted
## One model-specific picture shared by research, city production and every unit card.
const CACHE_LIMIT := 32
static var _manifest: Dictionary = {}
static var _cache: Dictionary = {}
static func manifest() -> Dictionary:
	if _manifest.is_empty(): _manifest = JSON.parse_string(FileAccess.get_file_as_string("res://data/menu_art.json"))
	return _manifest
static func texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path): return null
	if _cache.has(path):
		var value: Texture2D = _cache[path]
		_cache.erase(path); _cache[path] = value
		return value
	var value := load(path) as Texture2D
	if value != null:
		if _cache.size() >= CACHE_LIMIT: _cache.erase(_cache.keys()[0])
		_cache[path] = value
	return value
static func unit(model: String) -> Texture2D:
	return texture(str(manifest().get("models", {}).get(model, "")))
static func facility(definition: Dictionary) -> Texture2D:
	var pictures: Dictionary = manifest().get("buildings", {})
	return texture(str(pictures.get(definition.get("id", ""), pictures.get(definition.get("asset_roster_id", ""), ""))))
static func city(country: String) -> Texture2D:
	return texture(str(manifest().get("cities", {}).get(country, "")))
