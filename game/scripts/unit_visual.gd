class_name UnitVisual
extends RefCounted

## Map footprint (longest horizontal side, before the 0.65 marker scale) per unit type, so
## every original model reads at a consistent size against the cities instead of keeping
## whatever scale its source file happened to use.
const FOOTPRINT = UnitMapSize.FOOTPRINT
## Extra yaw (degrees) for source models that face backwards after long-axis alignment,
## keyed by model file prefix. Checked with tests/model_lineup.gd (all models face north).
const YAW_FIX: = {"su57": 180.0, "f18a": 180.0, "destroyer": 180.0, "kclass": 180.0, "upload20ab": 180.0, "ad": 180.0}  # ad_*: owner weapons.zip air defence (+X forward)
const RUSSIAN_CAMO: = "res://assets/materials/russian_blue_camo.png"
## Owner review (phone build): weapons must not look white. Ukrainian ground equipment gets
## a green/brown/black woodland scheme the same way Russian equipment gets the blue camo.
const UKRAINE_CAMO: = "res://assets/materials/ukraine_woodland_camo.png"
const GROUND_KINDS: = ["armor", "ifv", "artillery", "air_defense", "missile_launcher", "infantry", "support"]
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
## Models that ship in the website's start download, one per kind and side, shown while a unit's
## own model downloads on a phone.
static func download_stand_in(equipment_id: String, kind: String) -> String:
	var russian: bool = EquipmentIdentity.spec(equipment_id).get("country", GameSession.player_country) == "russia"
	match kind:
		"infantry": return "res://assets/library/arsenal/" + ("russia_motor_rifleman.glb" if russian else "euro_fr_foreign_legion.glb")
		"fighter": return "res://assets/library/arsenal/" + ("russia_yak130.glb" if russian else "euro_hawk_t2.glb")
		"air_defense": return "res://assets/library/airdefense/" + ("russia_strela10.glb" if russian else "nato_roland.glb")
		"naval": return ""
	return "res://assets/library/" + ("pl01_russian.glb" if russian else "pl01_european.glb")

static func stand_in_path(equipment_id: String, kind: String) -> String:
	var country: String = EquipmentIdentity.spec(equipment_id).get("country", GameSession.player_country)
	var russian: = country == "russia"
	match kind:
		"armor": return "res://assets/library/arsenal/russia_t90a.glb" if russian else "res://assets/library/arsenal/euro_leclerc.glb"
		"ifv": return "res://assets/library/upload661a_original.glb"
		"artillery": return "res://assets/library/upload7a7e_original.glb"
		"air_defense": return "res://assets/library/skyguard_" + ("russian" if russian else "european") + ".glb"
		"fighter": return "res://assets/library/arsenal/russia_su57.glb" if russian else "res://assets/library/arsenal/euro_mirage2000.glb"
		"missile_launcher": return "res://assets/library/arsenal/russia_iskander_m.glb" if russian else "res://assets/library/arsenal/euro_pluton.glb"
	return ""

## Fast, low-memory stand-in used during Android map startup and when a unit is
## off-camera. The real owner-supplied model is loaded only when needed on-screen.
static func lightweight(kind: String, faction: Color, equipment_id: String = "", level: int = 1) -> Node3D:
	var assembly := Node3D.new()
	assembly.set_meta("visual_level", level)
	assembly.set_meta("startup_lightweight", true)
	assembly.set_meta("missing_original_model", false)
	var mesh := MeshInstance3D.new()
	mesh.name = "LowMemoryMarker"
	var shape := BoxMesh.new()
	shape.size = Vector3(0.52, 0.26, 0.8)
	if kind in ["fighter", "bomber", "helicopter", "drone", "transport", "radar_aircraft"]:
		shape.size = Vector3(0.85, 0.14, 0.85)
	elif kind in ["naval", "carrier", "submarine"]:
		shape.size = Vector3(0.36, 0.2, 1.05)
	elif kind == "infantry":
		shape.size = Vector3(0.2, 0.45, 0.2)
	var spec := EquipmentIdentity.spec(equipment_id)
	var role: String = spec.get("role", "")
	if role.is_empty(): role = spec.get("visual_kind", kind)
	var path: String = EquipmentIdentity.research_tier(equipment_id, level).get("model", "")
	shape.size *= UnitMapSize.fit_factor(shape.size, role, path)
	mesh.position.y = shape.size.y * 0.5
	assembly.set_meta("pick_bounds", AABB(Vector3(-shape.size.x * 0.5, 0, -shape.size.z * 0.5), shape.size))
	assembly.set_meta("ground_shadow_size", Vector2(shape.size.x, shape.size.z) * 0.65)
	mesh.mesh = shape
	var material := StandardMaterial3D.new()
	material.albedo_color = faction
	material.roughness = 0.85
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	assembly.add_child(mesh)
	return assembly

