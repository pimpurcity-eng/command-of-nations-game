extends SceneTree

const Sizes = preload("res://scripts/unit_map_size.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var catalogue: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/equipment.json"))
	for equipment in catalogue:
		var role: String = equipment.get("role", "")
		if role.is_empty(): role = equipment.get("visual_kind", "armor")
		for tier in equipment.get("research_tiers", []):
			var path: String = tier.get("model", "")
			var envelope := Sizes.limits(role, path)
			# Source files can use metres, centimetres, or a tall deployed pose.
			for raw in [Vector3(2, 3, 10), Vector3(200, 300, 1000), Vector3(1, 12, 1)]:
				var factor := Sizes.fit_factor(raw, role, path)
				var fitted: Vector3 = raw * factor
				check(factor > 0 and is_finite(factor), "Invalid scale: " + path)
				check(maxf(fitted.x, fitted.z) <= envelope.x + 0.00001, "Horizontal overflow: " + path)
				check(fitted.y <= envelope.y + 0.00001, "Height overflow: " + path)
				check(is_equal_approx(fitted.y / fitted.z, raw.y / raw.z), "Distorted model: " + path)
	var small := Sizes.limits("artillery", "russia_2b14_mortar_82.glb")
	var large := Sizes.limits("artillery", "russia_2b11_mortar_120.glb")
	check(small.x < large.x and large.x < Sizes.limits("armor").x, "Mortars must be smaller than tanks")
	check(Sizes.fit_factor(Vector3(1, 12, 1), "artillery", "euro_mo120rt_mortar.glb") <= 0.03001, "Tall mortar regression")
	check(is_equal_approx(Sizes.fit_factor(Vector3(2, 3, 10), "armor"), Sizes.fit_factor(Vector3(200, 300, 1000), "armor") * 100), "Source units affect size")
	check(is_equal_approx(Sizes.limits("projectile").x, 0.62), "Projectile size changed")
	# Exercise the actual fitting transform, including yaw and grounding.
	var pivot := Node3D.new()
	var vehicle := Node3D.new()
	var mesh := MeshInstance3D.new()
	var source := BoxMesh.new()
	source.size = Vector3(1, 12, 1)
	mesh.mesh = source
	mesh.position = Vector3(4, 8, -3)
	vehicle.add_child(mesh)
	pivot.add_child(vehicle)
	UnitVisual._fit(pivot, vehicle, "artillery", "euro_mo120rt_mortar.glb")
	var fitted := UnitVisual.model_bounds(pivot, 0)
	check(fitted.size.y <= 0.36001, "Actual mortar fit exceeds height")
	check(is_zero_approx(fitted.position.y), "Model not grounded")
	check(is_zero_approx(fitted.get_center().x) and is_zero_approx(fitted.get_center().z), "Model not centred")
	check(mesh.mesh == source and source.size == Vector3(1, 12, 1), "Source geometry changed")
	pivot.free()
	for equipment in catalogue:
		for level in range(1, 6):
			var marker := UnitVisual.lightweight(equipment.get("visual_kind", "armor"), Color.GREEN, equipment.id, level)
			var bounds := UnitVisual.model_bounds(marker, 0)
			var metadata: AABB = marker.get_meta("pick_bounds")
			check(bounds.is_equal_approx(metadata), "Placeholder picking disagrees with geometry: " + equipment.id)
			marker.free()
	print("UNIT MAP SIZE ", "PASS" if failures == 0 else "FAIL", ": ", catalogue.size(), " families; ", checks, " checks; ", failures, " failures")
	quit(0 if failures == 0 else 1)
