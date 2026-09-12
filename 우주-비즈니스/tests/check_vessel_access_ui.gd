extends "res://tests/check_station_interface.gd"
func run() -> void:
	if not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--crew-folder="):DirAccess.make_dir_recursive_absolute(argument.trim_prefix("--crew-folder="))
	folder=ProjectSettings.globalize_path("res://../docs/production/media/vessel-access");DirAccess.make_dir_recursive_absolute(folder)
	FrontierInput.apply({});root.size=Vector2i(1280,800);root.content_scale_size=root.size
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
	app.start_solo(true);await create_timer(.7).timeout;app.onboarding.letter.hide()
	var world: Dictionary=app.session.authority.world
	var index:=1
	while FrontierSpaceStation.definition(world.manifest,index).is_empty():index+=1
	var station:=FrontierSpaceStation.definition(world.manifest,index)
	var nav: Dictionary=world.crew.navigation
	nav.mode="idle";nav.manual=true;nav.system=index;nav.target=FrontierUniverse.first_ordinal(world.manifest,index);nav.speed=0
	nav.position=FrontierExpeditionBusiness.array(FrontierCrewWorld.vector(station.position)+Vector3(0,360,1050));nav.direction=[0,-.25,-1]
	world.flight_position=nav.position.duplicate();world.location=FrontierUniverse.body_id(world.manifest,int(nav.target))
	world.business=FrontierExpeditionBusiness.create();world.business.credits=350000;world.business.bags[world.crew.owner_id]=FrontierExpeditionBusiness.inventory()
	world.vessel=FrontierVesselRefit.create(int(world.manifest.seed),world.crew.world_id)
	app.session._publish();app.outside=true;app.exterior_view.show();app.if_flight_view()
	await create_timer(.7).timeout;app.flight.transit_overlay.arrival_age=100
	app.test_mode=false;app._sync_mouse_capture();app.open_trade_station()
	app.station_market.mode="refits";app.station_market.selected="3";app.station_market.rebuild()
	check(app.station_market.visible and not app.station_market.buy.disabled,"station navigation refit reachable")
	check(app.station_market.hum.playing,"ElevenLabs station ambience")
	await capture("station-t3-before")
	app.station_market.send("station_navigation_refit")
	check(not app.station_market.pending and int(app.session.latest.vessel_stats.navigation_tier)==3,"host commits T3 refit")
	check(app.station_market.audio.last_played.has(FrontierSpaceStation.config().audio.hull),"refit success audio follows host")
	app.station_market.selected="5";app.station_market.refresh_detail()
	check(app.station_market.buy.disabled,"T5 cannot skip T4")
	root.size=Vector2i(960,640);root.content_scale_size=root.size
	await capture("station-refits-960")
	check(app.station_market.access_box.get_global_rect().end.y<=640 and app.station_market.access_box.visible,"capability comparison visible without scrolling")
	check(app.station_market.buy.get_global_rect().end.y<=640 and app.station_market.get_global_rect().end.x<=960,"refit action fits 960px")
	app.station_market.mode="ships";app.station_market.selected="";app.station_market.rebuild();await capture("rated-hulls-960")
	app.station_market.send("station_buy")
	check(app.session.latest.vessel.hulls.size()==2,"rated ship purchase")
	app.station_market.mode="owned";app.station_market.selected=app.session.latest.vessel.hulls[1];app.station_market.rebuild();app.station_market.send("station_equip")
	await create_timer(.5).timeout
	check(app.flight.refits.hull_node!=null,"purchased hull connected to live flight renderer")
	app.close_menus();app.toggle_shipyard();app.shipyard_panel.tabs.current_tab=2;app.shipyard_panel.rebuild()
	await capture("shipyard-refits-960")
	check(int(app.shipyard_panel.world.business.credits)==int(app.session.authority.world.business.credits),"shipyard shows current shared funds in orbit")
	check(app.shipyard_panel.visible and app.shipyard_panel.action_map.vessel_navigation_refit.visible,"K shipyard exposes permanent refits")
	check(app.shipyard_panel.action_map.vessel_navigation_refit.disabled,"ground service rejects orbit")
	check(app.shipyard_panel.action_map.vessel_navigation_refit.get_global_rect().end.y<=640,"shipyard refit action fits 960px")
	app.close_menus();app.navigation_ui.open_galaxy();app.navigation_ui.show_route(75000*8)
	await capture("locked-route-960")
	check(app.navigation_ui.route.disabled and app.navigation_ui.route.text=="항해 내성 부족","map compares T4 requirements against T3 ship")
	app.close_menus();await capture("rated-hull-flight")
	check(not app.station_market.hum.playing,"menu ambience stops on close")
	check(await app.session.close_session(),"save after ship refit and hull purchase")
	print("VESSEL ACCESS UI failures ",failures)
	app.queue_free();await process_frame;quit(1 if failures else 0)
