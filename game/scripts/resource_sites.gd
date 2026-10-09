class_name ResourceSites
extends Node3D
## Resource sites scattered across the provinces (oil and gas fields, mines and steelworks,
## timber, tech plants, grain farmland) and the resource specialties of each city. A site
## earns its resource for whoever controls its province; each is drawn as an original 3D
## installation with a resource badge above it (badges hide when zoomed far out).
## Data: res://data/resource_sites.json. Owner review 2026-10-09: "there has to be resources
## in cities, and some scattered across some provinces".
const DATA_PATH: = "res://data/resource_sites.json"
const ICON_DISTANCE: = 30.0
static var _data: Dictionary = {}
var sites: Array = []  # {name, resource, point: Vector2, territory: Dictionary}
var terrain: StrategicMap
var rig: StrategyCamera
var badges: Array[Sprite3D] = []

static func data() -> Dictionary:
	if _data.is_empty(): _data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return _data

static func city_resources(city_name: String) -> Array:
	return data().cities.get(city_name, [])

static func rate(resource: String) -> float:
	return float(data().rates.get(resource, 0.0))

static var _icons: Dictionary = {}
static func icon(resource: String) -> Texture2D:
	# A plain in-memory copy per icon: the imported texture drew as a white square in the HUD
	# top bar on the GL Compatibility renderer (money icon), while the copy draws correctly.
	if not _icons.has(resource):
		var source: Texture2D = load("res://assets/interface/res_" + resource + ".png")
		_icons[resource] = ImageTexture.create_from_image(source.get_image())
	return _icons[resource]

func setup(map: StrategicMap, camera_rig: StrategyCamera) -> void:
	terrain = map
	rig = camera_rig
	# Call of War: every province produces one resource, shown at its centre.
	var hints: = []
	for entry in data().sites: hints.append({"resource": entry.resource, "point": GeographicProjection.project(entry.longitude, entry.latitude)})
	var city_names: = {}
	for city in GeographicProjection.load_cities(): city_names[city.name] = city.point
	for title in terrain.province_hubs:
		var hub: Vector2 = terrain.province_hubs[title]
		var parts: = terrain.territories.filter(func(t: Dictionary): return t.playable and t.title == title)
		if parts.is_empty(): continue
		var resource: = ""
		var city_name: = ""
		for name in city_names:
			if city_names[name].distance_to(hub) < 0.5: city_name = name
		if not city_name.is_empty(): resource = city_resources(city_name)[0]
		else:
			var votes: = {}
			for hint in hints:
				if parts.any(func(t: Dictionary): return RegionData.contains(t, hint.point)): votes[hint.resource] = votes.get(hint.resource, 0) + 1
			for candidate in votes:
				if resource.is_empty() or votes[candidate] > votes[resource]: resource = candidate
			if resource.is_empty():
				var geo: = GeographicProjection.unproject(hub)
				var land: = TerrainProfile.landform(geo.x, geo.y)
				# Only the northern taiga is timber country; forests further south are farmland.
				if land == "forest" and geo.y < float(data().get("forest_timber_latitude", 0.0)): land = "plains"
				resource = data().by_landform.get(land, "manpower")
		var site: = {"name": title, "resource": resource, "point": _beside(hub, 1.0 if not city_name.is_empty() else 0.55), "territory": parts[0], "city": city_name}
		sites.append(site)
		_build(site)

## A spot at `distance` from the province centre, on the side farthest from its roads.
func _beside(hub: Vector2, distance: float) -> Vector2:
	var road_points: = []
	for road in terrain.roads:
		if road[0].distance_to(hub) < 0.05 or road[1].distance_to(hub) < 0.05:
			road_points.append_array(Array(StrategicMap.road_curve(road[0], road[1], road[2])))
	var best: = hub + Vector2(distance, 0)
	var clearance: = -1.0
	for i in 12:
		var candidate: = hub + Vector2.from_angle(TAU * i / 12.0) * distance
		var nearest: = INF
		for point in road_points: nearest = minf(nearest, point.distance_to(candidate))
		if nearest > clearance:
			clearance = nearest
			best = candidate
	return best

## Income per country this tick, added by ProductionSystem.advance.
func income(seconds: float) -> Dictionary:
	var result: = {}
	for site in sites:
		var controller: String = site.territory.controller
		if not result.has(controller): result[controller] = {}
		result[controller][site.resource] = result[controller].get(site.resource, 0.0) + rate(site.resource) * seconds
	return result

func _process(_delta: float) -> void:
	if rig == null: return
	var show: = rig.rendered_distance < ICON_DISTANCE
	for badge in badges: badge.visible = show

