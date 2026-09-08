extends "res://tests/test_solo_entry.gd"
func run() -> void:
	folder="/tmp/research-a05-ui"
	if "--crew-folder=/tmp/research-a05-ui" not in OS.get_cmdline_user_args():quit(1);return
	DirAccess.make_dir_recursive_absolute(folder)
	var owner:=FrontierPlayerProfile.new_character("공동 연구 확인",0)
	FrontierWorldStore.new(folder+"/world.json").write(FrontierUniverse.new_world(71491))
	var profile:=FrontierPlayerProfile.new(folder+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.session.active and app.flight!=null and not has_meta("startup_loader"),"basic ship scene starts with shared ledger",60):quit(1);return
	app.outside=false;app.exterior_view.hide();app.if_flight_view();app.close_menus();app.onboarding.letter.hide()
	var bench: FrontierCrewStation=app.stations.cabin.get_node("Station_research")
	var actor: CharacterBody3D=app.actors[owner.character_id]
	actor.position=bench.global_position+bench.global_basis.z*2.1+Vector3.UP*.1;app.session.authority.update_position(1,actor.position)
	var direction: Vector3=(bench.interaction_point()-(actor.position+Vector3.UP*1.72)).normalized();app.yaw=atan2(-direction.x,-direction.z);app.pitch=asin(direction.y)
	var world: Dictionary=app.session.authority.world
	world.business=FrontierExpeditionBusiness.create();world.business.bags[owner.character_id]=FrontierExpeditionBusiness.inventory();world.business.bags[owner.character_id].sapphire=3
	FrontierExpeditionResearch.record(world,world.location,"sapphire","fixture:discovery",2,"extraction",owner.character_id)
	app.session._publish();await create_timer(.3).timeout
	check(app.stations.resolve(owner.character_id,"ship:research").position.distance_to(bench.interaction_point())<.01,"live provider uses the research bench socket")
	var event:=InputEventKey.new();event.physical_keycode=KEY_F;event.pressed=true;Input.parse_input_event(event);await process_frame
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event);await process_frame
	check(app.stations.panel.visible and app.stations.selected=="research","F still opens the actual research bench")
	# A05 exposes the host contract; the visual specimen submission UI is A06.
	app.session.send_request("research_contribute",{"station_id":"ship:research","project":"deep_mining","resource":"sapphire","amount":3,"expected_stage":"discovered"})
	check(app.session.latest.expedition_research.projects.deep_mining.stage=="analyzed" and app.session.latest.inventory.sapphire==0,"live session commits sample contribution and publishes shared analysis")
	check(app.stations.resolve(owner.character_id,"ship:augmentation").position!=bench.interaction_point(),"augmentation keeps its own device location")
	await capture("research-bench-a05")
	await app.session.close_session();app.queue_free();await process_frame;await process_frame
	check(FrontierWorldStore.new(folder+"/world.json").read_state().expedition_research.projects.deep_mining.stage=="analyzed","actual game save reload keeps analyzed stage")
	print("RESEARCH_STATION_A05 ",checks," FAILURES ",failures);quit(1 if failures else 0)
