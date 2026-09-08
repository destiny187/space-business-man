extends "res://tests/check_facility_interactions.gd"
## Focused environment math and actual HUD rendering.
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
	if folder.is_empty() or not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
	if "--save-review" in OS.get_cmdline_user_args():
		var disk:=FrontierWorldStore.new(folder+"/world.json")
		var saved_world:=disk.read_state()
		check(not saved_world.is_empty(),"environment save reload valid")
		if not saved_world.is_empty():
			var saved_report:=FrontierEvaluator.environment_report(FrontierExpeditionBusiness.site(saved_world))
			check(saved_report.observed and is_equal_approx(saved_report.overall,75),"same environment derives same score after reload")
		print("ENVIRONMENT_SAVE_FAILURES ",failures);quit(1 if failures else 0);return
	root.size=Vector2i(1280,800)
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
	await process_frame
	app.world_store.write(FrontierUniverse.new_world(71491));app.start_solo()
	if not await until(func():return app.session.active,15):quit(1);return
	app.onboarding.letter.hide()
	var world: Dictionary=app.session.authority.world
	var ordinal:=FrontierUniverse.first_ordinal(world.manifest,23)
	while not FrontierUniverse.landable(FrontierUniverse.body(world.manifest,ordinal)):ordinal+=1
	var body:=FrontierUniverse.body(world.manifest,ordinal)
	var nav: Dictionary=world.crew.navigation
	nav.system=23;nav.target=ordinal;nav.mode="idle";nav.speed=0.0;nav.orbit_time=0.0
	var point:=FrontierCrewNavigation.center(ordinal,world.manifest,0)+Vector3(0,0,FrontierUniverse.radius(body)+30)
	nav.position=[point.x,point.y,point.z];nav.direction=[0,0,-1];world.location=body.id
	app.session._publish();await process_frame;app.travel_action("land")
	if not await until(func():return app.surface_world!=null and not app.arrival.active,90):check(false,"landing");quit(1);return
	app.close_menus();app.session.send_request("business_register",{})
	var perfect: Dictionary={"oxygen":.21,"pressure":1.0,"toxicity":0.0,"temperature":18.0,"water":100.0,"ecology":100.0,"stable_seconds":0.0}
	var fixture: Dictionary={"environment":perfect.duplicate(true)}
	var report:=FrontierEvaluator.environment_report(fixture,"review")
	check(report.observed and is_equal_approx(report.overall,100) and not report.stable,"four-axis suitability excludes stability")
	fixture.environment.stable_seconds=30.0
	var stable:=FrontierEvaluator.environment_report(fixture,"review")
	check(stable.stable and is_equal_approx(stable.overall,report.overall),"existing 30 second observation kept separate")
	fixture.environment.toxicity=100.0
	report=FrontierEvaluator.environment_report(fixture,"review")
	check(is_equal_approx(report.overall,75) and report.limiting_factors[0].key=="atmosphere","high average preserves mandatory atmosphere warning")
	fixture.environment=perfect.duplicate(true);fixture.restoration2={"salinity":70.0,"soil":10.0}
	report=FrontierEvaluator.environment_report(fixture,"review")
	check(is_equal_approx(report.scores.water,30) and is_equal_approx(report.scores.ecology,10) and is_equal_approx(report.overall,60),"tier2 salinity and soil limit their associated axes")
	fixture.restoration2.erase("soil")
	report=FrontierEvaluator.environment_report(fixture,"review")
	check(not report.observed and report.overall==null,"missing required observation has no invented score")
	var site:=FrontierExpeditionBusiness.site(app.session.authority.world)
	site.environment=perfect.duplicate(true);site.environment.toxicity=100.0
	site.erase("restoration2")
	app.session._publish();app.session._publish_surface()
	await create_timer(.5).timeout
	var hud: FrontierEnvironmentHud=app.field_hud.environment
	check(hud.is_visible_in_tree() and hud.report.observed and is_equal_approx(hud.bar.value,75),"HUD consumes actual published site")
	check(hud.warning.visible and "대기" in hud.warning.text,"weakest condition visible beside main bar")
	await capture("environment-compact")
	var key:=InputEventKey.new();key.physical_keycode=KEY_H;key.pressed=true;Input.parse_input_event(key)
	await process_frame;key=InputEventKey.new();key.physical_keycode=KEY_H;key.pressed=false;Input.parse_input_event(key)
	await create_timer(.3).timeout
	check(hud.details.visible,"H expands four environmental icons")
	root.size=Vector2i(960,640);root.content_scale_size=Vector2i(960,640)
	await create_timer(.3).timeout
	check(hud.get_global_rect().end.x<400 and hud.get_global_rect().end.y<400,"960px HUD stays below planet title without covering central aim")
	await capture("environment-details-960")
	app.open_station("ship");await process_frame
	for i in app.business_panel.tabs.get_tab_count():
		if str(app.business_panel.tabs.get_tab_control(i).name)=="환경·계약":app.business_panel.tabs.current_tab=i
	await create_timer(.3).timeout
	check("75%" in app.business_panel.environment_label.text and app.business_panel.environment_bars.atmosphere.value==0,"terminal shares HUD environmental result")
	await capture("environment-terminal")
	app.close_menus();site=FrontierExpeditionBusiness.site(app.session.authority.world)
	if site.has("restoration2"):site.erase("restoration2")
	check(await app.session.close_session(),"environment snapshot saved")
	var restored: Dictionary=app.world_store.read_state()
	check(not restored.is_empty(),"environment save reload valid")
	if not restored.is_empty():
		var after:=FrontierEvaluator.environment_report(FrontierExpeditionBusiness.site(restored),body.id)
		check(after.observed and is_equal_approx(after.overall,75),"same environment derives same score after reload")
	print("ENVIRONMENT_HUD_FAILURES ",failures);quit(1 if failures else 0)
