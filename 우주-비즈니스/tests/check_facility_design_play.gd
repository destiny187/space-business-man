extends "res://tests/test_solo_entry.gd"
func run() -> void:
 folder="/tmp/facility-design-play"
 if "--crew-ui-test" not in OS.get_cmdline_user_args() or "--crew-folder="+folder not in OS.get_cmdline_user_args():quit(2);return
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"landed design review",90):quit(1);return
 app.onboarding.welcome_pending=false;app.onboarding.letter.hide();app.onboarding.set_process(false);app.onboarding.hide();app.close_menus();app.set_physics_process(false);app.set_process(false)
 root.size=Vector2i(1280,800);root.content_scale_size=root.size
 if "--cards-only" in OS.get_cmdline_user_args():
  root.size=Vector2i(960,640);root.content_scale_size=root.size
  app.toggle_business();await create_timer(.5).timeout;await capture("build-cards-960")
  if "--field-only" not in OS.get_cmdline_user_args():
   await app.session.close_session();app.queue_free();await process_frame;print("FACILITY_CARDS_RENDER");quit();return
 var actor: String=app.session.latest.self_id
 var world: Dictionary=app.session.authority.world
 var field:=app.surface_world.terrain.field
 if "--field-only" in OS.get_cmdline_user_args():
  var buildings: Dictionary=FrontierExpeditionBusiness.site(world).buildings
  var origin:=FrontierExpeditionBusiness.point(buildings[buildings.keys().back()].position)
  app.close_menus();await review_motion(origin,world,field)
  await app.session.close_session();app.queue_free();await process_frame;print("FACILITY_MOTION_REVIEW ",checks," FAILURES ",failures);quit(1 if failures else 0);return
 world.business.bags[actor]=FrontierExpeditionBusiness.inventory()
 var cost: Dictionary=FrontierFacilityResearch.construction("solar").cost
 for resource in cost:world.business.bags[actor][resource]=cost[resource]
 var point:=Vector3.INF
 for x in range(-30,31,4):
  if point.is_finite():break
  for z in range(-30,31,4):
   var p:=FrontierExpeditionBusiness.ground(field,x,z,2.2)
   if not p.is_finite():continue
   var position_value:=p+Vector3(0,0,7);position_value.y=field.height(position_value.x,position_value.z)+.1
   world.crew.members[actor].position=FrontierExpeditionBusiness.array(position_value)
   if FrontierExpeditionBusiness.build_reason(world,actor,"solar",p,{1:actor}).is_empty():point=p;app.actors[actor].position=position_value;break
 check(point.is_finite(),"valid unchanged construction footprint")
 if not point.is_finite():quit(1);return
 app.session._publish()
 await until(func():return app.surface_world.ready_at(point),"placement terrain ready",45)
 app.camera.set_as_top_level(true);app.camera.position=point+Vector3(5,4,6);app.camera.look_at(point)
 app.toggle_business();await create_timer(.5).timeout;await capture("build-cards")
 app.business_panel.building_cards.solar.pressed.emit();await physics_frame
 app._update_business_placement()
 check(app.placement_kind=="solar" and app.placement_ghost!=null and app.placement_valid,"B card opens valid new-model ghost")
 await capture("solar-ghost")
 var wheel:=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.pressed=true;app._unhandled_input(wheel)
 check(app.placement_rotation==1,"new model keeps wheel rotation")
 var before: int=FrontierExpeditionBusiness.site(app.session.authority.world).buildings.size()
 var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;app._unhandled_input(click)
 if not await until(func():return FrontierExpeditionBusiness.site(app.session.authority.world).buildings.size()==before+1,"host installs rendered building",20):quit(1);return
 var site:=FrontierExpeditionBusiness.site(app.session.authority.world)
 var id: String=site.buildings.keys().back()
 await until(func():return app.surface_world.business_view.nodes.has(id),"placed Blender model arrives",20)
 var solar: Node3D=app.surface_world.business_view.nodes[id]
 check(is_equal_approx(solar.rotation.y,PI*.5),"installed rotation matches ghost")
 await capture("solar-installed")
 check(cost.keys().all(func(resource):return int(app.session.authority.world.business.bags[actor][resource])==0),"original construction cost charged once")
 await review_motion(point,world,field)
 check(await app.session.close_session(),"placed building save closes")
 var saved:=FrontierWorldStore.new(folder+"/world.json").read_state()
 check(saved.business.sites[world.location].buildings.has(id),"placed building survives reload")
 app.queue_free();await process_frame;print("FACILITY_DESIGN_PLAY ",checks," FAILURES ",failures);quit(1 if failures else 0)

func review_motion(point: Vector3,world: Dictionary,field: FrontierTerrainField) -> void:
 # Presentation-only controlled working states; no extra facilities enter the save.
 app.session.set_process(false)
 var view:=app.surface_world.business_view
 var packet: Dictionary=view.ledger.duplicate(true)
 var models: Dictionary={"atmosphere":"Anim_Fan_Process","thermal":"Anim_Fan_Process","water":"Anim_Piston_Process","biolab":"Anim_Agitator_Process"}
 var i:=0
 for kind in models:
  var p:=point+Vector3((i%2)*6,0,-8-(i/2)*6);p.y=field.height(p.x,p.z);i+=1
  packet.sites[world.location].buildings["review:"+kind]={"id":"review:"+kind,"type":kind,"position":FrontierExpeditionBusiness.array(p),"yaw":0.0,"tier":1,"active":true,"enabled":true,"working":true,"status":"가동 확인","work":0.0}
 view.accept(packet)
 for kind in models:
  var key: String="review:"+kind
  await until(func():return view.nodes.has(key),kind+" production scene model",20)
  var node: Node3D=view.nodes[key];var pivot: Node3D=node.find_child(models[kind],true,false)
  check(pivot!=null,kind+" motion pivot retained")
  if pivot==null:continue
  app.camera.position=node.position+Vector3(5,7,-7);app.camera.look_at(node.position+Vector3.UP*1.5)
  await create_timer(.3).timeout
  var pose:=pivot.transform;await create_timer(.3).timeout
  check(pose!=pivot.transform,kind+" existing working motion visible")
  await capture(kind+"-field")
