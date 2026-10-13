class_name RailwayMap
extends Node3D
## Railway lines between completed train stations (cities and provinces).
## Owner 2026-10-13: only the capital starts with a station, so there are no tracks at the start;
## a line appears once a second friendly station is built. Each country's stations are joined
## in one network (shortest links first), over its own land only. The original rail_straight
## model is laid at its true proportions along a smoothed line (it used to be squashed into a
## white "fence").
const TRACK_WIDTH: = 0.06
const MODEL: = "res://assets/library/buildings_oct12/rail_straight.glb"
static var active: RailwayMap
var cities: CitySystem
var buildings: BuildingSystem
var links: Array = []
## Territory ids a rail line runs through ("rail transport": armies move faster there).
var served: Dictionary = {}
var _signature: String = ""
var _model: Node3D
var _model_info: Dictionary = {}

func setup(city_system: CitySystem, building_system: BuildingSystem) -> void:
	cities = city_system;buildings = building_system
	active = self
	buildings.changed.connect(refresh)
	refresh()

func _exit_tree() -> void:
	if active == self: active = null

func stations() -> Array:
	var result: Array = []
	var navigation: LandRoutes = cities.armies.navigation
	for place in cities.cities:
		if buildings.level(place.id,"train_station") > 0:
			result.append({"id":place.id,"point":place.point,"country":navigation.controller_at(place.point)})
	if buildings.provinces != null:
		for id in buildings.provinces.levels:
			if buildings.provinces.level(id,"train_station") <= 0: continue
			var place: Dictionary = buildings.provinces.place(id)
			if place.is_empty(): continue
			result.append({"id":id,"point":place.point,"country":navigation.controller_at(place.point)})
	return result

func refresh() -> void:
	var list: = stations()
	var signature: String = ""
	for s in list: signature += s.id + s.country + ";"
	if signature == _signature: return
	_signature = signature
	for child in get_children(): remove_child(child);child.queue_free()
	links.clear()
	served.clear()
	var by_country: Dictionary = {}
	for s in list:
		if s.country.is_empty(): continue
		if not by_country.has(s.country): by_country[s.country] = []
		by_country[s.country].append(s)
	for country in by_country: _connect(country,by_country[country])
	if links.is_empty(): return
	_mark_served()
	_draw()

## Joins one country's stations into a network, shortest possible links first (Kruskal).
func _connect(country: String,group: Array) -> void:
	if group.size() < 2: return
	var pairs: Array = []
	for i in group.size():
		for j in range(i+1,group.size()): pairs.append([group[i].point.distance_squared_to(group[j].point),i,j])
	pairs.sort_custom(func(a,b):return a[0] < b[0])
	var parent: Array = range(group.size())
	var root: = func(i: int) -> int:
		while parent[i] != i: i = parent[i]
		return i
	for pair in pairs:
		var a: int = root.call(pair[1]);var b: int = root.call(pair[2])
		if a == b: continue
		var route: = _route(country,group[pair[1]].point,group[pair[2]].point)
		if route.is_empty(): continue
		parent[a] = b
		links.append({"a":group[pair[1]].id,"b":group[pair[2]].id,"country":country,"route":route})

## A straight line over the country's own land where possible, otherwise along the roads;
## never over water or another country's land. Corners are rounded off.
func _route(country: String,start: Vector2,finish: Vector2) -> Array:
	var navigation: LandRoutes = cities.armies.navigation
	var route: Array = [start,finish]
	if not _own_line(country,start,finish):
		route = [start]
		route.append_array(navigation.find_path(start,finish))
		if route.size() < 2 or route[-1].distance_to(finish) > 0.1: return []
		route[-1] = finish
		for i in route.size()-1:
			if not _own_line(country,route[i],route[i+1]): return []
	return _smooth(route)

func _own_line(country: String,a: Vector2,b: Vector2) -> bool:
	var navigation: LandRoutes = cities.armies.navigation
	var steps: = maxi(1,ceili(a.distance_to(b)/0.15))
	for i in steps+1:
		if navigation.controller_at(a.lerp(b,float(i)/steps)) != country: return false
	return true

