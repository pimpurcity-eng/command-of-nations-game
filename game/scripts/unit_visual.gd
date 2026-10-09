class_name UnitVisual
extends RefCounted

## Map footprint (longest horizontal side, before the 0.65 marker scale) per unit type, so
## every original model reads at a consistent size against the cities instead of keeping
## whatever scale its source file happened to use.
const FOOTPRINT: = {"bomber": 2.3, "armor": 1.35, "ifv": 1.25, "artillery": 1.3, "air_defense": 1.3, "missile_launcher": 1.4, "fighter": 1.5, "drone": 1.1, "naval": 1.9}
## Extra yaw (degrees) for source models that face backwards after long-axis alignment,
## keyed by model file prefix. Checked with tests/model_lineup.gd (all models face north).
const YAW_FIX: = {"su57": 180.0, "f18a": 180.0, "destroyer": 180.0, "kclass": 180.0, "upload20ab": 180.0, "ad": 180.0}  # ad_*: owner weapons.zip air defence (+X forward)
const RUSSIAN_CAMO: = "res://assets/materials/russian_blue_camo.png"
## Owner review (phone build): weapons must not look white. Ukrainian ground equipment gets
## a green/brown/black woodland scheme the same way Russian equipment gets the blue camo.
const UKRAINE_CAMO: = "res://assets/materials/ukraine_woodland_camo.png"
const GROUND_KINDS: = ["armor", "ifv", "artillery", "air_defense", "missile_launcher"]
static var _camo_shader: Shader
## Camouflage materials are created once and shared by every unit using the same model and
## paint. Per-unit materials were freed together with a destroyed/replaced unit while the
## GL Compatibility renderer still referenced them ('Parameter "material" is null').
static var _camo_materials: Dictionary = {}

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

## Equipment whose own original model has not been recovered yet (Leopard 2, Challenger 2,
## Oplot, ...) is shown with an original model of the same role instead of being invisible.
## Replace by adding the real model to assets/library and data/asset_roster.json.
static func stand_in_path(equipment_id: String, kind: String) -> String:
	var country: String = EquipmentIdentity.spec(equipment_id).get("country", GameSession.player_country)
	var russian: = country == "russia"
	match kind:
		"armor": return "res://assets/library/t90m_original.glb" if russian else "res://assets/library/abrams_european.glb"
		"ifv": return "res://assets/library/upload661a_original.glb"
		"artillery": return "res://assets/library/upload7a7e_original.glb"
		"air_defense": return "res://assets/library/skyguard_" + ("russian" if russian else "european") + ".glb"
		"fighter": return "res://assets/library/su57_russian.glb" if russian else "res://assets/library/f18a_european.glb"
	return ""

static func create(kind: String, _faction: Color, equipment_id: String = "", level: int = 1) -> Node3D:
	var assembly: = Node3D.new()
	assembly.set_meta("visual_level", level)
	var tier: Dictionary = EquipmentIdentity.research_tier(equipment_id, level)
	var path: String = tier.get("model", asset_path(equipment_id))
	if path.is_empty() or not ResourceLoader.exists(path):
		var spec_kind: String = EquipmentIdentity.spec(equipment_id).get("visual_kind", kind)
		path = stand_in_path(equipment_id, spec_kind)
		assembly.set_meta("stand_in_model", true)
	assembly.set_meta("asset_path", path)
	assembly.set_meta("original_vehicle_asset", true)
	if path.is_empty() or not ResourceLoader.exists(path):
		assembly.set_meta("missing_original_model", true)
		return assembly
	var vehicle: = (load(path) as PackedScene).instantiate() as Node3D
	# Owner arsenal models are built from hundreds of parts; merge them per material so a
	# tank is a handful of draw calls on phones (looks identical).
	if path.contains("/arsenal/"): vehicle = merged(vehicle)
	var spec: = EquipmentIdentity.spec(equipment_id)
	var role: String = spec.get("role", "")
	if role.is_empty(): role = spec.get("visual_kind", kind)
	var keep_colors: bool = AssetRoster.appearance(spec.get("asset_roster_id", ""), spec.get("country", GameSession.player_country)).get("original_colors", false)
	if owner_model(path) or keep_colors: pass  # Preserve supplied original paint.
	elif spec.get("country", "") == "russia": paint_russian(vehicle, model_bounds(vehicle, 0.0))
	elif spec.get("visual_kind", kind) in GROUND_KINDS: paint_camo(vehicle, model_bounds(vehicle, 0.0), UKRAINE_CAMO)
	# The pivot carries the fitting transform; the source scene's own transform is kept.
	var pivot: = Node3D.new()
	pivot.name = "ModelFit"
	pivot.add_child(vehicle)
	_fit(pivot, vehicle, role, path)
	assembly.add_child(pivot)
	var fitted_bounds: AABB = model_bounds(pivot, 0.0)
	assembly.set_meta("ground_shadow_size", Vector2(fitted_bounds.size.x, fitted_bounds.size.z) * 0.65)
	_enable_shadows(vehicle)
	if path.contains("/airdefense/"):
		var animator: = AirDefenseAnimator.new()
		assembly.add_child(animator)
		animator.configure(vehicle, path.get_file().get_basename())
		assembly.set_meta("air_defense_animator", animator)
		assembly.set_meta("visual_level", level)
	assembly.set_meta("missing_original_model", false)
	return assembly

