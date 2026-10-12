class_name Diplomacy
extends RefCounted
## Relations, coalitions and messages (owner request 2026-10-12, Call of War style).
## Works for any number of countries (Europe/world maps and future online matches); in the
## regional campaign the other side is the AI, which answers proposals by how the war is going.
## - Relation of every pair: war or peace, plus right of way (armies may cross), shared vision
##   (see what they see) and embargo (one-sided sanctions: SANCTION per embargo on the market).
## - Coalitions: members are at peace and share vision; leaving one blocks rejoining for
##   REJOIN_DAYS days.
## - Messages: a chat log (to a country, a coalition or everyone); AI countries reply.
signal changed
const DAY: = VictoryRules.DAY
const REJOIN_DAYS: = 3.0
const PROPOSAL_COOLDOWN: = DAY / 4.0
const SANCTION: = 0.25
const MAX_MESSAGES: = 200

var relations: Dictionary = {}   # "a|b" (sorted) -> {"war", "right_of_way", "shared_vision", "since"}
var embargoes: Dictionary = {}   # "from>to" -> true
var coalitions: Dictionary = {}  # name -> {"members": [], "leader"}
var left_at: Dictionary = {}     # country -> time it last left a coalition
var last_proposal: Dictionary = {}  # "from>to:kind" -> time
var messages: Array = []         # {time, from, to, text}
var ai_countries: Array = []
var now: = 0.0

