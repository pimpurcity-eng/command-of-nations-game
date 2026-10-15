extends SceneTree
## Unit cards (research / production pictures) rendered from the unit's own 3D model, for units
## that have no painted card yet (owner 2026-10-15: "can you make the cards yourself").
## Golden-hour sky, forest and hills, soft focus behind the vehicle; 512x512 like unit_art.
##   xvfb-run -a godot --path . --script tools/make_unit_cards.gd   (then tools/finish_unit_cards.py)
const OUT: = "/tmp/unit_cards/"
const CARDS: = [
	# model, output name, flying, yaw (deg), camera height factor
	["res://assets/library/arsenal/euro_warmate.glb", "euro_warmate", true, -28.0],
	["res://assets/library/arsenal/euro_globaleye.glb", "euro_globaleye", true, -32.0],
	["res://assets/library/arsenal/euro_lynx_kf41.glb", "euro_lynx_kf41", false, -38.0],
]
func _initialize() -> void: call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for card in CARDS: await render(card[0], card[1], card[2], card[3])
	quit()

func render(path: String, name: String, flying: bool, yaw: float) -> void:
	var view: = SubViewport.new()
	view.size = Vector2i(1024, 1024)
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_8X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var env: = Environment.new()
	var sky: = Sky.new()
	var sky_material: = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("6f8fb3")
	sky_material.sky_horizon_color = Color("f2c48d")
	sky_material.sky_curve = 0.12
	sky_material.ground_horizon_color = Color("8f8466")
	sky_material.ground_bottom_color = Color("3c4a2e")
	sky_material.sun_angle_max = 18.0
	sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color("e9c49a")
	env.fog_density = 0.0012
	env.fog_aerial_perspective = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.4
	var world_env: = WorldEnvironment.new()
	world_env.environment = env
	view.add_child(world_env)
	var sun: = DirectionalLight3D.new()
	sun.light_color = Color("ffd9a8")
	sun.light_energy = 1.6
	sun.rotation_degrees = Vector3(-22, 145, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120
	view.add_child(sun)
	var fill: = DirectionalLight3D.new()
	fill.light_color = Color("9fb6d6")
	fill.light_energy = 0.35
	fill.rotation_degrees = Vector3(-40, -40, 0)
	view.add_child(fill)
	# Land: rolling ground with forest and distant ridges.
	var rng: = RandomNumberGenerator.new()
	rng.seed = name.hash()
	var ground: = MeshInstance3D.new()
	var plane: = PlaneMesh.new()
	plane.size = Vector2(1200, 1200)
	plane.subdivide_width = 120
	plane.subdivide_depth = 120
	ground.mesh = plane
	var soil: = StandardMaterial3D.new()
	soil.albedo_color = Color("5b6a3b") if flying else Color("7a7451")
	soil.roughness = 1.0
	var noise: = FastNoiseLite.new()
	noise.frequency = 0.08
	var detail: = NoiseTexture2D.new()
	detail.noise = noise
	detail.width = 512
	detail.height = 512
	detail.seamless = true
	soil.albedo_texture = detail
	soil.uv1_scale = Vector3(60, 60, 1)
	ground.material_override = soil
	view.add_child(ground)
	var pine: = StandardMaterial3D.new()
	pine.albedo_color = Color("2f4a2a")
	pine.roughness = 1.0
	var rock: = StandardMaterial3D.new()
	rock.albedo_color = Color("5e5a4c")
	rock.roughness = 0.95
	for i in 2600:
		var at: = Vector3(rng.randf_range(-260, 260), 0, rng.randf_range(-320, 40))
		if not flying and (at.length() < 34 or at.z > -18): continue
		var tree: = MeshInstance3D.new()
		var cone: = CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = rng.randf_range(1.2, 2.2)
		cone.height = rng.randf_range(5.0, 9.0)
		cone.radial_segments = 6
		tree.mesh = cone
		tree.material_override = pine
		tree.position = at + Vector3.UP * cone.height * 0.5
		view.add_child(tree)
	for i in (0 if flying else 14):
		var ridge: = MeshInstance3D.new()
		var hill: = SphereMesh.new()
		hill.radius = rng.randf_range(60, 120)
		hill.height = hill.radius * 0.5
		ridge.mesh = hill
		var far: = StandardMaterial3D.new()
		far.albedo_color = Color("566a55").lerp(Color("8e9aa8"), rng.randf_range(0.3, 0.7))
		ridge.material_override = far
		ridge.position = Vector3(rng.randf_range(-500, 500), -hill.height * 0.15, rng.randf_range(-700, -450))
		view.add_child(ridge)
	if not flying:
		for i in 40:
			var stone: = MeshInstance3D.new()
			var lump: = SphereMesh.new()
			lump.radius = rng.randf_range(0.15, 0.45)
			lump.height = lump.radius * rng.randf_range(0.6, 1.2)
			stone.mesh = lump
			stone.material_override = rock
			stone.position = Vector3(rng.randf_range(-12, 12), -0.05, rng.randf_range(-4, 7))
			view.add_child(stone)
	# The unit itself, fitted to about 8 m across so every card frames the same way.
	var vehicle: Node3D = (load(path) as PackedScene).instantiate()
	var holder: = Node3D.new()
	holder.add_child(vehicle)
	view.add_child(holder)
	var bounds: = UnitVisual.model_bounds(vehicle, 0.0)
	var span: = maxf(bounds.size.x, bounds.size.z)
	var fit: = 8.0 / span
	vehicle.scale *= fit
	vehicle.position = -bounds.get_center() * fit
	vehicle.position.y = -bounds.position.y * fit
	holder.rotation_degrees.y = yaw
	var lift: = 70.0 if flying else 0.0
	holder.position.y = lift
	if flying: holder.rotation_degrees.z = -6.0
	var camera: = Camera3D.new()
	camera.fov = 34
	view.add_child(camera)
	camera.position = Vector3(1.5, lift + (-1.0 if flying else 1.6), 12.5)
	camera.look_at(Vector3(0, lift + bounds.size.y * fit * (0.6 if flying else 0.4), 0))
	var focus: = CameraAttributesPractical.new()
	focus.dof_blur_far_enabled = true
	focus.dof_blur_far_distance = 24.0
	focus.dof_blur_far_transition = 30.0
	focus.dof_blur_amount = 0.12
	camera.attributes = focus
	for i in 24: await process_frame
	view.get_texture().get_image().save_png(OUT + name + ".png")
	print("CARD ", name)
	view.queue_free()
