class_name CombatEffects
extends Node3D

const MAX_PROJECTILES: = 24
const MAX_IMPACTS: = 16
const MAX_SMOKE: = 64
const MAX_MUZZLES: = 24
const MAX_WRECKS: = 8
var smoke_jobs: Array = []
var muzzles: Array = []
var wrecks: Array = []
var damage_smoke_timer: = 0.0
var armies: UnitSystem
var clock: SimulationClock
var match_rules: MatchSystem
var projectiles: Array = []
var impacts: Array = []
var terrain: StrategicMap
var flight_scenes: Dictionary = {}
## Weapon and explosion sounds (set by main; none in tests that build effects alone).
var audio: GameAudio
func setup(units: UnitSystem, time: SimulationClock, rules: MatchSystem) -> void :
	armies = units
	clock = time
	match_rules = rules
	terrain = units.terrain
	rules.combat.weapon_fired.connect(on_shot)
	rules.air_combat.weapon_fired.connect(on_shot)
	rules.unit_destroyed.connect(on_destroyed)
func ink(color: Color) -> StandardMaterial3D:
	var material: = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
func sphere(parent: Node3D, radius: float, color: Color, smooth: bool = false) -> MeshInstance3D:
	var mesh: = MeshInstance3D.new()
	var shape: = SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2
	shape.radial_segments = 32 if smooth else 8
	shape.rings = 16 if smooth else 4
	mesh.mesh = shape
	mesh.material_override = ink(color)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh
func on_shot(source: Dictionary, target_unit: Dictionary, effect: String) -> void :
	var source_visible: = armies.visible_to_player(source)
	var target_visible: = armies.visible_to_player(target_unit)
	if not source_visible and not target_visible: return
	var start: Vector3 = source.node.position + Vector3.UP * 0.4
	var finish: Vector3 = target_unit.node.position + Vector3.UP * 0.2
	if audio != null: audio.play_shot(effect, source, start if source_visible else finish)
	if source_visible and effect == "interceptor":
		var model: Node3D = source.node.get_child(0)
		if model.has_meta("air_defense_animator"):
			var animator: AirDefenseAnimator = model.get_meta("air_defense_animator")
			animator.fire(finish)
			start = animator.muzzle_position()
	if source_visible:
		var direction: = (finish - start).normalized()
		if effect in ["missile", "nuke"]:
			source.heading = UnitVisual.firing_heading(source.equipment_id, direction)
			source.node.get_child(0).rotation.y = source.heading
			var launcher_model: Node3D = source.node.get_child(0)
			if launcher_model.has_meta("missile_launch_point"):
				var launch_point: Marker3D = launcher_model.get_meta("missile_launch_point")
				start = launch_point.global_position
		else: start += direction * 0.3
		muzzle_flash(source, start, direction, effect)
	if audio != null and armies != null and armies.air.is_air(source) and effect in ["air_strike", "drone_strike", "missile"]:
		audio.play("jet_flyby" if EquipmentIdentity.spec(source.equipment_id).get("role", "") != "drone" else "drone_strike", start if source_visible else finish)
	if not target_visible: return
	if not source_visible: start = finish + (start - finish).normalized() * 1.5 + Vector3.UP
	if effect == "air_strike":
		# Bombs fall from the aircraft onto the target (owner: "when they drop it's really crappy").
		var bomber: bool = EquipmentIdentity.spec(source.equipment_id).get("role", "") == "bomber"
		if audio != null: audio.play("bomb_whistle", finish)
		for i in (4 if bomber else 2):
			var spread: = Vector3(randf_range(-0.25, 0.25), 0, randf_range(-0.25, 0.25)) * (1.6 if bomber else 1.0)
			var drop: = Vector3(finish.x, maxf(start.y, finish.y + 1.6), finish.z) + Vector3(-0.4 * i, 0, 0.2 * i) * 0.4
			get_tree().create_timer(0.18 * i).timeout.connect(func(): launch(drop, finish + spread, "bomb", source.country))
		return
	var tier: Dictionary = EquipmentIdentity.research_tier(source.equipment_id, source.get("level", 1))
	if effect == "nuke":
		raise_and_fire(source, start, finish)
		return
	if effect == "missile" and source_visible and source.visual_kind == "missile_launcher" and source.node.get_child(0).has_meta("silo_missile"):
		silo_launch(source, finish, tier.get("projectile_model", ""))
		return
	if effect == "missile" and source_visible and source.visual_kind == "missile_launcher" and source.node.get_child(0).has_meta("erector_hinge"):
		erect_and_launch(source, finish, tier.get("projectile_model", ""))
		return
	launch(start, finish, effect, source.country, tier.get("projectile_model", ""))
## Owner 2026-10-15 ("make the missile come out of the silo as well, then disappear"): the lid
## slides open, the missile rises out of the shaft and flies off (the silo model's missile is hidden
## and the flying one takes over); the shaft is reloaded and the lid closes again.
func silo_launch(source: Dictionary, finish: Vector3, projectile_model: String) -> void:
	var pace: = 1.0 / maxf(1.0, clock.speed if clock != null else 1.0)
	var model: Node3D = source.node.get_child(0)
	var lid: Node3D = model.get_meta("silo_lid")
	var missile: Node3D = model.get_meta("silo_missile")
	var lid_rest: Vector3 = model.get_meta("silo_lid_rest")
	var missile_rest: Vector3 = model.get_meta("silo_missile_rest")
	var length: float = model.get_meta("silo_missile_length")
	var sequence: = create_tween()
	sequence.tween_property(lid, "position:x", lid_rest.x + float(model.get_meta("silo_lid_slide")), 0.8 * pace).set_trans(Tween.TRANS_SINE)
	sequence.tween_callback(func():
		if is_instance_valid(missile):
			missile.position = missile_rest
			missile.visible = true
			smoke_puff(model.global_position + Vector3.UP * 0.05, false, 0.2))
	sequence.tween_property(missile, "position:y", missile_rest.y + float(model.get_meta("silo_rise")), 1.4 * pace).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	sequence.tween_callback(func():
		if not is_instance_valid(missile): return
		var nose: Vector3 = missile.global_transform * Vector3(length, 0, 0)
		missile.visible = false
		launch(nose, finish, "missile", source.country, projectile_model)
		smoke_puff(model.global_position + Vector3.UP * 0.1, true, 0.25))
	sequence.tween_interval(2.0 * pace)
	sequence.tween_callback(func():
		if is_instance_valid(missile):
			missile.position = missile_rest
			missile.visible = true)
	sequence.tween_property(lid, "position:x", lid_rest.x, 1.0 * pace).set_trans(Tween.TRANS_SINE)