## Orient the model's long axis along the game's forward axis, scale it to the unit type's
## footprint and stand it on the ground at the marker's origin.
static func _fit(pivot: Node3D, vehicle: Node3D, role: String, path: String) -> void:
	var raw: = model_bounds(vehicle, 0.0)
	var yaw: = PI  # owner review 2026-10-09 ("undo"): guns face the direction of travel / target
	if raw.size.x > raw.size.z * 1.1: yaw += PI * 0.5  # source model lies sideways
	yaw += deg_to_rad(YAW_FIX.get(path.get_file().get_basename().get_slice("_", 0), 0.0))
	if owner_model(path): yaw = PI * 0.5  # Source +X cab faces game -Z.
	var bounds: = model_bounds(vehicle, yaw)
	var longest: = maxf(maxf(bounds.size.x, bounds.size.z), 0.001)
	var factor: float = FOOTPRINT.get(role, 0.62) / longest
	# Owner arsenal tanks/APCs keep their real relative size (an M113 is smaller than a
	# Leopard): 0.145 map units per metre, ~1.35 for a 9.4 m tank.
	if path.contains("/arsenal/") and role in ["armor", "ifv"]: factor = 0.145
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
	paint_camo(vehicle, bounds, RUSSIAN_CAMO)

static func paint_camo(vehicle: Node, bounds: AABB, pattern_path: String) -> void:
	var pattern: Texture2D = load(pattern_path)
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
			var key: = "%d:%.4f:%s" % [base.get_instance_id(), tiles, pattern_path]
			if _camo_materials.has(key):
				mesh_instance.set_surface_override_material(surface, _camo_materials[key])
				continue
			if base.albedo_texture != null and base.resource_name.to_lower().contains("paint"):
				# Converted models with a dedicated paint material: swap the pattern on its UVs.
				var blue: = base.duplicate() as BaseMaterial3D
				blue.albedo_texture = pattern
				blue.albedo_color = Color.WHITE
				_camo_materials[key] = blue
				mesh_instance.set_surface_override_material(surface, blue)
				continue
			var textured: = base.albedo_texture != null
			if not textured and not _is_hull_paint(base.albedo_color): continue
			var camo: = ShaderMaterial.new()
			camo.shader = _camo_shader
			camo.set_shader_parameter("camo", pattern)
			camo.set_shader_parameter("tiles", tiles)
			camo.set_shader_parameter("use_original", textured)
			if textured:
				camo.set_shader_parameter("original", base.albedo_texture)
				camo.set_shader_parameter("original_tint", base.albedo_color)
			camo.set_shader_parameter("roughness_value", base.roughness)
			_camo_materials[key] = camo
			mesh_instance.set_surface_override_material(surface, camo)

## Plain painted hull colours (olive/grey, mid luminance, sRGB as Godot reports them).
## Tracks, rubber, optics and lights are darker, brighter or saturated and keep their colour.
static func _is_hull_paint(color: Color) -> bool:
	var luminance: = color.get_luminance()
	return luminance > 0.43 and luminance < 0.62 and color.s < 0.3

static func preview_texture(equipment_id: String) -> Texture2D:
	# Menu pictures rendered from the unit's own 3D model (tests/render_previews.gd).
	var rendered: = "res://assets/library/previews/" + equipment_id + ".png"
	if ResourceLoader.exists(rendered): return load(rendered)
	var path: = preview_path(equipment_id)
	if not path.is_empty() and ResourceLoader.exists(path): return load(path)
	var country: String = EquipmentIdentity.spec(equipment_id).get("country", GameSession.player_country)
	return load("res://assets/vehicles/" + country + "_flag.png")


# The fitted model's front is -Z (base yaw PI; the 20AB truck needs its 180-degree fix so its
# cab, not its launcher rack, faces -Z).
static func firing_heading(_equipment_id: String, direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)

static func _enable_shadows(node: Node) -> void:
	if node is GeometryInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for child in node.get_children(): _enable_shadows(child)

## Models supplied by the owner (air defence and the tank/APC/aircraft arsenal): original
## paint, +X forward.
static func owner_model(path: String) -> bool:
	return path.contains("/airdefense/") or path.contains("/arsenal/")

## One MeshInstance3D holding every mesh of `source`, one surface per material.
static var _merged_meshes: Dictionary = {}
static func merged(source: Node3D) -> Node3D:
	var key: = source.scene_file_path
	var root: = Node3D.new()
	root.name = source.name
	var visual: = MeshInstance3D.new()
	visual.name = "Merged"
	if not key.is_empty() and _merged_meshes.has(key):
		visual.mesh = _merged_meshes[key]
	else:
		var tools: = {}
		var order: = []
		for item in _meshes(source, Transform3D.IDENTITY):
			var mesh_instance: MeshInstance3D = item[0]
			for surface in mesh_instance.mesh.get_surface_count():
				var material: = mesh_instance.get_active_material(surface)
				if not tools.has(material):
					var tool: = SurfaceTool.new()
					tool.begin(Mesh.PRIMITIVE_TRIANGLES)
					tool.set_material(material)
					tools[material] = tool
					order.append(material)
				tools[material].append_from(mesh_instance.mesh, surface, item[1])
		var mesh: = ArrayMesh.new()
		for material in order: tools[material].commit(mesh)
		visual.mesh = mesh
		if not key.is_empty(): _merged_meshes[key] = mesh
	root.add_child(visual)
	source.free()
	return root
