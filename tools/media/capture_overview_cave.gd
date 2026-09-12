extends "capture_overview_field.gd"
func industry() -> void:pass
func rover() -> void:pass
func combat() -> void:pass
func cave() -> void:
 var field:=app.surface_world.terrain.field
 var graph: Dictionary=field.caves.system_at(0,0)
 var entrance: Vector3=graph.nodes[0];var next: Vector3=graph.nodes[1]
 for take in 3:
  var at: Vector3=entrance.lerp(next,[.0,.28,.52][take])
  var p:=at
  for i in 250:
   if field.density(p)>0:break
   p.y-=.1
  p.y+=.22
  move_before_clip(p);app.actors[owner].velocity=Vector3.ZERO;app.session.authority.motions[owner]=FrontierCrewLocomotion.create()
  await until(func():return app.surface_world.ready_at(app.actors[owner].position),100)
  app.session.send_request("equipment_select",{"slot":1});await frames(35)
  var target:=at.lerp(next,.55);target.y=p.y+1.7
  aim(target);await frames(20)
  print("CAVE_CAPTURE ",take," actor ",app.actors[owner].position," camera ",app.camera.global_position," light ",app.surface_world.lamp.light_energy)
  start_clip("cave_entrance_"+str(take))
  for i in 120:
   root.grab_focus()
   aim(target+Vector3.UP*sin(float(i)/119*PI)*.2)
   await process_frame
  end_clip();await still("entrance-"+str(take))