static func pair(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a

func relation(a: String, b: String) -> Dictionary:
	var key: = pair(a, b)
	if not relations.has(key): relations[key] = {"war": false, "right_of_way": false, "shared_vision": false, "since": now}
	return relations[key]

func at_war(a: String, b: String) -> bool:
	return a != b and relation(a, b).war

func set_war(a: String, b: String, war: bool) -> void:
	var r: = relation(a, b)
	if r.war == war: return
	r.war = war
	r.since = now
	if war:
		r.right_of_way = false
		r.shared_vision = false
		for name in coalitions.keys():
			var members: Array = coalitions[name].members
			if a in members and b in members: leave(b, true)
	changed.emit()

func shares_vision(viewer: String, other: String) -> bool:
	if viewer == other: return true
	if relation(viewer, other).shared_vision: return true
	var mine: = coalition_of(viewer)
	return not mine.is_empty() and mine == coalition_of(other)

func right_of_way(mover: String, owner: String) -> bool:
	return mover == owner or relation(mover, owner).right_of_way or (not coalition_of(mover).is_empty() and coalition_of(mover) == coalition_of(owner))

func set_embargo(from: String, to: String, on: bool) -> void:
	if on: embargoes[from + ">" + to] = true
	else: embargoes.erase(from + ">" + to)
	changed.emit()

func embargoed(from: String, to: String) -> bool:
	return embargoes.has(from + ">" + to)

## Market price factor for `country` (buying ×, selling ÷).
func sanction_factor(country: String) -> float:
	var count: = 0
	for key in embargoes:
		if key.ends_with(">" + country): count += 1
	return 1.0 + SANCTION * count

func coalition_of(country: String) -> String:
	for name in coalitions:
		if country in coalitions[name].members: return name
	return ""

func create_coalition(name: String, leader: String) -> String:
	name = name.strip_edges()
	if name.length() < 3 or name.length() > 24: return "Coalition names have 3–24 characters"
	if coalitions.has(name): return "That name is taken"
	if not coalition_of(leader).is_empty(): return "Leave your coalition first"
	if now - float(left_at.get(leader, -INF)) < REJOIN_DAYS * DAY: return "You left a coalition less than %d days ago" % int(REJOIN_DAYS)
	coalitions[name] = {"members": [leader], "leader": leader}
	changed.emit()
	return ""

func join(name: String, country: String) -> String:
	if not coalitions.has(name): return "No such coalition"
	if not coalition_of(country).is_empty(): return "Leave your coalition first"
	if now - float(left_at.get(country, -INF)) < REJOIN_DAYS * DAY: return "You left a coalition less than %d days ago" % int(REJOIN_DAYS)
	for member in coalitions[name].members:
		if at_war(member, country): return "You are at war with a member"
	coalitions[name].members.append(country)
	changed.emit()
	return ""

func leave(country: String, quiet: bool = false) -> void:
	var name: = coalition_of(country)
	if name.is_empty(): return
	coalitions[name].members.erase(country)
	left_at[country] = now
	if coalitions[name].members.is_empty(): coalitions.erase(name)
	elif coalitions[name].leader == country: coalitions[name].leader = coalitions[name].members[0]
	if not quiet: changed.emit()

func post(from: String, to: String, text: String) -> void:
	text = text.strip_edges().left(300)
	if text.is_empty(): return
	messages.append({"time": now, "from": from, "to": to, "text": text})
	if messages.size() > MAX_MESSAGES: messages.pop_front()
	changed.emit()

## Messages a country can read: to it, from it, to everyone, or to its coalition.
func inbox(country: String) -> Array:
	var coalition: = coalition_of(country)
	return messages.filter(func(m: Dictionary): return m.to in ["all", country] or m.from == country or (not coalition.is_empty() and m.to == "coalition:" + coalition))

## A proposal from one country to another: "peace", "right_of_way", "shared_vision",
## "coalition". Players answer later; AI countries answer at once by how the war is going.
## Returns {"accepted": bool, "message": String}.
func propose(from: String, to: String, kind: String, standing: Dictionary = {}) -> Dictionary:
	var key: = "%s>%s:%s" % [from, to, kind]
	if now - float(last_proposal.get(key, -INF)) < PROPOSAL_COOLDOWN:
		return {"accepted": false, "message": "Wait a few hours before asking again"}
	last_proposal[key] = now
	if not to in ai_countries:
		post(from, to, "Proposal: " + kind.replace("_", " "))
		return {"accepted": false, "message": "Proposal sent"}
	var answer: = _ai_answer(from, to, kind, standing)
	if answer.accepted:
		match kind:
			"peace": set_war(from, to, false)
			"right_of_way": relation(from, to).right_of_way = true
			"shared_vision": relation(from, to).shared_vision = true
	post(to, from, answer.message)
	changed.emit()
	return answer

## The AI accepts peace when it is losing (the proposer holds more victory points and the war
## has lasted at least half a day); right of way and shared vision only after two days of peace.
func _ai_answer(from: String, to: String, kind: String, standing: Dictionary) -> Dictionary:
	var r: = relation(from, to)
	match kind:
		"peace":
			if not r.war: return {"accepted": false, "message": "We are not at war."}
			var losing: bool = standing.get(from, {}).get("points", 0) > standing.get(to, {}).get("points", 0) * 1.1
			if losing and now - r.since >= DAY * 0.5: return {"accepted": true, "message": "We accept your terms. The guns fall silent."}
			return {"accepted": false, "message": "Peace? Only when you have earned it on the battlefield."}
		"right_of_way", "shared_vision":
			if r.war or now - r.since < 2.0 * DAY: return {"accepted": false, "message": "We do not trust you yet."}
			return {"accepted": true, "message": "Agreed. Let this mark a new friendship."}
		"coalition":
			return {"accepted": false, "message": "We stand alone."}
	return {"accepted": false, "message": "We do not understand."}

func snapshot() -> Dictionary:
	return {"relations": relations.duplicate(true), "embargoes": embargoes.duplicate(), "coalitions": coalitions.duplicate(true), "left_at": left_at.duplicate(), "messages": messages.duplicate(true), "now": now}

func restore(state: Dictionary) -> void:
	relations = state.get("relations", {}).duplicate(true)
	embargoes = state.get("embargoes", {}).duplicate()
	coalitions = state.get("coalitions", {}).duplicate(true)
	left_at = state.get("left_at", {}).duplicate()
	messages = state.get("messages", []).duplicate(true)
	now = float(state.get("now", 0.0))
