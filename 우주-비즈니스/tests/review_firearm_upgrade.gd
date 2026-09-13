extends "res://tests/check_ground_combat.gd"
var events: Array=[]
func run() -> void:
	folder="/tmp/firearm-upgrade-play-20260913"
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
	if "--final-edges" in OS.get_cmdline_user_args():await final_edges();return
	for family in FrontierFirearms.config().families:
		if family=="laser":continue # Dedicated sustained-beam review lives in review_firearm_precision.gd.
		var definition: String=""
		for key in FrontierEquipment.config().items:
			if FrontierEquipment.config().items[key].get("firearm")==family:definition=key;break
		await transaction("equipment_equip",{"slot":2,"item_id":"fixture:"+definition})
		if not await until(func():return app.firearm.tool().get("firearm")==family,"equip "+family,4):continue
		await create_timer(.5).timeout
		reset_target();app.firearm.test_ads=false;look_at_point(FrontierExplorationIncidents.point(source,Vector3(0,1.45,0)))
		await create_timer(.18).timeout
		var gun:=app.firearm.tool();var before:=int(app.firearm.accepted.get("ammo",gun.magazine));events.clear()
		var start:=Time.get_ticks_msec();app.firearm.shoot()
		await until(func():return events.any(func(e):return not e.get("impact_only",false) and e.family==family),"host shot event "+family,2)
		check(int(app.firearm.accepted.get("ammo",gun.magazine))==before-1,"one round consumed "+family)
		check(is_instance_valid(app.firearm.hands) and app.firearm.hands.skeletons.size()==2,"both articulated hands connected "+family)
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(folder+"/"+family+"-fire.png")
		await until(func():return events.any(func(e):return e.get("impact_only",false) and e.family==family),"swept impact event "+family,2)
		print("SHOT_THROUGH_IMPACT_WAIT_MS ",family," ",Time.get_ticks_msec()-start)
		check(app.feedback.audio.last_played.has(gun.sound),"dedicated ElevenLabs shot "+family)
		if family in ["carbine","sniper"]:
			app.firearm.test_ads=true;await create_timer(.5).timeout
			check(absf(app.camera.fov-float(gun.ads_fov))<.2,"family ADS field of view "+family)
			await capture(family+"-ads");app.firearm.test_ads=false
		await create_timer(.5).timeout;app.firearm.reload()
		if await until(func():return app.firearm.reload_left>0,"reload begins "+family,2):
			await create_timer(app.firearm.reload_duration*.30).timeout
			await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(folder+"/"+family+"-mag-out.png")
			await create_timer(app.firearm.reload_duration*.37).timeout
			await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(folder+"/"+family+"-mag-in.png")
			await create_timer(app.firearm.reload_duration*.40+.2).timeout
			check(app.feedback.audio.last_played.has("sfx_gun_mag_out") and app.feedback.audio.last_played.has("sfx_gun_mag_in") and app.feedback.audio.last_played.has("sfx_gun_charge"),"three reload sound stages "+family)
		await create_timer(.3).timeout
	app.open_menu(app.inventory_panel);app.inventory_panel.tabs.current_tab=6
	root.size=Vector2i(960,640);root.content_scale_size=root.size;await create_timer(.5).timeout
	var panel: Node=app.inventory_panel.tabs.get_child(6)
	check(panel.cards.size()==FrontierFirearms.config().ammunition.size() and panel.cards.ammo_light.picture!=null,"catalog ammunition model cards")
	check(panel.size.x<=app.inventory_panel.tabs.size.x+1,"ammunition panel fits 960px")
	await capture("ammunition-960")
	var ammo_before:=int(app.session.latest.inventory.get("ammo_light",0));core.resolve_autonomous(true);app.session._publish();panel.refresh();panel.action.pressed.emit()
	await until(func():return int(app.session.latest.inventory.get("ammo_light",0))==ammo_before+60,"UI crafts carried ammunition",4)
	check(app.firearm.gun_effects.active.is_empty(),"menu suppresses combat effects")
	app.close_menus();await create_timer(.4).timeout
	record.set_recording_active(false);var mixed:=record.get_recording()
	if mixed!=null:mixed.save_to_wav(folder+"/runtime-audio.wav")
	check(mixed!=null and mixed.get_length()>5,"actual SFX bus recorded")
	AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
	check(await app.session.close_session(),"actual combat and ammunition saved")
	app.queue_free();await process_frame;await process_frame
	print("FIREARM_PLAY_REVIEW ",checks," FAILURES ",failures);quit(1 if failures else 0)
func reset_target() -> void:
	var robot: Dictionary=core.world.incidents.records[robot_key]
	robot.hp=float(FrontierExplorationIncidents.config().robot.health);robot.shield=float(robot.shield_max);robot.shield_wait=8;robot.phase="waking";robot.time=0;robot.serial+=1

func transaction(kind: String,args: Dictionary) -> void:
	for attempt in 3:
		core.resolve_autonomous(true);app.session._publish()
		app.session.send_request(kind,args)
		await create_timer(.3).timeout
		if kind=="equipment_equip" and app.firearm.tool().get("item_id")==args.item_id:return

func final_edges() -> void:
	await transaction("equipment_equip",{"slot":2,"item_id":"fixture:smg_2"})
	await create_timer(.55).timeout
	core.resolve_autonomous(true)
	var member: Dictionary=core.world.crew.members[actor_id]
	var gun:=FrontierEquipment.active(member);var state:=FrontierFirearms.ensure(member,gun)
	state.ammo=0;state.reload_left=0;state.reload_rounds=0;state.cooldown=0
	core.world.business.bags[actor_id]["ammo_light"]=0;app.session._publish()
	await create_timer(.15).timeout
	var requests: Array=[]
	app.session.request_started.connect(func(seq,kind,_args):
		if kind=="surface_reload":requests.append(seq))
	for i in 12:
		app.firearm.shoot();await create_timer(.025).timeout
	check(requests.size()==1 and state.ammo==0,"holding empty automatic weapon sends one dry reload request")
	core.world.business.bags[actor_id]["ammo_light"]=3;core.gun_dirty=true;app.session._publish()
	await create_timer(.15).timeout;app.firearm.shoot()
	await until(func():return app.firearm.reload_left>0,"resupply releases empty-trigger latch",2)
	await create_timer(2.3).timeout
	check(core.world.crew.members[actor_id].loadout.weapon_states[gun.item_id].ammo==3 and core.world.business.bags[actor_id].ammo_light==0,"resupply loads actual partial magazine")
	app.open_menu(app.inventory_panel);app.inventory_panel.tabs.current_tab=6
	root.size=Vector2i(960,640);root.content_scale_size=root.size;await create_timer(.3).timeout
	var panel: Node=app.inventory_panel.tabs.get_child(6)
	core.resolve_autonomous(true);app.session._publish();panel.refresh()
	var publication_before:=app.session.surface_serial
	panel.action.pressed.emit();await create_timer(.03).timeout
	# Regular surface cadence can still publish; the direct command itself has no forced packet.
	await until(func():return panel.pending<0 and int(app.session.latest.inventory.get("ammo_light",0))==60,"final scoped ammo UI commit",3)
	await capture("ammunition-960-final")
	check(panel.cards.ammo_heavy.picture!=panel.cards.ammo_light.picture,"heavy and light cartridge cards use separate images")
	print("REGULAR_SURFACE_SERIAL_DELTA ",app.session.surface_serial-publication_before)
	check(await app.session.close_session(),"save final edge fixture")
	app.queue_free();await process_frame;await process_frame
	print("FIREARM_FINAL_EDGES ",checks," FAILURES ",failures);quit(1 if failures else 0)
