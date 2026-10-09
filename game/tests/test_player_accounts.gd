extends SceneTree
var failures:=0
var checks:=0
var calls: Array=[]
var reply: Dictionary={"ok":true,"data":{}}
func _initialize() -> void:call_deferred("run")
func check(condition: bool,message: String) -> void:
	checks+=1
	if not condition:failures+=1;push_error(message)
	else:print("PASS ",message)
func mock(path: String,payload: Dictionary,method: int,bearer: String) -> Dictionary:
	calls.append([path,payload,method,bearer]);return reply.duplicate(true)
func session(confirmed: bool=true) -> Dictionary:
	return {"access_token":"test_access","refresh_token":"test_refresh","expires_in":3600,"user":{"id":"test-player-id","email":"tester@example.org","email_confirmed_at":"2026-10-09T00:00:00Z" if confirmed else "","user_metadata":{"commander_name":"Tester"}}}
func run() -> void:
	var auth:=PlayerAuth.new();root.add_child(auth);auth.transport=mock
	var r:=await auth.login("tester@example.org","password")
	check(not r.ok and calls.is_empty(),"Unconfigured accounts fail closed without a request")
	auth.base_url="http://insecure.example.org";auth.public_key="sb_publishable_example"
	check(not auth.configured(),"Reject insecure account endpoints")
	auth.base_url="https://example.supabase.co";auth.public_key="sb_secret_example"
	check(not auth.configured(),"Reject server secret keys in the client")
	auth.public_key="sb_publishable_example"
	r=await auth.signup("bad email","short","bad name")
	check(not r.ok and calls.is_empty(),"Invalid registration cannot reach backend")
	reply={"ok":true,"data":{}}
	r=await auth.signup("tester@example.org","strongpassword12","Tester")
	check(r.ok and calls[-1][0]=="/signup" and calls[-1][1].data.commander_name=="Tester","Registration sends commander metadata")
	check(not auth.signed_in(),"Registration waits for confirmation")
	reply={"ok":true,"data":session(false)}
	r=await auth.login("tester@example.org","strongpassword12")
	check(not r.ok and not auth.signed_in(),"Unconfirmed email cannot become a player session")
	var missing_confirmation:=session();missing_confirmation.user.email_confirmed_at=null
	r=auth.accept_session(missing_confirmation,false)
	check(not r.ok and not auth.signed_in(),"Null confirmation timestamps cannot pass validation")
	reply={"ok":true,"data":session()}
	r=await auth.verify("tester@example.org","123456")
	check(r.ok and auth.signed_in() and calls[-1][1].type=="email","Email code verifies a normal player session")
	auth.expires_at=0
	check(not auth.signed_in(),"Expired token is not accepted locally")
	r=await auth.refresh()
	check(r.ok and auth.signed_in() and calls[-1][0]=="/token?grant_type=refresh_token","Session refresh uses the refresh grant")
	r=await auth.verify("tester@example.org","123456",true)
	check(r.ok and auth.recovery_pending and not auth.signed_in(),"Recovery session is blocked from normal login")
	reply={"ok":true,"data":{}}
	r=await auth.reset_password("updatedpassword12")
	check(r.ok and calls[-2][0]=="/user" and calls[-2][2]==HTTPClient.METHOD_PUT and calls[-2][3]=="test_access","Password update requires recovery bearer token")
	check(not auth.recovery_pending and auth.access_token.is_empty(),"Reset clears session and requires a fresh login")
	r=await auth.reset_password("updatedpassword12")
	check(not r.ok,"Password update without verified recovery is blocked")
	r=await auth.verify("tester@example.org","123abc")
	check(not r.ok,"Malformed email codes are rejected")
	auth.accept_session(session(),false);reply=PlayerAuth.failure("Offline")
	r=await auth.logout()
	check(not r.ok and auth.access_token.is_empty(),"Offline logout still clears local credentials")
	auth.busy=true;var before:=calls.size();r=await auth.login("tester@example.org","password")
	check(not r.ok and calls.size()==before,"Concurrent account requests are rejected")
	auth.busy=false
	var panel:=AccountPanel.new();root.add_child(panel);panel.open()
	check(panel.mode=="login" and panel.overlay.visible,"Native account panel opens without configuration")
	panel.build("signup");check(panel.inputs.has("confirm") and panel.inputs.password.secret,"Registration has masked password confirmation")
	panel.build("recovery_code");check(panel.inputs.has("code"),"Recovery screen accepts email codes")
	panel.queue_free();auth.queue_free()
	print("ACCOUNT CHECKS ",checks," failures=",failures)
	quit(1 if failures else 0)
