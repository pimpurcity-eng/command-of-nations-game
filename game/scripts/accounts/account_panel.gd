class_name AccountPanel
extends CanvasLayer
@export var preview_open := false
## Native portrait-friendly account sheet, optional while the game remains offline.
var auth: PlayerAuth
var overlay: Control
var fields: VBoxContainer
var status: Label
var mode := "login"
var email := ""
var inputs: Dictionary = {}
var cooldown_until := 0
var working := false
func _ready() -> void:
	layer=30;auth=PlayerAuth.new();add_child(auth)
	overlay=Control.new();overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(overlay)
	var shade:=ColorRect.new();shade.color=Color(0.02,0.04,0.07,0.96);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.add_child(shade)
	var scroll:=ScrollContainer.new();scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);scroll.offset_left=32;scroll.offset_right=-32;scroll.offset_top=60;scroll.offset_bottom=-40;overlay.add_child(scroll)
	fields=VBoxContainer.new();fields.size_flags_horizontal=Control.SIZE_EXPAND_FILL;fields.add_theme_constant_override("separation",18);scroll.add_child(fields)
	var theme:=Theme.new();theme.default_font=load("res://assets/fonts/RobotoCondensed.ttf");theme.default_font_size=28
	var style:=StyleBoxFlat.new();style.bg_color=Color("172a35");style.set_corner_radius_all(18);style.content_margin_left=20;style.content_margin_right=20;style.content_margin_top=16;style.content_margin_bottom=16
	for state in ["normal","hover","pressed","disabled"]:theme.set_stylebox(state,"Button",style)
	theme.set_stylebox("normal","LineEdit",style);theme.set_color("font_color","Button",Color("f0dec1"));fields.theme=theme
	build("login");overlay.hide()
	# Back from Google in the phone's browser (Android): show the account, or what went wrong.
	auth.google_finished.connect(func(result: Dictionary):
		working=false
		overlay.show()
		if result.ok:build("profile")
		else:
			if mode!="login":build("login")
			status.text=str(result.message))
	if preview_open:open()
func open() -> void:
	build("profile" if auth.signed_in() else "new_password" if auth.recovery_pending else "login");overlay.show()
	# Add the Google button as soon as the account service says Google is switched on.
	if PlayerAuth.google_available() and not auth.google_enabled and not working:
		if await auth.check_google() and mode in ["login","signup"] and overlay.visible:build(mode)
func label_text(text: String,size: int=28) -> Label:
	var item:=Label.new();item.text=text;item.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;item.add_theme_font_size_override("font_size",size);fields.add_child(item);return item
func input(key: String,placeholder: String,secret: bool=false) -> void:
	var field:=LineEdit.new();field.placeholder_text=placeholder;field.secret=secret;field.custom_minimum_size.y=64
	field.max_length=128 if secret else 254;field.virtual_keyboard_type=LineEdit.KEYBOARD_TYPE_PASSWORD if secret else LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS if key=="email" else LineEdit.KEYBOARD_TYPE_NUMBER if key=="code" else LineEdit.KEYBOARD_TYPE_DEFAULT
	if key=="email":field.text=email
	inputs[key]=field;fields.add_child(field)
	# Owner 2026-10-14: "can you have a show password on there?"
	if secret and (key=="confirm" or mode=="login"):  # under the last password box
		# Owner 2026-10-15: the small switch was not visible; a full-size button like the others.
		var reveal:=Button.new();reveal.text="Show password";reveal.toggle_mode=true;reveal.custom_minimum_size.y=64
		reveal.toggled.connect(func(shown: bool):
			reveal.text="Hide password" if shown else "Show password"
			for name in ["password","confirm"]:
				if inputs.has(name):inputs[name].secret=not shown)
		fields.add_child(reveal)