static func _smooth(route: Array) -> Array:
	var points: Array = route
	for pass_index in 3:
		if points.size() < 3: break
		var next: Array = [points[0]]
		for i in points.size()-1:
			var a: Vector2 = points[i];var b: Vector2 = points[i+1]
			if i > 0: next.append(a.lerp(b,0.25))
			if i < points.size()-2: next.append(a.lerp(b,0.75))
		next.append(points[-1])
		points = next
	return points

func _mark_served() -> void:
	for link in links:
		var route: Array = link.route
		for i in route.size()-1:
			var steps: = maxi(1,ceili(route[i].distance_to(route[i+1])/0.2))
			for j in steps+1:
				var point: Vector2 = route[i].lerp(route[i+1],float(j)/steps)
				for territory in cities.terrain.territories:
					if territory.playable and RegionData.contains(territory,point):
						served[str(territory.id)] = true
						break

func _load_model() -> bool:
	if _model != null: return true
	var scene: = load(MODEL) as PackedScene
	if scene == null: return false
	_model = UnitVisual.merged(scene.instantiate() as Node3D)
	var bounds: = UnitVisual.model_bounds(_model,0.0)
	var along_x: = bounds.size.x >= bounds.size.z
	var width: float = bounds.size.z if along_x else bounds.size.x
	var scale: = TRACK_WIDTH/maxf(width,0.001)
	_model_info = {"bounds":bounds,"along_x":along_x,"scale":scale,"length":(bounds.size.x if along_x else bounds.size.z)*scale}
	return true

func _draw() -> void:
	if not _load_model(): return
	var bounds: AABB = _model_info.bounds
	var scale: float = _model_info.scale
	var piece: float = _model_info.length
	# Model space: centre on the origin, sit on the ground, long side along +x.
	var centre: = bounds.get_center()
	var local: = Transform3D(Basis.IDENTITY,-Vector3(centre.x,bounds.position.y,centre.z))
	if not _model_info.along_x: local = Transform3D(Basis(Vector3.UP,PI*0.5),Vector3.ZERO)*local
	local = Transform3D(Basis().scaled(Vector3.ONE*scale),Vector3.ZERO)*local
	var pieces: Array[Transform3D] = []
	for link in links:
		var route: Array = link.route
		var lengths: Array = [0.0]
		for i in route.size()-1: lengths.append(lengths[-1]+route[i].distance_to(route[i+1]))
		var total: float = lengths[-1]
		var count: = maxi(1,ceili(total/(piece*0.97)))
		var step: = total/count
		for k in count:
			var a: = _along(route,lengths,step*k)
			var b: = _along(route,lengths,step*(k+1))
			var middle: = (a+b)*0.5
			var yaw: = -(b-a).angle()
			var stretch: = Transform3D(Basis().scaled(Vector3(step/piece*1.02,1.0,1.0)),Vector3.ZERO)
			var ground: = cities.terrain.position_at(middle)+Vector3.UP*0.004
			pieces.append(Transform3D(Basis(Vector3.UP,yaw),ground)*stretch*local)
	for source in _model.get_children():
		if not source is MeshInstance3D: continue
		var batch: = MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = source.mesh
		batch.instance_count = pieces.size()
		for i in pieces.size(): batch.set_instance_transform(i,pieces[i]*source.transform)
		var visual: = MultiMeshInstance3D.new()
		visual.multimesh = batch;visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if source.material_override != null: visual.material_override = source.material_override
		add_child(visual)

static func _along(route: Array,lengths: Array,distance: float) -> Vector2:
	for i in route.size()-1:
		if distance <= lengths[i+1] or i == route.size()-2:
			var span: float = lengths[i+1]-lengths[i]
			return route[i].lerp(route[i+1],clampf((distance-lengths[i])/maxf(span,0.000001),0.0,1.0))
	return route[-1]
