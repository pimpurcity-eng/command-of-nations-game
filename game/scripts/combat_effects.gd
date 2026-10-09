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
func sphere(parent: Node3D, radius: float, color: Color) -> MeshInstance3D:
	var mesh: = MeshInstance3D.new()
	var shape: = SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2
	shape.radial_segments = 8
	shape.rings = 4
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
	if source_visible:
		var direction: = (finish - start).normalized()
		if effect == "missile":
			source.heading = UnitVisual.firing_heading(source.equipment_id, direction)
			source.node.get_child(0).rotation.y = source.heading
		start += direction * 0.3
		muzzle_flash(source, start, direction, effect)
	if not target_visible: return
	if not source_visible: start = finish + (start - finish).normalized() * 1.5 + Vector3.UP
	launch(start, finish, effect, source.country)
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
func launch(start: Vector3, finish: Vector3, effect: String, country: String = "russia") -> void :
	if projectiles.size() >= MAX_PROJECTILES: return
	var root: = Node3D.new()
	add_child(root)
	root.position = start
	if effect in ["missile", "interceptor"]:
		if not flight_scenes.has(country):
			var appearance: = AssetRoster.appearance("tomahawk", country)
			flight_scenes[country] = load(appearance.model)
		var body: Node3D = flight_scenes[country].instantiate()
		body.scale = Vector3.ONE * 0.12
		body.rotation.y = PI
		root.add_child(body)
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
	var glow: = sphere(root, 0.025, Color("ffbc62"))
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
	if effect in ["cannon", "tracer"]: duration = clampf(start.distance_to(finish) * 0.08, 0.12, 0.4)
	projectiles.append({"node": root, "start": start, "finish": finish, "effect": effect, "age": 0.0, "trail_age": 0.0, "duration": duration})
func trajectory(job: Dictionary, fraction: float) -> Vector3:
	var position: Vector3 = job.start.lerp(job.finish, fraction)
	var arc: = sin(fraction * PI) * (1.8 if job.effect == "artillery" else 0.75 if job.effect == "missile" else 0.0)
	position.y += arc

	if job.effect == "missile" and fraction > 0.1 and fraction < 0.9:
		position.y = maxf(position.y, terrain.elevation(Vector2(position.x, position.z)) + 0.5)
	return position
func explode(position: Vector3, large: bool = false) -> void :
	if impacts.size() >= MAX_IMPACTS: return
	var root: = Node3D.new()
	add_child(root)
	root.position = position
	var flash: = sphere(root, 0.08, Color("ffe4a3"))
	var fire: = sphere(root, 0.1, Color(1, 0.28, 0.04, 0.9))
	var smoke: = sphere(root, 0.15, Color(0.16, 0.17, 0.16, 0.7))
	var ring: = MeshInstance3D.new()
	var torus: = TorusMesh.new()
	torus.inner_radius = 0.15
	torus.outer_radius = 0.2
	torus.rings = 16
	torus.ring_segments = 4
	ring.mesh = torus
	ring.material_override = ink(Color(0.9, 0.65, 0.27, 0.6))
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	impacts.append({"node": root, "flash": flash, "fire": fire, "smoke": smoke, "ring": ring, "age": 0.0, "size": 1.5 if large else 1.0})
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
		if progress >= 1:
			explode(job.finish, job.effect == "missile")
			job.node.queue_free()
			projectiles.remove_at(i)
	for i in range(impacts.size() - 1, -1, -1):
		var job: Dictionary = impacts[i]
		job.age += seconds
		var age: float = job.age
		var size: float = job.size
		job.flash.visible = age < 0.22
		job.flash.scale = Vector3.ONE * (1 + age * 15) * size
		job.fire.visible = age < 0.6
		job.fire.scale = Vector3.ONE * (1 + age * 7) * size
		job.fire.material_override.albedo_color.a = maxf(0, 1 - age / 0.6)
		job.smoke.position.y = age * 0.35
		job.smoke.scale = Vector3.ONE * (1 + age * 3) * size
		job.smoke.material_override.albedo_color.a = maxf(0, 0.55 * (1 - age / 1.6))
		job.ring.scale = Vector3.ONE * (1 + age * 9) * size
		job.ring.material_override.albedo_color.a = maxf(0, 0.6 * (1 - age / 0.8))
		if age >= 1.6:
			job.node.queue_free()
			impacts.remove_at(i)
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
	for job in projectiles + impacts + smoke_jobs + muzzles + wrecks: job.node.queue_free()
	projectiles.clear()
	impacts.clear()
	smoke_jobs.clear()
	muzzles.clear()
	wrecks.clear()
