extends SceneTree
## Original models for units/buildings that had none (owner 2026-10-13):
##  * Geran-2 one-way attack drone (Russia) and FP-1/Liutyi long-range drone (Ukraine);
##  * BMM-80 armoured ambulance (BTR-80 medical variant) and Boxer ambulance (field medics);
##  * hospital building (city and province).
##  * Owner 2026-10-15 ("same units on both sides"): Warmate loitering munition and Saab GlobalEye
##    radar plane for Ukraine. These two are built nose-forward along +X like the owner's models.
## Set ONLY=name,name to rebuild just some models.
## The models are written into assets/library (kept out of the public repository, like the
## owner's models) together with a preview picture in the same style as the arsenal renders.
##   xvfb-run -a godot --path . --script tools/make_new_models.gd
const ARSENAL: = "res://assets/library/arsenal/"
const BUILDINGS: = "res://assets/library/buildings_oct12/"

func _initialize() -> void: call_deferred("run")

func mat(color: Color, rough: float = 0.75, metal: float = 0.1) -> StandardMaterial3D:
	var m: = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m

func part(parent: Node3D, mesh: Mesh, material: Material, at: Vector3, rotation_deg: Vector3 = Vector3.ZERO, scale: Vector3 = Vector3.ONE, name: String = "") -> MeshInstance3D:
	var m: = MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = material
	m.position = at
	m.rotation_degrees = rotation_deg
	m.scale = scale
	if not name.is_empty(): m.name = name
	parent.add_child(m)
	return m

func box(size: Vector3) -> BoxMesh:
	var b: = BoxMesh.new(); b.size = size; return b

func cylinder(top: float, bottom: float, height: float, sides: int = 16) -> CylinderMesh:
	var c: = CylinderMesh.new(); c.top_radius = top; c.bottom_radius = bottom; c.height = height; c.radial_segments = sides; return c

## Flat wing/fin from an outline in the XZ plane (x = span, z = forward), extruded in Y.
func plate(outline: PackedVector2Array, thickness: float) -> ArrayMesh:
	var st: = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris: = Geometry2D.triangulate_polygon(outline)
	for side in [1.0, -1.0]:
		for i in range(0, tris.size(), 3):
			var order: Array = [0, 1, 2] if side > 0 else [0, 2, 1]
			for k in order:
				var p: Vector2 = outline[tris[i + k]]
				st.set_normal(Vector3(0, side, 0))
				st.add_vertex(Vector3(p.x, side * thickness * 0.5, p.y))
	for i in outline.size():
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % outline.size()]
		var n: = Vector3(b.y - a.y, 0, -(b.x - a.x)).normalized()
		for v in [Vector3(a.x, -thickness * 0.5, a.y), Vector3(b.x, -thickness * 0.5, b.y), Vector3(b.x, thickness * 0.5, b.y), Vector3(a.x, -thickness * 0.5, a.y), Vector3(b.x, thickness * 0.5, b.y), Vector3(a.x, thickness * 0.5, a.y)]:
			st.set_normal(n)
			st.add_vertex(v)
	return st.commit()

# ---------------------------------------------------------------- drones

func geran2() -> Node3D:
	# Geran-2 / Shahed-136: 3.5 m long cranked delta, ~2.5 m span, wingtip fins, rear pusher prop.
	var root: = Node3D.new(); root.name = "Geran2"
	var skin: = mat(Color("2b2d2f"), 0.6, 0.2)
	var dark: = mat(Color("151617"), 0.5, 0.3)
	var nose: = mat(Color("3a3c3e"), 0.5, 0.2)
	part(root, cylinder(0.16, 0.16, 2.6, 18), skin, Vector3(0, 0, 0.1), Vector3(90, 0, 0))
	part(root, cylinder(0.0, 0.16, 0.6, 18), nose, Vector3(0, 0, 1.7), Vector3(90, 0, 0))
	var wing: = PackedVector2Array([Vector2(0, 1.05), Vector2(1.25, -0.95), Vector2(1.25, -1.25), Vector2(0, -1.15), Vector2(-1.25, -1.25), Vector2(-1.25, -0.95)])
	part(root, plate(wing, 0.05), skin, Vector3(0, -0.02, 0))
	for side in [-1.0, 1.0]:
		var fin: = PackedVector2Array([Vector2(0, -0.95), Vector2(0, -1.25), Vector2(0.45, -1.25), Vector2(0.4, -1.1)])
		part(root, plate(fin, 0.03), skin, Vector3(side * 1.25, 0.0, 0), Vector3(0, 0, 90))
		part(root, plate(fin, 0.03), skin, Vector3(side * 1.25, 0.0, 0), Vector3(0, 0, -90))
	part(root, cylinder(0.12, 0.14, 0.25, 12), dark, Vector3(0, 0, -1.3), Vector3(90, 0, 0))   # engine
	for blade in 2:
		part(root, box(Vector3(0.9, 0.03, 0.08)), dark, Vector3(0, 0, -1.47), Vector3(0, 0, blade * 90))
	return root

