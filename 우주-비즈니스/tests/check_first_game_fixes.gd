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
	var distant:=app.surface_world.distant
	var before:=distant.mesh
	var builds:=distant.build_count
	app.yaw+=PI
	await create_timer(.5).timeout
	check(distant.mesh==before and distant.build_count==builds,"camera turn retains distant mesh")
	await capture("terrain-4096")
	# The next CPU job must keep the existing landscape until it is complete.
	distant.request_rebuild(field,field.key_at(app.actors[actor].position)+Vector3i(1,0,0),2,app.surface_world.terrain.material,4096)
	check(distant.mesh==before,"movement rebuild keeps previous mesh")
	check(await until(func():return distant.task_id==-1,45),"background rebuild finishes")
	var arrays:=distant.mesh.surface_get_arrays(0)
	var sample_count:=0
	for vertex in arrays[Mesh.ARRAY_VERTEX]:
		if vertex.x>1000 and vertex.x<1100 and vertex.z>1000 and vertex.z<1100:
			sample_count+=1
			if absf(vertex.y-field.height(vertex.x,vertex.z))>.001:check(false,"world height mismatch");break
	check(sample_count>25,"far hills have dense world-aligned height samples")
	app.session.send_request("business_register",{})
	check(not FrontierExpeditionBusiness.site(app.session.authority.world).is_empty(),"free registration")
	world=app.session.authority.world
	world.business.bags[actor]=FrontierExpeditionBusiness.inventory()
	world.business.bags[actor].iron=201;world.crew.members[actor].carried=7
	app.session._publish();app.toggle_inventory();await create_timer(.5).timeout
	var panel:=app.inventory_panel
	check(panel.owned.get_child_count()==FrontierItemInventory.capacity(app.session.latest.crew.members[actor]),"single personal capacity grid")
	var counts: Array=[]
	for tile in panel.owned.get_children():
		if not tile.amount.is_empty():counts.append(tile.amount)
	check(counts==["100","100","1","7"],"resources and legacy stone share equipment grid without zeros")
	await capture("items-1280")
	root.size=Vector2i(960,640);root.content_scale_size=Vector2i(960,640)
	await create_timer(.5).timeout
	check(panel.detail.get_global_rect().end.x<=936,"960px inventory fits")
	await capture("items-960")
	panel.hide()
	app.session.send_request("equipment_select",{"slot":0})
	world=app.session.authority.world
	check(int(world.crew.members[actor].carried)==0 and int(world.business.bags[actor].stone)==7,"legacy stone migrated transactionally")
	var ore:=FrontierExpeditionBusiness.find_vein(body,"landing:iron")
	var ground:=FrontierMineralWorld.point(field,ore)
	app.actors[actor].position=ground+Vector3(0,.1,2);app.session.authority.update_position(1,app.actors[actor].position)
	app.session.send_request("business_mine",{"vein_id":ore.id})
	check(int(FrontierExpeditionBusiness.bag(app.session.authority.world,actor).iron)==204,"starter iron is mineable above old 96 total limit")
	check(await app.session.close_session(),"save succeeds")
	var saved:=app.world_store.read_state()
	var saved_iron:=int(saved.business.bags[actor].iron)
	for crate in saved.business.crates.values():saved_iron+=int(crate.inventory.get("iron",0))
	check(not saved.is_empty() and saved_iron==204 and int(saved.business.sites[body.id].remaining["landing:iron"])==397,"stack inventory and depletion survive reload/recovery crate")
	app.queue_free();await process_frame
	print("FIRST_GAME_FAILURES ",failures);quit(1 if failures else 0)
