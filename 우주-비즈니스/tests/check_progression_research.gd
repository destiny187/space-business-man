extends "res://tests/check_facility_interactions.gd"
## Bounded rendered review of personal and shared research.
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
	if folder.is_empty() or not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
	root.size=Vector2i(1280,800)
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
	await process_frame
	if not "--movement-review" in OS.get_cmdline_user_args():app.world_store.write(FrontierUniverse.new_world(71491))
	app.start_solo()
	if not await until(func():return app.session.active,15):quit(1);return
	app.onboarding.letter.hide()
	if "--movement-review" in OS.get_cmdline_user_args():
		if not await until(func():return app.surface_world!=null and not app.arrival.active,90):quit(1);return
		app.close_menus();await movement_review();return
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
	var owner: String=app.session.latest.self_id
	var w: Dictionary=app.session.authority.world
	w.business.technologies=["robotics"]
	w.business.bags[owner]=FrontierExpeditionBusiness.inventory()
	FrontierExpeditionBusiness.transfer(w.business.bags[owner],{"refined_iron":6,"control_circuit":6,"reinforced_frame":6},1)
	move_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))
	app.session._publish();app.session._publish_surface()
	var baseline:=float(FrontierEquipment.active(w.crew.members[owner]).interval)
	app.session.send_request("business_efficiency",{"field":"mining"})
	w=app.session.authority.world
	check(is_equal_approx(float(FrontierEquipment.active(w.crew.members[owner]).interval),baseline/1.1),"personal mining interval reflects exactly one research multiplier")
	check(int(w.business.bags[owner].refined_iron)==4 and int(w.business.bags[owner].control_circuit)==5,"personal research consumes own bag parts")
	check(is_equal_approx(float(FrontierEquipment.config().items.miner_1.interval),.6),"research never mutates shared equipment definition")
	app.session.send_request("business_efficiency",{"field":"logistics"})
	w=app.session.authority.world
	check(FrontierItemInventory.capacity(w.crew.members[owner])==9,"personal logistics adds one actual inventory slot")
	var credits: int=w.business.credits
	app.session.send_request("business_efficiency",{"field":"industry"})
	w=app.session.authority.world
	check(w.business.efficiency==1 and w.business.credits==credits-600,"shared research is purchased once")
	var isolated: Dictionary=w.duplicate(true)
	var guest: Dictionary=isolated.crew.members[owner].duplicate(true);guest.loadout.erase("research")
	check(is_equal_approx(float(FrontierEquipment.active(guest).interval),baseline) and FrontierItemInventory.capacity(guest)==8,"other character does not inherit personal bonuses")
	isolated.crew.members["guest"]=guest
	check("호스트" in FrontierProgressionResearch.reason(isolated,"guest","industry"),"guest cannot spend shared research budget")
	var site:=FrontierExpeditionBusiness.site(isolated)
	var ore: Dictionary={}
	for row in FrontierExpeditionBusiness.starter_veins(body):
		if row.resource=="iron":ore=row;break
	point=FrontierMineralWorld.point(app.surface_world.terrain.field,ore)
	var robot: Dictionary={"id":"review:robot","grade":"rare","tier":1,"position":FrontierExpeditionBusiness.array(point),"battery":100.0,"cargo":FrontierExpeditionBusiness.inventory(),"phase":"outbound","target":ore.id,"path":[],"status":"","work":.9,"charging":false}
	site.remaining[ore.id]=ore.capacity;site.robots={robot.id:robot}
	FrontierExpeditionIndustry._robot(isolated,site,robot,1)
	check(FrontierExpeditionBusiness.total(robot.cargo)==24 and float(robot.work)<1 and FrontierExpeditionBusiness.valid_robot(robot,robot.id),"one-second host tick accounts for all quality/research cycles and preserves valid remainder")
	site.buildings={"review:air":{"id":"review:air","type":"atmosphere","enabled":true,"active":true,"working":false,"work":0.0,"status":"","position":[0,2,0]}}
	site.environment={"temperature":18.0,"pressure":.6,"oxygen":.1,"toxicity":100.0,"water":100.0,"ecology":0.0,"stable_seconds":0.0}
	FrontierExpeditionIndustry.environment(isolated,site,1)
	check(is_equal_approx(site.environment.toxicity,99.67) and site.environment.stable_seconds==0,"shared processing factor applies once and does not accelerate stability")
	await compare_movement()
	move_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position));app.session._publish();app.session._publish_surface()
	app.toggle_research();app.research_frame.tabs.current_tab=2
	root.size=Vector2i(960,640);root.content_scale_size=Vector2i(960,640);await create_timer(.4).timeout
	var panel: FrontierProgressionResearchPanel=app.research_frame.tabs.get_tab_control(2)
	panel.selected="logistics";panel.signature="";panel.refresh();await capture("research-960")
	check("9칸" in panel.effect.text and panel.progress.value==1,"research UI reports actual personal capacity and level")
	check(app.feedback.audio.last_played.has("ui_discovery"),"accepted research uses existing ElevenLabs discovery sound")
	app.close_menus();check(await app.session.close_session(),"personal and shared research saved")
	var restored:=app.world_store.read_state()
	check(not restored.is_empty() and FrontierProgressionResearch.shared(restored)==1 and FrontierProgressionResearch.personal(restored.crew.members[owner],"mining")==1,"research survives reload")
	print("PROGRESSION_RESEARCH_FAILURES ",failures);quit(1 if failures else 0)

