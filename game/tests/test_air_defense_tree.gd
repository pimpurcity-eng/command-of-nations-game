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
	var research: = ResearchSystem.new()
	var economy: = ProductionSystem.new()
	var clock: = SimulationClock.new()
	research.economy = economy
	research.clock = clock
	research.levels["patriot_russia"] = 4
	economy.stockpiles.russia = {}
	for resource in ProductionSystem.RESOURCES: economy.stockpiles.russia[resource] = 100000
	clock.elapsed = 16 * 86400.0 / SimulationClock.REAL_SECONDS_PER_SIM_SECOND
	if research.start("patriot_russia", 5, "russia") != "Available on Day 18": failures += 1
	clock.elapsed = 17 * 86400.0 / SimulationClock.REAL_SECONDS_PER_SIM_SECOND
	if not research.start("patriot_russia", 5, "russia").is_empty(): failures += 1
	if research.jobs.size() != 1: failures += 1
	if research.unlock_day("t72", 5) != 6: failures += 1
	clock.free()
	print("Air-defense tree: 46 checks, ", failures, " failures")
	quit(1 if failures else 0)
