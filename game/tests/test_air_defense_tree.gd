extends SceneTree
func _initialize() -> void:
	var failures: int = 0
	for id in ["skyguard_russia", "patriot_russia", "skyguard_ukraine", "patriot_ukraine"]:
		var previous: float = 0
		var previous_damage: = 0.0
		for level in range(1, 6):
			var tier: Dictionary = EquipmentIdentity.research_tier(id, level)
			var unit: Dictionary = UnitStats.specimen(id, level)
			if tier.is_empty() or EquipmentIdentity.air_defense_range(unit) <= previous:
				failures += 1
				push_error("FAIL " + "tier.is_empty() or EquipmentIdentity.air_defense_range(unit) <= previous")
			previous = EquipmentIdentity.air_defense_range(unit)
			var actual: = AirBattleSystem.new().value(unit, "aa_damage")
			var first: = EquipmentIdentity.research_tier(id, 1)
			var initial: = AirBattleSystem.new().value(UnitStats.specimen(id), "aa_damage")
			if actual <= previous_damage or not is_equal_approx(actual / initial, float(tier.damage) / float(first.damage)):
				failures += 1
				push_error("FAIL AA HP damage must increase with its tier, without double level scaling")
			previous_damage = actual

	if EquipmentIdentity.research_title("patriot_russia", 5) != "S-500 Prometey":
		failures += 1
		push_error("FAIL " + "EquipmentIdentity.research_title(\"patriot_russia\", 5) != \"S-500 Prometey\"")
	if not EquipmentIdentity.research_tier("t72", 3).is_empty():
		failures += 1
		push_error("FAIL " + "not EquipmentIdentity.research_tier(\"t72\", 3).is_empty()")
	var research: = ResearchSystem.new()
	var economy: = ProductionSystem.new()
	var clock: = SimulationClock.new()
	research.economy = economy
	research.clock = clock
	research.levels["patriot_russia"] = 4
	economy.stockpiles.russia = {}
	for resource in ProductionSystem.RESOURCES: economy.stockpiles.russia[resource] = 100000
	# The unlock day comes from the weapons data (CoW-style catalogue rebuild moved the S-500 later).
	var s500_day: int = research.unlock_day("patriot_russia", 5)
	clock.elapsed = (s500_day - 2) * 86400.0 / SimulationClock.REAL_SECONDS_PER_SIM_SECOND
	if research.start("patriot_russia", 5, "russia") != "Available on Day %d" % s500_day:
		failures += 1
		push_error("FAIL " + "research.start(\"patriot_russia\", 5, \"russia\") != \"Available on Day 18\"")
	clock.elapsed = (s500_day - 1) * 86400.0 / SimulationClock.REAL_SECONDS_PER_SIM_SECOND
	if not research.start("patriot_russia", 5, "russia").is_empty():
		failures += 1
		push_error("FAIL " + "not research.start(\"patriot_russia\", 5, \"russia\").is_empty()")
	if research.jobs.size() != 1:
		failures += 1
		push_error("FAIL " + "research.jobs.size() != 1")
	if research.unlock_day("t72", 5) != 6:
		failures += 1
		push_error("FAIL " + "research.unlock_day(\"t72\", 5) != 6")
	clock.free()
	print("Air-defense tree: 46 checks, ", failures, " failures")
	quit(1 if failures else 0)
