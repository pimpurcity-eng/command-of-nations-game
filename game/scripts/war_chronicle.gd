class_name WarChronicle
extends RefCounted
## Battle reports and the daily newspaper (owner request 2026-10-12, Call of War style).
## Battles: fighting in one province within one game hour is one battle; each report lists
## shots fired and units lost per country. Newspaper: at the end of every game day an issue
## sums up captures, losses, the biggest battle, research and the race to victory.
const BATTLE_WINDOW: = VictoryRules.DAY / 24.0
const MAX_BATTLES: = 60
const MAX_ISSUES: = 30

var rules: MatchSystem
var battles: Array = []   # newest last: {id, province, start, end, shots{c:n}, lost{c:[names]}, day}
var issues: Array = []    # newest last: {day, headline, lines[]}
var day_events: Dictionary = {"captures": [], "lost": {}, "research": {}, "built": {}}
var last_day: = 1

func setup(match_system: MatchSystem) -> void:
	rules = match_system
	rules.combat.weapon_fired.connect(_on_shot)
	rules.air_combat.weapon_fired.connect(_on_shot)
	rules.unit_destroyed.connect(_on_destroyed)
	rules.report.connect(_on_report)

func day() -> int:
	return 1 + int((rules.clock.elapsed if rules.clock != null else 0.0) / VictoryRules.DAY)

func _province_of(position: Vector3) -> String:
	var point: = Vector2(position.x, position.z)
	for t in rules.terrain.territories:
		if t.playable and RegionData.contains(t, point): return str(t.title)
	return "open sea"

## Fighting within BATTLE_RANGE map units (both sides of a border) and one game hour is one
## battle, named after the province where it started.
const BATTLE_RANGE: = 2.0
func _battle_at(position: Vector3) -> Dictionary:
	var now: float = rules.clock.elapsed if rules.clock != null else 0.0
	var point: = Vector2(position.x, position.z)
	for i in range(battles.size() - 1, -1, -1):
		var b: Dictionary = battles[i]
		if now - b.end <= BATTLE_WINDOW and Vector2(b.x, b.z).distance_to(point) <= BATTLE_RANGE: return b
		if now - b.end > BATTLE_WINDOW * 4: break
	var battle: = {"id": battles.size() + 1, "province": _province_of(position), "x": point.x, "z": point.y, "start": now, "end": now, "shots": {}, "lost": {}, "day": day()}
	battles.append(battle)
	if battles.size() > MAX_BATTLES: battles.pop_front()
	return battle

func _on_shot(source: Dictionary, target_unit: Dictionary, _effect: String) -> void:
	if target_unit.get("node") == null: return
	var battle: = _battle_at(target_unit.node.position)
	battle.end = rules.clock.elapsed if rules.clock != null else 0.0
	battle.shots[source.country] = int(battle.shots.get(source.country, 0)) + 1

func _on_destroyed(unit: Dictionary) -> void:
	var battle: = _battle_at(unit.node.position if unit.get("node") != null else Vector3.ZERO)
	var title: = EquipmentIdentity.title(unit.get("equipment_id", "")) if not str(unit.get("equipment_id", "")).is_empty() else str(unit.get("name", "unit"))
	if not battle.lost.has(unit.country): battle.lost[unit.country] = []
	battle.lost[unit.country].append(title)
	day_events.lost[unit.country] = int(day_events.lost.get(unit.country, 0)) + 1

func _on_report(message: String) -> void:
	if " captured by " in message: day_events.captures.append(message)

func note_research(country: String) -> void:
	day_events.research[country] = int(day_events.research.get(country, 0)) + 1

func note_building(country: String) -> void:
	day_events.built[country] = int(day_events.built.get(country, 0)) + 1

## Called every step; prints an issue when a game day ends.
func advance(_seconds: float) -> void:
	var today: = day()
	while last_day < today:
		publish(last_day)
		last_day += 1

