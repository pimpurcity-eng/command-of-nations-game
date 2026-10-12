class_name MenuTouchScroll
extends Node
## One gesture owner for nested menu lists. Dragging a card scrolls its nearest scrollable
## parent; a tap still reaches the card. Mouse wheels and keyboard scrolling stay native.
var target: Control
var pointer: = -1
var origin: = Vector2.ZERO
var previous: = Vector2.ZERO
var dragging: = false
var velocity: = Vector2.ZERO
var cancelling: = false
const DEADZONE: = 12.0
func _scrollable(control: Control) -> bool:
 if control is ScrollContainer:
  return control.get_v_scroll_bar().max_value > control.get_v_scroll_bar().page + 1 or control.get_h_scroll_bar().max_value > control.get_h_scroll_bar().page + 1
 if control is ItemList: return control.get_v_scroll_bar().max_value > control.get_v_scroll_bar().page + 1
 return false
func _pick(node: Node, point: Vector2) -> Control:
 if node is CanvasLayer and not node.visible: return null
 if node is CanvasItem and not node.is_visible_in_tree(): return null
 var result: Control
 if node is Control and (node is ScrollContainer or node is ItemList):
  var local: Vector2 = node.get_global_transform_with_canvas().affine_inverse() * point
  if Rect2(Vector2.ZERO,node.size).has_point(local) and _scrollable(node): result = node
 for child in node.get_children():
  var nested: = _pick(child, point)
  if nested != null: result = nested
 return result
func _move(amount: Vector2) -> void:
 if not is_instance_valid(target): return
 if target is ScrollContainer:
  target.scroll_vertical += roundi(amount.y)
  target.scroll_horizontal += roundi(amount.x)
 elif target is ItemList: target.get_v_scroll_bar().value += amount.y
func _input(event: InputEvent) -> void:
 if cancelling: return
 if event is InputEventScreenTouch:
  if event.pressed:
   if pointer >= 0: return
   target = _pick(get_tree().root,event.position)
   if target == null: return
   pointer = event.index
   origin = event.position
   previous = origin
   dragging = false
   velocity = Vector2.ZERO
  elif event.index == pointer:
   pointer = -1
   if dragging: get_viewport().set_input_as_handled()
   dragging = false
 elif event is InputEventScreenDrag and event.index == pointer and is_instance_valid(target):
  var local_scale: = target.get_global_transform_with_canvas().basis_xform_inv(event.position - previous)
  previous = event.position
  if not dragging and origin.distance_to(event.position) < DEADZONE: return
  if not dragging:
   dragging = true
   # Release the emulated mouse outside the card so its action does not fire on a swipe.
   var release: = InputEventMouseButton.new()
   release.button_index = MOUSE_BUTTON_LEFT
   release.pressed = false
   release.position = Vector2(-10000,-10000)
   release.global_position = release.position
   cancelling = true
   get_viewport().push_input(release)
   cancelling = false
  _move(-local_scale)
  velocity = -target.get_global_transform_with_canvas().basis_xform_inv(event.velocity)
  get_viewport().set_input_as_handled()
func _process(delta: float) -> void:
 if pointer >= 0 or not is_instance_valid(target) or not target.is_visible_in_tree(): return
 if velocity.length() < 8: velocity = Vector2.ZERO;return
 _move(velocity * minf(delta,0.05))
 velocity *= exp(-delta*12.0)