## Owner 2026-10-16 ("or give it a frame ... for him"): a Premium commander's name and badge sit
## inside a gold frame on the profile.
func premium_frame(items: Array) -> PanelContainer:
	var frame:=PanelContainer.new();frame.name="PremiumFrame"
	var style:=StyleBoxFlat.new();style.bg_color=Color(0.79,0.64,0.29,0.12);style.border_color=Color("e9c46a")
	style.set_border_width_all(4);style.set_corner_radius_all(14);style.set_content_margin_all(16)
	style.shadow_color=Color(0.91,0.77,0.42,0.35);style.shadow_size=8
	frame.add_theme_stylebox_override("panel",style)
	var inside:=VBoxContainer.new();inside.add_theme_constant_override("separation",6);frame.add_child(inside)
	fields.add_child(frame);fields.move_child(frame,(items[0] as Control).get_index())
	for item in items:fields.remove_child(item);inside.add_child(item)
	return frame
func button(text: String,action: Callable) -> void:
	var item:=Button.new();item.text=text;item.custom_minimum_size.y=64;item.pressed.connect(func():
		if not working:action.call())
	fields.add_child(item)
func build(page: String) -> void:
	mode=page;inputs.clear()
	for item in fields.get_children():fields.remove_child(item);item.queue_free()
	label_text("WARFRONT MANDATE: WW3",24).modulate=Color("c9ad73")
	var titles: Dictionary={"login":"Welcome back, Commander","signup":"Create your commander account","check_email":"Check your email","recover":"Reset your password","recovery_code":"Check your email","new_password":"Choose a new password","profile":"Commander account","delete":"Delete account","leaderboard":"Top commanders","achievements":"Achievements","alliance":"Alliance","alliance_browse":"Find an alliance","alliance_create":"Found an alliance"}
	label_text(titles[page],40)
	if page=="profile":
		var commander_label:=label_text(str(auth.user.get("user_metadata",{}).get("commander_name","Commander")),34)
		# Owner 2026-10-16: Premium badge and gold commander name while the membership is active.
		if PlayerPremium.is_premium():
			commander_label.modulate=Color("e9c46a")
			var badge:=label_text("★ PREMIUM COMMANDER"+((" · until "+PlayerPremium.until_text()) if PlayerPremium.until_text()!="" else ""),26)
			badge.modulate=Color("e9c46a")
			premium_frame([commander_label,badge])
		if auth.profile.has("xp") and PlayerPremium.premium_user!=str(auth.user.get("id","")):load_premium.call_deferred()
		label_text(str(auth.user.get("email","")))
		if auth.profile.has("xp"):
			var xp:=int(auth.profile.xp);var level:=PlayerAuth.level_for(xp)
			var low:=PlayerAuth.xp_for_level(level);var high:=PlayerAuth.xp_for_level(level+1)
			label_text("LEVEL %d · %s" % [level,Achievements.rank(level).to_upper()],40).modulate=Color("e9c46a")
			var bar:=ProgressBar.new();bar.min_value=low;bar.max_value=high;bar.value=xp;bar.show_percentage=false;bar.custom_minimum_size.y=22;fields.add_child(bar)
			label_text("%d / %d XP to level %d" % [xp,high,level+1],24)
			# Owner 2026-10-15: "the stats have their KD, kill and death ... go a little deeper".
			var stats: Dictionary=auth.profile
			label_text("SERVICE RECORD",30).modulate=Color("c9ad73")
			label_text("Games %d · Wins %d · Losses %d · Win rate %d%%" % [int(stats.get("games_played",0)),int(stats.get("wins",0)),int(stats.get("losses",0)),roundi(PlayerAuth.win_rate(stats)*100.0)],26)
			if stats.has("units_destroyed"):
				label_text("K/D %.2f · Enemy units destroyed %d · Units lost %d" % [PlayerAuth.kd_ratio(stats),int(stats.get("units_destroyed",0)),int(stats.get("units_lost",0))],26)
				label_text("Provinces captured %d · Win streak %d (best %d)" % [int(stats.get("cities_captured",0)),int(stats.get("current_streak",0)),int(stats.get("best_streak",0))],26)
				var hours:=int(stats.get("play_minutes",0))/60
				label_text("Time in command %dh %02dm" % [hours,int(stats.get("play_minutes",0))%60],26)
		else:
			label_text("Loading your level and stats…",24)
			load_profile.call_deferred()
		label_text("Win a campaign for 100 XP, finish one for 25 XP, plus up to 50 XP for its length.",22)
		button("★ Premium membership",func():PremiumPanel.show_over(self,auth))
		button("Top commanders",func():build("leaderboard"))
		button("Alliance",func():alliance=null;build("alliance"))
		button("Achievements and medals",func():build("achievements"))
		button("Sign out",func():
			working=true;await auth.logout();working=false;build("login"))
		button("Delete account",func():build("delete"))
	elif page=="leaderboard":
		var tabs:=HBoxContainer.new();tabs.add_theme_constant_override("separation",8);fields.add_child(tabs)
		for entry in [["xp","XP"],["wins","Wins"],["destroyed","Kills"],["cities","Provinces"],["streak","Streak"]]:
			var tab:=Button.new();tab.text=entry[1];tab.toggle_mode=true;tab.button_pressed=board_metric==entry[0];tab.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tab.add_theme_font_size_override("font_size",22)
			tab.pressed.connect(func():board_metric=entry[0];leaderboard_rows=[];build("leaderboard"))
			tabs.add_child(tab)
		if leaderboard_rows.is_empty():
			label_text("Loading the top commanders…",24)
			load_leaderboard.call_deferred()
		for row in leaderboard_rows:
			var tag:=(" ["+str(row.alliance_tag)+"]") if row.get("alliance_tag")!=null and str(row.get("alliance_tag",""))!="" else ""
			var extra: String={"wins":"%d wins" % int(row.get("wins",0)),"destroyed":"%d kills" % int(row.get("units_destroyed",0)),"cities":"%d provinces" % int(row.get("cities_captured",0)),"streak":"best streak %d" % int(row.get("best_streak",0))}.get(board_metric,"%d XP · %d wins" % [int(row.get("xp",0)),int(row.get("wins",0))])
			label_text("%d. %s%s · level %d %s · %s" % [int(row.place),str(row.commander_name),tag,int(row.level),Achievements.rank(int(row.level)),extra],26)
		button("Back",func():leaderboard_rows=[];build("profile"))
	elif page=="alliance":
		_alliance_page()
	elif page=="alliance_browse":
		input("search","Search by name or tag")
		button("Search",func():directory=[];load_directory(value("search")))
		if directory.is_empty():
			label_text("Loading alliances…",24)
			load_directory.call_deferred("")
		for entry in directory:
			label_text("%d. [%s] %s · %d members · %d XP · %d wins%s" % [int(entry.place),str(entry.tag),str(entry.name),int(entry.members),int(entry.xp),int(entry.wins)," · open" if entry.open else " · by request"],26)
			if str(entry.motto)!="":label_text("    \"%s\"" % str(entry.motto),22).modulate=Color("a9b4bb")
			var id:=str(entry.alliance_id)
			button(("Join " if entry.open else "Request to join ")+str(entry.tag),func():
				working=true;var result:=await auth.join_alliance(id);working=false
				if result.ok:status.text="Joined!" if str(result.data.get("value",""))=="joined" else "Request sent - an officer will answer.";alliance=null;build("alliance")
				else:status.text=result.message)
		button("Back",func():build("alliance"))
	elif page=="alliance_create":
		input("alliance_name","Alliance name (3-28 letters)")
		input("alliance_tag","Tag (2-4 letters, e.g. WFM)")
		input("alliance_motto","Motto (optional)")
		var open_switch:=CheckButton.new();open_switch.text="Anyone can join (off: by request)";open_switch.button_pressed=true;fields.add_child(open_switch)
		button("Found the alliance",func():
			working=true;var result:=await auth.create_alliance(value("alliance_name").strip_edges(),value("alliance_tag").strip_edges().to_upper(),value("alliance_motto").strip_edges(),open_switch.button_pressed);working=false
			if result.ok:alliance=null;build("alliance")
			else:status.text=result.message)
		button("Back",func():build("alliance"))
	elif page=="achievements":
		var progress:=Achievements.new();progress.load_saved()
		label_text("%d of %d achievements" % [progress.unlocked.size(),Achievements.LIST.size()],30)
		for id in Achievements.LIST:
			label_text(("✔ " if progress.unlocked.has(id) else "· ")+Achievements.LIST[id].name+" — "+Achievements.LIST[id].text,24)
		label_text("MEDALS",30)
		for id in Achievements.MEDALS:
			label_text("%s ×%d — %s" % [Achievements.MEDALS[id].name,int(progress.medals.get(id,0)),Achievements.MEDALS[id].text],24)
		button("Back",func():build("profile" if auth.signed_in() else "login"))
	elif page=="delete":
		label_text("This permanently deletes your commander account, level, XP and stats. It cannot be undone. Your offline campaign on this phone is kept.",26)
		input("confirm_delete","Type DELETE to confirm")
		button("Delete my account forever",delete_account)
		button("Keep my account",func():build("profile"))
	else:
		# Owner 2026-10-14: "add a sign in with Google"; 2026-10-16: in the Android app too.
		if page in ["login","signup"] and PlayerAuth.google_available() and auth.google_enabled:
			button("Sign in with Google",func():
				status.text="Opening Google…";working=true
				var result:=await auth.google_sign_in();working=false
				status.text=str(result.get("message","")))
			label_text("or use your email",22)
		if page in ["login","signup","recover"]:input("email","Email address")
		if page=="signup":input("commander","Commander name")
		if page in ["login","signup","new_password"]:input("password","Password (8+ characters)" if page!="login" else "Password",true)
		if page in ["signup","new_password"]:input("confirm","Repeat password",true)
		if page=="recovery_code":
			label_text("Enter the six-digit code sent to "+email+".",24);input("code","Six-digit email code")
		if page=="check_email":
			# Owner 2026-10-16: no code box. Only shown while the account service still asks
			# new players to confirm their email (a setting of the account service).
			label_text("We sent a link to "+email+". Tap \"Confirm\" in that email, then come back here and tap \"Sign me in\".",26)
			label_text("No email? Check the spam folder, or send it again.",22)
			button("Sign me in",sign_in_after_link)
			button("Send the email again",resend_code)
		else:
			button({"login":"Sign in","signup":"Create account","recover":"Send reset code","recovery_code":"Verify reset code","new_password":"Save new password"}[page],submit)
		if page=="login":
			button("Create an account",func():remember_email();build("signup"))
			button("Achievements and medals",func():build("achievements"))
			button("Forgot password?",func():remember_email();build("recover"))
		elif page=="recovery_code":button("Send another code",resend_code)
		if page!="login":button("Back to sign in",func():auth.clear_session();build("login"))
	status=label_text("",24)
	if not auth.configured():status.text="Online accounts are being connected. Offline play is available."
	button("Back to game",func():overlay.hide())