## How far each launcher family raises its arm before firing (degrees).
const ERECT_ANGLE: = {"rockets": 45.0, "coastal_missiles": 40.0, "missiles": 72.0}
## Owner 2026-10-15 ("do this for all missile launchers"): the arm rises, the missile leaves from
## the tube mouth, and the arm folds back down once the salvo is away.
func erect_and_launch(source: Dictionary, finish: Vector3, projectile_model: String) -> void:
	var pace: = 1.0 / maxf(1.0, clock.speed if clock != null else 1.0)
	var model: Node3D = source.node.get_child(0)
	var hinge: Node3D = model.get_meta("erector_hinge")
	var family: String = str(source.equipment_id).rsplit("_", true, 1)[0]
	var angle: = deg_to_rad(float(ERECT_ANGLE.get(family, 60.0)))
	var rise: = 1.2 * pace
	var raised: = create_tween()
	raised.tween_property(hinge, "rotation:z", angle, rise).set_trans(Tween.TRANS_SINE)
	raised.tween_callback(func():
		if not is_instance_valid(hinge): return
		var mouth: Vector3 = hinge.global_transform * (model.get_meta("erector_mouth") as Vector3)
		launch(mouth, finish, "missile", source.country, projectile_model)
		smoke_puff(mouth, true, 0.12))
	raised.tween_interval(1.5 * pace)
	raised.tween_property(hinge, "rotation:z", 0.0, rise * 1.5).set_trans(Tween.TRANS_SINE)
## Owner 2026-10-15: before a nuclear launch the launcher's arm rises to vertical, the cap opens
## and the missile leaves the tube; it then flies to the target and the blast follows. The whole
## sequence lasts CombatSystem.NUKE_FLIGHT, shortened at higher game speeds.
func raise_and_fire(source: Dictionary, start: Vector3, finish: Vector3) -> void:
	var pace: = 1.0 / maxf(1.0, clock.speed if clock != null else 1.0)
	var exit: = {"at": start}  # where the missile leaves the tube (set when it does)
	var model: Node3D = source.node.get_child(0) if source.node.get_child_count() > 0 else null
	var hinge: Node3D = model.get_meta("erector_hinge", null) if model != null else null
	var rise: = 3.0 * pace
	if hinge != null and is_instance_valid(hinge):
		var tween: = create_tween()
		tween.tween_property(hinge, "rotation:z", deg_to_rad(88.0), rise).set_trans(Tween.TRANS_SINE)
		var cap: Node3D = model.get_meta("erector_cap", null)
		if cap != null: tween.tween_callback(func(): if is_instance_valid(cap): cap.visible = false)
		var missile: Node3D = model.get_meta("erector_missile", null)
		if missile != null:
			var out: = float(model.get_meta("erector_length", 10.0))
			tween.tween_property(missile, "position:x", missile.position.x + out, 1.0 * pace).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.tween_callback(func():
				if is_instance_valid(missile):
					exit.at = hinge.global_transform * (model.get_meta("erector_mouth") as Vector3)
					missile.visible = false)
		if audio != null: audio.play("nuclear_alarm", exit.at)
	else: rise = 0.5 * pace
	var flight: = 4.0 * pace
	get_tree().create_timer(rise + 1.0 * pace).timeout.connect(func():
		var tier: Dictionary = EquipmentIdentity.research_tier(source.equipment_id, source.get("level", 1))
		var from: Vector3 = exit.at
		launch(from + Vector3.UP * 0.3, finish, "missile", source.country, tier.get("projectile_model", ""), flight)
		smoke_puff(from, true, 0.25)
		get_tree().create_timer(flight).timeout.connect(func(): nuke(finish, StrategicWeapons.WEAPONS.nuclear.radius)))

func smoke_puff(position: Vector3, dark: bool = false, size: float = 0.08) -> void:
	if smoke_jobs.size() >= MAX_SMOKE: return
	if armies != null and not armies.point_visible(Vector2(position.x, position.z)): return
	var root: = Node3D.new()
	add_child(root)
	root.position = position
	var puff: = MeshInstance3D.new()
	var shape: = QuadMesh.new()
	shape.size = Vector2.ONE * size * 4
	puff.mesh = shape
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material: = ink(Color(0.15, 0.16, 0.16, 0.4) if dark else Color(0.75, 0.76, 0.73, 0.22))
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var gradient: = Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	var texture: = GradientTexture2D.new()
	texture.width = 32
	texture.height = 32
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1, 0.5)
	material.albedo_texture = texture
	puff.material_override = material
	root.add_child(puff)
	smoke_jobs.append({"node": root, "puff": puff, "age": 0.0, "duration": 2.5 if dark else 1.2, "alpha": 0.55 if dark else 0.4})
