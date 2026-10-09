class_name UnitShadow
extends RefCounted
static func create(marker: Node3D) -> MeshInstance3D:
	var shadow: = MeshInstance3D.new()
	shadow.name = "GroundShadow"
	var shape: = QuadMesh.new()
	shape.size = Vector2(0.4, 0.85)
	shadow.mesh = shape
	shadow.rotation.x = -PI / 2
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material: = ShaderMaterial.new()
	material.shader = load("res://assets/unit_shadow.gdshader")
	shadow.material_override = material
	marker.add_child(shadow)
	marker.set_meta("ground_shadow", shadow)
	return shadow
static func update(unit: Dictionary, ground: Vector3) -> void:
	var marker: Node3D = unit.node
	if not marker.has_meta("ground_shadow"): return
	var shadow: MeshInstance3D = marker.get_meta("ground_shadow")
	var height: = maxf(0, marker.position.y - ground.y)
	# A small contact shadow follows the fitted hull, not a wide black disk.
	var cast: = Vector3(0.015 + height * 0.1, 0.0, 0.015 + height * 0.08)
	var offset: = cast + Vector3(0, 0.04, 0)
	if shadow.is_inside_tree(): shadow.global_position = ground + offset
	else: shadow.position = ground - marker.position + offset
	shadow.rotation.y = unit.heading
	# Follows the model's size (armies shrink inside cities).
	var model_scale: = (marker.get_child(0) as Node3D).scale.x / 0.65 if marker.get_child_count() > 0 and marker.get_child(0) is Node3D else 1.0
	if marker.get_child_count() > 0 and marker.get_child(0).has_meta("ground_shadow_size"):
		(shadow.mesh as QuadMesh).size = marker.get_child(0).get_meta("ground_shadow_size") * 1.05
	shadow.scale = Vector3.ONE * (1.0 + minf(height, 2.0) * 0.1) * model_scale
	shadow.material_override.set_shader_parameter("opacity", 0.38 / (1.0 + height * 0.5))
