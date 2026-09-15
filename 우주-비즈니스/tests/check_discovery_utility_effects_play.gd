extends "res://tests/test_solo_entry.gd"
func run() -> void:
 folder="/tmp/discovery-utilities-play"
 if "--crew-ui-test" not in OS.get_cmdline_user_args() or "--crew-folder="+folder not in OS.get_cmdline_user_args():quit(2);return
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"effect fixture ready",90):quit(1);return
 app.onboarding.letter.hide();app.onboarding.set_process(false);app.onboarding.hide();app.close_menus();app.set_physics_process(false);app.set_process(false)
 root.size=Vector2i(960,640);root.content_scale_size=root.size;await create_timer(.4).timeout
 var core:=app.session.authority
 app.session.set_physics_process(false)
 if core.autonomous_pending():await until(func():return core.resolve_autonomous(),"finish pending simulation before controlled inputs",10)
 var world: Dictionary=core.world;var site:=FrontierExpeditionBusiness.site(world);var actor: String=world.crew.owner_id
 var ids: Dictionary={}
 for b in site.buildings.values():
  if FrontierDiscoveryUtilities.building(b.type):ids[b.type]=b.id;b.enabled=true
  else:b.enabled=false
 var tank: Dictionary=site.buildings[ids.luminous_vivarium];var garden: Dictionary=site.buildings[ids.resonance_garden];var alarm: Dictionary=site.buildings[ids.flood_sentinel];var shell: Dictionary=site.buildings[ids.shell_refuge]
 var field:=app.surface_world.terrain.field
 var standing:=FrontierCrewWorld.vector(tank.position)+Vector3(0,0,3)
 world.crew.members[actor].position=FrontierExpeditionBusiness.array(standing);app.actors[actor].position=standing
 site.environment.temperature=20;alarm.muted=false;garden.muted=false
 FrontierExpeditionIndustry.power(world,site);FrontierDiscoveryUtilities.tick(world,site,1.1);app.session._publish();app.session._publish_surface()
 if not await until(func():return app.surface_world.business_view.nodes.has(tank.id),"utility model ready",30):quit(1);return
 var tank_view: FrontierDiscoveryUtilityView=app.surface_world.business_view.nodes[tank.id].get_node("DiscoveryUtility")
 await until(func():return tank.active and tank_view.lamp.visible,"installed specimen lights actual scene",5)
 site.environment.temperature=60;FrontierExpeditionIndustry.power(world,site);FrontierDiscoveryUtilities.tick(world,site,1.1);app.session._publish();app.session._publish_surface()
 await until(func():return not tank.active and not tank_view.lamp.visible,"temperature failure darkens actual lamp",5)
 if "--temperature-only" in OS.get_cmdline_user_args():
  site.environment.temperature=20;tank.enabled=false;FrontierExpeditionIndustry.power(world,site);FrontierDiscoveryUtilities.tick(world,site,1.1);app.session._publish();app.session._publish_surface()
  await until(func():return not tank_view.lamp.visible,"disabled power leaves culture dark",3)
  tank.enabled=true
  app.toggle_research();app.research_frame.ecology.get_parent().current_tab=1;await process_frame
  var page:=FrontierDiscoveryIndex.page(core.world,"","discovery","",0);var journal: FrontierSurveyJournal=app.survey_journal;var shown:=false
  for entry in page.entries:
   if entry.row.template!="luminous_tidepool":continue
   journal.select(entry);await process_frame
   for label in journal.details.get_children():
    if label is Label and label.text.contains("실용 설비") and label.text.contains("1kW") and label.text.contains("55°C"):shown=true
   await capture("journal-utility");break
  check(shown,"actual J detail includes utility power and temperature conditions")
  app.close_menus()
  standing=FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position)+Vector3(3,0,3);standing.y=field.height(standing.x,standing.z)+.1
  world.crew.members[actor].position=FrontierExpeditionBusiness.array(standing);app.actors[actor].position=standing;world.business.facility_research.erase("shell_refuge");world.business.bags[actor].iron=6;world.business.bags[actor].copper=4
  app.session._publish();app.session._publish_surface();app.open_station("ship");app.business_panel.vessel_terminal.cards.research.pressed.emit();await process_frame
  var research: FrontierFacilityResearchPanel=app.stations.research_tabs.get_child(1);research.category.select(0);research.selected="shell_refuge";research.signature="";research.refresh()
  await until(func():return not research.action.disabled,"research settles on actionable completed proof",5)
  world.business.facility_research.append("shell_refuge")
  app.close_menus();check(await app.session.close_session(),"focused utility verification saves")
  app.queue_free();await process_frame;print("UTILITY_TEMPERATURE checks ",checks," failures ",failures);quit(1 if failures else 0);return
 site.environment.temperature=20
 var water_before: Dictionary=world.surface_water.get(world.location,FrontierSurfaceWater.create()).duplicate(true)
 var p:=FrontierCrewWorld.vector(shell.position)+Vector3.UP*.1
 world.surface_water[world.location]=FrontierSurfaceWater.create();world.surface_water[world.location].cells[FrontierSurfaceWater.key(FrontierSurfaceWater.cell(p))]=[1.,0.]
 standing=FrontierCrewWorld.vector(alarm.position)+Vector3(0,0,3);world.crew.members[actor].position=FrontierExpeditionBusiness.array(standing);app.actors[actor].position=standing
 FrontierExpeditionIndustry.power(world,site);FrontierDiscoveryUtilities.tick(world,site,1.1);app.session._publish();app.session._publish_surface()
 var alarm_view: FrontierDiscoveryUtilityView=app.surface_world.business_view.nodes[alarm.id].get_node("DiscoveryUtility")
 print("ALARM DEBUG ",alarm," distance ",p.distance_to(FrontierCrewWorld.vector(alarm.position)))
 await until(func():return alarm.active and not alarm.get("alarm_target","").is_empty() and alarm_view.cooldown>0,"actual water produces alarm audio event",5)
 await until(func():return alarm_view.lamp.visible,"alarm beacon flashes",2)
 app.camera.set_as_top_level(true);app.camera.position=FrontierCrewWorld.vector(alarm.position)+Vector3(3,2.7,-4);app.camera.look_at(FrontierCrewWorld.vector(alarm.position)+Vector3.UP);await capture("active-alarm")
 app.open_station("flood_sentinel",alarm.id);await create_timer(.3).timeout
 await until(func():return not alarm_view.speaker.playing,"open menu blocks alarm audio",3)
 var controls:=app.business_panel.utility_panel;controls.mute.pressed.emit()
 await until(func():return FrontierExpeditionBusiness.site(core.world).buildings[alarm.id].muted,"accepted alarm mute",20)
 app.close_menus();await create_timer(.3).timeout
 check(not alarm_view.speaker.playing,"muted alarm remains silent")
 world=core.world;site=FrontierExpeditionBusiness.site(world);alarm=site.buildings[alarm.id];garden=site.buildings[garden.id];tank=site.buildings[tank.id]
 world.surface_water[world.location]=water_before;FrontierDiscoveryUtilities.tick(world,site,1.1);app.session._publish();app.session._publish_surface()
 check(alarm.alarm_target.is_empty(),"dry foundation clears alarm")
 standing=FrontierCrewWorld.vector(garden.position)+Vector3(0,0,3);world.crew.members[actor].position=FrontierExpeditionBusiness.array(standing);app.actors[actor].position=standing;app.session._publish();app.session._publish_surface()
 var garden_view: FrontierDiscoveryUtilityView=app.surface_world.business_view.nodes[garden.id].get_node("DiscoveryUtility")
 await until(func():return garden_view.speaker.playing,"proximity resonance starts",5)
 app.open_station("resonance_garden",garden.id);await create_timer(.3).timeout
 await until(func():return not garden_view.speaker.playing,"menu blocks resonance",3)
 var next_tone: int=(int(garden.get("resonance_tone",1))+1)%3
 controls.tone.pressed.emit();await until(func():return FrontierExpeditionBusiness.site(core.world).buildings[garden.id].get("resonance_tone",1)==next_tone,"tone request accepted",20)
 app.close_menus();await until(func():return garden_view.speaker.playing and is_equal_approx(garden_view.speaker.pitch_scale,float(FrontierDiscoveryUtilities.config().garden.pitches[next_tone])),"resonance uses accepted pitch",5)
 # Actual F inventory operations and small-window layout, using the installed sample.
 world=core.world;tank=FrontierExpeditionBusiness.site(world).buildings[tank.id]
 standing=FrontierCrewWorld.vector(tank.position)+Vector3(0,0,3);world.crew.members[actor].position=FrontierExpeditionBusiness.array(standing);app.actors[actor].position=standing;app.session._publish();app.open_station("luminous_vivarium",tank.id);await create_timer(.3).timeout
 controls.remove_sample.pressed.emit();await until(func():return FrontierExpeditionBusiness.site(core.world).buildings[tank.id].get("specimen_stock",{}).is_empty(),"F recovers original sample",20)
 await create_timer(.3).timeout;await capture("culture-controls-960")
 check(controls.sample.size.y<60,"sample icon stays compact")
 check(controls.install.get_global_rect().end.y<=640,"install action is visible in 960 window")
 controls.install.pressed.emit();await until(func():return not FrontierExpeditionBusiness.site(core.world).buildings[tank.id].get("specimen_stock",{}).is_empty(),"same specimen reinstalled",20)
 app.close_menus();check(await app.session.close_session(),"functional states save")
 var loaded:=FrontierWorldStore.new(folder+"/world.json").read_state()
 check(not loaded.is_empty() and FrontierSpecimenItems.validate(loaded).is_empty(),"specimen integrity survives reload")
 app.queue_free();await process_frame;print("UTILITY_EFFECTS checks ",checks," failures ",failures);quit(1 if failures else 0)
