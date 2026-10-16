class_name TerrainRules
extends RefCounted
static var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain_modifiers.json"))
static func multiplier(kind: String, terrain: String, effect: String) -> float:
	return rules.get(terrain, {}).get(kind, {}).get(effect, 1.0)
static func unit_factor(unit: Dictionary, effect: String) -> float:
	return Doctrine.combat_factor(unit, effect) * _ground_factor(unit, effect)
## A specialist's terrain profile overrides its class only for the stated terrain/effect.
static func for_unit(unit: Dictionary, terrain: String, effect: String) -> float:
	if unit.get("visual_kind", "") in ["fighter", "naval"]: return 1.0
	var overrides: Dictionary = UnitStats.profile(unit).get("terrain", {}).get(terrain, {})
	return float(overrides.get(effect, multiplier(str(unit.get("visual_kind", "")), terrain, effect)))
static func _ground_factor(unit: Dictionary, effect: String) -> float:
	if not unit.has("node") or unit.visual_kind in ["fighter", "naval"]: return 1.0
	if effect == "defense" and unit.get("entrenched", false):
		return MatchSystem.ENTRENCH_BONUS * for_unit(unit, TerrainProfile.sample(Vector2(unit.node.position.x, unit.node.position.z)), effect)
	var point: = Vector2(unit.node.position.x, unit.node.position.z)
	return for_unit(unit, TerrainProfile.sample(point), effect)
