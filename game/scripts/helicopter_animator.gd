class_name HelicopterAnimator
extends Node3D
## Spin supplied rotors/propellers about their original pivots and local axes.
## Merge the fuselage and each rotor separately for mobile draw calls.
const ROTOR_NAMES: = ["MainRotor", "UpperRotor", "LowerRotor", "TailRotor"]
var rotors: Array[Node3D] = []
var rest: Array[Transform3D] = []
var phase: float = 0.0

func prepare(source: Node3D) -> Node3D:
	var parts: Array = []
	_collect(source, Transform3D.IDENTITY, parts)
	for part in parts:
		var rotor: Node3D = part[0]
		rotor.get_parent().remove_child(rotor)
		rotor.transform = Transform3D.IDENTITY
	var body: = UnitVisual.merged(source)
	for part in parts:
		var name: String = str(part[0].name)
		var rotor: = UnitVisual.merged(part[0])
		rotor.name = name
		rotor.transform = part[1]
		body.add_child(rotor)
		rotors.append(rotor)
		rest.append(rotor.transform)
	return body

func _collect(node: Node3D, parent_transform: Transform3D, parts: Array) -> void:
	var pose: = parent_transform * node.transform
	if str(node.name) in ROTOR_NAMES or str(node.name).begins_with("Propeller"):
		parts.append([node, pose])
		return
	for child in node.get_children():
		if child is Node3D: _collect(child, pose, parts)

func animate(delta: float, flying: bool) -> void:
	if not flying or delta <= 0: return
	phase = fmod(phase + delta * 30.0, TAU)
	for i in rotors.size():
		var direction: = -1.0 if str(rotors[i].name) == "UpperRotor" else 1.0
		var axis: = Vector3.RIGHT if str(rotors[i].name).begins_with("Propeller") else Vector3.UP
		rotors[i].transform = Transform3D(rest[i].basis * Basis(axis, phase * direction), rest[i].origin)
