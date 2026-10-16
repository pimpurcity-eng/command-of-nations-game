class_name EquipmentRosters
extends RefCounted
## One research family per country. Countries share original model files, not research progress.
static func profile_id(spec: Dictionary) -> String:
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/unit_balance.json"))
	return str(spec.get("balance_profile",balance.families.get(spec.id,"motorized")))
static func rebase_id(id: String, source: String, country: String) -> String:
	var suffix: = "_"+source
	return id.trim_suffix(suffix)+"_"+country if id.ends_with(suffix) else id+"_"+country
static func catalogue() -> Array:
	var original: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/equipment.json"))
	if MapDefinition.is_regional(): return original
	var american: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/equipment_american.json"))
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/unit_balance.json"))
	var result: Array = []
	for country in MapDefinition.countries():
		var doctrine: = Doctrine.of(country.id)
		var source: = "russia" if doctrine == "russian" else "united_states" if doctrine == "american" else "ukraine"
		var source_catalog: Array = american if source == "united_states" else original
		for prototype in source_catalog:
			if prototype.country != source: continue
			# Retired regional IDs remain for old regional saves, never become new foreign units.
			if prototype.get("retired",false) and country.id not in ["russia","ukraine"]: continue
			var spec: Dictionary = prototype.duplicate(true)
			spec.id = rebase_id(prototype.id,source,country.id)
			spec.country = country.id
			spec.prototype_id = prototype.id
			spec.balance_profile = prototype.get("balance_profile",balance.families.get(prototype.id,"motorized"))
			result.append(spec)
	return result
static func family(country: String, profile: String) -> String:
	for spec in EquipmentIdentity.catalog:
		if spec.country == country and not spec.get("retired",false) and str(spec.get("balance_profile",UnitStats.balance.families.get(spec.id,""))) == profile: return spec.id
	return ""
