extends Node3D
@export var paint_colour: Color = Color.WHITE
static var materials: Dictionary = {}
func _ready() -> void:
	# Shared cached materials outlive destroyed/replaced models, as with unit camouflage.
	for item in UnitVisual._meshes(self, Transform3D.IDENTITY):
		var model: MeshInstance3D = item[0]
		for index in model.mesh.get_surface_count():
			var original: = model.get_active_material(index)
			if not original is BaseMaterial3D: continue
			var key: = str(original.get_instance_id()) + ":" + paint_colour.to_html()
			if not materials.has(key):
				var material: = original.duplicate() as BaseMaterial3D
				material.albedo_color = paint_colour.lerp(original.albedo_color, 0.2)
				materials[key] = material
			model.set_surface_override_material(index, materials[key])
