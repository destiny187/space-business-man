extends "res://tests/test_solo_entry.gd"
func run() -> void:
 folder="/tmp/surface-recovery-20260909"
 if "--crew-folder=/tmp/surface-recovery-20260909" not in OS.get_cmdline_user_args():quit(2);return
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
 app.travel_action("land")
 if not await until(func():return app.surface_world!=null and not app.arrival.active,"landing completes",90):quit(1);return
 var surface:=app.surface_world;var presence:=surface.presence
 check(presence!=null,"surface presence connected")
 var out:=ProjectSettings.globalize_path("res://../docs/production/media/surface-recovery")
 DirAccess.make_dir_recursive_absolute(out)
 var site:=FrontierExpeditionBusiness.site(app.session.authority.world)
 var original: Dictionary=site.environment.duplicate(true)
 var camera:=Camera3D.new();app.add_child(camera);camera.far=1500;camera.fov=65
 camera.position=Vector3(55,22,65);camera.look_at(Vector3(5,0,0));camera.make_current()
 # A fixed sun phase isolates restoration differences; production keeps its shared sky clock.
 surface.atmosphere.cycles={};surface.atmosphere.daylight=1;surface.atmosphere.sun.rotation_degrees=Vector3(-45,-35,0);surface.atmosphere.sun.light_energy=1.8
 var stages: Array=[{"pressure":.12,"toxicity":65.,"temperature":38.,"water":3.,"ecology":0.},{"pressure":1.,"toxicity":5.,"temperature":18.,"water":42.,"ecology":35.},{"pressure":1.,"toxicity":0.,"temperature":18.,"water":75.,"ecology":95.}]
 var recorder:=AudioEffectRecord.new();recorder.format=AudioStreamWAV.FORMAT_16_BITS;AudioServer.add_bus_effect(0,recorder);recorder.set_recording_active(true)
 var counts: Array=[]
 for index in stages.size():
  for key in stages[index]:site.environment[key]=stages[index][key]
  if site.has("restoration2"):site.restoration2.soil=15+index*42;site.restoration2.salinity=60-index*28
  app.session._publish_surface();await process_frame
  if not await until(func():return presence.assets_ready,"existing Blender assets ready",20):quit(1);return
  for step in 55:
   presence._process(1.0);surface.atmosphere.step(1.0,surface.viewer.position,0,1);await process_frame
  var grass:=0;var trees:=0;var wet:=0
  for row in presence.patches:
   if row.valid and row.growth>.05:grass+=1
   if row.valid and row.wood>.05:trees+=1
  for row in presence.ponds:
   if row.valid and row.strength>.1:wet+=1
  counts.append({"grass":grass,"trees":trees,"water":wet})
  await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"/stage-"+str(index)+".png")
  print("RECOVERY_STAGE ",index," ",counts[-1])
 check(counts[0].grass==0 and counts[1].grass>0 and counts[2].trees>0,"barren to pioneer cover to trees")
 check(counts[2].water>0,"wet ground appears from actual regional water")
 check(presence.sounds.creature_sources.size()>0 or float(presence.sounds.gains.nature)<.001,"no fauna ambience without actual animals")
 check(not app.feedback.audio.ambient.playing,"old threshold ambience does not double the mix")
 var grown: Dictionary={}
 for row in presence.patches:
  if row.valid and row.growth>.7:grown=row;break
 if not grown.is_empty():
  var actor: CharacterBody3D=surface.viewer
  actor.position=grown.node.position+Vector3(2,.2,2);app.session.authority.update_position(1,actor.position);app.session._publish()
  camera.position=actor.position+Vector3(9,4,10);camera.look_at(grown.node.position+Vector3.UP)
  await create_timer(2).timeout
  check(presence.sounds.layers.foliage.playing,"new ElevenLabs foliage follows grown patch proximity")
  await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"/grown-close.png")
 var wet_row: Dictionary={}
 for row in presence.ponds:
  if row.valid:wet_row=row;break
 if not wet_row.is_empty():
  surface.viewer.position=wet_row.node.position+Vector3(0,.1,1);app.session.authority.update_position(1,surface.viewer.position);app.session._publish()
  await create_timer(2).timeout;check(presence.sounds.layers.water.playing,"new ElevenLabs water follows actual visible wet patch")
 presence.sounds._event("ice",surface.viewer.position+Vector3(3,0,0),-25);await create_timer(.4).timeout
 check(presence.sounds.event_count>0,"new ElevenLabs ice event can play at a world position")
 recorder.set_recording_active(false);var recording:=recorder.get_recording();recording.save_to_wav("/tmp/surface-recovery-mix.wav")
 check(recording.data.size()>48000,"game mix recorded")
 var at: Vector3=Vector3(15,0,15);at.y=surface.terrain.field.height(at.x,at.z)
 presence.mark(at,Vector3.FORWARD);check(presence.traces.size()>0,"surface trace drawn")
 camera.position=at+Vector3(2,3,4);camera.look_at(at);await create_timer(.3).timeout;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"/trace.png")
 app.open_menu(app.inventory_panel);await process_frame;presence.sounds.update(.1,true)
 check(presence.sounds.layers.wind.stream_paused,"menu pauses new ambience")
 app.close_menus()
 var frozen:=FrontierSurfaceRecovery.conditions({"pressure":0.,"water":80.,"temperature":-50.,"toxicity":0.,"ecology":100.})
 check(frozen.grass==0 and frozen.wet==0,"vacuum and frozen conditions reject green cover and liquid")
 check(FrontierSurfaceRecovery.weight(Vector3(1000,0,0),presence.region.center,presence.region.radius)==0,"restoration stays regional")
 for key in original:site.environment[key]=original[key]
 check(await app.session.close_session(),"isolated save closes")
 app.queue_free();await process_frame;await process_frame
 var file:=FileAccess.open(out+"/verification.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"stages":counts,"fixture":"actual landing, host regional environment samples, accelerated presentation only; fixed daytime comparison"},"  "));file.close()
 print("SURFACE_RECOVERY CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