static func create(kind: String, _faction: Color, equipment_id: String = "", level: int = 1) -> Node3D:
	var assembly: = Node3D.new()
	assembly.set_meta("visual_level", level)
	var tier: Dictionary = EquipmentIdentity.research_tier(equipment_id, level)
	var path: String = tier.get("model", asset_path(equipment_id))
	if not path.is_empty() and not WebExtras.has(path) and UnitSystem.mobile_device():
		# Phone browser: the real model is still downloading (WebExtras.has asked for it).
		# Owner 2026-10-15 ("the tanks are registering nothing"): show a vehicle from the start
		# download meanwhile instead of nothing; main._web_extras_loaded swaps the real one in.
		var interim: = download_stand_in(equipment_id, EquipmentIdentity.spec(equipment_id).get("visual_kind", kind))
		if interim.is_empty() or not WebExtras.has(interim):
			return _fallback(assembly, kind, equipment_id)
		path = interim
		assembly.set_meta("stand_in_model", true)
	if path.is_empty() or not WebExtras.has(path):
		var spec_kind: String = EquipmentIdentity.spec(equipment_id).get("visual_kind", kind)
		path = stand_in_path(equipment_id, spec_kind)
		assembly.set_meta("stand_in_model", true)
	assembly.set_meta("asset_path", path)
	assembly.set_meta("original_vehicle_asset", true)
	if path.is_empty() or not WebExtras.has(path):
		return _fallback(assembly, kind, equipment_id)
	var scene: = load(path) as PackedScene
	if scene == null:
		# A model that fails to load (low memory on a phone) is retried later, never left blank.
		push_warning("Unit model failed to load: " + path)
		return _fallback(assembly, kind, equipment_id)
	var vehicle: = scene.instantiate() as Node3D
	var launch_tip: Vector3 = Vector3.ZERO
	var has_launch_tip: bool = false
	if kind == "missile_launcher":
		for part in _meshes(vehicle, Transform3D.IDENTITY):
			if str(part[0].name) == "Nose":
				var nose: AABB = part[1] * part[0].get_aabb()
				launch_tip = part[1] * (part[0].get_aabb().get_center() + Vector3.RIGHT * part[0].get_aabb().size.x * 0.5)
				has_launch_tip = true
				break
	# Owner arsenal models are built from hundreds of parts; merge them per material so a
	# tank is a handful of draw calls on phones (looks identical).
	var helicopter: HelicopterAnimator
	if EquipmentIdentity.spec(equipment_id).get("role", "") in ["helicopter", "drone"]:
		helicopter = HelicopterAnimator.new()
		vehicle = helicopter.prepare(vehicle)
	elif path.contains("/arsenal/") and vehicle.find_child("Launcher_Pivot", true, false) == null and vehicle.find_child("SiloLid", true, false) == null: vehicle = merged(vehicle)
	var spec: = EquipmentIdentity.spec(equipment_id)
	var role: String = spec.get("role", "")
	if role.is_empty(): role = spec.get("visual_kind", kind)
	# Owner 2026-10-14 ("Where did you get the blue tanks?" - "whatever is in the research now"):
	# every unit keeps its model's own paint, so the map matches the research pictures. The blue
	# (Russia) and woodland (Ukraine) camouflage overlays (paint_camo) are no longer painted on.
	# The pivot carries the fitting transform; the source scene's own transform is kept.
	var pivot: = Node3D.new()
	pivot.name = "ModelFit"
	pivot.add_child(vehicle)
	_fit(pivot, vehicle, role, path)
	# Owner 2026-10-15: research levels that reuse one model can grow it (cargo ships, oil tankers).
	if tier.has("model_scale"): pivot.transform = Transform3D(Basis.from_scale(Vector3.ONE * float(tier.model_scale)), Vector3.ZERO) * pivot.transform
	assembly.add_child(pivot)
	_rig_erector(assembly, vehicle)
	if kind == "missile_launcher":
		var launch_point: = Marker3D.new()
		launch_point.name = "MissileLaunchPoint"
		assembly.add_child(launch_point)
		var launcher_bounds: AABB = model_bounds(pivot, 0.0)
		launch_point.position = pivot.transform * launch_tip if has_launch_tip else launcher_bounds.get_center() + Vector3.UP * launcher_bounds.size.y * 0.5
		if role == "silo": launch_point.position = pivot.transform * Vector3(0, 0.7, 0)
		assembly.set_meta("missile_launch_point", launch_point)
	if helicopter != null:
		assembly.add_child(helicopter)
		assembly.set_meta("helicopter_animator", helicopter)
	var fitted_bounds: AABB = model_bounds(pivot, 0.0)
	assembly.set_meta("ground_shadow_size", Vector2(fitted_bounds.size.x, fitted_bounds.size.z) * 0.65)
	_enable_shadows(vehicle)
	if path.contains("/airdefense/"):
		var animator: = AirDefenseAnimator.new()
		assembly.add_child(animator)
		animator.configure(vehicle, path.get_file().get_basename())
		assembly.set_meta("air_defense_animator", animator)
		assembly.set_meta("visual_level", level)
	assembly.set_meta("pick_bounds", model_bounds(assembly,0.0))
	if spec.get("visual_kind",kind) == "naval":
		for item in _meshes(assembly,Transform3D.IDENTITY): item[0].cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	assembly.set_meta("missing_original_model", false)
	return assembly

