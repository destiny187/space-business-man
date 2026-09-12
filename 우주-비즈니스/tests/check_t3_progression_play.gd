extends "res://tests/check_exploration_discovery_play.gd"
func run() -> void:
 var runtime:="/tmp/t3-progression-play"
 if not "--crew-folder=/tmp/t3-progression-play" in OS.get_cmdline_user_args() or not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
 folder=ProjectSettings.globalize_path("res://../docs/production/media/t3-progression")
 var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(runtime+"/fixture.json"))
 var row: Dictionary=fixture.archive
 var store:=FrontierWorldStore.new(runtime+"/world.json");var prepared:=store.read_state()
 prepared.discoveries.records.erase(FrontierExplorationDiscoveries.record_key(row));prepared.expedition_research.licenses.erase(fixture.design)
 if not store.write(prepared):quit(2);return
 root.size=Vector2i(1280,800);root.content_scale_size=root.size
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"Forward+ loaded T3 field",90):quit(1);return
 app.close_menus();app.onboarding.letter.hide();FrontierClientSettings.ensure(self).values.tutorial_mode=2;app.outside=false;app.exterior_view.hide();app.if_flight_view()
 var id: String=app.session.latest.self_id;var actor: CharacterBody3D=app.actors[id];var surface:=app.surface_world
 var view: FrontierDiscoveryView=surface.discoveries
 # Reconnect intentionally leaves carried materials in a preserved field crate.
 # These are isolated recovery supplies, not rewards or a free normal-play grant.
 app.session.authority.world.business.bags[id]["control_circuit"]=1
 app.session.authority.world.business.bags[id]["refined_copper"]=2
 app.session._publish()
 var base:=FrontierCrewWorld.vector(row.position)
 look(actor,base+Vector3(0,0,6).rotated(Vector3.UP,float(row.yaw)),base+Vector3.UP)
 if not await until(func():return surface.ready_at(actor.position) and view.models.has(row.id),"actual archive model and collision streamed",80):quit(1);return
 await capture("archive-before")
 for index in 3:
  var at:=FrontierExplorationDiscoveries.work_point(row,index)
  var pos:=at+Vector3(0,0,2.4).rotated(Vector3.UP,float(row.yaw))
  pos.y=surface.terrain.field.height(pos.x,pos.z)+.1
  app.session.authority.world.crew.members[id].position=FrontierExpeditionBusiness.array(pos)
  var aim: Vector3=(at-pos-Vector3.UP*1.72).normalized()
  actor.position=FrontierCrewWorld.vector(app.session.authority.world.crew.members[id].position)
  app.yaw=atan2(-aim.x,-aim.z);app.pitch=asin(aim.y)
  await create_timer(.4).timeout;app.test_scan=true
  var known:=await until(func():return FrontierExplorationDiscoveries.known(app.session.authority.world,row),"held E scans archive stage "+str(index),12)
  app.test_scan=false
  if not known:break
  await create_timer(.25).timeout
  var key:=InputEventKey.new();key.pressed=true;key.physical_keycode=KEY_F;app._unhandled_input(key)
  if not await until(func():return FrontierExplorationDiscoveries.stage(app.session.authority.world,row)==index+1,"F commits recovery stage "+str(index),6):break
  if index==1:
   await create_timer(.5).timeout
   check(view.models[row.id].get_node("ArchiveProjection").visible,"powered blueprint projection appears after host repair")
   look(actor,base+Vector3(5,0,7).rotated(Vector3.UP,float(row.yaw)),base+Vector3.UP*1.2);await capture("archive-powered")
 check(FrontierFacilityBlueprints.owned(app.session.authority.world,fixture.design),"recovered design usable by the crew")
 app.toggle_research();app.research_frame.tabs.current_tab=1;app.survey_journal.category.select(3);app.survey_journal.refresh();await create_timer(.5).timeout;await capture("archive-journal")
 check(app.feedback.blocked(),"journal blocks tools");app.close_menus()
 var peak:=-100.0;view.audio.play("ui_discovery",actor.position)
 for i in 10:
  await create_timer(.08).timeout;peak=maxf(peak,AudioServer.get_bus_peak_volume_left_db(AudioServer.get_bus_index("SFX"),0))
 check(peak> -75,"ElevenLabs recovery audio bus active")
 app.toggle_navigation();app.planet_map.modes.current_tab=1;app.planet_map.refresh();app.planet_map.terraform.layer=4;app.planet_map.terraform.refresh()
 root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("supply-empty-960")
 check(app.planet_map.terraform.info.get_global_rect().end.y<640,"supply plan fits 960px");app.close_menus()
 check(await app.session.close_session(),"live archive stored to disk")
 check(not FrontierWorldStore.new(runtime+"/world.json").read_state().is_empty(),"saved recovery reloads")
 app.queue_free();await process_frame;print("T3_ARCHIVE_PLAY ",checks," CHECKS / ",failures," FAILURES");quit(1 if failures else 0)