func muzzle_flash(source: Dictionary, position: Vector3, direction: Vector3, effect: String) -> void:
	if muzzles.size() >= MAX_MUZZLES: return
	var root: = Node3D.new()
	add_child(root)
	root.position = position
	sphere(root, 0.07 if effect == "tracer" else 0.12, Color("fff0bb"))
	var model: Node3D = source.node.get_child(0)
	for i in range(muzzles.size() - 1, -1, -1):
		if muzzles[i].model == model:
			model.position = muzzles[i].offset
			muzzles[i].node.queue_free()
			muzzles.remove_at(i)
	# Recoil is a visual offset; it never changes the army's world position.
	var offset: = model.position
	var recoil: = Vector3.ZERO if effect in ["missile", "interceptor", "air_strike", "drone_strike"] else -direction * 0.045
	model.position = offset + recoil
	muzzles.append({"node": root, "model": model, "offset": offset, "recoil": recoil, "age": 0.0})
	smoke_puff(position, false, 0.06)
func launch(start: Vector3, finish: Vector3, effect: String, country: String = "russia", projectile_model: String = "", flight_time: float = 0.0) -> void :
	if projectiles.size() >= MAX_PROJECTILES: return
	var root: = Node3D.new()
	add_child(root)
	root.position = start
	if effect in ["missile", "interceptor"]:
		var path: String = projectile_model if not projectile_model.is_empty() else "res://assets/library/arsenal/russia_p800_oniks.glb" if country == "russia" else "res://assets/library/arsenal/euro_nsm.glb"
		if not flight_scenes.has(path): flight_scenes[path] = load(path)
		var original: Node3D = flight_scenes[path].instantiate()
		var body: Node3D = UnitVisual.merged(original)
		var pivot: = Node3D.new()
		pivot.add_child(body)
		UnitVisual._fit(pivot, body, "projectile", path)
		root.add_child(pivot)
		root.set_meta("projectile_model", path)
	else:
		var shell: = CylinderMesh.new()
		shell.top_radius = 0.012
		shell.bottom_radius = 0.035
		shell.height = 0.18
		shell.radial_segments = 6
		var body: = MeshInstance3D.new()
		body.mesh = shell
		body.rotation.x = PI / 2
		body.material_override = ink(Color("ffe4ab"))
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(body)
	var glow: = sphere(root, 0.06 if effect in ["missile","interceptor"] else 0.025, Color("ffbc62"))
	glow.position.z = 0.12
	var trail: = MeshInstance3D.new()
	var tube: = CylinderMesh.new()
	tube.top_radius = 0.01
	tube.bottom_radius = 0.07
	tube.height = 0.6
	tube.radial_segments = 6
	trail.mesh = tube
	trail.rotation.x = PI / 2
	trail.position.z = 0.4
	trail.material_override = ink(Color(0.75, 0.75, 0.7, 0.4))
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(trail)
	trail.visible = false
	var duration: = clampf(start.distance_to(finish) * 0.15 + 0.65, 0.8, 2.0)
	if effect in ["missile","interceptor"]: duration = clampf(start.distance_to(finish)*0.25+2.0,2.4,4.0)
	if effect in ["cannon", "tracer", "skirmish"]: duration = clampf(start.distance_to(finish) * 0.08, 0.12, 0.4)
	if effect == "bomb": duration = 1.3
	if flight_time > 0.0: duration = flight_time
	projectiles.append({"node": root, "start": start, "finish": finish, "effect": effect, "age": 0.0, "trail_age": 0.0, "duration": duration})
func trajectory(job: Dictionary, fraction: float) -> Vector3:
	var position: Vector3 = job.start.lerp(job.finish, fraction)
	var arc: = sin(fraction * PI) * (1.8 if job.effect == "artillery" else 0.75 if job.effect == "missile" else 0.0)
	position.y += arc
	if job.effect == "bomb":
		# Released from the aircraft: carried forward, falling faster and faster.
		position = job.start.lerp(job.finish, fraction)
		position.y = lerpf(job.start.y, job.finish.y, fraction * fraction)

	if job.effect == "missile" and fraction > 0.1 and fraction < 0.9:
		position.y = maxf(position.y, terrain.elevation(Vector2(position.x, position.z)) + 0.5)
	return position
