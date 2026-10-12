class_name RailwayMap
extends Node3D
## Railway visuals connect completed city stations over the existing land-road graph.
## This does not turn civilian model previews into military production or cargo orders.
var cities: CitySystem
var buildings: BuildingSystem
var links: Array = []
var _signature: String = ""

func setup(city_system: CitySystem, building_system: BuildingSystem) -> void:
	cities = city_system;buildings = building_system
	buildings.changed.connect(refresh)
	refresh()

func refresh() -> void:
	var stations: Array = []
	var signature: String = ""
	for place in cities.cities:
		var level: = buildings.level(place.id,"train_station")
		if level <= 0: continue
		var country: = cities.armies.navigation.controller_at(place.point)
		stations.append({"place":place,"country":country})
		signature += place.id+country+str(level)
	if signature == _signature: return
	_signature = signature
	for child in get_children(): remove_child(child);child.queue_free()
	links.clear()
	if stations.size() < 2: return
	var raw: = (load("res://assets/library/buildings_oct12/rail_straight.glb") as PackedScene).instantiate() as Node3D
	var model: = UnitVisual.merged(raw)
	var bounds: = UnitVisual.model_bounds(model,0.0)
	var pieces: Array[Transform3D] = []
	var connected: Dictionary = {}
	# Connect nearby same-country stations; never draw across water or hostile territory.
	for a in stations:
		var candidates: Array = stations.filter(func(b):return b.place.id != a.place.id and b.country == a.country)
		candidates.sort_custom(func(b,c):return a.place.point.distance_squared_to(b.place.point)<a.place.point.distance_squared_to(c.place.point))
		if candidates.is_empty(): continue
		var b: Dictionary = candidates[0]
		var ids: Array = [a.place.id,b.place.id];ids.sort()
		var key: String = str(ids)
		if connected.has(key): continue
		var route: Array = [a.place.point]
		route.append_array(cities.armies.navigation.find_path(a.place.point,b.place.point))
		if route.size() < 2 or route[-1].distance_to(b.place.point)>0.1: continue
		if route.any(func(point):return cities.armies.navigation.controller_at(point)!=a.country): continue
		var clear: bool = true
		for i in route.size()-1:
			if not cities.armies.navigation.clear_segment(route[i],route[i+1]): clear=false;break
		if not clear: continue
		connected[key] = true
		links.append({"a":a.place.id,"b":b.place.id,"route":route})
		for i in route.size()-1:
			var start: Vector2 = route[i];var finish: Vector2 = route[i+1]
			var count: = maxi(1,ceili(start.distance_to(finish)/0.18))
			for j in count:
				var point: = start.lerp(finish,(float(j)+0.5)/count)
				var length: = start.distance_to(finish)/count
				var yaw: = -(finish-start).angle()
				var scale: = Vector3(length/maxf(bounds.size.x,0.001),0.06/maxf(bounds.size.z,0.001),0.06/maxf(bounds.size.z,0.001))
				var basis: = Basis(Vector3.UP,yaw).scaled(scale)
				pieces.append(Transform3D(basis,cities.terrain.position_at(point)+Vector3.UP*0.015-basis*bounds.get_center()))
	for source in model.get_children():
		if not source is MeshInstance3D: continue
		var batch: = MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = source.mesh
		batch.instance_count = pieces.size()
		for i in pieces.size(): batch.set_instance_transform(i,pieces[i]*source.transform)
		var visual: = MultiMeshInstance3D.new()
		visual.multimesh = batch;visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(visual)
	model.free()
