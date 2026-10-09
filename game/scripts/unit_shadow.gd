class_name UnitShadow
extends RefCounted
static func create(marker: Node3D) -> MeshInstance3D:
	var shadow: = MeshInstance3D.new()
	shadow.name = "GroundShadow"
	var shape: = QuadMesh.new()
	shape.size = Vector2(0.85, 0.55)
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
	shadow.position = ground - marker.position + Vector3(0.1 + height * 0.1, 0.04, 0.08 + height * 0.08)
	shadow.rotation.y = unit.heading
	shadow.scale = Vector3.ONE * (1.0 + minf(height, 2.0) * 0.15)
	shadow.material_override.set_shader_parameter("opacity", 0.3 / (1.0 + height * 0.2))
