extends SceneTree
## Bakes every province ground mesh into game/assets/map_cache/ (run after map data changes):
##   godot --headless --path game --script res://tools/bake_map_cache.gd
## The game rebuilds any province whose cache is missing or out of date, so a stale cache is
## only slower, never wrong.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(StrategicMap.MESH_CACHE_DIR))
	var map: = StrategicMap.new()
	var count: = 0
	for t in map.territories:
		var mesh: = map.build_sector_mesh(t)
		# The ground height index ships with the mesh, so the game does not rebuild it.
		mesh.set_meta("ground_cells", StrategicMap.ground_chunks(mesh))
		mesh.set_meta("ground_cell_size", StrategicMap.GROUND_CELL)
		var error: = ResourceSaver.save(mesh, StrategicMap.mesh_cache_path(t), ResourceSaver.FLAG_COMPRESS)
		if error != OK: printerr("Could not save ", t.id, ": ", error)
		else: count += 1
	map.free()
	print("Baked ", count, " province meshes")
	quit()
