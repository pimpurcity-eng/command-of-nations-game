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
static func password_valid(password: String) -> bool:return password.length()>=12 and password.length()<=128
static func code_valid(code: String) -> bool:
	var regex:=RegEx.new();regex.compile("^[0-9]{6}$");return regex.search(code)!=null
static func username_valid(value: String) -> bool:
	var regex:=RegEx.new();regex.compile("^[A-Za-z0-9_]{3,24}$");return regex.search(value)!=null
func signup(email: String,password: String,commander: String) -> Dictionary:
	if not email_valid(email) or not password_valid(password) or not username_valid(commander):return failure("Enter a valid email, a 12–128 character password and a commander name (3–24 letters, numbers or underscores).")
	var result:=await request("/signup",{"email":email.strip_edges(),"password":password,"data":{"commander_name":commander}})
	# Even if the server is misconfigured to auto-confirm, this UI never silently logs in after signup.
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
	if not password_valid(password):return failure("Use a password with 12–128 characters.")
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
	access_token="";refresh_token="";user={};expires_at=0;recovery_pending=false;session_changed.emit()
func accept_session(data: Dictionary,recovery: bool) -> Dictionary:
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
func http(path: String,payload: Dictionary,method: int,bearer: String) -> Dictionary:
	var client:=HTTPRequest.new();client.timeout=20;add_child(client)
	var headers:=PackedStringArray(["Content-Type: application/json","apikey: "+public_key])
	if not bearer.is_empty():headers.append("Authorization: Bearer "+bearer)
	var error:=client.request(base_url+"/auth/v1"+path,headers,method,JSON.stringify(payload))
	if error!=OK:client.queue_free();return failure("Could not connect. Please try again.")
	var raw: Array=await client.request_completed;client.queue_free()
	if int(raw[0])!=HTTPRequest.RESULT_SUCCESS:return failure("Connection interrupted. Please try again.")
	var status:=int(raw[1]);var decoded: Variant=JSON.parse_string(raw[3].get_string_from_utf8())
	var data: Dictionary=decoded if decoded is Dictionary else {}
	if status>=200 and status<300:return {"ok":true,"data":data,"status":status}
	# Do not expose raw backend errors, account existence, tokens, or response bodies.
	if status==429:return failure("Too many attempts. Wait a moment and try again.",status)
	if str(data.get("error_code",""))=="email_not_confirmed":return failure("Confirm your email before signing in.",status)
	if status>=500:return failure("Account service is temporarily unavailable. Please try again.",status)
	return failure("Could not complete that request. Check your details or request a new code.",status)
