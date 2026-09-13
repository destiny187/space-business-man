extends "res://tests/review_firearm_upgrade.gd"
func run() -> void:
	folder="/tmp/ground-shield-review-20260913"
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

	core.resolve_autonomous(true)
	var robot: Dictionary=core.world.incidents.records[robot_key]
	robot.shield=float(robot.shield_max);robot.shield_wait=30;robot.hp=float(FrontierExplorationIncidents.config().robot.health);robot.phase="waking";robot.time=0
	app.session._publish();await create_timer(.2).timeout
	look_at_point(FrontierExplorationIncidents.point(source,Vector3(0,1.5,0)));await create_timer(.15).timeout
	check(not app.surface_world.incidents.models[robot_key].has("shield"),"shielded ground robot has no enclosing visual shell")
	await capture("shield-ready")
	await shot("shield-hit",false)
	core.resolve_autonomous(true)
	robot=core.world.incidents.records[robot_key];robot.shield=3;robot.shield_wait=30;robot.phase="waking";robot.time=0
	app.session._publish();await create_timer(.3).timeout
	await shot("shield-break",true)
	var crack: Dictionary=FrontierFirearmEffects.config().confirmation["break"]
	check(app.feedback.audio.last_played.has(crack.sound),"distinct shield-break sound played after host confirmation")
	await create_timer(.3).timeout
	check(not app.firearm.gun_effects.active.any(func(e):return e.kind in ["contact","spark","arc","shard"]),"shield contact clears without persistent glow or fragments")
	await capture("shield-down")
	# Local incoming shield feedback uses the compact status meter and the same
	# clear break sound, not a full-screen blue frame or shattering shell.
	var instruments: FrontierFieldInstruments=app.find_children("*","FrontierFieldInstruments",true,false)[0] if not app.find_children("*","FrontierFieldInstruments",true,false).is_empty() else null
	if instruments==null:
		for node in app.find_children("*","Control",true,false):
			if node is FrontierFieldInstruments:instruments=node;break
	if instruments!=null:
		instruments.shield_flash=.16;instruments.shield_crack=.22
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(folder+"/incoming-shield.png")
		check(not instruments.shield_echoes.values().any(func(e):return e.has("mesh")),"crew feedback creates no shield sphere meshes")
	app.open_menu(app.inventory_panel);await create_timer(.15).timeout
	check(app.firearm.gun_effects.active.is_empty(),"menu clears the small shield contact effects")
	record.set_recording_active(false);var mixed:=record.get_recording()
	if mixed!=null:mixed.save_to_wav(folder+"/runtime-audio.wav")
	AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
	check(await app.session.close_session(),"unchanged shield state saved")
	app.queue_free();await process_frame;await process_frame
	print("GROUND_SHIELD_REVIEW ",checks," FAILURES ",failures);quit(1 if failures else 0)
func shot(label: String,breaking: bool) -> void:
	if not await until(func():return app.firearm.enabled() and app.firearm.draw_left<=0 and app.firearm.reload_left<=0 and app.firearm.pending.is_empty(),"weapon ready "+label,5):return
	# Screenshots and streaming can leave an autonomous save in flight. Finish
	# that isolated fixture transaction before exercising the actual shot path.
	core.resolve_autonomous(true)
	if not await until(func():return core.inputs.get(1,{}).get("controls_enabled",false) and float(core.inputs.get(1,{}).get("expires",0))>=Time.get_ticks_msec()/1000.0,"host input ready "+label,3):return
	core.resolve_autonomous(true)
	var count_before:=events.size()
	var replies: Array=[]
	var remember:=func(_sequence: int,result: Dictionary):replies.append(result)
	app.session.response_received.connect(remember)
	app.firearm.next_shot=0;app.firearm.shoot()
	var deadline:=Time.get_ticks_msec()+3000
	while Time.get_ticks_msec()<deadline and not events.slice(count_before).any(func(e):return e.get("impact_only",false)):
		await process_frame
	var hits:=events.slice(count_before).filter(func(e):return e.get("impact_only",false))
	print("SHIELD_CONTACT ",label," ",hits.map(func(e):return e.get("hits",{})))
	if hits.is_empty():print("SHOT_REPLIES ",replies," ENABLED ",app.firearm.enabled()," DRAW ",app.firearm.draw_left)
	app.session.response_received.disconnect(remember)
	check(not hits.is_empty() and bool(hits[0].hits.broken)==breaking,"host shield result "+label)
	var fx: Array=app.firearm.gun_effects.active
	check(not fx.any(func(e):return e.kind in ["arc","ring","shard"]),"no shield arcs, rings or flying fragments "+label)
	check(fx.filter(func(e):return e.kind in ["contact","spark"]).size()<=3,"shield effect stays at the contact point "+label)
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(folder+"/"+label+".png")
