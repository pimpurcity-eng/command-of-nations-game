class_name PlayerAuth
extends Node
## HTTPS-only Supabase Auth adapter. Passwords and tokens are never written to disk.
## A recovery session is deliberately excluded from normal player authentication.
signal session_changed
var base_url := ""
var public_key := ""
var access_token := ""
var refresh_token := ""
var user: Dictionary = {}
var profile: Dictionary = {}
var expires_at := 0.0
var recovery_pending := false
var busy := false
var refresh_retry_at := 0.0
var transport: Callable # Test injection only; production uses HTTPRequest.
func _ready() -> void:
	var config := ConfigFile.new()
	if config.load("res://config/accounts.cfg")==OK:
		base_url=str(config.get_value("supabase","url",""))
		public_key=str(config.get_value("supabase","publishable_key",""))
	var env_url:=OS.get_environment("CON_ACCOUNTS_URL")
	var env_key:=OS.get_environment("CON_ACCOUNTS_PUBLIC_KEY")
	if not env_url.is_empty():base_url=env_url
	if not env_key.is_empty():public_key=env_key
	base_url=base_url.trim_suffix("/")
func configured() -> bool:
	return base_url.begins_with("https://") and public_key.begins_with("sb_publishable_")
func signed_in() -> bool:
	return not recovery_pending and not access_token.is_empty() and float(Time.get_unix_time_from_system())<expires_at and confirmed(user)
static func confirmed(candidate: Dictionary) -> bool:
	var stamp: Variant=candidate.get("email_confirmed_at")
	return stamp is String and not stamp.is_empty()
func _process(_delta: float) -> void:
	var now:=float(Time.get_unix_time_from_system())
	if not busy and not refresh_token.is_empty() and now>=expires_at-60 and now>=refresh_retry_at:
		refresh_retry_at=now+30
		await refresh()
static func email_valid(email: String) -> bool:
	var regex:=RegEx.new();regex.compile("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$")
	return email.length()<=254 and regex.search(email)!=null
static func password_valid(password: String) -> bool:return password.length()>=8 and password.length()<=128
static func code_valid(code: String) -> bool:
	var regex:=RegEx.new();regex.compile("^[0-9]{6}$");return regex.search(code)!=null
static func username_valid(value: String) -> bool:
	var regex:=RegEx.new();regex.compile("^[A-Za-z0-9_]{3,24}$");return regex.search(value)!=null
## Owner 2026-10-14 ("Sir Matthew" was refused): spaces become underscores, as the account
## database only accepts letters, numbers and underscores.
static func commander_name(value: String) -> String:
	var cleaned:=value.strip_edges()
	while cleaned.contains("  "):cleaned=cleaned.replace("  "," ")
	return cleaned.replace(" ","_")
## Says exactly which field is wrong (owner: the combined message did not say what to fix).
static func signup_problem(email: String,password: String,commander: String) -> String:
	if not email_valid(email):return "That email address does not look right."
	if not password_valid(password):return "The password needs at least 8 characters."
	var name:=commander_name(commander)
	if name.length()<3:return "The commander name needs at least 3 letters."
	if name.length()>24:return "The commander name can have at most 24 letters."
	if not username_valid(name):return "The commander name can only use letters, numbers and spaces."
	return ""
func signup(email: String,password: String,commander: String) -> Dictionary:
	var problem:=signup_problem(email,password,commander)
	if not problem.is_empty():return failure(problem)
	commander=commander_name(commander)
	var result:=await request("/signup",{"email":email.strip_edges(),"password":password,"data":{"commander_name":commander}})
	# Even if the server is misconfigured to auto-confirm, this UI never silently logs in after signup.
	return result
## Sign in with Google (owner 2026-10-14). The website sends the player to Google through the
## account service and comes back with the session in the address (#access_token=...), which
## finish_google_from_url() reads once and wipes from the address bar. The app keeps email
## sign-in until it has a return link of its own.
static func google_available() -> bool:return OS.has_feature("web")
## True once the owner has switched Google on in the account service (checked, never assumed).
var google_enabled:=false
func check_google() -> bool:
	if not configured() or not google_available():return false
	var result:=await request("/settings",{},HTTPClient.METHOD_GET)
	google_enabled=result.ok and bool(result.data.get("external",{}).get("google",false))
	return google_enabled
