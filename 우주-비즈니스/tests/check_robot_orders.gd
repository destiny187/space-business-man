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
	if FrontierEquipment.state(app.session.latest.crew.members[id]).items.is_empty():app.session.send_request("equipment_craft",{"definition":"miner_1"})
	app.session.send_request("equipment_equip",{"item_id":"crafted:1","slot":0})
	await create_timer(.3).timeout
	var vein: Dictionary={}
	for row in FrontierExpeditionBusiness.veins(app.surface_world.body,app.camera.position):
		if row.resource!="iron":continue
		point=FrontierMineralWorld.point(app.surface_world.terrain.field,row)
		if not point.is_finite():continue
		var ground:=FrontierExpeditionBusiness.ground(app.surface_world.terrain.field,point.x,point.z+3)
		if not ground.is_finite():continue
		vein=row;move_to(ground+Vector3.UP*.2);break
	if vein.is_empty():check(false,"reachable iron fixture");quit(1);return
	await create_timer(.5).timeout
	app.camera.look_at(point+Vector3.UP*.65);app.yaw=app.camera.rotation.y;app.pitch=app.camera.rotation.x
	await create_timer(.2).timeout
	var site:=FrontierExpeditionBusiness.site(app.session.authority.world)
	var robot_point:=point+Vector3(0,0,2.2);robot_point.y=app.surface_world.terrain.field.height(robot_point.x,robot_point.z)
	for index in 3:
		var rid: String="robot:"+str(900+index)
		site.robots[rid]={"id":rid,"tier":1 if index==0 else 2,"grade":"rare" if index!=1 else "standard","position":FrontierExpeditionBusiness.array(robot_point),"battery":100.0,"cargo":FrontierExpeditionBusiness.inventory(),"phase":"idle","target":"","path":[],"status":"대기","work":0.0,"charging":false,"auto_enabled":false}
	app.session.authority.world.business.counter=903
	var responses: Array=[]
	app.session.response_received.connect(func(_seq: int,value: Dictionary):responses.append(value))
	app.session.send_request("business_assign",{"vein_id":vein.id})
	check(responses.back().ok,"onsite automatic one-robot command accepted")
	site=FrontierExpeditionBusiness.site(app.session.authority.world)
	check(site.robots["robot:902"].get("manual_target")==vein.id,"capability then quality selects Mk2 rare")
	app.session.send_request("business_assign",{"vein_id":vein.id})
	site=FrontierExpeditionBusiness.site(app.session.authority.world)
	check(site.robots.values().filter(func(r: Dictionary):return r.get("manual_target","")==vein.id).size()==1,"repeated command reserves only one robot")
	app.session.send_request("business_robot_auto",{"robot_id":"robot:902","enabled":false})
	app.session.send_request("business_assign",{"vein_id":vein.id,"robot_id":"robot:900"})
	site=FrontierExpeditionBusiness.site(app.session.authority.world)
	check(responses.back().ok and site.robots["robot:900"].get("manual_target")==vein.id,"explicit lower grade robot takes precedence")
	app.session.send_request("business_robot_auto",{"robot_id":"robot:900","enabled":false})
	app.session.send_request("business_assign",{"vein_id":vein.id,"robot_id":"missing"})
	check(not responses.back().ok,"invalid explicit robot does not silently substitute")
	site=FrontierExpeditionBusiness.site(app.session.authority.world)
	check(site.robots.values().all(func(r: Dictionary):return r.get("manual_target","").is_empty()),"invalid explicit selection leaves every robot unassigned")
	site=FrontierExpeditionBusiness.site(app.session.authority.world)
	for index in 3:
		var p:=point+Vector3(-4-index*3,0,0);p.y=app.surface_world.terrain.field.height(p.x,p.z)
		site.robots["robot:"+str(900+index)].position=FrontierExpeditionBusiness.array(p)
	app.session._publish_surface()
	app.preferred_robot_id="robot:900"
	await create_timer(.4).timeout
	app.camera.look_at(point+Vector3.UP*.65);app.yaw=app.camera.rotation.y;app.pitch=app.camera.rotation.x
	await physics_frame
	var key:=InputEventKey.new();key.physical_keycode=KEY_R;key.pressed=true
	app._unhandled_input(key)
	check(responses.back().ok and FrontierExpeditionBusiness.site(app.session.authority.world).robots["robot:900"].get("manual_target","")==vein.id,"R key dispatches selected robot from aimed ore")
	await create_timer(.3).timeout
	await capture("ore-command-hud")
	check(await app.session.close_session(),"one-robot settings saved")
	print("ROBOT_ORDER_FAILURES ",failures);quit(1 if failures else 0)
