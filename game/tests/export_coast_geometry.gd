extends SceneTree
func _initialize() -> void:
	var rings: Array = []
	for t in RegionData.territories():
		for polygon in t.get("mesh_polygons",[t.polygon]):
			var points: Array = []
			for p in polygon: points.append([p.x,p.y])
			rings.append(points)
	var file := FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE)
	file.store_string(JSON.stringify(rings))
	quit()
