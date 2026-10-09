class_name StrategicMap
extends Node3D
signal territory_selected(territory: Dictionary)
var territories: Array = RegionData.territories()
var bodies: Dictionary = {}
var materials: Dictionary = {}
var selected_id: = ""
var relation_signature: = ""
var noise: = FastNoiseLite.new()
var _surface_samples: Dictionary = {}
var _border_rings: Array = []
var _political: = -1.0
var _city_points: = PackedVector2Array()
## The drawn ground is made of province triangles that can lie well above or below the smooth
## height formula between their corners, which buried roads, sank tanks and split cities.
## After the ground is built, heights come from the drawn triangles (bucketed in a grid).
const GROUND_CELL: = 0.5
## Radius of a city's built-up area (district outline ~0.72 * 0.86-1.0); roads end here.
const CITY_EDGE: = 0.62
var _ground_cells: Dictionary = {}
var _ground_ready: = false
## Every road as [start, end, bend] (highways and local roads); armies travel only on these.
var roads: Array = []
## Province title -> centre (hub) where its roads meet and where it is captured.
var province_hubs: Dictionary = {}
var province_posts: Dictionary = {}
func _ready() -> void :
	noise.seed = 1874
	noise.frequency = 0.13
	for city in GeographicProjection.load_cities(): _city_points.append(city.point)
	for territory in territories:
		_build_sector(territory)
	_ground_ready = true
	var province_lines: = MapBorder.build_segments(MapBorder.unique_segments(_border_rings), self, 0.9, Color(0.21, 0.23, 0.2, 0.75))
	province_lines.name = "ProvinceBorders"
	add_child(province_lines)
	_add_landscape()
	_add_country_outlines()
	_add_connections()
func elevation(point: Vector2) -> float:
	if _ground_ready:
		for tri in _ground_cells.get(Vector2i(floori(point.x / GROUND_CELL), floori(point.y / GROUND_CELL)), []):
			var a: Vector3 = tri[0]
			var b: Vector3 = tri[1]
			var c: Vector3 = tri[2]
			var weights: = _barycentric(point, Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z))
			if weights.x >= -0.0001 and weights.y >= -0.0001 and weights.z >= -0.0001:
				return a.y * weights.x + b.y * weights.y + c.y * weights.z
	return TerrainProfile.height(point)
