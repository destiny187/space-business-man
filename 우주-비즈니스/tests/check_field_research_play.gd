extends "res://tests/test_solo_entry.gd"
func run() -> void:
 folder="/tmp/playtest-field-research"
 if "--crew-ui-test" not in OS.get_cmdline_user_args() or "--crew-folder="+folder not in OS.get_cmdline_user_args():quit(2);return
 DirAccess.make_dir_recursive_absolute(folder)
 var owner:=FrontierPlayerProfile.new_character("공동 설비 진입 확인",0)
 var core:=FrontierCrewAuthority.new()
 check(core.start(FrontierUniverse.new_world(71503),owner,func(_world):return true),"isolated solo host")
 var world: Dictionary=core.world
 var body: Dictionary={}
 for ordinal in range(8,200):
  var candidate:=FrontierUniverse.body(world.manifest,ordinal)
  if FrontierUniverse.landable(candidate) and int(candidate.planet_tier)==1:body=candidate;break
 if body.is_empty():quit(1);return
 var actor: String=owner.character_id
 var nav: Dictionary=world.crew.navigation
 nav.system=body.system_ordinal;nav.target=body.ordinal;nav.mode="idle";nav.erase("solar_opening")
 nav.position=FrontierExpeditionBusiness.array(FrontierCrewNavigation.center(body.ordinal,world.manifest,float(nav.orbit_time))+Vector3.UP*(FrontierUniverse.navigation_radius(body)+2))
 world.crew.members[actor].ready=true;core.phase="playing";world.crew.phase="playing"
 var reason:=FrontierCrewSurface.apply(world,actor,"land",{"ordinal":body.ordinal},{1:actor})
 check(reason.is_empty(),"landed fixture "+reason)
 var store:=FrontierWorldStore.new(folder+"/world.json")
 check(store.write(world),"save isolated landing "+store.last_error)
 var profile:=FrontierPlayerProfile.new(folder+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
 root.size=Vector2i(1280,800)
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"actual landed solo scene",90):quit(1);return
 app.onboarding.letter.hide();app.close_menus();core=app.session.authority;world=core.world
 var point:=FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position)+Vector3(3,0,3)
 point.y=app.surface_world.terrain.field.height(point.x,point.z)+.1
 world.crew.members[actor].position=FrontierExpeditionBusiness.array(point);app.actors[actor].position=point
 world.business.facility_research=[];world.business.credits=600
 world.business.bags[actor]=FrontierExpeditionBusiness.inventory()
 app.session._publish();await process_frame
 app.toggle_business();app.business_panel.refresh_building_cost()
 var cards: Dictionary=app.business_panel.building_cards
 var identity: int=cards.factory.get_instance_id()
 check(not cards.factory.visible,"unresearched factory is absent from B")
 check(cards.solar.visible,"unlocked solar remains visible without materials")
 app.close_menus();app.open_station("ship")
 app.business_panel.vessel_terminal.cards.research.pressed.emit()
 await process_frame
 check(app.stations.panel.visible and not app.research_frame.visible,"actual ship research button opens device instead of J journal")
 var research: FrontierFacilityResearchPanel=app.stations.research_tabs.get_child(1)
 check(research.is_visible_in_tree() and research.title.text=="자동 조립 설비","shared equipment research directly exposes factory license")
 var cost: Dictionary=FrontierFacilityResearch.config().projects.factory.cost
 for id in cost:world.business.bags[actor][id]=cost[id]
 app.session._publish();research.refresh();await process_frame
 if not await until(func():return not research.action.disabled,"host research enabled after material snapshot",10):quit(1);return
 root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("research-960")
 check(research.action.get_global_rect().end.y<=640 and research.action.get_global_rect().end.x<=960,"research action fits small window")
 research.action.pressed.emit()
 if not await until(func():return FrontierFacilityResearch.owned(core.world.business,"factory"),"research purchase commits",15):quit(1);return
 app.close_menus();app.toggle_business();app.business_panel.refresh_building_cost();await capture("build-after-research-960")
 check(cards.factory.visible and cards.factory.get_instance_id()==identity,"same factory card unlocks after research without rebuilding grid")
 check(not FrontierExpeditionBusiness.affordable(core.world.business.bags[actor],FrontierFacilityResearch.construction("factory").cost),"insufficient construction materials do not hide unlocked factory")
 check(int(core.world.business.credits)==0,"research charged once")
 check(await app.session.close_session(),"research saves")
 var loaded:=store.read_state();check(FrontierFacilityResearch.owned(loaded.business,"factory"),"factory research survives reload")
 app.queue_free();await process_frame;print("FIELD_RESEARCH checks ",checks," failures ",failures);quit(1 if failures else 0)
