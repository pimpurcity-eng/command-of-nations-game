class_name DefenceAI
extends RefCounted
## Guard mode (owner 2026-10-13, planned for the premium account): "if you need to sleep, you
## can click a button and the AI will defend for you." Unlike CountryAI it never attacks:
##  * enemy armies inside your land, or heading into it near one of your cities, are threats;
##  * the nearest idle ground armies move to meet a threat while the route stays on your own
##    land, otherwise they fall back into the threatened city;
##  * a city's last garrison stays put unless that city is the one under threat;
##  * grounded fighters patrol over the threatened city;
##  * nothing is produced, researched or spent, and no war is declared.
const THREAT_RADIUS: = 4.0     # enemy this close to one of your cities is a threat
const RESPONSE_RADIUS: = 9.0   # armies further away keep their position
const GARRISON_RADIUS: = 0.8
const MAX_RESPONDERS: = 2      # armies sent to each threat
const MAX_ORDERS: = 6          # armies moved per decision, so the front is not stripped
const THINK_EVERY: = 2.0       # game seconds between decisions
var country: = "russia"
var timer: = 0.0
var last_report: = ""
## "While you were away" log (owner 2026-10-13): shown when guard mode is switched off.
var started: = 0.0
var defended: Dictionary = {}   # city name -> times armies were sent to defend it
var kills: = 0
var lost: = 0
var lost_places: Array = []
var retaken: Array = []

func log_state() -> Dictionary:
	return {"started": started, "defended": defended.duplicate(), "kills": kills, "lost": lost, "lost_places": lost_places.duplicate(), "retaken": retaken.duplicate()}

func restore_log(state: Dictionary) -> void:
	started = float(state.get("started", started))
	defended = Dictionary(state.get("defended", {})).duplicate()
	kills = int(state.get("kills", 0))
	lost = int(state.get("lost", 0))
	lost_places = Array(state.get("lost_places", [])).duplicate()
	retaken = Array(state.get("retaken", [])).duplicate()

## One short report for the morning.
func summary(now: float) -> String:
	var lines: Array = ["WHILE YOU WERE AWAY · " + SimulationClock.duration(maxf(0.0, now - started))]
	if defended.is_empty(): lines.append("No attacks on your land")
	else:
		var places: Array = defended.keys()
		places.sort_custom(func(a, b): return defended[a] > defended[b])
		lines.append("Attacks met at " + ", ".join(places.slice(0, 4)) + (" and %d more" % (places.size() - 4) if places.size() > 4 else ""))
	lines.append("%d enemy %s destroyed · %d of your %s lost" % [kills, "army" if kills == 1 else "armies", lost, "army" if lost == 1 else "armies"])
	if not lost_places.is_empty(): lines.append("Lost: " + ", ".join(lost_places.slice(0, 5)))
	if not retaken.is_empty(): lines.append("Taken back: " + ", ".join(retaken.slice(0, 5)))
	if lost_places.is_empty(): lines.append("No provinces lost")
	return "\n".join(lines)

