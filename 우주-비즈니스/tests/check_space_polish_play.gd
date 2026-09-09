extends "res://tests/test_solo_entry.gd"
var report: Dictionary={"checks":[],"audio":{}}
var record: AudioEffectRecord
func run() -> void:
	folder="/tmp/space-polish-v2-20260909"
	if "--crew-folder=/tmp/space-polish-v2-20260909" not in OS.get_cmdline_user_args():quit(1);return
	DirAccess.make_dir_recursive_absolute(folder)
	var owner:=FrontierPlayerProfile.new_character("우주 시청각 확인",0)
	FrontierWorldStore.new(folder+"/world.json").write(FrontierUniverse.new_world(61739))
	var profile:=FrontierPlayerProfile.new(folder+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.session.active and app.flight!=null,"actual expedition ready",50):quit(1);return
	if not await until(func():return root.has_focus(),"game window focused",45):quit(1);return
	app.close_menus();app.onboarding.letter.hide();app.outside=true;app.exterior_view.show();app.if_flight_view();root.gui_release_focus()
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	app.set_physics_process(false);app.session.set_process(false);app.session.set_physics_process(false)
	await create_timer(1).timeout
	check(app.soundtrack.music.discovery.stream!=null and app.soundtrack.music.danger.stream!=null,"both generated music variations imported")
	await capture("actual-earth-start")
	var world: Dictionary=app.session.authority.world
	# Run the real authority's steering, then publish acknowledged movement.
	for i in 16:
		FrontierCrewNavigation.steer(world,[1.0,.35,.1,1.0],.1);world.crew.navigation.orbit_time+=.1;app.session._publish();await create_timer(.1).timeout
	check(app.flight.drive.thrust>.05 and app.flight.vessel_sound.layers.exhaust.playing,"authority flight drives exhaust visuals and layered audio")
	check(app.flight.drive.attitude_jets.any(func(j: GPUParticles3D):return j.emitting),"turning activates attitude jets")
	await capture("actual-boost-turn")
	record=AudioEffectRecord.new();AudioServer.add_bus_effect(0,record);record.set_recording_active(true)
	await create_timer(2).timeout
	record.set_recording_active(false);var mixed:=record.get_recording();mixed.save_to_wav(folder+"/flight-mix.wav");AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	report.audio.mix_duration=mixed.get_length();report.audio.sfx_peak_db=AudioServer.get_bus_peak_volume_left_db(AudioServer.get_bus_index("SFX"),0)
	check(report.audio.sfx_peak_db> -70,"game SFX bus has an audible signal")
	app.open_menu(app.navigation_ui.pause_frame);await create_timer(.3).timeout
	check(app.flight.vessel_sound.layers.exhaust.stream_paused and app.soundtrack.music.space.stream_paused,"actual pause menu suspends engines and music")
	app.close_menus();await create_timer(.3).timeout
	check(not app.flight.vessel_sound.layers.exhaust.stream_paused,"closing menu resumes propulsion")
	for i in 18:
		FrontierCrewNavigation.steer(world,[0.0,0.0,0.0],.1);world.crew.navigation.orbit_time+=.1;app.session._publish();await create_timer(.1).timeout
	await capture("actual-braking")
	# Real acknowledged depart route; no save injection or new financial gameplay.
	var nearby:=FrontierStellarRoutes.nearby(world.manifest,0,FrontierVesselRefit.stellar_range(world))
	if nearby.is_empty():check(false,"reachable departure target");quit(1);return
	var target:=FrontierUniverse.first_ordinal(world.manifest,int(nearby[0].index))
	app.session.send_request("navigate",{"ordinal":target});app.travel_action("depart")
	world=app.session.authority.world
	check(world.crew.navigation.mode=="jump","host accepts the existing departure action")
	for i in 126:
		FrontierCrewNavigation.step(world,.1);app.session._publish();await create_timer(.1).timeout
		if i==8:await capture("actual-jump-charge")
		if i==37:await capture("actual-jump-travel")
		if i==116:await capture("actual-jump-quiet")
	await create_timer(1).timeout
	check(app.soundtrack.current_mood=="discovery" and app.soundtrack.music.discovery.playing,"actual arrival selects discovery variation")
	await capture("actual-arrival")
	world.crew.navigation.star_warning=true;app.session._publish();await create_timer(3).timeout
	check(app.soundtrack.current_mood=="danger" and app.soundtrack.music.danger.playing,"acknowledged hazard selects danger variation")
	world.crew.navigation.star_warning=false;world.crew.navigation.speed=450;app.session._publish()
	app.flight.refits.update_loadout({"hull":"finch"})
	if not await until(func():return app.flight.refits.requested_hull.is_empty(),"FINCH visual loaded",10):quit(1);return
	await create_timer(.7).timeout
	check(app.flight.drive.finch and float(app.flight.vessel_sound.gains.finch)>float(app.flight.vessel_sound.gains.turbine),"FINCH nozzle layout and turbine mix selected")
	await capture("actual-finch")
	app.outside=false;app.exterior_view.hide();app.if_flight_view();await create_timer(.6).timeout
	check(app.flight.vessel_sound.layers.finch.bus=="SpaceCabin","interior camera uses filtered hull audio")
	await capture("actual-cabin")
	root.size=Vector2i(960,640);root.content_scale_size=root.size;app.outside=true;app.exterior_view.show();app.if_flight_view();await capture("actual-flight-960")
	world.crew.navigation.speed=0;app.session._publish()
	check(await app.session.close_session(),"isolated expedition saves and closes")
	app.queue_free();await process_frame;await process_frame
	report.checks=checks;report.failures=failures
	var file:=FileAccess.open(folder+"/verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("SPACE_POLISH_PLAY ",checks," FAILURES ",failures);quit(1 if failures else 0)
