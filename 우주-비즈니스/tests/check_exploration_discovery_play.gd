extends "res://tests/check_lotus_play.gd"
func run() -> void:
 folder="/tmp/exploration-discovery-play"
 if "--crew-folder=/tmp/exploration-discovery-play" not in OS.get_cmdline_user_args() or "--crew-ui-test" not in OS.get_cmdline_user_args():quit(2);return
 var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"/fixture.json"))
 var store:=FrontierWorldStore.new(folder+"/world.json");var world:=store.read_state()
 var id: String=world.crew.owner_id;var owner: Dictionary=world.crew.members[id].profile
 var row: Dictionary=fixture.rows.hollow_geode;var ordinal:=int(fixture.ordinals.hollow_geode);var body:=FrontierUniverse.body(world.manifest,ordinal)
 world.location=body.id;world.navigation_target=body.id;world.crew.landing.body_id=body.id;world.crew.navigation.target=ordinal;world.crew.navigation.system=body.system_ordinal
 world.discoveries.records.erase(FrontierExplorationDiscoveries.record_key(row))
 world.crew.members[id].loadout.selected=1
 check(store.write(world),"isolated geode fixture "+store.last_error)
 var profile:=FrontierPlayerProfile.new(folder+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
 root.size=Vector2i(1280,800);root.content_scale_size=root.size
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"Forward+ exploration ready",75):quit(1);return
 app.close_menus();app.onboarding.letter.hide();FrontierClientSettings.ensure(self).values.tutorial_mode=2;app.outside=false;app.exterior_view.hide();app.if_flight_view()
 var actor: CharacterBody3D=app.actors[id];var s:=app.surface_world;var view: FrontierDiscoveryView=s.discoveries
 var base:=FrontierCrewWorld.vector(row.position)
 look(actor,base+Vector3(0,0,-6).rotated(Vector3.UP,float(row.yaw)),FrontierExplorationDiscoveries.work_point(row,0))
 app.session._publish()
 if not await until(func():return s.ready_at(actor.position) and view.models.has(row.id),"actual streamed discovery collider ready",45):
  print("DISCOVERY_DEBUG ",actor.position," viewer ",s.viewer.position," row ",row," ready ",s.ready_at(actor.position)," models ",view.models.keys()," rows ",view.rows.keys());await capture("missing");quit(1);return
 s.atmosphere.cycles={};s.atmosphere.sun.rotation_degrees=Vector3(-42,-30,0);s.atmosphere.sun.light_energy=1.5
 var output:=ProjectSettings.globalize_path("res://../docs/production/media/exploration-t2")
 var original_folder:=folder;folder=output
 await capture("geode-before")
 # Positioning fixture only; E scan and F operation remain the real input/request path.
 for index in 3:
  var aim: Vector3=point_actor(app.session.authority,row,index)
  actor.position=FrontierCrewWorld.vector(app.session.authority.world.crew.members[id].position)
  app.yaw=atan2(-aim.x,-aim.z);app.pitch=asin(aim.y)
  await create_timer(.3).timeout
  app.test_scan=true
  var scanned:=await until(func():return FrontierExplorationDiscoveries.known(app.session.authority.world,row),"held scanner stage "+str(index),8)
  app.test_scan=false
  if not scanned:break
  await create_timer(.25).timeout
  var key:=InputEventKey.new();key.pressed=true;key.physical_keycode=KEY_F;app._unhandled_input(key)
  if not await until(func():return FrontierExplorationDiscoveries.stage(app.session.authority.world,row)==index+1,"F commits stage "+str(index),4):break
  if index==1:
   await create_timer(1.0).timeout
   var covers: Array= view.models[row.id].find_children("Anim_Cover*","Node3D",true,false)
   check(not covers.is_empty() and covers.all(func(n):return not n.visible),"geode crust removed in live model")
   look(actor,base+Vector3(0,0,-6).rotated(Vector3.UP,float(row.yaw)),base+Vector3.UP)
   await capture("geode-open")
 check(FrontierExplorationDiscoveries.progress(app.session.authority.world,row).get("claimed",false),"physical gemstone reward")
 check(view.audio.stream("sfx_discovery_excavate")!=null and view.audio.stream("amb_discovery_resonance",true)!=null,"generated ElevenLabs streams load")
 view.audio.play("sfx_discovery_excavate",actor.position)
 var peak:=-100.0
 for i in 12:
  await create_timer(.08).timeout
  peak=maxf(peak,AudioServer.get_bus_peak_volume_left_db(AudioServer.get_bus_index("SFX"),0))
 check(peak> -75,"game sound bus active: "+str(peak))
 root.size=Vector2i(960,640);root.content_scale_size=root.size
 app.toggle_research();app.research_frame.tabs.current_tab=1;app.survey_journal.category.select(3);app.survey_journal.refresh();await capture("journal-960")
 check(app.feedback.blocked(),"journal blocks tool input")
 await create_timer(.2).timeout;check(view.ambience.stream_paused and not view.hint.visible,"discovery sound and hint paused in menu")
 check(await app.session.close_session(),"save actual play")
 check(not FrontierWorldStore.new(original_folder+"/world.json").read_state().is_empty(),"real disk readback")
 app.queue_free();await process_frame;print("DISCOVERY_PLAY ",checks," FAILURES ",failures);quit(1 if failures else 0)

func point_actor(core: FrontierCrewAuthority,row: Dictionary,index: int) -> Vector3:
 var at:=FrontierExplorationDiscoveries.work_point(row,index)
 var field:=FrontierCrewSurface.field(core.world)
 var member: Dictionary=core.world.crew.members[core.peers[1]]
 for i in 16:
  var pos:=at+Vector3(sin(i*TAU/16+float(row.yaw)+PI)*2.4,0,cos(i*TAU/16+float(row.yaw)+PI)*2.4);pos.y=field.height(pos.x,pos.z)+.1
  member.position=FrontierExpeditionBusiness.array(pos)
  var aim: Vector3=(at-pos-Vector3.UP*1.72).normalized()
  if FrontierExplorationDiscoveries.target(core.world,core.peers[1],aim).get("id")==row.id:return aim
 return Vector3.ZERO
