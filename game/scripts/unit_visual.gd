class_name UnitVisual
extends RefCounted

static func asset_path(equipment_id: String) -> String:
	if equipment_id == "t90": return "res://assets/library/t90m_original.glb"
	var equipment: = EquipmentIdentity.spec(equipment_id)
	var roster_id: String = equipment.get("asset_roster_id", {"armata": "armata", "abrams": "abrams"}.get(equipment_id, ""))
	if roster_id.is_empty(): return ""
	return AssetRoster.appearance(roster_id, equipment.get("country", GameSession.player_country)).get("model", "")

static func preview_path(equipment_id: String) -> String:
	var equipment: = EquipmentIdentity.spec(equipment_id)
	var roster_id: String = equipment.get("asset_roster_id", {"t90": "t90m", "armata": "armata", "abrams": "abrams"}.get(equipment_id, ""))
	return AssetRoster.appearance(roster_id, equipment.get("country", GameSession.player_country)).get("preview", "")

static func create(_kind: String, _faction: Color, equipment_id: String = "") -> Node3D:
	var assembly: = Node3D.new()
	var path: = asset_path(equipment_id)
	assembly.set_meta("asset_path", path)
	assembly.set_meta("original_vehicle_asset", true)
	if path.is_empty() or not ResourceLoader.exists(path):
		assembly.set_meta("missing_original_model", true)
		return assembly
	var vehicle: = (load(path) as PackedScene).instantiate() as Node3D
	vehicle.rotation.y = PI
	assembly.add_child(vehicle)
	assembly.set_meta("missing_original_model", false)
	return assembly

static func preview_texture(equipment_id: String) -> Texture2D:
	var path: = preview_path(equipment_id)
	if not path.is_empty() and ResourceLoader.exists(path): return load(path)
	var country: String = EquipmentIdentity.spec(equipment_id).get("country", GameSession.player_country)
	return load("res://assets/vehicles/" + country + "_flag.png")
