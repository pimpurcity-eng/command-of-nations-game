extends SceneTree
func _initialize():
 var paths: Dictionary = {}
 var queue: Array = []
 for e in EquipmentIdentity.catalog:
  for t in e.research_tiers:queue.append(t.model)
 for e in JSON.parse_string(FileAccess.get_file_as_string("res://data/weapon_showcase.json")):queue.append(e.model)
 while not queue.is_empty():
  var path: String = queue.pop_back()
  if paths.has(path):continue
  paths[path] = true
  for dependency in ResourceLoader.get_dependencies(path):
   var parts = dependency.split("::")
   var dest = parts[parts.size()-1]
   if dest.begins_with("res://"):queue.append(dest)
 var f = FileAccess.open("res://tests/package_dependencies.json",FileAccess.WRITE)
 f.store_string(JSON.stringify(paths.keys()))
 print("dependencies ",paths.size())
 quit()