func decide(armies: UnitSystem, cities: Array, production: ProductionSystem, seconds: float) -> String:
	timer += seconds
	if timer < THINK_EVERY: return ""
	timer = 0.0
	if not armies.at_war: return ""
	var own_cities: Array = cities.filter(func(c: Dictionary): return production == null or production.controlled(c, country))
	# Threats: visible living enemies in our land or near our cities.
	var threats: Array = []
	for enemy in armies.units:
		if enemy.country == country or enemy.health <= 0 or not armies.unit_visible(enemy, country): continue
		var at: = Vector2(enemy.node.position.x, enemy.node.position.z)
		var city: = _nearest(own_cities, at)
		var near_city: bool = not city.is_empty() and city.point.distance_to(at) <= THREAT_RADIUS
		# A threat is an enemy inside our land, or one near our city that is heading into it.
		var inside: bool = armies.navigation.controller_at(at) == country
		var incoming: bool = near_city and enemy.get("moving", false) and armies.navigation.controller_at(enemy.target) == country
		if not inside and not incoming: continue
		# Enemies close together are one threat.
		var merged: = false
		for t in threats:
			if t.point.distance_to(at) < 1.5: merged = true
		if not merged: threats.append({"point": at, "city": city, "air": enemy.visual_kind == "fighter"})
	if threats.is_empty(): return ""
	threats.sort_custom(func(a, b): return a.point.distance_to(a.city.get("point", a.point)) < b.point.distance_to(b.city.get("point", b.point)))
	var used: Dictionary = {}
	var orders: = 0
	for threat in threats:
		var responders: = 0
		var candidates: Array = []
		for group in armies.stacks.groups():
			var leader: Dictionary = armies.stacks.leader(group)
			if leader.country != country or used.has(leader.id) or leader.health <= 0: continue
			if leader.get("moving", false) or leader.get("engaged", false) or armies.is_naval(leader): continue
			if group.any(func(m): return EquipmentIdentity.spec(m.equipment_id).get("stationary", false)): continue
			var at: = Vector2(leader.node.position.x, leader.node.position.z)
			if at.distance_to(threat.point) > RESPONSE_RADIUS: continue
			candidates.append({"group": group, "leader": leader, "at": at})
		candidates.sort_custom(func(a, b): return a.at.distance_to(threat.point) < b.at.distance_to(threat.point))
		for c in candidates:
			if responders >= MAX_RESPONDERS or orders >= MAX_ORDERS: break
			var leader: Dictionary = c.leader
			if leader.visual_kind == "fighter":
				if threat.city.is_empty(): continue
				var refused: String = armies.air.order(leader, threat.city.point, "patrol")
				if not refused.is_empty(): continue
				used[leader.id] = true
				responders += 1
				orders += 1
				continue
			if threat.air: continue  # ground armies do not chase aircraft
			# Keep the last garrison of another city at home.
			var home: = _nearest(own_cities, c.at)
			if not home.is_empty() and home.point.distance_to(c.at) <= GARRISON_RADIUS and home.id != threat.city.get("id", "") and _garrison(armies, home, country) <= 1: continue
			var goal: Vector2 = threat.point
			var path: Array = armies.path_for(leader, c.at, goal)
			if path.is_empty() or path.any(func(p: Vector2): return armies.navigation.controller_at(p) != country):
				# Never follow the enemy out of our own land: hold the threatened city instead.
				if threat.city.is_empty(): continue
				goal = threat.city.point
				if goal.distance_to(c.at) <= GARRISON_RADIUS: continue
				path = armies.path_for(leader, c.at, goal)
				if path.is_empty() or path.any(func(p: Vector2): return armies.navigation.controller_at(p) != country): continue
			for member in c.group:
				member.target = goal
				member.waypoints = path.duplicate()
				member.moving = true
			armies._update_heading(leader)
			used[leader.id] = true
			responders += 1
			orders += 1
	if orders == 0: return ""
	var city_name: String = threats[0].city.get("name", "your land")
	defended[city_name] = int(defended.get(city_name, 0)) + 1
	var report: = "GUARD · %d armies moved to defend %s" % [orders, city_name]
	if report == last_report: return ""
	last_report = report
	return report

func _nearest(places: Array, point: Vector2) -> Dictionary:
	var best: Dictionary = {}
	for place in places:
		if best.is_empty() or place.point.distance_to(point) < best.point.distance_to(point): best = place
	return best

func _garrison(armies: UnitSystem, city: Dictionary, owner: String) -> int:
	var count: = 0
	for group in armies.stacks.groups():
		var leader: Dictionary = armies.stacks.leader(group)
		if leader.country == owner and Vector2(leader.node.position.x, leader.node.position.z).distance_to(city.point) <= GARRISON_RADIUS: count += 1
	return count
