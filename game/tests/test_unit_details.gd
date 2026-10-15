extends SceneTree
## Real reusable Godot panels without the full-map fixture. Also produces review PNGs
## with -- --render and UNIT_REVIEW_DIR; no mockup or generated replacement artwork.
var failures: = 0
var checks: = 0
var research_panel: ResearchPanel
var research: ResearchSystem
var armies: UnitSystem
var nodes: Array[Node] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL ", label)
func frames() -> void:
	for i in 8: await process_frame
func shot(name: String) -> void:
	if "--render" not in OS.get_cmdline_user_args(): return
	await frames()
	var folder: = OS.get_environment("UNIT_REVIEW_DIR")
	if folder.is_empty(): folder = "user://unit-review"
	DirAccess.make_dir_recursive_absolute(folder)
	root.get_texture().get_image().save_png(folder.path_join(name + ".png"))
func labels(node: Node) -> PackedStringArray:
	var result: PackedStringArray = []
	if node is Label: result.append(node.text)
	for child in node.get_children(): result.append_array(labels(child))
	return result
func run() -> void:
	root.size = Vector2i(720, 1440)
	GameSession.player_country = "russia"
	armies = UnitSystem.new()
	armies.stacks.armies = armies
	armies.air.armies = armies
	armies.fog_enabled = false
	var economy: = ProductionSystem.new()
	for country in ["russia", "ukraine"]:
		economy.stockpiles[country] = ProductionSystem.START_STOCK.duplicate()
	var clock: = SimulationClock.new()
	research = ResearchSystem.new()
	research.setup(economy, clock, armies)
	economy.research = research
	research_panel = ResearchPanel.new()
	root.add_child(research_panel)
	research_panel.setup(research, StrategyTheme.create())
	research_panel.open_unit("light_tank_russia", 1)
	await frames()
	var card: UnitDetailPanel = research_panel.unit_card
	check(card.visible and card.equipment_id == "light_tank_russia", "army/city open_unit opens the full unit card")
	check(card.panel.get_global_rect().end.y <= root.get_visible_rect().end.y + 1, "card fits viewport height")
	check(card.hero_picture.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "hero fills width without distortion")
	check(absf(card.hero_picture.get_global_rect().size.x - card.content.get_global_rect().size.x) < 2, "photo fills card width")
	var text: = "\n".join(labels(card.content))
	check(text.contains("35 HP") and text.contains("Attack") and text.contains("Defence") and text.contains("Terrain effects".to_upper()), "card shows role HP, attack, defence and terrain")
	await shot("Unit_Card_Full_Width")
	check(text.contains("PRODUCTION AND UPKEEP") and text.contains("Daily upkeep"), "unit card exposes production prices, upkeep and 1x base time")
	card.content.get_parent().scroll_vertical = 99999
	await shot("Unit_Card_Prices")
	card.content.get_parent().scroll_vertical = 510
	await frames()
	check(card.content.get_parent().scroll_vertical > 0, "unit card scrolls to combat and terrain while action stays visible")
	check(card.action.get_global_rect().end.y <= root.get_visible_rect().end.y, "research action stays on screen")
	await shot("Unit_Card_Combat_Terrain")
	card.hide()
	# Research tile press must open the same card, including a locked level for inspection.
	var cell: Dictionary = research_panel.cells.filter(func(c): return c.id == "light_tank_russia" and c.level == 3 and not c.get("refinement", false))[0]
	cell.card.pressed.emit()
	await frames()
	check(card.visible and card.level == 3, "tapping research picture opens its own selected level")
	check(card.action.disabled, "future/locked research can be viewed but not started")
	card.open("infantry_russia", 1, research)
	await frames()
	check(not card.action.disabled, "available owned unit can be researched from card")
	card.action.pressed.emit()
	check(not research.active("infantry_russia").is_empty(), "card research button starts real research")
	var running: = research.active("infantry_russia")
	running.progress = research.job_duration(running) * 0.25
	clock.set_speed(10.0)
	card._refresh()
	check("Research remaining: 7m 30s" in card.status.text, "card countdown uses actual remaining work and 10x speed")
	clock.set_speed(1.0)
	card.open("tanks_ukraine", 1, research)
	await frames()
	check(card.action.disabled and "European" in "\n".join(labels(card.content)), "enemy card uses enemy doctrine and blocks research")
	check("2h 07m" in card.status.text, "European tank card displays its own discounted research duration")
	await shot("European_Tank_Card")
	for size in [Vector2i(640, 1280), Vector2i(720, 1560), Vector2i(1440, 900)]:
		root.size = size
		await frames()
		var bounds: = card.panel.get_global_rect()
		check(bounds.position.x >= -1 and bounds.end.x <= root.get_visible_rect().size.x + 1, "card fits viewport " + str(size))
		check(bounds.end.y <= root.get_visible_rect().size.y + 1, "card fits height after resize " + str(size))
		check(card.action.get_global_rect().end.y <= root.get_visible_rect().size.y + 1, "research action visible after resize " + str(size))
		check(absf(card.hero_picture.get_global_rect().size.x - card.content.get_global_rect().size.x) < 2, "full-width image after resize " + str(size))
	root.size = Vector2i(720, 1440)
	research_panel.hide()
	await frames()
	check(not card.visible, "closing research also closes its child card")
	# Army header and list use capacity sums, never count * 100.
	var point: Vector2 = GeographicProjection.load_cities()[0].point
	for id in ["light_tank_russia", "infantry_russia", "infantry_russia", "skyguard_russia"]:
		var unit: = UnitStats.specimen(id)
		var node: = Node3D.new()
		nodes.append(node)
		node.position = Vector3(point.x, 0, point.y)
		unit.merge({"id": str(armies.units.size()), "stack_id": "review", "node": node, "moving": false, "engaged": false})
		armies.units.append(unit)
	armies.selected = 0
	armies.stacks.invalidate()
	var terrain: = StrategicMap.new()
	var army: = ArmyDetailsPanel.new()
	root.add_child(army)
	army.setup(StrategyTheme.create())
	army.open(armies, terrain)
	await frames()
	text = "\n".join(labels(army.content))
	check(text.contains("110 / 110") and text.contains("35 / 35") and text.contains("25 / 25"), "mixed stack shows actual per-unit and summed HP")
	var picture: TextureRect = army.content.get_child(0).get_child(0)
	check(picture.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "army hero fills width")
	await shot("Army_Details_Actual_HP")
	army.content.get_parent().scroll_vertical = 1080
	await shot("Army_Units_Actual_HP")
	for node in nodes: node.free()
	terrain.free(); armies.free(); clock.free()
	print("RESULT UNIT_DETAILS checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
