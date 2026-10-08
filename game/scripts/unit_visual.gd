class_name UnitVisual
extends RefCounted

## Map footprint (longest horizontal side, before the 0.65 marker scale) per unit type, so
## every original model reads at a consistent size against the cities instead of keeping
## whatever scale its source file happened to use.
const FOOTPRINT: = {"armor": 0.95, "ifv": 0.9, "artillery": 0.95, "air_defense": 0.95, "missile_launcher": 1.0, "fighter": 1.15, "drone": 0.8, "naval": 1.5}
## Extra yaw (degrees) for source models that face backwards after long-axis alignment,
## keyed by model file prefix. Checked with tests/model_lineup.gd (all models face north).
const YAW_FIX: = {"su57": 180.0, "f18a": 180.0, "destroyer": 180.0, "kclass": 180.0, "upload20ab": 180.0}
const RUSSIAN_CAMO: = "res://assets/materials/russian_blue_camo.png"
static var _camo: Texture2D
static var _camo_shader: Shader

static func asset_path(equipment_id: String) -> String:
	# T-90M: the owner's original T90m.fbx. (The *_russian conversion lost the gun barrel.)
	if equipment_id == "t90": return "res://assets/library/t90m_original.glb"
	var equipment: = EquipmentIdentity.spec(equipment_id)
	var roster_id: String = equipment.get("asset_roster_id", {"armata": "armata", "abrams": "abrams"}.get(equipment_id, ""))
	if roster_id.is_empty(): return ""
	return AssetRoster.appearance(roster_id, equipment.get("country", GameSession.player_country)).get("model", "")

static func preview_path(equipment_id: String) -> String:
	var equipment: = EquipmentIdentity.spec(equipment_id)
	var roster_id: String = equipment.get("asset_roster_id", {"t90": "t90m", "armata": "armata", "abrams": "abrams"}.get(equipment_id, ""))
	return AssetRoster.appearance(roster_id, equipment.get("country", GameSession.player_country)).get("preview", "")

static func create(kind: String, _faction: Color, equipment_id: String = "") -> Node3D:
	var assembly: = Node3D.new()
	var path: = asset_path(equipment_id)
	assembly.set_meta("asset_path", path)
	assembly.set_meta("original_vehicle_asset", true)
	if path.is_empty() or not ResourceLoader.exists(path):
		assembly.set_meta("missing_original_model", true)
		return assembly
	var vehicle: = (load(path) as PackedScene).instantiate() as Node3D
	var spec: = EquipmentIdentity.spec(equipment_id)
	var role: String = spec.get("role", "")
	if role.is_empty(): role = spec.get("visual_kind", kind)
	if spec.get("country", "") == "russia": paint_russian(vehicle, model_bounds(vehicle, 0.0))
	# The pivot carries the fitting transform; the source scene's own transform is kept.
	var pivot: = Node3D.new()
	pivot.name = "ModelFit"
	pivot.add_child(vehicle)
	_fit(pivot, vehicle, role, path)
	assembly.add_child(pivot)
	assembly.set_meta("missing_original_model", false)
	return assembly

## Orient the model's long axis along the game's forward axis, scale it to the unit type's
## footprint and stand it on the ground at the marker's origin.
static func _fit(pivot: Node3D, vehicle: Node3D, role: String, path: String) -> void:
	var raw: = model_bounds(vehicle, 0.0)
	var yaw: = PI
	if raw.size.x > raw.size.z * 1.1: yaw += PI * 0.5  # source model lies sideways
	yaw += deg_to_rad(YAW_FIX.get(path.get_file().get_basename().get_slice("_", 0), 0.0))
	var bounds: = model_bounds(vehicle, yaw)
	var longest: = maxf(maxf(bounds.size.x, bounds.size.z), 0.001)
	var factor: float = FOOTPRINT.get(role, 0.62) / longest
	var center: = bounds.get_center()
	pivot.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * factor), Vector3(-center.x, -bounds.position.y, -center.z) * factor)

