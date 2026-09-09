extends "res://tests/test_solo_entry.gd"
func run() -> void:
 folder="/tmp/surface-hydrology-20260909"
 if "--crew-folder=/tmp/surface-hydrology-20260909" not in OS.get_cmdline_user_args():quit(2);return
 DirAccess.make_dir_recursive_absolute(folder)
 var owner:=FrontierPlayerProfile.new_character("착륙 연출 확인",1)
 FrontierWorldStore.new(folder+"/world.json").write(FrontierUniverse.new_world(71491))
 var profile_store:=FrontierPlayerProfile.new(folder+"/profile.json");profile_store.data={"version":1,"character":owner,"sessions":{}};profile_store.save()
 root.size=Vector2i(1280,800)
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.session.active and app.flight!=null,"actual expedition started",50):quit(1);return
 FrontierClientSettings.ensure(self).values.view_distance=1400
 app.onboarding.letter.hide();app.close_menus()
 var world: Dictionary=app.session.authority.world
 var small: bool="--finch" in OS.get_cmdline_user_args()
 var selected: Dictionary={}
 for system in range(1,80):
  for i in FrontierUniverse.body_count(world.manifest,system):
   var ordinal:=FrontierUniverse.first_ordinal(world.manifest,system)+i
   var body:=FrontierUniverse.body(world.manifest,ordinal)
   var p:=FrontierLandingSurfaceEffects.profile(body)
   if FrontierUniverse.landable(body) and FrontierSurfaceDrainage.liquid(body.get("terrain_traits",{})):selected={"body":body,"system":system,"ordinal":ordinal};break
  if not selected.is_empty():break
 check(not selected.is_empty(),"requested atmospheric environment exists")
 if selected.is_empty():quit(1);return
 var nav: Dictionary=world.crew.navigation
 var body: Dictionary=selected.body
 nav.system=selected.system;nav.target=selected.ordinal;nav.mode="idle";nav.speed=0.0;nav.orbit_time=0.0
 var point:=FrontierCrewNavigation.center(selected.ordinal,world.manifest,0)+Vector3(0,0,FrontierUniverse.navigation_radius(body)+30)
 nav.position=[point.x,point.y,point.z];nav.direction=[0,0,-1];world.location=body.id;world.navigation_target=body.id
 if small:
  var actor: String=app.session.latest.self_id
  if not world.crew.has("shuttles"):world.crew.shuttles={}
  world.crew.shuttles[actor]={"state":"sortie","pad_slot":0,"progress":1.0,"factory_id":"fixture","system":selected.system,"location":body.id,"navigation_target":body.id,"navigation":nav.duplicate(true),"landing":{},"cargo":{},"cargo_equipment":{},"rock":0}
  world.crew.members[actor].shuttle_id=actor
 app.session._publish();await create_timer(.8).timeout
 app.travel_action("land")
 if not await until(func():return app.surface_world!=null and not app.arrival.active,"landing completes",90):quit(1);return
 var surface:=app.surface_world;var presence:=surface.presence
 check(presence!=null,"surface presence connected")
 var hydro:=surface.hydrology
 check(hydro!=null and hydro.ocean!=null,"liquid world connects ocean and drainage")
 if not await until(func():return hydro.jobs.is_empty() and hydro.source_requests.is_empty() and hydro.tiles.size()>0,"bounded drainage generated",65):quit(1);return
 var longest: Dictionary={}
 for row in hydro.tiles.values():
  if row.samples.size()>longest.get("samples",[]).size():longest=row
 check(longest.get("samples",[]).size()>5,"river follows several connected terrain segments")
 if longest.is_empty():quit(1);return
 var monotone:=true
 for i in range(1,longest.samples.size()):
  if longest.samples[i].y>longest.samples[i-1].y+.001:monotone=false
 check(monotone,"river water does not flow uphill")
 check(hydro.tiles.size()<=19,"catchment count bounded")
 var field:=surface.terrain.field
 var q: Vector3=longest.samples[longest.samples.size()/2]
 var before:=field.height(q.x,q.z)
 var seed_a:=FrontierSurfaceDrainage.source(field,Vector2i(1,1),0,hydro.cfg)
 var seed_b:=FrontierSurfaceDrainage.source(field,Vector2i(1,1),0,hydro.cfg)
 check(seed_a==seed_b,"same seed produces same catchment source")
 check(not FrontierSurfaceDrainage.liquid({"water":80,"pressure":0,"temperature":20}) and not FrontierSurfaceDrainage.liquid({"water":80,"pressure":1,"temperature":-10}),"vacuum and ice worlds do not create liquid water")
 var out:=ProjectSettings.globalize_path("res://../docs/production/media/surface-hydrology")
 DirAccess.make_dir_recursive_absolute(out)
 var camera:=Camera3D.new();app.add_child(camera);camera.far=1400;camera.fov=65;camera.make_current()
 surface.atmosphere.cycles={};surface.atmosphere.daylight=1;surface.atmosphere.sun.rotation_degrees=Vector3(-45,-35,0);surface.atmosphere.sun.light_energy=1.8
 surface.viewer.position=q+Vector3(4,.5,4);surface.viewer.position.y=field.height(surface.viewer.position.x,surface.viewer.position.z)+.2
 app.session.authority.update_position(1,surface.viewer.position);app.session._publish()
 await until(func():return surface.terrain.ready_at(surface.viewer.position+Vector3.UP),"river bank terrain streamed",35)
 camera.position=q+Vector3(28,26,28);camera.look_at(q)
 await create_timer(2).timeout;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"/river.png")
 var recorder:=AudioEffectRecord.new();recorder.format=AudioStreamWAV.FORMAT_16_BITS;AudioServer.add_bus_effect(0,recorder);recorder.set_recording_active(true)
 presence.scenery.sample();presence.sounds.sample_left=0
 await create_timer(3).timeout
 check(float(presence.scenery.water.distance)<30,"water sound is attached to nearby generated water")
 check(presence.sounds.water_sources.river.playing,"new ElevenLabs river source plays at river bank")
 var ocean_at:=Vector3.INF
 for x in range(-600,601,24):
  for z in range(-600,601,24):
   var h:=field.height(x,z)
   if h< -4.2 and h> -6:ocean_at=Vector3(x,-4,z);break
  if ocean_at.is_finite():break
 check(ocean_at.is_finite(),"seeded terrain contains an ocean shoreline")
 if ocean_at.is_finite():
  surface.viewer.position=ocean_at+Vector3(6,1,6);app.session.authority.update_position(1,surface.viewer.position);app.session._publish()
  camera.position=ocean_at+Vector3(50,30,50);camera.look_at(ocean_at)
  await create_timer(4).timeout;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"/ocean.png")
 recorder.set_recording_active(false);var recording:=recorder.get_recording();recording.save_to_wav("/tmp/surface-hydrology-mix.wav");AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
 check(recording.data.size()>48000,"actual game audio signal captured")
 check(field.height(q.x,q.z)==before,"water presentation preserves existing terrain height")
 check(presence.scenery.haze.multimesh.instance_count==12 and presence.scenery.motes.multimesh.instance_count==48,"midground and interaction effect pools bounded")
 presence.mark(Vector3(15,2,15),Vector3.FORWARD,3);check(not presence.traces.is_empty(),"lasting landing wash mark can be rendered")
 app.open_menu(app.inventory_panel);var old_time:=presence.clock_value;await create_timer(.3).timeout
 check(is_equal_approx(old_time,presence.clock_value) and (not presence.sounds.water_sources.river.playing or presence.sounds.water_sources.river.stream_paused),"menu freezes effect time and water sound")
 app.close_menus()
 var report: Dictionary={"checks":checks,"failures":failures,"body_id":body.id,"river_segments":longest.samples.size(),"catchments":hydro.tiles.size(),"maximum_hydrology_step_ms":hydro.maximum_step_usec/1000.0,"note":"Hydrology scheduling, shoreline, tracing and mesh install; not whole-game FPS."}
 FileAccess.open(out+"/verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 check(await app.session.close_session(),"world saves and closes")
 app.queue_free();await process_frame
 print("SURFACE_HYDROLOGY_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
