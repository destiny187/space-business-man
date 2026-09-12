extends "res://tests/check_ground_combat.gd"
## Narrow actual-window review using the established isolated combat fixture.
var timeline: Array=[]
var started:=0
func run() -> void:
	folder="/tmp/ground-weapon-feedback"
	if "--crew-ui-test" not in OS.get_cmdline_user_args() or ("--crew-folder="+folder) not in OS.get_cmdline_user_args():quit(2);return
	var owner:=fixture()
	if owner.is_empty():quit(1);return
	DirAccess.make_dir_recursive_absolute(folder);root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var store:=FrontierWorldStore.new(folder+"/world.json");check(store.write(core.world),"isolated fixture saved")
	var profile:=FrontierPlayerProfile.new(folder+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
	await process_frame;app.start_solo()
	if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"Forward+ ground loaded",90):quit(1);return
	app.close_menus();app.onboarding.letter.hide();FrontierClientSettings.ensure(self).values.tutorial_mode=2;app.outside=false;app.exterior_view.hide();app.if_flight_view()
	core=app.session.authority
	var approach:=FrontierCrewWorld.vector(source.position)+Vector3(0,0,9);approach.y=app.surface_world.terrain.field.height(approach.x,approach.z)+.1
	app.actors[actor_id].position=approach;app.actors[actor_id].velocity=Vector3.ZERO;core.update_position(1,approach);core.motions[actor_id]=FrontierCrewLocomotion.create()
	if not await until(func():return app.surface_world.ready_at(app.actors[actor_id].position) and app.surface_world.incidents.models.has(robot_key),"robot and ground streamed",55):quit(1);return
	await create_timer(.5).timeout
	var record:=AudioEffectRecord.new();record.format=AudioStreamWAV.FORMAT_16_BITS
	var bus:=AudioServer.get_bus_index("SFX");AudioServer.add_bus_effect(bus,record);record.set_recording_active(true);started=Time.get_ticks_msec()
	for family in FrontierFirearms.config().families:
		var definition: String=""
		for key in FrontierEquipment.config().items:
			if FrontierEquipment.config().items[key].get("firearm")==family:definition=key;break
		app.session.send_request("equipment_equip",{"slot":2,"item_id":"fixture:"+definition});await create_timer(.35).timeout
		reset_robot(500,500);look_at_point(FrontierExplorationIncidents.point(source,Vector3(0,1.5,0)))
		await create_timer(.15).timeout
		var gun:=app.firearm.tool();var stamp:=float(Time.get_ticks_msec()-started)/1000.0
		app.firearm.shoot()
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(folder+"/"+family+"-attack.png")
		var event: Dictionary=core.world.crew.members[actor_id].get("weapon_event",{})
		check(event.get("family","")==family and event.get("item_id","")==gun.item_id,"fresh accepted family event "+family)
		check(event.get("rays",[]).size()==int(gun.pellets) and event.get("contacts",[]).size()>0,"accepted pellet contacts "+family)
		check(event.get("contacts",[]).all(func(hit):return hit.point in event.rays or (family=="plasma" and hit.get("splash",false))),"contacts remain on their own ray or confirmed blast target "+family)
		check(app.feedback.audio.last_played.has(gun.sound),"family audio plays "+family)
		await create_timer(.05).timeout
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(folder+"/"+family+"-impact.png")
		if family in ["smg","carbine","lmg"]:
			for n in 4:
				await create_timer(float(gun.interval)+.035).timeout;reset_robot(500,500);app.firearm.shoot()
		timeline.append({"family":family,"from":stamp,"to":float(Time.get_ticks_msec()-started)/1000.0,"contacts":event.get("contacts",[])})
		await create_timer(maxf(.3,float(gun.interval))).timeout
	# Same accepted shot path for shield break, armor, weak point and defeat.
	app.session.send_request("equipment_equip",{"slot":2,"item_id":"fixture:pulse_2"});await create_timer(.35).timeout
	for kind in ["break","hit","weak","kill"]:
		reset_robot(500 if kind!="kill" else 1,1 if kind=="break" else 0)
		var target:=FrontierExplorationIncidents.point(source,Vector3(0,1.98,.52) if kind=="weak" else Vector3(0,1.5,0))
		if kind=="weak":core.world.incidents.records[robot_key].phase="cooling";core.world.incidents.records[robot_key].time=0
		app.firearm.test_ads=kind=="weak";look_at_point(target);await create_timer(.22).timeout
		app.firearm.shoot();await create_timer(.025).timeout
		check(app.firearm.hit_kind==kind,"distinct confirmed feedback "+kind+" actual="+app.firearm.hit_kind)
		timeline.append({"confirmation":kind,"at":float(Time.get_ticks_msec()-started)/1000.0})
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(folder+"/confirmed-"+kind+".png")
		await create_timer(.35).timeout
	app.firearm.test_ads=false
	# No host target: a real shot into open air must not produce a hit marker.
	app.pitch=1.2;app.firearm.hit_left=0;await create_timer(.2).timeout;app.firearm.shoot()
	check(core.world.crew.members[actor_id].weapon_event.get("contacts",[]).is_empty() and app.firearm.hit_left==0,"air shot has no invented impact")
	await create_timer(.25).timeout
	app.firearm.reload();await create_timer(.12).timeout
	app.open_menu(app.inventory_panel);await create_timer(.1).timeout
	check(app.firearm.gun_effects.active.is_empty() and app.feedback.audio.get_children().all(func(node):return not str(node.get_meta("cue","")).begins_with("sfx_gun_") or not node.playing),"menu clears firearm effects and sound")
	app.close_menus();root.size=Vector2i(960,640);root.content_scale_size=root.size
	reset_robot(500,500);look_at_point(FrontierExplorationIncidents.point(source,Vector3(0,1.5,0)))
	await create_timer(1.8).timeout;app.firearm.shoot();await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(folder+"/combat-960.png")
	await create_timer(.7).timeout;record.set_recording_active(false)
	var mixed:=record.get_recording();check(mixed!=null and mixed.get_length()>5,"actual SFX bus captured")
	if mixed!=null:mixed.save_to_wav(folder+"/runtime-mix.wav")
	AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
	var file:=FileAccess.open(folder+"/runtime-timeline.json",FileAccess.WRITE);file.store_string(JSON.stringify(timeline,"\t"));file.close()
	check(await app.session.close_session(),"isolated combat save closes")
	app.queue_free();await process_frame;await process_frame
	print("GROUND_FEEDBACK_REVIEW ",checks," FAILURES ",failures);quit(1 if failures else 0)

func reset_robot(hp: float,shield: float) -> void:
	var robot: Dictionary=core.world.incidents.records[robot_key]
	robot.hp=minf(hp,float(FrontierExplorationIncidents.config().robot.health));robot.shield=minf(shield,float(robot.shield_max))
	robot.shield_wait=float(FrontierExplorationIncidents.config().robot.shield_delay)
	robot.phase="waking";robot.time=0;robot.serial+=1
