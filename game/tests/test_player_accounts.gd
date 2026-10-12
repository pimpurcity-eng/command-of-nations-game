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
	# Profiles, levels, results and deletion (migration 002).
	check(PlayerAuth.level_for(0)==1 and PlayerAuth.level_for(99)==1 and PlayerAuth.level_for(100)==2 and PlayerAuth.level_for(400)==3,"Levels follow 100*(n-1)^2 XP like the server")
	r=await auth.record_result(true,30)
	check(not r.ok and calls.size()==before,"Signed-out players cannot report results")
	auth.accept_session(session(),false)
	reply={"ok":true,"data":{"rows":[{"commander_name":"Tester","xp":450,"games_played":3,"wins":2,"losses":1}]}}
	r=await auth.load_profile()
	check(r.ok and calls[-1][0].begins_with("/rest/v1/player_profiles?") and calls[-1][2]==HTTPClient.METHOD_GET and calls[-1][3]=="test_access" and auth.profile.xp==450,"Profile loads own row with the player token")
	reply={"ok":true,"data":{"rows":[{"xp":575,"level":3,"games_played":4,"wins":3,"losses":1}]}}
	before=calls.size()
	r=await auth.record_result(true,25)
	check(not r.ok and calls.size()==before and auth.profile.xp==450,"Local wins cannot submit or award online XP")
	auth.accept_session(session(),false)
	check(auth.profile.xp==450,"Refreshing the same account preserves its own cached profile")
	var other:=session();other.user.id="other-player-id"
	auth.accept_session(other,false)
	check(auth.profile.is_empty(),"Switching accounts clears the previous commander's profile")
	auth.profile={"commander_name":"Other","xp":1000}
	auth.accept_session(other,true)
	check(auth.profile.is_empty(),"Entering password recovery clears cached player profile")
	auth.accept_session(session(),false)
	auth.transport=func(_path,_payload,_method,_bearer):
		auth.clear_session()
		return {"ok":true,"data":session()}
	r=await auth.refresh()
	check(not r.ok and not auth.signed_in(),"A delayed refresh cannot resurrect a signed-out session")
	auth.accept_session(session(),false)
	auth.transport=func(_path,_payload,_method,_bearer):
		auth.accept_session(other,false)
		return {"ok":true,"data":{"rows":[{"commander_name":"Previous","xp":9999}]}}
	r=await auth.load_profile()
	check(not r.ok and auth.profile.is_empty(),"An old profile response cannot overwrite the new account")
	auth.transport=mock
	auth.accept_session(session(),false);auth.profile={"commander_name":"Tester","xp":450}
	var panel:=AccountPanel.new();root.add_child(panel);panel.auth.queue_free();panel.auth=auth
	panel.build("profile")
	check(panel.fields.get_children().any(func(n): return n is ProgressBar) and panel.fields.get_children().any(func(n): return n is Label and n.text=="LEVEL 3"),"Profile shows level and XP bar")
	panel.build("delete");panel.inputs.confirm_delete.text="delete";before=calls.size();await panel.delete_account()
	check(calls.size()==before and auth.signed_in(),"Deletion needs DELETE typed exactly")
	reply={"ok":true,"data":{}};panel.inputs.confirm_delete.text="DELETE";await panel.delete_account()
	check(calls[-1][0]=="/rest/v1/rpc/delete_my_account" and not auth.signed_in() and auth.profile.is_empty() and panel.mode=="login","Deleting the account calls the server and signs out")
	panel.queue_free()
	auth=PlayerAuth.new();root.add_child(auth);auth.transport=mock;auth.base_url="https://example.supabase.co";auth.public_key="sb_publishable_example"
	panel=AccountPanel.new();root.add_child(panel);panel.open()
	check(panel.mode=="login" and panel.overlay.visible,"Native account panel opens without configuration")
	panel.build("signup");check(panel.inputs.has("confirm") and panel.inputs.password.secret,"Registration has masked password confirmation")
	panel.build("recovery_code");check(panel.inputs.has("code"),"Recovery screen accepts email codes")
	panel.queue_free();auth.queue_free()
	print("ACCOUNT CHECKS ",checks," failures=",failures)
	quit(1 if failures else 0)