func _build(site: Dictionary) -> void:
	var anchor: = Node3D.new()
	anchor.name = "Site_" + str(site.name).validate_node_name()
	var point: Vector2 = site.point
	var ground: = terrain.elevation(point)
	for i in 6: ground = maxf(ground, terrain.elevation(point + Vector2.from_angle(TAU * i / 6.0) * 0.22))
	anchor.position = Vector3(point.x, ground, point.y)
	anchor.rotation.y = float(abs(str(site.name).hash()) % 628) / 100.0
	anchor.scale = Vector3.ONE * 1.6
	add_child(anchor)
	var parts: = Parts.new()
	match site.resource:
		"fuel": _oil_field(parts)
		"materials": _timber(parts) if _forested(site.point) else _mine(parts)
		"electronics": _factory(parts)
		"manpower": _farm(parts)
		"funds": _factory(parts)
	parts.commit(anchor)
	var badge: = Sprite3D.new()
	badge.texture = icon(site.resource)
	badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	badge.fixed_size = true
	badge.pixel_size = 0.00017
	badge.no_depth_test = true
	badge.render_priority = 2
	badge.position = anchor.position + Vector3.UP * 0.38
	badge.set_meta("site", site.name)
	add_child(badge)
	badges.append(badge)

func _forested(point: Vector2) -> bool:
	var geo: = GeographicProjection.unproject(point)
	return TerrainProfile.landform(geo.x, geo.y) == "forest"

# --- Installations (local units; the anchor scales them by 1.6) ---------------------------

func _oil_field(p: Parts) -> void:
	for spot: Vector3 in [Vector3(-0.09, 0, -0.05), Vector3(0.08, 0, -0.08), Vector3(0.0, 0, 0.09)]:
		var turn: = spot.x * 9.0
		var basis: = Basis(Vector3.UP, turn)
		p.box("concrete", Vector3(0.15, 0.01, 0.045), spot + basis * Vector3(0, 0.005, 0), turn)
		p.box("steel", Vector3(0.012, 0.075, 0.03), spot + basis * Vector3(0, 0.047, 0), turn)
		p.box("steel", Vector3(0.15, 0.012, 0.014), spot + basis * Vector3(0.005, 0.088, 0), turn, 0.12)
		p.box("steel", Vector3(0.018, 0.045, 0.016), spot + basis * Vector3(0.078, 0.072, 0), turn)
		p.box("rust", Vector3(0.035, 0.03, 0.03), spot + basis * Vector3(-0.055, 0.025, 0), turn)
	p.cylinder("tank", 0.045, 0.055, Vector3(0.12, 0.0275, 0.07))
	p.cylinder("tank", 0.035, 0.045, Vector3(0.15, 0.0225, -0.01))

func _mine(p: Parts) -> void:
	for x in [-0.03, 0.03]:
		for z in [-0.03, 0.03]: p.box("steel", Vector3(0.01, 0.2, 0.01), Vector3(x, 0.1, z), 0.0)
	for y in [0.06, 0.13]: p.box("steel", Vector3(0.07, 0.008, 0.07), Vector3(0, y, 0), 0.0)
	p.box("steel", Vector3(0.08, 0.012, 0.08), Vector3(0, 0.205, 0), 0.0)
	p.cylinder("rust", 0.028, 0.008, Vector3(0, 0.235, 0), Vector3(PI * 0.5, 0, 0))
	p.box("brick", Vector3(0.09, 0.055, 0.07), Vector3(-0.1, 0.0275, 0.02), 0.0)
	p.box("roof", Vector3(0.095, 0.01, 0.075), Vector3(-0.1, 0.06, 0.02), 0.0)
	p.cone("ore", 0.1, 0.08, Vector3(0.11, 0.0, 0.06))
	p.cone("ore", 0.065, 0.05, Vector3(0.05, 0.0, 0.13))
	p.box("steel", Vector3(0.12, 0.01, 0.02), Vector3(0.055, 0.05, 0.03), -0.5, 0.55)

func _timber(p: Parts) -> void:
	p.box("wood", Vector3(0.12, 0.05, 0.07), Vector3(-0.07, 0.025, 0.0), 0.0)
	p.box("roof", Vector3(0.13, 0.01, 0.08), Vector3(-0.07, 0.055, 0.0), 0.0)
	for row in 3:
		for i in 4 - row:
			p.cylinder("log", 0.012, 0.14, Vector3(0.08, 0.012 + row * 0.021, -0.04 + i * 0.024 + row * 0.012), Vector3(0, 0, PI * 0.5))
	for i in 5:
		p.cone("pine", 0.035, 0.11, Vector3(-0.15 + i * 0.07, 0.0, -0.12 + (i % 2) * 0.02))

