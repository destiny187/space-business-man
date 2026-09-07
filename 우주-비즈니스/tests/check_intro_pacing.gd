extends "res://tests/check_facility_interactions.gd"
## One guided real-time intro flow; no resource grants or simulation acceleration.
var owner: String
var started: int
var building_ids: Dictionary={}
func state() -> Dictionary:return app.session.authority.world
func current() -> Dictionary:return FrontierExpeditionBusiness.site(state())
func walk(goal: Vector3,reach: float=3.5) -> void:
	var actor: CharacterBody3D=app.actors[owner]
	var nav:=FrontierTerrainNavigation.new()
	var blockers:=FrontierExpeditionIndustry.obstacles(state())
	for vein in FrontierExpeditionBusiness.veins(app.surface_world.body,actor.position):
		if not vein.get("underground",false):blockers.append({"position":vein.position,"radius":3.0})
	var destination:=goal+(actor.position-goal).normalized()*maxf(0,reach-1)
	destination.y=app.surface_world.terrain.field.height(destination.x,destination.z)
	var result:=nav.find_path(app.surface_world.terrain.field,actor.position,destination,FrontierSurfaceLogistics.config().navigation,blockers)
	var points: Array=[]
	for point in result.points:points.append(point)
	points.append(destination)
	var limit:=Time.get_ticks_msec()+60000
	for point in points:
		var close: float=.25 if point==points.back() else .8
		var observed:=actor.position;var observation_time:=Time.get_ticks_msec()
		while Vector2(actor.position.x-point.x,actor.position.z-point.z).length()>close and actor.position.distance_to(goal)>reach and Time.get_ticks_msec()<limit:
			var direction:=Vector2(point.x-actor.position.x,point.z-actor.position.z).normalized()
			app.test_direction=direction.rotated(app.yaw)
			await physics_frame
			if Time.get_ticks_msec()-observation_time>800:
				if actor.position.distance_to(observed)<.2:
					app.test_direction=direction.rotated(PI/2+app.yaw)
					await create_timer(.8).timeout
					break
				observed=actor.position;observation_time=Time.get_ticks_msec()
	app.test_direction=Vector2.ZERO
	var okay:=actor.position.distance_to(goal)<=reach+1
	check(okay,"walk reaches work point")
	if not okay:
		print("WALK_BLOCKED ",actor.position," GOAL ",goal," PATH ",points)
		await capture("walk-blocked");await app.session.close_session();quit(1);return
	await create_timer(.2).timeout
