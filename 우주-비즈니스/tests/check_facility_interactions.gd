extends SceneTree
var app: FrontierCrewExpedition
var folder: String=""
var failures:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func until(test: Callable,seconds: float=60) -> bool:
	var end:=Time.get_ticks_msec()+int(seconds*1000)
	while not test.call() and Time.get_ticks_msec()<end:await process_frame
	return test.call()
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+name+".png")
func move_to(point: Vector3) -> void:
	app.actors[app.session.latest.self_id].position=point
	app.session.authority.update_position(1,point)
	app.session._publish()
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
	if folder.is_empty() or not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
	root.size=Vector2i(1280,800)
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
	await process_frame
	if not "--facility-resume" in OS.get_cmdline_user_args():app.world_store.write(FrontierUniverse.new_world(71491))
	app.start_solo()
	if not await until(func():return app.session.active,15):check(false,"session");quit(1);return
	app.onboarding.letter.hide()
	if "--facility-resume" in OS.get_cmdline_user_args():
		if not await until(func():return app.surface_world!=null and not app.arrival.active,90):quit(1);return
		await verify_remaining();return
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
	app.open_station("ship");await process_frame
	check(app.business_panel.register_button.is_visible_in_tree(),"registration belongs to ship")
	app.business_panel.register_button.pressed.emit();await process_frame
	check(not FrontierExpeditionBusiness.site(app.session.authority.world).is_empty(),"register from ship")
	app.close_menus();app.toggle_business();await process_frame
	check(str(app.business_panel.tabs.get_current_tab_control().name)=="건설" and not app.business_panel.robot_factory.is_visible_in_tree(),"B exposes construction only")
	await capture("construction")
	app.close_menus()
	# Supply a bounded fixture; placement and manufacturing still use host commands.
	world=app.session.authority.world
	world.business.technologies.append("robotics")
	var site:=FrontierExpeditionBusiness.site(world)
	for resource in site.inventory:site.inventory[resource]=500
	var built: Array[String]=[]
	for kind in ["solar","charger","factory","factory"]:
		var found:=false
		for x in range(-45,46,9):
			if found:break
			for z in range(-45,46,9):
				point=FrontierExpeditionBusiness.ground(app.surface_world.terrain.field,x,z,float(FrontierCatalog.entry("buildings",kind).radius))
				if not point.is_finite():continue
				move_to(point+Vector3(0,.2,5))
				var before: Array=FrontierExpeditionBusiness.site(app.session.authority.world).buildings.keys()
				app.session.send_request("business_build",{"building":kind,"position":FrontierExpeditionBusiness.array(point)})
				site=FrontierExpeditionBusiness.site(app.session.authority.world)
				if site.buildings.size()<=before.size():continue
				for id in site.buildings:
					if not before.has(id) and kind=="factory":built.append(id)
				found=true;break
		check(found,"build "+kind)
	if built.size()!=2:quit(1);return
	var factory_id: String=built[0]
	site=FrontierExpeditionBusiness.site(app.session.authority.world)
	point=FrontierExpeditionBusiness.point(site.buildings[factory_id].position)
	move_to(point+Vector3(0,0,5))
	await create_timer(1).timeout
	# Exercise actual ray selection and F dispatch, not just the panel setter.
	app.camera.look_at(point+Vector3.UP)
	await physics_frame
	if not await until(func():return app.surface_world.business_view.nodes.has(factory_id),30):check(false,"factory model loaded");quit(1);return
	app.interact_business();await process_frame
	check(app.business_panel.visible and app.business_panel.context_id==factory_id and app.business_panel.robot_factory.is_visible_in_tree(),"F opens exact factory robot interface")
	if not app.business_panel.visible:quit(1);return
	await capture("robot-factory")
	app.business_panel.robot_factory.craft.pressed.emit();await process_frame
	site=FrontierExpeditionBusiness.site(app.session.authority.world)
	check(site.jobs.size()==1 and site.jobs.values()[0].factory_id==factory_id,"robot job bound to interacted factory")
	app.session.send_request("business_craft",{"building_id":factory_id})
	check(FrontierExpeditionBusiness.site(app.session.authority.world).jobs.size()==1,"duplicate factory reservation rejected")
	await create_timer(1).timeout
	await capture("robot-progress")
	app.close_menus()
	if not await until(func():return not FrontierExpeditionBusiness.site(app.session.authority.world).robots.is_empty(),90):
		print("FACTORY_DIAGNOSTIC ",FrontierExpeditionBusiness.site(app.session.authority.world))
		check(false,"robot finishes");quit(1);return
	await verify_remaining()