## Owner 2026-10-13 ("the explosions are crap"): a real blast - light flash, a particle
## fireball, sparks and debris thrown out, a rising smoke column and a ground shock ring.
func explode(position: Vector3, large: bool = false, power: float = 1.0) -> void :
	if audio != null: audio.play("explosion_large" if large else "explosion_small", position)
	if impacts.size() >= MAX_IMPACTS: return
	if armies != null and not armies.point_visible(Vector2(position.x, position.z)): return
	var size: float = (1.6 if large else 1.0) * power
	var root: = Node3D.new()
	add_child(root)
	root.position = position
	var light: = OmniLight3D.new()
	light.light_color = Color("ffb35c")
	light.light_energy = 6.0 * size
	light.omni_range = 1.2 * size
	light.shadow_enabled = false
	root.add_child(light)
	# Glowing core that swells and fades, wrapped in a boiling particle fireball.
	var core: = sphere(root, 0.1 * size, Color(1.0, 0.82, 0.45, 1.0), true)
	core.material_override.emission_enabled = true
	core.material_override.emission = Color("ff9a30")
	core.material_override.emission_energy_multiplier = 2.5
	# Owner 2026-10-14: the same glowing fire as the nuke, much smaller - a boiling fireball
	# and, for missiles and bombs, a little mushroom of fire rising off it.
	var fire: = _cloud_burst(Color(1.0, 0.97, 0.85, 1.0), Color(1.0, 0.55, 0.12, 0.9), Color(0.45, 0.12, 0.04, 0.0), int(18 * size), 1.1, 0.4 * size, 0.4 * size, -0.4, true)
	fire.emission_sphere_radius = 0.08 * size
	root.add_child(fire)
	if large:
		var stem: = _cloud_burst(Color(0.9, 0.5, 0.2, 0.45), Color(0.4, 0.3, 0.24, 0.25), Color(0.2, 0.18, 0.17, 0.0), int(12 * size), 1.4, 0.55 * size, 0.22 * size, 0.0, true)
		stem.spread = 8.0
		stem.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		stem.emission_box_extents = Vector3(0.03, 0.01, 0.03) * size
		root.add_child(stem)
		var cap: = _cloud_burst(Color(1.0, 0.75, 0.4, 0.6), Color(0.5, 0.36, 0.28, 0.3), Color(0.25, 0.22, 0.2, 0.0), int(16 * size), 1.6, 0.15 * size, 0.32 * size, -0.05, true)
		cap.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		cap.emission_ring_axis = Vector3.UP
		cap.emission_ring_radius = 0.16 * size
		cap.emission_ring_inner_radius = 0.06 * size
		cap.emission_ring_height = 0.04 * size
		cap.flatness = 0.4
		cap.position.y = 0.55 * size
		root.add_child(cap)
	root.add_child(_burst(Color("ffe08a"), Color("ff9a2a"), Color(1, 0.5, 0.1, 0.0), int(14 * size), 0.5, 2.6 * size, 0.035 * size, 3.5, 0.0))  # sparks
	root.add_child(_burst(Color(0.12, 0.11, 0.1, 1.0), Color(0.18, 0.16, 0.14, 1.0), Color(0.2, 0.18, 0.16, 0.0), int(8 * size), 1.1, 1.6 * size, 0.03 * size, 4.0, 0.0, true))  # debris
	root.add_child(_burst(Color(0.22, 0.2, 0.19, 0.75), Color(0.3, 0.29, 0.28, 0.5), Color(0.45, 0.44, 0.42, 0.0), int(10 * size), 2.6, 0.35 * size, 0.22 * size, -0.25, 0.25))  # smoke
	var ring: = MeshInstance3D.new()
	var torus: = TorusMesh.new()
	torus.inner_radius = 0.17
	torus.outer_radius = 0.2
	torus.rings = 24
	torus.ring_segments = 4
	ring.mesh = torus
	ring.material_override = ink(Color(0.95, 0.75, 0.45, 0.55))
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	impacts.append({"node": root, "light": light, "core": core, "ring": ring, "age": 0.0, "size": size, "life": 3.0})

static var _soft_texture: GradientTexture2D
## A one-shot particle burst. Colours fade start -> middle -> end over the particle's life.
func _burst(start: Color, middle: Color, finish: Color, amount: int, life: float, speed: float, particle_size: float, gravity: float, delay: float, solid: bool = false) -> CPUParticles3D:
	var particles: = CPUParticles3D.new()
	particles.one_shot = true
	particles.emitting = true
	particles.amount = maxi(2, amount)
	particles.lifetime = life
	particles.explosiveness = 0.92
	particles.preprocess = 0.0
	particles.local_coords = false
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = particle_size * 0.6
	particles.direction = Vector3.UP
	particles.spread = 180.0 if gravity > 0.0 else 70.0
	particles.initial_velocity_min = speed * 0.5
	particles.initial_velocity_max = speed
	particles.gravity = Vector3(0, -gravity, 0)
	particles.damping_min = 0.6
	particles.damping_max = 1.2
	particles.scale_amount_min = 0.7
	particles.scale_amount_max = 1.3
	var growth: = Curve.new()
	growth.add_point(Vector2(0, 0.5 if not solid else 1.0))
	growth.add_point(Vector2(1, 2.2 if not solid else 1.0))
	particles.scale_amount_curve = growth
	var ramp: = Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	ramp.colors = PackedColorArray([start, middle, finish])
	particles.color_ramp = ramp
	var material: = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if solid:
		var chunk: = BoxMesh.new()
		chunk.size = Vector3.ONE * particle_size
		chunk.material = material
		particles.mesh = chunk
	else:
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		if _soft_texture == null:
			var gradient: = Gradient.new()
			gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
			_soft_texture = GradientTexture2D.new()
			_soft_texture.width = 64
			_soft_texture.height = 64
			_soft_texture.gradient = gradient
			_soft_texture.fill = GradientTexture2D.FILL_RADIAL
			_soft_texture.fill_from = Vector2(0.5, 0.5)
			_soft_texture.fill_to = Vector2(1, 0.5)
		material.albedo_texture = _soft_texture
		var quad: = QuadMesh.new()
		quad.size = Vector2.ONE * particle_size
		quad.material = material
		particles.mesh = quad
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles

