extends "res://tests/check_facility_interactions.gd"
## Bounded rendered review of accepted mining, survey, weapon and cancellation.
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
	if folder.is_empty() or not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
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
	var id: String=app.session.latest.self_id
	var site:=FrontierExpeditionBusiness.site(app.session.authority.world)
	var cost: Dictionary=FrontierCatalog.entry("buildings","solar").cost
	for key in cost:site.inventory[key]=int(cost[key])*2
	var found:=false
	for x in range(-45,46,6):
		if found:break
		for z in range(-45,46,6):
			point=FrontierExpeditionBusiness.ground(app.surface_world.terrain.field,x,z,2.2)
			if not point.is_finite():continue
			move_to(point+Vector3(0,.2,5))
			if FrontierExpeditionBusiness.placement(app.session.authority.world,"solar",point,{1:id}).is_empty():found=true;break
	check(found,"valid construction fixture")
	if not found:quit(1);return
	var responses: Array=[]
	app.session.response_received.connect(func(_seq: int,value: Dictionary):responses.append(value))
	app.session.send_request("business_build",{"building":"solar","position":FrontierExpeditionBusiness.array(point)})
	check(not responses.back().ok and "가방" in responses.back().error,"warehouse stock cannot build")
	site=FrontierExpeditionBusiness.site(app.session.authority.world)
	check(site.buildings.is_empty() and FrontierExpeditionBusiness.affordable(site.inventory,cost),"failed construction leaves resources untouched")
	await create_timer(.5).timeout
	app.camera.look_at(point);app.yaw=app.camera.rotation.y;app.pitch=app.camera.rotation.x
	app.begin_placement("solar");await create_timer(.3).timeout
	check(not app.placement_valid and "가방" in app.placement_reason,"invalid preview uses backpack check")
	await capture("build-unavailable")
	app.session.authority.world.business.bags[id]=FrontierExpeditionBusiness.inventory()
	FrontierExpeditionBusiness.transfer(app.session.authority.world.business.bags[id],cost,1)
	FrontierExpeditionBusiness.site(app.session.authority.world).inventory=FrontierExpeditionBusiness.inventory()
	app.session._publish();app.session._publish_surface();await create_timer(.3).timeout
	check(app.placement_valid,"backpack funded preview becomes valid")
	await capture("build-available")
	app.cancel_placement()
	app.session.send_request("business_build",{"building":"solar","position":FrontierExpeditionBusiness.array(point)})
	print("BUILD_RESPONSE ",responses.back()," PREVIEW ",app.placement_reason)
	check(responses.back().ok,"backpack alone funds construction")
	site=FrontierExpeditionBusiness.site(app.session.authority.world)
	check(site.buildings.size()==1 and FrontierExpeditionBusiness.total(FrontierExpeditionBusiness.bag(app.session.authority.world,id))==0,"exact cost deducted once from backpack")
	check(FrontierExpeditionBusiness.total(site.inventory)==0,"warehouse remains empty")
	await create_timer(.4).timeout;await capture("built")
	check(await app.session.close_session(),"construction saved")
	print("GROUND_CONSTRUCTION_FAILURES ",failures);quit(1 if failures else 0)
