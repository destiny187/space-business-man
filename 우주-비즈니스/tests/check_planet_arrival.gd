extends SceneTree
var app: FrontierCrewExpedition
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if not "--crew-ui-test" in OS.get_cmdline_user_args() or not str(OS.get_cmdline_user_args()).contains("--crew-folder="):
  printerr("Use --crew-ui-test --crew-folder=<existing temporary directory>");quit(2);return
 root.size=Vector2i(1280,800)
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
 app.start_solo(true)
 await create_timer(.5).timeout
 app.onboarding.letter.hide()
 var world: Dictionary=app.session.authority.world
 var ordinal:=FrontierUniverse.first_ordinal(world.manifest,23)
 while not FrontierUniverse.landable(FrontierUniverse.body(world.manifest,ordinal)):ordinal+=1
 var body:=FrontierUniverse.body(world.manifest,ordinal)
 var nav: Dictionary=world.crew.navigation
 nav.system=23;nav.target=ordinal;nav.mode="idle";nav.speed=0.0;nav.orbit_time=0.0
 var point:=FrontierCrewNavigation.center(ordinal,world.manifest,0)+Vector3(0,0,FrontierUniverse.radius(body)+30)
 nav.position=[point.x,point.y,point.z];nav.direction=[0,0,-1];world.location=body.id
 app.session._publish()
 await create_timer(.5).timeout
 app.travel_action("land")
 assert(app.arrival.active,"landing presentation starts after approval")
 var last: String=""
 var end:=Time.get_ticks_msec()+90000
 while app.arrival.active and Time.get_ticks_msec()<end:
  if app.arrival.phase!=last:
   last=app.arrival.phase;print("ARRIVAL PHASE ",last)
  if app.arrival.phase in ["approach","descent","touchdown"] and app.arrival.age>1 and not has_meta(last):
   set_meta(last,true)
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../test-results/planet-arrival/"+last+".png"))
  await process_frame
 assert(not app.arrival.active,"landing finishes once collision ready")
 assert(app.camera.current,"game camera restored")
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