func liutyi() -> Node3D:
	# FP-1 / Liutyi class long-range strike drone: slim fuselage, straight high wing, V-tail.
	var root: = Node3D.new(); root.name = "Liutyi"
	var skin: = mat(Color("8d9298"), 0.55, 0.15)
	var dark: = mat(Color("2a2c2e"), 0.5, 0.3)
	part(root, cylinder(0.18, 0.15, 3.6, 16), skin, Vector3(0, 0, 0), Vector3(90, 0, 0))
	part(root, cylinder(0.0, 0.18, 0.5, 16), skin, Vector3(0, 0, 2.05), Vector3(90, 0, 0))
	part(root, box(Vector3(6.2, 0.06, 0.55)), skin, Vector3(0, 0.18, 0.3))
	for side in [-1.0, 1.0]:
		part(root, box(Vector3(1.1, 0.04, 0.35)), skin, Vector3(side * 0.45, 0.32, -1.6), Vector3(0, 0, side * 35))
	part(root, cylinder(0.1, 0.12, 0.22, 12), dark, Vector3(0, 0, -1.9), Vector3(90, 0, 0))
	for blade in 2:
		part(root, box(Vector3(1.0, 0.03, 0.08)), dark, Vector3(0, 0, -2.04), Vector3(0, 0, blade * 90))
	return root


## Plate from an outline in the XY plane (x = forward, y = up), extruded along Z: fins and tails.
func fin(outline: PackedVector2Array, thickness: float) -> ArrayMesh:
	var flat: = plate(outline, thickness)
	var turned: = ArrayMesh.new()
	var st: = SurfaceTool.new()
	st.create_from(flat, 0)
	var arrays: = st.commit_to_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in vertices.size():
		vertices[i] = Vector3(vertices[i].x, vertices[i].z, vertices[i].y)
		normals[i] = Vector3(normals[i].x, normals[i].z, normals[i].y)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	turned.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return turned

func warmate() -> Node3D:
	# WB Electronics Warmate (Poland): ~1.1 m tube-launched loitering munition, 1.4 m straight high
	# wing, cruciform tail, rear pusher propeller, warhead/camera nose. +X is forward.
	var root: = Node3D.new(); root.name = "Warmate"
	var skin: = mat(Color("4b5442"), 0.6, 0.15)
	var dark: = mat(Color("1d1f1c"), 0.5, 0.3)
	var glass: = mat(Color("101418"), 0.15, 0.6)
	part(root, cylinder(0.055, 0.055, 0.82, 16), skin, Vector3(0, 0, 0), Vector3(0, 0, 90), Vector3.ONE, "Fuselage")
	part(root, cylinder(0.0, 0.055, 0.2, 16), skin, Vector3(0.51, 0, 0), Vector3(0, 0, -90), Vector3.ONE, "Warhead")
	part(root, cylinder(0.035, 0.035, 0.05, 12), glass, Vector3(0.38, -0.05, 0), Vector3.ZERO, Vector3.ONE, "Camera")
	var wing: = PackedVector2Array([Vector2(-0.7, 0.07), Vector2(0.7, 0.07), Vector2(0.7, -0.05), Vector2(-0.7, -0.05)])
	var w: = part(root, plate(PackedVector2Array([Vector2(0.07, -0.7), Vector2(0.07, 0.7), Vector2(-0.05, 0.7), Vector2(-0.05, -0.7)]), 0.012), skin, Vector3(0.05, 0.065, 0), Vector3.ZERO, Vector3.ONE, "Wing")
	w.rotation_degrees = Vector3(0, 0, 0)
	for k in 4:
		var tail: = part(root, fin(PackedVector2Array([Vector2(-0.38, 0.0), Vector2(-0.26, 0.0), Vector2(-0.33, 0.16), Vector2(-0.4, 0.16)]), 0.01), skin, Vector3.ZERO, Vector3(k * 90.0 + 45.0, 0, 0), Vector3.ONE, "Tail_%d" % k)
	part(root, cylinder(0.03, 0.045, 0.06, 12), dark, Vector3(-0.44, 0, 0), Vector3(0, 0, 90), Vector3.ONE, "Motor")
	for blade in 2:
		part(root, box(Vector3(0.012, 0.34, 0.03)), dark, Vector3(-0.48, 0, 0), Vector3(blade * 90.0, 0, 0), Vector3.ONE, "Prop_%d" % blade)
	return root