## Bounds of every mesh under (and including) `vehicle`, after turning it by `yaw`.
static func model_bounds(vehicle: Node3D, yaw: float) -> AABB:
	var turn: = Transform3D(Basis(Vector3.UP, yaw), Vector3.ZERO)
	var items: = _meshes(vehicle, vehicle.transform)
	if vehicle is MeshInstance3D and (vehicle as MeshInstance3D).mesh != null: items.append([vehicle, vehicle.transform])
	var result: = AABB()
	for i in items.size():
		var box: AABB = turn * (items[i][1] as Transform3D) * (items[i][0] as MeshInstance3D).mesh.get_aabb()
		result = box if i == 0 else result.merge(box)
	return result

static func _meshes(node: Node, to_root: Transform3D) -> Array:
	var found: Array = []
	for child in node.get_children():
		if child is Node3D:
			var t: Transform3D = to_root * (child as Node3D).transform
			if child is MeshInstance3D and (child as MeshInstance3D).mesh != null: found.append([child, t])
			found.append_array(_meshes(child, t))
	return found

## Russian equipment gets the Su-57-inspired blue splinter camouflage on its paint surfaces.
## Only materials (paint) change; the original model geometry is untouched.
static func paint_russian(vehicle: Node, bounds: AABB) -> void:
	if _camo == null: _camo = load(RUSSIAN_CAMO)
	if _camo_shader == null: _camo_shader = load("res://assets/russian_camo.gdshader")
	# Untextured originals (e.g. the T-90M) get the camouflage projected triplanar in model
	# space: about two pattern repeats along the hull.
	var tiles: = 2.0 / maxf(maxf(bounds.size.x, bounds.size.z), 0.001)
	var items: = _meshes(vehicle, Transform3D.IDENTITY)
	if vehicle is MeshInstance3D: items.append([vehicle, Transform3D.IDENTITY])
	for item in items:
		var mesh_instance: MeshInstance3D = item[0]
		if mesh_instance.mesh == null: continue
		for surface in mesh_instance.mesh.get_surface_count():
			var material: = mesh_instance.get_active_material(surface)
			if not (material is BaseMaterial3D): continue
			var base: = material as BaseMaterial3D
			if base.albedo_texture != null and base.resource_name.to_lower().contains("paint"):
				# Converted models with a dedicated paint material: swap the pattern on its UVs.
				var blue: = base.duplicate() as BaseMaterial3D
				blue.albedo_texture = _camo
				blue.albedo_color = Color.WHITE
				mesh_instance.set_surface_override_material(surface, blue)
				continue
			var textured: = base.albedo_texture != null
			if not textured and not _is_hull_paint(base.albedo_color): continue
			var camo: = ShaderMaterial.new()
			camo.shader = _camo_shader
			camo.set_shader_parameter("camo", _camo)
			camo.set_shader_parameter("tiles", tiles)
			camo.set_shader_parameter("use_original", textured)
			if textured:
				camo.set_shader_parameter("original", base.albedo_texture)
				camo.set_shader_parameter("original_tint", base.albedo_color)
			camo.set_shader_parameter("roughness_value", base.roughness)
			mesh_instance.set_surface_override_material(surface, camo)

## Plain painted hull colours (olive/grey, mid luminance, sRGB as Godot reports them).
## Tracks, rubber, optics and lights are darker, brighter or saturated and keep their colour.
static func _is_hull_paint(color: Color) -> bool:
	var luminance: = color.get_luminance()
	return luminance > 0.43 and luminance < 0.62 and color.s < 0.3

static func preview_texture(equipment_id: String) -> Texture2D:
	var path: = preview_path(equipment_id)
	if not path.is_empty() and ResourceLoader.exists(path): return load(path)
	var country: String = EquipmentIdentity.spec(equipment_id).get("country", GameSession.player_country)
	return load("res://assets/vehicles/" + country + "_flag.png")
