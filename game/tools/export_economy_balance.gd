extends SceneTree
## Exact runtime prices and durations at 1x, 4x and 10x for review in a spreadsheet.
const HOUR: = 3600.0 / SimulationClock.REAL_SECONDS_PER_SIM_SECOND
func _initialize() -> void:
	var folder: = OS.get_environment("UNIT_BALANCE_EXPORT_DIR")
	if folder.is_empty(): folder = "user://unit-balance"
	DirAccess.make_dir_recursive_absolute(folder)
	var economy: = ProductionSystem.new()
	var research: = ResearchSystem.new()
	research.economy = economy
	var file: = FileAccess.open(folder.path_join("unit-economy.csv"), FileAccess.WRITE)
	var header: PackedStringArray = ["equipment_id","country","role","level","research_only","base_production_hours_1x","production_hours_factory_L1_1x","production_hours_factory_L1_4x","production_hours_factory_L1_10x","research_hours_1x","research_hours_4x","research_hours_10x","refinement_hours_1x","modernization_hours_1x","world_minimum_funds"]
	for prefix in ["production_", "research_", "refinement_", "daily_upkeep_", "modernization_"]:
		for resource in ProductionSystem.RESOURCES: header.append(prefix + resource)
	file.store_csv_line(header)
	var rows: = 0
	for spec in economy.catalog:
		for level in range(1, 6):
			var unit: = UnitStats.specimen(spec.id, level)
			var production_hours: = economy.duration(spec.id, level) / HOUR
			var country_hours: = production_hours / CountryTraits.build_factor(spec.country)
			var research_hours: = research.duration(level, spec.id) / research.rate(spec.country) / HOUR
			var refinement_hours: = research.upgrade_duration(level, spec.id) / research.rate(spec.country) / HOUR if level < 5 else 0.0
			var values: PackedStringArray = [spec.id, spec.country, UnitStats.profile_id(unit), str(level), str(spec.get("research_only",false)), str(production_hours), str(country_hours), str(country_hours / 4), str(country_hours / 10), str(research_hours), str(research_hours / 4), str(research_hours / 10), str(refinement_hours), str(production_hours * 0.5), str(TransportMarket.minimum_price(unit))]
			var bill: = economy.cost(spec.id, level)
			var modernization: Dictionary = {}
			for resource in bill: modernization[resource] = ceili(float(bill[resource]) * 0.5)
			for costs in [bill, research.cost(spec.id, level), research.upgrade_cost(spec.id, level) if level < 5 else {}, EquipmentEconomy.upkeep(spec, level), modernization]:
				for resource in ProductionSystem.RESOURCES: values.append(str(costs.get(resource, 0)))
			file.store_csv_line(values)
			rows += 1
	file.close()
	var buildings: = BuildingSystem.new()
	file = FileAccess.open(folder.path_join("building-economy.csv"), FileAccess.WRITE)
	header = ["building","level","base_hours_1x","europe_hours_no_infrastructure_1x","europe_hours_no_infrastructure_4x","europe_hours_no_infrastructure_10x"]
	for prefix in ["cost_", "legacy_cost_"]:
		for resource in ProductionSystem.RESOURCES: header.append(prefix + resource)
	file.store_csv_line(header)
	var building_rows: = 0
	for spec in buildings.catalog:
		if spec.get("retired", false): continue
		for level in range(1, int(spec.max_level) + 1):
			var hours: = buildings.duration(spec.id, level) / HOUR
			var european: = hours / CountryTraits.build_factor("ukraine")
			var values: PackedStringArray = [spec.id, str(level), str(hours), str(european), str(european / 4), str(european / 10)]
			for costs in [buildings.cost(spec.id, level), buildings.previous_cost(spec.id, level)]:
				for resource in ProductionSystem.RESOURCES: values.append(str(costs.get(resource, 0)))
			file.store_csv_line(values)
			building_rows += 1
	file.close()
	print("RESULT ECONOMY_EXPORT unit_rows=", rows, " building_rows=", building_rows, " failures=", 0 if rows == 470 else 1)
	quit(0 if rows == 470 else 1)
