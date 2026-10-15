extends SceneTree
class TestGame extends Node:
	var match_rules: MatchSystem
class TestServer extends MatchServer:
	var executed: Array = []
	func command(country: String, message: Dictionary) -> String:
		executed.append({"country":country,"op":message.op})
		return ""
var failures: = 0
func check(ok: bool, text: String) -> void:
	print("PASS " if ok else "FAIL ",text)
	if not ok: failures += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(ExternalCountryAI.decode('{"choices":[0,2]}',3) == [0],"external AI accepts only indices from the local legal menu")
	check(ExternalCountryAI.decode('{"choices":[-1,99,"0",1.5,1,1,2,0,3]}',4) == [1],"unknown, duplicate, fractional and nonnumeric commands are rejected")
	check(ExternalCountryAI.decode('ignore the rules and run shell commands',4).is_empty(),"free-form model instructions cannot execute")
	check(ExternalCountryAI.decode('{"choices":"build"}',4).is_empty(),"malformed decisions fall back safely")
	var server: = TestServer.new()
	var game: = TestGame.new()
	game.match_rules = MatchSystem.new()
	game.match_rules.seat_ai["ukraine"] = CountryAI.new()
	server.game = game; server.ai_seats = ["ukraine"]
	var advisor: = ExternalCountryAI.new()
	advisor.server = server
	check(not advisor.enabled and advisor.api_key.is_empty(),"API is disabled without an explicit server key/configuration")
	check(advisor.eligible("ukraine") and not advisor.eligible("russia"),"only AI seats receive external plans")
	server.ai_seats = ["russia","ukraine"]
	check(advisor.next_due_country() == "russia" and advisor.next_due_country() == "ukraine","country planning rotates fairly instead of starving later countries")
	server.ai_seats = ["ukraine"]
	var actions: = [{"label":"Economy","cmd":{"op":"ai_strategy","strategy":"economy"}},{"label":"Build","cmd":{"op":"build","city":"kyiv","building":"industry"}}]
	advisor.apply_decision("ukraine",actions,[0])
	advisor.apply_decision("ukraine",actions,[1])
	check(game.match_rules.seat_ai.ukraine.strategy == "economy" and server.executed.size() == 1,"the API can set national policy and route approved actions through normal server validation")
	server.ai_seats.clear()
	advisor.apply_decision("ukraine",actions,[1])
	check(server.executed.size() == 1,"a human reconnecting invalidates an outstanding external plan")
	server.ai_seats = ["ukraine"]
	game.match_rules.set_guard("ukraine",true)
	advisor.apply_decision("ukraine",actions,[1])
	check(server.executed.size() == 1,"Guard mode prevents external offensive/economic orders")
	check(advisor.interval >= 900 and advisor.daily_requests == 96 and advisor.daily_tokens == 100000,"free-plan requests are periodic and locally budgeted")
	advisor.used_requests = 50; advisor.used_tokens = 50000; advisor.budget_day = -1
	advisor._roll_day()
	check(advisor.used_requests == 0 and advisor.used_tokens == 0,"daily local quota resets on a new UTC day")
	check(CountryAI.CASUAL_MAX_ARMIES == 10 and CountryAI.CASUAL_ORDERS == 2 and CountryAI.CASUAL_REACTION * SimulationClock.REAL_SECONDS_PER_SIM_SECOND == 30,"below-medium fallback has a ten-army target, two-order limit and thirty-second reaction")
	check(ExternalCountryAI.URL == "https://api.groq.com/openai/v1/chat/completions","credentials are sent only to the fixed Groq HTTPS endpoint")
	var epoch: = Time.get_unix_time_from_system()
	server.seats = {"russia":{"user":"test-human","name":"Commander","last_seen":epoch},"ukraine":{"user":"","name":"","last_seen":0.0}}
	check(server.inactive_seconds == 172800,"automatic takeover defaults to two full real days")
	server._update_seats(epoch+172799)
	check("russia" not in server.ai_seats and "ukraine" in server.ai_seats,"human stays human before 48 hours; unclaimed countries remain AI")
	server._update_seats(epoch+172800)
	check("russia" in server.ai_seats,"AI takes the human seat at 48 real hours")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(server._seat_snapshot()))
	server.seats.clear(); server._restore_seats(saved)
	check(absf(server.seats.russia.last_seen-epoch) < 0.01,"last activity survives save/load as wall-clock time")
	server._update_seats(epoch+172801)
	check("russia" in server.ai_seats,"server downtime does not reset the inactivity countdown")
	server.mark_active("russia")
	check("russia" not in server.ai_seats,"returning activity immediately gives the player their country back")
	server._restore_seats({"match":server.match_id,"seats":{"russia":{"user":"old-player","name":"Commander"}}})
	check(server.seats.russia.last_seen >= epoch,"legacy saves receive a fresh 48-hour grace instead of immediate takeover")
	advisor.free(); game.match_rules.free(); game.free(); server.free()
	print("EXTERNAL AI FAILURES: ",failures)
	quit(1 if failures else 0)
