class_name UnitDetailPanel
extends CanvasLayer
## One full-width unit card, shared by research, city pictures and army inspection.
var panel: PanelContainer
var content: VBoxContainer
var hero_picture: TextureRect
var research: ResearchSystem
var equipment_id: = ""
var level: = 1
var action: Button
var status: Label
var bill: Label
var gold_action: Button
var gold_breakdown: Label
var gold_result: = ""
var refresh_time: = 0.0

func setup(theme: Theme) -> void:
	layer = 15
	var root: = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = theme
	add_child(root)
	var dim: = ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.03, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", CowUI.skin("panel_dark", 0))
	root.add_child(panel)
	# Wrapped footer labels may first measure against the old width. Refit after their
	# minimum size settles so the scroll view, close button and research action stay on screen.
	panel.minimum_size_changed.connect(_layout.call_deferred)
	var column: = VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	panel.add_child(column)
	var head: = CowUI.header("Unit Details", false)
	head.close.pressed.connect(hide)
	column.add_child(head.bar)
	var scroll: = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 0)
	scroll.add_child(content)
	var footer: = VBoxContainer.new()
	footer.add_theme_constant_override("separation", 4)
	column.add_child(footer)
	bill = CowUI.label("", 14, Color("e5dec9"))
	bill.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_child(bill)
	status = CowUI.label("", 15, CowUI.GOLD)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_child(status)
	action = CowUI.action("RESEARCH", "research")
	action.pressed.connect(func():
		var error: = research.start(equipment_id, level)
		status.text = "Research started" if error.is_empty() else error
		_refresh())
	footer.add_child(action)
	gold_breakdown = CowUI.label("", 14, CowUI.GOLD)
	gold_breakdown.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_child(gold_breakdown)
	gold_action = CowUI.action("FINISH NOW WITH GOLD", "", CowUI.GREEN)
	gold_action.pressed.connect(func():
		var purchase: Dictionary = gold_action.get_meta("purchase")
		gold_result = research.buy_now(purchase.id, purchase.level, GameSession.player_country, false, purchase.max_gold)
		_refresh())
	footer.add_child(gold_action)
	get_viewport().size_changed.connect(_layout)
	hide()

func _layout() -> void:
	var size: = get_viewport().get_visible_rect().size
	var width: = minf(760.0, size.x)
	var top: = roundf(size.y * 0.02)
	panel.scale = Vector2.ONE * CowUI.MENU_ZOOM
	panel.position = Vector2((size.x - width) * 0.5, top)
	panel.size = Vector2(width, size.y - top * 2) / CowUI.MENU_ZOOM

func _section(text: String) -> void:
	var back: = PanelContainer.new()
	back.add_theme_stylebox_override("panel", CowUI.box(Color("777569"), 0, Color("171c20"), 1, 10))
	content.add_child(back)
	back.add_child(CowUI.label(text.to_upper(), 20, Color("efe6cf")))

func _row(values: Array, header: bool = false) -> void:
	var back: = PanelContainer.new()
	back.add_theme_stylebox_override("panel", CowUI.box(Color("b8b5a7") if header else CowUI.LIST, 0, Color("23272b"), 1, 9))
	content.add_child(back)
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	back.add_child(row)
	for i in values.size():
		var label: = CowUI.label(str(values[i]), 15 if header else 17, CowUI.INK)
		if i == 0:
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.clip_text = true
		else:
			label.custom_minimum_size.x = 78 if values.size() > 3 else 104
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(label)

