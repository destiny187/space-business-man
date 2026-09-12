extends "capture_overview_field.gd"
func rover() -> void:pass
func combat() -> void:pass
func cave() -> void:
 var field:=app.surface_world.terrain.field
 var chosen:=Vector3.INF;var center:=Vector3.ZERO
 for x in range(0,4):
  if chosen.is_finite():break
  for z in range(0,4):
   var graph: Dictionary=field.caves.system_at(x*400,z*400)
   var candidates: Array=[]
   for room in graph.chambers:candidates.append(room.center)
   for i in range(2,graph.nodes.size()):candidates.append(graph.nodes[i])
   for at: Vector3 in candidates:
    if field.density(at)>-.7:continue
    var p:=at
    for i in 200:
     if field.density(p)>0:break
     p.y-=.1
    p.y+=.18
    if field.density(p+Vector3.UP*1.9)>-.25 or field.density(p+Vector3.UP*.4)>0:continue
    chosen=p;center=at;break
   if chosen.is_finite():break
 if not chosen.is_finite():printerr("NO_CLEAR_CAVE_FLOOR");return
 move_before_clip(chosen);app.actors[owner].velocity=Vector3.ZERO;app.session.authority.motions[owner]=FrontierCrewLocomotion.create()
 if not await until(func():return app.surface_world.ready_at(app.actors[owner].position),100):printerr("CAVE_NOT_READY");return
 var query:=PhysicsRayQueryParameters3D.create(center,center-Vector3.UP*35)
 query.exclude=[app.actors[owner].get_rid()]
 var hit:=app.surface_world.get_world_3d().direct_space_state.intersect_ray(query)
 if not hit.is_empty():
  chosen=hit.position+Vector3.UP*.15;move_before_clip(chosen);app.actors[owner].velocity=Vector3.ZERO
 print("CAVE_POSE ",chosen," center ",center," floor ",hit.get("position",Vector3.INF))
 app.session.send_request("equipment_select",{"slot":3});await frames(25)
 aim(center+Vector3(4,0,-5));var base:=app.yaw
 start_clip("underground_explore")
 for i in 150:
  app.yaw=base+sin(float(i)/149*PI-.5)*.18
  await process_frame
 end_clip();await still("cave-clear");evidence["cave_floor"]=FrontierExpeditionBusiness.array(chosen)