func globaleye() -> Node3D:
	# Saab GlobalEye (Sweden): Global 6000/6500 business-jet airframe, 30 m long, 31.7 m span,
	# swept low wing with winglets, T-tail, two rear engines, Erieye radar beam on top. +X is forward.
	var root: = Node3D.new(); root.name = "GlobalEye"
	var skin: = mat(Color("6f777e"), 0.5, 0.25)
	var light: = mat(Color("7c848b"), 0.5, 0.2)
	var dark: = mat(Color("2b2f33"), 0.4, 0.4)
	var glass: = mat(Color("12181e"), 0.1, 0.7)
	part(root, cylinder(1.25, 1.25, 20.0, 24), skin, Vector3(0.5, 0, 0), Vector3(0, 0, 90), Vector3.ONE, "Fuselage")
	part(root, cylinder(0.25, 1.25, 4.5, 24), skin, Vector3(12.75, -0.15, 0), Vector3(0, 0, -90), Vector3(1, 1, 0.95), "Nose")
	part(root, cylinder(0.35, 1.25, 6.0, 24), skin, Vector3(-12.5, 0.35, 0), Vector3(0, 0, 90), Vector3.ONE, "Tailcone")
	part(root, box(Vector3(1.4, 0.35, 1.9)), glass, Vector3(12.2, 0.75, 0), Vector3(0, 0, -18), Vector3.ONE, "Cockpit")
	# Swept wing with winglets.
	for side in [-1.0, 1.0]:
		var outline: = PackedVector2Array([Vector2(1.6, 0.0), Vector2(-1.2, 0.0), Vector2(-6.2, side * 15.2), Vector2(-4.6, side * 15.2)])
		if side < 0: outline.reverse()
		var wing: = part(root, plate(outline, 0.35), light, Vector3(0, -0.85, 0), Vector3.ZERO, Vector3.ONE, "Wing_%s" % ("R" if side > 0 else "L"))
		part(root, fin(PackedVector2Array([Vector2(-4.6, 0), Vector2(-6.2, 0), Vector2(-7.0, 2.0), Vector2(-6.0, 2.0)]), 0.15), light, Vector3(0, -0.85, side * 15.2), Vector3.ZERO, Vector3.ONE, "Winglet_%s" % ("R" if side > 0 else "L"))
		# Rear-mounted engines on pylons.
		part(root, cylinder(0.75, 0.65, 4.2, 18), dark, Vector3(-8.0, 0.9, side * 2.4), Vector3(0, 0, 90), Vector3.ONE, "Engine_%s" % ("R" if side > 0 else "L"))
		part(root, box(Vector3(1.6, 0.25, 1.1)), skin, Vector3(-8.0, 0.75, side * 1.5), Vector3.ZERO, Vector3.ONE)
		# Horizontal tail on top of the fin (T-tail).
		var tail: = PackedVector2Array([Vector2(-14.6, 0.0), Vector2(-16.6, 0.0), Vector2(-17.6, side * 5.0), Vector2(-16.4, side * 5.0)])
		if side < 0: tail.reverse()
		part(root, plate(tail, 0.2), light, Vector3(0, 5.7, 0), Vector3.ZERO, Vector3.ONE, "Stabiliser_%s" % ("R" if side > 0 else "L"))
	part(root, fin(PackedVector2Array([Vector2(-11.5, 0.5), Vector2(-14.2, 0.5), Vector2(-16.6, 5.7), Vector2(-14.6, 5.7)]), 0.3), light, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, "Fin")
	# Erieye ER radar: long flat beam on two struts above the fuselage, and ventral strakes.
	part(root, box(Vector3(8.6, 0.85, 0.75)), light, Vector3(-1.2, 2.35, 0), Vector3.ZERO, Vector3.ONE, "Erieye")
	part(root, box(Vector3(8.0, 0.08, 0.8)), dark, Vector3(-1.2, 2.8, 0), Vector3.ZERO, Vector3.ONE, "ErieyeTop")
	for x in [1.2, -3.6]:
		part(root, box(Vector3(1.2, 1.1, 0.35)), skin, Vector3(x, 1.5, 0), Vector3.ZERO, Vector3.ONE, "Strut")
	for side in [-1.0, 1.0]:
		part(root, box(Vector3(3.5, 0.9, 0.12)), skin, Vector3(-9.5, -1.0, side * 0.6), Vector3(side * 15.0, 0, 0), Vector3.ONE, "Strake")
	# Window line.
	for i in 10:
		for side in [-1.0, 1.0]:
			part(root, box(Vector3(0.45, 0.4, 0.05)), glass, Vector3(8.0 - i * 1.3, 0.35, side * 1.24), Vector3.ZERO, Vector3.ONE)
	return root

