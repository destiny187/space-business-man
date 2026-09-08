extends "res://tests/check_field_tool_feedback.gd"
## One current expedition pass: changed extractor, construction, factory and charger.
var followup_reviewed:=false
func capture(name: String) -> void:
	await super.capture(name)
	if name=="survey-complete" and not followup_reviewed:
		followup_reviewed=true
		await review_construction()

func review_construction() -> void:
	app.test_scan=false;app.close_menus()
	var actor: String=app.session.latest.self_id
	var world: Dictionary=app.session.authority.world
	if "robotics" not in world.business.technologies:world.business.technologies.append("robotics")
	var built: Dictionary={}
	for kind in ["solar","charger","factory"]:
		world=app.session.authority.world
		var def:=FrontierCatalog.entry("buildings",kind)
		world.business.bags[actor]=FrontierExpeditionBusiness.inventory()
		FrontierExpeditionBusiness.transfer(world.business.bags[actor],def.cost,1)
		var point:=Vector3.INF
		for x in range(-40,41,5):
			if point.is_finite():break
			for z in range(-40,41,5):
				var p:=FrontierExpeditionBusiness.ground(app.surface_world.terrain.field,x,z,float(def.radius))
				if not p.is_finite():continue
				var eye:=FrontierExpeditionBusiness.ground(app.surface_world.terrain.field,x,z+6,.5)
				if not eye.is_finite():continue
				move_to(eye+Vector3.UP*.2)
				if FrontierExpeditionBusiness.build_reason(app.session.authority.world,actor,kind,p,{1:actor}).is_empty():point=p;break
		check(point.is_finite(),kind+" supported build location")
		if not point.is_finite():return
		app.session._publish();app.session._publish_surface()
		app.test_camera_position=point+Vector3(0,3.5,6)
		await create_timer(.35).timeout
		app.camera.look_at(point);app.yaw=app.camera.rotation.y;app.pitch=app.camera.rotation.x
		app.begin_placement(kind)
		check(await until(func():return app.placement_ghost!=null and app.placement_ghost.visible and app.placement_valid,10),kind+" valid model ghost: "+app.placement_reason)
		await super.capture(kind+"-ghost")
		app.cancel_placement()
		var previous: Array=FrontierExpeditionBusiness.site(app.session.authority.world).buildings.keys()
		app.session.send_request("business_build",{"building":kind,"position":FrontierExpeditionBusiness.array(point)})
		var site:=FrontierExpeditionBusiness.site(app.session.authority.world)
		for bid in site.buildings:
			if bid not in previous:built[kind]=bid;break
		check(built.has(kind),kind+" accepted backpack-funded placement")
		if not built.has(kind):return
		check(await until(func():return app.surface_world.business_view.nodes.has(built[kind]),20),kind+" actual scene model loaded")
		check(app.feedback.audio.last_played.has("sfx_build_place"),kind+" construction sound")
		await super.capture(kind+"-built")
	var site:=FrontierExpeditionBusiness.site(app.session.authority.world)
	FrontierExpeditionBusiness.transfer(site.inventory,FrontierCatalog.entry("robots","miner").cost,1)
	app.session._publish_surface();await create_timer(.6).timeout
	app.open_station("factory",built.factory);await create_timer(.2).timeout
	check(app.business_panel.robot_factory.is_visible_in_tree(),"new factory opens production controls")
	root.size=Vector2i(960,640);root.content_scale_size=Vector2i(960,640)
	await create_timer(.35).timeout
	check(app.business_panel.get_global_rect().end.x<=960,"factory controls fit 960px")
	await super.capture("factory-960")
	app.business_panel.robot_factory.craft.pressed.emit();await process_frame
	check(not FrontierExpeditionBusiness.site(app.session.authority.world).jobs.is_empty(),"factory accepts real production job")
	app.close_menus()
	check(await until(func():return not FrontierExpeditionBusiness.site(app.session.authority.world).robots.is_empty(),40),"new factory completes robot production")
	site=FrontierExpeditionBusiness.site(app.session.authority.world)
	if site.robots.is_empty():return
	var robot: Dictionary=site.robots.values()[0]
	var charger:=FrontierExpeditionBusiness.point(site.buildings[built.charger].position)
	var robot_point:=FrontierExpeditionBusiness.ground(app.surface_world.terrain.field,charger.x+3,charger.z,.5)
	check(robot_point.is_finite(),"charger approach supported")
	if robot_point.is_finite():
		robot.position=FrontierExpeditionBusiness.array(robot_point);robot.path=[];robot.battery=20.0;robot.charging=true
		var eye:=charger+Vector3(5,0,6);eye.y=app.surface_world.terrain.field.height(eye.x,eye.z)+.2;move_to(eye)
		app.test_camera_position=charger+Vector3(6,4,7);await create_timer(.25).timeout
		app.camera.look_at(charger+Vector3.UP);app.yaw=app.camera.rotation.y;app.pitch=app.camera.rotation.x
		check(await until(func():return float(FrontierExpeditionBusiness.site(app.session.authority.world).robots[robot.id].battery)>20.0,8),"new charger increases actual battery")
		await create_timer(.3).timeout
		check(app.feedback.audio.emitters.has(robot.id),"charging robot retains positional audio")
		await super.capture("charging-960")
	app.toggle_business();await create_timer(.3).timeout
	for kind in ["solar","charger","factory"]:
		check(app.business_panel.building_cards[kind].get_child(0).get_child(0).texture!=null,kind+" refreshed construction card")
	check(not app.feedback.handheld.visible and not app.feedback.audio.suction.playing,"960px menu blocks tool and suction")
	await super.capture("construction-960")
	app.close_menus();root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800)

func run() -> void:
	if not "--followup-preview-review" in OS.get_cmdline_user_args():
		await super.run();return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
	if folder.is_empty() or not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
	root.size=Vector2i(960,640);root.content_scale_size=Vector2i(960,640)
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
	await process_frame;app.start_solo()
	check(await until(func():return app.session.active and app.surface_world!=null and not app.arrival.active,90),"saved expedition restored")
	app.onboarding.letter.hide();app.close_menus();app.toggle_business()
	await create_timer(.5).timeout
	for kind in ["solar","charger","factory"]:
		var texture:Texture2D=app.business_panel.building_cards[kind].get_child(0).get_child(0).texture
		var actual:=texture.get_image()
		var expected:=Image.load_from_file(ProjectSettings.globalize_path("res://assets/ui/previews/"+kind+".png"))
		actual.convert(Image.FORMAT_RGBA8);expected.convert(Image.FORMAT_RGBA8)
		check(actual.get_data()==expected.get_data(),kind+" menu uses final INK preview pixels")
	await super.capture("construction-960-final")
	check(await app.session.close_session(),"restored world saved");await process_frame
	print("FOLLOWUP_PREVIEW_FAILURES ",failures);quit(1 if failures else 0)
