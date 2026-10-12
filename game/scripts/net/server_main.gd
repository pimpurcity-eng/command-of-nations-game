extends SceneTree
## Starts a dedicated match server (see docs/MULTIPLAYER_SERVER.md):
##   godot --headless --path . --script res://scripts/net/server_main.gd -- --port 8910 --match europe-1
## Settings come from the command line or the environment:
##   --port / WM_PORT                 TCP port for WebSocket connections (default 8910)
##   --match / WM_MATCH               match id phones must ask for (default "main")
##   --save / WM_SAVE                 save file (default user://matches/<match>.json)
##   --inactive / WM_INACTIVE         seconds away before the AI takes over (default 600)
##   SUPABASE_URL, SUPABASE_ANON_KEY  account sign-in check (required in production)
##   WM_ALLOW_DEV_TOKENS=1            accept "dev:<name>" sign-ins (local testing only)
var server: MatchServer

func _initialize() -> void: call_deferred("run")

func option(name: String, env: String, fallback: String) -> String:
	var args: = OS.get_cmdline_user_args()
	var at: = args.find("--" + name)
	if at >= 0 and at + 1 < args.size(): return args[at + 1]
	return OS.get_environment(env) if OS.has_environment(env) else fallback

func run() -> void:
	var match_id: = option("match", "WM_MATCH", "main")
	var save: = option("save", "WM_SAVE", "user://matches/%s.json" % match_id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save.get_base_dir()))
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 3: await process_frame
	server = MatchServer.new()
	server.inactive_seconds = float(option("inactive", "WM_INACTIVE", "600"))
	server.allow_dev_tokens = OS.get_environment("WM_ALLOW_DEV_TOKENS") == "1"
	server.supabase_url = OS.get_environment("SUPABASE_URL")
	server.supabase_key = OS.get_environment("SUPABASE_ANON_KEY")
	root.add_child(server)
	var port: = int(option("port", "WM_PORT", "8910"))
	var error: = server.start(game, port, match_id, save)
	if error != OK:
		printerr("Could not listen on port %d (error %d)" % [port, error])
		quit(1)
		return
	if server.supabase_url.is_empty() and not server.allow_dev_tokens: printerr("Warning: SUPABASE_URL is not set, nobody can sign in")
	print("Warfront Mandate match '%s' listening on port %d · save %s" % [match_id, port, ProjectSettings.globalize_path(save)])

func _finalize() -> void:
	if server != null: server.stop()
