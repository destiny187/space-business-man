extends "res://tests/check_facility_interactions.gd"
## One isolated first-landing fixture; time acceleration here is review-only.
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
	if folder.is_empty() or not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
	root.size=Vector2i(1280,800)
	DisplayServer.window_move_to_foreground()
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
	await process_frame;check(app.world_store.write(FrontierUniverse.new_world(71491)),"isolated new world")
	app.start_solo()
	if not await until(func():return app.session.active,15):check(false,"session");quit(1);return
	app.onboarding.letter.hide()
	var world: Dictionary=app.session.authority.world
	var ordinal:=FrontierCrewNavigation.first_destination(world.manifest)
	check(ordinal>=0,"new introductory cycle candidate")
	if ordinal<0:quit(1);return
	var body:=FrontierUniverse.body(world.manifest,ordinal);var nav: Dictionary=world.crew.navigation
	check(body.astro.intro_eligible,"introductory 16–30 h solar day and modest tilt")
	nav.system=body.system_ordinal;nav.target=ordinal;nav.mode="idle";nav.speed=0.0
	var point:=FrontierCrewNavigation.center(ordinal,world.manifest,float(nav.orbit_time))+Vector3(0,0,FrontierUniverse.navigation_radius(body)+30)
	nav.position=FrontierExpeditionBusiness.array(point);nav.direction=[0,0,-1];world.location=body.id
	app.session._publish();await process_frame;app.travel_action("land")
	if not await until(func():return app.surface_world!=null and not app.arrival.active,90):check(false,"actual landing");quit(1);return
	app.close_menus();app.arrival.cancel()
	world=app.session.authority.world;nav=world.crew.navigation
	var surface:=app.surface_world;var air=surface.atmosphere
	check(not air.cycles.is_empty(),"production sky connected")
	var region: Dictionary=world.celestial_regions[body.id]
	check(FrontierCrewSurfaceReplica.validate(FrontierCrewSurfaceReplica.packet(world,world.crew.owner_id),world.manifest),"landing longitude replicated")
	var base_time: float=nav.orbit_time
	var records: Array=[]
	var ship_point:=surface.landing_ship.global_position
	# Keep actual player eye height and show the ship, terrain and sky together.
	var look: Vector3=(ship_point+Vector3.UP*2.2-app.camera.global_position).normalized()
	app.yaw=atan2(-look.x,-look.z);app.pitch=asin(look.y)
	for phase in [0.0,.25,.5,.75]:
		var time: float=base_time+float(body.astro.mean_solar_seconds)/60.0*phase
		nav.orbit_time=time;nav.position=FrontierExpeditionBusiness.array(FrontierCrewNavigation.center(ordinal,world.manifest,time)+Vector3(0,0,FrontierUniverse.navigation_radius(body)+30))
		app.session._publish();air.sync_clock(time);air.update_cycles();air.paint()
		await create_timer(1.0).timeout
		check(air.sun.global_basis.z.normalized().distance_to(air.sky_state.sun_direction)<.001,"sun disk and light direction "+str(phase))
		await capture("cycle-"+str(int(phase*4)))
		records.append({"phase":phase,"sun_height":air.sky_state.sun_height,"ambient":surface.environment.ambient_light_energy,"lamp":surface.lamp.light_energy,"clock":air.clock_seconds})
		if phase==.5:
			check(air.daylight<.1 and surface.lamp.light_energy>0,"night worklight and readable ambient")
			DisplayServer.window_move_to_foreground();await create_timer(.5).timeout
			print("AMBIENCE_STATE ",app.feedback.audio.ambient_key," paused=",app.feedback.audio.ambient.stream_paused," focus=",DisplayServer.window_is_focused()," blocked=",app.feedback.blocked())
			check(app.feedback.audio.ambient.playing,"existing ElevenLabs ambience remains playing")
			var rover:=FrontierRoverActor.new();surface.add_child(rover);rover.set_headlights(true)
			check(rover.headlights.size()==2 and rover.headlights[0].visible,"two physical rover headlights")
			await process_frame;rover.queue_free()
			root.size=Vector2i(960,640);await create_timer(.3).timeout;await capture("cycle-night-small");root.size=Vector2i(1280,800)
			app.open_menu(app.navigation_ui.pause_frame);await create_timer(.4).timeout
			check(app.feedback.audio.ambient.stream_paused,"menu pauses ambience")
			var menu_time: float=nav.orbit_time;await create_timer(.3).timeout;check(nav.orbit_time>menu_time,"personal menu keeps world time running");app.close_menus()
	check(app.session.authority.checkpoint(),"cycles and region save")
	var saved:=app.world_store.read_state()
	check(not saved.is_empty() and saved.celestial_regions==world.celestial_regions,"region restored")
	var t: float=saved.crew.navigation.orbit_time
	var expected:=FrontierPlanetaryCycles.sky_state(body,t,region)
	var restored:=FrontierPlanetaryCycles.sky_state(FrontierUniverse.body(saved.manifest,ordinal),t,saved.celestial_regions[body.id])
	check(expected.sun_direction.distance_to(restored.sun_direction)<.0001,"saved/joined phase matches")
	FileAccess.open(folder+"/cycles.json",FileAccess.WRITE).store_string(JSON.stringify({"body":body.id,"astro":body.astro,"region":region,"samples":records,"failures":failures},"  "))
	print("CYCLES_PLAY_RESULT ",failures)
	await app.session.close_session();app.queue_free();await process_frame;await process_frame;quit(1 if failures else 0)
