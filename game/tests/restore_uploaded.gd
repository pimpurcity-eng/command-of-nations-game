extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for id in ["uploadec7e", "upload661a", "upload3b99", "upload7a7e", "upload20ab"]: restore_asset(id)
	quit()
func restore_asset(id: String) -> void:
	var original = load("res://assets/" + id + ".fbx").instantiate()
	root.add_child(original)
	var parts = original.find_children("*", "MeshInstance3D", true, false)
	var bounds = AABB()
	var seen = false
	for part in parts:
		var box = part.global_transform * part.get_aabb()
		bounds = bounds.merge(box) if seen else box
		seen = true
	var factor = 1.92 / maxf(bounds.size.x, bounds.size.z)
	var center = bounds.get_center()
	var rotation = Basis(Vector3.UP, PI / 2) if bounds.size.x > bounds.size.z else Basis.IDENTITY
	var normalize = Transform3D(rotation.scaled(Vector3.ONE * factor), rotation * Vector3(-center.x, -bounds.position.y, -center.z) * factor)
	var batches = {}
	var vertex_count = 0
	var textured = 0
	for part in parts:
		for i in part.mesh.get_surface_count():
			var material = part.get_active_material(i)
			var key = material.get_instance_id()
			vertex_count += part.mesh.surface_get_array_len(i)
			if not batches.has(key):
				var st = SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				var kept = material.duplicate()
				if kept is StandardMaterial3D:
					if kept.albedo_texture != null: textured += 1
					for property in ["albedo_texture", "normal_texture", "roughness_texture", "metallic_texture", "ao_texture"]:
						var texture = kept.get(property)
						if texture == null: continue
						var bitmap: Image = texture.get_image()
						if bitmap == null: continue
						var largest = maxi(bitmap.get_width(), bitmap.get_height())
						if largest > 1024:
							bitmap.resize(maxi(1, bitmap.get_width() * 1024 / largest), maxi(1, bitmap.get_height() * 1024 / largest), Image.INTERPOLATE_LANCZOS)
							kept.set(property, ImageTexture.create_from_image(bitmap))
				st.set_material(kept)
				batches[key] = st
			batches[key].append_from(part.mesh, i, normalize * part.global_transform)
	var result = Node3D.new()
	result.name = id + "_Original"
	var mesh = ArrayMesh.new()
	for st in batches.values(): st.commit(mesh)
	var model = MeshInstance3D.new()
	model.name = "Original_geometry_and_materials"
	model.mesh = mesh
	result.add_child(model); model.owner = result
	var document = GLTFDocument.new()
	var state = GLTFState.new()
	assert(document.append_from_scene(result, state) == OK)
	assert(document.write_to_filesystem(state, "/workspace/scratch/9cc4c8c712c9/recovered-game/assets/library/" + id + "_original.glb") == OK)
	print(id, " ORIGINAL vertices=", vertex_count, " materials=", mesh.get_surface_count(), " textured=", textured, " bounds=", model.get_aabb())
	original.free(); result.free()
