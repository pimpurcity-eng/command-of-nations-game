extends SceneTree
var failures: = 0
func check(ok: bool, message: String):
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures += 1
func _initialize(): call_deferred("run")
func run():
	root.size = Vector2i(720,1440)
	var hud = load("res://scripts/hud.gd").new()
	root.add_child(hud)
	await process_frame
	GameSession.player_country = "russia"
	var unit: = {"equipment_id":"missiles_russia","level":3,"country":"russia","health":100.0,"visual_kind":"missile_launcher"}
	hud.show_unit(unit)
	for i in 3: await process_frame
	check(hud.selection_title.text == "YARS RS-24 · L3","unit name and level have their own heading")
	check(hud.selection_title.get_theme_font_size("font_size") == 28,"heading doubles previous text size")
	check(hud.selection_title.global_position.y < hud.action_row.global_position.y,"name appears above commands")
	check(hud.selection_title.get_parent().size.x <= root.size.x,"heading fits portrait width")
	hud.selection_title.text = "LONG RANGE AIR DEFENSE · MODERNIZATION LEVEL 5"
	for i in 3: await process_frame
	check(hud.selection_title.size.x <= root.size.x and hud.selection_title.get_visible_line_count() == hud.selection_title.get_line_count(),"long names wrap without clipping")
	hud.show_territory({"title":"Kursk","controller":"russia","terrain":"hills"})
	check(hud.selection_title.text == "KURSK","place name uses the large heading")
	check(hud.detail.text == "YOURS · HILLS · MORALE 100%","place information and morale stay separate from its name")
	hud.clear_unit_selection()
	check(hud.selection_title.text == "REGIONAL COMMAND","clearing selection removes stale name")
	print("RESULT checks=8 failures=",failures)
	hud.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
