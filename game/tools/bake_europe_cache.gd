extends SceneTree
## Bake the flat map without redundant interior subdivision. Every supplied coast vertex,
## hole and province boundary remains unchanged. Shared elevation/collision uses these meshes.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	MapDefinition.use(MapDefinition.EUROPE)
	DirAccess.make_dir_recursive_absolute(StrategicMap.MESH_CACHE_DIR)
	var regions: = RegionData.territories()
	var count: = 0
	for region in regions:
		var surface: = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var normals: Dictionary = {}
		for poly in region.get("mesh_polygons",[region.polygon]):
			var indices: = Geometry2D.triangulate_polygon(poly)
			for index in indices:
				var point: Vector2 = poly[index]
				if not normals.has(point):
					var dx: = TerrainProfile.relief_height(point+Vector2(.035,0))-TerrainProfile.relief_height(point-Vector2(.035,0))
					var dz: = TerrainProfile.relief_height(point+Vector2(0,.035))-TerrainProfile.relief_height(point-Vector2(0,.035))
					normals[point]=[Vector3(-dx/.07,1,-dz/.07).normalized(),TerrainProfile.relief_height(point)]
				surface.set_normal(normals[point][0])
				surface.set_color(Color(normals[point][1]/4,0,0))
				surface.add_vertex(Vector3(point.x,TerrainProfile.FLAT_HEIGHT,point.y))
		surface.index()
		var mesh: = surface.commit()
		mesh.set_meta("cache_key",StrategicMap.mesh_cache_key(region))
		mesh.set_meta("flat_coast_preserving_cache",true)
		mesh.set_meta("ground_cells",StrategicMap.ground_chunks(mesh))
		mesh.set_meta("ground_cell_size",StrategicMap.GROUND_CELL)
		mesh.set_meta("ground_vertices",mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
		var error: = ResourceSaver.save(mesh,StrategicMap.mesh_cache_path(region),ResourceSaver.FLAG_COMPRESS)
		if error!=OK: push_error("Cannot save Europe cache "+region.id);quit(1);return
		count+=1
		if count%50==0: print("EUROPE_CACHE ",count,"/",regions.size());await process_frame
	print("RESULT EUROPE_CACHE meshes=",count," failures=0")
	quit()
