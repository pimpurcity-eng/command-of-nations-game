class_name HistoricalUnitCatalog
extends RefCounted
## Separate historical-mode definitions. Does not alter Warfront Mandate's equipment.json.
const PATH := "res://data/historical_units.json"
static var _roster: Dictionary = {}
static func roster() -> Dictionary:
    if _roster.is_empty():
        var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
        if decoded is Dictionary:
            _roster = decoded
    return _roster
static func eras() -> Array:
    return roster().get("eras", [])
static func all_units() -> Array:
    return roster().get("units", [])
static func unit_spec(id: String) -> Dictionary:
    for spec in all_units():
        if spec.get("id", "") == id:
            return spec
    return {}
static func units_unlocked(era_index: int, faction_id: String = "") -> Array:
    var available: Array = []
    for spec in all_units():
        if int(spec.get("unlock_era", 99)) > era_index:
            continue
        var limited: Array = spec.get("variant_factions", [])
        if not limited.is_empty() and faction_id not in limited:
            continue
        available.append(spec)
    return available
static func era_index(era_id: String) -> int:
    var list: Array = eras()
    for i in range(list.size()):
        if list[i].get("id", "") == era_id:
            return i
    return -1
static func reset_cache() -> void:
    _roster.clear()
