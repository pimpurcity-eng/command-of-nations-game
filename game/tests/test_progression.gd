extends SceneTree
## Ranks, achievements, medals, leaderboard, tutorial, alerts and translations
## (owner request 2026-10-12).
##   godot --headless --path . --script tests/test_progression.gd
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
	else: print("PASS ", message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	ArsenalFixture.use_archive()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Achievements.PATH))
	var settings: = ConfigFile.new()
	settings.load(Tutorial.SETTINGS_PATH)
	settings.set_value("tutorial", "done", false)
	settings.set_value("general", "locale", "en")
	settings.save(Tutorial.SETTINGS_PATH)
	# Ranks.
	check(Achievements.rank(1) == "Private" and Achievements.rank(5) == "Lieutenant" and Achievements.rank(60) == "Field Marshal", "levels map to military ranks")
	GameSession.player_country = "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	current_scene = game
	for i in 3: await process_frame
	game.mobile_start.hide()
	game.match_rules.ai_enabled = false
	var rules: MatchSystem = game.match_rules
	# Achievements from play.
	var enemy: Dictionary = {}
	for unit in game.units.units:
		if unit.country == "ukraine" and enemy.is_empty(): enemy = unit
	rules.unit_destroyed.emit(enemy)
	check(game.achievements.unlocked.has("first_blood") and "ACHIEVEMENT UNLOCKED · First Blood" in game.hud.status_message, "destroying an enemy army unlocks First Blood and announces it")
	var capital: Dictionary = {}
	for city in game.cities.cities:
		if city.country == "Ukraine" and city.get("capital", false): capital = city
	var title: = ""
	for t in game.map.territories:
		if t.id == capital.sector: title = t.title
	rules.report.emit(title + " captured by Russia")
	check(game.achievements.unlocked.has("capital_fall") and game.achievements.unlocked.has("conqueror"), "capturing the enemy capital unlocks Conqueror and Fall of the Capital")
	for i in 25: game.research.completed.emit("tanks_russia", "russia")
	check(game.achievements.unlocked.has("strategist"), "25 research projects unlock Strategist")
	rules.diplomacy.agreed.emit("russia", "ukraine", "peace")
	check(game.achievements.unlocked.has("peacemaker"), "an accepted peace unlocks Peacemaker")
	# Medals at the end of a campaign.
	rules.clock.elapsed = 3.0 * VictoryRules.DAY
	rules.end_match("russia", "domination")
	check(game.achievements.unlocked.has("domination") and game.achievements.unlocked.has("first_victory") and int(game.achievements.medals.get("blitz", 0)) == 1 and int(game.achievements.medals.get("no_nukes", 0)) == 1, "a quick clean domination win earns Blitz and Clean Hands")
	var stored: = Achievements.new()
	stored.load_saved()
	check(stored.unlocked.has("domination") and stored.counters.get("research", 0) == 25, "achievements and counters are remembered on the phone")
	# Tutorial.
	game.queue_free()
	await process_frame
	GameSession.player_country = "russia"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	current_scene = game
	for i in 3: await process_frame
	game.match_rules.ai_enabled = false
	game.mobile_start.fresh_requested.emit()
	game.mobile_start.hide()
	await process_frame
	check(game.tutorial != null and game.tutorial.step == 0 and "TUTORIAL 1/7" in game.tutorial.text.text, "a first campaign starts the tutorial")
	var army: Dictionary = {}
	for unit in game.units.units:
		if unit.country == "russia" and unit.visual_kind == "armor" and army.is_empty(): army = unit
	game.units.select_unit(game.units.units.find(army))
	for i in 30: await process_frame
	check(game.tutorial.step >= 1, "selecting an army completes the first step")
	game.player_order(game.map_position(39.2, 51.66))
	for i in 30: await process_frame
	check(game.tutorial.step >= 2, "moving it completes the second")
	game.tutorial.finish()
	await process_frame
	check(Tutorial.done(), "finishing (or skipping) the tutorial is remembered")
	# Alerts.
	game.rig.target = Vector3(400, 0, 400)
	game.rig._snap(1.0)
	await process_frame
	game.match_rules.declare_war()
	game._last_alert = -1000.0
	for unit in game.units.units:
		if unit.country == "ukraine": enemy = unit
	game.match_rules.combat.weapon_fired.emit(enemy, army, "cannon")
	check(game.hud.status_message.begins_with("UNDER ATTACK"), "an army attacked off-screen raises an alert: " + game.hud.status_message)
	# Translations.
	TranslationServer.set_locale("de")
	check(TranslationServer.translate("START CAMPAIGN") == "KAMPAGNE STARTEN" and TranslationServer.translate("Victory") == "Sieg", "German translations load")
	TranslationServer.set_locale("ru")
	check(TranslationServer.translate("Propose peace") == "Предложить мир", "Russian translations load")
	TranslationServer.set_locale("uk")
	check(TranslationServer.translate("Retreat") == "Відступити", "Ukrainian translations load")
	check(game.mobile_start.language_picker.item_count == 6, "the start screen offers six languages")
	TranslationServer.set_locale("en")
	# Leaderboard over the account service (mocked).
	var auth: = PlayerAuth.new()
	root.add_child(auth)
	auth.base_url = "https://example.supabase.co"
	auth.public_key = "sb_publishable_example"
	auth.transport = func(path: String, payload: Dictionary, method: int, bearer: String) -> Dictionary:
		return {"ok": true, "status": 200, "data": {"rows": [{"place": 1, "commander_name": "Bravo", "level": 4, "xp": 900, "wins": 3}]}}
	auth.accept_session({"access_token": "t", "refresh_token": "r", "expires_in": 3600, "user": {"id": "id", "email": "a@b.cd", "email_confirmed_at": "2026-10-12T00:00:00Z"}}, false)
	var board: = await auth.leaderboard(10)
	check(board.ok and board.data.rows[0].commander_name == "Bravo", "the leaderboard loads commander names, levels and wins")
	print("RESULT failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
