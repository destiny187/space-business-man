extends "res://tests/test_solo_entry.gd"
func run() -> void:
 folder="/tmp/discovery-industry-play"
 if "--crew-ui-test" not in OS.get_cmdline_user_args() or "--crew-folder="+folder not in OS.get_cmdline_user_args():quit(2);return
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"resume built discovery facilities",90):quit(1);return
 app.onboarding.letter.hide();app.onboarding.set_process(false);app.onboarding.hide();app.close_menus();app.set_physics_process(false);app.set_process(false)
 root.size=Vector2i(960,640);root.content_scale_size=root.size
 var core:=app.session.authority;var world: Dictionary=core.world;var actor: String=app.session.latest.self_id
 var site:=FrontierExpeditionBusiness.site(world);var b: Dictionary={}
 for row in site.buildings.values():
  if row.type=="dew_condenser":b=row;break
 if b.is_empty():check(false,"saved condenser exists");quit(1);return
 var p:=FrontierCrewWorld.vector(b.position)+Vector3(0,0,6);p.y=app.surface_world.terrain.field.height(p.x,p.z)+.1
 world.crew.members[actor].position=FrontierExpeditionBusiness.array(p);app.actors[actor].position=p
 app.camera.set_as_top_level(true);app.camera.position=FrontierCrewWorld.vector(b.position)+Vector3(5,4,-7);app.camera.look_at(FrontierCrewWorld.vector(b.position)+Vector3.UP)
 app.session._publish();await process_frame
 app.open_station("dew_condenser",b.id)
 var panel:=app.business_panel.production_panel
 await until(func():return panel.upgrade.text=="강화 완료","completed enhancement UI after resume",5)
 check(panel.is_visible_in_tree() and not panel.description.text.contains("Mk."),"F opens completed operational panel without Mk labels")
 check(panel.upgrade.disabled,"no extra enhancement action")
 check(not panel.upgrade.get_parent().get_parent() is ScrollContainer,"enhancement state remains outside scroll")
 await capture("enhancement-complete")
 app.close_menus();await until(func():return app.surface_world.business_view.nodes.has(b.id),"final natural condenser model",20)
 await create_timer(.5).timeout;await capture("enhanced-condenser")
 var visual: Node3D=app.surface_world.business_view.nodes[b.id]
 check(visual.has_meta("tier2_visual") and visual.find_child("Anim_Fan_Condenser",true,false)!=null,"natural model keeps its fan and adds side retrofit")
 for row in FrontierExpeditionBusiness.site(core.world).buildings.values():
  if row.type!="geothermal_generator":continue
  app.camera.position=FrontierCrewWorld.vector(row.position)+Vector3(5,4,-7);app.camera.look_at(FrontierCrewWorld.vector(row.position)+Vector3.UP*1.4)
  await capture("natural-geothermal")
 p=FrontierCrewWorld.vector(b.position)+Vector3(0,0,28);p.y=app.surface_world.terrain.field.height(p.x,p.z)+.1
 app.actors[actor].position=p;app.surface_world.viewer.position=p
 app.surface_world.presence.scenery.sample()
 app.surface_world.presence.sounds.update(1.0,false)
 var sound_ids: Array=[]
 for player in app.surface_world.presence.sounds.machinery:
  if player.playing and not player.stream_paused:sound_ids.append(player.get_meta("sound",""))
 check("sfx_water_loop" in sound_ids and "sfx_thermal_loop" in sound_ids,"existing water and thermal audio streams play for working natural facilities")
 check(await app.session.close_session(),"enhanced discovery facility saves")
 var loaded:=FrontierWorldStore.new(folder+"/world.json").read_state()
 check(not loaded.is_empty() and FrontierFacilityResearch.owned(loaded.business,"dew_condenser") and int(FrontierExpeditionBusiness.site(loaded).buildings[b.id].tier)==2,"licenses and enhanced building reload")
 app.queue_free();await process_frame;print("DISCOVERY_FINISH checks ",checks," failures ",failures);quit(1 if failures else 0)
