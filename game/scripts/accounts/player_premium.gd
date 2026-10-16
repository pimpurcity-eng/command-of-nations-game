class_name PlayerPremium
extends RefCounted
## Owner 2026-10-16: "For premium account, I want you to start creating the premium account."
## Premium membership (Call of War style conveniences, never pay-to-win; see docs/PREMIUM.md).
## The flag is premium_until on the signed-in commander's profile
## (backend/migrations/005_premium.sql). Players can read it but never write it: only the
## server (service role / a future Google Play purchase check) sets it.
## Nothing is saved on the device, so premium cannot be switched on by editing local files.
## Owner 2026-10-16: rally points and the five-unit city queue are FREE for everyone.

## Free commanders queue five units per city; Premium commanders eight.
const FREE_PLAN_LIMIT := 5
const PREMIUM_PLAN_LIMIT := 8
const PRICE_IDEA := "$4.99 / month"
## What Premium gives (shown on the Premium screen). Only items marked live are switched on.
const BENEFITS: Array = [
	{"title": "8 production slots per city", "text": "Queue up to eight units in each city instead of five.", "live": true},
	{"title": "Premium badge", "text": "A gold PREMIUM badge and gold commander name on your profile.", "live": true},
	{"title": "Monthly gold bonus", "text": "Extra gold credited to your account every month.", "live": false},
	{"title": "Army templates", "text": "Save army formations and build them again with one tap.", "live": false},
	{"title": "Advanced army statistics", "text": "Full combat numbers, terrain bonuses and battle forecasts.", "live": false},
	{"title": "More match slots", "text": "Play more online matches and save slots at the same time.", "live": false},
	{"title": "Extra profile statistics", "text": "Match history, favourite units and win rate by country.", "live": false},
	{"title": "Ad-free", "text": "No adverts, ever (if adverts are added for free players).", "live": false},
]
## Always free for every commander (owner 2026-10-16).
const ALWAYS_FREE: Array = ["Rally points for new units", "Five-unit production queue per city", "Every unit, building and research", "Online matches and alliances"]

## Unix time the membership ends (0 = none) and whose profile it came from.
static var premium_until_unix := 0.0
static var premium_user := ""
## Test toggle: -1 follows the account, 0 forces off, 1 forces on. Tests set it directly;
## players can only use it in debug builds (the Premium screen hides it in release builds).
static var test_override := -1

static func is_premium() -> bool:
	if test_override >= 0 and (OS.is_debug_build() or test_override == 0): return test_override == 1
	return premium_until_unix > Time.get_unix_time_from_system()

## Most units one city may have queued for this country (only the player's own country gets
## the Premium slots; online matches follow the match server's rules).
static func plan_limit(country: String) -> int:
	if country == GameSession.player_country and MatchClient.active == null and is_premium(): return PREMIUM_PLAN_LIMIT
	return FREE_PLAN_LIMIT

static func clear() -> void:
	premium_until_unix = 0.0
	premium_user = ""

## Reads premium_until from a profile row. Missing, null or unreadable means not premium.
static func apply_profile(row: Dictionary, user_id: String = "") -> void:
	premium_user = user_id
	premium_until_unix = parse_time(row.get("premium_until"))

## ISO 8601 timestamp from Supabase (e.g. 2026-11-16T10:00:00.123+00:00) to unix seconds.
static func parse_time(value: Variant) -> float:
	if not value is String or str(value).length() < 19: return 0.0
	var text := str(value)
	var unix := float(Time.get_unix_time_from_datetime_string(text.substr(0, 19)))
	# Time zone suffix: Z, +HH:MM or -HH:MM after optional fractional seconds.
	var zone := RegEx.new()
	zone.compile("([+-])(\\d{2}):?(\\d{2})$")
	var found := zone.search(text)
	if found != null:
		var offset := int(found.get_string(2)) * 3600 + int(found.get_string(3)) * 60
		unix -= offset if found.get_string(1) == "+" else -offset
	return unix

## The end date shown on the profile and the Premium screen.
static func until_text() -> String:
	if premium_until_unix <= 0: return ""
	return Time.get_date_string_from_unix_time(int(premium_until_unix))

## Asks the account service for the signed-in commander's premium_until. Before migration 005
## is applied the column does not exist; the request fails and the commander stays free.
static func refresh(auth: PlayerAuth) -> Dictionary:
	if auth == null or not auth.signed_in():
		clear()
		return PlayerAuth.failure("Sign in first.")
	if not auth.has_meta("premium_watch"):
		auth.set_meta("premium_watch", true)
		auth.session_changed.connect(func():
			if not auth.signed_in() or str(auth.user.get("id", "")) != premium_user: clear())
	var user_id := str(auth.user.get("id", ""))
	# The account adapter runs one request at a time; wait briefly for the current one.
	for attempt in 50:
		if not auth.busy: break
		await auth.get_tree().create_timer(0.1).timeout
	var result: Dictionary = await auth.request("/rest/v1/player_profiles?select=premium_until&id=eq." + user_id.uri_encode(), {}, HTTPClient.METHOD_GET, auth.access_token)
	if not auth.signed_in() or str(auth.user.get("id", "")) != user_id: return PlayerAuth.failure("Account changed.")
	var rows: Variant = result.get("data", {}).get("rows", [])
	apply_profile(rows[0] if result.get("ok", false) and rows is Array and not rows.is_empty() else {}, user_id)
	return {"ok": true, "data": {"premium": is_premium(), "until": until_text()}}
