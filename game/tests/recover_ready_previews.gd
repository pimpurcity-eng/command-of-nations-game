extends SceneTree
func _initialize():
 for name in ["russia_iskander_m_ready","euro_pluton_ready","russia_avangard_silo_ready","euro_s3_silo_ready"]:
  var path = "res://assets/library/arsenal/"+name+".png"
  var texture = load(path) as Texture2D
  if texture != null and texture.get_image()!=null:
   print(name," ",texture.get_image().save_png(path))
 quit()
