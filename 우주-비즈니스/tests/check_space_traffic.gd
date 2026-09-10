extends "res://tests/test_solo_entry.gd"
var manifest: Dictionary={}
func run() -> void:
	if "--menu-review" in OS.get_cmdline_user_args():await menu_review();return
	if "--crew-folder=/tmp/space-traffic-play" not in OS.get_cmdline_user_args() or "--crew-ui-test" not in OS.get_cmdline_user_args():quit(2);return
	folder=ProjectSettings.globalize_path("res://../docs/production/media/corporate-space");DirAccess.make_dir_recursive_absolute("/tmp/space-traffic-play")
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var owner:=FrontierPlayerProfile.new_character("Space Y 운항 확인",2);var core:=FrontierCrewAuthority.new();core.start(FrontierUniverse.new_world(61739),owner,func(_w):return true)
	var world: Dictionary=core.world;manifest=world.manifest
	var old: Dictionary=manifest.duplicate(true);old.settings.corporate_space.erase("traffic")
	check(FrontierSpaceTraffic.all(old,0,0).is_empty(),"saved SP04 world gains no traffic")
	check(FrontierSpaceTraffic.all(manifest,1,0).is_empty(),"no remote-system ship nodes or route sampling")
	var safe:=true;var gap:=INF
	for t in range(0,1200,2):
		var rows:=FrontierSpaceTraffic.all(manifest,0,float(t));gap=minf(gap,rows[0].position.distance_to(rows[1].position))
		for row in rows:
			if row.position.length()<float(FrontierUniverse.star_settings(manifest,0).star_warning_radius)+70:safe=false
			for ordinal in range(8):
				var body:=FrontierUniverse.body(manifest,ordinal);var point:=FrontierUniverse.position(manifest,ordinal,float(t))
				if row.position.distance_to(point)<FrontierUniverse.navigation_radius(body)+80:safe=false
				for moon in body.get("moons",[]):
					if row.position.distance_to(point+FrontierUniverse.moon_offset(body,moon,float(t)))<FrontierUniverse.moon_radius(body,moon)+80:safe=false
	check(safe and gap>120,"one complete round trip clears celestial spheres and the other carrier; gap="+str(gap))
	var offset:=float(FrontierUniverse.derive(int(manifest.seed),"space_y_freight_phase")%20)+75
	var continuous:=true
	for cut in [.05,.10,.15,.32,.72,.89,.93,1.0]:
		var t:=600.0+float(cut)*600-offset
		var a:=FrontierSpaceTraffic.sample(manifest,0,t-.001);var b:=FrontierSpaceTraffic.sample(manifest,0,t+.001)
		if a.position.distance_to(b.position)>20:continuous=false
	check(continuous,"moving endpoints and round-trip phase boundaries stay continuous")
	world.crew.navigation.manual=true;world.crew.navigation.target=3
	var initial:=FrontierSpaceTraffic.sample(manifest,0,0);var camera_point: Vector3=initial.position+Vector3(210,180,-330)
	world.crew.navigation.position=FrontierExpeditionBusiness.array(camera_point);world.crew.navigation.direction=FrontierExpeditionBusiness.array((initial.position-camera_point).normalized());world.flight_position=world.crew.navigation.position.duplicate()
	check(FrontierWorldStore.new("/tmp/space-traffic-play/world.json").write(world),"new traffic save valid")
	var profile:=FrontierPlayerProfile.new("/tmp/space-traffic-play/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.session.active and app.flight!=null and not has_meta("startup_loader"),"actual current flight",45):quit(1);return
	app.onboarding.letter.hide();app.close_menus();FrontierClientSettings.ensure(self).values.tutorial_mode=2
	app.outside=true;app.exterior_view.show();app.if_flight_view();app.flight.transit_overlay.arrival_age=100
	app.set_process(false);app.flight.scan_enabled=true;app.flight.presentation_blocked=false;app.flight.exterior=false;root.grab_focus()
	check(app.flight.traffic.models.values().filter(func(visual):return str(visual.root.name).begins_with("CARRIER")).size()==2,"two near/LOD carriers in actual flight")
	# Observe a real game-clock transition and its audio, then inspect representative later phases.
	await place(600+60-offset-1.5)
	await until(func():return app.flight.traffic.rows[0].stage=="depart","natural host departure phase",10)
	await create_timer(.2).timeout
	check(app.flight.traffic.rows[0].stage=="depart" and app.flight.traffic.engine.playing,"natural loaded departure and synthesized sensor engine")
	check(app.flight.traffic.last_radio.contains("계류 해제") and app.flight.traffic.radio.stream!=null,"acknowledged stage control signal")
	await capture("freighter-departure")
	app.session.set_physics_process(false);app.flight.set_process(false)
	for pair in [[.028,"freighter-unload"],[.053,"freighter-empty"],[.077,"freighter-load"],[.43,"freighter-cruise"],[.91,"freighter-approach-wait"],[.98,"freighter-dock"]]:
		await place(600+float(pair[0])*600-offset);await capture(pair[1])
	check(not app.flight.traffic.selected.is_empty(),"gaze identifies operator callsign mission and destination")
	app.flight.presentation_blocked=true;app.flight.traffic.update(.02,app.flight.orbit_clock,true)
	check(app.flight.traffic.selected.is_empty() and (not app.flight.traffic.engine.playing or app.flight.traffic.engine.stream_paused) and (not app.flight.traffic.radio.playing or app.flight.traffic.radio.stream_paused),"menu blocks gaze and traffic sound")
	app.flight.presentation_blocked=false;app.flight.traffic.update(.02,app.flight.orbit_clock,false)
	root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("freighter-960")
	var saved_time: float=app.session.authority.world.crew.navigation.orbit_time
	var before:=FrontierSpaceTraffic.sample(manifest,0,saved_time)
	check(await app.session.close_session(),"traffic world checkpoint")
	var saved:=FrontierWorldStore.new("/tmp/space-traffic-play/world.json").read_state()
	var after:=FrontierSpaceTraffic.sample(saved.manifest,0,float(saved.crew.navigation.orbit_time))
	check(before.id==after.id and before.position==after.position and before.stage==after.stage,"same vessel cargo phase and position after save reload")
	check(not saved.has("station_markets"),"NPC trips do not restock markets")
	app.queue_free();await process_frame;await process_frame
	print("SPACE_TRAFFIC_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
func place(t: float) -> void:
	var world: Dictionary=app.session.authority.world;var nav: Dictionary=world.crew.navigation
	var row:=FrontierSpaceTraffic.sample(manifest,0,t)
	var point: Vector3=row.position+Vector3(240,190,-360)
	nav.orbit_time=t;nav.position=FrontierExpeditionBusiness.array(point);nav.direction=FrontierExpeditionBusiness.array((row.position-point).normalized());nav.speed=0;nav.mode="idle";nav.manual=true;nav.traffic_observers=[];world.flight_position=nav.position.duplicate()
	app.session._publish();app.flight.ship.position=point;app.flight.ship.basis=app.flight._flight_basis(FrontierCrewWorld.vector(nav.direction));app.flight.look_offset=Vector2.ZERO
	app.flight.update_navigation(nav);app.flight.camera.position=Vector3.ZERO;app.flight.camera.rotation=Vector3.ZERO
	app.flight.traffic.update(.02,t,false)
	await create_timer(.1).timeout

func menu_review() -> void:
	var world:=FrontierUniverse.new_world(61739);var view:=FrontierCrewFlightView.new();view.state={"manifest":world.manifest};root.add_child(view)
	var nav:=FrontierCrewNavigation.create(world);view.update_navigation(nav);view.set_process(false)
	view.traffic.engine.play();view.traffic.radio.play();view.traffic.update(.02,0,true)
	check(view.traffic.selected.is_empty() and (not view.traffic.engine.playing or view.traffic.engine.stream_paused) and (not view.traffic.radio.playing or view.traffic.radio.stream_paused),"menu produces no active unpaused traffic sound or gaze")
	view.queue_free();await process_frame;await process_frame;quit(1 if failures else 0)
