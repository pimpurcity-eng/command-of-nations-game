class_name ProvincePanel
extends CanvasLayer
var buildings: BuildingSystem
var province_id: = ""
var panel: PanelContainer
var heading: Label
var summary: Label
var income: Label
var list: VBoxContainer
var queue: VBoxContainer
var message: Label
var rows: Dictionary = {}
var ui_timer: = 0.0
const EFFECTS: = {"industry":"+25% province output per level", "bunker":"20% less damage per level at the province centre", "infrastructure":"+10% ground travel and +15% construction speed per level", "airbase":"Aircraft may rebase and refuel here. No unit production.","train_station":"Rail logistics station. No unit production.","naval_base":"Coastal naval facilities. No unit production.", "hospital":"Heals your armies nearby (+2 health per level each hour)."}
func setup(system: BuildingSystem,theme: Theme) -> void:
 buildings=system;layer=12
 var root: = Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.theme=theme;add_child(root)
 panel=PanelContainer.new();panel.add_theme_stylebox_override("panel",CowUI.skin("panel_dark",8));root.add_child(panel)
 var column: = VBoxContainer.new();column.add_theme_constant_override("separation",8);panel.add_child(column)
 var head: = CowUI.header("Province",false);heading=head.title;head.close.pressed.connect(hide);column.add_child(head.bar)
 summary=CowUI.label("",18);summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(summary)
 income=CowUI.label("",18);income.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(income)
 var notice: = CowUI.label("Province construction · Unit production is available in cities",18,CowUI.GOLD);notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(notice)
 var scroll: = ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;column.add_child(scroll)
 list=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.add_theme_constant_override("separation",8);scroll.add_child(list)
 for kind in ProvinceConstruction.ALLOWED:
  var card: = PanelContainer.new();card.add_theme_stylebox_override("panel",CowUI.skin("row",8,12));list.add_child(card)
  var inner: = VBoxContainer.new();inner.add_theme_constant_override("separation",8);card.add_child(inner)
  var heading_row: = HBoxContainer.new();inner.add_child(heading_row)
  var picture: = TextureRect.new();picture.custom_minimum_size=Vector2(118,80);picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;heading_row.add_child(picture)
  var name: = CowUI.label("",24,CowUI.INK);name.size_flags_horizontal=Control.SIZE_EXPAND_FILL;name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;heading_row.add_child(name)
  var effect: = CowUI.label(EFFECTS[kind],18,CowUI.INK);effect.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;inner.add_child(effect)
  var row: = HBoxContainer.new();inner.add_child(row)
  var costs: = CowUI.label("",16,CowUI.INK);costs.size_flags_horizontal=Control.SIZE_EXPAND_FILL;costs.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;row.add_child(costs)
  var button: = CowUI.action("CONSTRUCT","hammer");button.pressed.connect(func():message.text=buildings.provinces.schedule(province_id,kind);refresh());row.add_child(button)
  rows[kind]={"name":name,"picture":picture,"costs":costs,"button":button}
 queue=VBoxContainer.new();list.add_child(queue)
 message=CowUI.label("",18,CowUI.GOLD);message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(message)
 buildings.changed.connect(func():if visible:refresh())
 get_viewport().size_changed.connect(_layout)
 _layout();hide()
func _layout() -> void:
 var size: = get_viewport().get_visible_rect().size
 var width: = minf(760,size.x)
 panel.position=Vector2((size.x-width)/2,roundf(size.y*0.06));panel.size=Vector2(width,size.y-panel.position.y)
func open(place: Dictionary) -> void:
 province_id=place.id;message.text="";show();_layout();refresh()
func refresh() -> void:
 var place: = buildings.provinces.place(province_id)
 if place.is_empty():return
 var owner: = buildings.economy.controller(place)
 heading.text=place.name
 summary.text=("YOURS" if owner==GameSession.player_country else "Controlled by "+owner.capitalize())+" · "+str(place.region.get("terrain","plains")).capitalize()+" · Morale "+str(roundi(float(place.region.get("morale",100))))+"%"
 var output: = buildings.economy.province_income(place)
 var amounts: PackedStringArray=[]
 for resource in output:
  if output[resource]>0:amounts.append(resource.capitalize()+" +%.1f/h" % (output[resource]*30.0))
 income.text=" · ".join(amounts) if not amounts.is_empty() else "No resources here · all resources and money come from cities"
 for kind in rows:
  var row: Dictionary=rows[kind];var current: = buildings.provinces.level(province_id,kind)
  row.name.text=ProvinceConstruction.NAMES[kind]+" · Level "+str(current)
  row.picture.texture=FacilityVisual.preview(buildings.spec(kind),place.country.to_lower(),mini(current+1,int(buildings.spec(kind).max_level)),true)
  var bill: = buildings.cost(kind,current+1);var parts: PackedStringArray=[]
  for resource in bill:
   if bill[resource]>0:parts.append(resource.capitalize()+" "+str(int(bill[resource])))
  row.costs.text=" · ".join(parts)+"\n"+SimulationClock.duration(buildings.duration(kind,current+1)/buildings.provinces.construction_rate(province_id))
  var reason: = buildings.provinces.reason(province_id,kind)
  row.button.disabled=not reason.is_empty();row.button.tooltip_text=reason
  row.button.get_meta("caption").text="MAX LEVEL" if current>=buildings.spec(kind).max_level else "CONSTRUCT L"+str(current+1)
  if current>=buildings.spec(kind).max_level: row.costs.text="Maximum level completed"
 for child in queue.get_children():queue.remove_child(child);child.queue_free()
 var jobs: = buildings.provinces.jobs.filter(func(j):return j.city==province_id)
 if not jobs.is_empty():queue.add_child(CowUI.section("Construction queue"))
 for job in jobs:
  var row: = HBoxContainer.new();queue.add_child(row)
  var text: = CowUI.label(ProvinceConstruction.NAMES[job.building]+" · L"+str(job.level)+" · "+(SimulationClock.duration((buildings.duration(job.building,job.level)-job.progress)/buildings.provinces.construction_rate(province_id)) if job.paid else "Waiting for resources"),18)
  text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(text)
  var cancel: = CowUI.square("close");cancel.pressed.connect(func():message.text=buildings.provinces.cancel(job.id);refresh());row.add_child(cancel)
func _process(delta: float) -> void:
 if not visible:return
 ui_timer+=delta
 if ui_timer>=0.5:ui_timer=0;refresh()
