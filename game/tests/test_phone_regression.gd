extends SceneTree
var failures=0
var checks=0
func check(ok: bool,msg: String):
 checks+=1
 print("PASS " if ok else "FAIL ",msg)
 if not ok: failures+=1
func _initialize(): call_deferred("run")
func run():
 root.size=Vector2i(720,1440)
 GameSession.player_country="russia"
 GameSession.weapons_test=true
 var game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 while not game.boot_finished: await process_frame
 for i in 3: await process_frame
 game.mobile_start.hide()
 game.units.fog_enabled=false
 game.rig.set_process(false)
 var enemy=game.units.units.filter(func(u): return u.country=="ukraine")[0]
 game.units.select_unit(game.units.units.find(enemy))
 check(GameSession.player_country=="russia","inspecting enemy preserves Russia player flag")
 game.match_rules.declare_war()
 game.map.update_relations(true)
 var own=game.map.territories.filter(func(t):return t.playable and t.controller=="russia")[0]
 check(not game.map.materials[own.id].get_shader_parameter("hostile"),"Russia remains friendly after enemy selection")
 var armies=game.units.units.filter(func(u):return u.equipment_id=="tanks_russia").slice(0,3)
 var ids: Array[String]=[]
 for army in armies: ids.append(army.id)
 game.units.select_armies(ids)
 game.open_army_selection()
 var city=game.cities.cities.filter(func(c):return c.id=="kursk")[0]
 game.rig.target=game.map.position_at(city.point)
 game.rig.distance=7
 game.rig._snap(1.0)
 var screen=game.rig.camera.unproject_position(game.map.position_at(city.point)+Vector3.UP*0.2)
 # The enlarged garrison is selectable in group-selection mode. Aim at the city's
 # buildings, away from an army, to choose the meeting point rather than toggle that army.
 var town_tap_found=false
 for radius in [0,30,50,70,90,110,130]:
  for angle in 16:
   var candidate=screen+Vector2.from_angle(TAU*angle/16.0)*radius
   var town=game.cities.pick_screen(candidate)
   var hit=game.units.pick_screen(game.rig.camera,candidate)
   var own_hit=not hit.is_empty() and game.units.units[hit.index].country==GameSession.player_country and (town.is_empty() or float(hit.rank)<float(town.distance))
   if not town.is_empty() and town.city.id==city.id and not own_hit:
    screen=candidate
    town_tap_found=true
    break
  if town_tap_found:break
 check(town_tap_found,"the city's buildings have a distinct meeting-point tap")
 game._map_click(screen,false)
 check(not game.selecting_armies,"city model tap completes group selection")
 check(armies.all(func(u):return u.moving),"all three armies move to city")
 game.units.select_armies(ids)
 game.open_army_selection()
 game.cities.select_city(city)
 check(not game.selecting_armies and armies.all(func(u):return u.moving),"city label sends group to city")
 var silo=game.units.units.filter(func(u):return u.equipment_id=="silos_ukraine")[0]
 var visual=silo.node.get_child(0)
 var box=visual.get_meta("pick_bounds")
 check(box.position.y < -0.5 and box.end.y < 0.4,"silo shaft below ground, surface pad stays low")
 var launch_point: Marker3D=visual.get_meta("missile_launch_point")
 check(launch_point.position.y>=0 and launch_point.position.y<0.2,"silo launch point at surface hatch")
 check(game.hud.unit_portrait.custom_minimum_size.y>=80 and game.hud.detail.get_theme_font_size("font_size")>=22,"larger selected unit portrait and readable details")
 # Real input -> attack -> simulation -> projectile, including a paused weapons map.
 var launcher=game.units.units.filter(func(u):return u.equipment_id=="missiles_russia")[0]
 enemy.node.position=launcher.node.position+Vector3(2,0,0)
 game.units.select_unit(game.units.units.find(launcher))
 game.rig.target=enemy.node.position
 game.rig.distance=5
 game.rig._snap(1.0)
 game.clock.paused=true
 game.combat_effects.clear()
 game.match_rules.combat.cooldowns.clear()
 game.hud.attack_requested.emit()
 game._map_click(game.rig.camera.unproject_position(enemy.node.position+Vector3.UP*0.2),false)
 check(not game.clock.paused and launcher.attack_target==enemy.id,"Attack starts missile order from paused weapons map")
 game.clock.advance(0.05)
 var marker: Marker3D=launcher.node.get_child(0).get_meta("missile_launch_point")
 # Real launchers raise their erector before firing; wait for the physical tube mouth.
 var fired=false
 for frame in 180:
  var model: Node3D=launcher.node.get_child(0)
  var mouth: Vector3=marker.global_position
  if model.has_meta("erector_hinge"):
   mouth=(model.get_meta("erector_hinge") as Node3D).global_transform*(model.get_meta("erector_mouth") as Vector3)
  if game.combat_effects.projectiles.any(func(p):return p.effect=="missile" and p.start.is_equal_approx(mouth)):
   fired=true
   break
  await process_frame
 check(fired,"actual combat launches projectile from launcher muzzle after raising the erector")
 print("RESULT checks=",checks," failures=",failures)
 game.queue_free()
 await process_frame
 quit(1 if failures else 0)