# ---------------------------------------------------------------- medical vehicles

## A white panel with a red cross. `normal` is the direction the panel faces (outwards).
func red_cross(parent: Node3D, at: Vector3, normal: Vector3, size: float) -> void:
	var white: = mat(Color("f2f2ee"), 0.6)
	var red: = mat(Color("c8102e"), 0.5)
	var holder: = Node3D.new()
	holder.position = at
	parent.add_child(holder)
	# Build facing +Z, then turn +Z to the requested normal.
	if normal.abs().is_equal_approx(Vector3.UP): holder.rotation_degrees = Vector3(-90 * signf(normal.y), 0, 0)
	else: holder.rotation.y = atan2(normal.x, normal.z)
	part(holder, box(Vector3(size, size, 0.02)), white, Vector3.ZERO)
	var bar: float = size * 0.62
	var thick: float = size * 0.2
	part(holder, box(Vector3(bar, thick, 0.02)), red, Vector3(0, 0, 0.015))
	part(holder, box(Vector3(thick, bar, 0.02)), red, Vector3(0, 0, 0.015))

func mesh_bounds(node: Node3D) -> AABB:
	var result: = AABB()
	var first: = true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi: = child as MeshInstance3D
		var box_aabb: AABB = mi.global_transform * mi.get_aabb()
		if first: result = box_aabb; first = false
		else: result = result.merge(box_aabb)
	return result

func ambulance(source: String, name: String) -> Node3D:
	var model: = Node3D.new(); model.name = name
	var vehicle: = (load(source) as PackedScene).instantiate() as Node3D
	model.add_child(vehicle)
	root.add_child(model)
	var bounds: = mesh_bounds(model)
	var long_x: bool = bounds.size.x > bounds.size.z
	var c: = bounds.get_center()
	var height: float = bounds.size.y
	var size: float = minf(height * 0.25, minf(bounds.size.x, bounds.size.z) * 0.28)
	# Side crosses towards the rear of the hull, flush with the armour.
	for side in [-1.0, 1.0]:
		var at: = Vector3(c.x, bounds.position.y + height * 0.4, c.z)
		var normal: = Vector3.ZERO
		if long_x:
			at.z = c.z + side * (bounds.size.z * 0.5 + 0.012)
			at.x = c.x - bounds.size.x * 0.18
			normal = Vector3(0, 0, side)
		else:
			at.x = c.x + side * (bounds.size.x * 0.5 + 0.012)
			at.z = c.z - bounds.size.z * 0.18
			normal = Vector3(side, 0, 0)
		red_cross(model, at, normal, size)
	# Roof height from the hull only (antennas and turrets would lift the cross into the air).
	var roof: = bounds.position.y + height * 0.5
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var part_box: AABB = (child as MeshInstance3D).global_transform * (child as MeshInstance3D).get_aabb()
		if maxf(part_box.size.x, part_box.size.z) > maxf(bounds.size.x, bounds.size.z) * 0.6: roof = maxf(roof, part_box.end.y)
	red_cross(model, Vector3(c.x - (bounds.size.x * 0.2 if long_x else 0.0), roof + 0.012, c.z - (0.0 if long_x else bounds.size.z * 0.2)), Vector3.UP, size * 1.2)
	root.remove_child(model)
	return model

# ---------------------------------------------------------------- hospital

