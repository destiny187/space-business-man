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
	site.remaining[vein.id]=int(vein.capacity)
	var robot_point:=point+Vector3(0,0,2.35);robot_point.y=app.surface_world.terrain.field.height(robot_point.x,robot_point.z)
	site.robots["robot:900"]={"id":"robot:900","grade":"standard","position":FrontierExpeditionBusiness.array(robot_point),"battery":100.0,"cargo":FrontierExpeditionBusiness.inventory(),"phase":"idle","target":"","path":[],"status":"광맥으로 이동","work":0.0,"charging":false,"resource_filter":"iron"}
	app.session.authority.world.business.counter=901
	var viewer:=point+Vector3(5,0,5);viewer.y=app.surface_world.terrain.field.height(viewer.x,viewer.z)+.2
	move_to(viewer);app.test_camera_position=point+Vector3(5,3,5);await create_timer(.4).timeout
	app.camera.look_at(point+Vector3.UP);app.yaw=app.camera.rotation.y;app.pitch=app.camera.rotation.x
	check(await until(func():return app.surface_world.business_view.nodes.has("robot:900"),20),"robot model instantiated")
	check(await until(func():return FrontierExpeditionBusiness.site(app.session.authority.world).robots["robot:900"].status=="채광 중",20),"automatic robot reaches mining state")
	await create_timer(.4).timeout
	var node: Node3D=app.surface_world.business_view.nodes["robot:900"]
	var visual: Node3D=node.get_meta("visual")
	var rotor: Node3D=visual.find_child("ToolRotor",true,false)
	var before:=rotor.basis
	await create_timer(.3).timeout
	check(rotor.basis!=before,"actual Blender drill spins")
	var toward: Vector3=(point-node.position).normalized()
	check(visual.basis.z.dot(toward)>.95,"positive Z drill faces authoritative vein")
	check(node.get_meta("intake").global_position.distance_to(point+Vector3.UP*1.35)<1,"collection endpoint lies at drill tip near ore")
	check(FrontierExpeditionBusiness.total(FrontierExpeditionBusiness.site(app.session.authority.world).robots["robot:900"].cargo)>0,"robot extracts authoritative resources")
	check(app.feedback.audio.emitters.has("robot:900"),"existing ElevenLabs positional work emitter active")
	await capture("robot-drilling")
	var r: Dictionary=FrontierExpeditionBusiness.site(app.session.authority.world).robots["robot:900"]
	check(r.get("auto_enabled",false) and r.target==vein.id,"legacy robot defaults to automatic nearby iron")
	var tier2:=vein.duplicate(true);tier2.required_tier=2
	check(not FrontierRobotWork.reason(app.session.authority.world,r,tier2).is_empty(),"Mk1 rejects higher capability ore")
	var upgraded:=r.duplicate(true);upgraded.tier=2
	check(FrontierRobotWork.reason(app.session.authority.world,upgraded,tier2).is_empty(),"existing Mk2 capability accepts tier2 ore")
	upgraded.grade="rare";upgraded.tier=1
	check(FrontierRobotWork.tier(upgraded)==1,"quality never bypasses capability tier")
	app.open_station("robot","robot:900");await create_timer(.3).timeout;await capture("auto-controls")
	app.close_menus()
	r=FrontierExpeditionBusiness.site(app.session.authority.world).robots["robot:900"]
	var isolated: Dictionary=app.session.authority.world.duplicate(true)
	var test_robot: Dictionary=FrontierExpeditionBusiness.site(isolated).robots["robot:900"]
	test_robot.anchor=[100000,0,100000];test_robot.resource_filter="iron"
	check(not FrontierRobotWork.search(isolated,test_robot),"automatic search never follows distant starting deposits")
	check(FrontierExpeditionBusiness.validate(app.session.authority.world.business,app.session.authority.world.manifest).is_empty(),"new work settings remain save valid")
	check(await app.session.close_session(),"robot operation saved")
	print("ROBOT_AUTO_FAILURES ",failures);quit(1 if failures else 0)