## Owner 2026-10-15 ("look at the tanks ... you can't see them again, and when they move, they
## don't appear"): when a unit's model cannot be loaded yet (downloading, or a phone short of
## memory) it is drawn as a simple model of its kind, built from a few shapes, instead of nothing.
## It stays marked missing so the real model is tried again every few seconds.
static var _fallback_meshes: Dictionary = {}
static func _fallback(assembly: Node3D, kind: String, equipment_id: String) -> Node3D:
	assembly.set_meta("missing_original_model", true)
	var spec: = EquipmentIdentity.spec(equipment_id)
	var role: String = spec.get("role", "")
	if role.is_empty(): role = spec.get("visual_kind", kind)
	var shape_kind: String = spec.get("visual_kind", kind)
	var russian: bool = spec.get("country", GameSession.player_country) == "russia"
	var key: = shape_kind + ":" + role + (":r" if russian else ":u")
	if not _fallback_meshes.has(key): _fallback_meshes[key] = _simple_mesh(shape_kind, role, russian)
	var vehicle: = Node3D.new()
	var body: = MeshInstance3D.new()
	body.mesh = _fallback_meshes[key]
	vehicle.add_child(body)
	var pivot: = Node3D.new()
	pivot.name = "ModelFit"
	pivot.add_child(vehicle)
	_fit(pivot, vehicle, role, "")
	assembly.add_child(pivot)
	var fitted: AABB = model_bounds(pivot, 0.0)
	assembly.set_meta("ground_shadow_size", Vector2(fitted.size.x, fitted.size.z) * 0.65)
	assembly.set_meta("pick_bounds", model_bounds(assembly, 0.0))
	assembly.set_meta("simple_model", true)
	return assembly