## Kept in memory only (never saved) so "Sign me in" can sign in after the email link.
var signup_password:=""
func sign_in_after_link() -> void:
	if signup_password.is_empty():build("login");status.text="Your email is confirmed? Sign in with your password.";return
	working=true;status.text="Signing in…"
	var result:=await auth.login(email,signup_password);working=false
	if result.ok:
		signup_password="";build("profile")
	else:status.text="Not confirmed yet - tap the link in the email first, then try again." if "Confirm your email" in str(result.message) else str(result.message)
var leaderboard_rows: Array = []
var board_metric:="xp"
# ---------------------------------------------------------------- alliances
## Owner 2026-10-15: "create an alliance outside of the matches like Call of War but make it much
## better - their system is hard to play alliance matches". One screen: members, chat, and
## Operations - an officer posts an online match and every member joins it with one tap.
var alliance: Variant = null
var directory: Array = []
func _alliance_page() -> void:
	if alliance==null:
		label_text("Loading your alliance…",24)
		load_alliance.call_deferred()
		return
	if alliance is Dictionary and alliance.is_empty():
		label_text("You are not in an alliance yet. Join one to share a chat, plan operations together and climb the alliance ranking.",26)
		button("Find an alliance",func():directory=[];build("alliance_browse"))
		button("Found your own alliance",func():build("alliance_create"))
		button("Back",func():build("profile"))
		return
	var info: Dictionary=alliance.get("alliance",{})
	var role:=str(alliance.get("role","member"))
	label_text("[%s] %s" % [str(info.get("tag","")),str(info.get("name",""))],36).modulate=Color(str(info.get("colour","#d9a441")))
	if str(info.get("motto",""))!="":label_text("\"%s\"" % str(info.get("motto","")),24)
	label_text("Your rank: %s · %d members · operations won %d" % [role.capitalize(),alliance.get("members",[]).size(),int(info.get("operations_won",0))],24)
	# Operations first: the whole point is getting into a match together quickly.
	label_text("OPERATIONS",30).modulate=Color("c9ad73")
	var operations: Array=alliance.get("operations",[])
	if operations.is_empty():label_text("No operation posted. Officers can post one below.",22)
	for op in operations:
		label_text("%s · play %s · posted by %s%s" % [str(op.match_code),str(op.side).capitalize(),str(op.posted_by),(" · "+str(op.note)) if str(op.note)!="" else ""],24)
		var code:=str(op.match_code);var side:=str(op.side)
		button("Join operation "+code,func():
			overlay.hide()
			operation_requested.emit(code,side))
	if role in ["leader","officer"]:
		input("op_code","Online match code (e.g. the one you host)")
		var side_pick:=OptionButton.new();side_pick.add_item("Russia");side_pick.add_item("Ukraine");side_pick.custom_minimum_size.y=64;fields.add_child(side_pick)
		input("op_note","Note (optional, e.g. 'Day 3 push on Kharkiv')")
		button("Post operation for all members",func():
			working=true;var result:=await auth.post_alliance_operation(value("op_code").strip_edges(),"russia" if side_pick.selected==0 else "ukraine",value("op_note").strip_edges());working=false
			if result.ok:alliance=null;build("alliance")
			else:status.text=result.message)
	label_text("CHAT",30).modulate=Color("c9ad73")
	for message in alliance.get("messages",[]):
		label_text("%s: %s" % [str(message.commander),str(message.body)],22)
	input("chat","Write to your alliance")
	button("Send",func():
		var text:=value("chat").strip_edges()
		if text.is_empty():return
		working=true;var result:=await auth.post_alliance_message(text);working=false
		if result.ok:alliance=null;build("alliance")
		else:status.text=result.message)
	label_text("MEMBERS",30).modulate=Color("c9ad73")
	for member in alliance.get("members",[]):
		label_text("%s · %s · level %d · %d XP · %d wins%s" % [str(member.commander),str(member.role).capitalize(),int(member.level),int(member.xp),int(member.wins)," (you)" if member.get("me",false) else ""],24)
		if member.get("me",false):continue
		var id:=int(member.member_id);var their_role:=str(member.role)
		if role=="leader":
			if their_role=="member":button("Promote "+str(member.commander)+" to officer",func():_alliance_action(auth.set_alliance_role.bind(id,"officer")))
			elif their_role=="officer":button("Make "+str(member.commander)+" a member",func():_alliance_action(auth.set_alliance_role.bind(id,"member")))
		if role=="leader" or (role=="officer" and their_role=="member"):
			button("Remove "+str(member.commander),func():_alliance_action(auth.remove_alliance_member.bind(id)))
	if role in ["leader","officer"] and not alliance.get("requests",[]).is_empty():
		label_text("REQUESTS TO JOIN",30).modulate=Color("c9ad73")
		for request in alliance.get("requests",[]):
			var request_id:=int(request.request_id)
			label_text("%s · level %d" % [str(request.commander),int(request.level)],24)
			button("Accept "+str(request.commander),func():_alliance_action(auth.answer_alliance_request.bind(request_id,true)))
			button("Decline "+str(request.commander),func():_alliance_action(auth.answer_alliance_request.bind(request_id,false)))
	button("Alliance ranking",func():directory=[];build("alliance_browse"))
	button("Leave alliance",func():_alliance_action(auth.leave_alliance))
	button("Back",func():build("profile"))
