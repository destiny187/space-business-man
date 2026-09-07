extends SceneTree
var app: FrontierCrewExpedition
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if not "--crew-ui-test" in OS.get_cmdline_user_args() or not str(OS.get_cmdline_user_args()).contains("--crew-folder="):
  printerr("Use --crew-ui-test --crew-folder=<existing temporary directory>");quit(2);return
 root.size=Vector2i(1280,800)
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
 assert(app.world_store.write(FrontierUniverse.new_world(71491)),"write isolated fresh fixture")
 app.start_solo(true)
 await create_timer(.5).timeout
 FrontierClientSettings.ensure(self).values.view_distance=4096
 app.onboarding.letter.hide()
 var world: Dictionary=app.session.authority.world
 var ordinal:=FrontierUniverse.first_ordinal(world.manifest,23)
 while not FrontierUniverse.landable(FrontierUniverse.body(world.manifest,ordinal)):ordinal+=1
 var body:=FrontierUniverse.body(world.manifest,ordinal)
 var nav: Dictionary=world.crew.navigation
 nav.system=23;nav.target=ordinal;nav.mode="idle";nav.speed=0.0;nav.orbit_time=0.0
 var point:=FrontierCrewNavigation.center(ordinal,world.manifest,0)+Vector3(0,0,FrontierUniverse.navigation_radius(body)+30)
 nav.position=[point.x,point.y,point.z];nav.direction=[0,0,-1];world.location=body.id
 app.session._publish()
 await create_timer(.5).timeout
 app.travel_action("land")
 if not app.arrival.active:
  printerr("Landing rejected: ",app.status.value);quit(1);return
 var last: String=""
 var checked_wait:=false
 var checked_descent:=false
 var end:=Time.get_ticks_msec()+90000
 while app.arrival.active and Time.get_ticks_msec()<end:
  if app.arrival.phase=="loading" and app.arrival.prepared and not checked_wait:
   var business:=app.surface_world.business_view
   business.set_process(false);business.requested_models["__test_loading__"]=true
   await create_timer(.25).timeout
   assert(app.arrival.phase=="loading","unfinished model keeps descent behind curtain")
   assert(app.arrival.vessel_overlay.visible and app.arrival.vessel_overlay.hull.is_visible_in_tree(),"real vessel stays visible in front of loading atmosphere")
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../test-results/planet-arrival/atmosphere-vessel.png"))
   assert(float(app.arrival.cover.get_shader_parameter("cover"))==1.0,"loading cover stays opaque")
   business.requested_models.erase("__test_loading__");business.set_process(true);checked_wait=true
   print("ARRIVAL MODEL WAIT PASS")
  if app.arrival.phase=="descent" and not checked_descent:
   assert(app.surface_world.landing_view_ready(),"local terrain, far terrain, models and details ready before descent")
   assert(app.arrival.warm_frames>=8,"actual render frames completed behind curtain")
   assert(app.arrival.vessel_overlay.visible,"vessel continues into descent without disappearing")
   checked_descent=true;print("ARRIVAL RENDER BARRIER PASS")
  if app.arrival.phase!=last:
   last=app.arrival.phase;print("ARRIVAL PHASE ",last)
  if app.arrival.phase in ["approach","descent","touchdown"] and app.arrival.age>1 and not has_meta(last):
   set_meta(last,true)
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../test-results/planet-arrival/"+last+".png"))
  await process_frame
 assert(not app.arrival.active,"landing finishes once collision ready")
 assert(checked_wait and checked_descent,"loading regression checks ran")
 assert(app.surface_world.presentation_points.is_empty() and app.surface_world.business_view.presentation_points.is_empty(),"preload interests released after handover")
 assert(app.camera.current,"game camera restored")
 assert(app.surface_world.landing_ship.visible and app.flight.ship.get_child(0).visible,"both source hulls restored after presentation")
 assert(app.surface_world.ready_at(app.actors[app.session.latest.self_id].position),"spawn collision ready")
 await create_timer(.5).timeout
 var before: Vector3=app.actors[app.session.latest.self_id].position
 app.test_direction=Vector2(1,0);await create_timer(.5).timeout;app.test_direction=Vector2.ZERO
 assert(app.actors[app.session.latest.self_id].position.distance_to(before)>1,"control restored")
 print("ARRIVAL PASS: accepted landing, loading gate, descent, touchdown, camera and movement")
 await app.session.close_session();app.queue_free();await process_frame
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;app.start_solo()
 await create_timer(.5).timeout
 assert(not app.arrival.active,"surface resume does not replay entry")
 assert(app.surface_world!=null,"landed save resumes")
 print("ARRIVAL RESUME PASS")
 await app.session.close_session();app.queue_free();await process_frame;quit()
