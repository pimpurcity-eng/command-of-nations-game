@tool
extends EditorPlugin
## Adds the return link for "Sign in with Google" to the Android manifest at export time
## (needs the Gradle build, which the Play bundle uses). See app_link_export.gd.
var exporter: EditorExportPlugin
func _enter_tree() -> void:
	exporter=preload("res://addons/warfront_app_link/app_link_export.gd").new()
	add_export_plugin(exporter)
func _exit_tree() -> void:
	if exporter!=null:remove_export_plugin(exporter)
	exporter=null
