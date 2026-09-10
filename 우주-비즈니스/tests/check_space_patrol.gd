extends "res://tests/test_solo_entry.gd"
var m: Dictionary={}
func run() -> void:
	if "--crew-folder=/tmp/space-patrol-play" not in OS.get_cmdline_user_args() or "--crew-ui-test" not in OS.get_cmdline_user_args():quit(2);return
	folder=ProjectSettings.globalize_path("res://../docs/production/media/corporate-space");DirAccess.make_dir_recursive_absolute("/tmp/space-patrol-play")
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var owner:=FrontierPlayerProfile.new_character("Space Y 경비 확인",2);var core:=FrontierCrewAuthority.new();core.start(FrontierUniverse.new_world(61739),owner,func(_w):return true)
	var world: Dictionary=core.world;m=world.manifest
	var legacy: Dictionary=m.duplicate(true);legacy.settings.corporate_space.traffic.erase("patrol")
	check(FrontierSpaceTraffic.all(legacy,0,0).size()==2,"SP05 saved fleet stays two freighters")
	var frame:=FrontierSpacePatrol.frame(m,"solar_mars_port",0)
	var target: Vector3=frame.center+frame.radial*1900+Vector3.UP*600
	world.crew.navigation.position=FrontierExpeditionBusiness.array(target);world.crew.navigation.manual=true;world.flight_position=world.crew.navigation.position.duplicate()
	world.crew.navigation.traffic_observers=FrontierSpaceTraffic.observers(world)
	FrontierSpacePatrol.step(world)
	var patrols: Dictionary=world.crew.navigation.traffic_patrols.duplicate(true)
	check(patrols.solar_mars_port.started==0 and not patrols.solar_mars_port.armed,"nearby crew ship triggers one host sensor visit")
	var safe:=true;var separated:=true
	for k in range(0,241):
		var t:=float(k)*.25;var rows:=FrontierSpacePatrol.all(m,t,world.crew.navigation.traffic_observers,patrols)
		for i in [0,2]:
			if rows[i].position.distance_to(rows[i+1].position)<170:separated=false
		for row in rows:
			if row.position.length()<float(FrontierUniverse.star_settings(m,0).star_warning_radius):safe=false
			for ordinal in range(8):
				var body:=FrontierUniverse.body(m,ordinal)
				if row.position.distance_to(FrontierUniverse.position(m,ordinal,t))<FrontierUniverse.navigation_radius(body)+80:safe=false
	check(safe and separated,"approach scan return patrol preserve celestial clearance and 180m pairs")
	var trial: Dictionary=world.duplicate(true);trial.crew.navigation.orbit_time=80;FrontierSpacePatrol.step(trial)
	check(trial.crew.navigation.traffic_patrols.solar_mars_port.started==0,"loitering does not retrigger inspection")
	trial.crew.navigation.orbit_time=120;trial.crew.navigation.traffic_observers=[];FrontierSpacePatrol.step(trial)
	check(trial.crew.navigation.traffic_patrols.solar_mars_port.armed,"departure and cooldown rearm next arrival")
	var malformed: Dictionary=patrols.duplicate(true);malformed.solar_mars_port.target=["bad",0,0];check(not FrontierSpacePatrol.valid_state(malformed),"invalid saved patrol target rejected")
	check(FrontierWorldStore.new("/tmp/space-patrol-play/world.json").write(world),"patrol save valid")
	var profile:=FrontierPlayerProfile.new("/tmp/space-patrol-play/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.session.active and app.flight!=null and not has_meta("startup_loader"),"current expedition loads guard fleet",45):quit(1);return
	app.onboarding.letter.hide();app.close_menus();app.outside=true;app.exterior_view.show();app.if_flight_view();app.set_process(false)
	app.flight.set_process(false);app.flight.scan_enabled=true;app.flight.presentation_blocked=false;app.flight.camera.set_as_top_level(true);app.flight.exterior=false;app.flight.transit_overlay.hide()
	check(app.flight.traffic.models.size()==6,"two carriers and four near/LOD guards")
	# The current host session crosses the sensor phase boundary naturally from a review timestamp.
	await position_camera(11.7)
	if await until(func():
		app.flight.traffic.update(.1,float(app.session.authority.world.crew.navigation.orbit_time),false)
		return app.flight.traffic.rows[4].stage=="inspect","host time enters actual sensor check",10):
		check(app.flight.traffic.last_radio.contains("센서 확인"),"one control cue on sensor phase transition")
	await capture("fighter-sensor-live")
	app.session.set_physics_process(false);app.flight.set_process(false)
	for pair in [[5.0,"fighter-intercept"],[15.0,"fighter-inspect"],[24.0,"fighter-return"],[45.0,"fighter-patrol"]]:
		await position_camera(float(pair[0]));await capture(pair[1])
	var hull:=float(app.session.authority.world.crew.navigation.get("hull",100))
	check(hull==100 and app.session.authority.world.crew.navigation.mode=="idle","inspection neither damages nor locks crew navigation")
	check(not app.flight.traffic.selected.is_empty() and app.flight.traffic.selected.kind=="fighter","fighter gaze uses formation detail")
	var cache: Dictionary=app.flight.traffic.models;var id: String=app.flight.traffic.rows[4].id
	app.flight.camera.global_position=app.flight.traffic.rows[4].position+Vector3(0,100,7000);app.flight.traffic.update(.02,45,false)
	check(cache[id].far.visible and not cache[id].near.visible,"far guard switches to authored LOD")
	await position_camera(15);root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("fighter-960")
	app.flight.traffic.update(.02,15,true)
	check(app.flight.traffic.selected.is_empty() and (not app.flight.traffic.radio.playing or app.flight.traffic.radio.stream_paused),"menu clears sensor HUD and control audio")
	var saved_world: Dictionary=app.session.authority.world;var clock: float=saved_world.crew.navigation.orbit_time
	var expected:=FrontierSpacePatrol.all(m,clock,saved_world.crew.navigation.get("traffic_observers",[]),saved_world.crew.navigation.traffic_patrols)
	check(await app.session.close_session(),"patrol checkpoint saved")
	var saved:=FrontierWorldStore.new("/tmp/space-patrol-play/world.json").read_state();var nav: Dictionary=saved.crew.navigation
	var actual:=FrontierSpacePatrol.all(saved.manifest,float(nav.orbit_time),nav.get("traffic_observers",[]),nav.traffic_patrols)
	check(expected[2].id==actual[2].id and expected[2].position==actual[2].position and expected[2].stage==actual[2].stage,"same guard ID position inspection phase after reload")
	app.queue_free();await process_frame;await process_frame
	print("SPACE_PATROL_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
func position_camera(t: float) -> void:
	var world: Dictionary=app.session.authority.world;world.crew.navigation.orbit_time=t
	var rows:=FrontierSpacePatrol.all(m,t,world.crew.navigation.get("traffic_observers",[]),world.crew.navigation.traffic_patrols)
	var row: Dictionary=rows[2];var facing: Vector3=row.direction
	var point: Vector3=row.position+facing*210+Vector3(190,160,0)
	app.session._publish();app.flight.update_navigation(world.crew.navigation)
	app.flight.camera.global_position=point;app.flight.camera.look_at(row.position)
	app.flight.traffic.update(1,t,false);await create_timer(.2).timeout
