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
signal agreed(from: String, to: String, kind: String)
signal coalition_created(name: String, leader: String)
const DAY: = VictoryRules.DAY
const REJOIN_DAYS: = 3.0
const PROPOSAL_COOLDOWN: = DAY / 4.0
const SANCTION: = 0.25
const MAX_MESSAGES: = 200
## Owner 2026-10-16: "Make the newspaper better. Anyone can post" - articles are messages
## addressed to the newspaper, so they save, load and travel online like the chat.
const NEWSPAPER: = "newspaper"
const ARTICLE_LENGTH: = 600
const CHAT_LENGTH: = 300

var relations: Dictionary = {}   # "a|b" (sorted) -> {"war", "right_of_way", "shared_vision", "since"}
var embargoes: Dictionary = {}   # "from>to" -> true
var coalitions: Dictionary = {}  # name -> {"members": [], "leader"}
var left_at: Dictionary = {}     # country -> time it last left a coalition
var last_proposal: Dictionary = {}  # "from>to:kind" -> time
var messages: Array = []         # {time, from, to, text}
var ai_countries: Array = []
var pending: Dictionary = {}     # "from>to:kind" -> time (proposals waiting for a player's answer)
var now: = 0.0

static func pair(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a

func relation(a: String, b: String) -> Dictionary:
	var key: = pair(a, b)
	if not relations.has(key): relations[key] = {"war": false, "right_of_way": false, "shared_vision": false, "trade": false, "since": now}
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
		r.trade = false
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
	if MatchClient.active != null:
		MatchClient.active.send("embargo", {"to": to, "on": on})
		return
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
	if MatchClient.active != null: return MatchClient.active.send("coalition_create", {"name": name})
	name = name.strip_edges()
	if name.length() < 3 or name.length() > 24: return "Coalition names have 3–24 characters"
	if coalitions.has(name): return "That name is taken"
	if not coalition_of(leader).is_empty(): return "Leave your coalition first"
	if now - float(left_at.get(leader, -INF)) < REJOIN_DAYS * DAY: return "You left a coalition less than %d days ago" % int(REJOIN_DAYS)
	coalitions[name] = {"members": [leader], "leader": leader}
	coalition_created.emit(name, leader)
	changed.emit()
	return ""

func join(name: String, country: String) -> String:
	if MatchClient.active != null: return MatchClient.active.send("coalition_join", {"name": name})
	if not coalitions.has(name): return "No such coalition"
	if not coalition_of(country).is_empty(): return "Leave your coalition first"
	if now - float(left_at.get(country, -INF)) < REJOIN_DAYS * DAY: return "You left a coalition less than %d days ago" % int(REJOIN_DAYS)
	for member in coalitions[name].members:
		if at_war(member, country): return "You are at war with a member"
	coalitions[name].members.append(country)
	changed.emit()
	return ""

func leave(country: String, quiet: bool = false) -> void:
	if MatchClient.active != null and not quiet:
		MatchClient.active.send("coalition_leave")
		return
	var name: = coalition_of(country)
	if name.is_empty(): return
	coalitions[name].members.erase(country)
	left_at[country] = now
	if coalitions[name].members.is_empty(): coalitions.erase(name)
	elif coalitions[name].leader == country: coalitions[name].leader = coalitions[name].members[0]
	if not quiet: changed.emit()

func post(from: String, to: String, text: String) -> void:
	if MatchClient.active != null:
		MatchClient.active.send("chat", {"to": to, "text": text})
		return
	text = text.strip_edges().left(ARTICLE_LENGTH if to == NEWSPAPER else CHAT_LENGTH)
	if text.is_empty(): return
	messages.append({"time": now, "from": from, "to": to, "text": text})
	if messages.size() > MAX_MESSAGES: messages.pop_front()
	changed.emit()

## Any country (player or AI) writes an article for the war newspaper.
func post_article(from: String, text: String) -> void:
	post(from, NEWSPAPER, text)

## Newspaper articles, oldest first: {time, from, to = NEWSPAPER, text}.
func articles() -> Array:
	return messages.filter(func(m: Dictionary): return m.to == NEWSPAPER)

## Messages a country can read: to it, from it, to everyone, or to its coalition.
func inbox(country: String) -> Array:
	var coalition: = coalition_of(country)
	return messages.filter(func(m: Dictionary): return m.to != NEWSPAPER and (m.to in ["all", country] or m.from == country or (not coalition.is_empty() and m.to == "coalition:" + coalition)))

## A proposal from one country to another: "peace", "right_of_way", "shared_vision",
## "coalition". Players answer later; AI countries answer at once by how the war is going.
## Returns {"accepted": bool, "message": String}.
func propose(from: String, to: String, kind: String, standing: Dictionary = {}) -> Dictionary:
	if MatchClient.active != null:
		MatchClient.active.send("propose", {"to": to, "kind": kind})
		return {"accepted": false, "message": "Proposal sent"}
	var key: = "%s>%s:%s" % [from, to, kind]
	if now - float(last_proposal.get(key, -INF)) < PROPOSAL_COOLDOWN:
		return {"accepted": false, "message": "Wait a few hours before asking again"}
	last_proposal[key] = now
	if not to in ai_countries:
		pending[key] = now
		post(from, to, "Proposal: " + kind.replace("_", " "))
		return {"accepted": false, "message": "Proposal sent"}
	var answer: = _ai_answer(from, to, kind, standing)
	if answer.accepted:
		agreed.emit(from, to, kind)
		match kind:
			"peace": set_war(from, to, false)
			"right_of_way": relation(from, to).right_of_way = true
			"shared_vision": relation(from, to).shared_vision = true
			"trade": relation(from, to).trade = true
	post(to, from, answer.message)
	changed.emit()
	return answer

## A player answers another player's proposal (online matches).
func answer(responder: String, proposer: String, kind: String, accept: bool) -> String:
	var key: = "%s>%s:%s" % [proposer, responder, kind]
	if not pending.has(key): return "No such proposal"
	pending.erase(key)
	if accept:
		match kind:
			"peace": set_war(proposer, responder, false)
			"right_of_way": relation(proposer, responder).right_of_way = true
			"shared_vision": relation(proposer, responder).shared_vision = true
			"trade": relation(proposer, responder).trade = true
			"coalition":
				var name: = coalition_of(proposer)
				if name.is_empty() or not coalition_of(responder).is_empty(): return "That coalition offer has lapsed"
				coalitions[name].members.append(responder)
		agreed.emit(proposer, responder, kind)
	post(responder, proposer, ("Accepted: " if accept else "Declined: ") + kind.replace("_", " "))
	changed.emit()
	return ""

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
		"trade":
			# Trade (owner 2026-10-13): trains and ships between the two countries.
			if r.war or now - r.since < 1.0 * DAY: return {"accepted": false, "message": "Trade must wait until the guns have been quiet for a day."}
			return {"accepted": true, "message": "Agreed. Our trains and ships are welcome at your stations and ports."}
		"coalition":
			return {"accepted": false, "message": "We stand alone."}
	return {"accepted": false, "message": "We do not understand."}

func snapshot() -> Dictionary:
	return {"pending": pending.duplicate(), "relations": relations.duplicate(true), "embargoes": embargoes.duplicate(), "coalitions": coalitions.duplicate(true), "left_at": left_at.duplicate(), "messages": messages.duplicate(true), "now": now}

func restore(state: Dictionary) -> void:
	relations = state.get("relations", {}).duplicate(true)
	embargoes = state.get("embargoes", {}).duplicate()
	coalitions = state.get("coalitions", {}).duplicate(true)
	left_at = state.get("left_at", {}).duplicate()
	messages = state.get("messages", []).duplicate(true)
	pending = state.get("pending", {}).duplicate()
	now = float(state.get("now", 0.0))
