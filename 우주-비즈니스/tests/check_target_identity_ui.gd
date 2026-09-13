extends "res://tests/check_wildlife_combat.gd"
## Focused regression: passive targeting is not an identification or a new scan.
func track(seconds: float) -> void:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		aim();await process_frame
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
	if folder.is_empty() or not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	check(fixture(),"natural animal fixture")
	if chosen.is_empty():quit(1);return
	var best_time:=0.0;var best_height:=-2.0
	for sample in range(0,20001,80):
		var sky:=FrontierPlanetaryCycles.sky_state(body,float(sample),{})
		if sky.sun_height>best_height:best_height=sky.sun_height;best_time=float(sample)
	core.world.crew.navigation.orbit_time=best_time
	# Keep the real animal present without forcing a melee encounter during reading.
	var at:=home+Vector3(0,0,13);at.y=field.height(at.x,at.z)+.2
	core.world.crew.members[actor_id].position=FrontierExplorationIncidents.array(at)
	var store:=FrontierWorldStore.new(folder+"/world.json");check(store.write(core.world),"isolated world saved")
	var profile:=FrontierPlayerProfile.new(folder+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"Forward+ field ready",100):quit(1);return
	core=app.session.authority;app.close_menus();app.onboarding.letter.hide();FrontierClientSettings.ensure(self).values.tutorial_mode=2;app.outside=false;app.exterior_view.hide();app.if_flight_view()
	place(at)
	if not await until(func():return app.surface_world.ecology.actors.has(chosen.id) and app.surface_world.ready_at(at),"natural target loaded",60):quit(1);return
	animal=app.surface_world.ecology.actors[chosen.id]
	if "--impacts-only" in OS.get_cmdline_user_args():
		await review_impacts()
		await app.session.close_session();app.queue_free();await process_frame
		print("TARGET_IMPACT_REVIEW ",checks," FAILURES ",failures);quit(1 if failures else 0);return
	var hud:=app.field_hud;var card:=hud.scan_card
	await track(.5)
	check(app.surface_target.get("id")==chosen.id,"camera aims at actual animal")
	check(not hud.context.visible and hud.target_health.visible and not card.visible,"unscanned animal only exposes combat target health")
	await capture("01-passive-target")
	app.session.send_request("equipment_select",{"slot":0});await track(.2)
	check(not hud.context.visible and hud.target_health.visible,"animal health stays caption-free with a gathering tool")
	app.session.send_request("equipment_select",{"slot":2});await track(.2)
	app.test_scan=true
	var deadline:=Time.get_ticks_msec()+15000
	while not card.visible and Time.get_ticks_msec()<deadline:aim();await process_frame
	check(card.visible and card.displayed.get("form_id")==chosen.form_id and core.world.ecology.observations.has(body.id+":"+chosen.form_id),"real E scan identifies and records animal")
	await capture("02-scan-result")
	await track(4.3)
	check(not card.visible and app.test_scan,"holding E does not extend completed result")
	app.test_scan=false;await track(.4)
	check(not card.visible and not hud.context.visible and hud.target_health.visible,"known species stays anonymous in passive combat HUD")
	await capture("03-result-expired")
	app.test_scan=true;await track(.4)
	check(card.visible,"explicit repeat E inspection reopens result")
	app.toggle_inventory();await create_timer(.2).timeout
	check(not card.visible,"menu dismisses result")
	app.test_scan=false;app.close_menus();await track(.4)
	check(not card.visible,"closing menu cannot replay an old scan")
	root.size=Vector2i(960,640);root.content_scale_size=root.size
	app.test_scan=true;await track(.4);app.test_scan=false
	await capture("04-scan-960")
	check(card.get_global_rect().end.x<=960 and card.get_global_rect().end.y<=640,"scan result fits small screen")
	await review_impacts()
	await app.session.close_session();app.queue_free();await process_frame
	print("TARGET_IDENTITY_UI ",checks," FAILURES ",failures);quit(1 if failures else 0)

func review_impacts() -> void:
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	app.test_scan=false
	if app.field_hud.scan_card.visible:await track(4.1)
	var at:=animal.global_position+Vector3(0,0,8)
	at.y=field.height(at.x,at.z)+.2;place(at);await track(.4)
	if not await until(func():return core.inputs.get(1,{}).get("controls_enabled",false),"host controls enabled",8):return
	var event: Dictionary={}
	for attempt in 3:
		aim();await RenderingServer.frame_post_draw;app.firearm.shoot()
		event=core.world.crew.members[actor_id].get("weapon_event",{})
		if event.get("hits",{}).get("organic",false):break
		await track(.3)
	check(event.get("contacts",[]).any(func(hit):return hit.kind=="organic"),"host-confirmed organic impact")
	check(app.feedback.audio.last_played.has("sfx_gun_hit_organic"),"existing organic sound still plays")
	var fx:=app.firearm.gun_effects
	fx.set_process(false)
	await capture("05-organic-contact")
	fx._process(.04);fx._process(.04)
	await capture("06-organic-decay")
	fx._process(.3);check(fx.active.is_empty(),"organic effect expires cleanly")
	fx.set_process(true)
	await until(func():return app.firearm.next_shot<=0 and app.firearm.enabled(),"shot interval finished",3)
	app.pitch=-1.3
	await create_timer(.3).timeout
	app.session.response_received.connect(func(_sequence,result):
		if not result.get("ok",false):print("SHOT_REJECTION ",result))
	if await until(func():return app.camera.rotation.x< -1.2,"ground camera settled",3):
		print("GROUND_BEFORE ",app.firearm.enabled()," ",app.firearm.next_shot," ",core.world.crew.members[actor_id].loadout.get("weapon_states",{}))
		app.firearm.shoot();event=core.world.crew.members[actor_id].get("weapon_event",{})
		print("GROUND_EVENT ",event)
		check(event.get("contacts",[]).any(func(hit):return hit.kind=="surface"),"host-confirmed terrain impact")
		await capture("07-ground-contact")
	await track(.4)
	# Material close-ups use explicit presentation contacts, not simulated damage.
	fx.clear();fx.set_process(false)
	for kind in ["armor","shield","break"]:
		var point:=app.camera.global_position-app.camera.global_basis.z*2.0
		fx.impact({"kind":kind,"point":FrontierExplorationIncidents.array(point),"normal":FrontierExplorationIncidents.array(app.camera.global_basis.z)})
		fx._process(0)
		await capture("08-"+kind+"-material-start")
		fx._process(.07)
		await capture("09-"+kind+"-material-decay")
		fx.clear()
	fx.set_process(true)
	var before:=int(fx.emitted.muzzle)
	core.shot_obstacle_provider=func(_id,_origin,_direction,_reach):return .1
	app.firearm.shoot()
	check(int(fx.emitted.muzzle)==before,"rejected shot emits no flash")
	core.shot_obstacle_provider=app._shot_obstacle_distance
	app.toggle_inventory();await create_timer(.2).timeout
	check(not app.field_hud.visible and fx.active.is_empty(),"menu hides health and clears effects")