func hospital() -> Node3D:
	var root: = Node3D.new(); root.name = "Hospital"
	var wall: = mat(Color("e9e6dc"), 0.85)
	var glass: = mat(Color("6f8ea6"), 0.2, 0.4)
	var roof: = mat(Color("9a9a94"), 0.9)
	var ground: = mat(Color("8c8f86"), 0.95)
	part(root, box(Vector3(9.0, 0.1, 7.0)), ground, Vector3(0, 0.05, 0))
	part(root, box(Vector3(6.0, 2.6, 2.4)), wall, Vector3(0, 1.4, -1.6))          # main wing
	part(root, box(Vector3(2.4, 2.0, 3.0)), wall, Vector3(-1.8, 1.1, 1.0))        # side wing
	part(root, box(Vector3(6.1, 0.12, 2.5)), roof, Vector3(0, 2.76, -1.6))
	part(root, box(Vector3(2.5, 0.12, 3.1)), roof, Vector3(-1.8, 2.16, 1.0))
	for floor_i in 3:
		for x in range(-5, 6, 2):
			part(root, box(Vector3(0.5, 0.45, 0.04)), glass, Vector3(x * 0.5, 0.65 + floor_i * 0.75, -0.38))
	red_cross(root, Vector3(0, 2.84, -1.6), Vector3.UP, 1.6)
	red_cross(root, Vector3(1.6, 2.2, -0.38), Vector3(0, 0, 1), 0.9)
	# Helipad and an ambulance bay.
	part(root, cylinder(1.1, 1.1, 0.04, 24), mat(Color("3d3f3c"), 0.9), Vector3(2.4, 0.12, 1.6))
	part(root, box(Vector3(0.18, 0.02, 1.2)), mat(Color("f0f0ea")), Vector3(2.15, 0.15, 1.6))
	part(root, box(Vector3(0.18, 0.02, 1.2)), mat(Color("f0f0ea")), Vector3(2.65, 0.15, 1.6))
	part(root, box(Vector3(0.68, 0.02, 0.18)), mat(Color("f0f0ea")), Vector3(2.4, 0.15, 1.6))
	return root

# ---------------------------------------------------------------- composed buildings

func placed(parent: Node3D, scene: Node3D, at: Vector3, length: float, yaw: float) -> void:
	parent.add_child(scene)
	var bounds: = mesh_bounds(scene)
	var factor: float = length / maxf(maxf(bounds.size.x, bounds.size.z), 0.001)
	scene.scale = Vector3.ONE * factor
	scene.rotation_degrees.y = yaw
	scene.position = at - Vector3(0, bounds.position.y * factor, 0)

func yard(stem: String, name: String) -> Node3D:
	var site: = Node3D.new(); site.name = name
	root.add_child(site)
	var hall: = (load("res://assets/library/" + stem + ".glb") as PackedScene).instantiate() as Node3D
	placed(site, hall, Vector3(0, 0, -1.2), 6.0, 0)
	var pad: = part(site, box(Vector3(8.5, 0.05, 7.0)), mat(Color("77786f"), 0.95), Vector3(0, 0.0, 0))
	pad.position.y = 0.025
	return site

func drone_factory() -> Node3D:
	var site: = yard("warehouse3_shared", "DroneFactory")
	for i in 4:
		placed(site, geran2(), Vector3(-2.6 + i * 1.4, 0.06, 2.2), 1.0, 180)
	var rail: = part(site, box(Vector3(0.25, 0.08, 2.4)), mat(Color("4a4c4e"), 0.6, 0.4), Vector3(3.2, 0.55, 1.6), Vector3(-14, 0, 0))
	part(site, box(Vector3(0.08, 0.6, 0.08)), mat(Color("4a4c4e")), Vector3(3.2, 0.3, 0.6))
	placed(site, geran2(), rail.position + Vector3(0, 0.12, 0.2), 1.0, 0)
	root.remove_child(site)
	return site

func support_depot() -> Node3D:
	var site: = yard("warehouse7_shared", "SupportDepot")
	placed(site, (load(ARSENAL + "russia_kamaz5350_supply.glb") as PackedScene).instantiate() as Node3D, Vector3(-2.5, 0.05, 2.0), 1.6, 90)
	placed(site, (load(ARSENAL + "russia_brem1m_recovery.glb") as PackedScene).instantiate() as Node3D, Vector3(0, 0.05, 2.0), 1.6, 90)
	placed(site, ambulance(ARSENAL + "russia_btr80.glb", "Ambulance"), Vector3(2.5, 0.05, 2.0), 1.6, 90)
	root.remove_child(site)
	return site