func gather(cost: Dictionary) -> void:
	for resource in cost:
		while int(FrontierExpeditionBusiness.bag(state(),owner).get(resource,0))<int(cost[resource]):
			var target: Dictionary={}
			for row in FrontierExpeditionBusiness.starter_veins(app.surface_world.body):
				if row.resource==resource and int(current().remaining.get(row.id,row.capacity))>0:target=row;break
			if target.is_empty():check(false,"sufficient local "+resource);return
			var point:=FrontierMineralWorld.point(app.surface_world.terrain.field,target)
			await walk(point,5)
			app.camera.look_at(point+Vector3.UP*.6);app.yaw=app.camera.rotation.y;app.pitch=app.camera.rotation.x
			var limit:=Time.get_ticks_msec()+120000
			while int(FrontierExpeditionBusiness.bag(state(),owner).get(resource,0))<int(cost[resource]) and int(current().remaining.get(target.id,target.capacity))>0 and Time.get_ticks_msec()<limit:
				if app.session.mining_ready():app.session.send_request("business_mine",{"vein_id":target.id})
				await process_frame
			if Time.get_ticks_msec()>=limit:check(false,"mining completes "+resource);return
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
	if folder.is_empty() or not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
	root.size=Vector2i(1280,800)
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
	await process_frame
	var resume: bool="--finish-review" in OS.get_cmdline_user_args()
	if not resume:print("WRITE_NEW ",app.world_store.write(FrontierUniverse.new_world(71491))," ",app.world_store.last_error)
	app.start_solo()
	if not await until(func():return app.session.active,15):print("START_FAILED ",app.status.value," ",app.world_store.last_error);quit(1);return
	app.onboarding.letter.hide()
	if resume:
		check(await until(func():return app.surface_world!=null and not app.arrival.active,90),"resume pending robot assembly")
		owner=app.session.latest.self_id;started=Time.get_ticks_msec()
		check(await until(func():return not current().robots.is_empty() and current().jobs.is_empty(),90),"natural robot production finished")
		print("PACE_REMAINING_ASSEMBLY_SECONDS ",(Time.get_ticks_msec()-started)/1000.0)
		await finish();return
	var world: Dictionary=app.session.authority.world
	var ordinal:=FrontierCrewNavigation.first_destination(world.manifest)
	var body:=FrontierUniverse.body(world.manifest,ordinal)
	var nav: Dictionary=world.crew.navigation
	nav.system=FrontierUniverse.system_index(world.manifest,ordinal);nav.target=ordinal;nav.mode="idle";nav.speed=0.0;nav.orbit_time=0.0
	var point:=FrontierCrewNavigation.center(ordinal,world.manifest,0)+Vector3(0,0,FrontierUniverse.radius(body)+30)
	nav.position=[point.x,point.y,point.z];nav.direction=[0,0,-1];world.location=body.id
	app.session._publish();await process_frame;app.travel_action("land")
	if not await until(func():return app.surface_world!=null and not app.arrival.active,90):check(false,"landing");quit(1);return
	app.close_menus()
	started=Time.get_ticks_msec();owner=app.session.latest.self_id
	check(FrontierGroundProgression.intro_candidate(body),"bounded introductory climate")
	check(FrontierGroundProgression.starter(body).size()==5,"all five supported starter deposits")
	print("INTRO_BODY ",body.id," ",body.traits.name," PROCESSING_SECONDS ",FrontierGroundProgression.processing_seconds(body))
	await walk(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position),7)
	for technology in ["robotics","atmosphere","thermal","water","biotech"]:app.session.send_request("business_technology",{"technology":technology})
	for kind in ["solar","atmosphere","thermal","water","solar","charger","factory","biolab"]:
		await gather(FrontierCatalog.entry("buildings",kind).cost)
		var build_point:=Vector3.INF
		for x in range(-40,41,6):
			if build_point.is_finite():break
			for z in range(-36,37,6):
				var p:=FrontierExpeditionBusiness.ground(app.surface_world.terrain.field,x,z,float(FrontierCatalog.entry("buildings",kind).radius))
				if p.is_finite() and FrontierExpeditionBusiness.placement(state(),kind,p,{1:owner}).is_empty():build_point=p;break
		check(build_point.is_finite(),"supported build point "+kind)
		if not build_point.is_finite():quit(1);return
		await walk(build_point,7)
		var before: Array=current().buildings.keys()
		app.session.send_request("business_build",{"building":kind,"position":FrontierExpeditionBusiness.array(build_point)})
		check(current().buildings.size()==before.size()+1,"backpack build "+kind)
		for id in current().buildings:
			if id not in before:building_ids[kind]=id
		print("PACE_BUILT ",kind," ",(Time.get_ticks_msec()-started)/1000.0)
		if kind=="water":
			await gather({"ice":70})
			await walk(FrontierCrewWorld.vector(current().center),7)
			app.session.send_request("business_deposit",{"resource":"ice","amount":70})
	await gather(FrontierCatalog.entry("robots","miner").cost)
	await walk(FrontierCrewWorld.vector(current().center),7)
	app.session.send_request("business_deposit",{"all_resources":true})
	await walk(FrontierCrewWorld.vector(current().buildings[building_ids.factory].position),7)
	app.session.send_request("business_craft",{"building_id":building_ids.factory})
	check(not current().jobs.is_empty(),"robot manufacturing from mined inputs")
	var end:=Time.get_ticks_msec()+480000
	while Time.get_ticks_msec()<end:
		var e: Dictionary=current().environment;var score:=FrontierEvaluator.scores(e)
		if e.ecology>=20 and e.stable_seconds>=30 and minf(score.atmosphere,minf(score.temperature,score.water))>=60 and current().jobs.is_empty():break
		await create_timer(1).timeout
	print("PACE_ELAPSED_SECONDS ",(Time.get_ticks_msec()-started)/1000.0," ENV ",current().environment)
	await finish()
func finish() -> void:
	await capture("first-restoration")
	check(not current().robots.is_empty(),"natural robot production finished")
	check(current().environment.ecology>=20,"real-time first restoration ready")
	await walk(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position),7)
	app.session.send_request("business_settle",{})
	check(current().state=="settled","actual first contract settles through host")
	check(await app.session.close_session(),"first flow saved")
	print("INTRO_PACING_FAILURES ",failures);quit(1 if failures else 0)
