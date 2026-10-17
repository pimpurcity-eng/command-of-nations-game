class_name CountryFlag
extends Control
## National SVG flags from flag-icons (MIT), independently of weapons doctrine.
var country: = ""
var follow_parent: = false
var player: = false
static var textures: Dictionary = {}
func _ready() -> void: mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(_delta: float) -> void:
	var next: String = GameSession.player_country if player else str(get_parent().get("country")) if follow_parent else country
	if next!=country: country=next;queue_redraw()
func _draw() -> void:
	var path: = "res://assets/interface/flags/"+country+".svg"
	if not textures.has(country): textures[country]=load(path) if ResourceLoader.exists(path) else null
	if textures[country]!=null: draw_texture_rect(textures[country],Rect2(Vector2.ZERO,size),false)
	else: draw_rect(Rect2(Vector2.ZERO,size),MapDefinition.country_color(country))
	draw_rect(Rect2(Vector2.ZERO,size),Color("18232b"),false,1)