signal operation_requested(code: String, side: String)
func _alliance_action(call: Callable) -> void:
	working=true;var result: Dictionary=await call.call();working=false
	if result.ok:alliance=null;build("alliance")
	else:status.text=result.message
func load_alliance() -> void:
	if working or mode!="alliance":return
	working=true;var result:=await auth.my_alliance();working=false
	if not result.ok:status.text=result.message;return
	var data: Dictionary=result.data
	alliance=data if data.has("alliance") else {}
	if mode=="alliance":build("alliance")
func load_directory(search: String) -> void:
	if working:return
	working=true;var result:=await auth.alliance_directory(search);working=false
	if result.ok:
		directory=result.data.get("rows",[])
		if directory.is_empty():status.text="No alliances yet - found the first one."
		elif mode=="alliance_browse":build("alliance_browse")
	else:status.text=result.message
func load_leaderboard() -> void:
	if working or mode!="leaderboard":return
	working=true;var result:=await auth.leaderboard(50,board_metric);working=false
	if result.ok:
		leaderboard_rows=result.data.rows
		if leaderboard_rows.is_empty():status.text="No commanders yet."
		else:build("leaderboard")
	else:status.text=result.message
## Premium flag for a profile that was loaded elsewhere (e.g. after Google sign-in).
func load_premium() -> void:
	if working or mode!="profile":return
	working=true;await PlayerPremium.refresh(auth);working=false
	if mode=="profile" and PlayerPremium.is_premium():build("profile")