# ---------------------------------------------------------------- export and preview

func export_glb(scene: Node3D, path: String) -> void:
	var doc: = GLTFDocument.new()
	var state: = GLTFState.new()
	var holder: = Node3D.new()
	holder.add_child(scene)
	root.add_child(holder)
	var error: = doc.append_from_scene(scene, state)
	if error == OK: error = doc.write_to_filesystem(state, ProjectSettings.globalize_path(path))
	print("MODEL ", path, " ", error_string(error))
	holder.remove_child(scene)
	holder.queue_free()

func preview(scene: Node3D, path: String, size: Vector2i, flying: bool) -> void:
	var view: = SubViewport.new()
	view.size = size
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var env: = WorldEnvironment.new()
	var sky: = Sky.new()
	var sky_material: = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("8f8679")
	sky_material.sky_horizon_color = Color("e2b98a")
	sky_material.ground_horizon_color = Color("8a7a5c")
	sky_material.ground_bottom_color = Color("5b5a3e")
	sky.sky_material = sky_material
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_SKY
	env.environment.sky = sky
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.environment.ambient_light_energy = 0.8
	env.environment.fog_enabled = true
	env.environment.fog_light_color = Color("c9a985")
	env.environment.fog_density = 0.004
	view.add_child(env)
	var sun: = DirectionalLight3D.new()
	sun.light_color = Color("ffe6c4")
	sun.light_energy = 1.4
	sun.rotation_degrees = Vector3(-35, -40, 0)
	sun.shadow_enabled = true
	view.add_child(sun)
	var field: = MeshInstance3D.new()
	var plane: = PlaneMesh.new(); plane.size = Vector2(400, 400)
	field.mesh = plane
	field.material_override = mat(Color("5d5a35"), 1.0)
	view.add_child(field)
	var copy: = scene.duplicate() as Node3D
	view.add_child(copy)
	var bounds: = UnitVisual.model_bounds(UnitVisual.merged(scene.duplicate()), 0.0)
	var span: float = maxf(bounds.size.x, bounds.size.z)
	copy.position = -bounds.get_center() + Vector3(0, -bounds.position.y + bounds.get_center().y + (span * 0.35 if flying else 0.0), 0)
	copy.position.y = -bounds.position.y + (span * 0.35 if flying else 0.0)
	copy.rotation_degrees.y = -35
	var camera: = Camera3D.new()
	camera.fov = 30
	view.add_child(camera)
	camera.position = Vector3(0, span * 0.55 + (span * 0.35 if flying else 0.0), span * 2.3)
	camera.look_at(Vector3(0, bounds.size.y * 0.4 + (span * 0.35 if flying else 0.0), 0))
	for i in 10: await process_frame
	view.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("PREVIEW ", path)
	view.queue_free()

func run() -> void:
	var made: = [
		[warmate(), ARSENAL + "euro_warmate.glb", true],
		[globaleye(), ARSENAL + "euro_globaleye.glb", true],
		[geran2(), ARSENAL + "russia_geran2.glb", true],
		[liutyi(), ARSENAL + "ukraine_liutyi.glb", true],
		[ambulance(ARSENAL + "russia_btr80.glb", "BMM80"), ARSENAL + "russia_bmm80_medical.glb", false],
		[ambulance(ARSENAL + "euro_boxer.glb", "BoxerAmbulance"), ARSENAL + "euro_boxer_ambulance.glb", false],
		[hospital(), BUILDINGS + "hospital.glb", false],
		[drone_factory(), BUILDINGS + "drone_factory.glb", false],
		[support_depot(), BUILDINGS + "support_depot.glb", false],
	]
	var only: = OS.get_environment("ONLY")
	for entry in made:
		var scene: Node3D = entry[0]
		var path: String = entry[1]
		if not only.is_empty() and not path.get_file().get_basename() in only.split(","): continue
		var building: bool = path.begins_with(BUILDINGS)
		await preview(scene, path.trim_suffix(".glb") + ("_menu.png" if building else ".png"), Vector2i(512, 512) if building else Vector2i(1600, 1000), entry[2])
		export_glb(scene, path)
	quit()
