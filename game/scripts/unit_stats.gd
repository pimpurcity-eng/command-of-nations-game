class_name UnitStats
extends RefCounted
## Shared unit balance. Damage is HP; saved `health` is still 0..100 condition, so old
## saves, multiplayer snapshots, forced march and percentage-based recovery keep working.
static var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/unit_balance.json"))

static func profile_id(unit: Dictionary) -> String:
	var id: String = str(unit.get("equipment_id", unit.get("id", "")))
	if balance.families.has(id): return balance.families[id]
	# Older saved/catalogue unit IDs retain a sensible role; current families have explicit entries.
	var spec: Dictionary = EquipmentIdentity.spec(id)
	if spec.has("balance_profile"): return str(spec.balance_profile)
	var role: String = str(spec.get("role", unit.get("role", "")))
	if role in ["submarine", "carrier", "supply", "recovery", "engineer", "bridge", "medic"]: return role
	match str(unit.get("visual_kind", spec.get("visual_kind", "infantry"))):
		"armor": return "light_tank" if id.begins_with("light_tank") else "mbt"
		"ifv": return "ifv"
		"artillery": return "sp_artillery"
		"air_defense": return "long_aa" if id.begins_with("patriot") else "short_aa"
		"missile_launcher": return "tactical_missile"
		"fighter": return "fighter"
		"naval": return "frigate"
		"support": return "supply"
	return "motorized"

static func profile(unit: Dictionary) -> Dictionary:
	return balance.profiles[profile_id(unit)]

static func specimen(id: String, level: int = 1, country: String = "") -> Dictionary:
	var spec: Dictionary = EquipmentIdentity.spec(id)
	return {"equipment_id": id, "visual_kind": spec.get("visual_kind", "infantry"),
		"country": spec.get("country", "") if country.is_empty() else country,
		"level": clampi(level, 1, 5), "health": 100.0}

static func max_hp(unit: Dictionary) -> float:
	var values: Array = profile(unit).hp
	return float(roundi(float(values[clampi(int(unit.get("level", 1)) - 1, 0, 4)]) * Doctrine.hp_factor(unit)))

static func condition(unit: Dictionary) -> float:
	return clampf(float(unit.get("health", 100.0)) / 100.0, 0.0, 1.0)

static func current_hp(unit: Dictionary) -> float:
	return max_hp(unit) * condition(unit)

static func hp_label(unit: Dictionary) -> String:
	return "%s / %d" % [number(current_hp(unit)), roundi(max_hp(unit))]

static func number(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value

## Convert once, at the target, before existing systems apply simultaneous damage.
static func condition_damage(unit: Dictionary, hp: float) -> float:
	return maxf(0.0, hp) * 100.0 / maxf(1.0, max_hp(unit))

static func base_damage(unit: Dictionary, target: String, defending: bool = false) -> float:
	var role: Dictionary = profile(unit)
	var row: Dictionary = role.defense if defending else role.attack
	var growth: float = balance.level_damage[clampi(int(unit.get("level", 1)) - 1, 0, 4)]
	# AA research tiers already have their own progression. Do not multiply level growth twice.
	if unit.get("visual_kind", "") == "air_defense" and target == "air":
		var first: Dictionary = EquipmentIdentity.research_tier(str(unit.equipment_id), 1)
		var tier: Dictionary = EquipmentIdentity.research_tier(str(unit.equipment_id), int(unit.get("level", 1)))
		if float(first.get("damage", 0)) > 0: growth = float(tier.get("damage", first.damage)) / float(first.damage)
	return float(row.get(target, 0.0)) * growth * EquipmentIdentity.upgrade_factor(unit)

static func damage(unit: Dictionary, target: String, defending: bool = false) -> float:
	if condition(unit) <= 0.0: return 0.0
	return base_damage(unit, target, defending) * (0.2 + 0.8 * condition(unit))

static func group_hp(group: Array) -> Vector2:
	var result: = Vector2.ZERO
	for unit in group:
		result.x += current_hp(unit)
		result.y += max_hp(unit)
	return result

static func speed(unit: Dictionary) -> float:
	var kind: String = str(unit.get("visual_kind", ""))
	var spec: Dictionary = EquipmentIdentity.spec(str(unit.get("equipment_id", "")))
	if kind == "fighter": return float(spec.get("air_speed", 3.0))
	if kind == "naval": return float(spec.get("sea_speed", 1.2))
	if kind in ["artillery", "missile_launcher"]: return 1.0
	if kind == "ifv": return 1.6
	if kind == "air_defense": return 0.9
	return 1.4

static func range_label(unit: Dictionary) -> String:
	var kind: String = str(unit.get("visual_kind", ""))
	var spec: Dictionary = EquipmentIdentity.spec(str(unit.get("equipment_id", "")))
	if kind == "fighter": return "%s game km operating radius" % number(float(spec.get("air_range", 14.0)) * 40.0)
	if kind == "air_defense": return "%s game km air defence" % number(EquipmentIdentity.air_defense_range(unit) * 40.0)
	if kind == "naval": return "%s game km naval fire" % number(float(spec.get("sea_range", 2.8)) * 40.0)
	if kind == "artillery": return "96 game km artillery"
	if kind == "missile_launcher": return "%s game km strike" % number(float(spec.get("strike_range", 8.0)) * 40.0)
	return "Close combat"