## Owner 2026-10-13 ("it's the biggest point in the game ... make it amazing"): a nuclear
## detonation - blinding flash and camera shake, a boiling fireball of cloud particles rising
## into a rolling mushroom cap on a churning stem, a white condensation ring, a ground-hugging
## shock wave and dust storm, burning ruins and a glowing radioactive fallout zone.
func nuke(position: Vector3, radius: float, fallout_seconds: float = 0.0) -> void:
	if audio != null: audio.play("nuclear_blast")
	var root: = Node3D.new()
	add_child(root)
	root.position = position
	var r: = radius
	var light: = OmniLight3D.new()
	light.light_color = Color("fff1d0")
	light.light_energy = 60.0
	light.omni_range = r * 8.0
	root.add_child(light)
	# Fireball: an emissive core inside boiling, glowing cloud puffs.
	var fireball: = sphere(root, r * 0.28, Color(1.0, 0.92, 0.7, 1.0), true)
	fireball.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var fire_cloud: = _cloud_burst(Color(1.0, 0.97, 0.85, 1.0), Color(1.0, 0.55, 0.12, 0.95), Color(0.45, 0.12, 0.04, 0.0), 90, 2.8, r * 0.35, r * 0.75, 0.0, true)
	fire_cloud.emission_sphere_radius = r * 0.3
	fire_cloud.one_shot = false
	fire_cloud.explosiveness = 0.2
	root.add_child(fire_cloud)
	# Stem: a churning column of fire at the bottom turning to brown smoke.
	var stem: = _cloud_burst(Color(0.7, 0.36, 0.14, 0.32), Color(0.32, 0.25, 0.2, 0.2), Color(0.2, 0.18, 0.17, 0.0), 140, 3.4, r * 0.75, r * 0.45, 0.0, true)
	stem.one_shot = false
	stem.explosiveness = 0.0
	stem.spread = 5.0
	stem.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	stem.emission_box_extents = Vector3(r * 0.13, 0.02, r * 0.13)
	stem.damping_min = 0.0
	stem.damping_max = 0.1
	root.add_child(stem)
	# Cap: a rolling ring of cloud, hot inside, dark and heavy outside.
	var cap: = _cloud_burst(Color(0.75, 0.4, 0.17, 0.3), Color(0.36, 0.28, 0.23, 0.2), Color(0.22, 0.2, 0.19, 0.0), 220, 7.0, r * 0.38, r * 0.85, -0.02, true)
	cap.one_shot = false
	cap.explosiveness = 0.0
	cap.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	cap.emission_ring_axis = Vector3.UP
	cap.emission_ring_radius = r * 0.85
	cap.emission_ring_inner_radius = r * 0.35
	cap.emission_ring_height = r * 0.25
	cap.direction = Vector3.UP
	cap.spread = 80.0
	cap.flatness = 0.45
	root.add_child(cap)
	var cap_glow: = _cloud_burst(Color(1.0, 0.7, 0.35, 0.5), Color(0.9, 0.35, 0.08, 0.35), Color(0.4, 0.1, 0.03, 0.0), 60, 2.5, r * 0.2, r * 0.6, 0.0, true)
	cap_glow.one_shot = false
	cap_glow.explosiveness = 0.0
	cap_glow.emission_sphere_radius = r * 0.35
	root.add_child(cap_glow)
	# Condensation ring around the rising stem.
	var halo: = MeshInstance3D.new()
	var halo_shape: = TorusMesh.new()
	halo_shape.inner_radius = 0.85
	halo_shape.outer_radius = 1.0
	halo_shape.rings = 64
	halo_shape.ring_segments = 8
	halo.mesh = halo_shape
	halo.material_override = ink(Color(1, 1, 1, 0.55))
	root.add_child(halo)
	# Ground shock wave and the dust storm it pushes out.
	var shock: = MeshInstance3D.new()
	var wave: = TorusMesh.new()
	wave.inner_radius = 0.93
	wave.outer_radius = 1.0
	wave.rings = 64
	wave.ring_segments = 6
	shock.mesh = wave
	shock.material_override = ink(Color(1.0, 0.95, 0.85, 0.8))
	root.add_child(shock)
	var dust: = _cloud_burst(Color(0.62, 0.52, 0.42, 0.85), Color(0.55, 0.48, 0.4, 0.6), Color(0.55, 0.5, 0.45, 0.0), 140, 5.0, r * 2.4, r * 0.55, 0.0, false)
	dust.direction = Vector3.RIGHT
	dust.spread = 180.0
	dust.flatness = 1.0
	dust.emission_sphere_radius = r * 0.25
	dust.damping_min = r * 0.4
	dust.damping_max = r * 0.6
	root.add_child(dust)
	root.add_child(_burst(Color("ffe08a"), Color("ff6a1a"), Color(0.6, 0.15, 0.0, 0.0), 70, 1.8, r * 4.0, r * 0.07, 2.0, 0.0))
	# Scorched ground and burning ruins.
	var scorch: = MeshInstance3D.new()
	var disc: = CylinderMesh.new()
	disc.top_radius = r * 1.1
	disc.bottom_radius = r * 1.1
	disc.height = 0.01
	disc.radial_segments = 48
	scorch.mesh = disc
	var burnt: = StandardMaterial3D.new()
	burnt.albedo_texture = _scorch_texture()
	burnt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	burnt.albedo_color = Color(1, 1, 1, 0.0)
	scorch.material_override = burnt
	scorch.position.y = 0.02
	root.add_child(scorch)
	var fires: Array = []
	for i in 10:
		var spot: = Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 10.0 + randf() * 0.4) * r * randf_range(0.15, 0.85)
		var fire: = _cloud_burst(Color(1.0, 0.8, 0.35, 0.9), Color(1.0, 0.35, 0.05, 0.7), Color(0.2, 0.18, 0.16, 0.0), 14, 1.6, r * 0.18, r * 0.16, -0.3, true)
		fire.one_shot = false
		fire.explosiveness = 0.0
		fire.emitting = false
		fire.position = spot + Vector3.UP * 0.05
		root.add_child(fire)
		fires.append(fire)
	nuke_jobs.append({"node": root, "light": light, "fireball": fireball, "fire_cloud": fire_cloud, "cap": cap, "cap_glow": cap_glow, "stem": stem,
		"halo": halo, "shock": shock, "scorch": scorch, "fires": fires, "radius": r, "age": 0.0})
	_screen_flash(Color(1, 0.98, 0.9, 1.0))
	shake = maxf(shake, 1.0)
	if fallout_seconds > 0.0: _fallout_zone(position, r * 1.5, fallout_seconds)