static func _barycentric(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> Vector3:
	var v0: = b - a
	var v1: = c - a
	var v2: = p - a
	var denominator: = v0.x * v1.y - v1.x * v0.y
	if absf(denominator) < 1e-12: return Vector3(-1, -1, -1)
	var v: = (v2.x * v1.y - v1.x * v2.y) / denominator
	var w: = (v0.x * v2.y - v2.x * v0.y) / denominator
	return Vector3(1.0 - v - w, v, w)
func _register_ground(a: Vector3, b: Vector3, c: Vector3) -> void :
	var low: = Vector2i(floori(minf(a.x, minf(b.x, c.x)) / GROUND_CELL), floori(minf(a.z, minf(b.z, c.z)) / GROUND_CELL))
	var high: = Vector2i(floori(maxf(a.x, maxf(b.x, c.x)) / GROUND_CELL), floori(maxf(a.z, maxf(b.z, c.z)) / GROUND_CELL))
	for x in range(low.x, high.x + 1):
		for y in range(low.y, high.y + 1):
			var key: = Vector2i(x, y)
			if not _ground_cells.has(key): _ground_cells[key] = []
			_ground_cells[key].append([a, b, c])
func terrain_at(point: Vector2) -> String:
	return TerrainProfile.sample(point)
func position_at(point: Vector2) -> Vector3:
	return Vector3(point.x, elevation(point), point.y)
func _build_sector(t: Dictionary) -> void :
	var poly: PackedVector2Array = t.polygon
	var surface: = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for patch in t.get("mesh_polygons", [poly]):
		var triangles: = Geometry2D.triangulate_polygon(patch)
		for i in range(0, triangles.size(), 3):
			_subdivide(surface, patch[triangles[i]], patch[triangles[i + 1]], patch[triangles[i + 2]], 3 if t.playable and t.get("terrain", "") in ["hills", "mountains"] else 2)
	surface.index()
	var mesh: = surface.commit()
	_surface_samples.clear()
	var material: = ShaderMaterial.new()
	material.shader = load("res://assets/terrain.gdshader")
	material.set_shader_parameter("terrain_types", TerrainVisualMap.get_texture())
	material.set_shader_parameter("terrain_weights", TerrainVisualMap.get_weights())
	material.set_shader_parameter("relief", load("res://assets/materials/relief.png"))
	material.set_shader_parameter("city_points", _city_points)
	material.set_shader_parameter("city_count", _city_points.size())
	material.set_shader_parameter("land_detail", load("res://assets/materials/land_detail.png"))
	material.set_shader_parameter("ownership_strength", 0.18 if t.playable else 0.0)
	material.set_shader_parameter("blank_context", not t.playable)
	var profile: Dictionary = t.get("terrain_profile", {})
	material.set_shader_parameter("forest_density", profile.get("forest_density", 0.72) if t.get("terrain", "") == "forest" else 0.0)
	material.set_shader_parameter("dryness", profile.get("dryness", 0.3))
	material.set_shader_parameter("wetness", profile.get("wetness", 0.0))
	material.set_shader_parameter("country_tint", Color("8a9872") if t.country == "Ukraine" else (Color("c5b77e") if t.country == "Russia" else Color("6e7566")))
	if t.playable:
		var tint: = Color("8a9872") if t.country == "Ukraine" else Color("c5b77e")
		var variation: float = (abs(t.title.hash()) % 5 - 2) * 0.045
		tint = tint.lightened(variation) if variation >= 0 else tint.darkened( - variation)
		material.set_shader_parameter("country_tint", tint)
	materials[t.id] = material
	var visual: = MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	# Raised terrain cast hard shadow wedges onto the sea along mountain coasts (Crimea).
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	var body: = StaticBody3D.new()
	body.collision_layer = 1 if t.playable else 2
	body.set_meta("territory", t)
	var collision: = CollisionShape3D.new()
	collision.shape = mesh.create_trimesh_shape()
	collision.shape.backface_collision = true
	body.add_child(collision)
	add_child(body)
	bodies[t.id] = body
	if not t.playable: return
	_border_rings.append(poly)
	_border_rings.append_array(t.get("holes", []))
func _subdivide(s: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, depth: int) -> void :
	if depth > 0:
		var ab: = (a + b) * 0.5
		var bc: = (b + c) * 0.5
		var ca: = (c + a) * 0.5
		_subdivide(s, a, ab, ca, depth - 1)
		_subdivide(s, ab, b, bc, depth - 1)
		_subdivide(s, ca, bc, c, depth - 1)
		_subdivide(s, ab, bc, ca, depth - 1)
	else:
		for point in [a, b, c]:
			if not _surface_samples.has(point):

				var dx: = elevation(point + Vector2(0.035, 0)) - elevation(point - Vector2(0.035, 0))
				var dz: = elevation(point + Vector2(0, 0.035)) - elevation(point - Vector2(0, 0.035))
				_surface_samples[point] = [position_at(point), Vector3( - dx / 0.07, 1.0, - dz / 0.07).normalized()]
			var sample: Array = _surface_samples[point]
			s.set_color(Color("486c4d").lerp(Color("ddd3b1"), clampf(sample[0].y / 3.0, 0, 1)))
			s.set_normal(sample[1])
			s.add_vertex(sample[0])
		_register_ground(_surface_samples[a][0], _surface_samples[b][0], _surface_samples[c][0])
func select(t: Dictionary) -> void :
	selected_id = t.id
	for item in territories:
		materials[item.id].set_shader_parameter("selected", item.id == selected_id)
	territory_selected.emit(t)
func pick(camera: Camera3D, screen: Vector2) -> Dictionary:
	var origin: = camera.project_ray_origin(screen)
	var query: = PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(screen) * 200.0, 1)
	query.hit_back_faces = true
	var hit: = get_world_3d().direct_space_state.intersect_ray(query)
	if hit and hit.collider.has_meta("territory"):
		return {"territory": hit.collider.get_meta("territory"), "position": hit.position}

	var direction: = camera.project_ray_normal(screen)
	if direction.y < -0.01:
		var distance: = (0.5 - origin.y) / direction.y
		for iteration in 8:
			var point: = origin + direction * distance
			distance = (elevation(Vector2(point.x, point.z)) - origin.y) / direction.y
		var point: = origin + direction * distance
		for territory in territories:
			if territory.playable and RegionData.contains(territory, Vector2(point.x, point.z)):
				return {"territory": territory, "position": point}
	return {}

