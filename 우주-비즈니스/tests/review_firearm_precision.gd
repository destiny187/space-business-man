extends "res://tests/review_firearm_upgrade.gd"
func run() -> void:
	folder="/tmp/firearm-precision-play-20260913"
	if not "--crew-ui-test" in OS.get_cmdline_user_args() or not ("--crew-folder="+folder) in OS.get_cmdline_user_args():quit(2);return
	var owner:=fixture()
	if owner.is_empty():quit(1);return
	var bag:=FrontierExpeditionBusiness.bag(core.world,actor_id)
	bag.copper=20;bag.crystal=10
	for id in FrontierFirearms.config().ammunition:bag[id]=int(FrontierFirearms.config().ammunition[id].amount)
	DirAccess.make_dir_recursive_absolute(folder);root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var store:=FrontierWorldStore.new(folder+"/world.json")
	if not store.write(core.world):printerr("FIXTURE_SAVE ",store.last_error," BAG ",bag);quit(1);return
	var profile:=FrontierPlayerProfile.new(folder+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"Forward+ ground loaded",90):quit(1);return
	app.close_menus();app.onboarding.letter.hide();FrontierClientSettings.ensure(self).values.tutorial_mode=2;app.outside=false;app.exterior_view.hide();app.if_flight_view()
	core=app.session.authority
	var approach:=FrontierCrewWorld.vector(source.position)+Vector3(0,0,10);approach.y=app.surface_world.terrain.field.height(approach.x,approach.z)+.1
	app.actors[actor_id].position=approach;app.actors[actor_id].velocity=Vector3.ZERO;core.update_position(1,approach);core.motions[actor_id]=FrontierCrewLocomotion.create()
	if not await until(func():return app.surface_world.ready_at(app.actors[actor_id].position) and app.surface_world.incidents.models.has(robot_key),"combat ground streamed",55):quit(1);return
	# Restoring an isolated surface fixture puts its disconnected cargo in a crate.
	core.resolve_autonomous(true)
	bag=FrontierExpeditionBusiness.bag(core.world,actor_id)
	for crate in core.world.business.crates.values():FrontierExpeditionBusiness.transfer(bag,crate.inventory,1);crate.inventory=FrontierExpeditionBusiness.inventory()
	core.gun_dirty=true;app.session._publish()
	app.session.firearm_event_received.connect(func(e):events.append(e))
	var record:=AudioEffectRecord.new();record.format=AudioStreamWAV.FORMAT_16_BITS
	var bus:=AudioServer.get_bus_index("SFX");AudioServer.add_bus_effect(bus,record);record.set_recording_active(true)
	await create_timer(.6).timeout

	for family in FrontierFirearms.config().families:
		var definition: String=""
		for key in FrontierEquipment.config().items:
			if FrontierEquipment.config().items[key].get("firearm")==family:definition=key;break
		await transaction("equipment_equip",{"slot":2,"item_id":"fixture:"+definition})
		await create_timer(.65).timeout
		core.resolve_autonomous(true);reset_target()
		var gun:=app.firearm.tool()
		look_at_point(FrontierExplorationIncidents.point(source,Vector3(0,1.5,0)));await create_timer(.12).timeout
		var original_pitch:=app.pitch;var count_before:=app.firearm.predicted_shots
		app.firearm.shoot()
		check(app.firearm.predicted_shots==count_before+1,"trigger motion starts immediately "+family)
		await until(func():return events.any(func(e):return not e.get("impact_only",false) and e.family==family),"authoritative shot "+family,3)
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(folder+"/"+family+"-fire.png")
		check(is_instance_valid(app.firearm.hands) and app.firearm.hands.grip_error<.025,"shoulder/elbow IK reaches hand contact "+family)
		await create_timer(.7).timeout
		check(absf(app.pitch-original_pitch)<.001,"camera recoil recovers without permanent drift "+family)
		app.firearm.reload()
		if await until(func():return app.firearm.reload_left>0,"reload begins "+family,3):
			await create_timer(app.firearm.reload_duration*.36).timeout
			await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(folder+"/"+family+"-reload.png")
			check(app.firearm.hands.grip_error<.035,"elbow follows family reload contact "+family)
			await create_timer(app.firearm.reload_duration*.70+.2).timeout
		if family=="laser":
			var member: Dictionary=core.world.crew.members[actor_id];var state:=FrontierFirearms.ensure(member,gun)
			state.ammo=60;state.heat=0;state.overheated=false;state.cooldown=0;app.session._publish()
			app.pitch=.25;await create_timer(.1).timeout
			for i in 20:
				app.firearm.shoot();await create_timer(.12).timeout
				if i==4:
					check(app.firearm.gun_effects.active.filter(func(e):return e.kind=="beam").size()==1 and app.firearm.beam_audio.size()==1,"held laser retains one beam and one audio voice")
					await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(folder+"/laser-sustain.png")
			check(app.firearm.accepted.get("overheated",false),"actual sustained firing reaches thermal lock")
			await capture("laser-hot")
			await create_timer(.3).timeout
			check(app.firearm.beam_audio.is_empty() and not app.firearm.gun_effects.active.any(func(e):return e.kind=="beam"),"trigger release stops beam and looping audio")
			await create_timer(4).timeout
			check(not app.firearm.accepted.get("overheated",true),"thermal HUD unlock follows host cooling")
	app.open_menu(app.inventory_panel);app.inventory_panel.tabs.current_tab=6
	root.size=Vector2i(960,640);root.content_scale_size=root.size;await create_timer(.5).timeout
	var panel: Node=app.inventory_panel.tabs.get_child(6)
	check(panel.cards.size()==6 and ResourceLoader.exists("res://assets/ui/resources/ammo_energy.png"),"six model ammunition cards including laser cells")
	await capture("ammunition-960")
	check(app.firearm.beam_audio.is_empty() and app.firearm.gun_effects.active.is_empty(),"menu silences and clears all firearm presentation")
	record.set_recording_active(false);var mixed:=record.get_recording()
	if mixed!=null:mixed.save_to_wav(folder+"/runtime-audio.wav")
	check(mixed!=null and mixed.get_length()>5,"actual SFX bus recorded")
	AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
	check(await app.session.close_session(),"modified weapon states saved")
	app.queue_free();await process_frame;await process_frame
	print("FIREARM_PRECISION_PLAY ",checks," FAILURES ",failures);quit(1 if failures else 0)
