extends "res://tests/test_solo_entry.gd"
func run() -> void:
 folder="/tmp/landing-polish-20260909"
 if "--crew-folder=/tmp/landing-polish-20260909" not in OS.get_cmdline_user_args():quit(2);return
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
   if FrontierUniverse.landable(body) and (p.air<.35 if small else p.air>.6):selected={"body":body,"system":system,"ordinal":ordinal};break
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
 var recording:=AudioEffectRecord.new();recording.format=AudioStreamWAV.FORMAT_16_BITS;AudioServer.add_bus_effect(0,recording);recording.set_recording_active(true)
 app.travel_action("land")
 check(app.arrival.active,"host accepted landing: "+app.status.value)
 if not app.arrival.active:quit(1);return
 var prefix: String="finch-thin-air" if small else "kestrel-air"
 var out:=ProjectSettings.globalize_path("res://../docs/production/media/landing-polish")
 var phases: Dictionary={};var end:=Time.get_ticks_msec()+100000
 var mix_peaks: Dictionary={}
 var walk_end:=false
 while app.arrival.active and Time.get_ticks_msec()<end:
  var arrival=app.arrival
  mix_peaks[arrival.phase]=maxf(float(mix_peaks.get(arrival.phase,-100)),AudioServer.get_bus_peak_volume_left_db(0,0))
  if arrival.phase=="descent" and not phases.has("ready"):
   check(app.surface_world.landing_view_ready() and arrival.warm_frames>=8,"render and terrain barrier retained");phases.ready=true
   check(arrival.landing_audio.layers.cooling.stream!=null and arrival.landing_audio.library.stream("sfx_landing_gear_v2")!=null,"new ElevenLabs files loaded")
   check(not app.flight.vessel_sound.layers.reactor.playing,"orbital reactor stopped at entry")
  if arrival.phase=="handover" and not walk_end:
   check(arrival.walker.global_position.distance_to(app.actors[app.session.latest.self_id].position)<.3,"disembark reaches the approved physical character")
   check(arrival.effects.lamp.light_energy>0 and app.surface_world.refits.gear.hatch>.9,"door or canopy and boarding light open")
   walk_end=true
  if arrival.age>(3.0 if arrival.phase=="descent" else (1.7 if arrival.phase=="disembark" else .6)) and not phases.has(arrival.phase):
   phases[arrival.phase]=true;await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(out+"/"+prefix+"-"+arrival.phase+".png")
   print("LANDING_CAPTURE ",prefix," ",arrival.phase)
  await process_frame
 check(not app.arrival.active and walk_end,"landing and physical view handover complete")
 check(app.camera.current and app.surface_world.landing_ship.visible,"camera and source hull restored")
 check(app.surface_world.presentation_points.is_empty(),"temporary preload interests released")
 if small:check(app.arrival.profile.air<.35 and float(app.arrival.flow_material.get_shader_parameter("atmosphere"))<.35,"thin atmosphere reduces cloud flow")
 await create_timer(.25).timeout
 var before: Vector3=app.actors[app.session.latest.self_id].position
 app.test_direction=Vector2(1,0);await create_timer(.4).timeout;app.test_direction=Vector2.ZERO
 check(app.actors[app.session.latest.self_id].position.distance_to(before)>.5,"ground movement restored")
 root.size=Vector2i(960,640);root.content_scale_size=root.size;await create_timer(.2).timeout;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/"+prefix+"-ground-960.png")
 recording.set_recording_active(false)
 var recorded:=recording.get_recording();recorded.save_to_wav("/tmp/"+prefix+"-landing-mix.wav")
 check(recorded.data.size()>48000 and float(mix_peaks.get("touchdown",-100))>-70,"landing mix produces recorded output")
 if "--return-flight" in OS.get_cmdline_user_args():
  var actor: CharacterBody3D=app.actors[app.session.latest.self_id]
  actor.position=app.surface_world.landing_ship.position+Vector3(3,0,3);actor.position.y=app.surface_world.terrain.field.height(actor.position.x,actor.position.z)+.1
  app.session.authority.update_position(1,actor.position);app.session._publish();app.station_action("launch")
  check(app.arrival.active and app.arrival.phase=="ascent","approved return starts ascent")
  var deadline:=Time.get_ticks_msec()+60000
  while app.arrival.active and Time.get_ticks_msec()<deadline:await process_frame
  check(not app.arrival.active and app.surface_world==null and app.outside,"return restores orbital view")
 check(await app.session.close_session(),"isolated save closes")
 app.queue_free();await process_frame;await process_frame
 var file:=FileAccess.open(out+"/"+prefix+"-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"profile":FrontierLandingSurfaceEffects.profile(body),"fixture":"isolated navigation and optional ready FINCH; actual host landing transaction","subjective_listening":false,"master_peak_by_phase_db":mix_peaks},"  "));file.close()
 print("LANDING_POLISH ",prefix," CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
