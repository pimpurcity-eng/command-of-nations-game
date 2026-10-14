class_name FacilityVisual
extends RefCounted

static func preview(definition: Dictionary, country: String, level: int, rural: bool = false) -> Texture2D:
	var art := MenuArt.facility(definition)
	if art != null: return art
	var source: String = path(definition,country,level,rural)
	var supplied: String = source.trim_suffix(".glb")+"_menu.png"
	if WebExtras.has(supplied): return load(supplied)
	var fallback: String = str(AssetRoster.appearance(definition.asset_roster_id,country).get("preview", ""))
	# Browser version: pictures of buildings you don't have yet may still be downloading.
	return load(fallback) if WebExtras.has(fallback) else null

static func path(definition: Dictionary, country: String, level: int, rural: bool = false) -> String:
	var tiers: Array = definition.get("rural_model_tiers" if rural else "model_tiers", [])
	if not tiers.is_empty():
		# Browser version: higher levels arrive with the background download (WebExtras); until
		# then the building shows its own highest model that is already here.
		var index: = clampi(level - 1, 0, tiers.size() - 1)
		while index > 0 and not WebExtras.has(str(tiers[index])): index -= 1
		return str(tiers[index])
	return str(AssetRoster.appearance(definition.asset_roster_id, country).get("model", ""))

static func create(definition: Dictionary, country: String, level: int, rural: bool = false) -> Node3D:
	var source: String = path(definition, country, level, rural)
	var assembly: = Node3D.new()
	assembly.set_meta("facility_model", source)
	if not WebExtras.has(source):
		# Browser version: the model is still downloading; an empty marker is replaced as soon as it
		# arrives (an empty facility_model makes the next city sync rebuild it).
		assembly.set_meta("facility_model", "")
		return assembly
	var original: = (load(source) as PackedScene).instantiate() as Node3D
	if not source.contains("/buildings_oct12/") and not definition.get("normalize", false):
		assembly.add_child(original)
		return assembly
	var merged: = UnitVisual.merged(original)
	var box: = UnitVisual.model_bounds(merged, 0.0)
	var factor: = 7.0 / maxf(maxf(box.size.x, box.size.z), 0.001)
	var center: = box.get_center()
	merged.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * factor), Vector3(-center.x, -box.position.y, -center.z) * factor)
	assembly.add_child(merged)
	assembly.set_meta("original_colors", true)
	return assembly
