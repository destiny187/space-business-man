extends SceneTree
var failures:=0
var app: FrontierCrewExpedition
var folder:=""
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	if not ok:failures+=1;printerr("FAIL ",label)
	else:print("PASS ",label)
func until(test: Callable,seconds: float=60) -> bool:
	var end:=Time.get_ticks_msec()+int(seconds*1000)
	while not test.call() and Time.get_ticks_msec()<end:await process_frame
	return test.call()
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+name+".png")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
	if folder.is_empty() or not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
	check(FrontierItemInventory.stacks({"iron":201,"copper":0})==[{"resource":"iron","amount":100},{"resource":"iron","amount":100},{"resource":"iron","amount":1}],"100 stack split and no zero slots")
	root.size=Vector2i(1280,800)
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
	await process_frame
	app.world_store.write(FrontierUniverse.new_world(71491));app.start_solo()
	if not await until(func():return app.session.active,15):check(false,"session starts");quit(1);return
	app.onboarding.letter.hide()
	var preferences:=FrontierClientSettings.ensure(self)
	preferences.values.view_distance=4096
	var world: Dictionary=app.session.authority.world
	var ordinal:=FrontierUniverse.first_ordinal(world.manifest,23)
	while not FrontierUniverse.landable(FrontierUniverse.body(world.manifest,ordinal)):ordinal+=1
	var body:=FrontierUniverse.body(world.manifest,ordinal)
	var nav: Dictionary=world.crew.navigation
	nav.system=23;nav.target=ordinal;nav.mode="idle";nav.speed=0.0;nav.orbit_time=0.0
	var point:=FrontierCrewNavigation.center(ordinal,world.manifest,0)+Vector3(0,0,FrontierUniverse.radius(body)+30)
	nav.position=[point.x,point.y,point.z];nav.direction=[0,0,-1];world.location=body.id
	app.session._publish();await process_frame;app.travel_action("land")
	if not await until(func():return app.surface_world!=null and not app.arrival.active and app.surface_world.distant.mesh!=null,90):check(false,"landing and 4096 terrain complete");quit(1);return
	var actor: String=app.session.latest.self_id
	var field:=app.surface_world.terrain.field
	for row in FrontierExpeditionBusiness.starter_veins():
		check(FrontierMineralWorld.point(field,row).is_finite(),"starter ground "+row.resource)
	check(await until(func():return app.surface_world.business_view.nodes.has("landing:iron") and app.surface_world.business_view.nodes.has("landing:copper") and app.surface_world.business_view.nodes.has("landing:stone"),30),"all starter ores visible before registration")
	app.toggle_research();await create_timer(.8).timeout
	await capture("research-1280")
	root.size=Vector2i(960,640);root.content_scale_size=Vector2i(960,640)
	await create_timer(.5).timeout
	check(app.research_frame.get_global_rect().end.x<=936,"research fits 960px")
	await capture("research-960")
	app.research_frame.action.pressed.emit();await create_timer(.3).timeout
	check("robotics" in app.session.authority.world.business.technologies,"research card purchases actual technology")
	check(app.session.authority.world.business.active.is_empty(),"research does not require a development contract")
	app.research_frame.tabs.current_tab=1
	await create_timer(.5).timeout;await capture("ecology-960")
	app.research_frame.hide()
	world=app.session.authority.world
	var ore:=FrontierExpeditionBusiness.find_vein(body,"landing:iron")
	var ground:=FrontierMineralWorld.point(field,ore)
	app.actors[actor].position=ground+Vector3(0,.1,2);app.session.authority.update_position(1,app.actors[actor].position)
	app.session.send_request("business_mine",{"vein_id":ore.id})
	check(int(FrontierExpeditionBusiness.bag(app.session.authority.world,actor).iron)==3,"starter iron is mineable without registration or research")
	check(await app.session.close_session(),"save succeeds")
	var saved:=app.world_store.read_state()
	var saved_iron:=int(saved.business.bags[actor].iron)
	for crate in saved.business.crates.values():saved_iron+=int(crate.inventory.get("iron",0))
	check(not saved.is_empty() and saved_iron==3 and int(saved.business.sites[body.id].remaining["landing:iron"])==397,"stack inventory and depletion survive reload/recovery crate")
	app.queue_free();await process_frame
	print("RESEARCH_ARRIVAL_FAILURES ",failures);quit(1 if failures else 0)