func google_url(return_to: String) -> String:
	return base_url+"/auth/v1/authorize?provider=google&redirect_to="+return_to.uri_encode()
func google_sign_in() -> Dictionary:
	if not configured():return failure("Online accounts are being connected. You can keep playing offline.")
	if not google_available():return failure("Google sign-in works on the website for now. In the app, use email.")
	var here:=str(JavaScriptBridge.eval("window.location.origin + window.location.pathname"))
	JavaScriptBridge.eval("window.location.assign("+JSON.stringify(google_url(here))+")")
	return {"ok":true,"data":{},"message":"Opening Google…"}
static func address_values(fragment: String) -> Dictionary:
	var values: Dictionary={}
	for pair in fragment.trim_prefix("#").split("&",false):
		var parts:=pair.split("=",true,1)
		if parts.size()==2:values[parts[0].uri_decode()]=parts[1].replace("+"," ").uri_decode()
	return values
func finish_google_from_url() -> Dictionary:
	if not OS.has_feature("web"):return failure("Not a browser.")
	var fragment:=str(JavaScriptBridge.eval("window.location.hash"))
	var values:=address_values(fragment)
	if not values.has("access_token") and not values.has("error"):return failure("No Google sign-in in the address.")
	# Never leave tokens in the address bar or browser history.
	JavaScriptBridge.eval("history.replaceState(null, '', window.location.pathname + window.location.search)")
	return await accept_google(values)
func accept_google(values: Dictionary) -> Dictionary:
	if values.has("error"):return failure("Google sign-in was cancelled or refused.")
	var token:=str(values.get("access_token",""))
	var who:=await request("/user",{},HTTPClient.METHOD_GET,token)
	if not who.ok:return failure("Google sign-in could not be completed. Please try again.")
	var result:=accept_session({"access_token":token,"refresh_token":values.get("refresh_token",""),"expires_in":float(values.get("expires_in",3600)),"user":who.data},false)
	if result.ok:await load_profile()
	return result
func login(email: String,password: String) -> Dictionary:
	if not email_valid(email) or password.is_empty():return failure("Enter your email and password.")
	var result:=await request("/token?grant_type=password",{"email":email.strip_edges(),"password":password})
	if result.ok:return accept_session(result.data,false)
	return result
func verify(email: String,code: String,recovery: bool=false) -> Dictionary:
	if not email_valid(email) or not code_valid(code):return failure("Enter the six-digit code from your email.")
	var result:=await request("/verify",{"email":email.strip_edges(),"token":code,"type":"recovery" if recovery else "email"})
	if result.ok:return accept_session(result.data,recovery)
	return result
func resend(email: String,recovery: bool=false) -> Dictionary:
	if not email_valid(email):return failure("Enter a valid email address.")
	return await request("/recover" if recovery else "/resend",{"email":email.strip_edges()} if recovery else {"email":email.strip_edges(),"type":"signup"})
func reset_password(password: String) -> Dictionary:
	if not recovery_pending or access_token.is_empty():return failure("Verify the password-reset code first.")
	if not password_valid(password):return failure("Use a password with 8–128 characters.")
	var result:=await request("/user",{"password":password},HTTPClient.METHOD_PUT,access_token)
	if result.ok:
		# Close the recovery session, then require a normal login using the new password.
		await logout()
	return result
func refresh() -> Dictionary:
	if refresh_token.is_empty():return failure("Please sign in again.")
	var result:=await request("/token?grant_type=refresh_token",{"refresh_token":refresh_token})
	if result.ok:return accept_session(result.data,recovery_pending)
	if int(result.get("status",0)) in [400,401,403]:clear_session()
	return result
func logout() -> Dictionary:
	var token:=access_token
	clear_session() # Always clear local access, including when offline.
	if token.is_empty():return {"ok":true,"data":{}}
	return await request("/logout?scope=local",{},HTTPClient.METHOD_POST,token)
func clear_session() -> void:
	access_token="";refresh_token="";user={};profile={};expires_at=0;recovery_pending=false;session_changed.emit()
## Commander level from XP: level n needs 100*(n-1)^2 XP. Same formula as the server
## (backend/migrations/002_profiles_levels_deletion.sql, commander_level).
const PROFILE_COLUMNS: = "commander_name,xp,games_played,wins,losses,units_destroyed,units_lost,cities_captured,play_minutes,best_streak,current_streak"
## Kills per loss, as shown on the profile (a commander with no losses shows their kills).
static func kd_ratio(stats: Dictionary) -> float:
	return float(stats.get("units_destroyed",0))/maxf(float(stats.get("units_lost",0)),1.0)
