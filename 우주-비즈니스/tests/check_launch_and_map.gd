extends SceneTree
var app: FrontierCrewExpedition
var failures:=0
var folder:="res://../test-results/launch-map"
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures+=1
func capture(label: String) -> void:
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path(folder+"/"+label+".png"))
func run() -> void:
 if not "--crew-ui-test" in OS.get_cmdline_user_args() or not str(OS.get_cmdline_user_args()).contains("--crew-folder="):quit(2);return
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 FrontierInput.apply({});root.size=Vector2i(1280,800);root.content_scale_size=root.size
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
 app.world_store.write(FrontierUniverse.new_world(71491));app.start_solo(true)
 await create_timer(.5).timeout;app.onboarding.letter.hide()
 var deadline:=0
 if not "--boarding-only" in OS.get_cmdline_user_args():
  app.open_menu(app.navigation_frame);app.chart.galaxy=true;app.chart.queue_redraw()
  deadline=Time.get_ticks_msec()+30000
  while app.chart.map_built<125000 and Time.get_ticks_msec()<deadline:await process_frame
  check(app.chart.map_built==125000,"all system coordinates indexed without planet nodes")
  await capture("galaxy")
  var before: Dictionary=app.chart.displayed_systems.duplicate()
  app.chart.zoom=4;app.chart.pan=Vector2(900,0);app.chart.queue_redraw()
  await create_timer(.2).timeout
  var additional:=0
  for id in app.chart.displayed_systems:
   if not before.has(id):additional+=1
  check(additional>100,"zoom reveals local stars absent from overview")
  var previous_preview: int=app.navigation_ui.selected_preview
  app.navigation_ui.show_target(FrontierUniverse.first_ordinal(app.session.manifest,625))
  check(app.navigation_ui.selected_preview==previous_preview,"new unvisited stars do not reveal interior details")
  await capture("galaxy-zoom")
  app.close_menus()
 var world: Dictionary=app.session.authority.world
 var ordinal:=FrontierUniverse.first_ordinal(world.manifest,23)
 while not FrontierUniverse.landable(FrontierUniverse.body(world.manifest,ordinal)):ordinal+=1
 var body:=FrontierUniverse.body(world.manifest,ordinal)
 var nav: Dictionary=world.crew.navigation
 nav.system=23;nav.target=ordinal;nav.mode="idle";nav.speed=0.0;nav.orbit_time=0.0;nav.manual=false
 var point:=FrontierCrewNavigation.center(ordinal,world.manifest,0)+Vector3(0,0,FrontierUniverse.navigation_radius(body)+30)
 nav.position=[point.x,point.y,point.z];nav.direction=[0,0,-1];world.location=body.id
 app.session._publish();await create_timer(.3).timeout;app.travel_action("land")
 deadline=Time.get_ticks_msec()+90000
 while app.arrival.active and Time.get_ticks_msec()<deadline:await process_frame
 check(not app.arrival.active and app.surface_world!=null,"normal landing finishes before return")
 if app.surface_world==null:quit(1);return
 if "--boarding-only" in OS.get_cmdline_user_args():
  var core:=app.session.authority
  var guest:=FrontierPlayerProfile.new_character("탑승 대기 이동 확인",1)
  core.world.crew.members[guest.character_id]=FrontierCrewWorld.member(guest,FrontierCrewWorld.content_hash(),1)
  FrontierCrewSurface.spawn_member(core.world,core.world.crew.members[guest.character_id],1)
  core.world.crew.members[guest.character_id].position=core.world.crew.members[app.session.latest.self_id].position.duplicate()
  core.world.crew.members[app.session.latest.self_id].aboard=true
  core.peers[2]=guest.character_id
  # Feed the host snapshot directly; no fake network peer or RPC is created.
  app._snapshot(core.snapshot(1))
  var guest_actor: CharacterBody3D=app.actors[guest.character_id]
  var own_actor: CharacterBody3D=app.actors[app.session.latest.self_id]
  var guest_before:=guest_actor.position
  var own_before:=own_actor.position
  core.inputs[2]={"direction":Vector2(1,0),"expires":core.now+1,"controls_enabled":true}
  app._physics_process(.05)
  check(app.arrival.phase=="boarding" and app.arrival.unboard.visible,"host waits at ship with cancel control")
  check(guest_actor.position.distance_to(guest_before)>.001,"unboarded guest can move while host waits")
  check(own_actor.position==own_before,"boarded host stays seated")
  core.peers.erase(2);core.inputs.erase(2);core.world.crew.members.erase(guest.character_id)
  app.session.send_request("surface_unboard",{})
  await process_frame
  check(not app.arrival.active,"cancel boarding restores surface controls")
  await app.session.close_session();app.queue_free();await process_frame
  print("BOARDING MOTION failures ",failures);quit(1 if failures else 0);return
 var actor: CharacterBody3D=app.actors[app.session.latest.self_id]
 var ship:=FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position)
 actor.position=ship+Vector3(3,1,3);actor.position.y=app.surface_world.terrain.field.height(actor.position.x,actor.position.z)+.1
 app.session.authority.update_position(1,actor.position);app.session._publish()
 app.station_action("launch")
 check(app.arrival.active and app.arrival.phase=="ascent","solo boarding immediately starts approved takeoff")
 check(app.session.latest.crew.landing.is_empty() and app.session.latest.crew.pilot_id==app.session.latest.self_id,"host has helm after boarding")
 check(app.arrival.engine.playing and app.arrival.audio.last_played.has("sfx_vessel_boost"),"ElevenLabs thrust and boost play after approval")
 var phases: Dictionary={}
 deadline=Time.get_ticks_msec()+30000
 while app.arrival.active and Time.get_ticks_msec()<deadline:
  var phase: String=app.arrival.phase
  if app.arrival.age>.8 and not phases.has(phase):
   phases[phase]=true;await capture(phase)
   if phase=="escape_loading":
    check(app.arrival.vessel_overlay.visible and float(app.arrival.cover.get_shader_parameter("cover"))==1,"visible ship and opaque atmosphere during space preparation")
   if phase=="escape":check(app.arrival.warm_frames>=8,"space rendered before clouds clear")
  await process_frame
 check(phases.has("ascent") and phases.has("escape_loading") and phases.has("escape"),"takeoff cloud and escape stages shown")
 check(not app.arrival.active and app.surface_world==null and app.outside and app.flight.exterior,"flight view restored instead of cabin")
 check(app.session.latest.crew.navigation.manual and app._mouse_look_allowed(),"manual controls enabled after handover")
 app.test_mode=false;DisplayServer.window_move_to_foreground();await create_timer(.2).timeout;app._sync_mouse_capture()
 check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"mouse captured for host piloting")
 var old_steering:=app.mouse_steering;app._mouse_look(Vector2(20,10),.0025,false)
 check(app.mouse_steering!=old_steering,"mouse controls helm direction")
 app.test_mode=true
 var old_position:=FrontierCrewWorld.vector(app.session.authority.world.crew.navigation.position)
 FrontierCrewNavigation.steer(app.session.authority.world,[1.0,0.0,0.0],.5)
 check(FrontierCrewWorld.vector(app.session.authority.world.crew.navigation.position).distance_to(old_position)>1,"host thrust moves vessel after launch")
 app.session._publish();await capture("manual-flight")
 check(await app.session.close_session(),"launch result saved")
 app.queue_free();await process_frame
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;app.start_solo()
 await create_timer(.5).timeout
 check(app.outside and app.surface_world==null and not app.arrival.active,"saved space return resumes in flight without takeoff replay")
 await app.session.close_session();app.queue_free();await process_frame
 print("LAUNCH MAP failures ",failures);quit(1 if failures else 0)