func _add_landscape() -> void :
	var water: = StandardMaterial3D.new()
	water.albedo_color = Color("548aa0")
	water.roughness = 0.65
	var path: Array[Vector2] = []
	for point in [[30.52, 50.45], [30.9, 50.0], [32.06, 49.44], [32.7, 49.0], [33.5, 48.8], [34.7, 48.55], [35.05, 48.46], [35.14, 47.84], [34.2, 47.5], [33.3, 47.0], [32.62, 46.63], [31.8, 46.5]]:
		path.append(GeographicProjection.project(point[0], point[1]))
	var river_surface: = SurfaceTool.new()
	river_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(path.size() - 1):
		var normal: = Vector2( - (path[i + 1] - path[i]).y, (path[i + 1] - path[i]).x).normalized() * 0.045
		for j in 16:
			var a: Vector2 = path[i].lerp(path[i + 1], j / 16.0)
			var b: Vector2 = path[i].lerp(path[i + 1], (j + 1) / 16.0)
			for point in [a - normal, a + normal, b + normal, a - normal, b + normal, b - normal]:
				river_surface.set_normal(Vector3.UP)
				river_surface.add_vertex(position_at(point) + Vector3.UP * 0.025)
	var river: = MeshInstance3D.new()
	river.name = "DniproRiver"
	river.mesh = river_surface.commit()
	river.material_override = water
	river.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(river)
	var forest: = StandardMaterial3D.new()
	forest.albedo_color = Color("2f4527")
	forest.roughness = 0.95
	forest.vertex_color_use_as_albedo = true
	var rng: = RandomNumberGenerator.new()
	rng.seed = 2943
	var transforms: Array[Transform3D] = []
	var city_locations: = GeographicProjection.load_cities()
	for i in 8000:
		var point: = Vector2(rng.randf_range(-19, 23), rng.randf_range(-20, 11))
		var kind: = terrain_at(point)
		var grove_density: = noise.get_noise_2d(point.x * 3.0, point.y * 3.0)
		var density: = clampf(0.3 + grove_density * 1.2, 0.05, 0.85) if kind == "forest" else 0.0
		if kind != "forest": continue
		if rng.randf() > density: continue
		var near_city: = false
		for city in city_locations:
			if city.point.distance_to(point) < 1.3: near_city = true
		if near_city: continue
		for t in territories:
			if t.playable and RegionData.contains(t, point) and point.distance_to(t.center) > 1.0:
				var scale: = rng.randf_range(0.35, 0.65)
				transforms.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3(scale, scale * rng.randf_range(0.8, 1.3), scale)), position_at(point) + Vector3.UP * 0.22))
				break

	# Realistic small trees instead of the old round "lollipop" spheres: a layered conifer
	# with a dark trunk, in natural muted greens (per-instance colour variation below).
	var tree_builder: = SurfaceTool.new()
	tree_builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tier in [[0.0, 0.11, 0.16], [0.08, 0.085, 0.14], [0.15, 0.055, 0.12]]:
		var cone: = CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = tier[1]
		cone.height = tier[2]
		cone.radial_segments = 7
		cone.rings = 1
		tree_builder.append_from(cone, 0, Transform3D(Basis.IDENTITY, Vector3(0, tier[0], 0)))
	var trunk: = CylinderMesh.new()
	trunk.top_radius = 0.012
	trunk.bottom_radius = 0.016
	trunk.height = 0.08
	trunk.radial_segments = 5
	tree_builder.append_from(trunk, 0, Transform3D(Basis.IDENTITY, Vector3(0, -0.1, 0)))
	tree_builder.generate_normals()
	var tree: = tree_builder.commit()
	var grove: = MultiMeshInstance3D.new()
	grove.name = "ForestInstances"
	var instances: = MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.mesh = tree
	instances.instance_count = transforms.size()
	for i in transforms.size():
		instances.set_instance_transform(i, transforms[i])
		instances.set_instance_color(i, Color(0.8 + rng.randf() * 0.35, 0.85 + rng.randf() * 0.3, 0.75 + rng.randf() * 0.25))
	grove.multimesh = instances
	grove.set_meta("placement_transforms", transforms)
	grove.material_override = forest
	add_child(grove)

