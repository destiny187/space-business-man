extends "res://tests/check_uiux_growth.gd"
func run() -> void:
	folder="/tmp/uiux-ux03"
	if "--crew-ui-test" not in OS.get_cmdline_user_args() or "--crew-folder=/tmp/uiux-ux03" not in OS.get_cmdline_user_args():quit(1);return
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.session.active and app.surface_world!=null and not has_meta("startup_loader") and not app.arrival.active,"UX03 final isolated scene",60):quit(1);return
	if not app.test_mode or app.world_store.path!=folder+"/world.json":quit(1);return
	app.close_menus();app.onboarding.letter.hide();app.navigation_journal.path=folder+"/navigation.json"
	root.size=Vector2i(960,640);root.content_scale_size=root.size
	var station: FrontierCrewStation=app.stations.surface.get_node("Station_augmentation")
	await place(station.interaction_point()+Vector3(0,0,1.5));app.stations.open_device("augmentation",1);await capture("equipment-final-960")
	var workshop: FrontierEquipmentWorkshop=app.stations.augmentation_tabs.get_tab_control(1)
	check(workshop.grid.get_child(0).picture!=null,"suit card uses real transparent game render")
	app.close_menus();station=app.stations.surface.get_node("Station_research");await place(station.interaction_point()+Vector3(0,0,1.5))
	var world: Dictionary=app.session.authority.world;world.crew.rock=20
	for ordinal in range(400,420):
		var body:=FrontierUniverse.body(world.manifest,ordinal)
		if not FrontierUniverse.landable(body):continue
		var planet:=FrontierEcology.ensure_planet(world.ecology,body)
		if not planet.lineages.is_empty():FrontierEcology.scan(world.ecology,body.id,planet.lineages[0]);break
	app.session._publish();app.session._publish_surface();app.stations.open_device("research",2);await create_timer(.3).timeout
	app.survey_journal.category.select(2);app.survey_journal.refresh();await create_timer(.3).timeout
	var form_id: String=app.survey_journal.selected_entry.row.form_id
	app.research_actions[0].pressed.emit();await create_timer(.3).timeout
	check(app.session.authority.world.ecology.research.has(FrontierEcologyCatalog.form(form_id).environment),"physical research bench analyzes selected discovery")
	await capture("research-device-960")
	app.toggle_research();app.research_frame.tabs.current_tab=1;await create_timer(.2).timeout
	check(app.survey_journal.get_parent()==app.research_frame.ecology and not app.research_actions[1].visible,"J restores shared journal as read-only")
	app.close_menus();await place(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position));app.toggle_shipyard()
	var yard:=app.shipyard_panel
	yard.tabs.current_tab=1;await capture("shipyard-final-960")
	check(yard.preview.size.y>=240 and yard.action_map.vessel_draw.get_global_rect().end.y<yard.get_global_rect().end.y,"compact vehicle entry leaves ship preview and actions on screen")
	app.session.set_process(false)
	var empty_snapshot: Dictionary=app.session.latest.duplicate(true);empty_snapshot.vessel={};yard.last_inventory="";yard.update_snapshot(empty_snapshot,app.session.surface.business);await capture("shipyard-first-module-960")
	check(yard.preview.view.model!=null and yard.candidate().type=="drive","empty initial vessel supports blueprint preview")
	app.close_menus()
	var market:=app.station_market;var data: Dictionary=app.session.latest.duplicate(true)
	data.crew.landing={};data.crew.navigation.mode="idle";data.crew.navigation.speed=0;data.crew.navigation.position=[0,0,0]
	data.station={"name":"WAYFARER","position":[0,0,0],"credits":1000,"stock":{"iron":10,"copper":0,"stone":0},"prices":{"iron":12,"copper":20,"stone":5}};data.inventory={"copper":3}
	market.data=data;market.mode="goods";market.selected="iron";market.rebuild();app.open_menu(market);await capture("market-final-960")
	check(market.icon.get_global_rect().end.y<market.quantity.get_global_rect().position.y,"selected commodity image fits above fixed trade controls")
	check(market.buy.get_global_rect().end.y<market.get_global_rect().end.y,"trade action inside panel")
	app.close_menus();check(await app.session.close_session(),"final fixture saved and closed")
	print("UIUX_GROWTH_POLISH ",checks," FAILURES ",failures);quit(1 if failures else 0)
