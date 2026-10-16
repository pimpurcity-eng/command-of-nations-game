class_name VictoryRules
extends RefCounted
## How a match is won (owner request 2026-10-12, Call of War / Conflict of Nations style):
## - DOMINATION: capture DOMINATION_SHARE of all victory points outside your homeland and hold
##   them for a game hour. Provinces are worth 1 point, cities 5, capitals 10, so the target is
##   fair for big and small countries alike.
## - ECONOMIC: double the country’s starting productive income, keep a treasury of
##   ECONOMIC_FUNDS and hold your capital, every moment for ECONOMIC_DAYS days in a row.
##   Losing any condition resets the count.
## - ELIMINATION: every rival has lost all armies and production AND its capital (MatchSystem keeps
##   this one; owner 2026-10-16: destroying the starting armies alone ended matches unexpectedly).
## - POINTS: after TIME_LIMIT_DAYS the country with the most victory points wins.
## Game time: one day is 86 400 displayed seconds = 720 simulation seconds at 1x.
const DAY: = 86400.0 / SimulationClock.REAL_SECONDS_PER_SIM_SECOND
const DOMINATION_SHARE: = 0.6
## Owner 2026-10-16 ("I won the game. I don't know how."): domination is held for six game hours
## (was one) and the top bar counts it down, so a win never arrives unannounced.
const DOMINATION_HOLD: = DAY / 4.0
const ECONOMIC_GROWTH: = 2.0
const ECONOMIC_SHARE: = 0.8 # legacy saves/tests only; no longer a victory requirement
const ECONOMIC_FUNDS: = 250000.0
const ECONOMIC_DAYS: = 7.0
const TIME_LIMIT_DAYS: = 45.0
const PROVINCE_POINTS: = 1
const CITY_POINTS: = 5
const CAPITAL_POINTS: = 10

var economic_baseline: Dictionary = {} # starting productive capacity, persisted across saves
var domination_held: Dictionary = {}   # country -> sim seconds above the share
var economic_held: Dictionary = {}     # country -> sim seconds meeting every economic condition
var income_window: Dictionary = {}     # country -> income value earned in the current hour
var income_rate: Dictionary = {}       # country -> income value per sim second (last full hour)
var _window_age: = 0.0
var _last_earned: Dictionary = {}

## Victory points of every playable province: {territory id: [points, home country]}.
static func province_points(territories: Array, cities: Array) -> Dictionary:
	var points: Dictionary = {}
	for t in territories:
		if t.playable: points[t.id] = [PROVINCE_POINTS, str(t.owner)]
	for city in cities:
		var sector: String = city.get("sector", "")
		if points.has(sector):
			points[sector][0] += CAPITAL_POINTS if city.get("capital", false) else CITY_POINTS
	return points

## {country: {"points", "foreign_total", "foreign_held", "domination"}} for the scoreboard.
static func standings(territories: Array, cities: Array, countries: Array) -> Dictionary:
	var points: = province_points(territories, cities)
	var total: = 0
	var home: Dictionary = {}
	for id in points:
		total += points[id][0]
		home[points[id][1]] = home.get(points[id][1], 0) + points[id][0]
	var result: Dictionary = {}
	for country in countries:
		result[country] = {"points": 0, "foreign_total": total - home.get(country, 0), "foreign_held": 0, "domination": 0.0}
	for t in territories:
		if not points.has(t.id) or not result.has(t.controller): continue
		var row: Dictionary = result[t.controller]
		row.points += points[t.id][0]
		if points[t.id][1] != t.controller: row.foreign_held += points[t.id][0]
	for country in result:
		var row: Dictionary = result[country]
		row.domination = float(row.foreign_held) / maxf(1.0, row.foreign_total)
	return result

## Income in one number: funds plus resources at rough market value.
static func value(resources: Dictionary) -> float:
	return float(resources.get("funds", 0.0)) + 2.0 * float(resources.get("materials", 0.0)) + 4.0 * float(resources.get("electronics", 0.0)) + 2.5 * float(resources.get("fuel", 0.0)) + 3.0 * float(resources.get("manpower", 0.0)) + 1.5 * float(resources.get("food", 0.0))

## Called by MatchSystem every step. Returns [winner country, victory type] or [] if none.
func evaluate(rules: MatchSystem, seconds: float) -> Array:
	var countries: Array = rules.production.stockpiles.keys() if rules.production != null else ["russia", "ukraine"]
	var table: = standings(rules.terrain.territories, rules.cities, countries)
	if rules.production != null and economic_baseline.is_empty():
		var gross: Dictionary = rules.production.gross_income()
		for country in countries: economic_baseline[country] = maxf(1.0, value(gross.get(country, {})))
	# Domination.
	for country in countries:
		if table[country].domination >= DOMINATION_SHARE:
			domination_held[country] = domination_held.get(country, 0.0) + seconds
			if domination_held[country] >= DOMINATION_HOLD: return [country, "domination"]
		else: domination_held.erase(country)
	# Economic: productive income plus net exports over the last full game hour.
	if rules.production != null:
		_window_age += seconds
		for country in countries:
			var earned: float = value(rules.production.earned.get(country, {}))
			income_window[country] = income_window.get(country, 0.0) + earned - _last_earned.get(country, earned)
			_last_earned[country] = earned
		if _window_age >= DAY / 24.0:
			for country in countries: income_rate[country] = income_window.get(country, 0.0) / _window_age
			income_window.clear()
			_window_age = 0.0
		var all_income: = 0.0
		for country in countries: all_income += income_rate.get(country, 0.0)
		for country in countries:
			if economic_conditions(rules, country, all_income).all(func(ok: bool): return ok):
				economic_held[country] = economic_held.get(country, 0.0) + seconds
				if economic_held[country] >= ECONOMIC_DAYS * DAY: return [country, "economic"]
			else: economic_held.erase(country)
	# Points at the time limit.
	if rules.clock != null and rules.clock.elapsed >= TIME_LIMIT_DAYS * DAY:
		var best: = ""
		for country in countries:
			if best.is_empty() or table[country].points > table[best].points: best = country
		return [best, "points"]
	return []