func verify_remaining() -> void:
	var site:=FrontierExpeditionBusiness.site(app.session.authority.world)
	var body: Dictionary=app.surface_world.body
	var point:=Vector3.ZERO
	var robot_id: String=site.robots.keys()[0]
	check(await until(func():return app.session.surface.get("business",{}).get("sites",{}).get(body.id,{}).get("robots",{}).has(robot_id),10),"robot published to interaction snapshot")
	point=FrontierExpeditionBusiness.point(site.robots[robot_id].position)
	move_to(point+Vector3(0,0,3));app.open_station("robot",robot_id);await process_frame
	check(app.business_panel.selected(app.business_panel.robot)==robot_id and not app.business_panel.robot_factory.is_visible_in_tree(),"robot controls fixed to robot, no manufacturing")
	await capture("robot-controls")
	root.size=Vector2i(960,640);root.content_scale_size=Vector2i(960,640);await create_timer(.3).timeout
	check(app.business_panel.get_global_rect().end.x<=936,"960px station fits")
	await capture("station-960")
	app.close_menus()
	var factory_id: String=""
	for id in site.buildings:
		if site.buildings[id].type=="factory":factory_id=id;break
	move_to(FrontierExpeditionBusiness.point(site.buildings[factory_id].position)+Vector3(0,0,5))
	app.open_station("factory",factory_id);await process_frame
	check(app.business_panel.robot_factory.is_visible_in_tree(),"factory still exposes robot production")
	await capture("factory-960")
	for i in app.business_panel.tabs.get_tab_count():
		if str(app.business_panel.tabs.get_tab_control(i).name)=="생산·개조":app.business_panel.tabs.current_tab=i
	check(app.business_panel.production_panel.targets.item_count==1 and app.business_panel.selected(app.business_panel.production_panel.targets)==factory_id,"product production fixed to one factory")
	await capture("production-960")
	var produced_before: int=int(FrontierExpeditionBusiness.site(app.session.authority.world).inventory.get("refined_iron",0))
	app.business_panel.production_panel.produce.pressed.emit();await process_frame
	check(app.feedback.audio.last_played.has("sfx_build_place"),"accepted production triggers existing ElevenLabs start audio")
	check(await until(func():return int(FrontierExpeditionBusiness.site(app.session.authority.world).inventory.get("refined_iron",0))>produced_before,30),"product completes in the selected factory")
	check(await until(func():return app.feedback.audio.last_played.has("sfx_factory_complete"),5),"published completion triggers existing ElevenLabs completion audio")
	app.close_menus();move_to(FrontierExpeditionBusiness.point(site.center))
	app.open_station("base","business-base");await process_frame
	check(app.business_panel.warehouse.is_visible_in_tree() and not app.business_panel.robot_factory.is_visible_in_tree(),"warehouse contains cargo, no robot production")
	await capture("warehouse-960")
	app.close_menus();app.toggle_research();await process_frame
	app.research_frame.tabs.current_tab=1
	check(app.research_actions[0].is_visible_in_tree(),"J opens independent research desk with ecology actions")
	app.close_menus();move_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))
	app.open_station("ship");await process_frame;await capture("ship-terminal")
	app.station_action("research");app.research_frame.tabs.current_tab=1;await process_frame
	check(app.research_actions[0].is_visible_in_tree(),"ship laboratory exposes research actions")
	app.close_menus()
	check(await app.session.close_session(),"save station production state")
	app.queue_free();await process_frame
	print("FACILITY_FAILURES ",failures);quit(1 if failures else 0)