func _text(text: String) -> void:
	var margin: = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 12)
	content.add_child(margin)
	var label: = CowUI.label(text, 16, Color("e6decb"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	margin.add_child(label)

func open(id: String, selected_level: int, system: ResearchSystem) -> void:
	if EquipmentIdentity.spec(id).is_empty() or id.begins_with("economy_"): return
	equipment_id = id
	level = clampi(selected_level, 1, 5)
	research = system
	gold_result = ""
	_build()
	_refresh()
	_layout()
	content.get_parent().scroll_vertical = 0
	show()

func _build() -> void:
	for child in content.get_children(): content.remove_child(child); child.queue_free()
	var unit: = UnitStats.specimen(equipment_id, level)
	var role: Dictionary = UnitStats.profile(unit)
	var hero: = Control.new()
	hero.custom_minimum_size.y = 340
	hero.clip_contents = true
	content.add_child(hero)
	hero_picture = TextureRect.new()
	hero_picture.texture = CowUI.research_picture(equipment_id, level)
	hero_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	hero_picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hero.add_child(hero_picture)
	_text(EquipmentIdentity.research_title(equipment_id, level) + " · Level " + EquipmentIdentity.roman_level(level) + "\n" + str(unit.country).capitalize() + " · " + role.name)
	var levels: = HBoxContainer.new()
	content.add_child(levels)
	for i in range(1, 6):
		var button: = Button.new()
		button.text = EquipmentIdentity.roman_level(i)
		button.custom_minimum_size.y = 42
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = i == level
		var chosen: = i
		button.pressed.connect(func(): level = chosen; _build(); _refresh())
		levels.add_child(button)
	_section("Unit statistics")
	_row(["Hit points", "%d HP" % roundi(UnitStats.max_hp(unit))])
	_row(["Movement rate", "%.2f" % (UnitStats.speed(unit) * SimulationClock.MOVEMENT_PACE)])
	_text(UnitStats.range_label(unit) + "\n" + str(role.get("purpose", "")))
	_section("Attack and defence")
	_row(["Target", "Attack", "Defence"], true)
	for target in UnitClasses.ALL:
		_row([UnitClasses.NAMES[target], "%.1f" % (UnitStats.base_damage(unit, target) * Doctrine.combat_factor(unit, "attack")), "%.1f" % (UnitStats.base_damage(unit, target, true) * Doctrine.combat_factor(unit, "defense"))])
	_text("At full health. Doctrine included; terrain effects below. Home defence and fortifications also apply in battle.")
	_section("Terrain effects")
	_row(["Terrain", "Speed", "Attack", "Defence"], true)
	for terrain in TerrainRules.rules:
		var values: Array = [str(terrain).capitalize()]
		for effect in ["speed", "attack", "defense"]:
			var percent: = roundi((TerrainRules.for_unit(unit, terrain, effect) - 1.0) * 100.0)
			values.append("—" if percent == 0 else "%+d%%" % percent)
		_row(values)
	if unit.visual_kind in ["fighter", "naval"]:
		_text("Airborne aircraft ignore ground terrain. Ships operate on water." if unit.visual_kind == "fighter" else "Ships operate on water; ground terrain does not affect naval fire.")
	_section("National doctrine")
	_text(Doctrine.summary(str(unit.country)))
	_section("Production and upkeep")
	if EquipmentIdentity.spec(equipment_id).get("research_only", false):
		_text("Freight capacity research. This vessel is not produced as a map unit and has no unit upkeep.")
	else:
		var spec: = EquipmentIdentity.spec(equipment_id)
		_text("Base production time at 1×: " + SimulationClock.duration(EquipmentEconomy.duration(spec, level), 1.0) + ". Factories, morale and doctrine change the actual time shown in your city.")
		_row(["Resource", "Build cost", "Daily upkeep"], true)
		var cost: = EquipmentEconomy.cost(spec, level)
		var upkeep: = EquipmentEconomy.upkeep(spec, level)
		for resource in ProductionSystem.RESOURCES:
			_row([resource.capitalize(), str(int(cost[resource])), str(int(upkeep[resource]))])
	if unit.visual_kind == "air_defense":
		var layers: PackedStringArray = []
		var names: = {"drone": "small drones", "low": "helicopters", "attack": "jets on attack runs", "high": "high-flying aircraft"}
		for layer_name in AirBattleSystem.engages(unit): layers.append(names.get(layer_name, layer_name))
		_text("Engages " + ", ".join(layers) + ". Air defence fires every 7 game minutes; passing aircraft take half damage.")
	if unit.visual_kind == "fighter": _text("Patrol: 65% of attack damage every 7 game minutes. Direct attacks use full damage, then return to refuel.")
	if CombatSystem.nuclear(unit): _text("A nuclear launch consumes this unit. Its area blast uses a shared 250 HP pool at the centre, with damage falling towards the edge.")

func _refresh() -> void:
	if research == null or equipment_id.is_empty(): return
	var reason: = research.reason(equipment_id, level)
	var job: Dictionary = research.active(equipment_id)
	var label: Label = action.get_meta("caption")
	label.text = "RESEARCHED" if research.level(equipment_id) >= level else "IN PROGRESS" if not job.is_empty() else "RESEARCH LEVEL " + EquipmentIdentity.roman_level(level)
	action.disabled = not reason.is_empty()
	var owner: String = EquipmentIdentity.spec(equipment_id).country
	var work: = research.duration(level, equipment_id)
	var running: bool = not job.is_empty() and not job.get("refinement", false) and int(job.level) == level
	if running: work = research.job_duration(job) - float(job.progress)
	status.text = ("Research remaining: " if running else "Research time: ") + SimulationClock.duration(work / maxf(0.01, research.rate(owner)))
	if not reason.is_empty() and not running: status.text += " · " + reason
	var parts: PackedStringArray = []
	var cost: Dictionary = research.cost(equipment_id, level)
	for resource in ProductionSystem.RESOURCES:
		if float(cost.get(resource, 0)) > 0: parts.append(str(resource).capitalize() + " " + CowUI.short(float(cost[resource])))
	bill.text = "Research cost · " + "  ·  ".join(parts)
	var gold_reason: = research.gold_reason(equipment_id, level)
	gold_action.visible = gold_reason.is_empty()
	gold_breakdown.visible = gold_action.visible
	if gold_action.visible:
		var price: = research.gold_quote(equipment_id, level)
		gold_breakdown.text = GoldWallet.explanation(price)
		gold_action.get_meta("caption").text = "FINISH NOW · %s GOLD" % StrategyHUD._thousands(int(price.total))
		gold_action.disabled = int(research.economy.gold.get(GameSession.player_country,0)) < int(price.total)
		gold_action.set_meta("purchase", {"id":equipment_id,"level":level,"max_gold":int(price.total)})
	if not gold_result.is_empty(): status.text += "\n" + gold_result

func _process(delta: float) -> void:
	if not visible: return
	refresh_time += delta
	if refresh_time >= 0.5:
		refresh_time = 0.0
		_refresh()
