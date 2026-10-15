extends SceneTree
## Export the values actually used by both the panels and the combat engine.
## UNIT_BALANCE_EXPORT_DIR=/absolute/path godot --headless --path game --script tools/export_unit_balance.gd
func _initialize() -> void:
	var folder: = OS.get_environment("UNIT_BALANCE_EXPORT_DIR")
	if folder.is_empty(): folder = "user://unit-balance"
	DirAccess.make_dir_recursive_absolute(folder)
	var file: = FileAccess.open(folder.path_join("unit-stats.csv"), FileAccess.WRITE)
	var header: PackedStringArray = ["equipment_id", "country", "doctrine", "level", "model_name", "role", "max_hp"]
	for target in UnitClasses.ALL: header.append_array(["attack_" + str(target), "defence_" + str(target)])
	header.append_array(["base_speed", "range", "funds", "materials", "electronics", "fuel", "food", "manpower", "urban_speed", "urban_attack", "urban_defence", "forest_attack", "forest_defence", "mountains_attack", "mountains_defence"])
	file.store_csv_line(header)
	var rows: = 0
	for family in EquipmentIdentity.catalog:
		for level in range(1, 6):
			var unit: = UnitStats.specimen(family.id, level)
			var values: PackedStringArray = [family.id, family.country, Doctrine.of(family.country), str(level), EquipmentIdentity.research_title(family.id, level), UnitStats.profile(unit).name, str(UnitStats.max_hp(unit))]
			for target in UnitClasses.ALL:
				values.append("%.3f" % (UnitStats.base_damage(unit, target) * Doctrine.combat_factor(unit, "attack")))
				values.append("%.3f" % (UnitStats.base_damage(unit, target, true) * Doctrine.combat_factor(unit, "defense")))
			values.append_array([str(UnitStats.speed(unit)), UnitStats.range_label(unit)])
			var bill: = EquipmentEconomy.cost(family, level)
			for resource in ["funds", "materials", "electronics", "fuel", "food", "manpower"]: values.append(str(bill[resource]))
			for pair in [["urban", "speed"], ["urban", "attack"], ["urban", "defense"], ["forest", "attack"], ["forest", "defense"], ["mountains", "attack"], ["mountains", "defense"]]:
				values.append(str(TerrainRules.for_unit(unit, pair[0], pair[1])))
			file.store_csv_line(values)
			rows += 1
	file.close()
	print("RESULT UNIT_BALANCE_EXPORT rows=", rows, " failures=", 0 if rows == EquipmentIdentity.catalog.size() * 5 else 1)
	quit(0 if rows == EquipmentIdentity.catalog.size() * 5 else 1)