func _add_country_outlines() -> void :
	for country in RegionData.countries():
		if country.country not in ["Russia", "Ukraine"]: continue
		var visual: = MapBorder.build([country.polygon], self, 1.65, Color("343d38"))
		visual.name = "CountryBorder_" + country.country
		add_child(visual)

## Call of War look: strong political colours when zoomed out, terrain detail up close.
func set_view_distance(distance: float) -> void :
	var value: = smoothstep(13.0, 30.0, distance)
	if absf(value - _political) < 0.01: return
	_political = value
	for territory in territories:
		if territory.playable: materials[territory.id].set_shader_parameter("political", value)

func set_terrain_mode(enabled: bool) -> void :
	for territory in territories:
		materials[territory.id].set_shader_parameter("ownership_strength", (0.08 if enabled else 0.18) if territory.playable else 0.0)

func _add_connections() -> void :
	var locations: Dictionary = {}
	for city in GeographicProjection.load_cities(): locations[city.name] = city.point
	var land: Array = []
	for country in RegionData.countries():
		if country.country in ["Russia", "Ukraine"]: land.append(country.polygon)
	# Highways between the major cities.
	var highways: = SurfaceTool.new()
	highways.begin(Mesh.PRIMITIVE_TRIANGLES)
	var connections: = [["Lviv", "Kyiv"], ["Kyiv", "Kharkiv"], ["Kyiv", "Dnipro"], ["Dnipro", "Odesa"], ["Kharkiv", "Dnipro"], ["Moscow", "Kursk"], ["Moscow", "Voronezh"], ["Kursk", "Belgorod"], ["Voronezh", "Rostov-on-Don"]]
	for pair in connections:
		_road(highways, locations[pair[0]], locations[pair[1]], 0.025, 0.4, land)
		roads.append([locations[pair[0]], locations[pair[1]], 0.4])
	_add_road_mesh(highways, Color("5e5b52"))
	var local: = SurfaceTool.new()
	local.begin(Mesh.PRIMITIVE_TRIANGLES)
	var graph: = road_graph(territories)
	province_hubs = graph.hubs
	for edge in graph.edges:
		_road(local, edge[0], edge[1], 0.022, edge[2], land)
		roads.append(edge)
	_add_province_posts(locations.values())
	_add_road_mesh(local, Color("6a6456"))

## [start, end, bend] for the local road between every pair of neighbouring provinces.
static func road_network(territory_list: Array) -> Array:
	return road_graph(territory_list).edges