func compare_movement() -> void:
	var owner: String=app.session.latest.self_id
	# Use equal physics frames after acceleration; wall timers included variable rendering stalls.
	var origin:=Vector3(0,app.surface_world.terrain.field.height(0,-10)+.1,-10)
	check(await until(func():return app.surface_world.ready_at(origin) and app.surface_world.ready_at(origin+Vector3(6,0,0)),60),"movement lane streamed")
	var speeds: Array[float]=[]
	for level in [0,1]:
		app.test_direction=Vector2.ZERO
		move_to(origin);app.actors[owner].velocity=Vector3.ZERO
		app.session.authority.world.crew.members[owner].loadout.research.logistics=level
		await create_timer(.4).timeout
		app.yaw=0;app.test_direction=Vector2.RIGHT
		for frame in 30:await physics_frame
		var sum:=0.0
		for frame in 15:
			await physics_frame
			sum+=app.actors[owner].velocity.x
		speeds.append(sum/15)
		app.test_direction=Vector2.ZERO
	print("RESEARCH_STEADY_SPEED ",speeds)
	check(absf(speeds[0]-6.0)<.1 and absf(speeds[1]-6.6)<.1,"actual host steady ground velocity receives exactly +10 percent logistics")
func movement_review() -> void:
	await compare_movement()
	var w: Dictionary=app.session.authority.world.duplicate(true)
	var site:=FrontierExpeditionBusiness.site(w)
	site.buildings={"solar":{"id":"solar","type":"solar","enabled":true,"active":true,"working":false,"work":0.0,"status":"","position":[0,2,0]},"factory":{"id":"factory","type":"factory","enabled":true,"active":true,"working":false,"work":0.0,"status":"","position":[4,2,0]}}
	site.jobs={"review:job":{"factory_id":"factory","progress":0.0,"seconds":20.0,"grade":"common","tier":1}}
	FrontierExpeditionIndustry.tick(w,1)
	check(is_equal_approx(float(site.jobs["review:job"].progress),1.1),"shared research advances actual factory job +10 percent")
	check(is_equal_approx(FrontierProgressionResearch.multiplier(50),1.5),"research maximum is +50 percent")
	check(await app.session.close_session(),"movement review saved")
	print("PROGRESSION_MOVEMENT_FAILURES ",failures);quit(1 if failures else 0)
