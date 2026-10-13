class_name VictoryRules
extends RefCounted
## How a match is won (owner request 2026-10-12, Call of War / Conflict of Nations style):
## - DOMINATION: capture DOMINATION_SHARE of all victory points outside your homeland and hold
##   them for a game hour. Provinces are worth 1 point, cities 5, capitals 10, so the target is
##   fair for big and small countries alike.
## - ECONOMIC (very hard): earn ECONOMIC_SHARE of all income on the map, keep a treasury of
##   ECONOMIC_FUNDS and hold your capital, every moment for ECONOMIC_DAYS days in a row.
##   Losing any condition resets the count.
## - ELIMINATION: every rival has lost all armies and production (MatchSystem keeps this one).
## - POINTS: after TIME_LIMIT_DAYS the country with the most victory points wins.
## Game time: one day is 86 400 displayed seconds = 720 simulation seconds at 1x.
const DAY: = 86400.0 / SimulationClock.REAL_SECONDS_PER_SIM_SECOND
const DOMINATION_SHARE: = 0.6
const DOMINATION_HOLD: = DAY / 24.0
const ECONOMIC_SHARE: = 0.8
const ECONOMIC_FUNDS: = 250000.0
const ECONOMIC_DAYS: = 7.0
const TIME_LIMIT_DAYS: = 45.0
const PROVINCE_POINTS: = 1
const CITY_POINTS: = 5
const CAPITAL_POINTS: = 10

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
	# Domination.
	for country in countries:
		if table[country].domination >= DOMINATION_SHARE:
			domination_held[country] = domination_held.get(country, 0.0) + seconds
			if domination_held[country] >= DOMINATION_HOLD: return [country, "domination"]
		else: domination_held.erase(country)
	# Economic: income share measured over the last full game hour.
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
	var share: float = float(income_rate.get(country, 0.0)) / maxf(all_income, 1e-6)
	var funds: float = rules.production.stockpiles.get(country, {}).get("funds", 0.0) if rules.production != null else 0.0
	return [share >= ECONOMIC_SHARE, funds >= ECONOMIC_FUNDS, holds_capital(rules, country)]

static func holds_capital(rules: MatchSystem, country: String) -> bool:
	for city in rules.cities:
		if city.get("capital", false) and str(city.get("country", "")).to_lower() == country:
			for t in rules.terrain.territories:
				if t.id == city.get("sector", "") and t.controller == country: return true
	return false

func income_share(country: String) -> float:
	var total: = 0.0
	for other in income_rate: total += income_rate[other]
	return income_rate.get(country, 0.0) / maxf(total, 1e-6)

func snapshot() -> Dictionary:
	return {"domination_held": domination_held.duplicate(), "economic_held": economic_held.duplicate(), "income_rate": income_rate.duplicate()}

func restore(state: Dictionary) -> void:
	domination_held = state.get("domination_held", {}).duplicate()
	economic_held = state.get("economic_held", {}).duplicate()
	income_rate = state.get("income_rate", {}).duplicate()