## {"edges": [[start, end, bend], ...], "hubs": {province title: centre}}. The hub is the
## centre of the province's largest piece: where its roads meet and where it is captured.
static func road_graph(territory_list: Array) -> Dictionary:
	# Owner review: a road to every province. Provinces that share a border are joined
	# centre to centre; a road a-b is dropped when a common neighbour c is closer to both
	# (the detour a-c-b replaces it), which keeps every province connected without clutter.
	# One road node per province (island parts join their main part); a city province and
	# its surrounding region (Moscow, Kyiv, St. Petersburg) share one hub.
	var main_part: Dictionary = {}  # title -> centre of its largest piece
	var largest: Dictionary = {}
	for t in territory_list:
		if not t.playable: continue
		var area: = _polygon_area(t.polygon)
		if area > largest.get(t.title, -1.0):
			largest[t.title] = area
			main_part[t.title] = t.center
	var centers: Array[Vector2] = []
	var node_of: Dictionary = {}
	var cells: Dictionary = {}  # 0.04 grid cell -> province nodes with a border vertex there
	for t in territory_list:
		if not t.playable: continue
		var center: Vector2 = main_part[t.title]
		var hub: = Vector2i(roundi(center.x * 10.0), roundi(center.y * 10.0))
		var key: String = node_of.get(t.title, node_of.get(hub, ""))
		var index: int
		if key.is_empty():
			index = centers.size()
			centers.append(center)
		else: index = int(key)
		node_of[t.title] = str(index)
		node_of[hub] = str(index)
		for vertex in t.polygon:
			var cell: = Vector2i(floori(vertex.x / 0.04), floori(vertex.y / 0.04))
			if not cells.has(cell): cells[cell] = {}
			cells[cell][index] = true
	var neighbours: Array[Dictionary] = []
	for i in centers.size(): neighbours.append({})
	for cell in cells:
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				var other: Dictionary = cells.get(cell + Vector2i(dx, dy), {})
				for i in cells[cell]:
					for j in other:
						if i != j: neighbours[i][j] = true
	var edges: Array = []
	var connected: Dictionary = {}
	for i in centers.size():
		for j in neighbours[i]:
			if j <= i: continue
			var length: = centers[i].distance_to(centers[j])
			var blocked: = false
			for k in neighbours[i]:
				if k != j and neighbours[j].has(k) and maxf(centers[k].distance_to(centers[i]), centers[k].distance_to(centers[j])) < length:
					blocked = true
					break
			if not blocked:
				edges.append([centers[i], centers[j], 0.12 * sin(float(i * 31 + j))])
				connected[i] = true
				connected[j] = true
	# Enclaves (Kyiv City inside Kyiv region) share no outer border vertex: join the nearest.
	for i in centers.size():
		if connected.has(i): continue
		var nearest: = -1
		for j in centers.size():
			if j != i and centers[j].distance_to(centers[i]) < 6.0 and (nearest < 0 or centers[j].distance_to(centers[i]) < centers[nearest].distance_to(centers[i])): nearest = j
		if nearest >= 0: edges.append([centers[i], centers[nearest], 0.0])
	return {"edges": edges, "hubs": main_part}

static func _polygon_area(polygon: PackedVector2Array) -> float:
	var area: = 0.0
	for i in polygon.size(): area += polygon[i].cross(polygon[(i + 1) % polygon.size()])
	return absf(area) * 0.5

