extends "res://tests/check_lotus_play.gd"
## Focused SP02 field fixture: three branded objects, host E scans, J and saved sightings.
func run() -> void:
	folder="/tmp/corporate-presence-play"
	if "--crew-folder=/tmp/corporate-presence-play" not in OS.get_cmdline_user_args() or "--crew-ui-test" not in OS.get_cmdline_user_args():quit(2);return
	if "--review-only" in OS.get_cmdline_user_args():await review_saved();return
	DirAccess.make_dir_recursive_absolute(folder);root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var owner:=FrontierPlayerProfile.new_character("기업 현장 확인",2)
	var core:=FrontierCrewAuthority.new();check(core.start(FrontierUniverse.new_world(71491),owner,func(_w):return true),"host start")
	var world: Dictionary=core.world
	var ordinal:=FrontierCrewNavigation.first_destination(world.manifest)
	var planet:=FrontierUniverse.body(world.manifest,ordinal)
	world.location=planet.id;world.navigation_target=planet.id;world.crew.navigation.system=planet.system_ordinal;world.crew.navigation.target=ordinal
	world.crew.navigation.position=FrontierExpeditionBusiness.array(FrontierCrewNavigation.center(ordinal,world.manifest,float(world.crew.navigation.orbit_time))+Vector3.UP*(FrontierUniverse.navigation_radius(planet)+1))
	world.crew.members[owner.character_id].ready=true
	check(FrontierCrewSurface.apply(world,owner.character_id,"land",{},{1:owner.character_id}).is_empty(),"land isolated world")
	check(FrontierLotusSupport.apply(world,owner.character_id,"lotus_request",{"resource":"iron"}).is_empty(),"actual Lotus dispatch request")
	FrontierLotusSupport.tick(world,FrontierLotusSupport.duration())
	var crate: Dictionary=world.lotus.crates.values()[0]
	var at:=FrontierCrewWorld.vector(crate.position)
	var field:=FrontierCrewSurface.field(world)
	var miner:=at+Vector3(10,0,0);miner.y=field.height(miner.x,miner.z)
	var robot:=at+Vector3(25,0,0);robot.y=field.height(robot.x,robot.z)
	var site:=FrontierExpeditionBusiness.ensure_site(world)
	site.robots["sp02-miner"]={"id":"sp02-miner","grade":"standard","position":FrontierExpeditionBusiness.array(miner),"battery":100.0,"cargo":FrontierExpeditionBusiness.inventory(),"phase":"idle","target":"","path":[],"status":"작업 선택 대기","work":0.0,"charging":false,"tier":2}
	FrontierRobotWork.ensure(site.robots["sp02-miner"])
	site.robots["sp02-miner"].region_id=FrontierRegionalTerraform.region_id(site,miner)
	if not site.regions.has(site.robots["sp02-miner"].region_id):site.regions[site.robots["sp02-miner"].region_id]=FrontierFreeTerraform.district(site,site.robots["sp02-miner"].region_id)
	var row:=FrontierExplorationIncidents.create({"id":"incident:sp02:robot","template":"illuti_dormant_combat_robot","body_id":planet.id,"position":FrontierExpeditionBusiness.array(robot),"relay":FrontierExpeditionBusiness.array(robot+Vector3(0,0,8)),"battery_position":FrontierExpeditionBusiness.array(robot),"path":[],"yaw":0.0,"tier":2})
	row.materialized=true;world.incidents.records[FrontierExplorationIncidents.key(row)]=row
	check(FrontierCorporations.records(world).is_empty(),"old-format world reveals no unseen company")
	var store:=FrontierWorldStore.new(folder+"/world.json");check(store.write(world),"fixture validation "+store.last_error)
	if not store.last_error.is_empty():quit(1);return
	var profile:=FrontierPlayerProfile.new(folder+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"Forward+ current field",80):quit(1);return
	app.close_menus();app.onboarding.letter.hide();FrontierClientSettings.ensure(self).values.tutorial_mode=2;app.outside=false;app.exterior_view.hide();app.if_flight_view()
	var actor: CharacterBody3D=app.actors[owner.character_id]
	var fixtures: Array=[["lotus",at,"lotus_crate"],["mine",miner,"mine_miner"],["coopertech",robot,"coopertech_robot"]]
	for fixture in fixtures:
		var target: Vector3=fixture[1]+Vector3.UP*float(FrontierCorporations.asset(fixture[2]).height)
		look(actor,fixture[1]+Vector3(0,0,5),target)
		if not await until(func():return app.surface_world.ready_at(actor.position),"nearby collision ready",20):quit(1);return
		app.test_scan=true
		if not await until(func():return FrontierCorporations.records(app.session.authority.world).has(fixture[0]),"E identifies "+fixture[0],12):
			print("SCAN_DEBUG ",app.session.authority.scans," position ",actor.position," aim ",-app.camera.global_basis.z);await capture("failed-scan");quit(1);return
		await create_timer(.25).timeout
		check(app.session.latest.scan.info.get("company")==fixture[0],"host result has company symbol")
		await capture(fixture[0]+"-scan")
		app.test_scan=false
		app.toggle_research();app.research_frame.tabs.current_tab=1;app.survey_journal.category.select(5);app.survey_journal.refresh()
		await create_timer(.25).timeout
		var entries:=FrontierDiscoveryIndex.page(app.session.authority.world,fixture[0],"corporation","",0)
		check(entries.total==1,"only discovered company searchable")
		app.survey_journal.select(entries.entries[0]);await capture(fixture[0]+"-journal")
		check(app.feedback.blocked(),"J blocks field input")
		app.close_menus()
	check(FrontierCorporations.affiliations("mine_miner")[0].id=="crew" and FrontierCorporations.affiliations("coopertech_robot")[0].id=="","manufacturer never implies operator")
	check(FrontierDiscoveryIndex.page(app.session.authority.world,"Space Y","corporation","",0).total==0,"unseen Space Y remains hidden")
	check(FrontierDiscoveryIndex.page(app.session.authority.world,"쿠퍼테크","corporation","",0).total==1,"Korean company name search")
	app.toggle_research();app.research_frame.tabs.current_tab=1;app.survey_journal.category.select(5);app.survey_journal.refresh()
	root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("corporations-journal-960")
	check(app.survey_journal.detail_column.get_global_rect().end.x<=960,"company detail fits 960px")
	var expected:=JSON.stringify(FrontierCorporations.records(app.session.authority.world))
	check(await app.session.close_session(),"save company sightings")
	var saved:=FrontierWorldStore.new(folder+"/world.json").read_state()
	check(not saved.is_empty() and JSON.stringify(FrontierCorporations.records(saved))==expected,"reload preserves first physical sightings")
	var local:=saved.duplicate(true);local.crew.corporations={}
	local.crew.shuttles[owner.character_id].state="sortie"
	var context:=FrontierShuttles.context(local,owner.character_id)
	FrontierCorporations.record(context,FrontierCorporations.candidate("lotus_crate",crate.id,crate.position,planet.id));FrontierShuttles.commit(local,context,owner.character_id)
	check(FrontierCorporations.records(local).has("lotus"),"independent shuttle commits new company record")
	app.queue_free();await process_frame;await process_frame
	print("CORPORATE_PLAY_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
func review_saved() -> void:
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"saved field review",80):quit(1);return
	app.close_menus();app.onboarding.letter.hide();FrontierClientSettings.ensure(self).values.tutorial_mode=2;app.outside=false;app.exterior_view.hide();app.if_flight_view()
	var actor: CharacterBody3D=app.actors[app.session.latest.self_id]
	for id in ["lotus","mine","coopertech"]:
		var row: Dictionary=FrontierCorporations.records(app.session.authority.world)[id]
		var target:=FrontierCrewWorld.vector(row.position)
		var offset:=Vector3(0,0,5)
		if id=="lotus":
			var heading:=float(app.session.authority.world.lotus.crates[row.source_id].heading)
			offset=Vector3(sin(heading),0,cos(heading))*5
		look(actor,target+offset,target)
		app.test_scan=true;await create_timer(.8).timeout
		await capture(id+"-scan");app.test_scan=false
		app.toggle_research();app.research_frame.tabs.current_tab=1;app.survey_journal.category.select(5);app.survey_journal.refresh();await create_timer(.2).timeout
		var entry: Dictionary=FrontierDiscoveryIndex.page(app.session.authority.world,id,"corporation","",0).entries[0]
		app.survey_journal.select(entry);await capture(id+"-journal");app.close_menus()
	app.toggle_research();app.research_frame.tabs.current_tab=1;app.survey_journal.category.select(5);app.survey_journal.refresh();await create_timer(.2).timeout
	root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("corporations-journal-960")
	check(app.survey_journal.preview.camera.position.z>0,"manufacturer plate faces journal camera")
	check(app.survey_journal.detail_column.get_global_rect().end.x<=960,"revised detail fits small window")
	check(await app.session.close_session(),"close saved review")
	app.queue_free();await process_frame;await process_frame
	print("CORPORATE_REVIEW_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