## One mesh per kind: hull, turret and gun for tanks, wings for aircraft and so on. Front is +Z.
static func _simple_mesh(kind: String, role: String, russian: bool) -> ArrayMesh:
	var paint: = StandardMaterial3D.new()
	paint.albedo_color = Color("5d6b4a") if russian else Color("55633f")
	paint.roughness = 0.8
	var dark: = StandardMaterial3D.new()
	dark.albedo_color = Color("2b2f27")
	dark.roughness = 0.9
	var light: = StandardMaterial3D.new()
	light.albedo_color = Color("9aa3a8")
	light.roughness = 0.6
	var parts: Array = []  # [mesh, transform, material]
	var box: = func(size: Vector3, at: Vector3, ink: Material) -> void:
		var m: = BoxMesh.new()
		m.size = size
		parts.append([m, Transform3D(Basis.IDENTITY, at), ink])
	var tube: = func(radius: float, length: float, at: Vector3, tilt: float, ink: Material) -> void:
		var m: = CylinderMesh.new()
		m.top_radius = radius
		m.bottom_radius = radius
		m.height = length
		m.radial_segments = 10
		parts.append([m, Transform3D(Basis(Vector3.RIGHT, PI * 0.5 - tilt), at), ink])
	if kind == "fighter" or role in ["helicopter", "drone", "bomber", "transport", "radar_aircraft"]:
		var hull: = light if not role in ["drone"] else paint
		tube.call(0.09, 1.3, Vector3(0, 0.12, 0), 0.0, hull)
		box.call(Vector3(1.2, 0.03, 0.32), Vector3(0, 0.12, -0.05), hull)
		box.call(Vector3(0.45, 0.03, 0.14), Vector3(0, 0.13, -0.55), hull)
		box.call(Vector3(0.03, 0.22, 0.16), Vector3(0, 0.25, -0.55), hull)
		box.call(Vector3(0.1, 0.06, 0.18), Vector3(0, 0.2, 0.35), dark)
	elif kind == "naval":
		box.call(Vector3(0.36, 0.16, 1.6), Vector3(0, 0.08, 0), light)
		box.call(Vector3(0.24, 0.18, 0.4), Vector3(0, 0.25, -0.1), light)
		box.call(Vector3(0.1, 0.22, 0.1), Vector3(0, 0.45, -0.1), dark)
		tube.call(0.025, 0.35, Vector3(0, 0.22, 0.5), 0.0, dark)
	elif kind == "infantry":
		box.call(Vector3(0.18, 0.28, 0.12), Vector3(0, 0.42, 0), paint)
		box.call(Vector3(0.07, 0.28, 0.08), Vector3(-0.05, 0.14, 0), paint)
		box.call(Vector3(0.07, 0.28, 0.08), Vector3(0.05, 0.14, 0), paint)
		box.call(Vector3(0.11, 0.11, 0.11), Vector3(0, 0.62, 0), dark)
		box.call(Vector3(0.03, 0.03, 0.34), Vector3(0.08, 0.44, 0.12), dark)
	else:
		# Tracked or wheeled vehicle: hull, running gear, then what sits on top.
		box.call(Vector3(0.5, 0.16, 0.95), Vector3(0, 0.17, 0), paint)
		box.call(Vector3(0.12, 0.14, 1.0), Vector3(-0.26, 0.07, 0), dark)
		box.call(Vector3(0.12, 0.14, 1.0), Vector3(0.26, 0.07, 0), dark)
		match kind:
			"armor", "ifv":
				box.call(Vector3(0.34, 0.13, 0.4), Vector3(0, 0.31, -0.05), paint)
				tube.call(0.025 if kind == "armor" else 0.018, 0.6 if kind == "armor" else 0.35, Vector3(0, 0.32, 0.38 if kind == "armor" else 0.25), 0.0, dark)
			"artillery":
				box.call(Vector3(0.36, 0.16, 0.45), Vector3(0, 0.33, -0.15), paint)
				tube.call(0.03, 0.8, Vector3(0, 0.45, 0.3), 0.35, dark)
			"air_defense":
				box.call(Vector3(0.3, 0.12, 0.3), Vector3(0, 0.31, -0.1), paint)
				box.call(Vector3(0.28, 0.2, 0.36), Vector3(0, 0.45, -0.1), paint)
				box.call(Vector3(0.22, 0.03, 0.18), Vector3(0, 0.58, -0.25), light)
			"missile_launcher":
				box.call(Vector3(0.36, 0.14, 0.62), Vector3(0, 0.32, -0.12), paint)
				tube.call(0.06, 0.7, Vector3(-0.09, 0.42, -0.05), 0.0, light)
				tube.call(0.06, 0.7, Vector3(0.09, 0.42, -0.05), 0.0, light)
			_:
				box.call(Vector3(0.44, 0.22, 0.5), Vector3(0, 0.36, -0.15), paint)
	var tools: Dictionary = {}
	var mesh: = ArrayMesh.new()
	for part in parts:
		var ink: Material = part[2] if part[2] is Material else dark
		if not tools.has(ink):
			var tool: = SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			tool.set_material(ink)
			tools[ink] = tool
		tools[ink].append_from(part[0], 0, part[1])
	for ink in tools: tools[ink].commit(mesh)
	return mesh

