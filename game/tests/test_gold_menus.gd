extends SceneTree
## Genuine native panels; optional screenshots with -- --render and GOLD_REVIEW_DIR.
var checks: = 0
var failures: = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL ",message)
func frames() -> void:
	for i in 8: await process_frame
func shot(name: String) -> void:
	if "--render" not in OS.get_cmdline_user_args(): return
	await frames()
	var folder: = OS.get_environment("GOLD_REVIEW_DIR")
	if folder.is_empty(): folder="user://gold-review"
	DirAccess.make_dir_recursive_absolute(folder)
	root.get_texture().get_image().save_png(folder.path_join(name+".png"))
func run() -> void:
	root.size=Vector2i(720,1440); root.gui_embed_subwindows=true
	GameSession.player_country="russia"
	var hud: = StrategyHUD.new();root.add_child(hud)
	hud.show_clock(0,1,false)
	await frames()
	var menu: = hud.navigation_menu.get_popup()
	check(menu.item_count==9, "More has nine destinations (newspaper on top level, owner 2026-10-16) instead of 42 entries")
	check(menu.get_item_id(0)==100 and menu.get_item_id(1)==101, "Home and profile remain first")
	var text: = ""
	for i in menu.item_count:text+=menu.get_item_text(i)+"\n"
	check(not text.contains("Attack") and not text.contains("Research") and not text.contains("All weapon"), "main menu omits army commands, bottom-tab duplicates and test tools")
	check((menu.get_node("Reports") as PopupMenu).item_count==2 and (menu.get_node("Game") as PopupMenu).item_count==3, "reports and save/load/new-match have short groups")
	var speed: = hud.settings_menu.get_node("Game_speed") as PopupMenu
	check(speed.item_count==4 and speed.get_item_id(3)==102, "all four speeds remain in Settings")
	var requests: Array = []
	hud.speed_requested.connect(func(value):requests.append(value))
	speed.id_pressed.emit(102)
	check(requests==[10.0], "10x dispatch still works from the relocated menu")
	hud._show_audio_items()
	check(hud.settings_menu.get_item_text(hud.settings_menu.get_item_index(31)).begins_with("Sound:"), "sound toggle remains in Settings")
	menu.popup(Rect2i(360,820,340,0))
	await frames()
	check(menu.size.y < 500 and menu.position.y+menu.size.y<=root.size.y, "short More fits a phone without a long scrolling list")
	await shot("More_Eight_Choices")
	menu.hide()
	hud.settings_menu.popup(Rect2i(360,900,340,0))
	await shot("Settings_Grouped")
	hud.settings_menu.hide()
	hud.own_unit=true;hud.inspecting_unit=true;hud.show_air_commands(false)
	var orders: = hud.orders_menu.get_popup()
	check(orders.item_count==5 and orders.get_item_index(10)<0, "ground army More has at most five visible choices")
	check((orders.get_node("Organize") as PopupMenu).item_count==2 and hud.army_orders.item_count==3, "advanced army orders are grouped")
	hud.show_air_commands(true)
	check(orders.get_item_index(10)>=0 and orders.get_item_index(20)<0, "aircraft show Rebase and hide ground-only orders")
	hud.show_air_commands(false)
	orders.popup(Rect2i(360,850,340,0))
	await shot("Army_Commands_Grouped")
	orders.hide();hud.clear_unit_selection()

	var economy: = ProductionSystem.new()
	for country in ["russia","ukraine"]:
		economy.stockpiles[country]={}
		for resource in ProductionSystem.RESOURCES:economy.stockpiles[country][resource]=0.0
		economy.gold[country]=GoldWallet.START
	var panel: = GoldPanel.new();root.add_child(panel);panel.setup(economy,StrategyTheme.create());panel.open()
	await frames()
	check(panel.purchases.size()==12, "both pack sizes use the price book for all six resources")
	check(GoldWallet.resource_price("electronics",1000)==5000 and panel.purchases[-1].button.disabled, "expensive bulk resource purchase is visibly disabled when unaffordable")
	for size in [Vector2i(640,1280),Vector2i(720,1440),Vector2i(1440,900)]:
		root.size=size;await frames()
		var bounds: = panel.panel.get_global_rect()
		# canvas_items stretch uses logical coordinates, including expanded desktop width.
		var viewport_size: = root.get_visible_rect().size
		check(bounds.position.x>=-1 and bounds.end.x<=viewport_size.x+1 and bounds.end.y<=viewport_size.y+1, "gold panel fits "+str(size)+" bounds="+str(bounds))
	root.size=Vector2i(720,1440);await frames()
	await shot("Gold_Resource_Prices")
	(panel.list.get_parent() as ScrollContainer).scroll_vertical=99999
	await shot("Gold_Canadian_Pack")
	panel.hide()
	var clock: = SimulationClock.new()
	var research: = ResearchSystem.new();research.setup(economy,clock,null);economy.research=research
	var card: = UnitDetailPanel.new();root.add_child(card);card.setup(StrategyTheme.create());card.open("infantry_russia",1,research)
	await frames()
	check(card.action.disabled and card.gold_action.visible and not card.gold_action.disabled, "missing regular resources can be covered with gold")
	check(card.gold_breakdown.text.contains("1334 gold for remaining time + 1732 gold for missing resources = 3066 gold"), "phone displays a time/resource/total breakdown")
	check(card.gold_action.get_global_rect().end.y<=root.size.y, "gold action stays visible under the breakdown")
	await shot("Research_Missing_Resources")
	card.gold_action.pressed.emit()
	check(research.level("infantry_russia")==1 and economy.gold.russia==GoldWallet.START-3066, "card purchase uses the displayed quote")
	research.levels.infantry_russia=0
	for resource in ProductionSystem.RESOURCES:economy.stockpiles.russia[resource]=100000.0
	research.start("infantry_russia",1,"russia")
	var job: = research.active("infantry_russia");job.progress=research.job_duration(job)*0.5
	card.open("infantry_russia",1,research);await frames()
	check(card.gold_breakdown.text.contains("667 gold for remaining time + 0 gold for missing resources"), "paid half-complete research shows time only")
	await shot("Research_Time_Only")
	clock.free()
	print("RESULT GOLD_MENUS checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
