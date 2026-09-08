extends "res://tests/test_solo_entry.gd"
func place(point: Vector3) -> void:
	app.actors[app.session.latest.self_id].position=point;app.session.authority.update_position(1,point);app.session._publish();app.session._publish_surface();await create_timer(.2).timeout
func run() -> void:
	folder="/tmp/uiux-ux03"
	if "--crew-ui-test" not in OS.get_cmdline_user_args() or "--crew-folder=/tmp/uiux-ux03" not in OS.get_cmdline_user_args():quit(1);return
	if not FileAccess.file_exists(folder+"/world.json"):quit(1);return
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.session.active and app.surface_world!=null and not has_meta("startup_loader") and not app.arrival.active,"UX03 isolated scene",60):quit(1);return
	if not app.test_mode or app.world_store.path!=folder+"/world.json":quit(1);return
	app.close_menus();app.onboarding.letter.hide();app.navigation_journal.path=folder+"/navigation.json"
	root.size=Vector2i(960,640);root.content_scale_size=root.size
	await place(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))
	var actor: String=app.session.latest.self_id
	var world: Dictionary=app.session.authority.world
	world.crew.members[actor].loadout.inventory_slots=48;world.business.credits=16000
	for id in ["refined_iron","reinforced_frame","control_circuit","heat_transfer_unit"]:world.business.bags[actor][id]=10
	world.business.sites[world.location].inventory.iron=90;world.business.sites[world.location].inventory.copper=90
	app.session._publish();app.session._publish_surface()
	var before:=FrontierProgressionResearch.personal(world.crew.members[actor],"mining")
	app.session.send_request("business_efficiency",{"field":"mining","station_id":"ship:augmentation"})
	check(FrontierProgressionResearch.personal(app.session.authority.world.crew.members[actor],"mining")==before,"host rejects upgrade away from actual station")
	var station: FrontierCrewStation=app.stations.surface.get_node("Station_augmentation")
	await place(station.interaction_point()+Vector3(0,0,1.5));app.stations.open_device("augmentation",1);await capture("equipment-workshop-960")
	var workshop: FrontierEquipmentWorkshop=app.stations.augmentation_tabs.get_tab_control(1)
	check(workshop.action.get_global_rect().end.y<=640 and app.stations.panel.get_global_rect().end.x<=960,"equipment workshop fits small screen")
	app.stations.augmentation_tabs.current_tab=2;await create_timer(.3).timeout
	var performance: FrontierProgressionResearchPanel=app.stations.augmentation_tabs.get_tab_control(2)
	performance.selected="mining";performance.signature="";performance.refresh();performance.action.pressed.emit();await create_timer(.3).timeout
	check(FrontierProgressionResearch.personal(app.session.authority.world.crew.members[actor],"mining")==before+1,"actual station buys personal upgrade through host")
	await capture("personal-performance-960")
	app.toggle_research();await capture("records-960")
	check(app.research_frame.tabs.get_tab_count()==2 and not app.surface_panel.at_station,"J contains records and shared research only")
	app.close_menus();app.toggle_inventory();app.inventory_panel.tabs.current_tab=3;await capture("personal-status-960");app.close_menus()
	await place(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position));app.toggle_shipyard();await capture("shipyard-empty-960")
	var yard:=app.shipyard_panel;yard.tabs.current_tab=1;await create_timer(.2).timeout
	yard.action_map.vessel_build.pressed.emit();await create_timer(.3).timeout
	check(app.session.latest.vessel.modules.size()==1 and not yard.pending,"standard module builds with host result")
	yard.tabs.current_tab=0;yard.rebuild();yard.action_map.vessel_equip.pressed.emit();await create_timer(.3).timeout
	check(not app.session.latest.vessel.loadout.propulsion.is_empty(),"module equips selected ship slot")
	yard.ghost.button_pressed=true;await capture("shipyard-960")
	check(yard.preview.mounts.size()==2 and yard.preview.view.model!=null,"actual hull and both module mount positions rendered")
	check(yard.action_map.vessel_equip.get_global_rect().end.x<=960 and yard.action_map.vessel_equip.get_global_rect().end.y<=640,"ship refit actions fit small screen")
	app.close_menus()
	# Market fixture is a read-only snapshot. Existing trading rules are unchanged.
	app.session.set_process(false)
	var market:=app.station_market
	var data: Dictionary=app.session.latest.duplicate(true);data.crew.landing={};data.crew.navigation.mode="idle";data.crew.navigation.speed=0;data.crew.navigation.position=[0,0,0]
	data.station={"name":"WAYFARER","position":[0,0,0],"credits":1000,"stock":{"iron":10,"copper":0,"stone":0},"prices":{"iron":12,"copper":20,"stone":5}}
	data.inventory={"iron":0,"copper":3,"stone":0}
	market.data=data;market.mode="goods";market.selected="";market.rebuild();app.open_menu(market);await capture("market-960")
	check(market.grid.get_child_count()==2,"market hides items absent from both shop and bag")
	market.sale_only.button_pressed=true;market.rebuild()
	check(market.grid.get_child_count()==1 and market.selected=="copper","sell filter includes only owned items even when shop empty")
	market.browser.search.text="없음";market.rebuild();check(market.empty.visible and not market.buy.visible,"search empty state hides stale transaction")
	market.browser.search.text="";market.sale_only.button_pressed=false;market.rebuild();market.selected="iron";market.quantity.value=2;market.refresh_detail()
	check(market.buy.text.contains("24") and market.unit_price.text.contains("12"),"market unit price and total stay explicit")
	check(market.buy.get_global_rect().end.y<=640,"market actions fit small screen")
	app.close_menus();check(await app.session.close_session(),"UX03 fixture saved")
	print("UIUX_GROWTH ",checks," FAILURES ",failures);quit(1 if failures else 0)