## Owner 2026-10-15 ("animate the arm coming up before a nuclear launch ... do this for all missile
## launchers"): every launcher model has a Launcher_Pivot hinged at the back of its tubes, so turning
## it raises the tube ends; CombatEffects raises it before each shot and fires from the tube mouth.
## The Yars / Topol-M also open the cap and slide the missile out (CombatEffects.raise_and_fire).
static func _rig_erector(assembly: Node3D, vehicle: Node3D) -> void:
	var arm: Node3D = vehicle.find_child("Launcher_Pivot", true, false)
	if arm == null:
		_rig_silo(assembly, vehicle)
		return
	var tube: MeshInstance3D = arm.find_child("Tube", true, false)
	var reach: = AABB()
	var parts: = _meshes(arm, Transform3D.IDENTITY)
	for i in parts.size():
		var box: AABB = (parts[i][1] as Transform3D) * (parts[i][0] as MeshInstance3D).mesh.get_aabb()
		reach = box if i == 0 else reach.merge(box)
	assembly.set_meta("erector_hinge", arm)
	assembly.set_meta("erector_mouth", Vector3(reach.end.x, reach.get_center().y, reach.get_center().z))
	assembly.set_meta("erector_missile", arm.find_child("Missile", true, false))
	assembly.set_meta("erector_cap", arm.find_child("CanisterCap", true, false))
	assembly.set_meta("erector_length", tube.get_aabb().size.x if tube != null else reach.size.x)

## Owner 2026-10-15 ("make the missile come out of the silo as well, then disappear"): silos keep
## their lid and missile as separate parts so CombatEffects.silo_launch can open the lid and raise
## the missile out of the shaft.
static func _rig_silo(assembly: Node3D, vehicle: Node3D) -> void:
	var lid: Node3D = vehicle.find_child("SiloLid", true, false)
	var missile: Node3D = vehicle.find_child("Missile", true, false)
	if lid == null or missile == null: return
	var length: = 0.0
	for part in _meshes(missile, Transform3D.IDENTITY):
		length = maxf(length, ((part[1] as Transform3D) * (part[0] as MeshInstance3D).mesh.get_aabb()).end.x)
	var cover: = AABB()
	var parts: = _meshes(lid, Transform3D.IDENTITY)
	for i in parts.size():
		var box: AABB = (parts[i][1] as Transform3D) * (parts[i][0] as MeshInstance3D).mesh.get_aabb()
		cover = box if i == 0 else cover.merge(box)
	assembly.set_meta("silo_lid", lid)
	assembly.set_meta("silo_missile", missile)
	assembly.set_meta("silo_lid_rest", lid.position)
	assembly.set_meta("silo_lid_slide", cover.size.x * 1.05)
	assembly.set_meta("silo_missile_rest", missile.position)
	# The missile rises until about two thirds of it stands above the ground.
	assembly.set_meta("silo_rise", -missile.position.y + length * 0.65)
	assembly.set_meta("silo_missile_length", length)

## Orient the model's long axis along the game's forward axis, scale it to the unit type's
## footprint and stand it on the ground at the marker's origin.
static func _fit(pivot: Node3D, vehicle: Node3D, role: String, path: String) -> void:
	var raw: = model_bounds(vehicle, 0.0)
	var yaw: = PI  # owner review 2026-10-09 ("undo"): guns face the direction of travel / target
	if raw.size.x > raw.size.z * 1.1: yaw += PI * 0.5  # source model lies sideways
	yaw += deg_to_rad(YAW_FIX.get(path.get_file().get_basename().get_slice("_", 0), 0.0))
	if owner_model(path): yaw = PI * 0.5  # Source +X cab faces game -Z.
	# Owner 2026-10-15 ("the drone is flying the wrong way"): the Geran-2 model points along +Z.
	if path.get_file().begins_with("russia_geran2") or path.get_file().begins_with("ukraine_liutyi"): yaw = PI  # built nose along +Z (tools/make_new_models.gd)
	var bounds: = model_bounds(vehicle, yaw)
	var factor := UnitMapSize.fit_factor(bounds.size, role, path)
	var center: = bounds.get_center()
	pivot.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * factor), Vector3(-center.x, 0.0 if role == "silo" else -bounds.position.y, -center.z) * factor)

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
	var tier: = EquipmentIdentity.research_tier(equipment_id,1)
	var stem: String = str(tier.get("model", "")).trim_suffix(".glb")
	for candidate in [str(tier.get("preview", "")),stem+"_ready.png",stem+".png",stem+"_preview.png"]:
		if not candidate.is_empty() and WebExtras.has(candidate): return load(candidate)
	var rendered: = "res://assets/library/previews/" + equipment_id + ".png"
	if WebExtras.has(rendered): return load(rendered)
	var path: = preview_path(equipment_id)
	if not path.is_empty() and WebExtras.has(path): return load(path)
	return load("res://assets/interface/icons/produce.svg")


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
