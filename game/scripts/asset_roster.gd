class_name AssetRoster
extends RefCounted

static var entries: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_roster.json"))

static func entry(id: String) -> Dictionary:
	for item in entries:
		if item.id == id: return item
	return {}

static func appearance(id: String, country: String) -> Dictionary:
	var item: = entry(id)
	if item.is_empty(): return {}
	var theme: = "shared" if item.shared_building else ("russian" if country == "russia" else "european")
	return item.assets.get(theme, {})

static func category_counts(country: String) -> Dictionary:
	var counts: Dictionary = {}
	for item in entries:
		if country not in item.available_to: continue
		counts[item.kind] = counts.get(item.kind, 0) + 1
	return counts
