extends SceneTree
func _initialize() -> void:
	var failures: int = 0
	for id in ["skyguard_russia", "patriot_russia", "skyguard_ukraine", "patriot_ukraine"]:
		var previous: float = 0
		for level in range(1, 6):
			var tier: Dictionary = EquipmentIdentity.research_tier(id, level)
			var unit: Dictionary = {"equipment_id": id, "level": level, "health": 100.0, "visual_kind": "air_defense"}
			if tier.is_empty() or EquipmentIdentity.air_defense_range(unit) <= previous: failures += 1
			previous = EquipmentIdentity.air_defense_range(unit)
			if not is_equal_approx(AirBattleSystem.new().value(unit, "aa_damage"), float(tier.damage)): failures += 1
	if EquipmentIdentity.research_title("patriot_russia", 5) != "S-500 Prometey": failures += 1
	if not EquipmentIdentity.research_tier("t72", 3).is_empty(): failures += 1
	print("Air-defense tree: 42 checks, ", failures, " failures")
	quit(1 if failures else 0)