const USE_CLOUD_FOR_SMOKE: = false
var nuke_jobs: Array = []
var shake: = 0.0
var _flash: ColorRect
var _warning: Label
var warning_time: = 0.0
func _overlay() -> void:
	if _flash != null: return
	var layer: = CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.visible = false
	layer.add_child(_flash)
	_warning = Label.new()
	_warning.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_warning.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_warning.grow_vertical = Control.GROW_DIRECTION_BOTH
	_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning.text = "☢ NUCLEAR MISSILE INBOUND ☢"
	_warning.add_theme_font_size_override("font_size", 52)
	var banner: = StyleBoxFlat.new()
	banner.bg_color = Color(0.25, 0.0, 0.0, 0.85)
	banner.set_content_margin_all(18)
	banner.border_color = Color("ffcc00")
	banner.set_border_width_all(4)
	_warning.add_theme_stylebox_override("normal", banner)
	_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warning.custom_minimum_size = Vector2(620, 0)
	_warning.add_theme_color_override("font_color", Color("fff2e0"))
	_warning.add_theme_color_override("font_outline_color", Color("3a0000"))
	_warning.add_theme_constant_override("outline_size", 10)
	_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warning.visible = false
	layer.add_child(_warning)
func _screen_flash(colour: Color) -> void:
	_overlay()
	_flash.color = colour
	_flash.visible = true
	flash_age = 0.0

## Owner 2026-10-13: "make their whole screen flash red when a nuke's coming in ... go berserk".
func nuke_warning(seconds: float) -> void:
	_overlay()
	warning_time = seconds
	_warning.visible = true
	if audio != null:
		audio.play("war_declared")
		audio.play("nuclear_alarm")
var flash_age: = 0.0

## A radioactive fallout zone: a glowing yellow-green haze and drifting particles that stay on
## the map until the fallout ends (game time).
func _fallout_zone(position: Vector3, radius: float, seconds: float) -> void:
	var root: = Node3D.new()
	add_child(root)
	root.position = position
	var haze: = MeshInstance3D.new()
	var disc: = CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.01
	disc.radial_segments = 64
	haze.mesh = disc
	var glow: = StandardMaterial3D.new()
	glow.albedo_texture = _fallout_texture()
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1, 1, 1, 0.75)
	haze.material_override = glow
	haze.position.y = 0.04
	root.add_child(haze)
	var motes: = _cloud_burst(Color(0.75, 1.0, 0.3, 0.0), Color(0.7, 0.95, 0.25, 0.45), Color(0.55, 0.8, 0.2, 0.0), 60, 6.0, 0.05, radius * 0.35, -0.02, true)
	motes.one_shot = false
	motes.explosiveness = 0.0
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	motes.emission_sphere_radius = radius * 0.8
	motes.position.y = 0.2
	root.add_child(motes)
	var end: float = (clock.elapsed if clock != null else 0.0) + seconds
	fallout_zones.append({"node": root, "end": end, "haze": haze})
var fallout_zones: Array = []

static var _cloud_tex: ImageTexture
## Soft, lumpy cloud sprite (fractal noise inside a round falloff) for smoke and fire.
static func cloud_texture() -> ImageTexture:
	if _cloud_tex != null: return _cloud_tex
	var noise: = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_octaves = 4
	noise.frequency = 0.045
	var size: = 128
	var image: = Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var d: = Vector2(x - size * 0.5, y - size * 0.5).length() / (size * 0.5)
			var n: = noise.get_noise_2d(x, y) * 0.5 + 0.5
			var a: = clampf((1.0 - d * d) * (0.35 + 0.9 * n) - 0.08, 0.0, 1.0)
			var shade: = 0.75 + 0.25 * n
			image.set_pixel(x, y, Color(shade, shade, shade, a))
	_cloud_tex = ImageTexture.create_from_image(image)
	return _cloud_tex

static var _scorch_tex: ImageTexture
static func _scorch_texture() -> ImageTexture:
	if _scorch_tex != null: return _scorch_tex
	var noise: = FastNoiseLite.new()
	noise.frequency = 0.06
	var size: = 128
	var image: = Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var d: = Vector2(x - size * 0.5, y - size * 0.5).length() / (size * 0.5)
			var n: = noise.get_noise_2d(x, y) * 0.5 + 0.5
			var a: = clampf((1.0 - d) * 1.6 * (0.6 + 0.6 * n), 0.0, 0.92)
			image.set_pixel(x, y, Color(0.08 + 0.06 * n, 0.07 + 0.04 * n, 0.06, a))
	_scorch_tex = ImageTexture.create_from_image(image)
	return _scorch_tex

static var _fallout_tex: ImageTexture
static func _fallout_texture() -> ImageTexture:
	if _fallout_tex != null: return _fallout_tex
	var size: = 128
	var image: = Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var d: = Vector2(x - size * 0.5, y - size * 0.5).length() / (size * 0.5)
			var edge: = clampf(1.0 - absf(d - 0.94) * 30.0, 0.0, 1.0)
			var a: = clampf(0.28 * (1.0 - d * d), 0.0, 1.0) + 0.6 * edge
			var stripe: = 0.5 + 0.5 * sin((x + y) * 0.35)
			image.set_pixel(x, y, Color(0.75 + 0.2 * edge, 0.95, 0.15 + 0.1 * stripe, a if d <= 1.0 else 0.0))
	_fallout_tex = ImageTexture.create_from_image(image)
	return _fallout_tex

## A particle burst that uses the cloud sprite (and additive glow for fire).
func _cloud_burst(start: Color, middle: Color, finish: Color, amount: int, life: float, speed: float, particle_size: float, gravity: float, glow: bool) -> CPUParticles3D:
	var particles: = _burst(start, middle, finish, amount, life, speed, particle_size, gravity, 0.0)
	var quad: = particles.mesh as QuadMesh
	var material: = (quad.material as StandardMaterial3D).duplicate() as StandardMaterial3D
	material.albedo_texture = cloud_texture() if glow or USE_CLOUD_FOR_SMOKE else material.albedo_texture
	if glow: material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	quad = quad.duplicate() as QuadMesh
	quad.material = material
	particles.mesh = quad
	particles.angle_min = 0.0
	particles.angle_max = 360.0
	return particles

