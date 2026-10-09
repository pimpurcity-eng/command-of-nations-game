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
	if preview_open:open()
func open() -> void:
	build("profile" if auth.signed_in() else "new_password" if auth.recovery_pending else "login");overlay.show()
func label_text(text: String,size: int=28) -> Label:
	var item:=Label.new();item.text=text;item.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;item.add_theme_font_size_override("font_size",size);fields.add_child(item);return item
func input(key: String,placeholder: String,secret: bool=false) -> void:
	var field:=LineEdit.new();field.placeholder_text=placeholder;field.secret=secret;field.custom_minimum_size.y=64
	field.max_length=128 if secret else 254;field.virtual_keyboard_type=LineEdit.KEYBOARD_TYPE_PASSWORD if secret else LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS if key=="email" else LineEdit.KEYBOARD_TYPE_NUMBER if key=="code" else LineEdit.KEYBOARD_TYPE_DEFAULT
	if key=="email":field.text=email
	inputs[key]=field;fields.add_child(field)
func button(text: String,action: Callable) -> void:
	var item:=Button.new();item.text=text;item.custom_minimum_size.y=64;item.pressed.connect(func():
		if not working:action.call())
	fields.add_child(item)
func build(page: String) -> void:
	mode=page;inputs.clear()
	for item in fields.get_children():fields.remove_child(item);item.queue_free()
	label_text("COMMAND OF NATIONS",24).modulate=Color("c9ad73")
	var titles: Dictionary={"login":"Welcome back, Commander","signup":"Create your commander account","verify":"Confirm your email","recover":"Reset your password","recovery_code":"Check your email","new_password":"Choose a new password","profile":"Commander account"}
	label_text(titles[page],40)
	if page=="profile":
		label_text(str(auth.user.get("user_metadata",{}).get("commander_name","Commander")),34)
		label_text(str(auth.user.get("email","")))
		label_text("Email confirmed. Online matches are still in development.",24)
		button("Sign out",func():
			working=true;await auth.logout();working=false;build("login"))
	else:
		if page in ["login","signup","recover"]:input("email","Email address")
		if page=="signup":input("commander","Commander name")
		if page in ["login","signup","new_password"]:input("password","Password (12+ characters)" if page!="login" else "Password",true)
		if page in ["signup","new_password"]:input("confirm","Repeat password",true)
		if page in ["verify","recovery_code"]:
			label_text("Enter the six-digit code sent to "+email+".",24);input("code","Six-digit email code")
		button({"login":"Sign in","signup":"Create account","verify":"Confirm email","recover":"Send reset code","recovery_code":"Verify reset code","new_password":"Save new password"}[page],submit)
		if page=="login":
			button("Create an account",func():remember_email();build("signup"))
			button("Forgot password?",func():remember_email();build("recover"))
		elif page in ["verify","recovery_code"]:button("Send another code",resend_code)
		if page!="login":button("Back to sign in",func():auth.clear_session();build("login"))
	status=label_text("",24)
	if not auth.configured():status.text="Online accounts are being connected. Offline play is available."
	button("Back to game",func():overlay.hide())
func remember_email() -> void:
	if inputs.has("email"):email=inputs.email.text.strip_edges()
func value(key: String) -> String:return inputs[key].text if inputs.has(key) else ""
func submit() -> void:
	remember_email()
	if mode in ["signup","new_password"] and value("password")!=value("confirm"):status.text="Passwords do not match.";return
	working=true;status.text="Connecting…"
	var result: Dictionary
	match mode:
		"login":result=await auth.login(email,value("password"))
		"signup":result=await auth.signup(email,value("password"),value("commander"))
		"verify":result=await auth.verify(email,value("code"))
		"recover":result=await auth.resend(email,true)
		"recovery_code":result=await auth.verify(email,value("code"),true)
		"new_password":result=await auth.reset_password(value("password"))
	working=false
	if not result.ok:status.text=result.message;return
	match mode:
		"login","verify":build("profile")
		"signup":cooldown_until=Time.get_ticks_msec()+60000;build("verify")
		"recover":cooldown_until=Time.get_ticks_msec()+60000;build("recovery_code");status.text="If that account exists, a reset code has been sent."
		"recovery_code":build("new_password")
		"new_password":build("login");status.text="Password updated. Sign in with your new password."
func resend_code() -> void:
	if Time.get_ticks_msec()<cooldown_until:status.text="Please wait a minute before requesting another code.";return
	working=true;var result:=await auth.resend(email,mode=="recovery_code");working=false
	status.text="If eligible, a new code has been sent." if result.ok else result.message
	if result.ok:cooldown_until=Time.get_ticks_msec()+60000
