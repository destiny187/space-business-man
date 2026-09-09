extends "res://tests/test_solo_entry.gd"
func run() -> void:
	folder="/tmp/ui-growth-refresh"
	if "--crew-folder=/tmp/ui-growth-refresh" not in OS.get_cmdline_user_args() or "--crew-ui-test" not in OS.get_cmdline_user_args():quit(1);return
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var owner:=FrontierPlayerProfile.new_character("트리 탐험가",2)
	var initial:=FrontierUniverse.new_world(71491)
	check(FrontierUniverse.validate_world(initial).is_empty(),"new mineral rules validate")
	var planet:=FrontierUniverse.body(initial.manifest,FrontierCrewNavigation.first_destination(initial.manifest))
	var rows:=FrontierExpeditionBusiness.starter_veins(planet)
	check(rows.size()>=20 and rows.all(func(row):return row.capacity<=40),"many small starting deposits")
	var region:=FrontierMineralWorld.region(planet,3,3)
	check(region.filter(func(row):return not row.underground).size()==12 and region.all(func(row):return row.capacity<90),"denser small regional deposits")
	var legacy: Dictionary={"augmentation":{"version":1,"levels":{"mobility":3,"combat":2,"vitality":1}}}
	check(FrontierCrewAugmentation.validate(legacy.augmentation),"old three-field save accepted")
	FrontierCrewAugmentation.ensure(legacy)
	check(FrontierCrewAugmentation.validate(legacy.augmentation) and FrontierCrewAugmentation.level(legacy,"mobility")==3 and FrontierCrewAugmentation.level(legacy,"jump")==0,"old levels preserved on tree migration")
	FrontierWorldStore.new(folder+"/world.json").write(initial)
	var profile:=FrontierPlayerProfile.new(folder+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.session.active and app.flight!=null and not has_meta("startup_loader"),"ship ready",60):quit(1);return
	app.outside=false;app.exterior_view.hide();app.if_flight_view();app.close_menus();app.onboarding.letter.hide()
	var station: FrontierCrewStation=app.stations.cabin.get_node("Station_augmentation")
	var actor: CharacterBody3D=app.actors[owner.character_id]
	actor.position=station.global_position+station.global_basis.z*2.1+Vector3.UP*.1;app.session.authority.update_position(1,actor.position)
	var world: Dictionary=app.session.authority.world
	world.business=FrontierExpeditionBusiness.create();world.business.bags[owner.character_id]=FrontierExpeditionBusiness.inventory()
	for id in ["sapphire","ruby","emerald"]:world.business.bags[owner.character_id][id]=99
	app.session._publish();app.session._publish_surface();await process_frame
	app.stations.selected="augmentation";app.stations.research_tabs.hide();app.stations.augmentation_tabs.show();app.stations.panel.show();app.stations.title.text="신체 강화";app.stations.augmentation.open()
	var page:=app.stations.augmentation
	page.select_field("jump");check(not page.branch_requirement.text.is_empty(),"jump requires mobility root")
	var denied:=FrontierCrewAugmentation.reason(world,owner.character_id,{"station_id":"ship:augmentation","field":"jump","expected_level":0},app.stations.resolve(owner.character_id,"ship:augmentation"))
	check(denied.contains("보행 강화"),"host blocks prerequisite bypass")
	page.select_field("mobility");page.prepare_gem("sapphire");page.submit();await create_timer(1.2).timeout
	check(FrontierCrewAugmentation.level(page.member(),"mobility")==1 and page.bag().sapphire==96,"root purchase committed once")
	page.select_field("jump");page.prepare_gem("sapphire");page.submit();await create_timer(1.2).timeout
	check(FrontierCrewAugmentation.level(page.member(),"jump")==1 and page.bag().sapphire==92,"branch purchase committed once")
	check(page.speaker.stream!=null,"existing ElevenLabs feedback connected")
	await capture("tree-1280")
	root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("tree-960")
	check(page.get_global_rect().end.x<=960 and page.action.get_global_rect().end.y<=640 and page.tree.buttons.excavation.get_global_rect().end.y<=640,"tree and action fit small window")
	var own: Dictionary=world.crew.members[owner.character_id]
	own.augmentation.levels.vitality=1;own.augmentation.levels.fall_guard=2
	var base:=own.duplicate(true);base.augmentation.levels.fall_guard=0
	own.vitals=FrontierCrewVitals.create();base.vitals=FrontierCrewVitals.create()
	FrontierCrewVitals.land(own,14);FrontierCrewVitals.land(base,14)
	check(own.vitals.health>base.vitals.health,"fall protection changes actual host damage")
	app.close_menus()
	world=app.session.authority.world
	var destination:=FrontierCrewNavigation.first_destination(world.manifest)
	planet=FrontierUniverse.body(world.manifest,destination)
	world.crew.navigation.system=FrontierUniverse.system_index(world.manifest,destination);world.crew.navigation.target=destination
	world.crew.navigation.position=FrontierExpeditionBusiness.array(FrontierCrewNavigation.center(destination,world.manifest,float(world.crew.navigation.orbit_time))+Vector3.UP*(FrontierUniverse.navigation_radius(planet)+1))
	app.session.send_request("ready",{"value":true});app.session.send_request("land",{})
	if not await until(func():return app.surface_world!=null and not app.arrival.active and app.surface_world.ready_at(actor.position),"landed field",60):quit(1);return
	app.onboarding.letter.hide();app.pitch=-.2
	await capture("small-deposits-field")
	var jump_motion:=FrontierCrewLocomotion.create();jump_motion.grounded=true;jump_motion.takeoff=.001
	FrontierCrewLocomotion.step(actor,jump_motion,Vector2.ZERO,0,9.8,0,.002,true,0,0,FrontierCrewAugmentation.multiplier(app.session.latest.crew.members[owner.character_id],"jump"))
	check(actor.velocity.y>float(FrontierCrewLocomotion.config().jump_speed),"purchased jump changes actual actor takeoff")
	var ore: Dictionary=FrontierExpeditionBusiness.starter_veins(planet)[0]
	var ore_point:=FrontierMineralWorld.point(app.surface_world.terrain.field,ore)
	actor.position=ore_point+Vector3(1,.15,1);app.session.authority.update_position(1,actor.position)
	app.session.send_request("business_mine",{"vein_id":ore.id});await process_frame
	check(FrontierExpeditionBusiness.site(app.session.authority.world).remaining.get(ore.id,ore.capacity)<ore.capacity,"small deposit yields resources through host mining")
	app.toggle_inventory();await capture("inventory-960")
	check(not app.inventory_panel.upgrade_action.visible and not app.inventory_panel.suit_action.visible,"inventory has no unrelated retrofit costs")
	var hot:=app.inventory_panel.hotbar
	check(absf(hot.position.x+hot.size.x/2-480)<1 and app.inventory_panel.hotbuttons[0].compact_slot,"centered large hotbar icons")
	app.close_menus();app.business_panel.show();app.session.authority.world.business.bags[owner.character_id]={"iron":5,"stone":100};app.session._publish();app.session._publish_surface();await process_frame;app.business_panel.set_context("build");app.business_panel.refresh_building_cost();app.business_panel.try_place_building()
	check(app.business_panel.building_message.text=="재료가 부족합니다.","build shortage click gives direct message")
	await capture("building-960")
	check(app.business_panel.is_visible_in_tree(),"building cards visible on actual surface")
	app.business_panel.hide()
	await app.session.close_session();app.queue_free();await process_frame;await process_frame
	var saved:=FrontierWorldStore.new(folder+"/world.json").read_state()
	check(FrontierCrewAugmentation.level(saved.crew.members[owner.character_id],"jump")==1,"branch survives save reload")
	print("UI_GROWTH_REFRESH ",checks," FAILURES ",failures);quit(1 if failures else 0)
