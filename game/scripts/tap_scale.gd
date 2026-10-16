class_name TapScale
extends RefCounted
## Owner 2026-10-16 (fix 11, "units easier to tap"): taps and the 3D map are measured in the phone's
## real pixels, but the game is laid out for a 720 px wide screen (stretch mode canvas_items), so on
## a 1080-1440 px phone a "44 px fingertip" was only about 3 mm. Every tap distance is multiplied by
## this factor so it stays the same size under the finger on every screen (never smaller than 1).
static func of(node: Node) -> float:
	if node == null or not node.is_inside_tree(): return 1.0
	var stretch: float = node.get_viewport().get_stretch_transform().get_scale().x
	return maxf(1.0, stretch) * node.get_window().content_scale_factor
