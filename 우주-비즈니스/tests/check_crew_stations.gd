extends "res://tests/test_solo_entry.gd"
func aim_station(node: FrontierCrewStation) -> void:
	var actor: CharacterBody3D=app.actors[app.session.latest.self_id]
	actor.position=node.global_position+node.global_basis.z*2.1+Vector3.UP*.1
	app.session.authority.update_position(1,actor.position)
	var direction: Vector3=(node.interaction_point()-(actor.position+Vector3.UP*1.72)).normalized()
	app.yaw=atan2(-direction.x,-direction.z);app.pitch=asin(direction.y)
	await create_timer(.25).timeout
func press_f() -> void:
	var event:=InputEventKey.new();event.physical_keycode=KEY_F;event.pressed=true
	Input.parse_input_event(event);await process_frame
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event);await process_frame
func run() -> void:
	folder="/tmp/crew-stations-a03"
	if "--crew-folder=/tmp/crew-stations-a03" not in OS.get_cmdline_user_args():quit(1);return
	DirAccess.make_dir_recursive_absolute(folder)
	var owner:=FrontierPlayerProfile.new_character("장치 배치 확인",0)
	check(FrontierWorldStore.new(folder+"/world.json").write(FrontierUniverse.new_world(71491)),"isolated world")
	var profile:=FrontierPlayerProfile.new(folder+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.session.active and app.flight!=null,"ship scene ready",60):quit(1);return
	app.outside=false;app.exterior_view.hide();app.if_flight_view();app.close_menus();app.onboarding.letter.hide();root.gui_release_focus()
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	await create_timer(.8).timeout
	var station: FrontierCrewStation=app.stations.cabin.get_node("Station_augmentation")
	check(station.scan!=null and station.tray!=null and station.socket!=null,"Blender scan and tray pivots imported")
	await aim_station(station)
	check(app.stations.target()=="augmentation","cabin device reachable and aimed")
	await capture("augmentation-cabin")
	await press_f()
	check(app.stations.panel.visible and app.stations.preview.model!=null and app.feedback.blocked(),"F opens actual device inspection and blocks tools")
	var opened_sound:=false
	for speaker in app.feedback.audio.get_children():
		if speaker is AudioStreamPlayer and speaker.playing and speaker.stream==app.feedback.audio.stream("sfx_pickup_resource"):opened_sound=true
	check(opened_sound,"existing ElevenLabs opening cue is playing")
	check(station.scan.position.distance_to(station.origins[station.scan].origin)>.01,"inspection moves scan head")
	root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("augmentation-inspect-960")
	check(app.stations.panel.get_global_rect().end.y<=640,"device page fits small viewport")
	app.close_menus()
	station=app.stations.cabin.get_node("Station_research");await aim_station(station);await capture("research-cabin")
	await press_f();check(app.stations.selected=="research" and app.stations.panel.visible,"F opens research bench")
	app.close_menus()
	# Real host station descriptor authorizes A02; no new purchasing UI in A03.
	station=app.stations.cabin.get_node("Station_augmentation");await aim_station(station)
	var world: Dictionary=app.session.authority.world
	world.business=FrontierExpeditionBusiness.create();world.business.bags[owner.character_id]=FrontierExpeditionBusiness.inventory();world.business.bags[owner.character_id].sapphire=3
	app.session.send_request("augmentation_upgrade",{"station_id":"ship:augmentation","field":"mobility","expected_level":0})
	check(app.session.authority.world.crew.members[owner.character_id].augmentation.levels.mobility==1,"live device authorizes atomic augmentation")
	# Arrange an orbit fixture; flight progression is outside station placement scope.
	world=app.session.authority.world
	var destination:=FrontierCrewNavigation.first_destination(world.manifest);var body:=FrontierUniverse.body(world.manifest,destination)
	world.crew.navigation.system=FrontierUniverse.system_index(world.manifest,destination);world.crew.navigation.target=destination
	world.crew.navigation.position=FrontierExpeditionBusiness.array(FrontierCrewNavigation.center(destination,world.manifest,float(world.crew.navigation.orbit_time))+Vector3.UP*(FrontierUniverse.navigation_radius(body)+1))
	app.session.send_request("ready",{"value":true});app.session.send_request("land",{})
	if not await until(func():return app.surface_world!=null and is_instance_valid(app.stations.surface) and not app.arrival.active,"landed service stations ready",60):quit(1);return
	station=app.stations.surface.get_node("Station_research");await aim_station(station)
	if not await until(func():return app.surface_world.ready_at(app.actors[owner.character_id].position),"service apron collision ready",60):quit(1);return
	await aim_station(station);await capture("research-surface")
	await press_f();check(app.stations.panel.visible and app.stations.selected=="research","landed service bench can be opened")
	app.close_menus()
	var descriptor:=app.stations.resolve(owner.character_id,"ship:augmentation")
	check(descriptor.get("area")=="surface" and descriptor.get("body_id")==app.surface_world.body.id,"service access follows main landing body")
	station=app.stations.surface.get_node("Station_augmentation");station.queue_free()
	check(app.stations.resolve(owner.character_id,"ship:augmentation").is_empty(),"removed device never authorizes a cached location")
	await app.session.close_session();app.queue_free();await process_frame;await process_frame
	print("CREW_STATIONS_A03 ",checks," FAILURES ",failures);quit(1 if failures else 0)