func load_profile() -> void:
	if working or mode!="profile":return
	working=true;var result:=await auth.load_profile()
	if result.ok:await PlayerPremium.refresh(auth)
	working=false
	if result.ok and mode=="profile":build("profile")
	elif mode=="profile":status.text=result.message
func delete_account() -> void:
	if value("confirm_delete").strip_edges()!="DELETE":status.text="Type DELETE (in capitals) to confirm.";return
	working=true;status.text="Deleting…";var result:=await auth.delete_account();working=false
	if not result.ok:status.text=result.message;return
	build("login");status.text="Your account and all its data were deleted."
func remember_email() -> void:
	if inputs.has("email"):email=inputs.email.text.strip_edges()
func value(key: String) -> String:return inputs[key].text if inputs.has(key) else ""
func submit() -> void:
	remember_email()
	if mode in ["signup","new_password"] and value("password")!=value("confirm"):status.text="Passwords do not match.";return
	working=true;status.text="Connecting…"
	var result: Dictionary
	match mode:
		"login":
			signup_password=value("password")
			result=await auth.login(email,signup_password)
		"signup":
			signup_password=value("password")
			result=await auth.signup(email,signup_password,value("commander"))
		"recover":result=await auth.resend(email,true)
		"recovery_code":result=await auth.verify(email,value("code"),true)
		"new_password":result=await auth.reset_password(value("password"))
	working=false
	if not result.ok:
		# Signed up earlier but never tapped the email link: show how to finish, no code box.
		if mode=="login" and str(result.message).begins_with("Confirm your email"):
			build("check_email");status.text="Your email is not confirmed yet."
			return
		signup_password=""
		status.text=result.message;return
	match mode:
		"login":signup_password="";build("profile")
		"signup":
			if result.get("needs_email",false):cooldown_until=Time.get_ticks_msec()+60000;build("check_email");status.text=str(result.message)
			else:signup_password="";build("profile")
		"recover":cooldown_until=Time.get_ticks_msec()+60000;build("recovery_code");status.text="If that account exists, a reset code has been sent."
		"recovery_code":build("new_password")
		"new_password":build("login");status.text="Password updated. Sign in with your new password."
func resend_code() -> void:
	if Time.get_ticks_msec()<cooldown_until:status.text="Please wait a minute before requesting another code.";return
	working=true;var result:=await auth.resend(email,mode=="recovery_code");working=false
	status.text=("If eligible, a new email has been sent." if mode=="check_email" else "If eligible, a new code has been sent.") if result.ok else result.message
	if result.ok:cooldown_until=Time.get_ticks_msec()+60000
