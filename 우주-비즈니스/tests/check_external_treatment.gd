extends "res://tests/check_facility_interactions.gd"
## Bounded rendered review of accepted mining, survey, weapon and cancellation.
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
	if folder.is_empty() or not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
	root.size=Vector2i(1280,800)
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
	await process_frame
	var review: bool="--hud-review" in OS.get_cmdline_user_args()
	if not review:app.world_store.write(FrontierUniverse.new_world(71491))
	app.start_solo()
	if not await until(func():return app.session.active,15):quit(1);return
	app.onboarding.letter.hide()
	if review:
		check(await until(func():return app.surface_world!=null and not app.arrival.active,90),"resume external HUD")
		var clues:=FrontierGroundExploration.deposits(app.surface_world.body)
		var p:=FrontierMineralWorld.point(app.surface_world.terrain.field,clues[0])
		move_to(p+Vector3(0,.15,5))
		check(await until(func():return app.surface_world.ready_at(app.actors[app.session.latest.self_id].position),60),"external surface loaded")
		await create_timer(.5).timeout
		check(app.field_hud.location.text=="지표 탐사","negative elevation remains surface exploration")
		await capture("external-surface-height")
		var a:=Vector2(clues[0].position[0],clues[0].position[2]);var b:=Vector2(clues[1].position[0],clues[1].position[2])
		print("OUTER_STRAIGHT_WALK_SECONDS ",(a.length()+a.distance_to(b)+b.length())/6.0)
		await app.session.close_session();print("EXTERNAL_HUD_FAILURES ",failures);quit(1 if failures else 0);return
	var world: Dictionary=app.session.authority.world
	var ordinal:=8
	while ordinal<100000:
		var candidate:=FrontierUniverse.body(world.manifest,ordinal)
		if FrontierUniverse.landable(candidate) and int(candidate.planet_tier)==2 and FrontierGroundExploration.inputs(candidate).size()==2:break
		ordinal+=37
	var body:=FrontierUniverse.body(world.manifest,ordinal)
	var nav: Dictionary=world.crew.navigation
	nav.system=FrontierUniverse.system_index(world.manifest,ordinal);nav.target=ordinal;nav.mode="idle";nav.speed=0.0;nav.orbit_time=0.0
	var point:=FrontierCrewNavigation.center(ordinal,world.manifest,0)+Vector3(0,0,FrontierUniverse.radius(body)+30)
	nav.position=[point.x,point.y,point.z];nav.direction=[0,0,-1];world.location=body.id
	app.session._publish();await process_frame;app.travel_action("land")
	if not await until(func():return app.surface_world!=null and not app.arrival.active,90):check(false,"landing");quit(1);return
	app.close_menus();app.session.send_request("business_register",{})
	var owner: String=app.session.latest.self_id
	var site:=FrontierExpeditionBusiness.site(app.session.authority.world)
	check(site.restoration2.get("inputs",{}).size()==2,"new geological profile specifies both external treatment inputs")
	check("추천" in FrontierMineralWorld.summary(body),"prelanding summary recommends locally supplied T2")
	var deposits:=FrontierGroundExploration.deposits(body)
	for row in deposits:
		check(Vector2(row.position[0],row.position[2]).length()>=450 and row.required_tier==1,"external treatment material outside landing area")
		point=FrontierMineralWorld.point(app.surface_world.terrain.field,row)
		check(point.is_finite(),"first treatment ore exposed on supported surface")
		move_to(point+Vector3(0,.15,5))
		check(await until(func():return app.surface_world.ready_at(app.actors[owner].position),60),"external terrain streamed")
		await create_timer(.5).timeout
		app.camera.look_at(point+Vector3.UP*.6);app.yaw=app.camera.rotation.y;app.pitch=app.camera.rotation.x
		for i in 3:
			await until(func():return app.session.mining_ready(),5)
			app.session.send_request("business_mine",{"vein_id":row.id})
		check(int(FrontierExpeditionBusiness.bag(app.session.authority.world,owner).get(row.resource,0))==9,"actual Mk1 mining of "+row.resource)
		await capture("external-"+row.resource)
	site=FrontierExpeditionBusiness.site(app.session.authority.world)
	move_to(FrontierCrewWorld.vector(site.center));await create_timer(.5).timeout
	app.session.send_request("business_deposit",{"all_resources":true})
	site=FrontierExpeditionBusiness.site(app.session.authority.world)
	site.inventory.mineral_filter=10;site.inventory.soil_base=10;site.inventory.ice=50
	site.environment={"temperature":18.0,"pressure":1.0,"oxygen":.21,"toxicity":0.0,"water":80.0,"ecology":0.0,"stable_seconds":0.0}
	var ids: Dictionary={}
	for kind in ["solar","solar","factory","water","biolab"]:
		var found:=false
		for x in range(-40,41,7):
			if found:break
			for z in range(-35,36,7):
				point=FrontierExpeditionBusiness.ground(app.surface_world.terrain.field,x,z,float(FrontierCatalog.entry("buildings",kind).radius))
				if not point.is_finite() or not FrontierExpeditionBusiness.placement(app.session.authority.world,kind,point,{1:owner}).is_empty():continue
				var id:=FrontierExpeditionBusiness.identifier(app.session.authority.world.business,"fixture")
				site.buildings[id]={"id":id,"type":kind,"position":FrontierExpeditionBusiness.array(point),"yaw":0.0,"enabled":true,"active":false,"status":"대기","work":0.0,"tier":2 if kind in ["water","biolab"] else 1};ids[kind]=id;found=true;break
		check(found,"supported fixture "+kind)
	app.session._publish();app.session._publish_surface()
	await create_timer(7).timeout
	site=FrontierExpeditionBusiness.site(app.session.authority.world)
	check(site.restoration2.salinity==70 and site.restoration2.soil==10,"old filter and base cannot bypass new local inputs")
	for product in ["freshwater_module","soil_activation_pack"]:
		site=FrontierExpeditionBusiness.site(app.session.authority.world)
		move_to(FrontierCrewWorld.vector(site.buildings[ids.factory].position)+Vector3(0,0,5))
		app.session.send_request("business_produce",{"building_id":ids.factory,"product":product})
		check(not FrontierExpeditionBusiness.site(app.session.authority.world).buildings[ids.factory].get("production",{}).is_empty(),"host reserves recipe "+product)
		await create_timer(15).timeout
	site=FrontierExpeditionBusiness.site(app.session.authority.world)
	check(site.restoration2.salinity==60 and site.restoration2.soil==20,"new modules drive real water and soil processing")
	check(site.inventory.silicon==1 and site.inventory.phosphate==1,"external raw materials consumed exactly once")
	var legacy: Dictionary={"restoration2":{"salinity":70.0,"soil":10.0},"inventory":{"mineral_filter":1},"environment":{"toxicity":0.0}}
	var machine: Dictionary={"type":"water","tier":2,"status":"","treatment_work":0.0}
	FrontierProductionTier2.restore(legacy,machine,6)
	check(legacy.restoration2.salinity==60 and legacy.inventory.mineral_filter==0,"legacy T2 retains old input path")
	app.open_station("factory",ids.factory);await process_frame
	for i in app.business_panel.tabs.get_tab_count():
		if str(app.business_panel.tabs.get_tab_control(i).name)=="생산·개조":app.business_panel.tabs.current_tab=i
	app.business_panel.production_panel.selected_product="freshwater_module";app.business_panel.production_panel.refresh()
	root.size=Vector2i(960,640);root.content_scale_size=Vector2i(960,640);await create_timer(.4).timeout;await capture("module-production-960")
	check(app.feedback.audio.last_played.has("sfx_factory_complete"),"existing ElevenLabs production completion audio connected")
	app.close_menus();check(await app.session.close_session(),"external profile and depletion saved")
	var restored:=app.world_store.read_state()
	check(not restored.is_empty() and FrontierExpeditionBusiness.site(restored).restoration2.inputs.size()==2,"saved external profile reloads")
	print("EXTERNAL_TREATMENT_FAILURES ",failures);quit(1 if failures else 0)
