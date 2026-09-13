extends "res://tests/test_solo_entry.gd"
## Focused reproduction: returning character, fresh expedition, full opening and scan overlap.
func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--crew-folder="):folder=argument.trim_prefix("--crew-folder=")
	assert(not folder.is_empty() and not FileAccess.file_exists(folder+"/world.json"), "Use a fresh isolated --crew-folder")
	DirAccess.make_dir_recursive_absolute(folder)
	var profile:=FrontierPlayerProfile.new(folder+"/profile.json")
	assert(profile.ensure("출항 확인"))
	assert(profile.remember("a".repeat(32),"b".repeat(64)))
	var old_progress: Dictionary={"eligible":true,"solar_move":true,"solar_boost":true,"solar_scan":true,"complete":false}
	var previous:=ConfigFile.new()
	previous.set_value("players",profile.data.character.character_id,old_progress)
	assert(previous.save(folder+"/play_guide.cfg")==OK)
	root.size=Vector2i(1280,800)
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
	await process_frame
	app.start_solo()
	app.session.set_physics_process(false)
	if not await until(func():return app.flight!=null and not app.preparing_first_snapshot,"fresh solo scene prepared",180):quit(1);return
	app.set_physics_process(false)
	root.grab_focus()
	var guide:=app.onboarding
	check(not guide.new_player and guide.solar_step()=="move","old character's step 04 does not carry into a new expedition")
	check(guide.player_key==app.session.latest.galaxy_id+":"+app.session.latest.self_id,"guide progress belongs to character and expedition")
	check(not guide._practice_allowed(),"opening cannot complete movement practice")
	var world: Dictionary=app.session.authority.world
	var nav: Dictionary=world.crew.navigation
	var shot: Dictionary=nav.solar_opening
	check(FrontierSolarOpening.valid(shot) and shot.version==2,"new opening is saved as version 2")
	var unrelated:=world.duplicate()
	unrelated.erase("crew");unrelated.erase("flight_position")
	var world_before:=JSON.stringify(unrelated)
	var members_before:=JSON.stringify(world.crew.members)
	var start:=FrontierCrewWorld.vector(nav.position)
	var earth:=FrontierUniverse.position(world.manifest,2)
	check(start.distance_to(earth)<651 and FrontierCrewWorld.vector(nav.direction).dot((earth-start).normalized())>.999,"opening starts close to Earth and faces Earth")
	check(app.flight.atmosphere_overlay==null or not app.flight.atmosphere_overlay.visible,"opening hides atmosphere observation with no target")
	var trace: Array=[]
	var near_earth:=true
	var clear_route:=true
	var forward_motion:=true
	var held_for_turn:=true
	# Advance the ordinary navigation domain clock, publishing to the actual game
	# scene. Window focus and unrelated simulation cannot skip screenshot moments.
	for tick in 85:
		FrontierCrewNavigation.step(world,.1)
		app.session._publish()
		var point:=FrontierCrewWorld.vector(nav.position)
		earth=FrontierUniverse.position(world.manifest,2,float(nav.orbit_time))
		var distance:=point.distance_to(earth)
		near_earth=near_earth and distance<960 and nav.system==0 and nav.mode=="idle"
		if float(shot.elapsed)<=float(shot.move_start):held_for_turn=held_for_turn and point.distance_to(start)<.01
		if float(nav.speed)>1:forward_motion=forward_motion and FrontierCrewWorld.vector(nav.direction).dot((point-earth).normalized())>.999
		for ordinal in 8:
			var center:=FrontierUniverse.position(world.manifest,ordinal,float(nav.orbit_time))
			clear_route=clear_route and point.distance_to(center)>FrontierUniverse.navigation_radius(FrontierUniverse.body(world.manifest,ordinal))+180
		trace.append({"time":shot.elapsed,"earth_distance":distance,"speed":nav.speed,"direction_dot_earth":FrontierCrewWorld.vector(nav.direction).dot((earth-point).normalized())})
		await create_timer(.1).timeout
		if tick==9:await capture("01-earth")
		if tick==31:await capture("02-turn")
		if tick==66:await capture("03-departure")
	# Avoid floating point accumulation leaving the final frame below duration.
	FrontierCrewNavigation.step(world,.01);app.session._publish()
	check(near_earth and clear_route,"entire route stays near Earth with planetary clearance")
	check(held_for_turn and forward_motion,"ship turns naturally before a short forward departure")
	check(not FrontierSolarOpening.active(nav) and absf(float(nav.speed))<.01,"opening hands over stopped without jump or continued acceleration")
	check(FrontierCrewNavigation.orientation(nav).is_equal_approx(Basis(FrontierSolarOpening.pose(shot,float(shot.duration)).rotation)),"handoff preserves final orientation including up")
	unrelated=world.duplicate();unrelated.erase("crew");unrelated.erase("flight_position")
	check(JSON.stringify(unrelated)==world_before and JSON.stringify(world.crew.members)==members_before,"opening changes navigation and flight position only")
	var legacy:=shot.duplicate(true)
	legacy.version=1;legacy.erase("move_start");legacy.focus=legacy.start_focus.duplicate()
	check(FrontierSolarOpening.valid(legacy) and FrontierSolarOpening.pose(legacy,float(legacy.duration)).direction.dot((FrontierCrewWorld.vector(legacy.start_focus)-FrontierCrewWorld.vector(legacy.finish)).normalized())>.98,"stored version 1 path retains its original pose")
	check(guide.letter.visible,"full opening reaches Lotus welcome")
	await capture("04-welcome")
	for button in guide.letter.find_children("*","Button",true,false):
		if button.text=="확인":button.pressed.emit()
	await until(func():return guide.card.visible and guide.step=="move","welcome confirmation shows guide 01",10)
	await capture("05-guide-01")
	check(guide.counter.text.contains("01 / 07"),"visible guide starts at 01")
	check(guide.z_index==0 and guide.get_index()<app.field_hud.get_index() and guide.letter.z_index==90,"guide draws below field results and welcome keeps modal depth")
	guide.progress.solar_move=true;guide._save()
	guide.player_key="";guide.update_snapshot(app.session.latest)
	check(guide.solar_step()=="boost","same expedition keeps completed practice on reread")
	var saved_guide:=ConfigFile.new();saved_guide.load(folder+"/play_guide.cfg")
	check(saved_guide.get_value("players",profile.data.character.character_id)==old_progress,"legacy character guide record is preserved")
	# Keep the actual scan renderer and guide layout, inject only a completed
	# Mars report; this is a display reproduction, not a scan-input test.
	app.flight.set_process(false)
	guide.progress.solar_boost=true;guide.progress.solar_scan=true;guide._save()
	var overlay=app.flight.transit_overlay
	overlay.opening=false;overlay.arrival_age=100;overlay.presentation_blocked=false
	overlay.scan_body=FrontierUniverse.body(world.manifest,3);overlay.scan_progress=1.0;overlay.atmosphere_ready=false
	for viewport_size in [Vector2i(1280,800),Vector2i(960,640)]:
		root.size=viewport_size;root.content_scale_size=viewport_size
		await create_timer(.3).timeout
		guide._process(.1)
		var scale_factor:=maxf(app.exterior_view.size.x/app.space_view.size.x,app.exterior_view.size.y/app.space_view.size.y)
		var offset: Vector2=app.exterior_view.global_position-(Vector2(app.space_view.size)*scale_factor-app.exterior_view.size)*.5
		var scan_box: Rect2=overlay.scan_result_rect()
		var screen_box:=Rect2(offset+scan_box.position*scale_factor,scan_box.size*scale_factor)
		check(scan_box.has_area() and (not guide.card.visible or not guide._overlaps_result(screen_box,guide._target(app.navigation_ui.context))),"scan and context stay clear of guidance at "+str(viewport_size))
		if viewport_size.x==1280:check(guide.card.visible,"normal viewport keeps guidance beside scan")
		await capture("06-scan-"+str(viewport_size.x))
	overlay.scan_body={};guide._process(.1)
	check(guide.card.visible,"guidance returns after scan result closes")
	var file:=FileAccess.open(folder+"/route.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(trace,"\t"));file.close()
	check(await app.session.close_session(),"isolated expedition saves and closes")
	app.queue_free();await process_frame
	print("EARTH_DEPARTURE_GUIDE_CHECKS ",checks," FAILURES ",failures)
	quit(1 if failures else 0)
