class_name TerrainRules
extends RefCounted
static var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain_modifiers.json"))
static func multiplier(kind: String, terrain: String, effect: String) -> float:
	return rules.get(terrain, {}).get(kind, {}).get(effect, 1.0)
static func unit_factor(unit: Dictionary, effect: String) -> float:
	if not unit.has("node") or unit.visual_kind in ["fighter", "naval"]: return 1.0
	var point: = Vector2(unit.node.position.x, unit.node.position.z)
	return multiplier(unit.visual_kind, TerrainProfile.sample(point), effect)
