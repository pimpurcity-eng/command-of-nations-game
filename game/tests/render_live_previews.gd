extends SceneTree
func _initialize():call_deferred("run")
func run():
 var viewport: = SubViewport.new()
 viewport.size = Vector2i(512,320)
 viewport.own_world_3d = true
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var world: = Node3D.new()
 viewport.add_child(world)
 var env: = WorldEnvironment.new()
 var settings: = Environment.new()
 settings.background_mode = Environment.BG_COLOR
 settings.background_color = Color("34434e")
 settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 settings.ambient_light_color = Color.WHITE
 settings.ambient_light_energy = 0.8
 env.environment = settings
 world.add_child(env)
 var sun: = DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-45,-30,0)
 sun.light_energy = 1.2
 world.add_child(sun)
 var camera: = Camera3D.new()
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.position = Vector3(3,2.3,4)
 world.add_child(camera)
 camera.current = true
 for entry in JSON.parse_string(FileAccess.get_file_as_string("res://tests/missing_previews.json")):
  var spec: = EquipmentIdentity.spec(entry.equipment)
  var model: = UnitVisual.create(spec.visual_kind,Color.WHITE,entry.equipment,entry.level)
  world.add_child(model)
  var box: AABB = UnitVisual.model_bounds(model,0)
  camera.size = maxf(1.0,maxf(box.size.x,box.size.z)*1.3)
  camera.look_at(box.get_center())
  for i in 4:await process_frame
  var status = viewport.get_texture().get_image().save_png(entry.preview)
  print("PREVIEW ",entry.preview," result=",status)
  model.queue_free()
  await process_frame
 quit()