## A flag post at every province centre without a city (cities mark their own centre): the
## point an army must hold to capture the province. The flag shows who controls it.
func _add_province_posts(city_points: Array) -> void :
	var flags: = {"russia": [Color("f2f2ee"), Color("2853a8"), Color("c8372d")], "ukraine": [Color("2f6bc7"), Color("f2c418")]}
	for title in province_hubs:
		var hub: Vector2 = province_hubs[title]
		if city_points.any(func(city: Vector2): return city.distance_to(hub) < 0.5): continue
		var post: = Node3D.new()
		post.name = "ProvinceCentre_" + str(title).validate_node_name()
		post.position = position_at(hub)
		add_child(post)
		var dark: = StandardMaterial3D.new()
		dark.albedo_color = Color("2e302c")
		var base: = MeshInstance3D.new()
		var plinth: = CylinderMesh.new()
		plinth.top_radius = 0.07
		plinth.bottom_radius = 0.09
		plinth.height = 0.04
		plinth.radial_segments = 12
		base.mesh = plinth
		base.material_override = dark
		base.position.y = 0.02
		post.add_child(base)
		var pole: = MeshInstance3D.new()
		var stick: = CylinderMesh.new()
		stick.top_radius = 0.007
		stick.bottom_radius = 0.007
		stick.height = 0.36
		stick.radial_segments = 6
		pole.mesh = stick
		pole.material_override = dark
		pole.position.y = 0.2
		post.add_child(pole)
		for country in flags:
			var flag: = Node3D.new()
			flag.name = country
			flag.position = Vector3(0.075, 0.33, 0)
			var stripes: Array = flags[country]
			for i in stripes.size():
				var stripe: = MeshInstance3D.new()
				var cloth: = BoxMesh.new()
				cloth.size = Vector3(0.14, 0.09 / stripes.size(), 0.006)
				stripe.mesh = cloth
				var paint: = StandardMaterial3D.new()
				paint.albedo_color = stripes[i]
				stripe.material_override = paint
				stripe.position.y = 0.045 - 0.09 * (i + 0.5) / stripes.size()
				flag.add_child(stripe)
			post.add_child(flag)
		province_posts[title] = post
	_update_posts()
func _update_posts() -> void :
	for territory in territories:
		if not territory.playable or not province_posts.has(territory.title): continue
		var post: Node3D = province_posts[territory.title]
		for flag in post.get_children():
			if flag.name in ["russia", "ukraine"]: flag.visible = flag.name == territory.controller

## Points along the road from start to end (both included), bowed sideways by `bend`.
static func road_curve(start: Vector2, end: Vector2, bend: float) -> PackedVector2Array:
	var normal: = Vector2( - (end - start).y, (end - start).x).normalized()
	var count: = maxi(8, ceili(start.distance_to(end) / 0.2))
	var points: = PackedVector2Array()
	for i in count + 1:
		var t: = i / float(count)
		points.append(start.lerp(end, t) + normal * sin(t * PI) * bend)
	return points

## Ribbon road from a to b with a gentle sideways bend, following the terrain; segments over
## water are skipped.
func _road(surface: SurfaceTool, start: Vector2, end: Vector2, half_width: float, bend: float, land: Array) -> void :
	var curve: = road_curve(start, end, bend)
	for i in curve.size() - 1:
		var a: = curve[i]
		var b: = curve[i + 1]
		var on_land: = false
		for polygon in land:
			if Geometry2D.is_point_in_polygon((a + b) * 0.5, polygon):
				on_land = true
				break
		if not on_land: continue
		# Roads stop at the city edge instead of piling up through the city.
		var middle: = (a + b) * 0.5
		if _city_points.size() > 0 and Array(_city_points).any(func(city: Vector2): return city.distance_to(middle) < CITY_EDGE): continue
		var side: = (b - a).orthogonal().normalized() * half_width
		for point in [a - side, a + side, b + side, a - side, b + side, b - side]:
			surface.add_vertex(position_at(point) + Vector3.UP * 0.04)

func _add_road_mesh(surface: SurfaceTool, color: Color) -> void :
	var roads: = MeshInstance3D.new()
	roads.mesh = surface.commit()
	var material: = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	roads.material_override = material
	roads.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(roads)

func update_relations(at_war: bool) -> void :
	var signature: = str(at_war)
	for territory in territories: signature += str(territory.controller)
	if signature == relation_signature: return
	relation_signature = signature
	_update_posts()
	for territory in territories:
		if not territory.playable: continue
		var material: ShaderMaterial = materials[territory.id]
		material.set_shader_parameter("hostile", at_war and territory.controller != GameSession.player_country)
		material.set_shader_parameter("occupied", territory.controller != territory.owner)
		material.set_shader_parameter("country_tint", Color("c5b77e") if territory.controller == GameSession.player_country else Color("8a9872"))