static func win_rate(stats: Dictionary) -> float:
	return float(stats.get("wins",0))/maxf(float(stats.get("games_played",0)),1.0)
# ---------------------------------------------------------------- alliances (migration 004)
func alliance_call(function: String,payload: Dictionary={}) -> Dictionary:
	if not signed_in():return failure("Sign in to use alliances.")
	var result:=await request("/rest/v1/rpc/"+function,payload,HTTPClient.METHOD_POST,access_token)
	if not result.ok and int(result.get("status",0)) == 404:return failure("Alliances are being switched on - try again soon.",404)
	return result
func my_alliance() -> Dictionary:return await alliance_call("my_alliance")
func alliance_directory(search: String="") -> Dictionary:return await alliance_call("alliance_directory",{"search":search,"how_many":30})
func create_alliance(name: String,tag: String,motto: String,open: bool) -> Dictionary:return await alliance_call("create_alliance",{"alliance_name":name,"alliance_tag":tag,"alliance_motto":motto,"is_open":open})
func join_alliance(id: String) -> Dictionary:return await alliance_call("join_alliance",{"target":id})
func leave_alliance() -> Dictionary:return await alliance_call("leave_alliance")
func answer_alliance_request(id: int,accept: bool) -> Dictionary:return await alliance_call("answer_alliance_request",{"request_id":id,"accept":accept})
func set_alliance_role(member: int,role: String) -> Dictionary:return await alliance_call("set_alliance_role",{"member_id":member,"new_role":role})
func remove_alliance_member(member: int) -> Dictionary:return await alliance_call("remove_alliance_member",{"member_id":member})
func post_alliance_message(text: String) -> Dictionary:return await alliance_call("post_alliance_message",{"message":text})
func post_alliance_operation(code: String,side: String,note: String) -> Dictionary:return await alliance_call("post_alliance_operation",{"code":code,"play_side":side,"operation_note":note})
static func level_for(xp: int) -> int:return int(floor(sqrt(maxf(xp,0)/100.0)))+1
static func xp_for_level(level: int) -> int:return 100*(level-1)*(level-1)
func load_profile() -> Dictionary:
	if not signed_in():return failure("Sign in first.")
	var profile_user := str(user.get("id",""))
	# Full statistics (migration 004); older databases only have the first five columns.
	var result:=await request("/rest/v1/player_profiles?select="+PROFILE_COLUMNS+"&id=eq."+str(user.id).uri_encode(),{},HTTPClient.METHOD_GET,access_token)
	if not result.ok:result=await request("/rest/v1/player_profiles?select=commander_name,xp,games_played,wins,losses&id=eq."+str(user.id).uri_encode(),{},HTTPClient.METHOD_GET,access_token)
	if not result.ok:return result
	var rows: Variant=result.data.get("rows",[])
	if not (rows is Array) or rows.is_empty():return failure("Profile not found yet. Try again in a moment.")
	if not signed_in() or str(user.get("id","")) != profile_user: return failure("Account changed.")
	profile=rows[0];return {"ok":true,"data":profile}
## Single-player result against the AI. The server rate-limits and caps the XP; when online
## matches arrive, the match server records results instead.
func record_result(won: bool,minutes: int,destroyed: int=0,lost: int=0,provinces: int=0) -> Dictionary:
	if not signed_in():return failure("Sign in to earn XP.")
	# Battle numbers go with the result (migration 004); without it the plain result is kept.
	var result:=await request("/rest/v1/rpc/record_match_stats",{"won":won,"minutes":maxi(minutes,0),"destroyed":maxi(destroyed,0),"lost":maxi(lost,0),"cities":maxi(provinces,0)},HTTPClient.METHOD_POST,access_token)
	if not result.ok and int(result.get("status",0)) == 404:
		result=await request("/rest/v1/rpc/record_match_result",{"won":won,"minutes":maxi(minutes,0)},HTTPClient.METHOD_POST,access_token)
	if not result.ok:return result
	var rows: Variant=result.data.get("rows",[])
	if rows is Array and not rows.is_empty():profile.merge(rows[0],true)
	return {"ok":true,"data":profile}