func _factory(p: Parts) -> void:
	p.box("wall", Vector3(0.24, 0.06, 0.15), Vector3(0, 0.03, 0), 0.0)
	for i in 4:
		p.prism("roof", Vector3(0.06, 0.03, 0.15), Vector3(-0.09 + i * 0.06, 0.075, 0))
	p.box("glass", Vector3(0.07, 0.09, 0.06), Vector3(0.16, 0.045, 0.04), 0.0)
	p.cylinder("brick", 0.012, 0.19, Vector3(-0.1, 0.095, -0.1))
	p.box("concrete", Vector3(0.3, 0.004, 0.22), Vector3(0.02, 0.002, 0), 0.0)

func _farm(p: Parts) -> void:
	for i in 3:
		var at: = Vector3(-0.04 + i * 0.055, 0, -0.06)
		p.cylinder("silo", 0.024, 0.12, at + Vector3(0, 0.06, 0))
		p.sphere("silo", 0.024, at + Vector3(0, 0.12, 0))
	p.box("barn", Vector3(0.1, 0.05, 0.06), Vector3(0.0, 0.025, 0.06), 0.0)
	p.prism("roof", Vector3(0.1, 0.03, 0.065), Vector3(0.0, 0.065, 0.06), PI * 0.5)
	for f in [[Vector3(-0.2, 0.002, 0.02), "wheat"], [Vector3(0.18, 0.002, -0.02), "crop"], [Vector3(0.0, 0.002, 0.2), "wheat"]]:
		p.box(f[1], Vector3(0.16, 0.004, 0.11), f[0], 0.0)

## Batches primitive parts per material into one mesh per material.
class Parts:
	const COLORS: = {"concrete": "68655d", "steel": "3d4144", "rust": "5a3a28", "tank": "66705f", "ore": "3b3936", "brick": "7d4b3a", "roof": "55595c", "wall": "655e55", "glass": "4f7189", "silo": "4f5355", "barn": "6e3027", "wheat": "75643a", "crop": "3c4e26", "wood": "7b5a3a", "log": "8d6a43", "pine": "2f4a2c"}
	var tools: Dictionary = {}
	func _add(material: String, mesh: PrimitiveMesh, transform: Transform3D) -> void:
		if not tools.has(material):
			var tool: = SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[material] = tool
		tools[material].append_from(mesh, 0, transform)
	func box(material: String, size: Vector3, center: Vector3, yaw: float, roll: float = 0.0) -> void:
		var mesh: = BoxMesh.new()
		mesh.size = size
		_add(material, mesh, Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, roll), center))
	func cylinder(material: String, radius: float, height: float, center: Vector3, euler: = Vector3.ZERO) -> void:
		var mesh: = CylinderMesh.new()
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		mesh.height = height
		mesh.radial_segments = 10
		mesh.rings = 1
		_add(material, mesh, Transform3D(Basis.from_euler(euler), center))
	func cone(material: String, radius: float, height: float, base: Vector3) -> void:
		var mesh: = CylinderMesh.new()
		mesh.top_radius = 0.0
		mesh.bottom_radius = radius
		mesh.height = height
		mesh.radial_segments = 9
		mesh.rings = 1
		_add(material, mesh, Transform3D(Basis.IDENTITY, base + Vector3.UP * height * 0.5))
	func sphere(material: String, radius: float, center: Vector3) -> void:
		var mesh: = SphereMesh.new()
		mesh.radius = radius
		mesh.height = radius * 2.0
		mesh.radial_segments = 10
		mesh.rings = 5
		_add(material, mesh, Transform3D(Basis.IDENTITY, center))
	func prism(material: String, size: Vector3, center: Vector3, yaw: float = 0.0) -> void:
		var mesh: = PrismMesh.new()
		mesh.size = size
		_add(material, mesh, Transform3D(Basis(Vector3.UP, yaw), center))
	func commit(parent: Node3D) -> void:
		for material in tools:
			var visual: = MeshInstance3D.new()
			var tool: SurfaceTool = tools[material]
			tool.generate_normals()
			visual.mesh = tool.commit()
			var shading: = StandardMaterial3D.new()
			shading.albedo_color = Color(COLORS[material])
			shading.roughness = 0.35 if material == "glass" else 0.85
			shading.metallic = 0.4 if material in ["steel", "tank", "glass"] else 0.0
			visual.material_override = shading
			parent.add_child(visual)
