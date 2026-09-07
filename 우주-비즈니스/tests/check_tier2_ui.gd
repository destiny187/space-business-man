extends "res://tests/test_solo_entry.gd"
func run() -> void:
	assert("--crew-ui-test" in OS.get_cmdline_user_args())
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--crew-folder="):folder=argument.trim_prefix("--crew-folder=")
	root.size=Vector2i(1280,800)
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame
	app.start_solo()
	if not await until(func():return app.surface_world!=null and not app.arrival.active and not app.outside,"saved surface resumes after arrival",60):quit(1);return
	var actor: String=app.session.latest.self_id
	var site:=FrontierExpeditionBusiness.site(app.session.authority.world)
	app.actors[actor].position=FrontierCrewWorld.vector(site.buildings["fixture:factory"].position)+Vector3(0,0,4)
	app.session.authority.update_position(1,app.actors[actor].position)
	await create_timer(1).timeout
	app.toggle_business();app.business_panel.production_panel.selected_product="control_circuit";app.business_panel.production_panel.refresh()
	check(app.business_panel.visible,"production panel opens")
	await capture("circuit-ui")
	root.size=Vector2i(960,640);root.content_scale_size=Vector2i(960,640);await capture("production-960")
	app.business_panel.hide();app.toggle_inventory();await create_timer(.4).timeout
	check(app.inventory_panel.title.text.contains("Mk.2"),"owned selection follows upgraded definition")
	await capture("equipment-960")
	app.inventory_panel.tabs.current_tab=2;app.inventory_panel.storage.select(1);app.inventory_panel.last_key="";app.inventory_panel.selected_resource="control_circuit";await capture("withdraw-960")
	app.inventory_panel.hide()
	app.session.send_request("business_produce",{"building_id":"fixture:factory","product":"refined_iron"})
	await create_timer(1.5).timeout
	check(app.feedback.audio.emitters.has("fixture:factory"),"production starts spatial ElevenLabs work loop")
	app.toggle_business();await create_timer(.4).timeout
	check(app.feedback.blocked(),"production menu blocks field actions and work audio")
	app.business_panel.hide()
	var water: Vector3=FrontierCrewWorld.vector(site.buildings["fixture:water"].position)
	var eye:=water+Vector3(6,3,8)
	app.test_camera_position=eye;app.pitch=-.18;app.yaw=atan2(eye.x-water.x,eye.z-water.z)
	await capture("retrofitted-site")
	check(app.surface_world.business_view.nodes.has("fixture:water") and app.surface_world.business_view.nodes["fixture:water"].has_meta("tier2_visual"),"Mk.2 attachment is present in actual field")
	await app.session.close_session()
	print("TIER2_UI_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