## [income share met, treasury met, capital held] for the economic victory.
func economic_conditions(rules: MatchSystem, country: String, all_income: float = -1.0) -> Array:
	if all_income < 0:
		all_income = 0.0
		for other in income_rate: all_income += income_rate[other]
	var funds: float = rules.production.stockpiles.get(country, {}).get("funds", 0.0) if rules.production != null else 0.0
	return [float(income_rate.get(country, 0.0)) >= economic_target(country), funds >= ECONOMIC_FUNDS, holds_capital(rules, country)]

static func holds_capital(rules: MatchSystem, country: String) -> bool:
	for city in rules.cities:
		if city.get("capital", false) and str(city.get("country", "")).to_lower() == country:
			for t in rules.terrain.territories:
				if t.id == city.get("sector", "") and t.controller == country: return true
	return false

func economic_target(country: String) -> float:
	return maxf(1.0, float(economic_baseline.get(country, INF))) * ECONOMIC_GROWTH

func income_share(country: String) -> float:
	var total: = 0.0
	for other in income_rate: total += income_rate[other]
	return income_rate.get(country, 0.0) / maxf(total, 1e-6)

func snapshot() -> Dictionary:
	return {"economic_baseline": economic_baseline.duplicate(), "income_window": income_window.duplicate(), "last_earned": _last_earned.duplicate(), "window_age": _window_age, "domination_held": domination_held.duplicate(), "economic_held": economic_held.duplicate(), "income_rate": income_rate.duplicate()}

func restore(state: Dictionary) -> void:
	economic_baseline = state.get("economic_baseline", {}).duplicate()
	income_window = state.get("income_window", {}).duplicate()
	_last_earned = state.get("last_earned", {}).duplicate()
	_window_age = float(state.get("window_age", 0.0))
	domination_held = state.get("domination_held", {}).duplicate()
	economic_held = state.get("economic_held", {}).duplicate()
	income_rate = state.get("income_rate", {}).duplicate()

## Owner 2026-10-16: "make me ... I don't know how I won." The goals in one line (top bar tooltip,
## planning hint) and a plain explanation of how a finished match was won (result screen).
static func goal_text() -> String:
	return "Win: hold %d%% of enemy victory points for %s · or destroy every enemy army and take its capital · or double your economy for %d days · or lead on points on day %d" % [roundi(DOMINATION_SHARE * 100), SimulationClock.duration(DOMINATION_HOLD), int(ECONOMIC_DAYS), int(TIME_LIMIT_DAYS)]

## Seconds left until `country` wins by domination, or -1 when it is not holding the share.
func domination_countdown(country: String) -> float:
	if not domination_held.has(country): return -1.0
	return maxf(0.0, DOMINATION_HOLD - float(domination_held[country]))

## Enemy cities `country` controls, capitals first ("Kyiv (capital)").
static func captured_cities(rules: MatchSystem, country: String) -> Array:
	var names: Array = []
	for city in rules.cities:
		if str(city.get("country", "")).to_lower() == country: continue
		for t in rules.terrain.territories:
			if t.id == city.get("sector", "") and t.controller == country:
				if city.get("capital", false): names.push_front(str(city.name) + " (capital)")
				else: names.append(str(city.name))
	return names

static func explain(rules: MatchSystem, winner: String, kind: String) -> String:
	var countries: Array = rules.production.stockpiles.keys() if rules.production != null else ["russia", "ukraine"]
	var table: = standings(rules.terrain.territories, rules.cities, countries)
	var row: Dictionary = table.get(winner, {"points": 0, "foreign_total": 0, "foreign_held": 0, "domination": 0.0})
	var rivals: Array = countries.filter(func(c): return c != winner)
	var day: = 1 + int(rules.clock.elapsed / DAY) if rules.clock != null else 1
	var lines: Array = []
	match kind:
		"domination":
			lines.append("%s held %d of %d enemy victory points (%d%%; the goal is %d%%) for %s without a break." % [winner.capitalize(), row.foreign_held, row.foreign_total, roundi(row.domination * 100), roundi(DOMINATION_SHARE * 100), SimulationClock.duration(DOMINATION_HOLD)])
			lines.append("Provinces are worth %d point, cities %d, capitals %d." % [PROVINCE_POINTS, CITY_POINTS, CAPITAL_POINTS])
		"economic":
			lines.append("%s doubled its starting income, kept %s funds and held its capital for %d days in a row." % [winner.capitalize(), StrategyHUD._thousands(int(ECONOMIC_FUNDS)), int(ECONOMIC_DAYS)])
		"elimination":
			lines.append("%s destroyed every army of %s, stopped all its production and took its capital." % [winner.capitalize(), ", ".join(rivals.map(func(c): return str(c).capitalize()))])
		"points":
			var scores: Array = countries.map(func(c): return "%s %d" % [str(c).capitalize(), int(table[c].points)])
			lines.append("Time limit reached on day %d: %s had the most victory points (%s)." % [int(TIME_LIMIT_DAYS), winner.capitalize(), ", ".join(scores)])
		_:
			lines.append("%s won the match." % winner.capitalize())
	var taken: = captured_cities(rules, winner)
	if not taken.is_empty(): lines.append("Enemy cities held: " + ", ".join(taken.slice(0, 8)) + (" and %d more" % (taken.size() - 8) if taken.size() > 8 else "") + ".")
	lines.append("Decided on day %d." % day)
	return "\n".join(lines)