## Achievements go to the account (server accepts known ids once each, migration 003).
func unlock_achievement(code: String) -> Dictionary:
	if not signed_in():return failure("Sign in first.")
	return await request("/rest/v1/rpc/unlock_achievement",{"code":code},HTTPClient.METHOD_POST,access_token)
## The public leaderboard: [{place, commander_name, level, xp, wins}].
## metric: xp, wins, destroyed, cities, streak (migration 004); falls back to the XP board.
func leaderboard(how_many: int=50,metric: String="xp") -> Dictionary:
	if not signed_in():return failure("Sign in to see the leaderboard.")
	var result:=await request("/rest/v1/rpc/top_commanders_by",{"metric":metric,"how_many":how_many},HTTPClient.METHOD_POST,access_token)
	if not result.ok and int(result.get("status",0)) == 404:
		result=await request("/rest/v1/rpc/top_commanders",{"how_many":how_many},HTTPClient.METHOD_POST,access_token)
	if not result.ok:return result
	return {"ok":true,"data":{"rows":result.data.get("rows",[])}}
## Permanently deletes the account and everything stored with it (Google Play requirement).
func delete_account() -> Dictionary:
	if not signed_in():return failure("Sign in first.")
	var result:=await request("/rest/v1/rpc/delete_my_account",{},HTTPClient.METHOD_POST,access_token)
	if result.ok:clear_session()
	return result
func accept_session(data: Dictionary,recovery: bool) -> Dictionary:
	if str(data.get("user",{}).get("id","")) != str(user.get("id","")): profile.clear()
	var raw_user: Variant=data.get("user",{})
	var candidate: Dictionary=raw_user if raw_user is Dictionary else {}
	if str(data.get("access_token","")).is_empty() or str(candidate.get("id","")).is_empty() or not confirmed(candidate):
		clear_session();return failure("Confirm your email before signing in.")
	access_token=str(data.access_token);refresh_token=str(data.get("refresh_token",""));user=candidate
	expires_at=float(Time.get_unix_time_from_system())+float(data.get("expires_in",3600));recovery_pending=recovery
	session_changed.emit();return {"ok":true,"data":candidate}
static func failure(message: String,status: int=0) -> Dictionary:return {"ok":false,"message":message,"status":status,"data":{}}
func request(path: String,payload: Dictionary,method: int=HTTPClient.METHOD_POST,bearer: String="") -> Dictionary:
	if busy:return failure("Please wait for the current request.")
	if not configured():return failure("Online accounts are being connected. You can keep playing offline.")
	busy=true
	var response: Dictionary
	if transport.is_valid():response=await transport.call(path,payload,method,bearer)
	else:response=await http(path,payload,method,bearer)
	busy=false
	return response
func endpoint(path: String) -> String:
	return base_url+path if path.begins_with("/rest/v1/") else base_url+"/auth/v1"+path
static func response_data(decoded: Variant) -> Dictionary:
	if decoded is Dictionary:return decoded
	if decoded is Array:return {"rows":decoded}
	if decoded is String or decoded is float or decoded is bool:return {"value":decoded}
	return {}
func http(path: String,payload: Dictionary,method: int,bearer: String) -> Dictionary:
	var client:=HTTPRequest.new();client.timeout=20;add_child(client)
	var headers:=PackedStringArray(["Content-Type: application/json","apikey: "+public_key])
	if not bearer.is_empty():headers.append("Authorization: Bearer "+bearer)
	var error:=client.request(endpoint(path),headers,method,JSON.stringify(payload))
	if error!=OK:client.queue_free();return failure("Could not connect. Please try again.")
	var raw: Array=await client.request_completed;client.queue_free()
	if int(raw[0])!=HTTPRequest.RESULT_SUCCESS:return failure("Connection interrupted. Please try again.")
	var status:=int(raw[1]);var decoded: Variant=JSON.parse_string(raw[3].get_string_from_utf8())
	var data: Dictionary=response_data(decoded)
	if status>=200 and status<300:return {"ok":true,"data":data,"status":status}
	# Do not expose raw backend errors, account existence, tokens, or response bodies.
	if status==429:return failure("Too many attempts. Wait a moment and try again.",status)
	if str(data.get("error_code",""))=="email_not_confirmed":return failure("Confirm your email before signing in.",status)
	if status>=500:return failure("Account service is temporarily unavailable. Please try again.",status)
	return failure("Could not complete that request. Check your details or request a new code.",status)
