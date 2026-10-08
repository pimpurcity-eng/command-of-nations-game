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
func _ready() -> void :
	noise.seed = 1874
	noise.frequency = 0.13
	for city in GeographicProjection.load_cities(): _city_points.append(city.point)
	for territory in territories:
		_build_sector(territory)
	var province_lines: = MapBorder.build_segments(MapBorder.unique_segments(_border_rings), self, 0.9, Color(0.21, 0.23, 0.2, 0.75))
	province_lines.name = "ProvinceBorders"
	add_child(province_lines)
	_add_landscape()
	_add_country_outlines()
	_add_connections()
func elevation(point: Vector2) -> float:
	return TerrainProfile.height(point)
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
	forest.albedo_color = Color("475b36")
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

	var tree_builder: = SurfaceTool.new()
	tree_builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for offset in [Vector3(0, 0.12, 0), Vector3(-0.055, 0.07, 0.025), Vector3(0.05, 0.07, -0.02)]:
		var crown: = SphereMesh.new()
		crown.radius = 0.12
		crown.height = 0.22
		crown.radial_segments = 10
		crown.rings = 5
		tree_builder.append_from(crown, 0, Transform3D(Basis.IDENTITY, offset))
	var trunk: = CylinderMesh.new()
	trunk.top_radius = 0.019
	trunk.bottom_radius = 0.024
	trunk.height = 0.25
	trunk.radial_segments = 6
	tree_builder.append_from(trunk, 0, Transform3D(Basis.IDENTITY, Vector3(0, -0.14, 0)))
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
		instances.set_instance_color(i, Color(0.8 + rng.randf() * 0.25, 0.85 + rng.randf() * 0.2, 0.75 + rng.randf() * 0.2))
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
	var surface: = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var connections: = [["Lviv", "Kyiv"], ["Kyiv", "Kharkiv"], ["Kyiv", "Dnipro"], ["Dnipro", "Odesa"], ["Kharkiv", "Dnipro"], ["Moscow", "Kursk"], ["Moscow", "Voronezh"], ["Kursk", "Belgorod"], ["Voronezh", "Rostov-on-Don"]]
	for pair in connections:
		var start: Vector2 = locations[pair[0]]
		var end: Vector2 = locations[pair[1]]
		var normal: = Vector2( - (end - start).y, (end - start).x).normalized()
		var count: = maxi(8, ceili(start.distance_to(end) / 0.22))
		for i in count:
			var t: = i / float(count)
			var next: = (i + 1) / float(count)
			var a: = start.lerp(end, t) + normal * sin(t * PI) * 0.4
			var b: = start.lerp(end, next) + normal * sin(next * PI) * 0.4
			var on_land: = false
			for country in RegionData.countries():
				if country.country in ["Russia", "Ukraine"] and Geometry2D.is_point_in_polygon((a + b) * 0.5, country.polygon):
					on_land = true
					break
			if not on_land: continue
			for point in [a - normal * 0.025, a + normal * 0.025, b + normal * 0.025, a - normal * 0.025, b + normal * 0.025, b - normal * 0.025]:
				surface.add_vertex(position_at(point) + Vector3.UP * 0.045)
	var roads: = MeshInstance3D.new()
	roads.mesh = surface.commit()
	var material: = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color("a59a77")
	roads.material_override = material
	add_child(roads)

func update_relations(at_war: bool) -> void :
	var signature: = str(at_war)
	for territory in territories: signature += str(territory.controller)
	if signature == relation_signature: return
	relation_signature = signature
	for territory in territories:
		if not territory.playable: continue
		var material: ShaderMaterial = materials[territory.id]
		material.set_shader_parameter("hostile", at_war and territory.controller != GameSession.player_country)
		material.set_shader_parameter("occupied", territory.controller != territory.owner)
		material.set_shader_parameter("country_tint", Color("c5b77e") if territory.controller == GameSession.player_country else Color("8a9872"))