func on_destroyed(unit: Dictionary) -> void :
	if not armies.visible_to_player(unit): return
	explode(unit.node.position + Vector3.UP * 0.15, true)
	if wrecks.size() >= MAX_WRECKS or unit.visual_kind == "fighter": return
	var root: = Node3D.new()
	add_child(root)
	root.position = unit.node.position
	# Preserve the destroyed vehicle's original geometry and appearance.
	var model: = unit.node.get_child(0).duplicate() as Node3D
	root.add_child(model)
	model.position = Vector3.ZERO
	model.rotation.z = 0.12
	UnitShadow.create(root)
	UnitShadow.update({"node": root, "heading": unit.heading}, root.position)
	wrecks.append({"node": root, "age": 0.0, "smoke_age": 0.0, "point": Vector2(root.position.x, root.position.z)})
func _process(delta: float) -> void :
	if clock == null or (clock.paused and match_rules.winner.is_empty()): return
	advance_visual(minf(delta, 0.1))
	_skirmish(minf(delta, 0.1))

## Owner 2026-10-15 ("the armies, when they meet up to fight, you can't even tell they're fighting.
## Animate them somehow"): between the half-hour damage rounds, armies locked in a close battle keep
## shooting - muzzle flashes, tracers flying both ways and dust where they land - with the
## machine-gun and rifle sounds, so a battle reads at a glance like Call of War's.
const SKIRMISH_LIMIT: = 10
var _skirmish_timers: Dictionary = {}
func _skirmish(seconds: float) -> void:
	if armies == null or not armies.at_war: return
	var shown: = 0
	for unit in armies.units:
		if shown >= SKIRMISH_LIMIT: break
		if not unit.get("engaged", false) or not unit.has("foe_point") or not unit.node.visible: continue
		if armies.air.is_air(unit) or armies.is_naval(unit) or unit.health <= 0: continue
		shown += 1
		var left: float = _skirmish_timers.get(unit.id, randf_range(0.0, 0.6)) - seconds
		if left > 0.0:
			_skirmish_timers[unit.id] = left
			continue
		_skirmish_timers[unit.id] = randf_range(0.35, 1.1)
		var model: Node3D = unit.node.get_child(0)
		var foe: Vector2 = unit.foe_point
		var start: Vector3 = model.global_position + Vector3.UP * (0.22 if unit.visual_kind == "infantry" else 0.3)
		var finish: = Vector3(foe.x, terrain.elevation(foe) + 0.15, foe.y) + Vector3(randf_range(-0.12, 0.12), 0, randf_range(-0.12, 0.12))
		var direction: = (finish - start).normalized()
		start += direction * 0.18
		if muzzles.size() < MAX_MUZZLES: muzzle_flash(unit, start, direction, "tracer")
		if projectiles.size() < MAX_PROJECTILES:
			launch(start, finish, "skirmish", unit.country)
		if audio != null and randf() < 0.45:
			audio.play("heavy_machine_gun" if unit.visual_kind != "infantry" or randf() < 0.3 else "rifle_fire", start)
	if _skirmish_timers.size() > 200: _skirmish_timers.clear()
