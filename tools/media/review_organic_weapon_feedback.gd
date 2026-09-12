extends "res://tests/check_wildlife_combat.gd"
## Only the remaining organic contact, scoped shot, ground hit and blocked shot paths.
func run() -> void:
	folder="/tmp/ground-organic-feedback"
	if "--crew-ui-test" not in OS.get_cmdline_user_args() or ("--crew-folder="+folder) not in OS.get_cmdline_user_args():quit(2);return
	if "--scope-only" in OS.get_cmdline_user_args():await scope_only();return
	check(fixture(),"natural animal fixture")
	if chosen.is_empty():quit(1);return
	for id in FrontierEquipment.config().items:
		if FrontierEquipment.config().items[id].get("firearm")=="sniper":core.world.crew.members[actor_id].loadout.items["fixture:sniper"]=id;break
	DirAccess.make_dir_recursive_absolute(folder)
	var store:=FrontierWorldStore.new(folder+"/world.json");check(store.write(core.world),"organic fixture saved")
	var profile:=FrontierPlayerProfile.new(folder+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"organic Forward+ ready",100):quit(1);return
	core=app.session.authority;app.close_menus();app.onboarding.letter.hide();FrontierClientSettings.ensure(self).values.tutorial_mode=2;app.outside=false;app.exterior_view.hide();app.if_flight_view()
	var at:=home+Vector3(0,0,8);at.y=field.height(at.x,at.z)+.2;place(at)
	if not await until(func():return app.surface_world.ecology.actors.has(chosen.id) and app.surface_world.ready_at(app.actors[actor_id].position),"actual animal and ground collision loaded",60):quit(1);return
	animal=app.surface_world.ecology.actors[chosen.id]
	await create_timer(.4).timeout
	app.session.response_received.connect(func(_sequence,result):
		if not result.get("ok",false):print("FEEDBACK_REJECTION ",result))
	if not await until(func():return core.inputs.get(1,{}).get("controls_enabled",false),"host ground controls acknowledged",8):quit(1);return
	if "--terrain-only" in OS.get_cmdline_user_args():
		await terrain_shot()
		if "--scope-check" in OS.get_cmdline_user_args():await scoped_shot()
		check(await app.session.close_session(),"terrain review saves")
		app.queue_free();await process_frame;await process_frame
		print("TERRAIN_FEEDBACK_REVIEW ",checks," FAILURES ",failures);quit(1 if failures else 0);return
	var recorder:=AudioEffectRecord.new();recorder.format=AudioStreamWAV.FORMAT_16_BITS
	var bus:=AudioServer.get_bus_index("SFX");AudioServer.add_bus_effect(bus,recorder);recorder.set_recording_active(true)
	var event: Dictionary={}
	for attempt in 3:
		aim();await RenderingServer.frame_post_draw;app.firearm.shoot()
		event=core.world.crew.members[actor_id].get("weapon_event",{})
		if event.get("hits",{}).get("organic",false):break
		print("ORGANIC_ATTEMPT ",event," enabled=",app.firearm.enabled()," next=",app.firearm.next_shot)
		await create_timer(.25).timeout
	check(event.get("contacts",[]).any(func(hit):return hit.kind=="organic"),"host reports real organic contact")
	check(app.feedback.audio.last_played.has("sfx_gun_hit_organic"),"short organic confirmation plays")
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(folder+"/organic-impact.png")
	await create_timer(.6).timeout
	await terrain_shot()
	await create_timer(.25).timeout
	var count: int=app.firearm.gun_effects.emitted.muzzle
	core.shot_obstacle_provider=func(_id,_origin,_direction,_reach):return .1
	app.firearm.shoot()
	check(int(app.firearm.gun_effects.emitted.muzzle)==count,"host rejection creates no shot flash")
	core.shot_obstacle_provider=app._shot_obstacle_distance
	app.session.send_request("equipment_equip",{"slot":2,"item_id":"fixture:sniper"});app.firearm.test_ads=true;app.pitch=.3
	await create_timer(.5).timeout
	count=app.firearm.gun_effects.emitted.muzzle;app.firearm.shoot()
	check(core.world.crew.members[actor_id].weapon_event.get("family","")=="sniper" and not app.feedback.handheld.visible and int(app.firearm.gun_effects.emitted.muzzle)==count,"scope keeps muzzle flash out of accepted shot")
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(folder+"/scoped-shot.png")
	await create_timer(.6).timeout;recorder.set_recording_active(false);recorder.get_recording().save_to_wav(folder+"/organic-runtime.wav")
	AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
	check(await app.session.close_session(),"organic encounter saves")
	app.queue_free();await process_frame;await process_frame
	print("ORGANIC_FEEDBACK_REVIEW ",checks," FAILURES ",failures);quit(1 if failures else 0)

func terrain_shot() -> void:
	# Both tree/render signals can resume inside the old frame; wait for the actual camera state.
	app.pitch=-1.3
	if not await until(func():return app.camera.rotation.x< -1.2,"downward camera updated",3):return
	app.firearm.shoot()
	var event: Dictionary=core.world.crew.members[actor_id].get("weapon_event",{})
	check(event.get("contacts",[]).any(func(hit):return hit.kind=="surface"),"terrain hit creates surface contact")
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(folder+"/terrain-impact.png")

func scope_only() -> void:
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.surface_world!=null and not has_meta("startup_loader"),"saved scope scene ready",90):quit(1);return
	core=app.session.authority;actor_id=app.session.latest.self_id
	app.close_menus();app.onboarding.letter.hide();app.outside=false;app.exterior_view.hide();app.if_flight_view()
	if not await until(func():return app.surface_world.ready_at(app.actors[actor_id].position),"scope ground collision ready",60):quit(1);return
	await scoped_shot()
	await create_timer(.3).timeout;check(await app.session.close_session(),"scope saves")
	app.queue_free();await process_frame;await process_frame
	print("SCOPE_FEEDBACK_REVIEW ",checks," FAILURES ",failures);quit(1 if failures else 0)

func scoped_shot() -> void:
	app.session.send_request("equipment_equip",{"slot":2,"item_id":"fixture:sniper"});app.firearm.test_ads=true;app.pitch=.3
	await create_timer(.5).timeout;app.firearm.shoot()
	check(core.world.crew.members[actor_id].weapon_event.get("family","")=="sniper" and not app.feedback.handheld.visible,"accepted scoped shot")
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(folder+"/scoped-shot.png")
	var traces:=app.firearm.gun_effects.active.filter(func(e):return e.kind=="tracer")
	check(not traces.is_empty() and traces.all(func(e):return app.camera.global_position.distance_to(e.start)>3),"scope trace begins beyond near field")
