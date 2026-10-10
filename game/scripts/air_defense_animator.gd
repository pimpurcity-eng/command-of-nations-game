class_name AirDefenseAnimator
extends Node3D
## Named pivots in the owner's supplied models. Source front is +X; launch elevation is +Z.
var model_key: String
var launchers: Array[Node3D] = []
var radars: Array[Node3D] = []
var turrets: Array[Node3D] = []
var wheels: Array[Node3D] = []
var rest: Dictionary = {}
var moving: bool = false
var deployed: float = 0.0
var shot_remaining: float = 0.0
var target_point: Vector3
var phase: float = 0.0
var elevation: float = 0.0
func configure(vehicle: Node3D, key: String) -> void:
	model_key = key
	if key in ["russia_s400", "russia_s500_prometey", "nato_iris_t_slm", "nato_samp_t", "nato_aster30"]: elevation = PI * 0.5
	elif key == "nato_nasams": elevation = deg_to_rad(45)
	else: elevation = deg_to_rad(35)
	collect(vehicle)
func collect(node: Node) -> void:
	if node is Node3D:
		if str(node.name).begins_with("Launcher_Pivot"):
			launchers.append(node)
			rest[node] = node.rotation
		elif node.name in ["Search_Radar", "Radar_Turntable"]: radars.append(node)
		elif node.name == "Turret": turrets.append(node)
		elif str(node.name).begins_with("Wheel_") or str(node.name).begins_with("RoadWheel_"): wheels.append(node)
	for child in node.get_children(): collect(child)
func fire(point: Vector3) -> void:
	target_point = point
	shot_remaining = 1.5
func muzzle_position() -> Vector3:
	if launchers.is_empty(): return global_position + Vector3.UP * 0.35
	# The canisters run along source +X from each named hinge.
	var length: float = 8.5 if model_key == "russia_s500_prometey" else 8.0 if model_key == "russia_s400" else 6.0 if model_key in ["nato_iris_t_slm", "nato_samp_t", "nato_aster30"] else 2.7
	return launchers[0].to_global(Vector3(length, 0.7, 0))
func animate(delta: float) -> void:
	phase += delta
	shot_remaining = maxf(0, shot_remaining - delta)
	deployed = move_toward(deployed, 0.0 if moving else 1.0, delta * 0.7)
	for radar in radars: radar.rotation.y = wrapf(radar.rotation.y + delta * 0.65 * deployed, -PI, PI)
	for turret in turrets:
		var yaw: float = sin(phase * 0.24) * 0.28
		if shot_remaining > 0:
			var direction: Vector3 = turret.get_parent().global_basis.inverse() * (target_point - turret.global_position)
			yaw = atan2(-direction.z, direction.x)
		turret.rotation.y = lerp_angle(turret.rotation.y, yaw * deployed, 1.0 - exp(-delta * 6.0))
	for launcher in launchers:
		var base: Vector3 = rest[launcher]
		var raised: float = lerpf(base.z, elevation, deployed)
		launcher.rotation.z = raised + sin(shot_remaining * 18.0) * shot_remaining * 0.012
	if moving:
		for wheel in wheels: wheel.rotate_z(-delta * 2.0)
