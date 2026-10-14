extends SceneTree
## Loads every offered unit picture through the same helpers as the research and unit cards.

var checks := 0
var failures := 0

func verify(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: ", description)

func _initialize() -> void:
	for level in range(1, 6):
		verify(EquipmentIdentity.roman_level(level) == ["I", "II", "III", "IV", "V"][level - 1], "Roman level " + str(level))
	var models := {}
	var picture_owners := {}
	var canonical_previews := {}
	var cards := 0
	for spec in EquipmentIdentity.catalog:
		if spec.get("retired", false):
			continue
		for level in range(1, 6):
			cards += 1
			var tier := EquipmentIdentity.research_tier(spec.id, level)
			var model: String = tier.model
			var canonical := EquipmentIdentity.picture_tier(spec.id, level)
			verify(str(canonical.get("model", "")) == model, "Selected unit identity: " + spec.id)
			var preview: String = str(canonical.get("preview", ""))
			if canonical_previews.has(model):
				verify(canonical_previews[model] == preview, "Upgrades reuse their original preview: " + model)
			canonical_previews[model] = preview
			var path: String = MenuArt.manifest().models.get(model, "")
			verify(not path.is_empty(), "Picture mapping: " + spec.id + " level " + str(level))
			verify(ResourceLoader.exists(path), "Installed artwork: " + path)
			if models.has(model):
				verify(models[model] == path, "Same model keeps one shared picture: " + model)
			models[model] = path
			if picture_owners.has(path):
				verify(picture_owners[path] == model, "Different models have different pictures: " + path)
			picture_owners[path] = model
			var texture := MenuArt.unit(model)
			verify(texture != null and texture.get_width() > 0 and texture.get_height() > 0, "Decoded picture: " + path)
			verify(CowUI.research_picture(spec.id, level) == texture, "Research uses the assigned picture: " + spec.id)
			verify(CowUI.equipment_picture(spec.id, level) == texture, "Production and selected unit use the same picture: " + spec.id)
	verify(cards == 420, "All 420 research cards checked")
	verify(models.size() == 161, "All 161 distinct unit models checked")
	verify(picture_owners.size() == 161, "Every distinct model has its own picture")
	print("UNIT_ART_COVERAGE checks=", checks, " failures=", failures, " cards=", cards, " unique_models=", models.size())
	quit(0 if failures == 0 else 1)
