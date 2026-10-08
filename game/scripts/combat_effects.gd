class_name CombatEffects
extends Node3D

const MAX_PROJECTILES: = 24
const MAX_IMPACTS: = 16
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
	if not armies.visible_to_player(target_unit): return
	var start: Vector3 = source.node.position + Vector3.UP * 0.4
	var finish: Vector3 = target_unit.node.position + Vector3.UP * 0.2

	if not armies.visible_to_player(source): start = finish + (start - finish).normalized() * 1.5 + Vector3.UP
	launch(start, finish, effect, source.country)
func launch(start: Vector3, finish: Vector3, effect: String, country: String = "russia") -> void :
	if projectiles.size() >= MAX_PROJECTILES: return
	var root: = Node3D.new()
	add_child(root)
	root.position = start
	if effect == "missile":
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
	var glow: = sphere(root, 0.055, Color("ffbc62"))
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
	projectiles.append({"node": root, "start": start, "finish": finish, "effect": effect, "age": 0.0, "duration": clampf(start.distance_to(finish) * 0.15 + 0.65, 0.8, 2.0)})
func trajectory(job: Dictionary, fraction: float) -> Vector3:
	var position: Vector3 = job.start.lerp(job.finish, fraction)
	var arc: = sin(fraction * PI) * (1.8 if job.effect == "artillery" else 0.75)
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
	if armies.visible_to_player(unit): explode(unit.node.position + Vector3.UP * 0.15, true)
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
		job.smoke.material_override.albedo_color.a = maxf(0, 0.7 * (1 - age / 1.6))
		job.ring.scale = Vector3.ONE * (1 + age * 9) * size
		job.ring.material_override.albedo_color.a = maxf(0, 0.6 * (1 - age / 0.8))
		if age >= 1.6:
			job.node.queue_free()
			impacts.remove_at(i)
func clear() -> void :
	for job in projectiles + impacts: job.node.queue_free()
	projectiles.clear()
	impacts.clear()