func advance_visual(seconds: float) -> void :
	if seconds <= 0: return
	for i in range(projectiles.size() - 1, -1, -1):
		var job: Dictionary = projectiles[i]
		job.age += seconds
		var progress: float = minf(1, job.age / job.duration)
		job.node.position = trajectory(job, progress)
		job.trail_age += seconds
		if job.effect in ["missile", "interceptor", "artillery"] and job.trail_age >= 0.06:
			job.trail_age = 0.0
			smoke_puff(job.node.position, false, 0.065)
		var heading: Vector3 = trajectory(job, minf(1, progress + 0.01)) - job.node.position
		if heading.length_squared() > 1e-06:
			var up: = Vector3.RIGHT if absf(heading.normalized().dot(Vector3.UP)) > 0.98 else Vector3.UP
			job.node.look_at(job.node.position + heading, up)
		if progress >= 1 and job.effect == "skirmish":
			smoke_puff(job.finish, randf() < 0.3, 0.05)
			job.node.queue_free()
			projectiles.remove_at(i)
			continue
		if progress >= 1:
			explode(job.finish, job.effect in ["missile", "bomb"])
			job.node.queue_free()
			projectiles.remove_at(i)
	for i in range(impacts.size() - 1, -1, -1):
		var job: Dictionary = impacts[i]
		job.age += seconds
		var age: float = job.age
		var size: float = job.size
		job.light.light_energy = maxf(0.0, 6.0 * size * (1.0 - age / 0.35))
		job.core.visible = age < 0.7
		job.core.scale = Vector3.ONE * (1.0 + age * 5.0)
		job.core.material_override.albedo_color.a = maxf(0.0, 1.0 - age / 0.7)
		job.ring.scale = Vector3.ONE * (1 + age * 10) * size
		job.ring.material_override.albedo_color.a = maxf(0, 0.55 * (1 - age / 0.7))
		if age >= job.life:
			job.node.queue_free()
			impacts.remove_at(i)
	for i in range(nuke_jobs.size() - 1, -1, -1):
		var job: Dictionary = nuke_jobs[i]
		job.age += seconds
		var age: float = job.age
		var r: float = job.radius
		var rise: = 1.0 - pow(1.0 - minf(age / 7.0, 1.0), 2.0)
		job.light.light_energy = 60.0 * maxf(0.0, 1.0 - age / 3.0)
		job.fireball.position.y = r * (0.25 + 1.5 * rise)
		job.fireball.scale = Vector3.ONE * (1.0 + 1.4 * minf(age / 1.2, 1.0))
		job.fireball.material_override.albedo_color = Color(1.0, 0.92 - 0.4 * minf(age / 3.0, 1.0), 0.7 - 0.55 * minf(age / 3.0, 1.0), maxf(0.0, 1.0 - maxf(0.0, age - 1.5) / 2.0))
		job.fireball.visible = age < 3.6
		job.fire_cloud.position.y = job.fireball.position.y
		job.fire_cloud.emitting = age < 3.5
		job.cap.position.y = r * (0.35 + 1.55 * rise)
		job.cap_glow.position.y = job.cap.position.y
		job.cap.emitting = age > 0.8 and age < 9.0
		job.cap_glow.emitting = age > 0.8 and age < 5.0
		job.stem.emitting = age > 0.6 and age < 7.5
		job.halo.visible = age > 1.0 and age < 4.0
		job.halo.position.y = r * (0.6 + 0.8 * rise)
		job.halo.scale = Vector3(1, 0.25, 1) * r * (0.5 + 0.9 * clampf((age - 1.0) / 3.0, 0.0, 1.0))
		job.halo.material_override.albedo_color.a = 0.55 * (1.0 - clampf((age - 1.0) / 3.0, 0.0, 1.0))
		job.shock.scale = Vector3(1, 0.4, 1) * r * (0.15 + age * 1.6)
		job.shock.material_override.albedo_color.a = maxf(0.0, 0.8 * (1.0 - age / 3.2))
		job.scorch.material_override.albedo_color.a = minf(1.0, age / 1.5)
		for fire in job.fires: fire.emitting = age > 1.2 and age < 40.0
		if age >= 45.0:
			job.node.queue_free()
			nuke_jobs.remove_at(i)
	# Screen flash fades; the incoming-nuke warning strobes red ("go berserk").
	if _flash != null:
		flash_age += seconds
		if warning_time > 0.0:
			warning_time -= seconds
			var pulse: = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU * 3.0)
			_flash.color = Color(0.85, 0.0, 0.0, 0.15 + 0.4 * pulse)
			_flash.visible = true
			_warning.visible = true
			_warning.modulate.a = 0.4 + 0.6 * pulse
			_warning.scale = Vector2.ONE * (1.0 + 0.06 * pulse)
			shake = maxf(shake, 0.25)
			if warning_time <= 0.0:
				_warning.visible = false
				_flash.visible = false
		elif _flash.visible:
			_flash.color.a = maxf(0.0, 1.0 - flash_age / 1.6)
			_flash.visible = _flash.color.a > 0.0
	# Camera shake.
	var camera: = get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera != null:
		if shake > 0.0:
			shake = maxf(0.0, shake - seconds * 0.5)
			camera.h_offset = randf_range(-1.0, 1.0) * shake * 0.35
			camera.v_offset = randf_range(-1.0, 1.0) * shake * 0.35
		elif camera.h_offset != 0.0 or camera.v_offset != 0.0:
			camera.h_offset = 0.0
			camera.v_offset = 0.0
	# Fallout zones last until the fallout ends (game time).
	for i in range(fallout_zones.size() - 1, -1, -1):
		var zone: Dictionary = fallout_zones[i]
		zone.haze.material_override.albedo_color.a = 0.55 + 0.2 * sin(Time.get_ticks_msec() / 700.0)
		if clock != null and clock.elapsed >= zone.end:
			zone.node.queue_free()
			fallout_zones.remove_at(i)
	for i in range(muzzles.size() - 1, -1, -1):
		var job: Dictionary = muzzles[i]
		job.age += seconds
		job.node.visible = job.age < 0.1
		if is_instance_valid(job.model): job.model.position = job.offset + job.recoil * maxf(0, 1 - job.age / 0.2)
		if job.age >= 0.2:
			job.node.queue_free()
			muzzles.remove_at(i)
	for i in range(smoke_jobs.size() - 1, -1, -1):
		var job: Dictionary = smoke_jobs[i]
		job.age += seconds
		if armies != null: job.node.visible = armies.point_visible(Vector2(job.node.position.x, job.node.position.z))
		job.node.position += Vector3(0.015, 0.18, 0.008) * seconds
		job.puff.scale = Vector3.ONE * (1 + job.age * 1.5)
		job.puff.material_override.albedo_color.a = job.alpha * maxf(0, 1 - job.age / job.duration)
		if job.age >= job.duration:
			job.node.queue_free()
			smoke_jobs.remove_at(i)
	for i in range(wrecks.size() - 1, -1, -1):
		var job: Dictionary = wrecks[i]
		job.age += seconds
		job.smoke_age += seconds
		job.node.visible = armies == null or armies.point_visible(job.point)
		if job.node.visible and job.smoke_age >= 0.3:
			job.smoke_age = 0.0
			smoke_puff(job.node.position + Vector3.UP * 0.3, true, 0.12)
		if job.age >= 15:
			job.node.queue_free()
			wrecks.remove_at(i)
	damage_smoke_timer += seconds
	if armies != null and damage_smoke_timer >= 0.4:
		damage_smoke_timer = 0.0
		var count: = 0
		for unit in armies.units:
			if unit.health > 0 and unit.health < 40 and unit.node.visible and armies.visible_to_player(unit):
				smoke_puff(unit.node.position + Vector3.UP * 0.35, true, 0.08)
				count += 1
				if count >= 8: break
func clear() -> void :
	for job in muzzles:
		if is_instance_valid(job.model): job.model.position = job.offset
	for job in projectiles + impacts + smoke_jobs + muzzles + wrecks + nuke_jobs + fallout_zones: job.node.queue_free()
	nuke_jobs.clear()
	fallout_zones.clear()
	projectiles.clear()
	impacts.clear()
	smoke_jobs.clear()
	muzzles.clear()
	wrecks.clear()
