extends "res://tests/test_solo_entry.gd"
func press(key: Key) -> void:
	var event:=InputEventKey.new();event.physical_keycode=key;event.pressed=true;Input.parse_input_event(event);await process_frame
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event);await process_frame
func run() -> void:
	folder="/tmp/suit-augmentation-play"
	if "--crew-folder=/tmp/suit-augmentation-play" not in OS.get_cmdline_user_args() or "--crew-ui-test" not in OS.get_cmdline_user_args():quit(1);return
	DirAccess.make_dir_recursive_absolute(folder)
	var owner:=FrontierPlayerProfile.new_character("증강 탐험가",2)
	FrontierWorldStore.new(folder+"/world.json").write(FrontierUniverse.new_world(71491))
	var profile:=FrontierPlayerProfile.new(folder+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.session.active and app.flight!=null and not has_meta("startup_loader"),"ship scene",60):quit(1);return
	if not app.test_mode or app.world_store.path!=folder+"/world.json" or app.session.latest.self_id!=owner.character_id:printerr("ISOLATION_MISMATCH");quit(1);return
	app.outside=false;app.exterior_view.hide();app.if_flight_view();app.close_menus();app.onboarding.letter.hide()
	var station: FrontierCrewStation=app.stations.cabin.get_node("Station_augmentation")
	var actor: CharacterBody3D=app.actors[owner.character_id]
	actor.position=station.global_position+station.global_basis.z*2.1+Vector3.UP*.1;app.session.authority.update_position(1,actor.position)
	var direction: Vector3=(station.interaction_point()-(actor.position+Vector3.UP*1.72)).normalized();app.yaw=atan2(-direction.x,-direction.z);app.pitch=asin(direction.y)
	var world: Dictionary=app.session.authority.world
	world.business=FrontierExpeditionBusiness.create();world.business.bags[owner.character_id]=FrontierExpeditionBusiness.inventory()
	for id in ["sapphire","ruby","emerald"]:world.business.bags[owner.character_id][id]=12

	app.session._publish();await process_frame
	var appearance: FrontierSuitAppearance=app.visuals[owner.character_id].appearance
	check(appearance.current_stages=={"mobility":0,"combat":0,"vitality":0},"base suit has no free augmentation layers")
	await press(KEY_F)
	var page: FrontierAugmentationPanel=app.stations.augmentation
	page.prepare_gem("sapphire");page.submit();await create_timer(1.3).timeout
	check(page.last_receipt.get("ok",false) and appearance.current_stages.mobility==1 and appearance.current_stages.combat==0 and appearance.current_stages.vitality==0,"host purchase adds only mobility armor")
	app.close_menus();app.toggle_inventory();app.inventory_panel.tabs.current_tab=3
	root.size=Vector2i(1280,800);root.content_scale_size=root.size;await capture("body-first")
	var readout: FrontierAugmentationReadout=app.inventory_panel.augmentation_readout
	check(readout.appearance.current_stages==appearance.current_stages,"I body preview matches real actor")
	world=app.session.authority.world
	for keys in FrontierSuitAppearance.config().branches.values():
		var left:=16
		for key in keys:world.crew.members[owner.character_id].augmentation.levels[key]=mini(left,5);left=maxi(0,left-5)
	app.session._publish();await capture("body-max")
	check(appearance.current_stages=={"mobility":5,"combat":5,"vitality":5} and readout.appearance.current_stages==appearance.current_stages,"existing ranks derive full armor on actor and preview")
	root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("body-max-960")
	check(await app.session.close_session(),"save and close")
	var saved:=FrontierWorldStore.new(folder+"/world.json").read_state()
	check(not saved.is_empty() and FrontierSuitAppearance.stages(saved.crew.members[owner.character_id])==appearance.current_stages,"reload derives same armor without cosmetic migration")
	app.queue_free();await process_frame;await process_frame
	print("SUIT_PLAY_CHECK ",checks," FAILURES ",failures);quit(1 if failures else 0)