func publish(issue_day: int) -> Dictionary:
	var lines: Array = []
	var headline: = "Day %d: an uneasy quiet on the front" % issue_day
	var captures: Array = day_events.captures
	if not captures.is_empty():
		headline = "Day %d: %s" % [issue_day, captures[-1].replace(" captured by ", " falls to ")]
		for capture in captures.slice(-6): lines.append("• " + capture)
	var losses: Dictionary = day_events.lost
	if not losses.is_empty():
		var parts: = []
		for country in losses: parts.append("%s %d" % [country.capitalize(), losses[country]])
		lines.append("Losses today: " + ", ".join(parts) + " units.")
		if captures.is_empty():
			var worst: = ""
			for country in losses:
				if worst.is_empty() or losses[country] > losses[worst]: worst = country
			headline = "Day %d: heavy losses for %s" % [issue_day, worst.capitalize()]
	var biggest: Dictionary = {}
	for b in battles:
		if b.day != issue_day: continue
		if biggest.is_empty() or _size(b) > _size(biggest): biggest = b
	if not biggest.is_empty(): lines.append("Biggest battle: " + summary(biggest))
	for country in day_events.research: lines.append("%s completed %d research projects." % [country.capitalize(), day_events.research[country]])
	for country in day_events.built: lines.append("%s finished %d construction projects." % [country.capitalize(), day_events.built[country]])
	var countries: Array = rules.production.stockpiles.keys() if rules.production != null else ["russia", "ukraine"]
	var table: = VictoryRules.standings(rules.terrain.territories, rules.cities, countries)
	var race: = []
	for country in countries:
		race.append("%s %d pts (%d%% to domination)" % [country.capitalize(), table[country].points, roundi(100.0 * table[country].domination / VictoryRules.DOMINATION_SHARE)])
	lines.append("Standings: " + " · ".join(race))
	var leader: = ""
	for country in countries:
		if leader.is_empty() or rules.victory.income_share(country) > rules.victory.income_share(leader): leader = country
	if not leader.is_empty() and rules.victory.income_share(leader) > 0.0:
		lines.append("Economy: %s earns %d%% of all income." % [leader.capitalize(), roundi(100.0 * rules.victory.income_share(leader))])
	var issue: = {"day": issue_day, "headline": headline, "lines": lines}
	var statement: = _statement(issue_day, captures, losses)
	if not statement.is_empty(): issue["statement"] = statement
	issues.append(issue)
	if issues.size() > MAX_ISSUES: issues.pop_front()
	day_events = {"captures": [], "lost": {}, "research": {}, "built": {}}
	return issue

## Owner 2026-10-16 ("make the newspaper better"): one AI government gives the paper a short
## statement each day, picked by how its day went. {country, text} or {} with no AI country.
func _statement(issue_day: int, captures: Array, losses: Dictionary) -> Dictionary:
	var speakers: Array = rules.diplomacy.ai_countries.filter(func(c): return rules.production == null or rules.production.stockpiles.has(c)) if rules.diplomacy != null else []
	if speakers.is_empty(): return {}
	var country: String = speakers[issue_day % speakers.size()]
	var name: = country.capitalize()
	var won: = captures.any(func(c: String): return c.to_lower().ends_with(" by " + name.to_lower()))
	var lost: = captures.any(func(c: String): return not c.to_lower().ends_with(" by " + name.to_lower()))
	var options: Array
	if won: options = ["Our forces advance as planned. More will follow.", "Victory is near. The people of %s stand united." % name, "Another city returns to order under our flag."]
	elif lost: options = ["A temporary setback. We will retake every metre.", "The enemy will pay for every town it holds.", "Reinforcements are already on the way."]
	elif int(losses.get(country, 0)) > 0: options = ["Our soldiers fight with honour. Their sacrifice will not be forgotten.", "The front holds despite heavy fighting."]
	else: options = ["We are ready for talks, and ready for war.", "Our factories work day and night. Let no one doubt our resolve.", "The government of %s is watching the border closely." % name]
	return {"country": country, "text": options[issue_day % options.size()]}

static func _size(b: Dictionary) -> int:
	var total: = 0
	for c in b.shots: total += int(b.shots[c])
	for c in b.lost: total += 10 * b.lost[c].size()
	return total

## One line per battle: "Battle of Kharkiv region (day 3): Russia fired 12, lost 2 (T-90M, ...)".
static func summary(b: Dictionary) -> String:
	var parts: = []
	var countries: = {}
	for c in b.shots: countries[c] = true
	for c in b.lost: countries[c] = true
	for c in countries:
		var lost: Array = b.lost.get(c, [])
		var text: = "%s fired %d, lost %d" % [str(c).capitalize(), int(b.shots.get(c, 0)), lost.size()]
		if not lost.is_empty(): text += " (" + ", ".join(lost.slice(0, 3)) + ("…" if lost.size() > 3 else "") + ")"
		parts.append(text)
	return "Battle of %s (day %d): %s" % [b.province, b.day, "; ".join(parts)]

func snapshot() -> Dictionary:
	return {"battles": battles.duplicate(true), "issues": issues.duplicate(true), "day_events": day_events.duplicate(true), "last_day": last_day}

func restore(state: Dictionary) -> void:
	battles = state.get("battles", []).duplicate(true)
	issues = state.get("issues", []).duplicate(true)
	day_events = state.get("day_events", {"captures": [], "lost": {}, "research": {}, "built": {}}).duplicate(true)
	last_day = int(state.get("last_day", 1))
