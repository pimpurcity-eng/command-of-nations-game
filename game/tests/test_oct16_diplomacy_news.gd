extends SceneTree
## Owner 2026-10-16, fixes 13-16: messages in Diplomacy (13), Diplomacy shows this map's coalition
## only (14), who is leading the war (15), a newspaper anyone can write in (16).
##   godot --headless --path . --script tests/test_oct16_diplomacy_news.gd
var failures: = 0
func check(ok: bool, text: String) -> void:
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", text)
func _initialize() -> void: call_deferred("run")
func texts(node: Node, into: Array = []) -> Array:
	if node is Label: into.append((node as Label).text)
	if node is Button: into.append((node as Button).text)
	if node is LineEdit: into.append((node as LineEdit).placeholder_text)
	for child in node.get_children(): texts(child, into)
	return into
func has_text(lines: Array, part: String) -> bool:
	return lines.any(func(line: String): return line.to_lower().contains(part.to_lower()))
func run() -> void:
	GameSession.player_country = "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	current_scene = game
	game.mobile_start.hide()
	game.clock.paused = true
	game.match_rules.ai_enabled = false
	var talks: Diplomacy = game.match_rules.diplomacy
	game.match_rules.advance(0.01)

	# 13: messages are written and read in Diplomacy; the AI answers.
	talks.post("russia", "ukraine", "Talks at dawn?")
	talks.post("ukraine", "russia", "Agreed.")
	talks.post("russia", "all", "To every nation")
	var inbox: = talks.inbox("russia")
	check(inbox.size() == 3, "13: Russia's inbox holds its private and public messages (%d)" % inbox.size())
	game.open_campaign("diplomacy")
	await process_frame
	var page: = texts(game.campaign_panel.content)
	check(has_text(page, "Messages") and has_text(page, "Write a message") and has_text(page, "Send"), "13: Diplomacy has a Messages section with a box and Send")
	check(has_text(page, "Talks at dawn?") and has_text(page, "Agreed."), "13: the conversation shows in Diplomacy")

	# 14: the coalition shown is this match's, not the account alliance.
	check(has_text(page, "this map only"), "14: the coalition heading says it is for this map only")
	check(has_text(page, "commander profile"), "14: account alliances are pointed to the profile instead")
	talks.create_coalition("Northern Pact", "russia")
	game.campaign_panel.open("diplomacy")
	await process_frame
	page = texts(game.campaign_panel.content)
	check(has_text(page, "Northern Pact") and has_text(page, "Leave coalition"), "14: your match coalition shows with Leave")

	# 15: the leaderboard marks who is leading.
	check(has_text(page, "Leaderboard") and has_text(page, "LEADING THE WAR"), "15: Diplomacy shows which country is leading")

	# 16: anyone can write in the newspaper; articles stay out of the inbox and keep their length.
	var long_text: = "Front report. ".repeat(60)
	talks.post_article("ukraine", "Kyiv stands firm")
	talks.post_article("russia", long_text)
	check(talks.articles().size() == 2, "16: both countries' articles are in the newspaper")
	check(talks.articles()[1].text.length() == Diplomacy.ARTICLE_LENGTH, "16: an article keeps up to %d letters (a chat only %d)" % [Diplomacy.ARTICLE_LENGTH, Diplomacy.CHAT_LENGTH])
	check(not talks.inbox("russia").any(func(m): return m.to == Diplomacy.NEWSPAPER), "16: articles do not fill the Diplomacy inbox")
	game.campaign_panel.open("news")
	await process_frame
	page = texts(game.campaign_panel.content)
	check(has_text(page, "WRITE ARTICLE"), "16: the newspaper has a Write article button")
	check(has_text(page, "Kyiv stands firm"), "16: readers' articles are printed in the newspaper")
	print("RESULT failures=", failures)
	quit(1 if failures > 0 else 0)
