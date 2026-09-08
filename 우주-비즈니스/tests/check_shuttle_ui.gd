extends "res://tests/test_solo_entry.gd"
func tab(name_value: String) -> void:
	for i in app.business_panel.tabs.get_tab_count():
		if app.business_panel.tabs.get_tab_title(i)==name_value:app.business_panel.tabs.current_tab=i;return
func run() -> void:
	folder="/tmp/finch-ui"
	if "--crew-folder=/tmp/finch-ui" not in OS.get_cmdline_user_args():printerr("isolated --crew-folder=/tmp/finch-ui required");quit(1);return
	DirAccess.make_dir_recursive_absolute(folder)
	var fixture:=FrontierWorldStore.new("/tmp/finch-sortie/world.json").read_state()
	var owner: String=fixture.crew.owner_id
	var craft: Dictionary=fixture.crew.shuttles.values()[0].duplicate(true)
	for member in fixture.crew.members.values():member.erase("shuttle_id")
	craft.state="docked";craft.pad_slot=0;craft.location=fixture.location;craft.navigation_target=fixture.location;craft.system=fixture.crew.navigation.system;craft.navigation=fixture.crew.navigation.duplicate(true);craft.landing=fixture.crew.landing.duplicate();craft.cargo={};craft.cargo_equipment={};craft.rock=0
	fixture.crew.shuttles={owner:craft}
	var store:=FrontierWorldStore.new(folder+"/world.json")
	check(store.write(fixture),"prepare isolated docked craft: "+store.last_error)
	var profile_store:=FrontierPlayerProfile.new(folder+"/profile.json");profile_store.data={"version":1,"character":fixture.crew.members[owner].profile,"sessions":{}};profile_store.save()
	root.size=Vector2i(1280,800)
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame
	app.start_solo()
	if not await until(func():return app.surface_world!=null and not app.arrival.active,"opens actual supply site",60):quit(1);return
	var actor: String=app.session.latest.self_id
	var factory: Dictionary=FrontierExpeditionBusiness.site(app.session.authority.world).buildings["fixture:factory"]
	var point:=FrontierCrewWorld.vector(factory.position)+Vector3(0,0,4)
	app.actors[actor].position=point;app.session.authority.update_position(1,point)
	await create_timer(.5).timeout
	app.open_station("factory","fixture:factory");tab("소형선")
	check(app.business_panel.visible and app.business_panel.shuttle_panel.preview.model!=null,"FINCH model card in live factory")
	await capture("finch-factory")
	root.size=Vector2i(960,640);root.content_scale_size=root.size
	var scroll: ScrollContainer=app.business_panel.get_child(0);scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value)
	await capture("finch-factory-960")
	check(app.feedback.blocked(),"craft menu blocks field controls/audio")
	app.close_menus()
	point=FrontierShuttles.pad(app.session.authority.world,actor)
	app.actors[actor].position=point+Vector3(3,0,4);app.session.authority.update_position(1,app.actors[actor].position)
	app.yaw=atan2(3.0,4.0);app.pitch=-.10
	await create_timer(.5).timeout
	check(app.surface_world.shuttle_models.has(actor),"docked FINCH in current INK world")
	await capture("finch-pad")
	app.actors[actor].position=point;app.session.authority.update_position(1,point)
	app.session.send_request("shuttle_board",{})
	if not await until(func():return app.surface_world==null and not app.arrival.active and app.outside,"independent takeoff reaches local flight",60):quit(1);return
	check(app.session.latest.local_shuttle==actor and app.flight.refits.hull_id=="finch","flight renders own craft and scoped navigation")
	check(float(app.session.latest.vessel_stats.stellar_range)==0,"map disables interstellar range")
	await capture("finch-flight")
	# Real player input path; transient controls expire and are then braked by the normal host tick.
	var local:=FrontierShuttles.context(app.session.authority.world,actor)
	FrontierCrewNavigation.steer(local,[1.0,.1,0.0,0.0],.1);FrontierShuttles.commit(app.session.authority.world,local,actor)
	await create_timer(.2).timeout
	check(app.flight.engine.stream!=null and app.flight.drive.jets.size()==2,"ElevenLabs flight engine and paired exhaust remain connected")
	check(await app.session.close_session(),"save own craft in flight")
	app.queue_free();await process_frame;await process_frame
	FrontierCrewSurface.reset_cache()
	print("SHUTTLE_UI_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
