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
## Owner 2026-10-16: "Unit movements, they're faster on their own territory. Different things
## affect." Call of War style: armies march 25% faster on their own or allied land (right of way,
## coalition), and 20% slower on enemy or neutral land. Terrain (data/terrain_modifiers.json),
## roads (province infrastructure) and railways (TradeNetwork.rail_factor) stack on top.
const OWN_TERRITORY_SPEED: = 1.25
const FOREIGN_TERRITORY_SPEED: = 0.8
static func territory_speed(mover: String, owner: String, diplomacy: Diplomacy = null) -> float:
	if owner.is_empty() or mover.is_empty(): return 1.0
	if owner == mover: return OWN_TERRITORY_SPEED
	if diplomacy != null and not diplomacy.at_war(mover, owner) and diplomacy.right_of_way(mover, owner): return OWN_TERRITORY_SPEED
	return FOREIGN_TERRITORY_SPEED
static func territory_label(factor: float) -> String:
	if factor > 1.0: return "own territory +%d%%" % roundi((factor - 1.0) * 100.0)
	if factor < 1.0: return "foreign territory −%d%%" % roundi((1.0 - factor) * 100.0)
	return ""
